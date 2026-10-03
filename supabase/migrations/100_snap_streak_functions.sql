-- 100_snap_streak_functions.sql
-- Server-side Snap Streak logic (spec section 9.6). Mirrors
-- lib/features/snap_streaks/data/snap_streak_calculator.dart. Keep both in sync.
--
-- Assumes the tables from spec section 8 exist (profiles, friendships, snaps,
-- snap_recipients, snap_streaks). The optional `streaks` table (XP) is used
-- only if it exists.

-- ---------------------------------------------------------------------------
-- Lock down snap_streaks: members may read, nobody on the client may write.
-- ---------------------------------------------------------------------------
alter table snap_streaks enable row level security;

drop policy if exists "members read pair streak" on snap_streaks;
create policy "members read pair streak" on snap_streaks
  for select using (auth.uid() = user_a or auth.uid() = user_b);

-- No insert/update/delete policies exist, so RLS denies them. Also revoke the
-- table privileges as defence in depth.
revoke insert, update, delete on snap_streaks from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Clients can never change verification fields on snaps.
-- ---------------------------------------------------------------------------
create or replace function protect_snap_verification() returns trigger
language plpgsql as $$
begin
  if coalesce(auth.role(), '') in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.verification_status := 'pending';
      new.verification_label := null;
      new.verification_confidence := null;
      new.rejection_reason := null;
    elsif new.verification_status is distinct from old.verification_status
       or new.verification_label is distinct from old.verification_label
       or new.verification_confidence is distinct from old.verification_confidence
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'verification fields are server-only';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists snaps_protect_verification on snaps;
create trigger snaps_protect_verification
  before insert or update on snaps
  for each row execute function protect_snap_verification();

-- ---------------------------------------------------------------------------
-- Helper: a valid timezone name, falling back to UTC.
-- ---------------------------------------------------------------------------
create or replace function safe_timezone(tz text) returns text
language sql stable as $$
  select coalesce(
    (select name from pg_timezone_names where name = tz limit 1),
    'UTC');
$$;

-- ---------------------------------------------------------------------------
-- update_snap_streaks(snap_id)
-- Call when a snap becomes `verified`. Returns a jsonb array of events the
-- Edge Function turns into push notifications:
--   { sender_id, recipient_id, event, current, milestone }
--   event: 'nudge' | 'completed' | 'already_completed'
-- ---------------------------------------------------------------------------
create or replace function update_snap_streaks(p_snap_id uuid) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_snap snaps%rowtype;
  v_row snap_streaks%rowtype;
  r record;
  v_a uuid;
  v_b uuid;
  v_tz text;
  v_today date;
  v_new int;
  v_event text;
  v_milestone int;
  v_events jsonb := '[]'::jsonb;
begin
  select * into v_snap from snaps where id = p_snap_id;
  if not found
     or v_snap.verification_status <> 'verified'
     or v_snap.is_story then
    return v_events;
  end if;

  for r in select recipient_id from snap_recipients where snap_id = p_snap_id loop
    -- Only accepted friends take part in a pair streak.
    if not exists (
      select 1 from friendships f
      where f.status = 'accepted'
        and ((f.requester_id = v_snap.sender_id and f.addressee_id = r.recipient_id)
          or (f.requester_id = r.recipient_id and f.addressee_id = v_snap.sender_id))
    ) then
      continue;
    end if;

    v_a := least(v_snap.sender_id, r.recipient_id);
    v_b := greatest(v_snap.sender_id, r.recipient_id);

    -- The pair timezone is the timezone of whoever started the streak.
    insert into snap_streaks (user_a, user_b, timezone)
    values (v_a, v_b,
      safe_timezone((select timezone from profiles where id = v_snap.sender_id)))
    on conflict (user_a, user_b) do nothing;

    select * into v_row from snap_streaks
      where user_a = v_a and user_b = v_b for update;

    v_tz := safe_timezone(v_row.timezone);
    v_today := (now() at time zone v_tz)::date;

    if v_snap.sender_id = v_a then
      v_row.last_a_snap_date := v_today;
    else
      v_row.last_b_snap_date := v_today;
    end if;

    v_milestone := null;

    if v_row.last_a_snap_date = v_today and v_row.last_b_snap_date = v_today then
      if v_row.last_completed_date = v_today then
        v_event := 'already_completed';
      else
        if v_row.last_completed_date = v_today - 1 then
          v_new := v_row.current + 1;
        else
          v_new := 1; -- new or restarted
        end if;
        v_row.current := v_new;
        v_row.longest := greatest(v_row.longest, v_new);
        v_row.last_completed_date := v_today;
        v_event := 'completed';

        if v_new in (3, 7, 14, 30, 50, 100) then
          v_milestone := v_new;
          -- Milestone reward: XP. Badges are derived from `longest` on the client.
          if to_regclass('public.streaks') is not null then
            execute 'insert into streaks (user_id, xp) values ($1, $3), ($2, $3)
                     on conflict (user_id) do update set xp = streaks.xp + excluded.xp'
              using v_a, v_b, v_new * 5;
          end if;
        end if;
      end if;
    else
      v_event := 'nudge';
    end if;

    update snap_streaks set
      current = v_row.current,
      longest = v_row.longest,
      last_a_snap_date = v_row.last_a_snap_date,
      last_b_snap_date = v_row.last_b_snap_date,
      last_completed_date = v_row.last_completed_date
    where id = v_row.id;

    v_events := v_events || jsonb_build_object(
      'sender_id', v_snap.sender_id,
      'recipient_id', r.recipient_id,
      'event', v_event,
      'current', v_row.current,
      'milestone', v_milestone);
  end loop;

  return v_events;
