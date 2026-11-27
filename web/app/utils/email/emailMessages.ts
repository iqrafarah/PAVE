import type { EmailErrorCode } from '#shared/types/email';

// E-mail in Meldingen (iOS EmailAccountsScreen, EmailThreadScreen, EmailComposeSheet; docs/ui-teksten.md).

export const EMAIL_KIND_TITLE = 'E-mail';
export const EMAIL_YOU = 'Jij';
export const EMAIL_NO_SUBJECT = 'Geen onderwerp';

// The card in Meldingen, offered once.
export const EMAIL_CARD_TITLE = 'Je e-mail ook hier?';
export const EMAIL_CARD_MESSAGE = 'Koppel iCloud Mail en beantwoord e-mails als een chat.';
export const EMAIL_CARD_CONNECT = 'Koppel';
export const EMAIL_CARD_DISMISS = 'Niet nu';

// The toolbar.
export const EMAIL_NEW_MESSAGE = 'Nieuw bericht';
export const EMAIL_ACCOUNT_BUTTON = 'E-mail';

// Connecting and disconnecting.
export const EMAIL_ACCOUNT_TITLE = 'E-mail';
export const EMAIL_CONNECT_TITLE = 'E-mailaccount koppelen';
export const EMAIL_CONNECT_INTRO = 'Je e-mails verschijnen bij je meldingen. Je kunt ze daar lezen en beantwoorden.';
export const EMAIL_WHICH_TITLE = 'Welke e-mails zie je?';
export const EMAIL_WHICH_MESSAGE =
  'Je ziet alleen gesprekken met mensen die je eerder mailde. Nieuwsbrieven en automatische berichten komen er niet in.';
export const EMAIL_PRIVACY =
  'PAVE haalt je e-mail live op bij iCloud en bewaart je e-mails niet. Je app-specifieke wachtwoord wordt versleuteld opgeslagen, zodat PAVE je e-mail ook in de browser kan ophalen. Als je ontkoppelt, wordt het gewist.';
export const EMAIL_PROVIDER = 'iCloud Mail';
export const EMAIL_PROVIDER_SUBTITLE = 'Je @icloud.com-adres, ook in Mail op je Mac';
export const EMAIL_ADDRESS = 'E-mailadres';
export const EMAIL_PASSWORD = 'App-specifiek wachtwoord';
export const EMAIL_PASSWORD_HELP =
  'Je doet dit maar één keer. Gebruik niet je gewone Apple-wachtwoord. Maak bij account.apple.com › Inloggen en beveiliging › App-specifieke wachtwoorden een nieuw wachtwoord voor PAVE en plak het hier.';
export const EMAIL_APPLE_LINK = 'Ga naar account.apple.com';
export const EMAIL_CONNECT = 'Koppelen';
export const EMAIL_CONNECTING = 'Bezig…';
export const EMAIL_CONNECTED = 'Gekoppeld';
export const EMAIL_THIS_ACCOUNT = 'Dit account';
export const EMAIL_DISCONNECT = 'Ontkoppelen';
export const EMAIL_DISCONNECT_TITLE = 'Ontkoppelen?';
export const EMAIL_DISCONNECT_MESSAGE =
  'PAVE wist je wachtwoord. Je e-mails blijven gewoon in je mailbox. Trek het app-specifieke wachtwoord ook in bij account.apple.com als je het niet meer gebruikt.';
export const EMAIL_NOT_ICLOUD_OUTLOOK =
  'Dit is een Hotmail- of Outlook-adres. PAVE werkt alleen met iCloud Mail: een @icloud.com-, @me.com- of @mac.com-adres.';
export const EMAIL_NOT_ICLOUD = 'PAVE werkt alleen met iCloud Mail: een @icloud.com-, @me.com- of @mac.com-adres.';

