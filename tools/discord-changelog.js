// Posts a version's CHANGELOG.md section to the Discord changelog forum as a new post
// (run by .github/workflows/release.yml after the packager, on every version tag).
//   node tools/discord-changelog.js [version]
// version: the tag ("6.2"); defaults to GITHUB_REF_NAME. The section is "# FlareUI <version>" up to
// the next "# FlareUI " heading. Discord caps a message at 2000 characters: the first chunk opens
// the post (titled "FlareUI <version>"), the rest follow as replies in it, split before a "## "
// heading where possible, else between lines.
// Env: DISCORD_CHANGELOG_WEBHOOK (the forum channel's webhook; without it the chunks are only
// printed, a dry run). Forum tags, each optional (a tag's ID; a missing one is just not put on):
//   DISCORD_TAG_MAJOR / _UPDATE / _HOTFIX   X.0 = Major, X.Y = Update; X.Y.Z = Update when its section
//                                           has a "## New" heading (new toggles), else Hotfix (11-14)
//   DISCORD_TAG_RESTART    the section has the "Restart the game fully" line
//   DISCORD_TAG_DEFAULTS   the section has the "Please check your settings" line
'use strict';
const fs = require('fs');
const path = require('path');

const LIMIT = 1900;   // under Discord's 2000, with room for the release link
const version = process.argv[2] || process.env.GITHUB_REF_NAME;
const webhook = process.env.DISCORD_CHANGELOG_WEBHOOK;

// the forum tags this release gets: [name, its ID or undefined]
function Tags(ver, body) {
  const parts = ver.split('.');
  // (11-14, Marcus) small additions now ship as X.Y.Z too: one with a New section is still an Update
  const hasNew = /^## New\b/m.test(body);
  const kind = parts.length >= 3 ? (hasNew ? 'UPDATE' : 'HOTFIX') : (parts.length === 1 || parts[1] === '0') ? 'MAJOR' : 'UPDATE';
  const tags = [kind];
  if (/restart the game fully/i.test(body)) tags.push('RESTART');
  if (/please check your settings/i.test(body)) tags.push('DEFAULTS');
  return tags.map((t) => [t, (process.env['DISCORD_TAG_' + t] || '').trim() || undefined]);
}

function Section(text, ver) {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex((l) => l.trim() === '# FlareUI ' + ver);
  if (start < 0) return null;
  let end = lines.findIndex((l, i) => i > start && l.startsWith('# FlareUI '));
  if (end < 0) end = lines.length;
  return lines.slice(start + 1, end).join('\n').trim();
}

// chunks of at most LIMIT characters: a "## " heading starts a new chunk when the current one is
// already half full, so a section rarely splits from its title
function Split(body) {
  const chunks = [];
  let cur = '';
  const push = () => { if (cur.trim()) chunks.push(cur.trim()); cur = ''; };
  for (let line of body.split('\n')) {
    if (line.startsWith('## ') && cur.length > LIMIT / 2) push();
    while (line.length > LIMIT) {   // one very long line: cut at a space
      push();
      const cut = line.lastIndexOf(' ', LIMIT) > 0 ? line.lastIndexOf(' ', LIMIT) : LIMIT;
      chunks.push(line.slice(0, cut));
      line = line.slice(cut).trimStart();
    }
    if (cur.length + line.length + 1 > LIMIT) push();
    cur += (cur ? '\n' : '') + line;
  }
  push();
  return chunks;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function Post(query, payload) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const res = await fetch(webhook + (webhook.includes('?') ? '&' : '?') + query, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (res.status === 429) {   // rate limited: wait as told
      const info = await res.json().catch(() => ({}));
      await sleep(Math.ceil((info.retry_after || 1) * 1000) + 250);
      continue;
    }
    if (!res.ok) throw new Error('Discord answered ' + res.status + ': ' + (await res.text()));
    return res.json();
  }
  throw new Error('Discord kept rate limiting');
}

async function main() {
  if (!version) throw new Error('No version: pass one or set GITHUB_REF_NAME');
  const file = path.join(__dirname, '..', 'CHANGELOG.md');
  const body = Section(fs.readFileSync(file, 'utf8'), version);
  if (!body) { console.log('No "# FlareUI ' + version + '" section in CHANGELOG.md: nothing posted.'); return; }

  const chunks = Split(body);
  const repo = process.env.GITHUB_REPOSITORY;
  if (repo) {
    const link = '\n\n[Release on GitHub](' + (process.env.GITHUB_SERVER_URL || 'https://github.com') + '/' + repo + '/releases/tag/' + encodeURIComponent(version) + ')';
    if (chunks[chunks.length - 1].length + link.length <= 2000) chunks[chunks.length - 1] += link;
    else chunks.push(link.trim());
  }

  const tags = Tags(version, body);
  console.log('Tags: ' + tags.map(([n, id]) => n + (id ? '' : ' (no ID set)')).join(', '));
  if (!webhook) {
    console.log('DISCORD_CHANGELOG_WEBHOOK not set: dry run, ' + chunks.length + ' message(s).');
    chunks.forEach((c, i) => console.log('\n----- message ' + (i + 1) + ' (' + c.length + ' chars) -----\n' + c));
    return;
  }

  // no pings from the text; no link preview cards (flag 4: suppress embeds)
  const base = { allowed_mentions: { parse: [] }, flags: 4 };
  const first = { ...base, content: chunks[0], thread_name: 'FlareUI ' + version };
  const ids = tags.map(([, id]) => id).filter(Boolean);
  if (ids.length) first.applied_tags = ids;
  const msg = await Post('wait=true', first);
  const thread = msg.channel_id;   // a forum post is a thread; the first message lives in it
  for (const c of chunks.slice(1)) {
    await sleep(600);
    await Post('wait=true&thread_id=' + thread, { ...base, content: c });
  }
  console.log('Posted FlareUI ' + version + ' to Discord in ' + chunks.length + ' message(s).');
}

main().catch((e) => { console.error(e.message); process.exit(1); });
