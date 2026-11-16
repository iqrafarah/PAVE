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
