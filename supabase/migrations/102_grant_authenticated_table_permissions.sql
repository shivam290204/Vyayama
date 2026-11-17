-- 102: Least-privilege table grants for authenticated client operations.
-- RLS remains 100% active and enforced on all tables.
-- Direct INSERT and DELETE on profiles remain withheld (creation is handled by auth trigger; deletion by delete_my_account RPC).

-- 1. Profiles & Account (SELECT and UPDATE only; no direct INSERT, no direct DELETE)
grant select, update on table public.profiles to authenticated;

-- 2. Read-only catalogs & public application data
grant select on table public.exercises to authenticated;
grant select on table public.challenges to authenticated;
grant select on table public.app_config to authenticated;
grant select on table public.verification_metrics to authenticated;
grant select on table public.snap_streaks to authenticated;

-- 3. User-isolated personal data
-- Daily stats & Streaks: SELECT, INSERT, UPDATE only (no DELETE)
grant select, insert, update on table public.daily_stats to authenticated;
grant select, insert, update on table public.streaks to authenticated;
grant select, insert, update on table public.challenge_completions to authenticated;

-- Health conditions: SELECT, INSERT, DELETE only (no UPDATE)
grant select, insert, delete on table public.user_conditions to authenticated;

-- User personal CRUD records
grant select, insert, update, delete on table public.medicines to authenticated;
grant select, insert, update, delete on table public.bmi_records to authenticated;
grant select, insert, update, delete on table public.workout_logs to authenticated;
grant select, insert, update, delete on table public.device_tokens to authenticated;
grant select, insert, update, delete on table public.schedule_blocks to authenticated;
grant select, insert, update, delete on table public.block_completions to authenticated;
grant select, insert, update, delete on table public.outdoor_activities to authenticated;
grant select, insert, update, delete on table public.saved_routes to authenticated;

-- 4. Social & Friendships
grant select, insert, update, delete on table public.friendships to authenticated;
grant select, insert on table public.reports to authenticated;

-- 5. Snaps & Messaging (Immutable snaps: no UPDATE; Recipients: no DELETE)
grant select, insert, delete on table public.snaps to authenticated;
grant select, insert, update on table public.snap_recipients to authenticated;

-- 6. Teams (Creation & joins handled via RPC)
grant select, update, delete on table public.teams to authenticated;
grant select, delete on table public.team_members to authenticated;

-- 7. Workout Plans (Save/updates handled via save_workout_plan RPC; days/exercises read-only for client)
grant select, delete on table public.workout_plans to authenticated;
grant select on table public.plan_days to authenticated;
grant select on table public.plan_exercises to authenticated;

