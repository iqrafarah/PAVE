# The vault

The vault is shared account data for iOS and web. This page describes the first database shape and how it fits the mobile work. The schema is [`shared/supabase/migrations/20261110120000_vault.sql`](../shared/supabase/migrations/20261110120000_vault.sql).

> **Status (2026-11-10):** the migration is applied to the shared Supabase project; the vault tables exist and are still empty. iOS has the list and consent-picker UI, but there is no `VaultService`, upload flow, validation service, or Ayla consent endpoint yet. Change the schema only together with the web team.

## Data model

| Table | Purpose |
| --- | --- |
| `vault_folders` | User-created folders. A folder can optionally be associated with one of the shared vault categories. |
| `vault_items` | Evidence metadata: category, title, description, organisation, location, dates, current status and origin. |
| `vault_item_files` | Private Storage object metadata for files attached to an item. Extracted document text is not stored here. |
| `vault_item_skills` | Skill tags on an item, including Ayla suggestions the user has not accepted or rejected yet. |
| `vault_validation_requests` | A user's request for an organisation to validate one of their items. The validation service owns the outcome. |
| `vault_access_grants` | Consent for one Ayla request/task, including its purpose, conversation, completion/expiry and withdrawal time. |
| `vault_access_grant_items` | The exact items selected for a task. |
| `vault_access_grant_categories` | Categories selected for a task. |

Categories match `shared/ayla/reply.schema.json`: `diplomas`, `certificates`, `badges`, `projects`, `workExperience`, `internships`, `skills`, `feedback` and `reflections`. The item verification states match the mobile/web designs: `toVerify`, `verified` and `rejected`. A custom folder is separate from a category, so an item can remain in a category and also appear in a user-created folder.

## Privacy and access rules

- Every public vault table has row-level security for the owner and a restrictive `public.is_mfa_verified()` policy. A session that has not reached `aal2` cannot read or change vault records.
- File objects live in a private `pave-vault` bucket at `<user UUID>/<item UUID>/<file UUID>.<extension>`. Storage policies check MFA, the account folder and ownership of the item. Use the Storage API; do not write to `storage.objects` directly.
- Users can create unverified items and user-authored skills. Only trusted server code can assign verification outcomes or claim an item/skill came from an organisation, Ayla or an import.
- Users can request validation, read its status and cancel a pending request. Only the validation service can set the outcome.
- A grant is valid only while it is not withdrawn or completed and `expires_at` is still in the future. The default expiry is one hour; the server should mark the grant completed as soon as the task is done. Selected items and categories are stored in child tables. The Ayla Edge Function must check the active grant and these allowlists before it reads any vault content; an access request by itself grants nothing.
- File records cascade when an item is deleted, but Storage objects must be removed through the Storage API first. The future item-deletion flow must handle both operations and report cleanup failures.
- The schema deliberately does not store OCR/extracted text. The app can read a file on-device for a one-time message where the user consents, following the existing attachment rule in `docs/ayla.md`.

## Rollout sequence

1. Review categories, folder behavior, status transitions, file limits and validation ownership with Daaf and the web team.
2. Build the `VaultService` and file upload/delete flow against this model; generate and review the database types.
3. Add the server-side validation and task-consent behavior. Test that Ayla cannot read an item or category without an active, matching grant.
4. ~~Apply the migration to the shared Supabase project.~~ Done on 2026-11-10.
5. Update `ios/README.md`, `docs/ayla.md` and this page when the schema is applied or the contract changes.

The migration includes Realtime publication entries for the vault tables so other signed-in devices can refresh. Clients must still use the authenticated user's session; service-role keys belong only in trusted server functions.
