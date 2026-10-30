-- 019: Outdoor Activities and Saved Routes for Vyayama Maps
-- Additive migration: persists GPS activity recordings and user saved routes with Row Level Security.

-- ============================================================================
-- 1. OUTDOOR ACTIVITIES TABLE
-- ============================================================================
create table if not exists public.outdoor_activities (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_type text not null default 'walk',
  start_time timestamptz not null default now(),
  end_time timestamptz not null default now(),
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  distance_meters numeric(10,2) not null default 0.0 check (distance_meters >= 0),
  average_pace_sec_km integer not null default 0,
  average_speed_kmh numeric(6,2) not null default 0.0,
  points jsonb not null default '[]'::jsonb,
  elevation_gain_meters numeric(6,2) not null default 0.0,
  calories_burned integer not null default 0 check (calories_burned >= 0),
  status text not null default 'completed' check (status in ('active', 'paused', 'completed', 'discarded')),
  title text not null default '',
  is_synced boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.outdoor_activities enable row level security;

create policy "read own outdoor activities" on public.outdoor_activities
  for select to authenticated
  using (auth.uid() = user_id);

create policy "insert own outdoor activities" on public.outdoor_activities
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "update own outdoor activities" on public.outdoor_activities
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "delete own outdoor activities" on public.outdoor_activities
  for delete to authenticated
  using (auth.uid() = user_id);

create index if not exists idx_outdoor_activities_user_start
  on public.outdoor_activities(user_id, start_time desc);

-- ============================================================================
-- 2. SAVED ROUTES TABLE
-- ============================================================================
create table if not exists public.saved_routes (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  activity_type text not null default 'walk',
  distance_meters numeric(10,2) not null default 0.0 check (distance_meters >= 0),
  estimated_duration_sec integer not null default 0 check (estimated_duration_sec >= 0),
  difficulty text not null default 'easy' check (difficulty in ('easy', 'moderate', 'hard')),
  points jsonb not null default '[]'::jsonb,
  elevation_gain_meters numeric(6,2) not null default 0.0,
  surface_type text not null default 'paved' check (surface_type in ('paved', 'trail', 'mixed')),
  elevation_profile text not null default 'flat' check (elevation_profile in ('flat', 'moderate', 'hilly')),
  description text not null default '',
  is_saved_by_user boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.saved_routes enable row level security;

create policy "read own saved routes" on public.saved_routes
  for select to authenticated
  using (auth.uid() = user_id);

create policy "insert own saved routes" on public.saved_routes
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "update own saved routes" on public.saved_routes
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "delete own saved routes" on public.saved_routes
  for delete to authenticated
  using (auth.uid() = user_id);

create index if not exists idx_saved_routes_user_created
  on public.saved_routes(user_id, created_at desc);

