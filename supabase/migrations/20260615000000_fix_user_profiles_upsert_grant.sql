-- ─────────────────────────────────────────────────────────────────────────────
-- Fix: onboarding "Continue" fails with "permission denied for table user_profiles"
--
-- 20260605200000_moderation_gateway_lockdown.sql replaced the blanket
-- INSERT/UPDATE grants on user_profiles with column-level grants. The client's
-- saveInterests() upsert (id, interests, onboarding_completed) compiles to:
--
--   INSERT ... ON CONFLICT (id) DO UPDATE SET id = excluded.id, interests = ...
--
-- The ON CONFLICT DO UPDATE clause sets `id`, so the statement requires UPDATE
-- privilege on the `id` column — which was omitted from the update grant. The
-- privilege is checked on the compiled statement, so the upsert is denied even
-- when no conflicting row exists. Add `id` to the update grant; the only value
-- ever written is the user's own id (and RLS `auth.uid() = id` still applies),
-- so this does not widen what the client can do.
-- ─────────────────────────────────────────────────────────────────────────────

grant update (id, interests, onboarding_completed, avatar_url, notification_preferences, username_changed_at, updated_at)
  on public.user_profiles to authenticated;
