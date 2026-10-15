-- ============================================================
-- Vyayama Complete Supabase Schema (All Migrations Combined)
-- Copy and run this entire file in Supabase SQL Editor
-- ============================================================

-- >>> Migration: 001_profiles_and_auth_trigger.sql <<<
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

-- >>> Migration: 002_exercises_and_plans.sql <<<
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

-- >>> Migration: 003_logs_stats_schedule_streaks_challenges.sql <<<
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

-- >>> Migration: 004_health.sql <<<
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

-- >>> Migration: 005_friendships.sql <<<
-- 005: friendships, safe user lookup, and block support.
-- Convention: a 'blocked' row always has requester_id = the blocker.

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references public.profiles(id) on delete cascade,
  addressee_id uuid references public.profiles(id) on delete cascade,
  status text default 'pending'
    check (status in ('pending','accepted','declined','blocked')),
  created_at timestamptz default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

-- Only one row per pair, regardless of direction.
create unique index friendships_pair_unique
  on public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

alter table public.friendships enable row level security;

-- Helpers are SECURITY DEFINER so policies on other tables can use them
-- without recursive RLS.
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'blocked'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

-- Users see rows they are part of, but a blocked person never sees the block.
create policy "see own friendships" on public.friendships
  for select to authenticated
  using (
    requester_id = auth.uid()
    or (addressee_id = auth.uid() and status <> 'blocked')
  );

-- A blocked user cannot send requests.
create policy "send friend request" on public.friendships
  for insert to authenticated
  with check (
    requester_id = auth.uid()
    and status = 'pending'
    and not public.is_blocked_between(requester_id, addressee_id)
  );

-- Only the addressee can accept or decline.
create policy "respond to request" on public.friendships
  for update to authenticated
  using (addressee_id = auth.uid() and status = 'pending')
  with check (addressee_id = auth.uid() and status in ('accepted','declined'));

revoke update on public.friendships from authenticated, anon;
grant update (status) on public.friendships to authenticated;

-- Either side can remove a friendship; only the blocker can lift a block.
create policy "remove friendship" on public.friendships
  for delete to authenticated
  using (
    (requester_id = auth.uid() or addressee_id = auth.uid())
    and (status <> 'blocked' or requester_id = auth.uid())
  );

