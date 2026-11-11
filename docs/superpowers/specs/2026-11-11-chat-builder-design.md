# Unified chat builder

Status: approved by the user; implemented on `feat/chat-builder`, pending in-client verification.

## Intent and agreed scope

Make creating and editing chat windows easier inside FlareUI, replacing trips through Blizzard's scattered filter menus with an organized frontend. Keep Blizzard's chat backend. Work only in Jeor/FlareUI on `feat/chat-builder`, based on upstream-compatible FlareUI 6.0.1 (`4a07cae`). Do not publish or submit upstream.

The user selected a unified builder. A panel means an individual Blizzard chat window, docked as a tab or popped out. Multiple independent tab containers are outside scope. Users can edit existing windows, create new ones, load sensible defaults, customize them, and save reusable presets.

## Approaches

1. **Unified builder — selected by the user.** A window list and selected-window editor combine creation, configuration, and presets in one place. Best for repeatedly adjusting existing tabs; requires a custom settings tab.
2. **Guided creation plus separate editing.** A preset/content/appearance wizard simplifies first-time creation but duplicates controls and slows ongoing editing. Not selected.

## Proposed user experience

Add a **Builder** tab to the existing Chat settings page, retaining Frame, Tweaks, and Fonts. Use the settings framework's custom-tab support, as the Radial Editor does, with a wider canvas if needed.

- Left: persistent chat windows by their actual names, with docked/popped-out status and a New Window action. Selection does not change the player's active chat tab.
- Main editor: selected window's name, Dock/Pop Out action, and contents grouped into Conversations, Groups, Public Channels, Rewards & Progress, System, and NPCs & Encounters. Groups expand into individual supported Blizzard message types. Include search and category-level select/clear controls with mixed-selection state.
- Preset controls: choose a built-in or saved preset, inspect its contents, apply it to the selected window, or create a new window from it. Save the selected window's content filters as a named custom preset. Rename and delete custom presets; built-ins remain immutable.
- Appearance: make existing shared Frame/Tweaks/Fonts settings easy to reach and explicitly label them as affecting all chat windows. Do not introduce per-window skin/font overrides in this iteration. Window placement continues through existing FlareUI movement and pop-out behavior.
- Keep an Open Blizzard Settings action for advanced or unsupported options. The builder complements existing tab context menus.

Use FlareUI's existing typography, bronze accents, controls, focus conventions, and localized text. Register searchable entry points for the custom tab and ensure keyboard/controller navigation reaches its actions and filters. No mock chat messages are needed: the visible game windows show the outcome.

## Editing and preservation rules

These are proposed implementation decisions, not additional user requirements:

- Direct filter toggles and renames use Blizzard's supported operations; prefer immediate changes where verified safe, and show the resulting state after the operation. If the client requires a reload for a filter change, clearly distinguish saved/pending filters from active filters and expose Reload to Apply. Never claim a pending filter is already active. Validate nonempty names and client limits.
- New Window opens a name/preset choice, with Blank available. Create only after the explicit Create action and only if a slot is available. Failure must not modify an existing window.
- Preset application replaces only the selected window's builder-supported message and public-channel filters. Show a confirmation summarizing replacement; preserve the window name, position, docking, unrelated settings, and unknown filters. Applying a preset never resets every window.
- Closing an ordinary window requires confirmation. Protect the primary General window and Combat Log from deletion. Respect any additional client restrictions for docking and renaming.
- Show Combat Log as a special window with a route to its native configuration; do not treat combat-log event filtering as ordinary chat message filtering. Exclude temporary whisper windows and FlareUI's damage-meter pseudo-tab from editable persistent chat windows.
- Do not apply presets on startup, profile change, or simply opening the builder. Read current client state when opening/selecting a window and refresh after relevant external changes while the builder is visible. A closed/reused frame must not retain a stale selection or receive edits meant for the previous window.
- Block builder mutations during combat, explaining why and enabling them again afterward. Do not silently queue destructive actions. Disable builder actions when the Chat module has not started or is disabled pending reload.

## Built-in presets (proposed defaults)

Presets are filter templates for one window, not whole-layout replacements. They never implicitly leave or join channels.

