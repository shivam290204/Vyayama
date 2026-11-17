-- 101_reinstate_snap_verification_and_streaks.sql
-- Reinstates hardened definitions clobbered by 100_snap_streak_functions.sql:
-- 1. Ensures uuid-ossp extension is enabled in the extensions schema.
-- 2. Restores protect_snap_verification() trigger function with trusted postgres/service_role bypass (from 013).
-- 3. Restores update_snap_streaks() with the 6-hour streak verification delay grace window and milestone XP (from 016).

-- ---------------------------------------------------------------------------
-- 1. Ensure uuid-ossp extension is active in extensions schema
-- ---------------------------------------------------------------------------
create extension if not exists "uuid-ossp" with schema extensions;

-- ---------------------------------------------------------------------------
-- 2. Reinstate protect_snap_verification() trigger function (from 013)
-- Allows updates when executed via trusted server roles (service_role) or
-- SECURITY DEFINER RPC functions (postgres / supabase_admin like appeal_snap / verify_snap),
-- while strictly preventing unauthorized direct client updates on verification fields.
-- ---------------------------------------------------------------------------
create or replace function public.protect_snap_verification()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Allow trusted server contexts and SECURITY DEFINER RPC functions
  if current_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;

  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      if new.verification_status is null then
        new.verification_status := 'pending';
      end if;
    elsif new.verification_status is distinct from old.verification_status
       or new.verification_label is distinct from old.verification_label
       or new.verification_confidence is distinct from old.verification_confidence
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'verification fields are server-only';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists snaps_protect_verification on public.snaps;
create trigger snaps_protect_verification
  before insert or update on public.snaps
  for each row execute function public.protect_snap_verification();

-- ---------------------------------------------------------------------------
-- 3. Reinstate update_snap_streaks() with 6-Hour Delay Grace Window (from 016)
-- Backdates effective streak credit if a snap was submitted before midnight
-- but verified by Edge Functions or appeal before 06:00 AM local time.
-- ---------------------------------------------------------------------------
create or replace function public.update_snap_streaks(p_snap_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_snap public.snaps%rowtype;
  v_row public.snap_streaks%rowtype;
  r record;
  v_a uuid;
  v_b uuid;
  v_tz text;
  v_today date;
  v_snap_created_local date;
  v_current_local_time time;
  v_effective_date date;
  v_new int;
  v_event text;
  v_milestone int;
  v_events jsonb := '[]'::jsonb;
begin
  select * into v_snap from public.snaps where id = p_snap_id;
  -- Streaks ONLY increment for strictly 'verified' snaps (appealed snaps give no streak credit)
  if not found
     or v_snap.verification_status <> 'verified'
     or v_snap.is_story then
    return v_events;
  end if;

  for r in select recipient_id from public.snap_recipients where snap_id = p_snap_id loop
    if not exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and ((f.requester_id = v_snap.sender_id and f.addressee_id = r.recipient_id)
          or (f.requester_id = r.recipient_id and f.addressee_id = v_snap.sender_id))
    ) then
      continue;
    end if;

    v_a := least(v_snap.sender_id, r.recipient_id);
    v_b := greatest(v_snap.sender_id, r.recipient_id);

    insert into public.snap_streaks (user_a, user_b, timezone)
    values (v_a, v_b,
      public.safe_timezone((select timezone from public.profiles where id = v_snap.sender_id)))
    on conflict (user_a, user_b) do nothing;

    select * into v_row from public.snap_streaks
      where user_a = v_a and user_b = v_b for update;

    v_tz := public.safe_timezone(v_row.timezone);
    v_today := (now() at time zone v_tz)::date;
    v_current_local_time := (now() at time zone v_tz)::time;
    v_snap_created_local := (v_snap.created_at at time zone v_tz)::date;

    -- Verification Delay Grace Window:
    -- If snap was created yesterday before midnight and verified before 06:00 AM local time,
    -- backdate effective streak credit to the created date so server delay doesn't break streaks.
    if v_snap_created_local = (v_today - 1) and v_current_local_time <= '06:00:00'::time then
      v_effective_date := v_snap_created_local;
    else
      v_effective_date := v_today;
    end if;

    if v_snap.sender_id = v_a then
      v_row.last_a_snap_date := v_effective_date;
    else
      v_row.last_b_snap_date := v_effective_date;
    end if;

    if v_row.last_a_snap_date = v_effective_date
       and v_row.last_b_snap_date = v_effective_date
       and coalesce(v_row.last_completed_date, '1970-01-01'::date) <> v_effective_date then

      if v_row.last_completed_date = v_effective_date - 1 then
        v_new := coalesce(v_row.current, 0) + 1;
      else
        v_new := 1;
      end if;

      v_row.current := v_new;
      if v_new > coalesce(v_row.longest, 0) then
        v_row.longest := v_new;
      end if;
      v_row.last_completed_date := v_effective_date;

      v_event := 'completed';
      v_milestone := case when v_new in (3, 7, 14, 30, 50, 100) then v_new else null end;

      -- Milestone reward: XP
      if to_regclass('public.streaks') is not null then
        execute 'insert into public.streaks (user_id, xp) values ($1, $3), ($2, $3)
                 on conflict (user_id) do update set xp = public.streaks.xp + excluded.xp'
          using v_a, v_b, v_new * 5;
      end if;
    elsif coalesce(v_row.last_completed_date, '1970-01-01'::date) = v_effective_date then
      v_event := 'already_completed';
      v_milestone := null;
    else
      v_event := 'nudge';
      v_milestone := null;
    end if;

    update public.snap_streaks
    set current = v_row.current,
        longest = v_row.longest,
        last_a_snap_date = v_row.last_a_snap_date,
        last_b_snap_date = v_row.last_b_snap_date,
        last_completed_date = v_row.last_completed_date
    where user_a = v_a and user_b = v_b;

    v_events := v_events || jsonb_build_object(
      'sender_id', v_snap.sender_id,
      'recipient_id', r.recipient_id,
      'event', v_event,
      'current', v_row.current,
      'milestone', v_milestone
    );
  end loop;

  return v_events;
end;
$$;

revoke all on function public.update_snap_streaks(uuid) from public, anon, authenticated;
grant execute on function public.update_snap_streaks(uuid) to service_role, postgres;

