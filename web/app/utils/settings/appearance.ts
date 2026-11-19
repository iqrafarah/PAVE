import { buildThemeColours as themeColours } from './themeColours';
export { buildThemeColours as themeColours } from './themeColours';
import { PERSONAL_TEXT_SIZES, PERSONAL_THEMES } from '~/utils/settings/settingsMessages';

export type ThemeId = (typeof PERSONAL_THEMES)[number]['id'] | 'custom';
export type TextSize = (typeof PERSONAL_TEXT_SIZES)[number]['id'];
export type WorkMode = 'ai' | 'traditional';
export type DisplayChoice = 'auto' | 'light' | 'dark';

export function validDisplayChoice(value: unknown): value is DisplayChoice {
  return value === 'auto' || value === 'light' || value === 'dark';
}

export interface Personalisation {
  theme: ThemeId;
  customColor: string | null;
  textSize: TextSize;
  workMode: WorkMode;
  isVaultGrid: boolean;
  displayMode: DisplayChoice;
}

export const APPEARANCE_DEFAULTS: Personalisation = {
  theme: 'green', customColor: null, textSize: 'normal', workMode: 'ai', isVaultGrid: true, displayMode: 'auto',
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
    displayMode: validDisplayChoice(value?.displayMode) ? value.displayMode : 'auto',
  };
}

export function appearanceFromProfile(profile: Record<string, unknown>): Personalisation {
  return normaliseAppearance({
    theme: profile.theme_color as ThemeId,
    customColor: profile.theme_custom_color as string | null,
    textSize: profile.text_size === 'standard' ? 'normal' : profile.text_size as TextSize,
    isVaultGrid: profile.vault_layout !== 'list',
    displayMode: profile.display_mode as DisplayChoice,
  });
}

export function appearanceToProfile(value: Personalisation, supportsCustomColor: boolean, supportsDisplayMode = false) {
  return {
    theme_color: value.theme,
    ...(supportsCustomColor ? { theme_custom_color: value.customColor?.toUpperCase() ?? null } : {}),
    text_size: value.textSize === 'normal' ? 'standard' : value.textSize,
    vault_layout: value.isVaultGrid ? 'grid' : 'list',
    ...(supportsDisplayMode ? { display_mode: value.displayMode } : {}),
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
  const palette = themeColours(isCustom ? settings.customColor! : theme.accent, isCustom ? settings.customColor! : theme.hex);
  const colours = !isCustom && theme.id === 'green'
    ? Object.fromEntries(Object.entries(palette).filter(([name]) => name.startsWith('--dark-')))
    : palette;
  const size = ROOT_TEXT_SIZES[settings.textSize];
  return size ? { ...colours, 'font-size': size } : colours;
}
