# FlareUI 7.0.5

Two new windows from the community: a FlareUI loot window and a searchable flight list. Pet threat on nameplates, the same Health Text picker on raid frames, and a stack of fixes.

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Heads up
Some things look or work differently even if you change nothing:
- **Loot Roll Window:** **Background Opacity** is gone. The window always shows at full strength, since it was hard to read see-through.
- **Quality of Life:** **Coordinates on the World Map** is gone from Map & Mail. It only switched Blizzard's own map coordinates, which are still in Blizzard's options (Interface).
- **Nameplates:** **Threat Percentage** no longer takes the level's place. It has its own small box beside the plate.

## Highlights
- **Loot Window:** FlareUI's own window for corpses and chests.
- **Flight Destination List:** search the flight map by stop or zone.
- **Nameplates:** your pet's threat counts.

## New

### Bags & Looting
- **Loot Window** (off) on the Looting tab: FlareUI's loot window replaces Blizzard's for corpses and chests. By Xentinus.
  - Shows how many of each item you already carry.
  - Item marks follow your Bags options: item level, junk coin, BoE, uncollected appearances, thin or thick borders and rarity colours.
  - A looted item leaves a gap, so nothing moves under your mouse.
  - Placed and scaled in Edit Mode as "FlareUI Loot Window".
- **Show Free Bag Slots** (off): your free bag slots at the bottom of the loot window, red when the bags are full.

### Quality of Life
- **Flight Destination List** (off) in Map & Mail: a list beside the flight map. By parchinskiy.
  - Search for a stop by name or zone.
  - See each fare.
  - Star the stops you use most to keep them at the top, for each character.

### Nameplates
- **Pet threat:** a mob your pet holds takes the **Another Tank Has It** colour, for tanks and damage dealers alike.
- **DoesItDie** and **DoesItDiePlus** show their marker on FlareUI's nameplates. DoesItDiePlus works on the target and focus frames too (by BillChirico).

## Changed
- **Nameplates:** **Threat Percentage** sits in its own small box, on the side away from the level, or on the right with no level.
- **Party Frames:** in Raid Style, **Health Text** and **Power Text** use the same picker as the other frames, with the Centre slot only. Your old choice carries over.
- **Raid Frames:** **Health Text** and **Power Text** use the same Centre-only picker. Your old choice carries over.
- **Quest Tracker:** the header buttons are bronze icons instead of boxes, by GregDuhamel. They follow your **Colour Scheme**: bronze with FlareUI's, gold with Blizzard's.
- **Meters:** if Blizzard's own meter Visibility is set to In a Group or Hidden, a window at login explains why the meter hides in a fight and opens Edit Mode to fix it. Blizzard's Visibility row now stays in the meter's Edit Mode dialog while it is wrong.
- **Settings:** new previews in the info panel:
  - the loot window
  - the Quest Tracker's Colour Scheme, header buttons, complete tag and scroll bar
  - the chat's Frame Style, edit box, icons, header buttons and tab glow
  - the bags' item level, BoE, uncollected and empty slots
  - the minimap's Info Bar

## Fixed
- **Chat:** chat tabs couldn't be switched during a fight.
- **Party Frames:** after switching from Classic to Raid Style, the old health text showed beside the new one.
- **Bags:** using a reagent from the crafting bag in the backpack (an armor kit, filling a crate) could be blocked. By parchinskiy.
- **Resource Bars:** a /reload during a flight broke the Resource Bars until the next reload. By GregDuhamel.
- **Settings:** a section's Reset skipped six options: Button Scale, XP Bubbles, Gryphons, Food and Flask, Hide for My Role and Auto Minimize. By GregDuhamel.
- **Settings:** Buff Reminders showed no previews.
- **Profiles:** importing a profile now checks every option's value type. By GregDuhamel.

# FlareUI 7.0.4

A big batch from your ideas: names above the nameplates, Blizzard's cast bar glow, stacked buffs and debuffs, and item levels in the inspect window. It also brings smoother nameplates in big pulls and the normal game font back.

## Heads up
Some things look or work differently even if you change nothing:
- **Fonts:** the game font is back to normal. 7.0.3 swapped it for Blizzard's Russian copy by accident, which looked sharper and drew some symbols as boxes. Liked the sharper look? Pick **Friz Quadrata TT (Crisp)** in any font list.
- **Nameplates:** Name Only plates show players' full names. Switch **Show Full Name** off for first names only.
- **Unit Frames:** **Name Above Plates** is now called **Name Above Frames**.

## Highlights
- **Nameplates:** names above the plate, and smoother plates in big pulls.
- **Cast bars:** Blizzard's bright edge at the front of the cast.
- **Buffs and Debuffs** can share a place on the unit, party and boss frames.

## New

