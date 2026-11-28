# Separate local testing addon

Run `node tools/build-testing.js <output-parent>` to produce `FlareUI_Testing/`.
The builder refuses to overwrite an existing destination. Copy the resulting folder
alongside FlareUI in the Forever client's `Interface/AddOns/` directory.

The build uses separate saved variables, addon globals, artwork paths and the custom
FlareEditMode library name. It opens with `/fuitest` or `/flareuitest`; `/rltest` reloads.
Production source files and live saved variables are not modified or imported.
If FlareUI is also loaded, a bootstrap guard stops every subsequent testing Lua chunk.

Fully restart WoW after installation. On a test character, disable FlareUI and enable
FlareUI_Testing in the AddOns list, then open `/fuitest`. Follow the acceptance checklist
in `settings-previews.md`. To return to production, disable FlareUI_Testing and enable
FlareUI again. Blizzard CVars and Edit Mode remain client settings shared with other
addons; separate saved variables do not sandbox changes to those settings.

Initial local installation verification: 163 copied files matched their staged hashes;
all 160 production addon files remained unchanged. The testing TOC validated, all 91
testing Lua files parsed, and all 90 guarded chunks returned without executing when
production was marked loaded. The preview suite passed its 131 setting variants.
In-game rendering, interaction and combat checks still require client testing.

## Revision 5 — native preview follow-up

Installed from `local-testing/revision-5-final/FlareUI_Testing` on 2026-11-10. The prior testing installation is backed up in `local-testing/revision-5/previous-FlareUI_Testing`; the adjacent `install-report.json` records verification. All 163 staged files matched the installed copies; all 160 live FlareUI files retained their hashes. Saved variables and slash commands remain isolated.

Ported contextual player-frame auras, overview pet/target-of-target examples, native portrait fallback, distinct quest XP modes (including unsaved dropdown exploration), minimap drawer/clock-tooltip composition, per-quest native voice/focus icons, resource swing animation and radial selection motion. Existing source-rendered style cards, native gryphons, chat/header controls, bags, and font dropdown previews remain included.

Validation passed: preview harness including the new regression cases, 93 source Lua files parsed, 91 staged Lua files parsed, 90 guarded chunks returned without executing when live FlareUI was marked loaded, TOC references, and whitespace check. Rendering in the game client has not yet been verified. No TOC or file-list changes in this revision; reload the UI with only FlareUI_Testing enabled, then open `/fuitest`.

## Revision 6 — portable animated specimens

Uses bundled transparent preview artwork for the round minimap rim, day/night badge, radial wheel, animated selection wedge/cursor, quest buttons and bag markers. This avoids client-dependent atlas fragments. Map popup backgrounds render above terrain; tooltips fit their sample content. Bags have a framed inventory, row separation, money, stack counts and responsive toggles. Dirty persistent previews re-read the selected value rather than retaining an old dropdown hover. Aura timers animate alongside native cooldowns; arrival overrides are captured before animation callbacks.

Restart WoW completely for the new texture files. Client visual acceptance remains required. The automated preview suite covers stale dropdown state, bag options, overlay layers, and animation cleanup in addition to the existing setting variants.

## Revision 7 — preview lifecycle and failure isolation

Inherited hide notifications now stop animations without clearing cached artwork. They invalidate the containing preview so the next refresh rebuilds it. Rendering failures restore the previous option override, clear the incomplete specimen and return to the illustration without aborting settings-page construction. The original error is still sent to the client error handler. Regression tests cover every specimen kind, nested action artwork, and an injected aura API failure followed by recovery. The exact client-side aura error remains pending in-game error text.

## Revision 8 — Auto aura fonts and tracker palette

Resolved the reported zero-height font exception: the sample now interprets size 0 as Auto using the same icon-size formula as AuraLook.ForUnit, on copies of timer/stack font configuration. All four swipe styles are covered with the actual zero-valued defaults and explicit font sizes. Tracker specimens read shared production colors for gold headers/titles, bronze zones, blue focused quests and gray objectives. Removed the invented progress bar under an ordinary kill-count objective.

## Revision 9 — frame card cleanup

Party, raid, boss and cast specimens use compact foreground borders with inset flat health/power fills. Group layouts are centered within the card canvas; target-of-target and target-of-focus samples are enlarged for legibility. The cast specimen includes a Frostbolt icon and separate name/time labels. Automated geometry checks cover border ordering, fill insets and card bounds; in-game appearance still needs visual verification.
