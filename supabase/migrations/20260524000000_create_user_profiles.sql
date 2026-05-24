-- User profiles table for onboarding data and preferences
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  interests text[] not null default '{}',
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable RLS
alter table public.user_profiles enable row level security;

-- Users can read their own profile
create policy "Users can read own profile"
  on public.user_profiles for select
  using (auth.uid() = id);

-- Users can insert their own profile
create policy "Users can insert own profile"
  on public.user_profiles for insert
  with check (auth.uid() = id);

-- Users can update their own profile
create policy "Users can update own profile"
  on public.user_profiles for update
  using (auth.uid() = id);

-- Auto-update updated_at on changes
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger on_user_profiles_updated
  before update on public.user_profiles
  for each row
  execute function public.handle_updated_at();
