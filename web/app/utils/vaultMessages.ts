import type { VaultItemCategory } from '~/types/vault';

// "Kluis aanvullen" (Figma FEDDIES 1167:12715, 1167:11759, 1167:12237, 1167:11255, 1167:10880). The category names and
// the checks match iOS (VaultCategory.swift, VaultItemDraft.swift and VaultMessages.swift).

export const VAULT_ADD_TITLE = 'Kluis aanvullen';
export const VAULT_ADD_QUESTION = 'Wil je iets toevoegen?';
export const VAULT_ADD_YES = 'Ja';
export const VAULT_ADD_NO = 'Nee';
export const VAULT_ADD_CLOSE = 'Sluiten';
export const VAULT_ADD_NEXT = 'Volgende';
export const VAULT_ADD_BACK = 'Terug';
export const VAULT_ADD_SAVING = 'Bezig met opslaan…';
export const VAULT_ADD_STEPS = ['Basis', 'Documenten', 'Vaardigheden', 'Afronden'] as const;

export const VAULT_DROP_FILE = 'Sleep bestand hierheen of klik om te uploaden';
export const VAULT_OR = 'Of';
export const VAULT_WITHOUT_FILE_TITLE = 'Voeg een ervaring toe zonder bestand';
export const VAULT_WITHOUT_FILE_MESSAGE = 'Geen document, geen probleem. Je kunt ook zelf ervaringen toevoegen.';
export const VAULT_REMOVE_FILE = 'Bestand weghalen';

export const VAULT_FIELD_TITLE = 'Titel';
export const VAULT_FIELD_CATEGORY = 'Soort bewijs';
export const VAULT_FIELD_CATEGORY_PLACEHOLDER = 'Kies een soort';
export const VAULT_FIELD_ORGANISATION = 'Organisatie / school';
export const VAULT_FIELD_PERIOD = 'Periode';
export const VAULT_FIELD_ISSUED = 'Behaald in';
export const VAULT_FIELD_START = 'Van';
export const VAULT_FIELD_END = 'Tot';
export const VAULT_FIELD_END_HINT = 'Leeg als je dit nog doet';
export const VAULT_FIELD_DESCRIPTION = 'Beschrijving';
export const VAULT_REQUIRED = 'verplicht';

export const VAULT_COVER = 'Omslag';
export const VAULT_NO_COVER = 'Geen Omslag';
export const VAULT_LOGO = 'Logo';
export const VAULT_DETAIL_CARD = 'Kaart';
export const VAULT_IMAGE_CHOOSE = 'Kiezen';
export const VAULT_IMAGE_CHANGE = 'Wijzigen';
export const VAULT_LOGO_FROM_ORGANISATION = 'Van de organisatie';
export const VAULT_LOGO_HINT = 'Optioneel. Het logo staat rond op je kaart en de kleur van de kaart past zich erop aan.';

export const VAULT_SKILLS_FROM_VAULT = 'Vaardigheden uit mijn kluis';
export const VAULT_SKILLS_FROM_AYLA = 'Voorstel van';
export const VAULT_SKILLS_ADD_OWN = 'Zelf een vaardigheid toevoegen';
export const VAULT_SKILLS_SEARCH = 'Zoek een vaardigheid of voeg er zelf een toe';
export const VAULT_SKILLS_NONE_IN_VAULT = 'Er staan nog geen vaardigheden in je kluis.';
export const VAULT_SKILLS_NONE_FROM_AYLA = 'Ayla heeft nog geen voorstel voor dit bewijs.';
export const VAULT_SKILLS_SELECTED = 'Gekozen vaardigheden';
export const VAULT_SKILL_ADD = 'Toevoegen';
export const VAULT_SKILL_REMOVE = 'Weghalen';
export const VAULT_SKILL_ADD_TYPED = (name: string) => `“${name}” toevoegen`;

export const VAULT_DONE_TITLE = 'Bewijs toegevoegd';
export const VAULT_DONE_CONSENT = 'Ayla mag dit document bekijken en gebruiken';
export const VAULT_DONE_FINISH = 'Afronden';

