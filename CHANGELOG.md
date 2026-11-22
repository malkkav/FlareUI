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

# FlareUI 6.14

**Restart the game fully after updating** (not just /reload): this version adds new files.

A new page joins the Combat list: **Cooldowns**, built by brudi, brings FlareUI's look and a few handy extras to Blizzard's Cooldown Manager. Your backpack can now sort itself into rows, and the Edit Mode windows finally stay where you put them.

## Heads up
Some things look or work differently even if you change nothing:
- **Skin Cooldown Manager** moved from Action Bars to the new **Cooldowns** page. If it was on, Cooldowns is on too.
- **Category Filters** is now a choice in **Bag View** (Bags & Looting › Bag Window). If you had filters on, you get Category Filters: the buttons by the search box when there's room, the drawer otherwise.
- **XP Bar:** **FlareUI XP Bar** is now called **Bar Style**, and its tooltip is gone. It covered the bar's own text.
- **Edit Mode:** settings windows no longer jump next to the frame you click. They open at the top right, then wherever you last dragged one.

## Highlights
- **Cooldowns:** Blizzard's Cooldown Manager in FlareUI's style. By brudi.
- **Bag View:** the combined backpack sorted into category rows. By andrzejskibinski.
- **In a Capital City:** a new Visibility condition on every frame.

## New

### Cooldowns (new page, off)
- First in the Combat list. It changes Blizzard's own Cooldown Manager bars.
- **Cooldown Manager** section:
  - **Enable Blizzard Cooldown Manager**: the same switch as in the game's options.
  - **Advanced Cooldown Settings**: opens Blizzard's window where you pick what each bar tracks.
- **Skin Cooldown Manager** (off): Tracked Bars like FlareUI's cast bars, icons with FlareUI's borders.
- **Bar Colour**: the Tracked Bars' colour, in FlareUI's colour window.
- Icons (all off):
  - **Show Keybind Text**: your keybinds on the Essential and Utility icons.
  - **Show Button Presses**: an icon lights up while you hold its key.
  - **Soften Active Overlay**: a faint swipe over a running effect, so you can see the icon.
  - **Show Cooldown During Effect**: the ability's own cooldown in the icon's corner.
- Fonts tab: **Keybinds**, **Counts**, **Cooldown Numbers** and **Bar Text**.
- Edit Mode, on each Cooldown Manager bar:
  - **Growth** (Blizzard): Tracked Buffs and Tracked Bars packed together, growing right, left, down, up or from the middle.
  - **Icon Shape** (Square): Square or Rectangle.
  - **Fading**, as on every other frame.

### Bags
- **Bag View** (All Items), in Bags & Looting › Bag Window:
  - **Category Filters**: the filter buttons, as before.
  - **Category Rows**: the combined backpack in sections: Quest Items, Equipment, Materials, Consumables, Junk and Other.
  - **Category Rows + Sets**: a section for each equipment set too.
- The **+** button (more bag space) sits at the left end of the gold bar.

### Visibility
- **In a Capital City**: last on every Visibility list. Shows the frame in Stormwind, Ironforge, Darnassus, Orgrimmar, Thunder Bluff and Undercity.

### Edit Mode
- The FlareUI layout code (About page and setup tour) has the new layout.

## Changed
- Settings window: a little taller, so every page fits in the list.
- Minimap › Addon Buttons: the preview follows **Drawer Button Size**, **FlareUI Minimap Button** and **Drawer Style** as you change them. By parchinskiy.
- XP Bar settings: **Bar Texture**, **Border**, **Separators** and **Pick Your Colours** sit right under **Bar Style**.
- French: the 6.13 phrases. By Brainc3ll.

## Fixed
- Custom fonts: text drawn before its font loaded no longer stays blank after login (the Info Bar, keybinds and more).
- Chat: the **Copy Chat** button opens Copy Chat again.
- Quest Tracker: a plain "Ready for turn-in" line is grey, as on Blizzard's tracker.
- Quest Tracker on Visibility **Never**: no more tooltips or clicks where it was.
- Buff Reminders: the food reminder remembers food you eat anywhere, also from /use macros.
- Fake CM: its Visibility names were one place off.

---

Older versions (6.13 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
