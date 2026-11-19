import type { DisplayChoice } from '~/utils/settings/appearance';
import { validDisplayChoice } from '~/utils/settings/appearance';

export type { DisplayChoice };

/** Auto follows the time of day on this device: dark in the evening and at night. */
const DARK_FROM_HOUR = 19;
const DARK_UNTIL_HOUR = 7;

export function isNightHour(hour: number) {
  return hour >= DARK_FROM_HOUR || hour < DARK_UNTIL_HOUR;
}

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
  // The server does not know the visitor's local time, so Auto starts light there and settles once mounted.
  const hour = useState<number | null>('pave-display-hour', () => null);
  const resolved = computed<'light' | 'dark'>(() => {
    if (mode.value !== 'auto') return mode.value;
    return hour.value !== null && isNightHour(hour.value) ? 'dark' : 'light';
  });
  function startClock() {
    const tick = () => { hour.value = new Date().getHours(); };
    tick();
    const timer = setInterval(tick, 60_000);
    onScopeDispose(() => clearInterval(timer));
  }
  return { mode, resolved, startClock };
}
