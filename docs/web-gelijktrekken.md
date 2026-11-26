# Web en iOS gelijktrekken

Stand van 2026-11-24. Een vergelijking van de code van `web/` en `ios/` liet zien waar de twee apps verschillen. Daaf besliste over de open punten; dit is wat het webteam (Yassine, Iqra) nog moet aanpassen, met per punt waar het op iOS staat. Teksten staan in [`ui-teksten.md`](ui-teksten.md); gebruik die woorden letterlijk.

## Besluiten

| Punt | Besluit |
| --- | --- |
| Bewijs toevoegen vanuit de chat | Combineren: de conceptkaart van iOS met de keuzes van web. iOS heeft dit al (zie hieronder); web neemt de kaart over. |
| "Gebaseerd op" onder Ayla's antwoord (gebruikte herinneringen en kluis) | Tonen, zoals iOS. Web verborg het op verzoek van de product owner: eerst met de product owner afstemmen, dan tonen. |
| Filter in de kluis | Vorm per platform houden (iOS één Filter-menu, web chips). Alleen de woorden gelijk: "Volgorde" in plaats van "Datum". |
| Privacypagina in Instellingen | Zo laten; het verschil hoort bij het platform (vergrendelen en Spotlight bestaan alleen op de iPhone). |

## Wat web moet aanpassen, belangrijkste eerst

### 1. Vacatures
- **Paneel over de chat** met tabs Gevonden en Bewaard, een vacature open met "Past bij jou", "Wat je nog mist" (met de regel uit de vacaturetekst), een stukje tekst en "Lees de hele vacature", en bovenaan wat Ayla zocht en welke gegevens ze gebruikte. iOS: `ios/PAVE/Features/Ayla/Cards/Vacancies/` (`AylaVacancyShelf`, `VacancyList`, `VacancyDetail`, `VacancySearchSummary`). Web toont nu alleen een raster kaarten in `components/ayla/chat/AylaCanvas.vue`.
- **Bewaren** in de tabel `saved_vacancies` (migratie is al uitgevoerd). iOS: `AylaService.swift` (`savedVacancies`, `saveVacancy`, `removeSavedVacancy`), knop `VacancySaveButton`.
- **De vier knoppen** Wat mis ik? / Solliciteren / Oefen gesprek / Vergelijk (2 of 3). Ze sturen `context.task` (`compare`, `gaps`, `prepare`, `interview`) met `context.vacancy` of `context.compare`; tijdens het oefenen gaat `task: 'interview'` met elke vraag mee tot je stopt. De server accepteert dit al van elk apparaat (`shared/ayla/reply.schema.json`). iOS: `VacancyActions`, `VacancyCompareBar`, `VacancyPracticeBar`, en `AylaChatModel.question(for:about:)`.
- **Logo's**: zonder logo vraagt iOS de functie `company-logo` (POST `{ company, city }`, antwoord `{ logoUrl? }`), één keer per bedrijf; anders een icoon van een gebouw, nooit een letter. iOS: `CompanyLogo.swift`.
- **Wat Ayla doet tijdens het zoeken**: de stream stuurt `status`-gebeurtenissen (`vacancySearch`, `vacancyMatch`); iOS toont "Ayla zoekt vacatures: …" en "Ayla vergelijkt {n} vacatures met je kluis…". Web negeert ze in `useAyla.ts`.
- **Typen**: `Vacancy` mist `summary` en `postedAt`; het vacatureblok mist `search`.
- **Woorden**: "Skill-gap" → "Wat je nog mist"; "Bekijk vacature" → "Lees de hele vacature"; lege lijst "Nog geen vacatures". Zie "Vacatures in de Ayla-chat" in `ui-teksten.md`.

### 2. Meldingen
- iOS heeft een echte inbox op `vault-review`: soorten Gesprek / Verificatie / Afgewezen bewijs / Verificatie aanvraag, Vandaag / Gisteren / Eerder, zoeken, filter, ongelezen, vegen om te verwijderen, "Recent verwijderd" (7 dagen), en als beoordelaar "Verifieer document" / "Aanvraag afwijzen" met een reden. iOS: `ios/PAVE/Features/Notifications/`, `PAVECore/.../NotificationsService.swift`. Web `pages/meldingen.vue` is nog leeg.

