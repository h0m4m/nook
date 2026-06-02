-- Add notification preferences to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS notification_preferences jsonb NOT NULL DEFAULT '{"push_enabled": true, "activity": true, "community": true, "reviews": true}'::jsonb;
