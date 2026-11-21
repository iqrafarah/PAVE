-- Organisations, evidence verification and the notification inbox: the whole setup in one file.
--
-- Replaces these earlier files (all merged here, see docs/verificatie.md for the overview):
--   20261112160000_notifications_and_vault_review        20261117120000_organisation_directory
--   20261112170000_resolve_vault_validation              20261117130000_organisation_contacts
--   20261117091516_vault_rejection_notifications_...     20261117140000_reconcile_organisation_kinds
--   20261117150000_rejection_reason_required             20261117160000_validation_organisation_directory
--   20261117170000_organisation_contact_persons
--
-- Runs on a fresh database (after the vault and Ayla migrations) and on a database where the old files were already
-- applied: every step is safe to run again and removes what the old setup left behind.
--
-- 20261120180000_simple_verification_directory simplifies this setup (no reviewer table, departments everywhere).
-- Run that one after this file, and do not run this file again once it is applied.
--
--   organizations                 Fontys                          Coolblue
--   └─ organization_locations     └─ Fontys Tilburg               └─ Coolblue Breda
--      └─ organization_departments   └─ ICT (schools only)           └─ contact person(s)
--         └─ organization_contacts      └─ teachers
--   organization_reviewers: per organisation, the PAVE accounts that handle requests to a person without an account.
--
--   A learner picks a location, then (at a school) a department, then one person.
--
--   vault_validation_requests (one per request; only the vault-review Edge Function writes them)
--        └── user_notifications (inbox: Ayla replies, requests for reviewers, decisions for learners)
--
-- Who receives a request: the account linked to the chosen contact, otherwise every reviewer of the organisation,
-- and never the learner who asked.

-- 1. Directory ---------------------------------------------------------------------------------------------------------
-- `organizations` belongs to the web team (id, name, logo_url, ...). Its only read policy lets members read their own
-- organisation; learners get the pick-list through validation_organizations() below.

alter table public.organizations
  add column if not exists kind text check (kind is null or kind in ('school', 'company'));
comment on column public.organizations.kind is 'school or company; null keeps the organisation out of the verification directory.';

create table if not exists public.organization_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  city text not null check (length(btrim(city)) between 1 and 100),
  created_at timestamptz not null default now(),
  unique (organization_id, city),
  unique (id, organization_id)
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'organization_locations_id_organization_id_key')
     and not exists (select 1 from pg_constraint where conname = 'organization_locations_id_organization') then
    alter table public.organization_locations add constraint organization_locations_id_organization_id_key unique (id, organization_id);
  end if;
end $$;

create index if not exists organization_locations_organization on public.organization_locations (organization_id);

-- A department or study programme at one location of a school: Fontys Tilburg ICT and Fontys Eindhoven ICT are two
-- departments, each with its own teachers. Companies have no departments; their contacts are at a location.
create table if not exists public.organization_departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 120),
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  constraint organization_departments_id_location unique (id, location_id),
  unique nulls not distinct (organization_id, location_id, name),
  foreign key (location_id, organization_id) references public.organization_locations (id, organization_id) on delete cascade
);

-- Departments for a whole organisation (no location) belonged to the first setup: they go, with their contacts.
delete from public.organization_departments where location_id is null;
alter table public.organization_departments alter column location_id set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'organization_departments_id_location') then
    alter table public.organization_departments add constraint organization_departments_id_location unique (id, location_id);
  end if;
end $$;

create index if not exists organization_departments_organization on public.organization_departments (organization_id);
create index if not exists organization_departments_location on public.organization_departments (location_id);

-- 2. Reviewers ---------------------------------------------------------------------------------------------------------
-- Explicit assignments, separate from the web roles in profiles: a teacher can review without being a web admin.
-- Managed by trusted staff in the SQL editor; see docs/verificatie.md.

do $$
begin
  if to_regclass('public.vault_validation_reviewers') is not null and to_regclass('public.organization_reviewers') is null then
    alter table public.vault_validation_reviewers rename to organization_reviewers;
  end if;
