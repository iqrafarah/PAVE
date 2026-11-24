# Ayla

> **Status (2026-11-10):** the brain (`shared/supabase/functions/ayla`) and Ayla's voice (`shared/supabase/functions/ayla-voice`) run on the shared Supabase project. iOS has chat, voice, chat history and the first vault list/selection UI. Memory tables are applied. The vault schema (`shared/supabase/migrations/20261110120000_vault.sql`) is applied, but has no client/service or Edge Function integration yet. Consent for the vault is asked once per conversation (2026-11-13, `shared/supabase/functions/ayla/consent.ts`): Ayla sees no vault items until the user says Ja to "Mag ik in je kluis kijken om …?" (`accessRequest` plus a Ja/Nee question); the answer holds for the rest of that conversation, and "Vraag Ayla over dit bewijs" counts as consent. Within that, she still only sees the items with "Ayla mag dit bekijken en gebruiken". See [docs/vault.md](vault.md) for the model and rollout sequence. Changes to the contract or shared database require iOS and web review (see `Conventions.md`).

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
| Model provider | OpenRouter, with Mistral models that Mistral hosts itself (see below). |
| Where Ayla runs | A Supabase Edge Function (`ayla`) in the shared project. It runs with the user's own session, so row level security and two-step verification apply. |
| Real data only | No example data in the apps. Ayla only knows what the user tells her and, later, the vault items the user allows. |
| Consent | Per item: "Ayla mag dit bekijken en gebruiken" on the evidence, which the user can switch off at any time. In a conversation Ayla first asks whether she may look in the vault; only after Ja does she use the allowed items. |
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

Decision (2026-11-05): **Adzuna**, no example vacancies. Ayla only discusses what Adzuna returned and says honestly that she saw part of the text. Full vacancy texts only if the terms allow it; see "Vacancies in the chat" for the match against the vault.

Rules for the card:

- A field that is empty is not shown and never filled in. An estimated salary is labelled "geschat", and a yearly salary is shown per month.
- Without a logo the card shows a monogram.
- Every item in the skill-gap shows which requirement of the vacancy it comes from, so the user can check it. It is a possibility, not a fact.
- Only search terms leave the system, never personal data. The API key stays on the server.

### Vacancies in the chat (2026-11-20)

**Sources (2026-11-20).** Adzuna registration did not work out, so the server uses the job API that has a key, with the web search beside it (see below): Adzuna (only with `ADZUNA_APP_ID` and `ADZUNA_APP_KEY`), Jooble (only with `JOOBLE_API_KEY`, host `JOOBLE_HOST`, default `nl.jooble.org`; key through the form on jooble.org/api/about), and a web search through OpenRouter (Exa, limited to Dutch job sites in `JOB_SITES`, about $0.007 per search plus tokens). A web result counts only when its link is among the search results (`fromWebAnswer`), so the model cannot invent a vacancy. The Jooble client follows the commonly used format (POST with `keywords` and `location`, `jobs` with `title`, `company`, `location`, `snippet`, `salary`, `link`, `id`); its documentation comes with the key, so check it once the key is there. OpenRouter marks the `web` plugin as deprecated in favour of the `openrouter:web_search` server tool on the Responses API; it still works, but move over when it stops.

Vacancies are not a page in the menu: you search them in the chat with Ayla, using the evidence in your vault.

