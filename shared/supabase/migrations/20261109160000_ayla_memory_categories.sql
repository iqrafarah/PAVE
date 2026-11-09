-- Gives every note Ayla remembers a category, so "Wat Ayla over je weet" can group them
-- (Opleiding, Werk en stages, Doelen, Vaardigheden, Wat je belangrijk vindt, Hoe je wilt werken,
-- Interesses en hobby's, Over jou).
-- Applied on 2026-11-09. Without it, the Ayla function and the apps keep working without categories: every note
-- counts as "Over jou".
-- The existing policy "Own memories" already covers the new column.

alter table public.ayla_memories
  add column category text not null default 'personal'
  check (category in ('education', 'work', 'goals', 'skills', 'values', 'workStyle', 'interests', 'personal'));
