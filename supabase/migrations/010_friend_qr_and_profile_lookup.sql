-- 010: friend QR code and profile lookup RPCs.
-- Allows authenticated users to safely look up public profile cards (id, username, name, avatar_url)
-- by user ID, invite token, or username without exposing private profile fields.

-- 1. Find profile by user ID (for QR codes and deep links: https://vyayama.app/u/{user_id})
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

  -- Blocked users cannot view each other's profiles
  if p_user_id <> v_uid and public.is_blocked_between(v_uid, p_user_id) then
    return;
  end if;

  return query
  select p.id, p.username, p.name, p.avatar_url, p.timezone
  from public.profiles p
  where p.id = p_user_id;
end;
$$;

-- 2. Unified identifier lookup (UUID, username, or invite_token)
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

  -- Strip leading '@' if present
  if starts_with(v_clean, '@') then
    v_clean := substring(v_clean from 2);
  end if;

  -- Try parsing as UUID
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

  -- Match by username or invite_token
  return query
  select p.id, p.username, p.name, p.avatar_url, p.timezone
  from public.profiles p
  where (p.username = v_clean or p.invite_token = trim(p_query))
    and not (p.id <> v_uid and public.is_blocked_between(v_uid, p.id));
end;
$$;

-- 3. Check if a username is available for registration / profile update
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

  -- Must match username regex
  if not (v_clean ~ '^[a-z0-9_]{3,20}$') then
    return false;
  end if;

  -- Check if another user has this username
  return not exists (
    select 1 from public.profiles p
    where p.username = v_clean
      and (v_uid is null or p.id <> v_uid)
  );
end;
$$;

-- 4. Update handle_new_user trigger to save username if provided in metadata
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

-- Lock down execution to authenticated users
revoke all on function public.find_profile_by_user_id(uuid) from public, anon;
revoke all on function public.find_profile_by_identifier(text) from public, anon;
revoke all on function public.check_username_available(text) from public, anon;

grant execute on function public.find_profile_by_user_id(uuid) to authenticated;
grant execute on function public.find_profile_by_identifier(text) to authenticated;
grant execute on function public.check_username_available(text) to authenticated, anon;
