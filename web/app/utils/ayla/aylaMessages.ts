import type { AylaErrorCode, MemoryCategory } from '~/types/ayla';
import { INSUFFICIENT_AAL_MESSAGE } from '../shared/messages';

// Texts marked "iOS" are the same as in ios/PAVE/Features/Ayla, so both apps say the same.

// Chat (iOS: AylaMessages.swift)
export const AYLA_SIGN_IN_AGAIN = 'Je bent niet meer ingelogd. Log opnieuw in om met Ayla te praten.';
export const AYLA_CONVERSATION_GONE = 'Dit gesprek bestaat niet meer. Begin een nieuw gesprek.';
export const AYLA_UNAVAILABLE = 'Ayla kon nu geen antwoord geven. Probeer het zo opnieuw.';
export const AYLA_CHATS_UNAVAILABLE =
  'Je chats konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.';
export const AYLA_RENAME_FAILED = 'De naam kon niet worden aangepast. Probeer het opnieuw.';
export const AYLA_DELETE_FAILED = 'Het gesprek kon niet worden verwijderd. Probeer het opnieuw.';
export const AYLA_REDO_FAILED = 'Dat lukte niet. Controleer je internetverbinding en probeer het opnieuw.';
export const AYLA_PIN_FAILED = 'Vastzetten lukte niet. Probeer het opnieuw.';
export const AYLA_MEMORY_SAVE_FAILED =
  'Opslaan lukte niet. Controleer je internetverbinding en probeer het opnieuw.';
export const AYLA_MEMORY_FORGET_FAILED =
  'Wissen lukte niet. Controleer je internetverbinding en probeer het opnieuw.';
export const AYLA_MEMORY_NOT_SET_UP =
  'Het geheugen van Ayla staat nog niet aan in PAVE. Zodra het er is, zie je hier alles wat Ayla over je onthoudt.';
export const AYLA_SPEECH_UNAVAILABLE = 'Inspreken werkt nu niet. Typ je vraag maar.';

// Chat labels (iOS)
export const AYLA_NAME = 'Ayla';
export const AYLA_PLACEHOLDER = 'Vraag het aan Ayla';
export const AYLA_THINKING = 'Ayla denkt na…';
/** The big pixel loader, only for reading attachments and first data loads that take long. */
export const AYLA_FETCHING_DATA = 'Gegevens ophalen';
/** Waits shorter than this show no loader at all. */
export const DATA_LOADER_DELAY_MS = 400;
export const AYLA_SEND_LABEL = 'Versturen';
export const AYLA_STOP_LABEL = 'Stop Ayla';
export const AYLA_DICTATE_LABEL = 'Inspreken';
export const AYLA_STOP_DICTATE_LABEL = 'Stop met inspreken';
export const AYLA_ADD_FILE_LABEL = 'Bestand toevoegen';
export const AYLA_ADD_PHOTO_LABEL = 'Foto toevoegen';
export const AYLA_VAULT_SAVING = 'Ayla zet het in je kluis…';
export const AYLA_VAULT_ADDED = 'Toegevoegd aan je kluis';
export const AYLA_PHOTOS_ADDED = (count: number, title: string) =>
  count === 1 ? `Ik heb 1 foto toegevoegd aan ${title}.` : `Ik heb ${count} foto's toegevoegd aan ${title}.`;
export const AYLA_LOOK_MISSING = (logo: boolean, cover: boolean) =>
  logo && cover
    ? 'Ayla vond geen logo of omslag. Wil je er zelf een kiezen?'
    : logo
      ? 'Ayla vond geen logo. Wil je er zelf een kiezen?'
      : 'Nog geen omslag. Wil je er een kiezen?';
export const AYLA_LOOK_LOGO = 'Logo kiezen';
export const AYLA_LOOK_DONE = 'Klaar';
export const AYLA_FILL_BY_AYLA = 'Ayla vult het in';
export const AYLA_FILL_MYSELF = 'Zelf invullen';
export const AYLA_ADDED_CAPTION = (title: string) => `${title} staat in je kluis.`;
export const AYLA_LOOK_COVER = 'Omslag kiezen';
export const AYLA_LOOK_FAILED = 'Die afbeelding kon niet bij je bewijs worden gezet. Kies een JPG of PNG.';
export const AYLA_PHOTOS_FAILED = 'De foto kon niet bij je bewijs worden gezet. Probeer het zo nog een keer.';
/** What the chat tells Ayla after saving (iOS AylaMessages.added): her instructions wait for these words. */
export const AYLA_VAULT_ADDED_MESSAGE = (title: string, files: string[] = []) =>
  files.length ? `Toegevoegd aan mijn kluis: ${title} (met ${files.join(', ')}).` : `Toegevoegd aan mijn kluis: ${title}.`;
