-- The verification directory, ready for national use (see docs/verificatie.md).
--
--   * Every kind of organisation: onderwijs (school), bedrijven (company), overheid (government) and overig (other).
--   * An organisation can carry a registry number (KvK, BRIN, OIN), unique per registry, so imports and evidence can
--     point at exactly one organisation instead of matching on a name.
--   * Who may confirm what: organization_contact_evidence_types lists, per contact person, the kinds of evidence
--     (vault_items.category) they are authorised to confirm. An active PAVE account alone is not enough any more.
--     Existing contact persons keep confirming what they could before: they get every kind once, here, and an
--     administrator narrows that down. New contact persons can confirm nothing until a kind is granted.
--   * Searching happens in the database, a page at a time, through the validation_* functions below. They show only
--     persons who may confirm the given kind of evidence, never the learner, and never which account is behind someone.
--
-- Changes nothing that exists: no rows are removed, the old functions and table rights stay for older app versions.
-- Safe to run again.

-- 1. Kinds of organisation ---------------------------------------------------------------------------------------------

-- The old check on kind (school, company) may carry another name than the default: drop every check on kind.
do $$
declare
  existing record;
begin
  for existing in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.organizations'::regclass
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ~ '\mkind\M'
  loop
    execute format('alter table public.organizations drop constraint %I', existing.conname);
  end loop;
end $$;
alter table public.organizations add constraint organizations_kind_check
  check (kind is null or kind in ('school', 'company', 'government', 'other'));
comment on column public.organizations.kind is
  'school, company, government or other; null keeps the organisation out of the verification directory.';

-- 2. Registry numbers --------------------------------------------------------------------------------------------------

alter table public.organizations
  add column if not exists registry_type text,
  add column if not exists registry_id text;
alter table public.organizations drop constraint if exists organizations_registry;
alter table public.organizations add constraint organizations_registry check (
  (registry_type is null and registry_id is null)
  or (registry_type in ('kvk', 'brin', 'oin', 'other') and length(btrim(registry_id)) between 1 and 64)
);
create unique index if not exists organizations_registry_unique
  on public.organizations (registry_type, registry_id) where registry_id is not null;
comment on column public.organizations.registry_type is 'kvk (KvK-nummer), brin (onderwijs), oin (overheid) or other.';
comment on column public.organizations.registry_id is 'The number in that registry; unique per registry.';

-- 3. Who may confirm which kind of evidence ----------------------------------------------------------------------------

create table if not exists public.organization_contact_evidence_types (
  contact_id uuid not null references public.organization_contacts (id) on delete cascade,
  category text not null check (category in (
    'diplomas', 'certificates', 'badges', 'projects', 'workExperience',
    'internships', 'skills', 'feedback', 'reflections', 'other'
  )),
  granted_at timestamptz not null default now(),
  primary key (contact_id, category)
);
create index if not exists organization_contact_evidence_types_category
  on public.organization_contact_evidence_types (category, contact_id);

comment on table public.organization_contact_evidence_types is
  'The kinds of evidence (vault_items.category) a contact person is authorised to confirm. Managed by administrators.';

-- Only once, for the persons that exist before this table: they keep what they could do.
do $$
begin
  if not exists (select 1 from public.organization_contact_evidence_types) then
    insert into public.organization_contact_evidence_types (contact_id, category)
    select c.id, k.category
    from public.organization_contacts c
    cross join (values ('diplomas'), ('certificates'), ('badges'), ('projects'), ('workExperience'),
                       ('internships'), ('skills'), ('feedback'), ('reflections'), ('other')) as k (category)
    on conflict do nothing;
  end if;
end $$;

-- Administrators (service role) only: learners never read who may confirm what, they only get the result.
alter table public.organization_contact_evidence_types enable row level security;
revoke all on public.organization_contact_evidence_types from anon, authenticated;

-- 4. Search indexes ----------------------------------------------------------------------------------------------------

-- Trigram indexes make "contains" searches on names fast. pg_trgm may already live in another schema.
create extension if not exists pg_trgm with schema extensions;
do $$
declare
  trgm_schema text := (select n.nspname from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'pg_trgm');
begin
  execute format(
    'create index if not exists organizations_name_trgm on public.organizations using gin (name %I.gin_trgm_ops) where kind is not null',
    trgm_schema);
  execute format(
    'create index if not exists organization_contacts_name_trgm on public.organization_contacts using gin (name %I.gin_trgm_ops)',
    trgm_schema);
end $$;
create index if not exists organization_contacts_department on public.organization_contacts (department_id);
create index if not exists organization_departments_location on public.organization_departments (location_id);
create index if not exists vault_validation_requests_user_contact
  on public.vault_validation_requests (user_id, requested_at desc) where contact_id is not null;

-- 5. The persons a learner may ask -------------------------------------------------------------------------------------
-- Internal: active, with an account, not the learner, and authorised for this kind of evidence. Not callable by users.

