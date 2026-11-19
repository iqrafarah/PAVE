-- Locked chats: one four-digit PIN per account protects every locked chat (web; see docs/ayla.md).
-- A locked chat leaves the recent list and the search, and opens only after the PIN. The PIN is stored hashed
-- (bcrypt) and only checked inside the database, with a short wait after five wrong tries. This hides chats; it does
-- not encrypt them.
-- Nothing existing changes. Not applied yet: agree with the team first, then run it in the SQL Editor.

create extension if not exists pgcrypto with schema extensions;

create table public.ayla_chat_pins (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  pin_hash text not null,
  failed_attempts int not null default 0,
  blocked_until timestamptz,
  created_at timestamptz not null default now()
);

-- No policies: the table is only reached through the functions below.
alter table public.ayla_chat_pins enable row level security;

create table public.ayla_locked_chats (
  conversation_id uuid primary key references public.ayla_conversations (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  locked_at timestamptz not null default now()
);

alter table public.ayla_locked_chats enable row level security;

create policy "Require two-step verification"
  on public.ayla_locked_chats as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Own locked chats"
  on public.ayla_locked_chats for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ayla_conversations c
      where c.id = conversation_id and c.user_id = (select auth.uid())
    )
  );

create function public.ayla_chat_pin_exists() returns boolean
language sql security definer set search_path = '' stable as $$
  select public.is_mfa_verified() and exists (select 1 from public.ayla_chat_pins where user_id = auth.uid());
$$;

create function public.ayla_set_chat_pin(pin text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_mfa_verified() then raise exception 'mfa_required'; end if;
  if pin !~ '^[0-9]{4}$' then raise exception 'invalid_pin'; end if;
  insert into public.ayla_chat_pins (user_id, pin_hash)
  values (auth.uid(), extensions.crypt(pin, extensions.gen_salt('bf', 10)));
exception when unique_violation then
  raise exception 'pin_exists';
end;
$$;

-- true when the PIN is right, false when it is wrong; raises 'too_many_attempts' during the wait.
create function public.ayla_check_chat_pin(pin text) returns boolean
language plpgsql security definer set search_path = '' as $$
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

-- "Pincode vergeten": the locked chats are deleted for good and the PIN is removed, so a new one can be made.
create function public.ayla_reset_chat_pin() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_mfa_verified() then raise exception 'mfa_required'; end if;
  delete from public.ayla_conversations
    where user_id = auth.uid()
    and id in (select conversation_id from public.ayla_locked_chats where user_id = auth.uid());
  delete from public.ayla_chat_pins where user_id = auth.uid();
end;
$$;

revoke all on function public.ayla_chat_pin_exists(), public.ayla_set_chat_pin(text), public.ayla_check_chat_pin(text), public.ayla_reset_chat_pin() from public, anon;
grant execute on function public.ayla_chat_pin_exists(), public.ayla_set_chat_pin(text), public.ayla_check_chat_pin(text), public.ayla_reset_chat_pin() to authenticated;
