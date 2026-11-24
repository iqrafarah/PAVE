-- The department filter goes by name (see docs/verificatie.md).
--
-- "ICT" in Tilburg and "ICT" in Eindhoven are two departments, but for the learner it is one choice: ICT. So the
-- persons are filtered on the department's name instead of one department ID; together with the location filter it
-- still narrows to one location. Only validation_search_contacts changes: p_department_id becomes p_department.
-- Safe to run again.

drop function if exists public.validation_search_contacts(uuid, text, text, uuid, uuid, text, int, int);

create or replace function public.validation_search_contacts(
  p_organization_id uuid, p_category text, p_query text default null,
  p_location_id uuid default null, p_department text default null, p_function text default null,
  p_limit int default 25, p_offset int default 0
)
returns table (
  id uuid, name text, job_title text, function text, department_id uuid, department_name text,
  location_id uuid, city text, organization_id uuid, total_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.*, count(*) over ()
  from public.validation_available_contacts(p_category) a
  where a.organization_id = p_organization_id
    and (p_location_id is null or a.location_id = p_location_id)
    and (p_department is null or a.department_name = p_department)
    and (p_function is null or a.function = p_function)
    and public.validation_matches(concat_ws(' ', a.name, a.function, a.department_name, a.city), p_query)
    and public.is_mfa_verified() and (select auth.uid()) is not null
  order by a.name, a.city, a.department_name
  limit least(greatest(coalesce(p_limit, 25), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int) from public, anon;
grant execute on function public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int) to authenticated;

comment on function public.validation_search_contacts(uuid, text, text, uuid, text, text, int, int) is
  'A page of persons of one organisation who may confirm this kind of evidence. Never returns the account behind them.';
