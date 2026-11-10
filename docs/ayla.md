# Ayla

> **Status (2026-11-10):** the brain (`shared/supabase/functions/ayla`) and Ayla's voice (`shared/supabase/functions/ayla-voice`) run on the shared Supabase project. iOS has chat, voice, chat history and the first vault list/selection UI. Memory tables are applied. The vault schema (`shared/supabase/migrations/20261110120000_vault.sql`) is applied, but has no client/service or Edge Function integration yet. Task consent is not enforced by the server yet. See [docs/vault.md](vault.md) for the model and rollout sequence. Changes to the contract or shared database require iOS and web review (see `Conventions.md`).

## The idea

There is **one Ayla per account**, not one per app. Ayla works like an operating system for PAVE: the conversation, the memory and the permissions belong to the account, and every device is just a way to talk to her.

```
     Apple Watch            iPhone                Web
   (speak, short)      (speak + chat)        (speak + chat)
          \                   |                   /
           \                  |                  /
            ────────────  one account  ────────────
                              |
                       ┌──────┴───────┐
                       │  Ayla brain  │   prompt, rules, model, consent
                       └──────┬───────┘
              ┌───────────────┼────────────────┐
        Conversations      Memory          Vault + consent
         (per account)   (per account)      (per account)
```

Speech recognition stays on each device (watchOS, iOS, browser). Only text goes to the brain. Ayla's voice comes from the server, so she sounds the same everywhere.

## Principles

- **The user keeps control.** Ayla supports and proposes, she never decides or acts without confirmation. This is the main finding of the SURF/Npuls research.
- **One Ayla, many devices.** Never a separate Ayla for web and iOS.
- **Consent is enforced on the server**, not trusted from the app. Ayla only sees the vault sections the user allowed, and the user can withdraw that at any time.
- **Honesty.** Ayla never pretends she saved, shared or sent something she did not.
- **Dutch, B1 level.** All user-facing text is Dutch.

## Decisions so far

| Topic | Decision |
| --- | --- |
| Conversations | Separate conversations with a history, like ChatGPT or Claude. Ayla gives each one a title. |
| Switching devices | When you start on the Watch, you can continue on your phone with one tap. |
| Starting on the Watch | Ayla asks: continue the last conversation or start a new one? The Watch starts from the Action button or a watch face complication. A third-party app cannot listen for "Hey Ayla". |
| Memory | Short notes the user can see and delete. Ayla **proposes** a note ("Shall I remember that…?") and only saves it after the user says yes. Allowed categories: preferences, goals, doubts and feelings, personal situation. The user can turn each category off. Never stored: BSN, medical data, support needs. |
| Voice | One voice from the server for all devices. Speech-to-text stays per device. |
| Initiative | Ayla may start contact with notifications on phone and Watch, but only about: plan deadlines and steps, answers to validation requests, and reflection questions. Suggestions from Ayla are shown softly in the app, not as notifications. |
| Notification content | The user chooses per type of notification whether the lock screen shows a general text or the details. |
| Context | Ayla knows which screen or item is open, for example the internship in the vault. The app sends only an id; the server reads the item, and only with consent. |
| Voice control | Opening and navigating ("go to my plan") needs no confirmation, because it changes nothing. Everything that changes data is a proposal the user confirms. |
| Actions | Later Ayla can also save things (vault item, plan, profile draft) **after confirmation**. The reply format has room for it, but we build talking first. |
| Proposals | An open proposal expires after a few days. Ayla can propose it again if it still fits. |
| Two devices at once | Both messages go into the conversation in the order the server received them. Ayla answers both. |
| Transparency | A line under each answer shows what Ayla used, for example "Used: work experience, skills". Tapping it shows the details. |
| Retention | Conversations are kept until the user deletes them, one at a time or all at once. Deleting removes them on every device. |
| Offline | The Watch says clearly that Ayla is not reachable. It does not queue or guess. |
| Cost limits | No limit during the prototype, but an emergency cap on credits in OpenRouter. |
| Model provider | OpenRouter, with the same Mistral models as in the demo (see below). |
| Where Ayla runs | A Supabase Edge Function (`ayla`) in the shared project. It runs with the user's own session, so row level security and two-step verification apply. |
| Real data only | No example data in the apps. Ayla only knows what the user tells her and, later, the vault items the user allows. |
| Consent | Per task, per item or category: the user picks what Ayla may see for that task ("2 items selected"). The grant belongs to that task and can be withdrawn. |
| CV | Ayla returns a structured CV (profile, experience, skills) that the user edits in the app, not only text in the chat. |
| Without AI | In Settings the user can choose "Traditioneel" instead of "AI-begeleid". Then Ayla disappears from the app and vault, plan and profile keep working without her. |