/** What is sent with a file and no question of your own. */
export const AYLA_FILES_ONLY_QUESTION = (count: number) => (count === 1 ? 'Bekijk dit bestand.' : 'Bekijk deze bestanden.');
export const AYLA_ATTACH_ITEM_LABEL = 'Item uit je kluis';
export const AYLA_PICK_ITEM_TITLE = 'Kies uit je kluis';
export const AYLA_PICK_ITEM_HINT = 'Ayla gebruikt wat je kiest in dit gesprek.';
export const AYLA_ALL_ITEMS = 'Alle items';
export const AYLA_CONTEXT_ITEMS = (count: number) => `${count} items uit je kluis`;
export const AYLA_PICK_NOT_ALLOWED_TITLE = (count: number) =>
  count === 1 ? AYLA_ASK_NOT_ALLOWED_TITLE : `Ayla mag ${count} van deze items nog niet gebruiken`;
export const AYLA_ASK_ALLOW_ALL = 'Toestaan en gebruiken';
export const AYLA_ASK_WITHOUT_THEM = 'Gebruiken zonder die items';
export const AYLA_PICK_CONTINUE = (count: number) => (count === 0 ? 'Kies items' : count === 1 ? 'Verder met 1 item' : `Verder met ${count} items`);
export const AYLA_PICK_CLOSE = 'Sluiten';
export const AYLA_ADD_ITEM_LABEL = 'Item toevoegen';
export const AYLA_ADD_PLAN_LABEL = 'Plan toevoegen';
export const AYLA_NOT_AVAILABLE_YET = 'Nog niet beschikbaar';
export const AYLA_ADD_TO_MESSAGE_LABEL = 'Toevoegen aan je bericht';
export const AYLA_VAULT_EMPTY_NOTE = 'Je kluis is nog leeg';
export const AYLA_NO_PLAN_NOTE = 'Je hebt nog geen plan';
export const AYLA_COPY_LABEL = 'Kopiëren';
export const AYLA_NEW_ANSWER_LABEL = 'Nieuw antwoord';
export const AYLA_EDIT_QUESTION_LABEL = 'Aanpassen';
export const AYLA_MORE_OPTIONS = 'Meer opties';
export const AYLA_SCROLL_DOWN = 'Naar het nieuwste bericht';
export const AYLA_NEW_CONVERSATION_TITLE = 'Nieuw gesprek';
export const AYLA_RETRY = 'Opnieuw proberen';
export const AYLA_UNDO = 'Ongedaan maken';
export const AYLA_CANCEL = 'Annuleren';
export const AYLA_SAVE = 'Bewaren';
export const AYLA_SEARCH_CHATS = 'Zoeken in chats';
export const AYLA_SEARCH_TAB_ALL = 'Alles';
export const AYLA_SEARCH_TAB_CHATS = 'Chats';
export const AYLA_SEARCH_TAB_PROJECTS = 'Projecten';
export const AYLA_SEARCH_TAB_ITEMS = 'Bewijzen';
export const AYLA_SEARCH_TAB_DOCUMENTS = 'Documenten';
export const AYLA_SEARCH_TAB_IMAGES = 'Afbeeldingen';
export const AYLA_SEARCH_PLACEHOLDER = 'Zoeken in PAVE';
export const AYLA_SEARCH_EMPTY = 'Nog niets om te tonen.';
export const AYLA_SEARCH_CLEAR = 'Wissen';
export const AYLA_SEARCH_CLOSE = 'Zoeken sluiten';
export const AYLA_PIN = 'Vastzetten';
export const AYLA_UNPIN = 'Losmaken';
export const AYLA_RENAME = 'Naam wijzigen';
export const AYLA_DELETE = 'Verwijderen';
export const AYLA_EDIT = 'Aanpassen';
export const AYLA_DELETE_QUESTION = 'Chat verwijderen?';
export const AYLA_DELETE_CONFIRM = 'Verwijderen';
export const AYLA_NO_CHATS = 'Nog geen chats';
export const AYLA_NO_CHATS_BODY =
  'Je gesprekken met Ayla komen hier te staan, ook die je op je iPhone begint.';