### 3. Kluis: verificatie
- **Echte aanvraag**: op iOS kies je via de vertrouwde lijst organisatie → locatie → afdeling → contactpersoon en gaat de aanvraag via `vault-review`. Web `components/vault/add/VaultRequestDialog.vue` is een formulier dat niets verstuurt. iOS: `ios/PAVE/Features/Vault/RequestConfirmation/`.
- **"In afwachting" en de reden bij afwijzen**: iOS leest `vault_validation_requests` en toont het label met klok, de uitleg, en "Reden van {organisatie}"; tijdens een open aanvraag verdwijnt de knop om te vragen. Het web-type `VaultItem` heeft nog geen velden voor de aanvraag.
- **Statuswoorden**: web zegt "Bevestigd", iOS "Geverifieerd". Op de branch `feat/ios/wallet-demo` (nog niet in `dev`) worden het vier woorden: Niet geverifieerd / Wordt geverifieerd / Geverifieerd / Afgewezen, met een uitleg als je op het label tikt en de knop "Laten verifiëren". Neem die over zodra die branch in `dev` staat.
- **Wallet** ("Haal bewijs uit je wallet", demo voor Npuls) staat op dezelfde branch.

### 4. Ayla doet dingen in de app
- Op iOS verandert Ayla zelf instellingen, opent ze mappen en pagina's en bewaart ze vacatures (`AylaReply.actions`, `continues`; in de vraag `app` en `results`), met een balk die haar stappen laat zien. iOS: `AylaAppAction.swift`, `AylaAppCommand.swift`, `AylaActivityPill`, `AylaPageDriver`.
- **Serverwijziging nodig**: de functie `ayla` geeft acties en de keuze "Kies zelf" nu alleen aan `device === 'phone'` (`brain.ts` `cleanActions`, `consent.ts` `consentChoices`). Dat zetten we open voor web zodra web ze kan uitvoeren; zeg het als je zover bent, dan doet het iOS-team de serverkant.
- **"Kies zelf"** bij Ayla's vraag om de kluis: web heeft de kiezer al (`AylaVaultPicker`), alleen de keuze ontbreekt door de server.

### 5. Kleinere punten
- **Bewijs toevoegen vanuit de chat**: de conceptkaart "Bewijs in opbouw" overnemen (velden, bestanden aan en uit, "Zet in de kluis", "Zelf invullen"). De stap "Logo kiezen / Omslag kiezen / Klaar" heeft web al; iOS heeft hem nu ook. iOS: `AylaEvidenceConceptCard`, `AylaChatScreen` (`addEvidenceForUser`, `fillMyself`, `LookStep`).
- **Pagina's over de chat**: Kluis, Plan, Profiel, Instellingen, Meldingen en Vacatures openen op iOS over de chat. Op web alleen de kluis; `SCREEN_ROUTES` stuurt `settings` naar het geheugen en kent geen `vacancies`, `notifications`, `vaultItem` en `addEvidence`.
- **Chatlijst**: meerdere chats selecteren en in één keer verwijderen (iOS `AylaChatList.swift`).
- **Bijlagen**: plakken (foto of pdf) en slepen in de chat.
- **Filter in de kluis**: "Datum" → "Volgorde".
- **Weergave**: dezelfde volgorde als iOS: Themakleur, Licht of donker, Weergave kluis, Tekstgrootte, Animaties uitzetten.
- **Sessie elders beëindigd** (wachtwoord op een ander apparaat veranderd): iOS heeft hier een eigen scherm (`SessionEndedView`); web lijkt dat niet te hebben. Controleren.

### 6. Vacatures en sollicitaties (nieuw op iOS, 2026-11-24)
- **Menu Vacatures**, onder Kluis: Gevonden (Ayla's laatste zoekopdracht), Bewaard en Sollicitaties. iOS: `ios/PAVE/Features/Vacancies/VacanciesScreen.swift`.
- **Cv en motivatiebrief** per vacature met galerij, "Wat komt erin?", dekking per eis, Ayla die doorvraagt en een vinkje bij geverifieerd bewijs; **Mijn sollicitatie** met status, deadline, herinneringen en geschiedenis. Alles staat nog alleen op het toestel; zie [`voorstel-concepten-in-account.md`](voorstel-concepten-in-account.md) voor bewaren in het account. iOS: `ios/PAVE/Features/Apply/`.

## Alleen op iOS, met opzet

Face ID en de pincode van de app, Camera Control, Apple Watch, Dynamic Island, Spotlight, de documentscanner, knikken met AirPods, de vacaturekaarten tijdens praten, de indeling voor iPhone Duo en trillingen. Die hoeven niet op web.

## Al gelijk

Streaming van antwoorden, herinneringen, projecten met bronnen, de zoektabs, vastzetten / archiveren / vergrendelen / verval van chats, bewijs toevoegen in stappen met "Laat Ayla invullen", mappen, archief, raster en lijst, account, apparaten, "Gegevens bewaren", inloggen met tweestapsverificatie, wachtwoord vergeten, en de lege pagina's Plan en Profiel.