### Nameplates
- **Names Above Plate** (Off) on the Style tab: the name above the plate, left, centre or right, first or full name. Buffs and debuffs move up to make room.
- **Show Full Name** (on) in the Name Only Mode section.
- **Edge Glow** on the Cast Bar tab.

### Cast Bars
- **Edge Glow**: a bright edge at the front of the cast, as on Blizzard's cast bars.
  - In each frame's Cast Bar section in Edit Mode, and under Look on the Player Cast Bar.
  - On for new players. Already using FlareUI? Switch it on there.

### Unit Frames
- **Buffs** and **Debuffs** can pick the same place, or the same edge: they stack. The one placed first stays next to the frame, the other goes one row further out. Party and boss frames too.
- **Range Check** (off) on Target of Target and Target of Focus.

### Resource Bars
- **Show in Caster Form** (off) on the Druid Mana bar: it stays up in caster form too.

### Bags
- **Reverse Bag Fill** (off): the backpack starts at the top left and fills left to right, downwards.
- **Item Level** also shows on the inspect window's slots, with the player's average item level under their name.

### Minimap
- **Below the Map** (off) in the Info Bar section: the bar sits under the minimap, clear of the quest arrow.

### Meters
- **Hide Until Next Group** in the meter's gear menu: the meter goes away until you join another group, or reload.

### Fonts
- **Friz Quadrata TT (Crisp)**: Blizzard's sharper copy of the game font. It lacks a few symbols.

## Changed
- **Nameplates:** the Visibility tab works with the Nameplates module off. Those are Blizzard's own nameplate settings, so you can switch In Combat back off.
- **Nameplates:** the settings preview shows aura timers and swipes.
- **Action Bars:** **Update Spell Ranks** moves your pet's spells up too (a warlock's Torment after the grimoire).
- **Buffs & Debuffs:** **Filtered Auras** marks debuffs the game won't let addons hide on you as **Not on You**.
- **Radial Menu:** a `/click FUIRadial` macro opens the radial for the controller while the Gamepad UI is on.
- **About:** Kabaday is credited for the loot roll window and the Cooldown Manager.
- **French:** the 7.0.2 and 7.0.3 text is translated. By Brainc3ll.

## Fixed
- **Quest Tracker:** with Blizzard's Gamepad UI on, a mouse click on a quest showed "Open your quest log" instead of opening it.
- **Quest Tracker:** quests that Blizzard's own tracker doesn't list open on a click too.
- **Nameplates:** less stutter in big pulls. Out of Range Opacity, threat colours and glows do far less work per mob.
- **Fonts:** tooltips showed boxes instead of the "·" dot.

# FlareUI 7.0.3

More nameplate polish, plus fixes for the bugs you sent in after 7.0.2. Nameplate auras get their own look options and can stack in two lines.

## Heads up
Some things look or work differently even if you change nothing:
- **Nameplates:** player names on full plates are white. Class colour stays on Name Only plates, where it is easy to read.
- **Nameplates:** **Threat Percentage** no longer sits over the name. It shows in the level box instead of the level while you have threat. With **Level** off, it gets its own small box right of the plate, shown only in a fight.
- **Nameplates:** the raid marker sits on the side opposite the quest icon. **Defensives** and **Crowd Control** go past it on its side.

## New

### Nameplates
- **Auras** section at the top of the Auras tab, for each plate type:
  - **Aura Icon Shape** (Square)
  - **Aura Swipe**, **Aura Timer** and **Timer Colour**: start with your Unit Frames values, so nothing changes.
- **Aura Positions** section below Debuffs, shown when both Buffs and Debuffs are on:
  - **Position** (One Line): **One Line** keeps them side by side, as before.
  - **Buffs on Top** or **Debuffs on Top**: each gets its own line across the whole plate, one line at most.

## Changed
- **Nameplates:** **Quest Objective** and **Quest Progress** no longer show for the two player plate types.
- **French:** the 7.0.1 text is translated. By Brainc3ll.

## Fixed
- **Chat:** with **Fade Old Lines** on, names are clickable again and link tooltips no longer flicker.
- **Unit Frames:** **Values on Mouseover** works on the player frame again. Other frames no longer need one hover after Edit Mode.
- **Bags & Looting:** a switched-off module stays off after a reload.
- **Fonts:** Russian names show in the meter on English clients. FlareUI uses Blizzard's Cyrillic fonts where the game has them. Fix from Aleksandr Vasinskyi.
- **Buffs & Debuffs:** the **Pick One of Yours** list no longer errors in a fight.

# FlareUI 7.0.2

A quick hotfix for four things 7.0.1 broke or missed. Thanks for reporting them so fast.

