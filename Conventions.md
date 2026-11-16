# Conventies

## Inhoud
- [Algemeen](#algemeen)
- [Naamgevingsconventies](#naamgevingsconventies)
- [Mappenstructuur](#mappenstructuur)
- [Git](#git)
- [Definition of Done](#definition-of-done)

## Algemeen
- Code, comments, branches, commits en pull requests schrijven we in het Engels.
- Onnodige comments, zoals AI-comments, verwijderen we.
- We schrijven duidelijke en overzichtelijke code.
- We gebruiken SwiftUI voor iOS en Nuxt (Vue + TypeScript) voor de website.
- De interface van PAVE (web en iOS) is in het Nederlands, in gewone en vriendelijke taal met "je". Teksten en woordkeuze staan in `docs/ui-teksten.md`. Nieuwe teksten voegen we daar toe, zodat web en iOS dezelfde woorden gebruiken.

## Naamgevingsconventies
- Classes, types en componenten gebruiken `PascalCase`, bijvoorbeeld `UserProfile`.
- Variabelen, properties en functies gebruiken `camelCase`, bijvoorbeeld `userName` en `getUserProfile`.
- Bestandsnamen voor Vue-componenten gebruiken `PascalCase`, bijvoorbeeld `ProfileCard.vue`.
- Pagina's gebruiken `kebab-case`, bijvoorbeeld `job-listings.vue`.
- We houden ons zoveel mogelijk aan de standaardconventies van Swift en Nuxt.

## Mappenstructuur
We gebruiken één repository voor het hele project.

- `ios/` — Swift / SwiftUI-app.
- `web/` — Nuxt-website.
- `shared/` — Mockdata en API-definities.
- `docs/` — Projectdocumentatie.
- `README.md` — Uitleg over het project.

Binnen `ios/` en `web/` gebruiken we de standaardmappen van de gebruikte frameworks.

## Git
- We pushen nooit direct naar `main` of `dev`.
- `main` bevat de stabiele versie van PAVE.
- `dev` is de branch waarin we nieuwe functies samenvoegen en testen.
- Nieuwe functies maken we op een aparte branch vanuit `dev`.
- We gebruiken pull requests om code te mergen.
- Een pull request naar `dev` of `main` moet door minimaal **1 ander teamlid** worden goedgekeurd.
- Na goedkeuring mag de pull request worden gemerged.
- We mergen alleen van `dev` naar `main` als de versie stabiel is.

### Branchnamen
- `feat/ios/profile` — Nieuwe functie voor iOS.
- `feat/web/dashboard` — Nieuwe functie voor de website.
- `fix/ios/navigation` — Bugfix voor iOS.
- `fix/web/login` — Bugfix voor de website.
- `docs/update-readme` — Documentatie aanpassen.

## Definition of Done
- De functionaliteit werkt zoals bedoeld.
- De code bevat geen errors.
- De code is getest.
- De code is duidelijk en overzichtelijk.
- De wijzigingen zijn gemaakt op een aparte branch.
- Er is een pull request aangemaakt en goedgekeurd door minimaal 1 ander teamlid.
- Het issue wordt pas gesloten als alles klaar en gemerged is.