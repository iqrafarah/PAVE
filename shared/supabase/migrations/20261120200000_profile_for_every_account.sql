-- Every account gets a profile. Accounts come from the organisation (Supabase dashboard or invite), never from the apps,
-- and until now nothing created the matching row in public.profiles.
--
-- The name comes from the account's metadata (full_name or name) when the organisation set it; otherwise it stays empty
-- and the user can fill in their preferred name in the apps. Every new account is a learner; organization_id and admin
-- are set by the organisation (SQL Editor).
--
-- Safe to run again.

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')), ''),
    'learner'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.create_profile_for_new_user() from public, anon, authenticated;

drop trigger if exists profile_on_signup on auth.users;
create trigger profile_on_signup
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

-- Accounts that already exist without a profile.
insert into public.profiles (id, email, full_name, role)
select u.id,
       u.email,
       nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ''),
       'learner'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;

comment on function public.create_profile_for_new_user() is 'Creates the profile of a new account: email, name from the metadata, role learner.';
