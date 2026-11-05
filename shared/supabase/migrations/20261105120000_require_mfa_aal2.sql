-- Two-step verification (TOTP) is mandatory for web and iOS.
-- Every table with user data must add agit  restrictive policy that uses this function,
-- so a session that only passed the password step (aal1) cannot read or write data:
--
--   create policy "Require two-step verification"
--     on public.<table>
--     as restrictive
--     for all
--     to authenticated
--     using (public.is_mfa_verified())
--     with check (public.is_mfa_verified());

create or replace function public.is_mfa_verified()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'aal') = 'aal2', false);
$$;

comment on function public.is_mfa_verified() is
  'True when the current session completed two-step verification (aal2). Use in restrictive RLS policies.';

grant execute on function public.is_mfa_verified() to authenticated;