end $$;

create table if not exists public.organization_reviewers (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  reviewer_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  primary key (organization_id, reviewer_id)
);

create index if not exists organization_reviewers_reviewer on public.organization_reviewers (reviewer_id);

-- 3. Contacts ----------------------------------------------------------------------------------------------------------
-- The person a learner picks: at a location (Coolblue Breda: one or more contact persons), and at a school also in a
-- department of that location (Fontys Tilburg ICT: its teachers). `reviewer_id` is that person's PAVE account, if they
-- have one: requests to them go only to that account. Learners can read every column except reviewer_id.

create table if not exists public.organization_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id uuid not null,
  department_id uuid,
  name text not null check (length(btrim(name)) between 1 and 120),
  job_title text check (job_title is null or length(btrim(job_title)) between 1 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  unique nulls not distinct (organization_id, location_id, department_id, name),
  foreign key (location_id, organization_id) references public.organization_locations (id, organization_id) on delete cascade,
  -- The department must be one of this location.
  constraint organization_contacts_department_location
    foreign key (department_id, location_id) references public.organization_departments (id, location_id) on delete cascade
);

-- Contacts for a whole organisation (no location) belonged to the first setup: they go.
delete from public.organization_contacts where location_id is null;
alter table public.organization_contacts alter column location_id set not null;
alter table public.organization_contacts drop constraint if exists organization_contacts_department_id_organization_id_fkey;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'organization_contacts_department_location') then
    alter table public.organization_contacts
      add constraint organization_contacts_department_location
      foreign key (department_id, location_id) references public.organization_departments (id, location_id) on delete cascade;
  end if;
end $$;

create index if not exists organization_contacts_location on public.organization_contacts (location_id);

alter table public.organization_contacts add column if not exists reviewer_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'organization_contacts_reviewer') then
    -- The linked account must be a reviewer of the same organisation; removing that assignment unlinks the contact.
    alter table public.organization_contacts
      add constraint organization_contacts_reviewer
      foreign key (organization_id, reviewer_id) references public.organization_reviewers (organization_id, reviewer_id)
      on delete set null (reviewer_id);
  end if;
end $$;

create index if not exists organization_contacts_organization on public.organization_contacts (organization_id);

-- The old link table becomes the reviewer_id column (one account per person).
do $$
begin
  if to_regclass('public.organization_contact_reviewers') is not null then
    update public.organization_contacts c
    set reviewer_id = link.reviewer_id
    from (
      select distinct on (contact_id) contact_id, reviewer_id
      from public.organization_contact_reviewers
      order by contact_id, created_at
    ) link
    where c.id = link.contact_id and c.reviewer_id is null;
    drop table public.organization_contact_reviewers;
  end if;
end $$;

-- 4. Directory access --------------------------------------------------------------------------------------------------
-- Same pattern as the vault tables: one permissive policy for what you may read, one restrictive policy for MFA.

alter table public.organization_locations enable row level security;
alter table public.organization_departments enable row level security;
alter table public.organization_contacts enable row level security;
alter table public.organization_reviewers enable row level security;

drop policy if exists "Signed-in users can read organisation locations" on public.organization_locations;
drop policy if exists "Require two-step verification for organisation locations" on public.organization_locations;
drop policy if exists "Read the directory" on public.organization_locations;
drop policy if exists "Require two-step verification" on public.organization_locations;
create policy "Read the directory" on public.organization_locations for select to authenticated using (true);
create policy "Require two-step verification" on public.organization_locations as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Signed-in users can read departments" on public.organization_departments;
drop policy if exists "Require two-step verification for departments" on public.organization_departments;
drop policy if exists "Read the directory" on public.organization_departments;
drop policy if exists "Require two-step verification" on public.organization_departments;
create policy "Read the directory" on public.organization_departments for select to authenticated using (true);
create policy "Require two-step verification" on public.organization_departments as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Signed-in users can read active contacts" on public.organization_contacts;
drop policy if exists "Require two-step verification for contacts" on public.organization_contacts;
drop policy if exists "Read active contacts" on public.organization_contacts;
drop policy if exists "Require two-step verification" on public.organization_contacts;
create policy "Read active contacts" on public.organization_contacts for select to authenticated using (is_active);
create policy "Require two-step verification" on public.organization_contacts as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Reviewers can read their own assignments" on public.organization_reviewers;
drop policy if exists "Read own reviewer assignments" on public.organization_reviewers;
drop policy if exists "Require two-step verification" on public.organization_reviewers;
create policy "Read own reviewer assignments" on public.organization_reviewers for select to authenticated
  using ((select auth.uid()) = reviewer_id);
