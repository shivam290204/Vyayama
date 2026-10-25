-- 018_fix_snap_image_path_index.sql
-- Replaces unique index on snaps(image_path) with standard B-tree index.
-- This allows sibling snaps (e.g. story post + direct friend snap) to share the same
-- uploaded image in storage without duplicate storage usage or unique constraint violation.

drop index if exists public.snaps_image_path_key;
create index if not exists snaps_image_path_idx on public.snaps (image_path);