-- Block a user: removes any existing relationship, then records the block.
create or replace function public.block_user(p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if p_user_id = v_uid then
    raise exception 'You cannot block yourself' using errcode = '22023';
  end if;

  delete from public.friendships
  where (requester_id = v_uid and addressee_id = p_user_id)
     or (requester_id = p_user_id and addressee_id = v_uid);

  insert into public.friendships (requester_id, addressee_id, status)
  values (v_uid, p_user_id, 'blocked');
end;
$$;

-- Search by EXACT username only. Under-18 users cannot search, cannot be
-- found by search, and users who opted out are not returned.
create or replace function public.find_profile_by_username(p_username text)
returns table (id uuid, username text, name text, avatar_url text)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_age int;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select pr.age into v_age from public.profiles pr where pr.id = v_uid;
  if coalesce(v_age, 0) < 18 then
    return;
  end if;

  return query
  select p.id, p.username, p.name, p.avatar_url
  from public.profiles p
  where p.username = lower(trim(p_username))
    and p.id <> v_uid
    and p.username_search_enabled
    and coalesce(p.age, 0) >= 18
    and not public.is_blocked_between(v_uid, p.id);
end;
$$;

-- Invite link / QR lookup by secret token (works for any age, ignores the
-- search opt-out because the owner shared the token on purpose).
create or replace function public.find_profile_by_invite_token(p_token text)
returns table (id uuid, username text, name text, avatar_url text)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  return query
  select p.id, p.username, p.name, p.avatar_url
  from public.profiles p
  where p.invite_token = trim(p_token)
    and p.id <> v_uid
    and not public.is_blocked_between(v_uid, p.id);
end;
$$;

-- Safe card for yourself and accepted friends (no weight, age, health data).
create view public.friend_profiles as
select p.id, p.username, p.name, p.avatar_url, p.timezone
from public.profiles p
where p.id = auth.uid()
   or public.are_friends(auth.uid(), p.id);

revoke all on public.friend_profiles from public, anon;
grant select on public.friend_profiles to authenticated;

-- Lock down function execution to signed-in users.
revoke all on function public.are_friends(uuid, uuid) from public, anon;
revoke all on function public.is_blocked_between(uuid, uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.find_profile_by_username(text) from public, anon;
revoke all on function public.find_profile_by_invite_token(text) from public, anon;

grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.find_profile_by_username(text) to authenticated;
grant execute on function public.find_profile_by_invite_token(text) to authenticated;

-- >>> Migration: 006_snaps_streaks_devices_reports.sql <<<
-- 006: snaps, recipients, snap_streaks (table + read policy only),
-- device tokens, reports, and the private 'snaps' storage bucket.
-- Streak WRITE logic lives in 100_snap_streak_functions.sql (Claude 5).

create table public.snaps (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles(id) on delete cascade,
  image_path text not null,                -- path in private 'snaps' bucket
  activity_type text check (activity_type in
    ('workout','running','yoga','walking','cycling','gym','stretching','sports','other_exercise')),
  caption text check (char_length(caption) <= 140),
  is_story boolean default false,          -- true = Friends Feed post
  verification_status text default 'pending'
    check (verification_status in ('pending','verified','rejected')),
  verification_label text,
  verification_confidence numeric(3,2),
  rejection_reason text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '24 hours')
);

create table public.snap_recipients (
  snap_id uuid references public.snaps(id) on delete cascade,
  recipient_id uuid references public.profiles(id) on delete cascade,
  viewed_at timestamptz,
  reaction text check (reaction is null or char_length(reaction) <= 40),
  primary key (snap_id, recipient_id)
);

-- One row per friend pair. user_a < user_b keeps the pair unique.
create table public.snap_streaks (
  id uuid primary key default gen_random_uuid(),
  user_a uuid references public.profiles(id) on delete cascade,
  user_b uuid references public.profiles(id) on delete cascade,
  current int default 0,
  longest int default 0,
  last_a_snap_date date,
  last_b_snap_date date,
  last_completed_date date,
  timezone text default 'UTC',
  created_at timestamptz default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  token text not null,
  platform text,
  updated_at timestamptz default now(),
  unique (user_id, token)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  snap_id uuid references public.snaps(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  reason text,
  status text default 'open',
  created_at timestamptz default now()
);

alter table public.snaps enable row level security;
alter table public.snap_recipients enable row level security;
alter table public.snap_streaks enable row level security;
alter table public.device_tokens enable row level security;
alter table public.reports enable row level security;

-- Clients can never change verification fields or created/expiry times.
create or replace function public.snaps_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    new.verification_status := 'pending';
    new.verification_label := null;
    new.verification_confidence := null;
    new.rejection_reason := null;
  end if;
  new.created_at := now();
  new.expires_at := now() + interval '24 hours';
  return new;
end;
$$;

create trigger snaps_before_insert
  before insert on public.snaps
  for each row execute function public.snaps_before_insert();

-- SECURITY DEFINER helpers avoid recursive RLS between snaps and recipients.
create or replace function public.is_snap_sender(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.id = p_snap_id and s.sender_id = auth.uid()
  );
$$;

create or replace function public.is_snap_recipient(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snap_recipients r
    where r.snap_id = p_snap_id and r.recipient_id = auth.uid()
  );
$$;

-- "Delivered" = verified and not expired.
create or replace function public.is_snap_live(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.id = p_snap_id
      and s.verification_status = 'verified'
      and s.expires_at > now()
  );
$$;

-- Can the caller read the storage object at this path (via signed URL)?
create or replace function public.can_read_snap_path(p_path text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.image_path = p_path
      and s.verification_status = 'verified'
      and s.expires_at > now()
      and not public.is_blocked_between(auth.uid(), s.sender_id)
      and (
        (s.is_story = false and exists (
          select 1 from public.snap_recipients r
          where r.snap_id = s.id and r.recipient_id = auth.uid()
        ))
        or (s.is_story = true and public.are_friends(auth.uid(), s.sender_id))
      )
  );
$$;

-- snaps: sender inserts/reads/deletes own; recipients read delivered snaps;
-- accepted friends read stories. No update policy: clients can never
-- change verification_status (only the service role can).
create policy "sender inserts snaps" on public.snaps
  for insert to authenticated
  with check (sender_id = auth.uid());

create policy "sender reads own snaps" on public.snaps
  for select to authenticated
  using (sender_id = auth.uid());

create policy "recipient reads delivered snaps" on public.snaps
  for select to authenticated
  using (
    is_story = false
    and verification_status = 'verified'
    and expires_at > now()
    and public.is_snap_recipient(id)
    and not public.is_blocked_between(auth.uid(), sender_id)
  );

create policy "friends read stories" on public.snaps
  for select to authenticated
  using (
    is_story = true
    and verification_status = 'verified'
    and expires_at > now()
    and public.are_friends(auth.uid(), sender_id)
  );

create policy "sender deletes own snaps" on public.snaps
  for delete to authenticated
  using (sender_id = auth.uid());

revoke update on public.snaps from authenticated, anon;

-- snap_recipients: only accepted friends (so blocked users are excluded).
create policy "read own deliveries" on public.snap_recipients
  for select to authenticated
  using (
    public.is_snap_sender(snap_id)
    or (recipient_id = auth.uid() and public.is_snap_live(snap_id))
  );

create policy "sender adds recipients" on public.snap_recipients
  for insert to authenticated
  with check (
    public.is_snap_sender(snap_id)
    and public.are_friends(auth.uid(), recipient_id)
  );

create policy "recipient updates own row" on public.snap_recipients
  for update to authenticated
  using (recipient_id = auth.uid() and public.is_snap_live(snap_id))
  with check (recipient_id = auth.uid());

revoke update on public.snap_recipients from authenticated, anon;
grant update (viewed_at, reaction) on public.snap_recipients to authenticated;

-- snap_streaks: read-only for the two members. Written only by server code.
create policy "members read streak" on public.snap_streaks
  for select to authenticated
  using (auth.uid() in (user_a, user_b));

revoke insert, update, delete on public.snap_streaks from authenticated, anon;

-- device_tokens: own rows.
create policy "own rows" on public.device_tokens
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- reports: anyone can file one, and can see only their own. Review is
-- done by admins with the service role.
create policy "file report" on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');

create policy "read own reports" on public.reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- Private storage bucket. Path format: {sender_id}/{snap_id}.jpg
-- (RLS is already enabled on storage.objects by Supabase.)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('snaps', 'snaps', false, 1048576, array['image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = 1048576,
      allowed_mime_types = array['image/jpeg'];

create policy "snaps upload own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'snaps'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Needed so recipients can create signed URLs for snaps delivered to them.
create policy "snaps read own or delivered" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'snaps'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_read_snap_path(name)
    )
  );

create policy "snaps delete own folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'snaps'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

revoke all on function public.is_snap_sender(uuid) from public, anon;
revoke all on function public.is_snap_recipient(uuid) from public, anon;
revoke all on function public.is_snap_live(uuid) from public, anon;
revoke all on function public.can_read_snap_path(text) from public, anon;

grant execute on function public.is_snap_sender(uuid) to authenticated;
grant execute on function public.is_snap_recipient(uuid) to authenticated;
grant execute on function public.is_snap_live(uuid) to authenticated;
grant execute on function public.can_read_snap_path(text) to authenticated;

-- >>> Migration: 007_teams.sql <<<
-- 007: teams. Create and join go through RPCs so invite codes stay secret
-- from non-members and the creator is always added as a member.

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text check (type in ('running','workout','walking')),
  invite_code text unique not null,
  -- set null so deleting an account never blocks on team ownership
  owner_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now()
);

create table public.team_members (
  team_id uuid references public.teams(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz default now(),
  primary key (team_id, user_id)
);

alter table public.teams enable row level security;
alter table public.team_members enable row level security;

create or replace function public.is_team_member(p_team_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = p_team_id and m.user_id = auth.uid()
  );
$$;

-- Members read their team; only the owner updates or deletes it.
-- There is no INSERT policy: use create_team() and join_team().
create policy "members read team" on public.teams
  for select to authenticated
  using (public.is_team_member(id) or owner_id = auth.uid());

create policy "owner updates team" on public.teams
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "owner deletes team" on public.teams
  for delete to authenticated
  using (owner_id = auth.uid());

create policy "members read members" on public.team_members
  for select to authenticated
  using (public.is_team_member(team_id));

-- Members can leave a team.
create policy "leave team" on public.team_members
  for delete to authenticated
  using (user_id = auth.uid());

create or replace function public.create_team(p_name text, p_type text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_code text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if p_type is null or p_type not in ('running','workout','walking') then
    raise exception 'Invalid team type' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'Team name must be 1 to 60 characters' using errcode = '22023';
  end if;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (select 1 from public.teams t where t.invite_code = v_code);
  end loop;

  insert into public.teams (name, type, invite_code, owner_id)
  values (trim(p_name), p_type, v_code, v_uid)
  returning id into v_id;

  insert into public.team_members (team_id, user_id) values (v_id, v_uid);
  return v_id;
end;
$$;

-- Joining checks the invite code. Returns the team id.
create or replace function public.join_team(p_invite_code text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_team_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select t.id into v_team_id
  from public.teams t
  where t.invite_code = upper(trim(p_invite_code));

  if v_team_id is null then
    raise exception 'Invalid invite code' using errcode = 'P0002';
  end if;

  insert into public.team_members (team_id, user_id)
  values (v_team_id, v_uid)
  on conflict do nothing;

  return v_team_id;
end;
$$;

-- Team totals per member for a date range. Members only see team aggregates,
-- never each other's raw rows.
create or replace function public.team_leaderboard(
  p_team_id uuid, p_from date, p_to date
)
returns table (
  user_id uuid, name text, username text, avatar_url text,
  steps bigint, calories bigint, active_minutes bigint, workouts bigint
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_team_member(p_team_id) then
    raise exception 'Not a member of this team' using errcode = '42501';
  end if;

  return query
  select
    m.user_id, p.name, p.username, p.avatar_url,
    coalesce((select sum(ds.steps) from public.daily_stats ds
              where ds.user_id = m.user_id and ds.date between p_from and p_to), 0)::bigint,
    coalesce((select sum(ds.calories) from public.daily_stats ds
              where ds.user_id = m.user_id and ds.date between p_from and p_to), 0)::bigint,
    coalesce((select sum(ds.active_minutes) from public.daily_stats ds
              where ds.user_id = m.user_id and ds.date between p_from and p_to), 0)::bigint,
    coalesce((select count(*) from public.workout_logs wl
              where wl.user_id = m.user_id
                and (wl.completed_at at time zone 'UTC')::date between p_from and p_to), 0)::bigint
  from public.team_members m
  join public.profiles p on p.id = m.user_id
  where m.team_id = p_team_id
  order by 5 desc, 8 desc;
end;
$$;

revoke all on function public.is_team_member(uuid) from public, anon;
revoke all on function public.create_team(text, text) from public, anon;
revoke all on function public.join_team(text) from public, anon;
revoke all on function public.team_leaderboard(uuid, date, date) from public, anon;

grant execute on function public.is_team_member(uuid) to authenticated;
grant execute on function public.create_team(text, text) to authenticated;
grant execute on function public.join_team(text) to authenticated;
grant execute on function public.team_leaderboard(uuid, date, date) to authenticated;

-- >>> Migration: 008_account_deletion.sql <<<
-- 008: delete_my_account().
-- Deletes the caller's auth user; every user table cascades from profiles.
--
-- IMPORTANT (storage): Supabase blocks deleting storage files with SQL.
-- The app must FIRST remove the user's files with the Storage API:
--   1. select image_path from snaps where sender_id = <me>
--   2. supabase.storage.from('snaps').remove(paths)
--   3. supabase.rpc('delete_my_account')
-- (A server-side Edge Function doing the same with the service role is the
-- more robust option if you prefer it.)

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  -- Teams only this user belongs to disappear with them.
  delete from public.teams t
  where t.owner_id = v_uid
    and not exists (
      select 1 from public.team_members m
      where m.team_id = t.id and m.user_id <> v_uid
    );

  -- Other teams are handed to the longest-standing remaining member.
  update public.teams t
  set owner_id = (
    select m.user_id from public.team_members m
    where m.team_id = t.id and m.user_id <> v_uid
    order by m.joined_at
    limit 1
  )
  where t.owner_id = v_uid;

  -- Cascades to profiles and everything that references it.
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- >>> Migration: 009_indexes.sql <<<
-- 009: indexes on foreign keys and (user_id, date) lookups.
-- Already covered by constraints, so not repeated here:
--   daily_stats (user_id, date)          -> unique constraint
--   challenge_completions (user_id, date)-> unique constraint
--   block_completions (block_id, date)   -> unique constraint
--   snap_recipients (snap_id, ...)       -> primary key
--   team_members (team_id, ...)          -> primary key
--   device_tokens (user_id, ...)         -> unique constraint
--   snap_streaks (user_a, ...)           -> unique constraint

create index if not exists workout_plans_owner_idx on public.workout_plans (owner_id);
create index if not exists plan_days_plan_idx on public.plan_days (plan_id);
create index if not exists plan_exercises_day_idx on public.plan_exercises (plan_day_id);
create index if not exists plan_exercises_exercise_idx on public.plan_exercises (exercise_id);

create index if not exists workout_logs_user_completed_idx
  on public.workout_logs (user_id, completed_at desc);
create index if not exists workout_logs_plan_day_idx on public.workout_logs (plan_day_id);

create index if not exists schedule_blocks_user_idx on public.schedule_blocks (user_id);
create index if not exists block_completions_user_date_idx
  on public.block_completions (user_id, date);
create index if not exists challenge_completions_challenge_idx
  on public.challenge_completions (challenge_id);

create index if not exists user_conditions_user_idx on public.user_conditions (user_id);
create index if not exists medicines_user_idx on public.medicines (user_id);

create index if not exists friendships_requester_idx on public.friendships (requester_id);
create index if not exists friendships_addressee_idx on public.friendships (addressee_id);

create unique index if not exists snaps_image_path_key on public.snaps (image_path);
create index if not exists snaps_sender_created_idx on public.snaps (sender_id, created_at desc);
create index if not exists snaps_expires_idx on public.snaps (expires_at);
create index if not exists snap_recipients_recipient_idx on public.snap_recipients (recipient_id);
create index if not exists snap_streaks_user_b_idx on public.snap_streaks (user_b);

create index if not exists reports_reporter_idx on public.reports (reporter_id);
create index if not exists reports_snap_idx on public.reports (snap_id);
create index if not exists reports_reported_user_idx on public.reports (reported_user_id);

create index if not exists teams_owner_idx on public.teams (owner_id);
create index if not exists team_members_user_idx on public.team_members (user_id);

-- >>> Migration: 100_snap_streak_functions.sql <<<
-- 100_snap_streak_functions.sql
-- Server-side Snap Streak logic (spec section 9.6). Mirrors
-- lib/features/snap_streaks/data/snap_streak_calculator.dart. Keep both in sync.
--
-- Assumes the tables from spec section 8 exist (profiles, friendships, snaps,
-- snap_recipients, snap_streaks). The optional `streaks` table (XP) is used
-- only if it exists.

-- ---------------------------------------------------------------------------
-- Lock down snap_streaks: members may read, nobody on the client may write.
-- ---------------------------------------------------------------------------
alter table snap_streaks enable row level security;

drop policy if exists "members read pair streak" on snap_streaks;
create policy "members read pair streak" on snap_streaks
  for select using (auth.uid() = user_a or auth.uid() = user_b);

-- No insert/update/delete policies exist, so RLS denies them. Also revoke the
-- table privileges as defence in depth.
revoke insert, update, delete on snap_streaks from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Clients can never change verification fields on snaps.
-- ---------------------------------------------------------------------------
create or replace function protect_snap_verification() returns trigger
language plpgsql as $$
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.verification_status := 'pending';
      new.verification_label := null;
      new.verification_confidence := null;
      new.rejection_reason := null;
    elsif new.verification_status is distinct from old.verification_status
       or new.verification_label is distinct from old.verification_label
       or new.verification_confidence is distinct from old.verification_confidence
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'verification fields are server-only';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists snaps_protect_verification on snaps;
create trigger snaps_protect_verification
  before insert or update on snaps
  for each row execute function protect_snap_verification();

-- ---------------------------------------------------------------------------
-- Helper: a valid timezone name, falling back to UTC.
-- ---------------------------------------------------------------------------
create or replace function safe_timezone(tz text) returns text
language sql stable as $$
  select coalesce(
    (select name from pg_timezone_names where name = tz limit 1),
    'UTC');
$$;

-- ---------------------------------------------------------------------------
-- update_snap_streaks(snap_id)
-- Call when a snap becomes `verified`. Returns a jsonb array of events the
-- Edge Function turns into push notifications:
--   { sender_id, recipient_id, event, current, milestone }
--   event: 'nudge' | 'completed' | 'already_completed'
-- ---------------------------------------------------------------------------
create or replace function update_snap_streaks(p_snap_id uuid) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_snap snaps%rowtype;
  v_row snap_streaks%rowtype;
  r record;
  v_a uuid;
  v_b uuid;
  v_tz text;
  v_today date;
  v_new int;
  v_event text;
  v_milestone int;
  v_events jsonb := '[]'::jsonb;
begin
  select * into v_snap from snaps where id = p_snap_id;
  if not found
     or v_snap.verification_status <> 'verified'
     or v_snap.is_story then
    return v_events;
  end if;

  for r in select recipient_id from snap_recipients where snap_id = p_snap_id loop
    -- Only accepted friends take part in a pair streak.
    if not exists (
      select 1 from friendships f
      where f.status = 'accepted'
        and ((f.requester_id = v_snap.sender_id and f.addressee_id = r.recipient_id)
          or (f.requester_id = r.recipient_id and f.addressee_id = v_snap.sender_id))
    ) then
      continue;
    end if;

    v_a := least(v_snap.sender_id, r.recipient_id);
    v_b := greatest(v_snap.sender_id, r.recipient_id);

    -- The pair timezone is the timezone of whoever started the streak.
    insert into snap_streaks (user_a, user_b, timezone)
    values (v_a, v_b,
      safe_timezone((select timezone from profiles where id = v_snap.sender_id)))
    on conflict (user_a, user_b) do nothing;

    select * into v_row from snap_streaks
      where user_a = v_a and user_b = v_b for update;

    v_tz := safe_timezone(v_row.timezone);
    v_today := (now() at time zone v_tz)::date;

    if v_snap.sender_id = v_a then
      v_row.last_a_snap_date := v_today;
    else
      v_row.last_b_snap_date := v_today;
    end if;

    v_milestone := null;

    if v_row.last_a_snap_date = v_today and v_row.last_b_snap_date = v_today then
      if v_row.last_completed_date = v_today then
        v_event := 'already_completed';
      else
        if v_row.last_completed_date = v_today - 1 then
          v_new := v_row.current + 1;
        else
          v_new := 1; -- new or restarted
        end if;
        v_row.current := v_new;
        v_row.longest := greatest(v_row.longest, v_new);
        v_row.last_completed_date := v_today;
        v_event := 'completed';

        if v_new in (3, 7, 14, 30, 50, 100) then
          v_milestone := v_new;
          -- Milestone reward: XP. Badges are derived from `longest` on the client.
          if to_regclass('public.streaks') is not null then
            execute 'insert into streaks (user_id, xp) values ($1, $3), ($2, $3)
                     on conflict (user_id) do update set xp = streaks.xp + excluded.xp'
              using v_a, v_b, v_new * 5;
          end if;
        end if;
      end if;
    else
      v_event := 'nudge';
    end if;

    update snap_streaks set
      current = v_row.current,
      longest = v_row.longest,
      last_a_snap_date = v_row.last_a_snap_date,
      last_b_snap_date = v_row.last_b_snap_date,
      last_completed_date = v_row.last_completed_date
    where id = v_row.id;

    v_events := v_events || jsonb_build_object(
      'sender_id', v_snap.sender_id,
      'recipient_id', r.recipient_id,
      'event', v_event,
      'current', v_row.current,
      'milestone', v_milestone);
  end loop;

  return v_events;
end $$;

revoke all on function update_snap_streaks(uuid) from public, anon, authenticated;
grant execute on function update_snap_streaks(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- reset_expired_streaks()  (run hourly)
-- Resets streaks after a full missed day and returns streaks that just entered
-- the 4-hour warning window. The window is (3h, 4h] so that an hourly job
-- reports each pair exactly once per day. Returns:
--   { reset: n, at_risk: [ { user_id, partner_id, current } ] }
-- ---------------------------------------------------------------------------
create or replace function reset_expired_streaks() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_tz text;
  v_local timestamp;
  v_today date;
  v_hours_left numeric;
  v_reset int := 0;
  v_at_risk jsonb := '[]'::jsonb;
begin
  for r in select * from snap_streaks where current > 0 for update loop
    v_tz := safe_timezone(r.timezone);
    v_local := now() at time zone v_tz;
    v_today := v_local::date;

    if r.last_completed_date is null or v_today - r.last_completed_date >= 2 then
      update snap_streaks set current = 0 where id = r.id;
      v_reset := v_reset + 1;
    elsif r.last_completed_date <> v_today then
      v_hours_left := extract(epoch from
        (date_trunc('day', v_local) + interval '1 day') - v_local) / 3600;
      if v_hours_left <= 4 and v_hours_left > 3 then
        -- Warn whoever has not sent yet today.
        if r.last_a_snap_date is distinct from v_today then
          v_at_risk := v_at_risk || jsonb_build_object(
            'user_id', r.user_a, 'partner_id', r.user_b, 'current', r.current);
        end if;
        if r.last_b_snap_date is distinct from v_today then
          v_at_risk := v_at_risk || jsonb_build_object(
            'user_id', r.user_b, 'partner_id', r.user_a, 'current', r.current);
        end if;
      end if;
    end if;
  end loop;

  return jsonb_build_object('reset', v_reset, 'at_risk', v_at_risk);
end $$;

revoke all on function reset_expired_streaks() from public, anon, authenticated;
grant execute on function reset_expired_streaks() to service_role;

-- ---------------------------------------------------------------------------
-- delete_expired_snaps()  (run hourly)
-- Deletes expired snap rows (snap_recipients cascade) and returns their image
-- paths so the Edge Function can remove the files from Storage. Deleting
-- storage.objects rows from SQL would leave the files behind, so schedule the
-- Edge Function job `cleanup`, not this function directly.
-- Only metadata kept for streaks (snap_streaks) is untouched.
-- ---------------------------------------------------------------------------
create or replace function delete_expired_snaps() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paths jsonb;
begin
  select coalesce(jsonb_agg(image_path), '[]'::jsonb) into v_paths
  from snaps where expires_at < now();

  delete from snaps where expires_at < now();
  return v_paths;
end $$;

revoke all on function delete_expired_snaps() from public, anon, authenticated;
grant execute on function delete_expired_snaps() to service_role;

-- ---------------------------------------------------------------------------
-- Scheduling with pg_cron + pg_net (run once in the SQL editor, replacing
-- <PROJECT_REF> and <CRON_SECRET>; store the secret in Vault in production).
-- The Edge Function `verify-snap` handles both jobs when the body has `job`.
--
-- select cron.schedule('snap-streak-maintenance', '0 * * * *', $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/verify-snap',
--     headers := jsonb_build_object('Content-Type', 'application/json',
--                                   'x-cron-secret', '<CRON_SECRET>'),
--     body := '{"job":"streak_maintenance"}'::jsonb);
-- $$);
--
-- select cron.schedule('snap-cleanup', '15 * * * *', $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/verify-snap',
--     headers := jsonb_build_object('Content-Type', 'application/json',
--                                   'x-cron-secret', '<CRON_SECRET>'),
--     body := '{"job":"cleanup"}'::jsonb);
-- $$);
-- ---------------------------------------------------------------------------
-- 010: Friend QR code and profile lookup RPCs
-- ---------------------------------------------------------------------------

create or replace function public.find_profile_by_user_id(p_user_id uuid)
returns table (id uuid, username text, name text, avatar_url text, timezone text)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_user_id <> v_uid and public.is_blocked_between(v_uid, p_user_id) then
    return;
  end if;

  return query
  select p.id, p.username, p.name, p.avatar_url, p.timezone
  from public.profiles p
  where p.id = p_user_id;
end;
$$;

create or replace function public.find_profile_by_identifier(p_query text)
returns table (id uuid, username text, name text, avatar_url text, timezone text)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_clean text := lower(trim(p_query));
  v_uuid uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if v_clean is null or v_clean = '' then
    return;
  end if;

  if starts_with(v_clean, '@') then
    v_clean := substring(v_clean from 2);
  end if;

  begin
    v_uuid := v_clean::uuid;
  exception when others then
    v_uuid := null;
  end;

  if v_uuid is not null then
    return query
    select p.id, p.username, p.name, p.avatar_url, p.timezone
    from public.profiles p
    where p.id = v_uuid
      and not (v_uuid <> v_uid and public.is_blocked_between(v_uid, v_uuid));
    return;
  end if;

  return query
  select p.id, p.username, p.name, p.avatar_url, p.timezone
  from public.profiles p
  where (p.username = v_clean or p.invite_token = trim(p_query))
    and not (p.id <> v_uid and public.is_blocked_between(v_uid, p.id));
end;
$$;

create or replace function public.check_username_available(p_username text)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_clean text := lower(trim(p_username));
begin
  if v_clean is null or v_clean = '' then
    return false;
  end if;

  if not (v_clean ~ '^[a-z0-9_]{3,20}$') then
    return false;
  end if;

  return not exists (
    select 1 from public.profiles p
    where p.username = v_clean
      and (v_uid is null or p.id <> v_uid)
  );
end;
$$;

revoke all on function public.find_profile_by_user_id(uuid) from public, anon;
revoke all on function public.find_profile_by_identifier(text) from public, anon;
revoke all on function public.check_username_available(text) from public, anon;

grant execute on function public.find_profile_by_user_id(uuid) to authenticated;
grant execute on function public.find_profile_by_identifier(text) to authenticated;
grant execute on function public.check_username_available(text) to authenticated, anon;
