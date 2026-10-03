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
