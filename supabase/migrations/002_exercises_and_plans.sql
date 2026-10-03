-- 002: exercise library and workout plans.

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  muscle_group text,
  equipment text,
  instructions text,
  animation_asset text,
  contraindications text[] default '{}',
  created_at timestamptz default now()
);

create table public.workout_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  goal text,
  level text,
  is_system boolean default false,
  owner_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now()
);

create table public.plan_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.workout_plans(id) on delete cascade,
  day_number int not null,
  name text
);

create table public.plan_exercises (
  id uuid primary key default gen_random_uuid(),
  plan_day_id uuid references public.plan_days(id) on delete cascade,
  exercise_id uuid references public.exercises(id),
  sort_order int default 0,
  sets int,
  reps int,
  duration_sec int,
  rest_sec int default 45
);

alter table public.exercises enable row level security;
alter table public.workout_plans enable row level security;
alter table public.plan_days enable row level security;
alter table public.plan_exercises enable row level security;

-- System data: read-only for signed-in users (seed with the service role).
create policy "read exercises" on public.exercises
  for select to authenticated using (true);

-- Plans: read system plans and own plans; write only own custom plans.
create policy "read plans" on public.workout_plans
  for select to authenticated
  using (is_system = true or owner_id = auth.uid());

create policy "insert own plans" on public.workout_plans
  for insert to authenticated
  with check (owner_id = auth.uid() and is_system = false);

create policy "update own plans" on public.workout_plans
  for update to authenticated
  using (owner_id = auth.uid() and is_system = false)
  with check (owner_id = auth.uid() and is_system = false);

create policy "delete own plans" on public.workout_plans
  for delete to authenticated
  using (owner_id = auth.uid() and is_system = false);

-- Days and exercises follow the parent plan's rules.
-- The sub-selects run with the caller's RLS, so readable plans = readable days.
create policy "read plan days" on public.plan_days
  for select to authenticated
  using (exists (
    select 1 from public.workout_plans p where p.id = plan_days.plan_id
  ));

create policy "write own plan days" on public.plan_days
  for all to authenticated
  using (exists (
    select 1 from public.workout_plans p
    where p.id = plan_days.plan_id
      and p.owner_id = auth.uid() and p.is_system = false
  ))
  with check (exists (
    select 1 from public.workout_plans p
    where p.id = plan_days.plan_id
      and p.owner_id = auth.uid() and p.is_system = false
  ));

create policy "read plan exercises" on public.plan_exercises
  for select to authenticated
  using (exists (
    select 1 from public.plan_days d where d.id = plan_exercises.plan_day_id
  ));

create policy "write own plan exercises" on public.plan_exercises
  for all to authenticated
  using (exists (
    select 1
    from public.plan_days d
    join public.workout_plans p on p.id = d.plan_id
    where d.id = plan_exercises.plan_day_id
      and p.owner_id = auth.uid() and p.is_system = false
  ))
  with check (exists (
    select 1
    from public.plan_days d
    join public.workout_plans p on p.id = d.plan_id
    where d.id = plan_exercises.plan_day_id
      and p.owner_id = auth.uid() and p.is_system = false
  ));
