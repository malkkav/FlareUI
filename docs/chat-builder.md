# Chat Builder (Jeor fork)

## Independent test addon

Build with `node tools/build-testing.js <output-parent> FlareUI_Chat`. Install the generated `FlareUI_Chat` folder under `_forever_/Interface/AddOns`, fully restart WoW, disable **FlareUI** and **FlareUI_Testing** for the test character, and enable **FlareUI_Chat**. Open `/flareuichat` (or `/fuichat`), then **Chat → Builder**. The test addon refuses to initialize when either conflicting addon is loaded.

The test build has separate addon preferences (`FlareUI_Chat2_DB`, `FlareUI_Chat_DB`), media paths, commands, and named frames. Blizzard's chat tabs and filters are still the character's normal chat configuration and therefore remain shared when switching between addons. To switch back, disable FlareUI_Chat and enable FlareUI. Nothing is installed automatically by the build script.

## Using the builder

Open **FlareUI → Chat → Builder**. Select a window, then choose which messages and joined channels it displays. Use the preset menu to inspect General, Social, Group, Loot, Trade, or Blank; **New window** creates an empty window, **Duplicate** copies the selected window into a new one, and **Create from preset** creates a window from the selected preset. **Replace window filters** replaces that window's supported filters after confirmation. **Save preset** creates an account-wide template from the saved selections.

Builder keeps the standard settings-panel dimensions and reuses its fonts, switches, dropdowns, selected buttons, and slim scrollbars. The selected window is highlighted and named in the editing header. The window list follows the dock tab order; Move up/Move down moves the selected docked tab left/right immediately and saves its position. General and Combat Log keep their positions; popped-out windows are positioned by dragging. Creation guidance lives in button tooltips to leave more room for the window list. **Selected only** shows enabled filters across all categories. Appearance remains in the existing Frame, Tweaks, and Fonts tabs. Choose one content category from the selector to see a compact two-column checklist; each category shows its selected/total count. Search spans all categories, and clearing it returns to the selected category. All/None continues to affect the entire named category, including when search hides some entries.

Built-in presets are intentionally focused:

| Preset | Messages | Public channels |
| --- | --- | --- |
| General | Nearby chat, whispers, guild, groups, system, quest and encounter dialogue | General, Local Defense |
| Social | Nearby chat, whispers, guild/officer/Discord, achievements | None |
| Group | Party/raid/instance and leaders, raid warnings, whispers, boss messages, pings, battleground notices | None |
| Loot | Items, money, currency, XP, honor, reputation, skill/crafting, opening, appearances | None |
| Trade | Whispers and Battle.net replies | Trade, Services |
| Blank | None | None |

Client-specific or custom channels (such as OOC) remain opt-in in Public Channels. Unavailable public channels are skipped and reported, never joined. Updating these built-in templates does not overwrite existing windows or saved custom presets; load a template explicitly to use its revised filters.

Filters update active routing and saved settings immediately through Blizzard's chat-frame methods. No reload is required. Native settings remain available after edits. A rejected batch attempts to restore its previous selections; any restoration failure is reported.

The primary window cannot be closed or popped out. Combat Log has a native-settings link instead of ordinary filters. Temporary whisper windows and the damage-meter pseudo-tab are not editable. Existing Frame, Tweaks, and Fonts settings still apply to all windows. Channel toggles never join or leave channels. Message colors remain in Blizzard settings.

Custom presets live in `FlareUI2_DB`'s AceDB global `chatBuilderPresets` store, schema version 1. The client continues to own window state. Presets are only applied by explicit user action. Existing Sync Blizz UI ownership remains in effect: the source character updates its snapshot after builder changes, and other characters see a notice that future source snapshots may replace their settings. Builder mutations are disabled during initial sync and combat.

## Client API evidence

Implementation checked against the `forever` branch of Blizzard's extracted UI source:

- [ChatFrameMixin](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrame.lua): group/channel methods mutate live `messageTypeList`, `channelList`, and event registrations as well as saved settings. Builder calls those native methods and verifies both active routing and saved settings; `GetChatWindowChannels` is consumed as name/zone-ID pairs.
- [Chat configuration](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua): message groups, PvP token aliases, voice availability, `GetChannelList` triples, and regional-channel disabled state.
- [Floating chat windows](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua): `FCF_OpenNewWindow(name, noDefaultChannels)`, `FCF_Close`, and window renaming. Dock/pop-out actions reuse FlareUI's Chat module.
- [Chat constants](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua) and [Chat info](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua): channel identifiers resolve to `zoneChannelID`; session `localID` is display/order data, never preset identity.

Built-in channel templates use zone-channel IDs (General 1, Trade 2, Local Defense 22, Services 42). In-client verification must confirm those templates against the installed build. Saved custom channels use their case-folded channel identity; public zone channels use their stable zone ID. Unknown groups and unavailable channel assignments are preserved when applying templates. Unsupported preset entries are reported as skipped.

## Automated validation

From the repository root:

```text
luajit tools/tests/chat-builder.lua
luajit tools/tests/chat-builder-ui.lua
luajit tools/tests/minimap-scans.lua
luajit tools/tests/syntax.lua
node tools/enus.js
node tools/tests/build-testing.cjs
git diff --check
```

The backend fixture keeps saved settings and active routing separate. Tests cover isolated edits, rollback on client rejection, immediate active/saved agreement, duplicate windows, unknown-filter preservation, unavailable/localized/reordered channels, preset CRUD, name validation, stale confirmations, protected windows, module/combat guards, and unavailable APIs. The UI harness exercises real editor callbacks with fake frame primitives; it covers search, category toggles, preset confirmation/management, selected-only filtering, distinct creation actions, standard controls, sidebar ownership, control reuse, and unavailable-client rendering. These tests do not reproduce WoW's secure execution or visual layout engine.

## In-client verification (pending)

Fully restart the client after installing: new files were added to the TOC. Keep the Interface at 16001; no release version bump was made.

1. Enable Lua errors or BugSack. Open Builder with existing customized tabs; verify checked saved filters and normal active filters agree before editing.
2. Create Social, Group, Loot, and Trade windows; check unavailable channel notices, rename, dock/pop out, and close an ordinary window. Verify General and Combat Log protections and the maximum-window-capacity message.
3. Toggle an individual filter, All/None, switch categories, search across categories, and apply a preset. Verify other windows are untouched. Send/receive representative chat immediately without reloading, then confirm persistence after a reload/login.
4. Save and reuse a custom preset on another character. Move zones or change channel ordering and verify template channel identities; no channel should be joined or left automatically.
5. After applying changes, edit in Blizzard settings, return to Builder, and verify refreshed selections without a reload.
6. Switch Builder → Radial Editor → ordinary settings → Builder; no controls should leak between tabs. Test long localized labels, small-screen scaling, keyboard search, and controller navigation into scrolled filters/preset choices.
7. Enter combat with a dialog open; confirmation must refuse mutations. Close/reuse its target window through native controls before confirming; the stale operation must be rejected.
8. With Sync Blizz UI enabled, verify source changes persist, non-source notices are clear, and the initial sync does not overwrite an in-progress builder edit. Check taint logs and BugSack after reload, docking, and channel changes.

No in-client visual, persistence, or taint verification has been performed by the automated tests.

An independent code review found sidebar ownership and missing-API handling issues; both were fixed with regression tests and rechecked. The named-package test executes the isolation bootstrap and verifies generated paths, commands, saved variables, and all TOC references.