export const AYLA_CLOSE_PANEL = 'Sluit het paneel';
export const AYLA_SKILL_GAP = 'Skill-gap:';
export const AYLA_FULL_TIME = 'Fulltime';
export const AYLA_PART_TIME = 'Part-time';
export const AYLA_MAX_TITLE_LENGTH = 80;
export const AYLA_STARTED_ON_PHONE = 'Op iPhone';

// Chat list groups and times (iOS: AylaConversationSection and AylaTimeline in PAVECore)
export const AYLA_TODAY = 'Vandaag';
export const AYLA_YESTERDAY = 'Gisteren';
export const AYLA_SECTION_TITLES = {
  pinned: 'Vastgezet',
  today: AYLA_TODAY,
  yesterday: AYLA_YESTERDAY,
  lastWeek: 'Afgelopen 7 dagen',
  lastMonth: 'Afgelopen 30 dagen',
  earlier: 'Eerder',
} as const;

// Asking about one item from the vault (iOS: AylaMessages.swift)
export const AYLA_ASK_ABOUT_ITEM = 'Vraag Ayla over dit bewijs';
export const AYLA_ASK_NOT_ALLOWED_TITLE = 'Ayla mag dit bewijs nog niet gebruiken';
export const AYLA_ASK_NOT_ALLOWED_MESSAGE =
  'Sta je het toe, dan kan Ayla dit bewijs meenemen in je vragen en zoekopdrachten. Je kunt het altijd weer uitzetten.';
export const AYLA_ASK_ALLOW = 'Toestaan en vragen';
export const AYLA_ASK_WITHOUT = 'Vragen zonder toestemming';
export const AYLA_CLEAR_CONTEXT = 'Niet meer over dit bewijs vragen';

export function getAboutLabel(title: string) {
  return `Over: ${title}`;
}

export function getNoChatsFoundMessage(search: string) {
  return `Geen chats gevonden met “${search.trim()}”.`;
}

export function getDeleteChatMessage(title: string) {
  return `De chat “${title}” wordt voor altijd verwijderd. Dit kan niet terug.`;
}

export function getHomeHeading(firstName: string | null) {
  if (!firstName) return 'Wat wil je vandaag doen?';
  return `Wat wil je vandaag doen, ${firstName}?`;
}

// Written for the web (no iOS counterpart)
export const AYLA_HOME_INTRO =
  'Ayla helpt je bij werk en opleiding. Je krijgt advies, hulp bij je cv en vacatures die bij je passen.';
export const AYLA_OFFLINE = 'Geen verbinding. Probeer het zo opnieuw.';
export const AYLA_NEW_CHAT = 'Nieuwe chat';

// Projecten: een map voor chats, met eigen instructies voor Ayla.
export const AYLA_PROJECTS = 'Projecten';
export const AYLA_NEW_PROJECT = 'Nieuw project';
export const AYLA_PROJECT_NAME_LABEL = 'Naam van het project';
export const AYLA_PROJECT_NAME_PLACEHOLDER = 'Bijvoorbeeld: Stage zoeken';
export const AYLA_PROJECT_INSTRUCTIONS = 'Instructies voor Ayla';
export const AYLA_PROJECT_INSTRUCTIONS_HINT =
  'Ayla volgt dit in elke chat in dit project. Schrijf bijvoorbeeld waar het project over gaat of hoe Ayla moet antwoorden.';