export const VAULT_DISCARD_TITLE = 'Stoppen met toevoegen? Wat je hebt ingevuld, wordt niet bewaard.';
export const VAULT_DISCARD_CONFIRM = 'Stoppen';

export const VAULT_PROBLEM_TITLE = 'Geef het bewijs een titel.';
export const VAULT_PROBLEM_TITLE_TOO_LONG = 'De titel mag maximaal 200 tekens zijn.';
export const VAULT_PROBLEM_CATEGORY = 'Kies wat voor bewijs dit is.';
export const VAULT_PROBLEM_ORGANISATION = 'Vul de organisatie of school in.';
export const VAULT_PROBLEM_PERIOD = 'Vul in wanneer dit was.';
export const VAULT_PROBLEM_END_BEFORE_START = 'De einddatum ligt voor de begindatum.';
export const VAULT_PROBLEM_DESCRIPTION = 'Vertel kort wat je hebt gedaan of geleerd.';
export const VAULT_PROBLEM_DESCRIPTION_TOO_LONG = 'De omschrijving is te lang.';
export const VAULT_PROBLEM_FILE = 'Kies een bestand, of voeg een ervaring toe zonder bestand.';
export const VAULT_PROBLEM_COVER = 'Kies een afbeelding voor de omslag, of kies Geen Omslag.';
export const VAULT_FILE_TOO_BIG = 'Dit bestand is groter dan 20 MB. Kies een kleiner bestand.';
export const VAULT_FILE_TYPE = 'Dit soort bestand kan niet in je kluis. Kies een PDF, Word-bestand, foto of tekstbestand.';
export const VAULT_COVER_TYPE = 'Kies een JPG-, PNG- of HEIC-afbeelding.';
export const VAULT_FILE_EMPTY = 'Dit bestand is leeg.';

export const VAULT_SAVE_FAILED = 'Je bewijs kon niet worden opgeslagen. Probeer het zo nog een keer.';
export const VAULT_SAVE_NOT_SIGNED_IN = 'Je sessie is verlopen. Log opnieuw in om je kluis aan te vullen.';
export const VAULT_SAVE_NOT_READY = 'Je kluis is nog niet beschikbaar. Probeer het later nog een keer.';
export const VAULT_CONSENT_FAILED = 'Je toestemming kon niet worden opgeslagen. Probeer het opnieuw.';

export const VAULT_CATEGORY_TITLES: Record<VaultItemCategory, string> = {
  diplomas: 'Diploma',
  certificates: 'Certificaat',
  badges: 'Badge',
  projects: 'Project',
  workExperience: 'Werkervaring',
  internships: 'Stage',
  skills: 'Vaardigheid',
  feedback: 'Feedback',
  reflections: 'Reflectie',
  other: 'Overig',
};

/** Obtained on one day (a date), or done for a while (a start and an end), as on iOS. */
export function hasPeriod(category: VaultItemCategory | '') {
  return !['diplomas', 'certificates', 'badges'].includes(category);
}

/** "PDF - 2,4 MB", as under the file in the design. */
export function describeFile(file: File) {
  const extension = file.name.split('.').pop()?.toUpperCase() ?? '';
  const megabytes = file.size / 1024 / 1024;
  const size = megabytes >= 1
    ? `${megabytes.toLocaleString('nl-NL', { maximumFractionDigits: 1 })} MB`
    : `${Math.max(1, Math.round(file.size / 1024))} KB`;
  return extension ? `${extension} - ${size}` : size;
}

