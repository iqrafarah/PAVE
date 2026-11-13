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
- Folders have a colour and an icon on iOS. The columns for them come from round two below (applied). Before that, iOS kept the colour and icon on the device; that fallback still works if a column is ever missing.
- Web should use the same words; they are in `ios/PAVE/Features/Vault/VaultMessages.swift`.

## Round two (applied on 2026-11-10)

[`20261110170000_vault_cleanup_and_evidence_flow.sql`](../shared/supabase/migrations/20261110170000_vault_cleanup_and_evidence_flow.sql) tidies up and prepares the screens in Figma (add evidence in four steps, the consent picker, the vault grid and list). It was applied on 2026-11-10; iOS knows the category `other` since then.

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
| Add | Category `other` ("Overige") | The category bar in the consent picker. iOS and `shared/ayla/reply.schema.json` know it. |
| Add | `organizations.logo_url` and `vault_items.organization_id` | Logos on the cards. Only trusted server code may link an item to an organisation, so a logo never makes your own item look official. |
| Add | `vault_items.ayla_allowed_at` | Step 4 "Ayla mag dit document bekijken en gebruiken": off by default, time of agreeing, null to take it back. A task grant is still the way to share items for one question. |
| Tighten | `guard_vault_item_authority` | Also blocks changing the content of a verified or imported item (title, dates, organisation and so on); moving it, Ayla access and deleting still work. iOS already behaves this way. |

Not needed: steps 2 and 3 of adding evidence use the existing `vault_item_files` and `vault_item_skills`, and "Verifiëren" uses `vault_validation_requests`. The task list next to the consent picker (Items selecteren, Vacature kiezen, Kluis toestemming, CV genereren) is not stored yet; decide that together with the Ayla task flow.

## Round three: adding and changing evidence, example folders (not applied)

Migration `20261112120000_vault_cover_example_folders_reverify.sql`. Run it together with the web team.

- **Adding evidence on iOS** follows Figma FEDDIES 1348:1169 to 1348:2537, in four steps:
  1. **Basis:** upload a file, or add without a file; then title, type, organisation, period (a period or one date, for any type), folder and description.
  2. **Documenten:** the card shown live. A **logo** goes in the round avatar. Without a **cover**, the band takes a light tint of the logo's strongest colour (Figma 1209:56023); with a cover, the band shows that photo. Up to five documents.
  3. **Vaardigheden:** as on the web (1348:2064, 1173:15642). Skills from the vault and "Voorstel van Ayla" side by side, then your own. Ayla only proposes on request and only sees the fields of the form (Edge Function `ayla-skills`, nothing stored).
  4. **Toestemming:** the item is saved. "Ayla mag dit bekijken en gebruiken" starts off; switching it on sets `ayla_allowed_at`.
- **Files** go to the private bucket `pave-vault` at `<user>/<item>/<uuid>.<ext>`. Each gets a row in `vault_item_files` with `role` set to `document`, `logo` or `cover`, with at most one logo and one cover. Photos are stored as JPEG without their metadata (no location).
- **Changing evidence:** every item can be changed: details, logo, cover, documents, skills and Ayla's permission. Changing the details or files of a confirmed item sets it back to `toVerify`, so it is confirmed again. The guard does this for details, a trigger on `vault_item_files` for files. Only trusted server code can confirm or reject.
- **More than one folder** (migration `20261112130000_vault_item_folders.sql`, run after the one above):
  - `vault_item_folders` holds every folder of an item, and `vault_items.folder_id` keeps the first for older clients.
  - New evidence goes in the folder of its kind (the example folder, or a folder named after the kind such as "Stages") and in the folder you add it from.
  - You change the folders in the form ("Mappen", several can be ticked) and in the menu of a card ("In mappen").
- **Example folders:** every account starts with Certificaten, Diploma's, Feedback and Projecten as ordinary `vault_folders`.
  - They can be renamed, restyled and deleted.
  - Existing items without a folder move into the folder of their category, once.
  - New accounts get the folders from a trigger on `auth.users`.
  - Until the migration runs, iOS makes them for an account without any folder.
- **Ayla and the vault:** the `ayla` function reads the items with `ayla_allowed_at` set and uses them in answers and searches. It sees their details, skills and file names, not file contents. Other items stay invisible to her.

## Rollout sequence

1. Review categories, folder behavior, status transitions, file limits and validation ownership with Daaf and the web team.
2. ~~Build the `VaultService` against this model.~~ Done on iOS on 2026-11-10 (read, add, change, move, delete, folders). Still to do: file upload, and the web client.
3. ~~Apply `20261112170000_resolve_vault_validation.sql`.~~ Applied by Gianna on 2026-11-13. Still to do: deploy `vault-review`, provision reviewers, and test validation end to end. Separately add the Ayla task-consent behavior and verify grants before Ayla reads a vault item/category.
4. ~~Apply the migration to the shared Supabase project.~~ Done on 2026-11-10.
5. Update `ios/README.md`, `docs/ayla.md` and this page when the schema is applied or the contract changes.

## Notifications and organisation review (applied 2026-11-12)

[`20261112160000_notifications_and_vault_review.sql`](../shared/supabase/migrations/20261112160000_notifications_and_vault_review.sql) adds the database records needed to connect the iOS notifications screen:

- `user_notifications` is a durable, private per-user inbox for conversations, verified evidence, and verification requests. It contains display metadata and source IDs only; Edge Functions create events and the recipient can mark them read.
- `vault_validation_requests.organization_id` and `vault_validation_reviewers` provide a trusted route from a pending request to explicitly assigned reviewers. The learner's organisation text remains the display value; trusted server code must resolve it to an organisation.

The migration was applied to the shared Supabase project on 2026-11-12 (confirmed by Gianna). I have not independently queried the live database because no Supabase CLI, linked project reference, or Supabase connector is available in this workspace.

[`20261112170000_resolve_vault_validation.sql`](../shared/supabase/migrations/20261112170000_resolve_vault_validation.sql) was applied by Gianna on 2026-11-13. The `vault-review` Edge Function is implemented in the repo, but deployment to Supabase has not been confirmed. It handles request submission, reviewer inbox/detail, five-minute signed links for evidence files, atomic reviewer decisions with an audit row, and a notification to the learner after approval. Ayla replies also create an inbox event. The iOS inbox calls this function, and the reviewer detail renders the evidence card and opens the actual files in Quick Look.

For the flow to work against Supabase: deploy `vault-review` and provision each organisation's authorised reviewers in `vault_validation_reviewers` through trusted admin tooling. From the repository root, run `supabase login`, then `supabase --workdir shared functions deploy vault-review --project-ref <project-ref>`. `shared/supabase/config.toml` keeps gateway JWT verification enabled for this function. The organisation entered by the learner must match an `organizations.name`; otherwise the request is rejected. The contact email is saved on the request but no email is sent. Keep `vault_item_files` and the private `pave-vault` Storage policies owner-only for client sessions; only the reviewer function issues short-lived signed links. The function relies on the standard Supabase environment variables and validates both the user's JWT and MFA level; do not put a service-role key in iOS or web code.

Conversation inbox events currently cover the learner's own Ayla replies. The repo has no teacher-to-learner chat or relationship model, so it cannot notify an admin about another learner's chat without defining and authorizing that sharing first.

The migration includes Realtime publication entries for the vault tables so other signed-in devices can refresh. Clients must still use the authenticated user's session; service-role keys belong only in trusted server functions.
