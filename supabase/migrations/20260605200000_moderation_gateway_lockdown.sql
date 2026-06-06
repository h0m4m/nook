-- ─────────────────────────────────────────────────────────────────────────────
-- Moderation gateway lockdown
--
-- All user-generated content now flows through the `content` Edge Function, which
-- runs OpenAI moderation before writing with the service role. To make that path
-- un-bypassable, the client (the `authenticated` role) loses the ability to write
-- content rows directly:
--   * content tables: drop the INSERT/UPDATE RLS policies (RLS denies by default;
--     SELECT + DELETE policies are kept, so reading and deleting your own content
--     still works). The service role bypasses RLS, so the gateway still writes.
--   * club_posts: keep the UPDATE policies (pin/unpin) but restrict the column
--     privilege to `is_pinned` so the post body can't be edited around the gateway.
--   * user_profiles: mixed text + non-text columns — use column-level privileges
--     so only full_name / username / bio are gated; avatar / interests / prefs
--     stay client-writable.
--
-- Count-maintenance triggers (likes_count, member_count, votes_count) are all
-- SECURITY DEFINER, so they are unaffected by these policy/privilege changes.
-- ─────────────────────────────────────────────────────────────────────────────

-- Reviews ---------------------------------------------------------------------
drop policy if exists "Users insert own reviews" on public.reviews;
drop policy if exists "Users update own reviews" on public.reviews;

drop policy if exists "Users insert own review_comments" on public.review_comments;
drop policy if exists "Users update own review_comments" on public.review_comments;

-- Clubs -----------------------------------------------------------------------
drop policy if exists "Users insert own clubs" on public.clubs;
drop policy if exists "Admins update club" on public.clubs;

-- Club posts + attachments ----------------------------------------------------
drop policy if exists "Users insert own club_posts" on public.club_posts;
drop policy if exists "Insert own club_post_images" on public.club_post_images;
drop policy if exists "Insert own club_post_media" on public.club_post_media;
drop policy if exists "Insert poll for own post" on public.club_post_polls;
drop policy if exists "Insert options for own poll" on public.club_poll_options;

drop policy if exists "Users insert own club_post_comments" on public.club_post_comments;
drop policy if exists "Users update own club_post_comments" on public.club_post_comments;

-- club_posts: keep pin/unpin UPDATE policies, but only `is_pinned` is writable by
-- the client (the body can no longer be edited directly).
revoke update on public.club_posts from authenticated;
grant update (is_pinned) on public.club_posts to authenticated;

-- Nooks -----------------------------------------------------------------------
drop policy if exists "Users insert own nooks" on public.nooks;
drop policy if exists "Users update own nooks" on public.nooks;

drop policy if exists "Users insert items to own nooks" on public.nook_items;
drop policy if exists "Users update items in own nooks" on public.nook_items;

drop policy if exists "Users insert own nook_comments" on public.nook_comments;
drop policy if exists "Users update own nook_comments" on public.nook_comments;

-- User profiles ---------------------------------------------------------------
-- Keep the ownership RLS policies, but gate the free-text columns at the column
-- privilege layer. full_name / username / bio are writable only by the service
-- role (i.e. only through the moderation gateway).
revoke insert, update on public.user_profiles from authenticated;
grant insert (id, interests, onboarding_completed, avatar_url, notification_preferences)
  on public.user_profiles to authenticated;
grant update (interests, onboarding_completed, avatar_url, notification_preferences, username_changed_at, updated_at)
  on public.user_profiles to authenticated;
