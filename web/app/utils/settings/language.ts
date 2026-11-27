// The languages of PAVE (iOS PaveLanguage and PaveTranslator; keep them the same). Dutch is the source: every text in
// the code is Dutch, and the other languages translate it with the table of the iOS app (public/i18n, made by
// scripts/translations-from-ios.mjs) plus the texts only the web has (public/i18n/web-*.json).

export type PaveLanguage = 'nl' | 'en' | 'pap';

export interface PaveLanguageInfo {
  id: PaveLanguage;
  /** Each language by its own name, so you can find yours even when you cannot read the one PAVE is in. */
  nativeName: string;
  /** Papiamentu gets Curaçao's flag, whose spelling PAVE uses. */
  flag: string;
  /** For dates and numbers; there are no Papiamentu formats, so the Dutch ones of Curaçao. */
  locale: string;
}

export const PAVE_LANGUAGES: PaveLanguageInfo[] = [
  { id: 'nl', nativeName: 'Nederlands', flag: '🇳🇱', locale: 'nl-NL' },
  { id: 'en', nativeName: 'English', flag: '🇬🇧', locale: 'en-NL' },
  { id: 'pap', nativeName: 'Papiamentu', flag: '🇨🇼', locale: 'nl-CW' },
];

export function isPaveLanguage(value: unknown): value is PaveLanguage {
  return value === 'nl' || value === 'en' || value === 'pap';
}

export function languageInfo(language: PaveLanguage) {
  return PAVE_LANGUAGES.find((entry) => entry.id === language) ?? PAVE_LANGUAGES[0]!;
}

/** The language of the browser when PAVE has it, otherwise Dutch. */
export function browserLanguage(languages: readonly string[]): PaveLanguage {
  for (const tag of languages) {
    const code = tag.toLowerCase().split('-')[0];
    if (isPaveLanguage(code)) return code;
  }
  return 'nl';
}

/** Long texts are messages and documents, not PAVE's own words. */
const MAX_PATTERN_LENGTH = 400;
const CACHE_LIMIT = 2000;

function escapeRegExp(text: string) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function letters(key: string) {
  return (key.replaceAll('%@', '').match(/\p{L}/gu) ?? []).length;
}

/** Puts the values in the %@s of a translation, in order, or by number for %1$@. */
export function fillTranslation(translation: string, values: string[]) {
  let next = 0;
  return translation.replace(/%(?:(\d+)\$)?@/g, (_, number: string | undefined) => {
    if (number) return values[Number(number) - 1] ?? '';
    return values[next++] ?? '';
  });
}

/**
 * Turns a Dutch text into another language. A text that is not in the table stays Dutch. Keys with %@ stand for texts
 * with a value in them, such as "Na %@ minuten": the value is taken from the Dutch text and put in the same place in
 * the translation.
 */
export class PaveTranslationTable {
  private readonly exact: Map<string, string>;
  private readonly patterns: { regex: RegExp; translation: string; isLoose: boolean }[];
  private readonly cache = new Map<string, string>();

  constructor(entries: Record<string, string>) {
    this.exact = new Map(Object.entries(entries));
    this.patterns = Object.entries(entries)
      // A key of only values, like "%@ · %@", would fit almost any text.
      .filter(([key]) => key.includes('%@') && letters(key) >= 3)
      .map(([key, translation]) => ({
        regex: new RegExp(`^${key.split('%@').map(escapeRegExp).join('(.+?)')}$`, 's'),
        translation,
        isLoose: letters(key) < 6,
      }))
      // Longer keys first, so "Na %@ minuten" does not lose to a shorter key that also fits.
      .sort((a, b) => b.regex.source.length - a.regex.source.length);
  }

  translate(text: string): string {
    if (!text) return text;
    const hit = this.exact.get(text) ?? this.cache.get(text);
    if (hit !== undefined) return hit;
    let result = text;
    if (text.length <= MAX_PATTERN_LENGTH) {
      for (const { regex, translation, isLoose } of this.patterns) {
        const match = regex.exec(text);
        if (!match) continue;
        const values = match.slice(1);
        // A key with few words of its own, like "%@ bij %@", would also fit a sentence you wrote yourself: it only
        // counts when each value is a name or a number of at most two words.
        if (isLoose && values.some((value) => value.split(' ').length > 2)) continue;
        // A value can be a translatable text itself, such as "morgen" in "wordt dan morgen verwijderd".
        result = fillTranslation(translation, values.map((value) => (value === text ? value : this.translate(value))));
        break;
      }
    }
    if (this.cache.size > CACHE_LIMIT) this.cache.clear();
    this.cache.set(text, result);
    return result;
  }
}
