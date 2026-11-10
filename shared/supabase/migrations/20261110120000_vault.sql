-- The user's vault: folders, evidence items, attached source files, skills, validation requests,
-- and task-scoped access grants for Ayla. See docs/vault.md.
-- Draft only. This changes the shared Supabase schema: review with the web team before applying.

create table public.vault_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 100),
  description text check (description is null or length(description) <= 500),
  category text check (category is null or category in (
    'diplomas', 'certificates', 'badges', 'projects', 'workExperience',
    'internships', 'skills', 'feedback', 'reflections'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create unique index vault_folders_user_name on public.vault_folders (user_id, lower(name));
create index vault_folders_user_updated on public.vault_folders (user_id, updated_at desc);

create table public.vault_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  folder_id uuid,
  category text not null check (category in (
    'diplomas', 'certificates', 'badges', 'projects', 'workExperience',
    'internships', 'skills', 'feedback', 'reflections'
  )),
  title text not null check (length(btrim(title)) between 1 and 200),
  description text check (description is null or length(description) <= 10000),
  organisation_name text check (organisation_name is null or length(organisation_name) <= 200),
  organisation_location text check (organisation_location is null or length(organisation_location) <= 200),
  start_date date,
  end_date date,
  issued_on date,
  is_current boolean not null default false,
  verification_status text not null default 'toVerify'
    check (verification_status in ('toVerify', 'verified', 'rejected')),
  source text not null default 'user'
    check (source in ('user', 'organization', 'ayla', 'import')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id),
  foreign key (user_id, folder_id)
    references public.vault_folders (user_id, id) on delete set null (folder_id),
  check (end_date is null or start_date is null or end_date >= start_date),
  check (not is_current or end_date is null)
);

create index vault_items_user_updated on public.vault_items (user_id, updated_at desc);
create index vault_items_user_category on public.vault_items (user_id, category, updated_at desc);
create index vault_items_user_status on public.vault_items (user_id, verification_status, updated_at desc);
create index vault_items_folder on public.vault_items (user_id, folder_id) where folder_id is not null;

create table public.vault_item_files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_id uuid not null,
  storage_path text not null unique,
  file_name text not null check (length(btrim(file_name)) between 1 and 255),
  mime_type text not null check (mime_type in (
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/heic', 'image/jpeg', 'image/png', 'text/plain'
  )),
  file_size_bytes bigint not null check (file_size_bytes between 1 and 20971520),
  checksum_sha256 text check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-fA-F]{64}$'),
  created_at timestamptz not null default now(),
  foreign key (user_id, item_id)
    references public.vault_items (user_id, id) on delete cascade,
  check (
    split_part(storage_path, '/', 1) = user_id::text
    and split_part(storage_path, '/', 2) = item_id::text
    and split_part(storage_path, '/', 3) <> ''
    and split_part(storage_path, '/', 4) = ''
    and right(storage_path, 1) <> '/'
  )
);

create index vault_item_files_item on public.vault_item_files (user_id, item_id, created_at);

create table public.vault_item_skills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 120),
  source text not null default 'user' check (source in ('user', 'ayla', 'organization', 'import')),
  status text not null default 'accepted' check (status in ('proposed', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (user_id, item_id)
    references public.vault_items (user_id, id) on delete cascade
);

create unique index vault_item_skills_item_name
  on public.vault_item_skills (user_id, item_id, lower(name));
create index vault_item_skills_item on public.vault_item_skills (user_id, item_id, status);

create table public.vault_validation_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item_id uuid not null,
  organisation_name text not null check (length(btrim(organisation_name)) between 1 and 200),
  message text check (message is null or length(message) <= 2000),
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected', 'cancelled')),
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  response text check (response is null or length(response) <= 2000),
  foreign key (user_id, item_id)
    references public.vault_items (user_id, id) on delete cascade,
  check ((status = 'pending' and resolved_at is null) or (status <> 'pending' and resolved_at is not null))
);

create index vault_validation_requests_user_status
  on public.vault_validation_requests (user_id, status, requested_at desc);
