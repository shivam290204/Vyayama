-- 001: profiles, RLS, and the auto-create trigger on auth.users.
-- Friends/snaps columns (username, avatar_url, timezone) are created here
-- instead of via a later ALTER, plus two safety columns (see notes).

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  age int check (age between 13 and 100),
  gender text check (gender in ('male','female','other')),
  weight_kg numeric(5,2),
  height_cm numeric(5,1),
  goal text check (goal in ('lose','gain','maintain')),
  fitness_level text default 'beginner',
  wake_time time,
  sleep_time time,
  work_start time,
  work_end time,
  onboarding_completed boolean not null default false,
  username text unique
    check (username is null or username ~ '^[a-z0-9_]{3,20}$'),
  avatar_url text,
  timezone text default 'UTC',
  -- Spec section 12: users may choose to be added only by invite link / QR.
  username_search_enabled boolean not null default true,
  -- Secret token carried by invite links and QR codes.
  invite_token text not null unique
    default substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "own profile" on public.profiles
  for all to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Create a profile row automatically when a user signs up.
-- The app passes the name as sign-up metadata: data: {'name': name}.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    nullif(trim(coalesce(
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name',
      ''
    )), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
