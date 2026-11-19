import type { AylaScreen } from '~/types/ayla';

export const MEMORY_PAGE_PATH = '/ayla/geheugen';

interface ScreenRoute {
  path: string;
  name: string;
}

// Where a screen from Ayla's `navigation` lives on the web. Screens missing here are ignored; the vault, plan and
// profile only work once their page exists (checked against the router before showing the button).
const SCREEN_ROUTES: Partial<Record<AylaScreen, ScreenRoute>> = {
  home: { path: '/', name: 'het startscherm' },
  settings: { path: MEMORY_PAGE_PATH, name: 'instellingen' },
  vault: { path: '/kluis', name: 'je kluis' },
  plans: { path: '/plan', name: 'je plan' },
  profile: { path: '/profiel', name: 'je profiel' },
};

export function getScreenRoute(screen: AylaScreen) {
  return SCREEN_ROUTES[screen] ?? null;
}

/** Whether the web app has a page at this path (the vault, plan and profile pages do not exist yet). */
export function hasPageAt(routes: { path: string }[], path: string) {
  return routes.some((route) => route.path === path);
}

const OPEN_VERBS = /\b(open|opent|ga naar|ga eens naar|breng me naar|neem me mee naar|toon|laat zien)\b/i;
const ASKED_SCREENS: [RegExp, AylaScreen][] = [
  [/\bkluis\b/i, 'vault'],
  [/\b(plan|plannen)\b/i, 'plans'],
  [/\bprofiel\b/i, 'profile'],
];

/** The screen a short "open mijn kluis" / "ga naar mijn plan" asks for, or null when the question is about something else. */
export function screenAskedFor(text: string): AylaScreen | null {
  const asked = text.trim();
  if (asked.length > 60 || !OPEN_VERBS.test(asked)) return null;
  return ASKED_SCREENS.find(([pattern]) => pattern.test(asked))?.[1] ?? null;
}
