// tracebuild.js: writes FlareUI's "trace build" for /fui perf trace (PerfTrace.lua).
//   node tools/tracebuild.js [addonsFolder]
// Run it after the normal deploy. Every FlareUI file listed in the TOC is copied into the AddOns folder
// with each hook, script and timer it sets up wrapped and labelled with its file and line:
//   hooksecurefunc(...), X:SecureHook(...), X:HookScript(...), X:SetScript(...)  last argument -> ns.T.W(label, fn)
//   C_Timer.NewTicker(d, fn, ...)                                              fn -> ns.T.W(label, fn)
//   C_Timer.After(d, fn) / C_Timer.NewTimer(d, fn)                             -> ns.T.After(label, d, fn)
// The repo is never changed: a normal deploy (robocopy) puts the plain files back.
// Strings and comments are skipped, so secure snippets in [[ ]] strings are left alone.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const OUT = process.argv[2] || 'C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/FlareUI';
const SKIP = new Set(['LoadCheck.lua', 'PerfTrace.lua', 'Perf.lua']);

// which characters are code (not inside a string or comment)
function codeMask(src) {
  const n = src.length;
  const mask = new Uint8Array(n);
  let i = 0;
  const longLevel = (j) => { // at '[': returns level if [=*[ else -1
    let k = j + 1, lv = 0;
    while (src[k] === '=') { lv++; k++; }
    return src[k] === '[' ? lv : -1;
  };
  const skipLong = (j, lv) => { // j at first '[': returns index after the closing bracket
    const close = ']' + '='.repeat(lv) + ']';
    const e = src.indexOf(close, j + lv + 2);
    return e < 0 ? n : e + close.length;
  };
  while (i < n) {
    const c = src[i];
    if (c === '-' && src[i + 1] === '-') {
      if (src[i + 2] === '[') {
        const lv = longLevel(i + 2);
        if (lv >= 0) { i = skipLong(i + 2, lv); continue; }
      }
      const e = src.indexOf('\n', i);
      i = e < 0 ? n : e;
      continue;
    }
    if (c === '"' || c === "'") {
      let k = i + 1;
      while (k < n && src[k] !== c && src[k] !== '\n') k += src[k] === '\\' ? 2 : 1;
      i = k + 1;
      continue;
    }
    if (c === '[') {
      const lv = longLevel(i);
      if (lv >= 0) { i = skipLong(i, lv); continue; }
    }
    mask[i] = 1;
    i++;
  }
  return mask;
}

const OPEN_BLOCK = new Set(['function', 'if', 'do', 'repeat']);
const CLOSE_BLOCK = new Set(['end', 'until']);

// from the '(' at open: the matching ')' and the top-level commas
function parseCall(src, mask, open) {
  let depth = 0, block = 0;
  const commas = [];
  for (let i = open + 1; i < src.length; i++) {
    if (!mask[i]) continue;
    const c = src[i];
    if (/[A-Za-z_]/.test(c) && !/[\w]/.test(src[i - 1] || '')) {
      const m = /^[A-Za-z_]\w*/.exec(src.slice(i, i + 20));
      const w = m[0];
      if (src[i - 1] !== '.' && src[i - 1] !== ':') {
        if (OPEN_BLOCK.has(w)) block++;
        else if (CLOSE_BLOCK.has(w)) block--;
      }
      i += w.length - 1;
      continue;
    }
    if (c === '(' || c === '[' || c === '{') depth++;
    else if (c === ')' || c === ']' || c === '}') {
      if (depth === 0 && c === ')') return { close: i, commas };
      depth--;
    } else if (c === ',' && depth === 0 && block === 0) commas.push(i);
  }
  return null;
}

function argSpan(src, call, open, index) { // start/end of argument `index` (0-based)
  const starts = [open + 1, ...call.commas.map((c) => c + 1)];
  const ends = [...call.commas, call.close];
  if (index < 0) index = starts.length + index;
  if (index < 0 || index >= starts.length) return null;
  let s = starts[index];
  while (/\s/.test(src[s])) s++;
  return { start: s, end: ends[index], text: src.slice(s, ends[index]).trim() };
}