- **Ayla searches for you.** "Vacatures die bij me passen" without a job title: Ayla picks the search terms from the vault, and asks for consent first when she may not look in it.
- **Ayla explains the match.** With the vault allowed, the second model call fills `vacancyMatches`: per vacancy what fits and what is missing, each with a literal piece of the vacancy text. The server (`withMatches`) keeps a requirement only when that text really is in the snippet, at most 3 per list, and drops a gap that is also a match. Without consent the lists stay empty.
- **Ayla helps close the gap.** Tapping a missing skill asks her how to get it for that vacancy.
- **The panel.** The vacancies open over the chat as the vault does (iOS `AylaShelf.vacancies`): low at first so her answer stays readable, pulled up to the full screen, swiped away, with Ayla's text field below. A card opens the vacancy in the same panel: the snippet (`Vacancy.summary`, never the whole text), what fits and what is missing, and a link to the whole vacancy at the employer.
- **The open vacancy is context.** While a vacancy is open, the request carries `context.vacancy` (title, company, city, snippet, skills; server limits in `contract.ts`), so "past deze bij mij?" is about that one. The prompt marks its text as the employer's text, not an instruction.
- **Saved vacancies** are kept in the account (`saved_vacancies`, migration `20261120170000_saved_vacancies.sql`), as Ayla showed them, so they still show when Adzuna no longer has them. Own rows only, behind two-step verification, no updates.
- **You see what she does.** The stream sends `status` events: `vacancySearch` (with the search terms) as soon as the model wrote them, so the Adzuna search starts while the model still writes, and `vacancyMatch` before the second call. The app shows them on one line where "Ayla denkt na…" stands. Apps that do not know the event ignore it.
- **Ja and Nee at once.** `askVault` comes right after `text` in the schema; as soon as it is written (and Ayla may not look yet) the server stops the model and sends the question, and the reply goes out before the conversation list is updated.
- **You choose which data Ayla uses (2026-11-21, Figma FEDDIES 1348:6).** Ayla's question about the vault has three answers on the iPhone: Ja (everything marked "Ayla mag dit bekijken en gebruiken"), Kies zelf (choice id `choose`: the app opens the vault picker, the same one as behind the plus button) and Nee. Items picked for a conversation go along as `context.itemIds`, and the server then gives the model **only those items**, not the rest of the allowed vault; picked right after her question it counts as a fresh yes, so she goes on with what she asked it for. Above the vacancies the panel says what was searched (`search` on the vacancies block) and which data was used, with "Andere gegevens kiezen" to search again. Web and Watch keep Ja and Nee until they have the picker behind the choice.
- **In your own words.** "Kies zelf" is also heard as "laat mezelf kiezen", "ik kies zelf", "laat mij kiezen" or "ik wil het zelf bepalen", typed or said (`AylaVaultOffer.wantsToChoose`); she says "Kies maar. Ik gebruik alleen wat je kiest." and the picker opens. Should such a sentence reach the brain anyway (web), the prompt tells it to point to the picker and ask again, not to start about something else. While you pick by hand during a spoken conversation, Ayla holds (the microphone is off) and goes on when the picker is gone; her answer after your choice is spoken.
- **Answers always fit.** The answers to her question stand next to each other when each fits on one line, and under each other when they do not (three answers on the closed iPhone Duo, or large text), so a label is never cut off (`AylaChoiceBar`).
- **She acts in the same turn (found on the iPhone Duo, 2026-11-21).** After a Ja to the vault the model sometimes only announced ("dan zoek ik vacatures") and waited, so the user had to say "ga". The prompt now forbids announcing a search without `vacancySearch`, and the server checks it (`announcesSearchOnly`): she is told so and searches in that turn. `vacancySearch` stands right after the text in the schema, the answer gets more room (900 tokens), and an answer that was cut off all the same never shows as raw JSON: what was complete is kept (her text, a search), the rest is left out. Actions that open or save a vacancy are dropped from a turn that searches, because those cards are not there yet.
- **She knows what is on screen.** `app.seeing` says in a few words what you look at (the page, the tab, "vacature 2 van 6 op de kaart"), and the vacancy on the card under the orb goes along as the open vacancy, so "past deze bij mij?" needs no asking back. No vault content and no names from the vault are in it.
- **A tap asks out loud too.** What the app asks for you after a tap (Vraag Ayla, a missing skill, what you picked) goes through the spoken conversation while you talk with her, so she answers with her voice.
- **Ask or do, never both, and no talking on unprompted (found on the Duo).** An answer that asks "wil je dat ik …?" carries no actions (the server drops them), and her own round after her actions only comes when a step failed or a job filled all four steps, not when everything simply worked.
- **More logos.** A vacancy without a company shows the icon of the job site it names ("Via werkzoeken.nl"); a company the model named no site for gets its own name tried as a site (`sitesFromName`: "synseltechniek.nl", or the name itself when it is a domain); the icon is asked at 256 pixels and shown from 32 pixels up, smaller when it is small.
- **Her tasks, ticked off.** The activity pill is open from the start when there is more than one step, with a tick per step as she finishes it and a red mark for what did not work. Searching vacancies shows as steps too (search, compare with your vault, open the list), moved along by the server's status.
- **A setting she changes.** Instellingen comes up, you see it change, and it goes down again by itself; it stays when you asked to see the page or had it open yourself.
- **"Met alles uit mijn kluis".** Said in so many words, that is a yes to the vault without her asking (`grantsWholeVault`), and it lifts a choice of items made earlier in the conversation (`usesWholeVault` in the app).
- **Per scenario.** (1) "Zoek vacatures die bij me passen": she asks for the vault first (Ja, Kies zelf, Nee), then picks the search terms from what she may see. (2) "Zoek junior developer in Eindhoven": she searches at once, and asks under the results whether she may show what fits. (3) Items picked first with the plus button: only those are used. (4) Nee: she searches on what you say and shows no match, and does not ask again. (5) Nothing in the vault she may see: she asks which job or direction you look for. (6) Follow-ups ("ook in Utrecht", "meer zoals die bij Bedrijf", "wat mis ik voor de tweede"): her earlier answers carry a line "(Getoonde vacatures …)" that the server adds from the stored cards, so she knows what was shown and searched.
- **Smarter search.** `vacancySearch.also` is one related job she searches beside the first; the results are merged in turn, each vacancy once, at most 6 cards. With the vault allowed the cards are ordered by fit (`bestFirst`: more that fits, less that is missing). She names vacancies by job and company, never by number.
- **The web search supports the job API** (`withSupport`): Jooble's vacancies first, the web's after them, and a vacancy both found keeps the longer piece of text, which gives the match more to go on. The web gets 6 seconds after the API answered; when the API fails or finds nothing, the web is the source. Jooble's `updated` shows as "Geplaatst op" in the vacancy.
- **Company logos (2026-11-21).** Jooble gives no logos. In the second model call the model names the company's own site per vacancy (`vacancySites`), only when it is sure. The server shows a logo only when the domain fits the company's name (`siteFits`: "ogd.nl" for "OGD ict-diensten", never a job site or social media, never for "Via …") and the site really answers (`siteChecker`, 2 seconds). `logoUrl` is then the icon of that site through Google's favicon service at 128 pixels, with no key. The app (`CompanyLogo`) shows it on a white badge and keeps the letter when there is no logo or it is smaller than 48 pixels. To be honest about: the phone loads the logo from Google, so Google sees which company's icon is asked for; the employer's own site is only touched by the server.
- **Hands-free**, typed or spoken: "toon de vacatures", "open de tweede vacature", "bewaar deze" (the open one), "bewaar de laatste", "open mijn bewaarde vacatures", "terug".

