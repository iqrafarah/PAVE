-- Several locations of one organisation in one city (see docs/verificatie.md).
--
-- Until now a location was only a city, and an organisation could have one location per city. But Tilburg has more
-- than one McDonald's, often each with its own franchisee. So a location gets its own name ("Westermarkt") and, when
-- known, an address; the learner sees "McDonald's · Westermarkt, Tilburg" and finds it by name, city or street.
--
--   name      optional; without one the location is just its city, as before. Needed as soon as an organisation
--             has a second location in a city.
--   address   optional, shown under the location so the learner knows which one it is.
--
-- An organisation can now have several locations per city, as long as their names differ. The earlier migrations that
-- add locations with "on conflict (organization_id, city)" are history: run them again only on an empty database.
-- Safe to run again.

-- 1. Name and address --------------------------------------------------------------------------------------------------

alter table public.organization_locations add column if not exists name text;
alter table public.organization_locations add column if not exists address text;

alter table public.organization_locations drop constraint if exists organization_locations_name_length;
alter table public.organization_locations add constraint organization_locations_name_length
  check (name is null or length(btrim(name)) between 1 and 100);
alter table public.organization_locations drop constraint if exists organization_locations_address_length;
alter table public.organization_locations add constraint organization_locations_address_length
  check (address is null or length(btrim(address)) between 1 and 200);

comment on column public.organization_locations.name is
  'The name of this location within its city ("Westermarkt"); needed when the organisation has more than one there.';
comment on column public.organization_locations.address is 'The street address, shown so the learner knows which location.';

-- One city, several locations: unique by organisation, city and name. Two unnamed locations in one city stay impossible.
alter table public.organization_locations drop constraint if exists organization_locations_organization_id_city_key;
alter table public.organization_locations drop constraint if exists organization_locations_place;
alter table public.organization_locations add constraint organization_locations_place
  unique nulls not distinct (organization_id, city, name);

-- 2. The persons a learner may ask, now with the name of their location ------------------------------------------------
-- The return type changes, so the function is dropped first; the functions that read it are made again below.

drop function if exists public.validation_available_contacts(text);

