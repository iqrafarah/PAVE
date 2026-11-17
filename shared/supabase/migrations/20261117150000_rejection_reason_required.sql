-- A rejection always carries the reviewer's reason, so the learner knows what to fix before asking again.
-- The resolver from 20261117130000, with one change: rejecting without a reason is refused.

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
  if p_action = 'rejected' and length(btrim(coalesce(p_response, ''))) = 0 then
    raise exception 'A rejection needs a reason' using errcode = '22023';
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
  set status = p_action, resolved_at = now(), resolved_by = v_actor, response = btrim(p_response)
  where r.id = p_request_id;

  insert into public.vault_validation_events (request_id, organization_id, actor_id, action, response)
  values (p_request_id, v_request.organization_id, v_actor, p_action, btrim(p_response));

  insert into public.user_notifications (
    recipient_id, kind, title, body, validation_request_id, vault_item_id, dedupe_key
  ) values (
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

comment on function public.resolve_vault_validation_request(uuid, text, text, uuid) is
  'Service-role-only atomic resolution. A rejection requires the reviewer''s reason, which the learner reads on the request.';
