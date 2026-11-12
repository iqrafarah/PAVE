import type { AylaErrorCode, MemoryCategory } from '~/types/ayla';
import { INSUFFICIENT_AAL_MESSAGE } from './messages';

// Texts marked "iOS" are the same as in ios/PAVE/Features/Ayla, so both apps say the same.

// Chat (iOS: AylaMessages.swift)
export const AYLA_SIGN_IN_AGAIN = 'Je sessie is verlopen. Log opnieuw in om met Ayla te praten.';
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
export const AYLA_PIN = 'Vastzetten';
export const AYLA_UNPIN = 'Losmaken';
export const AYLA_RENAME = 'Naam wijzigen';
export const AYLA_DELETE = 'Verwijderen';
export const AYLA_CHAT_DELETED = 'Chat verwijderd';
export const AYLA_NO_CHATS = 'Nog geen chats';
export const AYLA_NO_CHATS_BODY =
  'Je gesprekken met Ayla komen hier te staan, ook die je op je iPhone of Apple Watch begint.';
export const AYLA_CLOSE_PANEL = 'Sluit het paneel';
export const AYLA_SKILL_GAP = 'Skill-gap:';
export const AYLA_FULL_TIME = 'Fulltime';
export const AYLA_PART_TIME = 'Part-time';

export function getNoChatsFoundMessage(search: string) {
  return `Geen chats gevonden met “${search.trim()}”.`;
}

export function getHomeHeading(firstName: string | null) {
  if (!firstName) return 'Wat wil je vandaag doen?';
  return `Wat wil je vandaag doen, ${firstName}`;
}

// Written for the web (no iOS counterpart)
export const AYLA_HOME_INTRO =
  'Ontdek kansen, krijg persoonlijk advies en werk met AI direct in jouw PAVE-omgeving. Van je kluis en ontwikkelplan tot vacatures en sollicitaties.';
export const AYLA_OFFLINE = 'Geen verbinding. Probeer het zo opnieuw.';
export const AYLA_NEW_CHAT = 'Nieuwe chat';
export const AYLA_PINNED_HEADING = 'Vastgezet';
export const AYLA_CHATS_HEADING = 'Chats';
export const AYLA_NOTHING_FOUND = 'Dit kon niet gevonden worden';
export const AYLA_NO_MESSAGES = 'Nog geen berichten.';
export const AYLA_CHATS_LOADING = 'Chats laden…';
export const MEMORY_LOADING = 'Laden…';
export const AYLA_OPEN_CHATS = 'Gesprekken openen';
export const AYLA_TEXT_TOO_LONG = 'Je bericht is zo lang als het kan zijn: 4000 tekens.';
export const AYLA_FILE_TYPE_UNSUPPORTED =
  'Dit bestandstype kan ik nog niet lezen. Probeer een .txt-, .md- of .csv-bestand.';
export const AYLA_FILE_EMPTY = 'In dit bestand staat geen tekst.';
export const AYLA_FILE_TOO_LONG = 'Dit bestand is te lang. Ayla leest maximaal 20.000 tekens per bestand.';
export const AYLA_TOO_MANY_FILES = 'Je kunt 3 bestanden tegelijk toevoegen.';
export const AYLA_REMOVE_FILE = 'Bestand weghalen';
export const AYLA_COPIED = 'Gekopieerd';
export const AYLA_VAULT_LABEL = 'Kluis';
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
  'Ayla stelt voor wat ze onthoudt en jij beslist. Ze gebruikt het in je gesprekken op je iPhone, het web en je Apple Watch.';
export const MEMORY_NOTHING_YET =
  'Ayla onthoudt nog niets over je. Vertel je in een gesprek iets wat later handig is, zoals je opleiding of een doel, dan vraagt ze of ze het mag onthouden. Je kunt ook zelf iets toevoegen.';
export const MEMORY_FOLDER_OFF = 'Het geheugen staat uit: Ayla gebruikt dit nu niet.';
export const MEMORY_NOT_LOADED = 'Niet geladen';
export const MEMORY_EDIT = 'Aanpassen';
export const MEMORY_EDITOR_FOOTER = 'Ayla gebruikt dit in je gesprekken op je iPhone, het web en je Apple Watch.';
export const MEMORY_SWITCH_LABEL = 'Ayla mag dingen onthouden';
export const MEMORY_OFF_NOTICE =
  'Ayla gebruikt niets uit deze mappen en stelt niets voor. Wat erin staat, blijft bewaard tot je het wist.';
export const MEMORY_FORGET_ALL = 'Alles vergeten';
export const MEMORY_FORGET_ALL_QUESTION = 'Alles vergeten?';
export const MEMORY_FORGET_ALL_BODY =
  'Ayla vergeet alles wat hier staat, ook op je iPhone en Apple Watch. Dit kun je niet ongedaan maken.';
export const MEMORY_FORGET = 'Vergeten';
export const MEMORY_ADD = 'Iets toevoegen';
export const MEMORY_ADD_PLACEHOLDER = 'Bijvoorbeeld: Je wilt werken in de zorg-ICT…';
export const MEMORY_CATEGORY_LABEL = 'Categorie';
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
export const MEMORY_SUGGESTION_FOOTNOTE = 'Laat je het weghalen uit, dan blijft het gewoon staan.';
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
