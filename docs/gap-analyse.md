# Gap-analyse: wat Npuls vraagt en wat PAVE heeft

Stand van 25 november 2026. Voor het hele team (iOS, web) en om met de product owner te bespreken.

## Bronnen

- **Kick-off** "Ontwikkelgids", Npuls en SURF, 1 september 2026, 40 slides. Hieronder "kick-off p.".
- **Schetsboek** "Digitaal portfolio v2", sessie van 15 januari 2026, 30 pagina's. Hieronder "schetsboek p.".
- **Rapport** "Concepttest Ontwikkelgids", SURF en Npuls, 15 mei 2026. Tien interviews met 17- tot 26-jarigen; het idee is getest aan de hand van slides, het is geen UX-test. Hieronder "rapport p.".

De bestanden staan niet in de repo, maar lokaal bij Daaf. De functionele beschrijving uit de werkafspraken (kick-off p. 38) is niet gevonden.

## Wat Npuls van ons verwacht (kick-off p. 35–38)

- **Een klikbaar prototype door minstens één scenario.** Diepgang in één scenario is meer waard dan drie halve. Wij doen Ravi + AI.
- **Keuzes zichtbaar maken: "toestemming geven, tijdelijk delen, weer intrekken"** (p. 36). Dit staat bij wat er wél moet, maar staat **niet op ons takenbord**.
- **Testbaar met echte gebruikers, met voorbeelddata.** Een uitgewerkte back-end of koppelingen met bronsystemen hoeven niet.
- **Fase 2:** feedback verwerken, een demo voorbereiden en met gebruikers testen, en afsluiten met een eindpresentatie voor de werkgroep.
- **Ontwerpvraag** (p. 12): "Hoe zou jij 'ik deel dit twee weken met deze werkgever' laten zien in een app?" Toestemming en intrekken moeten begrijpelijk zijn "zonder juridische taal, zonder eindeloze schermen".

## Per bouwsteen

