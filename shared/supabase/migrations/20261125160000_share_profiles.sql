-- Profielen: a set of your evidence for a kind of recipient ("Voor werkgevers", "Voor school"), made once and shared
-- in two taps after that. Per piece of evidence it says whether it is shown briefly (title, organisation, period and
-- status) or in full (also the description and skills). Nothing is shared by keeping a profile: sharing still makes a
-- row in profile_shares, which the recipient reads through `share-view`. Only the owner reads and writes them.
-- Can be run again.

create table if not exists public.share_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  template text not null check (template in ('employer', 'education', 'municipality', 'fair')),
  item_ids uuid[] not null default '{}' check (cardinality(item_ids) <= 100),
  -- The pieces of evidence that are shown briefly; the rest in full.
  brief_ids uuid[] not null default '{}' check (cardinality(brief_ids) <= 100),
  headline text check (headline is null or length(headline) <= 120),
  includes_email boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists share_profiles_user on public.share_profiles (user_id, updated_at desc);

create or replace function public.share_profiles_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id <> old.user_id then
    raise exception 'A profile keeps its owner';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists share_profiles_touch on public.share_profiles;
create trigger share_profiles_touch
  before update on public.share_profiles
  for each row execute function public.share_profiles_touch();

alter table public.share_profiles enable row level security;

drop policy if exists "Require two-step verification" on public.share_profiles;
create policy "Require two-step verification"
  on public.share_profiles as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own profiles" on public.share_profiles;
create policy "Own profiles"
  on public.share_profiles for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.share_profiles from anon;
grant select, insert, update, delete on public.share_profiles to authenticated;
