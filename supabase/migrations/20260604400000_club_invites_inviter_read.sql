-- Inviters can also read invites they sent, so the invite sheet can show who
-- has already been invited (not just owner/managers and the invitee).
DROP POLICY IF EXISTS "Read own or club invites" ON public.club_invites;
CREATE POLICY "Read own or club invites" ON public.club_invites FOR SELECT
  TO authenticated
  USING (
    invitee_id = auth.uid()
    OR inviter_id = auth.uid()
    OR public.is_club_admin(club_id, auth.uid())
  );
