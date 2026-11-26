-- No melding "Ayla heeft gereageerd" for a chat you are looking at: you already see her answer come in.
-- Each app says every ~20 seconds which chat is open on screen (one row per device) and lets go of it when you leave.
-- notify_on_ayla_reply (20261117180000) skips the melding when the chat was open on any device in the last 45 seconds.
-- Run after 20261117180000_organisations_verification_notifications.sql. Until this runs, every reply still gives a
-- melding and the app's calls fail quietly.

create table if not exists public.ayla_open_chats (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Chosen by the app ("ios-<uuid>", "web-<uuid>"), so a phone and a browser never take each other's place.
  device text not null check (length(device) between 1 and 80),
  conversation_id uuid not null references public.ayla_conversations (id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (user_id, device)
);

create index if not exists ayla_open_chats_conversation on public.ayla_open_chats (conversation_id, seen_at desc);

alter table public.ayla_open_chats enable row level security;

drop policy if exists "Require two-step verification" on public.ayla_open_chats;
create policy "Require two-step verification"
  on public.ayla_open_chats as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own open chats" on public.ayla_open_chats;
create policy "Own open chats"
  on public.ayla_open_chats for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- The app calls this with p_open true while the chat is on screen, and with false when it leaves. Closing only removes
-- the row when it is still about that chat, so a late "closed" never clears the chat that was opened right after it.
-- The time is the database's own, so a phone with a wrong clock cannot keep meldingen away.
create or replace function public.set_open_chat(p_device text, p_conversation_id uuid, p_open boolean)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
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

grant execute on function public.set_open_chat(text, uuid, boolean) to authenticated;

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
