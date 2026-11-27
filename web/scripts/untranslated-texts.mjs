// Lists the Dutch texts of the web (app/utils/**/*Messages.ts) that neither the iOS table (public/i18n/en.json) nor
// the web's own table (public/i18n/web-en.json) translates yet, so they can be added to public/i18n/web-*.json.
// Texts with a value become keys with %@, as in the iOS table:
//   node scripts/untranslated-texts.mjs > untranslated.json
import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => (existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {});
const known = { ...read(join(root, 'public/i18n/en.json')), ...read(join(root, 'public/i18n/web-en.json')) };

const files = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full);
    else if (/[mM]essages\.ts$/.test(name)) files.push(full);
  }
})(join(root, 'app/utils'));

const found = new Set();
for (const file of files) {
  const text = readFileSync(file, 'utf8');
  for (const match of text.matchAll(/'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)"|`((?:[^`\\]|\\.)*)`/g)) {
    const raw = match[1] ?? match[2] ?? match[3];
    const value = raw
      .replace(/\$\{[^}]*\}/g, '%@')
      .replace(/\\'/g, "'")
      .replace(/\\n/g, '\n');
    if (!/\p{L}{3}/u.test(value) || /^[a-z0-9_\-/.~#:]+$/i.test(value.replaceAll('%@', '')) || value.startsWith('~/')) continue;
    if (/^[a-z-]+(\s[a-z-]+)*$/.test(value) && !/[aeiou]{1}[a-z]*\s/.test(value)) continue;
    if (known[value]) continue;
    found.add(value);
  }
}
process.stdout.write(`${JSON.stringify([...found].sort(), null, 1)}\n`);
