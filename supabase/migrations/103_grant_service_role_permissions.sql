-- 103_grant_service_role_permissions.sql
-- Grants full administrative table, sequence, and routine privileges to service_role in schema public.
-- Edge Functions and background workers rely on service_role with SUPABASE_SERVICE_ROLE_KEY
-- to perform administrative operations, moderate UGC, verify snaps, process reports, and maintain streaks.

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on all routines in schema public to service_role;

alter default privileges in schema public grant all privileges on tables to service_role;
alter default privileges in schema public grant all privileges on sequences to service_role;
alter default privileges in schema public grant all privileges on routines to service_role;

