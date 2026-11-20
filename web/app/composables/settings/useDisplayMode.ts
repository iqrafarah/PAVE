import type { DisplayChoice } from '~/utils/settings/appearance';
import { validDisplayChoice } from '~/utils/settings/appearance';

export type { DisplayChoice };

const SYSTEM_DARK_QUERY = '(prefers-color-scheme: dark)';

/** The choice on this device. The server reads it too, and it is the account's choice once that has loaded. */
export function useDisplayCookie() {
  return useCookie<string>('pave-display-mode', {
    default: () => 'auto',
    maxAge: 365 * 86_400,
    sameSite: 'lax',
    secure: !import.meta.dev,
  });
}

export function useDisplayMode() {
  const saved = useDisplayCookie();
  const personal = usePersonalisation();
  const mode = computed<DisplayChoice>({
    get: () => validDisplayChoice(saved.value) ? saved.value : 'auto',
    // Also saved to the account, so iOS and every other browser follow.
    set: (value) => { saved.value = value; personal.set({ displayMode: value }); },
  });
  // The server does not know the visitor's system setting, so Auto starts light there and settles once mounted.
  const systemIsDark = useState<boolean | null>('pave-system-dark', () => null);
  const resolved = computed<'light' | 'dark'>(() => {
    if (mode.value !== 'auto') return mode.value;
    return systemIsDark.value ? 'dark' : 'light';
  });
  /** Auto follows the light or dark setting of the device, and changes when that setting changes. */
  function watchSystem() {
    const query = window.matchMedia(SYSTEM_DARK_QUERY);
    const update = () => { systemIsDark.value = query.matches; };
    update();
    query.addEventListener('change', update);
    onScopeDispose(() => query.removeEventListener('change', update));
  }
  return { mode, resolved, watchSystem };
}
