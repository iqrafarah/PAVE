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

function toHsl([r, g, b]: Rgb): [number, number, number] {
  const [x, y, z] = [r / 255, g / 255, b / 255];
  const max = Math.max(x, y, z);
  const min = Math.min(x, y, z);
  const l = (max + min) / 2;
  const d = max - min;
  if (d === 0) return [0, 0, l];
  const s = d / (1 - Math.abs(2 * l - 1));
  const h = max === x ? ((y - z) / d + 6) % 6 : max === y ? (z - x) / d + 2 : (x - y) / d + 4;
  return [h * 60, s, l];
}

function fromHsl(h: number, s: number, l: number): Rgb {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    return l - (c / 2) * Math.max(-1, Math.min(k - 3, 9 - k, 1));
  };
  return [f(0) * 255, f(8) * 255, f(4) * 255];
}

/**
 * The colours of a theme. The brand colour carries white text on buttons and is text itself on white, so a light
 * colour (gold, lime) is made darker until that is readable (4.5 to 1). The soft colours are the brand colour mixed
 * with white in the same shares as the green ones in main.css.
 */
export function buildThemeColours(hex: string, originalHex = hex): Record<string, string> {
  const WHITE: Rgb = [255, 255, 255];
  let brand = toRgb(hex);
  while (1.05 / (luminance(brand) + 0.05) < 4.5) brand = brand.map((channel) => Math.floor(channel * 0.97)) as Rgb;
  const soft = (share: number) => toHex(mix(brand, WHITE, share));
  return {
    ...darkThemeColours(originalHex),
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

/** Derived display colours only: the selected preset/custom hex is never changed. */
export function darkThemeColours(hex: string): Record<string, string> {
  const original = toRgb(hex);
  const white: Rgb = [255, 255, 255];
  const panel: Rgb = [18, 18, 18];
  const raised: Rgb = [31, 31, 31];
  const contrast = (a: Rgb, b: Rgb) => (Math.max(luminance(a), luminance(b)) + 0.05) / (Math.min(luminance(a), luminance(b)) + 0.05);
  const rounded = (value: Rgb) => value.map(Math.round) as Rgb;
  // On black a muted colour looks dull, so coloured themes get a livelier version; greys stay grey.
  const [hue, saturation] = toHsl(original);
  const vividSaturation = saturation > 0.12 ? Math.min(0.85, Math.max(0.5, saturation * 1.25)) : saturation;
  const shade = (lightness: number) => rounded(fromHsl(hue, vividSaturation, lightness));
  const vivid = saturation > 0.12 ? shade(0.5) : original;
  // Accent text is also used on tinted selections, so leave extra contrast headroom.
  let text = saturation > 0.12 ? shade(0.7) : original;
  for (let step = 0; contrast(text, raised) < 7 && step <= 100; step++) {
    text = rounded(mix(saturation > 0.12 ? shade(0.7) : original, white, 1 - step / 100));
  }
  // Filled controls keep white labels: the lightest, liveliest shade that still carries them.
  let fill = original;
  if (saturation > 0.12) {
    // Prefer a shade that carries white text and still stands out from the black surfaces; else the white label wins.
    let readable: Rgb | undefined;
    fill = shade(0.05);
    for (let lightness = 0.7; lightness > 0.05; lightness -= 0.01) {
      const candidate = shade(lightness);
      if (contrast(candidate, white) < 4.6) continue;
      readable ??= candidate;
      if (contrast(candidate, raised) >= 3) { fill = candidate; break; }
    }
    if (contrast(fill, white) < 4.6 || contrast(fill, raised) < 3) fill = readable ?? fill;
  } else if (contrast(fill, white) < 4.6) {
    for (let step = 0; contrast(fill, white) < 4.6 && step <= 100; step++) {
      fill = rounded(mix(original, [0, 0, 0], 1 - step / 100));
    }
  } else if (contrast(fill, raised) < 3) {
    for (let step = 0; contrast(fill, raised) < 3 && step <= 100; step++) {
      fill = rounded(mix(original, white, 1 - step / 100));
    }
  }
  // Tinted surfaces are deep, clean shades of the hue itself (not the colour mixed into grey, which turns muddy).
  const surface = (lightness: number) => toHex(saturation > 0.12 ? rounded(fromHsl(hue, Math.min(0.24, saturation), lightness)) : mix(original, panel, lightness / 0.5 > 1 ? 1 : lightness / 0.5 * 0.2));
  return {
    '--dark-brand': toHex(fill),
    '--dark-accent-text': toHex(text),
    '--dark-brand-soft': surface(0.2),
    '--dark-tint': surface(0.135),
    '--dark-badge': surface(0.18),
    '--dark-drop': surface(0.1),
    '--dark-drop-line': toHex(text),
    '--dark-verified-surface': surface(0.115),
  };
}
