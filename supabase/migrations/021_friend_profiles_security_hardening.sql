-- 021: Security hardening for friend_profiles and are_friends
-- 1. Switch public.friend_profiles view to security_invoker = true
--    Satisfies Supabase Security Advisor rule 0010_security_definer_view.
-- 2. Harden public.are_friends(a, b):
--    - Set to STABLE SECURITY INVOKER with SET search_path = ''.
--    - Satisfies Supabase Security Advisor rule 0029_authenticated_security_definer_function_executable.
--    - Enforce that authenticated callers can only query friendships where they are a participant.
--    - Prevent third-party friendship relationship probing / enumeration.
--    - Preserve service_role and postgres admin bypass for trusted backend operations.
--    - Restrict EXECUTE to authenticated and service_role.
-- 3. Correct column reference qualification on public.profiles RLS policy
--    "friends and snap contacts can view profiles" to ensure pending request partners
--    can resolve each other's profile under security_invoker = true without column shadowing.

-- ============================================================================
-- 1. HARDEN public.are_friends(uuid, uuid)
-- ============================================================================

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_uid uuid;
  v_role text;
begin
  -- Null arguments cannot form a valid friendship
  if a is null or b is null then
    return false;
  end if;

  v_role := coalesce(auth.role(), '');
  v_uid := auth.uid();

  -- Trusted service role and database superuser/admin can inspect any friendship
  if v_role = 'service_role' or current_user in ('postgres', 'supabase_admin') then
    return exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and ((f.requester_id = a and f.addressee_id = b)
          or (f.requester_id = b and f.addressee_id = a))
    );
  end if;

  -- Authenticated callers can only inspect friendships where they are a participant.
  -- This prevents arbitrary probing of third-party social graphs.
  if v_uid is distinct from a and v_uid is distinct from b then
    return false;
  end if;

  return exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
end;
$$;

-- Revoke all permissions from public and anon
revoke all on function public.are_friends(uuid, uuid) from public, anon;
-- Grant execute only to authenticated and service_role
grant execute on function public.are_friends(uuid, uuid) to authenticated, service_role;


-- ============================================================================
-- 2. UPDATE public.profiles RLS POLICY (QUALIFY profiles.id)
-- ============================================================================

-- In previous migration 013, the policy contained `f.addressee_id = id`,
-- where unqualified `id` bound to `friendships.id` (`f.id`) instead of `profiles.id`.
-- When friend_profiles operated as SECURITY DEFINER, view owner privileges masked
-- this bug. With security_invoker = true, qualifying `profiles.id` is required
-- so pending request partners can view permitted profile cards.

drop policy if exists "friends and snap contacts can view profiles" on public.profiles;

create policy "friends and snap contacts can view profiles" on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or public.are_friends(auth.uid(), id)
    or exists (
      select 1 from public.friendships f
      where f.status in ('pending', 'accepted')
        and ((f.requester_id = auth.uid() and f.addressee_id = profiles.id)
          or (f.addressee_id = auth.uid() and f.requester_id = profiles.id))
    )
    or exists (
      select 1 from public.snaps s
      join public.snap_recipients r on r.snap_id = s.id
      where (s.sender_id = profiles.id and r.recipient_id = auth.uid())
         or (s.sender_id = auth.uid() and r.recipient_id = profiles.id)
    )
    or exists (
      select 1 from public.snaps s
      where s.is_story = true
        and s.sender_id = profiles.id
        and (s.sender_id = auth.uid() or public.are_friends(auth.uid(), s.sender_id))
    )
  );


-- ============================================================================
-- 3. RECREATE public.friend_profiles WITH security_invoker = true
-- ============================================================================

drop view if exists public.friend_profiles cascade;

create view public.friend_profiles
with (security_invoker = true) as
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
grant select on public.friend_profiles to authenticated, service_role;

