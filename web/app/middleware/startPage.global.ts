// "Werkwijze" in the settings: with Traditioneel you start in your vault instead of with Ayla. Only where PAVE opens
// (the address itself, or coming from logging in); the Ayla button in the menu still goes to Ayla.
const OPENING_PATHS = ['/login', '/confirm', '/mfa-verify', '/mfa-complete', '/mfa-setup'];

export default defineNuxtRouteMiddleware((to, from) => {
  if (import.meta.server || to.path !== '/') return;
  const isOpening = from.path === to.path || OPENING_PATHS.includes(from.path);
  if (isOpening && usePersonalisation().state.value.workMode === 'traditional') return navigateTo('/kluis');
});
