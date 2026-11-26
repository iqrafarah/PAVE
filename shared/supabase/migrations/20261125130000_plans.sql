-- Plans: a personal workspace where someone works towards one goal, step by step, with Ayla (see docs/ayla.md).
-- A plan has ordered steps; chats with Ayla belong to a plan through ayla_conversations.plan_id, as with projects.
-- The apps save a whole plan at once with save_plan; Ayla changes one step with set_plan_step_status. Both run with
-- the user's own rights, so row level security decides what can be read and changed.
-- Deleting a plan removes the plan and its steps only: its chats stay (or are deleted by the app when the user asks),
-- and evidence in the vault is never touched.
-- Run after 20261118120000_ayla_projects.sql. Until this runs, the Plan screen says plans are not available yet and
-- Ayla works as before.

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  goal text not null default '' check (length(goal) <= 280),
  -- The template the plan started from ("job", "internship", …), for its icon. Null for a plan from elsewhere.
  template_id text check (template_id is null or length(template_id) between 1 and 40),
  -- Free room for the flow that made the plan, such as the vacancy it is about. The plan itself never reads it.
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- When the plan was finished: by "Voltooien", or by finishing its last step. Null while it is still going.
  completed_at timestamptz
);

create index if not exists plans_user_updated on public.plans (user_id, updated_at desc);

create table if not exists public.plan_steps (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  position integer not null check (position >= 0),
  title text not null check (length(btrim(title)) between 1 and 80),
  summary text not null default '' check (length(summary) <= 280),
  -- An open set: a flow can bring kinds of its own ("vacancy"); the apps show an unknown kind as a general step.
  kind text not null default 'general' check (kind ~ '^[A-Za-z][A-Za-z0-9_-]{0,39}$'),
  status text not null default 'upcoming' check (status in ('upcoming', 'active', 'done', 'skipped')),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object')
);

create index if not exists plan_steps_plan_position on public.plan_steps (plan_id, position);

-- At most one step per plan is the one being worked on.
create unique index if not exists plan_steps_one_active on public.plan_steps (plan_id) where status = 'active';

alter table public.plans enable row level security;
alter table public.plan_steps enable row level security;

drop policy if exists "Require two-step verification" on public.plans;
create policy "Require two-step verification"
  on public.plans as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own plans" on public.plans;
create policy "Own plans"
  on public.plans for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "Require two-step verification" on public.plan_steps;
create policy "Require two-step verification"
  on public.plan_steps as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

-- A step is only ever in a plan of the same user.
drop policy if exists "Own plan steps" on public.plan_steps;
create policy "Own plan steps"
  on public.plan_steps for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.plans p where p.id = plan_id and p.user_id = (select auth.uid()))
  );

-- Chats in a plan. Deleting a plan keeps its chats: they go back to the normal list.
alter table public.ayla_conversations
  add column if not exists plan_id uuid references public.plans (id) on delete set null,
  add column if not exists plan_step_id uuid references public.plan_steps (id) on delete set null;

create index if not exists ayla_conversations_plan on public.ayla_conversations (plan_id) where plan_id is not null;

-- A chat can only be put in one of the user's own plans.
create or replace function public.guard_conversation_plan()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.plan_id is not null and not exists (select 1 from public.plans p where p.id = new.plan_id and p.user_id = new.user_id) then
    raise exception 'plan_not_found' using errcode = '42501';
  end if;
  if new.plan_step_id is not null and not exists (select 1 from public.plan_steps s where s.id = new.plan_step_id and s.plan_id = new.plan_id) then
    new.plan_step_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists ayla_conversations_plan_guard on public.ayla_conversations;
create trigger ayla_conversations_plan_guard
  before insert or update of plan_id, plan_step_id on public.ayla_conversations
  for each row execute function public.guard_conversation_plan();

