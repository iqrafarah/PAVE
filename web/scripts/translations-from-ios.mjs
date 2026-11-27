// Copies the translations of the iOS app (ios/PAVE/Resources/Localizable.xcstrings) to the web, so both say the same
// thing in English and Papiamentu. Run it again after the iOS table changes:
//   node scripts/translations-from-ios.mjs
// Writes public/i18n/en.json and public/i18n/pap.json: { "<Dutch text>": "<translation>" }. Keys with %@ hold a value.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = resolve(here, '../../ios/PAVE/Resources/Localizable.xcstrings');
const target = resolve(here, '../public/i18n');
const catalog = JSON.parse(readFileSync(source, 'utf8'));

mkdirSync(target, { recursive: true });
for (const language of ['en', 'pap']) {
  const table = {};
  for (const [key, entry] of Object.entries(catalog.strings)) {
    const value = entry.localizations?.[language]?.stringUnit?.value;
    if (key.trim() && typeof value === 'string' && value !== key) table[key] = value;
  }
  const sorted = Object.fromEntries(Object.entries(table).sort(([a], [b]) => a.localeCompare(b)));
  writeFileSync(resolve(target, `${language}.json`), `${JSON.stringify(sorted, null, 0)}\n`);
  console.log(`${language}: ${Object.keys(sorted).length} texts`);
}
