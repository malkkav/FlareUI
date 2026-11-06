// Fills Settings.NEW in Settings/Registry.lua: every settings row added since the last version line gets
// a NEW tag for this line (3.0 options against the last 2.x tag, 3.1 options against the last 3.0.x tag).
// The list is rewritten whole, so old tags drop off by themselves. Run on each release, after copy2lua.js.
//   node tools/newtags.js
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const git = (cmd) => execSync('git ' + cmd, { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const keysOf = (text) => new Set([...text.matchAll(/^\s+\["([a-z]+\.[A-Za-z0-9_.]+)"\] = \{/gm)].map((m) => m[1]));

const toc = fs.readFileSync(path.join(ROOT, 'FlareUI.toc'), 'utf8');
const version = toc.match(/^## Version: (\S+)/m)[1];
const line = version.split('.').slice(0, 2).join('.');
const inLine = (tag) => tag === line || tag.startsWith(line + '.');

// tags newest first: the first one outside this line, and older than it
const tags = git('tag --sort=-v:refname').split(/\r?\n/).filter((t) => /^\d+\.\d+/.test(t));
const start = tags.findIndex(inLine);
const base = start === -1
  ? tags.find((t) => t.localeCompare(version, undefined, { numeric: true }) < 0)
  : tags.slice(start).find((t) => !inLine(t));
if (!base) throw new Error('no earlier version tag to compare with');

const now = keysOf(fs.readFileSync(path.join(ROOT, 'Settings/Copy.lua'), 'utf8'));
const then = keysOf(git(`show ${base}:Settings/Copy.lua`));
const added = [...now].filter((k) => !then.has(k)).sort();

const file = path.join(ROOT, 'Settings/Registry.lua');
const text = fs.readFileSync(file, 'utf8');
const eol = text.includes('\r\n') ? '\r\n' : '\n';
const table = /Settings\.NEW = \{[\s\S]*?\r?\n\}/;
if (!table.test(text)) throw new Error('Settings.NEW not found');
const body = added.map((k) => `    ["${k}"] = "${line}",`);
fs.writeFileSync(file, text.replace(table, () => ['Settings.NEW = {', ...body, '}'].join(eol)));

console.log(`NEW tags for ${line} (since ${base}): ${added.length}`);
for (const k of added) console.log('  ' + k);