## What Ayla does in the app herself (2026-11-21)

Ayla has to be able to do nearly everything for you, also hands-off (typed or spoken, no tapping). There are two ways, and they end in the same code in the app:

1. **Fixed sentences, at once** (`AylaAppCommand` in PAVECore): "open de map Stages", "zet het thema op blauw", "ga terug". The app recognises them itself, so they work at once and mostly without a connection. Two things in one sentence ("zet donker aan en open mijn stages") are not handled here but go to the brain.
2. **Actions her brain chooses** (`actions` in the reply, `ACTIONS` in `contract.ts`, `AylaAppAction` in PAVECore): any wording, up to four in a row, alongside her answer. The app carries them out one after the other so you see it happen (`run` in `AylaChatScreen`), and says so in the chat when something cannot be done (a folder that does not exist).

Rules:

- **Names are yours.** A folder, a piece of evidence or a chat is named in your own words; the app looks it up (`AylaAppAction.best`). The model never gets a list of your folders, evidence or chats for this.
- **What cannot be undone asks first.** `deleteChat`, `deleteEvidence`, `signOut` and `forgetAll` come with `confirm`: the server replaces her text with a question in fixed words and Ja and Nee, and the app only acts after Ja, once. A model that says "gedaan" too soon changes nothing.
- **She never says it is done when it is not.** The prompt forbids it, and after a Ja the app checks that the thing exists before she says so.
- **Only on the iPhone for now.** Web and Watch get no actions and the prompt tells the model so; they can adopt the list (`reply.schema.json`, `$defs.action`).

- **You follow what she does.** One compact glass pill shows the step she is on, with her own pixel blocks as progress and how far she is (`AylaActivityPill`); a tap opens the steps. It floats just above where she lives (the text field or the small orb), in the chat and on an open page, and stays a few seconds after she is done. This follows what ChatGPT, Claude and Perplexity do (one status line, steps on request) rather than a permanent list. It is not shaped or placed like the Dynamic Island: Apple asks apps not to imitate it.
- **While you talk, she stays with you as the small orb.** A page that opens during a spoken conversation has one floating glass capsule at its bottom: the orb, what she is doing, the microphone and stop (`AylaShelfVoiceBar`), next to the glow along the edge. Typed, that place is the text field. Glass is only used for this layer of controls over the page, tinted so text under it does not run through.
- **Outside the app** the Live Activity of the spoken conversation (Lock Screen and Dynamic Island, `PAVEWidgets`) also says that she is busy: "Stap 2 van 3", "Zoekt vacatures". Never names of folders, evidence or chats and never search terms, because the Lock Screen can be seen by others.
- **She goes on after her own actions (the loop).** When she set `continues`, or a step did not work, the app sends what came of her actions (`results` in the request: per action whether it worked and what the app said) and she takes another way or does the next steps. At most three rounds per question; such a round stores no message of the user, and it works spoken too. If she cannot be reached for it, the app says itself what failed.
- **A model by how hard the turn is** (`effortFor`, `modelsFor`): a greeting starts with Mistral Small (`mistral-small-2603`), an ordinary question with `mistral-large-2512`, and real work (writing or comparing, files, a long or compound request, comparing vacancies with the vault, a round after her own actions, a question about data and privacy, the turn right after a yes to the vault) with `mistral-medium-3-5`, which also gets longer to start before the next model joins. When a model is slow or refuses (Mistral answers 429 when it is busy), the next one takes the turn at once; the small model is the last resort outside a greeting, because it follows the prompt least well.
- **She knows how the app is set.** Every question carries `app` (theme, text size, light or dark, vault layout, text while talking, animations, memory on or off, the title of this chat and whether it is pinned): no vault content and no names of folders or evidence. So she can say how something stands and does not do what is already so.
- **Her own access asks first.** `allowAyla` with `on` gives Ayla the use of a piece of evidence, so it is asked with Ja and Nee like the things that cannot be undone; taking access away is done at once.

