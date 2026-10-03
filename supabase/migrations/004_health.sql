-- 004: health conditions and medicine reminders.
-- Medicines store name and reminder times only: no dosage or advice fields.

create table public.user_conditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  condition_key text not null
);

create table public.medicines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  reminder_times time[] not null,
  is_active boolean default true
);

do $$
declare
  t text;
begin
  foreach t in array array['user_conditions', 'medicines'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated '
      'using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end
$$;
