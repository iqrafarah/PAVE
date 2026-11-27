-- What a person keeps in PAVE besides their evidence, plans, chats and applications, so it follows the account to
-- every device, as in ChatGPT and Claude: Mijn beursdag, what was already seen in Meldingen and in "Wie keek er",
-- choices on Ayla's proposals for a plan, the order and look of the vault's folders, pinned and muted mail, and the
-- last choices in sharing. The apps keep a copy per account on the device and compare it with this table.
--
-- One row per thing: a scope (what kind of thing) and a key within it, with its value as the app writes it. The server
-- never reads inside the value. Until this runs, the apps keep these on the device only, per account, as before.
--
-- What the iPhone writes (docs/supabase-account-state.md); every value is JSON:
--   fairDay/entries                 the stands scanned and cards left at the fair: [{date, event}]
--   seen/fairInvitations            ids of fair invitations already announced: ["..."]
--   seen/shareLooksUntil            seen "Wie keek er" up to this moment: "2026-11-27T10:00:00Z"
--   planEdit/decisions              Ayla's plan proposals and what was chosen: {"<id>": "applied" | "declined"}
--   vault/folderStyles              colour and icon per folder: {"<folder id>": "colour|icon"}
--   vault/folderOrder, itemOrder    the order of folders and items: ["<id>", ...]
--   vault/exampleFoldersMade        the example folders were made once: true
--   mail/pinned, muted, locked      mail conversations by id: ["..."]
--   choices/quickShareProfile       the last selection used to share quickly: "<id>"
--   choices/fairAvailability        what was last filled in as availability at the fair: "..."

create table if not exists public.account_state (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  scope text not null check (scope ~ '^[a-zA-Z][a-zA-Z0-9_.-]{0,40}$'),
  key text not null check (length(key) between 1 and 200),
  value jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, scope, key),
  check (pg_column_size(value) <= 65536)
);

alter table public.account_state enable row level security;

drop policy if exists "Require two-step verification" on public.account_state;
create policy "Require two-step verification"
  on public.account_state as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own account state" on public.account_state;
create policy "Own account state"
  on public.account_state for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