create policy "Require two-step verification" on public.organization_reviewers as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

revoke all on public.organization_locations, public.organization_departments, public.organization_contacts,
  public.organization_reviewers from anon, authenticated;
grant select on public.organization_locations, public.organization_departments, public.organization_reviewers to authenticated;
-- Every column but reviewer_id: which account is behind a person stays private.
grant select (id, organization_id, location_id, department_id, name, job_title, is_active, created_at)
  on public.organization_contacts to authenticated;

-- The pick-list of organisations: only id, name and kind, of organisations in the directory, after two-step verification.
create or replace function public.validation_organizations()
returns table (id uuid, name text, kind text)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, o.name, o.kind
  from public.organizations o
  where o.kind is not null
    and public.is_mfa_verified()
  order by o.name;
$$;

revoke all on function public.validation_organizations() from public, anon;
grant execute on function public.validation_organizations() to authenticated;

-- 5. Requests ----------------------------------------------------------------------------------------------------------
-- vault_validation_requests comes from 20261110120000_vault.sql. A request is created and decided only by the vault-review
-- Edge Function (service role), so learners only read their own; the old insert/delete rights and the status guard go.
-- The request row is the history: who decided, when and why. A new request after a rejection is a new row.

alter table public.vault_validation_requests
  add column if not exists organization_id uuid references public.organizations (id) on delete set null,
  add column if not exists location_id uuid references public.organization_locations (id) on delete set null,
  add column if not exists department_id uuid references public.organization_departments (id) on delete set null,
  add column if not exists contact_id uuid references public.organization_contacts (id) on delete set null,
  add column if not exists resolved_by uuid references auth.users (id) on delete set null,
  drop column if exists contact_email;

comment on column public.vault_validation_requests.organisation_name is
  'The organisation''s name when the request was sent: learners cannot read organizations, so they read it here.';

drop table if exists public.vault_validation_events;

drop policy if exists "Request validation for own items" on public.vault_validation_requests;
drop policy if exists "Cancel pending validation requests" on public.vault_validation_requests;
revoke insert, update, delete on public.vault_validation_requests from authenticated;
drop trigger if exists vault_validation_requests_guard_status on public.vault_validation_requests;
drop function if exists public.guard_vault_validation_status();

create index if not exists vault_validation_requests_organization_pending
  on public.vault_validation_requests (organization_id, requested_at desc)
  where status = 'pending';
-- One open request per item and organisation; the Edge Function turns a violation into "already_pending".
create unique index if not exists vault_validation_requests_one_pending_per_org
  on public.vault_validation_requests (user_id, item_id, organization_id)
  where status = 'pending' and organization_id is not null;

