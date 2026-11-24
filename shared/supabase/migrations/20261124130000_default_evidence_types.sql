-- Default evidence types for new contact persons (see docs/verificatie.md).
--
-- Since 20261124120000 a contact person may only confirm the kinds of evidence in organization_contact_evidence_types.
-- So a new teacher works straight away, a new contact person now gets the default set of their kind of organisation:
--
--   school       diplomas, certificates, badges, projects, skills, feedback, reflections
--   company      workExperience, internships, projects, skills, feedback
--   government   workExperience, internships, certificates, projects, skills, feedback
--   other        certificates, projects, skills, feedback, other
--
-- The defaults live in a table, so they change without code. Exceptions per person are still made in
-- organization_contact_evidence_types. Changing a default does not change persons that already exist.
-- Safe to run again.

-- 1. The defaults ------------------------------------------------------------------------------------------------------

create table if not exists public.organization_kind_evidence_types (
  kind text not null check (kind in ('school', 'company', 'government', 'other')),
  category text not null check (category in (
    'diplomas', 'certificates', 'badges', 'projects', 'workExperience',
    'internships', 'skills', 'feedback', 'reflections', 'other'
  )),
  primary key (kind, category)
);

comment on table public.organization_kind_evidence_types is
  'The kinds of evidence a new contact person may confirm, by kind of organisation. Managed by administrators.';

-- Only when the table is new, so defaults that an administrator changed are not put back.
do $$
begin
  if not exists (select 1 from public.organization_kind_evidence_types) then
    insert into public.organization_kind_evidence_types (kind, category) values
      ('school', 'diplomas'), ('school', 'certificates'), ('school', 'badges'), ('school', 'projects'),
      ('school', 'skills'), ('school', 'feedback'), ('school', 'reflections'),
      ('company', 'workExperience'), ('company', 'internships'), ('company', 'projects'),
      ('company', 'skills'), ('company', 'feedback'),
      ('government', 'workExperience'), ('government', 'internships'), ('government', 'certificates'),
      ('government', 'projects'), ('government', 'skills'), ('government', 'feedback'),
      ('other', 'certificates'), ('other', 'projects'), ('other', 'skills'), ('other', 'feedback'), ('other', 'other');
  end if;
end $$;

-- Administrators (service role) only, like organization_contact_evidence_types.
alter table public.organization_kind_evidence_types enable row level security;
revoke all on public.organization_kind_evidence_types from anon, authenticated;

-- 2. A new contact person gets the defaults ----------------------------------------------------------------------------

create or replace function public.grant_default_evidence_types(p_contact_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.organization_contact_evidence_types (contact_id, category)
  select c.id, k.category
  from public.organization_contacts c
  join public.organization_departments d on d.id = c.department_id
  join public.organization_locations l on l.id = d.location_id
  join public.organizations o on o.id = l.organization_id
  join public.organization_kind_evidence_types k on k.kind = o.kind
  where c.id = p_contact_id
  on conflict do nothing;
$$;

revoke all on function public.grant_default_evidence_types(uuid) from public, anon, authenticated;

create or replace function public.organization_contacts_default_evidence_types()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.grant_default_evidence_types(new.id);
  return new;
end;
$$;

revoke all on function public.organization_contacts_default_evidence_types() from public, anon, authenticated;

drop trigger if exists organization_contacts_default_evidence_types on public.organization_contacts;
create trigger organization_contacts_default_evidence_types
  after insert on public.organization_contacts
  for each row execute function public.organization_contacts_default_evidence_types();

-- 3. Persons added between 20261124120000 and this file ----------------------------------------------------------------
-- Only persons without a single kind: someone with a narrowed set keeps it.

select public.grant_default_evidence_types(c.id)
from public.organization_contacts c
where not exists (select 1 from public.organization_contact_evidence_types t where t.contact_id = c.id);
