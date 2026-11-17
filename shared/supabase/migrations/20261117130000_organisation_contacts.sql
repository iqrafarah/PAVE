-- Who a learner can ask to confirm evidence, after picking the organisation and its place
-- (20261117120000_organisation_directory.sql): a department at a school, and a person or desk to send it to.
-- Needs the review tables from the notifications branch (vault_validation_reviewers, vault_validation_requests.organization_id).
--
-- Learners read departments and contacts to fill in the form. Which PAVE account receives a request is never readable
-- by learners: it lives in organization_contact_reviewers, written by trusted provisioning only. A contact without a
-- linked account falls back to every reviewer of the organisation, as before. Safe to run again.

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'organization_locations_id_organization') then
    alter table public.organization_locations
      add constraint organization_locations_id_organization unique (id, organization_id);
  end if;
end $$;

drop policy if exists "Require two-step verification for organisation locations" on public.organization_locations;
create policy "Require two-step verification for organisation locations"
  on public.organization_locations as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

-- A department or study programme. Without a place it is at every place of the organisation.
create table if not exists public.organization_departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id uuid,
  name text not null check (length(btrim(name)) between 1 and 120),
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  unique nulls not distinct (organization_id, location_id, name),
  foreign key (location_id, organization_id) references public.organization_locations (id, organization_id) on delete cascade
);

create index if not exists organization_departments_organization on public.organization_departments (organization_id);

-- A person (a teacher, a mentor) or a desk (Stagebureau, HR) that can confirm evidence. Without a place or department
-- it is reachable from every place or department of the organisation.
create table if not exists public.organization_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id uuid,
  department_id uuid,
  name text not null check (length(btrim(name)) between 1 and 120),
  job_title text check (job_title is null or length(btrim(job_title)) between 1 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  unique nulls not distinct (organization_id, location_id, department_id, name),
  foreign key (location_id, organization_id) references public.organization_locations (id, organization_id) on delete cascade,
  foreign key (department_id, organization_id) references public.organization_departments (id, organization_id) on delete cascade
);

create index if not exists organization_contacts_organization on public.organization_contacts (organization_id);

-- The PAVE accounts behind a contact. Each must be an assigned reviewer of the same organisation.
create table if not exists public.organization_contact_reviewers (
  contact_id uuid not null,
  organization_id uuid not null,
  reviewer_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (contact_id, reviewer_id),
  foreign key (contact_id, organization_id) references public.organization_contacts (id, organization_id) on delete cascade,
  foreign key (organization_id, reviewer_id) references public.vault_validation_reviewers (organization_id, reviewer_id) on delete cascade
);

alter table public.organization_departments enable row level security;
alter table public.organization_contacts enable row level security;
alter table public.organization_contact_reviewers enable row level security;

drop policy if exists "Signed-in users can read departments" on public.organization_departments;
create policy "Signed-in users can read departments"
  on public.organization_departments for select to authenticated
  using (true);
drop policy if exists "Require two-step verification for departments" on public.organization_departments;
create policy "Require two-step verification for departments"
  on public.organization_departments as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Signed-in users can read active contacts" on public.organization_contacts;
create policy "Signed-in users can read active contacts"
  on public.organization_contacts for select to authenticated
  using (is_active);
drop policy if exists "Require two-step verification for contacts" on public.organization_contacts;
create policy "Require two-step verification for contacts"
  on public.organization_contacts as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

grant select on public.organization_departments, public.organization_contacts to authenticated;
revoke insert, update, delete on public.organization_departments, public.organization_contacts from authenticated;
revoke all on public.organization_departments, public.organization_contacts, public.organization_contact_reviewers from anon;
revoke all on public.organization_contact_reviewers from authenticated;

-- What the learner picked. Only the trusted function sets these, after checking they belong to the organisation.
alter table public.vault_validation_requests
  add column if not exists location_id uuid references public.organization_locations (id) on delete set null,
  add column if not exists department_id uuid references public.organization_departments (id) on delete set null,
  add column if not exists contact_id uuid references public.organization_contacts (id) on delete set null;

create or replace function public.guard_vault_validation_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.status <> 'pending' or new.organization_id is not null or new.resolved_by is not null
         or new.location_id is not null or new.department_id is not null or new.contact_id is not null then
        raise exception 'Validation requests must start pending and be routed by trusted server code' using errcode = '42501';
      end if;
    elsif new.status is distinct from old.status
       or new.organization_id is distinct from old.organization_id
       or new.resolved_by is distinct from old.resolved_by
       or new.location_id is distinct from old.location_id
       or new.department_id is distinct from old.department_id
       or new.contact_id is distinct from old.contact_id then
      raise exception 'Only trusted server code may route or resolve validation requests' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