| Preset | Included content |
| --- | --- |
| General | Say, yell, emotes, whispers/Battle.net whispers, guild, party/raid/instance and their leader/warning variants, system messages; available General and Local Defense public channels |
| Social | Say, emotes, whispers/Battle.net whispers, guild and officer chat, guild announcements and achievements |
| Group | Party, raid, instance, leader/warning variants, whispers, encounter/boss announcements, supported group pings |
| Loot | Item loot, currency, money, experience, reputation, skill gains, supported appearance-collection notices |
| Trade | Available Trade and Services public channels; no unrelated social or rewards messages |
| Blank | No builder-supported content selected |

Exact tokens and available options must come from verified client definitions. Unsupported types are omitted. Public channels are resolved by stable client identifiers where available and localized identity otherwise, never by session channel number or hardcoded English display text. Unavailable preset channels are displayed as skipped, not silently subscribed later.

## Backend and persistence

Blizzard owns live window definitions, message groups, channel subscriptions, docking, and their persistence. FlareUI reads those definitions and changes them through the supported client APIs. Do not implement a second message-routing pipeline or read/copy message bodies to determine filter state.

Distinguish a window displaying a channel from the character joining that channel. Public Channels lists currently joined channels with per-window display toggles; it does not manage joining/leaving, passwords, moderation, or channel order. Keep a route to Blizzard settings for those operations.

Keep the adapter separate from the UI: enumerate/identify windows, read filters, toggle filters, apply presets, create/rename/close, and dock/pop out. Reuse existing Chat module behavior for pop-outs and refresh so skins, hooks, and positions remain coherent. Verify API signatures against the actual Forever client or its matching source before implementation; Retail examples are not evidence for this client's behavior.

Store custom preset records in `ns.db.global.chatBuilderPresets` with a schema version, stable record ID, display name, message-group tokens, and channel identities. They are account-wide within FlareUI and usable by any character. Presets exclude frame IDs, actual messages, window positions, skin options, and channel passwords. Missing channel/type support is reported on application; saved templates are retained unchanged for other characters. No automatic cross-character chat layout synchronization.

Existing chat colors remain unchanged. Editing message colors is deferred because Blizzard color settings can be shared across windows; the native settings link remains available. Existing FlareUI account-wide settings integration must be inspected so it does not reapply stale chat state after builder changes.

Repository evidence: `Modules/Tweaks.lua` captures chat windows and restores saved message/channel filters, explicitly requesting reload for those changes because of live chat-handler taint concerns. This is a required implementation investigation: verify the native configuration's safe update path on the matching client, and preserve the reload fallback above if immediate updates cannot be supported safely. Preserve the user's existing account-wide synchronization setting rather than adding or disabling synchronization implicitly.

## Integration boundaries

Likely changes: `Settings/Pages/Chat.lua` to register Builder, a dedicated settings editor file, a chat backend adapter, load-order entries, localization source/copy tooling, and focused Lua tests. `Settings/Registry.lua` and `Settings/Panel.lua` already support custom tabs, refresh callbacks, and searchable rows; extend shared infrastructure only where necessary. Do not merge unrelated settings integration branch changes as part of this feature.

Builder may decide exact spacing, widget composition, internal method names, stable preset ID generation, and file organization. Verify the current copy-generation source before editing generated localization files. No TOC interface/version bump is part of this feature.

## Validation and acceptance

- Existing windows and their enabled filters appear accurately, including edits made in Blizzard's configuration.
- Create from Blank or a built-in, rename, dock/pop out, change individual/category filters, and safely close an ordinary window.
- Applying presets affects only the selected window and only explicitly supported filters; unavailable channels and full window capacity are clear, recoverable states.
- Save, rename, apply, and delete a custom preset; confirm reuse across characters without changing live windows automatically.
- Special windows, frame-slot reuse, combat state, disabled module, and unavailable APIs cannot cause accidental mutations or Lua errors.
- Lua adapter tests cover routing changes, preservation of unknown filters, preset isolation, missing channels, stale window selection, capacity failure, and combat guards. Run syntax checks and `git diff --check`; add focused UI lifecycle tests where practical.
- In-client checks cover persistence across reload/login, zone/channel changes, native-settings edits, docking, existing account-wide settings behavior, localization, narrow layouts, and keyboard/controller navigation. Report these as pending until actually exercised. Restart the client after adding TOC file entries.

Success means a user can configure a useful named chat window entirely within the Builder, then keep adjusting it through either FlareUI or Blizzard without the two systems fighting over its settings.

## Design review

An independent builder review found no important unanswered planning questions. Client API verification and account-wide settings integration remain explicit implementation investigations, not claims of tested behavior.
