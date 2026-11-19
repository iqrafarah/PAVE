-- Projects get an icon and a colour of their own (web). Same names as the vault folders: the icon is one of the folder
-- icons (folder, briefcase, rocket-launch, ...), the colour one of the theme colours (green, blue, gold, ...).
-- Run after 20261118120000_ayla_projects.sql. Safe to run more than once. Until this runs, every project shows the
-- default folder in the brand colour and the picker is hidden.

alter table public.ayla_projects add column if not exists icon text check (icon is null or length(icon) <= 40);
alter table public.ayla_projects add column if not exists color text check (color is null or color ~ '^[a-z]{3,10}$' or color ~ '^#[0-9a-f]{6}$');
