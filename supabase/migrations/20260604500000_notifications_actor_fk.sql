-- Notifications: embed the actor's profile + allow deleting your own.
-- Without the user_profiles FK, the notifications query's
-- `actor:user_profiles!actor_id` embed 400s and the list comes back empty.
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_actor_id_user_profiles_fkey
  FOREIGN KEY (actor_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;

DROP POLICY IF EXISTS "Users delete own notifications" ON public.notifications;
CREATE POLICY "Users delete own notifications" ON public.notifications FOR DELETE
  TO authenticated USING (auth.uid() = user_id);
