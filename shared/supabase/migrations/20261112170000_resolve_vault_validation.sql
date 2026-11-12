-- Atomic, reviewer-authorized verification decisions. The Edge Function validates the caller's
-- session and loads documents; this function is the only client-callable way to resolve a request.
alter table public.vault_validation_requests
  add column contact_email text check (contact_email is null or length(btrim(contact_email)) <= 254);

create policy "Require two-step verification for notifications"
  on public.user_notifications as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

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

  if p_action = 'verified' then
    insert into public.user_notifications (
      recipient_id, kind, title, body, validation_request_id, vault_item_id, dedupe_key
    ) values (
      v_request.user_id, 'evidence_verified', 'Bewijs geverifieerd', v_item_title,
      p_request_id, v_request.item_id, 'vault-validation:' || p_request_id::text
    ) on conflict (recipient_id, dedupe_key) do nothing;
  end if;

  return jsonb_build_object('request_id', p_request_id, 'item_id', v_request.item_id, 'status', p_action);
end;
$$;

revoke all on function public.resolve_vault_validation_request(uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.resolve_vault_validation_request(uuid, text, text, uuid) to service_role;

comment on function public.resolve_vault_validation_request(uuid, text, text, uuid) is
  'Service-role-only atomic resolution. The Edge Function authenticates the MFA-verified reviewer; this function checks reviewer assignment and records the decision.';

-- Store one inbox row for each completed Ayla reply. The trigger runs inside the database so an
-- authenticated client cannot forge notification content or recipients.
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
  select c.user_id, c.title into v_owner, v_title
  from public.ayla_conversations c where c.id = new.conversation_id;
  if v_owner is not null then
    insert into public.user_notifications (recipient_id, kind, title, body, conversation_id, dedupe_key)
    values (v_owner, 'conversation', coalesce(nullif(v_title, ''), 'Gesprek met Ayla'), 'Ayla heeft gereageerd.', new.conversation_id, 'ayla-message:' || new.id::text)
    on conflict (recipient_id, dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

create trigger ayla_message_notification
  after insert on public.ayla_messages
  for each row execute function public.notify_on_ayla_reply();

comment on function public.notify_on_ayla_reply() is
  'Creates an inbox entry for the owner when Ayla replies. Does not expose another account conversation.';
