-- 020: Saved Routes Metadata Alignment & Tombstone Infrastructure
-- PROPOSED ADDITIVE MIGRATION for Vyayama Maps (Phase 5)
-- IMPORTANT: Do not apply to live Supabase project without administrative sign-off.
--
-- Purpose:
-- 1. Adds 'is_loop' and 'is_difficulty_estimated' columns to public.saved_routes
--    to support client-side loop circuit detection and automatic difficulty rating.
-- 2. Relaxes 'surface_type' and 'elevation_profile' check constraints to permit
--    'unknown' fallback without failing inserts when OSM tag data is incomplete.
-- 3. Relaxes 'elevation_gain_meters' to allow NULL when elevation cannot be calculated.
-- 4. Provides server-side soft-deletion tombstone tracking.
-- 5. Implements PostgreSQL transaction-scoped advisory locking triggers to eliminate
--    server-side resurrection races between stale upserts and tombstone creations.

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

-- 6. Outdoor Deletion Tombstones Table (Cross-Device Deletion Synchronization)
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

create policy "read own outdoor tombstones" on public.outdoor_tombstones
  for select to authenticated
  using (auth.uid() = user_id);

create policy "insert own outdoor tombstones" on public.outdoor_tombstones
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "update own outdoor tombstones" on public.outdoor_tombstones
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "delete own outdoor tombstones" on public.outdoor_tombstones
  for delete to authenticated
  using (auth.uid() = user_id);

create index if not exists idx_outdoor_tombstones_user_deleted
  on public.outdoor_tombstones(user_id, deleted_at desc);

comment on table public.saved_routes is
  'User saved and custom outdoor routes with loop detection and difficulty estimation metadata.';

comment on table public.outdoor_tombstones is
  'Cross-device deletion tombstones preventing stale local records from resurrecting deleted workouts or routes.';

-- ============================================================================
-- 7. Anti-Resurrection Concurrency Serialization (Advisory Lock Triggers)
-- ============================================================================
-- Under PostgreSQL default Read Committed isolation, a race exists where Device B
-- deletes an entity and inserts a tombstone, while offline Device A reconnects
-- and sends an upsert for the deleted entity.
--
-- By acquiring a deterministic 64-bit transaction-scoped advisory lock:
--   hashtextextended('outdoor_lock:' || user_id::text || ':' || entity_type || ':' || id, 0)
-- conflicting operations for the same entity are strictly serialized:
-- 1. If tombstone commits first, the upsert trigger sees it and returns NULL (dropping the stale write).
-- 2. If upsert commits first, the tombstone trigger unblocks and immediately purges the newly inserted row.
-- In all interleavings, the final database state never contains an entity whose tombstone exists.

-- 7.1. Check Outdoor Activities for Tombstone on INSERT / UPDATE
create or replace function public.check_outdoor_activity_tombstone()
returns trigger
language plpgsql
security definer
as $$
declare
  v_lock_key bigint;
  v_tombstone_exists boolean;
begin
  -- Deterministic advisory transaction lock scoped to user, entity type, and ID
  v_lock_key := hashtextextended('outdoor_lock:' || NEW.user_id::text || ':activity:' || NEW.id, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  select exists (
    select 1
    from public.outdoor_tombstones
    where id = NEW.id
      and entity_type = 'activity'
      and user_id = NEW.user_id
  ) into v_tombstone_exists;

  if v_tombstone_exists then
    -- Stale write detected: cancel insert/update
    return null;
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
as $$
declare
  v_lock_key bigint;
  v_tombstone_exists boolean;
begin
  -- Deterministic advisory transaction lock scoped to user, entity type, and ID
  v_lock_key := hashtextextended('outdoor_lock:' || NEW.user_id::text || ':route:' || NEW.id, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  select exists (
    select 1
    from public.outdoor_tombstones
    where id = NEW.id
      and entity_type = 'route'
      and user_id = NEW.user_id
  ) into v_tombstone_exists;

  if v_tombstone_exists then
    -- Stale write detected: cancel insert/update
    return null;
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
as $$
declare
  v_lock_key bigint;
begin
  -- Acquire the exact same deterministic transaction lock
  v_lock_key := hashtextextended('outdoor_lock:' || NEW.user_id::text || ':' || NEW.entity_type || ':' || NEW.id, 0);
  perform pg_advisory_xact_lock(v_lock_key);

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
  before insert or update on public.outdoor_tombstones
  for each row
  execute function public.process_outdoor_tombstone();

grant execute on function public.check_outdoor_activity_tombstone() to authenticated, service_role;
grant execute on function public.check_saved_route_tombstone() to authenticated, service_role;
grant execute on function public.process_outdoor_tombstone() to authenticated, service_role;
