# PAVE iOS

SwiftUI-app voor PAVE. Open `PAVE.xcodeproj` in Xcode 26 of nieuwer. Minimale versie: iOS 26. De iPhone-app en ingebedde Watch-app gebruiken respectievelijk iOS 26.0 en watchOS 26.0 als deployment target, zodat een Xcode 26-SDK de volledige app kan bouwen.

Bij een compileerfout op een MacBook: controleer eerst dat Xcode 26 of nieuwer actief is en dat de nieuwste PAVE-wijzigingen binnen zijn. Het verificatiedetail importeert `PAVECore` voor de kluiscategorieën; houd de argumentvolgorde van `NotificationsScreen` gelijk aan de propertyvolgorde en splits zware SwiftUI-viewexpressies op in kleine views.

## Structuur

```
PAVE/
  App/            PAVEApp, AppState (loading → login → pincode → main), RootView, PaveAppDelegate
    Services/     Keuze tussen echte en demo-diensten (AuthServiceFactory, AylaServiceFactory), Face ID, internetverbinding
    Shortcuts/    Sneltoetsen (PaveCommands) en Siri/Opdrachten (PaveAppShortcuts)
  DesignSystem/   Herbruikbare UI voor de hele app
    Buttons/      Knoppen, chips, vinkje
    Text/         Tekststijlen, titels, hulptekst, icoon met tekst
    Inputs/       Tekstveld, zoekveld, toetsenbord voor de pincode
    Feedback/     Meldingen, lege staat, offline-melding, trillingen, privacyscherm, MessageSlot
    Layout/       Indeling per toestel (AdaptiveLayout), maximale breedte, matchedFrame
  Features/       Eén map per feature van het takenbord
    Loading/
    Auth/         AuthFlow (navigatie + logica), Screens/, Components/
    Lock/         Pincode aanmaken en invoeren (PinSetupView, PinLockView, PinScreen)
    Main/         De app na het inloggen: MainView, Menu/ (zijbalk, lade, account, bel), Components/
    Ayla/         AylaRootView, en per onderdeel:
      Chat/       Het gesprek: AylaChatScreen, AylaChatModel, concepten; Components/ (berichten, welkom, keuzes, denken)
      Composer/   Het tekstveld en dicteren; Attachments/ (plusmenu, bijlagen, scannen, slepen en plakken)
      Voice/      Spraakbalk en volledig scherm; Audio/ (opnemen, afspelen, voorlezen), Orb/ (de orb en zijn beweging)
      Chats/      Chatoverzicht en zoeken; Components/ (lijst, rijen, voorbeeld, menu)
      Memory/     Wat Ayla over je weet: scherm, mapjes, model; Components/ (kaart in de chat, mapje, bewerken)
      Cards/      Kaarten in een antwoord: Vacancies/, VaultSelection/, bijlagekaart, onderblad
      Shared/     Wat meerdere onderdelen van Ayla gebruiken (AylaMessages, AylaUndoBar)
    Vault/        Kluis: mappen, filters, kaarten, detail, toevoegen en aanpassen, via Supabase
    Plan/         Plannen (nu nog leeg)
    Profile/      Profiel (nu nog leeg: delen bestaat nog niet)
    Settings/     Instellingen: je account en uitloggen
    Notifications/ Meldingen, filters, rolgebonden overzicht en aanvraagdetail (data-aansluiting volgt)
  Resources/      AppIcon.icon, Assets.xcassets (iconen)
PAVEWatch/        Apple Watch-app (spraakbot, geen volledige interface)
PAVEWidgets/      Widgets en knoppen voor het Bedieningspaneel (WidgetKit-extensie)
Shared/           Wat iPhone, Watch en widgets delen: kleuren, logo-letters, laadscherm, de PAVE-slash, fonts (Inter, Sora),
                  de links naar de app (`PaveLink`) en de opdrachten voor Siri (`PaveIntents`)
PAVETests/        Swift Testing
PAVECore/         Gedeelde logica voor iPhone en Watch (zonder UI): Auth/, Lock/, Layout/, Ayla/
```

Nieuwe features krijgen een eigen map in `Features/` (bijv. `Home/`, `Ayla/`, `Vault/`, `Plans/`, `Jobs/`, `Contact/`, `Settings/`, `Onboarding/`). UI-componenten die alleen de iPhone gebruikt, komen in `PAVE/DesignSystem/`. Alles wat iPhone en Watch allebei tonen, staat in `Shared/`.

## PAVECore: klaar voor de Apple Watch

Later krijgt PAVE een Apple Watch-app: geen volledige interface, maar een spraakbot waarmee je Ayla snel iets vraagt en PAVE handsfree bedient, met hooguit een kort antwoord en Ja/Nee-knoppen op het scherm. Alles wat iPhone en Watch allebei nodig hebben, staat daarom in het Swift-package `PAVECore` en niet in de app zelf:

- Modellen (kluisitems, statussen, plannen, vacatures).
- Ayla-logica, gesprekken en de acties die Ayla kan voorstellen (met bevestiging).
- Toestemming: wat Ayla mag zien.
- Mockdata laden.

Regels voor `PAVECore`:

- Geen SwiftUI of UIKit: alleen logica en data.
- Types die de app gebruikt, zijn `public`.
- Testen kan zonder simulator: `swift test --package-path PAVECore`.

## Schermen en indeling

De app draait op iPhone en iPad. Alle inlog- en pincodeschermen passen zich aan de schermgrootte aan, ook op de iPhone Duo (dichtgeklapt, uitgeklapt en half open). We volgen daarbij de richtlijnen van Apple voor de Duo: size classes in plaats van vaste breedtes of de stand van het toestel, en veilige zones in plaats van vaste marges.

- **Smal** (`horizontalSizeClass == .compact`: iPhone, Duo dichtgeklapt): alles onder elkaar, zoals in Figma.
- **Breed en staand** (regular, hoger dan breed: Duo uitgeklapt, iPad staand): het formulier op een kaart in het midden.
- **Breed en liggend** (regular, breder dan hoog): links het logo en de titel, rechts het formulier of toetsenbord.
- **Half open** (alleen iOS 27.1 of nieuwer): de app vraagt de vouwzone op (`reservedRegions(kind: .division)`) en verdeelt het scherm in twee velden aan weerszijden van de vouw. Titel en uitleg staan in het ene veld, formulier of toetsenbord in het andere. Er staat niets in de vouw. De berekening zit in `PAVECore/Layout/FoldSplit.swift` en is getest.
- De pincodeschermen meten hoeveel ruimte de tekst inneemt en maken de toetsen zo groot als er past. Bij heel grote tekst scrollen ze, in plaats van af te kappen.

De indeling zit in `AuthScreen` (inlog) en `PinScreen` (pincode), de keuze tussen de indelingen in `DesignSystem/Layout/AdaptiveLayout.swift`. Nieuwe schermen in de inlogflow gebruiken `AuthScreen { intro } content: { formulier }`.

Testen kan in Xcode via Device Hub (Window, Device Hub): kies de iPhone Duo en zet het toestel dicht, open, half open, gedraaid en in Split View. Controleer Split View aan beide kanten, want de veilige zone is niet aan beide kanten even breed.

## Afspraken

### Componenten

