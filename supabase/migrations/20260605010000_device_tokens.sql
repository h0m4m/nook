-- APNs device tokens for push delivery (Phase 4).
--
-- One row per device token. `token` is globally unique: if a device is re-used by a
-- different account (sign out -> sign in), the client upserts on `token` and the row
-- moves to the new user, so we never push to the wrong account. The `send-push` edge
-- function reads this table (service role) to fan a notification out to a user's
-- devices, and deletes rows APNs reports as stale (410 / BadDeviceToken).
create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  token       text not null unique,
  platform    text not null default 'ios',
  environment text not null default 'sandbox',   -- 'sandbox' | 'production' (matches aps-environment)
  app_version text,
  locale      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Users only ever see/manage their own device tokens. The edge function uses the
-- service role key and bypasses this.
drop policy if exists "Users manage own device tokens" on public.device_tokens;
create policy "Users manage own device tokens"
  on public.device_tokens
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
