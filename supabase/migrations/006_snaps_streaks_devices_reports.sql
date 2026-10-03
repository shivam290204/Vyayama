-- 006: snaps, recipients, snap_streaks (table + read policy only),
-- device tokens, reports, and the private 'snaps' storage bucket.
-- Streak WRITE logic lives in 100_snap_streak_functions.sql (Claude 5).

create table public.snaps (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles(id) on delete cascade,
  image_path text not null,                -- path in private 'snaps' bucket
  activity_type text check (activity_type in
    ('workout','running','yoga','walking','cycling','gym','stretching','sports','other_exercise')),
  caption text check (char_length(caption) <= 140),
  is_story boolean default false,          -- true = Friends Feed post
  verification_status text default 'pending'
    check (verification_status in ('pending','verified','rejected')),
  verification_label text,
  verification_confidence numeric(3,2),
  rejection_reason text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '24 hours')
);

create table public.snap_recipients (
  snap_id uuid references public.snaps(id) on delete cascade,
  recipient_id uuid references public.profiles(id) on delete cascade,
  viewed_at timestamptz,
  reaction text check (reaction is null or char_length(reaction) <= 40),
  primary key (snap_id, recipient_id)
);

-- One row per friend pair. user_a < user_b keeps the pair unique.
create table public.snap_streaks (
  id uuid primary key default gen_random_uuid(),
  user_a uuid references public.profiles(id) on delete cascade,
  user_b uuid references public.profiles(id) on delete cascade,
  current int default 0,
  longest int default 0,
  last_a_snap_date date,
  last_b_snap_date date,
  last_completed_date date,
  timezone text default 'UTC',
  created_at timestamptz default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  token text not null,
  platform text,
  updated_at timestamptz default now(),
  unique (user_id, token)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  snap_id uuid references public.snaps(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  reason text,
  status text default 'open',
  created_at timestamptz default now()
);

alter table public.snaps enable row level security;
alter table public.snap_recipients enable row level security;
alter table public.snap_streaks enable row level security;
alter table public.device_tokens enable row level security;
alter table public.reports enable row level security;

-- Clients can never change verification fields or created/expiry times.
create or replace function public.snaps_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    new.verification_status := 'pending';
    new.verification_label := null;
    new.verification_confidence := null;
    new.rejection_reason := null;
  end if;
  new.created_at := now();
  new.expires_at := now() + interval '24 hours';
  return new;
end;
$$;

create trigger snaps_before_insert
  before insert on public.snaps
  for each row execute function public.snaps_before_insert();

-- SECURITY DEFINER helpers avoid recursive RLS between snaps and recipients.
create or replace function public.is_snap_sender(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.id = p_snap_id and s.sender_id = auth.uid()
  );
$$;

create or replace function public.is_snap_recipient(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snap_recipients r
    where r.snap_id = p_snap_id and r.recipient_id = auth.uid()
  );
$$;

-- "Delivered" = verified and not expired.
create or replace function public.is_snap_live(p_snap_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.id = p_snap_id
      and s.verification_status = 'verified'
      and s.expires_at > now()
  );
$$;

-- Can the caller read the storage object at this path (via signed URL)?
create or replace function public.can_read_snap_path(p_path text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.snaps s
    where s.image_path = p_path
      and s.verification_status = 'verified'
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

-- snaps: sender inserts/reads/deletes own; recipients read delivered snaps;
-- accepted friends read stories. No update policy: clients can never
-- change verification_status (only the service role can).
create policy "sender inserts snaps" on public.snaps
  for insert to authenticated
  with check (sender_id = auth.uid());

create policy "sender reads own snaps" on public.snaps
  for select to authenticated
  using (sender_id = auth.uid());

create policy "recipient reads delivered snaps" on public.snaps
  for select to authenticated
  using (
    is_story = false
    and verification_status = 'verified'
    and expires_at > now()
    and public.is_snap_recipient(id)
    and not public.is_blocked_between(auth.uid(), sender_id)
  );

create policy "friends read stories" on public.snaps
  for select to authenticated
  using (
    is_story = true
    and verification_status = 'verified'
    and expires_at > now()
    and public.are_friends(auth.uid(), sender_id)
  );

create policy "sender deletes own snaps" on public.snaps
  for delete to authenticated
  using (sender_id = auth.uid());

revoke update on public.snaps from authenticated, anon;

-- snap_recipients: only accepted friends (so blocked users are excluded).
create policy "read own deliveries" on public.snap_recipients
  for select to authenticated
  using (
    public.is_snap_sender(snap_id)
    or (recipient_id = auth.uid() and public.is_snap_live(snap_id))
  );

create policy "sender adds recipients" on public.snap_recipients
  for insert to authenticated
  with check (
    public.is_snap_sender(snap_id)
    and public.are_friends(auth.uid(), recipient_id)
  );

create policy "recipient updates own row" on public.snap_recipients
  for update to authenticated
  using (recipient_id = auth.uid() and public.is_snap_live(snap_id))
  with check (recipient_id = auth.uid());

revoke update on public.snap_recipients from authenticated, anon;
grant update (viewed_at, reaction) on public.snap_recipients to authenticated;

-- snap_streaks: read-only for the two members. Written only by server code.
create policy "members read streak" on public.snap_streaks
  for select to authenticated
  using (auth.uid() in (user_a, user_b));

revoke insert, update, delete on public.snap_streaks from authenticated, anon;

-- device_tokens: own rows.
create policy "own rows" on public.device_tokens
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- reports: anyone can file one, and can see only their own. Review is
-- done by admins with the service role.
create policy "file report" on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');

create policy "read own reports" on public.reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- Private storage bucket. Path format: {sender_id}/{snap_id}.jpg
-- (RLS is already enabled on storage.objects by Supabase.)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('snaps', 'snaps', false, 1048576, array['image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = 1048576,
      allowed_mime_types = array['image/jpeg'];

create policy "snaps upload own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'snaps'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Needed so recipients can create signed URLs for snaps delivered to them.
create policy "snaps read own or delivered" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'snaps'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_read_snap_path(name)
    )
  );

create policy "snaps delete own folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'snaps'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

revoke all on function public.is_snap_sender(uuid) from public, anon;
revoke all on function public.is_snap_recipient(uuid) from public, anon;
revoke all on function public.is_snap_live(uuid) from public, anon;
revoke all on function public.can_read_snap_path(text) from public, anon;

grant execute on function public.is_snap_sender(uuid) to authenticated;
grant execute on function public.is_snap_recipient(uuid) to authenticated;
grant execute on function public.is_snap_live(uuid) to authenticated;
grant execute on function public.can_read_snap_path(text) to authenticated;