const strContent = (t) => { const m = /^(["'])(.*)\1$/s.exec(t); return m ? m[2] : null; };
const isIdent = (t) => /^[\w.:]+$/.test(t);
const clean = (t) => t.replace(/["\\\n\r]/g, '').slice(0, 48);

function enclosingName(lines, lineNo) {
  for (let l = lineNo - 1; l >= 0 && l >= lineNo - 400; l--) {
    const s = lines[l];
    let m = /^\s*(?:local\s+)?function\s+([\w.:]+)\s*\(/.exec(s);
    if (m) return m[1];
    m = /^\s*(?:local\s+)?([\w.:\[\]"]+)\s*=\s*function\s*\(/.exec(s);
    if (m) return m[1];
  }
  return 'main';
}

function transform(src, file) {
  const mask = codeMask(src);
  const lineStarts = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === '\n') lineStarts.push(i + 1);
  const lines = src.split('\n');
  const lineOf = (pos) => { let lo = 0, hi = lineStarts.length - 1; while (lo < hi) { const mid = (lo + hi + 1) >> 1; if (lineStarts[mid] <= pos) lo = mid; else hi = mid - 1; } return lo; };
  const edits = [];
  let sites = 0;
  const label = (pos, desc) => JSON.stringify(`${file}:${lineOf(pos) + 1} ${clean(desc)}`.trim());

  const re = /(?<![\w.:])hooksecurefunc\s*\(|:SecureHook\s*\(|:HookScript\s*\(|:SetScript\s*\(|(?<![\w.:])C_Timer\.(?:NewTicker|After|NewTimer)\s*\(/g;
  let m;
  while ((m = re.exec(src))) {
    const at = m.index;
    if (!mask[at]) continue;
    const open = at + m[0].length - 1;
    const call = parseCall(src, mask, open);
    if (!call) { console.warn(`  ${file}:${lineOf(at) + 1} could not read the call, left as is`); continue; }
    const head = m[0].replace(/\s*\($/, '');
    const nargs = call.commas.length + 1;
    if (head === 'C_Timer.After' || head === 'C_Timer.NewTimer') {
      const fn = argSpan(src, call, open, 1);
      const desc = `${head.slice(8)} in ${enclosingName(lines, lineOf(at))}${fn && isIdent(fn.text) ? ' -> ' + fn.text : ''}`;
      edits.push({ pos: at, del: m[0].length, text: `ns.T.${head.slice(8)}(${label(at, desc)}, ` });
      sites++;
      continue;
    }
    if (head === 'C_Timer.NewTicker') {
      const fn = argSpan(src, call, open, 1);
      if (!fn) continue;
      const desc = `Ticker in ${enclosingName(lines, lineOf(at))}${isIdent(fn.text) ? ' -> ' + fn.text : ''}`;
      edits.push({ pos: fn.start, text: `ns.T.W(${label(at, desc)}, ` });
      edits.push({ pos: fn.end, text: ')' });
      sites++;
      continue;
    }
    const last = argSpan(src, call, open, -1);
    if (!last || nargs < 2) continue;
    let desc, isEvent = false;
    if (head === 'hooksecurefunc' || head === ':SecureHook') {
      const a = argSpan(src, call, open, 0), b = nargs >= 3 ? argSpan(src, call, open, 1) : null;
      const name = b ? `${a.text}.${strContent(b.text) ?? b.text}` : (strContent(a.text) ?? a.text);
      desc = `hook ${name}`;
    } else {
      // receiver:HookScript("OnX", fn) or Ace's self:HookScript(frame, "OnX", fn)
      let r = at - 1;
      while (r >= 0 && /[\w.\]\["')]/.test(src[r])) r--;
      const receiver = src.slice(r + 1, at);
      const scriptArg = argSpan(src, call, open, nargs - 2);
      const script = strContent(scriptArg.text) ?? scriptArg.text;
      const target = nargs >= 3 ? argSpan(src, call, open, 0).text : receiver;
      isEvent = script === 'OnEvent';
      desc = `${target} ${script}${head === ':HookScript' ? ' (hook)' : ''}${isIdent(last.text) ? ' -> ' + last.text : ''}`;
    }
    if (last.text === 'nil') continue;
    edits.push({ pos: last.start, text: `ns.T.W(${label(at, desc)}, ` });
    edits.push({ pos: last.end, text: isEvent ? ', true)' : ')' });
    sites++;
  }
  edits.sort((a, b) => b.pos - a.pos);
  let out = src;
  for (const e of edits) out = out.slice(0, e.pos) + e.text + out.slice(e.pos + (e.del || 0));
  return { out, sites };
}

const toc = fs.readFileSync(path.join(ROOT, 'FlareUI.toc'), 'utf8').split(/\r?\n/)
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#') && l.endsWith('.lua'))
  .map((l) => l.replace(/\\/g, '/'))
  .filter((l) => !l.startsWith('Libs/') && !l.startsWith('Locales/') && !SKIP.has(l));
let total = 0;
for (const rel of toc) {
  const src = fs.readFileSync(path.join(ROOT, rel), 'utf8');
  const { out, sites } = transform(src, path.basename(rel));
  total += sites;
  fs.mkdirSync(path.dirname(path.join(OUT, rel)), { recursive: true });
  fs.writeFileSync(path.join(OUT, rel), out);
}
const traceFile = path.join(OUT, 'PerfTrace.lua');
fs.writeFileSync(traceFile, fs.readFileSync(path.join(ROOT, 'PerfTrace.lua'), 'utf8')
  + `\n-- written by tools/tracebuild.js\nns.T.instrumented = true\nns.T.sites = ${total}\n`);
console.log(`trace build: ${toc.length} files, ${total} sites wrapped -> ${OUT}`);
