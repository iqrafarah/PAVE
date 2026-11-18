-- Folders in the vault get a colour of your own and can be pinned (web).
--
-- 1. color: the colours to choose from are now the theme colours of Settings, so gold, red and lime join the named
--    colours (rose is "Roze", rust is "Oranje"; slate stays for folders that have it). Besides those, a colour you
--    picked yourself as `#rrggbb` (lower case). A client that does not know a colour shows the default green, as for null.
-- 2. pinned_at: a pinned folder comes first in the folder row. Read folders in the order
--    `pinned_at is null, position asc nulls last, created_at asc`.
--
-- Run after 20261113120000_vault_order.sql. Safe to run more than once. Until this runs, the web keeps pins in the
-- browser (and moves them here once it has run) and says Goud, Rood, Limoen or an own colour cannot be saved yet. Part of the shared schema: run it together with the iOS team.

-- Drop the old colour check by what it checks, not by name, so a differently named check cannot stay behind.
do $$
declare
  target record;
begin
  for target in
    select c.conname
    from pg_constraint c
    where c.contype = 'c'
      and c.conrelid = 'public.vault_folders'::regclass
      and pg_get_constraintdef(c.oid) ilike '%color%'
  loop
    execute format('alter table public.vault_folders drop constraint %I', target.conname);
  end loop;
end;
$$;

alter table public.vault_folders
  add constraint vault_folders_color_check check (
    color is null
    or color in ('green', 'blue', 'gold', 'rose', 'rust', 'purple', 'red', 'lime', 'slate')
    or color ~ '^#[0-9a-f]{6}$'
  );

alter table public.vault_folders add column if not exists pinned_at timestamptz;