### Which models, and where the data goes (found 2026-11-23)

Running the scenarios against the real models showed that the live function had been answering ordinary questions with the wrong model for some time:

- `mistralai/mistral-medium-3.1`, the model for ordinary questions, was retired by Mistral (error 400, "Invalid model"). Every such turn fell back at once to `mistral-small-3.2-24b-instruct`, the weakest of the three, which explains many of the careless answers seen on the Duo.
- OpenRouter does not serve `mistral-small-3.2` through Mistral at all, only through DeepInfra, Parasail and Venice. So what people told Ayla on those turns went to those companies, not to Mistral. The same holds for `ayla-evidence` and `ayla-skills`, which use the same list (`MODELS`).
- That model also sometimes wrote only spaces and tabs after a field until its room ran out: 20 seconds of waiting and an answer that lost its actions and the vault items it used.

What `openrouter.ts` does now:

- Only models Mistral hosts itself (`mistral-small-2603`, `mistral-large-2512`, `mistral-medium-3-5`), and every request carries `provider: { only: ['mistral'] }`, so OpenRouter cannot route it elsewhere. `mistral-large-4-0` was tried and left out: it has the same whitespace problem.
- A model that answers with an error is logged by name and status (never the question), so a retired model shows in the function's logs.
- A stream that only writes whitespace any more is cut there (`MAX_TRAILING_SPACE`), and JSON that stopped between two fields is read as whole up to there (`parsed` in `brain.ts`).
- Costs: the prompt is about 7,600 tokens per call. An ordinary turn costs roughly $0.004 on `mistral-large-2512`; a hard turn or a fallback on `mistral-medium-3-5` roughly $0.012.

`node evals/run.ts` prints which model answered how often; run it when answers get worse, because models are retired without notice.

### Intelligence round 2 (2026-11-23)

29 new scenarios in `evals/run.ts` (names starting with "r2"): unexpected questions (a joke, "help", typos, English words in a Dutch sentence, fear of not finding work, salary, a BSN, an attempt to make her delete everything), several tasks at once, five folders in two rounds, an order that points at nothing ("zet hem uit"), a one-year plan, preparing an application, a motivation letter, interview questions, and vacancy follow-ups (another city, part-time, compare two, why one fits less, more like one, save the second, what to learn and how long, an internship, search then open the second). The harness now records what she searched for, so a check can see that "ook in Utrecht" searches in Utrecht and keeps the job.

First run 24 of 29. What changed:

- **Answer the question asked.** Questions about a job, salary, study or applying are answered (salary as a rough range that differs per employer), not turned into a search; "welke banen passen bij mij" still searches at once.
- **A search nobody asked for does not start** (`asksForWork`): when neither the message nor a yes to her own offer is about work or searching, a search she wants is held back and she is told to answer instead. A question about vacancies already shown ("wat mis ik voor de tweede?", `asksAboutShown`) is answered from "Getoonde vacatures", never searched again.
- **"Zet hem uit" with nothing to point at** gets "Wat bedoel je precies?" instead of a guess.
- **Plans** are numbered steps, at most five, with "maand 1-3" when a term is named; she no longer offers to save a plan. **A big job** (an application, a cv, a switch) starts with the plan for that situation, including what is missing for that vacancy, before she asks where to begin. **Comparing** names each option by job and company and ends with which fits best and why. **"Schrijf …"** gets a draft at once.
- **Found vacancies that do not match the search** (looked for UX, found developers) are said so in the first sentence, with an offer of other words, never a promise that she already searches again.
- **More than four steps** asked at once always go on in a next round, even when the model forgot to say so.
- **Feelings and worries** are not proposed as memories.