export const AYLA_PROJECT_INSTRUCTIONS_MAX = 2000;
export const AYLA_PROJECT_INSTRUCTIONS_PLACEHOLDER = 'Bijvoorbeeld: Help me met stage zoeken in de zorg. Antwoord kort en in simpele taal.';
export const AYLA_PROJECT_EDIT = 'Project aanpassen';
export const AYLA_PROJECT_CREATE = 'Project maken';
export const AYLA_PROJECT_MOVED = (project: string) => `Chat verplaatst naar ${project}`;
export const AYLA_PROJECT_MOVE_FAILED = 'De chat kon niet worden verplaatst. Probeer het opnieuw.';
export const AYLA_PROJECT_NO_INSTRUCTIONS = 'Nog geen instructies. Kies Aanpassen om Ayla te vertellen waar dit project over gaat.';
export const AYLA_PROJECT_DELETE_QUESTION = 'Project verwijderen?';
export const AYLA_PROJECT_DELETE_BODY = 'Je chats blijven bestaan, ze horen alleen niet meer bij een project.';
export const AYLA_PROJECT_CHATS = 'Chats in dit project';
export const AYLA_PROJECT_NO_CHATS = 'Nog geen chats in dit project. Stel hieronder je eerste vraag.';
export const AYLA_PROJECT_DELETE = 'Project verwijderen';
export const AYLA_PROJECTS_NOT_READY = 'Projecten zijn nog niet beschikbaar. Probeer het later opnieuw.';
export const AYLA_PROJECT_GONE = 'Dit project bestaat niet meer.';
export const AYLA_PROJECT_FAILED = 'Het project kon niet worden opgeslagen. Probeer het opnieuw.';
export const AYLA_PROJECT_LOAD_FAILED = 'Het project kon niet worden geladen.';
export const AYLA_NOTHING_FOUND = 'Dit kon niet gevonden worden';
export const AYLA_NO_MESSAGES = 'Nog geen berichten.';
export const AYLA_CHATS_LOADING = 'Chats laden…';
export const MEMORY_LOADING = 'Laden…';
export const AYLA_OPEN_CHATS = 'Gesprekken openen';
export const AYLA_TEXT_TOO_LONG = 'Je bericht is te lang. Het mag maximaal 4000 tekens zijn.';
export const AYLA_FILE_TYPE_UNSUPPORTED =
  'Dit bestandstype kan ik nog niet lezen. Probeer een pdf, foto, .txt-, .md- of .csv-bestand.';
export const AYLA_FILE_EMPTY = 'In dit bestand staat geen tekst.';
export const AYLA_FILE_TOO_LONG = 'Dit bestand is te lang. Ayla leest maximaal 20.000 tekens per bestand.';
export const AYLA_TOO_MANY_FILES = 'Je kunt 5 bestanden tegelijk toevoegen.';
export const AYLA_REMOVE_FILE = 'Bestand weghalen';
export const AYLA_COPIED = 'Gekopieerd';
export const AYLA_VAULT_LABEL = 'Kluis';
export const AYLA_DISCLAIMER = 'Ayla is een AI-assistent en kan fouten maken.';
export const AYLA_ERROR_LOADING_CHAT = 'Dit gesprek kon niet worden geladen. Probeer het opnieuw.';
export const AYLA_MICROPHONE_BLOCKED =
  'Geef je browser toegang tot je microfoon om je vraag in te spreken.';
export const AYLA_EXAMPLE_LABEL = 'Voorbeeld';
export const AYLA_OPEN_VACANCY = 'Bekijk vacature';
export const AYLA_SIGN_IN_AGAIN_ACTION = 'Opnieuw inloggen';
export const AYLA_ENTER_CODE_ACTION = 'Code invullen';

export function getOpenScreenLabel(screenName: string) {
  return `Open ${screenName}`;
}

const ERROR_MESSAGES: Record<AylaErrorCode, string> = {
  invalid_request: AYLA_UNAVAILABLE,
  not_signed_in: AYLA_SIGN_IN_AGAIN,
  insufficient_aal: INSUFFICIENT_AAL_MESSAGE,
  conversation_not_found: AYLA_CONVERSATION_GONE,
  project_not_found: AYLA_PROJECT_GONE,
  unavailable: AYLA_UNAVAILABLE,
  offline: AYLA_OFFLINE,
};

export function getAylaErrorMessage(code: AylaErrorCode) {
  return ERROR_MESSAGES[code];
}

// Memory (iOS: Memory/*.swift and docs/ayla.md)
export const MEMORY_PAGE_TITLE = 'Wat Ayla over je weet';
// Word for word from iOS AylaMemoryScreen, AylaMemoryFolderScreen, AylaMemoryFolder and AylaMemoryEditor.
export const MEMORY_ON_EXPLANATION =
  'Ayla stelt voor wat ze onthoudt en jij beslist. Ze gebruikt het in je gesprekken op je iPhone en op het web.';
