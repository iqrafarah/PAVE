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