-- Who receives (and may decide) a request: the chosen person's account, otherwise every reviewer of the organisation.
-- The learner who asked is never one of them, also not when they are a reviewer themselves.
create or replace function public.vault_validation_recipients(p_request_id uuid)
returns table (reviewer_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with request as (
    select r.user_id, r.organization_id, r.contact_id from public.vault_validation_requests r where r.id = p_request_id
  ), chosen as (
    select c.reviewer_id
    from public.organization_contacts c
    join request r on c.id = r.contact_id and c.organization_id = r.organization_id
    where c.reviewer_id is not null and c.reviewer_id <> r.user_id
  )
  select chosen.reviewer_id from chosen
  union
  select o.reviewer_id
  from public.organization_reviewers o
  join request r on o.organization_id = r.organization_id
  where o.reviewer_id <> r.user_id
    and not exists (select 1 from chosen);
$$;

revoke all on function public.vault_validation_recipients(uuid) from public, anon, authenticated;
grant execute on function public.vault_validation_recipients(uuid) to service_role;

-- Deciding a request, in one transaction: the request, the item's status and the learner's notification.
-- A rejection always carries the reviewer's reason, so the learner knows what to fix before asking again.
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
  v_request public.vault_validation_requests%rowtype;
  v_item_title text;
begin
  if coalesce(auth.role(), '') <> 'service_role' or p_actor_id is null then
    raise exception 'This operation requires the trusted validation service' using errcode = '42501';
  end if;
  if p_action not in ('verified', 'rejected') then
    raise exception 'Invalid validation outcome' using errcode = '22023';
  end if;
  if p_response is not null and length(p_response) > 2000 then
    raise exception 'Response is too long' using errcode = '22023';
  end if;
  if p_action = 'rejected' and length(btrim(coalesce(p_response, ''))) = 0 then
    raise exception 'A rejection needs a reason' using errcode = '22023';
  end if;

  select r.* into v_request from public.vault_validation_requests r where r.id = p_request_id for update;
  if not found or v_request.status <> 'pending' then
    raise exception 'Pending validation request not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.vault_validation_recipients(p_request_id) recipient where recipient.reviewer_id = p_actor_id
  ) then
    raise exception 'Not a recipient of this request' using errcode = '42501';
  end if;

  update public.vault_items i
  set verification_status = p_action, updated_at = now()
  where i.id = v_request.item_id and i.user_id = v_request.user_id and i.verification_status = 'toVerify'
  returning i.title into v_item_title;
  if not found then
    raise exception 'Evidence is no longer awaiting verification' using errcode = 'P0002';
  end if;

  update public.vault_validation_requests r
  set status = p_action, resolved_at = now(), resolved_by = p_actor_id, response = nullif(btrim(p_response), '')
  where r.id = p_request_id;

  insert into public.user_notifications (recipient_id, kind, title, body, validation_request_id, vault_item_id, dedupe_key)
  values (
    v_request.user_id,
    case when p_action = 'verified' then 'evidence_verified' else 'evidence_rejected' end,
    case when p_action = 'verified' then 'Bewijs geverifieerd' else 'Bewijs afgewezen' end,
    v_item_title,
    p_request_id,
    v_request.item_id,
    'vault-validation:' || p_request_id::text
  ) on conflict (recipient_id, dedupe_key) do nothing;

  return jsonb_build_object('request_id', p_request_id, 'item_id', v_request.item_id, 'status', p_action);
end;
$$;

revoke all on function public.resolve_vault_validation_request(uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.resolve_vault_validation_request(uuid, text, text, uuid) to service_role;

-- 6. Notifications -----------------------------------------------------------------------------------------------------
-- A private inbox per account. Server code writes the rows (the Edge Function, the resolver, the Ayla trigger); the
-- owner may only read them and mark them read. The payload is display text and IDs: no evidence, files or chat text.

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  title text not null check (length(btrim(title)) between 1 and 160),
  body text check (body is null or length(body) <= 500),
  conversation_id uuid references public.ayla_conversations (id) on delete cascade,
  validation_request_id uuid references public.vault_validation_requests (id) on delete cascade,
  vault_item_id uuid references public.vault_items (id) on delete cascade,
  dedupe_key text not null check (length(btrim(dedupe_key)) between 1 and 200),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (recipient_id, dedupe_key)
);