| Bouwsteen | Wat de bronnen vragen | iOS nu | Web nu | Gat |
| --- | --- | --- | --- | --- |
| Kluis | Alles op één plek. Automatisch importeren en zelf toevoegen. Bron en status zichtbaar. Validatie aanvragen (schetsboek p. 2, 4, 5). | Compleet: mappen, bewijs toevoegen met Ayla, vier statuswoorden, echte verificatieaanvragen. Wallet-demo staat op een aparte branch. | Basis aanwezig. Verificatieaanvraag en statuswoorden lopen achter (`web-gelijktrekken.md`). | Web gelijktrekken. Wallet-demo naar `dev`. |
| Plan | Een plan per doel, automatisch gevuld, als tijdlijn. Mensen uitnodigen om mee te kijken. Chat met genodigden (kick-off p. 16–18, schetsboek p. 11–13). | Lege pagina. | Lege pagina. | Een collega werkt hieraan. Uitnodigen en meekijken horen erbij. |
| Profiel en delen | Profielen per ontvanger (onderwijs, gemeente, werkgever). Per onderdeel zichtbaarheid, duur en detail. Delen via tijdelijke links of exports die je kunt **pauzeren en intrekken**. Overzicht van deelrechten. **Log van wie wat wanneer heeft bekeken** (schetsboek p. 4–5, must-have 5 en 6). Bevestigen met Face ID, Ja/Nee (kick-off p. 19). | Lege pagina. | Lege pagina. | **Het grootste gat.** Zie hieronder. |
| AI (Ayla) | Suggesties voor carrièrepaden, functies en vacatures, ook vacatures die deels passen. Matchpercentage en wat je mist. Cv en brief opstellen, de mens controleert. Spraak (kick-off p. 27–31). AI moet een keuze blijven en mag niet te ver gaan bij de brief (rapport p. 9, 19, 22). | Ruim: chat, spraak, toestemming per gegeven, "gebaseerd op", vacatures met match, cv en brief met "Ayla vult het in" of "Zelf invullen", Ayla die doorvraagt. | Chat en kluiskiezer. Vacatures en acties lopen achter. | Web gelijktrekken. Het rapport vraagt AI als keuze; zie "Spanningen". |
| Vacatures en solliciteren | Vacature, match, wat je mist, cv en brief, delen met de werkgever (kick-off p. 22–29). Filter uitzendbureau of directe werkgever, informatie over werkgevers, hulp bij het gesprek, een kalender (rapport p. 9, 23). | Menu Vacatures (Gevonden, Bewaard, Sollicitaties). Tien cv-ontwerpen. Mijn sollicitatie met status, deadline, herinneringen en agenda. | Raster met kaarten. | Delen met de werkgever ontbreekt (zie Profiel en delen). Filter op uitzendbureau ontbreekt. |
| Na solliciteren | Bericht "Uitnodiging kennismaking" met een melding en een postvak-badge. Een afspraak plannen, zelf of door Ayla. Voorbereiding op het gesprek (kick-off p. 25, 30, schetsboek p. 18, 22). Een melding als de ontvanger iets heeft gelezen (rapport p. 9). | Oefengesprek met Ayla. Status zelf bijhouden. Geen bericht van de werkgever. | Niets. | Een gesimuleerd bericht van de werkgever, een afspraak plannen en "bekeken door". |
| Ontwikkel-ID, wallet | Niet in de kick-off of het schetsboek als ID. Alleen "via je wallet", eduwallet en de EU-wallet als links (kick-off p. 19, 24, 39). | Wallet-demo op een branch. | Niets. | Wallet-demo naar `dev`. Een ID-scherm is geen eis. |
| Uitleg en vertrouwen | Uitleggen wat delen betekent: wat de ontvanger mag, hoe lang, of hij mag downloaden, welke wetgeving (AVG) en wie de aanbieder is (rapport p. 9, 21, 23). "Hoe weet ik dat de ontwikkelgids betrouwbaar is?" (kick-off p. 12). | Privacy-pagina in Instellingen, tweestapsverificatie, pincode met Face ID. | Tweestapsverificatie. | Uitleg bij het delen zelf en een pagina "Zo gaan we met je gegevens om". |

## Ravi + AI, stap voor stap (kick-off p. 27–31)

1. **Inspiratie vragen aan Ayla, ook met spraak.** Staat er.
2. **Carrièrepaden en functies.** Gedeeltelijk: Ayla doet het in de chat, maar er is geen kaartweergave met paden zoals in het schetsboek (p. 26).
3. **Passende en deels passende vacatures, met match en wat je mist.** Staat er.
4. **Cv en brief klaarzetten, Ravi controleert.** Staat er.
5. **Ayla deelt cv en brief met Hetzner, met tijdelijke toegang tot de kluis.** **Ontbreekt.**
6. **Uitnodiging de volgende dag, Ayla plant het gesprek in.** **Ontbreekt.** Er is wel het oefengesprek en de agenda voor de deadline.

## Profiel en delen: wat het moet kunnen

Samengevoegd uit de drie bronnen, met wat PAVE al vastlegt in `PAVE_CONTEXT.md` (wat, met wie, waarvoor, hoe lang, intrekbaar, expliciet bevestigen).

- **Wat:**
  - een profiel per soort ontvanger (werkgever, onderwijs, gemeente), samengesteld uit de kluis;
  - cv en brief van een sollicitatie;
  - losse bewijsstukken;
  - een plan (dat laatste hoort bij Plan).
  Per onderdeel aan en uit, met de status zichtbaar. Het rapport waarschuwt: laat zien dat de gebruiker kiest, ook als PAVE het klaarzet (p. 9).
