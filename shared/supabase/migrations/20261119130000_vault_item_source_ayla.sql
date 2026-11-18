-- "Bron: Via Ayla" in the vault filter. Until now the app could only add items with source 'user', so evidence that Ayla
-- filled in ("Laat Ayla invullen", or saved from the chat) showed under "Zelf toegevoegd" and "Via Ayla" stayed empty.
-- The app may now add an item with source 'ayla' as well. That says only who filled it in: such an item is still the
-- user's own, unconfirmed and not linked to an organisation, and 'organization' and 'import' stay for trusted server
-- code. The rest of guard_vault_item_authority is unchanged (20261112120000).
--
-- Run after 20261112120000_vault_cover_example_folders_reverify.sql. Safe to run more than once. Required before the web
-- saves Ayla-filled evidence; failed inserts must not silently change its source to 'user'.
-- Existing mislabelled items need a targeted correction after their origin has been confirmed.

create or replace function public.guard_vault_item_authority()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.source not in ('user', 'ayla') or new.verification_status <> 'toVerify' or new.organization_id is not null then
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
