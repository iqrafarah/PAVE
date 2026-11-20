import type { DisplayChoice, KeptLook, Personalisation } from '~/utils/settings/appearance';
import { APPEARANCE_DEFAULTS, appearanceFromProfile, normaliseAppearance, themeColours, validCustomColor } from '~/utils/settings/appearance';
import { PERSONAL_THEMES } from '~/utils/settings/settingsMessages';

const STORAGE_KEY = 'pave-personalisation';
const VAULT_GRID_KEY = 'pave-vault-grid';
// rem-based text, icons and controls scale together, as Dynamic Type does in iOS.
const ROOT_SIZES = { small: '93.75%', normal: '', large: '112.5%' };

function apply(settings: Personalisation) {
  if (!import.meta.client) return;
  const root = document.documentElement;
  const theme = PERSONAL_THEMES.find((entry) => entry.id === settings.theme) ?? PERSONAL_THEMES[0];
  const isCustom = settings.theme === 'custom' && validCustomColor(settings.customColor);
  const color = isCustom ? settings.customColor! : theme.hex;
  // Green is what main.css says, so it needs nothing on top.
  for (const [name, value] of Object.entries(themeColours(isCustom ? color : theme.accent, color))) {
    if (!isCustom && theme.id === 'green' && !name.startsWith('--dark-')) root.style.removeProperty(name);
    else root.style.setProperty(name, value);
  }
  root.style.fontSize = ROOT_SIZES[settings.textSize];
  if (settings.reduceMotion) root.dataset.reduceMotion = 'true';
  else delete root.dataset.reduceMotion;
  // The icon in the browser tab follows along, PAVE green included: the same icon in every colour, and going back to
  // green shows at once (a browser only looks for the site's own icon again after a reload).
  setThemeFavicon(themeColours(isCustom ? color : theme.accent)['--color-brand']!);
}

export function usePersonalisation() {
  // The same look in a cookie, so the server builds the page in the right colour and size (plugins/look.server.ts).
  const keptLook = useCookie<KeptLook | null>('pave-look', { default: () => null, maxAge: 365 * 86_400, sameSite: 'lax', secure: !import.meta.dev });

  function keepLook() {
    const { theme, customColor, textSize, isVaultGrid, reduceMotion } = state.value;
    const kept = keptLook.value;
    if (kept?.theme !== theme || kept?.customColor !== customColor || kept?.textSize !== textSize || kept?.isVaultGrid !== isVaultGrid || kept?.reduceMotion !== reduceMotion) {
      keptLook.value = { theme, customColor, textSize, isVaultGrid, reduceMotion };
    }
  }

  // Starts from the kept look, on the server too, so the page and its choices are right from the first moment.
  const displayCookie = useDisplayCookie();
  const state = useState<Personalisation>('pave-personalisation', () =>
    normaliseAppearance({ ...(keptLook.value && typeof keptLook.value === 'object' ? keptLook.value : {}), displayMode: displayCookie.value as DisplayChoice }),
  );
  const hasLoaded = useState('pave-appearance-loaded', () => false);
  const storageProblem = useState<string | null>('pave-appearance-storage-problem', () => null);
  const account = useAppearanceAccount(state, restoreProfile);
  function store() {
    try {
      const { isVaultGrid, ...rest } = state.value;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(rest));
      localStorage.setItem(VAULT_GRID_KEY, isVaultGrid ? 'grid' : 'list');
      keepLook();
      storageProblem.value = null;
    } catch {
      storageProblem.value = PERSONAL_STORAGE_FAILED;
    }
  }

  function load() {
    if (hasLoaded.value) return;
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}') as Partial<Personalisation> | null;
      state.value = normaliseAppearance({ ...saved, isVaultGrid: localStorage.getItem(VAULT_GRID_KEY) !== 'list', displayMode: displayCookie.value as DisplayChoice });
    } catch {
      state.value = { ...APPEARANCE_DEFAULTS, displayMode: normaliseAppearance({ displayMode: displayCookie.value as DisplayChoice }).displayMode };
    }
    hasLoaded.value = true;
    apply(state.value);
    keepLook();
  }

  function restoreProfile(profile: Record<string, unknown>) {
    const fromAccount = appearanceFromProfile(profile);
    // An account from before the display mode existed keeps the choice made on this device.
    const displayMode = 'display_mode' in profile ? fromAccount.displayMode : state.value.displayMode;
    state.value = { ...fromAccount, displayMode, workMode: state.value.workMode, reduceMotion: state.value.reduceMotion };
    displayCookie.value = displayMode;
    apply(state.value);
    store();
  }

  function set(change: Partial<Personalisation>, options: { save?: boolean } = {}) {
    if (change.customColor !== undefined && change.customColor !== null && !validCustomColor(change.customColor)) return;
    const next = { ...state.value, ...change };
    if (next.theme === 'custom' && !validCustomColor(next.customColor)) return;
    state.value = normaliseAppearance(next);
    displayCookie.value = state.value.displayMode;
    apply(state.value);
    store();
    account.changed();
    if (options.save !== false) void account.saveAccount();
  }

  return { state, load, set, storageProblem, ...account };
}