export const MEMORY_NOTHING_YET =
  'Ayla onthoudt nog niets over je. Vertel je in een gesprek iets wat later handig is, zoals je opleiding of een doel, dan vraagt ze of ze het mag onthouden. Je kunt ook zelf iets toevoegen.';
export const MEMORY_FOLDER_OFF = 'Het geheugen staat uit: Ayla gebruikt dit nu niet.';
export const MEMORY_NOT_LOADED = 'Niet geladen';
export const MEMORY_EDIT = 'Aanpassen';
export const MEMORY_EDITOR_FOOTER = 'Ayla gebruikt dit in je gesprekken op je iPhone en op het web.';
export const MEMORY_SWITCH_LABEL = 'Ayla mag dingen onthouden';
export const MEMORY_OFF_NOTICE =
  'Ayla gebruikt niets uit deze mappen en stelt niets voor. Wat erin staat, blijft bewaard tot je het wist.';
export const MEMORY_FORGET_ALL = 'Alles vergeten';
export const MEMORY_FORGET_ALL_QUESTION = 'Alles vergeten?';
export const MEMORY_FORGET_ALL_BODY =
  'Ayla vergeet alles wat hier staat, ook op je iPhone. Dit kun je niet ongedaan maken.';
export const MEMORY_FORGET = 'Vergeten';
export const MEMORY_ADD = 'Iets toevoegen';
export const MEMORY_ADD_PLACEHOLDER = 'Bijvoorbeeld: Je wilt werken in de zorg-ICT…';
export const MEMORY_CATEGORY_LABEL = 'Categorie';
export const MEMORY_CATEGORY_FOOTER = "Kies er één of meer, zoals Werk en stages én Interesses en hobby's.";
export const MEMORY_SUGGESTED_BY_AYLA = 'Voorgesteld door Ayla';
export const MEMORY_ADDED_BY_USER = 'Zelf toegevoegd';
export const MEMORY_EMPTY_FOLDER = 'Nog leeg';
export const MEMORY_REMEMBER = 'Onthouden';
export const MEMORY_UPDATE = 'Bijwerken';
export const MEMORY_REMOVE = 'Weghalen';
export const MEMORY_NOT_NEEDED = 'Nee, niet nodig';
export const MEMORY_QUESTION_REMEMBER = 'Zal ik dit over je onthouden?';
export const MEMORY_QUESTION_UPDATE = 'Zal ik dit bijwerken?';
export const MEMORY_QUESTION_REMOVE = 'Zal ik dit weghalen?';
export const MEMORY_SEE_ALL = 'Bekijk wat Ayla over je weet';
export const MEMORY_SUGGESTION_FOOTNOTE = 'Zeg je nee, dan blijft het bewaard.';
export const MEMORY_USED_HEADING = 'Dit antwoord steunt op';
// Written for the web
export const MEMORY_SAVED = 'Klaar.';
export const MEMORY_LOAD_FAILED =
  'Wat Ayla over je weet kon niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.';
export const MEMORY_SETTING_FAILED = 'De instelling kon niet worden bewaard. Probeer het opnieuw.';

export function getAddToFolderLabel(categoryTitle: string) {
  return `Iets toevoegen aan ${categoryTitle}`;
}

/** "Leeg", "1 ding" or "3 dingen" under a folder. */
export function getFolderCount(count: number) {
  if (count === 0) return 'Leeg';
  return count === 1 ? '1 ding' : `${count} dingen`;
}

export function getRemoveFromCategoryLabel(categoryTitle: string) {
  return `Weghalen uit ${categoryTitle.toLowerCase()}`;
}

export function getUsedMemoriesLine(categoryTitles: string[]) {
  const lowerCased = categoryTitles.map((title) => title.toLowerCase());
  return `Gebaseerd op: ${lowerCased.join(', ')}`;
}

export function getEmptyFolderMessage(categoryTitle: string) {
  return `Vertel je Ayla iets over ${categoryTitle.toLowerCase()}, dan vraagt ze of ze het hier mag bewaren. Je kunt ook zelf iets toevoegen.`;
}

export function getNoteSourceLine(source: 'ayla' | 'user', date: string) {
  const sourceText = source === 'ayla' ? MEMORY_SUGGESTED_BY_AYLA : MEMORY_ADDED_BY_USER;
  return `${sourceText} · ${date}`;
}

