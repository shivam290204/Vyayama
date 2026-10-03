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
