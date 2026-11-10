-- Lets someone pin a conversation with Ayla to the top of their list ("Vastgezet").
-- Not applied yet: agree with the web team first, then run it in the SQL Editor.
-- The existing policy "Own conversations" already lets people update only their own rows.
-- Until this runs, the iOS app simply hides pinning.

alter table public.ayla_conversations add column pinned_at timestamptz;