-- Who may see and decide a request: the accounts of the chosen contact, or, when it has none, every reviewer of the
-- organisation. The function uses this for the notifications, the inbox and the detail; the resolver below too.
create or replace function public.vault_validation_recipients(p_request_id uuid)
returns table (reviewer_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with request as (
    select r.organization_id, r.contact_id from public.vault_validation_requests r where r.id = p_request_id
  ), chosen as (
    select cr.reviewer_id
    from public.organization_contact_reviewers cr
    join request r on cr.contact_id = r.contact_id and cr.organization_id = r.organization_id
  )
  select chosen.reviewer_id from chosen
  union
  select vr.reviewer_id
  from public.vault_validation_reviewers vr
  join request r on vr.organization_id = r.organization_id
  where not exists (select 1 from chosen);
$$;

revoke all on function public.vault_validation_recipients(uuid) from public, anon, authenticated;
grant execute on function public.vault_validation_recipients(uuid) to service_role;

-- The resolver from 20261117091516, with one change: the actor must be one of the request's recipients.
create or replace function public.resolve_vault_validation_request(
  p_request_id uuid,
  p_action text,
  p_response text default null,
  p_actor_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_id;
  v_request public.vault_validation_requests%rowtype;
  v_item_title text;
begin
  if coalesce(auth.role(), '') <> 'service_role' or v_actor is null then
    raise exception 'This operation requires the trusted validation service' using errcode = '42501';
  end if;
  if p_action not in ('verified', 'rejected') then
    raise exception 'Invalid validation outcome' using errcode = '22023';
  end if;
  if p_response is not null and length(p_response) > 2000 then
    raise exception 'Response is too long' using errcode = '22023';
  end if;

  select r.* into v_request
  from public.vault_validation_requests r
  where r.id = p_request_id
  for update;

  if not found or v_request.status <> 'pending' or v_request.organization_id is null then
    raise exception 'Pending validation request not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.vault_validation_recipients(p_request_id) recipient where recipient.reviewer_id = v_actor
  ) then
    raise exception 'Not a recipient of this request' using errcode = '42501';
  end if;

  update public.vault_items i
  set verification_status = p_action, updated_at = now()
  where i.id = v_request.item_id and i.user_id = v_request.user_id
    and i.verification_status = 'toVerify'
  returning i.title into v_item_title;

  if not found then
    raise exception 'Evidence is no longer awaiting verification' using errcode = 'P0002';
  end if;

  update public.vault_validation_requests r
  set status = p_action, resolved_at = now(), resolved_by = v_actor, response = p_response
  where r.id = p_request_id;

  insert into public.vault_validation_events (request_id, organization_id, actor_id, action, response)
  values (p_request_id, v_request.organization_id, v_actor, p_action, p_response);

  insert into public.user_notifications (
    recipient_id, kind, title, body, validation_request_id, vault_item_id, dedupe_key
  ) values (
    v_request.user_id,
    case when p_action = 'verified' then 'evidence_verified' else 'evidence_rejected' end,
    case when p_action = 'verified' then 'Bewijs geverifieerd' else 'Bewijs afgewezen' end,
    case when p_action = 'verified' then v_item_title else 'Een beoordelaar heeft je bewijs afgewezen.' end,
    p_request_id,
    v_request.item_id,
    'vault-validation:' || p_request_id::text
  ) on conflict (recipient_id, dedupe_key) do nothing;

  return jsonb_build_object('request_id', p_request_id, 'item_id', v_request.item_id, 'status', p_action);
end;
$$;

revoke all on function public.resolve_vault_validation_request(uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.resolve_vault_validation_request(uuid, text, text, uuid) to service_role;

comment on table public.organization_departments is
  'Departments or study programmes of an organisation (mostly schools), for picking who confirms evidence.';
comment on table public.organization_contacts is
  'People or desks a learner can ask to confirm evidence. Demo rows are roles, not real people.';
comment on table public.organization_contact_reviewers is
  'Private: the PAVE reviewer accounts behind a contact. Trusted provisioning only.';
comment on function public.vault_validation_recipients(uuid) is
  'Service-role only: the chosen contact''s reviewers, or every reviewer of the organisation when the contact has none.';

-- Demo directory. Departments only for Fontys (Ravi's school); every school has a Stagebureau, every company a
-- stagebegeleider and HR. These are roles, not people: real teachers and contact persons are added by the team and
-- linked to their PAVE account in organization_contact_reviewers. Safe to run again.
do $$
declare
  v_org record;
  v_fontys uuid;
  v_department text;
  v_department_id uuid;
begin
  select id into v_fontys from public.organizations where lower(btrim(name)) = 'fontys hogeschool' order by created_at limit 1;
  if v_fontys is not null then
    foreach v_department in array array['ICT', 'Engineering', 'Pedagogiek'] loop
      insert into public.organization_departments (organization_id, name) values (v_fontys, v_department)
      on conflict (organization_id, location_id, name) do nothing;
      select id into v_department_id from public.organization_departments
      where organization_id = v_fontys and location_id is null and name = v_department;
      insert into public.organization_contacts (organization_id, department_id, name, job_title)
      values (v_fontys, v_department_id, 'Stagecoördinator ' || v_department, 'Stagecoördinator'),
             (v_fontys, v_department_id, 'Docent ' || v_department, 'Docent')
      on conflict (organization_id, location_id, department_id, name) do nothing;
    end loop;
  end if;

  for v_org in select id, kind from public.organizations where kind is not null loop
    if v_org.kind = 'school' then
      insert into public.organization_contacts (organization_id, name, job_title)
      values (v_org.id, 'Stagebureau', 'Afdeling')
      on conflict (organization_id, location_id, department_id, name) do nothing;
    else
      insert into public.organization_contacts (organization_id, name, job_title)
      values (v_org.id, 'Stagebegeleider', 'Contactpersoon'),
             (v_org.id, 'HR-afdeling', 'Afdeling')
      on conflict (organization_id, location_id, department_id, name) do nothing;
    end if;
  end loop;
end $$;
