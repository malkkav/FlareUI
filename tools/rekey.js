// Carries translations over when an English phrase is renamed: each locale line keyed by an old
// phrase moves to the new phrase, unless the new phrase already has a line there (then the old line
// goes). Only for renames that keep the meaning (case, wording); a changed meaning stays
// untranslated for the translators.
//   node tools/rekey.js <map.json>      map: { "old phrase": "new phrase", ... }
const fs = require('fs');
const path = require('path');
const map = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const dir = path.resolve(__dirname, '../Locales');
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
for (const file of fs.readdirSync(dir)) {
  if (!file.endsWith('.lua') || file === 'enUS.lua' || file === 'Locale.lua') continue;
  const p = path.join(dir, file);
  const nl = fs.readFileSync(p, 'utf8').includes('\r\n') ? '\r\n' : '\n';
  let lines = fs.readFileSync(p, 'utf8').split(nl);
  let moved = 0, dropped = 0;
  for (const [from, to] of Object.entries(map)) {
    const oldKey = 'L["' + esc(from) + '"] = ';
    const newKey = 'L["' + esc(to) + '"] = ';
    if (!lines.some((l) => l.startsWith(oldKey))) continue;
    if (lines.some((l) => l.startsWith(newKey))) {
      lines = lines.filter((l) => !l.startsWith(oldKey));
      dropped++;
    } else {
      lines = lines.map((l) => (l.startsWith(oldKey) ? newKey + l.slice(oldKey.length) : l));
      moved++;
    }
  }
  fs.writeFileSync(p, lines.join(nl));
  if (moved || dropped) console.log(file + ': ' + moved + ' moved, ' + dropped + ' dropped (new key already translated)');
}
