-- =============================================================================
-- Club roles: single elevated tier "manager" (was "admin")
--   owner   — full control, only role that can delete the club / manage roles
--   manager — moderate posts (pin/delete), remove plain members, invite
--   member  — post/comment/vote/invite (cannot pin or moderate)
-- =============================================================================

-- Migrate any legacy admins to manager.
UPDATE public.club_members SET role = 'manager' WHERE role = 'admin';

-- is_club_admin = elevated moderator (owner OR manager).
CREATE OR REPLACE FUNCTION public.is_club_admin(p_club_id uuid, p_user_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.clubs WHERE id = p_club_id AND owner_id = p_user_id)
      OR EXISTS (SELECT 1 FROM public.club_members WHERE club_id = p_club_id AND user_id = p_user_id AND role = 'manager');
$$;

-- Member removal: owner removes any non-owner; manager removes only plain members.
DROP POLICY IF EXISTS "Admins remove members" ON public.club_members;
DROP POLICY IF EXISTS "Managers remove members" ON public.club_members;
CREATE POLICY "Managers remove members"
  ON public.club_members FOR DELETE
  TO authenticated
  USING (
    role <> 'owner' AND (
      public.is_club_owner(club_id, auth.uid())
      OR (role = 'member' AND public.is_club_admin(club_id, auth.uid()))
    )
  );

-- (clubs DELETE remains owner-only via the existing "Owners delete own clubs" policy;
--  role UPDATE remains owner-only via "Owner manages member roles".)
