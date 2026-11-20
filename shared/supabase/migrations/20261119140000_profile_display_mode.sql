-- Licht, donker of automatisch: the display mode follows the account to every device (web and iOS), like the theme
-- colour and text size from 20261112170000_profile_settings.sql. Part of the shared schema: run it with the web team.
-- The apps keep working without this column: the choice then stays on the device.

alter table public.profiles
  add column if not exists display_mode text not null default 'auto';

alter table public.profiles drop constraint if exists profiles_display_mode_check;
alter table public.profiles add constraint profiles_display_mode_check
  check (display_mode in ('auto', 'light', 'dark'));

comment on column public.profiles.display_mode is
  'auto (dark from 19:00 to 07:00 on the device), light or dark.';

create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if (to_jsonb(new) - array['preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'display_mode', 'updated_at'])
       is distinct from
       (to_jsonb(old) - array['preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'display_mode', 'updated_at']) then
      raise exception 'Only the name, photo and preferences can be changed here' using errcode = '42501';
    end if;
    if new.avatar_path is not null and split_part(new.avatar_path, '/', 1) <> new.id::text then
      raise exception 'The photo must be in the folder of this account' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

grant update (display_mode) on public.profiles to authenticated;
