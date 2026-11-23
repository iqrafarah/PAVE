# UI-teksten

## Statussen van bewijs (web en iOS)

Na een testronde (november 2026) vond een docent de statussen onduidelijk: de app gebruikte "bevestigen" en "verifiëren" door elkaar, en nergens stond wat een status betekent of hoe je verder komt. Daarom gebruiken we voor bewijs **overal één werkwoord: verifiëren**. "Bevestigen" blijft alleen voor inloggen en codes ("Code bevestigen").

| Status (database) | Label | Uiterlijk (iOS) | Uitleg |
| --- | --- | --- | --- |
| `toVerify` | Niet geverifieerd | Grijs, leeg keurmerk | Dit heb je zelf toegevoegd. Nog geen school, opleiding of werkgever heeft gecontroleerd dat het klopt. |
| `toVerify` met een lopende aanvraag | Wordt geverifieerd | Oranje, klokje | Je aanvraag ligt bij {organisatie}. Je krijgt een melding zodra je bewijs is beoordeeld. |
| `verified` | Geverifieerd | Groen, vol keurmerk | Een school, opleiding of werkgever heeft gecontroleerd dat dit klopt. Pas je iets aan, dan moet het opnieuw geverifieerd worden. |
| `rejected` | Afgewezen | Rood, uitroepteken | De organisatie kon niet verifiëren dat dit klopt. Kijk of alles klopt, pas het zo nodig aan en vraag het opnieuw aan. |

| Onderdeel | Tekst |
| --- | --- |
| Knop | Laten verifiëren |
| Knop na afwijzing | Opnieuw laten verifiëren |
| Vraag bij aanpassen van geverifieerd bewijs | Opnieuw laten verifiëren? |
| Na toevoegen | Het staat als Niet geverifieerd in je kluis, tot een school of werkgever het verifieert. |

### Uitleg bij het label (iOS: tik op het label in de bewijsbeschrijving)

Naast het label staat een (i). Een tik opent een kleine popup met het label, de uitleg hierboven, de drie stappen (de huidige gemarkeerd) en, als dat de volgende stap is, de knop Laten verifiëren.

| Stap | Titel | Tekst |
| --- | --- | --- |
| 1 | Niet geverifieerd | Je zet het zelf in je kluis. |
| 2 | Wordt geverifieerd | Je vraagt een school, opleiding of werkgever om het te controleren. |
| 3 | Geverifieerd | Zij hebben gecontroleerd dat het klopt. Scholen en werkgevers kunnen erop vertrouwen. |
| 3 (afgewezen) | Afgewezen | Zij konden niet verifiëren dat het klopt. Pas het aan en vraag het opnieuw aan. |

| Onderdeel | Tekst |
| --- | --- |
| Hint voor VoiceOver | Tik voor uitleg |
| Naam van de stappen (VoiceOver) | De stappen van verifiëren |

**Web:** gebruikt nu nog "Niet bevestigd" en "Bevestiging aanvragen"; neem bovenstaande woorden over, zodat web en iOS hetzelfde zeggen.

## Verificatieaanvraag (iOS)

| Onderdeel | Tekst |
| --- | --- |
| Titel | Verificatie aanvraag |
| Intro | Laat je bewijs verifiëren. |
| Organisatiegroep | School of opleiding / Bedrijf |
| Organisatieveld | Naam bedrijf |
| Organisatieplaceholder | Kies een organisatie |
| Vestigingsveld | Locatie van het bedrijf |
| Vestigingsplaceholder | Typ of kies een vestigingsplaats |
| Afdelingsveld | Afdeling of opleiding (bij een bedrijf: Afdeling) |
| Afdelingsplaceholder | Kies een afdeling of opleiding (bij een bedrijf: Kies een afdeling) |
| Ontbrekende afdeling | Kies een afdeling of opleiding. |
| Functiefilter (optioneel) | Functie (optioneel) |
| Functieplaceholder | Alle functies |
| Functie: alles tonen | Alle functies — Laat alle personen zien |
| Functie: aantal | 1 persoon / {n} personen |
| Contactveld | Contactpersoon (bij een school: Docent of contactpersoon) |
| Contactplaceholder | Kies één persoon |
| Gekozen persoon | {naam} · {functie} |
| Zoeken | Zoeken |
| Geen organisatie gevonden | Geen organisaties gevonden. Probeer een andere zoekopdracht. |
| Geen vestigingen | Er zijn nog geen vestigingen voor deze organisatie ingesteld. |
| Geen afdelingen | Er zijn geen afdelingen of opleidingen voor deze vestiging. |
| Geen contacten | Er zijn geen actieve contactpersonen voor deze keuze. |
| Laden organisaties mislukt | De organisaties konden niet worden geladen. Probeer het opnieuw. |
| Laden vestigingen mislukt | De vestigingen konden niet worden geladen. Probeer het opnieuw. |
| Laden afdelingen mislukt | De afdelingen of opleidingen konden niet worden geladen. Probeer het opnieuw. |
| Laden contacten mislukt | De contactpersonen konden niet worden geladen. Probeer het opnieuw. |
| Ontbrekende organisatie | Kies een organisatie. |
| Ontbrekende vestiging | Kies een vestigingsplaats. |
| Ontbrekend contact | Kies de persoon die je bewijs kan verifiëren. |
| Knop | Aanvraag versturen |
| Verzenden | Aanvraag versturen… |
| Routeringsuitleg | Je aanvraag gaat naar de gekozen contactpersoon. |
| Succes | Je aanvraag is doorgestuurd. Je krijgt een melding zodra het bewijs is beoordeeld. |
| Ongeldige keuze | Deze organisatie-, vestigings- of contactkeuze is niet meer geldig. Kies de gegevens opnieuw. |
| Al aangevraagd | Voor dit bewijs staat al een verificatieaanvraag open. |

