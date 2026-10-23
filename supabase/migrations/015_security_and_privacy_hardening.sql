-- 015: Security, RLS and privacy hardening
-- 1. Restrict verify_snap to service_role (revoke client-side self-verification)
-- 2. Refine profiles RLS policies (separate SELECT, UPDATE, DELETE; remove direct INSERT)
-- 3. Hardened delete_my_account() with automatic storage object cleanup

-- ============================================================================
-- 1. SECURE verify_snap RPC
-- ============================================================================

-- Recreate verify_snap with strict service_role / admin guard and clean search_path
create or replace function public.verify_snap(
  p_snap_id uuid,
  p_activity text default 'workout',
  p_confidence numeric default 0.95
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_snap public.snaps%rowtype;
  v_events jsonb := '[]'::jsonb;
begin
  -- Strictly enforce service_role or database admin execution.
  -- Normal authenticated users cannot self-certify arbitrary snaps.
  if coalesce(auth.role(), '') <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'Unauthorized: verify_snap can only be invoked by trusted backend service role'
      using errcode = '42501';
  end if;

  select * into v_snap from public.snaps where id = p_snap_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Snap not found');
  end if;

  -- Update snap status to verified
  update public.snaps
  set verification_status = 'verified',
      verification_label = coalesce(p_activity, activity_type, 'workout'),
      verification_confidence = coalesce(p_confidence, 0.95),
      rejection_reason = null
  where id = p_snap_id;

  -- If direct snap (not story), trigger streak calculation
  if not v_snap.is_story then
    begin
      v_events := public.update_snap_streaks(p_snap_id);
    exception when others then
      v_events := '[]'::jsonb;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'status', 'verified',
    'activity', coalesce(p_activity, 'workout'),
    'confidence', coalesce(p_confidence, 0.95),
    'streak_events', v_events
  );
end;
$$;

-- Revoke execute from public, anon, and authenticated
revoke all on function public.verify_snap(uuid, text, numeric) from public, anon, authenticated;
-- Grant execute ONLY to service_role
grant execute on function public.verify_snap(uuid, text, numeric) to service_role;


-- ============================================================================
-- 2. REFINE profiles RLS POLICIES
-- ============================================================================

-- Drop the overly permissive FOR ALL policy
drop policy if exists "own profile" on public.profiles;

-- Separate SELECT policy: users can read their own profile
create policy "read own profile" on public.profiles
  for select to authenticated
  using (auth.uid() = id);

-- Separate UPDATE policy: users can update their own profile
create policy "update own profile" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Separate DELETE policy: users can delete their own profile
create policy "delete own profile" on public.profiles
  for delete to authenticated
  using (auth.uid() = id);

-- Direct client INSERT is intentionally not permitted for authenticated.
-- User profile creation is safely handled by public.handle_new_user() trigger on auth.users.


-- ============================================================================
-- 3. HARDEN delete_my_account() WITH STORAGE OBJECT CLEANUP
-- ============================================================================

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  -- 1. Cleanup storage files belonging to this user in 'snaps' and 'avatars' buckets
  begin
    delete from storage.objects
    where (bucket_id = 'snaps' or bucket_id = 'avatars')
      and (
        owner = v_uid
        or name like v_uid::text || '/%'
        or name like '%/' || v_uid::text || '/%'
      );
  exception when others then
    -- Best-effort storage cascade if running on standard Supabase schema
    null;
  end;

  -- 2. Teams only this user belongs to disappear with them.
  delete from public.teams t
  where t.owner_id = v_uid
    and not exists (
      select 1 from public.team_members m
      where m.team_id = t.id and m.user_id <> v_uid
    );

  -- 3. Other teams are handed to the longest-standing remaining member.
  update public.teams t
  set owner_id = (
    select m.user_id from public.team_members m
    where m.team_id = t.id and m.user_id <> v_uid
    order by m.joined_at
    limit 1
  )
  where t.owner_id = v_uid;

  -- 4. Cascades to profiles and all referencing database tables
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
