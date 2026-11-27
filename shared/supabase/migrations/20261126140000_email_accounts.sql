-- E-mail in Meldingen on the web: the learner's connected iCloud Mail account.
--
-- iOS keeps the app-specific password in the iPhone's Keychain and talks to iCloud itself. A browser cannot speak
-- IMAP or SMTP, so on the web PAVE's own web server (web/server/api/email) logs in for the learner. It needs the
-- password for that, so it is kept here: encrypted with AES-256-GCM by the web server, with a key that only the web
-- server has (NUXT_EMAIL_SECRET). The database, Supabase and the browser only ever see the encrypted text.
--
-- One account per learner. Only the learner can read, write or delete their own row; the web server works with the
-- learner's own session, not with the service role.

create table if not exists public.email_accounts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  provider text not null default 'icloud' check (provider in ('icloud')),
  address text not null check (length(btrim(address)) between 3 and 320),
  -- The user name that worked at login: the whole address, or the part before the @.
  login_name text not null check (length(btrim(login_name)) between 1 and 320),
  -- "v1:<iv>:<auth tag>:<ciphertext>", all base64; see web/server/utils/email/secret.ts.
  secret text not null check (secret like 'v1:%'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.email_accounts is
  'The connected mailbox of a learner for e-mail in Meldingen (web). The password is encrypted by the web server.';
comment on column public.email_accounts.secret is
  'The app-specific password, AES-256-GCM encrypted with a key only the web server has.';

alter table public.email_accounts enable row level security;

drop policy if exists email_accounts_select_own on public.email_accounts;
create policy email_accounts_select_own on public.email_accounts
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists email_accounts_insert_own on public.email_accounts;
create policy email_accounts_insert_own on public.email_accounts
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists email_accounts_update_own on public.email_accounts;
create policy email_accounts_update_own on public.email_accounts
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists email_accounts_delete_own on public.email_accounts;
create policy email_accounts_delete_own on public.email_accounts
  for delete to authenticated using (user_id = (select auth.uid()));

revoke all on public.email_accounts from anon;
grant select, insert, update, delete on public.email_accounts to authenticated;
