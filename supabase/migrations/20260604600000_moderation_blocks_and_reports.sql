-- Moderation: database-level block enforcement + a mature reports schema.
--
-- Block enforcement is done with RESTRICTIVE row-level-security policies so it
-- is bypass-proof and centralized: once user A blocks user B, B's content stops
-- coming back from EVERY query A makes (reviews, comments, club posts, nooks,
-- activity, notifications) — no client-side filtering required, and it works in
-- both directions (if B blocked A, A also stops seeing B).
--
-- Reports are captured maturely (reason vocabulary, dedupe, status lifecycle)
-- but intentionally have no in-app consumer yet — moderation tooling is future
-- work. The schema is ready for it.

-- ---------------------------------------------------------------------------
-- 0. private schema for internal helpers (NOT exposed through PostgREST, so the
--    block-relationship helper can never be probed via /rest/v1/rpc).
-- ---------------------------------------------------------------------------

create schema if not exists private;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------------
-- 1. user_blocks hardening
-- ---------------------------------------------------------------------------

-- You cannot block yourself.
alter table public.user_blocks
  drop constraint if exists user_blocks_no_self_block;
alter table public.user_blocks
  add constraint user_blocks_no_self_block check (blocker_id <> blocked_id);

-- Reverse-direction lookups (does anyone block me?) need their own index;
-- the primary key only covers (blocker_id, blocked_id).
create index if not exists user_blocks_blocked_id_idx
  on public.user_blocks (blocked_id, blocker_id);

-- Blocking severs any follow relationship in BOTH directions. This is a
-- trigger-only function, so its default PUBLIC execute grant is revoked.
create or replace function public.sever_follows_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.user_follows
  where (follower_id = new.blocker_id and following_id = new.blocked_id)
     or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return new;
end;
$$;
-- Trigger-only: not meant to be callable directly. Supabase's default
-- privileges grant EXECUTE to anon/authenticated explicitly, so revoke all.
revoke execute on function public.sever_follows_on_block() from public, anon, authenticated;

drop trigger if exists user_blocks_sever_follows on public.user_blocks;
create trigger user_blocks_sever_follows
  after insert on public.user_blocks
  for each row execute function public.sever_follows_on_block();

-- ---------------------------------------------------------------------------
-- 2. is_blocked() — bidirectional check used by the RLS policies.
--    Lives in `private` so it is usable by policies but not callable via the
--    REST API. SECURITY DEFINER so it can see block rows in either direction.
-- ---------------------------------------------------------------------------

create or replace function private.is_blocked(viewer uuid, author uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_blocks
    where (blocker_id = viewer and blocked_id = author)
       or (blocker_id = author and blocked_id = viewer)
  );
$$;

revoke execute on function private.is_blocked(uuid, uuid) from public;
grant execute on function private.is_blocked(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RESTRICTIVE policies that hide content authored by a blocked user.
--    Restrictive policies are AND-ed with the existing permissive SELECT
--    policies, so they only ever subtract rows — never widen access.
-- ---------------------------------------------------------------------------

drop policy if exists "Hide blocked users' reviews" on public.reviews;
create policy "Hide blocked users' reviews" on public.reviews
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

drop policy if exists "Hide blocked users' review comments" on public.review_comments;
create policy "Hide blocked users' review comments" on public.review_comments
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

drop policy if exists "Hide blocked users' club posts" on public.club_posts;
create policy "Hide blocked users' club posts" on public.club_posts
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

drop policy if exists "Hide blocked users' club post comments" on public.club_post_comments;
create policy "Hide blocked users' club post comments" on public.club_post_comments
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

drop policy if exists "Hide blocked users' nooks" on public.nooks;
create policy "Hide blocked users' nooks" on public.nooks
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

drop policy if exists "Hide blocked users' nook comments" on public.nook_comments;
create policy "Hide blocked users' nook comments" on public.nook_comments
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

drop policy if exists "Hide blocked users' activity" on public.activity_feed;
create policy "Hide blocked users' activity" on public.activity_feed
  as restrictive for select to authenticated
  using (not private.is_blocked((select auth.uid()), user_id));

-- Notifications: drop any whose actor you've blocked (or who blocked you).
drop policy if exists "Hide blocked actors' notifications" on public.notifications;
create policy "Hide blocked actors' notifications" on public.notifications
  as restrictive for select to authenticated
  using (actor_id is null or not private.is_blocked((select auth.uid()), actor_id));

-- A previous revision created this helper in `public`; remove it now that the
-- policies point at the private one. (No-op on a fresh database.)
drop function if exists public.is_blocked(uuid, uuid);

-- ---------------------------------------------------------------------------
-- 4. reports: mature schema
-- ---------------------------------------------------------------------------

alter table public.reports
  add column if not exists reported_user_id uuid references auth.users(id) on delete set null,
  add column if not exists details text,
  add column if not exists status text not null default 'pending',
  add column if not exists updated_at timestamptz not null default now();

-- Constrain the vocabularies so the data stays clean for future tooling.
alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports add constraint reports_status_check
  check (status in ('pending', 'reviewing', 'actioned', 'dismissed'));

alter table public.reports drop constraint if exists reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('post', 'club', 'review', 'comment', 'user', 'nook'));

-- One open report per reporter per target — re-reporting updates the row
-- instead of piling up duplicates.
create unique index if not exists reports_reporter_target_unique
  on public.reports (reporter_id, target_type, target_id);

-- The client reports via upsert (INSERT ... ON CONFLICT DO UPDATE), so an UPDATE
-- policy is required for a re-report to land instead of being denied by RLS.
drop policy if exists "Update own reports" on public.reports;
create policy "Update own reports" on public.reports
  for update to authenticated
  using ((select auth.uid()) = reporter_id)
  with check ((select auth.uid()) = reporter_id);

-- Keep updated_at fresh on re-report.
create or replace function public.touch_reports_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke execute on function public.touch_reports_updated_at() from public, anon, authenticated;

drop trigger if exists reports_touch_updated_at on public.reports;
create trigger reports_touch_updated_at
  before update on public.reports
  for each row execute function public.touch_reports_updated_at();
