
-- Your own order in the vault. On iOS you drag a folder to another place in the folder row, and a card to another place
-- in the grid or list ("Eigen volgorde"); that order is kept here, so it is the same on every device and on the web.
-- Rows without a position (made before, or on a device that does not set one yet) come after the others: folders oldest
-- first, as before; evidence newest first.
--
-- Read folders in the order `position asc nulls last, created_at asc`. A position is not part of the evidence itself:
-- changing it never sets a confirmed item back to "toVerify" (guard_vault_item_authority does not look at it).
-- Safe to run more than once. Part of the shared schema: run it together with the web team.

alter table public.vault_folders
  add column if not exists position integer check (position is null or position >= 0);

alter table public.vault_items
  add column if not exists position integer check (position is null or position >= 0);

create index if not exists vault_folders_user_position on public.vault_folders (user_id, position);
create index if not exists vault_items_user_position on public.vault_items (user_id, position);
