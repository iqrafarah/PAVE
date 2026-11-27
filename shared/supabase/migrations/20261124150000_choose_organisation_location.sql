-- Choosing an organisation means choosing one of its locations (see docs/verificatie.md).
--
-- A location is not always run by the same people as the rest of the organisation: an Albert Heijn or a McDonald's is
-- often its own entrepreneur. So the learner picks "Albert Heijn · Breda" in one go, and only sees the persons there.
-- These functions return one row per location, only locations where someone may confirm this kind of evidence, with
-- the organisation's logo (logo_url) when it has one. The earlier organisation functions stay. Safe to run again,
-- also after an earlier version of this file (the functions are dropped first, because their columns changed).

drop function if exists public.validation_search_places(text, text, text, uuid, int, int);
drop function if exists public.validation_places_by_id(text, uuid[]);

-- A page of locations, searched on organisation name and city ("albert heijn breda"). p_kind: null for every kind.
-- p_organization_id: only the locations of one organisation (when the evidence names the organisation, not the city).
create or replace function public.validation_search_places(
  p_category text, p_query text default null, p_kind text default null, p_organization_id uuid default null,
  p_limit int default 25, p_offset int default 0
)
returns table (
  organization_id uuid, organization_name text, kind text, logo_url text, location_id uuid, city text,
  available_contacts int, total_count bigint
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
  select o.id, o.name, o.kind, o.logo_url, l.id, l.city, p.available, count(*) over ()
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id and o.kind is not null
  join people p on p.location_id = l.id
  where (p_kind is null or o.kind = p_kind)
    and (p_organization_id is null or o.id = p_organization_id)
    and public.validation_matches(o.name || ' ' || l.city, p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by o.name, l.city
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- Known locations by ID (from an earlier request), also when nobody there may confirm it any more:
-- available_contacts then says 0.
create or replace function public.validation_places_by_id(p_category text, p_location_ids uuid[])
returns table (
  organization_id uuid, organization_name text, kind text, logo_url text, location_id uuid, city text,
  available_contacts int
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
  select o.id, o.name, o.kind, o.logo_url, l.id, l.city, coalesce(p.available, 0)
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

create index if not exists organization_locations_organization on public.organization_locations (organization_id, city);

-- The filter choices now come per location, functions too, so the app shows only what there is at the chosen location.
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
  select 'location', p.location_id::text, p.city, p.location_id, count(*)::int from people p group by p.location_id, p.city
  union all
  select 'department', p.department_id::text, p.department_name, p.location_id, count(*)::int
  from people p group by p.department_id, p.department_name, p.location_id
  union all
  select 'function', p.function, p.function, p.location_id, count(*)::int from people p group by p.function, p.location_id
  order by 1, 3;
$$;
