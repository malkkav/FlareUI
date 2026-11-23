# Contributing to FlareUI

Thanks for wanting to help! These notes are here so your time goes into work that gets merged.

## What FlareUI is, and what it isn't

FlareUI is **Blizzard's UI for WoW: Forever, made cleaner and more efficient**. It is not a catch-all UI replacement that tries to do everything.

- **It should still feel like Blizzard's UI.** Same art, same look and feel, the same places for things. A player who switches FlareUI off should feel at home in the default UI, and the other way round.
- **Better, not bigger.** We'd rather make what Blizzard already shows clearer, faster and easier to read than add new things to the screen.
- **Fewer options beat more options.** Every option has to earn its place. When a change brings the UI closer to Blizzard's, it ships as the default, with no switch.
- **Other addons are welcome alongside it.** If an addon already does something well, FlareUI works with it instead of copying it.

If an idea makes FlareUI look less like Blizzard's UI, or turns it into a toolbox of extra features, it doesn't belong in the main addon, however good it is.

## 1. Propose first, build second

Before you build a feature, post the idea in Discord's **#feature-request** forum or open a GitHub issue, and wait for Malkkav's answer. If it's out of scope or feature creep, you'll hear it right away, before you spend a weekend on it.

You don't need to ask first for:
- bug fixes
- translations
- small cleanups in code you're already fixing

## 2. What fits FlareUI

A good fit:
- It improves something Blizzard already shows, and it keeps Blizzard's look and feel.
- It makes the UI cleaner or quicker to use, not busier.
- Many players would use it, not just one class, one build or one playstyle.
- It works everywhere: in combat, in instances, on other players. A feature that only works half the time isn't a feature.
- It's light on performance.

Examples that fit:
- Bug fixes, and fixes for compatibility with other addons
- Translations
- Better readability (clearer text, sharper borders, honest tooltips)
- Options that change how an existing FlareUI frame works

Examples that don't fit:
- New looks that move away from Blizzard's art and style.
- Whole new systems Blizzard's UI doesn't have, just because other UI packs have them.
- Things another addon already does well (DoT timers, boss mods, full damage meters). Instead, we make FlareUI work alongside that addon.
- Pure looks with no other use (custom text colours, extra border styles).
- Ideas made by another addon's author, unless that author agreed in writing.
- Features that can't work in combat because the game blocks them.

Not sure? Ask in Discord. A quick "would this fit?" saves everyone time.

## 3. Avoid doubling up

Malkkav fixes bugs fast, so check first:
- **Before you start**, comment on the bug post or issue ("I'm on this"). Then nobody else starts on it.
- Look at the open pull requests on GitHub, so you don't build the same thing twice.
- If someone said they're on it but went quiet for a few days, ask in the thread before taking it over.

## 4. Pull requests

- One fix or one feature per pull request. Don't reformat or rename code you weren't asked to touch.
- In the description, say what you changed, why, and how you tested it in game. If you couldn't test it, say so.
- Don't bump the version or edit `CHANGELOG.md`. Malkkav does both at release time.
- Run the tests before you open it (GitHub runs them too):
  ```bash
  for t in tools/tests/*.lua; do [ "$t" = tools/tests/perf-helpers.lua ] || luajit "$t" || echo "FAILED: $t"; done
  ```

### Lua line coverage

To reproduce the CI coverage report, install LuaCov 0.17.0 and LuaFileSystem 1.8.0
for LuaJIT. Move aside any existing `luacov.stats.out` before running the suite
from the repository root so the report measures a fresh run.

```bash
(
  set -e
  export LUACOV_CONFIG=tools/.luacov
  for test in tools/tests/*.lua; do
    if [ "$test" = tools/tests/perf-helpers.lua ]; then
      continue
    fi
    luajit -joff -lluacov "$test"
  done
  luacov
  awk '/^Total / { print }' luacov.report.out
)
```

Use `loadfile` when testing a complete addon file so LuaCov can attribute hits
to the source. The coverage total includes untested files in the CI scope.
WoW client doubles exercise addon logic offline. Combat lockdown, taint, and
rendering still need an in-game check.

## 5. House rules for code and options

The full list is in [AGENTS.md](AGENTS.md). It applies to people and AI tools alike. The short version:
- **Blizzard first.** Use Blizzard's own art, fonts and widgets. When in doubt, do it the way Blizzard's UI does.
- New options start **off**. Turning an option off never forces a Blizzard setting.
- In dropdowns, **Off** or **None** comes first. Labels are short and in Title Case.
- Don't indent an option under another one. Rework the options instead.
- Player-facing text goes through `L["..."]`. Panel text belongs in `Settings/Copy.lua`: list your new strings in the PR and Malkkav moves them into his copy document.
- Lua 5.1, at most 200 locals per file, and respect secret values and combat lockdown.
- Only use code from other addons if their licence allows it, and add that licence to `LICENSES/`.

## 6. Ideas that don't fit the main addon

Build them as a separate plugin. You can publish a plugin without asking permission. The one exception: a plugin that copies another addon author's own idea without their written OK. We'll ask for that plugin to be taken down.

## 7. Translations

Every phrase is in `Locales/enUS.lua`. Copy the ones you need into your language's file in the same format, `L["English"] = "Translation"`, and open a pull request. Not into GitHub? Post the file in Discord and we'll add it and credit you.
