# Notes for AI coding agents

These rules apply to any change to FlareUI, whether a person or an AI tool writes it. Read them before you write code and before you open a pull request.

## What FlareUI is

- A World of Warcraft addon for **WoW: Forever** only (`## Interface: 16001`). Forever is not Retail and not Classic: its API and Blizzard UI code differ from both.
- FlareUI improves Blizzard's own interface without replacing its look. It is split into modules that players switch on one by one.

## Keep pull requests small

- One fix or one feature per pull request. Don't reformat, rename or "clean up" code you weren't asked to touch.
- Explain in the PR what you changed, why, and how you tested it in game (or say that you couldn't).
- Don't bump `## Version` or edit `CHANGELOG.md`. The maintainer does both at release time.

## Use the real API

- Only call functions that exist in Forever. If you aren't sure, check Blizzard's own Forever UI code (export it with the client's `exportInterfaceFiles code` console command). Don't guess from Retail or Classic documentation.
- Many values are **secret** in combat (aura data, health, some sizes). Addon code can't compare, do maths on, or branch on them. Pass them to Blizzard's widgets as they are. Never anchor a frame to a texture whose size may be secret.
- Respect taint and combat lockdown: don't touch protected frames in combat (`InCombatLockdown()`), and prefer `hooksecurefunc` to replacing Blizzard functions.
- Store per-character data by GUID (`ns.CharDB()`), not by name: in Forever `UnitName` returns only the first name.

## Options and text

- New options start **off**, unless the maintainer says otherwise. Switching an option off must not force a Blizzard setting either way.
- When you change an option that has a preview, check it against what players see in game. If it is out of date, update it when possible. For a new option, add a preview when its effect can be shown accurately in the settings panel.
- Labels are short and in Title Case. Don't indent a row under another to show it depends on it; rework the options instead.
- Panel text lives in `Settings/Copy.lua`, which is generated from the maintainer's copy document. Add new strings there and list them in your PR; the maintainer moves them into the document.
- Every player-facing string goes through `L["..."]`. After changing strings, run `node tools/enus.js`. Don't edit the other languages unless you speak them.

## Code limits

- WoW runs **Lua 5.1**: no `goto`, no `//` integer division, no 5.3+ bit operators.
- A file's main chunk can hold at most **200 locals**. Big files sit close to that limit: group new constants into an existing table instead of adding new top-level locals.
- Don't copy code from other addons unless its licence allows it, and add the licence to `LICENSES/`. Many popular addons are "all rights reserved".

## Tests

Run every test before you open a pull request (GitHub Actions runs them too):

```bash
for t in tools/tests/*.lua; do [ "$t" = tools/tests/perf-helpers.lua ] || luajit "$t" || echo "FAILED: $t"; done
```

- `tools/tests/syntax.lua` loads every Lua file, so it catches syntax errors and the 200-locals limit.
- Prefer small, focused tests. Give each test case one clearly named behavior or scenario and use only the setup and assertions needed to verify it. Related assertions can stay together when they describe the same outcome. Keep unrelated cases independently runnable, even if they share a file or fixture. Use broader integration tests when the interaction itself is what needs coverage.
- When you fix a bug that can be reproduced outside the game, add a small test for it in `tools/tests/`, using the mock helpers in `perf-helpers.lua`.
- Do not extract and execute fragments of production Lua in tests. Tests must not depend on declaration order, nearby comments, spacing, line endings, or other source-text markers. Load the actual module with WoW API doubles and exercise its normal entry points. If logic needs isolation, load a small real module as a whole. Apply this rule to new tests and migrate existing source-slicing tests when changing them.
- Secret values, taint and Blizzard's locked frames can't be tested outside the game. Say in the PR that it needs an in-game test.