create function public.validation_available_contacts(p_category text)
returns table (
  id uuid, name text, job_title text, function text,
  department_id uuid, department_name text, location_id uuid, city text, organization_id uuid, location_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.job_title, coalesce(nullif(btrim(c.job_title), ''), 'Overig'),
         d.id, d.name, l.id, l.city, l.organization_id, l.name
  from public.organization_contacts c
  join public.organization_departments d on d.id = c.department_id
  join public.organization_locations l on l.id = d.location_id
  join public.organizations o on o.id = l.organization_id and o.kind is not null
  where c.is_active
    and c.reviewer_id is not null
    and c.reviewer_id <> (select auth.uid())
    and exists (
      select 1 from public.organization_contact_evidence_types t
      where t.contact_id = c.id and t.category = p_category
    );
$$;

revoke all on function public.validation_available_contacts(text) from public, anon, authenticated;

-- 3. Locations: with name and address, searched on organisation, city, name and address ---------------------------------

drop function if exists public.validation_search_places(text, text, text, uuid, int, int);
drop function if exists public.validation_places_by_id(text, uuid[]);

create function public.validation_search_places(
  p_category text, p_query text default null, p_kind text default null, p_organization_id uuid default null,
  p_limit int default 25, p_offset int default 0
)
returns table (
  organization_id uuid, organization_name text, kind text, logo_url text, location_id uuid, city text,
  location_name text, address text, available_contacts int, total_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with people as (
    select a.location_id, count(*)::int as available
    from public.validation_available_contacts(p_category) a
    group by a.location_id
  )
  select o.id, o.name, o.kind, o.logo_url, l.id, l.city, l.name, l.address, p.available, count(*) over ()
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id and o.kind is not null
  join people p on p.location_id = l.id
  where (p_kind is null or o.kind = p_kind)
    and (p_organization_id is null or o.id = p_organization_id)
    and public.validation_matches(concat_ws(' ', o.name, l.city, l.name, l.address), p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by o.name, l.city, l.name nulls first
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create function public.validation_places_by_id(p_category text, p_location_ids uuid[])
returns table (
  organization_id uuid, organization_name text, kind text, logo_url text, location_id uuid, city text,
  location_name text, address text, available_contacts int
)
language sql
stable
security definer
set search_path = ''
as $$
  with people as (
    select a.location_id, count(*)::int as available
    from public.validation_available_contacts(p_category) a
    where a.location_id = any (p_location_ids)
    group by a.location_id
  )
  select o.id, o.name, o.kind, o.logo_url, l.id, l.city, l.name, l.address, coalesce(p.available, 0)
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id and o.kind is not null
  left join people p on p.location_id = l.id
  where l.id = any (p_location_ids[1:20])
    and public.is_mfa_verified() and (select auth.uid()) is not null;
$$;

revoke all on function public.validation_search_places(text, text, text, uuid, int, int) from public, anon;
revoke all on function public.validation_places_by_id(text, uuid[]) from public, anon;
grant execute on function public.validation_search_places(text, text, text, uuid, int, int) to authenticated;
grant execute on function public.validation_places_by_id(text, uuid[]) to authenticated;

-- 4. Persons, with the name of their location -------------------------------------------------------------------------

drop function if exists public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int);

create function public.validation_search_contacts(
  p_organization_id uuid, p_category text, p_query text default null,
  p_location_id uuid default null, p_department text default null, p_function text default null,
  p_limit int default 25, p_offset int default 0
)
returns table (
  id uuid, name text, job_title text, function text, department_id uuid, department_name text,
  location_id uuid, city text, organization_id uuid, location_name text, total_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.name, a.job_title, a.function, a.department_id, a.department_name,
         a.location_id, a.city, a.organization_id, a.location_name, count(*) over ()
  from public.validation_available_contacts(p_category) a
  where a.organization_id = p_organization_id
    and (p_location_id is null or a.location_id = p_location_id)
    and (p_department is null or a.department_name = p_department)
    and (p_function is null or a.function = p_function)
    and public.validation_matches(concat_ws(' ', a.name, a.function, a.department_name, a.city, a.location_name), p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by a.name, a.city, a.department_name
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int) from public, anon;
grant execute on function public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int) to authenticated;
comment on function public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int) is
  'A page of persons of one organisation who may confirm this kind of evidence. Never returns the account behind them.';

drop function if exists public.validation_previous_contacts(text, int);

create function public.validation_previous_contacts(p_category text, p_limit int default 5)
returns table (
  id uuid, name text, job_title text, function text, department_id uuid, department_name text,
  location_id uuid, city text, organization_id uuid, organization_name text, location_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.name, a.job_title, a.function, a.department_id, a.department_name,
         a.location_id, a.city, a.organization_id, o.name, a.location_name
  from (
    select r.contact_id, max(r.requested_at) as last_requested_at
    from public.vault_validation_requests r
    where r.user_id = (select auth.uid()) and r.contact_id is not null
    group by r.contact_id
  ) asked
  join public.validation_available_contacts(p_category) a on a.id = asked.contact_id
  join public.organizations o on o.id = a.organization_id
  where public.is_mfa_verified()
  order by asked.last_requested_at desc
  limit least(greatest(coalesce(p_limit, 5), 1), 20);
$$;

revoke all on function public.validation_previous_contacts(text, int) from public, anon;
grant execute on function public.validation_previous_contacts(text, int) to authenticated;

-- 5. The location filter names the location too ------------------------------------------------------------------------

create or replace function public.validation_contact_filters(p_organization_id uuid, p_category text)
returns table (filter text, value text, label text, location_id uuid, people int)
language sql
stable
security definer
set search_path = ''
as $$
  with people as (
    select a.* from public.validation_available_contacts(p_category) a
    where a.organization_id = p_organization_id
      and public.is_mfa_verified() and (select auth.uid()) is not null
  )
  -- "Westermarkt, Tilburg"; "Tilburg-Noord" when the name already says the city; "Tilburg" without a name.
  select 'location', p.location_id::text,
         case when p.location_name ilike '%' || p.city || '%' then p.location_name
              else concat_ws(', ', p.location_name, p.city) end,
         p.location_id, count(*)::int
  from people p group by p.location_id, p.location_name, p.city
  union all
  select 'department', p.department_id::text, p.department_name, p.location_id, count(*)::int
  from people p group by p.department_id, p.department_name, p.location_id
  union all
  select 'function', p.function, p.function, p.location_id, count(*)::int from people p group by p.function, p.location_id
  order by 1, 3;
$$;
