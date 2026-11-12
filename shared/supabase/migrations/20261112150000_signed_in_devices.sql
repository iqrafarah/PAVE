-- Signed-in devices (Instellingen, Ingelogde apparaten): an account sees where it is signed in and can sign a device out.
--
-- The sessions live in auth.sessions, which the apps cannot read. These two functions show and end only the sessions of
-- the signed-in account, and only after two-step verification. No service key is needed: they run as their owner and
-- filter on auth.uid() themselves.
--
-- Ending a session deletes it with its refresh tokens: that device cannot refresh its access token and is asked to
-- sign in again. An access token it already has stays valid until it expires (at most an hour).
--
-- Not applied yet. This is part of the shared schema: run it only together with the web team.

create or replace function public.my_sessions()
returns table (
  id uuid,
  signed_in_at text,
  last_active_at text,
  user_agent text,
  is_current boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    s.id,
    to_char(s.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    to_char(
      greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'UTC') at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS"Z"'
    ),
    s.user_agent,
    s.id = nullif(auth.jwt() ->> 'session_id', '')::uuid
  from auth.sessions s
  where s.user_id = auth.uid()
    and public.is_mfa_verified()
    and (s.not_after is null or s.not_after > now())
  order by greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'UTC') desc;
$$;

-- Signs one other device out. The device you use signs out with the normal sign-out instead.
create or replace function public.end_my_session(target uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  removed integer;
begin
  if not public.is_mfa_verified() then
    raise exception 'Two-step verification is required' using errcode = '42501';
  end if;
  if target = nullif(auth.jwt() ->> 'session_id', '')::uuid then
    raise exception 'Use sign out for this device' using errcode = '22023';
  end if;
  delete from auth.sessions where id = target and user_id = auth.uid();
  get diagnostics removed = row_count;
  return removed > 0;
end;
$$;

revoke all on function public.my_sessions() from public, anon;
revoke all on function public.end_my_session(uuid) from public, anon;
grant execute on function public.my_sessions() to authenticated;
grant execute on function public.end_my_session(uuid) to authenticated;

comment on function public.my_sessions() is
  'The sessions of the signed-in account (aal2 only): where it is signed in, for Instellingen > Ingelogde apparaten.';
comment on function public.end_my_session(uuid) is
  'Signs one other session of the signed-in account out (aal2 only); not the current one.';
