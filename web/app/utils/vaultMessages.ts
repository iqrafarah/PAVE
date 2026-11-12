import type { VaultItemCategory } from '~/types/vault';

// "Kluis aanvullen" (Figma FEDDIES 1167:12715, 1167:11759, 1167:12237, 1167:11255, 1167:10880). The category names and
// the checks match iOS (VaultCategory.swift, VaultItemDraft.swift and VaultMessages.swift).

export const VAULT_ADD_TITLE = 'Bewijs toevoegen';
export const VAULT_ADD_QUESTION = 'Wil je iets toevoegen?';
export const VAULT_ADD_YES = 'Ja';
export const VAULT_ADD_NO = 'Nee';
export const VAULT_ADD_CLOSE = 'Sluiten';
export const VAULT_ADD_NEXT = 'Volgende';
export const VAULT_ADD_BACK = 'Terug';
export const VAULT_ADD_SAVING = 'Bezig met opslaan…';
export const VAULT_ADD_STEPS = ['Basis', 'Documenten', 'Vaardigheden', 'Toestemming'] as const;

export const VAULT_DROP_FILE = 'Sleep een bestand hierheen of klik om te uploaden';
export const VAULT_UPLOAD_HINT = 'PDF, Word, tekst of foto, tot 20 MB';
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
export const VAULT_FIELD_PERIOD_KIND = 'Periode of één datum';
export const VAULT_PERIOD_RANGE = 'Van – tot';
export const VAULT_PERIOD_ONE_DATE = 'Eén datum';
export const VAULT_FIELD_START = 'Van';
export const VAULT_FIELD_END = 'Tot';
export const VAULT_FIELD_END_HINT = 'Leeg als je dit nog doet';
export const VAULT_FIELD_DESCRIPTION = 'Beschrijving';
export const VAULT_REQUIRED = 'verplicht';

export const VAULT_COVER = 'Omslag';
export const VAULT_NO_COVER = 'Geen omslag';
export const VAULT_LOGO = 'Logo';
export const VAULT_LOGO_HINT = 'Komt in de cirkel op je kaart, bijvoorbeeld het logo van je school of werkgever.';
export const VAULT_LOGO_CHOOSE = 'Logo kiezen';
export const VAULT_LOGO_REPLACE = 'Ander logo kiezen';
export const VAULT_LOGO_REMOVE = 'Logo weghalen';
export const VAULT_LOGO_FROM_ORGANISATION = 'Het logo van de organisatie staat al op je kaart.';
export const VAULT_COVER_HINT = 'Je eigen foto in de band boven je kaart';
export const VAULT_COVER_CHOOSE = 'Omslag kiezen';
export const VAULT_COVER_REPLACE = 'Andere omslag kiezen';
export const VAULT_COVER_REMOVE = 'Omslag weghalen';
export const VAULT_NO_COVER_WITH_LOGO = 'De band krijgt de sterkste kleur uit je logo.';
export const VAULT_NO_COVER_WITHOUT_LOGO = 'Kies je een logo, dan krijgt de band de sterkste kleur daaruit.';
export const VAULT_LOGO_HINT_CHOSEN = 'Klik op het logo om het te verplaatsen, te vervangen of weg te halen.';
export const VAULT_COVER_CHOSEN = 'Staat in de band boven je kaart';
export const VAULT_COVER_ACTIONS = 'Omslag aanpassen';
export const VAULT_REFRAME = 'Verplaatsen en schalen';
export const VAULT_REFRAME_HINT = 'Sleep om te verplaatsen, schuif om te schalen';
export const VAULT_REFRAME_ZOOM = 'Schaal';
export const VAULT_REFRAME_USE = 'Gebruiken';
export const VAULT_IMAGE_UNREADABLE = 'Deze afbeelding kan niet worden geopend. Kies een JPG of PNG.';
export const VAULT_CARD_PREVIEW = 'Zo ziet je kaart eruit';
export const VAULT_DOCUMENTS = 'Documenten';
export const VAULT_DOCUMENTS_EMPTY = 'Nog geen document. Zonder bestand kan ook: dan staat je ervaring er zelf beschreven in.';
export const VAULT_ADD_DOCUMENT = 'Document toevoegen';
export const VAULT_ADD_ANOTHER_DOCUMENT = 'Nog een document toevoegen';
export const VAULT_DOCUMENTS_FULL = (max: number) => `Je kunt tot ${max} documenten toevoegen.`;
export const VAULT_IMAGES_NOT_YET =
  'Je bewijs staat in je kluis. Het logo en de omslag kunnen nog niet bewaard worden; dat komt binnenkort.';

export const VAULT_SKILLS_FROM_VAULT = 'Vaardigheden uit mijn kluis';
export const VAULT_AYLA_SKILLS_INTRO =
  'Ayla kan vaardigheden voorstellen die bij dit bewijs passen. Ze kijkt naar wat je invulde en naar je bestanden, alleen voor dit voorstel.';
