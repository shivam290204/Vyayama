-- 014: BMI and weight historical tracking with Row Level Security.

create table if not exists public.bmi_records (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  weight_kg numeric(5,2) not null check (weight_kg > 0),
  height_cm numeric(5,1) not null check (height_cm > 0),
  bmi numeric(4,1) not null check (bmi > 0),
  recorded_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bmi_records enable row level security;

create policy "read own bmi records" on public.bmi_records
  for select to authenticated
  using (auth.uid() = user_id);

create policy "insert own bmi records" on public.bmi_records
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "update own bmi records" on public.bmi_records
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "delete own bmi records" on public.bmi_records
  for delete to authenticated
  using (auth.uid() = user_id);

create index if not exists idx_bmi_records_user_recorded
  on public.bmi_records(user_id, recorded_at desc);
