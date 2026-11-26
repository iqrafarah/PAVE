-- The language of PAVE (Instellingen › Taal) follows the account to every device, like the display mode from
-- 20261119140000_profile_display_mode.sql. Null: not chosen yet, so each device uses its own language when it has it
-- and Dutch otherwise. Part of the shared schema: run it with the web team.
-- The apps keep working without this column: the choice then stays on the device.

alter table public.profiles
  add column if not exists language text;

alter table public.profiles drop constraint if exists profiles_language_check;
alter table public.profiles add constraint profiles_language_check
  check (language is null or language in ('nl', 'en', 'pap'));

comment on column public.profiles.language is
  'nl (Nederlands), en (English) or pap (Papiamentu); null follows the language of the device.';

create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  own text[] := array[
    'preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'display_mode',
    'chat_expiry_days', 'chat_expiry_from', 'chat_expiry_keeps_pinned', 'chat_expiry_keeps_locked', 'ayla_uses_archive',
    'language', 'updated_at'
  ];
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if (to_jsonb(new) - own) is distinct from (to_jsonb(old) - own) then
      raise exception 'Only the name, photo and preferences can be changed here' using errcode = '42501';
    end if;
    if new.avatar_path is not null and split_part(new.avatar_path, '/', 1) <> new.id::text then
      raise exception 'The photo must be in the folder of this account' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

grant update (language) on public.profiles to authenticated;
