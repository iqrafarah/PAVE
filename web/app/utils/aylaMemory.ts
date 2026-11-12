import type { MemoryCategory } from '~/types/ayla';
import type { PaveIconName } from './paveIcons';
import { MEMORY_CATEGORIES } from './aylaMessages';

export const MAX_MEMORY_LENGTH = 300;

// Small words that say nothing about the person. Same list as the server (ayla/memory.ts) and iOS.
const STOP_WORDS = new Set([
  'je', 'jij', 'jouw', 'ik', 'mijn', 'me', 'de', 'het', 'een', 'en', 'of', 'bij', 'als', 'aan', 'op', 'in', 'van',
  'voor', 'met', 'naar', 'om', 'te', 'dat', 'die', 'dit', 'er', 'is', 'zijn', 'ben', 'bent', 'wil', 'wilt', 'graag',
  'nu', 'ook',
]);
const COVERED_SHARE = 0.75;
const ACCENTS = /[̀-ͯ]/g;
const NOT_LETTERS_OR_DIGITS = /[^a-z0-9]+/;

function getMeaningfulWords(text: string) {
  const plain = text.toLocaleLowerCase('nl').normalize('NFD').replace(ACCENTS, '');
  const words = plain.split(NOT_LETTERS_OR_DIGITS);
  return new Set(words.filter((word) => word.length > 1 && !STOP_WORDS.has(word)));
}

/** The note already says what the suggestion says, also in other words (same rule as the server). */
export function noteCovers(note: string, suggestion: string) {
  const words = getMeaningfulWords(suggestion);
  if (words.size === 0) return true;

  const knownWords = getMeaningfulWords(note);
  const sharedCount = [...words].filter((word) => knownWords.has(word)).length;
  return sharedCount / words.size >= COVERED_SHARE;
}

export function getCategoryTitle(category: MemoryCategory) {
  const found = MEMORY_CATEGORIES.find((item) => item.id === category);
  return found?.title ?? 'Over jou';
}

/** The categories of the used notes, once each, in the order of the table in docs/ayla.md. */
export function getUsedCategoryTitles(categories: MemoryCategory[]) {
  const used = new Set(categories);
  return MEMORY_CATEGORIES.filter((item) => used.has(item.id)).map((item) => item.title);
}

// As on iOS (.dateTime.day().month(.abbreviated)): "12 nov."
const DATE_FORMAT = new Intl.DateTimeFormat('nl-NL', { day: 'numeric', month: 'short' });

export function formatNoteDate(isoDate: string) {
  return DATE_FORMAT.format(new Date(isoDate));
}

/** How a folder looks (iOS AylaMemoryCategoryStyle): a solid Heroicon on one of the pastel tints of the vault tiles. */
export const MEMORY_CATEGORY_STYLES: Record<MemoryCategory, { icon: PaveIconName; tintClass: string }> = {
  education: { icon: 'academicCap', tintClass: 'bg-card-tint-lavender' },
  work: { icon: 'briefcase', tintClass: 'bg-card-tint-apricot' },
  goals: { icon: 'flag', tintClass: 'bg-card-tint-green' },
  skills: { icon: 'star', tintClass: 'bg-card-tint-lime' },
  values: { icon: 'heart', tintClass: 'bg-card-tint-rose' },
  workStyle: { icon: 'userGroup', tintClass: 'bg-card-tint-lavender' },
  interests: { icon: 'paintBrush', tintClass: 'bg-card-tint-apricot' },
  personal: { icon: 'userCircle', tintClass: 'bg-card-tint-green' },
};
