// How PAVE looks and works for you (Figma FEDDIES 1393:5359): the theme colour, the size of the text and the way of
// working. Like the settings on the iPhone these belong to the device, so they are kept in this browser. The view of
// the vault (list or grid) is the vault's own setting and is read and written under its own key.

// Named here and not left to the automatic imports: the plugin that puts the theme on the page runs before anything
// else, on every page.
import { PERSONAL_TEXT_SIZES, PERSONAL_THEMES } from '~/utils/settingsMessages';

export type ThemeId = (typeof PERSONAL_THEMES)[number]['id'];
export type TextSize = (typeof PERSONAL_TEXT_SIZES)[number]['id'];
export type WorkMode = 'ai' | 'traditional';

interface Personalisation {
  theme: ThemeId;
  textSize: TextSize;
  workMode: WorkMode;
  isVaultGrid: boolean;
}

const STORAGE_KEY = 'pave-personalisation';
const VAULT_GRID_KEY = 'pave-vault-grid';
const DEFAULTS: Personalisation = { theme: 'green', textSize: 'normal', workMode: 'ai', isVaultGrid: true };
// The whole app is sized in rem, so the size of the root letter scales everything along.
const ROOT_SIZES: Record<TextSize, string> = { small: '93.75%', normal: '', large: '112.5%' };

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
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  }) as Rgb;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * The colours of a theme. The brand colour carries white text on buttons and is text itself on white, so a light
 * colour (gold, lime) is made darker until that is readable (4.5 to 1). The soft colours are the brand colour mixed
 * with white in the same shares as the green ones in main.css.
 */
function themeColours(hex: string): Record<string, string> {
  const WHITE: Rgb = [255, 255, 255];
  let brand = toRgb(hex);
  while (1.05 / (luminance(brand) + 0.05) < 4.5) brand = mix(brand, [0, 0, 0], 0.95);
  const soft = (share: number) => toHex(mix(brand, WHITE, share));
  return {
    '--color-brand': toHex(brand),
    '--color-brand-soft': soft(0.28),
    '--color-tint': soft(0.11),
    '--color-badge': soft(0.27),
    '--color-drop': soft(0.05),
    '--color-drop-line': soft(0.33),
    '--color-orb-0': soft(0.08),
    '--color-orb-1': soft(0.18),
    '--color-orb-2': soft(0.35),
    '--color-orb-3': soft(0.58),
    '--color-orb-4': soft(0.8),
    '--color-orb-5': soft(0.95),
    '--color-orb-6': toHex(brand),
  };
}

function apply(settings: Personalisation) {
  if (!import.meta.client) return;
  const root = document.documentElement;
  const theme = PERSONAL_THEMES.find((entry) => entry.id === settings.theme) ?? PERSONAL_THEMES[0];
  // Green is what main.css says, so it needs nothing on top.
  for (const [name, value] of Object.entries(themeColours(theme.hex))) {
    if (theme.id === 'green') root.style.removeProperty(name);
    else root.style.setProperty(name, value);
  }
  root.style.fontSize = ROOT_SIZES[settings.textSize];
}

export function usePersonalisation() {
  const state = useState<Personalisation>('pave-personalisation', () => ({ ...DEFAULTS }));

  /** Reads what this browser remembers and puts it on the page. */
  function load() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}') as Partial<Personalisation>;
      state.value = {
        theme: PERSONAL_THEMES.some((entry) => entry.id === saved.theme) ? saved.theme! : DEFAULTS.theme,
        textSize: PERSONAL_TEXT_SIZES.some((entry) => entry.id === saved.textSize) ? saved.textSize! : DEFAULTS.textSize,
        workMode: saved.workMode === 'traditional' ? 'traditional' : 'ai',
        isVaultGrid: localStorage.getItem(VAULT_GRID_KEY) !== 'list',
      };
    } catch {
      // Storage is blocked or holds something else: the standard look stays.
    }
    apply(state.value);
  }

  function set(change: Partial<Personalisation>) {
    state.value = { ...state.value, ...change };
    apply(state.value);
    try {
      const { isVaultGrid, ...rest } = state.value;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(rest));
      localStorage.setItem(VAULT_GRID_KEY, isVaultGrid ? 'grid' : 'list');
    } catch {
      // Storage is blocked: the choice works until the page is closed.
    }
  }

  return { state, load, set };
}
