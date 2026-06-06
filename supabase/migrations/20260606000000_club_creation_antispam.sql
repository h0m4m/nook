-- Club-creation anti-spam: layered, server-enforced, unbypassable.
--
-- Replaces the flat "5/day, 20 total" cap (20260604200000) with strict, graduated
-- gates. All enforcement lives in the BEFORE INSERT trigger on public.clubs, so it
-- holds regardless of how the row is written (the content gateway uses the service
-- role, which bypasses RLS — but not triggers).
--
-- Layers, in order of evaluation:
--   1. Email verified            (auth.users.email_confirmed_at)
--   2. Profile complete          (user_profiles.onboarding_completed + username)
--   3. Account age >= 7 days     (auth.users.created_at)
--   4. Cooldown: 1 club / 24h    (creation ledger, survives deletes)
--   5. Lifetime cap by age       (7-14d:1, 14-30d:2, >=30d:4 — ledger-based)
--   6. At most 1 empty club      (no posts) at a time
--   7. 2nd+ club needs traction  (an existing club with >=10 members AND >=3 posts)
--   + Name length 3-50, description <= 500, global near-duplicate name block (pg_trgm)
--
-- The ledger (club_creation_log) is never deleted, so deleting a club does NOT
-- refund creation quota — closing the delete-and-recreate bypass.

-- ─────────────────────────────────────────────────────────────────────────────
-- Creation ledger
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.club_creation_log (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  club_id    uuid,                       -- no FK: kept after the club is deleted
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS club_creation_log_user_created_idx
  ON public.club_creation_log (user_id, created_at DESC);

-- Lock the table down: only SECURITY DEFINER functions (and the service role)
-- touch it; clients have no direct access.
ALTER TABLE public.club_creation_log ENABLE ROW LEVEL SECURITY;

-- Backfill from existing clubs so lifetime caps are accurate from day one.
INSERT INTO public.club_creation_log (user_id, club_id, created_at)
SELECT owner_id, id, created_at FROM public.clubs
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- Evaluator: account-level gates (everything except per-input name/length/dup).
-- Returns jsonb { ok, code, message, next_allowed_at }. Read-only; reused by the
-- trigger, the content gateway (pre-check, saves a moderation call), and the
-- client eligibility RPC so the rules live in exactly one place.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.evaluate_club_creation(p_user uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_created_at     timestamptz;
  v_email_conf     timestamptz;
  v_onboarded      boolean;
  v_username       text;
  v_age            interval;
  v_lifetime       int;
  v_owned          int;
  v_empty          int;
  v_has_traction   boolean;
  v_last_at        timestamptz;
  v_cap            int;
BEGIN
  SELECT created_at, email_confirmed_at
    INTO v_created_at, v_email_conf
    FROM auth.users WHERE id = p_user;

  IF v_created_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'no_account',
      'message', 'Account not found.');
  END IF;

  -- 1. Email verified.
  IF v_email_conf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'email_unverified',
      'message', 'Verify your email address before creating a club.');
  END IF;

  -- 2. Profile complete.
  SELECT onboarding_completed, username
    INTO v_onboarded, v_username
    FROM public.user_profiles WHERE id = p_user;

  IF coalesce(v_onboarded, false) = false
     OR v_username IS NULL OR btrim(v_username) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'profile_incomplete',
      'message', 'Finish setting up your profile before creating a club.');
  END IF;

  -- 3. Account age >= 7 days.
  v_age := now() - v_created_at;
  IF v_age < interval '7 days' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'too_new',
      'message', 'New accounts can create their first club after 7 days.',
      'next_allowed_at', v_created_at + interval '7 days');
  END IF;

  -- 4. Cooldown: at most one club per 24h (ledger-based).
  SELECT max(created_at) INTO v_last_at
    FROM public.club_creation_log WHERE user_id = p_user;
  IF v_last_at IS NOT NULL AND now() - v_last_at < interval '24 hours' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'cooldown',
      'message', 'You can only create one club per day. Please try again later.',
      'next_allowed_at', v_last_at + interval '24 hours');
  END IF;

  -- 5. Lifetime cap by account age (ledger-based — deletes don't refund).
  v_cap := CASE
    WHEN v_age >= interval '30 days' THEN 4
    WHEN v_age >= interval '14 days' THEN 2
    ELSE 1
  END;
  SELECT count(*) INTO v_lifetime
    FROM public.club_creation_log WHERE user_id = p_user;
  IF v_lifetime >= v_cap THEN
    RETURN jsonb_build_object('ok', false, 'code', 'lifetime_cap',
      'message', format(
        'You''ve reached the maximum of %s club(s) for your account. Older accounts can create more.',
        v_cap));
  END IF;

  -- 6. At most one empty (no-posts) club at a time.
  SELECT count(*) INTO v_empty
    FROM public.clubs c
   WHERE c.owner_id = p_user
     AND NOT EXISTS (SELECT 1 FROM public.club_posts p WHERE p.club_id = c.id);
  IF v_empty >= 1 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'empty_club',
      'message', 'Post in your existing club before creating another one.');
  END IF;

  -- 7. The 2nd+ club requires a proven, active club.
  SELECT count(*) INTO v_owned
    FROM public.clubs WHERE owner_id = p_user;
  IF v_owned >= 1 THEN
    SELECT EXISTS (
      SELECT 1 FROM public.clubs c
       WHERE c.owner_id = p_user
         AND c.member_count >= 10
         AND (SELECT count(*) FROM public.club_posts p WHERE p.club_id = c.id) >= 3
    ) INTO v_has_traction;
    IF NOT v_has_traction THEN
      RETURN jsonb_build_object('ok', false, 'code', 'needs_traction',
        'message', 'Grow one of your clubs to 10+ members and 3+ posts before creating another.');
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Client-facing wrapper: evaluates the caller's own eligibility.
CREATE OR REPLACE FUNCTION public.can_create_club()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT public.evaluate_club_creation(auth.uid());
$$;

