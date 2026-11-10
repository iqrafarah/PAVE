-- A note in "Wat Ayla over je weet" can be in more than one category, such as "Je ontwerpt graag" under both
-- "Werk en stages" and "Interesses en hobby's" (see docs/ayla.md, "Memory").
-- Applied on 2026-11-10. Before it ran, the apps saved only the main category and kept working.
--
-- `category` stays: it is the main category, the first of `categories`, and the Ayla function and the web keep reading
-- it. A trigger keeps the two in step, so a client that only writes `category` still gets a valid `categories`.
-- The existing policies on ayla_memories already cover the new column.

alter table public.ayla_memories
  add column categories text[] not null default '{}';

update public.ayla_memories set categories = array[category];

create or replace function public.sync_ayla_memory_categories()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.categories is not distinct from old.categories
     and new.category is distinct from old.category then
    -- Only the main category changed (an older client): it replaces the list.
    new.categories := array[new.category];
  elsif cardinality(new.categories) = 0 then
    new.categories := array[new.category];
  end if;
  -- Each category once, in the order given; the first is the main one.
  new.categories := array(
    select c from unnest(new.categories) with ordinality as u(c, i) group by c order by min(i)
  );
  new.category := new.categories[1];
  return new;
end;
$$;

create trigger ayla_memories_sync_categories
  before insert or update on public.ayla_memories
  for each row execute function public.sync_ayla_memory_categories();

alter table public.ayla_memories
  add constraint ayla_memories_categories_check check (
    cardinality(categories) between 1 and 8
    and categories <@ array['education', 'work', 'goals', 'skills', 'values', 'workStyle', 'interests', 'personal']
    and category = categories[1]
  );

comment on column public.ayla_memories.categories is
  'Every category the note is in, at least one; the first is the same as category.';