// The order in docs/ayla.md, also used for "Gebaseerd op".
export const MEMORY_CATEGORIES: { id: MemoryCategory; title: string }[] = [
  { id: 'education', title: 'Opleiding' },
  { id: 'work', title: 'Werk en stages' },
  { id: 'goals', title: 'Doelen' },
  { id: 'skills', title: 'Vaardigheden' },
  { id: 'values', title: 'Wat je belangrijk vindt' },
  { id: 'workStyle', title: 'Hoe je wilt werken' },
  { id: 'interests', title: "Interesses en hobby's" },
  { id: 'personal', title: 'Over jou' },
];

// What a chat row carries while it is dragged onto a project.
export const CHAT_DRAG_TYPE = 'application/x-pave-chat';

// Vergrendelde chats: één pincode voor alle vergrendelde chats.
export const AYLA_LOCK_MENU = 'Chat vergrendelen';
export const AYLA_UNLOCK_MENU = 'Ontgrendelen';
export const AYLA_LOCK_QUESTION = 'Deze chat vergrendelen?';
export const AYLA_LOCK_BODY = 'De chat staat dan alleen nog bij Vergrendelde chats. Je opent hem met je pincode.';
export const AYLA_LOCK_CONFIRM = 'Chat vergrendelen';
export const AYLA_LOCK_FAILED = 'De chat kon niet worden vergrendeld. Probeer het opnieuw.';
export const AYLA_UNLOCK_CHAT = 'Ontgrendelen';
export const AYLA_UNLOCK_FAILED = 'De chat kon niet worden ontgrendeld. Probeer het opnieuw.';
export const AYLA_LOCKED_CHATS = 'Vergrendelde chats';

// Archiveren en automatisch verwijderen.
export const AYLA_ARCHIVE_MENU = 'Archiveren';
export const AYLA_UNARCHIVE = 'Terugzetten';
export const AYLA_ARCHIVED_CHATS = 'Gearchiveerd';
export const AYLA_ARCHIVED_PATH = '/instellingen/gearchiveerd';
export const AYLA_ARCHIVED_EMPTY = 'Je hebt geen gearchiveerde chats. Kies Archiveren in het menu van een chat.';
export const AYLA_ARCHIVED_INTRO = 'Zoek je gearchiveerde chats en zet terug wat je weer wilt gebruiken.';
export const AYLA_ARCHIVED_SEARCH = 'Zoek in gearchiveerde chats';
export const AYLA_ARCHIVED_NO_MATCH = 'Geen chats gevonden.';
export const AYLA_ARCHIVED_SORT_LABEL = 'Sorteren';
export const AYLA_ARCHIVED_SORT_NEWEST = 'Nieuwste eerst';
export const AYLA_ARCHIVED_SORT_OLDEST = 'Oudste eerst';
export const AYLA_ARCHIVED_SORT_NAME = 'Naam';
export const AYLA_ARCHIVED_PROJECT_LABEL = 'Project';
export const AYLA_ARCHIVED_ALL_PROJECTS = 'Alle projecten';
export const AYLA_ARCHIVED_NO_PROJECT = 'Geen project';
export function getArchivedSummary(count: number) {
  return count === 0 ? 'Nog geen gearchiveerde chats.' : count === 1 ? '1 chat' : `${count} chats`;
}
export const AYLA_ARCHIVE_FAILED = 'Archiveren lukte niet. Probeer het opnieuw.';
export const AYLA_UNARCHIVE_FAILED = 'Terugzetten lukte niet. Probeer het opnieuw.';
export const SETTINGS_AUTO_DELETE_TITLE = 'Chats automatisch verwijderen';
export const SETTINGS_AUTO_DELETE_HINT = 'Vastgezette, gearchiveerde en vergrendelde chats blijven altijd bewaard.';
export function getAutoDeleteQuestion(period: string) {
  return `Chats die langer dan ${period} niet zijn gebruikt worden verwijderd, ook de bestaande. Vastgezette, gearchiveerde en vergrendelde chats blijven bewaard. Dit kan niet ongedaan worden gemaakt.`;
}
export const SETTINGS_AUTO_DELETE_FAILED = 'De keuze is niet opgeslagen. Probeer het opnieuw.';
export const SETTINGS_AUTO_DELETE_OPTIONS = [
  { value: 'never', days: null, period: '', label: 'Nooit', meaning: 'Chats blijven bewaard' },
  { value: '1', days: 1, period: '24 uur', label: 'Na 24 uur', meaning: 'Na een dag niet gebruikt' },
  { value: '30', days: 30, period: '30 dagen', label: 'Na 30 dagen', meaning: 'Na een maand niet gebruikt' },
  { value: '90', days: 90, period: '90 dagen', label: 'Na 90 dagen', meaning: 'Na drie maanden niet gebruikt' },
] as const;
export const AYLA_LOCKED_EMPTY = 'Je hebt geen vergrendelde chats. Kies Chat vergrendelen in het menu van een chat.';
export const AYLA_LOCKED_RELOCK = 'Nu vergrendelen';
export const AYLA_LOCKED_NEW_CHAT = 'Nieuwe vergrendelde chat';
export const AYLA_LOCKED_CHIP = `Nieuwe chat in ${AYLA_LOCKED_CHATS}`;
export const AYLA_PIN_LENGTH = 4;
export const AYLA_PIN_CREATE_TITLE = 'Kies een pincode';
export const AYLA_PIN_CREATE_BODY = 'Kies 4 cijfers. Daarmee open je je vergrendelde chats.';
export const AYLA_PIN_CONFIRM_TITLE = 'Herhaal je pincode';
export const AYLA_PIN_CONFIRM_BODY = 'Typ dezelfde 4 cijfers nog een keer.';
export const AYLA_PIN_ENTER_TITLE = 'Pincode';
export const AYLA_PIN_ENTER_BODY = 'Typ je pincode.';
export const AYLA_PIN_LABEL = 'Pincode';
export const AYLA_PIN_MISMATCH = 'De pincodes zijn niet hetzelfde. Probeer het opnieuw.';
export const AYLA_PIN_WRONG = 'Deze pincode klopt niet.';
export const AYLA_PIN_BLOCKED = 'Te vaak fout. Probeer het over 5 minuten opnieuw.';
export const AYLA_PINCODE_FAILED = 'Er ging iets mis. Probeer het opnieuw.';
export const AYLA_PIN_FORGOT = 'Pincode vergeten?';
export const AYLA_PIN_RESET_QUESTION = 'Pincode resetten?';
export const AYLA_PIN_RESET_BODY = 'Al je vergrendelde chats worden verwijderd. Dit kan niet terug.';
export const AYLA_PIN_RESET_CONFIRM = 'Resetten en verwijderen';

