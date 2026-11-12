import logoFile from '~~/public/images/ayla/logo-mark.svg?raw';

// The icon in the browser tab in the theme colour: the PAVE logo in white on a rounded square of that colour. It is
// made for every colour, PAVE green too, so the icon looks the same whichever colour is chosen. The logo is read into
// the code when the site is built, so the server can put the icon in the page as it arrives (plugins/look.server.ts)
// and the browser changes it without fetching anything.

export const THEME_ICON_ID = 'pave-theme-icon';

// The shapes of the PAVE logo, made white.
const LOGO_SHAPES = logoFile.match(/<svg[^>]*>([\s\S]*)<\/svg>/)?.[1]?.replace(/fill="#[0-9a-f]{3,8}"/gi, 'fill="#fff"') ?? '';

/** The icon as a link the browser can show straight away. The logo is 42 by 22 and sits in a 64 by 64 square. */
export function themeFaviconHref(colour: string) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="${colour}"/><svg x="8" y="19.4" width="48" height="25.1" viewBox="0 0 42 22" fill="none">${LOGO_SHAPES}</svg></svg>`;
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}

export function setThemeFavicon(colour: string) {
  if (!import.meta.client) return;
  const existing = document.getElementById(THEME_ICON_ID) as HTMLLinkElement | null;
  const link = existing ?? document.createElement('link');
  link.id = THEME_ICON_ID;
  link.rel = 'icon';
  link.type = 'image/svg+xml';
  link.href = themeFaviconHref(colour);
  // Last in the head, so it wins over the icon that comes with the site.
  if (!existing) document.head.appendChild(link);
}