## Fixed
- **Quest Tracker:** a left click on a quest opens it again. 7.0.1 only showed "Open your quest log to read this quest" for most quests.
- **Bags:** the crafting bag shows its items in the combined backpack again (**Crafting Bag in Backpack**). 7.0.1 left the section empty when you opened only the backpack.
- **Nameplates:** **Full Name** is a choice in the plate's **Health Text**, so friendly players can show their surname. 7.0.1 drew it but left it out of the list.
- **Nameplates:** the raid marker sits right beside full plates. The **Defensives** icons now go past it instead of pushing it far to the left.

# FlareUI 7.0.1

Sorry, everyone. The new nameplates came with more bugs than they should have, and the fixes took longer than I wanted. This update fixes every nameplate bug you reported, plus a long list of other fixes. Thank you for your patience and for all the reports.

A big thank you to this release's contributors: **alex47** (the Items section, Healing & Damage, the preview fix), **parchinskiy** (collapsible backpack sections), **Braincell1980** (the French translation) and **Archy** (the complete Russian translation).

## Heads up
Some things look or work differently even if you change nothing:
- **Quest Tracker:** the right-click menu no longer has **Open Quest Log** or **Show on Map**. A left click on a quest opens both.
- **Chat:** **Border** now only borders the chat window. The edit box has its own border option and keeps the look it had.
- **Chat:** the Combat Log tab can be moved like any other tab. General stays first.
- **Tooltips:** **Show Item Level**, **Compare with Shift** and **Simplified Item Stats** moved to a new **Items** section on the Content tab.

## Highlights
- **Nameplates:** every bug you reported is fixed, including the stutter when combat starts and ends.
- **Bags:** collapsible backpack sections, and filling crates from the crafting bag works again.
- **Nameplates:** NPC titles like "General Goods" under Name Only names.

## New

### Nameplates
- NPC titles under the name on Name Only plates, in a soft tan. Always on.
- **Threat Percentage** now shows during fights.

### Bags
- Click a section header in **Category Rows** and **Category Rows + Sets** to collapse or expand it. By parchinskiy.
  - Each character remembers its own sections.

### Tooltips
- **Items** section on the Content tab. By alex47.
- **Healing & Damage** (Off): shortens item lines with both healing and damage. By alex47.
  - **Spell Healing / Spell Damage:** both numbers as they are.
  - **Spell Healing / Spell Power:** the damage as Spell Power, plus the extra healing.

### Chat
- **Edit Box Style** (Modern):
  - **FlareUI:** Blizzard's own edit box, in FlareUI's bronze.
  - **Modern:** a dark box.
- **Edit Box Border** (follows your old chat border): **None**, **FlareUI Thick** or **FlareUI Thin**. Shows with Modern only.

### Resource Bars
- **Paladin Seals:** **Show Icon** (off) in Edit Mode puts the seal's icon at the bar's left end.

### Buff Reminders
- **Warlock pet:** right-click the icon to pick the demon a click summons: **Last Used** (default) or any demon you know.
- Every icon's right-click menu has a **FlareUI Settings** link.

### Quest Tracker
- The **Voice Button** also plays quest lines from Wayfarer (Russian voice-over).

### Minimap
- **Info Bar:** gold shows with coin icons, like in your bags.

## Changed
- **Unit Frames (Forever Style):** your own name box takes your class colour when that frame's **Class Colours** is on, as on target and party.
- **Languages:**
  - Russian: complete (739 new strings). By Archy.
  - French: 7.0 strings translated. By Braincell1980.
- **Russian client:** a dash replaces the middle dot "·", which Russian fonts draw as a box.

## Fixed

### Nameplates
- A stutter when combat started and ended.
- **Show Friendly Plates** reset to Off when you picked **Always**. **In Combat** and Quality of Life's **Combat Friendly Plates** didn't work either.
- Chairs, signs, mailboxes and herb or ore nodes got enemy plates.
- Pet and minor names were tiny, even at 200%.
- **Full Name** in Bar Text showed only the first name.
- The raid marker sat far from the name on Name Only plates.
- Friendly players showed two names with the Musician addon.
- Quest marks stayed beside plates when another nameplate addon was running, and couldn't be turned off.

### Bags
- Filling a crate, milling or prospecting from the crafting bag was blocked (**Crafting Bag in Backpack**).

### Quest Tracker
- After you opened a quest from the tracker, the world map could be blocked in a fight.

### Gamepad
- A "blocked action" popup after closing Edit Mode. In Gamepad mode, Edit Mode dropdowns and colour swatches now open FlareUI's own lists. Colour swatches offer ready colours.

### Chat
- The chat tabs took clicks meant for quest, merchant and crafting windows above them.

### Other
- **XP Bar:** a small gap stayed at the bottom of the screen.
- **Settings previews:** squeezed previews cut their text short. By alex47.

---

Older versions (7.0 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
