-- 009: indexes on foreign keys and (user_id, date) lookups.
-- Already covered by constraints, so not repeated here:
--   daily_stats (user_id, date)          -> unique constraint
--   challenge_completions (user_id, date)-> unique constraint
--   block_completions (block_id, date)   -> unique constraint
--   snap_recipients (snap_id, ...)       -> primary key
--   team_members (team_id, ...)          -> primary key
--   device_tokens (user_id, ...)         -> unique constraint
--   snap_streaks (user_a, ...)           -> unique constraint

create index if not exists workout_plans_owner_idx on public.workout_plans (owner_id);
create index if not exists plan_days_plan_idx on public.plan_days (plan_id);
create index if not exists plan_exercises_day_idx on public.plan_exercises (plan_day_id);
create index if not exists plan_exercises_exercise_idx on public.plan_exercises (exercise_id);

create index if not exists workout_logs_user_completed_idx
  on public.workout_logs (user_id, completed_at desc);
create index if not exists workout_logs_plan_day_idx on public.workout_logs (plan_day_id);

create index if not exists schedule_blocks_user_idx on public.schedule_blocks (user_id);
create index if not exists block_completions_user_date_idx
  on public.block_completions (user_id, date);
create index if not exists challenge_completions_challenge_idx
  on public.challenge_completions (challenge_id);

create index if not exists user_conditions_user_idx on public.user_conditions (user_id);
create index if not exists medicines_user_idx on public.medicines (user_id);

create index if not exists friendships_requester_idx on public.friendships (requester_id);
create index if not exists friendships_addressee_idx on public.friendships (addressee_id);

create unique index if not exists snaps_image_path_key on public.snaps (image_path);
create index if not exists snaps_sender_created_idx on public.snaps (sender_id, created_at desc);
create index if not exists snaps_expires_idx on public.snaps (expires_at);
create index if not exists snap_recipients_recipient_idx on public.snap_recipients (recipient_id);
create index if not exists snap_streaks_user_b_idx on public.snap_streaks (user_b);

create index if not exists reports_reporter_idx on public.reports (reporter_id);
create index if not exists reports_snap_idx on public.reports (snap_id);
create index if not exists reports_reported_user_idx on public.reports (reported_user_id);

create index if not exists teams_owner_idx on public.teams (owner_id);
create index if not exists team_members_user_idx on public.team_members (user_id);
