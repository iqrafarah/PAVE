# PAVE

PAVE is a platform being developed for students in a Dutch government context. It helps students collect evidence of what they have learned, recognise their skills, and work towards education and employment goals.

This repository contains the website, iOS app and shared backend code. Both apps use the same Supabase backend. The interface is in Dutch.

## What PAVE does

- **Ayla:** an AI assistant with conversations, voice features and memory that students can review and manage.
- **Kluis:** a personal vault for documents, projects, certificates and other evidence, with folders and skill suggestions.
- **Settings:** account, appearance, personalisation, privacy and signed-in device settings.
- **Authentication:** email and password sign-in, password recovery and two-step verification.

The project is still in development. Onboarding, evidence verification, the complete job-search and CV flows, and planning are on the roadmap. On the web, Plan and Profiel currently show empty-state screens; the full planning and profile-sharing features are not implemented yet.

## Repository

| Directory | Contents |
| --- | --- |
| `web/` | Nuxt 4 website, using Vue 3, TypeScript and Tailwind CSS 4; dependencies managed with npm. |
| `ios/` | Native SwiftUI app and related Apple platform targets. |
| `shared/` | Shared API contracts, Supabase migrations and Edge Functions. |
| `docs/` | Authentication, Ayla and vault documentation. |

Supabase provides authentication, database access, file storage and shared Edge Functions.

## Web requirements

- Node.js 24.15 or newer within the 24.x series, with npm. This satisfies the current Nuxt and PDF-processing dependency requirements.
- Access to the team's configured Supabase project and its public connection values.
- A test account and an authenticator app for two-step verification. Accounts are currently created by an administrator; there is no public sign-up flow.

Running the web app locally connects to the Supabase project you configure. It does not create a local backend, apply database migrations or deploy Edge Functions. Ask the team for the development project and a test account.

## Run the website

From the repository root:

```sh
cd web
npm ci
```

On first setup, create your local environment file:

```sh
cp .env.example .env
```

Fill in `web/.env` with the development project's values:

```dotenv
NUXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NUXT_PUBLIC_SUPABASE_KEY=your-public-anon-or-publishable-key
```

Use the public key, never a service-role key. The `.env` file is ignored by Git. Keep an existing `.env` when returning to the project.

Start the development server:

```sh
npm run dev
```

Open [http://localhost:3000](http://localhost:3000), or the address printed in the terminal if that port is occupied. Sign in with your test account and complete authenticator setup or verification. Stop the server with `Ctrl+C`.

## Web commands

Run these commands from `web/`:

| Command | Purpose |
| --- | --- |
| `npm ci` | Install the exact dependencies from the lockfile; also prepares Nuxt's generated files. |
| `npm run dev` | Start the development server with live updates. |
| `npm run typecheck` | Check TypeScript and Vue types. |
| `npm run build` | Create the production build in `.output/`. |
| `npm run preview` | Run a local preview of the production build. |
| `npm run generate` | Generate a prerendered build; requires the configured backend and is not the default preview workflow. |

To check a change and preview the production build:

```sh
npm run typecheck
npm run build
npm run preview
```

The web app currently has no automated test suite. Check affected flows in the browser as well, including sign-in, loading, empty and error states.

## Run the iOS app

Use macOS with Xcode 26 or newer and an iOS 26 or newer simulator or device.

1. Open `ios/PAVE.xcodeproj` in Xcode.
2. On first setup, copy `ios/Config/Local.xcconfig.example` to `ios/Config/Local.xcconfig` and fill in your local values. Follow the URL format in the example file.
3. Configure the Supabase URL and public key to use the shared backend. For a physical device, also configure your development team and signing.
4. Select the PAVE app scheme and a simulator or device, then run the app.

See the [iOS documentation](ios/README.md) for device setup, demo mode, tests and platform-specific details.

## Web setup troubleshooting

- **Missing Supabase URL or key:** check both values in `web/.env`, then restart the development server.
- **Cannot sign in:** confirm you are using an account from the configured Supabase project. See the [authentication documentation](docs/auth.md) for account and MFA behaviour.
- **Ayla or vault requests fail:** these features depend on the shared database, storage policies and deployed Edge Functions. Check the configured project with the team; starting Nuxt alone does not set up these services.
- **Missing generated Nuxt types:** run `npm run postinstall` from `web/` to regenerate them. Supabase's `database.types.ts` is separate; see the coding guidance for database type generation.

## Project documentation

- [Web coding guidance](web/guidance.md) — folder structure, feature map and maintenance rules.
- [Project conventions](Conventions.md) — naming, collaboration and Git workflow.
- [Authentication](docs/auth.md) — sign-in, password recovery and MFA.
- [Ayla](docs/ayla.md) — assistant behaviour and shared API design.
- [Vault](docs/vault.md) — evidence, storage and verification model.
- [Interface language](web/guidance.md#10-interface-language-and-tone) — Dutch wording and tone.

Backend migrations and Edge Functions live in the repository's `shared/supabase/` directory. Changes to shared data or API contracts must be coordinated with the iOS team.
