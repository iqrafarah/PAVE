-- What Ayla remembers about someone, shared by web, iPhone and Watch (see docs/ayla.md, "Memory").
-- Nothing goes in by itself: Ayla only suggests a note in her reply (`memory`), and the app saves it after the user
-- taps "Onthouden", or the user writes one themselves. The user sees, changes and deletes every note in
-- "Wat Ayla over je weet".
-- Not applied yet: agree with the web team first, then run it in the SQL Editor.
-- Until this runs, the Ayla function remembers nothing and the apps say the memory is not available yet.

create table public.ayla_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  text text not null check (length(text) between 1 and 300),
  -- 'ayla': suggested by Ayla and accepted by the user; 'user': written by the user.
  source text not null default 'ayla' check (source in ('ayla', 'user')),
  -- Where the note came from. Deleting that conversation keeps the note: the user decides about it separately.
  conversation_id uuid references public.ayla_conversations (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ayla_memories_user_created on public.ayla_memories (user_id, created_at desc);

-- One row per user. Without a row the memory is on; it only lets Ayla suggest notes and use the ones the user kept.
create table public.ayla_settings (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  memory_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.ayla_memories enable row level security;
alter table public.ayla_settings enable row level security;

create policy "Require two-step verification"
  on public.ayla_memories as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Require two-step verification"
  on public.ayla_settings as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Own memories"
  on public.ayla_memories for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Own settings"
  on public.ayla_settings for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