- **Met wie:** naam van de ontvanger en organisatie. In de demo zijn die fictief.
- **Waarvoor:** het doel, bijvoorbeeld "Sollicitatie Junior IT-Consultant". Komt uit de situatie.
- **Hoe lang:** een keuze, bijvoorbeeld 1 dag, 1 week, 2 weken of 1 maand. Het voorbeeld uit de kick-off is "twee weken".
- **Wat de ontvanger mag:** bekijken, en wel of niet downloaden. Testers vroegen hier steeds naar (rapport p. 21, 23).
- **Bevestigen:** een samenvatting in gewone taal, daarna Face ID met Ja en Nee (kick-off p. 19).
- **Hoe:** een link of een QR-code. Het rapport zegt dat de QR-stap voor sommigen "omslachtig" is, dus beide.
- **Overzicht:** actieve deelrechten met de resterende tijd, en pauzeren, verlengen en **intrekken**.
- **Logboek:** wie wat wanneer heeft bekeken, met een melding als iemand iets bekijkt (schetsboek must-have 6, rapport p. 9).
- **Weergave voor de ontvanger:** wat de werkgever ziet, alleen-lezen, met de geverifieerde vinkjes. Het staat in geen enkele bron, maar zonder dit is "tijdelijk" niet te laten zien.
- **Toestemming voor AI en voor delen apart houden.** Dat zeggen de bronnen niet, maar het is PAVE's eigen regel. Ayla mag iets bekijken; dat is iets anders dan delen met een werkgever.

Npuls vraagt geen back-end (kick-off p. 36). Een demo die het delen op het toestel naspeelt is dus genoeg, mits hij eerlijk is: de ontvanger is fictief en er gaat niets het toestel uit. Voor echte links is een Supabase-tabel nodig; zie `voorstel-delen-met-werkgever.md`.

## Spanningen en aandachtspunten

- **AI te ver bij de brief.** Het rapport zegt dat Ayla "regelmatig te ver" gaat met het schrijven van de motivatiebrief (p. 21–22), terwijl de kick-off juist laat zien dat Ayla het klaarzet. PAVE biedt allebei: "Zelf invullen", "Ayla vult het in" en Ayla die doorvraagt. Te bespreken: moet "Zelf invullen" de eerste keuze worden, met Ayla als hulp per blok?
- **Delen staat in de opdracht, niet op het takenbord.** Dit moet op het bord, met de product owner.
- **Werkgevers en scholen doen niet echt mee.** Wat zij zien en doen, kan alleen gesimuleerd worden, en moet dan ook zo gelabeld zijn.
- **Studiekeuze.** Het rapport zegt dat dit het moeilijkste deel is voor wie gaat studeren, en dat de gids daar niet in voorziet (p. 10). Dat is het Maria-scenario; voor ons later.
- **Naam en woorden.** Testers zeggen liever "carrière" dan "loopbaan" (rapport p. 26). PAVE gebruikt nu "Loopbaanoriëntatie" in de context; in de app nauwelijks.
- **Apple Watch.** Geen enkele bron noemt de Watch. QR op de Watch is ons eigen idee.

## Voorgestelde volgorde

1. **Profiel en delen** op de Profiel-tab, als demo op het toestel. Daarmee kan Ayla in stap 5 ook "deel dit met Hetzner" doen, met bevestiging.
2. **Na solliciteren:**
   - een gesimuleerd bericht "Uitnodiging kennismaking" in Meldingen;
   - een afspraak plannen, ook door Ayla, met bevestiging;
   - "bekeken door" vanuit het delen.
3. **Uitleg en vertrouwen:** bij het delen en op één pagina.
4. **Web gelijktrekken** (`web-gelijktrekken.md`) en de wallet-demo naar `dev`.
5. **Demo en gebruikerstest:** een draaiboek voor Ravi + AI van begin tot eind, testvragen (schetsboek p. 16, 23, 30: "Waar word je blij van? Wat roept zorgen of vragen op? Wat mis jij?") en de eindpresentatie.

## Open vragen voor de product owner

1. Mag delen en intrekken op het takenbord, als demo op het toestel?
2. Moet "Zelf invullen" bij de brief de eerste keuze zijn, gezien het rapport?
3. Willen we de functionele beschrijving van Npuls nog krijgen? Die staat in de werkafspraken, maar we hebben hem niet.
