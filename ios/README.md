# PAVE iOS

SwiftUI-app voor PAVE. Open `PAVE.xcodeproj` in Xcode 26 of nieuwer. Minimale versie: iOS 26.

## Structuur

```
PAVE/
  App/          PAVEApp, AppState (loading → login → main), RootView
  Features/     Eén map per feature van het takenbord
    Loading/
    Auth/
  Resources/    AppIcon.icon (Icon Composer)
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