// The vault itself (iOS VaultMessages.swift, VaultScreen.swift and the Figma vault grid 1209:55066 and list 1209:53998).
export const VAULT_TITLE = 'Kluis';
export const VAULT_EMPTY_TITLE = 'Je kluis is nog leeg';
export const VAULT_EMPTY_MESSAGE = "Bewaar hier je diploma's, certificaten, projecten en ervaringen. Dan heb je alles op één plek.";
export const VAULT_NO_RESULTS_TITLE = 'Niets gevonden';
export const VAULT_NO_RESULTS_MESSAGE = 'Probeer een ander woord of zet de filters uit.';
export const VAULT_EMPTY_FOLDER_MESSAGE = 'Open een item en kies Verplaatsen naar map.';
export const VAULT_LOAD_FAILED_TITLE = 'Je kluis kon niet laden';
export const VAULT_LOADING = 'Je kluis wordt geladen';
export const VAULT_RETRY = 'Opnieuw proberen';
export const VAULT_PROBLEM_TITLE_GENERIC = 'Dat lukte niet';
export const VAULT_OK = 'OK';

export const VAULT_FILTER_ALL = 'Alle';
export const VAULT_FILTER_STATUS = 'Status';
export const VAULT_FILTER_SOURCE = 'Bron';
export const VAULT_FILTER_DATE = 'Datum';
export const VAULT_FILTER_CLEAR = 'Filters wissen';
export const VAULT_VIEW = 'Weergave';
export const VAULT_SHOW_GRID = 'Toon als raster';
export const VAULT_SHOW_LIST = 'Toon als lijst';
export const VAULT_SEARCH = 'Zoeken in je kluis';
export const VAULT_SEARCH_CLOSE = 'Zoeken sluiten';
export const VAULT_SEARCH_PLACEHOLDER = 'Zoek op titel, organisatie of vaardigheid';
export const VAULT_ADD_BUTTON = 'Toevoegen';
export const VAULT_ADD_ITEM = 'Item toevoegen';
export const VAULT_SHOW_MORE = 'Meer tonen';
export const VAULT_BACK_TO_VAULT = 'Terug naar je kluis';
export const VAULT_FOLDERS = 'Mappen';

export const VAULT_STATUS_TITLES = { verified: 'Geverifieerd', toVerify: 'Niet bevestigd', rejected: 'Afgewezen' } as const;
export const VAULT_STATUS_EXPLANATIONS = {
  verified: 'Bevestigd door een officiële of vertrouwde bron. Daarom kun je dit item niet meer aanpassen.',
  toVerify: 'Nog niet bevestigd door een school, opleiding of werkgever.',
  rejected: 'De organisatie kon dit niet bevestigen. Kijk of alles klopt en pas het zo nodig aan.',
} as const;
export const VAULT_SOURCE_TITLES = {
  user: 'Zelf toegevoegd',
  organization: 'Van een organisatie',
  ayla: 'Voorgesteld door Ayla',
  import: 'Geïmporteerd',
} as const;
export const VAULT_ORIGIN_TITLES = { own: 'Zelf toegevoegd', organisation: 'Van een organisatie', ayla: 'Via Ayla' } as const;
export const VAULT_ORDER_TITLES = { newest: 'Nieuwste eerst', oldest: 'Oudste eerst' } as const;

export const VAULT_DETAIL_STATUS = 'Status';
export const VAULT_DETAIL_DATA = 'Gegevens';
export const VAULT_DETAIL_DESCRIPTION = 'Omschrijving';
export const VAULT_DETAIL_SKILLS = 'Vaardigheden';
export const VAULT_DETAIL_FILES = 'Bestanden';
export const VAULT_DETAIL_IN_FOLDER = (name: string) => `In de map ${name}`;
export const VAULT_DETAIL_MORE = 'Meer';
export const VAULT_DETAIL_DONE = 'Klaar';
export const VAULT_EDIT = 'Aanpassen';
export const VAULT_EDIT_TITLE = 'Aanpassen';
export const VAULT_SAVE = 'Bewaren';
export const VAULT_SAVING = 'Bewaren…';
export const VAULT_CANCEL = 'Annuleren';
export const VAULT_MOVE_OWN = 'Je mappen';
export const VAULT_FIELD_FOLDER = 'Map';
export const VAULT_FIELD_FOLDER_PLACEHOLDER = 'Kies een map';
export const VAULT_EDIT_LOCKED =
  'Dit item is bevestigd of komt van een organisatie, dus de inhoud blijft zoals hij is. Je kunt wel kiezen in welke van je eigen mappen het staat.';
