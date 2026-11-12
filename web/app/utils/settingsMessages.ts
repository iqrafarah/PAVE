import type { MemoryStatus } from '~/composables/useAylaMemory';

// The texts of the settings screen, word for word from iOS (ios/PAVE/Features/Settings/SettingsScreen.swift), so
// web and iPhone say the same thing in the same order.
export const SETTINGS_TITLE = 'Instellingen';
export const SETTINGS_ACCOUNT = 'Account';
export const SETTINGS_YOUR_ACCOUNT = 'Je account';
export const SETTINGS_SIGN_OUT = 'Uitloggen';
export const SETTINGS_SIGN_OUT_QUESTION = 'Wil je uitloggen?';
export const SETTINGS_SIGN_OUT_FAILED = 'Uitloggen lukte niet. Probeer het opnieuw.';
export const SETTINGS_AYLA = 'Ayla';
export const SETTINGS_MEMORY_LINK = 'Wat Ayla over je weet';
export const SETTINGS_VOICE_TEXT = 'Tekst bij praten met Ayla';
export const SETTINGS_VOICE_TEXT_EXPLANATION =
  'Je leest zin voor zin mee met wat Ayla zegt. Zet je dit uit, dan zie je alleen de orb.';

/** The line under "Wat Ayla over je weet" (iOS SettingsScreen.memorySummary). */
export function getMemorySummary(status: MemoryStatus, isEnabled: boolean, noteCount: number) {
  if (status === 'notSetUp') return 'Nog niet beschikbaar';
  if (status !== 'ready') return 'Bekijk, pas aan of wis wat Ayla onthoudt';
  if (!isEnabled) return 'Uit: Ayla onthoudt niets';
  if (noteCount === 0) return 'Ayla onthoudt nog niets';
  if (noteCount === 1) return 'Ayla onthoudt 1 ding';
  return `Ayla onthoudt ${noteCount} dingen`;
}

// The menu (iOS Features/Main): the same places and words as on the iPhone.
export const MENU_LABEL = 'Menu';
export const MENU_CLOSE = 'Menu sluiten';
export const MENU_CHATS = 'Chats';
export const MENU_NEW_CONVERSATION = 'Nieuw gesprek';
export const MENU_NOTIFICATIONS = 'Meldingen';
export const MENU_ACCOUNT = 'Je account';


export const SETTINGS_PATH = '/instellingen';
export const SETTINGS_ACCOUNT_PATH = '/instellingen/account';
export const SETTINGS_APPEARANCE_PATH = '/instellingen/weergave';
export const SETTINGS_AYLA_PATH = '/instellingen/ayla';
export const SETTINGS_PRIVACY_PATH = '/instellingen/privacy';
export const SETTINGS_ACCOUNT_SUBTITLE = 'Je naam, foto en gegevens';
export const SETTINGS_GENERAL = 'Algemeen';
export const SETTINGS_AYLA_PRIVACY = 'Ayla en privacy';
export const SETTINGS_PRIVACY = 'Privacy';
export const PERSONAL_TITLE = 'Weergave';
export const PERSONAL_BACK = 'Instellingen';
export const PERSONAL_THEME = 'Themakleur';
export const PERSONAL_CUSTOM_COLOR = 'Eigen kleur';
export const PERSONAL_CUSTOM_COLOR_HINT = 'Kies je eigen kleur';
export const PERSONAL_VAULT_VIEW = 'Weergave kluis';
export const PERSONAL_VIEW_LIST = 'Lijstweergave';
export const PERSONAL_VIEW_GRID = 'Rasterweergave';
export const PERSONAL_VAULT_HINT = 'Zo opent je kluis. In de kluis kun je even wisselen; de volgende keer opent hij weer zo.';
export const PERSONAL_TEXT_SIZE = 'Tekstgrootte';
export const PERSONAL_DEVICE_NOTE = 'Je keuzes gelden voor deze browser.';
export const PERSONAL_THEMES = [
  { id: 'green', name: 'Groen', hex: '#355D4C', accent: '#355D4C' },
  { id: 'blue', name: 'Blauw', hex: '#4F7DB8', accent: '#4C78B1' },
  { id: 'gold', name: 'Goud', hex: '#C89A2E', accent: '#927022' },
  { id: 'pink', name: 'Roze', hex: '#C56A8C', accent: '#AD5D7B' },
  { id: 'orange', name: 'Oranje', hex: '#C97A52', accent: '#A76544' },
  { id: 'purple', name: 'Paars', hex: '#8A6AC8', accent: '#8466C0' },
  { id: 'red', name: 'Rood', hex: '#C86A6C', accent: '#B25E60' },
  { id: 'lime', name: 'Limoen', hex: '#C8C36A', accent: '#7A7741' },
] as const;
export const PERSONAL_TEXT_SIZES = [
  { id: 'small', name: 'Klein' },
  { id: 'normal', name: 'Standaard' },
  { id: 'large', name: 'Groot' },
] as const;

