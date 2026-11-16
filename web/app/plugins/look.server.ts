import type { KeptLook } from '~/utils/settings/appearance';
import { appearanceStyle, normaliseAppearance, themeColours, validCustomColor } from '~/utils/settings/appearance';
import { PERSONAL_THEMES } from '~/utils/settings/settingsMessages';

// Builds the page in your theme colour and text size on the server already, from the cookie the browser keeps, with
// the icon for the browser tab in that colour. Without this the page arrives in PAVE green and only changes once the
// scripts have started: a flash on every refresh.
export default defineNuxtPlugin(() => {
  try {
    const kept = useCookie<Partial<KeptLook> | null>('pave-look').value;
    const look = normaliseAppearance(kept && typeof kept === 'object' ? kept : null);
    const style = Object.entries(appearanceStyle(look))
      .map(([name, value]) => `${name}:${value}`)
      .join(';');
    const theme = PERSONAL_THEMES.find((entry) => entry.id === look.theme) ?? PERSONAL_THEMES[0];
    const colour = look.theme === 'custom' && validCustomColor(look.customColor) ? look.customColor : theme.accent;
    useHead({
      htmlAttrs: style ? { style } : {},
      link: [{ id: THEME_ICON_ID, rel: 'icon', type: 'image/svg+xml', href: themeFaviconHref(themeColours(colour)['--color-brand']!) }],
    });
  } catch {
    // The look is never worth breaking the page for: it then arrives in the standard look.
  }
});
