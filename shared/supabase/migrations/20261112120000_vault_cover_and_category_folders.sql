-- Vault, round three (Figma FEDDIES 1348:1801 and the vault folder row):
--  1. An item can have a cover image next to its documents (step 2 "Documenten" of adding evidence).
--  2. The category folders at the top of the vault (Certificaten, Diploma's, Feedback, Projecten, ...) can be renamed,
--     restyled and hidden like your own folders. They are not rows in vault_folders: they show the items of one
--     category. This table only holds how you want each one to look.
--
-- Not applied yet. This is part of the shared schema: run it only together with the web team.
-- The iOS app works without it: documents upload as before, a cover waits for this column, and folder changes are kept
-- on the phone until the table exists.

-- 1. Cover -------------------------------------------------------------------------------------------------------------

alter table public.vault_item_files
  add column if not exists role text not null default 'document' check (role in ('document', 'cover'));

alter table public.vault_item_files
  drop constraint if exists vault_item_files_cover_is_image;
alter table public.vault_item_files
  add constraint vault_item_files_cover_is_image
  check (role <> 'cover' or mime_type in ('image/heic', 'image/jpeg', 'image/png'));

create unique index if not exists vault_item_files_one_cover
  on public.vault_item_files (user_id, item_id) where role = 'cover';

comment on column public.vault_item_files.role is
  'document: the evidence itself. cover: the image shown on the vault card; at most one per item.';

-- 2. Category folders ------------------------------------------------------------------------------------------------

create table if not exists public.vault_category_folders (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category text not null check (category in (
    'diplomas', 'certificates', 'badges', 'projects', 'workExperience', 'internships', 'skills', 'feedback',
    'reflections', 'other'
  )),
  -- Null keeps the category's own name, colour or icon.
  name text check (name is null or length(btrim(name)) between 1 and 100),
  color text check (color is null or color in ('green', 'blue', 'purple', 'rust', 'rose', 'slate')),
  icon text check (icon is null or icon in (
    'folder', 'briefcase', 'academic-cap', 'check-badge', 'wrench-screwdriver', 'chat-bubble-left-ellipsis',
    'star', 'heart', 'code-bracket', 'light-bulb', 'rocket-launch', 'globe-europe-africa', 'paint-brush',
    'document-text', 'user-group', 'trophy'
  )),
  -- Hidden from the folder row; the items stay in the vault and the folder can be shown again.
  is_hidden boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);

alter table public.vault_category_folders enable row level security;

drop policy if exists "Require two-step verification" on public.vault_category_folders;
create policy "Require two-step verification"
  on public.vault_category_folders as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own vault category folders" on public.vault_category_folders;
create policy "Own vault category folders"
  on public.vault_category_folders for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.vault_category_folders to authenticated;

comment on table public.vault_category_folders is
  'How each category folder at the top of the vault looks for one account: its own name, colour and icon, or hidden.';