// A conversation.
export const EMAIL_LOADING = 'Laden…';
export const EMAIL_MESSAGE_LOADING = 'Bericht wordt geladen';
export const EMAIL_THREAD_NOT_FOUND_TITLE = 'Gesprek niet gevonden';
export const EMAIL_THREAD_NOT_FOUND_MESSAGE = 'Het staat niet meer in je mailbox.';
export const EMAIL_SENT_LABEL = 'Verstuurd';
export const EMAIL_TODAY = (time: string) => `Vandaag ${time}`;
export const EMAIL_YESTERDAY = (time: string) => `Gisteren ${time}`;
export const EMAIL_REPLY_ALL = 'Aan iedereen';
export const EMAIL_REPLY_ONLY = (name: string) => `Alleen aan ${name}`;
export const EMAIL_TO = (names: string) => `Aan: ${names}`;
export const EMAIL_MESSAGE_PLACEHOLDER = 'Bericht';
export const EMAIL_SEND = 'Versturen';
export const EMAIL_SENDING = 'Bezig met versturen';
export const EMAIL_ADD_ATTACHMENT = 'Bijlage toevoegen';
export const EMAIL_REMOVE_ATTACHMENT = (name: string) => `${name} weghalen`;
export const EMAIL_REPLY_FAILED = 'Je antwoord kon niet worden verstuurd. Probeer opnieuw.';
export const EMAIL_DELETE_THREAD = 'Gesprek verwijderen';
export const EMAIL_DELETE_TITLE = 'Dit gesprek verwijderen?';
export const EMAIL_DELETE_MESSAGE = 'Het gaat naar de prullenmand van je iCloud-mailbox. Daar kun je het in Mail nog terugzetten.';
export const EMAIL_DELETE = 'Verwijderen';
export const EMAIL_DELETED = 'Gesprek verwijderd';
export const EMAIL_DELETE_FAILED = 'Het gesprek kon niet worden verwijderd. Probeer het opnieuw.';
export const EMAIL_BACK = 'Terug naar meldingen';
export const EMAIL_ATTACHMENT_OPEN = (name: string) => `${name} openen`;

// A new message.
export const EMAIL_COMPOSE_TITLE = 'Nieuw bericht';
export const EMAIL_COMPOSE_TO = 'Aan';
export const EMAIL_COMPOSE_TO_HINT = 'Meerdere adressen scheid je met een komma.';
export const EMAIL_COMPOSE_SUBJECT = 'Onderwerp';
export const EMAIL_COMPOSE_BODY = 'Je bericht';
export const EMAIL_COMPOSE_FROM = (address: string) => `Je verstuurt vanaf ${address}.`;
export const EMAIL_COMPOSE_SEND = 'Verstuur';
export const EMAIL_COMPOSE_SENDING = 'Bezig…';
export const EMAIL_COMPOSE_FAILED = 'Je bericht kon niet worden verstuurd. Probeer opnieuw.';
export const EMAIL_COMPOSE_MISSING_TO = 'Vul minstens één geldig e-mailadres in.';
export const EMAIL_COMPOSE_MISSING_TEXT = 'Schrijf een bericht of voeg een bijlage toe.';
export const EMAIL_DISCARD_TITLE = 'Bericht weggooien?';
export const EMAIL_DISCARD = 'Weggooien';
export const EMAIL_DISCARD_KEEP = 'Verder met schrijven';
export const EMAIL_TOO_LARGE = 'De bijlagen zijn samen te groot. Je kunt tot 15 MB versturen.';

/** Why it did not work, in words (iOS EmailError). */
export const EMAIL_ERRORS: Record<EmailErrorCode, string> = {
  not_signed_in: 'Log opnieuw in om je e-mail te zien.',
  not_configured: 'E-mail in PAVE is nog niet beschikbaar op deze server.',
  not_connected: 'Er is geen e-mailaccount gekoppeld.',
  not_icloud: EMAIL_NOT_ICLOUD,
  wrong_password: 'Het e-mailadres of het app-specifieke wachtwoord klopt niet.',
  expired: 'Je toegang tot je e-mail is verlopen. Koppel je account opnieuw.',
  network: 'Je e-mail kon niet worden opgehaald. Controleer je internetverbinding en probeer opnieuw.',
  server: 'Er ging iets mis bij je e-mailprovider. Probeer het zo opnieuw.',
  too_large: EMAIL_TOO_LARGE,
  invalid: 'Er klopt iets niet in wat je invulde. Controleer het en probeer opnieuw.',
  not_found: 'Dit staat niet meer in je mailbox.',
};
