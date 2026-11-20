-- Removes the task-scoped consent tables of 20261110120000_vault.sql. Nothing ever wrote to them: Ayla uses the items
-- the user allowed (vault_items.ayla_allowed_at), and only after a Ja to looking in the vault in that conversation
-- (shared/supabase/functions/ayla/consent.ts). Their triggers, policies and indexes go with the tables.
--
-- Safe to run again.

drop table if exists public.vault_access_grant_items;
drop table if exists public.vault_access_grant_categories;
drop table if exists public.vault_access_grants;
drop function if exists public.guard_vault_access_grant_update();

comment on column public.vault_items.ayla_allowed_at is
  'When the user allowed Ayla to read this item and its files; null means not allowed.';
