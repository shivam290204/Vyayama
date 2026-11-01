-- 020: Saved Routes Metadata Alignment & Tombstone Infrastructure
-- PROPOSED ADDITIVE MIGRATION for Vyayama Maps (Phase 5 / Security Hardening)
-- IMPORTANT: Do not apply to live Supabase project without administrative sign-off.
--
-- Purpose:
-- 1. Adds 'is_loop' and 'is_difficulty_estimated' columns to public.saved_routes
--    to support client-side loop circuit detection and automatic difficulty rating.
-- 2. Relaxes 'surface_type' and 'elevation_profile' check constraints to permit
--    'unknown' fallback without failing inserts when OSM tag data is incomplete.
-- 3. Relaxes 'elevation_gain_meters' to allow NULL when elevation cannot be calculated.
-- 4. Establishes strictly append-only, immutable outdoor deletion tombstones.
-- 5. Implements hardened SECURITY DEFINER triggers with SET search_path = '',
--    strict caller ownership verification (IS DISTINCT FROM), deterministic advisory
--    locks, and explicit database exceptions (TOMBSTONE_EXISTS) to eliminate resurrection.

-- 1. Add missing metadata fields to saved_routes
alter table public.saved_routes
  add column if not exists is_loop boolean not null default false;

alter table public.saved_routes
  add column if not exists is_difficulty_estimated boolean not null default false;

-- 2. Relax surface_type check constraint to permit 'unknown'
alter table public.saved_routes
  drop constraint if exists saved_routes_surface_type_check;

alter table public.saved_routes
  add constraint saved_routes_surface_type_check
  check (surface_type in ('paved', 'trail', 'mixed', 'unknown'));

-- 3. Relax elevation_profile check constraint to permit 'unknown'
alter table public.saved_routes
  drop constraint if exists saved_routes_elevation_profile_check;

alter table public.saved_routes
  add constraint saved_routes_elevation_profile_check
  check (elevation_profile in ('flat', 'moderate', 'hilly', 'unknown'));

-- 4. Allow null elevation_gain_meters when elevation cannot be reliably calculated
alter table public.saved_routes
  alter column elevation_gain_meters drop not null;

-- 5. Add index for fast user sync and pagination
create index if not exists idx_saved_routes_user_updated
  on public.saved_routes(user_id, created_at desc);

-- 6. Outdoor Deletion Tombstones Table (Append-Only, Cross-Device Synchronization)
-- Prevents stale local records on secondary/offline devices from resurrecting deleted workouts or routes.
create table if not exists public.outdoor_tombstones (
  id text not null,
  entity_type text not null check (entity_type in ('activity', 'route')),
  user_id uuid not null references public.profiles(id) on delete cascade,
  deleted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (id, entity_type, user_id)
);

alter table public.outdoor_tombstones enable row level security;

-- Drop previous policies to ensure clean state
drop policy if exists "read own outdoor tombstones" on public.outdoor_tombstones;
drop policy if exists "insert own outdoor tombstones" on public.outdoor_tombstones;
drop policy if exists "update own outdoor tombstones" on public.outdoor_tombstones;
drop policy if exists "delete own outdoor tombstones" on public.outdoor_tombstones;

-- Only SELECT and INSERT policies for authenticated clients (strictly append-only)
create policy "read own outdoor tombstones" on public.outdoor_tombstones
  for select to authenticated
  using (auth.uid() = user_id);

create policy "insert own outdoor tombstones" on public.outdoor_tombstones
  for insert to authenticated
  with check (auth.uid() = user_id);

-- Explicitly revoke UPDATE and DELETE table privileges from PUBLIC, anon, and authenticated
revoke all on table public.outdoor_tombstones from public, anon;
revoke update, delete on table public.outdoor_tombstones from authenticated;
grant select, insert on table public.outdoor_tombstones to authenticated;
grant all on table public.outdoor_tombstones to service_role;

create index if not exists idx_outdoor_tombstones_user_deleted
  on public.outdoor_tombstones(user_id, deleted_at desc);

comment on table public.saved_routes is
  'User saved and custom outdoor routes with loop detection and difficulty estimation metadata.';

comment on table public.outdoor_tombstones is
  'Append-only cross-device deletion tombstones preventing stale local records from resurrecting deleted workouts or routes.';

-- Note on Safe Tombstone Retention:
-- Automatic 90-day truncation is deliberately omitted to prevent data resurrection on dormant/offline
-- secondary devices (e.g. tablet used infrequently for outdoor workouts). Tombstones average <100 bytes
-- each and are retained indefinitely until account deletion (cascaded via public.profiles on auth.users deletion)
-- or future multi-device acknowledgement protocol.

