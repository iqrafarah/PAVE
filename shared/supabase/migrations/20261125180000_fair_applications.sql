-- Applying at the job fair without a CV: a short card left with one vacancy of a fair employer (from a poster or a
-- stand), and the employer's side in the demo: whoever has the employer's secret key sees who applied and can invite
-- them for a talk, through the function `fair-inbox`. The applicant reads their own applications and answers an
-- invitation; nothing else. The employers do not take part in PAVE: in the demo a classmate plays the recruiter.
-- Can be run again.

create table if not exists public.fair_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  employer_slug text not null references public.fair_employers (slug) on delete cascade,
  vacancy_id text not null check (length(vacancy_id) between 1 and 80),
  vacancy_title text not null check (length(vacancy_title) between 1 and 160),
  -- {name, headline, why, pitch, availability: {days: [...], maxHours}}
  card jsonb not null check (jsonb_typeof(card) = 'object' and pg_column_size(card) < 20000),
  status text not null default 'new' check (status in ('new', 'invited', 'declined')),
  invited_at timestamptz,
  invited_for timestamptz,
  invitation_message text check (invitation_message is null or length(invitation_message) <= 400),
  answer text check (answer is null or answer in ('accepted', 'declined')),
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, employer_slug, vacancy_id)
);

create index if not exists fair_applications_employer on public.fair_applications (employer_slug, created_at desc);

-- The applicant may only answer an invitation; the rest is the employer's, through `fair-inbox`.
create or replace function public.fair_applications_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated' then
    if new.user_id <> old.user_id or new.employer_slug <> old.employer_slug or new.vacancy_id <> old.vacancy_id
       or new.vacancy_title <> old.vacancy_title or new.card <> old.card or new.status <> old.status
       or new.invited_at is distinct from old.invited_at or new.invited_for is distinct from old.invited_for
       or new.invitation_message is distinct from old.invitation_message or new.created_at <> old.created_at then
      raise exception 'Only the answer to an invitation can be changed';
    end if;
    if old.status <> 'invited' then
      raise exception 'There is no invitation to answer';
    end if;
    new.answered_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists fair_applications_guard on public.fair_applications;
create trigger fair_applications_guard
  before update on public.fair_applications
  for each row execute function public.fair_applications_guard();

alter table public.fair_applications enable row level security;

drop policy if exists "Require two-step verification" on public.fair_applications;
create policy "Require two-step verification"
  on public.fair_applications as restrictive for all to authenticated
  using (public.is_mfa_verified()) with check (public.is_mfa_verified());

drop policy if exists "Own applications" on public.fair_applications;
create policy "Own applications"
  on public.fair_applications for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.fair_applications from anon;
grant select, insert, update, delete on public.fair_applications to authenticated;

-- The secret key of each employer's inbox, kept as a hash and readable by nobody but the server.
create table if not exists public.fair_employer_keys (
  employer_slug text primary key references public.fair_employers (slug) on delete cascade,
  key_hash text not null,
  created_at timestamptz not null default now()
);

alter table public.fair_employer_keys enable row level security;
revoke all on public.fair_employer_keys from anon, authenticated;
