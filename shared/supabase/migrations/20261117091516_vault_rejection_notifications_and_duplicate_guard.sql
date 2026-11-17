-- Notify learners about rejected evidence and prevent concurrent duplicate requests.
-- Existing duplicate pending rows must be reviewed before this migration can be applied.

do $$
begin
  if exists (
    select 1
    from public.vault_validation_requests
    where status = 'pending' and organization_id is not null
    group by user_id, item_id, organization_id
    having count(*) > 1
  ) then
    raise exception 'Duplicate pending vault requests exist; resolve them before applying this migration';
  end if;
end;
$$;

create unique index vault_validation_requests_one_pending_per_org
  on public.vault_validation_requests (user_id, item_id, organization_id)
  where status = 'pending' and organization_id is not null;

alter table public.user_notifications
  drop constraint user_notifications_kind_check,
  add constraint user_notifications_kind_check
    check (kind in ('conversation', 'evidence_verified', 'evidence_rejected', 'verification_request'));

alter table public.user_notifications
  drop constraint user_notifications_check,
  add constraint user_notifications_check
    check (
      (kind = 'conversation' and conversation_id is not null
        and validation_request_id is null and vault_item_id is null)
      or (kind in ('evidence_verified', 'evidence_rejected') and conversation_id is null
        and validation_request_id is not null and vault_item_id is not null)
      or (kind = 'verification_request' and conversation_id is null
        and validation_request_id is not null and vault_item_id is null)
    );

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
    select 1 from public.vault_validation_reviewers vr
    where vr.organization_id = v_request.organization_id and vr.reviewer_id = v_actor
  ) then
    raise exception 'Not assigned to this organisation' using errcode = '42501';
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

comment on function public.resolve_vault_validation_request(uuid, text, text, uuid) is
  'Service-role-only atomic resolution; emits a private inbox event for both approval and rejection.';
