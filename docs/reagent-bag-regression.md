# Reagent bag: prevent post-bank item click taint

Do not call Blizzard's `OpenBag(5)` from a deferred FlareUI callback to fill
the embedded crafting section. A normal click on the combined backpack icon
opens bags 0–4. FlareUI displays reagent slots from bag 5 using its own
instances of Blizzard's item button template when the game has not opened the
separate reagent window. If Blizzard opens it, FlareUI adopts those native
buttons instead. Do not replace the template's click or drag scripts.

## Observed on WoW Forever, build 71037 / FlareUI 7.0.11

From a clean reload, with Crafting Bag in Backpack enabled and both windows
closed, open the backpack with its normal icon, wait, then close it. Visit a
personal banker with all bags closed. The old code reproduces a FlareUI
`bankType` taint at bank open, followed by blocked ordinary right-clicks
after leaving. Opening with the native Open All Bags command did not reproduce
it in the paired test. Keyring alone did not reproduce it either. Removing
the addon-owned OpenBag(5) branch stopped this reproduction in the client.
The exact intermediate native taint carrier was not identified:
`bagSetupDirty` was secure at the observed checkpoints.

## Automated regression

Run `lua tools/tests/bag-section-collapse.lua` from the checkout with Lua 5.1
or LuaJIT. It runs in the existing PR workflow. The fixture fails if the addon
requests `OpenBag(5)` and checks that the ordinary icon path renders all 12
fixture reagent slots without native window ownership. It also checks
section folding/reload, no duplicate slot on handoff to an opened Blizzard
window, native item button identity, keyring behavior and protected-button
handling in combat. The fallback's stock Battlepay texture starts visible
in the fixture just as it does in the template; it must be reset, while the
legitimate bag hover indicator still toggles. These are mocked UI tests, not a
simulation of the client's taint engine.

## Live verification before a release

1. After a reload, use the normal backpack icon. Verify the entire section,
   including a late slot and an empty slot. Pick up and drop a reagent and
   check search and section fold/unfold.
2. Move the pointer onto and off the reagent bag icon. A legitimate highlight
   may appear while hovering; no blue stock overlay should remain on idle slots.
3. Close the backpack, open a personal banker, and run:
   `/dump issecurevariable(BankFrame.BankPanel, "bankType")`.
   Expect `true, nil`. Close the bank and use a normal item with right-click.
4. Repeat with Open All Bags, keyring enabled, and after combat. Also move
   a reagent into and out of a bank slot with the banker open.
