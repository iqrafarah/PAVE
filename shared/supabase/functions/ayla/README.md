# `ayla` Edge Function

Ayla's brain for web, iPhone and Watch. The contract is in [`shared/ayla`](../../../ayla), the design in [`docs/ayla.md`](../../../../docs/ayla.md).

| File | What it does |
| --- | --- |
| `index.ts` | Checks the session (two-step verification required), stores the conversation, calls the brain |
| `brain.ts` | One turn: prompt, model, vacancy search, reply in the contract format |
| `prompt.ts` | The prompt in layers: core, device, data, output |
| `openrouter.ts` | Mistral through OpenRouter, a second model starts when the first is slow |
| `vacancies.ts` | Adzuna search. Only the search terms leave PAVE |
| `contract.ts` | Types and request checks |

## Tests

```bash
node --test shared/supabase/functions/ayla/tests/ shared/supabase/functions/ayla-voice/tests/
```

## Going live

Agree with the web team first: this adds two tables and a function to the shared project.

1. Run `shared/supabase/migrations/20261105150000_ayla_conversations.sql` in the SQL Editor.
2. Install the Supabase CLI (`brew install supabase/tap/supabase`) and log in (`supabase login`).
3. Set the secrets. They never go into git:
   ```bash
   supabase secrets set --project-ref <ref> OPENROUTER_API_KEY=… ADZUNA_APP_ID=… ADZUNA_APP_KEY=…
   ```
   Without the Adzuna keys Ayla works, and says that vacancy search is not set up yet.
4. Deploy from the `shared` folder: `supabase functions deploy ayla --project-ref <ref>`.
5. Ayla's voice is a second function, `ayla-voice` (it uses the same OpenRouter key): `supabase functions deploy ayla-voice --project-ref <ref>`.
   Both functions share `_shared/http.ts` (CORS, JSON replies, sign-in level).