create or replace function public.validation_available_contacts(p_category text)
returns table (
  id uuid, name text, job_title text, function text,
  department_id uuid, department_name text, location_id uuid, city text, organization_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.name, c.job_title, coalesce(nullif(btrim(c.job_title), ''), 'Overig'),
         d.id, d.name, l.id, l.city, l.organization_id
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

-- Every word of the query has to occur somewhere in the text; % and _ are taken literally.
create or replace function public.validation_matches(p_text text, p_query text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select not exists (
    select 1
    from unnest(regexp_split_to_array(btrim(coalesce(p_query, '')), '\s+')) as w (word)
    where w.word <> ''
      and p_text not ilike '%' || replace(replace(replace(w.word, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  );
$$;

-- 6. Functions for the app ---------------------------------------------------------------------------------------------
-- All of them: signed in with two-step verification, at most 50 rows a page, total_count for paging.

-- Organisations with at least one person who may confirm this kind of evidence. p_kind: null for all.
create or replace function public.validation_search_organizations(
  p_category text, p_query text default null, p_kind text default null, p_limit int default 25, p_offset int default 0
)
returns table (id uuid, name text, kind text, cities text[], available_contacts int, total_count bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with people as (
    select a.organization_id, a.city from public.validation_available_contacts(p_category) a
  ), found as (
    select o.id, o.name, o.kind,
           array(select distinct p.city from people p where p.organization_id = o.id order by p.city) as cities,
           (select count(*)::int from people p where p.organization_id = o.id) as available_contacts
    from public.organizations o
    where o.kind is not null
      and (p_kind is null or o.kind = p_kind)
      and public.validation_matches(o.name, p_query)
      and exists (select 1 from people p where p.organization_id = o.id)
  )
  select f.*, count(*) over ()
  from found f
  where public.is_mfa_verified() and (select auth.uid()) is not null
  order by f.name
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- Known organisations by ID (the organisation of the evidence or of an earlier request), also when nobody there may
-- confirm this kind of evidence: available_contacts then says 0.
create or replace function public.validation_organizations_by_id(p_category text, p_ids uuid[])
returns table (id uuid, name text, kind text, cities text[], available_contacts int)
language sql
stable
security definer
set search_path = ''
as $$
  with people as (
    select a.organization_id, a.city from public.validation_available_contacts(p_category) a
    where a.organization_id = any (p_ids)
  )
  select o.id, o.name, o.kind,
         array(select distinct p.city from people p where p.organization_id = o.id order by p.city),
         (select count(*)::int from people p where p.organization_id = o.id)
  from public.organizations o
  where o.id = any (p_ids[1:20])
    and o.kind is not null
    and public.is_mfa_verified() and (select auth.uid()) is not null;
$$;

-- Persons of one organisation, searched on name, function, department and city; location, department and function
-- are optional filters.
create or replace function public.validation_search_contacts(
  p_organization_id uuid, p_category text, p_query text default null,
  p_location_id uuid default null, p_department_id uuid default null, p_function text default null,
  p_limit int default 25, p_offset int default 0
)
returns table (
  id uuid, name text, job_title text, function text, department_id uuid, department_name text,
  location_id uuid, city text, organization_id uuid, total_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.*, count(*) over ()
  from public.validation_available_contacts(p_category) a
  where a.organization_id = p_organization_id
    and (p_location_id is null or a.location_id = p_location_id)
    and (p_department_id is null or a.department_id = p_department_id)
    and (p_function is null or a.function = p_function)
    and public.validation_matches(concat_ws(' ', a.name, a.function, a.department_name, a.city), p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by a.name, a.city, a.department_name
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- The choices for the filters: only values that lead to at least one person. filter is location, department or function.
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
  select 'location', p.location_id::text, p.city, null::uuid, count(*)::int from people p group by p.location_id, p.city
  union all
  select 'department', p.department_id::text, p.department_name, p.location_id, count(*)::int
  from people p group by p.department_id, p.department_name, p.location_id
  union all
  select 'function', p.function, p.function, null::uuid, count(*)::int from people p group by p.function
  order by 1, 3;
$$;

-- The persons this learner asked before, most recent first, as far as they may still confirm this kind of evidence.
create or replace function public.validation_previous_contacts(p_category text, p_limit int default 5)
returns table (
  id uuid, name text, job_title text, function text, department_id uuid, department_name text,
  location_id uuid, city text, organization_id uuid, organization_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.name, a.job_title, a.function, a.department_id, a.department_name,
         a.location_id, a.city, a.organization_id, o.name
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

revoke all on function public.validation_search_organizations(text, text, text, int, int) from public, anon;
revoke all on function public.validation_organizations_by_id(text, uuid[]) from public, anon;
revoke all on function public.validation_search_contacts(uuid, text, text, uuid, uuid, text, int, int) from public, anon;
revoke all on function public.validation_contact_filters(uuid, text) from public, anon;
revoke all on function public.validation_previous_contacts(text, int) from public, anon;
grant execute on function public.validation_search_organizations(text, text, text, int, int) to authenticated;
grant execute on function public.validation_organizations_by_id(text, uuid[]) to authenticated;
grant execute on function public.validation_search_contacts(uuid, text, text, uuid, uuid, text, int, int) to authenticated;
grant execute on function public.validation_contact_filters(uuid, text) to authenticated;
grant execute on function public.validation_previous_contacts(text, int) to authenticated;

-- 7. Who receives and decides a request --------------------------------------------------------------------------------
-- The chosen person's account, as long as that person may confirm this kind of evidence. Taking the right away also
-- takes away open requests from their inbox.

create or replace function public.vault_validation_recipients(p_request_id uuid)
returns table (reviewer_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select c.reviewer_id
  from public.vault_validation_requests r
  join public.vault_items i on i.id = r.item_id and i.user_id = r.user_id
  join public.organization_contacts c on c.id = r.contact_id
  where r.id = p_request_id
    and c.reviewer_id is not null
    and c.reviewer_id <> r.user_id
    and exists (
      select 1 from public.organization_contact_evidence_types t
      where t.contact_id = c.id and t.category = i.category
    );
$$;

revoke all on function public.vault_validation_recipients(uuid) from public, anon, authenticated;
grant execute on function public.vault_validation_recipients(uuid) to service_role;

comment on function public.vault_validation_recipients(uuid) is
  'The account of the chosen contact person, when authorised for the kind of evidence; never the learner who asked.';
comment on function public.validation_search_contacts(uuid, text, text, uuid, uuid, text, int, int) is
  'A page of persons of one organisation who may confirm this kind of evidence. Never returns the account behind them.';
