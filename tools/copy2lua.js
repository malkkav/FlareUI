// Builds Settings/Copy.lua from the panel copy document (Research/FlareUI 2.0/03-copy.md by default):
// every label, description, tip, choice name, section and module text of the settings panel.
// The strings are written as L["..."] so tools/enus.js picks them up for CurseForge.
//   node tools/copy2lua.js [path/to/03-copy.md]
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = process.argv[2] || path.resolve(ROOT, '../Research/FlareUI 2.0/03-copy.md');
const OUT = path.join(ROOT, 'Settings/Copy.lua');

const lines = fs.readFileSync(SRC, 'utf8').split(/\r?\n/);

const copy = { window: {}, modules: {}, sections: {}, rows: {} };
const warnings = [];
let mod = null;          // current module key ("ab")
let section = null;      // current section key ("ab.buttons")
let rows = [];           // rows the current "- Field:" lines apply to
let inWindow = false;

const slug = (s) => s.toLowerCase().replace(/\(.*?\)/g, '').replace(/[^a-z0-9]+/g, ' ').trim()
  .replace(/ (\w)/g, (_, c) => c.toUpperCase());
const strip = (s) => s.replace(/\*\*/g, '').trim();
const keysIn = (s) => [...s.matchAll(/`([a-z][\w.*]*)`/g)].map((m) => m[1]).filter((k) => k.includes('.'));
const choicesIn = (s) => {
  const m = s.match(/\{([^}]*)\}/);
  if (!m || m[1].includes('…')) return null;   // a range ("Bar 1 … Bar 8") is built by the code
  return m[1].split('·').map((c) => c.trim()).filter(Boolean);
};

