# Settings redesign implementation

Implemented on `checkpoint/settings-ui-2026-11-10`, following the concept in `settings-concept.png` while retaining the actual addon assets and setting behavior.

- Shared charcoal surface, warm headings, bronze section labels, restrained tabs and secondary Edit buttons.
- Narrower navigation with matching bronze section glyphs, wider control area and consistent row spacing.
- Frame cards have explicit enable checkboxes and neutral borders; gold selection borders remain on style presets.
- Compact dropdowns replace arrow steppers. Numeric opacity, scale and bag-column choices use discrete sliders with preview during drag and a single write on release.
- Unit Frames opens on Appearance. Action Bars separates Appearance and Visibility, retaining Fake CM and Fonts. Appearance groups distinguish button art, text and spell behavior.
- Quality of Life separates Bags and Nameplates from Gameplay, Interface and Advanced, retaining all existing settings and their apply/reload behavior.
- Bags and Nameplates have persistent initial specimens. Help text stays visible after leaving a setting. Preview motion has a Pause/Play control.
- The reload notice uses a dark bronze surface; its protected reload action is unchanged.

Validation: Lua syntax, registry reachability, preview variants, actual dropdown/range callbacks, font overrides, animation pause and cleanup. Native WoW visual acceptance is still required; the generated concept is not a screenshot of the implementation. The restored live minimap module is unchanged by this redesign.

Follow-up refinements: dog logo retained in the title bar; shared page Edit buttons replace resource-row and frame-card duplicates; frame cards use their checkbox for state and a smaller footprint. Tooltip, bag and nameplate toggles temporarily preview their opposite value on hover with an explicit unsaved-preview label. Tooltip comparisons and visibility choices have dedicated examples.

Appearance follow-up: per-unit Portrait and Show Level controls live on Unit Frames Appearance; portrait choices use the Character Portrait label. Level-badge synchronization is deferred during combat. Section headers reset only their active-tab settings through existing setters and reload tracking, using profile defaults. Frame cards are 100 pixels tall with 68-pixel specimen areas; compact group rows fit inside that space.

## Upstream 5.1.1 integration

Integrated on `integrate/settings-ui-5.1.1`, based on upstream `6fdc003`. The earlier checkpoint branch remains unchanged. Upstream minimap runtime code and accepted scan tests are retained unchanged.

Preserved new upstream settings and localized button sizing. Adapted Channel Names, moved Cooldown Manager, removed obsolete shared unit-frame fading, and added specimens for new reminder, bag-section, loot-feed, mouse-ring, minimap-hover and quest-title options. Section resets account for custom Channel Names and global UI Scale settings. Navigation search now uses explicit tab labels, matching the visible tabs.

Validation includes all preview regressions, new setting variants and animation reuse, tab reachability, retained upstream setting keys, bag-group bounds, drawer hover state, and upstream minimap scan tests. Native in-game acceptance remains required before merging a PR.