create index vault_validation_requests_item
  on public.vault_validation_requests (user_id, item_id, requested_at desc);

-- A grant is scoped to one Ayla request/task. The selected rows are the allowlist the server must check before
-- reading vault content. Completion, expiry or withdrawal closes the grant; the row remains as an audit record.
create unique index ayla_conversations_user_id_id
  on public.ayla_conversations (user_id, id);

create table public.vault_access_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  request_id text not null check (length(btrim(request_id)) between 1 and 200),
  conversation_id uuid,
  purpose text not null check (length(btrim(purpose)) between 1 and 500),
  granted_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '1 hour'),
  completed_at timestamptz,
  withdrawn_at timestamptz,
  unique (user_id, id),
  unique (user_id, request_id),
  foreign key (user_id, conversation_id)
    references public.ayla_conversations (user_id, id) on delete set null (conversation_id),
  check (expires_at > granted_at),
  check (completed_at is null or completed_at >= granted_at)
);

create index vault_access_grants_user_active
  on public.vault_access_grants (user_id, expires_at) where withdrawn_at is null and completed_at is null;

create table public.vault_access_grant_items (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  grant_id uuid not null,
  item_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, grant_id, item_id),
  foreign key (user_id, grant_id)
    references public.vault_access_grants (user_id, id) on delete cascade,
  foreign key (user_id, item_id)
    references public.vault_items (user_id, id) on delete cascade
);

create index vault_access_grant_items_item on public.vault_access_grant_items (user_id, item_id);

create table public.vault_access_grant_categories (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  grant_id uuid not null,
  category text not null check (category in (
    'diplomas', 'certificates', 'badges', 'projects', 'workExperience',
    'internships', 'skills', 'feedback', 'reflections'
  )),
  created_at timestamptz not null default now(),
  primary key (user_id, grant_id, category),
  foreign key (user_id, grant_id)
    references public.vault_access_grants (user_id, id) on delete cascade
);

create index vault_access_grant_categories_category
  on public.vault_access_grant_categories (user_id, category);

create or replace function public.set_vault_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger vault_folders_set_updated_at
  before update on public.vault_folders
  for each row execute function public.set_vault_updated_at();

create trigger vault_items_set_updated_at
  before update on public.vault_items
  for each row execute function public.set_vault_updated_at();

create trigger vault_item_skills_set_updated_at
  before update on public.vault_item_skills
  for each row execute function public.set_vault_updated_at();

-- Account sessions may add and edit their own items, but only trusted server code can mark an item verified/rejected
-- or claim an organisation/Ayla/import source.
create or replace function public.guard_vault_item_authority()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.source <> 'user' or new.verification_status <> 'toVerify' then
        raise exception 'Vault items must be user-created and unverified' using errcode = '42501';
      end if;
    elsif new.source is distinct from old.source
       or new.verification_status is distinct from old.verification_status then
      raise exception 'Only trusted server code may change vault item source or verification status' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger vault_items_guard_authority
  before insert or update on public.vault_items
  for each row execute function public.guard_vault_item_authority();

-- Ayla may propose a skill. The user may accept or reject that proposal, but cannot forge its origin.
create or replace function public.guard_vault_item_skill_authority()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.source <> 'user' or new.status <> 'accepted' then
        raise exception 'Only trusted server code may add proposed or attributed skills' using errcode = '42501';
      end if;
    else
      if new.source is distinct from old.source then
        raise exception 'Skill source cannot be changed' using errcode = '42501';
      end if;
      if old.source = 'ayla' then
        if new.status not in ('accepted', 'rejected') then
          raise exception 'Ayla skill proposals must be accepted or rejected' using errcode = '42501';
        end if;
      elsif new.status is distinct from old.status then
        raise exception 'Only Ayla skill proposals can change approval status' using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end;
$$;

create trigger vault_item_skills_guard_authority
  before insert or update on public.vault_item_skills
  for each row execute function public.guard_vault_item_skill_authority();

