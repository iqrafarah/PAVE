-- Plans can be finished ("Voltooien", or by finishing the last step): plans.completed_at, and the functions that keep
-- it. For a project where 20261125130000_plans.sql ran before it had this column. Safe to run more than once, and it
-- changes nothing where the column is already there.

alter table public.plans add column if not exists completed_at timestamptz;

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

grant execute on function public.save_plan(jsonb) to authenticated;
grant execute on function public.normalize_plan(uuid) to authenticated;

-- PostgREST picks up the new column at once.
notify pgrst, 'reload schema';
