-- Server-side notification generation.
--
-- Until now every row in public.notifications was inserted client-side, best-effort
-- (`try?`), from the *actor's* device. That was unreliable (silent failures, missed
-- when the app backgrounds mid-action), ignored the user's notification_preferences
-- and per-club mutes entirely, and could not power push (the recipient isn't
-- involved in the actor's request). This migration moves creation into the database
-- via AFTER INSERT triggers so notifications are reliable, preference-aware, and a
-- single source of truth that a push pipeline (Phase 4) can hang off later.
--
-- Notification `type` + `reference_type` strings below MUST match what the iOS client
-- already renders/navigates on (Models/Notification.swift, Views/Notifications):
--   follow         (ref: none)
--   like_review    (ref: review_id      / "review")
--   comment_review (ref: review_id      / "review")
--   like_post      (ref: club_post id   / "club_post")
--   comment_post   (ref: club_post id   / "club_post")
--   club_invite    (ref: club_id        / "club")
--   club_join      (ref: club_id        / "club")
--   nook_mention   (ref: club_post id   / "club_post")

-- ---------------------------------------------------------------------------
-- Preconditions
-- ---------------------------------------------------------------------------
-- notification_preferences is required by the preference guard below. It has its
-- own migration (add_notification_preferences) but that wasn't applied on every
-- environment, and this migration hard-depends on the column, so ensure it exists
-- here (idempotent — no-op where it already exists).
alter table public.user_profiles
  add column if not exists notification_preferences jsonb not null
  default '{"push_enabled": true, "activity": true, "community": true, "reviews": true}'::jsonb;

-- ---------------------------------------------------------------------------
-- Preference category mapping
-- ---------------------------------------------------------------------------
-- user_profiles.notification_preferences is { push_enabled, activity, community,
-- reviews }. push_enabled is reserved for push delivery (Phase 4). The three
-- category flags gate whether the in-app notification row is created at all, so the
-- Settings toggles become functional now. Mapping follows the Settings UI copy:
--   activity  = "likes, follows, mentions"        -> follow, like_post, nook_mention
--   community = "new posts/replies" (clubs)       -> comment_post, club_invite, club_join
--   reviews   = "reactions to your reviews"       -> like_review, comment_review
create or replace function private.notification_category(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_type
    when 'like_review'    then 'reviews'
    when 'comment_review' then 'reviews'
    when 'comment_post'   then 'community'
    when 'club_invite'    then 'community'
    when 'club_join'      then 'community'
    when 'follow'         then 'activity'
    when 'like_post'      then 'activity'
    when 'nook_mention'   then 'activity'
    else 'activity'
  end;
$$;

-- Whether the recipient's preferences allow this category. Fail-open: a missing
-- profile or missing key means "allowed" so we never silently drop notifications.
create or replace function private.notification_pref_allows(p_recipient uuid, p_type text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (up.notification_preferences ->> private.notification_category(p_type))::boolean,
    true
  )
  from public.user_profiles up
  where up.id = p_recipient;
$$;

-- ---------------------------------------------------------------------------
-- Central insert helper — applies every guard in one place.
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER (owned by postgres) so it bypasses the notifications INSERT RLS
-- policy (WITH CHECK auth.uid() = actor_id) — the recipient, not the actor, is the
-- row owner here. Guards, in order:
--   1. recipient/actor present
--   2. no self-notification
--   3. neither party has blocked the other
--   4. recipient's category preference allows it
--   5. recipient hasn't muted this club (when p_club_id given)
--   6. dedupe noisy repeat events (follow / likes) against existing UNREAD rows
create or replace function private.create_notification(
  p_recipient      uuid,
  p_actor          uuid,
  p_type           text,
  p_reference_id   uuid default null,
  p_reference_type text default null,
  p_club_id        uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_recipient is null or p_actor is null then
    return;
  end if;

  if p_recipient = p_actor then
    return;
  end if;

  if private.is_blocked(p_recipient, p_actor) then
    return;
  end if;

  if not coalesce(private.notification_pref_allows(p_recipient, p_type), true) then
    return;
  end if;

  if p_club_id is not null then
    if exists (
      select 1 from public.club_members cm
      where cm.club_id = p_club_id
        and cm.user_id = p_recipient
        and cm.notifications_muted
    ) then
      return;
    end if;
  end if;

  -- Collapse repeat likes/follows while still unread (e.g. unlike -> relike spam).
  if p_type in ('follow', 'like_review', 'like_post') then
    if exists (
      select 1 from public.notifications n
      where n.user_id = p_recipient
        and n.actor_id = p_actor
        and n.type = p_type
        and n.reference_id is not distinct from p_reference_id
        and n.is_read = false
    ) then
      return;
    end if;
  end if;

  insert into public.notifications (user_id, actor_id, type, reference_id, reference_type)
  values (p_recipient, p_actor, p_type, p_reference_id, p_reference_type);
end;
$$;

-- ---------------------------------------------------------------------------
-- Mention helper — parses @username tokens out of post/comment bodies and notifies
-- each mentioned user who is a member of the club (members can always see the post,
-- which avoids leaking private-club content to non-members).
-- ---------------------------------------------------------------------------
create or replace function private.notify_post_mentions(
  p_post_id uuid,
  p_club_id uuid,
  p_actor   uuid,
  p_body    text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
begin
  if p_body is null then
    return;
  end if;

  for v_user in
    select distinct up.id
    from regexp_matches(p_body, '@([a-zA-Z0-9_]{3,20})', 'g') as m(parts)
    join public.user_profiles up
      on lower(up.username) = lower(m.parts[1])
    join public.club_members cm
      on cm.club_id = p_club_id and cm.user_id = up.id
  loop
    perform private.create_notification(
      v_user, p_actor, 'nook_mention', p_post_id, 'club_post', p_club_id
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Follow
create or replace function private.tg_notify_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.create_notification(NEW.following_id, NEW.follower_id, 'follow');
  return NEW;
end;
$$;

drop trigger if exists trg_notify_follow on public.user_follows;
create trigger trg_notify_follow
  after insert on public.user_follows
  for each row execute function private.tg_notify_follow();

-- Review like
create or replace function private.tg_notify_review_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select r.user_id into v_owner from public.reviews r where r.id = NEW.review_id;
  perform private.create_notification(v_owner, NEW.user_id, 'like_review', NEW.review_id, 'review');
  return NEW;
end;
$$;

drop trigger if exists trg_notify_review_like on public.review_likes;
create trigger trg_notify_review_like
  after insert on public.review_likes
  for each row execute function private.tg_notify_review_like();

-- Review comment
create or replace function private.tg_notify_review_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select r.user_id into v_owner from public.reviews r where r.id = NEW.review_id;
  perform private.create_notification(v_owner, NEW.user_id, 'comment_review', NEW.review_id, 'review');
  return NEW;
end;
$$;

drop trigger if exists trg_notify_review_comment on public.review_comments;
create trigger trg_notify_review_comment
  after insert on public.review_comments
  for each row execute function private.tg_notify_review_comment();

-- Club post like
create or replace function private.tg_notify_club_post_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
  v_club   uuid;
begin
  select p.user_id, p.club_id into v_author, v_club
  from public.club_posts p where p.id = NEW.post_id;
  perform private.create_notification(v_author, NEW.user_id, 'like_post', NEW.post_id, 'club_post', v_club);
  return NEW;
end;
$$;

drop trigger if exists trg_notify_club_post_like on public.club_post_likes;
create trigger trg_notify_club_post_like
  after insert on public.club_post_likes
  for each row execute function private.tg_notify_club_post_like();

-- Club post comment (notify author + any @mentioned members)
create or replace function private.tg_notify_club_post_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
  v_club   uuid;
begin
  select p.user_id, p.club_id into v_author, v_club
  from public.club_posts p where p.id = NEW.post_id;

  perform private.create_notification(v_author, NEW.user_id, 'comment_post', NEW.post_id, 'club_post', v_club);
  perform private.notify_post_mentions(NEW.post_id, v_club, NEW.user_id, NEW.body);
  return NEW;
end;
$$;

drop trigger if exists trg_notify_club_post_comment on public.club_post_comments;
create trigger trg_notify_club_post_comment
  after insert on public.club_post_comments
  for each row execute function private.tg_notify_club_post_comment();

-- Club post created (notify @mentioned members)
create or replace function private.tg_notify_club_post_mention()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify_post_mentions(NEW.id, NEW.club_id, NEW.user_id, NEW.body);
  return NEW;
end;
$$;

drop trigger if exists trg_notify_club_post_mention on public.club_posts;
create trigger trg_notify_club_post_mention
  after insert on public.club_posts
  for each row execute function private.tg_notify_club_post_mention();

-- Club invite
create or replace function private.tg_notify_club_invite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.create_notification(
    NEW.invitee_id, NEW.inviter_id, 'club_invite', NEW.club_id, 'club'
  );
  return NEW;
end;
$$;

drop trigger if exists trg_notify_club_invite on public.club_invites;
create trigger trg_notify_club_invite
  after insert on public.club_invites
  for each row execute function private.tg_notify_club_invite();

-- Club join (notify the club owner; owner joining their own club is filtered by the
-- no-self-notification guard)
create or replace function private.tg_notify_club_join()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select c.owner_id into v_owner from public.clubs c where c.id = NEW.club_id;
  perform private.create_notification(
    v_owner, NEW.user_id, 'club_join', NEW.club_id, 'club', NEW.club_id
  );
  return NEW;
end;
$$;

drop trigger if exists trg_notify_club_join on public.club_members;
create trigger trg_notify_club_join
  after insert on public.club_members
  for each row execute function private.tg_notify_club_join();

-- ---------------------------------------------------------------------------
-- Realtime — let the client subscribe to its own notifications instead of polling.
-- ---------------------------------------------------------------------------
alter table public.notifications replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;  -- already a member
  when undefined_object then null;  -- publication missing (local stack without realtime)
end;
$$;
