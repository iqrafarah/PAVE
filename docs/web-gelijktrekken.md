# Web en iOS gelijktrekken

Stand van 2026-11-27. Een vergelijking van de code van `web/` en `ios/` op `dev` (4f3f6c2), met alle documenten in `docs/`. Dit is wat het webteam nog moet aanpassen, met per punt waar het op iOS staat. Teksten staan in [`ui-teksten.md`](ui-teksten.md); gebruik die woorden letterlijk.

## Besluiten

| Punt | Besluit |
| --- | --- |
| Plan in de chat | Op web geen Dynamic Bar, maar de stappen van het plan op de plek van de chats in het chatpaneel, met een pil "Chats" erboven (Figma FEDDIES 1173-18657). |
| Serverwijzigingen voor web | Het webteam past `shared/supabase/functions/ayla` zelf aan, in dezelfde pull request, en het iOS-team keurt die goed. |
| Bewijs toevoegen vanuit de chat | Combineren: de conceptkaart van iOS met de keuzes van web. |
| "Gebaseerd op" onder Ayla's antwoord | Tonen, zoals iOS, na afstemming met de product owner. Staat op web nog uit (`AylaCanvas.vue`). |
| Filter in de kluis | Vorm per platform houden (iOS één Filter-menu, web chips). Alleen de woorden gelijk: "Volgorde" in plaats van "Datum". |
| Privacypagina in Instellingen | Zo laten; vergrendelen en Spotlight bestaan alleen op de iPhone. |

## Sinds 24 november op web

Meldingen (inbox, groepen, Recent verwijderd, beoordelen, beurs, seintje van de browser), een echte verificatieaanvraag via `vault-review` met de status van de aanvraag en de reden bij afwijzen, de pagina Plan (sjablonen, stappen van Ayla, plan voor een vacature, project), e-mail in Meldingen via de webserver, taal en lettertype, en de pagina's voor ontvangers (`/gedeeld`, `/werkgever`, `/inbox`, `/beurs`).

## Wat web moet aanpassen, belangrijkste eerst

### 1. Plan in de chat (branch `feat/web/plan-in-chat`)
- **Gebouwd:**
  - Vraag je Ayla om een (stappen)plan, dan maakt ze het en zoekt ze in die beurt geen vacatures.
  - Het plan wordt meteen bewaard met de chat erin, zoals op iOS. Stuurt de server (nog) geen `createPlan`, dan maakt web het uit de genummerde stappen van haar antwoord (`createFromAnswer` in `usePlans`).
  - De stappen staan op de plek van de chats, met boven de stappen een pil "Chats" (en in de chats een pil "Stappen" terug). Terwijl Ayla het plan maakt staat daar "Ayla maakt je plan…".
  - "Plan toevoegen" met het plusje en onder het tekstveld: een bestaand plan kiezen of een nieuw plan maken zoals bij Plan (`PlanPickerDialog`).
  - De stappen als tijdlijn, zoals Figma FEDDIES 1363:2656 (`PlanChatPanel`, `PlanStepMark`): een rondje per stap (klaar, bezig, nog te doen) met een lijntje naar de volgende, de datum waarop een stap klaar was, de titel en een regel eronder. Een klik op het rondje rondt de stap af of zet hem terug.
  - Ayla's antwoord wordt gevolgd: een plan dat ze maakt (`createPlan`), een stap die ze afvinkt (`updatePlan`) en de kaart "Pas plan aan" (`planEdit`, `PlanEditCard`).
  - De server stuurt `newPlan` en `planEdit` nu ook naar `web` (`makesPlans` in `plan.ts`).
- **Nog te doen:**
  - "Laat Ayla nakijken" op de pagina van een plan (iOS `PlanMessages.reviewPlan`).
  - De keuze bij een voorstel naar het account (`account_state`, `planEdit/decisions`) zodra die tabel er is; nu blijft die in de browser.

### 2. Profiel en delen
- `pages/profiel.vue` is nog een lege staat. iOS heeft Snel delen, selecties, beheren (pauzeren, verlengen, intrekken), "Wie keek er" en Mijn beursdag.
- Web heeft de kant van de ontvanger al, de kant van de eigenaar nog niet. Volgens [`gap-analyse.md`](gap-analyse.md) is dit het grootste gat.
- iOS: `ios/PAVE/Features/Profile/Sharing/`.

### 3. Vacatures
- Web toont alleen een raster kaarten (`AylaCanvas.vue`). Op web ontbreekt nog:
  - de tabs Gevonden, Bewaard en Sollicitaties, en het detail met "Past bij jou" en "Wat je nog mist";
  - bewaren in `saved_vacancies`;
  - de vier knoppen (`context.task`);
  - de statusregels `vacancySearch` en `vacancyMatch`;
  - logo's (`company-logo`), filters, Skill-kompas en "Over {bedrijf}".