## Beoordelaar heeft geverifieerd (iOS)

| Onderdeel | Tekst |
| --- | --- |
| In plaats van de knoppen, en voorgelezen | Geverifieerd |

## Bewijs uit je wallet (iOS, demo)

Een eigen route binnen Bewijs toevoegen, met de stappen Kiezen, Controleren en Toestemming.

| Onderdeel | Tekst |
| --- | --- |
| Keuze bij Bewijs toevoegen | Haal bewijs uit je wallet |
| Uitleg bij die keuze | Diploma's, certificaten en badges die je school of werkgever al ondertekende. Ze komen geverifieerd in je kluis. |
| Titel, met label | Uit je wallet · Demo |
| Stappen | Kiezen / Controleren / Toestemming |
| Kiezen, bovenaan | Kies wat je in je kluis zet. Het komt erin als Geverifieerd, omdat je school of werkgever het al ondertekende. |
| Kiezen, onderaan | Dit is een demo: de wallet en de controle zijn nagemaakt, met verzonnen bewijs. Er gaat niets naar of uit een echte wallet. |
| Laden (voorgelezen) | Je wallet openen… |
| Alles al in de kluis | Alles uit je wallet staat al in je kluis. |
| Knop zonder keuze | Kies eerst iets |
| Knop | Voeg {n} toe |
| Controleren, bovenaan | PAVE kijkt bij elk bewijsstuk of het echt is: wie het ondertekende, of die uitgever bekend is en of het nog geldt. |
| Label op de kaart tijdens de controle | Controleren (wordt Geverifieerd) |
| Regel op de kaart | Handtekening controleren… / Uitgever opzoeken… / Kijken of het nog geldt… |
| Knop tijdens de controle | Controleren… |
| Toestemming, titel | In je kluis |
| Toestemming, onder de titel | 1 bewijsstuk staat geverifieerd in je kluis. / {n} bewijsstukken staan geverifieerd in je kluis. |
| Toestemming, kaart | Ayla mag dit bewijs bekijken en gebruiken / Ayla mag deze bewijsstukken bekijken en gebruiken |
| Knop | Klaar |
| Bron bij het bewijs | Uit je wallet (demo) |
| Wallet laadt niet | Je wallet kon niet geopend worden. Probeer het zo nog eens. |
| Functie staat nog niet aan | De demowallet staat nog niet aan. Vraag het team om de functie vault-wallet te zetten. |
| Toevoegen mislukt | Het lukte niet om dit in je kluis te zetten. Probeer het zo nog eens. |
| Knop na een fout | Opnieuw proberen |

## Status van een aanvraag in de kluis (iOS)

| Onderdeel | Tekst |
| --- | --- |
| Label terwijl een aanvraag loopt | Wordt geverifieerd |
| Uitleg terwijl een aanvraag loopt | Je aanvraag ligt bij {organisatie}. Je krijgt een melding zodra je bewijs is beoordeeld. |
| Uitleg zonder organisatie | Je aanvraag is verstuurd. Je krijgt een melding zodra je bewijs is beoordeeld. |
| Kop boven de reden | Reden van {organisatie} (zonder organisatie: Reden van afwijzing) |
| Knop na afwijzing | Opnieuw laten verifiëren |

## Aanvraag afwijzen (iOS, beoordelaar)

| Onderdeel | Tekst |
| --- | --- |
| Titel | Aanvraag afwijzen |
| Vraag | Waarom wijs je {bewijs} af? |
| Placeholder | Bijvoorbeeld: De datum op het certificaat klopt niet met je stageperiode. |
| Uitleg | De lerende ziet deze reden bij het bewijs in de kluis en kan daarna opnieuw een aanvraag doen. |
| Knoppen | Annuleren / Afwijzen / Bezig… |
| Reden ontbreekt | Schrijf waarom je de aanvraag afwijst. |
| Al beoordeeld | Deze aanvraag is al beoordeeld of niet meer beschikbaar. Vernieuw je meldingen. |
| Detail laden mislukt | Opnieuw proberen |

## Meldingen verwijderen (iOS)

| Onderdeel | Tekst |
| --- | --- |
| Veegactie en menu | Verwijderen |
| Menu bij een ongelezen melding | Markeer als gelezen |
| Balk na verwijderen | Melding verwijderd · Ongedaan maken |
| Link onderaan de lijst | Recent verwijderd {aantal} |
| Hint bij beslissingen | Bekijk bewijs |
| Titel prullenbak | Recent verwijderd |
| Uitleg prullenbak | Verwijderde meldingen blijven 7 dagen staan. Daarna zijn ze definitief weg. |
| Per melding | Nog 1 dag / Nog {n} dagen |
| Terugzetten (tik, veeg, menu) | Terugzetten |
| Prullenbak leeg | Niets verwijderd — Meldingen die je verwijdert, staan hier nog een week. |
| Verwijderen mislukt | De melding kon niet worden verwijderd. Probeer het opnieuw. |
| Terugzetten mislukt | De melding kon niet worden teruggezet. Probeer het opnieuw. |

## Animaties uitzetten (web en iOS, Instellingen › Weergave)

| Onderdeel | Tekst |
| --- | --- |
| Schakelaar | Animaties uitzetten |
| Uitleg (web) | Alles in PAVE blijft stil staan: geen bewegende overgangen, laders of golven. Geldt alleen voor deze browser. |
| Uitleg (iOS) | Alles in PAVE blijft stil staan: geen bewegende overgangen, laders of golven. Geldt alleen op dit apparaat. |