// Accountpincode in Privacy: dezelfde pincode op al je apparaten, dus ook vanaf je laptop te wijzigen of te resetten.
export const ACCOUNT_PIN_TITLE = 'Accountpincode';
export const ACCOUNT_PIN_INTRO = 'Gebruik je accountpincode om je vergrendelde chats op al je apparaten te beveiligen.';
export const ACCOUNT_PIN_NONE = 'Je hebt nog geen accountpincode. Die kies je zodra je een chat vergrendelt.';
export const ACCOUNT_PIN_CHANGE_TITLE = 'Pincode wijzigen';
export const ACCOUNT_PIN_CHANGE_BODY = 'Kies een nieuwe pincode voor je vergrendelde chats.';
export const ACCOUNT_PIN_CHANGE_BUTTON = 'Wijzigen';
export const ACCOUNT_PIN_RESET_TITLE = 'Pincode resetten';
export const ACCOUNT_PIN_RESET_BODY = 'Reset je pincode alleen als je je huidige pincode bent vergeten. Je vergrendelde chats blijven bewaard.';
export const ACCOUNT_PIN_RESET_BUTTON = 'Resetten';
export const ACCOUNT_PIN_CURRENT_TITLE = 'Huidige pincode';
export const ACCOUNT_PIN_CURRENT_BODY = 'Typ je huidige pincode om een nieuwe te kiezen.';
export const ACCOUNT_PIN_NEW_TITLE = 'Kies een nieuwe pincode';
export const ACCOUNT_PIN_NEW_BODY = 'Kies 4 nieuwe cijfers. Daarmee open je vanaf nu je vergrendelde chats.';
export const ACCOUNT_PIN_CHANGED = 'Je pincode is gewijzigd.';
export const ACCOUNT_PIN_WAS_RESET = 'Je pincode is gereset. Je vergrendelde chats zijn bewaard.';
export const ACCOUNT_PIN_DELETED = 'Je pincode en je vergrendelde chats zijn verwijderd.';
export const ACCOUNT_PIN_VERIFY_TITLE = 'Bevestig dat jij het bent';
export const ACCOUNT_PIN_VERIFY_BODY = 'Typ de code uit je authenticator-app. Daarna kies je een nieuwe pincode. Je vergrendelde chats blijven bewaard.';
export const ACCOUNT_PIN_CODE_LABEL = 'Code uit je authenticator-app';
export const ACCOUNT_PIN_DELETE_ALL = 'Of verwijder alles en begin opnieuw';
export const ACCOUNT_PIN_DELETE_BODY = 'Je pincode wordt gewist en al je vergrendelde chats worden definitief verwijderd. Dit kan niet ongedaan worden gemaakt.';

