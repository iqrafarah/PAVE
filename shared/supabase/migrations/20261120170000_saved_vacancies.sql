-- Bewaarde vacatures: a vacancy Ayla found that you keep, on every device of your account.
--
-- The vacancy is stored as Ayla showed it (title, company, city, salary, link, and what fits and what is missing), so it
-- still shows when Adzuna no longer has it. It holds no vault content: only the skills and the vacancy text they came from.
-- Each account sees and changes only its own, behind two-step verification as the rest of the account's data.
-- Can be run again.

create table if not exists public.saved_vacancies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  vacancy_id text not null check (length(vacancy_id) between 1 and 200),
  vacancy jsonb not null check (jsonb_typeof(vacancy) = 'object' and pg_column_size(vacancy) < 20000),
  saved_at timestamptz not null default now(),
  unique (user_id, vacancy_id)
);

create index if not exists saved_vacancies_user_saved on public.saved_vacancies (user_id, saved_at desc);

alter table public.saved_vacancies enable row level security;

drop policy if exists "Require two-step verification" on public.saved_vacancies;
create policy "Require two-step verification"
  on public.saved_vacancies as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own saved vacancies" on public.saved_vacancies;
create policy "Own saved vacancies"
  on public.saved_vacancies for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.saved_vacancies from anon;
grant select, insert, delete on public.saved_vacancies to authenticated;
