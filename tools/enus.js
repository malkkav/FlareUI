// Locales/enUS.lua rebuilt from every L["..."] in the code (keeps the CurseForge phrase list
// in step with the code). Run after any string change.
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (!['Libs', 'Locales', '.git', 'Media', 'tools'].includes(e.name)) walk(p); }
    else if (p.endsWith('.lua')) files.push(p);
  }
})(ROOT);
// Edit Mode section titles are looked up as L[name] at display (UnitFrames.lua, PartyFrames.lua Section)
const keys = new Set(["Party", "Frame", "Look", "Absorbs", "Auras", "Important Auras", "Cast Bar", "Pets", "Icons"]);
const re = /\bL\["((?:[^"\\]|\\.)*)"\]/g;
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8');
  let m;
  while ((m = re.exec(src))) keys.add(m[1]);
}
const lines = [
  '-- FlareUI phrases, English (the base language). Not loaded by the game: every key is its own',
  "-- English text (Locales/Locale.lua falls back to the key). This list is what CurseForge's",
  '-- localization tool imports; translations come back through the packager into the other files.',
  '-- Generated from every L["..."] in the code (tools/enus.js); do not edit by hand.',
  'local L = {}',
];
for (const k of [...keys].sort((a, b) => a.localeCompare(b))) lines.push('L["' + k + '"] = true');
fs.writeFileSync(path.join(ROOT, 'Locales/enUS.lua'), lines.join('\n') + '\n');
console.log('phrases', keys.size, 'from', files.length, 'files');