**Constraint for notifications:** pushes sent from a server need the paid Apple Developer Program. With a free account only local notifications (scheduled by the app itself) work. Web notifications are separate.

## What the Figma design adds

Figma flows reviewed: Onboarding, Vacature zoeken, Document aan kluis toevoegen, Mobiel voorbeeld 1 and 2. This changes the design in six ways:

1. **Replies are cards, not only text.** Examples in the design: a selection of categories with item counts, a consent request, a list of vacancies with salary and skill-gap, skill suggestions for a piece of evidence, a CV. The reply format therefore needs `blocks`, each with a type the apps know how to draw.
2. **Consent is per task and per item** ("Alle items 50, Diploma's 5, Certificaten 15", then "2 gegevens geselecteerd" and the step "Kluis toestemming"). It is not a standing permission per vault section.
3. **The model uses tools, it does not guess.** The server runs the tools and gives the results to the model: search the vault (needs consent), search vacancies, build a CV, open a screen. The model explains and compares, so it can never invent a vacancy, salary or diploma.
4. **History shows the steps of a flow:** a title, a time and a line below ("2 bewijsstukken gekozen", "Voor IT coördinator • Pinterest"). Conversations can be pinned ("Vastgezet").
5. **Ayla opens parts of the app.** "You have nothing about your LiveWall internship yet. Want to add something?" opens the add-evidence flow. Ayla also suggests skills for an item ("Voorstel van Ayla"), which the user accepts, edits or removes.
6. **AI is a choice** (Instellingen, Werkwijze: AI-begeleid or Traditioneel). Items keep their own status (Geverifieerd, Verifiëren, Afgewezen); Ayla never sets it.

### Where vacancies come from

The vacancy card in the design shows: company logo, title, company and city, full-time or part-time, a monthly salary range, and a **skill-gap**. Ayla works out the skill-gap by reading the requirements of the vacancy and comparing them with the vault items the user allowed for this task.

What each source can fill (Adzuna checked against its documentation, web search is general knowledge and should be tested):

| Card field | Adzuna API | Web search (OpenRouter `:online`) |
| --- | --- | --- |
| Title | `title` | From the page |
| Company | `company.display_name` | Usually |
| City | `location.display_name` | Usually |
| Full-time or part-time | `contract_time`, sometimes empty | Sometimes |
| Salary | `salary_min` and `salary_max`, **per year**, with `salary_is_predicted` for estimates | Often not stated in Dutch vacancies |
| Logo | not provided | not provided |
| Requirements (for the skill-gap) | **only a snippet** of the description | the whole page |

Conclusions:

- Neither source fills the whole card alone. Web search is unreliable for salary and logo and forces the model to extract fields from loose text, which invites invented values.
- The API gives clean card data but only a snippet of the text. The skill-gap needs the full requirements. Fetching the full text through the vacancy link needs a check of the terms of Adzuna and of the employers first.
- LinkedIn is not possible (no public job search API, scraping breaks its terms).

Decision (2026-11-05): **Adzuna**, no example vacancies. Ayla only discusses what Adzuna returned and says honestly that she saw part of the text. The skill-gap stays empty until the vault exists. Full vacancy texts only if the terms allow it.

Rules for the card:

- A field that is empty is not shown and never filled in. An estimated salary is labelled "geschat", and a yearly salary is shown per month.
- Without a logo the card shows a monogram.
- Every item in the skill-gap shows which requirement of the vacancy it comes from, so the user can check it. It is a possibility, not a fact.
- Only search terms leave the system, never personal data. The API key stays on the server.

## What belongs to the account (shared state)

These are proposals for tables, all with row level security on the user, like `profiles`.

