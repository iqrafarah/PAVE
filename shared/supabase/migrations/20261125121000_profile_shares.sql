-- Profiel en delen: a selection of your data, shared with someone for a while, which you can pause and take back.
--
-- A share is a code (128 random bits) behind a link and a QR code. Whoever has the code sees what the owner chose,
-- through the function `share-view`, only while the share is not paused, taken back or past its end date. Each look is
-- written down, so the owner sees who looked at what and when. Evidence is not copied: the share names vault items, and
-- `share-view` reads them as they are at that moment (deleted or archived ones drop out, a status is never taken from the
-- share). What is not in the vault (the CV and letter made on the phone, contact details) is kept with the share, and
-- wiped as soon as the share is taken back or has ended.
--
-- Also the employers of the job fair demo: fictional, readable by everyone, so a QR code at a stand opens their card.
-- Can be run again.

-- Shares ---------------------------------------------------------------------------------------------------------------

create table if not exists public.profile_shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  code text not null unique default encode(extensions.gen_random_bytes(16), 'hex'),
  title text not null check (length(btrim(title)) between 1 and 120),
  recipient_name text not null check (length(btrim(recipient_name)) between 1 and 120),
  recipient_organisation text check (recipient_organisation is null or length(recipient_organisation) <= 120),
  purpose text check (purpose is null or length(purpose) <= 200),
  template text not null check (template in ('employer', 'education', 'municipality', 'fair')),
  item_ids uuid[] not null default '{}' check (cardinality(item_ids) <= 100),
  content jsonb not null default '{}' check (jsonb_typeof(content) = 'object' and pg_column_size(content) < 200000),
  allows_download boolean not null default false,
  expires_at timestamptz not null,
  paused_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- At most a year, and never in the past when it is made.
  check (expires_at <= created_at + interval '366 days'),
  check (expires_at > created_at)
);

create index if not exists profile_shares_user on public.profile_shares (user_id, created_at desc);

-- The code and the owner never change; taking back is for good and wipes what was kept with it.
create or replace function public.profile_shares_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.code <> old.code or new.user_id <> old.user_id or new.created_at <> old.created_at then
    raise exception 'A share keeps its code and owner';
  end if;
  if old.revoked_at is not null then
    raise exception 'A share that was taken back stays taken back';
  end if;
  if new.revoked_at is not null then
    new.content := '{}'::jsonb;
    new.item_ids := '{}';
    new.paused_at := null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profile_shares_guard on public.profile_shares;
create trigger profile_shares_guard
  before update on public.profile_shares
  for each row execute function public.profile_shares_guard();

alter table public.profile_shares enable row level security;

drop policy if exists "Require two-step verification" on public.profile_shares;
create policy "Require two-step verification"
  on public.profile_shares as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own shares" on public.profile_shares;
create policy "Own shares"
  on public.profile_shares for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.profile_shares from anon;
grant select, insert, update, delete on public.profile_shares to authenticated;

-- Who looked ---------------------------------------------------------------------------------------------------------------

