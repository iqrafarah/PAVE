-- Ayla projects: a folder for chats with its own instructions for Ayla (see docs/ayla.md).
-- Nothing existing changes: project_id is optional, so every current chat simply belongs to no project.
-- Not applied yet: agree with the team first, then run it in the SQL Editor.

create table public.ayla_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  instructions text not null default '' check (length(instructions) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ayla_projects_user_updated on public.ayla_projects (user_id, updated_at desc);

alter table public.ayla_projects enable row level security;

create policy "Require two-step verification"
  on public.ayla_projects as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

create policy "Own projects"
  on public.ayla_projects for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Deleting a project keeps its chats: they go back to the normal list.
alter table public.ayla_conversations
  add column project_id uuid references public.ayla_projects (id) on delete set null;

create index ayla_conversations_project on public.ayla_conversations (project_id) where project_id is not null;

alter publication supabase_realtime add table public.ayla_projects;
