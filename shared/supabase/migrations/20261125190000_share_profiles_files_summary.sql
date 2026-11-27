-- Selecties (saved profiles) can now say which evidence takes its files along, carry a few sentences about you and keep
-- how long a share of them lasts. The files themselves stay in the vault; share-view signs a short-lived link to them
-- only for evidence that a live share names in content.files.
alter table public.share_profiles
  add column if not exists file_ids uuid[] not null default '{}' check (cardinality(file_ids) <= 100),
  add column if not exists summary text check (summary is null or length(summary) <= 400),
  add column if not exists duration_days integer check (duration_days is null or duration_days in (1, 7, 14, 30, 90));

comment on column public.share_profiles.file_ids is 'Evidence of this selection whose files the recipient may open.';
comment on column public.share_profiles.summary is 'A few sentences about the owner, shown on top of what is shared.';
comment on column public.share_profiles.duration_days is 'How long a share of this selection lasts; null keeps the default of its template.';