| What | Content | Notes |
| --- | --- | --- |
| Conversations | id, title, created, last message, device it started on | Deleting a conversation removes it on every device |
| Messages | conversation, role (user or Ayla), text, device, time | Append only. The server sets the order |
| Vault | Folders, evidence items, file metadata, skill tags and validation requests | User-owned; private files; only trusted server code sets verification outcomes |
| Memory notes | text, category, source conversation, time | Visible and deletable, with a switch per category. Never sensitive data (BSN, medical, support needs) |
| Consent grants | Ayla request/task, conversation, selected items or categories, grant, completion, expiry and withdrawal times | Valid for that task only. The server must check the active allowlist before reading vault data |
| Proposals | type, summary, status (open, confirmed, rejected, expired) | Ayla proposes on the Watch, you confirm on the phone |
| Notification settings | per type: on or off, general or detailed | One source for all devices |

Devices see changes live through Supabase Realtime, so a message from the Watch shows up on web.

## What differs per device (not a different Ayla)

The app sends a `device` and an `input` value with each message, and the brain adapts the style:

| Device | Style |
| --- | --- |
| Watch | One or two sentences. Choices such as Yes or No. Nothing sensitive spoken aloud |
| iPhone | Speak or type, longer answers, confirmation buttons |
| Web | Same as the phone, on a large screen |

## The brain

A single place that builds the prompt, calls the model and returns a structured reply. The apps never contain prompts or API keys.

1. **Prompt in layers:** the fixed core (personality, rules, limits), a style per device, the data the user allowed, then the conversation.
2. **Model call:** the models from the demo, with fallback: if the first model is slow, the next one starts alongside it.
3. **Reply format** instead of tags hidden in the text:
   - `text`: what Ayla says
   - `question` and `choices` (at most three): for Yes or No on the Watch
   - `accessRequest`: vault sections she wants to see, so the app can ask for consent
   - `proposedAction`: something she suggests, which the user confirms
   - `blocks`: cards the apps draw (selection, consent request, vacancies, skill suggestions, CV), each with a type from a fixed list
   - `navigation`: a screen to open, chosen from a fixed list the apps map to their own routes
   - `usedData`: which allowed sections were used, set by the server so it is always true

Each message also carries `device`, `input` (voice or text) and optionally `context` (the open screen or item id) and `attachments` (up to 3 files the user added with the plus button; the app reads their text on the device and sends only that text, which Ayla sees in that one message and which is not stored).

### Models (from the demo)

| Job | Model |
| --- | --- |
| Answers | `mistralai/mistral-medium-3.1` |
| Fallback | `mistralai/mistral-small-3.2-24b-instruct`, `mistralai/mistral-large-2512` |
| Voice | `openai/gpt-audio-mini`, voice `coral` |

## Voice mode

Like voice mode in ChatGPT and Claude: hands-free turns in the normal chat, with the pixel orb from the demo.

