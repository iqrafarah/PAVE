# Voorstel: een cv delen met een werkgever, ook met een QR-code

Voor de product owner, van het iOS-team. Staat niet op het takenbord; dit is een voorstel, niet gebouwd. Daaf's idee: een QR-code, eventueel op de Apple Watch, die een werkgever snel kan scannen.

## Wat PAVE al vastlegt
Delen moet laten zien **wat**, **met wie**, **waarvoor** en **hoe lang**, kan worden ingetrokken, en vraagt expliciete bevestiging. Het cv heeft nu al een vinkje bij bewijs dat geverifieerd is. Een werkgever kan dat vinkje alleen controleren als er een plek is waar het te zien is.

## Opties
1. **Alleen pdf delen (bestaat al).** Geen controle, geen intrekken.
2. **Link met een einddatum.** De gebruiker kiest wat er in zit (cv, brief, welk bewijs) en hoe lang. Een QR-code is dezelfde link. De ontvanger ziet een alleen-lezen pagina met de geverifieerde regels. Dit vraagt een backend: een tabel met gedeelde selecties en een openbare pagina of functie. Dat raakt Supabase en web.
3. **QR in de Wallet.** Staat niet op het takenbord; niet bouwen zonder besluit.

Mijn voorstel: optie 2, eerst op de iPhone, met een QR-scherm dat de link toont.

## De Apple Watch
Het idee is goed voor een snelle scan, maar de afspraak is nu dat de Watch geen vault-, plan- of vacatureschermen heeft en niets laat zien dat de iPhone niet toestaat. Een QR-scherm zou een uitzondering zijn. Het toont geen gegevens zelf, alleen een verwijzing, maar het blijft een besluit voor het team. Voorwaarde: de gebruiker bevestigt op de iPhone wat er gedeeld wordt; de Watch toont alleen dezelfde QR.

## Vragen
1. Mag het cv met geverifieerde regels via een link gedeeld worden, met einddatum en intrekken?
2. Hoe zichtbaar mag de werkgever zijn vorm krijgen in de demo: echt of gesimuleerd? Het prototype mag niet doen alsof er iets is verzonden dat niet is verzonden.
3. Mag de Watch een QR-code tonen, als uitzondering op "geen volledige interface"?
4. Wie bouwt de openbare pagina: web-team of iOS?