Result: all 68 scenarios twice, 135 of 136 (the one miss was a check, not her answer), median 2.7 s per scenario.

### Vacatures met de stem en vier taken (2026-11-23)

**Two new fields on `context`** (`contract.ts`, checked in `parseRequest`):

```jsonc
"context": {
  "screen": "vacancies",                  // compare is allowed where vacancy is: vacancies, vault, vaultItem
  "vacancy": { "title": "…", "company": "…", "city": "…", "summary": "…", "matches": ["…"], "skillGap": ["…"] },
  "compare": [ /* 2 or 3 vacancies in the same shape as vacancy */ ],
  "task": "compare" | "gaps" | "prepare" | "interview"
}
```

`task: "compare"` needs `compare`; `gaps`, `prepare` and `interview` need `vacancy`. Anything else is `context is not valid`. The visible message stays a plain Dutch sentence ("Vergelijk deze vacatures", "Wat mis ik voor deze baan?", "Help me solliciteren op deze vacature", "Oefen een sollicitatiegesprek met mij"); the task tells the brain what the button meant.

**The four tasks** are a prompt layer (`taskLayer` in `prompt.ts`, after where the user is) plus a note with the question (`contextNote`):

- `compare`: each vacancy by job and company, what fits (`matches`), what is missing (`skillGap`), practical points only when they are in the data, and an advice which fits best and why. No made-up salary or hours. Spoken: three to five sentences, no lists.
- `gaps`: what is still missing, checked against the vault she may see, then two to five numbered steps with a rough timeline ("maand 1-2"). She never offers to save it as a plan: Plan does not exist yet.
- `prepare`: which vault items to mention (by title, only items she may see), what to stress, and the opening of a motivation letter (three to five honest sentences). Without the vault she asks for it with the usual question (Ja, Kies zelf, Nee); after a no she writes with `[je opleiding]`-style gaps to fill in. Nothing is sent and nobody has applied. Spoken: she names the items and asks whether to put the letter in the chat.
- `interview`: she plays a recruiter of that company. First turn: one sentence about the practice and the first question; then feedback on the answer and the next question, one at a time, at most five; after the fifth answer or "stop", "klaar" or "genoeg" a summary with two strengths and one point to improve. The app keeps sending `task: "interview"` while practice mode is on.

The server keeps them to it (`brain.ts`): a task never searches (a `vacancySearch` is dropped, no nudge), only `prepare` may ask for the vault (the others go on with what she sees, so interview practice also works without the vault), and `compare`, `gaps` and `prepare` use the hard model while an interview turn is normal (`effortFor`).

**Follow-ups about the cards, also spoken** (`asksAboutShown`): anything that points at the cards shown last or the card that is open (`context.vacancy`) is answered from them and never searched again: places in the list ("en die tweede?", "de vorige", "de laatste"), "naast elkaar", "vergelijk", "welke van", "die/deze vacature", a company or a distinctive word of a title from "(Getoonde vacatures …)" ("is die van Appwerk beter?", "die iOS-baan"), "deze" or "die" while a card is open, and short follow-ups such as "en qua reistijd?". Asking for other results ("zoek", "ook in Utrecht", "nog meer", "andere vacatures", "parttime", "en in Utrecht?") is still a search. Travel times are not made up: she names the places and says what is closer only when she is sure.

**Listening with Voxtral** (`ayla-listen`): the recording goes to `mistralai/voxtral-small-24b-2507`, only on Mistral's servers (`provider: { only: ['mistral'] }`), about a second per sentence. The app may send `X-Ayla-Hints`: a percent-encoded, comma-separated list of names the user may say (companies, job titles, skills, vault titles). The server keeps at most 40 names of at most 80 characters, 1000 characters in all, and only letters, digits, spaces and `-'.&+#/()`, so the list cannot carry an instruction; the model is told it is only a list. With hints "Appwerk" is heard as Appwerk, without them as "Upwork". The limit is about 60 seconds (2 MB of 16 kHz mono 16-bit WAV).

What testing against the real model showed, and what the function does about it:

- A system message, or the instruction before the recording, makes Voxtral answer or make up a story instead of writing out short sentences ("Stop maar" became "Ik ben klaar om te beginnen"). So there is one user message: the recording first, then the instruction.
- For silence or steady noise it writes whole made-up sentences, with the hint names in them. A recording without speech (`hasSpeech`: at least 150 ms clearly louder than the quietest part) is not sent and gives empty text, and a transcript with more words than fit in the recording (`plausibleTranscript`, five words a second) counts as nothing heard. The answer gets room for what fits in the recording (`max_tokens`).
- Without hints it sometimes answers a spoken question instead of writing it out; with hints that did not happen in the tests. Tested with the macOS voice Xander, not with real people yet.

**Evals.** 17 scenarios starting with "r3" in `evals/run.ts`: each task typed and spoken, applying without the vault, an interview of three turns ending in "stop", and the spoken follow-ups above. First run 15 of 17: steps were checked too strictly (a check bug), and "stop" in an interview gave only "Het is goed" (her mistake). Fixed since: the summary after "stop", steps that are always given (they were sometimes left out), and no made-up travel times ("20 minuten met de auto"). The "wat mis ik" scenarios then passed 6 of 6; a full run with all r3 scenarios after the last changes is still to do (the OpenRouter credit ran out during it).

### How the server holds her to her word (review round, 2026-11-22)

The model is not trusted to be consistent; `brain.ts` checks each answer against what it says it is.

- **`intent` comes first.** The first field of the model's answer says what the answer is: `answer`, `askUser`, `askVault`, `search`, `propose` or `act`. The model commits before it writes, and the server uses it: `search` without `vacancySearch`, or `act` without anything that happens, gets one more try in the same turn (`nudgeFor`) in which she is told that nothing happens yet. When that try fails, her first answer stands.
- **Ask or do** (`asksBeforeDoing`): a closing "zal ik …?", "wil je dat ik …?" or "wil je deze … bewaren?", or any closing question in an answer with intent `askUser`, means she waits, so the actions are dropped. Not when she said before it that she does something ("Ik zet donker aan. Zal ik ook de tekst groter maken?"): that is doing and then asking about something else, and the first still happens.
- **One question names everything it is a yes to** (`confirmable`): several pieces of evidence to delete, or to give her the use of, fit in one question with all their titles. Anything else is asked on its own, and what the question does not name is left out of that answer, so a Ja never does more than it was asked for.
- **What she may see of the vault** (`vaultScope`): a yes in the conversation opens every item marked "Ayla mag dit bekijken en gebruiken". Items picked for the conversation, the item that is open ("Vraag Ayla over dit bewijs") and the sources of a project open **only themselves**; for the rest she can still ask (`mayAskMore`), unless the user said no. A no also closes the project sources, and "kijk niet meer in mijn kluis" closes what is picked or open as well (the app lets the picked items go, `takesVaultBack`).
- **Yes and no as people say them** (`consent.ts`): a yes is an answer made only of yes words ("doe maar", "ja, kijk maar", "tuurlijk", "eh ja", "laat maar zien"); "oké, nee toch niet" and "laat maar" are a no; "ja, maar alleen mijn stage", "ja ik wil zelf kiezen" and "mag ik eerst iets vragen" are neither, so she asks again instead of looking. "Met alles uit mijn kluis" only counts as said to her, not as a question or a remark about the vault. "Kijk niet meer in mijn kluis" takes the consent back for the rest of the conversation.
- **A no to an offer ends the offer** (`declinedOffer`), but only a bare no to something she offered. A no to an ordinary question ("Heb je al een cv?") is an answer, and the questions PAVE itself asks (the vault, a confirmation) always stay.
- **The round about the vacancies only talks.** It has its own, smaller schema (`MATCH_OUTPUT_SCHEMA`: text, sites, matches), so it cannot act, navigate or propose; what she does was decided in the first round. The vacancies reach her as a message of PAVE with the text between `<vacatures>` tags, marked as material and not an instruction. When that round fails or is cut off, the cards still show: the matches that were complete are kept (`entriesSoFar`), and without any words of hers PAVE says "Dit heb ik gevonden. …". Matches need at least one vault item in view; at most 3 per list.
- **Nobody else speaks as PAVE.** "(Bericht van PAVE …)" is removed from what a user types and from the text of files (`ownWords`), a file cannot close its own `<bijlage>` tag, and notes the server adds to the history never show as her words (`cleanText`).
- **She knows what she did.** Her earlier answers carry "(Je acties bij dit antwoord: …)", so "zet het terug" has something to point at.
- **The model for the turn** also looks at what she asked: "prima" after her question is an answer (Medium, or Large when she offered to write a cv), not a greeting, and the turn right after a yes to the vault is hard.
- **The prompt** (`prompt.ts`): what the app can really do today (`APP_PROMPT`, the iPhone-only part apart), evidence statuses in the words of the app ("Geverifieerd", "Niet bevestigd", "Afgewezen"), the rules for files only in a conversation that has files, building evidence as a list instead of one paragraph, and a five-line recap at the end. New rules: two directions and a search at once for "welke banen passen bij mij", a cv or letter of at most 150 words (spoken: the outline first), no names of courses or providers and no prices, "stop", forgetting one thing versus everything, and an honest answer about what happens with data, without promises about where it is stored.
- **Small things the server decides itself**, because the model got them wrong against the real thing: an action that sets what is already so is dropped (`alreadySo`, "Dat staat al zo."); a vacancy is only saved when the user said so or said yes to her offer (`asksToSave`); asked to forget one thing while she remembers nothing, she says so; an item she names by its title counts as used ("Uit je kluis"); the item or vacancy that is open goes with the question itself (`contextNote`); English is answered in English (`writesEnglish`); on the Watch she says how many vacancies she found and that they can be asked for in the app.
- **Checking it against the real models:** `node evals/run.ts` in `shared/supabase/functions/ayla` runs 39 scenarios through the real brain and models with a made-up vault and vacancies (`--only`, `--verbose`, `--raw`, `--times`). It needs `OPENROUTER_API_KEY` (environment, or `shared/supabase/functions/.env`, which is not in git). On 2026-11-23 all 39 passed, with a median of 2.2 seconds per scenario.

