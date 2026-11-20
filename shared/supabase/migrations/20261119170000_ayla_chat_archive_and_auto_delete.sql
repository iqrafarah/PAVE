-- Archiving a chat, and deleting chats automatically after a while (web; the iPhone can follow).
-- Not applied yet: agree with the team first, then run it in the SQL Editor. Until it runs, the web hides both:
-- "Archiveren" is not in the chat menu and the auto-delete choice is not on the privacy page.

-- An archived chat leaves the recent list but is kept: it shows under "Gearchiveerd" and can be put back.
alter table public.ayla_conversations
  add column archived_at timestamptz;

-- How long a chat is kept: null is for ever. Chats that are pinned, archived or locked never expire.
alter table public.ayla_settings
  add column chat_auto_delete_days int
  check (chat_auto_delete_days in (1, 30, 90));

-- The time is counted from the last message (updated_at). Messages go with the chat (on delete cascade).
create function public.ayla_delete_expired_chats() returns int
language plpgsql security definer set search_path = '' as $$
declare
  removed int;
begin
  with gone as (
    delete from public.ayla_conversations c
    using public.ayla_settings s
    where s.user_id = c.user_id
      and s.chat_auto_delete_days is not null
      and c.updated_at < now() - make_interval(days => s.chat_auto_delete_days)
      and c.pinned_at is null
      and c.archived_at is null
      and not exists (select 1 from public.ayla_locked_chats l where l.conversation_id = c.id)
    returning c.id
  )
  select count(*) into removed from gone;
  return removed;
end;
$$;

-- Only the scheduled job runs it, nobody over the API.
revoke all on function public.ayla_delete_expired_chats() from public, anon, authenticated;

-- Every hour. Needs the pg_cron extension (Supabase: Database > Extensions).
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('ayla-delete-expired-chats', '17 * * * *', 'select public.ayla_delete_expired_chats()');
