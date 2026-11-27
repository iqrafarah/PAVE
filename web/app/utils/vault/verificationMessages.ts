// Asking an organisation to confirm evidence (iOS VaultRequestConfirmationSheet, VaultOrganizationSearchSheet and
// VaultMessages; docs/ui-teksten.md).

export const REQUEST_TITLE = 'Bevestiging aanvragen';
export const REQUEST_KIND_TITLES = {
  school: 'Onderwijs',
  company: 'Bedrijf',
  government: 'Overheid',
  other: 'Overig',
} as const;
// The filter of the organisation search: Alles, then the kinds ("Bedrijven" in the plural there).
export const REQUEST_KIND_ALL = 'Alles';
export const REQUEST_KIND_FILTERS = {
  school: 'Onderwijs',
  company: 'Bedrijven',
  government: 'Overheid',
  other: 'Overig',
} as const;

export const REQUEST_ORGANISATION = 'Organisatie';
export const REQUEST_ORGANISATION_SEARCH = 'Zoek een organisatie of plaats';
export const REQUEST_ORGANISATION_SEARCH_PLACE = (name: string) => `Kies een vestiging van ${name}`;
export const REQUEST_ORGANISATION_SEARCH_OTHER = 'Andere zoeken';
export const REQUEST_ORGANISATION_CHANGE = 'Wijzig';
export const REQUEST_ORGANISATION_CHANGE_LABEL = 'Andere organisatie of vestiging kiezen';
export const REQUEST_SUGGESTION = (name: string) => `Bedoel je ${name}?`;
export const REQUEST_SUGGESTION_CHOOSE = 'Kiezen';
export const REQUEST_SUGGESTION_CHOOSE_LABEL = (name: string) => `${name} kiezen`;
export const REQUEST_ORGANISATION_PICKER = 'Organisatie kiezen';
export const REQUEST_ORGANISATION_PROMPT = 'Organisatie, plaats of adres';
export const REQUEST_ORGANISATION_DONE = 'Gereed';
export const REQUEST_ORGANISATION_NONE_TITLE = 'Geen organisatie gevonden';
export const REQUEST_ORGANISATION_NONE_MESSAGE = 'Probeer een andere naam, plaats of categorie.';
export const REQUEST_ORGANISATION_FAILED_TITLE = 'Laden lukte niet';
export const REQUEST_ORGANISATION_FAILED_MESSAGE = 'Probeer het opnieuw.';

export const REQUEST_CONTACT = 'Contactpersoon';
export const REQUEST_CONTACT_SEARCH = 'Zoek op naam of functie';
export const REQUEST_PREVIOUS = 'Eerder benaderd';
export const REQUEST_ALL_CONTACTS = 'Alle contactpersonen';
export const REQUEST_FILTER_DEPARTMENT = 'Afdeling';
export const REQUEST_FILTER_DEPARTMENT_ALL = 'Alle afdelingen';
export const REQUEST_FILTER_FUNCTION = 'Functie';
export const REQUEST_FILTER_FUNCTION_ALL = 'Alle functies';
export const REQUEST_FILTERS_CLEAR = 'Filters wissen';
export const REQUEST_OTHER_FUNCTION = 'Overig';
export const REQUEST_NOBODY_CAN_CONFIRM = 'Bij deze vestiging kan niemand dit soort bewijs bevestigen.';
export const REQUEST_NO_CONTACTS = 'Niemand gevonden.';
export const REQUEST_LOADING = 'Laden…';
export const REQUEST_LOAD_MORE = (shown: number, total: number) => `Meer laden (${shown} van ${total})`;

// "Met omschrijving, 2 bestanden en 3 vaardigheden": what comes with the evidence.
export const REQUEST_SHARED_DESCRIPTION = 'omschrijving';
export const REQUEST_SHARED_FILES = (count: number) => (count === 1 ? '1 bestand' : `${count} bestanden`);
export const REQUEST_SHARED_SKILLS = (count: number) => (count === 1 ? '1 vaardigheid' : `${count} vaardigheden`);

export const REQUEST_SEND = 'Aanvraag versturen';
export const REQUEST_SEND_TO = (name: string) => `Versturen naar ${name}`;
export const REQUEST_SENDING = 'Versturen…';
export const REQUEST_ONLY_THEY_SEE = (name: string) => `Alleen ${name} ziet dit bewijs.`;
export const REQUEST_SENT_TITLE = 'Verzoek verstuurd';
export const REQUEST_SENT_MESSAGE = (name: string | null) => `Je krijgt een melding zodra ${name ?? 'de contactpersoon'} het heeft beoordeeld.`;
export const REQUEST_SEE_IN_NOTIFICATIONS = 'Bekijk in meldingen';
export const REQUEST_CLOSE = 'Sluiten';
export const REQUEST_SEND_FAILED = 'Je aanvraag kon niet worden verstuurd. Probeer het zo nog een keer.';

export const REQUEST_DISCARD_TITLE = 'Verzoek weggooien?';
export const REQUEST_DISCARD = 'Weggooien';
export const REQUEST_DISCARD_KEEP = 'Verder met invullen';

export const REQUEST_MISSING = {
  organization: 'Kies een organisatie.',
  contact: 'Kies de persoon die je bewijs kan bevestigen.',
} as const;

export const REQUEST_LOAD_FAILED = {
  organizations: 'De organisaties konden niet worden geladen. Probeer het opnieuw.',
  contacts: 'De contactpersonen konden niet worden geladen. Probeer het opnieuw.',
} as const;

// The status of a request in the vault.
export const REQUEST_AWAITING_TITLE = 'In afwachting';

export function awaitingReviewExplanation(organisation: string | null | undefined) {
  if (organisation) return `Je aanvraag ligt bij ${organisation}. Je krijgt een melding zodra je bewijs is beoordeeld.`;
  return 'Je aanvraag is verstuurd. Je krijgt een melding zodra je bewijs is beoordeeld.';
}

export function rejectionReasonTitle(organisation: string | null | undefined) {
  return organisation ? `Reden van ${organisation}` : 'Reden van afwijzing';
}
