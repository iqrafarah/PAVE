import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { buildThemeColours } from '../app/utils/settings/themeColours.ts';
import { PERSONAL_THEMES } from '../app/utils/settings/settingsMessages.ts';

function luminance(hex) {
  const channels = hex.slice(1).match(/../g).map(value => parseInt(value, 16) / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}
function contrast(a, b) {
  const values = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (values[0] + 0.05) / (values[1] + 0.05);
}
const css = readFileSync(new URL('../app/assets/css/main.css', import.meta.url), 'utf8');
const dark = css.split(':root[data-display-mode="dark"] {')[1].split('}')[0];
const surfaces = ['canvas', 'sidebar', 'surface', 'panel', 'tile'].map(name => dark.match(new RegExp(`--color-${name}: (#[a-f0-9]{6});`))[1]);
function checkPalette(hex, accent = hex) {
  const palette = buildThemeColours(accent, hex);
  assert.ok(contrast(palette['--color-brand'], '#ffffff') >= 4.5, `${hex}: light button text`);
  assert.ok(contrast(palette['--dark-brand'], '#ffffff') >= 4.5, `${hex}: dark button text`);
  for (const surface of surfaces) {
    assert.ok(contrast(palette['--dark-accent-text'], surface) >= 4.5, `${hex}: accent text on ${surface}`);
    assert.ok(contrast(palette['--dark-brand'], surface) >= 3, `${hex}: filled control on ${surface}`);
  }
  for (const token of ['--dark-tint', '--dark-brand-soft', '--dark-drop', '--dark-badge']) {
    assert.ok(contrast(palette['--dark-accent-text'], palette[token]) >= 4.5, `${hex}: accent text on ${token}`);
  }
}

test('all eight presets have readable light and dark accent variants', () => {
  for (const theme of PERSONAL_THEMES) checkPalette(theme.hex, theme.accent);
});
test('custom colours including black, white, saturated and near-neutral extremes remain readable', () => {
  for (const hex of ['#000000', '#ffffff', '#4b2d2d', '#00ff00', '#ff0000', '#0000ff', '#ffff00', '#00ffff', '#ff00ff']) checkPalette(hex);
  for (let r = 0; r <= 255; r += 51) {
    for (let g = 0; g <= 255; g += 51) {
      for (let b = 0; b <= 255; b += 51) checkPalette(`#${[r, g, b].map(c => c.toString(16).padStart(2, '0')).join('')}`);
    }
  }
});
test('dark variants do not change the existing light theme palette or preset definitions', () => {
  const original = JSON.stringify(PERSONAL_THEMES);
  assert.equal(buildThemeColours('#355D4C')['--color-brand'], '#355d4c');
  for (const theme of PERSONAL_THEMES) {
    const standard = buildThemeColours(theme.accent);
    const withOriginalHue = buildThemeColours(theme.accent, theme.hex);
    for (const key of Object.keys(standard).filter(key => key.startsWith('--color-'))) assert.equal(withOriginalHue[key], standard[key]);
  }
  assert.equal(JSON.stringify(PERSONAL_THEMES), original);
});
