import type { NotificationAudience, NotificationKind } from '~/types/notifications';

// The inbox (iOS NotificationsScreen, NotificationTrashScreen and NotificationRejectSheet; docs/ui-teksten.md).

export const NOTIFICATIONS_TITLE = 'Meldingen';
export const NOTIFICATIONS_TAB_ALL = 'Alle meldingen';
export const NOTIFICATIONS_SEARCH = 'Zoek in meldingen';
export const NOTIFICATIONS_LOADING = 'Meldingen laden…';
export const NOTIFICATIONS_RETRY = 'Opnieuw proberen';
export const NOTIFICATIONS_EMPTY_TITLE = 'Je bent helemaal bij';
export const NOTIFICATIONS_EMPTY_MESSAGE: Record<NotificationAudience, string> = {
  learner: 'Zodra een organisatie je bewijs beoordeelt, zie je dat hier.',
  administrator: 'Nieuwe verificatieaanvragen en beslissingen verschijnen hier.',
};
export const NOTIFICATIONS_NONE_FOUND_TITLE = 'Niets gevonden';
export const NOTIFICATIONS_NONE_FOUND_MESSAGE = 'Pas je zoekopdracht of filters aan.';
export const NOTIFICATIONS_ACTION_NEEDED = 'Actie nodig';
export const NOTIFICATIONS_TODAY = 'Vandaag';
export const NOTIFICATIONS_THIS_WEEK = 'Deze week';
export const NOTIFICATIONS_EARLIER = 'Eerder';
export const NOTIFICATIONS_MESSAGES = (count: number) => (count === 1 ? '1 bericht' : `${count} berichten`);
export const NOTIFICATIONS_UNREAD_COUNT = (count: number) => `${count} ongelezen`;
export const NOTIFICATIONS_UNREAD = 'Ongelezen';
export const NOTIFICATIONS_MARK_READ = 'Markeer als gelezen';
export const NOTIFICATIONS_NEW = 'Nieuwe melding';
export const NOTIFICATIONS_NEW_LABEL = (title: string) => `Nieuwe melding: ${title}`;
export const NOTIFICATIONS_CLOSE = 'Sluiten';

// After judging a verification request (iOS NotificationResolvedBar).
export const NOTIFICATIONS_RESOLVED_VERIFIED = 'Je hebt het bewijs geverifieerd.';
export const NOTIFICATIONS_RESOLVED_REJECTED = 'Je hebt de aanvraag afgewezen.';

// A small signal outside the page (iOS NotificationAlerts and Instellingen › Meldingen). On web: a browser notification
// while PAVE is open in another tab or window.
export const ALERTS_SETTINGS_TITLE = 'Meldingen';
export const ALERTS_SWITCH = 'Seintje bij nieuwe meldingen';
export const ALERTS_SWITCH_EXPLANATION =
  'Een melding van je browser als je bewijs is beoordeeld of er een verificatieaanvraag binnenkomt, ook als PAVE in een ander tabblad staat. Er staat alleen een titel in, nooit je bewijs of je gesprekken.';
export const ALERTS_BROWSER_NOTE = 'Dit werkt zolang PAVE ergens in je browser open staat. Het geldt alleen voor deze browser.';
export const ALERTS_BLOCKED_NOTE = 'Je browser blokkeert meldingen van PAVE. Sta ze toe in de instellingen van je browser (het slotje naast het adres).';
export const ALERTS_UNSUPPORTED_NOTE = 'Deze browser kan geen meldingen tonen.';
export const ALERTS_CARD_TITLE = 'Een seintje bij nieuwe meldingen?';
export const ALERTS_CARD_MESSAGE = 'Je ziet het ook als PAVE in een ander tabblad staat. Alleen de titel, nooit je bewijs.';
export const ALERTS_CARD_BLOCKED_TITLE = 'Meldingen staan uit in je browser';
export const ALERTS_CARD_BLOCKED_MESSAGE = 'Zet ze aan in de instellingen van je browser.';
export const ALERTS_CARD_TURN_ON = 'Zet aan';
export const ALERTS_CARD_DISMISS = 'Niet nu';
export const NOTIFICATIONS_DELETE = 'Verwijderen';
export const NOTIFICATIONS_DELETED = 'Melding verwijderd';
export const NOTIFICATIONS_DELETE_FAILED = 'De melding kon niet worden verwijderd. Probeer het opnieuw.';
export const NOTIFICATIONS_RESTORE_FAILED = 'De melding kon niet worden teruggezet. Probeer het opnieuw.';
export const NOTIFICATIONS_EVIDENCE_GONE = 'Dit bewijs staat niet meer in je kluis.';

export const NOTIFICATIONS_TRASH = 'Recent verwijderd';
export const NOTIFICATIONS_TRASH_INTRO = 'Verwijderde meldingen blijven 7 dagen staan. Daarna zijn ze definitief weg.';
export const NOTIFICATIONS_TRASH_EMPTY_TITLE = 'Niets verwijderd';
export const NOTIFICATIONS_TRASH_EMPTY_MESSAGE = 'Meldingen die je verwijdert, staan hier nog een week.';
export const NOTIFICATIONS_RESTORE = 'Terugzetten';
export const NOTIFICATIONS_DAYS_LEFT = (days: number) => (days === 1 ? 'Nog 1 dag' : `Nog ${days} dagen`);

export const NOTIFICATION_KIND_TITLES: Record<NotificationKind, string> = {
  conversation: 'Gesprek',
  evidence_verified: 'Verificatie',
  evidence_rejected: 'Afgewezen bewijs',
  verification_request: 'Verificatie aanvraag',
  email: 'E-mail',
};

