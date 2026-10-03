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
