-- Migration 017: UGC reporting, blocking, and admin email alerting infrastructure

-- 1. Ensure public.reports has admin alerting columns
alter table public.reports
  add column if not exists admin_alerted boolean not null default false,
  add column if not exists admin_alerted_at timestamptz;

-- 2. Indexes for efficient moderation queries and abuse filtering
create index if not exists idx_reports_status_created on public.reports(status, created_at desc);
create index if not exists idx_reports_reported_user on public.reports(reported_user_id);
create index if not exists idx_reports_snap_id on public.reports(snap_id);

-- 3. Stored Procedure for comprehensive UGC reporting + blocking
create or replace function public.file_ugc_report(
  p_snap_id uuid,
  p_reason text,
  p_block_user boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reporter_id uuid := auth.uid();
  v_reported_user_id uuid;
  v_report_id uuid;
begin
  if v_reporter_id is null then
    raise exception 'Authentication required to file report';
  end if;

  -- Lookup snap author
  select sender_id into v_reported_user_id
  from public.snaps
  where id = p_snap_id;

  -- Create report record
  insert into public.reports (
    reporter_id,
    snap_id,
    reported_user_id,
    reason,
    status,
    admin_alerted
  ) values (
    v_reporter_id,
    p_snap_id,
    v_reported_user_id,
    coalesce(trim(p_reason), 'Unspecified'),
    'open',
    false
  ) returning id into v_report_id;

  -- Optionally block the user immediately
  if p_block_user and v_reported_user_id is not null then
    perform public.block_user(v_reported_user_id);
  end if;

  return jsonb_build_object(
    'success', true,
    'report_id', v_report_id,
    'blocked', p_block_user
  );
end;
$$;

grant execute on function public.file_ugc_report(uuid, text, boolean) to authenticated;
