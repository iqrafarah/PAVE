# PAVE Web — Coding Guidance

Binding rules for everyone (and every AI assistant) working in `web/`.
This file extends the root `Conventions.md`; if the two conflict, `Conventions.md` wins and this file gets fixed.

Rules marked **[PROPOSED]** are not yet agreed or installed. Both web developers must approve them in a PR before they apply.

## 1. Stack

Current state of `web/` (verified from `package.json`):

| Item | Value |
|------|-------|
| Framework | Nuxt `^4.6.3` (Vue `^3.5`, vue-router `^5`) |
| Language | TypeScript (Nuxt-generated tsconfig) |
| Package manager | npm (`package-lock.json` is committed) |
| Backend | Supabase, shared with iOS |
| Styling | Tailwind CSS v4 (`tailwindcss` + `@tailwindcss/vite`) |
| Supabase integration | `@nuxtjs/supabase` module |
| Not installed yet | linter, formatter, test runner, UI component library |

- Use npm only. Never commit `pnpm-lock.yaml`, `yarn.lock` or `bun.lockb`.
- Add a dependency only after agreeing with your web teammate, and mention it in the PR.
- Use Vue's Composition API with `<script setup lang="ts">` everywhere. No Options API, no `any`, no `// @ts-ignore`.

## 2. Folder structure (Nuxt 4)

Application code lives in `web/app/`. Start in `app/pages/` to find a screen, then follow its components and composables. Use the standard Nuxt 4 directories and do not invent new top-level ones.

```text
web/
├── app/
│   ├── pages/          # Routes and screen composition; filenames determine URLs
│   ├── components/     # UI grouped by feature (see below)
│   ├── composables/    # State, browser behavior and Supabase access, by feature
│   ├── utils/          # Helpers and text constants, by feature; no Vue or Supabase
│   ├── types/          # Shared TypeScript types
│   ├── layouts/        # Default app shell and authentication shell
│   ├── middleware/     # Route guards
│   ├── plugins/        # Startup, session, appearance and cached-data setup
│   ├── assets/css/     # Global styles and design tokens in main.css
│   ├── app.vue         # App entry point
│   └── error.vue       # Full-page error screen
├── public/             # Static assets, served at their existing URLs
└── nuxt.config.ts      # Framework setup and automatic import rules
```

`node_modules/`, `.nuxt/`, `.output/` and `.data/` are dependencies or generated/local data, not application source. Keep these folders collapsed in your editor; do not edit them.

### Find a feature

The same feature names are used in `components/`, `composables/` and `utils/`:

| Feature | Start here | Supporting files |
| --- | --- | --- |
| Ayla chat | `pages/index.vue`, `pages/ayla/[id].vue` | `ayla/` |
| Ayla memory | `pages/ayla/geheugen.vue` | `components/ayla/memory/`, Ayla composables and helpers |
| Vault (Kluis) | `pages/kluis.vue` | `vault/` |
| Settings | `pages/instellingen/` | `settings/` |
| Login, passwords and MFA | `pages/login.vue`, password and MFA pages | `auth/` |
| Navigation and app shell | `layouts/default.vue` | `layout/` |
| Reusable behavior and helpers | — | `composables/shared/`, `utils/shared/` |

The larger component folders have one extra level:

- `components/ayla/`: `chat/`, `composer/`, `history/`, `memory/`, `voice/` and `shared/`. `AylaChatView.vue` and `AylaTitleBar.vue` stay at the feature root as entry points.
- `components/vault/`: `add/`, `items/`, `folders/`, `forms/` and `shared/`. `VaultLibrary.vue` and `VaultToolbar.vue` stay at the feature root.

A feature's `shared/` folder contains components used in multiple parts of that feature. App-wide layout components stay in `components/layout/`.

### Keep it manageable