What she can do, by part of the app:

| Part | By fixed sentence | By her brain as well |
| --- | --- | --- |
| Opening | Kluis, plan, profiel, instellingen, meldingen, a settings page, a folder, a piece of evidence, back, close | Wat Ayla onthoudt, bewaarde vacatures |
| Looks and settings | Theme, text size, light or dark, vault as list or grid, text while talking, chats in iPhone search | Animations on or off, memory on or off |
| Chats | | New chat, open a chat by its title, rename, pin, archive, expiry of this chat, delete (asks first) |
| Vault | Open a folder or evidence | New folder, put evidence in a folder, archive evidence, let Ayla use a piece of evidence or not, open the form to have it confirmed, delete evidence (asks first) |
| Adding evidence | | From a file, a photo or what you tell her (`vaultItem`, since 2026-11-10) |
| Vacancies | Save one, open one, the saved ones | Search, a related job, choosing which data, the same by place in the list |
| Memory | | Remember and forget single facts (`memories`), forget everything (asks first) |
| Account | | Sign out (asks first) |

Not by Ayla, on purpose: sending a verification request (you choose who and send it yourself), the PIN for locked chats, and changing a password. She says where you find them.

## What belongs to the account (shared state)

These are proposals for tables, all with row level security on the user, like `profiles`.

| What | Content | Notes |
| --- | --- | --- |
| Conversations | id, title, created, last message, device it started on | Deleting a conversation removes it on every device |
| Messages | conversation, role (user or Ayla), text, device, time | Append only. The server sets the order |
| Vault | Folders, evidence items, file metadata, skill tags and validation requests | User-owned; private files; only trusted server code sets verification outcomes |
| Memory notes | text, category, source conversation, time | Visible and deletable, with a switch per category. Never sensitive data (BSN, medical, support needs) |
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
   - (A stored user message keeps only the names of its attachments in its `reply` column, as `{ "attachments": [names] }`, so the chat can show them again.)
   - `accessRequest`: vault sections she wants to see, so the app can ask for consent. The question is asked once: when the model also asked it in `text`, the function takes that sentence out, and with nothing else to say `text` is the question itself and `question.text` is empty (the choices stay).
   - `proposedAction`: something she suggests, which the user confirms
   - `blocks`: cards the apps draw (selection, consent request, vacancies, skill suggestions, CV), each with a type from a fixed list
   - `navigation`: a screen to open, chosen from a fixed list the apps map to their own routes
   - `usedData`: which allowed sections were used, set by the server so it is always true

Each message also carries `device`, `input` (voice or text) and optionally `context` (the open screen or item id) and `attachments` (up to 5 files the user added with the plus button, as many as evidence in the vault takes; the app reads their text on the device and sends that text, and for a photo also a small JPEG so Ayla can look at it; Ayla sees them in that one message and nothing of them is stored, only the file names).

### Models (from the demo)

| Job | Model |
| --- | --- |
| Answers | `mistralai/mistral-large-2512` (ordinary), `mistralai/mistral-small-2603` (greeting), `mistralai/mistral-medium-3-5` (hard) |
| Fallback | the other two, the small one last |
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
| `migrations/20261110120000_vault.sql` | Vault records, private files, skills and validation requests; applied on 2026-11-10 (the task grants in it are removed by `20261120190000`) |

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
- **Vault:** evidence, files, verification and per-item Ayla consent; see [docs/vault.md](vault.md).
- **Outside the app:** Siri and Shortcuts phrases, the Action button, Control Center buttons and widgets start a voice conversation or a new chat. They only open the app (behind the PIN), never show anything from it.