alter table public.user_notifications
  drop constraint if exists user_notifications_kind_check,
  add constraint user_notifications_kind_check
    check (kind in ('conversation', 'evidence_verified', 'evidence_rejected', 'verification_request')),
  drop constraint if exists user_notifications_check,
  add constraint user_notifications_check
    check (
      (kind = 'conversation' and conversation_id is not null and validation_request_id is null and vault_item_id is null)
      or (kind in ('evidence_verified', 'evidence_rejected') and conversation_id is null
          and validation_request_id is not null and vault_item_id is not null)
      or (kind = 'verification_request' and conversation_id is null
          and validation_request_id is not null and vault_item_id is null)
    );

-- Deleting is soft: the owner can bring a notification back for 7 days ("Recent verwijderd"), then it is purged.
alter table public.user_notifications add column if not exists deleted_at timestamptz;

create index if not exists user_notifications_inbox on public.user_notifications (recipient_id, created_at desc);
create index if not exists user_notifications_deleted on public.user_notifications (deleted_at) where deleted_at is not null;
create index if not exists user_notifications_unread on public.user_notifications (recipient_id, created_at desc) where read_at is null;

alter table public.user_notifications enable row level security;
drop policy if exists "Read own notifications" on public.user_notifications;
drop policy if exists "Mark own notifications read" on public.user_notifications;
drop policy if exists "Mark own notifications read or deleted" on public.user_notifications;
drop policy if exists "Require two-step verification for notifications" on public.user_notifications;
drop policy if exists "Require two-step verification" on public.user_notifications;
create policy "Read own notifications" on public.user_notifications for select to authenticated
  using ((select auth.uid()) = recipient_id);
create policy "Mark own notifications read or deleted" on public.user_notifications for update to authenticated
  using ((select auth.uid()) = recipient_id) with check ((select auth.uid()) = recipient_id);
create policy "Require two-step verification" on public.user_notifications as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

revoke all on public.user_notifications from anon, authenticated;
grant select, update on public.user_notifications to authenticated;

-- The owner may only mark a notification read (once), delete it, and bring it back within 7 days.
create or replace function public.guard_user_notification_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if (new.id, new.recipient_id, new.kind, new.title, new.body, new.conversation_id, new.validation_request_id,
        new.vault_item_id, new.dedupe_key, new.created_at)
       is distinct from
       (old.id, old.recipient_id, old.kind, old.title, old.body, old.conversation_id, old.validation_request_id,
        old.vault_item_id, old.dedupe_key, old.created_at)
       or (old.read_at is not null and new.read_at is distinct from old.read_at) then
      raise exception 'Only notification read and deleted state can be changed by the recipient' using errcode = '42501';
    end if;
    -- Deleting sets the time on the server, so a client cannot stretch or shorten the 7 days.
    if new.deleted_at is not null and old.deleted_at is null then
      new.deleted_at := now();
    elsif new.deleted_at is not null and new.deleted_at is distinct from old.deleted_at then
      raise exception 'A deleted notification can only be restored' using errcode = '42501';
    elsif new.deleted_at is null and old.deleted_at < now() - interval '7 days' then
      raise exception 'This notification can no longer be restored' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists user_notifications_guard_update on public.user_notifications;
create trigger user_notifications_guard_update
  before update on public.user_notifications
  for each row execute function public.guard_user_notification_update();

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'user_notifications') then
    alter publication supabase_realtime add table public.user_notifications;
  end if;
end $$;

-- After 7 days a deleted notification is gone for good. `vault-review` also purges the caller's own rows when it
-- loads the inbox; this nightly job (only where pg_cron is enabled) catches accounts that do not open the app.
create or replace function public.purge_deleted_notifications()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.user_notifications where deleted_at < now() - interval '7 days';
$$;

revoke all on function public.purge_deleted_notifications() from public, anon, authenticated;
grant execute on function public.purge_deleted_notifications() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('purge-deleted-notifications', '17 3 * * *', 'select public.purge_deleted_notifications()');
  end if;
end $$;

