-- ─────────────────────────────────────────────────────────────────────────────
-- Nook Plus subscription state
--
-- `is_plus` mirrors whether the user currently has an active RevenueCat "plus"
-- entitlement. It is the cross-user source for the profile Plus badge (the
-- *current* user reads their entitlement straight from the RevenueCat SDK).
--
-- Written ONLY by the `revenuecat-webhook` Edge Function (service role). The
-- moderation lockdown already revoked table-level UPDATE from `authenticated`
-- and re-granted a fixed column allowlist; these new columns are intentionally
-- left out of that allowlist, so users cannot set their own Plus status.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.user_profiles
  add column if not exists is_plus boolean not null default false,
  add column if not exists plus_expires_at timestamptz;

comment on column public.user_profiles.is_plus is
  'Active Nook Plus entitlement. Maintained by the revenuecat-webhook Edge Function; not user-writable.';
comment on column public.user_profiles.plus_expires_at is
  'When the current Nook Plus entitlement expires (from RevenueCat). NULL when not subscribed.';