create table if not exists public.profile_share_views (
  id uuid primary key default gen_random_uuid(),
  share_id uuid not null references public.profile_shares (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  action text not null check (action in ('view', 'download')),
  -- What the visitor said about themselves, when they did: not checked.
  viewer_name text check (viewer_name is null or length(viewer_name) <= 80),
  viewer_organisation text check (viewer_organisation is null or length(viewer_organisation) <= 80)
);

create index if not exists profile_share_views_share on public.profile_share_views (share_id, viewed_at desc);

alter table public.profile_share_views enable row level security;

drop policy if exists "Require two-step verification" on public.profile_share_views;
create policy "Require two-step verification"
  on public.profile_share_views as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

-- The owner reads the log of their own shares; only `share-view` writes it.
drop policy if exists "Views of own shares" on public.profile_share_views;
create policy "Views of own shares"
  on public.profile_share_views for select to authenticated
  using (exists (select 1 from public.profile_shares s where s.id = share_id and s.user_id = (select auth.uid())));

revoke all on public.profile_share_views from anon;
grant select on public.profile_share_views to authenticated;

-- Ended shares keep nothing ------------------------------------------------------------------------------------------------

create or replace function public.wipe_ended_shares()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profile_shares
  set content = '{}'::jsonb, item_ids = '{}'
  where expires_at < now() and (content <> '{}'::jsonb or cardinality(item_ids) > 0);
$$;

revoke all on function public.wipe_ended_shares() from public, anon, authenticated;

select cron.unschedule('wipe-ended-shares') where exists (select 1 from cron.job where jobname = 'wipe-ended-shares');
select cron.schedule('wipe-ended-shares', '41 * * * *', 'select public.wipe_ended_shares()');

-- Files kept with a share (the CV and letter as pdf) ----------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-shares', 'profile-shares', false, 5242880, array['application/pdf'])
on conflict (id) do nothing;

-- Under a folder named after the owner; `share-view` hands the recipient a link that works for a few minutes.
drop policy if exists "Own share files" on storage.objects;
create policy "Own share files"
  on storage.objects for all to authenticated
  using (bucket_id = 'profile-shares' and (storage.foldername(name))[1] = (select auth.uid())::text and public.is_mfa_verified())
  with check (bucket_id = 'profile-shares' and (storage.foldername(name))[1] = (select auth.uid())::text and public.is_mfa_verified());

-- Job fair demo: employers ------------------------------------------------------------------------------------------------

create table if not exists public.fair_employers (
  slug text primary key check (slug ~ '^[a-z0-9-]{2,40}$'),
  name text not null,
  city text,
  about text not null,
  stand text,
  website text,
  vacancies jsonb not null default '[]' check (jsonb_typeof(vacancies) = 'array'),
  -- Fictional, made for the demo; shown as such.
  is_example boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.fair_employers enable row level security;

drop policy if exists "Everyone reads the fair" on public.fair_employers;
create policy "Everyone reads the fair"
  on public.fair_employers for select to anon, authenticated
  using (true);

grant select on public.fair_employers to anon, authenticated;

insert into public.fair_employers (slug, name, city, about, stand, vacancies) values
  ('kade-consultancy', 'Kade Consultancy', 'Eindhoven',
   'Adviesbureau voor cloud en IT-beheer bij middelgrote bedrijven. Starters werken mee in een vast team en krijgen een opleidingsbudget.',
   'Stand 12',
   '[{"id":"fair-kade-1","title":"Junior IT-consultant","company":"Kade Consultancy","city":"Eindhoven","employment":"fullTime","source":"example","summary":"Je adviseert klanten over cloud en beveiliging, samen met een senior collega. Een Scrum-certificaat is een pre.","matches":[],"skillGap":[]}]'::jsonb),
  ('studio-noorderlicht', 'Studio Noorderlicht', 'Utrecht',
   'Klein appbureau dat iOS- en webapps bouwt voor culturele instellingen.',
   'Stand 4',
   '[{"id":"fair-noorderlicht-1","title":"Junior iOS-ontwikkelaar","company":"Studio Noorderlicht","city":"Utrecht","employment":"partTime","source":"example","summary":"Je bouwt mee aan apps in SwiftUI, van ontwerp tot App Store.","matches":[],"skillGap":[]}]'::jsonb),
  ('lumen-data', 'Lumen Data', 'Tilburg',
   'Databedrijf dat dashboards maakt voor gemeenten en zorgorganisaties.',
   'Stand 21',
   '[{"id":"fair-lumen-1","title":"Data-analist (starter)","company":"Lumen Data","city":"Tilburg","employment":"fullTime","source":"example","summary":"Je zet data om in dashboards en werkt met Python en SQL.","matches":[],"skillGap":[]},{"id":"fair-lumen-2","title":"Stage software engineering","company":"Lumen Data","city":"Tilburg","employment":"fullTime","source":"example","summary":"Afstudeerstage van vijf maanden in het platformteam.","matches":[],"skillGap":[]}]'::jsonb)
on conflict (slug) do update set name = excluded.name, city = excluded.city, about = excluded.about, stand = excluded.stand, vacancies = excluded.vacancies;