end $$;

revoke all on function update_snap_streaks(uuid) from public, anon, authenticated;
grant execute on function update_snap_streaks(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- reset_expired_streaks()  (run hourly)
-- Resets streaks after a full missed day and returns streaks that just entered
-- the 4-hour warning window. The window is (3h, 4h] so that an hourly job
-- reports each pair exactly once per day. Returns:
--   { reset: n, at_risk: [ { user_id, partner_id, current } ] }
-- ---------------------------------------------------------------------------
create or replace function reset_expired_streaks() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_tz text;
  v_local timestamp;
  v_today date;
  v_hours_left numeric;
  v_reset int := 0;
  v_at_risk jsonb := '[]'::jsonb;
begin
  for r in select * from snap_streaks where current > 0 for update loop
    v_tz := safe_timezone(r.timezone);
    v_local := now() at time zone v_tz;
    v_today := v_local::date;

    if r.last_completed_date is null or v_today - r.last_completed_date >= 2 then
      update snap_streaks set current = 0 where id = r.id;
      v_reset := v_reset + 1;
    elsif r.last_completed_date <> v_today then
      v_hours_left := extract(epoch from
        (date_trunc('day', v_local) + interval '1 day') - v_local) / 3600;
      if v_hours_left <= 4 and v_hours_left > 3 then
        -- Warn whoever has not sent yet today.
        if r.last_a_snap_date is distinct from v_today then
          v_at_risk := v_at_risk || jsonb_build_object(
            'user_id', r.user_a, 'partner_id', r.user_b, 'current', r.current);
        end if;
        if r.last_b_snap_date is distinct from v_today then
          v_at_risk := v_at_risk || jsonb_build_object(
            'user_id', r.user_b, 'partner_id', r.user_a, 'current', r.current);
        end if;
      end if;
    end if;
  end loop;

  return jsonb_build_object('reset', v_reset, 'at_risk', v_at_risk);
end $$;

revoke all on function reset_expired_streaks() from public, anon, authenticated;
grant execute on function reset_expired_streaks() to service_role;

-- ---------------------------------------------------------------------------
-- delete_expired_snaps()  (run hourly)
-- Deletes expired snap rows (snap_recipients cascade) and returns their image
-- paths so the Edge Function can remove the files from Storage. Deleting
-- storage.objects rows from SQL would leave the files behind, so schedule the
-- Edge Function job `cleanup`, not this function directly.
-- Only metadata kept for streaks (snap_streaks) is untouched.
-- ---------------------------------------------------------------------------
create or replace function delete_expired_snaps() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paths jsonb;
begin
  select coalesce(jsonb_agg(image_path), '[]'::jsonb) into v_paths
  from snaps where expires_at < now();

  delete from snaps where expires_at < now();
  return v_paths;
end $$;

revoke all on function delete_expired_snaps() from public, anon, authenticated;
grant execute on function delete_expired_snaps() to service_role;

-- ---------------------------------------------------------------------------
-- Scheduling with pg_cron + pg_net (run once in the SQL editor, replacing
-- <PROJECT_REF> and <CRON_SECRET>; store the secret in Vault in production).
-- The Edge Function `verify-snap` handles both jobs when the body has `job`.
--
-- select cron.schedule('snap-streak-maintenance', '0 * * * *', $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/verify-snap',
--     headers := jsonb_build_object('Content-Type', 'application/json',
--                                   'x-cron-secret', '<CRON_SECRET>'),
--     body := '{"job":"streak_maintenance"}'::jsonb);
-- $$);
--
-- select cron.schedule('snap-cleanup', '15 * * * *', $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/verify-snap',
--     headers := jsonb_build_object('Content-Type', 'application/json',
--                                   'x-cron-secret', '<CRON_SECRET>'),
--     body := '{"job":"cleanup"}'::jsonb);
-- $$);
-- ---------------------------------------------------------------------------
