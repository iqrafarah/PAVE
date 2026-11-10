-- Ayla conversations, shared by web, iPhone and Watch (see docs/ayla.md).
-- One account has many conversations; messages are append only.
-- Not applied yet: agree with the web team first, then run it in the SQL Editor.

create table public.ayla_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null default 'Nieuw gesprek',
  started_on text not null check (started_on in ('watch', 'phone', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ayla_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ayla_conversations (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'ayla')),
  text text not null check (length(text) between 1 and 4000),
  device text not null check (device in ('watch', 'phone', 'web')),
  reply jsonb,
  created_at timestamptz not null default now()
);

create index ayla_conversations_user_updated on public.ayla_conversations (user_id, updated_at desc);
create index ayla_messages_conversation_created on public.ayla_messages (conversation_id, created_at);

alter table public.ayla_conversations enable row level security;
alter table public.ayla_messages enable row level security;

create policy "Require two-step verification"
  on public.ayla_conversations as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Require two-step verification"
  on public.ayla_messages as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Own conversations"
  on public.ayla_conversations for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Read own messages"
  on public.ayla_messages for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Add messages to own conversations"
  on public.ayla_messages for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ayla_conversations c
      where c.id = conversation_id and c.user_id = (select auth.uid())
    )
  );

create policy "Delete own messages"
  on public.ayla_messages for delete to authenticated
  using ((select auth.uid()) = user_id);

alter publication supabase_realtime add table public.ayla_conversations, public.ayla_messages;
