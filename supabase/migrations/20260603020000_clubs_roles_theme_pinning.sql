-- =============================================================================
-- Clubs: theme color + role-based moderation (pin / delete / member management)
-- =============================================================================

-- 1. Persist the club's chosen accent/theme color (6-digit hex, e.g. 'BA68C8').
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS theme_color text;

-- 2. Role helpers (SECURITY DEFINER -> bypass RLS, no recursion).
CREATE OR REPLACE FUNCTION public.is_club_owner(p_club_id uuid, p_user_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.clubs WHERE id = p_club_id AND owner_id = p_user_id);
$$;

CREATE OR REPLACE FUNCTION public.is_club_admin(p_club_id uuid, p_user_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.clubs WHERE id = p_club_id AND owner_id = p_user_id)
      OR EXISTS (
        SELECT 1 FROM public.club_members
        WHERE club_id = p_club_id AND user_id = p_user_id AND role IN ('owner','admin')
      );
$$;

-- 3. club_posts: owners/admins can moderate (pin/unpin = UPDATE, remove = DELETE)
--    any post in their club. Existing "own post" policies remain (OR-combined).
DROP POLICY IF EXISTS "Club admins update posts" ON public.club_posts;
CREATE POLICY "Club admins update posts"
  ON public.club_posts FOR UPDATE
  TO authenticated
  USING (public.is_club_admin(club_id, auth.uid()));

DROP POLICY IF EXISTS "Club admins delete posts" ON public.club_posts;
CREATE POLICY "Club admins delete posts"
  ON public.club_posts FOR DELETE
  TO authenticated
  USING (public.is_club_admin(club_id, auth.uid()));

-- 4. club_members management.
--    Role changes: owner only.
DROP POLICY IF EXISTS "Owner manages member roles" ON public.club_members;
CREATE POLICY "Owner manages member roles"
  ON public.club_members FOR UPDATE
  TO authenticated
  USING (public.is_club_owner(club_id, auth.uid()))
  WITH CHECK (public.is_club_owner(club_id, auth.uid()));

--    Removal: a member can leave (existing "Users can leave clubs"), and
--    owners/admins can remove any non-owner member.
DROP POLICY IF EXISTS "Admins remove members" ON public.club_members;
CREATE POLICY "Admins remove members"
  ON public.club_members FOR DELETE
  TO authenticated
  USING (public.is_club_admin(club_id, auth.uid()) AND role <> 'owner');
