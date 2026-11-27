// Instellingen › Weergave › Lettertype (iOS PaveFontStyle and PaveFontStore): PAVE's own (Inter with Sora for titles),
// the system's, a rounded one, one with serifs, or Atkinson Hyperlegible, made to be easy to read. Kept in this browser
// only, like "Animaties uitzetten"; a cookie lets the server build the page in it already (plugins/look.server.ts).

export type PaveFontStyle = 'pave' | 'system' | 'rounded' | 'serif' | 'readable';

export const PAVE_FONT_STYLES: PaveFontStyle[] = ['pave', 'system', 'rounded', 'serif', 'readable'];
export const FONT_COOKIE = 'pave-font';

export function isPaveFontStyle(value: unknown): value is PaveFontStyle {
  return PAVE_FONT_STYLES.includes(value as PaveFontStyle);
}

/** The readable typeface comes from Google Fonts, only when it is chosen. */
export const READABLE_FONT_HREF = 'https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&display=swap';

export function useFontStyle() {
  const cookie = useCookie<string | null>(FONT_COOKIE, { default: () => null, maxAge: 365 * 86_400, sameSite: 'lax', secure: !import.meta.dev });
  const style = computed<PaveFontStyle>({
    get: () => (isPaveFontStyle(cookie.value) ? cookie.value : 'pave'),
    set: (value) => {
      cookie.value = value === 'pave' ? null : value;
    },
  });

  // On the page at once, the readable typeface loaded when needed.
  useHead(() => ({
    htmlAttrs: { 'data-font': style.value === 'pave' ? undefined : style.value },
    link: style.value === 'readable' ? [{ key: 'pave-readable-font', rel: 'stylesheet', href: READABLE_FONT_HREF }] : [],
  }));

  return { style };
}
