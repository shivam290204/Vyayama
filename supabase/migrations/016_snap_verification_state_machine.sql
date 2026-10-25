-- 016_snap_verification_state_machine.sql
-- Aligns verification state machine across database and client.
-- States: pending, retrying, verified, rejected, appealed, expired.
-- Adds 6-hour streak verification delay grace window.
-- Supports kill-switch modes: active, hold, disabled.
-- Adds verification metrics and remote app_config.

-- 1. Update verification_status constraint on snaps table
alter table public.snaps
  drop constraint if exists snaps_verification_status_check;

alter table public.snaps
  add constraint snaps_verification_status_check
  check (verification_status in ('pending', 'retrying', 'verified', 'rejected', 'appealed', 'expired'));

-- 2. Update is_snap_live to allow both verified and safe appealed snaps
create or replace function public.is_snap_live(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.id = p_snap_id
      and s.verification_status in ('verified', 'appealed')
      and s.expires_at > now()
  );
$$;

-- 3. Update can_read_snap_path for storage signed URL authorization
create or replace function public.can_read_snap_path(p_path text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.image_path = p_path
      and s.verification_status in ('verified', 'appealed')
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

-- 4. Update recipient and story read policies on public.snaps
drop policy if exists "recipient reads delivered snaps" on public.snaps;
create policy "recipient reads delivered snaps" on public.snaps
  for select to authenticated
  using (
    is_story = false
    and verification_status in ('verified', 'appealed')
    and expires_at > now()
    and public.is_snap_recipient(id)
    and not public.is_blocked_between(auth.uid(), sender_id)
  );

drop policy if exists "friends read stories" on public.snaps;
create policy "friends read stories" on public.snaps
  for select to authenticated
  using (
    is_story = true
    and verification_status in ('verified', 'appealed')
    and expires_at > now()
    and public.are_friends(auth.uid(), sender_id)
  );

-- 5. Update update_snap_streaks with streak verification delay grace window
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

-- 6. RPC: appeal_snap
-- Allows a user to appeal a photo that was rejected as "not exercise".
-- Crucial Security Rule: Waives ONLY the is_exercise requirement.
-- If the photo was flagged as unsafe/inappropriate, appeal is strictly rejected.
create or replace function public.appeal_snap(p_snap_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_snap public.snaps%rowtype;
begin
  select * into v_snap from public.snaps where id = p_snap_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Snap not found');
  end if;

  if auth.uid() is not null and v_snap.sender_id <> auth.uid() then
    return jsonb_build_object('success', false, 'error', 'Unauthorized');
  end if;

  -- Block appeals on unsafe content
  if v_snap.rejection_reason like '%standards%' or v_snap.rejection_reason like '%unsafe%' then
    return jsonb_build_object(
      'success', false,
      'error', 'This photo cannot be appealed due to community safety standards.',
      'status', 'rejected'
    );
  end if;

  -- Transition to appealed (delivered without streak credit)
  update public.snaps
  set verification_status = 'appealed',
      rejection_reason = 'Appealed by user (exercise check waived; safety confirmed)'
  where id = p_snap_id;

  return jsonb_build_object(
    'success', true,
    'status', 'appealed',
    'message', 'Your snap was shared with your friends without streak credit.'
  );
end;
$$;

-- 7. Verification metrics table
create table if not exists public.verification_metrics (
  date date primary key default current_date,
  total_submitted int default 0,
  verified_count int default 0,
  rejected_count int default 0,
  retrying_count int default 0,
  appealed_count int default 0,
  expired_count int default 0,
  updated_at timestamptz default now()
);

alter table public.verification_metrics enable row level security;
drop policy if exists "read verification metrics" on public.verification_metrics;
create policy "read verification metrics" on public.verification_metrics
  for select to authenticated using (true);

-- 8. App configuration table for remote kill-switch and parameters
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz default now()
);

alter table public.app_config enable row level security;
drop policy if exists "read app config" on public.app_config;
create policy "read app config" on public.app_config
  for select to authenticated using (true);

insert into public.app_config (key, value)
values ('snap_verification', '{"mode": "active", "max_daily": 10, "min_confidence": 0.60, "model": "claude-3-5-haiku-20241022"}'::jsonb)
on conflict (key) do update set value = excluded.value;
