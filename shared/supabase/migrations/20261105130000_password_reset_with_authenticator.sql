-- Password reset with email + authenticator code, without sending email.
-- Used only by the Edge Functions verify-password-reset-code and reset-password (service role).
-- The functions live in public so the Edge Function can call them through the API,
-- but execute rights are revoked for anon and authenticated users.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.password_reset_failures (
  id bigint generated always as identity primary key,
  email text not null,
  failed_at timestamptz not null default now()
);

create index password_reset_failures_email_failed_at_idx
  on private.password_reset_failures (email, failed_at);

alter table private.password_reset_failures enable row level security;

create table private.password_reset_tokens (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz
);

alter table private.password_reset_tokens enable row level security;

create function public.count_password_reset_failures(p_email text, p_window_minutes integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from private.password_reset_failures
  where email = lower(p_email)
    and failed_at > now() - make_interval(mins => p_window_minutes);
$$;

create function public.record_password_reset_failure(p_email text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.password_reset_failures where failed_at < now() - interval '1 day';
  insert into private.password_reset_failures (email) values (lower(p_email));
$$;

create function public.get_verified_totp_secret(p_email text)
returns table (user_id uuid, secret text)
language sql
stable
security definer
set search_path = ''
as $$
  select factor.user_id, factor.secret
  from auth.mfa_factors as factor
  join auth.users as account on account.id = factor.user_id
  where lower(account.email) = lower(p_email)
    and factor.factor_type = 'totp'
    and factor.status = 'verified'
  order by factor.created_at
  limit 1;
$$;

create function public.create_password_reset_token(
  p_user_id uuid,
  p_token_hash text,
  p_valid_minutes integer
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.password_reset_tokens where expires_at < now() - interval '1 day';
  insert into private.password_reset_tokens (user_id, token_hash, expires_at)
  values (p_user_id, p_token_hash, now() + make_interval(mins => p_valid_minutes));
$$;

create function public.consume_password_reset_token(p_token_hash text)
returns uuid
language sql
security definer
set search_path = ''
as $$
  update private.password_reset_tokens
  set used_at = now()
  where token_hash = p_token_hash
    and used_at is null
    and expires_at > now()
  returning user_id;
$$;

create function public.revoke_user_sessions(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.sessions where user_id = p_user_id;
$$;

revoke execute on function
  public.count_password_reset_failures(text, integer),
  public.record_password_reset_failure(text),
  public.get_verified_totp_secret(text),
  public.create_password_reset_token(uuid, text, integer),
  public.consume_password_reset_token(text),
  public.revoke_user_sessions(uuid)
from public, anon, authenticated;

grant execute on function
  public.count_password_reset_failures(text, integer),
  public.record_password_reset_failure(text),
  public.get_verified_totp_secret(text),
  public.create_password_reset_token(uuid, text, integer),
  public.consume_password_reset_token(text),
  public.revoke_user_sessions(uuid)
to service_role;
