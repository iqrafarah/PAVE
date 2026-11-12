-- Instellingen (Figma FEDDIES 1393:5359): what an account may change about itself, for web and iOS alike.
--  1. The name Ayla uses (preferred_name) and an own profile photo. The full name, e-mail, role and organisation come
--     from the school or organisation and stay as they are.
--  2. Three preferences that follow the account to every device: theme colour, text size and how the vault opens.
--  3. A private bucket for profile photos, one folder per account.
--
-- `profiles` is the web team's table (docs/vault.md); this only adds columns and a narrow update rule. Not applied yet.
-- Part of the shared schema: run it only together with the web team.

-- 1 and 2. Columns -----------------------------------------------------------------------------------------------------

alter table public.profiles
  add column if not exists avatar_path text
    check (avatar_path is null or avatar_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|jpeg|png|heic)$'),
  add column if not exists theme_color text not null default 'green',
  add column if not exists theme_custom_color text,
  add column if not exists text_size text not null default 'standard'
    check (text_size in ('small', 'standard', 'large')),
  add column if not exists vault_layout text not null default 'grid'
    check (vault_layout in ('list', 'grid'));

alter table public.profiles drop constraint if exists profiles_theme_color_check;
alter table public.profiles add constraint profiles_theme_color_check
  check (theme_color in ('green', 'blue', 'gold', 'pink', 'orange', 'purple', 'red', 'lime', 'custom'));

alter table public.profiles drop constraint if exists profiles_theme_custom_color_check;
alter table public.profiles add constraint profiles_theme_custom_color_check
  check (theme_custom_color is null or theme_custom_color ~ '^#[0-9A-F]{6}$');

alter table public.profiles drop constraint if exists profiles_preferred_name_length;
alter table public.profiles add constraint profiles_preferred_name_length
  check (preferred_name is null or length(btrim(preferred_name)) between 1 and 60);

comment on column public.profiles.avatar_path is
  'An own profile photo in the pave-avatars bucket (<user id>/<uuid>.<ext>). Wins over avatar_url when set.';
comment on column public.profiles.theme_color is 'The accent colour the apps use for this account; custom uses theme_custom_color.';
comment on column public.profiles.theme_custom_color is
  'An own accent colour as #RRGGBB. The apps darken it until white text on it is readable (WCAG AA, 4.5:1).';
comment on column public.profiles.text_size is 'small, standard (the device setting) or large.';
comment on column public.profiles.vault_layout is 'How the vault opens: list or grid. The vault can still switch for a moment.';

-- Only these columns may be changed by the account itself; everything else stays with the school or trusted code.
create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if (to_jsonb(new) - array['preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'updated_at'])
       is distinct from
       (to_jsonb(old) - array['preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'updated_at']) then
      raise exception 'Only the name, photo and preferences can be changed here' using errcode = '42501';
    end if;
    if new.avatar_path is not null and split_part(new.avatar_path, '/', 1) <> new.id::text then
      raise exception 'The photo must be in the folder of this account' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_profile_self_update on public.profiles;
create trigger guard_profile_self_update
  before update on public.profiles
  for each row execute function public.guard_profile_self_update();

alter table public.profiles enable row level security;

drop policy if exists "Profile changes need two-step verification" on public.profiles;
create policy "Profile changes need two-step verification"
  on public.profiles as restrictive for update to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Update own profile settings" on public.profiles;
create policy "Update own profile settings"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

grant update (preferred_name, avatar_path, theme_color, theme_custom_color, text_size, vault_layout) on public.profiles to authenticated;

-- 3. Profile photos ---------------------------------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pave-avatars', 'pave-avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatars need two-step verification" on storage.objects;
create policy "Avatars need two-step verification"
  on storage.objects as restrictive for all to authenticated
  using (bucket_id <> 'pave-avatars' or public.is_mfa_verified())
  with check (bucket_id <> 'pave-avatars' or public.is_mfa_verified());

drop policy if exists "Own avatar objects" on storage.objects;
create policy "Own avatar objects"
  on storage.objects for all to authenticated
  using (bucket_id = 'pave-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (
    bucket_id = 'pave-avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  );
