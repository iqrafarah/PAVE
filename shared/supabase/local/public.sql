


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."education_level" AS ENUM (
    'vo',
    'mbo',
    'hbo',
    'wo'
);


ALTER TYPE "public"."education_level" OWNER TO "postgres";


CREATE TYPE "public"."profile_role" AS ENUM (
    'learner',
    'admin'
);


ALTER TYPE "public"."profile_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_change_chat_pin"("pin" "text", "new_pin" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
begin
  if new_pin !~ '^[0-9]{4}$' then raise exception 'invalid_pin'; end if;
  if not public.ayla_check_chat_pin(pin) then raise exception 'wrong_pin'; end if;
  update public.ayla_chat_pins
    set pin_hash = extensions.crypt(new_pin, extensions.gen_salt('bf', 10))
    where user_id = auth.uid();
end;
$_$;


ALTER FUNCTION "public"."ayla_change_chat_pin"("pin" "text", "new_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_chat_pin_exists"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select public.is_mfa_verified() and exists (select 1 from public.ayla_chat_pins where user_id = auth.uid());
$$;


ALTER FUNCTION "public"."ayla_chat_pin_exists"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_check_chat_pin"("pin" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  stored public.ayla_chat_pins;
begin
  if not public.is_mfa_verified() then raise exception 'mfa_required'; end if;
  select * into stored from public.ayla_chat_pins where user_id = auth.uid();
  if not found then raise exception 'no_pin'; end if;
  if stored.blocked_until is not null and stored.blocked_until > now() then
    raise exception 'too_many_attempts';
  end if;
  if stored.pin_hash = extensions.crypt(pin, stored.pin_hash) then
    update public.ayla_chat_pins set failed_attempts = 0, blocked_until = null where user_id = auth.uid();
    return true;
  end if;
  update public.ayla_chat_pins
    set failed_attempts = case when failed_attempts >= 4 then 0 else failed_attempts + 1 end,
        blocked_until = case when failed_attempts >= 4 then now() + interval '5 minutes' else null end
    where user_id = auth.uid();
  return false;
end;
$$;


ALTER FUNCTION "public"."ayla_check_chat_pin"("pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_delete_expired_chats"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS integer
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with gone as (
    delete from public.ayla_conversations c
    using public.profiles p
    where p.id = c.user_id
      and (p_user_id is null or c.user_id = p_user_id)
      and c.archived_at is null
      and c.project_id is null
      and coalesce(c.expiry_days, p.chat_expiry_days, 0) > 0
      and (c.pinned_at is null or not p.chat_expiry_keeps_pinned)
      and (not p.chat_expiry_keeps_locked
           or not exists (select 1 from public.ayla_locked_chats l where l.conversation_id = c.id))
      and (case when p.chat_expiry_from = 'created' then c.created_at
                else coalesce((select max(m.created_at) from public.ayla_messages m where m.conversation_id = c.id), c.created_at)
           end) + make_interval(days => coalesce(c.expiry_days, p.chat_expiry_days)) < now()
    returning 1
  )
  select count(*)::integer from gone;
$$;


ALTER FUNCTION "public"."ayla_delete_expired_chats"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_expire_my_chats"() RETURNS integer
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select case when auth.uid() is null then 0 else public.ayla_delete_expired_chats(auth.uid()) end;
$$;


ALTER FUNCTION "public"."ayla_expire_my_chats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_recover_chat_pin"("new_pin" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
begin
  if not public.is_mfa_verified() then raise exception 'mfa_required'; end if;
  if not exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) as entry
    where entry ->> 'method' = 'totp'
      and (entry ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 300
  ) then raise exception 'recent_mfa_required'; end if;
  if new_pin !~ '^[0-9]{4}$' then raise exception 'invalid_pin'; end if;
  update public.ayla_chat_pins
    set pin_hash = extensions.crypt(new_pin, extensions.gen_salt('bf', 10)), failed_attempts = 0, blocked_until = null
    where user_id = auth.uid();
  if not found then raise exception 'no_pin'; end if;
end;
$_$;


ALTER FUNCTION "public"."ayla_recover_chat_pin"("new_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_reset_chat_pin"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_mfa_verified() then raise exception 'mfa_required'; end if;
  delete from public.ayla_conversations
    where user_id = auth.uid()
    and id in (select conversation_id from public.ayla_locked_chats where user_id = auth.uid());
  delete from public.ayla_chat_pins where user_id = auth.uid();
end;
$$;


ALTER FUNCTION "public"."ayla_reset_chat_pin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ayla_set_chat_pin"("pin" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
begin
  if not public.is_mfa_verified() then raise exception 'mfa_required'; end if;
  if pin !~ '^[0-9]{4}$' then raise exception 'invalid_pin'; end if;
  insert into public.ayla_chat_pins (user_id, pin_hash)
  values (auth.uid(), extensions.crypt(pin, extensions.gen_salt('bf', 10)));
exception when unique_violation then
  raise exception 'pin_exists';
end;
$_$;


ALTER FUNCTION "public"."ayla_set_chat_pin"("pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_example_vault_folders"("target" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  insert into public.vault_folders (user_id, name, color, icon)
  values
    (target, 'Certificaten', 'green', 'check-badge'),
    (target, 'Diploma''s', 'green', 'academic-cap'),
    (target, 'Feedback', 'green', 'chat-bubble-left-ellipsis'),
    (target, 'Projecten', 'green', 'wrench-screwdriver')
  on conflict do nothing;
$$;


ALTER FUNCTION "public"."create_example_vault_folders"("target" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_example_vault_folders_for_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform public.create_example_vault_folders(new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."create_example_vault_folders_for_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_profile_for_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')), ''),
    'learner'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;


ALTER FUNCTION "public"."create_profile_for_new_user"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_profile_for_new_user"() IS 'Creates the profile of a new account: email, name from the metadata, role learner.';



CREATE OR REPLACE FUNCTION "public"."current_organization_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select organization_id from public.profiles where id = auth.uid();
$$;


ALTER FUNCTION "public"."current_organization_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."end_my_session"("target" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  removed integer;
begin
  if not public.is_mfa_verified() then
    raise exception 'Two-step verification is required' using errcode = '42501';
  end if;
  if target = nullif(auth.jwt() ->> 'session_id', '')::uuid then
    raise exception 'Use sign out for this device' using errcode = '22023';
  end if;
  delete from auth.sessions where id = target and user_id = auth.uid();
  get diagnostics removed = row_count;
  return removed > 0;
end;
$$;


ALTER FUNCTION "public"."end_my_session"("target" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."end_my_session"("target" "uuid") IS 'Signs one other session of the signed-in account out (aal2 only); not the current one.';



CREATE OR REPLACE FUNCTION "public"."fair_applications_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if current_user = 'authenticated' then
    if new.user_id <> old.user_id or new.employer_slug <> old.employer_slug or new.vacancy_id <> old.vacancy_id
       or new.vacancy_title <> old.vacancy_title or new.card <> old.card or new.status <> old.status
       or new.invited_at is distinct from old.invited_at or new.invited_for is distinct from old.invited_for
       or new.invitation_message is distinct from old.invitation_message or new.created_at <> old.created_at then
      raise exception 'Only the answer to an invitation can be changed';
    end if;
    if old.status <> 'invited' then
      raise exception 'There is no invitation to answer';
    end if;
    new.answered_at := now();
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."fair_applications_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_default_evidence_types"("p_contact_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."grant_default_evidence_types"("p_contact_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_conversation_plan"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.plan_id is not null and not exists (select 1 from public.plans p where p.id = new.plan_id and p.user_id = new.user_id) then
    raise exception 'plan_not_found' using errcode = '42501';
  end if;
  if new.plan_step_id is not null and not exists (select 1 from public.plan_steps s where s.id = new.plan_step_id and s.plan_id = new.plan_id) then
    new.plan_step_id := null;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_conversation_plan"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_profile_self_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  own text[] := array[
    'preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'display_mode',
    'chat_expiry_days', 'chat_expiry_from', 'chat_expiry_keeps_pinned', 'chat_expiry_keeps_locked', 'ayla_uses_archive',
    'language', 'updated_at'
  ];
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if (to_jsonb(new) - own) is distinct from (to_jsonb(old) - own) then
      raise exception 'Only the name, photo and preferences can be changed here' using errcode = '42501';
    end if;
    if new.avatar_path is not null and split_part(new.avatar_path, '/', 1) <> new.id::text then
      raise exception 'The photo must be in the folder of this account' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_profile_self_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_user_notification_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."guard_user_notification_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_vault_item_authority"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    if tg_op = 'INSERT' then
      if new.source not in ('user', 'ayla') or new.verification_status <> 'toVerify' or new.organization_id is not null then
        raise exception 'Vault items must be user-created, unverified and not linked to an organisation' using errcode = '42501';
      end if;
    else
      if new.source is distinct from old.source or new.organization_id is distinct from old.organization_id then
        raise exception 'Only trusted server code may change source or organisation' using errcode = '42501';
      end if;
      if new.verification_status is distinct from old.verification_status and new.verification_status <> 'toVerify' then
        raise exception 'Only trusted server code may confirm or reject an item' using errcode = '42501';
      end if;
      if (new.category, new.title, new.description, new.organisation_name, new.organisation_location,
          new.start_date, new.end_date, new.issued_on, new.is_current)
         is distinct from
         (old.category, old.title, old.description, old.organisation_name, old.organisation_location,
          old.start_date, old.end_date, old.issued_on, old.is_current) then
        new.verification_status := 'toVerify';
      end if;
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_vault_item_authority"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_vault_item_skill_authority"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."guard_vault_item_skill_authority"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_mfa_verified"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select auth.jwt() ->> 'aal') = 'aal2', false);
$$;


ALTER FUNCTION "public"."is_mfa_verified"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_mfa_verified"() IS 'True when the current session completed two-step verification (aal2). Use in restrictive RLS policies.';



CREATE OR REPLACE FUNCTION "public"."is_organization_admin"("target_organization" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and organization_id = target_organization
  );
$$;


ALTER FUNCTION "public"."is_organization_admin"("target_organization" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_sessions"() RETURNS TABLE("id" "uuid", "signed_in_at" "text", "last_active_at" "text", "user_agent" "text", "is_current" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    s.id,
    to_char(s.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    to_char(
      greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'UTC') at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS"Z"'
    ),
    s.user_agent,
    s.id = nullif(auth.jwt() ->> 'session_id', '')::uuid
  from auth.sessions s
  where s.user_id = auth.uid()
    and public.is_mfa_verified()
    and (s.not_after is null or s.not_after > now())
  order by greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'UTC') desc;
$$;


ALTER FUNCTION "public"."my_sessions"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."my_sessions"() IS 'The sessions of the signed-in account (aal2 only): where it is signed in, for Instellingen > Ingelogde apparaten.';



CREATE OR REPLACE FUNCTION "public"."normalize_plan"("p_plan_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if not exists (select 1 from public.plan_steps where plan_id = p_plan_id and status = 'active') then
    update public.plan_steps set status = 'active'
    where id = (select id from public.plan_steps where plan_id = p_plan_id and status = 'upcoming' order by position limit 1);
  end if;
  if exists (select 1 from public.plan_steps where plan_id = p_plan_id and status in ('upcoming', 'active')) then
    update public.plans set completed_at = null where id = p_plan_id and completed_at is not null;
  elsif exists (select 1 from public.plan_steps where plan_id = p_plan_id) then
    update public.plans set completed_at = now() where id = p_plan_id and completed_at is null;
  end if;
end;
$$;


ALTER FUNCTION "public"."normalize_plan"("p_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_on_ayla_reply"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_owner uuid;
  v_title text;
begin
  if new.role <> 'ayla' then return new; end if;
  select c.user_id, c.title into v_owner, v_title from public.ayla_conversations c where c.id = new.conversation_id;
  if v_owner is null then return new; end if;
  -- The chat is open on one of the owner's devices: no melding.
  if exists (
    select 1 from public.ayla_open_chats o
    where o.user_id = v_owner and o.conversation_id = new.conversation_id and o.seen_at > now() - interval '45 seconds'
  ) then
    return new;
  end if;
  insert into public.user_notifications (recipient_id, kind, title, body, conversation_id, dedupe_key)
  values (v_owner, 'conversation', coalesce(nullif(v_title, ''), 'Gesprek met Ayla'), 'Ayla heeft gereageerd.',
          new.conversation_id, 'ayla-message:' || new.id::text)
  on conflict (recipient_id, dedupe_key) do nothing;
  return new;
end;
$$;


ALTER FUNCTION "public"."notify_on_ayla_reply"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_on_ayla_reply"() IS 'Creates an inbox row for the owner when Ayla replies.';



CREATE OR REPLACE FUNCTION "public"."organization_contacts_default_evidence_types"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform public.grant_default_evidence_types(new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."organization_contacts_default_evidence_types"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profile_shares_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.code <> old.code or new.user_id <> old.user_id or new.created_at <> old.created_at then
    raise exception 'A share keeps its code and owner';
  end if;
  if old.revoked_at is not null then
    raise exception 'A share that was taken back stays taken back';
  end if;
  if new.revoked_at is not null then
    new.content := '{}'::jsonb;
    new.item_ids := '{}';
    new.paused_at := null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."profile_shares_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_deleted_notifications"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  delete from public.user_notifications where deleted_at < now() - interval '7 days';
$$;


ALTER FUNCTION "public"."purge_deleted_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_vault_validation_request"("p_request_id" "uuid", "p_action" "text", "p_response" "text" DEFAULT NULL::"text", "p_actor_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."resolve_vault_validation_request"("p_request_id" "uuid", "p_action" "text", "p_response" "text", "p_actor_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."resolve_vault_validation_request"("p_request_id" "uuid", "p_action" "text", "p_response" "text", "p_actor_id" "uuid") IS 'Decides a request in one transaction. A rejection needs a reason. Service role only.';



CREATE OR REPLACE FUNCTION "public"."reverify_vault_item_after_file_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  changed public.vault_item_files;
begin
  if coalesce(auth.role(), '') = 'service_role' or pg_trigger_depth() > 1 then
    return null;
  end if;
  changed := coalesce(new, old);
  update public.vault_items
  set verification_status = 'toVerify'
  where id = changed.item_id and user_id = changed.user_id and verification_status <> 'toVerify';
  return null;
end;
$$;


ALTER FUNCTION "public"."reverify_vault_item_after_file_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_plan"("p_plan" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid := (p_plan->>'id')::uuid;
  v_steps jsonb := coalesce(p_plan->'steps', '[]'::jsonb);
  v_chats jsonb := coalesce(p_plan->'conversations', '[]'::jsonb);
begin
  insert into public.plans (id, name, goal, template_id, metadata, created_at, updated_at, completed_at)
  values (
    v_id, btrim(p_plan->>'name'), coalesce(p_plan->>'goal', ''), nullif(p_plan->>'templateID', ''),
    coalesce(p_plan->'metadata', '{}'::jsonb), coalesce((p_plan->>'createdAt')::timestamptz, now()), now(),
    (p_plan->>'completedAt')::timestamptz
  )
  on conflict (id) do update
    set name = excluded.name, goal = excluded.goal, template_id = excluded.template_id, metadata = excluded.metadata,
        updated_at = now(), completed_at = excluded.completed_at;

  delete from public.plan_steps s
  where s.plan_id = v_id
    and not exists (select 1 from jsonb_array_elements(v_steps) e where (e->>'id')::uuid = s.id);

  -- Every step first without "active", so the one-active index never sees two while the order changes.
  update public.plan_steps set status = 'upcoming' where plan_id = v_id and status = 'active';

  insert into public.plan_steps (id, plan_id, position, title, summary, kind, status, completed_at, metadata)
  select (e->>'id')::uuid, v_id, (o - 1)::integer, btrim(e->>'title'), coalesce(e->>'summary', ''),
         coalesce(nullif(e->>'kind', ''), 'general'), coalesce(e->>'status', 'upcoming'),
         (e->>'completedAt')::timestamptz, coalesce(e->'metadata', '{}'::jsonb)
  from jsonb_array_elements(v_steps) with ordinality as t(e, o)
  on conflict (id) do update
    set position = excluded.position, title = excluded.title, summary = excluded.summary, kind = excluded.kind,
        status = excluded.status, completed_at = excluded.completed_at, metadata = excluded.metadata
    where public.plan_steps.plan_id = v_id;

  update public.ayla_conversations c set plan_id = null, plan_step_id = null
  where c.plan_id = v_id
    and not exists (select 1 from jsonb_array_elements(v_chats) e where (e->>'id')::uuid = c.id);

  update public.ayla_conversations c
  set plan_id = v_id, plan_step_id = nullif(e->>'stepID', '')::uuid
  from jsonb_array_elements(v_chats) e
  where c.id = (e->>'id')::uuid
    and (c.plan_id is distinct from v_id or c.plan_step_id is distinct from nullif(e->>'stepID', '')::uuid);

  perform public.normalize_plan(v_id);
end;
$$;


ALTER FUNCTION "public"."save_plan"("p_plan" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_open_chat"("p_device" "text", "p_conversation_id" "uuid", "p_open" boolean) RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if p_open then
    insert into public.ayla_open_chats (user_id, device, conversation_id, seen_at)
    values (auth.uid(), p_device, p_conversation_id, now())
    on conflict (user_id, device) do update set conversation_id = excluded.conversation_id, seen_at = excluded.seen_at;
  else
    delete from public.ayla_open_chats
    where user_id = auth.uid() and device = p_device and conversation_id = p_conversation_id;
  end if;
end;
$$;


ALTER FUNCTION "public"."set_open_chat"("p_device" "text", "p_conversation_id" "uuid", "p_open" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_plan_step_status"("p_step_id" "uuid", "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_plan uuid;
begin
  if p_status not in ('upcoming', 'active', 'done', 'skipped') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  select plan_id into v_plan from public.plan_steps where id = p_step_id;
  if v_plan is null then
    raise exception 'step_not_found' using errcode = 'P0002';
  end if;
  if p_status = 'active' then
    update public.plan_steps set status = 'upcoming' where plan_id = v_plan and status = 'active' and id <> p_step_id;
  end if;
  update public.plan_steps
  set status = p_status, completed_at = case when p_status = 'done' then coalesce(completed_at, now()) end
  where id = p_step_id;
  perform public.normalize_plan(v_plan);
  update public.plans set updated_at = now() where id = v_plan;
end;
$$;


ALTER FUNCTION "public"."set_plan_step_status"("p_step_id" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_vault_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_vault_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."share_profiles_touch"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.user_id <> old.user_id then
    raise exception 'A profile keeps its owner';
  end if;
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."share_profiles_touch"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_ayla_memory_categories"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if tg_op = 'UPDATE'
     and new.categories is not distinct from old.categories
     and new.category is distinct from old.category then
    -- Only the main category changed (an older client): it replaces the list.
    new.categories := array[new.category];
  elsif cardinality(new.categories) = 0 then
    new.categories := array[new.category];
  end if;
  -- Each category once, in the order given; the first is the main one.
  new.categories := array(
    select c from unnest(new.categories) with ordinality as u(c, i) group by c order by min(i)
  );
  new.category := new.categories[1];
  return new;
end;
$$;


ALTER FUNCTION "public"."sync_ayla_memory_categories"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_available_contacts"("p_category" "text") RETURNS TABLE("id" "uuid", "name" "text", "job_title" "text", "function" "text", "department_id" "uuid", "department_name" "text", "location_id" "uuid", "city" "text", "organization_id" "uuid", "location_name" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select c.id, c.name, c.job_title, coalesce(nullif(btrim(c.job_title), ''), 'Overig'),
         d.id, d.name, l.id, l.city, l.organization_id, l.name
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


ALTER FUNCTION "public"."validation_available_contacts"("p_category" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_contact_filters"("p_organization_id" "uuid", "p_category" "text") RETURNS TABLE("filter" "text", "value" "text", "label" "text", "location_id" "uuid", "people" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with people as (
    select a.* from public.validation_available_contacts(p_category) a
    where a.organization_id = p_organization_id
      and public.is_mfa_verified() and (select auth.uid()) is not null
  )
  -- "Westermarkt, Tilburg"; "Tilburg-Noord" when the name already says the city; "Tilburg" without a name.
  select 'location', p.location_id::text,
         case when p.location_name ilike '%' || p.city || '%' then p.location_name
              else concat_ws(', ', p.location_name, p.city) end,
         p.location_id, count(*)::int
  from people p group by p.location_id, p.location_name, p.city
  union all
  select 'department', p.department_id::text, p.department_name, p.location_id, count(*)::int
  from people p group by p.department_id, p.department_name, p.location_id
  union all
  select 'function', p.function, p.function, p.location_id, count(*)::int from people p group by p.function, p.location_id
  order by 1, 3;
$$;


ALTER FUNCTION "public"."validation_contact_filters"("p_organization_id" "uuid", "p_category" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_matches"("p_text" "text", "p_query" "text") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select not exists (
    select 1
    from unnest(regexp_split_to_array(btrim(coalesce(p_query, '')), '\s+')) as w (word)
    where w.word <> ''
      and p_text not ilike '%' || replace(replace(replace(w.word, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  );
$$;


ALTER FUNCTION "public"."validation_matches"("p_text" "text", "p_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_organizations"() RETURNS TABLE("id" "uuid", "name" "text", "kind" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select o.id, o.name, o.kind
  from public.organizations o
  where o.kind is not null
    and public.is_mfa_verified()
  order by o.name;
$$;


ALTER FUNCTION "public"."validation_organizations"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."validation_organizations"() IS 'Directory pick-list: id, name and kind of every organisation with a kind. MFA sessions only.';



CREATE OR REPLACE FUNCTION "public"."validation_organizations_by_id"("p_category" "text", "p_ids" "uuid"[]) RETURNS TABLE("id" "uuid", "name" "text", "kind" "text", "cities" "text"[], "available_contacts" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."validation_organizations_by_id"("p_category" "text", "p_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_places_by_id"("p_category" "text", "p_location_ids" "uuid"[]) RETURNS TABLE("organization_id" "uuid", "organization_name" "text", "kind" "text", "logo_url" "text", "location_id" "uuid", "city" "text", "location_name" "text", "address" "text", "available_contacts" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with people as (
    select a.location_id, count(*)::int as available
    from public.validation_available_contacts(p_category) a
    where a.location_id = any (p_location_ids)
    group by a.location_id
  )
  select o.id, o.name, o.kind, o.logo_url, l.id, l.city, l.name, l.address, coalesce(p.available, 0)
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id and o.kind is not null
  left join people p on p.location_id = l.id
  where l.id = any (p_location_ids[1:20])
    and public.is_mfa_verified() and (select auth.uid()) is not null;
$$;


ALTER FUNCTION "public"."validation_places_by_id"("p_category" "text", "p_location_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_previous_contacts"("p_category" "text", "p_limit" integer DEFAULT 5) RETURNS TABLE("id" "uuid", "name" "text", "job_title" "text", "function" "text", "department_id" "uuid", "department_name" "text", "location_id" "uuid", "city" "text", "organization_id" "uuid", "organization_name" "text", "location_name" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select a.id, a.name, a.job_title, a.function, a.department_id, a.department_name,
         a.location_id, a.city, a.organization_id, o.name, a.location_name
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


ALTER FUNCTION "public"."validation_previous_contacts"("p_category" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_search_contacts"("p_organization_id" "uuid", "p_category" "text", "p_query" "text" DEFAULT NULL::"text", "p_location_id" "uuid" DEFAULT NULL::"uuid", "p_department" "text" DEFAULT NULL::"text", "p_function" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 25, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "name" "text", "job_title" "text", "function" "text", "department_id" "uuid", "department_name" "text", "location_id" "uuid", "city" "text", "organization_id" "uuid", "location_name" "text", "total_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select a.id, a.name, a.job_title, a.function, a.department_id, a.department_name,
         a.location_id, a.city, a.organization_id, a.location_name, count(*) over ()
  from public.validation_available_contacts(p_category) a
  where a.organization_id = p_organization_id
    and (p_location_id is null or a.location_id = p_location_id)
    and (p_department is null or a.department_name = p_department)
    and (p_function is null or a.function = p_function)
    and public.validation_matches(concat_ws(' ', a.name, a.function, a.department_name, a.city, a.location_name), p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by a.name, a.city, a.department_name
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;


ALTER FUNCTION "public"."validation_search_contacts"("p_organization_id" "uuid", "p_category" "text", "p_query" "text", "p_location_id" "uuid", "p_department" "text", "p_function" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."validation_search_contacts"("p_organization_id" "uuid", "p_category" "text", "p_query" "text", "p_location_id" "uuid", "p_department" "text", "p_function" "text", "p_limit" integer, "p_offset" integer) IS 'A page of persons of one organisation who may confirm this kind of evidence. Never returns the account behind them.';



CREATE OR REPLACE FUNCTION "public"."validation_search_organizations"("p_category" "text", "p_query" "text" DEFAULT NULL::"text", "p_kind" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 25, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "name" "text", "kind" "text", "cities" "text"[], "available_contacts" integer, "total_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."validation_search_organizations"("p_category" "text", "p_query" "text", "p_kind" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validation_search_places"("p_category" "text", "p_query" "text" DEFAULT NULL::"text", "p_kind" "text" DEFAULT NULL::"text", "p_organization_id" "uuid" DEFAULT NULL::"uuid", "p_limit" integer DEFAULT 25, "p_offset" integer DEFAULT 0) RETURNS TABLE("organization_id" "uuid", "organization_name" "text", "kind" "text", "logo_url" "text", "location_id" "uuid", "city" "text", "location_name" "text", "address" "text", "available_contacts" integer, "total_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with people as (
    select a.location_id, count(*)::int as available
    from public.validation_available_contacts(p_category) a
    group by a.location_id
  )
  select o.id, o.name, o.kind, o.logo_url, l.id, l.city, l.name, l.address, p.available, count(*) over ()
  from public.organization_locations l
  join public.organizations o on o.id = l.organization_id and o.kind is not null
  join people p on p.location_id = l.id
  where (p_kind is null or o.kind = p_kind)
    and (p_organization_id is null or o.id = p_organization_id)
    and public.validation_matches(concat_ws(' ', o.name, l.city, l.name, l.address), p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by o.name, l.city, l.name nulls first
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;


ALTER FUNCTION "public"."validation_search_places"("p_category" "text", "p_query" "text", "p_kind" "text", "p_organization_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."vault_validation_recipients"("p_request_id" "uuid") RETURNS TABLE("reviewer_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."vault_validation_recipients"("p_request_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."vault_validation_recipients"("p_request_id" "uuid") IS 'The account of the chosen contact person, when authorised for the kind of evidence; never the learner who asked.';



CREATE OR REPLACE FUNCTION "public"."wipe_ended_shares"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  update public.profile_shares
  set content = '{}'::jsonb, item_ids = '{}'
  where expires_at < now() and (content <> '{}'::jsonb or cardinality(item_ids) > 0);
$$;


ALTER FUNCTION "public"."wipe_ended_shares"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."application_drafts" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "id" "text" NOT NULL,
    "draft" "jsonb",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "application_drafts_check" CHECK ((("draft" IS NOT NULL) OR ("deleted_at" IS NOT NULL))),
    CONSTRAINT "application_drafts_draft_check" CHECK ((("draft" IS NULL) OR ("jsonb_typeof"("draft") = 'object'::"text"))),
    CONSTRAINT "application_drafts_draft_check1" CHECK ((("draft" IS NULL) OR ("pg_column_size"("draft") <= 1048576))),
    CONSTRAINT "application_drafts_id_check" CHECK ((("length"("id") >= 1) AND ("length"("id") <= 200)))
);


ALTER TABLE "public"."application_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_chat_pins" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "pin_hash" "text" NOT NULL,
    "failed_attempts" integer DEFAULT 0 NOT NULL,
    "blocked_until" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ayla_chat_pins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "title" "text" DEFAULT 'Nieuw gesprek'::"text" NOT NULL,
    "started_on" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "pinned_at" timestamp with time zone,
    "project_id" "uuid",
    "archived_at" timestamp with time zone,
    "expiry_days" integer,
    "plan_id" "uuid",
    "plan_step_id" "uuid",
    CONSTRAINT "ayla_conversations_expiry_days_check" CHECK ((("expiry_days" IS NULL) OR ("expiry_days" = ANY (ARRAY[0, 1, 7, 30, 90])))),
    CONSTRAINT "ayla_conversations_started_on_check" CHECK (("started_on" = ANY (ARRAY['watch'::"text", 'phone'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."ayla_conversations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."ayla_conversations"."archived_at" IS 'Archived: out of the chat list, kept until it is put back or deleted. Never expires.';



COMMENT ON COLUMN "public"."ayla_conversations"."expiry_days" IS 'An own expiry for this chat: null follows the account, 0 never expires.';



CREATE TABLE IF NOT EXISTS "public"."ayla_locked_chats" (
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "locked_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ayla_locked_chats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_memories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "text" "text" NOT NULL,
    "source" "text" DEFAULT 'ayla'::"text" NOT NULL,
    "conversation_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "category" "text" DEFAULT 'personal'::"text" NOT NULL,
    "categories" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "ayla_memories_categories_check" CHECK (((("cardinality"("categories") >= 1) AND ("cardinality"("categories") <= 8)) AND ("categories" <@ ARRAY['education'::"text", 'work'::"text", 'goals'::"text", 'skills'::"text", 'values'::"text", 'workStyle'::"text", 'interests'::"text", 'personal'::"text"]) AND ("category" = "categories"[1]))),
    CONSTRAINT "ayla_memories_category_check" CHECK (("category" = ANY (ARRAY['education'::"text", 'work'::"text", 'goals'::"text", 'skills'::"text", 'values'::"text", 'workStyle'::"text", 'interests'::"text", 'personal'::"text"]))),
    CONSTRAINT "ayla_memories_source_check" CHECK (("source" = ANY (ARRAY['ayla'::"text", 'user'::"text"]))),
    CONSTRAINT "ayla_memories_text_check" CHECK ((("length"("text") >= 1) AND ("length"("text") <= 300)))
);


ALTER TABLE "public"."ayla_memories" OWNER TO "postgres";


COMMENT ON COLUMN "public"."ayla_memories"."categories" IS 'Every category the note is in, at least one; the first is the same as category.';



CREATE TABLE IF NOT EXISTS "public"."ayla_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "role" "text" NOT NULL,
    "text" "text" NOT NULL,
    "device" "text" NOT NULL,
    "reply" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ayla_messages_device_check" CHECK (("device" = ANY (ARRAY['watch'::"text", 'phone'::"text", 'web'::"text"]))),
    CONSTRAINT "ayla_messages_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'ayla'::"text"]))),
    CONSTRAINT "ayla_messages_text_check" CHECK ((("length"("text") >= 1) AND ("length"("text") <= 4000)))
);


ALTER TABLE "public"."ayla_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_open_chats" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "device" "text" NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "seen_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ayla_open_chats_device_check" CHECK ((("length"("device") >= 1) AND ("length"("device") <= 80)))
);


ALTER TABLE "public"."ayla_open_chats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_project_sources" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "item_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ayla_project_sources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_projects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "name" "text" NOT NULL,
    "instructions" "text" DEFAULT ''::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "pinned_at" timestamp with time zone,
    "icon" "text",
    "color" "text",
    CONSTRAINT "ayla_projects_color_check" CHECK ((("color" IS NULL) OR ("color" ~ '^[a-z]{3,10}$'::"text") OR ("color" ~ '^#[0-9a-f]{6}$'::"text"))),
    CONSTRAINT "ayla_projects_icon_check" CHECK ((("icon" IS NULL) OR ("length"("icon") <= 40))),
    CONSTRAINT "ayla_projects_instructions_check" CHECK (("length"("instructions") <= 2000)),
    CONSTRAINT "ayla_projects_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 80)))
);


ALTER TABLE "public"."ayla_projects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ayla_settings" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "memory_enabled" boolean DEFAULT true NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ayla_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fair_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "employer_slug" "text" NOT NULL,
    "vacancy_id" "text" NOT NULL,
    "vacancy_title" "text" NOT NULL,
    "card" "jsonb" NOT NULL,
    "status" "text" DEFAULT 'new'::"text" NOT NULL,
    "invited_at" timestamp with time zone,
    "invited_for" timestamp with time zone,
    "invitation_message" "text",
    "answer" "text",
    "answered_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "fair_applications_answer_check" CHECK ((("answer" IS NULL) OR ("answer" = ANY (ARRAY['accepted'::"text", 'declined'::"text"])))),
    CONSTRAINT "fair_applications_card_check" CHECK ((("jsonb_typeof"("card") = 'object'::"text") AND ("pg_column_size"("card") < 20000))),
    CONSTRAINT "fair_applications_invitation_message_check" CHECK ((("invitation_message" IS NULL) OR ("length"("invitation_message") <= 400))),
    CONSTRAINT "fair_applications_status_check" CHECK (("status" = ANY (ARRAY['new'::"text", 'invited'::"text", 'declined'::"text"]))),
    CONSTRAINT "fair_applications_vacancy_id_check" CHECK ((("length"("vacancy_id") >= 1) AND ("length"("vacancy_id") <= 80))),
    CONSTRAINT "fair_applications_vacancy_title_check" CHECK ((("length"("vacancy_title") >= 1) AND ("length"("vacancy_title") <= 160)))
);


ALTER TABLE "public"."fair_applications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fair_employer_keys" (
    "employer_slug" "text" NOT NULL,
    "key_hash" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."fair_employer_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fair_employers" (
    "slug" "text" NOT NULL,
    "name" "text" NOT NULL,
    "city" "text",
    "about" "text" NOT NULL,
    "stand" "text",
    "website" "text",
    "vacancies" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "is_example" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "fair_employers_slug_check" CHECK (("slug" ~ '^[a-z0-9-]{2,40}$'::"text")),
    CONSTRAINT "fair_employers_vacancies_check" CHECK (("jsonb_typeof"("vacancies") = 'array'::"text"))
);


ALTER TABLE "public"."fair_employers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_contact_evidence_types" (
    "contact_id" "uuid" NOT NULL,
    "category" "text" NOT NULL,
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "organization_contact_evidence_types_category_check" CHECK (("category" = ANY (ARRAY['diplomas'::"text", 'certificates'::"text", 'badges'::"text", 'projects'::"text", 'workExperience'::"text", 'internships'::"text", 'skills'::"text", 'feedback'::"text", 'reflections'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."organization_contact_evidence_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."organization_contact_evidence_types" IS 'The kinds of evidence (vault_items.category) a contact person is authorised to confirm. Managed by administrators.';



CREATE TABLE IF NOT EXISTS "public"."organization_contacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "department_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "job_title" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewer_id" "uuid",
    CONSTRAINT "organization_contacts_job_title_check" CHECK ((("job_title" IS NULL) OR (("length"("btrim"("job_title")) >= 1) AND ("length"("btrim"("job_title")) <= 120)))),
    CONSTRAINT "organization_contacts_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 120)))
);


ALTER TABLE "public"."organization_contacts" OWNER TO "postgres";


COMMENT ON TABLE "public"."organization_contacts" IS 'The persons a learner can ask to confirm evidence, in one department. reviewer_id (hidden from learners) is their PAVE account; only persons with one are shown.';



COMMENT ON COLUMN "public"."organization_contacts"."reviewer_id" IS 'The PAVE account that receives and decides requests to this person.';



CREATE TABLE IF NOT EXISTS "public"."organization_departments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "location_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "organization_departments_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 120)))
);


ALTER TABLE "public"."organization_departments" OWNER TO "postgres";


COMMENT ON TABLE "public"."organization_departments" IS 'Departments of one location: study programmes at a school, Stage or HR at a company.';



CREATE TABLE IF NOT EXISTS "public"."organization_kind_evidence_types" (
    "kind" "text" NOT NULL,
    "category" "text" NOT NULL,
    CONSTRAINT "organization_kind_evidence_types_category_check" CHECK (("category" = ANY (ARRAY['diplomas'::"text", 'certificates'::"text", 'badges'::"text", 'projects'::"text", 'workExperience'::"text", 'internships'::"text", 'skills'::"text", 'feedback'::"text", 'reflections'::"text", 'other'::"text"]))),
    CONSTRAINT "organization_kind_evidence_types_kind_check" CHECK (("kind" = ANY (ARRAY['school'::"text", 'company'::"text", 'government'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."organization_kind_evidence_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."organization_kind_evidence_types" IS 'The kinds of evidence a new contact person may confirm, by kind of organisation. Managed by administrators.';



CREATE TABLE IF NOT EXISTS "public"."organization_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "city" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text",
    "address" "text",
    CONSTRAINT "organization_locations_address_length" CHECK ((("address" IS NULL) OR (("length"("btrim"("address")) >= 1) AND ("length"("btrim"("address")) <= 200)))),
    CONSTRAINT "organization_locations_city_check" CHECK ((("length"("btrim"("city")) >= 1) AND ("length"("btrim"("city")) <= 100))),
    CONSTRAINT "organization_locations_name_length" CHECK ((("name" IS NULL) OR (("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 100))))
);


ALTER TABLE "public"."organization_locations" OWNER TO "postgres";


COMMENT ON TABLE "public"."organization_locations" IS 'The places of an organisation, for the verification directory.';



COMMENT ON COLUMN "public"."organization_locations"."name" IS 'The name of this location within its city ("Westermarkt"); needed when the organisation has more than one there.';



COMMENT ON COLUMN "public"."organization_locations"."address" IS 'The street address, shown so the learner knows which location.';



CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "support_email" "text",
    "support_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "logo_url" "text",
    "kind" "text",
    "registry_type" "text",
    "registry_id" "text",
    CONSTRAINT "organizations_kind_check" CHECK ((("kind" IS NULL) OR ("kind" = ANY (ARRAY['school'::"text", 'company'::"text", 'government'::"text", 'other'::"text"])))),
    CONSTRAINT "organizations_logo_url_check" CHECK ((("logo_url" IS NULL) OR ("logo_url" ~ '^https://'::"text"))),
    CONSTRAINT "organizations_registry" CHECK (((("registry_type" IS NULL) AND ("registry_id" IS NULL)) OR (("registry_type" = ANY (ARRAY['kvk'::"text", 'brin'::"text", 'oin'::"text", 'other'::"text"])) AND (("length"("btrim"("registry_id")) >= 1) AND ("length"("btrim"("registry_id")) <= 64)))))
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organizations"."logo_url" IS 'A public https image of the organisation''s logo, shown on vault cards.';



COMMENT ON COLUMN "public"."organizations"."kind" IS 'school, company, government or other; null keeps the organisation out of the verification directory.';



COMMENT ON COLUMN "public"."organizations"."registry_type" IS 'kvk (KvK-nummer), brin (onderwijs), oin (overheid) or other.';



COMMENT ON COLUMN "public"."organizations"."registry_id" IS 'The number in that registry; unique per registry.';



CREATE TABLE IF NOT EXISTS "public"."plan_steps" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "position" integer NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" DEFAULT ''::"text" NOT NULL,
    "kind" "text" DEFAULT 'general'::"text" NOT NULL,
    "status" "text" DEFAULT 'upcoming'::"text" NOT NULL,
    "completed_at" timestamp with time zone,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "plan_steps_kind_check" CHECK (("kind" ~ '^[A-Za-z][A-Za-z0-9_-]{0,39}$'::"text")),
    CONSTRAINT "plan_steps_metadata_check" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "plan_steps_position_check" CHECK (("position" >= 0)),
    CONSTRAINT "plan_steps_status_check" CHECK (("status" = ANY (ARRAY['upcoming'::"text", 'active'::"text", 'done'::"text", 'skipped'::"text"]))),
    CONSTRAINT "plan_steps_summary_check" CHECK (("length"("summary") <= 280)),
    CONSTRAINT "plan_steps_title_check" CHECK ((("length"("btrim"("title")) >= 1) AND ("length"("btrim"("title")) <= 80)))
);


ALTER TABLE "public"."plan_steps" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "name" "text" NOT NULL,
    "goal" "text" DEFAULT ''::"text" NOT NULL,
    "template_id" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "plans_goal_check" CHECK (("length"("goal") <= 280)),
    CONSTRAINT "plans_metadata_check" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "plans_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 80))),
    CONSTRAINT "plans_template_id_check" CHECK ((("template_id" IS NULL) OR (("length"("template_id") >= 1) AND ("length"("template_id") <= 40))))
);


ALTER TABLE "public"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_share_views" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "share_id" "uuid" NOT NULL,
    "viewed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "action" "text" NOT NULL,
    "viewer_name" "text",
    "viewer_organisation" "text",
    CONSTRAINT "profile_share_views_action_check" CHECK (("action" = ANY (ARRAY['view'::"text", 'download'::"text"]))),
    CONSTRAINT "profile_share_views_viewer_name_check" CHECK ((("viewer_name" IS NULL) OR ("length"("viewer_name") <= 80))),
    CONSTRAINT "profile_share_views_viewer_organisation_check" CHECK ((("viewer_organisation" IS NULL) OR ("length"("viewer_organisation") <= 80)))
);


ALTER TABLE "public"."profile_share_views" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_shares" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "code" "text" DEFAULT "encode"("extensions"."gen_random_bytes"(16), 'hex'::"text") NOT NULL,
    "title" "text" NOT NULL,
    "recipient_name" "text" NOT NULL,
    "recipient_organisation" "text",
    "purpose" "text",
    "template" "text" NOT NULL,
    "item_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "content" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "allows_download" boolean DEFAULT false NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "paused_at" timestamp with time zone,
    "revoked_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "profile_shares_check" CHECK (("expires_at" <= ("created_at" + '366 days'::interval))),
    CONSTRAINT "profile_shares_check1" CHECK (("expires_at" > "created_at")),
    CONSTRAINT "profile_shares_content_check" CHECK ((("jsonb_typeof"("content") = 'object'::"text") AND ("pg_column_size"("content") < 200000))),
    CONSTRAINT "profile_shares_item_ids_check" CHECK (("cardinality"("item_ids") <= 100)),
    CONSTRAINT "profile_shares_purpose_check" CHECK ((("purpose" IS NULL) OR ("length"("purpose") <= 200))),
    CONSTRAINT "profile_shares_recipient_name_check" CHECK ((("length"("btrim"("recipient_name")) >= 1) AND ("length"("btrim"("recipient_name")) <= 120))),
    CONSTRAINT "profile_shares_recipient_organisation_check" CHECK ((("recipient_organisation" IS NULL) OR ("length"("recipient_organisation") <= 120))),
    CONSTRAINT "profile_shares_template_check" CHECK (("template" = ANY (ARRAY['employer'::"text", 'education'::"text", 'municipality'::"text", 'fair'::"text"]))),
    CONSTRAINT "profile_shares_title_check" CHECK ((("length"("btrim"("title")) >= 1) AND ("length"("btrim"("title")) <= 120)))
);


ALTER TABLE "public"."profile_shares" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "full_name" "text",
    "email" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "preferred_name" "text",
    "organization_id" "uuid",
    "role" "public"."profile_role" DEFAULT 'learner'::"public"."profile_role" NOT NULL,
    "education_level" "public"."education_level",
    "program" "text",
    "expected_graduation" "date",
    "locale" "text" DEFAULT 'nl'::"text" NOT NULL,
    "onboarding_completed_at" timestamp with time zone,
    "avatar_path" "text",
    "theme_color" "text" DEFAULT 'green'::"text" NOT NULL,
    "text_size" "text" DEFAULT 'standard'::"text" NOT NULL,
    "vault_layout" "text" DEFAULT 'grid'::"text" NOT NULL,
    "theme_custom_color" "text",
    "display_mode" "text" DEFAULT 'auto'::"text" NOT NULL,
    "chat_expiry_days" integer,
    "chat_expiry_from" "text" DEFAULT 'last_message'::"text" NOT NULL,
    "chat_expiry_keeps_pinned" boolean DEFAULT true NOT NULL,
    "chat_expiry_keeps_locked" boolean DEFAULT true NOT NULL,
    "ayla_uses_archive" boolean DEFAULT false NOT NULL,
    "language" "text",
    CONSTRAINT "profiles_avatar_path_check" CHECK ((("avatar_path" IS NULL) OR ("avatar_path" ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|jpeg|png|heic)$'::"text"))),
    CONSTRAINT "profiles_chat_expiry_days_check" CHECK ((("chat_expiry_days" IS NULL) OR ("chat_expiry_days" = ANY (ARRAY[1, 7, 30, 90])))),
    CONSTRAINT "profiles_chat_expiry_from_check" CHECK (("chat_expiry_from" = ANY (ARRAY['last_message'::"text", 'created'::"text"]))),
    CONSTRAINT "profiles_display_mode_check" CHECK (("display_mode" = ANY (ARRAY['auto'::"text", 'light'::"text", 'dark'::"text"]))),
    CONSTRAINT "profiles_language_check" CHECK ((("language" IS NULL) OR ("language" = ANY (ARRAY['nl'::"text", 'en'::"text", 'pap'::"text"])))),
    CONSTRAINT "profiles_locale_check" CHECK (("locale" = ANY (ARRAY['nl'::"text", 'en'::"text"]))),
    CONSTRAINT "profiles_preferred_name_length" CHECK ((("preferred_name" IS NULL) OR (("length"("btrim"("preferred_name")) >= 1) AND ("length"("btrim"("preferred_name")) <= 60)))),
    CONSTRAINT "profiles_text_size_check" CHECK (("text_size" = ANY (ARRAY['small'::"text", 'standard'::"text", 'large'::"text"]))),
    CONSTRAINT "profiles_theme_color_check" CHECK (("theme_color" = ANY (ARRAY['green'::"text", 'blue'::"text", 'gold'::"text", 'pink'::"text", 'orange'::"text", 'purple'::"text", 'red'::"text", 'lime'::"text", 'custom'::"text"]))),
    CONSTRAINT "profiles_theme_custom_color_check" CHECK ((("theme_custom_color" IS NULL) OR ("theme_custom_color" ~ '^#[0-9A-F]{6}$'::"text"))),
    CONSTRAINT "profiles_vault_layout_check" CHECK (("vault_layout" = ANY (ARRAY['list'::"text", 'grid'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."avatar_path" IS 'An own profile photo in the pave-avatars bucket (<user id>/<uuid>.<ext>). Wins over avatar_url when set.';



COMMENT ON COLUMN "public"."profiles"."theme_color" IS 'The accent colour the apps use for this account; custom uses theme_custom_color.';



COMMENT ON COLUMN "public"."profiles"."text_size" IS 'small, standard (the device setting) or large.';



COMMENT ON COLUMN "public"."profiles"."vault_layout" IS 'How the vault opens: list or grid. The vault can still switch for a moment.';



COMMENT ON COLUMN "public"."profiles"."theme_custom_color" IS 'An own accent colour as #RRGGBB. The apps darken it until white text on it is readable (WCAG AA, 4.5:1).';



COMMENT ON COLUMN "public"."profiles"."display_mode" IS 'auto (dark from 19:00 to 07:00 on the device), light or dark.';



COMMENT ON COLUMN "public"."profiles"."chat_expiry_days" IS 'After how many days a chat is deleted for good; null is no expiry.';



COMMENT ON COLUMN "public"."profiles"."chat_expiry_from" IS 'From when the time runs: last_message or created.';



COMMENT ON COLUMN "public"."profiles"."chat_expiry_keeps_pinned" IS 'Pinned chats do not expire.';



COMMENT ON COLUMN "public"."profiles"."chat_expiry_keeps_locked" IS 'Locked chats do not expire.';



COMMENT ON COLUMN "public"."profiles"."ayla_uses_archive" IS 'Whether Ayla may use archived evidence the account allowed her to see.';



COMMENT ON COLUMN "public"."profiles"."language" IS 'nl (Nederlands), en (English) or pap (Papiamentu); null follows the language of the device.';



CREATE TABLE IF NOT EXISTS "public"."saved_vacancies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "vacancy_id" "text" NOT NULL,
    "vacancy" "jsonb" NOT NULL,
    "saved_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "saved_vacancies_vacancy_check" CHECK ((("jsonb_typeof"("vacancy") = 'object'::"text") AND ("pg_column_size"("vacancy") < 20000))),
    CONSTRAINT "saved_vacancies_vacancy_id_check" CHECK ((("length"("vacancy_id") >= 1) AND ("length"("vacancy_id") <= 200)))
);


ALTER TABLE "public"."saved_vacancies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."share_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "name" "text" NOT NULL,
    "template" "text" NOT NULL,
    "item_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "brief_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "headline" "text",
    "includes_email" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "file_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "summary" "text",
    "duration_days" integer,
    "hidden_file_ids" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "share_profiles_brief_ids_check" CHECK (("cardinality"("brief_ids") <= 100)),
    CONSTRAINT "share_profiles_duration_days_check" CHECK ((("duration_days" IS NULL) OR ("duration_days" = ANY (ARRAY[1, 7, 14, 30, 90])))),
    CONSTRAINT "share_profiles_file_ids_check" CHECK (("cardinality"("file_ids") <= 100)),
    CONSTRAINT "share_profiles_headline_check" CHECK ((("headline" IS NULL) OR ("length"("headline") <= 120))),
    CONSTRAINT "share_profiles_hidden_file_ids_check" CHECK (("cardinality"("hidden_file_ids") <= 400)),
    CONSTRAINT "share_profiles_item_ids_check" CHECK (("cardinality"("item_ids") <= 100)),
    CONSTRAINT "share_profiles_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 80))),
    CONSTRAINT "share_profiles_summary_check" CHECK ((("summary" IS NULL) OR ("length"("summary") <= 400))),
    CONSTRAINT "share_profiles_template_check" CHECK (("template" = ANY (ARRAY['employer'::"text", 'education'::"text", 'municipality'::"text", 'fair'::"text"])))
);


ALTER TABLE "public"."share_profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."share_profiles"."file_ids" IS 'Evidence of this selection whose files the recipient may open.';



COMMENT ON COLUMN "public"."share_profiles"."summary" IS 'A few sentences about the owner, shown on top of what is shared.';



COMMENT ON COLUMN "public"."share_profiles"."duration_days" IS 'How long a share of this selection lasts; null keeps the default of its template.';



CREATE TABLE IF NOT EXISTS "public"."user_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "recipient_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text",
    "conversation_id" "uuid",
    "validation_request_id" "uuid",
    "vault_item_id" "uuid",
    "dedupe_key" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "read_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "user_notifications_body_check" CHECK ((("body" IS NULL) OR ("length"("body") <= 500))),
    CONSTRAINT "user_notifications_check" CHECK (((("kind" = 'conversation'::"text") AND ("conversation_id" IS NOT NULL) AND ("validation_request_id" IS NULL) AND ("vault_item_id" IS NULL)) OR (("kind" = ANY (ARRAY['evidence_verified'::"text", 'evidence_rejected'::"text"])) AND ("conversation_id" IS NULL) AND ("validation_request_id" IS NOT NULL) AND ("vault_item_id" IS NOT NULL)) OR (("kind" = 'verification_request'::"text") AND ("conversation_id" IS NULL) AND ("validation_request_id" IS NOT NULL) AND ("vault_item_id" IS NULL)))),
    CONSTRAINT "user_notifications_dedupe_key_check" CHECK ((("length"("btrim"("dedupe_key")) >= 1) AND ("length"("btrim"("dedupe_key")) <= 200))),
    CONSTRAINT "user_notifications_kind_check" CHECK (("kind" = ANY (ARRAY['conversation'::"text", 'evidence_verified'::"text", 'evidence_rejected'::"text", 'verification_request'::"text"]))),
    CONSTRAINT "user_notifications_title_check" CHECK ((("length"("btrim"("title")) >= 1) AND ("length"("btrim"("title")) <= 160)))
);


ALTER TABLE "public"."user_notifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_notifications" IS 'Private inbox per account. Server code writes rows; the owner may read them, mark them read, and delete them (deleted_at), restorable for 7 days.';



CREATE TABLE IF NOT EXISTS "public"."vault_category_folders" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "category" "text" NOT NULL,
    "name" "text",
    "color" "text",
    "icon" "text",
    "is_hidden" boolean DEFAULT false NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "vault_category_folders_category_check" CHECK (("category" = ANY (ARRAY['diplomas'::"text", 'certificates'::"text", 'badges'::"text", 'projects'::"text", 'workExperience'::"text", 'internships'::"text", 'skills'::"text", 'feedback'::"text", 'reflections'::"text", 'other'::"text"]))),
    CONSTRAINT "vault_category_folders_color_check" CHECK ((("color" IS NULL) OR ("color" = ANY (ARRAY['green'::"text", 'blue'::"text", 'purple'::"text", 'rust'::"text", 'rose'::"text", 'slate'::"text"])))),
    CONSTRAINT "vault_category_folders_icon_check" CHECK ((("icon" IS NULL) OR ("icon" = ANY (ARRAY['folder'::"text", 'briefcase'::"text", 'academic-cap'::"text", 'check-badge'::"text", 'wrench-screwdriver'::"text", 'chat-bubble-left-ellipsis'::"text", 'star'::"text", 'heart'::"text", 'code-bracket'::"text", 'light-bulb'::"text", 'rocket-launch'::"text", 'globe-europe-africa'::"text", 'paint-brush'::"text", 'document-text'::"text", 'user-group'::"text", 'trophy'::"text"])))),
    CONSTRAINT "vault_category_folders_name_check" CHECK ((("name" IS NULL) OR (("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 100))))
);


ALTER TABLE "public"."vault_category_folders" OWNER TO "postgres";


COMMENT ON TABLE "public"."vault_category_folders" IS 'How each category folder at the top of the vault looks for one account: its own name, colour and icon, or hidden.';



CREATE TABLE IF NOT EXISTS "public"."vault_folders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "color" "text",
    "icon" "text",
    "position" integer,
    "pinned_at" timestamp with time zone,
    CONSTRAINT "vault_folders_color_check" CHECK ((("color" IS NULL) OR ("color" = ANY (ARRAY['green'::"text", 'blue'::"text", 'gold'::"text", 'rose'::"text", 'rust'::"text", 'purple'::"text", 'red'::"text", 'lime'::"text", 'slate'::"text"])) OR ("color" ~ '^#[0-9a-f]{6}$'::"text"))),
    CONSTRAINT "vault_folders_icon_check" CHECK ((("icon" IS NULL) OR ("icon" = ANY (ARRAY['folder'::"text", 'briefcase'::"text", 'academic-cap'::"text", 'check-badge'::"text", 'wrench-screwdriver'::"text", 'chat-bubble-left-ellipsis'::"text", 'star'::"text", 'heart'::"text", 'code-bracket'::"text", 'light-bulb'::"text", 'rocket-launch'::"text", 'globe-europe-africa'::"text", 'paint-brush'::"text", 'document-text'::"text", 'user-group'::"text", 'trophy'::"text"])))),
    CONSTRAINT "vault_folders_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 100))),
    CONSTRAINT "vault_folders_position_check" CHECK ((("position" IS NULL) OR ("position" >= 0)))
);


ALTER TABLE "public"."vault_folders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vault_item_files" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "item_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "file_name" "text" NOT NULL,
    "mime_type" "text" NOT NULL,
    "file_size_bytes" bigint NOT NULL,
    "checksum_sha256" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role" "text" DEFAULT 'document'::"text" NOT NULL,
    CONSTRAINT "vault_item_files_check" CHECK ((("split_part"("storage_path", '/'::"text", 1) = ("user_id")::"text") AND ("split_part"("storage_path", '/'::"text", 2) = ("item_id")::"text") AND ("split_part"("storage_path", '/'::"text", 3) <> ''::"text") AND ("split_part"("storage_path", '/'::"text", 4) = ''::"text") AND ("right"("storage_path", 1) <> '/'::"text"))),
    CONSTRAINT "vault_item_files_checksum_sha256_check" CHECK ((("checksum_sha256" IS NULL) OR ("checksum_sha256" ~ '^[0-9a-fA-F]{64}$'::"text"))),
    CONSTRAINT "vault_item_files_cover_is_image" CHECK ((("role" = 'document'::"text") OR ("mime_type" = ANY (ARRAY['image/heic'::"text", 'image/jpeg'::"text", 'image/png'::"text"])))),
    CONSTRAINT "vault_item_files_file_name_check" CHECK ((("length"("btrim"("file_name")) >= 1) AND ("length"("btrim"("file_name")) <= 255))),
    CONSTRAINT "vault_item_files_file_size_bytes_check" CHECK ((("file_size_bytes" >= 1) AND ("file_size_bytes" <= 20971520))),
    CONSTRAINT "vault_item_files_mime_type_check" CHECK (("mime_type" = ANY (ARRAY['application/pdf'::"text", 'application/msword'::"text", 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'::"text", 'image/heic'::"text", 'image/jpeg'::"text", 'image/png'::"text", 'text/plain'::"text"]))),
    CONSTRAINT "vault_item_files_role_check" CHECK (("role" = ANY (ARRAY['document'::"text", 'cover'::"text", 'logo'::"text"])))
);


ALTER TABLE "public"."vault_item_files" OWNER TO "postgres";


COMMENT ON TABLE "public"."vault_item_files" IS 'Private file metadata. File contents live in the non-public pave-vault Storage bucket; extracted text is not stored here.';



COMMENT ON COLUMN "public"."vault_item_files"."role" IS 'document: the evidence itself. logo: the image in the round avatar on the vault card. cover: the image in the band above it. At most one logo and one cover per item; both are images.';



CREATE TABLE IF NOT EXISTS "public"."vault_item_folders" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "item_id" "uuid" NOT NULL,
    "folder_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."vault_item_folders" OWNER TO "postgres";


COMMENT ON TABLE "public"."vault_item_folders" IS 'Which folders an item is in; an item can be in several. vault_items.folder_id keeps the first for older clients.';



CREATE TABLE IF NOT EXISTS "public"."vault_item_skills" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "item_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "source" "text" DEFAULT 'user'::"text" NOT NULL,
    "status" "text" DEFAULT 'accepted'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "vault_item_skills_name_check" CHECK ((("length"("btrim"("name")) >= 1) AND ("length"("btrim"("name")) <= 120))),
    CONSTRAINT "vault_item_skills_source_check" CHECK (("source" = ANY (ARRAY['user'::"text", 'ayla'::"text", 'organization'::"text", 'import'::"text"]))),
    CONSTRAINT "vault_item_skills_status_check" CHECK (("status" = ANY (ARRAY['proposed'::"text", 'accepted'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."vault_item_skills" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vault_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "folder_id" "uuid",
    "category" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "organisation_name" "text",
    "organisation_location" "text",
    "start_date" "date",
    "end_date" "date",
    "issued_on" "date",
    "is_current" boolean DEFAULT false NOT NULL,
    "verification_status" "text" DEFAULT 'toVerify'::"text" NOT NULL,
    "source" "text" DEFAULT 'user'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "organization_id" "uuid",
    "ayla_allowed_at" timestamp with time zone,
    "position" integer,
    "archived_at" timestamp with time zone,
    CONSTRAINT "vault_items_category_check" CHECK (("category" = ANY (ARRAY['diplomas'::"text", 'certificates'::"text", 'badges'::"text", 'projects'::"text", 'workExperience'::"text", 'internships'::"text", 'skills'::"text", 'feedback'::"text", 'reflections'::"text", 'other'::"text"]))),
    CONSTRAINT "vault_items_check" CHECK ((("end_date" IS NULL) OR ("start_date" IS NULL) OR ("end_date" >= "start_date"))),
    CONSTRAINT "vault_items_check1" CHECK (((NOT "is_current") OR ("end_date" IS NULL))),
    CONSTRAINT "vault_items_description_check" CHECK ((("description" IS NULL) OR ("length"("description") <= 10000))),
    CONSTRAINT "vault_items_organisation_location_check" CHECK ((("organisation_location" IS NULL) OR ("length"("organisation_location") <= 200))),
    CONSTRAINT "vault_items_organisation_name_check" CHECK ((("organisation_name" IS NULL) OR ("length"("organisation_name") <= 200))),
    CONSTRAINT "vault_items_position_check" CHECK ((("position" IS NULL) OR ("position" >= 0))),
    CONSTRAINT "vault_items_source_check" CHECK (("source" = ANY (ARRAY['user'::"text", 'organization'::"text", 'ayla'::"text", 'import'::"text"]))),
    CONSTRAINT "vault_items_title_check" CHECK ((("length"("btrim"("title")) >= 1) AND ("length"("btrim"("title")) <= 200))),
    CONSTRAINT "vault_items_verification_status_check" CHECK (("verification_status" = ANY (ARRAY['toVerify'::"text", 'verified'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."vault_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."vault_items" IS 'The account-owned evidence records in the PAVE vault. Only trusted server code may confirm, reject, set the source or link an organisation. Changing a confirmed item or its files sets it back to toVerify, so it is confirmed again.';



COMMENT ON COLUMN "public"."vault_items"."ayla_allowed_at" IS 'When the user allowed Ayla to read this item and its files; null means not allowed.';



COMMENT ON COLUMN "public"."vault_items"."archived_at" IS 'Archived: out of the vault, kept until it is put back or deleted. Not shared, and only used by Ayla when the account allows it.';



CREATE TABLE IF NOT EXISTS "public"."vault_validation_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "item_id" "uuid" NOT NULL,
    "organisation_name" "text" NOT NULL,
    "message" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved_at" timestamp with time zone,
    "response" "text",
    "organization_id" "uuid",
    "resolved_by" "uuid",
    "location_id" "uuid",
    "department_id" "uuid",
    "contact_id" "uuid",
    CONSTRAINT "vault_validation_requests_check" CHECK (((("status" = 'pending'::"text") AND ("resolved_at" IS NULL)) OR (("status" <> 'pending'::"text") AND ("resolved_at" IS NOT NULL)))),
    CONSTRAINT "vault_validation_requests_message_check" CHECK ((("message" IS NULL) OR ("length"("message") <= 2000))),
    CONSTRAINT "vault_validation_requests_organisation_name_check" CHECK ((("length"("btrim"("organisation_name")) >= 1) AND ("length"("btrim"("organisation_name")) <= 200))),
    CONSTRAINT "vault_validation_requests_response_check" CHECK ((("response" IS NULL) OR ("length"("response") <= 2000))),
    CONSTRAINT "vault_validation_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'verified'::"text", 'rejected'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."vault_validation_requests" OWNER TO "postgres";


COMMENT ON TABLE "public"."vault_validation_requests" IS 'Requests to confirm vault evidence. Created and decided only by the vault-review Edge Function; the row is the history.';



COMMENT ON COLUMN "public"."vault_validation_requests"."organisation_name" IS 'The organisation''s name when the request was sent: learners cannot read organizations, so they read it here.';



ALTER TABLE ONLY "public"."application_drafts"
    ADD CONSTRAINT "application_drafts_pkey" PRIMARY KEY ("user_id", "id");



ALTER TABLE ONLY "public"."ayla_chat_pins"
    ADD CONSTRAINT "ayla_chat_pins_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."ayla_conversations"
    ADD CONSTRAINT "ayla_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ayla_locked_chats"
    ADD CONSTRAINT "ayla_locked_chats_pkey" PRIMARY KEY ("conversation_id");



ALTER TABLE ONLY "public"."ayla_memories"
    ADD CONSTRAINT "ayla_memories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ayla_messages"
    ADD CONSTRAINT "ayla_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ayla_open_chats"
    ADD CONSTRAINT "ayla_open_chats_pkey" PRIMARY KEY ("user_id", "device");



ALTER TABLE ONLY "public"."ayla_project_sources"
    ADD CONSTRAINT "ayla_project_sources_pkey" PRIMARY KEY ("user_id", "project_id", "item_id");



ALTER TABLE ONLY "public"."ayla_projects"
    ADD CONSTRAINT "ayla_projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ayla_settings"
    ADD CONSTRAINT "ayla_settings_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."fair_applications"
    ADD CONSTRAINT "fair_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fair_applications"
    ADD CONSTRAINT "fair_applications_user_id_employer_slug_vacancy_id_key" UNIQUE ("user_id", "employer_slug", "vacancy_id");



ALTER TABLE ONLY "public"."fair_employer_keys"
    ADD CONSTRAINT "fair_employer_keys_pkey" PRIMARY KEY ("employer_slug");



ALTER TABLE ONLY "public"."fair_employers"
    ADD CONSTRAINT "fair_employers_pkey" PRIMARY KEY ("slug");



ALTER TABLE ONLY "public"."organization_contact_evidence_types"
    ADD CONSTRAINT "organization_contact_evidence_types_pkey" PRIMARY KEY ("contact_id", "category");



ALTER TABLE ONLY "public"."organization_contacts"
    ADD CONSTRAINT "organization_contacts_department_name" UNIQUE ("department_id", "name");



ALTER TABLE ONLY "public"."organization_contacts"
    ADD CONSTRAINT "organization_contacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_departments"
    ADD CONSTRAINT "organization_departments_location_name" UNIQUE ("location_id", "name");



ALTER TABLE ONLY "public"."organization_departments"
    ADD CONSTRAINT "organization_departments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_kind_evidence_types"
    ADD CONSTRAINT "organization_kind_evidence_types_pkey" PRIMARY KEY ("kind", "category");



ALTER TABLE ONLY "public"."organization_locations"
    ADD CONSTRAINT "organization_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_locations"
    ADD CONSTRAINT "organization_locations_place" UNIQUE NULLS NOT DISTINCT ("organization_id", "city", "name");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plan_steps"
    ADD CONSTRAINT "plan_steps_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_share_views"
    ADD CONSTRAINT "profile_share_views_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_shares"
    ADD CONSTRAINT "profile_shares_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."profile_shares"
    ADD CONSTRAINT "profile_shares_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saved_vacancies"
    ADD CONSTRAINT "saved_vacancies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saved_vacancies"
    ADD CONSTRAINT "saved_vacancies_user_id_vacancy_id_key" UNIQUE ("user_id", "vacancy_id");



ALTER TABLE ONLY "public"."share_profiles"
    ADD CONSTRAINT "share_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_recipient_id_dedupe_key_key" UNIQUE ("recipient_id", "dedupe_key");



ALTER TABLE ONLY "public"."vault_category_folders"
    ADD CONSTRAINT "vault_category_folders_pkey" PRIMARY KEY ("user_id", "category");



ALTER TABLE ONLY "public"."vault_folders"
    ADD CONSTRAINT "vault_folders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vault_folders"
    ADD CONSTRAINT "vault_folders_user_id_id_key" UNIQUE ("user_id", "id");



ALTER TABLE ONLY "public"."vault_item_files"
    ADD CONSTRAINT "vault_item_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vault_item_files"
    ADD CONSTRAINT "vault_item_files_storage_path_key" UNIQUE ("storage_path");



ALTER TABLE ONLY "public"."vault_item_folders"
    ADD CONSTRAINT "vault_item_folders_pkey" PRIMARY KEY ("item_id", "folder_id");



ALTER TABLE ONLY "public"."vault_item_skills"
    ADD CONSTRAINT "vault_item_skills_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_user_id_id_key" UNIQUE ("user_id", "id");



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_pkey" PRIMARY KEY ("id");



CREATE INDEX "ayla_conversations_archived" ON "public"."ayla_conversations" USING "btree" ("user_id", "archived_at" DESC) WHERE ("archived_at" IS NOT NULL);



CREATE INDEX "ayla_conversations_plan" ON "public"."ayla_conversations" USING "btree" ("plan_id") WHERE ("plan_id" IS NOT NULL);



CREATE INDEX "ayla_conversations_project" ON "public"."ayla_conversations" USING "btree" ("project_id") WHERE ("project_id" IS NOT NULL);



CREATE UNIQUE INDEX "ayla_conversations_user_id_id" ON "public"."ayla_conversations" USING "btree" ("user_id", "id");



CREATE INDEX "ayla_conversations_user_updated" ON "public"."ayla_conversations" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "ayla_memories_user_created" ON "public"."ayla_memories" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "ayla_messages_conversation_created" ON "public"."ayla_messages" USING "btree" ("conversation_id", "created_at");



CREATE INDEX "ayla_open_chats_conversation" ON "public"."ayla_open_chats" USING "btree" ("conversation_id", "seen_at" DESC);



CREATE INDEX "ayla_project_sources_project" ON "public"."ayla_project_sources" USING "btree" ("project_id");



CREATE UNIQUE INDEX "ayla_projects_user_id_id" ON "public"."ayla_projects" USING "btree" ("user_id", "id");



CREATE INDEX "ayla_projects_user_updated" ON "public"."ayla_projects" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "fair_applications_employer" ON "public"."fair_applications" USING "btree" ("employer_slug", "created_at" DESC);



CREATE INDEX "organization_contact_evidence_types_category" ON "public"."organization_contact_evidence_types" USING "btree" ("category", "contact_id");



CREATE INDEX "organization_contacts_department" ON "public"."organization_contacts" USING "btree" ("department_id");



CREATE INDEX "organization_contacts_name_trgm" ON "public"."organization_contacts" USING "gin" ("name" "extensions"."gin_trgm_ops");



CREATE INDEX "organization_contacts_reviewer_id" ON "public"."organization_contacts" USING "btree" ("reviewer_id") WHERE ("reviewer_id" IS NOT NULL);



CREATE INDEX "organization_departments_location" ON "public"."organization_departments" USING "btree" ("location_id");



CREATE INDEX "organization_locations_organization" ON "public"."organization_locations" USING "btree" ("organization_id");



CREATE INDEX "organizations_name_trgm" ON "public"."organizations" USING "gin" ("name" "extensions"."gin_trgm_ops") WHERE ("kind" IS NOT NULL);



CREATE UNIQUE INDEX "organizations_registry_unique" ON "public"."organizations" USING "btree" ("registry_type", "registry_id") WHERE ("registry_id" IS NOT NULL);



CREATE UNIQUE INDEX "plan_steps_one_active" ON "public"."plan_steps" USING "btree" ("plan_id") WHERE ("status" = 'active'::"text");



CREATE INDEX "plan_steps_plan_position" ON "public"."plan_steps" USING "btree" ("plan_id", "position");



CREATE INDEX "plans_user_updated" ON "public"."plans" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "profile_share_views_share" ON "public"."profile_share_views" USING "btree" ("share_id", "viewed_at" DESC);



CREATE INDEX "profile_shares_user" ON "public"."profile_shares" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "profiles_organization_id_idx" ON "public"."profiles" USING "btree" ("organization_id");



CREATE INDEX "saved_vacancies_user_saved" ON "public"."saved_vacancies" USING "btree" ("user_id", "saved_at" DESC);



CREATE INDEX "share_profiles_user" ON "public"."share_profiles" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "user_notifications_deleted" ON "public"."user_notifications" USING "btree" ("deleted_at") WHERE ("deleted_at" IS NOT NULL);



CREATE INDEX "user_notifications_inbox" ON "public"."user_notifications" USING "btree" ("recipient_id", "created_at" DESC);



CREATE INDEX "user_notifications_unread" ON "public"."user_notifications" USING "btree" ("recipient_id", "created_at" DESC) WHERE ("read_at" IS NULL);



CREATE UNIQUE INDEX "vault_folders_user_name" ON "public"."vault_folders" USING "btree" ("user_id", "lower"("name"));



CREATE INDEX "vault_folders_user_position" ON "public"."vault_folders" USING "btree" ("user_id", "position");



CREATE INDEX "vault_folders_user_updated" ON "public"."vault_folders" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "vault_item_files_item" ON "public"."vault_item_files" USING "btree" ("user_id", "item_id", "created_at");



CREATE UNIQUE INDEX "vault_item_files_one_cover" ON "public"."vault_item_files" USING "btree" ("user_id", "item_id") WHERE ("role" = 'cover'::"text");



CREATE UNIQUE INDEX "vault_item_files_one_logo" ON "public"."vault_item_files" USING "btree" ("user_id", "item_id") WHERE ("role" = 'logo'::"text");



CREATE INDEX "vault_item_folders_folder" ON "public"."vault_item_folders" USING "btree" ("user_id", "folder_id");



CREATE INDEX "vault_item_skills_item" ON "public"."vault_item_skills" USING "btree" ("user_id", "item_id", "status");



CREATE UNIQUE INDEX "vault_item_skills_item_name" ON "public"."vault_item_skills" USING "btree" ("user_id", "item_id", "lower"("name"));



CREATE INDEX "vault_items_archived" ON "public"."vault_items" USING "btree" ("user_id", "archived_at" DESC) WHERE ("archived_at" IS NOT NULL);



CREATE INDEX "vault_items_ayla_allowed" ON "public"."vault_items" USING "btree" ("user_id") WHERE ("ayla_allowed_at" IS NOT NULL);



CREATE INDEX "vault_items_folder" ON "public"."vault_items" USING "btree" ("user_id", "folder_id") WHERE ("folder_id" IS NOT NULL);



CREATE INDEX "vault_items_organization" ON "public"."vault_items" USING "btree" ("organization_id") WHERE ("organization_id" IS NOT NULL);



CREATE INDEX "vault_items_user_category" ON "public"."vault_items" USING "btree" ("user_id", "category", "updated_at" DESC);



CREATE INDEX "vault_items_user_position" ON "public"."vault_items" USING "btree" ("user_id", "position");



CREATE INDEX "vault_items_user_status" ON "public"."vault_items" USING "btree" ("user_id", "verification_status", "updated_at" DESC);



CREATE INDEX "vault_items_user_updated" ON "public"."vault_items" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "vault_validation_requests_item" ON "public"."vault_validation_requests" USING "btree" ("user_id", "item_id", "requested_at" DESC);



CREATE UNIQUE INDEX "vault_validation_requests_one_pending_per_org" ON "public"."vault_validation_requests" USING "btree" ("user_id", "item_id", "organization_id") WHERE (("status" = 'pending'::"text") AND ("organization_id" IS NOT NULL));



CREATE INDEX "vault_validation_requests_organization_pending" ON "public"."vault_validation_requests" USING "btree" ("organization_id", "requested_at" DESC) WHERE (("status" = 'pending'::"text") AND ("organization_id" IS NOT NULL));



CREATE INDEX "vault_validation_requests_user_contact" ON "public"."vault_validation_requests" USING "btree" ("user_id", "requested_at" DESC) WHERE ("contact_id" IS NOT NULL);



CREATE INDEX "vault_validation_requests_user_status" ON "public"."vault_validation_requests" USING "btree" ("user_id", "status", "requested_at" DESC);



CREATE OR REPLACE TRIGGER "ayla_conversations_plan_guard" BEFORE INSERT OR UPDATE OF "plan_id", "plan_step_id" ON "public"."ayla_conversations" FOR EACH ROW EXECUTE FUNCTION "public"."guard_conversation_plan"();



CREATE OR REPLACE TRIGGER "ayla_memories_sync_categories" BEFORE INSERT OR UPDATE ON "public"."ayla_memories" FOR EACH ROW EXECUTE FUNCTION "public"."sync_ayla_memory_categories"();



CREATE OR REPLACE TRIGGER "ayla_message_notification" AFTER INSERT ON "public"."ayla_messages" FOR EACH ROW EXECUTE FUNCTION "public"."notify_on_ayla_reply"();



CREATE OR REPLACE TRIGGER "fair_applications_guard" BEFORE UPDATE ON "public"."fair_applications" FOR EACH ROW EXECUTE FUNCTION "public"."fair_applications_guard"();



CREATE OR REPLACE TRIGGER "guard_profile_self_update" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."guard_profile_self_update"();



CREATE OR REPLACE TRIGGER "organization_contacts_default_evidence_types" AFTER INSERT ON "public"."organization_contacts" FOR EACH ROW EXECUTE FUNCTION "public"."organization_contacts_default_evidence_types"();



CREATE OR REPLACE TRIGGER "profile_shares_guard" BEFORE UPDATE ON "public"."profile_shares" FOR EACH ROW EXECUTE FUNCTION "public"."profile_shares_guard"();



CREATE OR REPLACE TRIGGER "profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "share_profiles_touch" BEFORE UPDATE ON "public"."share_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."share_profiles_touch"();



CREATE OR REPLACE TRIGGER "user_notifications_guard_update" BEFORE UPDATE ON "public"."user_notifications" FOR EACH ROW EXECUTE FUNCTION "public"."guard_user_notification_update"();



CREATE OR REPLACE TRIGGER "vault_folders_set_updated_at" BEFORE UPDATE ON "public"."vault_folders" FOR EACH ROW EXECUTE FUNCTION "public"."set_vault_updated_at"();



CREATE OR REPLACE TRIGGER "vault_item_files_reverify" AFTER INSERT OR DELETE ON "public"."vault_item_files" FOR EACH ROW EXECUTE FUNCTION "public"."reverify_vault_item_after_file_change"();



CREATE OR REPLACE TRIGGER "vault_item_skills_guard_authority" BEFORE INSERT OR UPDATE ON "public"."vault_item_skills" FOR EACH ROW EXECUTE FUNCTION "public"."guard_vault_item_skill_authority"();



CREATE OR REPLACE TRIGGER "vault_item_skills_set_updated_at" BEFORE UPDATE ON "public"."vault_item_skills" FOR EACH ROW EXECUTE FUNCTION "public"."set_vault_updated_at"();



CREATE OR REPLACE TRIGGER "vault_items_guard_authority" BEFORE INSERT OR UPDATE ON "public"."vault_items" FOR EACH ROW EXECUTE FUNCTION "public"."guard_vault_item_authority"();



CREATE OR REPLACE TRIGGER "vault_items_set_updated_at" BEFORE UPDATE ON "public"."vault_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_vault_updated_at"();



ALTER TABLE ONLY "public"."application_drafts"
    ADD CONSTRAINT "application_drafts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_chat_pins"
    ADD CONSTRAINT "ayla_chat_pins_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_conversations"
    ADD CONSTRAINT "ayla_conversations_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ayla_conversations"
    ADD CONSTRAINT "ayla_conversations_plan_step_id_fkey" FOREIGN KEY ("plan_step_id") REFERENCES "public"."plan_steps"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ayla_conversations"
    ADD CONSTRAINT "ayla_conversations_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."ayla_projects"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ayla_conversations"
    ADD CONSTRAINT "ayla_conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_locked_chats"
    ADD CONSTRAINT "ayla_locked_chats_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."ayla_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_locked_chats"
    ADD CONSTRAINT "ayla_locked_chats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_memories"
    ADD CONSTRAINT "ayla_memories_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."ayla_conversations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ayla_memories"
    ADD CONSTRAINT "ayla_memories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_messages"
    ADD CONSTRAINT "ayla_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."ayla_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_messages"
    ADD CONSTRAINT "ayla_messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_open_chats"
    ADD CONSTRAINT "ayla_open_chats_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."ayla_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_open_chats"
    ADD CONSTRAINT "ayla_open_chats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_project_sources"
    ADD CONSTRAINT "ayla_project_sources_user_id_item_id_fkey" FOREIGN KEY ("user_id", "item_id") REFERENCES "public"."vault_items"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_project_sources"
    ADD CONSTRAINT "ayla_project_sources_user_id_project_id_fkey" FOREIGN KEY ("user_id", "project_id") REFERENCES "public"."ayla_projects"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_projects"
    ADD CONSTRAINT "ayla_projects_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ayla_settings"
    ADD CONSTRAINT "ayla_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fair_applications"
    ADD CONSTRAINT "fair_applications_employer_slug_fkey" FOREIGN KEY ("employer_slug") REFERENCES "public"."fair_employers"("slug") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fair_applications"
    ADD CONSTRAINT "fair_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fair_employer_keys"
    ADD CONSTRAINT "fair_employer_keys_employer_slug_fkey" FOREIGN KEY ("employer_slug") REFERENCES "public"."fair_employers"("slug") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_contact_evidence_types"
    ADD CONSTRAINT "organization_contact_evidence_types_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."organization_contacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_contacts"
    ADD CONSTRAINT "organization_contacts_account" FOREIGN KEY ("reviewer_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."organization_contacts"
    ADD CONSTRAINT "organization_contacts_department" FOREIGN KEY ("department_id") REFERENCES "public"."organization_departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_departments"
    ADD CONSTRAINT "organization_departments_location" FOREIGN KEY ("location_id") REFERENCES "public"."organization_locations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_locations"
    ADD CONSTRAINT "organization_locations_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_steps"
    ADD CONSTRAINT "plan_steps_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plan_steps"
    ADD CONSTRAINT "plan_steps_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_share_views"
    ADD CONSTRAINT "profile_share_views_share_id_fkey" FOREIGN KEY ("share_id") REFERENCES "public"."profile_shares"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_shares"
    ADD CONSTRAINT "profile_shares_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."saved_vacancies"
    ADD CONSTRAINT "saved_vacancies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."share_profiles"
    ADD CONSTRAINT "share_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."ayla_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_validation_request_id_fkey" FOREIGN KEY ("validation_request_id") REFERENCES "public"."vault_validation_requests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_vault_item_id_fkey" FOREIGN KEY ("vault_item_id") REFERENCES "public"."vault_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_category_folders"
    ADD CONSTRAINT "vault_category_folders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_folders"
    ADD CONSTRAINT "vault_folders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_files"
    ADD CONSTRAINT "vault_item_files_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_files"
    ADD CONSTRAINT "vault_item_files_user_id_item_id_fkey" FOREIGN KEY ("user_id", "item_id") REFERENCES "public"."vault_items"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_folders"
    ADD CONSTRAINT "vault_item_folders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_folders"
    ADD CONSTRAINT "vault_item_folders_user_id_folder_id_fkey" FOREIGN KEY ("user_id", "folder_id") REFERENCES "public"."vault_folders"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_folders"
    ADD CONSTRAINT "vault_item_folders_user_id_item_id_fkey" FOREIGN KEY ("user_id", "item_id") REFERENCES "public"."vault_items"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_skills"
    ADD CONSTRAINT "vault_item_skills_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_item_skills"
    ADD CONSTRAINT "vault_item_skills_user_id_item_id_fkey" FOREIGN KEY ("user_id", "item_id") REFERENCES "public"."vault_items"("user_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_items"
    ADD CONSTRAINT "vault_items_user_id_folder_id_fkey" FOREIGN KEY ("user_id", "folder_id") REFERENCES "public"."vault_folders"("user_id", "id") ON DELETE SET NULL ("folder_id");



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."organization_contacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."organization_departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."organization_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vault_validation_requests"
    ADD CONSTRAINT "vault_validation_requests_user_id_item_id_fkey" FOREIGN KEY ("user_id", "item_id") REFERENCES "public"."vault_items"("user_id", "id") ON DELETE CASCADE;



CREATE POLICY "Add messages to own conversations" ON "public"."ayla_messages" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (EXISTS ( SELECT 1
   FROM "public"."ayla_conversations" "c"
  WHERE (("c"."id" = "ayla_messages"."conversation_id") AND ("c"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Delete own messages" ON "public"."ayla_messages" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Everyone reads the fair" ON "public"."fair_employers" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Mark own notifications read or deleted" ON "public"."user_notifications" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "recipient_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "recipient_id"));



CREATE POLICY "Organizations: members read own" ON "public"."organizations" FOR SELECT TO "authenticated" USING (((( SELECT ("auth"."jwt"() ->> 'aal'::"text")) = 'aal2'::"text") AND ("id" = "public"."current_organization_id"())));



CREATE POLICY "Own application drafts" ON "public"."application_drafts" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own applications" ON "public"."fair_applications" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own conversations" ON "public"."ayla_conversations" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own locked chats" ON "public"."ayla_locked_chats" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (EXISTS ( SELECT 1
   FROM "public"."ayla_conversations" "c"
  WHERE (("c"."id" = "ayla_locked_chats"."conversation_id") AND ("c"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Own memories" ON "public"."ayla_memories" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own open chats" ON "public"."ayla_open_chats" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own plan steps" ON "public"."plan_steps" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (EXISTS ( SELECT 1
   FROM "public"."plans" "p"
  WHERE (("p"."id" = "plan_steps"."plan_id") AND ("p"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Own plans" ON "public"."plans" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own profiles" ON "public"."share_profiles" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own project sources" ON "public"."ayla_project_sources" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own projects" ON "public"."ayla_projects" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own saved vacancies" ON "public"."saved_vacancies" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own settings" ON "public"."ayla_settings" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own shares" ON "public"."profile_shares" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own vault category folders" ON "public"."vault_category_folders" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own vault folders" ON "public"."vault_folders" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own vault item files" ON "public"."vault_item_files" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own vault item folders" ON "public"."vault_item_folders" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own vault item skills" ON "public"."vault_item_skills" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Own vault items" ON "public"."vault_items" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Profile changes need two-step verification" ON "public"."profiles" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Profiles: admins read their organization" ON "public"."profiles" FOR SELECT TO "authenticated" USING (((( SELECT ("auth"."jwt"() ->> 'aal'::"text")) = 'aal2'::"text") AND "public"."is_organization_admin"("organization_id")));



CREATE POLICY "Read contacts with an account" ON "public"."organization_contacts" FOR SELECT TO "authenticated" USING (("is_active" AND ("reviewer_id" IS NOT NULL) AND ("reviewer_id" <> ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Read own messages" ON "public"."ayla_messages" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Read own notifications" ON "public"."user_notifications" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "recipient_id"));



CREATE POLICY "Read own validation requests" ON "public"."vault_validation_requests" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Read the directory" ON "public"."organization_departments" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Read the directory" ON "public"."organization_locations" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Require two-step verification" ON "public"."application_drafts" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_conversations" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_locked_chats" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_memories" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_messages" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_open_chats" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_project_sources" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_projects" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."ayla_settings" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."fair_applications" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."organization_contacts" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."organization_departments" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."organization_locations" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."plan_steps" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."plans" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."profile_share_views" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."profile_shares" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."saved_vacancies" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."share_profiles" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."user_notifications" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_category_folders" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_folders" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_item_files" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_item_folders" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_item_skills" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_items" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Require two-step verification" ON "public"."vault_validation_requests" AS RESTRICTIVE TO "authenticated" USING ("public"."is_mfa_verified"()) WITH CHECK ("public"."is_mfa_verified"());



CREATE POLICY "Update own profile settings" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can create their own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK ((("id" = "auth"."uid"()) AND (("auth"."jwt"() ->> 'aal'::"text") = 'aal2'::"text")));



CREATE POLICY "Users can update their own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((("id" = "auth"."uid"()) AND (("auth"."jwt"() ->> 'aal'::"text") = 'aal2'::"text"))) WITH CHECK ((("id" = "auth"."uid"()) AND (("auth"."jwt"() ->> 'aal'::"text") = 'aal2'::"text")));



CREATE POLICY "Users can view their own profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) AND (("auth"."jwt"() ->> 'aal'::"text") = 'aal2'::"text")));



CREATE POLICY "Views of own shares" ON "public"."profile_share_views" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profile_shares" "s"
  WHERE (("s"."id" = "profile_share_views"."share_id") AND ("s"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."application_drafts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_chat_pins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_conversations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_locked_chats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_memories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_open_chats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_project_sources" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_projects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ayla_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fair_applications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fair_employer_keys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fair_employers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_contact_evidence_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_contacts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_departments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_kind_evidence_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plan_steps" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_share_views" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_shares" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."saved_vacancies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."share_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_category_folders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_folders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_item_files" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_item_folders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_item_skills" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vault_validation_requests" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_change_chat_pin"("pin" "text", "new_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_change_chat_pin"("pin" "text", "new_pin" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_change_chat_pin"("pin" "text", "new_pin" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_chat_pin_exists"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_chat_pin_exists"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_chat_pin_exists"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_check_chat_pin"("pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_check_chat_pin"("pin" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_check_chat_pin"("pin" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_delete_expired_chats"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_delete_expired_chats"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_expire_my_chats"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_expire_my_chats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_expire_my_chats"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_recover_chat_pin"("new_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_recover_chat_pin"("new_pin" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_recover_chat_pin"("new_pin" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_reset_chat_pin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_reset_chat_pin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_reset_chat_pin"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."ayla_set_chat_pin"("pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ayla_set_chat_pin"("pin" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ayla_set_chat_pin"("pin" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_example_vault_folders"("target" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_example_vault_folders"("target" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_example_vault_folders_for_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_example_vault_folders_for_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_example_vault_folders_for_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_profile_for_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_profile_for_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."current_organization_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_organization_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_organization_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."end_my_session"("target" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."end_my_session"("target" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."end_my_session"("target" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fair_applications_guard"() TO "anon";
GRANT ALL ON FUNCTION "public"."fair_applications_guard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fair_applications_guard"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."grant_default_evidence_types"("p_contact_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."grant_default_evidence_types"("p_contact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_conversation_plan"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_conversation_plan"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_conversation_plan"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_profile_self_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_profile_self_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_profile_self_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_user_notification_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_user_notification_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_user_notification_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_vault_item_authority"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_vault_item_authority"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_vault_item_authority"() TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_vault_item_skill_authority"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_vault_item_skill_authority"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_vault_item_skill_authority"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_mfa_verified"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_mfa_verified"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_mfa_verified"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_organization_admin"("target_organization" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_organization_admin"("target_organization" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_organization_admin"("target_organization" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_sessions"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_sessions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_sessions"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."normalize_plan"("p_plan_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."normalize_plan"("p_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_plan"("p_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_on_ayla_reply"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_on_ayla_reply"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_on_ayla_reply"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."organization_contacts_default_evidence_types"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."organization_contacts_default_evidence_types"() TO "service_role";



GRANT ALL ON FUNCTION "public"."profile_shares_guard"() TO "anon";
GRANT ALL ON FUNCTION "public"."profile_shares_guard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."profile_shares_guard"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_deleted_notifications"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_deleted_notifications"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."resolve_vault_validation_request"("p_request_id" "uuid", "p_action" "text", "p_response" "text", "p_actor_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resolve_vault_validation_request"("p_request_id" "uuid", "p_action" "text", "p_response" "text", "p_actor_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reverify_vault_item_after_file_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."reverify_vault_item_after_file_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reverify_vault_item_after_file_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."save_plan"("p_plan" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."save_plan"("p_plan" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_plan"("p_plan" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_open_chat"("p_device" "text", "p_conversation_id" "uuid", "p_open" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_open_chat"("p_device" "text", "p_conversation_id" "uuid", "p_open" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_open_chat"("p_device" "text", "p_conversation_id" "uuid", "p_open" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_plan_step_status"("p_step_id" "uuid", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."set_plan_step_status"("p_step_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_plan_step_status"("p_step_id" "uuid", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_vault_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_vault_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_vault_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."share_profiles_touch"() TO "anon";
GRANT ALL ON FUNCTION "public"."share_profiles_touch"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."share_profiles_touch"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_ayla_memory_categories"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_ayla_memory_categories"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_ayla_memory_categories"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_available_contacts"("p_category" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_available_contacts"("p_category" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_contact_filters"("p_organization_id" "uuid", "p_category" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_contact_filters"("p_organization_id" "uuid", "p_category" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_contact_filters"("p_organization_id" "uuid", "p_category" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."validation_matches"("p_text" "text", "p_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."validation_matches"("p_text" "text", "p_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_matches"("p_text" "text", "p_query" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_organizations"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_organizations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_organizations"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_organizations_by_id"("p_category" "text", "p_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_organizations_by_id"("p_category" "text", "p_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_organizations_by_id"("p_category" "text", "p_ids" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_places_by_id"("p_category" "text", "p_location_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_places_by_id"("p_category" "text", "p_location_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_places_by_id"("p_category" "text", "p_location_ids" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_previous_contacts"("p_category" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_previous_contacts"("p_category" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_previous_contacts"("p_category" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_search_contacts"("p_organization_id" "uuid", "p_category" "text", "p_query" "text", "p_location_id" "uuid", "p_department" "text", "p_function" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_search_contacts"("p_organization_id" "uuid", "p_category" "text", "p_query" "text", "p_location_id" "uuid", "p_department" "text", "p_function" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_search_contacts"("p_organization_id" "uuid", "p_category" "text", "p_query" "text", "p_location_id" "uuid", "p_department" "text", "p_function" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_search_organizations"("p_category" "text", "p_query" "text", "p_kind" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_search_organizations"("p_category" "text", "p_query" "text", "p_kind" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_search_organizations"("p_category" "text", "p_query" "text", "p_kind" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."validation_search_places"("p_category" "text", "p_query" "text", "p_kind" "text", "p_organization_id" "uuid", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validation_search_places"("p_category" "text", "p_query" "text", "p_kind" "text", "p_organization_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validation_search_places"("p_category" "text", "p_query" "text", "p_kind" "text", "p_organization_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."vault_validation_recipients"("p_request_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."vault_validation_recipients"("p_request_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."wipe_ended_shares"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."wipe_ended_shares"() TO "service_role";



GRANT ALL ON TABLE "public"."application_drafts" TO "anon";
GRANT ALL ON TABLE "public"."application_drafts" TO "authenticated";
GRANT ALL ON TABLE "public"."application_drafts" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_chat_pins" TO "anon";
GRANT ALL ON TABLE "public"."ayla_chat_pins" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_chat_pins" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_conversations" TO "anon";
GRANT ALL ON TABLE "public"."ayla_conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_conversations" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_locked_chats" TO "anon";
GRANT ALL ON TABLE "public"."ayla_locked_chats" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_locked_chats" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_memories" TO "anon";
GRANT ALL ON TABLE "public"."ayla_memories" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_memories" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_messages" TO "anon";
GRANT ALL ON TABLE "public"."ayla_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_messages" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_open_chats" TO "anon";
GRANT ALL ON TABLE "public"."ayla_open_chats" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_open_chats" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_project_sources" TO "anon";
GRANT ALL ON TABLE "public"."ayla_project_sources" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_project_sources" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_projects" TO "anon";
GRANT ALL ON TABLE "public"."ayla_projects" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_projects" TO "service_role";



GRANT ALL ON TABLE "public"."ayla_settings" TO "anon";
GRANT ALL ON TABLE "public"."ayla_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."ayla_settings" TO "service_role";



GRANT ALL ON TABLE "public"."fair_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."fair_applications" TO "service_role";



GRANT ALL ON TABLE "public"."fair_employer_keys" TO "service_role";



GRANT ALL ON TABLE "public"."fair_employers" TO "anon";
GRANT ALL ON TABLE "public"."fair_employers" TO "authenticated";
GRANT ALL ON TABLE "public"."fair_employers" TO "service_role";



GRANT ALL ON TABLE "public"."organization_contact_evidence_types" TO "service_role";



GRANT ALL ON TABLE "public"."organization_contacts" TO "service_role";



GRANT SELECT("id") ON TABLE "public"."organization_contacts" TO "authenticated";



GRANT SELECT("department_id") ON TABLE "public"."organization_contacts" TO "authenticated";



GRANT SELECT("name") ON TABLE "public"."organization_contacts" TO "authenticated";



GRANT SELECT("job_title") ON TABLE "public"."organization_contacts" TO "authenticated";



GRANT SELECT("is_active") ON TABLE "public"."organization_contacts" TO "authenticated";



GRANT SELECT("created_at") ON TABLE "public"."organization_contacts" TO "authenticated";



GRANT ALL ON TABLE "public"."organization_departments" TO "service_role";
GRANT SELECT ON TABLE "public"."organization_departments" TO "authenticated";



GRANT ALL ON TABLE "public"."organization_kind_evidence_types" TO "service_role";



GRANT ALL ON TABLE "public"."organization_locations" TO "service_role";
GRANT SELECT ON TABLE "public"."organization_locations" TO "authenticated";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."plan_steps" TO "anon";
GRANT ALL ON TABLE "public"."plan_steps" TO "authenticated";
GRANT ALL ON TABLE "public"."plan_steps" TO "service_role";



GRANT ALL ON TABLE "public"."plans" TO "anon";
GRANT ALL ON TABLE "public"."plans" TO "authenticated";
GRANT ALL ON TABLE "public"."plans" TO "service_role";



GRANT ALL ON TABLE "public"."profile_share_views" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_share_views" TO "service_role";



GRANT ALL ON TABLE "public"."profile_shares" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_shares" TO "service_role";



GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT INSERT("id") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("full_name"),UPDATE("full_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("email") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("avatar_url"),UPDATE("avatar_url") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("preferred_name"),UPDATE("preferred_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("education_level"),UPDATE("education_level") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("program"),UPDATE("program") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("expected_graduation"),UPDATE("expected_graduation") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("locale"),UPDATE("locale") ON TABLE "public"."profiles" TO "authenticated";



GRANT INSERT("onboarding_completed_at"),UPDATE("onboarding_completed_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("avatar_path") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("theme_color") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("text_size") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("vault_layout") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("theme_custom_color") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("display_mode") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("chat_expiry_days") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("chat_expiry_from") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("chat_expiry_keeps_pinned") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("chat_expiry_keeps_locked") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("ayla_uses_archive") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("language") ON TABLE "public"."profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."saved_vacancies" TO "authenticated";
GRANT ALL ON TABLE "public"."saved_vacancies" TO "service_role";



GRANT ALL ON TABLE "public"."share_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."share_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."user_notifications" TO "service_role";
GRANT SELECT,UPDATE ON TABLE "public"."user_notifications" TO "authenticated";



GRANT ALL ON TABLE "public"."vault_category_folders" TO "anon";
GRANT ALL ON TABLE "public"."vault_category_folders" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_category_folders" TO "service_role";



GRANT ALL ON TABLE "public"."vault_folders" TO "anon";
GRANT ALL ON TABLE "public"."vault_folders" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_folders" TO "service_role";



GRANT ALL ON TABLE "public"."vault_item_files" TO "anon";
GRANT ALL ON TABLE "public"."vault_item_files" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_item_files" TO "service_role";



GRANT ALL ON TABLE "public"."vault_item_folders" TO "anon";
GRANT ALL ON TABLE "public"."vault_item_folders" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_item_folders" TO "service_role";



GRANT ALL ON TABLE "public"."vault_item_skills" TO "anon";
GRANT ALL ON TABLE "public"."vault_item_skills" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_item_skills" TO "service_role";



GRANT ALL ON TABLE "public"."vault_items" TO "anon";
GRANT ALL ON TABLE "public"."vault_items" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_items" TO "service_role";



GRANT ALL ON TABLE "public"."vault_validation_requests" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vault_validation_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."vault_validation_requests" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







