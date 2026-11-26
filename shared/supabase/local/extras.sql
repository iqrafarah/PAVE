-- Local stack only: what the `public` dump (public.sql) does not carry. Loaded as a seed after public.sql, see
-- config.toml [db.seed]. Rebuild both with local/refresh.sh after a migration lands on the hosted project.


insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('pave-vault', 'pave-vault', false, 20971520, array[
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/heic', 'image/jpeg', 'image/png', 'text/plain'
  ]),
  ('pave-avatars', 'pave-avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/heic']),
  ('profile-shares', 'profile-shares', false, 5242880, array['application/pdf'])
on conflict (id) do nothing;

create trigger profile_on_signup
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

create trigger vault_example_folders_on_signup
  after insert on auth.users
  for each row execute function public.create_example_vault_folders_for_new_user();

-- Storage policies, as on the hosted project.
CREATE POLICY "Avatars need two-step verification" ON "storage"."objects" AS RESTRICTIVE TO "authenticated" USING ((("bucket_id" <> 'pave-avatars'::"text") OR "public"."is_mfa_verified"())) WITH CHECK ((("bucket_id" <> 'pave-avatars'::"text") OR "public"."is_mfa_verified"()));

CREATE POLICY "Delete own vault objects" ON "storage"."objects" FOR DELETE TO "authenticated" USING ((("bucket_id" = 'pave-vault'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Own avatar objects" ON "storage"."objects" TO "authenticated" USING ((("bucket_id" = 'pave-avatars'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text"))) WITH CHECK ((("bucket_id" = 'pave-avatars'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (COALESCE("array_length"("storage"."foldername"("name"), 1), 0) = 1)));

CREATE POLICY "Own share files" ON "storage"."objects" TO "authenticated" USING ((("bucket_id" = 'profile-shares'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND "public"."is_mfa_verified"())) WITH CHECK ((("bucket_id" = 'profile-shares'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND "public"."is_mfa_verified"()));

CREATE POLICY "Read own vault objects" ON "storage"."objects" FOR SELECT TO "authenticated" USING ((("bucket_id" = 'pave-vault'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Update own vault objects" ON "storage"."objects" FOR UPDATE TO "authenticated" USING ((("bucket_id" = 'pave-vault'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))) WITH CHECK ((("bucket_id" = 'pave-vault'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Upload own vault objects" ON "storage"."objects" FOR INSERT TO "authenticated" WITH CHECK ((("bucket_id" = 'pave-vault'::"text") AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));

CREATE POLICY "Vault objects must belong to an owned item" ON "storage"."objects" AS RESTRICTIVE TO "authenticated" USING ((("bucket_id" <> 'pave-vault'::"text") OR ((COALESCE("array_length"("storage"."foldername"("name"), 1), 0) = 2) AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))))) WITH CHECK ((("bucket_id" <> 'pave-vault'::"text") OR ((COALESCE("array_length"("storage"."foldername"("name"), 1), 0) = 2) AND (("storage"."foldername"("name"))[1] = (( SELECT "auth"."uid"() AS "uid"))::"text") AND (EXISTS ( SELECT 1
   FROM "public"."vault_items" "i"
  WHERE ((("i"."id")::"text" = ("storage"."foldername"("objects"."name"))[2]) AND ("i"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));

CREATE POLICY "Vault objects require two-step verification" ON "storage"."objects" AS RESTRICTIVE TO "authenticated" USING ((("bucket_id" <> 'pave-vault'::"text") OR "public"."is_mfa_verified"())) WITH CHECK ((("bucket_id" <> 'pave-vault'::"text") OR "public"."is_mfa_verified"()));