- **Iconen:** Heroicons Solid (https://heroicons.com/solid), als SVG in `Assets.xcassets` met `template-rendering-intent`, zodat ze de kleur van de tekst aannemen. Geen SF Symbols in de app, behalve waar iOS ze eist (knoppen in het Bedieningspaneel, de snelle acties op het app-icoon en Opdrachten) en waar Heroicons geen icoon hebben (vastzetten, de zijbalk wegklappen).

Een component in SwiftUI is een `View`, net als een `.vue`-bestand op web. Een scherm voegt kleinere componenten samen.

- **Eén component per bestand**, met dezelfde naam (`ChatBubble` staat in `ChatBubble.swift`). Een klein datatype dat alleen bij dat component hoort, mag erbij (zoals `AylaChoice` bij `AylaChoiceBar`).
- **Elk component heeft een `#Preview`**, zodat je het in Xcode los ziet, zonder de app te starten.
- **Waar komt een component?**
  - Bruikbaar in meer dan één onderdeel van de app (knoppen, invoervelden, chips, meldingen): `PAVE/DesignSystem/<Soort>/`, met `Pave` voor de naam (`PaveChip` in `Buttons/`, `PaveNotice` in `Feedback/`).
  - Alleen voor één onderdeel: `PAVE/Features/<Onderdeel>/Components/`. Is een feature groot (zoals Ayla), dan krijgt elk deel een eigen map met daarin weer `Components/`: `Features/Ayla/Chat/Components/`.
  - Een heel scherm: `PAVE/Features/<Onderdeel>/` (of `Screens/` bij veel schermen).
  - Logica zonder scherm (versturen, opslaan, regels): een model naast het scherm (`AylaChatModel`), of `PAVECore` als de Watch of web het ook nodig heeft.
- **Een component krijgt gegevens binnen en meldt acties terug**, zoals props en emits op web: `AylaComposer(text:onSend:)`. Het component praat zelf niet met de server.
- **Geen losse kleurcodes of lettertypes in de code.** Kleuren staan in de asset-catalogus (`Color.brandGreen`, `Color.cardTintRose`), tekst gebruikt `.textStyle(...)` uit `PaveTextStyle.swift`. Een nieuwe kleur of tekststijl voeg je daar eerst toe.
- **Teksten die een scherm vaker gebruikt of die meldingen zijn**, staan bij elkaar in een eigen bestand (`AuthMessages`, `AylaMessages`, `PinMessages`).

### Overig

- Na een wijziging in `PAVECore` gebruikt Xcode soms nog de oude versie. Kies dan Product, Clean Build Folder (⇧⌘K) en bouw opnieuw.
- De mappen `PAVE/`, `PAVEWatch/` en `PAVETests/` zijn gesynchroniseerd met Xcode: een bestand dat je in Finder of Xcode toevoegt, hoort automatisch bij het project.
- Werk zoveel mogelijk in je eigen feature-map om merge-conflicten te voorkomen.
- Alle teksten die de gebruiker ziet zijn Nederlands, ook als het Figma-ontwerp Engels is. Code en comments blijven Engels.
- **De teksten van de inlogflow zijn precies die van web, en web is leidend.** Verandert een tekst op web (`web/app/utils/messages.ts`, `passwordRules.ts` en de pagina's), pas hem dan ook op iOS aan. De foutmeldingen staan op één plek: `PAVECore/Sources/PAVECore/Auth/AuthMessages.swift`. `AuthMessagesTests` leest de webbestanden en faalt zodra een tekst verschilt.
- Mockdata die het web-team ook gebruikt, komt in `../shared/`.
- Zie `../Conventions.md` voor naamgeving en Git-afspraken.

## Draaien op je eigen iPhone

1. Kopieer `Config/Local.xcconfig.example` naar `Config/Local.xcconfig` (dit bestand staat in `.gitignore`).
2. Vul je eigen `DEVELOPMENT_TEAM` in. Je vindt het ID in Xcode onder Settings, Accounts, of in Signing & Capabilities.
3. Is `nl.fontys.pave` al in gebruik bij een ander Apple-account? Zet dan ook een eigen `APP_BUNDLE_IDENTIFIER` in `Local.xcconfig`.
4. Wil je echt inloggen? Zet dan ook `SUPABASE_URL` en `SUPABASE_PUBLISHABLE_KEY` in `Local.xcconfig` (zie het voorbeeldbestand). Laat je ze leeg, dan gebruikt de app de demo-accounts.
5. Zet op de iPhone de Ontwikkelaarsmodus aan (Instellingen, Privacy en beveiliging).

Met een gratis Apple-account verloopt de app na 7 dagen en moet je hem opnieuw installeren.

## Apple Watch

De Watch-app (`PAVEWatch/`) is een spraakbot voor snelle vragen en handsfree bedienen. Hij krijgt geen volledige interface. Nu bevat hij alleen het laadscherm en een tijdelijk Ayla-scherm. De Watch-app zit in de iPhone-app: een iPhone-build installeert hem op de gekoppelde Watch. Kies in Xcode het scheme `PAVEWatch` om hem los te draaien. Bundle-id: `<jouw APP_BUNDLE_IDENTIFIER>.watchkitapp`.

## Inloggen

De inlogflow staat in `PAVE/Features/Auth/`. De schermen praten nooit direct met een server, maar met het protocol `AuthService` in `PAVECore`. Er zijn twee implementaties:

- `SupabaseAuthService`: de echte inlog via Supabase (`supabase-swift`, product `Auth`).
- `MockAuthService`: demo-accounts zonder internet.

`AuthServiceFactory` kiest automatisch: staan `SUPABASE_URL` en `SUPABASE_PUBLISHABLE_KEY` in `Config/Local.xcconfig`, dan Supabase, anders de mock. Zie `Config/Local.xcconfig.example`; het zijn dezelfde waarden als in `web/.env`.

Wachtwoordvelden laten enters weg, net als een wachtwoordveld in de browser (`PasswordInput`): een wachtwoord dat je uit Notities of Mail plakt, neemt er vaak een mee, en dan lukt inloggen niet (uit gebruikerstest 1). Spaties blijven staan.

**Accounts worden nooit in de app aangemaakt.** Gebruikers krijgen hun account van de organisatie. De app kan alleen inloggen, tweestapsverificatie instellen en het wachtwoord resetten. Registreren staat in Supabase uit.

### Supabase-instellingen

Controleer dit in het dashboard van het gedeelde project:

- Authentication, Sign In / Providers: "Allow new users to sign up" staat uit.
- Authentication, Emails: de mail "Reset Password" bevat de code (`{{ .Token }}`). Web en iOS gebruiken dezelfde mail, dus er moet een code in staan en geen link.
- Authentication, Multi-Factor: TOTP staat aan (Enroll en Verify).
- Testaccounts maak je in Authentication, Users met "Auto Confirm User". Het profiel voeg je toe in de SQL Editor (tabellen `profiles` en `organizations`).

### Wachtwoord vergeten

Dezelfde flow als op web (`web/app/pages/forgot-password.vue`): e-mailadres invullen, een code van 6 cijfers per mail ontvangen, de code invullen en een nieuw wachtwoord kiezen. Er is geen link en dus geen diepe link in de app. Je kunt de mail op een ander toestel lezen en de code op je telefoon intikken.

- Supabase stuurt maximaal één mail per 60 seconden. De app toont dan "Wacht 60 seconden en probeer het opnieuw", net als web.
- Na het opslaan van het nieuwe wachtwoord word je uitgelogd en log je opnieuw in.
- Tweestapsverificatie is voor elk account verplicht. Supabase laat een wachtwoord pas wijzigen als ook de code uit de authenticator-app is ingevuld (anders weigert het met `insufficient_aal`). Daarom vraagt de app na de mailcode eerst die code, en daarna het nieuwe wachtwoord.
- Een nieuw account dat nog nooit heeft ingelogd, heeft nog geen tweestapsverificatie. Dat account gaat na de mailcode direct naar het nieuwe wachtwoord, en moet bij de eerste keer inloggen alsnog tweestapsverificatie instellen.
- Net als op web (sinds gebruikerstest 1) staat bovenaan een stappenbalk (`AuthSteps`): E-mail, Code uit e-mail, Authenticator-code, Nieuw wachtwoord. Bij een account zonder tweestapsverificatie valt de derde stap weg (`AuthFlow.resetSteps`).
- Het codescherm laat zien naar welk adres de code ging, half verborgen (`EmailMask`: `r***@student.example.edu`), met "Verkeerd e-mailadres? Terug". Een nieuwe code aanvragen kan pas 60 seconden na de vorige; de knop telt af.
- Bij het nieuwe wachtwoord krijgt het veld een oranje rand zolang het nog niet aan de eisen voldoet en een groene zodra het klopt. Onder de eisen staat "Nog 2 eisen te gaan". Het herhaalveld zegt "De wachtwoorden zijn hetzelfde." of "De wachtwoorden zijn niet gelijk." Dat laatste komt zodra het herhaalde wachtwoord even lang is, of als je het veld verlaat (op web alleen bij verlaten; op een iPhone verlaat je een veld zelden voor je opslaat). De knop werkt pas als alles klopt.
- Trillingen in de hele inlogflow, zoals in de chat (`PaveHaptics`): een fouttrilling bij elke melding die iets weigert (fout wachtwoord, foute code, wachtwoord voldoet niet), een succestrilling als een code klopt, een nieuwe code verstuurd is, of je wachtwoord of pincode is opgeslagen, en een licht tikje zodra je aan alle wachtwoordeisen voldoet en zodra de twee wachtwoorden gelijk zijn.
- Twee bewuste verschillen met web: plakken in het herhaalveld kan op iOS wel, omdat het sterke wachtwoord dat iOS voorstelt anders niet in beide velden komt (de hint zegt daarom alleen "Typ je wachtwoord nog een keer."). En er is geen Caps Lock-melding: het iOS-toetsenbord laat dat zelf zien.

### Tweestapsverificatie instellen op de iPhone

Een QR-code scannen kan niet op het toestel dat hem toont. Daarom opent de knop "Instellen op dit toestel" het systeemvenster van iOS, waar je Wachtwoorden of een authenticator-app kiest. De QR-code en de instelsleutel staan onder "Een ander apparaat gebruiken". Een account dat tweestapsverificatie al op web heeft ingesteld, krijgt op iOS direct het codescherm: de app vraagt de koppelingen bij Supabase op.

### Demo-accounts (mock)

| Account | Wachtwoord | Wat gebeurt er |
| --- | --- | --- |
| `ravi@student.example.edu` | `PaveDemo!2026` | Vraagt de verificatiecode |
| `new@student.example.edu` | `PaveDemo!2026` | Start de eerste instelling van tweestapsverificatie |

De code voor de tweestapsverificatie en voor wachtwoord vergeten is bij de demo-accounts altijd `123456`.

## PIN en Face ID

Na het inloggen maak je een PIN van 6 cijfers aan. Start je de app later opnieuw terwijl je nog bent ingelogd, dan vraagt PAVE eerst om die PIN. Je kunt ook Face ID of Touch ID aanzetten om sneller te ontgrendelen.

- De logica staat in `PAVECore/Sources/PAVECore/Lock/` (`PinVault`, `PinPolicy`). De PIN wordt nooit zelf bewaard: alleen een hash met een willekeurige salt (PBKDF2), in de Keychain van deze iPhone (`WhenUnlockedThisDeviceOnly`).
- Een PIN van 6 keer hetzelfde cijfer of een rij (bijv. `111111`, `123456`, `654321`) wordt geweigerd. Het scherm noemt die voorbeelden al vooraf, zodat je niet hoeft te raden wat niet mag (uit gebruikerstest 1).
- Een foute PIN schudt en trilt (`PinShake`), bij het aanmaken en bij het ontgrendelen. Zijn de twee PINs bij het aanmaken niet hetzelfde, dan ga je terug naar "Kies een pincode" en blijft de melding staan tot je het eerste cijfer typt.
- Na 5 foute pogingen word je uitgelogd en moet je opnieuw inloggen met wachtwoord en code. Dat geldt ook bij "Pincode vergeten?".
- De PIN hoort bij één account op dit toestel. Uitloggen bewaart hem: log je opnieuw in met hetzelfde account, dan hoef je geen nieuwe PIN te maken. Logt iemand anders in, dan wordt de oude PIN gewist en maakt die een eigen PIN aan. "Pincode vergeten?" en 5 foute pogingen wissen de PIN wel.
- Face ID/Touch ID zit in `AppState` via `BiometricAuthenticating`. De app opent hem alleen als je dat tijdens het instellen hebt aangezet.
- Het slot komt bij het opstarten van de app, en terug uit de achtergrond na de tijd die je kiest in Instellingen → Privacy → Opnieuw vergrendelen.

## Kluis

De iOS-uitwerking gebruikt de twee mobiele Figma-prototypes als basis: de lijst met categorieën en selecteerbare kaarten, en het uitschuifbare paneel waarin je kiest welke gegevens Ayla voor een taak mag gebruiken. De definitieve webbeelden zijn alleen geraadpleegd voor kaartvelden, statussen en de categorie-indeling; er is geen webcode aangepast.

- **Aangesloten op Supabase.** `VaultService` in PAVECore, met `SupabaseVaultService` (echt) en geen kluis bij het demo-account (`VaultServiceFactory`, net als Ayla). `VaultModel` houdt bij wat er geladen is; na elke wijziging leest hij de kluis opnieuw, zodat aantallen en mappen altijd kloppen met de server. Van de kluis staat op de telefoon alleen de kleur en het icoon van je eigen mappen, zolang de database daar nog geen kolommen voor heeft (zie Mappen).
- **Scherm (`VaultScreen`)** volgens Figma: bovenaan mappen (Certificaten, Diploma's, Feedback, Projecten, daarna andere categorieën zodra er iets in zit, en je eigen mappen). Daaronder één knop Filter (`VaultFilterBar`): één menu zonder submenu's, met de kopjes Status, Bron en Datum en een vinkje bij wat aanstaat. Nog een keer tikken zet een filter weer uit; Filters wissen zet alles uit. Staat er een filter aan, dan toont de knop hoeveel. Rechts wissel je tussen raster en lijst (dat onthoudt de app). Zoeken zoekt in titel, organisatie, plaats, omschrijving en vaardigheden. Laden toont grijze vormen op de plek van de kaarten (`VaultLoadingView`); leeg, niets gevonden, lege map, geen verbinding en demo hebben elk een eigen tekst (`VaultMessages`).
- **Kaarten (`VaultLibraryCard`)**: kleur per categorie, letter van de organisatie (geen echte logo's), status (`VaultStatusBadge`, kleuren uit Figma; de oranje is iets donkerder voor genoeg contrast), organisatie, periode en vaardigheden met "+2". Tik opent het item (`VaultItemDetailView`), lang drukken geeft Aanpassen, Verplaatsen naar map en Verwijderen (`VaultItemActionButtons`).
- **Toevoegen en aanpassen (`VaultItemEditor`)**: soort, titel, organisatie, plaats, datums (een periode of "Behaald op", afhankelijk van de soort), omschrijving en map. Controleert hetzelfde als de database. Wat je zelf toevoegt is altijd "Niet bevestigd"; een geverifieerd item of iets van een organisatie kun je niet aanpassen. Met wijzigingen vraagt Annuleren of je ze wilt weggooien. Een bestand toevoegen komt later (Storage).
- **Mappen** (`VaultFolderEditor`, in de stijl van het blad "Bewijs toevoegen" uit Figma): aanmaken via +, met een naam, een kleur (6) en een icoon (16, outline), en een voorbeeld van de map dat meteen meeverandert. Daarna "Map aangemaakt" met een vinkje en "Naar de map". De bovenkant van de map kleurt licht mee met de gekozen kleur (11% van die kleur op wit; bij groen precies de gewone tint). Liggend op een breed scherm staan voorbeeld en naam links, kleur en icoon rechts. Lang drukken op een map geeft Map aanpassen en Map verwijderen; items in een verwijderde map blijven in je kluis. Een naam die al bestaat, ook met andere hoofdletters, geeft een melding onder het veld. Kleur en icoon gaan naar `vault_folders.color` en `.icon` via de migratie `20261110170000_vault_cleanup_and_evidence_flow.sql` (uitgevoerd op 10 november). Ontbreken die kolommen ooit, dan bewaart de app ze op dit toestel.
- **Bladen (`paveSheet`, in `DesignSystem/Layout/`)**: op een telefoon schuift een blad omhoog maar stopt het naast de statuskolom van het buitenscherm van de iPhone Duo, in plaats van eronder door te lopen. Daarom staat het menu "…" van een item in de kop van het item en niet in de navigatiebalk (die zet zijn knoppen op de Duo in die kolom). Op brede schermen (iPad, de open Duo) is een blad een kaart in het midden. Getest op het buitenscherm van de Duo en op "PAVE Duo-binnen" (iPad mini) staand en liggend; de echte open Duo, en half gevouwen, nog niet.
- **Iconen**: Heroicons Solid, behalve de iconen op de mappen: die zijn outline, zoals in Figma (keuze Daaf).
- `VaultAccessSelectionPanel` en `VaultSelectionList` (Ayla-toestemming per vraag) zijn bijgewerkt naar het nieuwe model, maar nog niet zichtbaar: ze wachten op het toestemmingsendpoint (`vault_access_grants`).
- Previews gebruiken verzonnen items van Ravi (`VaultContents.preview`, alleen in Debug).

**Werkwijze voor volgende kluiswijzigingen:** gebruik de gedeelde `shared/`-contracten en iOS-stijlen, houd SwiftUI in `PAVE/Features/Vault/` en gedeelde modellen in `PAVECore` alleen wanneer meerdere targets ze nodig hebben. Werk de relevante sectie in deze README bij zodra schermgedrag, datamodel, beveiliging of de voortgang verandert. De webvoorbeelden zijn referentie; wijzigingen blijven in `ios/` tenzij web en iOS samen een contract aanpassen.

## Meldingen

`NotificationsScreen` bevat het iOS-overzicht volgens de aangeleverde wireframe: alle/ongelezen, zoeken, typefilter, groepering per dag en een detail voor verificatieaanvragen. Lerende accounts zien in de weergave alleen gesprekken en geverifieerd bewijs; de adminweergave toont gesprekken en verificatieaanvragen. Een gesprek kan terug naar Ayla navigeren; geverifieerd bewijs opent het eigen item in de kluis. Alleen de SwiftUI-previews bevatten voorbeeldmeldingen.

De iOS-meldingen gebruiken `NotificationsModel` en `SupabaseNotificationsService`: de inbox laadt van Supabase, markeren als gelezen wordt opgeslagen en Ayla-/verificatiemeldingen openen hun eigen bestemming. Een reviewer-aanvraag laadt een read-only kaart van het bewijs en geeft de toegewezen reviewer tijdelijke links (vijf minuten) om de originele bestanden in Quick Look te bekijken. Goedkeuren/afwijzen gaat via `vault-review`; de database werkt aanvraag, kluisstatus, auditlog en goedkeuringsmelding atomair bij.

Voor een eerste visuele controle staan statisch gerenderde iPhone-previews in `ios/previews/`. Ze volgen de huidige iOS-layout met fictieve inhoud, maar zijn geen captures van een draaiende SwiftUI-app. `render-notifications.ps1` maakt ze opnieuw.

De migraties `20261112160000_notifications_and_vault_review.sql` en `20261112170000_resolve_vault_validation.sql` zijn toegepast (respectievelijk bevestigd op 12 en 13 november 2026). Deployment van `shared/supabase/functions/vault-review/` is nog niet bevestigd. Reviewer-toewijzingen moeten via vertrouwde admin-provisioning in `vault_validation_reviewers` worden gezet; de webrepo beschrijft geen betrouwbare rolwaarden waarmee de app dit zelf veilig kan afleiden. Zonder deployment en toewijzingen blijft de echte flow onbeschikbaar. Zie `docs/vault.md` voor de backendvolgorde en grenzen.

## Ayla

Na het ontgrendelen opent `MainView` (`PAVE/Features/Main`) met Ayla. Ayla zelf draait op de server: de Edge Function `ayla` in `shared/supabase/functions/ayla`. De app bevat geen prompt en geen sleutels. Zie `docs/ayla.md`.

- **Welkom** (`AylaWelcome`, `AylaTypingTitle`): de lege chat begroet je met je voornaam uit `profiles`. De titel typt zichzelf uit met de PAVE-slash als cursor: de slash schrijft de letters en knippert twee keer. Daarna geeft hij blokje voor blokje over: de blokjes aan het eind verdwijnen van boven naar beneden, terwijl de echte slash vooraan zich van onder naar boven opbouwt (dezelfde slash die daarna blijft staan, dus aan het eind springt er niets). De hele titel staat vanaf het begin al op zijn plek (een `TextRenderer` tekent alleen de letters die er al zijn), zodat er niets verspringt. De tijd telt per beeldje, zodat een korte hapering bij het openen het typen laat wachten in plaats van overslaan. Met "Beweging beperken" aan staat de titel er meteen. Die komt van de server, dus het welkom wacht tot de naam er is en komt dan rustig in beeld, zodat de titel niet verspringt. Duurt het langer dan 1,5 seconde, dan verschijnt het welkom zonder naam en blijft het zo (een naam die later binnenkomt, wordt weggelaten).
- **Menu:** zelf naar een scherm gaan in plaats van alles via de chat. De A (Ayla) brengt je altijd terug naar de chat. De indeling volgt ChatGPT (`MainSidebar`), zoals Apple het doet: de inhoud begint bovenaan direct onder de statusbalk, de knoppen staan onderaan even ver van de onderrand als van de zijkant (16 punten), zodat ze de ronding van het scherm volgen, en "Nieuw gesprek" vult de ruimte naast je account. De kop richt zich nooit op knoppen in de zijkolom van de Duo; die staan halverwege het scherm. bovenin PAVE met rechts één knop, dan Ayla, Kluis, Plan en Profiel, en onderin links "Nieuw gesprek" (vanaf elk scherm terug naar Ayla met een lege chat) en rechts je account. Tik je op je account, dan zie je je naam, Instellingen en Uitloggen (met een vraag of je het zeker weet).
  - **iPhone en de opengeklapte Duo rechtop:** het menu schuift als effen paneel van boven tot onder tegen de linkerrand over het gedimde scherm, zonder zwevende ronde hoeken, net als bij ChatGPT en de zijbalk op iPad (`MainMenuDrawer`); rechtsboven de bel. Sluiten: naast het paneel tikken, het wegvegen of nog eens op de menuknop.
  - **iPad en de opengeklapte Duo dwars** (vanaf 800 punten breed): een zijbalk naast het scherm. Rechtsboven in de zijbalk klap je hem weg; dan komt linksboven de menuknop om hem terug te halen. De bel en je account delen onderin een glazen capsule.
  - **Buitenkant van de Duo:** de menuknop staat in de balk langs de zijkant. Open je het menu, dan wordt die knop een kruisje, komt in plaats van de chatknop een ronde knop voor een nieuw gesprek en staan je account en de bel onderin die balk, zoals bij ChatGPT (de knoppen melden hun plek via `reportMenuButtonFrame` en `reportChatsButtonFrame`).
  - De chats blijven achter de chatknop (keuze Daaf). Plan en Profiel tonen eerlijk een lege staat. Meldingen hebben het iOS-overzicht, zoeken, ongelezen-filter, typefilter, aanvraagdetail en doorklik naar een chat of eigen bewijs; zonder meldingenbron toont het scherm een lege staat en geen verzonnen aantal.
- `AylaRootView`: de chat (`AylaChatScreen`) en je chats (`AylaChatList`: zoeken, "Nieuw gesprek", Vastgezet en Chats). De chatknop rechtsboven opent ze.
- **Chats** (`AylaChatsScreen`, `AylaChatList`), achter de chatknop rechtsboven, zoals Mail en ChatGPT:
  - **Groepen:** Vastgezet, Vandaag, Gisteren, Afgelopen 7 dagen, Afgelopen 30 dagen en Eerder (`AylaConversationList.sections`). Onder elke titel de tijd of de dag, en "Op web" of "Op Apple Watch" als het gesprek daar begon (`started_on`).
  - **Acties:** veeg een chat naar rechts om hem vast te zetten of los te maken, naar links om de naam te wijzigen of hem te verwijderen (helemaal doorvegen verwijdert meteen). Houd hem ingedrukt voor een voorbeeld met de laatste berichten (`AylaChatPreview`) en dezelfde acties. VoiceOver heeft ze als acties op de rij. Een vastgezette chat staat meteen bovenaan, met een verse rij: de rij waarop je veegde is nog bezig zijn veegknoppen weg te werken en toont dan even geen tekst. Een verversing die niets zichtbaars verandert (vaak de echo van je eigen actie via live bijwerken) laat de lijst met rust (`looksTheSame`), zodat rijen niet opnieuw worden getekend. Tot de chats voor het eerst geladen zijn staan er grijze rijen, niet "Nog geen chats".
  - **Verwijderen en ongedaan maken:** een verwijderde chat verdwijnt meteen uit de lijst, met een balk "Chat verwijderd · Ongedaan maken" (`AylaUndoBar`), zoals Gmail. Pas na 5 seconden (of als je een volgende verwijdert, of de app naar de achtergrond gaat) verwijdert de app hem echt: het gesprek en de berichten gaan dan voorgoed weg uit de database (`on delete cascade`), ook op web. De app vraagt de verwijderde rij terug (`Prefer: return=representation`); komt er niets terug, dan heeft de database geweigerd en komt de chat terug met een melding. Hernoemen werkt net zo. Is het het open gesprek, dan begint de chat opnieuw.
  - **Selecteren:** onder de knop met drie puntjes rechtsboven (`AylaChatsMoreMenu`), op iPhone en in de brede kolom. Tik chats aan en zet ze in één keer vast of verwijder ze, met dezelfde balk om het ongedaan te maken.
  - **Trillingen in de hele app:** elke PAVE-knop geeft een licht tikje zodra je hem indrukt en geeft een beetje mee (`PaveButtonStyle`, `.buttonStyle(.pave)`); de grote groene knoppen een stevigere. Ook de menu- en chatknop bovenin en de knop met drie puntjes. In de chat: een tik als je bericht verstuurd is, een zachte als Ayla's antwoord binnenkomt en een fouttrilling als iets mislukt.
  - **Trillingen** (`PaveHaptics`, direct via iOS, omdat de SwiftUI-manier in een lijst met veegacties niet altijd doorkomt): bij vastzetten, verwijderen, ongedaan maken, een nieuwe naam bewaren, selecteren en elke aangetikte chat. Bij helemaal doorvegen en omlaag trekken trilt iOS zelf op het moment dat de actie gaat gebeuren.
  - **Live:** de lijst werkt zichzelf bij als je op web of je Apple Watch een chat begint of verandert (`followConversationChanges`, Supabase Realtime via `AylaRealtime`, alleen je eigen gesprekken dankzij de beveiligingsregels). Valt de verbinding weg, dan probeert de app het opnieuw, steeds iets later.
  - **iPhone-zoeken:** in Instellingen onder Privacy staat "Chats vindbaar in iPhone-zoeken", standaard uit. Aan zet de app alleen de titels van je chats in de zoekfunctie van je iPhone (`AylaSpotlight`, Core Spotlight); tik je een resultaat aan, dan opent die chat, ook als de app nog op slot zat (eerst je pincode). Uit, of uitloggen, haalt ze er meteen weer uit.
  - **Zoeken:** in de titels en in de berichten zelf (`searchMessages`, PostgREST `ilike`, vanaf 2 letters, pas als je even stopt met typen), met een stukje tekst waarin het zoekwoord vet staat.
  - **Laden:** omlaag trekken ververst; aan het eind laden oudere chats per 50. Tijdens het eerste laden staan grijze rijen in de vorm van echte chats; lukt laden niet, dan staat er een melding met "Opnieuw proberen"; zonder chats een lege staat.
  - **Nieuw gesprek:** onderin, binnen bereik van je duim (iPhone), of rechtsboven in de kolom met chats (brede schermen). De terugknop linksboven brengt je terug naar het gesprek.
  - Hernoemen en verwijderen vallen onder de bestaande beveiligingsregel "Own conversations"; er is geen databasewijziging voor nodig. Vastzetten werkt pas als de migratie `20261106120000_ayla_conversation_pins.sql` is gedraaid; tot dan verbergt de app die optie (`AylaConversationList.canPin`).
- **Een bericht vasthouden** (`ChatBubble.actions`), zoals in ChatGPT en Berichten: Kopiëren, Tekst selecteren (een blad met alleen dat bericht, waarin je een stuk kunt selecteren) en bij Ayla Voorlezen (in haar eigen stem van `ayla-voice`, met de iPhone-stem als die niet lukt; `AylaReadAloud`). Bij het laatste antwoord: Nieuw antwoord; bij je laatste vraag: Aanpassen (de vraag gaat terug in het tekstveld). Beide halen eerst je laatste vraag en Ayla's antwoord uit de database (`removeLastTurn`, onder de bestaande regel "Delete own messages"), zodat Ayla het oude antwoord niet meer in het gesprek ziet. Een nieuwe vraag wacht tot dat gelukt is. Lukt het niet, dan komt alles terug met een melding. Alleen de laatste beurt, zoals bij ChatGPT op de iPhone. VoiceOver heeft dezelfde acties.
- **Geheugen** (`AylaMemoryModel`, `AylaMemoryCard`, `AylaMemoryScreen`): Ayla onthoudt alleen wat jij goedkeurt. Vertel je iets blijvends, dan haalt Ayla elk feit apart uit je bericht ("ICT op Fontys" en "leidinggevende bij de Plus" worden twee), elk met een categorie (Opleiding, Werk en stages, Doelen, Vaardigheden, Wat je belangrijk vindt, Hoe je wilt werken, Interesses en hobby's, Over jou). Onder haar antwoord staat "Zal ik dit over je onthouden?" met een vinkje per feit, Onthouden en "Nee, niet nodig". Alleen wat aangevinkt is wordt opgeslagen (`ayla_memories`), daarna staat er "Onthouden · Bekijk wat Ayla weet". Wat Ayla al weet, ook in andere woorden, vraagt ze niet opnieuw (`AylaMemory.covers`). Maakt wat je vertelt iets ouds onwaar (een nieuwe baan, een diploma in plaats van "je studeert"), dan staat het oude als doorgestreepte regel op het kaartje om weg te halen, en heet de knop "Bijwerken". Vink je het uit, dan blijft het staan: je kunt twee banen hebben. Diploma's, afgeronde opleidingen, stages die voorbij zijn en vaardigheden stelt Ayla nooit voor om weg te halen. De uitleg onder het kaartje staat er alleen tot je een kaartje één keer hebt gebruikt. Alleen bij het nieuwste antwoord: een vraag waar je langs ging, komt niet terug. In Instellingen onder Ayla staat "Wat Ayla over je weet": een mapje per categorie (`AylaMemoryFolder`, in de stijl van de kluistegels), met daarin met waar het vandaan komt, vegen of tikken om aan te passen (tekst en categorie, `AylaMemoryEditor`) of te vergeten, zelf iets toevoegen (+), alles vergeten en het geheugen uitzetten. De tabellen (`20261109120000_ayla_memory.sql`) en de categorieën (`20261109160000_ayla_memory_categories.sql`) staan sinds 9 november in de database. Zonder tabellen zegt het scherm eerlijk dat het geheugen nog niet beschikbaar is; zonder de kolom met categorieën komt alles onder "Over jou". Zie `docs/ayla.md`, Memory.
- **Antwoord dat binnenstroomt:** Ayla's antwoord verschijnt woord voor woord terwijl ze schrijft (`AylaService.stream`, server-sent events van de functie `ayla`). De verstuurknop wordt dan een stopknop; stoppen laat staan wat er al stond, en de server bewaart dat ook. De spraakmodus krijgt het hele antwoord in één keer, omdat de stem de volledige tekst nodig heeft.
- **Gebaseerd op** (`AylaUsedMemories`): onder een antwoord dat steunt op wat Ayla over je weet, staat "Gebaseerd op: opleiding, werk en stages". Tik erop voor de herinneringen zelf en een weg naar "Wat Ayla over je weet". Zo zie je, zoals PAVE belooft, waar een advies vandaan komt.
- **Tijden in het gesprek** (`AylaTimeline`): boven het eerste bericht en na een pauze van 15 minuten, zoals Berichten: "Vandaag 14:02", "Gisteren 09:15", "Donderdag 18:40", "1 nov 14:02".
- **Bestanden slepen, plakken en scannen:** sleep een pdf, foto of tekstbestand de chat in (iPad, de opengeklapte Duo); er verschijnt "Laat los om aan je bericht toe te voegen" (`AylaDropTarget`). In het plusmenu plak je een gekopieerde foto of pdf ("Plakken" staat er alleen als er een foto of pdf op het klembord staat; iOS vraagt de eerste keer "PAVE wil plakken", en weigert iOS het, dan zegt de app waar je het toestaat) of scan je een document met de camera (`DocumentScanner`, VisionKit; meerdere pagina's worden één bijlage). Alles wordt op het toestel gelezen (`AttachmentReader`); alleen de tekst gaat met dat bericht naar Ayla.
- **Naar het nieuwste bericht:** scroll je een stuk omhoog, dan verschijnt boven het tekstveld een klein glazen rondje met een pijl (`ChatScrollDownButton`).
- **Wat je half typte blijft staan** (`AylaDrafts`): per chat, ook na het sluiten van de app. Alleen op dit toestel, weg bij uitloggen of als je de chat verwijdert.
- **Offline** (`PaveConnection`, `PaveOfflineNotice`): zonder verbinding staat boven het tekstveld rustig "Je bent offline. Wat je typt blijft staan tot je weer verbinding hebt." Typen kan, versturen en praten wachten. Het gesprek schuift op, zodat de melding nooit een bericht bedekt. Komt de verbinding terug, dan ververst de lijst met chats.
- **Toetsenbord:** tik naast het tekstveld (in het gesprek of het welkom) en het toetsenbord gaat dicht, zoals in Berichten en ChatGPT; omlaag vegen in het gesprek kan ook. Een knop in het gesprek (een starter, een vacaturekaart) werkt met dezelfde tik gewoon.
- **Plusje:** voegt iets toe aan je bericht, zoals bij ChatGPT of Claude: een item uit je kluis, een plan of een bestand. Kluis en plan zijn nog leeg, dus die regels zeggen waarom ze nog niet kunnen. Een bestand (pdf, foto of tekst) wordt op het toestel gelezen (`AttachmentReader`: PDFKit, Vision); alleen de tekst gaat met dat ene bericht mee naar Ayla en wordt niet bewaard. Maximaal 3 bestanden.
- `SupabaseAylaService` (PAVECore) stuurt je vraag met je eigen sessie naar de functie en leest je gesprekken uit `ayla_conversations` en `ayla_messages`.
- Met de demo-inlog (`MockAuthService`) is er geen Ayla: de chat zegt dat je met je eigen account moet inloggen. Er is geen nep-Ayla.
- Het scherm is 1:1 nagebouwd van de Figma-frames (440 × 956) en daarnaast gemeten. De maten staan in de componenten.
- Microfoon: dicteren zoals in ChatGPT (`SpeechDictation`, Nederlands, op het toestel als dat kan, anders via Apple). Tik op de microfoon en het tekstveld wordt een opnamebalk (`AylaDictationBar`): je woorden verschijnen live, een pixel-golf beweegt mee met je stem (`PixelLevelWave`) en de tijd loopt. ✕ gooit de opname weg, ✓ zet de tekst in het veld zodat je hem kunt nalezen voor je verstuurt. Een tikje (haptiek) bij starten en stoppen. Alleen de tekst gaat naar Ayla. Lukt herkennen niet, dan krijg je een melding in plaats van een knop die niets doet.
- Meldingen van Ayla hebben (nog) geen webversie; ze staan in `AylaMessages`.

### Praten met Ayla (spraakmodus)

Zoals de spraakmodus van ChatGPT en Claude, met de pixel-orb uit de spraakdemo (`experiment-ai-assistant-voice`).

- **Starten:** met een leeg tekstveld wordt de verstuurknop de golfjes-knop (`PixelWaveIcon`). De microfoon ernaast blijft dicteren: spraak wordt tekst in het veld.
- **Beurten** (`AylaVoiceSession`): Ayla luistert, en na 1,2 seconde stilte stuurt ze je vraag. Daarna denkt ze na, leest haar antwoord voor en luistert weer, tot je stopt. Je vragen en haar antwoorden staan gewoon in de chat, ook kaarten zoals vacatures.
- **Onderbreken:** praat door Ayla heen (na 0,8 seconde en met minstens twee woorden, zodat een kuchje haar niet stopt), of tik op de orb. Tik je op de orb terwijl ze luistert, dan gaat je vraag meteen weg.
- **Echo:** microfoon en speaker draaien op één audio-engine met spraakverwerking (`setVoiceProcessingEnabled`), zodat de microfoon Ayla zelf niet hoort. Dit werkt alleen goed op een echte iPhone.
- **Herkenning:** in het Nederlands (`SFSpeechRecognizer`, nl-NL), op het toestel als de Nederlandse spraakbestanden erop staan, anders via Apple (de toestemmingsvraag zegt dat). De simulator heeft geen Nederlandse spraakbestanden en gebruikt dus altijd Apple. Alleen tekst gaat naar Ayla. De nieuwe `SpeechTranscriber` van iOS 26 kent nog geen Nederlands. Woorden die vaak vallen (Ayla, PAVE, kluis, cv, stage) krijgt de herkenner als hint mee.
- **Let op, Swift 6:** vraag toestemming voor spraakherkenning altijd buiten de main actor (`VoiceRecognizer.requestPermission()`). iOS geeft het antwoord op een achtergrondthread, en een main-actor-callback daar laat de app crashen. Zo crashte de microfoonknop eerst.
- **Stem:** van de server (Edge Function `ayla-voice`, OpenRouter `openai/gpt-audio-mini`, stem `coral`), gestreamd als pcm16 van 24 kHz. Ayla blijft "nadenken" tot haar stem echt klinkt. Lukt de stem niet, of klinkt er na 8 seconden nog niets, dan leest de Nederlandse stem van de iPhone voor (`DeviceVoice`), zodat Ayla nooit stil valt. Bij het starten van de spraakmodus maakt de app beide serverfuncties alvast wakker (`warmUp()`, een OPTIONS-verzoek zonder vraag), zodat het eerste antwoord na het openen van de app niet op een koude server wacht.
- **Schermvullend op de iPhone** (`AylaVoiceStage`), zoals de aparte spraakmodus van ChatGPT: de orb groot in het midden met één regel eronder (wat je zegt, het begin van Ayla's antwoord, of wat ze doet). Het gesprek groeit op de achtergrond gewoon mee en staat er als je stopt. De regel staat 44 punten onder de orb en het pixelveld laat er een rustige zone omheen, zodat hij altijd leesbaar is. Sleep de orb omlaag om het gesprek te zien, zoals in ChatGPT (`AylaOrbMotion`, getekend door `AylaOrbTrack`). Het gedrag is gemeten op een schermopname van ChatGPT, beeld voor beeld: de orb volgt je vinger niet, maar geeft mee als elastiek (hooguit 70 punten, steeds minder naarmate je verder trekt) en rekt uit naar je vinger (veel langer, iets breder). Trek je verder dan 80 punten, of veeg je, dan springt hij bij loslaten in één snelle beweging naar zijn andere plek: hij krimpt meteen, schiet even voorbij zijn nieuwe maat en veert terug, terwijl hij naar beneden vliegt. Omhoog werkt hetzelfde: hij groeit even voorbij zijn maat. Trek je niet ver genoeg, dan veert het elastiek hem terug. Het gesprek verschijnt pas als de orb onderaan geland is, en verdwijnt meteen als hij weer groot wordt; de regel onder de grote orb doet het omgekeerde. Dat kan overal in het middengebied, niet alleen precies op de orb, en ook in een leeg gesprek. De orb is één en dezelfde, getekend boven alles; het volledige scherm en de spraakbalk houden alleen zijn plek vrij (de plek boven de spraakbalk is er altijd, zodat er niets verspringt). Terwijl hij springt breekt zijn pixelstructuur open: blokjes blijven achter hangen en klikken bij aankomst weer samen. Groot naar klein bij het eerste bericht op iPad glijdt rustig, zonder vinger. De veren zijn geen SwiftUI-animaties maar draaien zelf, beeld voor beeld, zodat ze altijd verdergaan vanaf waar de orb echt is. Alleen de orb, het veld eromheen en het vervagen (`AylaOrbFade`) lezen zijn beweging, zodat de rest van het scherm niet elk beeldje opnieuw wordt opgebouwd. De app mag op 120 beelden per seconde draaien (`CADisableMinimumFrameDurationOnPhone` in `Info.plist`); zonder die sleutel blijft een iPhone met ProMotion voor eigen animaties op 60 hangen. Haptiek: een duidelijke tik zodra loslaten zou wisselen, een stevige klik bij loslaten, een zachte landing op het moment dat hij zijn plek bereikt en een zacht tikje als hij terugveert. VoiceOver heeft er een actie voor ("Gesprek tonen" of "Volledig scherm").
- **iPad en de opengeklapte Duo:** in de chat, zoals ChatGPT op web: de kleine orb boven de spraakbalk met het gesprek in beeld (omhoog slepen kan ook daar). Alleen in een leeg gesprek staat de orb groot in het midden.
- **Orb** (`AylaPixelOrb`, overgezet van `PixelOrb.vue` uit de demo): 23 × 23 pixelblokjes in zeven groentinten, met de toestanden rust, luisteren, nadenken en praten. De demo dempt per beeldje bij 60 beelden per seconde; omdat iPhones tot 120 tekenen, rekent de orb dat om naar tijd, zodat de overgangen even snel gaan als in de demo. Hij reageert op het volume (`VoiceMeter`). Noemt Ayla de kluis, een plan, je cv of werk, dan vormen de blokjes even dat icoon (`AylaVoiceCue`, `AylaPixelIcons`). De zachte geluidjes bij luisteren en nadenken komen ook uit de demo (`VoiceBlip`).
- **Pixelveld** (`AylaAmbientField`, overgezet van `AmbientField.vue`): golven over de achtergrond die per toestand anders lopen (luisteren naar binnen, nadenken schuin, praten naar buiten), een ring om de orb die als een equalizer meebeweegt met 24 frequentiebanden (`VoiceMeter`, met `vDSP` zoals de analyser in de browser; salie als jij praat, groen als Ayla praat). De ring groeit mee als de orb opzwelt. De losse rondvliegende blokjes uit de demo zitten er bewust niet in (keuze Daaf). Bij de start rolt het veld vanuit de orb uit. Het veld meet zijn eigen plek op het scherm (het loopt door onder de balken) en krijgt elk beeldje de plek van de orb, zodat alles precies om de orb heen blijft, ook tijdens het slepen of als hij met het toetsenbord meegaat. De ring zet de lage tonen (meestal de luidste) bovenaan, weg van de tekst.
- **Intro en outro** (`AylaVoiceIntro`): de blokjes van de orb komen in een draai uit de golfjes-knop en vormen de orb; daarna neemt de echte orb het over. Bij stoppen valt de orb uiteen en draaien de blokjes terug de knop in. Zonder het PAVE-logo uit de demo (keuze Daaf). Met "Beweging beperken" aan is er geen intro of outro.
- **Niets mag haperen:** de audio-engine en de spraakherkenner starten buiten de main thread (`AylaVoiceSession.queueAudio`, `VoiceRecognizer.reserve`/`begin`). Op de main thread hielden ze de intro eerst een halve seconde stil.
- **Van invoerveld naar spraakbalk:** de balken wisselen niet, ze versmelten. Het invoerveld krimpt tot het veld van de spraakbalk (`matchedFrame`, een gedeeld frame) en de dempknop en stopknop schuiven er verend uit; bij stoppen groeit het veld weer terug. Dat gebeurt meteen bij de tik (`isTalking`, in een animatie), niet pas als de spraaksessie klaar is met starten. De automatische morph van Liquid Glass (`glassEffectID`) werkte hier niet tussen twee losse balken.
- **Niets springt:** tijdens het praten blijft de ruimte onder het gesprek gelijk (de extra ruimte voor "Ayla denkt na" hoort alleen bij typen), anders schoof de orb bij het nadenken 17 punten omhoog.
- **Elke beurt voelbaar:** je vraag gaat weg (stevige tik), Ayla begint te praten (zachte tik), jij bent weer aan de beurt (lichte tik). Zo weet je zonder te kijken waar het gesprek is.
- **Tekst bij praten met Ayla** (Instellingen → Ayla, staat standaard aan): de regel onder de orb volgt Ayla zin voor zin. Zet je hem uit, dan staat er geen tekst meer onder de orb; zijn plek blijft vrij, zodat de orb niet verspringt. De stem geeft geen tijden door, dus de app schat waar Ayla is, net als bij de iconen in de orb (`AylaCaptions`, 15 tekens per seconde).
- **Spraakbalk** (`AylaVoiceBar`), zoals de spraakmodus van ChatGPT: links een glazen veld met het plusje en "Vraag het aan Ayla" (getypt antwoordt Ayla ook hardop, `send(typed:)`), dan een ronde knop om te dempen en een groene ronde knop met ✕ om te stoppen. De spraakmodus stopt ook als je de app verlaat (naar de achtergrond; niet bij "even inactief", want dat gebeurt ook bij de toestemmingsvragen bij de eerste start) of een ander gesprek opent. Tijdens het praten blijft de denk-gloed onderin het scherm weg: de orb laat al zien dat Ayla nadenkt.

### Buiten de app: Siri, widgets, Bedieningspaneel en sneltoetsen

Alles hieronder opent alleen de app. PAVE vraagt dus eerst je pincode of Face ID en laat buiten de app niets van je zien.

- **Siri, Opdrachten, Spotlight en de Actieknop** (`PaveAppShortcuts`): "Praat met Ayla in PAVE" begint een nieuw gesprek waarin Ayla meteen luistert; "Nieuw gesprek in PAVE" opent een lege chat. Ze staan zonder instellen in de Opdrachten-app en zijn te kiezen voor de Actieknop. De opdrachten (`PaveIntents`) brengen de app naar voren en geven het verzoek door via `PaveLinkInbox`; `AppState.link` bewaart het tot de app ontgrendeld is. Vanuit de widget-extensie lukte het openen van een link niet ("Couldn't find shortcut"), daarom draaien ze in de app zelf.
- **Widgets** (`PAVEWidgets`): klein (praat met Ayla), middel (praten of een nieuw gesprek) en voor het toegangsscherm (rond en rechthoekig). In de stijl van het laadscherm. Ze tonen geen chats of naam, omdat ze zichtbaar zijn zonder de iPhone te ontgrendelen.
- **Bedieningspaneel** (`AylaControls`): de knoppen "Praat met Ayla" en "Nieuw gesprek met Ayla", ook te zetten op het toegangsscherm of onder de Actieknop.
- **Snelle acties op het app-icoon** (`UIApplicationShortcutItems` in `Info.plist`, `PaveAppDelegate`): houd PAVE ingedrukt op het beginscherm voor "Praat met Ayla" en "Nieuw gesprek". Ze gaan dezelfde weg als Siri.
- **Verder op een ander toestel** (Handoff, `AylaHandoff`): de chat die je open hebt, staat op je andere Apple-toestellen klaar (het PAVE-icoon in de Dock of de appwisselaar). Alleen het id van het gesprek reist mee, met de algemene titel "Gesprek met Ayla"; het andere toestel laadt het met je account, achter zijn eigen pincode. Je chats zelf staan sowieso op al je toestellen, want ze horen bij je account.
- **Opnieuw vergrendelen en privacy** (`AppState.didEnterBackground`/`didBecomeActive`, `PavePrivacyCover`): ben je langer weg dan ingesteld (Instellingen, Privacy: meteen, 1, 5 of 15 minuten; standaard 5), dan ligt het pincodescherm over de app, die zelf blijft staan zoals hij was. In de appwisselaar en onder het Bedieningspaneel zie je alleen het PAVE-logo. Siri, widgets en de zoekfunctie wachten tot je ontgrendeld bent.
- **Links:** `pave://ayla/praat-met-ayla` en `pave://ayla/nieuw-gesprek` (`PaveLink`). Testen: `xcrun simctl openurl booted pave://ayla/praat-met-ayla`.
- **Sneltoetsen** (`PaveCommands`), voor iPad en de Duo met een toetsenbord, in de menubalk en in het overzicht als je ⌘ ingedrukt houdt: ⌘N nieuw gesprek, ⌘K zoeken in chats (het zoekveld krijgt meteen het toetsenbord), ⇧⌘V praat met Ayla, ⌃⌘S menu tonen of verbergen (in plaats van de knop van iOS zelf, anders crasht de app op een dubbele sneltoets) en ⌘, Instellingen.
- **Taal:** de ontwikkeltaal van het project is Nederlands (`developmentRegion = nl`), zodat ook de teksten van iOS zelf in de app Nederlands zijn (zoals "Kopiëren" en de menubalk) en Siri de Nederlandse zinnen herkent.

### Per toestel

| Toestel | Menu | Chats | Vacatures |
| --- | --- | --- | --- |
| iPhone, Duo dichtgeklapt, Duo open en rechtop | Effen menu tegen de linkerrand dat over het gedimde scherm schuift. Op de buitenkant van de Duo worden de knoppen in de zijbalk een kruisje en een nieuw-gesprek-knop, met je account en de bel onderin; de gewone menu- en chatknop verdwijnen zolang het menu open is, zodat er geen tweede glazen rondje onder ligt | Ronde glazen chatknop rechtsboven: eigen pagina met "Nieuw gesprek" onderin | Paneel van onderen, het invoerveld zweeft erover |
| iPad, Duo open en dwars (vanaf 800 punten) | Zijbalk naast het scherm die je weg- en terugklapt | Chatknop linksboven naast de zijbalk. Breed genoeg (860 punten naast de zijbalk): kolom naast de chat. Anders: eigen pagina | Paneel van onderen, kaarten maximaal 600 punten breed in het midden |
| Duo half gevouwen (vouw van boven naar beneden) | Vult het veld links van de vouw, zonder knop om weg te klappen | Chatknop in het veld rechts van de vouw: eigen pagina in dat veld | Paneel van onderen |

- **Knoppen in de balk aan de zijkant (Duo):** de menuknop en de chatknop zijn gewone toolbarknoppen. Dan zet iOS ze op de Duo verticaal onder de statusbalk. Eigen knoppen of `sharedBackgroundVisibility(.hidden)` houden ze horizontaal, dus dat niet doen.
- **Liquid Glass:** het iPhone-menu, plusmenu, zoekveld, invoerveld, de ronde knoppen en "Terug naar gesprek" zijn glas (`glassEffect`), omdat ze boven de inhoud zweven. Kaarten en ballonnen niet.
- **Geen harde randen:** het gesprek vervaagt zacht onder de bovenbalk en achter het invoerveld (`scrollEdgeEffectStyle(.soft)` en een onzichtbare `safeAreaBar` op de plek van het invoerveld). Er is geen eigen kopvlak meer dat berichten afsnijdt.
- **Bovenmarge in de inhoud, niet in `contentMargins`:** iOS 26.0 telt scrollmarges dubbel als het een kort gesprek onderaan zet, waardoor het onder het invoerveld viel (gezien op iPad met iOS 26.0).
- **Vormen:** 8 voor de menutegels (zoals op web), 12 voor kleine dingen (rijen, bijlagen), 14 voor knoppen, chips en velden, 25 voor zwevend glas (invoerveld, plusmenu, "Terug naar gesprek"). Het glazen menu op de iPhone volgt de hoek van het scherm (`ConcentricRectangle`).
- **Duo open testen:** Device Hub laat zich niet vanaf de command line bedienen. Klap de simulator met de hand open en draai hem; daarna kun je met `xcrun simctl io <toestel> screenshot --display=3 --mask=black` het binnenscherm vastleggen (display 1 is het buitenscherm).
- **Titels van chats:** Ayla geeft een nieuw gesprek zelf een korte titel van 2 tot 5 woorden. Lukt dat niet, dan knipt de server de eerste vraag af op een heel woord, met "…".
- Achtergronden (header, paneel) lopen door tot de rand; inhoud blijft binnen de veilige zone, die op de Duo aan één kant breder kan zijn.

### Nog niet in de app

- De kluiskeuze uit Figma ("Alle items", kaarten met vinkjes, "Verder") en de kaart "2 gegevens geselecteerd" zijn gebouwd (`VaultSelectionList`, `VaultSelectionBar`, `ChatAttachmentCard`), maar alleen te zien in de Xcode-voorbeelden. Ze gaan aan zodra de kluis bestaat.
- Bedrijfslogo's: Adzuna levert die niet, dus de kaarten tonen de eerste letter van het bedrijf.
