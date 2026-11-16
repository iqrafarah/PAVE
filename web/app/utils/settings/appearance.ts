import { PERSONAL_TEXT_SIZES, PERSONAL_THEMES } from '~/utils/settings/settingsMessages';

export type ThemeId = (typeof PERSONAL_THEMES)[number]['id'] | 'custom';
export type TextSize = (typeof PERSONAL_TEXT_SIZES)[number]['id'];
export type WorkMode = 'ai' | 'traditional';

export interface Personalisation {
  theme: ThemeId;
  customColor: string | null;
  textSize: TextSize;
  workMode: WorkMode;
  isVaultGrid: boolean;
}

export const APPEARANCE_DEFAULTS: Personalisation = {
  theme: 'green', customColor: null, textSize: 'normal', workMode: 'ai', isVaultGrid: true,
};

export function normaliseAppearance(value: Partial<Personalisation> | null): Personalisation {
  const customColor = validCustomColor(value?.customColor) ? value.customColor.toUpperCase() : null;
  const hasValidTheme = PERSONAL_THEMES.some((entry) => entry.id === value?.theme)
    || (value?.theme === 'custom' && customColor !== null);
  return {
    theme: hasValidTheme ? value!.theme! : APPEARANCE_DEFAULTS.theme,
    customColor,
    textSize: PERSONAL_TEXT_SIZES.some((entry) => entry.id === value?.textSize) ? value!.textSize! : APPEARANCE_DEFAULTS.textSize,
    workMode: value?.workMode === 'traditional' ? 'traditional' : 'ai',
    isVaultGrid: typeof value?.isVaultGrid === 'boolean' ? value.isVaultGrid : true,
  };
}

export function appearanceFromProfile(profile: Record<string, unknown>): Personalisation {
  return normaliseAppearance({
    theme: profile.theme_color as ThemeId,
    customColor: profile.theme_custom_color as string | null,
    textSize: profile.text_size === 'standard' ? 'normal' : profile.text_size as TextSize,
    isVaultGrid: profile.vault_layout !== 'list',
  });
}

export function appearanceToProfile(value: Personalisation, supportsCustomColor: boolean) {
  return {
    theme_color: value.theme,
    ...(supportsCustomColor ? { theme_custom_color: value.customColor?.toUpperCase() ?? null } : {}),
    text_size: value.textSize === 'normal' ? 'standard' : value.textSize,
    vault_layout: value.isVaultGrid ? 'grid' : 'list',
  };
}

type Rgb = [number, number, number];

function toRgb(hex: string): Rgb {
  const value = Number.parseInt(hex.slice(1), 16);
  return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
}

function toHex(rgb: Rgb) {
  return `#${rgb.map((channel) => Math.round(channel).toString(16).padStart(2, '0')).join('')}`;
}

function mix(colour: Rgb, other: Rgb, share: number): Rgb {
  return [0, 1, 2].map((index) => colour[index]! * share + other[index]! * (1 - share)) as Rgb;
}

function luminance(rgb: Rgb) {
  const [r, g, b] = rgb.map((channel) => {
    const value = channel / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  }) as Rgb;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * The colours of a theme. The brand colour carries white text on buttons and is text itself on white, so a light
 * colour (gold, lime) is made darker until that is readable (4.5 to 1). The soft colours are the brand colour mixed
 * with white in the same shares as the green ones in main.css.
 */
export function themeColours(hex: string): Record<string, string> {
  const WHITE: Rgb = [255, 255, 255];
  let brand = toRgb(hex);
  while (1.05 / (luminance(brand) + 0.05) < 4.5) brand = brand.map((channel) => Math.floor(channel * 0.97)) as Rgb;
  const soft = (share: number) => toHex(mix(brand, WHITE, share));
  return {
    '--color-brand': toHex(brand),
    '--color-brand-soft': soft(0.28),
    '--color-tint': soft(0.11),
    '--color-badge': soft(0.27),
    '--color-drop': soft(0.045),
    '--color-drop-line': soft(0.33),
    '--color-status-verified-surface': soft(0.07),
    '--color-orb-0': soft(0.07),
    '--color-orb-1': soft(0.17),
    '--color-orb-2': soft(0.33),
    '--color-orb-3': soft(0.58),
    '--color-orb-4': soft(0.8),
    '--color-orb-5': soft(0.95),
    '--color-orb-6': toHex(brand),
  };
}

export function validCustomColor(value: unknown): value is string {
  return typeof value === 'string' && /^#[0-9a-f]{6}$/i.test(value);
}


// rem-based text, icons and controls scale together, as Dynamic Type does in iOS.
export const ROOT_TEXT_SIZES: Record<TextSize, string> = { small: '93.75%', normal: '', large: '112.5%' };

/** What of the look is kept in a cookie, so the server can build the page in the right colour and text size. */
export type KeptLook = Pick<Personalisation, 'theme' | 'customColor' | 'textSize' | 'isVaultGrid'>;

/**
 * The look as style rules for the page itself (the html element): the colours of the theme and the size of the text.
 * PAVE green in the standard size needs nothing, so it gives no rules.
 */
export function appearanceStyle(settings: Pick<Personalisation, 'theme' | 'customColor' | 'textSize'>): Record<string, string> {
  const theme = PERSONAL_THEMES.find((entry) => entry.id === settings.theme) ?? PERSONAL_THEMES[0];
  const isCustom = settings.theme === 'custom' && validCustomColor(settings.customColor);
  const colours = !isCustom && theme.id === 'green' ? {} : themeColours(isCustom ? settings.customColor! : theme.accent);
  const size = ROOT_TEXT_SIZES[settings.textSize];
  return size ? { ...colours, 'font-size': size } : colours;
}
