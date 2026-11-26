# Integration tests

PAVECore's Supabase services against a real (local) Supabase, with the same schema, row-level security, storage
policies and edge functions as the hosted project. Every test makes its own fresh account with two-step verification.

| Suite | What it checks |
| --- | --- |
| `AuthIntegrationTests` | sign-up, authenticator setup, sign-in with code, wrong password/code, address taken, sign-out |
| `DataIntegrationTests` | profile, plans and vault items round trip; another account sees nothing; nothing without two-step |
| `StorageIntegrationTests` | upload and download in `pave-vault`, removing, no access for others, wrong file type refused |
| `AylaIntegrationTests` | `ayla` refuses without a session or without two-step; a question reaches the model, the answer streams back and is stored; others cannot open it |

## Run

Docker must be running. From the repo root:

```sh
ios/scripts/integration-tests.sh           # starts local Supabase and the fake OpenRouter, then runs the tests
ios/scripts/integration-tests.sh --reset   # empty database first
```

`swift test` and ⌘U skip these unless `PAVE_INTEGRATION=1` is set.

## Ayla without a real model

Behind Ayla is a fake OpenRouter (`ios/scripts/fake-openrouter.mjs`, Node, no packages): it always streams the same
answer, needs no key and costs nothing. The script writes `shared/supabase/functions/.env` (git-ignored) so the local
`ayla` function uses it (`OPENROUTER_BASE_URL`). The hosted project never sets that variable and keeps using OpenRouter.
Whether the real model answers *well* is checked by the evals in `shared/supabase/functions/ayla/evals`, not here.

## The local schema

The migrations cannot build the database from nothing (`profiles`, `organizations` and more were made on the hosted
project before they were tracked), so locally the schema comes from a dump of the hosted project in
`shared/supabase/local/`, loaded as seeds (see `config.toml`). After a new migration is applied to the hosted project:

```sh
shared/supabase/local/refresh.sh                       # needs `supabase login` and `supabase link` once
ios/scripts/integration-tests.sh --reset
```

Local Supabase runs on ports 55321–55329, so it can run next to other local Supabase projects.