for (const raw of lines) {
  const line = raw.trimEnd();

  // module: ## Title  `key`   (About and Window have their own handling)
  let m = line.match(/^## (.+?)\s*(?:`(\w+)`)?\s*(\(.*\))?$/);
  if (m && !line.startsWith('###')) {
    inWindow = m[1].trim() === 'Window';
    const key = m[2] || (m[1].startsWith('About') ? 'about' : null);
    const radialTab = m[1].startsWith('Radial Menu: Options');
    if (radialTab) { mod = 'rm'; section = null; rows = []; continue; }
    mod = key;
    section = null;
    rows = [];
    if (key) copy.modules[key] = copy.modules[key] || { title: strip(m[1].replace(/\(.*\)/, '')) };
    continue;
  }
  if (inWindow) {
    // - Name: **text** · button **text**
    m = line.match(/^- ([^:]+):\s*(.+)$/);
    if (m) {
      const parts = [...m[2].matchAll(/\*\*(.+?)\*\*/g)].map((p) => p[1]);
      parts.forEach((p, i) => { copy.window[slug(m[1]) + (i ? String(i + 1) : '')] = p; });
    }
    continue;
  }
  if (!mod) continue;

  m = line.match(/^Module card:\s*(.+)$/);
  if (m) { copy.modules[mod].desc = m[1].trim(); continue; }
  m = line.match(/^Edit Mode button:\s*(.+)$/);
  if (m) { copy.modules[mod].editButton = strip(m[1]); continue; }
  m = line.match(/^Under the frame rows:\s*(.+)$/);
  if (m) { copy.modules[mod].editNote = strip(m[1]); continue; }
  m = line.match(/^Banner:\s*(.+)$/);
  if (m) {
    const parts = [...m[1].matchAll(/\*\*(.+?)\*\*/g)].map((p) => p[1]);
    copy.modules[mod].banner = parts[0]; copy.modules[mod].bannerButton = parts[1];
    continue;
  }
  m = line.match(/^Sub-tab names:\s*(.+)$/);
  if (m) { copy.modules[mod].tabs = [...m[1].matchAll(/\*\*(.+?)\*\*/g)].map((p) => p[1]); continue; }

  // section: #### Section: Name  `key` (chips) | #### Edit Mode ...
  // A note in lower case "(chips)" is for the code; "(FCM)" is part of the name. A `key` keeps a
  // renamed section on the key the code uses.
  m = line.match(/^#### Section:\s*(.+?)\s*(\([a-z].*\))?$/);
  if (m) {
    const own = keysIn(m[1])[0];
    const name = m[1].replace(/`[^`]*`/g, '').trim();
    section = own || mod + '.' + slug(name);
    copy.sections[section] = name;
    rows = [section];                 // a section's own "- Description:" / "- Chips:" lines
    copy.rows[section] = copy.rows[section] || {};
    continue;
  }
  if (line.startsWith('#### ')) { section = null; rows = []; continue; }

  // row: ### Name · Name  `k1` / `k2`  { choices }
  m = line.match(/^### (.+)$/);
  if (m) {
    const keys = keysIn(m[1]);
    if (!keys.length) { warnings.push('row without key: ' + line); rows = []; continue; }
    const head = m[1].split('`')[0].trim();
    const names = head.split('·').map((n) => n.trim());
    const choices = choicesIn(m[1]);
    rows = keys;
    keys.forEach((k, i) => {
      const r = copy.rows[k] = copy.rows[k] || {};
      r.label = names.length === keys.length ? names[i] : head;
      if (choices) r.choices = choices;
      if (/⟳/.test(m[1])) r.reload = true;
      if (/\[ER\]/.test(m[1]) || /\(text block\)/.test(m[1])) r.kind = /\(text block\)/.test(m[1]) ? 'text' : undefined;
      if (section) r.section = section;
    });
    continue;
  }

  // fields of the current row(s)
  // a "- Field: value" line; a sentence that merely contains a colon is a text block's body
  m = line.match(/^- ([^:]+):\s*(.*)$/);
  if (m && !/^(Label|Info title|Description|Tip|Intro|Done message|Empty list|Search words|Chips|Error.*|Note.*)$/.test(m[1].trim())) m = null;
  if (m && rows.length) {
    const field = m[1].trim();
    const value = m[2].trim();
    const map = {
      'Label': 'label', 'Info title': 'info', 'Description': 'desc', 'Tip': 'tip', 'Intro': 'intro',
      'Done message': 'done', 'Empty list': 'empty', 'Search words': 'tags', 'Chips': 'chips',
    };
    let to = map[field];
    if (!to && field.startsWith('Error')) { const e = slug(field.replace(/^Error,?/, '')); to = 'error' + e.charAt(0).toUpperCase() + e.slice(1); }
    if (!to && field.startsWith('Note')) continue;    // notes for the code, not panel text
    if (!to) { if (value) warnings.push(`unknown field "${field}" under ${rows.join(', ')}`); continue; }
    if (!value) continue;
    for (const k of rows) {
      const r = copy.rows[k] = copy.rows[k] || {};
      if (to === 'chips' || to === 'tags') r[to] = value.split(/·|,/).map((c) => c.trim()).filter(Boolean);
      else r[to] = value;
    }
    continue;
  }
  // a text block's body: "- text" right under its heading
  m = line.match(/^- (.+)$/);
  if (m && rows.length === 1 && copy.rows[rows[0]].kind === 'text') {
    copy.rows[rows[0]].text = m[1].trim();
  }
}

// Lua output
// <br> in the copy document is a line break in the game (<br><br> leaves an empty line)
const q = (s) => 'L["' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\s*<br>\s*/gi, '\\n') + '"]';
const plain = (s) => '"' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
const TEXT = new Set(['title', 'info', 'desc', 'label', 'tip', 'intro', 'done', 'empty', 'text', 'editButton', 'editNote', 'banner', 'bannerButton']);
function luaValue(k, v, allText) {
  if (Array.isArray(v)) return '{ ' + v.map((x) => (k === 'tags' ? plain(x.toLowerCase()) : q(x))).join(', ') + ' }';
  if (typeof v === 'boolean') return String(v);
  if (allText || TEXT.has(k) || k.startsWith('error')) return q(v);
  return plain(v);
}
function luaTable(obj, indent, allText) {
  const pad = '    '.repeat(indent);
  const out = [];
  for (const k of Object.keys(obj).sort()) {
    const v = obj[k];
    if (v === undefined) continue;
    if (v && typeof v === 'object' && !Array.isArray(v) && !Object.keys(v).length) continue;
    const key = /^[A-Za-z_]\w*$/.test(k) ? k : '[' + plain(k) + ']';
    if (v && typeof v === 'object' && !Array.isArray(v)) out.push(pad + key + ' = {\n' + luaTable(v, indent + 1, allText || (indent === 1 && (k === 'window' || k === 'sections'))) + '\n' + pad + '},');
    else out.push(pad + key + ' = ' + luaValue(k, v, allText) + ',');
  }
  return out.join('\n');
}

const header = [
  '-- Settings panel copy: every text of the panel, by row key.',
  '-- GENERATED by tools/copy2lua.js from the copy document; do not edit by hand.',
  'local _, ns = ...',
  'local L = ns.L',
  '',
  'ns.Copy = {',
];
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, header.join('\n') + '\n' + luaTable(copy, 1) + '\n}\n');
const n = Object.keys(copy.rows).length;
console.log(`Copy.lua: ${Object.keys(copy.modules).length} modules, ${Object.keys(copy.sections).length} sections, ${n} rows`);
for (const w of warnings) console.log('warning:', w);