/** Under her proposals: what Ayla looked at, so it is clear where they come from. */
export const VAULT_AYLA_SKILLS_LOOKED_AT = (files: number) =>
  files === 0
    ? 'Ayla keek alleen naar wat je invulde.'
    : files === 1
      ? 'Ayla keek naar wat je invulde en naar 1 bestand, alleen voor dit voorstel.'
      : `Ayla keek naar wat je invulde en naar ${files} bestanden, alleen voor dit voorstel.`;
export const VAULT_AYLA_SKILLS_ASK = 'Vraag Ayla om voorstellen';
export const VAULT_AYLA_SKILLS_AGAIN = 'Opnieuw vragen';
export const VAULT_AYLA_SKILLS_THINKING = 'Ayla bekijkt je bewijs…';
export const VAULT_AYLA_SKILLS_NONE =
  'Ayla vond geen nieuwe vaardigheden in dit bewijs. Vul de omschrijving aan of voeg een bestand toe en vraag het opnieuw.';
export const VAULT_AYLA_SKILLS_FAILED = 'Ayla kon nu geen voorstel doen. Probeer het zo nog een keer.';
export const VAULT_AYLA_SKILLS_NO_CONNECTION = 'Geen verbinding. Probeer het zo nog een keer.';
export const VAULT_AYLA_SKILLS_SIGNED_OUT = 'Je sessie is verlopen. Log opnieuw in en vraag het nog een keer.';
export const VAULT_AYLA_SKILLS_NOT_READY = 'Ayla kan nog geen vaardigheden voorstellen. Dat komt binnenkort.';
export const VAULT_SKILLS_FROM_AYLA = 'Voorstel van';
export const VAULT_SKILLS_ADD_OWN = 'Zelf een vaardigheid toevoegen';
export const VAULT_SKILLS_SEARCH = 'Zoek een vaardigheid of voeg er zelf een toe';
export const VAULT_SKILLS_NONE_IN_VAULT = 'Er staan nog geen vaardigheden in je kluis.';
export const VAULT_SKILLS_SELECTED = 'Gekozen vaardigheden';
export const VAULT_SKILL_ADD = 'Toevoegen';
export const VAULT_SKILL_REMOVE = 'Weghalen';
export const VAULT_SKILL_ADD_TYPED = (name: string) => `“${name}” toevoegen`;

export const VAULT_DONE_TITLE = 'Bewijs toegevoegd';
export const VAULT_DONE_MESSAGE = 'Het staat als Niet bevestigd in je kluis, tot een school of werkgever het bevestigt.';
export const VAULT_CONSENT = (hasFile: boolean) =>
  hasFile ? 'Ayla mag dit document bekijken en gebruiken' : 'Ayla mag dit bewijs bekijken en gebruiken';
export const VAULT_CONSENT_MEANING = 'Dan neemt Ayla dit mee in je vragen en zoekopdrachten. Je kunt het altijd weer uitzetten.';
export const VAULT_DONE_FINISH = 'Afronden';

export const VAULT_DISCARD_TITLE = 'Stoppen met toevoegen?';
export const VAULT_DISCARD_MESSAGE = 'Wat je hebt ingevuld, wordt niet bewaard.';
export const VAULT_DISCARD_KEEP = 'Verder met toevoegen';
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
export const VAULT_PROBLEM_COVER = 'Kies een afbeelding voor de omslag, of kies Geen omslag.';
export const VAULT_FILE_TOO_BIG = 'Dit bestand is groter dan 20 MB. Kies een kleiner bestand.';
export const VAULT_FILE_TYPE = 'Dit soort bestand kan niet in je kluis. Kies een PDF, Word-bestand, foto of tekstbestand.';
export const VAULT_COVER_TYPE = 'Kies een JPG-, PNG- of HEIC-afbeelding.';
export const VAULT_FILE_EMPTY = 'Dit bestand is leeg.';

export const VAULT_SAVE_FAILED = 'Je bewijs kon niet worden opgeslagen. Probeer het zo nog een keer.';
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
export const VAULT_EMPTY_FOLDER_MESSAGE = 'Voeg hier bewijs toe, of kies bij Aanpassen van een item in welke mappen het staat.';
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
export const VAULT_ADD_ITEM = 'Bewijs toevoegen';
export const VAULT_SHOW_MORE = 'Meer tonen';
export const VAULT_BACK_TO_VAULT = 'Terug naar je kluis';
export const VAULT_FOLDERS = 'Mappen';

