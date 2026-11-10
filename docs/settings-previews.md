# Settings previews

Unit Frames and Minimap use compact style cards. Hovering or focusing a card only changes the
Info Panel; clicking uses the same settings setter and pending-reload footer as the old stepper.
Leaving a card returns the preview to the selected style. No generated artwork is shipped.

Other visual options use one sample canvas above their existing description. Behaviour-only
options retain the section's last specimen while updating the help text. Dropdown options preview
on hover and restore the saved value on leave/close; only selection writes settings. Font menu
labels use their actual font face. Sample data does not read units, items, combat values or chat.
The radial editor keeps its existing live preview; the Options tab has a separate sample.
Unit Frames > Frames contains seven clickable enable/disable cards with independent Edit buttons.
Their diagrams remain visible without hover. Action Bars keeps bars and XP in a single composition;
ordinary hover updates help text without redrawing the specimen or restarting its proc animation.

## Coverage

| Section | Preview |
| --- | --- |
| Unit Frames | Three rendered styles using the production ring atlas coordinates, class/palette colours, separate player/pet/target examples and fade |
| Minimap | Interior terrain specimen with separately rendered square/round borders, coordinates and overlay buttons; the complete canonical layout scales down for cards |
| Buffs & Debuffs / unit auras | Production aura renderer: shapes, timers, swipe; sample arrival and cooldown bar |
| Chat | Border, background opacity, input position, formatting, header buttons and faded opacity |
| Tooltips | Character/item sample, client tooltip art, colours, health bar, details, scale and anchor diagram |
| Quest Tracker | Sample quests, borders, zone headers, tags, wrapping, counts, buttons and minimized form |
| Damage Meter | Three sample rows, frame styling, chat tab/header controls, threat text, line and warning |
| Action Bars | Sample buttons with artwork, bindings, macro labels, status colours, end caps and proc glow |
| Experience | Bar texture, value format and quest XP segment |
| Resource Bars | Health/power/swing samples and production combo point widgets |
| Quality of Life | Bag columns/gaps/borders/badges and nameplate name/level/quest/combo examples |
| Radial Options | Client wheel art and separate round icons, relative scale and name visibility; behavioural settings keep the wheel unchanged |
| Fonts | Selected face, size, outline and shadow on names, values and timer text |

Rendered style specimens show representative layouts, not every per-character Edit Mode customization.
Only the minimap terrain is sampled from Tour artwork, strictly inside its frame and away from
captured UI/coordinates. Borders, labels and buttons are independent elements with transparent
surrounds. The map uses a fixed logical size before scaling, avoiding oversized border pieces in cards. Samples for
map, bags, tooltips and nameplates are bounded specimens, not screenshots of the current world.
Scale previews use a common reduced baseline so the maximum option fits the fixed Info Panel.
Long sample text is constrained to avoid overlapping help text. Disabled settings may still be
previewed but retain their existing disabled controls.

## Automated checks

From the repository root:

```
luajit tools/tests/syntax.lua
luajit tools/tests/settings-previews.lua
node tools/enus.js
git diff --check
```

The widget smoke harness checks routing, widget reuse, animation teardown, 129 setting variants,
production palette values, scale ranges and read-only rendering. Registry integration checks the
real style setters, pending reload, undoing a selection, choice labels and font metadata.
Regression checks also execute the Panel's dropdown callbacks and right-column functions, verify
font labels, unsaved choice previews (including zero opacity), section persistence, distinct small
units, nameplate details and complete item tooltip content.
Additional regressions cover minimap scale/layer ordering, cached gryphon front/back changes,
non-redrawing Action Bars hover, and all seven frame-card setters and reload requirements.

## Required client acceptance pass before upstream submission

These checks cannot be replaced by Lua widget doubles; they have not been run in a WoW client:

- Open every visual section, hover controls, change choices and move between pages/search results.
- Hover each style card without selecting: saved values and reload state must remain unchanged.
- Select a style, switch back, and verify the reload footer clears; test the existing reload action.
- Verify the round minimap atlas and native tooltip layout on Forever, and compare each specimen
  against its real frame. Check all new textures load, correct layers and no blank/missing art.
- Check disabled modules/settings, search result cards, collapsed sections and 768-high windows.
- Test controller focus on every card and existing steppers, including after refresh and tab changes.
- Test long translations and font sizes 8 and 24; no text overlaps or escaped preview bounds.
- Switch away from animated samples and close settings: no preview updates should continue.
- Open/close Radial editor, its Options tab and What's New: no stale canvas over another view.
- Test in combat with script errors enabled: previews must not touch protected frames or unit data.

Development is confined to Jeor/FlareUI's feature branch. Do not submit or push upstream until the
client acceptance pass and the user's explicit upstream approval.
