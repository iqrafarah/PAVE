-- The verification form showed only the learner's own organisation: `organizations` belongs to the web team and its
-- only read policy is "Organizations: members read own" (id = current_organization_id()). A learner must be able to
-- pick any organisation in the directory, but the table itself stays closed: a broader policy would expose every
-- column of every organisation, including columns the web team adds later.
--
-- This function returns only what the pick-list needs (id, name, kind) for organisations in the directory
-- (kind set), and only to a session with two-step verification, like the other directory tables. It decides nothing:
-- `vault-review` checks the chosen IDs again with trusted server code before routing a request.

create or replace function public.validation_organizations()
returns table (id uuid, name text, kind text)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, o.name, o.kind
  from public.organizations o
  where o.kind is not null
    and public.is_mfa_verified()
  order by o.name;
$$;

revoke all on function public.validation_organizations() from public, anon;
grant execute on function public.validation_organizations() to authenticated;

comment on function public.validation_organizations() is
  'Directory pick-list for verification requests: id, name and kind of every organisation with a kind. MFA sessions only; organizations itself keeps its own-organisation read policy.';
