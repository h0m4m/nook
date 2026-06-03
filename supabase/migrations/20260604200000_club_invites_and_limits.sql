-- =============================================================================
-- Production club invites + create-club limits
-- =============================================================================

-- 1. club_invites — a pending invite lets the invitee see (and join) the club,
--    including private clubs that are otherwise hidden by RLS.
CREATE TABLE IF NOT EXISTS public.club_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (club_id, invitee_id)
);
CREATE INDEX IF NOT EXISTS club_invites_invitee_idx ON public.club_invites (invitee_id);

ALTER TABLE public.club_invites ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_club_invite(p_club_id uuid, p_user_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.club_invites
    WHERE club_id = p_club_id AND invitee_id = p_user_id AND status = 'pending'
  );
$$;

CREATE POLICY "Read own or club invites"
  ON public.club_invites FOR SELECT TO authenticated
  USING (invitee_id = auth.uid() OR public.is_club_admin(club_id, auth.uid()));

CREATE POLICY "Members invite"
  ON public.club_invites FOR INSERT TO authenticated
  WITH CHECK (inviter_id = auth.uid() AND public.is_club_member(club_id, auth.uid()));

CREATE POLICY "Invitee updates own invite"
  ON public.club_invites FOR UPDATE TO authenticated
  USING (invitee_id = auth.uid());

CREATE POLICY "Invitee or admin deletes invite"
  ON public.club_invites FOR DELETE TO authenticated
  USING (invitee_id = auth.uid() OR public.is_club_admin(club_id, auth.uid()));

-- Invitees can read the club they're invited to (even private).
DROP POLICY IF EXISTS "Read public clubs" ON public.clubs;
CREATE POLICY "Read public clubs"
  ON public.clubs FOR SELECT TO authenticated
  USING (
    privacy = 'public'
    OR owner_id = auth.uid()
    OR public.is_club_member(id, auth.uid())
    OR public.has_club_invite(id, auth.uid())
  );

-- 2. Create-club limits (enforced server-side, can't be bypassed).
CREATE OR REPLACE FUNCTION public.enforce_club_creation_limits()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE owned int; recent int;
BEGIN
  IF char_length(btrim(coalesce(NEW.name, ''))) < 3 THEN
    RAISE EXCEPTION 'Club name must be at least 3 characters.';
  END IF;
  IF char_length(NEW.name) > 50 THEN
    RAISE EXCEPTION 'Club name must be 50 characters or fewer.';
  END IF;
  IF NEW.description IS NOT NULL AND char_length(NEW.description) > 500 THEN
    RAISE EXCEPTION 'Club description must be 500 characters or fewer.';
  END IF;

  SELECT count(*) INTO owned FROM public.clubs WHERE owner_id = NEW.owner_id;
  IF owned >= 20 THEN
    RAISE EXCEPTION 'You can own at most 20 clubs.';
  END IF;

  SELECT count(*) INTO recent FROM public.clubs
   WHERE owner_id = NEW.owner_id AND created_at > now() - interval '24 hours';
  IF recent >= 5 THEN
    RAISE EXCEPTION 'You can create at most 5 clubs per day. Try again later.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_club_limits ON public.clubs;
CREATE TRIGGER enforce_club_limits
  BEFORE INSERT ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.enforce_club_creation_limits();
