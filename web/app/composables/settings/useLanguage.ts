import type { PaveLanguage } from '~/utils/settings/language';
import { browserLanguage, isPaveLanguage, PaveTranslationTable } from '~/utils/settings/language';

// Instellingen › Taal (iOS PaveLanguageStore and ProfileModel.setLanguage): Nederlands, English or Papiamentu. The
// choice follows the account to every device (profiles.language, migration 20261126120000); without that column, or
// before signing in, it stays in this browser. Not chosen at all: the language of the browser when PAVE has it.

const COOKIE = 'pave-language';

interface LanguageState {
  language: PaveLanguage;
  /** Picked in Instellingen, rather than taken from the browser. */
  isChosen: boolean;
  /** The account can keep it (the database has the column). */
  savesToAccount: boolean;
}

const tables = new Map<PaveLanguage, Promise<PaveTranslationTable>>();

async function fetchTable(file: string) {
  try {
    const response = await fetch(`/i18n/${file}.json`);
    return response.ok ? ((await response.json()) as Record<string, string>) : {};
  } catch {
    return {};
  }
}

/** The iOS table and the web's own texts together; the web's own win where both have one. */
export function translationTable(language: PaveLanguage) {
  let table = tables.get(language);
  if (!table) {
    table = Promise.all([fetchTable(language), fetchTable(`web-${language}`)]).then(
      ([fromIos, fromWeb]) => new PaveTranslationTable({ ...fromIos, ...fromWeb }),
    );
    tables.set(language, table);
  }
  return table;
}

export function useLanguage() {
  // A cookie, so the server already writes <html lang> right.
  const cookie = useCookie<string | null>(COOKIE, { default: () => null, maxAge: 365 * 86_400, sameSite: 'lax', secure: !import.meta.dev });
  const state = useState<LanguageState>('pave-language', () => ({
    language: isPaveLanguage(cookie.value) ? cookie.value : 'nl',
    isChosen: isPaveLanguage(cookie.value),
    savesToAccount: false,
  }));
  const problem = useState<string | null>('pave-language-problem', () => null);
  const supabase = useUntypedSupabase();
  const user = useSupabaseUser();

  function keep(language: PaveLanguage) {
    cookie.value = language;
    try {
      localStorage.setItem(COOKIE, language);
    } catch {
      // The cookie keeps it too.
    }
  }

  /** On this browser: the kept choice, otherwise the browser's language. Then the account's, which wins. */
  async function load() {
    if (!import.meta.client) return;
    let kept: string | null = cookie.value;
    try {
      kept = localStorage.getItem(COOKIE) ?? kept;
    } catch {
      // Only the cookie, then.
    }
    state.value = isPaveLanguage(kept)
      ? { ...state.value, language: kept, isChosen: true }
      : { ...state.value, language: browserLanguage(navigator.languages ?? [navigator.language]), isChosen: false };
    if (!user.value?.sub) return;
    const { data, error } = await supabase.from('profiles').select('*').eq('id', user.value.sub).maybeSingle();
    if (error || !data) return;
    const profile = data as Record<string, unknown>;
    const savesToAccount = 'language' in profile;
    state.value = { ...state.value, savesToAccount };
    if (isPaveLanguage(profile.language)) {
      state.value = { ...state.value, language: profile.language, isChosen: true };
      keep(profile.language);
    }
  }

  /** Changes at once; the account follows when it can. */
  async function select(language: PaveLanguage) {
    problem.value = null;
    state.value = { ...state.value, language, isChosen: true };
    keep(language);
    if (!state.value.savesToAccount || !user.value?.sub) return;
    const { error } = await supabase.from('profiles').update({ language }).eq('id', user.value.sub);
    if (error) problem.value = LANGUAGE_SAVE_FAILED;
  }

  return { state, problem, load, select };
}
