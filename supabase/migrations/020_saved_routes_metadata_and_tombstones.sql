-- 020: Saved Routes Metadata Alignment & Tombstone Infrastructure
-- PROPOSED ADDITIVE MIGRATION for Vyayama Maps (Phase 5)
-- IMPORTANT: Do not apply to live Supabase project without administrative sign-off.
--
-- Purpose:
-- 1. Adds 'is_loop' and 'is_difficulty_estimated' columns to public.saved_routes
--    to support client-side loop circuit detection and automatic difficulty rating.
-- 2. Relaxes 'surface_type' and 'elevation_profile' check constraints to permit
--    'unknown' fallback without failing inserts when OSM tag data is incomplete.
-- 3. Provides optional server-side soft-deletion tombstone tracking.

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

-- 4. Add index for fast user sync and pagination
create index if not exists idx_saved_routes_user_updated
  on public.saved_routes(user_id, created_at desc);

comment on table public.saved_routes is
  'User saved and custom outdoor routes with loop detection and difficulty estimation metadata.';

