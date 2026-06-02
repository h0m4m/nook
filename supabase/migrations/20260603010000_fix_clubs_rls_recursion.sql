-- =============================================================================
-- Fix infinite recursion in clubs / club_members RLS.
--
-- The original "Club members readable by same-club members" policy did
--   EXISTS (SELECT 1 FROM club_members ...)
-- from within the club_members SELECT policy itself, which Postgres rejects as
-- "infinite recursion detected in policy for relation club_members" (HTTP 500).
-- The clubs "Read public clubs" policy then sub-queried club_members, so it
-- 500'd too. This was dormant while clubs were mock; real usage trips it on
-- every read/insert.
--
-- Fix: SECURITY DEFINER helpers bypass RLS, so the membership lookups no longer
-- re-trigger the policy. Rewrite both SELECT policies to use them.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_club_member(p_club_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.club_members
    WHERE club_id = p_club_id AND user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_public_club(p_club_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.clubs
    WHERE id = p_club_id AND privacy = 'public'
  );
$$;

-- club_members: visible for public clubs, or clubs the current user belongs to.
DROP POLICY IF EXISTS "Club members readable by same-club members" ON public.club_members;
CREATE POLICY "Club members readable by same-club members"
  ON public.club_members FOR SELECT
  TO authenticated
  USING (
    public.is_public_club(club_id)
    OR public.is_club_member(club_id, auth.uid())
  );

-- clubs: public, owned, or joined — via the definer helper (no club_members RLS).
DROP POLICY IF EXISTS "Read public clubs" ON public.clubs;
CREATE POLICY "Read public clubs"
  ON public.clubs FOR SELECT
  TO authenticated
  USING (
    privacy = 'public'
    OR owner_id = auth.uid()
    OR public.is_club_member(id, auth.uid())
  );

-- Bonus correctness fix: a brand-new club defaulted member_count = 1, then the
-- owner's club_members insert fired the increment trigger -> 2. Start at 0 so
-- the owner insert lands it at exactly 1. (No backfill: zero clubs exist.)
ALTER TABLE public.clubs ALTER COLUMN member_count SET DEFAULT 0;
