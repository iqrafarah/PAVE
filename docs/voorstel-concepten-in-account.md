# Voorstel: cv-concepten in het account bewaren

Voor het web-team (Yassine, Iqra), van het iOS-team. Nog niets gebouwd of aangemaakt in Supabase; dit is een voorstel om samen over te beslissen.

## Probleem
De cv's en brieven die je op iOS maakt, staan alleen op dat ene toestel (`Application Support/Applications/{vacature}.json`, versleuteld zolang de telefoon op slot zit). Nieuwe telefoon of app verwijderd: weg. Web kan ze niet zien.

## Wat er in een concept zit
Eén concept per vacature, als JSON:
- de vacature (id, titel, bedrijf), ontwerp, kleurenpalet, foto aan of uit;
- het cv (naam, regel onder de naam, contact, profiel, onderdelen met regels, vaardigheden). Elke regel verwijst met `sourceItemID` naar een bewijsstuk in de kluis; de tekst op het cv staat er los van;
- de brief (aanhef, alinea's met `sourceItemIDs`, afsluiting, ondertekening);
- wat de gebruiker wil benadrukken, en status (met de geschiedenis van wijzigingen), deadline, notitie en of er herinneringen aan staan (door de gebruiker bijgehouden; PAVE stuurt niets naar het bedrijf). De herinneringen zelf zijn lokale meldingen en blijven op het toestel.

De profielfoto staat er niet in: die komt uit het profiel. Of een regel geverifieerd is, wordt elke keer uit de kluis berekend en niet opgeslagen.

## Voorstel
Een tabel `application_drafts`: `user_id` (verwijst naar het account), `vacancy_id` (tekst), `draft` (jsonb), `updated_at`; uniek op (`user_id`, `vacancy_id`). RLS: alleen de eigenaar leest en schrijft. Bij een botsing wint de nieuwste `updated_at`. iOS blijft lokaal werken en synchroniseert op de achtergrond.

## Vragen aan het web-team
1. Past dit bij de database en RLS-afspraken? Dit is gedeeld, dus niets aanmaken zonder jullie akkoord.
2. Wil web de cv-maker ook bouwen? Dan moet het ontwerp en de paginering op web nagebouwd worden. Zo niet, dan kan web alleen een lijst met concepten tonen.
3. Is het goed dat de volledige tekst van het cv in de database staat, gezien privacy en de eis dat de gebruiker de regie houdt? Een "verwijder alles"-knop zou erbij horen.
