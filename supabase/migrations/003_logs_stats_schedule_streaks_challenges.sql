-- 003: workout logs, daily stats, schedule, streaks, challenges.

create table public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  -- set null so deleting a custom plan never fails because of old logs
  plan_day_id uuid references public.plan_days(id) on delete set null,
  completed_at timestamptz default now(),
  duration_min int,
  calories_burned int
);

create table public.daily_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  date date not null,
  steps int default 0,
  calories int default 0,
  active_minutes int default 0,
  unique (user_id, date)
);

create table public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  type text check (type in ('workout','meal','medicine','sleep','wake','custom')),
  title text,
  start_time time not null,
  days_of_week int[] default '{1,2,3,4,5,6,7}',
  is_active boolean default true
);

create table public.block_completions (
  id uuid primary key default gen_random_uuid(),
  block_id uuid references public.schedule_blocks(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  date date not null,
  status text check (status in ('done','missed','skipped')),
  unique (block_id, date)
);

create table public.streaks (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current int default 0,
  longest int default 0,
  last_active_date date,
  xp int default 0
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  type text,
  target_value int,
  xp int default 10
);

create table public.challenge_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  challenge_id uuid references public.challenges(id),
  date date not null,
  unique (user_id, date)
);

-- "Own rows" policy for every table that has a user_id column.
do $$
declare
  t text;
begin
  foreach t in array array[
    'workout_logs', 'daily_stats', 'schedule_blocks',
    'streaks', 'challenge_completions'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated '
      'using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end
$$;

-- A completion must point at one of the caller's own blocks.
alter table public.block_completions enable row level security;

create policy "own block completions" on public.block_completions
  for all to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.schedule_blocks b
      where b.id = block_completions.block_id and b.user_id = auth.uid()
    )
  );

-- System data: read-only for signed-in users.
alter table public.challenges enable row level security;

create policy "read challenges" on public.challenges
  for select to authenticated using (true);
