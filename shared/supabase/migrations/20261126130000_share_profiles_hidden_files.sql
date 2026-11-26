-- A selection can leave single files behind: evidence takes its files along (file_ids), except the files named here.
-- Shares keep the same in content.hiddenFiles, which share-view honours.
-- Run after 20261125190000_share_profiles_files_summary.sql.

alter table public.share_profiles
  add column if not exists hidden_file_ids text[] not null default '{}'
    check (cardinality(hidden_file_ids) <= 400);
