-- Club deletion: a 1-hour "undo" window that refunds creation quota.
--
-- Owners can delete a club at any time. Because club names are immutable, a
-- common legit case is "I made a typo / wrong name, delete and recreate" — so a
-- delete within 1 hour of creation is treated as if the club never existed: its
-- ledger row is marked refunded, freeing both the lifetime slot AND the cooldown
-- (max(created_at) ignores refunded rows), letting the owner recreate immediately.
--
-- To stop this from reopening the create→delete→create farm, refunds are capped
-- at 3 per rolling 24h; beyond that a quick delete is treated as a normal delete
-- (slot consumed, cooldown still applies). Deletes after the 1h window never
-- refund. See [[project_club_antispam]].

ALTER TABLE public.club_creation_log
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS refunded   boolean NOT NULL DEFAULT false;

-- Refund-or-consume decision, on every club delete.
CREATE OR REPLACE FUNCTION public.handle_club_deletion_refund()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_created  timestamptz;
  v_refunds  int;
BEGIN
  SELECT created_at INTO v_created
    FROM public.club_creation_log
   WHERE club_id = OLD.id
   ORDER BY created_at
   LIMIT 1;

  IF v_created IS NOT NULL AND now() - v_created < interval '1 hour' THEN
    SELECT count(*) INTO v_refunds
      FROM public.club_creation_log
     WHERE user_id = OLD.owner_id
       AND refunded
       AND deleted_at > now() - interval '24 hours';

    IF v_refunds < 3 THEN
      -- Quick "undo": refund the slot + clear the cooldown hold.
      UPDATE public.club_creation_log
         SET refunded = true, deleted_at = now()
       WHERE club_id = OLD.id;
      RETURN OLD;
    END IF;
  END IF;

  -- Normal delete: slot stays consumed, cooldown still holds.
  UPDATE public.club_creation_log
     SET deleted_at = now()
   WHERE club_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS club_deletion_refund ON public.clubs;
CREATE TRIGGER club_deletion_refund
  BEFORE DELETE ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.handle_club_deletion_refund();

-- Lifetime cap + cooldown now ignore refunded rows.
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

  IF v_email_conf IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'email_unverified',
      'message', 'Verify your email address before creating a club.');
  END IF;

  SELECT onboarding_completed, username
    INTO v_onboarded, v_username
    FROM public.user_profiles WHERE id = p_user;

  IF coalesce(v_onboarded, false) = false
     OR v_username IS NULL OR btrim(v_username) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'profile_incomplete',
      'message', 'Finish setting up your profile before creating a club.');
  END IF;

  v_age := now() - v_created_at;
  IF v_age < interval '7 days' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'too_new',
      'message', 'New accounts can create their first club after 7 days.',
      'next_allowed_at', v_created_at + interval '7 days');
  END IF;

  -- Cooldown: at most one club per 24h (ledger-based, ignores refunded undos).
  SELECT max(created_at) INTO v_last_at
    FROM public.club_creation_log
   WHERE user_id = p_user AND NOT refunded;
  IF v_last_at IS NOT NULL AND now() - v_last_at < interval '24 hours' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'cooldown',
      'message', 'You can only create one club per day. Please try again later.',
      'next_allowed_at', v_last_at + interval '24 hours');
  END IF;

  -- Lifetime cap by account age (ledger-based; refunded undos don't count).
  v_cap := CASE
    WHEN v_age >= interval '30 days' THEN 4
    WHEN v_age >= interval '14 days' THEN 2
    ELSE 1
  END;
  SELECT count(*) INTO v_lifetime
    FROM public.club_creation_log
   WHERE user_id = p_user AND NOT refunded;
  IF v_lifetime >= v_cap THEN
    RETURN jsonb_build_object('ok', false, 'code', 'lifetime_cap',
      'message', format(
        'You''ve reached the maximum of %s club(s) for your account. Older accounts can create more.',
        v_cap));
  END IF;

  SELECT count(*) INTO v_empty
    FROM public.clubs c
   WHERE c.owner_id = p_user
     AND NOT EXISTS (SELECT 1 FROM public.club_posts p WHERE p.club_id = c.id);
  IF v_empty >= 1 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'empty_club',
      'message', 'Post in your existing club before creating another one.');
  END IF;

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
