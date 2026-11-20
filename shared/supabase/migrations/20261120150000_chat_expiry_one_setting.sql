-- One way to let chats expire, for web and iOS alike: the one of 20261120120000_chat_expiry_and_archive.sql.
--
-- 20261119170000_ayla_chat_archive_and_auto_delete.sql (web) and 20261120120000 (iOS) were both applied. That left:
--  1. two functions named ayla_delete_expired_chats: one without arguments (web) and one with an optional account
--     (iOS). The hourly job calls `ayla_delete_expired_chats()`, which then matches both, so it fails every hour;
--  2. two places for the choice: ayla_settings.chat_auto_delete_days (web) and profiles.chat_expiry_days (iOS), so a
--     choice made on one device did nothing on the other.
--
-- This keeps the iOS version: the choice in profiles (with when the time starts, and whether pinned and locked chats are
-- kept), an own choice per chat, and chats in a project or the archive never expire. A choice already made on the web
-- is carried over first. ayla_conversations.archived_at was the same in both and stays as it is.
-- Can be run again.

-- 1. The choice made on the web, where iOS has none yet. The web counted from the last message and kept pinned and
--    locked chats, which are the defaults in profiles too.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ayla_settings' and column_name = 'chat_auto_delete_days'
  ) then
    update public.profiles p
    set chat_expiry_days = s.chat_auto_delete_days
    from public.ayla_settings s
    where s.user_id = p.id
      and s.chat_auto_delete_days is not null
      and p.chat_expiry_days is null;

    alter table public.ayla_settings drop column chat_auto_delete_days;
  end if;
end;
$$;

-- 2. Only the function with the optional account remains; called without one it handles every account.
drop function if exists public.ayla_delete_expired_chats();

-- 3. The hourly job, once, calling the function that remains (where pg_cron is installed).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'ayla-delete-expired-chats';
    perform cron.schedule('ayla-delete-expired-chats', '17 * * * *', 'select public.ayla_delete_expired_chats(null)');
  end if;
end;
$$;
