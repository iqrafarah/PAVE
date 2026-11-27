# Voorstel: `account_state` (voor Yassine en Iqra)

**Status:** voorstel, nog niet uitgevoerd. De migratie staat klaar in `shared/supabase/migrations/20261127120000_account_state.sql`. We voeren hem pas uit als jullie akkoord zijn.

## Waarom

Wie op een ander apparaat inlogt, moet daar verder kunnen waar hij was, zoals bij ChatGPT en Claude. Kluis, plannen, chats, profiel en sollicitaties staan al in Supabase. Een paar dingen stonden alleen op de iPhone:

- Mijn beursdag (welke stands je scande en waar je je kaart achterliet)
- wat je al zag in Meldingen en bij "Wie keek er"
- je keuzes bij de planvoorstellen van Ayla
- de volgorde, kleur en het icoon van mappen in de kluis
- vastgezette, gedempte en vergrendelde mailgesprekken
- je laatste keuzes bij snel delen en bij je beschikbaarheid op de beurs

Op 27 november bleek ook dat die gegevens op de iPhone niet per account gescheiden waren. Wie op dezelfde telefoon met een ander account inlogde, zag de sollicitaties van het vorige account. Dat is in de app opgelost: alles op het toestel staat nu per account. Deze tabel zorgt ervoor dat het ook meegaat naar de laptop.

## De tabel

Eén tabel, één rij per ding: `scope` (wat voor soort ding), `key` (welke) en `value` (JSON, zoals de app het schrijft). De server leest nooit in `value`.

| Kolom | Type | |
|---|---|---|
| `user_id` | uuid | standaard `auth.uid()` |
| `scope` | text | bijv. `seen`, `mail` |
| `key` | text | bijv. `fairInvitations`, `pinned` |
| `value` | jsonb | maximaal 64 kB |
| `updated_at` | timestamptz | wie het laatst schreef, wint (behalve bij lijsten van "gezien": die worden samengevoegd) |

Beveiliging (RLS), net als bij `application_drafts`:

- alleen met tweestapsverificatie (`is_mfa_verified()`);
- iedereen ziet en schrijft alleen zijn eigen rijen.

## Wat de iPhone schrijft

| scope/key | value |
|---|---|
| `fairDay/entries` | lijst van `{date, event}` |
| `seen/fairInvitations` | lijst met ids |
| `seen/shareLooksUntil` | moment als ISO-tekst |
| `planEdit/decisions` | `{"<id>": "applied" \| "declined"}` |
| `vault/folderStyles` | `{"<map-id>": "kleur\|icoon"}` |
| `vault/folderOrder`, `vault/itemOrder` | lijst met ids |
| `vault/exampleFoldersMade` | `true` |
| `mail/pinned`, `mail/muted`, `mail/locked` | lijst met ids |
| `choices/quickShareProfile`, `choices/fairAvailability` | tekst |

De website kan dezelfde rijen lezen en schrijven. Gebruik dezelfde `scope` en `key`, dan zien beide apps hetzelfde.

## Zolang de tabel er niet is

De app merkt dat de tabel ontbreekt en houdt alles dan op het toestel, per account. Er gaat niets mis, het gaat alleen nog niet mee naar andere apparaten.

## Wat er al wél meegaat

- Sollicitaties (`application_drafts`): de app stuurt een wijziging nu binnen enkele seconden door, niet pas bij de volgende ronde.
- Thema, tekstgrootte, kluisweergave en licht/donker: staan al in `profiles`.

## Bewust alleen op het toestel

- Pincode en Face ID
- Een half getypt bericht aan Ayla
- Het plan op het toegangsscherm en de koppeling met de Watch
- Animaties aan of uit
