-- Profile photos (web: Instellingen, Personalisatie, Profielafbeelding).
--
-- A private bucket with one folder per account: <user id>/avatar-<time>.jpeg. Only the account itself reads and writes
-- its folder, and only after two-step verification, like the vault. The apps note the path of the photo on the account
-- (user metadata `avatar_path`) and show it through a signed link.
--
-- Not applied yet. This is part of the shared schema: run it only together with the team.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pave-avatars', 'pave-avatars', false, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "Profile photos need two-step verification"
  on storage.objects as restrictive for all to authenticated
  using (bucket_id <> 'pave-avatars' or public.is_mfa_verified())
  with check (bucket_id <> 'pave-avatars' or public.is_mfa_verified());

create policy "An account reads its own profile photo"
  on storage.objects for select to authenticated
  using (bucket_id = 'pave-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "An account adds its own profile photo"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'pave-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "An account removes its own profile photo"
  on storage.objects for delete to authenticated
  using (bucket_id = 'pave-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
