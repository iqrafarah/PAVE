# PAVE iOS

SwiftUI-app voor PAVE. Open `PAVE.xcodeproj` in Xcode 26 of nieuwer. Minimale versie: iOS 26.

## Structuur

```
PAVE/
  App/          PAVEApp, AppState (loading → login → main), RootView
  DesignSystem/ Herbruikbare UI: tekststijlen, knop, tekstveld, melding
  Features/     Eén map per feature van het takenbord
    Loading/
    Auth/       AuthFlow (navigatie + logica), Screens/, Components/
  Resources/    AppIcon.icon, Assets.xcassets (iconen), Fonts/ (Inter)
PAVEWatch/      Apple Watch-app (spraakbot, geen volledige interface)
Shared/         UI en assets voor iPhone en Watch (kleuren, logo-letters, laadscherm)
PAVETests/      Swift Testing
PAVECore/       Gedeelde logica voor iPhone en Watch (zonder UI)
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

## Afspraken

- De mappen `PAVE/`, `PAVEWatch/` en `PAVETests/` zijn gesynchroniseerd met Xcode: een bestand dat je in Finder of Xcode toevoegt, hoort automatisch bij het project.
- Werk zoveel mogelijk in je eigen feature-map om merge-conflicten te voorkomen.
- Mockdata die het web-team ook gebruikt, komt in `../shared/`.
- Zie `../Conventions.md` voor naamgeving en Git-afspraken.

## Draaien op je eigen iPhone

1. Kopieer `Config/Local.xcconfig.example` naar `Config/Local.xcconfig` (dit bestand staat in `.gitignore`).
2. Vul je eigen `DEVELOPMENT_TEAM` in. Je vindt het ID in Xcode onder Settings, Accounts, of in Signing & Capabilities.
3. Is `nl.fontys.pave` al in gebruik bij een ander Apple-account? Zet dan ook een eigen `APP_BUNDLE_IDENTIFIER` in `Local.xcconfig`.
4. Zet op de iPhone de Ontwikkelaarsmodus aan (Instellingen, Privacy en beveiliging).

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

- Authentication, Sign In / Providers: "Allow new users to sign up" staat uit.
- Authentication, URL Configuration: `pave://reset-password` staat bij de redirect-URL's.
- Authentication, Multi-Factor: TOTP staat aan.
- Testaccounts maak je in Authentication, Users met "Auto Confirm User".

### Demo-accounts (mock)

| Account | Wachtwoord | Wat gebeurt er |
| --- | --- | --- |
| `ravi@student.example.edu` | `PaveDemo!2026` | Vraagt de verificatiecode |
| `new@student.example.edu` | `PaveDemo!2026` | Start de eerste instelling van tweestapsverificatie |

De verificatiecode is altijd `123456`. Een resetlink test je in de simulator met `xcrun simctl openurl booted pave://reset-password`.

## PIN en Face ID

Na het inloggen maak je een PIN van 6 cijfers aan. Start je de app later opnieuw terwijl je nog bent ingelogd, dan vraagt PAVE eerst om die PIN. Je kunt ook Face ID of Touch ID aanzetten om sneller te ontgrendelen.

- De logica staat in `PAVECore/Sources/PAVECore/Lock/` (`PinVault`, `PinPolicy`). De PIN wordt nooit zelf bewaard: alleen een hash met een willekeurige salt (PBKDF2), in de Keychain van deze iPhone (`WhenUnlockedThisDeviceOnly`).
- Een PIN met herhaalde of oplopende cijfers (bijv. `000000`, `123456`) wordt geweigerd.
- Na 5 foute pogingen word je uitgelogd en moet je opnieuw inloggen met wachtwoord en code. Dat geldt ook bij "Forgot PIN?".
- De PIN hoort bij één account op dit toestel. Uitloggen bewaart hem: log je opnieuw in met hetzelfde account, dan hoef je geen nieuwe PIN te maken. Logt iemand anders in, dan wordt de oude PIN gewist en maakt die een eigen PIN aan. "Forgot PIN?" en 5 foute pogingen wissen de PIN wel.
- Face ID/Touch ID zit in `AppState` via `BiometricAuthenticating`. De app opent hem alleen als je dat tijdens het instellen hebt aangezet.
- Het slot komt bij het opstarten van de app. Terug uit de achtergrond vraagt hij nog niet opnieuw om de PIN.