-- ============================================================================
-- 7. Anti-Resurrection Concurrency Serialization (Hardened Advisory Lock Triggers)
-- ============================================================================
-- ISOLATION LEVEL REQUIREMENT:
-- Outdoor activity and saved-route synchronization strictly relies on PostgreSQL
-- READ COMMITTED transaction isolation (the default transaction isolation level in Supabase / PostgREST).
--
-- Concurrency Architecture & Guarantees:
-- 1. Each synchronization database operation executed by the mobile client is an isolated,
--    single-statement PostgREST HTTP request (fresh transaction and fresh MVCC snapshot per attempt).
-- 2. By acquiring a deterministic 64-bit transaction-scoped advisory lock:
--      pg_catalog.hashtextextended('outdoor_lock:' || user_id::text || ':' || entity_type || ':' || id, 0)
--    conflicting mutations for the same entity are strictly serialized.
-- 3. In READ COMMITTED, when a waiting upsert transaction acquires the lock released by a
--    committed tombstone transaction, PL/pgSQL sub-statements evaluate with an updated snapshot,
--    reliably detect the newly committed tombstone, and raise P0001: TOMBSTONE_EXISTS.
--
-- LIMITATIONS & UNSUPPORTED CONFIGURATION:
-- Changing the authenticated role's 'default_transaction_isolation' to 'REPEATABLE READ'
-- is UNSUPPORTED with this advisory-lock-only design. Under REPEATABLE READ, transaction
-- snapshots are frozen at transaction start and do not refresh upon obtaining advisory locks;
-- an upsert transaction started prior to tombstone commit would miss the tombstone and
-- resurrect a deleted entity. Do NOT use REPEATABLE READ or SERIALIZABLE multi-statement
-- transactions without row-level sentinel locks. Repeatable Read safety is not claimed.

-- 7.1. Check Outdoor Activities for Tombstone on INSERT / UPDATE
create or replace function public.check_outdoor_activity_tombstone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lock_key bigint;
  v_tombstone_exists boolean;
begin
  -- Authenticated ownership check before acquiring locks or executing privileged operations
  if auth.role() = 'authenticated' and NEW.user_id is distinct from auth.uid() then
    raise exception 'Unauthorized: user_id mismatch' using errcode = '42501';
  end if;

  -- Fully qualified 64-bit advisory transaction lock scoped to user, entity type, and ID
  v_lock_key := pg_catalog.hashtextextended('outdoor_lock:' || NEW.user_id::text || ':activity:' || NEW.id, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_lock_key);

  select exists (
    select 1
    from public.outdoor_tombstones
    where id = NEW.id
      and entity_type = 'activity'
      and user_id = NEW.user_id
  ) into v_tombstone_exists;

  if v_tombstone_exists then
    raise exception 'Activity % has been deleted by an active tombstone', NEW.id
      using errcode = 'P0001', detail = 'TOMBSTONE_EXISTS';
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_check_outdoor_activity_tombstone on public.outdoor_activities;
create trigger trg_check_outdoor_activity_tombstone
  before insert or update on public.outdoor_activities
  for each row
  execute function public.check_outdoor_activity_tombstone();

-- 7.2. Check Saved Routes for Tombstone on INSERT / UPDATE
create or replace function public.check_saved_route_tombstone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lock_key bigint;
  v_tombstone_exists boolean;
begin
  -- Authenticated ownership check before acquiring locks or executing privileged operations
  if auth.role() = 'authenticated' and NEW.user_id is distinct from auth.uid() then
    raise exception 'Unauthorized: user_id mismatch' using errcode = '42501';
  end if;

  -- Fully qualified 64-bit advisory transaction lock scoped to user, entity type, and ID
  v_lock_key := pg_catalog.hashtextextended('outdoor_lock:' || NEW.user_id::text || ':route:' || NEW.id, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_lock_key);

  select exists (
    select 1
    from public.outdoor_tombstones
    where id = NEW.id
      and entity_type = 'route'
      and user_id = NEW.user_id
  ) into v_tombstone_exists;

  if v_tombstone_exists then
    raise exception 'Route % has been deleted by an active tombstone', NEW.id
      using errcode = 'P0001', detail = 'TOMBSTONE_EXISTS';
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_check_saved_route_tombstone on public.saved_routes;
create trigger trg_check_saved_route_tombstone
  before insert or update on public.saved_routes
  for each row
  execute function public.check_saved_route_tombstone();

-- 7.3. Process Outdoor Tombstone Creation (purge concurrent writes)
create or replace function public.process_outdoor_tombstone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lock_key bigint;
begin
  -- Authenticated ownership check before acquiring locks or executing privileged operations
  if auth.role() = 'authenticated' and NEW.user_id is distinct from auth.uid() then
    raise exception 'Unauthorized: user_id mismatch' using errcode = '42501';
  end if;

  -- Fully qualified 64-bit advisory transaction lock scoped to user, entity type, and ID
  v_lock_key := pg_catalog.hashtextextended('outdoor_lock:' || NEW.user_id::text || ':' || NEW.entity_type || ':' || NEW.id, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_lock_key);

  if NEW.entity_type = 'activity' then
    delete from public.outdoor_activities
    where id = NEW.id and user_id = NEW.user_id;
  elsif NEW.entity_type = 'route' then
    delete from public.saved_routes
    where id = NEW.id and user_id = NEW.user_id;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_process_outdoor_tombstone on public.outdoor_tombstones;
create trigger trg_process_outdoor_tombstone
  before insert on public.outdoor_tombstones
  for each row
  execute function public.process_outdoor_tombstone();

-- 7.4. Function Privileges and Access Control
revoke all on function public.check_outdoor_activity_tombstone() from public, anon;
revoke all on function public.check_saved_route_tombstone() from public, anon;
revoke all on function public.process_outdoor_tombstone() from public, anon;

grant execute on function public.check_outdoor_activity_tombstone() to authenticated, service_role;
grant execute on function public.check_saved_route_tombstone() to authenticated, service_role;
grant execute on function public.process_outdoor_tombstone() to authenticated, service_role;
