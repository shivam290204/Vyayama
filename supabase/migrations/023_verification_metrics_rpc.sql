-- 023_verification_metrics_rpc.sql
-- Adds the increment_verification_metric RPC called by verify-snap/index.ts.

create or replace function public.increment_verification_metric(
  p_date date,
  p_field text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_field not in (
    'total_submitted',
    'verified_count',
    'rejected_count',
    'retrying_count',
    'appealed_count',
    'expired_count'
  ) then
    raise exception 'Invalid verification metric field: %', p_field;
  end if;

  insert into public.verification_metrics (
    date,
    total_submitted,
    verified_count,
    rejected_count,
    retrying_count,
    appealed_count,
    expired_count,
    updated_at
  )
  values (
    p_date,
    case when p_field = 'total_submitted' then 1 else 0 end,
    case when p_field = 'verified_count' then 1 else 0 end,
    case when p_field = 'rejected_count' then 1 else 0 end,
    case when p_field = 'retrying_count' then 1 else 0 end,
    case when p_field = 'appealed_count' then 1 else 0 end,
    case when p_field = 'expired_count' then 1 else 0 end,
    now()
  )
  on conflict (date) do update set
    total_submitted = public.verification_metrics.total_submitted + case when p_field = 'total_submitted' then 1 else 0 end,
    verified_count  = public.verification_metrics.verified_count  + case when p_field = 'verified_count'  then 1 else 0 end,
    rejected_count  = public.verification_metrics.rejected_count  + case when p_field = 'rejected_count'  then 1 else 0 end,
    retrying_count  = public.verification_metrics.retrying_count  + case when p_field = 'retrying_count'  then 1 else 0 end,
    appealed_count  = public.verification_metrics.appealed_count  + case when p_field = 'appealed_count'  then 1 else 0 end,
    expired_count   = public.verification_metrics.expired_count   + case when p_field = 'expired_count'   then 1 else 0 end,
    updated_at      = now();
end;
$$;

revoke all on function public.increment_verification_metric(date, text) from public, anon, authenticated;
grant execute on function public.increment_verification_metric(date, text) to service_role;
