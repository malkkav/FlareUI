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

# FlareUI 7.0

**Restart the game fully after updating** (not just /reload): this version adds new files.

FlareUI now draws its own nameplates. Every kind of unit gets its own look: enemy players and NPCs, friendly players and NPCs, and minor mobs with pets and totems. Open-world PvP gets full plates, quest givers get a clean name, and you can tweak every one of them with a live preview at your side. The chat also learned a few tricks, and unit frames can show the name above the frame.

## Heads up
Some things look or work differently even if you change nothing:
- **Chat:** a popped-out chat window now fades on its own. It comes back for its own messages only, not for every line in every window.
- **Visibility Never:** a frame set to Never no longer shows tooltips when you point where it is.
- **Radial Menus:** the **Mounts** catalog is now **Collections**, with your mounts and your toys.

## Highlights
- **Nameplates:** FlareUI's own nameplates, with a setup for each unit type.
- **Name Above Plates:** the name above any unit frame, so the bars stay clean.
- **Chat:** fade old lines one by one, and quiet loot and skill-ups.

## New

### Nameplates (new page, off)
- First in the Combat list. A /reload turns it on or off.
- **Unit types**, each with its own setup: **Enemy Player**, **Enemy NPC**, **Friendly Player**, **Friendly NPC** and **Minor** (minor mobs, pets, totems and guardians).
- **Presets** for each unit: **Full**, **Simple**, **Minimal**, **Name Only**. Change any setting and it becomes that unit's own Custom.
  - Friendly players and NPCs start on Name Only.
- **Live Preview** beside the settings, and **Test in Game** to put the look on the plates around you.
- **Plate:** size, **Background Opacity**, **Bar Texture**, **Border**, **Level**, **Bar Effects**, **Colour By**, **Health Text**.
  - **Name Only Mode**: just the name, with **Name Only Size**.
  - **Show Plates in Combat**: picked units leave Name Only in a fight.
- **Extras:**
  - Icons: **Elite & Rare**, **Combo Points**, **Quest Objective**, **Quest Progress**.
  - Threat: **Colour by Threat**, **Role**, **Threat Glow**, **Aggro Flash**, **Threat Scale**, **Threat Percentage**.
  - Colours: **Execute Range**, **Colour Mob Types**, **Party Colour**, **Raid Colour**.
- **Cast Bar:** icon, timer and target, **Kick Ready Colour**, **Kick Ready Mark**, **Flash When Targeted**, **Highlight Important Casts**.
- **Auras:** buffs, debuffs, **Defensives** and **Crowd Control**, each with size and count.
- **Targeting** (all plates): target and non-target scale and opacity, **Out of Range** and **Out of Sight** fading, target **Arrow**, **Border**, **Bar Colour**, **Outer Glow** and **Focus Colour**.
- **Visibility** (all plates):
  - Which enemies and friends get a plate, **Stacking**, **Keep Target on Screen**, **Click-Through**.
  - **Name Only While Unattackable** (off): enemy NPCs you can't attack yet show only their name.
  - The game's names over heads: **NPC Names**, **Player Names**, **Minion Names**.
- **Nameplate Colours** in FlareUI's colour window, and a Fonts tab.
- `/fui plates` prints what the module sees, for bug reports.

### Unit Frames
- **Name Above Plates** (Off), in the Text section in Edit Mode: First Name or Full Name above the frame, on the left, centre or right.
  - Auras and a cast bar above the frame move up to make room.
  - On the player, target, focus, pet, target of target, target of focus, party, boss and flag carrier frames. Not on Forever Style, which has its name box.

### Chat
- **Only Chat Messages**: a new Visibility choice. Only lines people write bring the chat back; loot, skill-ups and XP stay quiet.
- **Fade Old Lines** (off), under Fading in Edit Mode: lines fade one by one, oldest first. Pointing at the chat or typing brings them back.

### Visibility
- **Not in a Capital City**: last on every Visibility list, the reverse of In a Capital City.
- **Fade Delay** goes up to 1 minute (chat and meter).

### Radial Menus
- **Collections** catalog: mounts, then toys.
- Small titles split the catalog's lists: Mounts and Toys, Spells and Pet Spells, Target and World Markers, General and Character Macros, Professions and Profession Spells.

### Other
- **XP Bar:** **Show Tooltip** (off) brings the bar's tooltip back.
- `/fui buff` opens the Buff Reminders settings.

## Changed
- Settings text: clearer descriptions and tips, using the options' real names.
- Faster in several places: nameplate colours, buff reminder aura checks, resource bar text and the heal bars on party frames.
- French: the 6.14 phrases. By Brainc3ll.

## Fixed
- Chat: the mouse wheel scrolls the chat again, also when the game's own chat scroll setting is off.

---

Older versions (6.14 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