- Vorm op web: het detail opent in het middenvlak, waar de kaarten nu staan, niet in een paneel van onderen.
- iOS: `ios/PAVE/Features/Ayla/Cards/Vacancies/`, `ios/PAVE/Features/Vacancies/`.

### 4. Sollicitaties: cv, brief en Mijn sollicitatie
- Staat nog niet op web (`application_drafts`).
- Eerst beslissen of web de cv-maker zelf bouwt (vraag 2 in [`voorstel-concepten-in-account.md`](voorstel-concepten-in-account.md)).
- Voorstel: begin met de lijst en Mijn sollicitatie (status, deadline, notitie), de editor later.
- iOS: `ios/PAVE/Features/Apply/`.

### 5. Ayla doet dingen in de app
- De server geeft web geen acties (`brain.ts` `cleanActions`, `prompt.ts` `NO_ACTIONS_PROMPT`) en geen "Kies zelf" (`consent.ts` `consentChoices`).
- De kiezer staat op web al klaar (`AylaVaultPicker`). Zet het op de server open als web de acties kan uitvoeren.
- iOS: `AylaAppAction.swift`, `AylaActivityPill`, `AylaPageDriver`.

### 6. Kluis
- **Statuswoorden:** web zegt nog "Bevestigd" en "Niet bevestigd" (`vaultMessages.ts`) en "In afwachting" (`verificationMessages.ts`).
  - Wordt: Niet geverifieerd, Wordt geverifieerd, Geverifieerd, Afgewezen.
  - Met de uitleg bij een klik op het label en de knop "Laten verifiëren".
- **Wallet-demo:** staat sinds PR #77 in `dev`, nog niet op web (iOS `Vault/Wallet/`, functie `vault-wallet`).

### 7. Ayla in de chat
- **Opleidingen en bronnen worden weggegooid:**
  - De server zoekt op web wel opleidingen (`educationSearch`) en feiten (`webLookup`).
  - Maar `aylaReply.ts` kent de kaarten `educations` en `sources` niet en laat ze weg. Ayla zegt dan dat ze iets vond, terwijl er niets te zien is.
- **Ook nog niet op web:**
  - het verslag van een oefengesprek;
  - een afspraak in je agenda zetten;
  - de conceptkaart "Bewijs in opbouw".

### 8. Kleinere punten
- **Chatlijst:** meerdere chats selecteren en in één keer verwijderen (iOS `AylaChatList.swift`).
- **Bijlagen:** plakken (foto of pdf) en slepen in het tekstveld van de chat.
- **Schermroutes:** in `aylaScreens.ts` ontbreken Meldingen en Vacatures, en `settings` stuurt naar het geheugen.
- **Sessie elders beëindigd:** iOS heeft een eigen scherm (`SessionEndedView`), web niet.
- **E-mail:** vastzetten, dempen, vergrendelen, doorsturen en hulp van Ayla (zie "E-mail in Meldingen (web)" in `ui-teksten.md`).
- **Filter en weergave:** "Datum" wordt "Volgorde"; Weergave in dezelfde volgorde als iOS.
- **`account_state`:** wacht op akkoord van het webteam ([`supabase-account-state.md`](supabase-account-state.md)).

## Waar web bewust anders is

| iOS | Web |
| --- | --- |
| Dynamic Bar en Dynamic Island voor het plan | De stappen op de plek van de chats, met een pil "Chats" erboven |
| Paneel van onderen (vacatures, kluis) | Middenvlak of eigen pagina; lijst links en detail rechts, zoals Meldingen |
| Vegen en lang indrukken | Menu bij hover of rechtsklik, selecteren met vinkjes |

## Alleen op iOS, met opzet

Face ID en de pincode van de app, Camera Control, Apple Watch, Dynamic Island, het toegangsscherm, Spotlight, de documentscanner, knikken met AirPods, de vacaturekaarten tijdens praten, de indeling voor iPhone Duo en trillingen. Die hoeven niet op web.

## Al gelijk

Streaming van antwoorden, herinneringen, projecten met bronnen, de zoektabs, vastzetten, archiveren, vergrendelen en verval van chats, bewijs toevoegen in stappen met "Laat Ayla invullen", mappen, archief, raster en lijst, account, apparaten, "Gegevens bewaren", inloggen met tweestapsverificatie, wachtwoord vergeten, Meldingen, verificatie aanvragen en de pagina Plan.
