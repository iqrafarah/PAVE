# The vault

The vault is shared account data for iOS and web. This page describes the first database shape and how it fits the mobile work. The schema is [`shared/supabase/migrations/20261110120000_vault.sql`](../shared/supabase/migrations/20261110120000_vault.sql).

> **Status (2026-11-10):** the migration is applied to the shared Supabase project. iOS reads and writes it through `SupabaseVaultService` (PAVECore): items with their accepted skills and file names, folders, adding and changing your own items, moving them to a folder, and deleting (files first, through the Storage API). There is no file upload, validation service or Ayla consent endpoint yet. Change the schema only together with the web team.

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

## How iOS shows it

- Status labels: `verified` is "Geverifieerd", `toVerify` is "Niet bevestigd" (not "Verifiëren": nobody is checking it unless a validation request exists), `rejected` is "Afgewezen". Origin: `user` "Zelf toegevoegd", `organization`/`import` "Van een organisatie", `ayla` "Via Ayla".
- New items are always `source = user` and `toVerify`; the app never sends `verification_status` or `source`. An item that is `verified`, or that comes from an organisation, cannot be changed in the app, so a confirmed item never shows edited content under a confirmed label.
- Dates use `start_date`/`end_date`/`is_current` for categories with a period, and `issued_on` for diplomas, certificates and badges. Cards show them as "mrt 2025 - dec 2025", "nov 2025 - nu" or "jul 2024".
- Folders have a colour and an icon on iOS. The columns for them are in the round-two proposal below (**not applied**). Until it is applied, iOS saves only the name and keeps the colour and icon on the device.
- Web should use the same words; they are in `ios/PAVE/Features/Vault/VaultMessages.swift`.

## Round two (proposal, not applied)

[`20261110170000_vault_cleanup_and_evidence_flow.sql`](../shared/supabase/migrations/20261110170000_vault_cleanup_and_evidence_flow.sql) tidies up and prepares the screens in Figma (add evidence in four steps, the consent picker, the vault grid and list). Apply it only after the web team agrees.

What is in Supabase on 2026-11-10 (read-only check with the publishable key):

| Table | From | Used by |
| --- | --- | --- |
| `profiles` (id, full_name, preferred_name, email, avatar_url, role, organization_id, program, created_at, updated_at) | web team, not in our migrations | Ayla function (name) |
| `organizations` (id, name, created_at) | web team, not in our migrations | `profiles.organization_id` |
| `ayla_conversations`, `ayla_messages`, `ayla_memories`, `ayla_settings` | our migrations | iOS, Ayla function |
| the 8 `vault_*` tables and the `pave-vault` bucket | `20261110120000_vault.sql` | iOS (items, files, skills, folders); web not yet |

What it changes:

| | Change | Why |
| --- | --- | --- |
| Remove | The functions and `private` tables of the first password reset (`get_verified_totp_secret`, `create_password_reset_token` and four more) | Taken out of the repo in fe5e73b, called by nothing; one of them could read authenticator secrets. All with `if exists`, so it also runs if they were never applied. |
| Remove | `vault_folders.category` and `.description` | The category folders are the item categories, not rows; no screen shows a folder description. |
| Add | `vault_folders.color` and `.icon` | The "Nieuwe map" sheet. Replaces the earlier proposal `20261110150000`. |
| Add | Category `other` ("Overige") | The category bar in the consent picker. **iOS and `shared/ayla/reply.schema.json` must know `other` before an item uses it**: the current iOS app skips categories it does not know. |
| Add | `organizations.logo_url` and `vault_items.organization_id` | Logos on the cards. Only trusted server code may link an item to an organisation, so a logo never makes your own item look official. |
| Add | `vault_items.ayla_allowed_at` | Step 4 "Ayla mag dit document bekijken en gebruiken": off by default, time of agreeing, null to take it back. A task grant is still the way to share items for one question. |
| Tighten | `guard_vault_item_authority` | Also blocks changing the content of a verified or imported item (title, dates, organisation and so on); moving it, Ayla access and deleting still work. iOS already behaves this way. |

Not needed: steps 2 and 3 of adding evidence use the existing `vault_item_files` and `vault_item_skills`, and "Verifiëren" uses `vault_validation_requests`. The task list next to the consent picker (Items selecteren, Vacature kiezen, Kluis toestemming, CV genereren) is not stored yet; decide that together with the Ayla task flow.

## Rollout sequence

1. Review categories, folder behavior, status transitions, file limits and validation ownership with Daaf and the web team.
2. ~~Build the `VaultService` against this model.~~ Done on iOS on 2026-11-10 (read, add, change, move, delete, folders). Still to do: file upload, and the web client.
3. Add the server-side validation and task-consent behavior. Test that Ayla cannot read an item or category without an active, matching grant.
4. ~~Apply the migration to the shared Supabase project.~~ Done on 2026-11-10.
5. Update `ios/README.md`, `docs/ayla.md` and this page when the schema is applied or the contract changes.

The migration includes Realtime publication entries for the vault tables so other signed-in devices can refresh. Clients must still use the authenticated user's session; service-role keys belong only in trusted server functions.