-- After a change, one step is active while anything is left to do: the first that is still to come. A plan with
-- nothing left is finished; reopening a step makes it go on again. A plan without steps keeps what the app said.
create or replace function public.normalize_plan(p_plan_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (select 1 from public.plan_steps where plan_id = p_plan_id and status = 'active') then
    update public.plan_steps set status = 'active'
    where id = (select id from public.plan_steps where plan_id = p_plan_id and status = 'upcoming' order by position limit 1);
  end if;
  if exists (select 1 from public.plan_steps where plan_id = p_plan_id and status in ('upcoming', 'active')) then
    update public.plans set completed_at = null where id = p_plan_id and completed_at is not null;
  elsif exists (select 1 from public.plan_steps where plan_id = p_plan_id) then
    update public.plans set completed_at = now() where id = p_plan_id and completed_at is null;
  end if;
end;
$$;

-- Saves a whole plan as the app has it (the JSON of PavePlan): the plan, its steps in order and which chats are in it.
-- Steps that are no longer in it are removed; chats that are no longer in it go back to the normal list.
create or replace function public.save_plan(p_plan jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid := (p_plan->>'id')::uuid;
  v_steps jsonb := coalesce(p_plan->'steps', '[]'::jsonb);
  v_chats jsonb := coalesce(p_plan->'conversations', '[]'::jsonb);
begin
  insert into public.plans (id, name, goal, template_id, metadata, created_at, updated_at, completed_at)
  values (
    v_id, btrim(p_plan->>'name'), coalesce(p_plan->>'goal', ''), nullif(p_plan->>'templateID', ''),
    coalesce(p_plan->'metadata', '{}'::jsonb), coalesce((p_plan->>'createdAt')::timestamptz, now()), now(),
    (p_plan->>'completedAt')::timestamptz
  )
  on conflict (id) do update
    set name = excluded.name, goal = excluded.goal, template_id = excluded.template_id, metadata = excluded.metadata,
        updated_at = now(), completed_at = excluded.completed_at;

  delete from public.plan_steps s
  where s.plan_id = v_id
    and not exists (select 1 from jsonb_array_elements(v_steps) e where (e->>'id')::uuid = s.id);

  -- Every step first without "active", so the one-active index never sees two while the order changes.
  update public.plan_steps set status = 'upcoming' where plan_id = v_id and status = 'active';

  insert into public.plan_steps (id, plan_id, position, title, summary, kind, status, completed_at, metadata)
  select (e->>'id')::uuid, v_id, (o - 1)::integer, btrim(e->>'title'), coalesce(e->>'summary', ''),
         coalesce(nullif(e->>'kind', ''), 'general'), coalesce(e->>'status', 'upcoming'),
         (e->>'completedAt')::timestamptz, coalesce(e->'metadata', '{}'::jsonb)
  from jsonb_array_elements(v_steps) with ordinality as t(e, o)
  on conflict (id) do update
    set position = excluded.position, title = excluded.title, summary = excluded.summary, kind = excluded.kind,
        status = excluded.status, completed_at = excluded.completed_at, metadata = excluded.metadata
    where public.plan_steps.plan_id = v_id;

  update public.ayla_conversations c set plan_id = null, plan_step_id = null
  where c.plan_id = v_id
    and not exists (select 1 from jsonb_array_elements(v_chats) e where (e->>'id')::uuid = c.id);

  update public.ayla_conversations c
  set plan_id = v_id, plan_step_id = nullif(e->>'stepID', '')::uuid
  from jsonb_array_elements(v_chats) e
  where c.id = (e->>'id')::uuid
    and (c.plan_id is distinct from v_id or c.plan_step_id is distinct from nullif(e->>'stepID', '')::uuid);

  perform public.normalize_plan(v_id);
end;
$$;

-- Ayla marks a step done, skipped or the one to work on now; the plan stays in order, as in the apps.
create or replace function public.set_plan_step_status(p_step_id uuid, p_status text)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_plan uuid;
begin
  if p_status not in ('upcoming', 'active', 'done', 'skipped') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  select plan_id into v_plan from public.plan_steps where id = p_step_id;
  if v_plan is null then
    raise exception 'step_not_found' using errcode = 'P0002';
  end if;
  if p_status = 'active' then
    update public.plan_steps set status = 'upcoming' where plan_id = v_plan and status = 'active' and id <> p_step_id;
  end if;
  update public.plan_steps
  set status = p_status, completed_at = case when p_status = 'done' then coalesce(completed_at, now()) end
  where id = p_step_id;
  perform public.normalize_plan(v_plan);
  update public.plans set updated_at = now() where id = v_plan;
end;
$$;

grant execute on function public.save_plan(jsonb) to authenticated;
grant execute on function public.set_plan_step_status(uuid, text) to authenticated;
revoke execute on function public.normalize_plan(uuid) from public, anon;
grant execute on function public.normalize_plan(uuid) to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'plans') then
    alter publication supabase_realtime add table public.plans;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'plan_steps') then
    alter publication supabase_realtime add table public.plan_steps;
  end if;
end $$;
