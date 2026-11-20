-- Hoe lang gegevens blijven: verval voor chats en een archief voor chats en bewijsstukken, for web and iOS alike.
--  1. profiles: one general choice for how long chats stay (null = no expiry, the default), from when the time runs,
--     which chats are kept anyway, and whether Ayla may use what is archived (default: no).
--  2. ayla_conversations: archived_at, and an own expiry per chat (null = follow the account, 0 = never).
--  3. vault_items: archived_at. Evidence never expires by itself.
--  4. Deleting is final. Expired chats are deleted on the server: every hour by pg_cron where it is installed, and
--     for the account itself through ayla_expire_my_chats(), which the apps call when they load the chat list.
--
-- Never expires: an archived chat and a chat in a project. A pinned or locked chat is kept unless the account turned
-- that off. The time runs from the last message, or from when the chat was made, as the account chose.
-- Reading: the apps hide rows with archived_at from the normal lists and show them in the archive.
-- Can be run again.

-- 1. The account's choices --------------------------------------------------------------------------------------------

alter table public.profiles
  add column if not exists chat_expiry_days integer,
  add column if not exists chat_expiry_from text not null default 'last_message',
  add column if not exists chat_expiry_keeps_pinned boolean not null default true,
  add column if not exists chat_expiry_keeps_locked boolean not null default true,
  add column if not exists ayla_uses_archive boolean not null default false;

alter table public.profiles drop constraint if exists profiles_chat_expiry_days_check;
alter table public.profiles add constraint profiles_chat_expiry_days_check
  check (chat_expiry_days is null or chat_expiry_days in (1, 7, 30, 90));

alter table public.profiles drop constraint if exists profiles_chat_expiry_from_check;
alter table public.profiles add constraint profiles_chat_expiry_from_check
  check (chat_expiry_from in ('last_message', 'created'));

comment on column public.profiles.chat_expiry_days is 'After how many days a chat is deleted for good; null is no expiry.';
comment on column public.profiles.chat_expiry_from is 'From when the time runs: last_message or created.';
comment on column public.profiles.chat_expiry_keeps_pinned is 'Pinned chats do not expire.';
comment on column public.profiles.chat_expiry_keeps_locked is 'Locked chats do not expire.';
comment on column public.profiles.ayla_uses_archive is 'Whether Ayla may use archived evidence the account allowed her to see.';

-- The account may change these too. The list repeats 20261112170000 and already names display_mode (web, automation),
-- so the two migrations can be applied in either order.
create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  own text[] := array[
    'preferred_name', 'avatar_path', 'theme_color', 'theme_custom_color', 'text_size', 'vault_layout', 'display_mode',
    'chat_expiry_days', 'chat_expiry_from', 'chat_expiry_keeps_pinned', 'chat_expiry_keeps_locked', 'ayla_uses_archive',
    'updated_at'
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

grant update (chat_expiry_days, chat_expiry_from, chat_expiry_keeps_pinned, chat_expiry_keeps_locked, ayla_uses_archive)
  on public.profiles to authenticated;

-- 2 and 3. Archive and an own expiry per chat ------------------------------------------------------------------------

alter table public.ayla_conversations
  add column if not exists archived_at timestamptz,
  add column if not exists expiry_days integer;

alter table public.ayla_conversations drop constraint if exists ayla_conversations_expiry_days_check;
alter table public.ayla_conversations add constraint ayla_conversations_expiry_days_check
  check (expiry_days is null or expiry_days in (0, 1, 7, 30, 90));

comment on column public.ayla_conversations.archived_at is 'Archived: out of the chat list, kept until it is put back or deleted. Never expires.';
comment on column public.ayla_conversations.expiry_days is 'An own expiry for this chat: null follows the account, 0 never expires.';

alter table public.vault_items add column if not exists archived_at timestamptz;
comment on column public.vault_items.archived_at is 'Archived: out of the vault, kept until it is put back or deleted. Not shared, and only used by Ayla when the account allows it.';

create index if not exists ayla_conversations_archived on public.ayla_conversations (user_id, archived_at desc) where archived_at is not null;
create index if not exists vault_items_archived on public.vault_items (user_id, archived_at desc) where archived_at is not null;

-- 4. Deleting what expired --------------------------------------------------------------------------------------------

-- Deletes the chats whose time is up, of one account or (null) of every account. Returns how many.
create or replace function public.ayla_delete_expired_chats(p_user_id uuid default null)
returns integer
language sql
security definer
set search_path = ''
as $$
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

revoke all on function public.ayla_delete_expired_chats(uuid) from public, anon, authenticated;

-- For the apps: the chats of the signed-in account whose time is up go now.
create or replace function public.ayla_expire_my_chats()
returns integer
language sql
security definer
set search_path = ''
as $$
  select case when auth.uid() is null then 0 else public.ayla_delete_expired_chats(auth.uid()) end;
$$;

revoke all on function public.ayla_expire_my_chats() from public, anon;
grant execute on function public.ayla_expire_my_chats() to authenticated;

-- Every hour for everyone, where pg_cron is installed; without it the apps' own call above still clears them.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'ayla-delete-expired-chats';
    perform cron.schedule('ayla-delete-expired-chats', '17 * * * *', 'select public.ayla_delete_expired_chats()');
  end if;
end;
$$;