export const VAULT_STATUS_TITLES = { verified: 'Geverifieerd', toVerify: 'Niet bevestigd', rejected: 'Afgewezen' } as const;
export const VAULT_STATUS_EXPLANATIONS = {
  verified: 'Bevestigd door een officiële of vertrouwde bron. Pas je iets aan, dan moet het opnieuw bevestigd worden.',
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
export const VAULT_DETAIL_DONE = 'Klaar';
export const VAULT_EDIT = 'Aanpassen';
export const VAULT_EDIT_TITLE = 'Bewijs aanpassen';
export const VAULT_RECONFIRM_TITLE = 'Dit bewijs is bevestigd';
export const VAULT_RECONFIRM_MESSAGE =
  'Pas je de gegevens of bestanden aan, dan staat het weer als Niet bevestigd in je kluis. Daarna kun je opnieuw bevestiging aanvragen.';
export const VAULT_RECONFIRM_QUESTION = 'Opnieuw laten bevestigen?';
export const VAULT_DISCARD_CHANGES_TITLE = 'Wijzigingen weggooien?';
export const VAULT_DISCARD_CHANGES_CONFIRM = 'Weggooien';
export const VAULT_DISCARD_CHANGES_MESSAGE = 'Wat je hebt aangepast, wordt niet bewaard.';
export const VAULT_DISCARD_CHANGES_KEEP = 'Verder met aanpassen';
export const VAULT_IN_FOLDERS = 'In mappen';
export const VAULT_REQUEST_DISCARD_KEEP = 'Verder met invullen';
export const VAULT_FIELD_FOLDERS = 'Mappen';
export const VAULT_NO_FOLDER = 'Geen map';
export const VAULT_NEW_KIND_FOLDER = (name: string) => `${name} (nieuwe map)`;
export const VAULT_SAVE = 'Bewaren';
export const VAULT_SAVING = 'Bewaren…';
export const VAULT_CANCEL = 'Annuleren';
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
export const VAULT_ERROR_NOT_READY = 'Dit is nog niet beschikbaar. Probeer het later nog een keer.';

// Bevestiging aanvragen (iOS VaultRequestConfirmationSheet). Only the front for now: nothing is sent or stored.
export const VAULT_REQUEST_ACTION = 'Bevestiging aanvragen';
export const VAULT_REQUEST_AGAIN_ACTION = 'Opnieuw bevestiging aanvragen';
export const VAULT_REQUEST_PREVIEW_LABEL = 'Voorbeeld';
export const VAULT_REQUEST_PREVIEW_ACCESSIBILITY = 'Voorbeeld, werkt nog niet';
export const VAULT_REQUEST_NOT_ACTIVE =
  'Bevestiging aanvragen werkt nog niet. Je kunt alvast kijken hoe het wordt, maar er wordt niets verstuurd.';
export const VAULT_REQUEST_WHO_TITLE = 'Wie kan dit bevestigen?';
export const VAULT_REQUEST_ORGANISATION_PROMPT = 'Bijv. Fontys of LiveWall';
export const VAULT_REQUEST_EMAIL_TITLE = 'E-mailadres van je contactpersoon';
export const VAULT_REQUEST_EMAIL_PROMPT = 'naam@organisatie.nl';
export const VAULT_REQUEST_MESSAGE_TITLE = 'Bericht';
export const VAULT_REQUEST_MESSAGE_PROMPT = 'Bijv. Wil je mijn eindstage bevestigen?';
export const VAULT_REQUEST_SHARED_TITLE = 'Dit ziet de ontvanger';
export const VAULT_REQUEST_SEND = 'Verzoek versturen';
export const VAULT_REQUEST_NOT_SENT_TITLE = 'Nog niet verstuurd';
export const VAULT_REQUEST_NOT_SENT_MESSAGE = (organisation: string) =>
  `Bevestiging aanvragen werkt nog niet in deze versie van PAVE. Er is niets naar ${organisation.trim() || 'de organisatie'} gestuurd en niets bewaard.`;
export const VAULT_REQUEST_DISCARD_TITLE = 'Verzoek weggooien?';
export const VAULT_REQUEST_DISCARD_CONFIRM = 'Weggooien';
export const VAULT_REQUEST_MISSING = {
  organisation: 'Vul de naam van de organisatie in.',
  email: 'Vul een geldig e-mailadres in, zoals naam@organisatie.nl.',
} as const;
export const VAULT_REQUEST_RECIPIENTS = {
  school: {
    title: 'School of opleiding',
    example: "Voor diploma's, cijfers en certificaten.",
    organisationLabel: 'School of opleiding',
    icon: '/images/vault/icons/AcademicCapOutline.svg',
  },
  employer: {
    title: 'Werkgever of stagebedrijf',
    example: 'Voor werkervaring en stages.',
    organisationLabel: 'Werkgever of stagebedrijf',
    icon: '/images/vault/icons/BriefcaseOutline.svg',
  },
  mentor: {
    title: 'Docent of begeleider',
    example: 'Voor projecten, feedback en vaardigheden.',
    organisationLabel: 'School of organisatie van je begeleider',
    icon: '/images/vault/icons/UserGroupOutline.svg',
  },
} as const;
export const VAULT_SHARED_DESCRIPTION = 'Je omschrijving';
export const VAULT_SHARED_TITLE = (title: string, kind: string) => `${title} (${kind.toLowerCase()})`;
export const VAULT_SHARED_FILES = (count: number) => (count === 1 ? '1 bestand' : `${count} bestanden`);
export const VAULT_SHARED_SKILLS = (count: number) => (count === 1 ? '1 vaardigheid' : `${count} vaardigheden`);
