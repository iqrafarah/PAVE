import type { RouteLocationNormalizedLoaded, RouteLocationRaw } from 'vue-router';

export function isOnVault(route: RouteLocationNormalizedLoaded) {
  return route.path.startsWith('/kluis');
}

/**
 * Where a new chat starts: on the vault it stays on the vault, with what else is open there (a folder) but without the
 * chat (?chat=); everywhere else on the start screen.
 */
export function newChatPath(route: RouteLocationNormalizedLoaded): RouteLocationRaw {
  if (!isOnVault(route)) return '/';
  const query = { ...route.query };
  delete query.chat;
  return { path: route.path, query };
}
