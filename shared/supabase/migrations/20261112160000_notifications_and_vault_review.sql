-- Shared backend foundation for the iOS notification inbox and vault verification review.
-- This adds routing and inbox records only. Cross-account document access and verification decisions
-- must go through an authenticated Edge Function; never broaden client access to vault tables/storage.
-- See docs/vault.md for the current contract and rollout prerequisites.

-- The learner's free-text organisation name remains the display value. Trusted server code resolves
-- it to an organisation before routing a request to reviewers.
alter table public.vault_validation_requests
  add column organization_id uuid references public.organizations (id) on delete set null,
  add column resolved_by uuid references auth.users (id) on delete set null;

-- Existing guard already reserves outcomes for trusted server code. Extend it so clients cannot
-- assign a request to an organisation or forge the reviewer identity either.
create or replace function public.guard_vault_validation_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.status <> 'pending' or new.organization_id is not null or new.resolved_by is not null then
        raise exception 'Validation requests must start pending and be routed by trusted server code' using errcode = '42501';
      end if;
    elsif new.status is distinct from old.status
       or new.organization_id is distinct from old.organization_id
       or new.resolved_by is distinct from old.resolved_by then
      raise exception 'Only trusted server code may route or resolve validation requests' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create index vault_validation_requests_organization_pending
  on public.vault_validation_requests (organization_id, requested_at desc)
  where status = 'pending' and organization_id is not null;

-- Reviewer membership is explicitly assigned by trusted server/admin provisioning. We do not rely
-- on profiles.role values here because that table and its role vocabulary are owned outside these migrations.
create table public.vault_validation_reviewers (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  reviewer_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  primary key (organization_id, reviewer_id)
);

alter table public.vault_validation_reviewers enable row level security;
create policy "Reviewers can read their own assignments"
  on public.vault_validation_reviewers for select to authenticated
  using ((select auth.uid()) = reviewer_id and public.is_mfa_verified());

grant select on public.vault_validation_reviewers to authenticated;
revoke insert, update, delete on public.vault_validation_reviewers from authenticated;
revoke all on public.vault_validation_reviewers from anon;

-- Append-only record of decisions. RLS has no client policy: authenticated clients use the
-- validation Edge Function, which authorizes the assigned reviewer before writing with service role.
create table public.vault_validation_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.vault_validation_requests (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  actor_id uuid not null references auth.users (id) on delete restrict,
  action text not null check (action in ('verified', 'rejected')),
  response text check (response is null or length(response) <= 2000),
  created_at timestamptz not null default now()
);

create index vault_validation_events_request on public.vault_validation_events (request_id, created_at desc);
alter table public.vault_validation_events enable row level security;
revoke all on public.vault_validation_events from anon, authenticated;

-- Durable inbox. Payload is intentionally limited to display metadata and source IDs; it must not
-- contain evidence text, file paths, signed URLs, or chat contents.
create table public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('conversation', 'evidence_verified', 'verification_request')),
  title text not null check (length(btrim(title)) between 1 and 160),
  body text check (body is null or length(body) <= 500),
  conversation_id uuid references public.ayla_conversations (id) on delete cascade,
  validation_request_id uuid references public.vault_validation_requests (id) on delete cascade,
  vault_item_id uuid references public.vault_items (id) on delete cascade,
  dedupe_key text not null check (length(btrim(dedupe_key)) between 1 and 200),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (recipient_id, dedupe_key),
  check (
    (kind = 'conversation' and conversation_id is not null
      and validation_request_id is null and vault_item_id is null)
    or (kind = 'evidence_verified' and conversation_id is null
      and validation_request_id is not null and vault_item_id is not null)
    or (kind = 'verification_request' and conversation_id is null
      and validation_request_id is not null and vault_item_id is null)
  )
);

create index user_notifications_inbox
  on public.user_notifications (recipient_id, created_at desc);
create index user_notifications_unread
  on public.user_notifications (recipient_id, created_at desc) where read_at is null;

alter table public.user_notifications enable row level security;
create policy "Read own notifications"
  on public.user_notifications for select to authenticated
  using ((select auth.uid()) = recipient_id);
create policy "Mark own notifications read"
  on public.user_notifications for update to authenticated
  using ((select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = recipient_id);

grant select, update on public.user_notifications to authenticated;
revoke insert, delete on public.user_notifications from authenticated;
revoke all on public.user_notifications from anon;

-- Clients may only set/clear read_at. Trusted server code owns notification content and routing.
create or replace function public.guard_user_notification_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if new.id is distinct from old.id
       or new.recipient_id is distinct from old.recipient_id
       or new.kind is distinct from old.kind
       or new.title is distinct from old.title
       or new.body is distinct from old.body
       or new.conversation_id is distinct from old.conversation_id
       or new.validation_request_id is distinct from old.validation_request_id
       or new.vault_item_id is distinct from old.vault_item_id
       or new.dedupe_key is distinct from old.dedupe_key
       or new.created_at is distinct from old.created_at
       or (new.read_at is not null and old.read_at is not null) then
      raise exception 'Only notification read state can be changed by the recipient' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger user_notifications_guard_update
  before update on public.user_notifications
  for each row execute function public.guard_user_notification_update();

alter publication supabase_realtime add table public.user_notifications;

comment on table public.vault_validation_reviewers is
  'Explicit reviewer assignments. Manage only from trusted provisioning; role vocabulary lives outside this schema.';
comment on table public.vault_validation_events is
  'Append-only verification decisions written by the trusted validation function.';
comment on table public.user_notifications is
  'Private per-user notification inbox. Trusted server functions create rows; clients may read and mark them read.';