-- Validation outcomes are set by the validation service, never by the account that requested validation.
create or replace function public.guard_vault_validation_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' and new.status <> 'pending' then
      raise exception 'Validation requests must start as pending' using errcode = '42501';
    elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
      raise exception 'Only the validation service may change request status' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger vault_validation_requests_guard_status
  before insert or update on public.vault_validation_requests
  for each row execute function public.guard_vault_validation_status();

-- A user can withdraw an active grant once. The original task, purpose and grant time remain auditable.
create or replace function public.guard_vault_access_grant_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if new.user_id is distinct from old.user_id
       or new.request_id is distinct from old.request_id
       or new.conversation_id is distinct from old.conversation_id
       or new.purpose is distinct from old.purpose
       or new.granted_at is distinct from old.granted_at
       or new.expires_at is distinct from old.expires_at
       or new.completed_at is distinct from old.completed_at
       or old.withdrawn_at is not null and new.withdrawn_at is distinct from old.withdrawn_at then
      raise exception 'A grant can only be withdrawn, not rewritten' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger vault_access_grants_guard_update
  before update on public.vault_access_grants
  for each row execute function public.guard_vault_access_grant_update();

alter table public.vault_folders enable row level security;
alter table public.vault_items enable row level security;
alter table public.vault_item_files enable row level security;
alter table public.vault_item_skills enable row level security;
alter table public.vault_validation_requests enable row level security;
alter table public.vault_access_grants enable row level security;
alter table public.vault_access_grant_items enable row level security;
alter table public.vault_access_grant_categories enable row level security;

-- MFA is mandatory for every vault row, in addition to ownership checks below.
create policy "Require two-step verification"
  on public.vault_folders as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_items as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_item_files as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_item_skills as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_validation_requests as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_access_grants as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_access_grant_items as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());
create policy "Require two-step verification"
  on public.vault_access_grant_categories as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Own vault folders"
  on public.vault_folders for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Own vault items"
  on public.vault_items for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Own vault item files"
  on public.vault_item_files for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Own vault item skills"
  on public.vault_item_skills for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.vault_folders to authenticated;
grant select, insert, update, delete on public.vault_items to authenticated;
grant select, insert, update, delete on public.vault_item_files to authenticated;
grant select, insert, update, delete on public.vault_item_skills to authenticated;

create policy "Read own validation requests"
  on public.vault_validation_requests for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Request validation for own items"
  on public.vault_validation_requests for insert to authenticated
  with check ((select auth.uid()) = user_id and status = 'pending');
create policy "Cancel pending validation requests"
  on public.vault_validation_requests for delete to authenticated
  using ((select auth.uid()) = user_id and status = 'pending');

create policy "Read own vault access grants"
  on public.vault_access_grants for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Grant access to own vault"
  on public.vault_access_grants for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and withdrawn_at is null
    and completed_at is null
    and expires_at > now()
  );
create policy "Withdraw own vault access grants"
  on public.vault_access_grants for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Read own grant items"
  on public.vault_access_grant_items for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Add own items to active grants"
  on public.vault_access_grant_items for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.vault_access_grants g
      where g.id = grant_id and g.user_id = (select auth.uid())
        and g.withdrawn_at is null and g.completed_at is null and g.expires_at > now()
    )
  );
create policy "Remove own items from active grants"
  on public.vault_access_grant_items for delete to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.vault_access_grants g
      where g.id = grant_id and g.user_id = (select auth.uid())
        and g.withdrawn_at is null and g.completed_at is null and g.expires_at > now()
    )
  );

create policy "Read own grant categories"
  on public.vault_access_grant_categories for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Add own categories to active grants"
  on public.vault_access_grant_categories for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.vault_access_grants g
      where g.id = grant_id and g.user_id = (select auth.uid())
        and g.withdrawn_at is null and g.completed_at is null and g.expires_at > now()
    )
  );
