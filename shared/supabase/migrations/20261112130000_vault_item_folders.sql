-- An item can be in more than one folder, such as Projecten and Stage at once (the iOS app puts new evidence in the folder
-- of its kind and in the folder you add it from). vault_item_folders holds every folder of an item; vault_items.folder_id
-- keeps the first one, so the web keeps working until it reads the new table.
--
-- Not applied yet. This is part of the shared schema: run it only together with the web team. It needs
-- 20261112120000 first. The iOS app works without it: each item then has one folder, folder_id.

create table if not exists public.vault_item_folders (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_id uuid not null,
  folder_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (item_id, folder_id),
  foreign key (user_id, item_id) references public.vault_items (user_id, id) on delete cascade,
  foreign key (user_id, folder_id) references public.vault_folders (user_id, id) on delete cascade
);

create index if not exists vault_item_folders_folder on public.vault_item_folders (user_id, folder_id);

alter table public.vault_item_folders enable row level security;

drop policy if exists "Require two-step verification" on public.vault_item_folders;
create policy "Require two-step verification"
  on public.vault_item_folders as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own vault item folders" on public.vault_item_folders;
create policy "Own vault item folders"
  on public.vault_item_folders for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

grant select, insert, delete on public.vault_item_folders to authenticated;

-- Every item that is in a folder now, including the ones just put in an example folder above.
insert into public.vault_item_folders (user_id, item_id, folder_id)
select user_id, id, folder_id from public.vault_items where folder_id is not null
on conflict do nothing;

comment on table public.vault_item_folders is
  'Which folders an item is in; an item can be in several. vault_items.folder_id keeps the first for older clients.';
