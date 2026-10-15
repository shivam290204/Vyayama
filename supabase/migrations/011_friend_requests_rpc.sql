-- 011: friend requests RPCs and safe resolution
-- Provides secure endpoints for fetching pending incoming/outgoing requests
-- and sending/resending friend requests without RLS or unique constraint collisions.

-- 1. Fetch all pending friend requests for the current user
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
    coalesce(p.username, '') as other_username,
    coalesce(p.name, 'Athlete') as other_name,
    p.avatar_url as other_avatar_url,
    coalesce(p.timezone, 'UTC') as other_timezone,
    (f.addressee_id = v_uid) as is_incoming
  from public.friendships f
  join public.profiles p
    on p.id = (case when f.addressee_id = v_uid then f.requester_id else f.addressee_id end)
  where f.status = 'pending'
    and (f.requester_id = v_uid or f.addressee_id = v_uid)
    and not public.is_blocked_between(v_uid, p.id)
  order by f.created_at desc;
end;
$$;

-- 2. Send or resend a friend request safely
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
  if public.is_blocked_between(v_uid, p_addressee_id) then
    raise exception 'Unable to send friend request' using errcode = '22023';
  end if;

  select * into v_existing
  from public.friendships
  where (requester_id = v_uid and addressee_id = p_addressee_id)
     or (requester_id = p_addressee_id and addressee_id = v_uid);

  if v_existing.id is not null then
    if v_existing.status = 'accepted' then
      return jsonb_build_object('status', 'accepted', 'message', 'Already friends');
    elsif v_existing.status = 'pending' and v_existing.requester_id = p_addressee_id then
      -- The other user already sent us a request! Auto-accept into mutual friendship
      update public.friendships
      set status = 'accepted'
      where id = v_existing.id;
      return jsonb_build_object('status', 'accepted', 'message', 'Friend request accepted');
    else
      -- Resend or reactivate declined/stale request
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

-- Lock down execution to authenticated users
revoke all on function public.get_my_friend_requests() from public, anon;
revoke all on function public.send_friend_request(uuid) from public, anon;

grant execute on function public.get_my_friend_requests() to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
