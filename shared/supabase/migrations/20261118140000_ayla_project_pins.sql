-- Pinned projects: a project can be pinned to the top of the Projecten list in the chat history (web).
-- Run after 20261118120000_ayla_projects.sql. The existing "Own projects" policy already lets people update only their
-- own rows. Until this runs, pinning is hidden and the list still loads.

alter table public.ayla_projects add column if not exists pinned_at timestamptz;