// Menu's van projecten en chats, en verplaatsen naar een project.
export const AYLA_RECENT = 'Recent';
export const AYLA_PROJECT_SETTINGS = 'Projectinstellingen';
export const AYLA_PROJECT_PIN = 'Vastzetten';
export const AYLA_PROJECT_UNPIN = 'Losmaken';
export const AYLA_PROJECT_PINNED = 'Vastgezet';
export const AYLA_MOVE_TO_PROJECT = 'Naar project verplaatsen';
export const AYLA_MOVE_TITLE = 'Verplaatsen naar project';
export const AYLA_MOVE_NO_PROJECT = 'Geen project';
export const AYLA_MOVE_NO_PROJECT_HINT = 'Haal de chat uit zijn project';
export const AYLA_MOVE_EMPTY = 'Je hebt nog geen projecten. Maak er een met de + bij Projecten.';
export const AYLA_REMOVE_FROM_PROJECT = 'Uit project halen';
export const AYLA_REMOVED_FROM_PROJECT = 'Chat uit het project gehaald';
export const AYLA_PROJECT_EMPTY = 'Nog geen chats. Chats in dit project verschijnen hier.';
export const AYLA_PROJECT_NEW_CHAT = 'Nieuwe chat in project';
export function getProjectChipLabel(name: string) {
  return `Nieuwe chat in ${name}`;
}
export const AYLA_PANEL_RESIZE = 'Breedte van de chatlijst aanpassen';
export const AYLA_MOVE_SEARCH = 'Zoek of maak een project aan';
export const AYLA_MOVE_NOTHING_FOUND = 'Geen project gevonden.';
export function AYLA_MOVE_CREATE(name: string) {
  return `Nieuw project “${name}”`;
}

// Bronnen of a project: vault items that belong to it, used by Ayla in every chat of the project.
export const AYLA_PROJECT_TAB_CHATS = 'Chats';
export const AYLA_PROJECT_SOURCES = 'Bronnen';
export const AYLA_SOURCES_ADD = 'Bronnen toevoegen';
export const AYLA_SOURCES_EMPTY_TITLE = 'Geef Ayla meer context';
export const AYLA_SOURCES_SORT_NEWEST = 'Nieuwste';
export const AYLA_SOURCES_SORT_OLDEST = 'Oudste';
export const AYLA_SOURCES_SORT_NAME = 'Naam';
export const AYLA_SOURCES_FILTER_ALL = 'Alles';
export const AYLA_SOURCES_SORT_LABEL = 'Sorteren';
export const AYLA_SOURCES_FILTER_LABEL = 'Filteren';
export const AYLA_SOURCES_UPLOAD = 'Bestand toevoegen';
export const AYLA_SOURCES_FROM_VAULT = 'Uit kluis halen';
export const AYLA_SOURCES_REMOVE = 'Verwijderen uit project';
export const AYLA_SOURCES_EMPTY = 'Voeg bronnen toe om Ayla meer context over je project te geven. Ayla gebruikt ze in alle chats van dit project.';
export const AYLA_SOURCES_NO_MATCH = 'Geen bronnen met dit filter.';
export const AYLA_SOURCES_LOADING = 'Bronnen laden…';
export const AYLA_SOURCES_FAILED = 'Dit is niet gelukt. Probeer het opnieuw.';
export const AYLA_SOURCES_ALLOW_FAILED = 'De bron is toegevoegd, maar Ayla mag hem nog niet gebruiken. Zet "Ayla mag dit bekijken en gebruiken" aan bij het item.';