export const PERSONAL_PHOTO = 'Profielafbeelding';
export const PERSONAL_PHOTO_CHANGE = 'Wijzigen';
export const PERSONAL_PHOTO_CHOOSE = 'Foto kiezen';
export const PERSONAL_PHOTO_REMOVE = 'Verwijderen';
export const PERSONAL_PHOTO_REMOVE_QUESTION = 'Profielafbeelding verwijderen?';
export const PERSONAL_PHOTO_HINT = 'Kies een foto en schuif hem zo dat je gezicht in de cirkel staat.';
export const PERSONAL_PHOTO_SAVING = 'Je foto wordt bewaard…';
export const PERSONAL_PHOTO_TYPE = 'Kies een JPG- of PNG-afbeelding van maximaal 5 MB.';
export const PERSONAL_NOT_READY = 'Je naam en foto aanpassen kan nog niet. Zodra PAVE er klaar voor is, kan het hier.';
export const PERSONAL_SAVE_FAILED = 'Bewaren lukte niet. Probeer het opnieuw.';
export const PERSONAL_LOAD_FAILED = 'Je gegevens konden niet laden. Probeer het opnieuw.';
export const PERSONAL_NAME = 'Hoe Ayla je noemt';
export const PERSONAL_NAME_PROMPT = 'Je voornaam of roepnaam';
export const PERSONAL_NAME_HINT = 'Leeg laten? Dan gebruikt PAVE je voornaam.';
export const PERSONAL_SAVE = 'Bewaren';
export const PERSONAL_FULL_NAME = 'Volledige naam';
export const PERSONAL_EMAIL = 'E-mailadres';
export const PERSONAL_DETAILS_HINT = 'Deze gegevens kun je hier niet aanpassen.';
export const SETTINGS_PRIVACY_DEVICE_NOTE = 'Opnieuw vergrendelen met je pincode of Face ID en chats vindbaar maken in iPhone-zoeken stel je in via de PAVE-app op je iPhone.';

export const PERSONAL_SYNCED = 'Je keuzes worden bewaard in je account en gelden ook op je iPhone.';
export const PERSONAL_SYNC_LOADING = 'Je instellingen laden…';
export const PERSONAL_SYNC_SAVING = 'Je keuzes bewaren…';
export const PERSONAL_SYNC_FAILED = 'Je keuzes werken hier, maar bewaren in je account lukte niet. Probeer het opnieuw.';
export const PERSONAL_SYNC_LOAD_FAILED = 'Je accountinstellingen konden niet laden. Probeer het opnieuw.';
export const PERSONAL_CUSTOM_LOCAL = 'Je eigen kleur werkt nu alleen in deze browser. Bewaren in je account is nog niet beschikbaar.';
export const PERSONAL_STORAGE_FAILED = 'Je browser kon je keuzes niet bewaren. Ze werken tot je deze pagina sluit.';