export const VAULT_MOVE_STANDARD = 'Standaardmappen';
export const VAULT_DELETE = 'Verwijderen';
export const VAULT_DELETE_TITLE = 'Uit je kluis verwijderen?';
export const VAULT_DELETE_MESSAGE =
  'Dit haalt het item en de bestanden erbij voorgoed uit je kluis, ook op je telefoon. Dit kun je niet ongedaan maken.';
export const VAULT_MORE_SKILLS = (count: number) => `en nog ${count}`;

export const VAULT_NEW_FOLDER_TITLE = 'Nieuwe map';
export const VAULT_EDIT_FOLDER_TITLE = 'Map aanpassen';
export const VAULT_FOLDER_CREATE = 'Map aanmaken';
export const VAULT_FOLDER_NAME = 'Naam';
export const VAULT_FOLDER_NAME_PLACEHOLDER = 'Bijvoorbeeld Stage of Bijbaan';
export const VAULT_FOLDER_COLOR = 'Kleur';
export const VAULT_FOLDER_ICON = 'Icoon';
export const VAULT_FOLDER_NAME_MISSING = 'Geef je map een naam.';
export const VAULT_FOLDER_NAME_TAKEN = 'Je hebt al een map met deze naam. Kies een andere naam.';
export const VAULT_FOLDER_EDIT = 'Map aanpassen';
export const VAULT_FOLDER_DELETE = 'Map verwijderen';
export const VAULT_FOLDER_DELETE_TITLE = 'Map verwijderen?';
export const VAULT_FOLDER_DELETE_MESSAGE = 'De items in deze map blijven gewoon in je kluis staan.';
export const VAULT_FOLDER_EMPTY_TITLE = (name: string) => `${name} is nog leeg`;
export const VAULT_FOLDER_ACTIONS = (name: string) => `Opties voor ${name}`;
export const VAULT_ITEM_ACTIONS = (title: string) => `Opties voor ${title}`;
export const VAULT_STANDARD_FOLDER_DELETE_MESSAGE =
  'De map verdwijnt uit het rijtje. De items erin blijven gewoon in je kluis staan, en je kunt de map later terugzetten.';
export const VAULT_RESTORE_FOLDERS = 'Verwijderde standaardmappen terugzetten';
export const VAULT_EMPTY_CATEGORY_TITLE = (plural: string) => `Nog geen ${plural.toLowerCase()}`;
export const VAULT_ADD_CATEGORY = (singular: string) => `${singular} toevoegen`;

export const VAULT_FOLDER_COLOR_TITLES = {
  green: 'Groen',
  blue: 'Blauw',
  purple: 'Paars',
  rust: 'Roest',
  rose: 'Roze',
  slate: 'Grijs',
} as const;
export const VAULT_FOLDER_ICON_TITLES = {
  folder: 'Map',
  briefcase: 'Koffer',
  'academic-cap': 'Afstudeerhoed',
  'check-badge': 'Keurmerk',
  'wrench-screwdriver': 'Gereedschap',
  'chat-bubble-left-ellipsis': 'Tekstballon',
  star: 'Ster',
  heart: 'Hart',
  'code-bracket': 'Code',
  'light-bulb': 'Lampje',
  'rocket-launch': 'Raket',
  'globe-europe-africa': 'Wereldbol',
  'paint-brush': 'Kwast',
  'document-text': 'Document',
  'user-group': 'Groep',
  trophy: 'Beker',
} as const;

export const VAULT_ERROR_NO_CONNECTION = 'Je kluis is niet bereikbaar. Controleer je internetverbinding en probeer het opnieuw.';
export const VAULT_ERROR_NOT_SIGNED_IN = 'Je sessie is verlopen. Log opnieuw in om je kluis te openen.';
export const VAULT_ERROR_NOT_ALLOWED = 'Dit mag niet met je account. Log opnieuw in en probeer het nog een keer.';
export const VAULT_ERROR_GENERIC = 'Er ging iets mis. Probeer het zo nog een keer.';
