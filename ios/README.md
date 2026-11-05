# PAVE iOS

SwiftUI-app voor PAVE. Open `PAVE.xcodeproj` in Xcode 26 of nieuwer. Minimale versie: iOS 26.

## Structuur

```
PAVE/
  App/          PAVEApp, AppState (loading → login → pincode → main), RootView
  DesignSystem/ Herbruikbare UI: tekststijlen, knoppen, tekstveld, melding, toetsenbord voor de pincode
  Features/     Eén map per feature van het takenbord
    Loading/
    Auth/       AuthFlow (navigatie + logica), Screens/, Components/
    Lock/       Pincode aanmaken en invoeren (PinSetupView, PinLockView, PinScreen)
  Resources/    AppIcon.icon, Assets.xcassets (iconen), Fonts/ (Inter)
PAVEWatch/      Apple Watch-app (spraakbot, geen volledige interface)
Shared/         UI en assets voor iPhone en Watch (kleuren, logo-letters, laadscherm)
PAVETests/      Swift Testing
PAVECore/       Gedeelde logica voor iPhone en Watch (zonder UI): Auth/, Lock/, Layout/
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

De indeling zit in `AuthScreen` (inlog) en `PinScreen` (pincode), de keuze tussen de indelingen in `DesignSystem/AdaptiveLayout.swift`. Nieuwe schermen in de inlogflow gebruiken `AuthScreen { intro } content: { formulier }`.

Testen kan in Xcode via Device Hub (Window, Device Hub): kies de iPhone Duo en zet het toestel dicht, open, half open, gedraaid en in Split View. Controleer Split View aan beide kanten, want de veilige zone is niet aan beide kanten even breed.

## Afspraken

### Componenten

Een component in SwiftUI is een `View`, net als een `.vue`-bestand op web. Een scherm voegt kleinere componenten samen.

- **Eén component per bestand**, met dezelfde naam (`ChatBubble` staat in `ChatBubble.swift`). Een klein datatype dat alleen bij dat component hoort, mag erbij (zoals `AylaChoice` bij `AylaChoiceBar`).
- **Elk component heeft een `#Preview`**, zodat je het in Xcode los ziet, zonder de app te starten.
- **Waar komt een component?**
  - Bruikbaar in meer dan één onderdeel van de app (knoppen, invoervelden, chips, meldingen): `PAVE/DesignSystem/`, met `Pave` voor de naam (`PaveChip`, `PaveIconButton`).
  - Alleen voor één onderdeel: `PAVE/Features/<Onderdeel>/Components/`.
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
- Een PIN met herhaalde of oplopende cijfers (bijv. `000000`, `123456`) wordt geweigerd.
- Na 5 foute pogingen word je uitgelogd en moet je opnieuw inloggen met wachtwoord en code. Dat geldt ook bij "Pincode vergeten?".
- De PIN hoort bij één account op dit toestel. Uitloggen bewaart hem: log je opnieuw in met hetzelfde account, dan hoef je geen nieuwe PIN te maken. Logt iemand anders in, dan wordt de oude PIN gewist en maakt die een eigen PIN aan. ""Pincode vergeten?" en 5 foute pogingen wissen de PIN wel.
- Face ID/Touch ID zit in `AppState` via `BiometricAuthenticating`. De app opent hem alleen als je dat tijdens het instellen hebt aangezet.
- Het slot komt bij het opstarten van de app. Terug uit de achtergrond vraagt hij nog niet opnieuw om de PIN.

## Ayla

Na het ontgrendelen opent de chat met Ayla (`PAVE/Features/Ayla`). Ayla zelf draait op de server: de Edge Function `ayla` in `shared/supabase/functions/ayla`. De app bevat geen prompt en geen sleutels. Zie `docs/ayla.md`.

- `SupabaseAylaService` (PAVECore) stuurt je vraag met je eigen sessie naar de functie en leest je gesprekken uit `ayla_conversations` en `ayla_messages`.
- Met de demo-inlog (`MockAuthService`) is er geen Ayla: de chat zegt dat je met je eigen account moet inloggen. Er is geen nep-Ayla.
- Het scherm volgt de Figma-ontwerpen: welkom met Kluis/Plan/Profiel, berichten, Ja/Nee-keuzes in plaats van het invoerveld, vacaturekaarten, en de pixelblokjes bij denken (groen) en bij een fout (rood, ze vallen om).
- Meldingen van Ayla hebben (nog) geen webversie; ze staan in `AylaMessages`.
- Smal: één kolom. Breed en staand: de chat in het midden. Duo uitgeklapt en iPad liggend: links je gesprekken, rechts de chat, niets in de vouw.
- Nog niet gebouwd: de plus (bijlage) en de microfoon uit Figma, de kluiskeuze ("2 gegevens geselecteerd") en de skill-gap op basis van je kluis. Daarvoor is eerst de kluis nodig.
