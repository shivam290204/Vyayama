-- ============================================================================
-- FITBUDDY: Fix Friend Requests, Sender Names, and Profiles Resolution
-- ============================================================================
-- Run this script in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/dkhazruvustwmudjxiro/sql/new
--
-- This script:
-- 1. Updates Row Level Security (RLS) on public.profiles so pending and accepted
--    friends can see each other's name, username, and avatar.
-- 2. Creates get_my_friend_requests() to return sender details (name, @username).
-- 3. Creates find_profile_by_identifier() and find_profile_by_user_id().
-- 4. Updates friend_profiles view to include pending friend requests.
-- ============================================================================

-- 1. Update RLS policies on public.profiles
alter table public.profiles enable row level security;

drop policy if exists "own profile" on public.profiles;
drop policy if exists "friends and snap contacts can view profiles" on public.profiles;
drop policy if exists "users can view own profile and friend profiles" on public.profiles;

create policy "users can view own profile and friend profiles" on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.friendships f
      where (f.requester_id = auth.uid() and f.addressee_id = profiles.id)
         or (f.addressee_id = auth.uid() and f.requester_id = profiles.id)
    )
  );

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "insert own profile" on public.profiles;
create policy "insert own profile" on public.profiles
  for insert to authenticated
  with check (auth.uid() = id);

-- 2. Update friend_profiles view
drop view if exists public.friend_profiles cascade;

create view public.friend_profiles as
select p.id, p.username, p.name, p.avatar_url, p.timezone
from public.profiles p
where p.id = auth.uid()
   or public.are_friends(auth.uid(), p.id)
   or exists (
     select 1 from public.friendships f
     where f.status = 'pending'
       and ((f.requester_id = auth.uid() and f.addressee_id = p.id)
         or (f.addressee_id = auth.uid() and f.requester_id = p.id))
   );

revoke all on public.friend_profiles from public, anon;
grant select on public.friend_profiles to authenticated;

-- 3. find_profile_by_user_id RPC
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

  return query
  select p.id, p.username, p.name, p.avatar_url, p.timezone
  from public.profiles p
  where p.id = p_user_id;
end;
$$;

revoke all on function public.find_profile_by_user_id(uuid) from public, anon;
grant execute on function public.find_profile_by_user_id(uuid) to authenticated;

-- 4. find_profile_by_identifier RPC (resolves UUID, @username, or invite token)
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
    where p.id = v_uuid;
    return;
  end if;

  return query
  select p.id, p.username, p.name, p.avatar_url, p.timezone
  from public.profiles p
  where (lower(trim(p.username)) = v_clean or p.invite_token = trim(p_query));
end;
$$;

revoke all on function public.find_profile_by_identifier(text) from public, anon;
grant execute on function public.find_profile_by_identifier(text) to authenticated;

-- 5. check_username_available RPC
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
    where lower(trim(p.username)) = v_clean
      and (v_uid is null or p.id <> v_uid)
  );
end;
$$;

revoke all on function public.check_username_available(text) from public, anon;
grant execute on function public.check_username_available(text) to authenticated, anon;

-- 6. get_my_friend_requests RPC (Returns incoming & outgoing pending requests with names)
create or replace function public.get_my_friend_requests()
returns table (
  id uuid,
  requester_id uuid,
  addressee_id uuid,
  status text,
  created_at timestamptz,
  other_id uuid,
  other_username text,
  other_name text,
  other_avatar_url text,
  other_timezone text,
  is_incoming boolean
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  return query
  select
    f.id,
    f.requester_id,
    f.addressee_id,
    f.status,
    f.created_at,
    p.id as other_id,
    coalesce(nullif(trim(p.username), ''), '') as other_username,
    coalesce(nullif(trim(p.name), ''), nullif(trim(p.username), ''), 'Friend') as other_name,
    p.avatar_url as other_avatar_url,
    coalesce(p.timezone, 'UTC') as other_timezone,
    (f.addressee_id = v_uid) as is_incoming
  from public.friendships f
  join public.profiles p
    on p.id = (case when f.addressee_id = v_uid then f.requester_id else f.addressee_id end)
  where f.status = 'pending'
    and (f.requester_id = v_uid or f.addressee_id = v_uid)
  order by f.created_at desc;
end;
$$;

revoke all on function public.get_my_friend_requests() from public, anon;
grant execute on function public.get_my_friend_requests() to authenticated;

-- 7. send_friend_request RPC (Prevents duplicates and handles reversals)
create or replace function public.send_friend_request(p_addressee_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_existing record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if p_addressee_id = v_uid then
    raise exception 'Cannot add yourself as a friend' using errcode = '22023';
  end if;

  select * into v_existing
  from public.friendships
  where (requester_id = v_uid and addressee_id = p_addressee_id)
     or (requester_id = p_addressee_id and addressee_id = v_uid);

  if v_existing.id is not null then
    if v_existing.status = 'accepted' then
      return jsonb_build_object('status', 'accepted', 'message', 'Already friends');
    elsif v_existing.status = 'pending' and v_existing.requester_id = p_addressee_id then
      update public.friendships
      set status = 'accepted'
      where id = v_existing.id;
      return jsonb_build_object('status', 'accepted', 'message', 'Friend request accepted');
    else
      update public.friendships
      set requester_id = v_uid,
          addressee_id = p_addressee_id,
          status = 'pending',
          created_at = now()
      where id = v_existing.id;
      return jsonb_build_object('status', 'pending', 'message', 'Friend request sent');
    end if;
  else
    insert into public.friendships (requester_id, addressee_id, status)
    values (v_uid, p_addressee_id, 'pending');
    return jsonb_build_object('status', 'pending', 'message', 'Friend request sent');
  end if;
end;
$$;

revoke all on function public.send_friend_request(uuid) from public, anon;
grant execute on function public.send_friend_request(uuid) to authenticated;

-- 8. Update handle_new_user trigger to save username
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, username)
  values (
    new.id,
    nullif(trim(coalesce(
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name',
      ''
    )), ''),
    nullif(lower(trim(coalesce(
      new.raw_user_meta_data ->> 'username',
      ''
    ))), '')
  )
  on conflict (id) do update set
    username = coalesce(profiles.username, excluded.username),
    name = coalesce(profiles.name, excluded.name);
  return new;
end;
$$;