REVOKE ALL ON FUNCTION public.evaluate_club_creation(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.evaluate_club_creation(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.can_create_club() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Enforcement trigger: per-input checks + the account-level evaluator.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enforce_club_creation_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE v_eval jsonb;
BEGIN
  -- Name + description shape.
  IF char_length(btrim(coalesce(NEW.name, ''))) < 3 THEN
    RAISE EXCEPTION 'Club name must be at least 3 characters.';
  END IF;
  IF char_length(NEW.name) > 50 THEN
    RAISE EXCEPTION 'Club name must be 50 characters or fewer.';
  END IF;
  IF NEW.description IS NOT NULL AND char_length(NEW.description) > 500 THEN
    RAISE EXCEPTION 'Club description must be 500 characters or fewer.';
  END IF;

  -- Global near-duplicate name block (pg_trgm trigram similarity).
  IF EXISTS (
    SELECT 1 FROM public.clubs c
     WHERE similarity(lower(c.name), lower(NEW.name)) >= 0.8
  ) THEN
    RAISE EXCEPTION 'A club with a very similar name already exists. Please choose a different name.';
  END IF;

  -- Account-level gates (verification, age, cooldown, caps, traction).
  v_eval := public.evaluate_club_creation(NEW.owner_id);
  IF (v_eval->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION '%', v_eval->>'message';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_club_limits ON public.clubs;
CREATE TRIGGER enforce_club_limits
  BEFORE INSERT ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.enforce_club_creation_limits();

-- ─────────────────────────────────────────────────────────────────────────────
-- Ledger writer: record every successful creation (after the row exists).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_club_creation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.club_creation_log (user_id, club_id)
  VALUES (NEW.owner_id, NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_club_creation ON public.clubs;
CREATE TRIGGER log_club_creation
  AFTER INSERT ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.log_club_creation();
