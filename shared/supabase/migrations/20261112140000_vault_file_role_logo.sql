-- Repairs the file roles of the vault. The first version of 20261112120000 added `vault_item_files.role` with only
-- 'document' and 'cover'. The later version allows 'logo' too, but its `add column if not exists` skips the column, and
-- with it its check, on a database that already had it. Saving a logo then fails with
-- "violates check constraint vault_item_files_role_check" (seen in the Postgres logs of 2026-11-12).
--
-- Safe to run more than once and on a database that already has the newer version. Part of the shared schema: run it
-- together with the web team.

alter table public.vault_item_files
  drop constraint if exists vault_item_files_role_check;
alter table public.vault_item_files
  add constraint vault_item_files_role_check check (role in ('document', 'cover', 'logo'));

alter table public.vault_item_files
  drop constraint if exists vault_item_files_cover_is_image;
alter table public.vault_item_files
  add constraint vault_item_files_cover_is_image
  check (role = 'document' or mime_type in ('image/heic', 'image/jpeg', 'image/png'));

create unique index if not exists vault_item_files_one_logo
  on public.vault_item_files (user_id, item_id) where role = 'logo';