- Put new files in the existing feature folder. Add a subfolder when it groups a meaningful part of a large feature; avoid folders for a single tiny helper.
- Component filenames include the feature prefix, such as `AylaComposer.vue` or `VaultItemCard.vue`. Names must be unique across the app.
- Nuxt uses component filenames without directory prefixes (`pathPrefix: false`), so moving `AylaComposer.vue` within `components/ayla/` keeps `<AylaComposer>` working. [Nuxt component naming](https://nuxt.com/docs/4.x/directory-structure/app/components#component-names).
- `nuxt.config.ts` scans nested composable and utility folders. Existing automatic imports such as `useVault()` still work. Keep exported names unique and update explicit imports when moving files. [Nuxt nested imports](https://nuxt.com/docs/4.x/directory-structure/app/composables#how-files-are-scanned).
- Use an explicit path for type imports, for example `~/composables/auth/useAuth`.
- Keep route files in `pages/`; moving them can change URLs. Keep assets at their existing public paths unless you also update every reference.
- Extract a component for a distinct UI responsibility or reuse. Keep small one-off markup and helpers with their owner; do not create empty placeholders for future features.
- Do not create `web/shared/`. Nuxt 4 reserves it for code shared between app and server, and it would be confused with the repo-root `shared/`.
- Only add `web/server/` if a server route is truly needed (see §6).
- A file has one responsibility. Review components over about 200 lines for meaningful splits, but keep small one-off markup and helpers with their owner.

## 3. Naming and readability (from Conventions.md)

| Thing | Rule | Example |
|-------|------|---------|
| Vue components | `PascalCase.vue` | `ProfileCard.vue` |
| Pages | `kebab-case.vue` | `job-listings.vue` |
| Composables | `useXxx.ts`, camelCase | `useVaultSkills.ts` |
| Functions, variables | `camelCase` | `getUserProfile` |
| Types, interfaces | `PascalCase`, no `I` prefix | `UserProfile` |
| Constants | `UPPER_SNAKE_CASE` only for true constants | `MAX_UPLOAD_MB` |
| Branches | `feat/web/<name>`, `fix/web/<name>` | `feat/web/dashboard` |

- Component names are at least two words, except pages and layouts.
- Props and emits are typed with `defineProps<{...}>()` and `defineEmits<{...}>()`.
- All code, comments, commits and PRs are in English.
- Do not leave AI-style or obvious comments. Comment only the "why", never the "what".

### Readable code

Write code a teammate can understand in one read. Simple and boring beats clever.

- **Clear names over comments.** A name says what a thing is or does: `isProfileComplete`, not `flag`; `fetchSkills`, not `doStuff`. No abbreviations except common ones (`id`, `url`).
- **Booleans read like a question:** `isLoading`, `hasCertificates`, `canEdit`.
- **Functions do one thing** and stay short (aim for under about 25 lines). If you need "and" to describe it, split it.
- **Early returns** instead of deep nesting. Maximum two levels of nesting in a function.
- **No magic values.** Give numbers and strings a named constant (`MAX_UPLOAD_MB`, not `5`).
- **Explicit over clever.** No nested ternaries, no chained one-liners that hide logic, no unexplained regex. Use a named variable for each step instead.
- **Use `async`/`await`**, not long `.then()` chains.
- **Keep templates simple.** Move logic out of `<template>` into a `computed` or a function with a good name.
- **Order inside `<script setup>`:** imports, props and emits, state (`ref`), computed values, functions, lifecycle hooks.
- **No dead code.** Delete unused code, imports and commented-out blocks. Git remembers them.
- **Do not repeat yourself, but do not over-abstract either.** Extract a helper when the same code appears a third time, not before.
- **Consistent formatting** comes from the formatter, not from personal taste.
- **Review test:** if a reviewer needs you to explain a piece of code, rewrite it until they do not.

## 4. Components

- Components render UI and emit events. They never call Supabase directly (see §5).
- Keep presentational components free of data fetching; fetch in the page or in a composable and pass data down via props.
- **Styling is Tailwind CSS only.** No other CSS framework, no inline `style=""`, and no per-component `<style>` blocks, except for something Tailwind cannot express (for example a keyframe animation). Explain such an exception in the PR.
- **Design tokens live in one place:** the `@theme` block in `app/assets/css/main.css`. Every color, font and spacing value from Figma is added there once and used through classes (`bg-brand`, `font-heading`). Never hard-code hex colors or pixel values in components (no `bg-[#1a2b3c]`, `w-[137px]`).
- **Keep class lists readable.** Write classes in a consistent order: layout, spacing, size, typography, color, state (`hover:`, `focus:`), responsive (`md:`). If the same group of classes is repeated, make it a component (`BaseButton.vue`), not a copied string.
- **Mobile first.** Write the base style for small screens and add `sm:`, `md:`, `lg:` for larger ones.
- **State styling uses variants** (`hover:`, `focus-visible:`, `disabled:`), and every interactive element has a visible focus style.
- Every user-facing string that may need translation goes in one place **[PROPOSED]** (decide on i18n before the first real page).
- Accessibility baseline: semantic HTML, labelled form fields, visible focus, alt text on images.
- Every data-driven view handles three states: loading, error, empty.

## 5. Supabase on the web (must match iOS)

Supabase is the single source of truth. The web app is a client of it, not a second backend.

1. **One client.** Create the Supabase client in exactly one place **[PROPOSED: `@nuxtjs/supabase` module]**. Never call `createClient` anywhere else.
2. **One data layer.** All reads and writes live in feature folders under `app/composables/` (for example `vault/useVault.ts`). Pages and components call composables, never `supabase.from(...)`.
3. **Anon key only.** Only the public URL and anon key are ever used in the browser. The service-role key must never appear in `web/`, in `nuxt.config.ts`, in `runtimeConfig.public`, or in any commit.
4. **RLS is the security.** Never bypass or work around Row Level Security. If a query fails because of RLS, fix the policy through a migration (see §7), not the client.
5. **Schema names are law.** Table and column names are used exactly as in the database (`snake_case`). Map to camelCase in one mapper per entity inside the composable, not scattered through components.
6. **Generated types.** Database types come from `supabase gen types typescript` into `app/types/database.types.ts`. Never hand-write or edit that file. Derive domain types from it (`Tables<'profiles'>`).
7. **No web-only data.** Never create tables, columns, enums or storage buckets just for the web. Anything that is user data is shared with iOS by default.
8. **Auth.** Use Supabase Auth only: same providers, same email flows and same session behaviour as iOS. Route protection is done in `middleware/` and is only UX; real protection is RLS.
9. **Storage.** Use only the agreed bucket names and path scheme from `docs/` (see §7). Never invent a path.
10. **AI consent.** Any feature that sends personal vault data to an AI must check the user's stored consent first and must fail closed when consent is missing. The consent flag lives in the database, not in local state.
11. **Errors.** Never swallow Supabase errors. Return `{ data, error }` from composables, show a user-friendly message, and never display raw database errors.
12. **Secrets.** Real values live only in `.env` (git-ignored). Keep `.env.example` with variable names and no values.

## 6. Server routes

Default: **no** Nuxt server routes. Logic that both platforms need (validation, AI calls, permission checks) belongs in Supabase (Postgres functions or Edge Functions), so iOS gets it too. A Nuxt server route is allowed only for web-only concerns, and the PR must explain why it cannot live in Supabase.

## 7. Cross-platform contract

Anything below that changes must be agreed with the iOS team before merging.

- **Contract-changing:** database schema, RLS policies, auth settings, storage buckets and paths, Edge Functions, AI-consent rules.
- Every PR that touches the contract has a **"Cross-platform impact"** section stating what changes, which iOS models are affected, and whether it is backwards compatible.
- Prefer additive, backwards-compatible changes (new nullable column) over breaking ones (rename, drop, type change). A breaking change needs a deprecation plan.
- Do not assume a feature that works on web works on iOS.

### Where the contract is documented **[PROPOSED]**

| What | Where |
|------|-------|
| SQL migrations (only way to change the schema) | `shared/supabase/migrations/` |
| Schema reference per table (columns, types, relations, RLS) | `docs/database/<table>.md` |
| Auth rules (providers, redirect URLs, session handling) | `docs/auth.md` |
| Storage buckets, paths and policies | `docs/storage.md` |
| AI consent rules | `docs/ai-consent.md` |
| Decisions | `docs/decisions/NNNN-title.md` (short ADRs) |
| Change log of shared changes for iOS | `docs/contract-changelog.md` |

`Conventions.md` already lists `shared/supabase/migrations/` and the Supabase cross-platform rules. The per-table docs and the other files in `docs/` are still proposals until the iOS team agrees.

## 8. Quality, Git and Definition of Done

- No linter, formatter or tests exist yet. Run `npm run typecheck` and `npm run build` before opening a PR. **[PROPOSED]** add ESLint (`@nuxt/eslint`), Prettier config and Vitest, then also require `npm run lint` and `npm run test`.
- Never push to `main` or `dev`. Branch from `dev`, open a PR, get at least one approval from another team member.
- Commits are small, in English, imperative mood ("Add profile card").
- A task is done only when it meets the Definition of Done in `Conventions.md`.

## 9. Rules for AI coding assistants

1. Read `Conventions.md` and this file before changing anything, then inspect the existing code and match its patterns.
2. Work only in `web/`. Do not touch `ios/`. Touch `shared/` or `docs/` only when the task is a contract change, and say so.
3. Do not add dependencies, folders, patterns or abstractions that this file does not describe. Ask first. Style with Tailwind classes and the tokens in `main.css` only.
4. Never bypass RLS, expose the service-role key, or create web-only database structures.
5. Any database or contract change must come with the migration, the updated docs and the "Cross-platform impact" note, so the iOS team can update their Swift models.
6. Write simple, easy-to-read code that follows "Readable code" in §3. Do not generate unnecessary comments, placeholder code or dead code.
7. Write all interface text in Dutch following section 10 and `docs/ui-teksten.md`.
8. When something is unclear or conflicts with these rules, stop and ask instead of guessing.

## 10. Interface language and tone

All text the user sees (labels, buttons, placeholders, errors, emails shown in the UI) is **Dutch**, in plain, friendly language. Code, comments and commits stay English.

- The source of truth is `docs/ui-teksten.md`: tone rules, a glossary and standard messages shared with iOS. Read it before writing any UI text, and use the exact wording from it when the text already exists. Add new texts there in the same PR.
- Address the user with "je/jij", never "u". Use everyday words and short sentences. No jargon, no corporate phrases.
- PAVE is not an organization app. Never write "organisatie", "IT-support", "your organization's email" or similar. Say "e-mailadres" and refer to "PAVE-support" when the user needs help.
- Error messages say what happened and what the user can do next. Never blame the user, and never reveal whether an email address has an account.
- Do not scatter strings through templates when they repeat: keep repeated messages in one place (for example `app/utils/shared/messages.ts`) so web and iOS stay in sync with `docs/ui-teksten.md`.
- The Figma designs are in English. Translate them using the glossary instead of copying the English text.
