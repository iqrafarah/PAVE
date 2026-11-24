-- Groundwork for real push meldingen (APNs). Nothing sends yet: that needs a paid Apple Developer account and an APNs key.
-- The app does not write here either until then; the table only waits so the send step can be added without a new design.
--
-- One row per device token of an account. Only the owner reads or removes their own rows; the (future) send step uses
-- the service-role key, so no policy lets anyone read another account's tokens.

create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null check (length(token) between 32 and 400),
  platform text not null default 'ios' check (platform in ('ios')),
  environment text not null default 'production' check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (token)
);

create index if not exists push_devices_user on public.push_devices (user_id);

alter table public.push_devices enable row level security;

drop policy if exists "Own push devices" on public.push_devices;
create policy "Own push devices" on public.push_devices for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Require two-step verification" on public.push_devices;
create policy "Require two-step verification" on public.push_devices as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

comment on table public.push_devices is 'APNs device tokens per account, for push meldingen. Not used until the app has a paid Apple Developer account.';
