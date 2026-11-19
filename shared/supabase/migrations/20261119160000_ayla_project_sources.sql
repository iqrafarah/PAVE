-- Sources of an Ayla project: vault items the user added to a project (web, "Bronnen" on the project page).
-- Ayla uses the items in every chat of the project, still only the ones with "Ayla mag dit bekijken en gebruiken".
-- Run after 20261118120000_ayla_projects.sql and 20261110120000_vault.sql. Safe to run more than once. Until this runs the
-- web hides "Bronnen" and the Edge Function finds no sources. Not applied yet: agree with the team first (shared schema).

-- The composite foreign key below needs a unique (user_id, id) on projects; vault_items already has one.
create unique index if not exists ayla_projects_user_id_id on public.ayla_projects (user_id, id);

create table if not exists public.ayla_project_sources (
  user_id uuid not null default auth.uid(),
  project_id uuid not null,
  item_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, project_id, item_id),
  foreign key (user_id, project_id) references public.ayla_projects (user_id, id) on delete cascade,
  foreign key (user_id, item_id) references public.vault_items (user_id, id) on delete cascade
);

create index if not exists ayla_project_sources_project on public.ayla_project_sources (project_id);

alter table public.ayla_project_sources enable row level security;

drop policy if exists "Require two-step verification" on public.ayla_project_sources;
create policy "Require two-step verification"
  on public.ayla_project_sources as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own project sources" on public.ayla_project_sources;
create policy "Own project sources"
  on public.ayla_project_sources for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