1. The app recognises speech on the device (Dutch) and sends the question after 1.2 seconds of silence, with `input: "voice"`.
2. `ayla` answers as usual; for spoken questions the prompt asks for two or three short spoken sentences.
3. The app sends the answer text to `ayla-voice`, which streams Ayla's voice (pcm16, 24 kHz, mono) from `openai/gpt-audio-mini` (voice `coral`). The demo's stop rules keep the voice from talking past the text.
4. The app plays the audio as it arrives and listens again. The user can interrupt by talking (echo cancellation keeps Ayla's own voice out of the microphone) or by tapping the orb.

Only text leaves the device: the user's voice never does. The text of Ayla's answer goes to OpenAI through OpenRouter, so it may contain whatever the answer says (for example the user's name).

## What is built (2026-11-10)

### On the server

| Part | What it does |
| --- | --- |
| `ayla/index.ts` | Checks the session (two-step verification required, else `insufficient_aal`), creates or finds the conversation, stores the question and the answer |
| `ayla/prompt.ts` | The prompt in layers: core, device, data, output |
| `ayla/openrouter.ts` | Mistral through OpenRouter; a second model starts when the first is slow |
| `ayla/vacancies.ts` | Adzuna search; only search terms leave PAVE |
| `ayla/brain.ts` | One turn: prompt, model, vacancies, reply in the contract format |
| `ayla-voice/` | Reads one answer out loud and streams the audio (pcm16, 24 kHz, mono) |
| `migrations/…_ayla_conversations.sql` | `ayla_conversations` and `ayla_messages` with row level security; both are in the Realtime publication |
| `migrations/…_ayla_conversation_pins.sql` | `pinned_at` for "Vastgezet". Until it runs, the apps hide pinning |
| `ayla/memory.ts`, `migrations/…_ayla_memory.sql`, `…_ayla_memory_categories.sql` | Account memory and categories; applied on 2026-11-09 |
| `migrations/20261110120000_vault.sql` | Vault records, private files, skills, validation requests and task grants; applied on 2026-11-10 |

The existing policy "Own conversations" (`for all`) already allows renaming and deleting your own conversations; deleting removes the messages too (`on delete cascade`). No extra database change is needed for that.

### On iOS

Details and the reasons behind each choice are in `ios/README.md` (section Ayla).

- **Client** (`ios/PAVECore`): `SupabaseAylaService` sends questions, reads, pins, renames, deletes and searches conversations, and streams the voice. Renaming and deleting ask for the changed row back (`Prefer: return=representation`): an empty answer means a policy refused it, and the app puts the chat back with a message. `AylaRealtime` listens to `ayla_conversations` over Supabase Realtime so the list updates by itself.
- **Chat:** a welcome that types itself out, files read on the phone (only their text is sent, for that one message), dictation, vacancy cards in a sheet from below.
- **Voice mode:** speech is recognised on the phone in Dutch and sent as text after 1.2 seconds of silence; the answer is read out by `ayla-voice` while it streams in; echo cancellation lets you interrupt Ayla. The pixel orb can be dragged between full screen and the conversation, as in ChatGPT.
- **Chats:** grouped by date (Vastgezet, Vandaag, Gisteren, Afgelopen 7 dagen, Afgelopen 30 dagen, Eerder), swipe to pin, rename or delete, delete with a few seconds to undo, select several, search in titles and in messages, live updates, and an opt-in (off by default) to put chat titles in the iPhone's own search.
- **Menu:** laid out like ChatGPT, a sidebar on iPad and the open iPhone Duo held sideways, and a layout around the fold of a partly folded iPhone Duo.
- **Messages:** press and hold to copy, select text, have Ayla read it out, get a new answer to the last question, or change your last question. The last two first remove the last question and answer from `ayla_messages` (`removeLastTurn`, allowed by the policy "Delete own messages"), so Ayla does not see the old answer in the history.
- **Around the chat:** a half-typed message is kept per chat on the device, a button jumps back to the newest message, and offline the app says so calmly instead of failing.
- **Voice mode:** a haptic at every turn, and captions that follow Ayla sentence by sentence (on by default; the user can hide all text under the orb).
- **Memory:** "Zal ik dit onthouden?" under a reply, and "Wat Ayla over je weet" in Settings (see "Memory").
- **Vault:** the mobile list and consent-picker UI are in progress; the schema is applied, but persistence, uploads, validation and server-enforced task grants are not connected yet (see [docs/vault.md](vault.md)).
- **Outside the app:** Siri and Shortcuts phrases, the Action button, Control Center buttons and widgets start a voice conversation or a new chat. They only open the app (behind the PIN), never show anything from it.

## Memory ("Wat Ayla over je weet")

Ayla remembers things across conversations, but only what the user kept. This follows the product rule that Ayla asks before anything is stored.

- **Suggest, then confirm.** When the user tells something lasting that helps with learning or work, Ayla adds `memories: [{ text, category }]` to her reply: every fact on its own, one short line in the "je" form, at most 4 per reply. "Ik studeer ICT op Fontys en werk als leidinggevende bij de Plus" becomes two facts (education and work). The app shows "Zal ik dit over je onthouden?" with a tick per fact, Onthouden and "Nee, niet nodig". Only the ticked facts are saved, with the user's own session, into `ayla_memories` (`source = 'ayla'`). Ayla's text never claims she remembered something. Older replies with a single `memory: { text }` are still read.
- **Out of date.** When what the user tells makes one of their notes untrue (a current job, a study they follow now, where they live, a goal that changes), the suggestion carries `replaces`: the exact text of that note. "Ik werk nu bij Albert Heijn" suggests the new job and taking "Je werkt als leidinggevende bij de Plus" away; "Ik werk niet meer bij de Plus" only the taking away (empty `text`). The server keeps `replaces` only when it really is one of the user's notes. The app shows it as its own line, struck through, ticked like the rest, and the button says "Bijwerken" or "Weghalen". Untick it, or tap "Nee, niet nodig", and the old note stays: someone can have two jobs. Never suggested for what stays true: a diploma or finished study, a past internship or job, a skill.
- **Categories** (`category`): `education` Opleiding, `work` Werk en stages, `goals` Doelen, `skills` Vaardigheden, `values` Wat je belangrijk vindt, `workStyle` Hoe je wilt werken, `interests` Interesses en hobby's, `personal` Over jou. An unknown category becomes `personal`. "Wat Ayla over je weet" is grouped by them; the user picks one when adding or changing a note.
- **Never suggested:** health, religion, politics, sexuality, origin, money, passwords, or anything about other people (the prompt layer in `ayla/memory.ts`), nor a fact she already has, also in other words: when at least 3 of every 4 meaningful words of a suggestion are already in a note, it is dropped (`covers`, on the server and in the app, with the same list of small words).
- **Used in every conversation**, on every device: `index.ts` reads the newest 40 notes and the setting with the user's session (`loadMemory`) and lists them in the prompt between `<onthouden>` tags, as data and never as instructions.
- **The user is in charge** ("Wat Ayla over je weet" in Settings): see every note with where it came from and when, change it, delete it, write one yourself (`source = 'user'`), forget everything, or turn the memory off (`ayla_settings.memory_enabled`). Off: Ayla uses none of the notes and suggests nothing; the notes stay until the user deletes them. Without a settings row the memory is on, which is safe because nothing is stored without a tap.
- **Category column:** `migrations/20261109160000_ayla_memory_categories.sql`, applied on 2026-11-09. Without it, the function reads `*` and treats every note as `personal`, and the iOS app saves notes without a category when Supabase answers `PGRST204`.
- **Tables:** `migrations/20261109120000_ayla_memory.sql` (`ayla_memories`, `ayla_settings`, row level security, two-step verification), applied on 2026-11-09. Without it, the function remembers nothing and never suggests (the query fails, `status: 'unavailable'`), and the apps say the memory is not available yet (PostgREST `PGRST205` becomes `AylaError.notSetUp` on iOS).
- **Web:** show the same card under a reply with `memories`, insert every ticked fact into `ayla_memories` (`text`, `category`, `source: 'ayla'`, `conversation_id`) on confirm, and offer the same "Wat Ayla over je weet" page. The tables, rules and texts are shared, so the web needs no server change.

## Streaming and "Gebaseerd op"

- **Streaming.** Send `Accept: text/event-stream` to `ayla` and the answer comes as server-sent events: `start` (`{ conversationId }`, before anything is written), `text` (`{ text }`, everything written so far), then `reply` (the whole reply) or `error`. Without that header nothing changes. Closing the connection stops the model; what was written so far is saved as Ayla's answer, as in ChatGPT. The function reads the `text` field out of the half-written JSON (`partialText`); the first model that starts writing answers and the others stop.
- **`usedMemories`.** The notes are numbered in the prompt; the model returns the numbers it used and the server turns them into the notes (`usedNotes`). The apps show "Gebaseerd op" under the answer.

## Calling Ayla from the web

Everything the web needs to work with Ayla the way the iPhone does. Nothing has to change on the server: the functions, tables and security rules are shared, so a conversation started on the iPhone continues on the web and the other way round.

### How Ayla works, in short

```
browser ──► Supabase Edge Function `ayla` ──► OpenRouter (Mistral) for the answer
   │              │                       └─► Adzuna when the user asks for vacancies
   │              ├─ reads: the conversation so far, the user's first name, what Ayla remembers
   │              └─ writes: the question and the answer to `ayla_messages`
   │
   ├────────────► Edge Function `ayla-voice` ──► Ayla's voice (audio stream)
   │
   └────────────► tables, straight from the browser: conversations, messages, memory
                  (row level security: only the user's own rows, only after two-step verification)
```

- The brain lives on the server only. The browser never talks to OpenRouter or Adzuna and holds no keys besides the publishable one.
- The prompt is built in layers (`ayla/prompt.ts`): who Ayla is, the device, what she may know, what she remembers, and the shape of the answer. The model answers in JSON; the server turns that into the reply below.
- The vault is not connected yet: Ayla only knows what the user tells her, adds as a file, or let her remember.

### Before you call anything

- The user must be signed in **with two-step verification** (`aal2`). Otherwise both functions answer `403 insufficient_aal`, and the tables return nothing.
- `@nuxtjs/supabase` sends the session along with `functions.invoke` and with table queries. For the streaming and voice calls you use `fetch` yourself, with `Authorization: Bearer <access_token>` and `apikey: <publishable key>`.

| Status | `error` | What to show |
| --- | --- | --- |
| 400 | `invalid_request` | A bug in the request (see the limits below) |
| 401 | `not_signed_in` | Sign in again |
| 403 | `insufficient_aal` | Two-step verification is needed |
| 404 | `conversation_not_found` | The conversation was deleted (for instance on another device): start a new one |
| 500, 502 | `unavailable`, `not_configured` | "Ayla kon nu geen antwoord geven. Probeer het zo opnieuw." |

### 1. Ask a question (the whole answer at once)

```ts
const supabase = useSupabaseClient()
const { data: reply, error } = await supabase.functions.invoke('ayla', {
  body: {
    text: 'Welke stages passen bij mij?',   // 1 to 4000 characters
    device: 'web',
    input: 'text',                          // 'voice' when the question was spoken
    conversationId,                         // leave out for a new conversation
    attachments: [{ name: 'cv.pdf', text }],// optional, at most 3; only the text of a file (max 20,000 characters each), read in the browser
    // context: { screen: 'vault', itemId } // optional: what the user has open
  },
})
conversationId = reply.conversationId       // keep it for the next question
```

The server saves the question and the answer together, and gives a new conversation its title (from the model, or the first words of the question). Attachments are never stored: only that one question sees their text.

### 2. Ask a question and show the answer while Ayla writes (streaming)

This is what the iPhone does: the answer appears word by word, and the send button becomes a stop button. Same body as above, plus `Accept: text/event-stream`:

```ts
const { data: { session } } = await supabase.auth.getSession()
const stop = new AbortController()                       // stop button: stop.abort()
const response = await fetch(`${SUPABASE_URL}/functions/v1/ayla`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Accept: 'text/event-stream',
    Authorization: `Bearer ${session!.access_token}`,
    apikey: SUPABASE_KEY,                                 // the publishable key from runtimeConfig
  },
  body: JSON.stringify({ text, device: 'web', input: 'text', conversationId }),
  signal: stop.signal,
})
if (!response.ok) throw new Error(String(response.status)) // same statuses as the table above

const reader = response.body!.pipeThrough(new TextDecoderStream()).getReader()
let buffer = ''
let event = ''
for (;;) {
  const { value, done } = await reader.read()
  if (done) break
  buffer += value
  const lines = buffer.split('\n')
  buffer = lines.pop() ?? ''
  for (const line of lines) {
    if (line.startsWith('event:')) event = line.slice(6).trim()
    if (!line.startsWith('data:')) continue
    const data = JSON.parse(line.slice(5))
    if (event === 'start') conversationId = data.conversationId // comes first, also when you stop early
    if (event === 'text') writing.value = data.text             // everything written so far, not a piece
    if (event === 'reply') reply.value = data                   // the whole reply: replaces the text
    if (event === 'error') failed.value = true
  }
}
```

| Event | Data | What to do |
| --- | --- | --- |
| `start` | `{ conversationId }` | Keep it; it is there before anything is written |
| `text` | `{ text }` | Show it as Ayla's message that is still being written (replace, do not append) |
| `reply` | the whole reply | Replace the message with the reply, including cards and suggestions |
| `error` | `{ error: 'unavailable' }` | Take the half message away and show the error |

Stopping (`stop.abort()`) stops the model. What was written so far stays on screen, and the server saves it as Ayla's answer, as in ChatGPT. Without the `Accept` header nothing changes, so the plain call in step 1 keeps working.

### 3. What is in a reply

```ts
{
  version: 1,
  id, conversationId,
  text,                                   // what Ayla says; no markdown
  question?: { text, choices: [{ id, label }] },   // 2 or 3 choices: show them instead of the text field; tapping one sends its label as the next question
  blocks: [{ type: 'vacancies', items: Vacancy[] }],  // cards; skip a type you do not know
  navigation?: { screen },                // the user asked to open a part of PAVE
  memories?: [{ text, category, replaces? }],  // Ayla suggests remembering these (see 5)
  usedMemories?: [{ text, category }],    // what this answer leans on: show "Gebaseerd op" (see 5)
  usedData: [],                           // for the vault later; empty for now
}
```

The full contract with every field is `shared/ayla/reply.schema.json`, with examples in `shared/ayla/examples/` (one per kind of reply). `accessRequest` and `proposedAction` are in the contract but not sent yet.

### 4. Conversations and messages

Straight from the tables; the security rules only return the user's own rows.

```ts
// The list, newest first. Pinned ones (pinned_at not null) go on top under "Vastgezet".
await supabase.from('ayla_conversations').select('id,title,updated_at,pinned_at,started_on').order('updated_at', { ascending: false }).limit(50)

// The messages of one conversation. `reply` holds the whole reply of Ayla's messages, so cards and
// "Gebaseerd op" come back when you open an old chat.
await supabase.from('ayla_messages').select('id,role,text,reply,created_at').eq('conversation_id', id).order('created_at')

// Rename, pin (null to unpin), delete (its messages go along). Check that select('id') returned a row:
// an empty result means a rule refused it.
await supabase.from('ayla_conversations').update({ title }).eq('id', id).select('id')
await supabase.from('ayla_conversations').update({ pinned_at: new Date().toISOString() }).eq('id', id)
await supabase.from('ayla_conversations').delete().eq('id', id).select('id')

// Search in the messages (from 2 characters).
await supabase.from('ayla_messages').select('id,conversation_id,text').ilike('text', `%${words}%`).order('created_at', { ascending: false }).limit(30)
```

**Ask again / change the last question.** Remove the last question and Ayla's answer first, so Ayla does not see the old answer in the history, then send the question again (or put it back in the text field to change it):

```ts
const { data: last } = await supabase.from('ayla_messages').select('id,role')
  .eq('conversation_id', id).order('created_at', { ascending: false }).limit(2)
// Only when these are one question and its answer (roles 'ayla' and 'user'):
await supabase.from('ayla_messages').delete().in('id', last.map((m) => m.id)).select('id')   // expect 2 rows
```

**Live updates.** The list updates by itself when a chat starts or changes on another device:

```ts
supabase.channel('ayla-conversations')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'ayla_conversations', filter: `user_id=eq.${userId}` }, reload)
  .subscribe()
```

### 5. Memory: "Wat Ayla over je weet"

Ayla only remembers what the user kept. She suggests, the user decides.

**After each reply:** when `reply.memories` is there, show a card under the answer, "Zal ik dit over je onthouden?", with one line per suggestion and its category, each with a tick (ticked by default), and the buttons Onthouden and "Nee, niet nodig":

- A suggestion with `text` is a new fact. Keep it:
  ```ts
  await supabase.from('ayla_memories').insert({ text, category, source: 'ayla', conversation_id: conversationId }).select()
  ```
- A suggestion with `replaces` means an existing note is no longer true (a previous job, a study that became a diploma). Show that note struck through as its own ticked line ("Weghalen uit werk en stages"); the button then says "Bijwerken". Find the note with exactly that text and delete it only when it stays ticked:
  ```ts
  await supabase.from('ayla_memories').delete().eq('id', note.id).select('id')
  ```
  Unticked, or "Nee, niet nodig": the note stays (someone can have two jobs). An empty `text` with `replaces` only suggests taking the note away.
- Skip a suggestion the user already has in other words; the server already leaves those out, but a note may have been added on another device since.

**Under each answer:** when `reply.usedMemories` is there, show a quiet line "Gebaseerd op: opleiding, werk en stages" (the categories, in the order below). On click, show the notes themselves and a link to "Wat Ayla over je weet". This is how PAVE shows where advice comes from.

**The page "Wat Ayla over je weet"** (on iOS under Settings): a folder per category, the notes in it, and:

```ts
await supabase.from('ayla_memories').select('*').order('created_at', { ascending: false })        // the notes
await supabase.from('ayla_settings').select('memory_enabled').maybeSingle()                      // no row means on
await supabase.from('ayla_memories').insert({ text, category, source: 'user' }).select()          // write one yourself
await supabase.from('ayla_memories').update({ text, category, updated_at: new Date().toISOString() }).eq('id', id).select('id')
await supabase.from('ayla_memories').delete().eq('id', id).select('id')                           // forget one (iOS gives 5 seconds to undo)
await supabase.from('ayla_memories').delete().not('id', 'is', null)                               // forget everything, after a confirmation
await supabase.from('ayla_settings').upsert({ memory_enabled: false, updated_at: new Date().toISOString() }, { onConflict: 'user_id' })
```

Turned off, Ayla uses none of the notes and suggests nothing; the notes stay until the user deletes them. Notes are at most 300 characters. `user_id` fills itself in.

| `category` | Shown as |
| --- | --- |
| `education` | Opleiding |
| `work` | Werk en stages |
| `goals` | Doelen |
| `skills` | Vaardigheden |
| `values` | Wat je belangrijk vindt |
| `workStyle` | Hoe je wilt werken |
| `interests` | Interesses en hobby's |
| `personal` | Over jou (also for anything unknown) |

### 6. Voice

1. Recognise speech in the browser (Web Speech API, `lang = 'nl-NL'`) and send the text to `ayla` with `input: 'voice'`. Use step 1 (the whole answer): the voice needs the full text.
2. Send the answer text to `ayla-voice` with `fetch` (it streams): `POST {SUPABASE_URL}/functions/v1/ayla-voice` with `Authorization: Bearer <access_token>`, `apikey: <publishable key>` and `{ "text": answer }` (at most 2000 characters).
3. Read `response.body` piece by piece: raw pcm16, 24 kHz, mono. Turn each piece into `Float32` samples (divide by 32768) and play them with the Web Audio API (`new AudioContext({ sampleRate: 24000 })`). A sample can be split over two pieces; keep the odd byte for the next one.
4. An `OPTIONS` request to either function wakes it up without asking anything, so the first answer does not wait for a cold start. The iPhone does this when voice mode starts.

### Rules to keep

- Never save a memory, delete one or change anything without the user's tap. Ayla's text never says she remembered something.
- Never send attachments as files or store them: only their text, with that one question.
- Show "Gebaseerd op" whenever `usedMemories` is there; it is a promise of PAVE, not decoration.
- Use the texts of the iPhone where they exist (`ios/PAVE/Features/Ayla/Shared/AylaMessages.swift`), so both apps say the same.

## Privacy: things to be honest about

- OpenRouter does not guarantee that data stays in Europe, and the voice model is from OpenAI. The demo prompt says that data stays in Europe and that conversations are not used for training. **Only keep claims in the prompt that are true for this setup.**
- The server must not log what people say.
- Memory notes are personal data: the user can see, change and delete them, and can turn memory off.
- Real personal data should only go through a provider we have checked against the AVG.

## Reused from the demo

The demo (`experiment-ai-assistant-voice`) is a separate Nuxt project. We reuse its **logic**, not its interface:

- the personality and rules (`SYSTEM_PROMPT`), without the demo-specific parts (the audience, the sixty-word limit, "this is a demo")
- consent per vault section, but read from the database instead of sent by the app
- the model fallback (`completeWithHedging`)
- the pronunciation fixes for the voice ("PAVE" as "Peiv") and the speech recognition hints

Not reused: the pixel orb and icons, the audience questions with QR code, the demo password.

## Open questions

1. Ayla now uses the newest 40 notes. Do we need to pick only the relevant ones once people have many?
3. Which proposed actions exist first (vault item, plan, profile draft, validation request)?
   Are we allowed to store or show the full text of a vacancy from Adzuna or an employer? (Check the terms before building it.)
4. What does Ayla do when someone is struggling (stress, hopelessness)? Notes about "doubts and feelings" make this important: she must recognise it and point to real help, not play therapist.
5. Users under 16 (the persona Maria is 16): does the AVG require parental consent, and does it change what Ayla may remember?
6. Can the user rate or report an answer, and who looks at that?
7. Dutch only, or does Ayla follow the language of the user?

## Suggested order

1. Reply format with example replies that both TypeScript and Swift test against.
2. Prompt in layers, with tests that data the user did not allow never reaches the prompt.
3. Model call with fallback, tested with a fake model.
4. Conversations and messages in Supabase, with live sync.
5. Chat in the apps, then voice.
6. Consent and the vault, then memory, then proposals.
