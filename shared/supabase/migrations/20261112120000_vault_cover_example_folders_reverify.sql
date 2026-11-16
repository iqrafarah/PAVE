-- Vault, round three (Figma FEDDIES 1348:1169 to 1348:2537, adding and changing evidence):
--  1. An item can have a logo (the image in the round avatar on its card) and a cover (the image in the band above it)
--     next to its documents. Without a cover, the apps tint the band with the strongest colour of the logo.
--  2. Every account starts with four example folders (Certificaten, Diploma's, Feedback, Projecten). They are ordinary
--     folders: you can rename, restyle or delete them, and an item is in one because you put it there.
--  3. You can change any item. When it was confirmed, or when you change its files, it goes back to "not confirmed" and
--     has to be confirmed again. Nobody but trusted server code can mark it confirmed.
--
-- Not applied yet. This is part of the shared schema: run it only together with the web team.
-- The iOS app works without it: documents upload as before, a cover waits for this column, the example folders are made
-- by the app for an account without folders, and changing a confirmed item is refused until the guard below is in place.

-- 1. Logo and cover -------------------------------------------------------------------------------------------------

alter table public.vault_item_files
  add column if not exists role text not null default 'document' check (role in ('document', 'cover', 'logo'));

alter table public.vault_item_files
  drop constraint if exists vault_item_files_cover_is_image;
alter table public.vault_item_files
  add constraint vault_item_files_cover_is_image
  check (role = 'document' or mime_type in ('image/heic', 'image/jpeg', 'image/png'));

create unique index if not exists vault_item_files_one_cover
  on public.vault_item_files (user_id, item_id) where role = 'cover';
create unique index if not exists vault_item_files_one_logo
  on public.vault_item_files (user_id, item_id) where role = 'logo';

comment on column public.vault_item_files.role is
  'document: the evidence itself. logo: the image in the round avatar on the vault card. cover: the image in the band '
  'above it. At most one logo and one cover per item; both are images.';

-- 2. Example folders -------------------------------------------------------------------------------------------------

-- Makes the four example folders for one account. A name that already exists is left alone, so running it twice, or
-- for an account that made "Projecten" itself, changes nothing.
create or replace function public.create_example_vault_folders(target uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.vault_folders (user_id, name, color, icon)
  values
    (target, 'Certificaten', 'green', 'check-badge'),
    (target, 'Diploma''s', 'green', 'academic-cap'),
    (target, 'Feedback', 'green', 'chat-bubble-left-ellipsis'),
    (target, 'Projecten', 'green', 'wrench-screwdriver')
  on conflict do nothing;
$$;

revoke all on function public.create_example_vault_folders(uuid) from public, anon, authenticated;

create or replace function public.create_example_vault_folders_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.create_example_vault_folders(new.id);
  return new;
end;
$$;

drop trigger if exists vault_example_folders_on_signup on auth.users;
create trigger vault_example_folders_on_signup
  after insert on auth.users
  for each row execute function public.create_example_vault_folders_for_new_user();

-- Existing accounts get them too, once. Their items without a folder go into the example folder of their category, so the
-- vault looks the same as when these four were category filters.
do $$
declare
  account record;
begin
  for account in select id from auth.users loop
    perform public.create_example_vault_folders(account.id);
  end loop;

  update public.vault_items i
  set folder_id = f.id
  from public.vault_folders f
  where i.folder_id is null
    and f.user_id = i.user_id
    and f.name = case i.category
      when 'certificates' then 'Certificaten'
      when 'diplomas' then 'Diploma''s'
      when 'feedback' then 'Feedback'
      when 'projects' then 'Projecten'
    end;
end;
$$;

-- 3. Changing evidence means confirming it again ---------------------------------------------------------------------
-- Before: a confirmed or imported item could not be changed at all. Now you may change it, and it becomes "toVerify".
-- An account may still never set a status itself, except back to "toVerify"; source and organisation stay server-only.
create or replace function public.guard_vault_item_authority()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.source <> 'user' or new.verification_status <> 'toVerify' or new.organization_id is not null then
        raise exception 'Vault items must be user-created, unverified and not linked to an organisation' using errcode = '42501';
      end if;
    else
      if new.source is distinct from old.source or new.organization_id is distinct from old.organization_id then
        raise exception 'Only trusted server code may change source or organisation' using errcode = '42501';
      end if;
      if new.verification_status is distinct from old.verification_status and new.verification_status <> 'toVerify' then
        raise exception 'Only trusted server code may confirm or reject an item' using errcode = '42501';
      end if;
      if (new.category, new.title, new.description, new.organisation_name, new.organisation_location,
          new.start_date, new.end_date, new.issued_on, new.is_current)
         is distinct from
         (old.category, old.title, old.description, old.organisation_name, old.organisation_location,
          old.start_date, old.end_date, old.issued_on, old.is_current) then
        new.verification_status := 'toVerify';
      end if;
    end if;
  end if;
  return new;
end;
$$;

-- Adding or removing a file changes the evidence too. Skipped when the item itself is being deleted (the files go with it).
create or replace function public.reverify_vault_item_after_file_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  changed public.vault_item_files;
begin
  if coalesce(auth.role(), '') = 'service_role' or pg_trigger_depth() > 1 then
    return null;
  end if;
  changed := coalesce(new, old);
  update public.vault_items
  set verification_status = 'toVerify'
  where id = changed.item_id and user_id = changed.user_id and verification_status <> 'toVerify';
  return null;
end;
$$;

drop trigger if exists vault_item_files_reverify on public.vault_item_files;
create trigger vault_item_files_reverify
  after insert or delete on public.vault_item_files
  for each row execute function public.reverify_vault_item_after_file_change();

comment on table public.vault_items is
  'The account-owned evidence records in the PAVE vault. Only trusted server code may confirm, reject, set the source or '
  'link an organisation. Changing a confirmed item or its files sets it back to toVerify, so it is confirmed again.';
