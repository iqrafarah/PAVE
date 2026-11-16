-- Vault, round two: remove what nothing uses any more, and add what the new vault screens need
-- (Figma FEDDIES: add evidence 1348:2351 and 1348:2537, consent picker 1173:21147, vault grid 1209:55066 and list 1209:53998).
-- See docs/vault.md, "Round two".
--
-- Applied on 2026-11-10. This is part of the shared schema: change it only together with the web team.
-- It replaces the unapplied proposal 20261110150000_vault_folder_style.sql (folder colour and icon are in here).
-- Every step can run on the current database: drops use "if exists", and nothing here deletes vault rows.

-- 1. Remove ---------------------------------------------------------------------------------------------------------

-- 1a. Leftovers of the first password reset (20261105130000, taken out of the repo in fe5e73b). Neither app nor any
-- Edge Function calls them; the reset now uses the e-mail code of Supabase Auth. get_verified_totp_secret could read
-- authenticator secrets, so it should not stay behind even unused.
drop function if exists public.get_verified_totp_secret(text);
drop function if exists public.count_password_reset_failures(text, integer);
drop function if exists public.record_password_reset_failure(text);
drop function if exists public.create_password_reset_token(uuid, text, integer);
drop function if exists public.consume_password_reset_token(text);
drop function if exists public.revoke_user_sessions(uuid);
drop table if exists private.password_reset_tokens;
drop table if exists private.password_reset_failures;

do $$
begin
  -- The private schema was made for these tables only; keep it if someone has put something else in it since.
  if exists (select 1 from pg_namespace where nspname = 'private')
     and not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'private')
     and not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private') then
    drop schema private;
  end if;
end;
$$;

-- 1b. Folders are your own groups. The category folders on top of the vault are not rows but the item categories, so a
-- folder does not need a category; no screen shows or edits a folder description either.
alter table public.vault_folders drop column if exists category;
alter table public.vault_folders drop column if exists description;

-- 2. Add ------------------------------------------------------------------------------------------------------------

-- 2a. Folder colour and icon (the "Nieuwe map" sheet on iOS). Null shows the default: green with a folder.
alter table public.vault_folders
  add column if not exists color text check (color is null or color in ('green', 'blue', 'purple', 'rust', 'rose', 'slate')),
  add column if not exists icon text check (icon is null or icon in (
    'folder', 'briefcase', 'academic-cap', 'check-badge', 'wrench-screwdriver', 'chat-bubble-left-ellipsis',
    'star', 'heart', 'code-bracket', 'light-bulb', 'rocket-launch', 'globe-europe-africa', 'paint-brush',
    'document-text', 'user-group', 'trophy'
  ));

-- 2b. "Overige" in the category bar of the consent picker and the vault: for evidence that fits no other category.
-- Drop the old category checks by what they check, not by name, so a differently named check cannot stay behind.
do $$
declare
  target record;
begin
  for target in
    select c.conrelid::regclass as table_name, c.conname
    from pg_constraint c
    where c.contype = 'c'
      and c.conrelid in ('public.vault_items'::regclass, 'public.vault_access_grant_categories'::regclass)
      and pg_get_constraintdef(c.oid) like '%reflections%'
  loop
    execute format('alter table %s drop constraint %I', target.table_name, target.conname);
  end loop;
end;
$$;

alter table public.vault_items add constraint vault_items_category_check check (category in (
  'diplomas', 'certificates', 'badges', 'projects', 'workExperience', 'internships', 'skills', 'feedback',
  'reflections', 'other'
));
alter table public.vault_access_grant_categories add constraint vault_access_grant_categories_category_check check (category in (
  'diplomas', 'certificates', 'badges', 'projects', 'workExperience', 'internships', 'skills', 'feedback',
  'reflections', 'other'
));

-- 2c. The organisation behind an item, for its logo on the cards (grid and list). Only trusted server code links an item
-- to an organisation (see the guard below): a logo must not make something you typed yourself look official.
-- What you type yourself stays in organisation_name.
alter table public.organizations
  add column if not exists logo_url text check (logo_url is null or logo_url ~ '^https://');
comment on column public.organizations.logo_url is 'A public https image of the organisation''s logo, shown on vault cards.';

alter table public.vault_items
  add column if not exists organization_id uuid references public.organizations (id) on delete set null;
create index if not exists vault_items_organization on public.vault_items (organization_id) where organization_id is not null;

-- 2d. Step 4 "Toestemming" of adding evidence: "Ayla mag dit document bekijken en gebruiken". Off unless you tick it, and
-- you can take it back any time (set it to null). The time is when you agreed. A task grant (vault_access_grants) is
-- still how you share items for one question; this is the standing yes for one item.
alter table public.vault_items
  add column if not exists ayla_allowed_at timestamptz;
create index if not exists vault_items_ayla_allowed on public.vault_items (user_id) where ayla_allowed_at is not null;
comment on column public.vault_items.ayla_allowed_at is
  'When the user allowed Ayla to read this item and its files outside a task grant; null means not allowed.';

-- 2e. Skills (step 3 "Vaardigheden") already live in vault_item_skills, files (step 2 "Documenten") in vault_item_files,
-- and "Verifiëren" in vault_validation_requests. No change needed there.

-- 3. Tighten the item guard ---------------------------------------------------------------------------------------------
-- Before: an account could not change source or verification_status. Now also:
--  * the organisation link is set by trusted server code only;
--  * a verified item, or one that came from an organisation, Ayla or an import, keeps its content as it was confirmed.
--    You can still move it to a folder, allow or stop Ayla, or delete it. (iOS already works like this.)
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
      if new.source is distinct from old.source
         or new.verification_status is distinct from old.verification_status
         or new.organization_id is distinct from old.organization_id then
        raise exception 'Only trusted server code may change source, verification status or organisation' using errcode = '42501';
      end if;
      if (old.verification_status = 'verified' or old.source <> 'user')
         and (new.category, new.title, new.description, new.organisation_name, new.organisation_location,
              new.start_date, new.end_date, new.issued_on, new.is_current)
             is distinct from
             (old.category, old.title, old.description, old.organisation_name, old.organisation_location,
              old.start_date, old.end_date, old.issued_on, old.is_current) then
        raise exception 'A confirmed item keeps the content it was confirmed with' using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end;
$$;

comment on table public.vault_items is
  'The account-owned evidence records in the PAVE vault. Only trusted server code may change verification_status, source '
  'or organization_id, and the content of a verified or imported item stays as it was confirmed.';
