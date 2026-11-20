-- The verification directory, made simple: organisation → location → department → contact person.
--
-- Changes the setup of 20261117180000 (see docs/verificatie.md):
--   * organization_reviewers goes. The PAVE account of the chosen contact person (organization_contacts.reviewer_id)
--     receives and decides the request; nobody else.
--   * Learners only see contact persons who have an account, and never themselves.
--   * Every organisation has departments, companies too ("Stage" and "HR"), so the choice is the same everywhere.
--   * A department only points to its location, a contact person only to its department: the extra organisation and
--     location columns go.
--   * The made-up demo persons go.
--
-- Safe to run again: the conversion only runs while organization_contacts still has location_id.

-- 1. Conversion --------------------------------------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'organization_contacts' and column_name = 'location_id'
  ) then
    return;
  end if;

  insert into public.organization_departments (organization_id, location_id, name)
  select l.organization_id, l.id, d.name
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id
  cross join (values ('Stage'), ('HR')) as d (name)
  where o.kind = 'company'
  on conflict do nothing;

  -- The demo persons of 20261117180000, recognised by the name it generated from their department or location.
  with names as (
    select array['Sanne', 'Daan', 'Fatima', 'Lucas', 'Noor', 'Milan', 'Yara', 'Sem', 'Eva', 'Mohamed',
                 'Lotte', 'Jesse', 'Amira', 'Thijs', 'Femke', 'Bram', 'Ilse', 'Ruben', 'Zeynep', 'Tim'] as first,
           array['de Vries', 'Jansen', 'Bakker', 'Visser', 'Smit', 'Meijer', 'de Boer', 'Mulder', 'de Groot', 'Bos',
                 'Vos', 'Peters', 'Hendriks', 'van Dijk', 'Dekker', 'Brouwer', 'van Leeuwen', 'Kaya', 'El Amrani', 'Verhoeven'] as last
  ), demo as (
    select c.id
    from public.organization_contacts c
    cross join names n
    cross join lateral unnest(
      case when c.department_id is not null
           then array[c.department_id::text || ':docent:1', c.department_id::text || ':docent:2']
           else array[c.location_id::text || ':contact'] end
    ) as seed
    where c.reviewer_id is null
      and c.job_title = case when c.department_id is not null then 'Docent' else 'Stagebegeleider' end
      and c.name = n.first[1 + abs(hashtext(seed)::bigint) % 20] || ' ' || n.last[1 + abs(hashtext(seed || ':achternaam')::bigint) % 20]
  )
  delete from public.organization_contacts c where c.id in (select id from demo);

  -- A person without a department: at a company into "Stage", elsewhere into "Algemeen".
  insert into public.organization_departments (organization_id, location_id, name)
  select distinct c.organization_id, c.location_id, 'Algemeen'
  from public.organization_contacts c
  join public.organizations o on o.id = c.organization_id
  where c.department_id is null and o.kind is distinct from 'company'
  on conflict do nothing;

  update public.organization_contacts c
  set department_id = d.id
  from public.organization_departments d, public.organizations o
  where c.department_id is null
    and o.id = c.organization_id
    and d.location_id = c.location_id
    and d.name = case when o.kind = 'company' then 'Stage' else 'Algemeen' end;

  alter table public.organization_contacts drop constraint if exists organization_contacts_reviewer;
  alter table public.organization_contacts drop column organization_id, drop column location_id;
  alter table public.organization_contacts alter column department_id set not null;

  alter table public.organization_departments drop column organization_id;
  alter table public.organization_departments drop constraint if exists organization_departments_id_location;

  alter table public.organization_locations drop constraint if exists organization_locations_id_organization_id_key;
  alter table public.organization_locations drop constraint if exists organization_locations_id_organization;
end $$;

-- 2. Tables ------------------------------------------------------------------------------------------------------------

alter table public.organization_departments drop constraint if exists organization_departments_location;
alter table public.organization_departments add constraint organization_departments_location
  foreign key (location_id) references public.organization_locations (id) on delete cascade;
alter table public.organization_departments drop constraint if exists organization_departments_location_name;
alter table public.organization_departments add constraint organization_departments_location_name unique (location_id, name);

alter table public.organization_contacts drop constraint if exists organization_contacts_reviewer;
alter table public.organization_contacts drop constraint if exists organization_contacts_department;
alter table public.organization_contacts add constraint organization_contacts_department
  foreign key (department_id) references public.organization_departments (id) on delete cascade;
alter table public.organization_contacts drop constraint if exists organization_contacts_department_name;
alter table public.organization_contacts add constraint organization_contacts_department_name unique (department_id, name);
alter table public.organization_contacts drop constraint if exists organization_contacts_account;
alter table public.organization_contacts add constraint organization_contacts_account
  foreign key (reviewer_id) references auth.users (id) on delete set null;
create index if not exists organization_contacts_reviewer_id on public.organization_contacts (reviewer_id) where reviewer_id is not null;

drop table if exists public.organization_reviewers;

-- 3. Access ------------------------------------------------------------------------------------------------------------
-- A learner sees the active persons who have an account, except themselves. Which account it is stays private.

drop policy if exists "Read active contacts" on public.organization_contacts;
drop policy if exists "Read contacts with an account" on public.organization_contacts;
create policy "Read contacts with an account" on public.organization_contacts for select to authenticated
  using (is_active and reviewer_id is not null and reviewer_id <> (select auth.uid()));

revoke all on public.organization_contacts from anon, authenticated;
grant select (id, department_id, name, job_title, is_active, created_at) on public.organization_contacts to authenticated;

-- 4. Who receives a request --------------------------------------------------------------------------------------------

create or replace function public.vault_validation_recipients(p_request_id uuid)
returns table (reviewer_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select c.reviewer_id
  from public.vault_validation_requests r
  join public.organization_contacts c on c.id = r.contact_id
  where r.id = p_request_id
    and c.reviewer_id is not null
    and c.reviewer_id <> r.user_id;
$$;

revoke all on function public.vault_validation_recipients(uuid) from public, anon, authenticated;
grant execute on function public.vault_validation_recipients(uuid) to service_role;

-- 5. Descriptions ------------------------------------------------------------------------------------------------------

comment on table public.organization_departments is 'Departments of one location: study programmes at a school, Stage or HR at a company.';
comment on table public.organization_contacts is
  'The persons a learner can ask to confirm evidence, in one department. reviewer_id (hidden from learners) is their PAVE account; only persons with one are shown.';
comment on column public.organization_contacts.reviewer_id is 'The PAVE account that receives and decides requests to this person.';
comment on function public.vault_validation_recipients(uuid) is
  'The account of the chosen contact person, never the learner who asked. Service role only.';
