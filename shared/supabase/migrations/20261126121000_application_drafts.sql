-- Applications (a CV and a motivation letter for one vacancy) kept with the account, so a draft started on one device
-- goes on on another. The apps keep working from the copy on the device; this table is what they compare with.
-- The draft is stored whole, as the app writes it (ApplicationDraft); the server never reads inside it.
-- A deleted application stays as a row without a draft (deleted_at), so other devices remove it too.
-- Until this runs, applications stay on the device they were made on, as before.

create table if not exists public.application_drafts (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- The vacancy it is for; one application per vacancy.
  id text not null check (length(id) between 1 and 200),
  draft jsonb check (draft is null or jsonb_typeof(draft) = 'object'),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id),
  check (draft is not null or deleted_at is not null),
  check (draft is null or pg_column_size(draft) <= 1048576)
);

alter table public.application_drafts enable row level security;

drop policy if exists "Require two-step verification" on public.application_drafts;
create policy "Require two-step verification"
  on public.application_drafts as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own application drafts" on public.application_drafts;
create policy "Own application drafts"
  on public.application_drafts for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