## Memory ("Wat Ayla over je weet")

Ayla remembers things across conversations, but only what the user kept. This follows the product rule that Ayla asks before anything is stored.

- **Suggest, then confirm.** When the user tells something lasting that helps with learning or work, Ayla adds `memories: [{ text, category }]` to her reply: every fact on its own, one short line in the "je" form, at most 4 per reply. "Ik studeer ICT op Fontys en werk als leidinggevende bij de Plus" becomes two facts (education and work). The app shows "Zal ik dit over je onthouden?" with a tick per fact, Onthouden and "Nee, niet nodig". Only the ticked facts are saved, with the user's own session, into `ayla_memories` (`source = 'ayla'`). Ayla's text never claims she remembered something. Older replies with a single `memory: { text }` are still read.
- **Out of date.** When what the user tells makes one of their notes untrue (a current job, a study they follow now, where they live, a goal that changes), the suggestion carries `replaces`: the exact text of that note. "Ik werk nu bij Albert Heijn" suggests the new job and taking "Je werkt als leidinggevende bij de Plus" away; "Ik werk niet meer bij de Plus" only the taking away (empty `text`). The server keeps `replaces` only when it really is one of the user's notes. The app shows it as its own line, struck through, ticked like the rest, and the button says "Bijwerken" or "Weghalen". Untick it, or tap "Nee, niet nodig", and the old note stays: someone can have two jobs. Never suggested for what stays true: a diploma or finished study, a past internship or job, a skill.
- **Categories** (`category`): `education` Opleiding, `work` Werk en stages, `goals` Doelen, `skills` Vaardigheden, `values` Wat je belangrijk vindt, `workStyle` Hoe je wilt werken, `interests` Interesses en hobby's, `personal` Over jou. An unknown category becomes `personal`. "Wat Ayla over je weet" is grouped by them. When the user adds or changes a note, they can pick more than one ("Je ontwerpt graag" under both work and interests); the note then shows in each of those folders. `categories` holds them all and `category` is the first, the main one, which the Ayla function and suggestions keep using. Adding from inside a folder starts with that folder's category.
- **Never suggested:** health, religion, politics, sexuality, origin, money, passwords, or anything about other people (the prompt layer in `ayla/memory.ts`), nor a fact she already has, also in other words: when at least 3 of every 4 meaningful words of a suggestion are already in a note, it is dropped (`covers`, on the server and in the app, with the same list of small words).
- **Used in every conversation**, on every device: `index.ts` reads the newest 40 notes and the setting with the user's session (`loadMemory`) and lists them in the prompt between `<onthouden>` tags, as data and never as instructions.
- **The user is in charge** ("Wat Ayla over je weet" in Settings): see every note with where it came from and when, change it, delete it, write one yourself (`source = 'user'`), forget everything, or turn the memory off (`ayla_settings.memory_enabled`). Off: Ayla uses none of the notes and suggests nothing; the notes stay until the user deletes them. Without a settings row the memory is on, which is safe because nothing is stored without a tap.
- **More than one category:** `migrations/20261110180000_ayla_memory_more_categories.sql`, applied on 2026-11-10. It adds `categories text[]`; a trigger keeps `category` equal to the first one, so a client that only writes `category` keeps working. Without it, iOS would save only the main category (it retries without `categories` on `PGRST204`).
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
    attachments: [{ name: 'cv.pdf', text }],// optional, at most 5; only the text of a file (max 20,000 characters each), read in the browser
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
- Never store attachments: their text, and for a photo a small image, go with that one question only; the stored message keeps the names.
- Show "Gebaseerd op" whenever `usedMemories` is there; it is a promise of PAVE, not decoration.
- Use the texts of the iPhone where they exist (`ios/PAVE/Features/Ayla/Shared/AylaMessages.swift`), so both apps say the same.

## Privacy: things to be honest about

- The chat models are hosted by Mistral and requests are pinned to it (`provider.only`), but they still pass through OpenRouter, which does not guarantee that data stays in Europe; and the voice model is from OpenAI. Until 2026-11-23 ordinary turns went to DeepInfra, Parasail or Venice without anyone having chosen that (see "Which models, and where the data goes"). The demo prompt says that data stays in Europe and that conversations are not used for training. **Only keep claims in the prompt that are true for this setup.**
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