create policy "Remove own categories from active grants"
  on public.vault_access_grant_categories for delete to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.vault_access_grants g
      where g.id = grant_id and g.user_id = (select auth.uid())
        and g.withdrawn_at is null and g.completed_at is null and g.expires_at > now()
    )
  );

-- Do not let a user rewrite the outcome, source or creation time of a validation request.
revoke update, delete on public.vault_validation_requests from authenticated;
grant select, insert, delete on public.vault_validation_requests to authenticated;

-- A grant is immutable except for withdrawing it. Child rows can be removed while the grant is active.
revoke update, delete on public.vault_access_grants from authenticated;
revoke insert on public.vault_access_grants from authenticated;
grant select on public.vault_access_grants to authenticated;
grant insert (user_id, request_id, conversation_id, purpose) on public.vault_access_grants to authenticated;
grant update (withdrawn_at) on public.vault_access_grants to authenticated;
grant select, insert, delete on public.vault_access_grant_items to authenticated;
grant select, insert, delete on public.vault_access_grant_categories to authenticated;

-- Private source documents. Objects use the path <user UUID>/<item UUID>/<file UUID>.<extension>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pave-vault', 'pave-vault', false, 20971520,
  array[
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/heic', 'image/jpeg', 'image/png', 'text/plain'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Vault objects require two-step verification"
  on storage.objects as restrictive for all to authenticated
  using (bucket_id <> 'pave-vault' or public.is_mfa_verified())
  with check (bucket_id <> 'pave-vault' or public.is_mfa_verified());

-- This restrictive ownership guard still applies if another permissive Storage policy is added later.
create policy "Vault objects must belong to an owned item"
  on storage.objects as restrictive for all to authenticated
  using (
    bucket_id <> 'pave-vault'
    or (
      coalesce(array_length(storage.foldername(name), 1), 0) = 2
      and (storage.foldername(name))[1] = (select auth.uid())::text
      and exists (
        select 1 from public.vault_items i
        where i.id::text = (storage.foldername(name))[2]
          and i.user_id = (select auth.uid())
      )
    )
  )
  with check (
    bucket_id <> 'pave-vault'
    or (
      coalesce(array_length(storage.foldername(name), 1), 0) = 2
      and (storage.foldername(name))[1] = (select auth.uid())::text
      and exists (
        select 1 from public.vault_items i
        where i.id::text = (storage.foldername(name))[2]
          and i.user_id = (select auth.uid())
      )
    )
  );

create policy "Read own vault objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'pave-vault'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.vault_items i
      where i.id::text = (storage.foldername(name))[2]
        and i.user_id = (select auth.uid())
    )
  );
create policy "Upload own vault objects"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'pave-vault'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.vault_items i
      where i.id::text = (storage.foldername(name))[2]
        and i.user_id = (select auth.uid())
    )
  );
create policy "Update own vault objects"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'pave-vault'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.vault_items i
      where i.id::text = (storage.foldername(name))[2]
        and i.user_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'pave-vault'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.vault_items i
      where i.id::text = (storage.foldername(name))[2]
        and i.user_id = (select auth.uid())
    )
  );
create policy "Delete own vault objects"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'pave-vault'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.vault_items i
      where i.id::text = (storage.foldername(name))[2]
        and i.user_id = (select auth.uid())
    )
  );

-- Vault changes should appear on the user's other devices. Avoid adding a table twice if this is re-run manually.
do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'vault_folders', 'vault_items', 'vault_item_files', 'vault_item_skills',
    'vault_validation_requests', 'vault_access_grants',
    'vault_access_grant_items', 'vault_access_grant_categories'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = target_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I', target_table);
    end if;
  end loop;
end;
$$;

comment on table public.vault_items is
  'The account-owned evidence records in the PAVE vault. Only trusted server code may change verification_status or source.';
comment on table public.vault_item_files is
  'Private file metadata. File contents live in the non-public pave-vault Storage bucket; extracted text is not stored here.';
comment on table public.vault_access_grants is
  'A user''s task-scoped consent for Ayla. The server must check completion, expiry, withdrawal and selected child rows before reading vault data.';