// Reviewing a request (iOS VerificationRequestNotificationDetail).
export const REVIEW_MESSAGE = 'Bericht';
export const REVIEW_DOCUMENT = 'Document';
export const REVIEW_NO_DOCUMENT = 'Er is geen document toegevoegd.';
export const REVIEW_DESCRIPTION = 'Omschrijving';
export const REVIEW_SKILLS = 'Vaardigheden';
export const REVIEW_CHECK_FIRST = 'Controleer het document voordat je het verifieert.';
export const REVIEW_VERIFY = 'Verifieer document';
export const REVIEW_REJECT = 'Aanvraag afwijzen';
export const REVIEW_WORKING = 'Bezig…';
export const REVIEW_LOAD_FAILED = 'De verificatieaanvraag kon niet worden geladen. Probeer opnieuw.';
export const REVIEW_DECISION_FAILED = 'De beslissing kon niet worden opgeslagen. Vernieuw de meldingen en probeer opnieuw.';
export const REVIEW_DEFAULT_TYPE = 'Bewijs';

export const REJECT_TITLE = 'Aanvraag afwijzen';
export const REJECT_QUESTION = (documentName: string) => `Waarom wijs je ${documentName} af?`;
export const REJECT_PLACEHOLDER = 'Bijvoorbeeld: De datum op het certificaat klopt niet met je stageperiode.';
export const REJECT_EXPLANATION = 'De lerende ziet deze reden bij het bewijs in de kluis en kan daarna opnieuw een aanvraag doen.';
export const REJECT_CONFIRM = 'Afwijzen';
export const REJECT_FALLBACK_NAME = 'dit bewijs';

// Answers of vault-review (iOS NotificationsServiceError and VaultMessages).
const FUNCTION_ERROR_MESSAGES: Record<string, string> = {
  not_signed_in: 'Je sessie is verlopen. Log opnieuw in om je meldingen te bekijken.',
  insufficient_aal: 'Bevestig eerst je identiteit met tweestapsverificatie en probeer opnieuw.',
  not_found: 'Deze aanvraag is niet meer beschikbaar of je account is niet als beoordelaar toegewezen.',
  decision_failed: 'Deze aanvraag is al beoordeeld of niet meer beschikbaar. Vernieuw je meldingen.',
  response_required: 'Schrijf waarom je de aanvraag afwijst.',
  response_too_long: 'De reden is te lang. Houd het korter dan 2000 tekens.',
  no_reviewers: 'Er is nog geen beoordelaar ingesteld voor deze organisatie. Neem contact op met je organisatie.',
  already_pending: 'Voor dit bewijs staat al een verificatieaanvraag open.',
  organization_not_found: 'Deze organisatie is niet bekend bij PAVE. Controleer de naam of neem contact op met je organisatie.',
  item_not_awaiting_verification: 'Dit bewijs kan niet meer worden aangevraagd. Vernieuw de kluis en probeer opnieuw.',
  invalid_choice: 'Deze organisatie-, vestigings- of contactkeuze is niet meer geldig. Kies de gegevens opnieuw.',
  not_authorized: 'Deze persoon mag dit soort bewijs niet bevestigen. Kies iemand anders.',
  message_too_long: 'Je bericht is te lang. Houd het korter dan 2000 tekens.',
  offline: 'Meldingen zijn niet bereikbaar. Controleer je internetverbinding en probeer het opnieuw.',
};

export const NOTIFICATIONS_LOAD_FAILED = 'Meldingen konden niet worden geladen. Probeer opnieuw.';

/** A friendly message for an error code of vault-review, or the fallback for anything else. */
export function functionErrorMessage(code: string | null, fallback: string) {
  return (code && FUNCTION_ERROR_MESSAGES[code]) || fallback;
}

// Web: the inbox as a list beside the opened notification.
export const NOTIFICATIONS_FILTER_TYPE = 'Soort';
export const NOTIFICATIONS_FILTER_ALL_KINDS = 'Alle soorten';
export const NOTIFICATIONS_MARK_ALL_READ = 'Alles gelezen';
export const NOTIFICATIONS_MARK_ALL_READ_LABEL = 'Markeer alle meldingen als gelezen';
export const NOTIFICATIONS_LIST = 'Lijst met meldingen';
export const NOTIFICATIONS_BACK = 'Terug naar meldingen';
export const NOTIFICATIONS_PICK_TITLE = 'Kies een melding';
export const NOTIFICATIONS_PICK_MESSAGE = 'Kies links een melding om hem hier te bekijken.';
export const NOTIFICATIONS_FROM = 'Van';
export const NOTIFICATIONS_RECEIVED = (date: string) => `Ontvangen ${date}`;
export const NOTIFICATION_CONVERSATION_MESSAGE = 'Ayla heeft gereageerd in dit gesprek.';
export const NOTIFICATION_OPEN_CONVERSATION = 'Open gesprek';
export const NOTIFICATION_OPEN_IN_VAULT = 'Bekijk in je kluis';
export const NOTIFICATION_VERIFIED_MESSAGE = (organisation: string) =>
  `${organisation} heeft je bewijs bevestigd. Het staat nu als Geverifieerd in je kluis.`;
export const NOTIFICATION_REJECTED_MESSAGE = (organisation: string) =>
  `${organisation} kon je bewijs niet bevestigen. Lees de reden, pas het zo nodig aan en vraag opnieuw bevestiging aan.`;