-- An inbox row for each Ayla reply, written inside the database so a client cannot forge it.
create or replace function public.notify_on_ayla_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_title text;
begin
  if new.role <> 'ayla' then return new; end if;
  select c.user_id, c.title into v_owner, v_title from public.ayla_conversations c where c.id = new.conversation_id;
  if v_owner is not null then
    insert into public.user_notifications (recipient_id, kind, title, body, conversation_id, dedupe_key)
    values (v_owner, 'conversation', coalesce(nullif(v_title, ''), 'Gesprek met Ayla'), 'Ayla heeft gereageerd.',
            new.conversation_id, 'ayla-message:' || new.id::text)
    on conflict (recipient_id, dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists ayla_message_notification on public.ayla_messages;
create trigger ayla_message_notification
  after insert on public.ayla_messages
  for each row execute function public.notify_on_ayla_reply();

-- 7. Directory --------------------------------------------------------------------------------------------------------
-- Organisations in Brabant with their locations, and at every school location three departments. There are no persons:
-- the team adds real contact persons with their PAVE account (docs/verificatie.md).

do $$
declare
  entry record;
  v_id uuid;
  v_city text;
  v_department text;
  v_place record;
begin
  for entry in
    select * from (values
    ('Fontys Hogeschool', 'school', array['Tilburg', 'Eindhoven', 'Den Bosch', 'Venlo', 'Sittard'], array['ICT', 'Educatie', 'Biologie']),
    ('Avans Hogeschool', 'school', array['Breda', 'Tilburg', 'Den Bosch', 'Roosendaal'], array['ICT', 'Educatie', 'Gezondheidszorg']),
    ('Yonder', 'school', array['Tilburg'], array['ICT', 'Zorg en welzijn', 'Techniek']),
    ('Curio', 'school', array['Breda', 'Roosendaal', 'Bergen op Zoom', 'Oosterhout'], array['ICT', 'Zorg en welzijn', 'Techniek']),
    ('De Rooi Pannen', 'school', array['Tilburg', 'Breda', 'Eindhoven'], array['Horeca', 'Toerisme', 'Commercie']),
    ('Summa', 'school', array['Eindhoven'], array['ICT', 'Zorg en welzijn', 'Techniek']),
    ('Koning Willem I College', 'school', array['Den Bosch', 'Oss', 'Veghel', 'Cuijk'], array['ICT', 'Zorg en welzijn', 'Techniek']),
    ('Yuverta', 'school', array['Tilburg', 'Eindhoven', 'Den Bosch', 'Helmond'], array['Groen', 'Dier', 'Food']),
    ('Breda University of Applied Sciences', 'school', array['Breda'], array['Games', 'Media', 'Hotel']),
    ('Tilburg University', 'school', array['Tilburg'], array['Economie', 'Rechten', 'Psychologie']),
    ('Technische Universiteit Eindhoven', 'school', array['Eindhoven'], array['Informatica', 'Werktuigbouwkunde', 'Industrial Design']),
    ('HAS green academy', 'school', array['Den Bosch', 'Venlo'], array['Biologie', 'Food', 'Business']),
    ('SintLucas', 'school', array['Eindhoven', 'Boxtel'], array['Media', 'Design', 'Games']),
    ('Ter AA', 'school', array['Helmond', 'Deurne'], array['ICT', 'Zorg en welzijn', 'Techniek']),
    ('ROC Nijmegen', 'school', array['Nijmegen', 'Boxmeer'], array['ICT', 'Zorg en welzijn', 'Techniek']),
    ('Coolblue', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch'], array[]::text[]),
    ('Albert Heijn', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch', 'Waalwijk', 'Roosendaal'], array[]::text[]),
    ('Jumbo', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch', 'Veghel'], array[]::text[]),
    ('IKEA', 'company', array['Breda', 'Eindhoven'], array[]::text[]),
    ('bol', 'company', array['Waalwijk', 'Utrecht'], array[]::text[]),
    ('ASML', 'company', array['Veldhoven', 'Eindhoven'], array[]::text[]),
    ('Philips', 'company', array['Eindhoven', 'Best'], array[]::text[]),
    ('DAF Trucks', 'company', array['Eindhoven', 'Geldrop'], array[]::text[]),
    ('VDL Groep', 'company', array['Eindhoven', 'Tilburg', 'Helmond'], array[]::text[]),
    ('CM.com', 'company', array['Breda'], array[]::text[]),
    ('Prodrive Technologies', 'company', array['Son en Breugel'], array[]::text[]),
    ('Heijmans', 'company', array['Rosmalen', 'Eindhoven'], array[]::text[]),
    ('McDonald''s', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch'], array[]::text[]),
    ('Kruidvat', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch'], array[]::text[]),
    ('HEMA', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch'], array[]::text[]),
    ('Decathlon', 'company', array['Tilburg', 'Breda', 'Eindhoven'], array[]::text[]),
    ('PostNL', 'company', array['Tilburg', 'Breda', 'Eindhoven', 'Den Bosch'], array[]::text[]),
    ('DHL', 'company', array['Tilburg', 'Eindhoven', 'Breda'], array[]::text[]),
    ('Elisabeth-TweeSteden Ziekenhuis', 'company', array['Tilburg', 'Waalwijk'], array[]::text[]),
    ('Amphia', 'company', array['Breda', 'Oosterhout'], array[]::text[]),
    ('Jeroen Bosch Ziekenhuis', 'company', array['Den Bosch'], array[]::text[]),
    ('Organon', 'company', array['Oss'], array[]::text[])
    ) as list(name, kind, cities, departments)
  loop
    select id into v_id from public.organizations where lower(btrim(name)) = lower(btrim(entry.name)) order by created_at limit 1;
    if v_id is null then
      insert into public.organizations (name, kind) values (entry.name, entry.kind) returning id into v_id;
    else
      update public.organizations set kind = entry.kind where id = v_id and kind is distinct from entry.kind;
    end if;
    foreach v_city in array entry.cities loop
      insert into public.organization_locations (organization_id, city) values (v_id, v_city)
      on conflict (organization_id, city) do nothing;
    end loop;
    -- Every location of a school gets the school's departments.
    for v_place in select l.id from public.organization_locations l where l.organization_id = v_id loop
      foreach v_department in array entry.departments loop
        insert into public.organization_departments (organization_id, location_id, name) values (v_id, v_place.id, v_department)
        on conflict (organization_id, location_id, name) do nothing;
      end loop;
    end loop;
  end loop;
end $$;

-- 8. Descriptions ------------------------------------------------------------------------------------------------------

comment on table public.organization_locations is 'The places of an organisation, for the verification directory.';
comment on table public.organization_departments is 'Departments or study programmes at one location of a school.';
comment on table public.organization_contacts is
  'People a learner can ask to confirm evidence, at a location and (schools) a department. reviewer_id (hidden from learners) is their PAVE account, if any.';
comment on table public.organization_reviewers is
  'PAVE accounts that may decide verification requests for an organisation. Managed by trusted staff only.';
comment on table public.vault_validation_requests is
  'Requests to confirm vault evidence. Created and decided only by the vault-review Edge Function; the row is the history.';
comment on table public.user_notifications is
  'Private inbox per account. Server code writes rows; the owner may read them, mark them read, and delete them (deleted_at), restorable for 7 days.';
comment on function public.validation_organizations() is
  'Directory pick-list: id, name and kind of every organisation with a kind. MFA sessions only.';
comment on function public.vault_validation_recipients(uuid) is
  'The chosen person''s account, otherwise the organisation''s reviewers; never the learner who asked. Service role only.';
comment on function public.resolve_vault_validation_request(uuid, text, text, uuid) is
  'Decides a request in one transaction. A rejection needs a reason. Service role only.';
comment on function public.notify_on_ayla_reply() is 'Creates an inbox row for the owner when Ayla replies.';
