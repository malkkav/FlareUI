# Unified Chat Builder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Build the approved unified editor for Blizzard chat windows and reusable filter presets.

**Architecture:** A small catalog defines supported message groups and presets; an adapter reads/writes Blizzard's saved window state without modifying live chat-handler tables. A custom Chat settings tab consumes the adapter and uses existing dialogs, skin helpers, and controller navigation.

**Tech Stack:** Lua, WoW Forever Interface 16001, FlareUI Settings/AceDB, LuaJIT tests.

**Spec:** `docs/superpowers/specs/2026-11-11-chat-builder-design.md`

## Global Constraints

- Work only on Jeor `feat/chat-builder`; no upstream submissions.
- Blizzard owns live windows and routing. Presets are explicit, account-wide templates, not automatically applied layouts.
- Do not change Interface/version or other settings branches.
- Use localized text and regenerate `Locales/enUS.lua` with `node tools/enus.js`.
- Filter edits use saved-setting APIs and an explicit reload indicator; never write live message/channel tables.
- Keep General/Combat Log protected and exclude temporary windows.

## Review Focus

- A closed window slot is reused while a confirmation is open: reject the stale action (task 1).
- Zone channels are absent or renumbered: match stable identity, skip unavailable entries, never join channels (task 1).
- Preset data is malformed or from a future schema: fail before changing filters (task 1).
- Combat starts or Chat is disabled while a dialog is open: recheck mutation guards (tasks 1–2).
- Settings redraws or native edits occur while input has focus: preserve input and refresh only the visible editor (task 2).

### Task 1: Catalog and safe backend

**Files:** Create `Modules/ChatBuilderCatalog.lua`, `Modules/ChatBuilder.lua`, `tools/tests/chat-builder.lua`; modify `Modules/Chat.lua` for started-state flag, `Modules/Tweaks.lua` for sync notification if required, and TOC load order.

**Interfaces:** `ns.ChatBuilder:Windows()` returns snapshot handles `{id, frame, generation, name, special, docked}`; `Read(handle)` returns saved and active filter sets; `Categories()` and `Presets()` return display data. Mutators `SetFilter(handle, kind, key, enabled)`, `SetCategory(handle, category, enabled)`, `ApplyPreset(handle, presetID)`, `Create(name, presetID)`, `Rename(handle, name)`, `Close(handle)`, `SetDocked(handle, enabled)` return success/result or nil/error. Preset CRUD uses `SavePreset(handle,name)`, `RenamePreset(id,name)`, `DeletePreset(id)`. `Status()` reports edit availability and sync state, `Pending()` reports saved/live differences. `Watch(callback)` installs relevant lifecycle hooks and `Unwatch(callback)` removes visibility-scoped observers.

- [x] Write behavioral fixtures for saved/live distinction, window isolation, unknown-filter preservation, stale handles, combat/module guards, capacity failure, localized/reordered channels, preset copy isolation, and invalid preset data.
- [x] Run `luajit tools/tests/chat-builder.lua`; confirm missing-backend failure.
- [x] Implement catalog, adapter, guarded saved-filter operations, preset CRUD, and lifecycle observation. Verify Forever API signatures from matching UI source; document exact sources.
- [x] Run adapter tests and syntax checks; commit the backend.

### Task 2: Unified settings editor

**Files:** Create `Settings/ChatBuilder.lua`, `tools/tests/chat-builder-ui.lua`; modify `Settings/Pages/Chat.lua`, TOC, localization.

**Interfaces:** `ns.ChatBuilderEditor.Build(host, side)` and `Refresh()` for the custom Builder tab; consumes task 1's adapter. Existing FlareUI dialogs handle confirmations and name entry.

- [x] Write a lightweight settings-frame harness exercising selection, filtering, category actions, confirmation cancellation/acceptance, preset management, and show/hide observation cleanup.
- [x] Run the UI test; confirm missing-editor failure.
- [x] Implement window list, name/dock/close actions, grouped searchable filters, mixed category states, preset preview/apply/create/save/rename/delete controls, shared appearance links, native config link, and reload status. Preserve existing tab order/default settings behavior.
- [x] Run UI/backend tests, generate English phrases, run all repository Lua tests and diff checks; commit the editor.

### Task 3: Review and delivery

**Files:** Update this plan and add `docs/chat-builder.md` with API evidence and in-client checks.

- [x] Have a fresh reviewer inspect the whole branch against the spec and test evidence; resolve material findings with regression coverage.
- [x] Run the full Lua test set, syntax, TOC path validation, and diff check. Document client-only checks as pending.
- [x] Commit the verified feature and report the branch, behavior, validation, and client restart requirement. Do not push or install without a separate request.

## Execution ledger

- User approved the design and instructed proceed. Execute inline in the already isolated feature branch; no additional permission checkpoint for the plan.
- Pre-flight: task 2 consumes task 1 adapter methods above. No interface conflicts found.
- Ruling: saved-only filter edits with reload fallback — existing sync code documents taint risk and Forever `ChatFrameMixin` mutates live routing tables. Costs one reload after a batch of filter edits, with explicit pending state.

- Task 1: complete; ad3edd9; backend tests and syntax passed. API-read availability, native-settings pending guard, and rejected-write rollback covered.
- Task 2: complete; f09c5df; UI callback tests cover search, groups, presets, sidebar ownership, and missing API handling.
- Task 3: independent review and follow-up found no remaining important blocker; all automated checks passed. In-client validation remains pending.
- User extension: create FlareUI_Chat as an independently named test addon. Added an optional build target, separate globals/settings/commands, runtime conflict guard for FlareUI and FlareUI_Testing, artifact tests, and installation instructions.
- Ruling: preserved the requested feature branch and current checkout; implemented inline after the user's proceed instruction. No merge, push, or live installation.
- Ruling: UI and backend were developed together before their consecutive commits to exercise their boundary; both suites passed before committing. Source name validation follows existing FlareUI's 31-character rename dialog.
- Final verification: all four Lua test files, generated English phrases, named-package artifact/runtime tests, generated Lua syntax, TOC validation, git diff checks, and SHA256 comparison of all 203 ZIP files passed. Optional dependency warnings in the isolated stage are expected. Package review found no material issue. Scoped build guards fixed the generated PartyFrames 200-local-variable overflow. In-game checks remain pending.
