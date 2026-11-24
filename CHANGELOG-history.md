# FlareUI changelog history

Versions 7.0.7 and before. The latest versions are in [CHANGELOG.md](CHANGELOG.md).

# FlareUI 7.0.7

A big round of controller work, a real second power slot for druids in Forever Style, and a long list of fixes from your reports.

**Restart the game fully after updating** (not just /reload): this version adds new files.

**We need your help testing:**
- **Controller players:** we don't all play with one, so the controller changes below need your hands. Tell us what works and what doesn't.
- **Druids:** try **Mana on Shapeshift** in Forever Style, in and out of fights.
- If the game says it blocked an action from FlareUI, send us what `/fui errors` shows. It now lists those too.

## Heads up
Some things look or work differently even if you change nothing:
- **Quality of Life:** the **Nameplates** tab is gone.
  - **Combo Points**, **Quest Objectives** and the **In Combat** choices are in the Nameplates module, and work with Quality of Life off. Your choices carry over.
  - These are gone from Blizzard's own nameplates: Combo Points, Quest Objectives, Hide Names, Hide Level Box and Level Before Names.
- **Forever Style:** **Mana on Shapeshift** no longer cuts the power bar in half. The mana bar has its own slot below the frame.
- **Gamepad UI:** these are off, because each could break the controller until a reload:
  - stick scrolling in the quest tracker
  - opening quests from a click in FlareUI's tracker, and linking them to chat
  - the meter's right-click menus
  - the FlareUI button in the ESC menu
  - the chat's Copy button
  - **Skip Loot Confirmations**
- **Gamepad UI:** synced chat settings and the chat style wait for a reload or logout.

## Highlights
- **Quest Tracker:** use all of it with a controller.
- **Forever Style:** Blizzard's own second power slot for druids.
- **Party Frames:** raid markers on what your party is targeting.

## New

### Gamepad UI
- **Quest Tracker:** LB + RB, then D-pad Up, gives the controller to FlareUI's tracker. A legend below it shows the buttons.
  - D-pad: moves between quests, quest items, zones, recipes and the header buttons
  - A: focuses a quest, uses an item, folds a zone
  - X: opens the quest on the map
  - Y: a list with Share Quest, Collapse, Pin to Top and Untrack
  - B: gives the controller back
  - In fights, only quest items work. With none on screen, or with no tracker on screen, the quest log opens instead.
- **Dialogs:** X picks the third answer.

### Party Frames
- **Show Target Markers** (off) in Edit Mode under Pets & Targets: the raid marker of what each member is targeting, on the right edge of its frame. Needs **Party Targets** on.
- **Raid Style:** **Health Text** and **Power Text** have Left, Centre and Right, like Classic. Your old pick stays in the centre.

### Bug reports
- `/fui errors` also lists what the game blocked from FlareUI.

## Changed
- **Forever Style:** with **Mana on Shapeshift**, the power bar and its numbers keep their size, and it works with **Power Height** off. The attached cast bar and the auras below the frame make room.
- **Radial Menu** (controller):
  - You keep walking when a radial opens.
  - The lit button is always the one that's used.
  - The camera stays still for a moment after it closes.
  - A radial closes on loading screens.
- **Minimap:** the Info Bar's text is white.
- **Buff Reminders:** the missing elixir ranks are in the list. By GregDuhamel.
- **German:** 42 phrases translated. By kluntjewalker.
- **Hungarian:** translated up to 7.0.6. By Xentinus.

## Fixed
- **Gamepad UI:**
  - The quest shortcut (D-pad Up) gave the controller to a tracker nobody could see.
  - FlareUI's quest tracker took the stick while a radial was open.
  - B could close a radial opened from a B slot right away.
  - The dialogs and the settings window could pass button presses on to the game.
  - Several ways FlareUI's chat could stop the controller from working until a reload.
- **Quest Tracker:** clicking a quest's text could open the map without the quest.
- **Settings:** the X didn't close the window in a fight.
- **Fonts:** a name's shadow could be missing, most visibly with **Outline** on None.
- **Nameplates:**
  - **Combo Points** didn't show with Quality of Life off.
  - The level didn't show with **Names Above Plate** and **Level** on Follow Name.
- **Radial Menu:**
  - Toys didn't work from a radial.
  - Long names in the Catalog ran into its title.
- **Buff Reminders:** a drink could still be remembered as your food.
- **Minimap:** icon tooltips showed a second tooltip about moving them.
- **Chat:** another try at tabs that don't switch during a fight. **If yours still don't, please tell us.**

# FlareUI 7.0.6

More control over fading, a stack of nameplate options you asked for, and Korean and German translations by a player.

## Heads up
Some things look or work differently even if you change nothing:
- **Nameplates:** the cast bar has its own **Bar Texture** and **Border** now, FlareUI Dark and FlareUI Thin to start. It no longer copies the plate's texture and border, so set them again on the Cast Bar tab if you changed the plate's.
- **Nameplates:** the plate under your mouse gets a lighter border and bar. Pick what lights up, or turn it off, with **Mouseover Highlight** on the Targeting tab.
- **Loot Window:** with auto loot on, FlareUI's loot window opens for a moment like Blizzard's, and the items leave it as you pick them up.

## Highlights
- **Fade Delay** on every frame that fades by your choice.
- **Nameplates:** class-coloured names, guild colours, titles and a separate cast bar look.
- **Korean** and **German** translations by ithiel.

## New

### Fading
- **Fade Delay** (0 seconds) in the Fading section of Edit Mode: how long a frame stays after its last reason to show, before it fades.
  - On the action bars (1–8, pet, stance, Totem Bar), the gryphons, the bags bar, the micro menu, the player and pet frames, the Resource Bars' Health, Power, Mana and Combo Points, the XP bar, the minimap, Buffs, Debuffs, the Quest Tracker and the Cooldown Manager.
  - In a fade group the whole group shares one delay.
  - Frames the game shows and hides by itself (target, focus, the cast bar and similar) don't have it.
- **Slower** Hide Speed: fades to about half over 2 seconds, waits 2 seconds, then fades out. By themese.

### Chat
- **Keep Messages Shown** (off) in the chat's Edit Mode Fading section, after Fade Old Lines: the window, tabs and buttons fade as set, but the messages stay readable.

### Nameplates
- **Colour Names by Class** (off) on the Plate tab: players' names on full plates in their class colour.
- **Colour Guild Members** (off, Friendly Player): your guild's names in Blizzard's guild green on Name Only plates.
- **Show Titles**: players' titles and NPC roles under the name. On for NPCs, off for players and Minor.
- **Bar Texture** and **Border** for the cast bar, on the Cast Bar tab above Cast Bar Height.
- **Mouseover Highlight** on the Targeting tab, under Target Highlight: tick **Border**, **Bar** and **Outer Glow** (Border and Bar to start).

### Radial Menu
- **Tanning** and **Bait and Tackle** in the Professions list.

### Translations
- **Korean** and **German**, by ithiel.

## Changed
- **Nameplates:**
  - **Height** goes down to 5.
  - The tab row is split into two labelled groups: **This Unit Type** and **All Nameplates**.
  - The mouseover highlight also lightens the target and threat border colours.
  - **Show Full Name** is hidden for NPC types, where it did nothing.
  - Plates update more cheaply in big pulls. By parchinskiy.
- **Party Frames:** in the Gamepad UI, the target highlight is twice as bright, to spot the member picked with the D-pad.
- **Meters:** the Cyrillic font is used only for names with Russian letters.
- **French:** the 7.0.4 and 7.0.5 text translated. By Brainc3ll.

## Fixed
- **Gamepad UI:** party targeting with LB and the D-pad didn't work if the Gamepad UI was switched on after login. **Controller players, please tell us if it works for you now.**
- **Unit Frames:** **Values on Mouseover** with a druid's **Mana on Shapeshift** hid all the numbers in caster form.
- **Buff Reminders:** the food reminder remembered a drink as your food. By GregDuhamel.
- **Loot Window:** the gap above the first row now matches the sides.

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

# FlareUI 6.13

**Restart the game fully after updating** (not just /reload): this version adds new art files.

A huge thank-you to parchinskiy, a great collaborator who tracked down and fixed the hardest bug we've had so far: the bags breaking your clicks after a bank visit. This patch is also the big settings clean-up: every page and Edit Mode window got the same order, the same words and the same rules, and the unit frames now offer the same options in every style.

## Heads up
Some things look or work differently even if you change nothing:
- **Vendor** options moved to **Bags & Looting**, and now follow that page's switch. If Bags & Looting is off, turn it on to keep Auto Sell Junk, Auto Repair and the rest.
- **Quest Tracker:** the new **Colour Scheme** starts at **FlareUI**: softer, bronze-toned colours on the FlareUI and Modern styles. Pick **Blizzard** for the old colours.
- **Quest Tracker:** new installs start with the **Modern** style. Your current style stays as it is.
- **Names on unit frames:** outside Forever Style, the name is now a pick in **Health Text** only. If you had **Show Name** off, the name is back: untick it in Health Text.
- **Party (Classic) and boss frames:** **Health Text** and **Power Text** are now the Left / Centre / Right picker. Your old choice carries over.
- **Gryphons:** the **Same as Action Bar 1** Visibility choice is gone. Gryphons that used it now join bar 1's fade group, or copy its Visibility.
- **Minimap drawer:** **Addons in the Drawer: None** now keeps every addon button on the minimap's edge. **Drawer Style: Off** turns the drawer off. If you had None, your drawer is now set to Off.
- **Bar textures** renamed: FlareUI Forever is **FlareUI Dark**, FlareUI Forever (Light) is **FlareUI Light**. Your picks carry over.
- **Aura Swipe** and **Aura Timer** left the Buffs and Debuffs Edit Mode windows: set them in Settings › Buffs & Debuffs. The totems' are in Buffs & Debuffs › **Totems**.
- **Shields** over health bars are lighter (40%, was 75%), so the health under them shows.

## Highlights
- **Settings clean-up:** dropdowns, then sliders, then switches everywhere; one word for each idea; fewer, clearer sections.
- **Unit frame parity:** the same options on every frame and style where they make sense.
- **Chat and Meters:** the FlareUI **Frame Style**.
- **Loot Feed:** square or round icons with a border in the item's quality colour.
- **Values on Mouseover:** health and power numbers only while you point at a frame, as Blizzard's option.

## New

### Unit Frames
- **Values on Mouseover** (off), in each frame's Text section in Edit Mode: health and power numbers show only while you point at the frame. On every unit frame, party, raid, boss and flag carrier frame.
- **Level Disc Size** (100%), in each frame's Text section, FlareUI and Forever Style, with **Show Level** on. It replaces the one slider in Settings. By SSyl.
- **Show Combat Text** (off), player and pet, FlareUI and Forever Style: Blizzard's hit and heal numbers on the portrait. Its font is in Unit Frames › Fonts › **Combat Text**.
- **Portrait Scale** (100%) is back on FlareUI Style frames, now on party, boss and flag carrier frames too.
- **Show Weapon Enchants** (on), player frame: the enchants follow **Hide Buffs** too.
- **Combo Points** is one dropdown in every style: **Off**, **Classic** (the gems) or **Modern** (a bar). Forever Style's gems can now be turned off.
- Focus frame: **Leader**, **PvP Flag** and **Quest Objective** icons, as on the target frame.
- Target and focus: **Dispel Highlight** (Off), for a friendly unit you can dispel.
- Pet frame: **Range Check** (off).
- Boss frames: **High Level Skull** (on), FlareUI and Forever Style.
- Flag carrier frames: **Class Colours**.
- Party, boss and flag carrier cast bars: their own **Background**; boss and flag carriers also get **Position** (Above or Below). Cast bar **Height** goes up to 40 on every frame.
- Main Tanks: **Target Frame Width** and **Target Frame Height** for Tank Targets (Auto follows the tank's frame).
- Player Cast Bar: **Show Speed** and **Hide Speed** in its Fading.
- Mirror Bars has a description.

### Chat
- **Frame Style** (Modern): **FlareUI** puts the quest tracker's look on the chat.
- **Whisper Sound** (Off): Raid Warning, Alarm or Whisper. The speaker button plays it.
- Middle-click a whisper tab to close it.
- **Icons** dropdown: **Item and Spell Icons**, **Race Icons**, **Class Icons** (were three switches).
- **Notifications** section: **Tab Glow** and **Whisper Sound**.

### Meters
- **Frame Style** (Modern), as on the chat.
- **Bar Texture** (Blizzard).
- **Threat Window**: **Off**, **Separate Window** or **In the Meter in Combat** (were two switches).

### Quest Tracker
- **Colour Scheme**: **Blizzard** or **FlareUI** (default).
- **Header Buttons**: **Filter**, **Sort**, **Auto Accept** and **Auto Turn-In** box buttons on the header.
- **Hide Scroll Bar** (off).
- **Auto Minimize** dropdown: **In Instances**, **In Combat**, **On Flight Paths** (new).
- **Show Untracked Quests** works without Zone Headings: the untracked ones come after your tracked quests.

### Bags & Looting
- **Loot Feed** is now **Off**, **Square Icons** or **Round Icons**. Each icon has a border in the item's quality colour.
- Loot Feed: **Scale** in its Edit Mode window.
- **Skin Item Slots**: **Colour by Rarity** is back, under a line in the dropdown (on).

### Buffs & Debuffs
- **Aura Filters** (was Hide Auras): each spell can be **Hide** or **Show**. Shown spells get their own row and skip the other filters.
- **Totems** section: **Aura Swipe** and **Aura Timer** for your totems.
- **Never** in the Visibility of the buff and debuff frames.

### Buff Reminders
- A reminder waits while its spell is on cooldown (Fear Ward).
- Food: a click eats the food that last gave you Well Fed.
- **Upkeep** dropdown (was six switches), with **Weapon Oil / Stone** in it.
- **Icon Alerts** dropdown in Edit Mode: **Glow When Missing**, **Glow When Running Out**, **Time Left**.

### Minimap
- **Minimap Icons** section: one **Icons** dropdown (**Sundial**, **Group Finder**, **Vehicle Exit**, **Durability Warning**) and **Reset Minimap Icons**.
- Info Bar: **Experience**.
- Happy Camper and Lore Forever buttons sit in the minimap's button row.
- The day/night sundial lights up under your mouse and has a tooltip. By parchinskiy.

### Action Bars
- Gryphons: **Scale** in each gryphon's Edit Mode window.
- XP Bar: **Bar Texture** and **Border** are in Settings › Action Bars › XP Bar (were in Edit Mode).

### Everywhere
- **Never** in every Edit Mode Visibility, first in the list. A unit frame on Never takes no clicks.
- Sound dropdowns have a speaker button that plays the sound.

## Changed

### Settings
- Every page and Edit Mode window: dropdowns first, then sliders, then switches.
- Options that depend on another one sit in line and grey out, no longer indented.
- Names, one word per idea:
  - **Background Opacity** (was Frame Opacity), **Scale** for sizes in %, **Max Buffs** and **Max Debuffs** (were Buff Amount and Debuff Amount), **Border** on cast bars (was Border Texture), **Centre**, **Off** first in every list.
  - **Sync Blizzard UI**, **Keep Page 1 in Stances**, **Threat Text** (was Show Threat, now in the Text section), **At the Cursor** (Tooltips, was Mouseover), **Show My Frame in a Party / Raid** (were Hide Player Frame).
  - Fonts: **Counts**, **Macro Text**, **Spell Timer**.
  - Section names: **Bars**, **Buttons**, **Spell Behaviour**, **Frames**, **Controller**, **Consumables**, **Auras** and **Ordering**.
  - Unit frame aura places read **Above the Frame**, **Below the Frame, Left** and so on.
  - Quest Tracker style **Custom** is **Modern**; Unit Frames **Addon Style** is **Modern Style**; borders **FlareUI Thin** and **FlareUI Thick**.
- Quality of Life's **Interface** tab is now **Extras**.
- Minimap sections: **Look**, **Info Bar**, **Tweaks**, **Minimap Icons**, **Addon Buttons**.
- Quest Tracker tabs: **Frame**, **Behaviour**, **Fonts**; **Header Buttons** moved to Frame.
- Buff Reminders: the **Alerts** tab joined **When and Where**.
- Portrait, Flip Portrait and Mirror Bars moved to each frame's **Look** section in Edit Mode.
- Simple Pet Frame, Simple Target of Target and Level Disc Size are hidden in Modern Style, where they do nothing.
- Edit Mode rows that do nothing on a Fake Cooldown Manager bar are hidden there.
- Aura sizes: 8 to 48 on every frame (raid tiles 8 to 30).
- Meters: **Match Chat Size** and the Meter Tab rows grey out with Chat off, instead of hiding.
- **Open Flight Map at Once** moved to Map & Mail.

### Look
- One bronze for the ring styles' frames, rings and boss dragons, and for the minimap's Blizzard art.
- Warmer colours across the settings, tooltips and windows; aura borders a lighter bronze.
- Bronze header icons on the chat, meters and loot rolls are darker.
- Quest Tracker: a plain "Ready for turn-in" line is grey, as Blizzard's.

## Fixed
- **Bags:** after a bank visit, right-clicks on items stopped working (Cozy Sleeping Bag, bank tabs). The keyring and crafting bag now use Blizzard's own clicks. By parchinskiy.
- Gryphons faded with action bar 1 whatever their Visibility said.
- Raid frames: Width and Height only moved the gaps with Tank Targets on.
- Chat: an error when switching tabs in a fight; an error in the tab bar under combat restrictions.
- Edit Mode: an error with hidden auras under restrictions.
- Minimap FlareUI Thin and Thick borders: the map's corners now follow the border's angled corners.
- Minimap drawer: takes buttons from EnhanceQoL and HidingBar. By AreChen.
- Info Bar dividers stay one pixel wide at any UI scale. By Celbrund.
- Small action buttons (stance, pet, possess, totem): thinner border, no overlap. By Celbrund.
- Radial Menu: Sub-Radials reset on close kept the last button's name and icon.
- Radial emote labels in Russian lost their first letter.
- Keybinds sometimes missing at the first login.
- The layout restore box: Not Now keeps your layout, and a restore that didn't stick isn't offered again.
- Details! chat embed fits FlareUI's chat window.
- Quest Tracker: lines kept their old colours after a Colour Scheme switch.
- Totem Bar Scale showed with Action Bars off.

## Translations
- **Hungarian**, new. By Xentinus. Loot roll buttons use FlareUI's Need, Greed, Pass and Transmog words where your language has them.
- French: the 6.12 phrases. By Brainc3ll.

# FlareUI 6.12

**Restart the game fully after updating** (not just /reload): this version adds a new file.

A huge thank-you to AreChen for the Chinese translations and for all the help this week. This patch started as a few fixes and then kept growing: a new quest tracker look, minimap icons you can move around the edge, health colours, bar text in the order you pick, and a pile of fixes from your Discord reports.

## Heads up
Some things look different even if you change nothing:
- **Quest Tracker:** the new **Frame Style** starts at **FlareUI**: Blizzard's title and zone strips on FlareUI's frame, with a thicker border. Pick **Custom** for the old look.
- **Quest Tracker fonts** (only if you never set them): Header 12, Quest Names 11, Objectives 10 (were 13, 12 and 11).
- **Hide Buffs** now starts at **Off** on every frame, as on Blizzard's frames. Buffs without a timer show again: tracking, mounts, Plainsrunning and so on. To hide them, set **Hide Buffs** in the frame's Edit Mode settings.
- **Chat, Meters and Quest Tracker:** **Frame Opacity** starts at 75% (was 60%), if you never changed it.
- **Bar Text:** if 6.11 turned your health text into "% / Value", untick both and tick them again in the order you want.

## Highlights
- **Bar Text:** numbers show in the order you tick them, and the menu numbers your ticks.
- **Minimap:** move the sundial and the other edge icons around the map, and pick a new **Border**.
- **Quest Tracker:** **Frame Style**, **Quest Buttons** and Blizzard's glows.
- **Tint Health:** health bars that turn red when low, or shift from green to red.

## New

### Unit Frames
- **Tint Health** (Off), in each frame's Behaviour section in Edit Mode:
  - **On Low Health:** the bar turns red under 30%.
  - **By Health:** the bar goes from green to yellow to red.
  - On every unit frame, party, raid, boss and flag carrier frame, and the Resource Bars' health bar.
  - It replaces the Resource Bars' **Low Health Colour** switch. Your setting carries over.
- Player frame: **GCD Spark** (off), after **Five-Second Rule**.
- Player frame: **Dispel Highlight** (off), in Edit Mode › Auras: the frame lights up in the colour of a debuff you can remove.
- Debuff icons 18 px and bigger show the debuff's type (Magic, Curse, Poison, Disease) in their top right corner.
- Party and raid frames: the health bar flashes red when you start to pull threat. It's part of **Threat Glow**.

### Buffs & Debuffs
- **Timer Colour** (on) is back as its own switch, in two places:
  - Buffs & Debuffs (your buff and debuff frames).
  - Unit Frames (auras on your frames).
  - Turn it off to keep timers white.
- Weapon enchants now start your first buff row instead of sitting in a row of their own. They count toward **Max Icons**.
- The player frame shows your weapon enchants at the start of its buff row too.

### Quest Tracker
- **Frame Style**, first in the Frame section:
  - **Blizzard:** Blizzard's strips, with no background or border.
  - **FlareUI** (default): the strips on FlareUI's frame.
  - **Custom:** no strips, with your own background and border.
- **Quest Buttons** replaces Quest Icons and Voice Buttons. Pick **None**, or tick **Quest Icon**, **Focus Button** and **Voice Button**. Your choices carry over.
  - **Focus Button** brings back the small focus dot. Quest Icon and Focus Button can't both be on.
  - **Voice Button** moved to the right end of the quest title, with Play, Stop and Replay.
- Blizzard's glows: objectives glow when they move forward or finish, and quest titles glow when you accept or turn in a quest.
- With Questie, focusing a quest while the world map is open flashes the quest on the map.

### Minimap
- **Border** for the square minimap: **Bronze (Clean)** (default), **Bronze (Header)**, **FlareUI Thick** or **FlareUI Thin**.
  - **Style** is now just **Square** or **Round**. Square (Header) carries over as **Bronze (Header)**.
- Edge icons: the sundial, Group Finder, Vehicle Exit and Durability icons slide along the map's edge, like addon buttons.
  - Shift+drag to move one, Ctrl+mouse wheel to resize it, Shift+right-click or Ctrl+right-click to reset it.
  - In Edit Mode, drag, scroll and right-click without holding a key.
  - **Reset Minimap Icons**, in Map Tools, puts them all back.
- Info Bar: **Coords (Simple)** shows whole numbers, like 45, 62. The old choice is now **Coords (Decimals)**.

### Chat, Meters and Quest Tracker
- New border: **FlareUI Frames Thick**. The old border is now called **FlareUI Frames Thin**.

### Radial Menu
- **Target Mouseover** (Off), in Options: opening a radial also targets the unit under your mouse.
  - **Enabled**, or only while you hold **Shift**, **Ctrl** or **Alt**.
  - Works in combat.
- **Button Names**: **Off**, **On Hover** or **Always** (was the Show Button Names switch).
- About 220 more emotes.

### Tooltips
- **Show Guild Ranks** (off) is back. It's greyed while **Show Guild Name** is off.
- **Show Faction** (on) replaces Hide Faction. Your setting carries over.

### XP Bar
- **FlareUI XP Bar**: **Off**, **Single**, **Split** (default) or **Double** (a second bar below the first).
- **XP Text** is one dropdown: **Show Always** or **Show On Mouseover**, then tick **Percent**, **Value**, **Max** and **Remaining**. Your old choices carry over.

### Other
- **Zone Levels on the World Map** (off), in Quality of Life › Map & Mail: a zone's level range under its name.
- **/kb** opens Blizzard's Quick Keybind Mode, out of combat. If another addon already uses /kb, type **/fui kb**.
- Gamepad: LB + D-pad moves between FlareUI's party and raid frames.

## Changed
- Bar Text: numbers in one spot show in the order you tick them. The menu shows 1, 2, 3 next to your ticks.
- Tooltips: the Mouseover section is now **Position**, with **Tooltip Corner** at the top.
  - **Offset X** and **Offset Y** hide while **Mouseover** is **None**.
- Tooltips, Content tab: **Show PvP** comes before **Show Faction**, and **Simplified Item Stats** is last.
- Quality of Life: **Auto Accept Quests** and **Auto Turn-In Quests** are two switches again (were **Automate Quests**). Your setting carries over.
- XP Bar: **Bubbles** is now **Separators**.
- Profiles: **Reset FlareUI** sits in its own **Addon Reset** section.
- Unit Frames › Fonts: the Level font has no Size any more. It follows the name in Addon Style, and the level disc in the ring styles.
- Chat and Meters: the **Fading in Edit Mode** buttons are gone. Fading itself is still in Edit Mode.
- Radial Menu: **Custom Emote** is gone. A saved one becomes the matching emote, or keeps working as typed text.
- Quest Tracker: quest titles use Blizzard's yellow.
- Quest Tracker: **Show Complete Tag** turns only "(Complete)" green. The quest name keeps its colour.
- Action Bars: **Macro Text** sits centred under the icon.
- Action Bars: with **Skin Action Bars**, stance, pet and small buttons show as much of the icon as the main bars.
- Action Bars: a softer glow on the buttons of items you're wearing.
- Buff Reminders: casts the highest rank each group member can take. Members too low for any rank don't count.
- Minimap: Info Bar cells grow with their font, and a Middle cell on its own sits in the centre.
- Pet frame: **Power Height** starts at 8, so the pet's resource bar shows. By AreChen.
- Edit Mode is much faster: **Reset Settings**, opening Edit Mode, dragging sliders and nudging with the arrow keys.

## Fixed
- Unit frames: "Dead", "Offline" and "Ghost" no longer sit on top of the name.
- Unit frames: a /reload during a cast no longer loses unit frames.
- Tooltips: with **Health Bar** set to **Inside**, the bar no longer covers the last line (like PvP). When the game doesn't allow the room, the bar shows below the tooltip.
- Buff Reminders: clicking skips group members who are out of range.
- Chat: party, raid, guild and channel messages bring a faded chat back, like say and whispers.
- Quest Tracker: tracking or untracking a quest in a fight waits until the fight ends, with no more blocked-action error.
- Minimap: other addons' buttons outside the drawer sit above the border.
- Addon drawer: an icon without a label is listed by its addon's name, not its live text.
- Vendors: Shift+click to buy several items works again.
- Delete Junk When Full works on the first loot window after logging in.
- Loot Feed: money shows its coin icon.
- FlareUI Style: glows pulse together.
- Swing timer: the **Stand-Still Zone** colour updates as soon as you change it.
- Action Bars: pet command highlights show on skinned bars. By AreChen.
- Sync Blizz UI keeps your bag sort settings at logout. By Nico-Mayer.
- Radial editor: **Undo Changes** brings back your groups.
- Setup tour: the reload button hides during a fight.
- Settings: NEW tags no longer cover the text on button rows.

## Translations
- Chinese (Simplified and Traditional): updated. By AreChen.
- French: the 6.11 text. By Braincell1980.

# FlareUI 6.11

**Restart the game fully after updating** (not just /reload): this version adds new files.

This is the biggest patch yet. Put any text on any side of your bars, give the minimap an Info Bar, pick your action bar and XP bar colours, hide the auras you never want to see, and get flag carrier frames that look like the rest of your UI. Plus a long list of things you asked for on Discord. Grab a drink: the list below is long.

## Heads up
Some things look different even if you change nothing:
- **Buffs and debuffs:** each frame now shows a set number: 6 (8 in Addon Style; 4 on focus, party and boss frames; 3 on the pet). Wide frames used to show more. Raise **Buff Amount** and **Debuff Amount** in each frame's Edit Mode settings.
- **Target of Target and Target of Focus** frames are on by default.
- **Default font sizes** changed on most unit frames (only if you never set them yourself):
  - Player and target: 12 name, 12 health, 10 power.
  - Focus and pet: 10, 10, 8.
  - Target-of frames: 8, 8, 6.
  - Raid: 10, 8, 6.
  - Cast bars (all but the player's): 10.
- **Flip Portrait** now moves the portrait to the other side of the frame instead of mirroring the picture. It's on (portrait on the right) by default.
- **Options removed:**
  - **Status Colouring** switch: pick the **Disabled** palette in **Status Colours** instead.
  - **Full Player Names**: pick **First Name** or **Full Name** in the bars' **Health Text**.
  - **Portrait Size** (FlareUI Style): the ring now grows with the frame's height.
  - Minimap **Framerate**, **Latency** and **Coordinates**: they're now Info Bar cells.

## Highlights
- **Bar Text:** put the name, health, power and level on the left, middle or right of each bar.
- **Minimap Info Bar:** gold, bags, durability, framerate, latency or coordinates on the map. By Celbrund (GregDuhamel).
- **Hide Auras:** hide any buff or debuff on any frame.
- **Colours:** pick your own action bar status colours and XP bar colours.
- **Flag Carrier Frames:** rebuilt in your frame style, with cast bars.

## New

### Unit Frames
- **Bar Text**, in each frame's Edit Mode settings: **Health Text**, **Power Text** and **Druid Mana Text**.
  - Each has Left, Middle and Right spots. Tick what goes in each one.
  - Health: First Name, Full Name, Health Percent, Health Value, Health Max, Health Lost.
  - Power: Power Percent, Power Value, Power Max.
  - Several items in one spot are split by " / ".
  - On the player, target, focus, pet and target-of frames, and the Resource Bars' health, power and druid mana bars.
- **Show Name** (on), above **Show Level**, on every unit frame, party, raid and boss frame.
- **Buff Amount** and **Debuff Amount** (1 to 12), under Buff Size and Debuff Size: how many show.
  - On the unit frames, and on the party and boss frames when their auras sit above or below the frame.
- **Show Speed** and **Hide Speed** in the Fading section of the player, pet, target, focus and target-of frames. They start at Instant.
- **Damage Trail** (on), under **Bar Edge Glow**: turn off the light strip that shows the health you just lost.
- **Threat Glow** and **Combat Glow** (on), in the Look section, after Class Colours.
- Target of Target and Target of Focus: **Mirror Bars** (on) and **Flip Portrait** (on).
- Cast bars: **Background** slider in every frame style.
- Forever Style:
  - **Power Height**: moves the line between health and power. The lowest step hides the power bar.
  - **Mana on Shapeshift**: in Cat or Bear Form the power bar splits in two, with your mana in the lower half.
  - Power Text: **> Value** and **> Percent** put the number at the bar's right end, as on Blizzard's frame.
  - Another player's name box takes their class colour while the frame's **Class Colours** is on.
  - **Dispel Highlight**: the plate's border lights up in the debuff's colour.
- Far-higher mobs and bosses show the skull on the level, as on Blizzard's frames.

### Party, Raid and Boss Frames
- Party: **Show When Solo** (off): your own party frame shows when you're not in a group. Needs **Show Player**.
- Party and raid: **PvP Flag** icon (off), in the Icons section: the member's faction crest while flagged.
- Raid: **Hide Player Frame in a Raid** (off): your player and pet frames hide in a raid.
- Boss frames, Addon Style: **Elite & Rare** icon (on), in the Icons section.
- With **Hide Player Frame in a Party** on, your pet's happiness shows on your pet's party frame.

### Flag Carrier Frames
- Rebuilt as FlareUI frames in your frame style: name, health, power, class portrait and a big faction crest.
- **Cast bar** (on).
- Left-click targets the carrier, right-click sets your focus, as on Blizzard's frames.
- **Flip Portrait** and **Mirror Bars** (on), and their own fonts in Unit Frames › Fonts.
- They show nothing Blizzard's frames don't: no range fading, no raid markers.

### Buffs & Debuffs
- **Hide Auras** tab: hide any aura on any frame.
  - Pick one of your buffs or debuffs, or add one by its spell ID.
  - Each hidden aura has a **Hide On** list: Buffs & Debuffs, Player, Pet, Target, Focus, Party, Raid, Boss.
  - The game lets addons hide buffs on you, your pet and your group, and debuffs on enemies. Debuffs on you or a friend only hide for a few spells, such as Sated.
- Edit Mode: the Buffs sample shows the weapon enchant row too.

### Action Bars
- **Status Colours** button, in Bars Appearance: pick the colours for Out of Range, Out of Mana, Unusable and On Cooldown.
  - Palettes: FlareUI, Blizzard, **Disabled** (the game's own colours) or your own.
  - The opacity slider sets how strong each colour is. On Cooldown at 0 means no dimming.
- **Equipped Item Border** (off), after Show Button Art: the button of an item you're wearing gets a border in its quality colour.
- **XP Bar Colours** button, at the bottom of Other Bars › XP Bar: XP, Rested XP, Rested Bonus, Quest XP, every reputation standing, Renown and Honor.
- Bag buttons bar: **Smaller Size** (Off), in its Edit Mode settings: 50% to 70%, below Blizzard's smallest Size.
- Combo Points bar (Resource Bars): **Style** in Edit Mode: **Classic** gems or the **Modern** bar, in any frame style.

### Minimap
- **Info Bar**: up to three cells along the bottom of the square map: **Left**, **Center**, **Right**. By Celbrund (GregDuhamel).
  - Each shows Gold, Bags, Durability, Framerate, Latency or Coordinates.
  - **Show Box** (on) and **On Mouseover** (off). Its own font in Minimap › Fonts.
  - Round minimap: the Center cell, inside the circle.
- **FPS/Ping on Clock**, in Map Tools: framerate and latency on the clock's tooltip.
- **Vehicle Exit Button** (off): Blizzard's exit arrow as a round icon on the map's edge.
- **Durability Warning** (off): a repair icon on the map's edge, yellow or red as your gear wears down.
- **Sundial Icon** (on): turn the day and night badge off.
- **Drawer Style**, first in Addon Buttons: **Disabled**, **Sundial** or **Blizzard** (a button under the calendar).
- **Faded Opacity** and fade groups for the minimap. Its icons hide while it's faded.
- Round minimap: the Group Finder, Vehicle Exit and Durability icons sit around the circle's lower left.

### Tooltips
- **Show PvP** (on), in Tweaks: the "PvP" line on flagged players and creatures is back.

### Quality of Life
- New **Systems** tab, with Camera and Gamepad.
- **Craft Batch Time** (off), in Gameplay › Convenience: the cast bar also shows the time left for the whole batch.
- **Accept Summons** (off), in Convenience: takes a summon for you after 10 seconds. A small window lets you cancel or go at once.
- **Combat Friendly Plates** (off), in Nameplates: friendly players' nameplates show only during a fight.
- **UI Scale**: a new scale asks you to keep it, and goes back after 15 seconds if you don't. `/fui scale reset` puts it back to the game's own.

### Other
- **Combat Text Size**, under Combat Text Font in General › Interface.
- **FlareUI Button** (off), in General › ESC Menu: a FlareUI button in the game menu.
- Buff Reminders: **Remind Before It Ends** also offers 15, 30 and 45 seconds.
- Bags: **BoE Text** (off): items that bind when equipped show BoE until bound.
- Bags: **Plain Empty Slots** (off): every empty slot in the combined backpack looks the same.
- Radial editor: spell tooltips show the rank, and pet spells are listed at the end of Spells.

## Changed
- Edit Mode:
  - Switches sit in two columns.
  - Cast bar sections share one order: Position, Bar Texture, Border Texture, Background, Height, Show Icon, Show Spell Timer, Show Spell Pushback.
  - The Player Cast Bar's own section is now **Behaviour**.
  - Width and Height sliders move in steps of 1. Your sizes stay as they are.
  - Percent sliders show plain numbers, so "100" fits its box.
  - **Off** is the first choice in every dropdown.
- Action Bars: **Status Colouring** never dims a button for the global cooldown, so wand shots no longer grey the whole bar.
- Action Bars: a button on cooldown is 25% grey by default, so its colour still shows.
- Unit frames: the level uses the name's size in Addon Style.
- Raid frames: **Power Height** defaults to 10.
- Default positions and sizes in FlareUI Style and Forever Style: focus, pet, target-of frames, totems and flag carriers.
- Addon Style: party frames' role icon sits bottom left; the pet's happiness face sits right of the frame.
- General page: tabs are **General** (with ESC Menu on top) and **Interface**.
- Quality of Life: Other is now **Convenience**; Map & Mail sits above it in Gameplay.
- Quest tracker with a gamepad: the right stick scrolls only after you click the tracker.
- Loot rolls: tighter padding, and the header matches the chat's and the meter's. By Nico-Mayer.
- French translation updated. By Brainc3ll.

## Fixed
- Action Bars: keybind text shows right after logging in, on every bar.
- Action Bars: stance and pet buttons no longer show a second border inside FlareUI's.
- Action Bars: no more Lua errors from the gamepad action bars.
- Round minimap: quest areas no longer draw past the circle.
- Quest Tracker: elite quests show their **+** again.
- Unit Frames: **Bar Edge Glow** no longer shows on a full health bar.
- Forever Style: the portrait ring no longer bends when Power Height changes.
- Edit Mode: the boss frames' sample buffs show right after a reload.

# FlareUI 6.10.1

A quick fix for the error spam some of you hit after 6.10, mostly in Gnomeregan.

## Fixed
- Party and raid frames: the **Dispel Highlight** pulse no longer floods the error log in fights.
  - It came from debuffs the game keeps hidden from addons, as on some Gnomeregan mobs.
- Buffs & Debuffs: the weapon enchant row no longer causes errors in combat.
  - When the game hides your buffs from addons, the row stays where it was.
- Quest tracker: focusing a quest in combat no longer causes a blocked-action error.
  - The new focus is set as soon as the fight ends.

# FlareUI 6.10

**Restart the game fully after updating** (not just /reload): this version adds new files.

The big tidy-up. Edit Mode dialogs now open one section at a time, in the same order on every frame, so no more scrolling through 40 rows. The settings window got the same care: a **General** page, clearer tabs, dropdowns that look like dropdowns, and notes that tell you why something is greyed. We cut options nobody needed, merged the ones that belonged together, and added a few you asked for. Every new option starts off. Thanks to Kabaday for the help on the loot roll window!

## Highlights
- **Edit Mode:** one section open at a time, and the same sections in the same order on every frame.
- **Settings window:** a new **General** page, tidier tabs, and dropdowns with a proper arrow.
- **Loot rolls:** each open roll gets its own card, with Need above Greed. By Nico-Mayer.
- **New options** for vendors, resurrections, bags, the meter and tooltips. All off until you turn them on.

## New

### Unit Frames
- **Bar Edge Glow** (off), in each frame's Look section in Edit Mode: a bright line and a soft glow at the front of the health bar. It flashes when health changes.
- **Damage Trail** on the Resource Bars' health bar too.
- Works with **Smooth Animated Bars**: with its option for other addons' bars on, its fill shows on FlareUI's health and power bars.
- Edit Mode samples:
  - The **Five-Second Rule** spark runs across your mana bar.
  - Rogues and druids see sample combo gems in the ring styles.
- Party and raid frames: **Dispel Highlight** pulses fast. In the ring styles, the portrait ring pulses too, in the debuff's colour.
- Resource Bars: **Absorb Texture** for the health bar. Its Edit Mode sample shows incoming heals and a shield.
- Forever Style: a frame's **Scale** is saved per Edit Mode layout.

### Bags & Looting
- **Bank Window** section: **Columns** (Default), **Gaps Between Bags** (off) and **Tight Spacing** (off).
- **Combine Empty Slots** (off), in Bag Window: your empty slots show as one, after your items, with the number of free slots on it.
- **Auto Open Containers** (off), in Tools: clams, loot bags and lockboxes you've unlocked open by themselves.
  - Not in combat, and not at a vendor, mailbox, bank, auction house or in a trade.
- A note at the top of the Bags tab says why the options are greyed: another bag addon, or combined bags off.
- Works with **Syndicator**: pointing at your gold lists every character's gold.
- Works with **Hide 2FA Bag Slots**.

### Meters
- **Report to Chat**, in a meter window's right-click and gear menus: your top 3, 5 or 10 to Party, Raid, Instance, Guild, a whisper, or Say in instances. After combat only.
- **Close Tab** and **Close Window** in the same menus.
- **Reset on Leaving a Group** (off), in Tweaks.
- **Pull Warning Sound** (off), in Threat Bars: a sound as Pull Warning starts. Never while you hold the mob.

### Tooltips
- **Health Bar** in FlareUI's look: the FlareUI Forever texture in a thin border that takes the tooltip's border colour.
  - Now a choice, on the Content tab: **Off** (as before), **Below** the tooltip or **Inside** it.

### Quality of Life
- **Repair with Guild Funds** (off), in Vendor: Auto Repair uses your guild bank first, when your rank allows it.
- **Accept Resurrections** (off), in Other: never while you or the caster is in combat.
- **Coordinates on the World Map**, in Map & Mail: your coordinates and the cursor's. It's the same as Blizzard's own two options.

### Chat
- A tab's glow takes the colour of its newest message: green for guild, blue for party, and so on.
- Gamepad mode: Blizzard's chat tabs look like FlareUI's.
- Works with **Misspelled: Forever**: its highlights stay on the words.

### Action Bars
- **How Fake CM Works**: a short note at the top of the Fake CM tab.
- With **Skin Action Bars** on, a pet spell set to autocast gets a slowly pulsing gold border.

### Other
- Battleground Objectives: a **Scale** slider in its Edit Mode dialog.
- Loot rolls: each roll shows your choice, your roll and who leads, plus item level and slot. By Nico-Mayer.
- The chat preview shows item and spell link icons when you point at **Item and Spell Icons**. By parchinskiy.

## Changed

### Edit Mode
- One section opens at a time. Each frame remembers the last one you opened.
- Every unit frame, party, raid, boss and resource bar dialog uses the same sections in the same order: Size, Text, Look, Behaviour, Cast Bar, Auras, Icons, Fading.
- Dialogs grow taller, up to about two thirds of your screen.
- Shorter labels: **Power Height**, **Background**, **Bar Animations**, **Frame Gap**, **Group Gap**, **Group Order**. Search still finds the old names.
- Party: **Pets & Targets** section with the Pets and Party Targets choices.
- Classic party frames: **Dispel Icons** can sit anywhere the auras can.
- **Pet Happiness** is one choice: Off or where it sits.
- The first-time hint stays until you pick a FlareUI frame.

### Settings window
- **General** page (was Settings), with two tabs:
  - **Interface:** UI Scale, Global Font. Custom Scale and Text Scale are sliders now.
  - **Advanced:** Sync Blizz UI, Blizzard Frames (Move Any Window) and Language.
- Move Any Window, Sync Blizz UI and UI Scale work with Quality of Life off.
- Dropdowns lost their two side arrows and show a down arrow inside the box.
- Fold sections with the arrow left of their title. **Reset** shows only when something differs from its default.
- A module that's off lists what it gives. After **Turn On**, a banner offers the reload it needs.
- Pages that keep options in Edit Mode say so under their description.
- Tabs renamed or merged:
  - Action Bars: **Other Bars** (XP Bar and Hide Bars together).
  - Chat: **Behaviour**. Tooltips: **Content**.
  - Minimap: **Map** and **Addon Buttons**. Quest Tracker: **Look** and **Behaviour**.
- Unit Frames › Fonts: pick a **Frame** to see its fonts, and **Copy to All Frames**.
- Quality of Life: Convenience is now **Quests & NPCs**, **Map & Mail** and **Other**. The nameplate section is **Enemy Plates**.
- Profiles: **What a Profile Saves** opens the page, and Reset FlareUI sits in the Profile section.
- The setup tour offers Buff Reminders and has its own switch for Bags & Looting.

### Options merged
- **Automate Quests** (was Auto Accept Quests and Auto Turn-In Quests). If you had either one on, you get both.
- **Collapsible Bag Bar** now also removes the bag bar's frame (was two options). Either one on gives you this one on.
- **Gryphons** in Quality of Life › Hide Clutter: **Shown**, **Behind Bars** or **Hidden** (was Hide Gryphons and Gryphons Behind Bars). **Raid Manager** moved there too.
- **Skin Item Slots**: **Off**, **Thin Borders** or **Thick Borders**. Skinned slots always use rarity colours.
- **Meter Tab in the Chat**: one dropdown. **Disable** (the default), **Open When Clicked**, or tick **Open In Combat**, **Open In a Group** and **Open At Login** together.
- **Addons in the Drawer**: **None** turns the addon button drawer off (its own switch is gone).
- Separate Window and Threat View in Combat: turning one on turns the other off.

### Always on now (switches removed)
- **Damage Trail** on every frame.
- **Highlight Purgeable Buffs**, on enemy targets and boss frames.
- **Threat Glow** and **Combat Glow**.
- **Timer Colour**, **Latency Zone** and the spell rank on cast bars (lower ranks only, like "R2").
- Quest Tracker: **Quest Count**, **Hide When Empty**, **Wrap Long Text** and **Collapsible Zones**.
- Chat: link tooltips on mouseover and copyable links.
- Meters: the **Ready Check** and **Countdown** buttons.
- Buff Reminders: **Ignore Members Out of Range**.

### Other changes
- Action Bars: **Dim on Cooldown** is part of **Status Colouring**.
- Action Bars: **Bar Scale** is now **Button Scale**, in Button Appearance. Button Text joined Button Appearance.
- Buffs & Debuffs: weapon enchants get their own row under your buffs, so every buff row lines up.
- Meters: **Tank's Lead** shows after the numbers, like "100% (+25%)".
- Loot rolls: each roll still to decide gets its own card, with Need above Greed and Pass beside them. By Nico-Mayer.
- Chat: Formatting's note says it only works outside dungeons, raids and battlegrounds.

## Defaults
- Buffs & Debuffs › Buffs: **Size** 30, **Icons per Row** 8, **Max Icons** 16.
- Meters: **Tank's Lead** on.
- Resource Bars: **Queued Attack Colour**, **Stand-Still Zone** and **Waiting State** on.
- Only settings you never changed take the new defaults.

## Removed
- Quality of Life: **Flag Carrier Frames** and **Durability Warning** (Buff Reminders' Low Durability covers it).
- Cast bars: **Channel Ticks** and **Spell Queue Window**.
- Quest Tracker: **Focus Buttons** and **Auto Quest Buttons**. Quest Icons still focus a quest when clicked.
- Chat: **Colon After Names**.
- Tooltips: **Show Guild Ranks**.

## Fixed
- Target frame: a friendly target's buffs no longer show twice, once with a white border.
- Gamepad: D-pad Up and Down work on the action bar again with the quest tracker on. The tracker list scrolls with the right stick.
- Click-cast addons work on the player, target, focus and other single frames again.
- Action bar 1 shows its keybinds right after logging in.
- Quest tracker: Shift-click links a quest into any open chat box, like Whisper Messenger's. By parchinskiy.
- Action bars: a stance, pet or possess bar left 1 pixel wide is sized again, so Edit Mode can select it.
- Chat: tab glow works again.
- Gamepad mode: the chat tabs are no longer dim and fade with the chat.
- Settings: lists only make room for a scrollbar when they need one. By parchinskiy.
- Settings: the Bags & Looting preview shows the search box, sort button and Category Filters. By parchinskiy.

## Translations
- French: the 6.9 text. By Braincell1980.

# FlareUI 6.9

Version 6.9. (Nice!) All your fading now lives in Edit Mode. The chat, the Damage Meter and the threat window can join fade groups at last, every Visibility list learns **In an Instance**, and Edit Mode's settings open right next to the frame you clicked. Also new: Chinese, by AreChen, and a pile of quest tracker and chat options you asked for.

## Highlights
- **Fading in Edit Mode:** the chat, the Damage Meter and the threat window get a **Fading** section in Edit Mode, like every other frame. They can join fade groups.
- **Edit Mode settings open next to the frame you select**, and stay on screen.
- **In an Instance** on every Visibility list.
- **Chinese:** Simplified and Traditional Chinese, by AreChen.

## New

### Chat
- **Tab Sets Channel** (off), in Chat › Tweaks: clicking a tab that shows only one kind of chat, like Guild or Party, makes it the kind you type in.
  - It goes by what the tab shows, not its name.
  - A tab that shows several kinds keeps your current one. Party or Raid when you're not in one: Say.

### Quest Tracker
- **Quest Icons** (off), in Display: Blizzard's round icons before each quest, "…" while in progress and "?" when ready to turn in. Click one to focus the quest.
- **Show Complete Tag** (on), in Display: turn it off and finished quests lose "(Complete)" and the green colour.
- **Show Untracked Quests** (off), in Quests: with zone headings, quests in your zone that you don't track show too, dimmed. Shift-click one to track it.
- **Collapsible Zones** (on), in Quests: click a zone heading to fold its quests. The heading now shows Blizzard's fold arrow.

### Bags & Looting
- **Combined Backpack**, in Bag Window: the same as Blizzard's **Use Combined Bags**. The options below it need it on.
- **Sort Bags on Open** (off), in Tools: your bags tidy themselves each time you open them, as the broom button does. Not in a fight, and not at a vendor, the mailbox, the bank, the auction house or a trade. By ronborens.

### Buff Reminders
- Paladins: right-click the aura reminder for **Aura to Cast**: **Last Used** (the default) or one aura.
- Elixirs, in Reminders › Consumables, by GregDuhamel from Celbrund's idea:
  - **Elixirs to Watch**: **Ticked Ones** (as before) or **Those in Your Bags**, every elixir you carry with nothing to tick.
  - **Elixirs to Keep Up**: **Each of Them** (as before) or **Any One of Them**, one icon until any of them is on you.
  - Lower ranks of an elixir count, and a click drinks the best one you carry.
  - The flask reminder can be clicked to drink your flask.

### Quality of Life
- **Better Camera** is now two sliders in Gameplay: **Max Zoom** and **Zoom Speed**.
  - Both start at Blizzard's own values. If you had Better Camera on, you keep its values.
  - Zoom Speed is greyed in Gamepad mode.

### Player Cast Bar
- Its **Visibility** in Edit Mode has **Never**: it hides FlareUI's cast bar and keeps Blizzard's hidden too, so only the player frame's own Cast Bar shows.

### Translations
- **Simplified Chinese** and **Traditional Chinese**, by AreChen. Pick them in Settings › Language.
- French: all the 6.8.1 and 6.8.2 text, by Braincell1980.

## Changed

### Fading
- The chat's, the Damage Meter's and the threat window's fading options moved from the settings window to Edit Mode. Your choices carry over.
  - The chat's Visibility has a new **New Messages** choice: a new line, or closing a quest or vendor window, brings it back. Typing always shows the chat.
  - The chat and the meter have a **Fade Delay**: how long they stay before fading.
  - The meter's Visibility has **Never** (the old Hidden). Its Show on Mouseover is now the Mouseover choice.
  - The threat window starts on **Same as Meter**, as before.
  - The Chat and Meters pages have a **Fading in Edit Mode** button.
- Every Visibility list has **In an Instance**, under In a Group.
- **Has an Attackable Target** is now **Attackable Target**.
- **Fade In Speed** and **Fade Out Speed** are now **Show Speed** and **Hide Speed**.

### Edit Mode
- The settings dialog opens next to the frame you select, not in a corner of the screen. FlareUI's own Fading box stays right under Blizzard's dialog, on screen.
- Fading sections open and close, and start closed, on every frame.
- The Damage Meter's dialog no longer shows **Text Size**. The meter's fonts are in Meters › Fonts.

### Unit Frames
- **Full Player Names** now works on party frames in every style. The focus frame always shows first names.
- FlareUI Style: the portrait ring is a softer bronze, closer to the frame's border.

### Other
- **Nameplate Font** also sets the names over characters in the world. They change after a full restart of the game.
- The hunter pet reminder stays quiet with the **Lone Wolf** talent.

## Fixed
- Bags: you can right-click items again after opening the bags through the crafting bag icon in a fight. By parchinskiy.
- Damage Meter: closing Edit Mode no longer shows an error. By tinker-n-tailor.
- Fonts: a font from another addon, like SharedMedia, applies even when that addon loads after FlareUI.
- Settings window: small buttons no longer grow when you point at them.

# FlareUI 6.8.2

A round of fixes from your reports: chat tabs you can see in Gamepad mode, no more reload prompts when you switch to an alt, and two small options from the general chat.

## New

### Bags & Looting
- Bag Window: **Combined Backpack**, the same as Blizzard's **Use Combined Bags**.
  - The options below it need it on, so you no longer have to find Blizzard's option to use them.

### Player Cast Bar
- Its **Visibility** in Edit Mode has a new **Never** choice.
  - It hides FlareUI's cast bar and keeps Blizzard's hidden too, so only the player frame's own **Cast Bar** shows.

## Fixed

### Chat
- Gamepad mode: the chat tabs stay fully visible. They faded out each time the controller left the chat.

### Sync Blizz UI
- Switching from your main to an alt no longer asks for a reload when nothing changed.
  - An alt only copies settings your main really changed.
  - It only asks for a reload when one of those needs it.

### Buff Reminders
- Fortitude: a player with Forever's **First Aid Kit** buff from a campfire counts as having it. The two can't stack.
- A new custom reminder shows in the settings list right away.

### Unit Frames
- **Highlight Purgeable Buffs** only applies to enemies. A friendly target's buffs show normally, with no white border.

### Other
- Flight Timer: a route timed for the first time reads **New Route** and counts up. It used to say "Learning".
- Quest Tracker: "(Complete)" uses the game's own word in languages FlareUI isn't translated into yet.

# FlareUI 6.8.1

A quick follow-up to 6.8: the Damage Meter settings open again, party frames show the debuffs you can dispel, and paladins pick which aura the reminder casts.

## New

### Buff Reminders
- Right-click the paladin aura reminder for **Aura to Cast**.
  - **Last Used** (the default): a click casts the last aura you had up, such as Retribution or Concentration after you die.
  - Or pick one aura to always cast: Devotion, Retribution, Concentration, a resistance aura or Sanctity.
- Custom reminders: type a food's or potion's name while it's in your bags, and the reminder gets its icon and a click uses it.
  - To track a food's buff, add the buff's name too, for example `item:4593, Well Fed`.

### Translations
- French: all the 6.8 text is translated. By Braincell1980.

## Fixed

### Damage Meter
- The Damage Meter settings page opens again. 6.8 showed an error there.
- A meter window on its own no longer gets its Threat tab back.

### Party and Raid Frames
- Debuffs you can dispel show in your **Debuffs** place again while **Dispel Icons** are on.
  - Before, they only showed as the small type symbol in the middle of the bar.
  - This affected every party style, the raid frames and the main tank frames.

# FlareUI 6.8

**Restart the game fully after updating** (not just /reload): this version adds new files.

**Please check your settings.** Some defaults changed in this version (listed under **Defaults**). Options you already set yourself keep your choice; options you never touched take the new default.

A big one. The damage meter learns to dock like chat, health bars show the hits you take, chat tabs stop glowing at trade chat, and the bags get one-click filters again. Five contributors this time: pkejval made a lot of FlareUI do less work, tinker-n-tailor fixed the Group Finder Icon and the level disc, Nico-Mayer polished the loot roll preview, Braincell1980 caught French up, and parchinskiy's original filter buttons are back as an option.

## Highlights
- **Damage Meter**: extra meter windows dock as tabs on the first window, like chat tabs. Any of them can move out to its own window and back.
- **Damage Trail** on health bars: the health you lose stays for a moment in a light colour, then shrinks away.
- **Fade In Speed** and **Fade Out Speed** replace the single Fade Speed everywhere.
- **Tab Glow**: pick which messages make a chat tab glow, and mute single tabs.

## Defaults
- Tooltips: **Party/Raid Auras** is now **Always**. The buff and debuff icons on party and raid frames show their tooltip.
- Loot Feed: **Alignment** is now **Center**.
- New default spots for the health, power, mana, swing, flight and duration bars, the Loot Roll Window, toasts and the battleground objectives.
  - Only frames you never moved take the new spot.

## New

### Unit Frames
- **Damage Trail** (off), in the **Frame** section of the player, target, focus, pet, party, raid and boss frames in Edit Mode.
  - The health you lose stays for a moment in a light colour, then shrinks away.
  - Healing has no trail. It works in fights too.
- **Flag Carrier Frames** (off, needs a reload), in Unit Frames › Enable Frames.
  - Blizzard's battleground flag carrier frames, moved and placed in Edit Mode as a FlareUI frame.
  - They start where the first boss frame sits.
- FlareUI Totems (your totem timers): a **Fading** section in its Edit Mode dialog.
  - Fade Group, Visibility, Fade In Speed, Fade Out Speed and Faded Opacity, as on the other frames.
  - Visibility has a new **Never** choice: the totems stay hidden. Edit Mode still shows them.
  - Totems you can't see can't be right-clicked away by accident.
- The player and pet frames can join a fade group.

### Damage Meter
- Extra meter windows dock as tabs on the first window, like chat tabs.
  - Open and close them from Blizzard's gear menu. You can have up to two meter windows.
  - The Threat tab is always the last tab.
- Right-click a docked tab, a window's title or its gear menu: **Move to Own Window**.
  - The window opens under the first window, or above it when the first window sits low on the screen.
  - A window on its own has no Threat tab. The threat list stays on the first window.
  - Its spot and size are saved. Right-click it for **Dock as a Tab** to bring it back.
  - In a fight, the move waits until the fight ends.
- Threat: right-click the Threat tab for **Move to Own Window** (the same as Threat › Separate Window). Right-click the threat window's header for **Dock as a Tab**.

### Chat
- **Tab Glow**, in Chat › Frame: tick which messages make a tab glow.
  - **Say**, **Yell**, **Party**, **Raid**, **Guild**, **Whispers** and **Channels** (all ticked). **None** turns the glow off.
- Right-click a chat tab for **Mute Tab**: that tab never glows. The entry then reads **Unmute Tab**.
  - Mutes are kept after a reload.

### Quest Tracker
- **Keep Quest Focus** (off), in Quest Tracker › Quests. A quest you accept doesn't take the focus; the quest you had focused stays focused.
- With Questie loaded, right-click a quest for **Hide Questie Icons** or **Show Questie Icons**. It hides that quest's icons on Questie's map, as Questie's own menu does.

### Bags & Looting
- **Category Filters** (Bags & Looting › Tools) is now a choice of three (Off):
  - **Drawer**: the filter button and drawer, as before.
  - **Buttons**: the four filters in a row by the search box, one click each. Click the lit one again, or right-click it, to clear it. From parchinskiy's first design.
  - Buttons needs the combined backpack with room to spare. In a narrow backpack or separate bags you get the drawer.
  - If you had Category Filters on, you get Drawer.
- Loot Feed: **Alignment** has a new **Center** choice.

### Buff Reminders
- Right-click the blessing reminder for two new menus:
  - **By Class**: a different blessing for each class.
  - **Group Members**: a different blessing for one player.
  - A player's pick wins over their class's, and the class's over the blessing for everyone.

### Resource Bars
- Main-hand swing bar: **Queued Attack Colour** (off), in its Edit Mode dialog.
  - The bar takes a colour for each queued attack: Heroic Strike (gold), Cleave (blue), Maul (orange-red) and Raptor Strike (green).
  - Pick the colours in **Bar Colours** › Swing Timers. A custom queued colour you had becomes the Heroic Strike colour.

## Changed

### Fading
- **Fade Speed** is now two options: **Fade In Speed** and **Fade Out Speed**.
  - In every Edit Mode Fading section, and in the Chat, Damage Meter and Buff Reminders settings.
  - Your old Fade Speed carries over to both.
  - A unit frame on its own still fades at once. In a fade group it uses the group's speeds.

### Unit Frames
- Portrait choices are now **None**, **2D** and **Class Icon**. The picture was called 3D before; it is the same picture.
- Boss frames: **Portrait** is now a None / 2D choice. It's hidden in the ring styles.
- With Forever Faces installed, the ring's dark disc hides on 2D portraits, so its 3D faces show again.
- Ring styles: the level disc shows the number only ("21", not "21+"). The ring's dragon and star already show elite and rare. By tinker-n-tailor.

### Minimap
- **Group Finder Icon** only shows while you're in a queue, listed in the group finder or in a battleground, like Blizzard's eye. Edit Mode still shows it.

### Chat
- Tabs only glow for messages people write. NPC lines, loot and system messages no longer light a tab.
- The glow is softer.

### Bags & Looting
- The Loot Rolls preview in the settings uses your **Frame Opacity**, the thin border and FlareUI's language. By Nico-Mayer.

### Performance
- Less repeated work in the action bars, buff reminders (most in raids), the damage meter after fights, bags, the quest tracker, proc glows and the loot roll window. By pkejval.

### Translations
- French: all the 6.6 and 6.7 text is translated. By Braincell1980.

## Fixed

### Action Bars
- A hidden stance, pet or possess bar no longer leaves a gap in Edit Mode's bar stack after you change forms.
- Turning **Hide Stance Bar** off (or the Action Bars module off) brings the bar and its Edit Mode box back at once, without a reload.
- A stance bar you can see always has a box you can click in Edit Mode.
- Cooldown numbers show above **FlareUI Borders**.

### Bags
- Cooldown numbers show above the bag slot overlays.
- Turning Blizzard's **Use Combined Bags** back on keeps FlareUI's combined backpack.

### Buff Reminders
- **Ignore Members Out of Range** now works. Outside fights, members past follow distance (about 28 yards) don't count as missing a buff.

### Minimap
- Clicking the **Group Finder Icon** opens the group finder again. By tinker-n-tailor.

### Other
- Player cast bar: it draws above the resource bars.
- World map: with Leatrix Maps loaded, FlareUI no longer moves the world map or restyles its coordinates. Leatrix Maps does both.
- Quest tracker in Gamepad mode: clicking a quest no longer shows an error. The quest log opens on that quest the next time you open it with your controller, and the D-pad scrolls the tracker.

# FlareUI 6.7

**Restart the game fully after updating** (not just /reload): this version adds new files.

Your feature ideas, delivered by the dozen. Loot rolls get their own window, frames glow when you pull aggro, and the quest tracker learns some new tricks. A big shoutout to parchinskiy, who keeps quietly making the bags faster and steadier, and thanks to tinker-n-tailor and Nico-Mayer for their first features.

## New
- Bags & Looting › Loot Rolls: **Loot Roll Window** (off, needs a reload), by Nico-Mayer.
  - It replaces Blizzard's roll frames: Need, Greed and Pass for each item, everyone's choice and roll as they come in, who leads and who won.
  - A roll you pass on leaves the window. The icon at the top opens Blizzard's loot history.
  - **Frame Opacity** (100%), and a **Loot Rolls** entry in the Fonts tab.
  - Move and scale it in Edit Mode as "FlareUI Loot Rolls". A spot you gave Blizzard's roll frames carries over.
- Minimap › Tweaks: **Group Finder Icon** (off), by tinker-n-tailor.
  - A small icon in place of Blizzard's large queue eye. Click it to open the group finder.
  - In a queue it works like Blizzard's eye: point at it to see the queue, click for the scoreboard or your listing, right-click for the queue menu.
- Unit frames › Look: **Threat Glow** (on) on the target, focus, pet, party, raid and boss frames.
  - The frame's border pulses in the threat colour while there's aggro, and so does the portrait ring. Forever Style's plate glows too.
  - Party and raid frames show the member's aggro. Target, focus and boss frames show your threat on them.
- Player frame › Look: **Combat Glow** (on). In a fight, the border and portrait pulse red. With aggro, the threat colour shows instead.
- Resource Bars: **Duration Bars** (off). Your breath, fatigue and feign death bars in FlareUI's style, in place of Blizzard's.
  - Move and size them in Edit Mode. Pick each one's colour in **Bar Colours**.
- Quest Tracker:
  - **Auto Quest Buttons** (off, Display): a **!** and a **?** in the tracker's header turn Auto Accept and Auto Turn-In on and off.
  - **Focused Quest First** (off, Quests): the quest you focus on the map moves to the top. With zone headings, its zone moves up with it.
- Player cast bar: **Show Spell Rank** (off, Edit Mode), under Show Spell Timer. Your cast reads "Holy Light (R2)".
- Buff Reminders › When and Where: **Ignore Members Out of Range** (off). Members too far away don't count as missing a buff.
- Quality of Life › Convenience: **Cast on Key Press** (off). Spells go off when you press the key, not when you let go.
- Minimap › Addon Buttons: **Drawer Button Size** (100%), up to 150%.
- Radial Menu: 12 more emotes (Out of Mana, Thank, Cheer, Hello, Bye, Follow Me, Help Me, Heal Me, Incoming, Attack My Target, Charge and Flee), and a **Custom Emote** for any emote command.

## Changed
- Unit frames: **Threat Glow** and **Rest & Combat Glow** moved from Icons to Look, as Threat Glow and Combat Glow.
  - If you had turned one off, its new switch starts off.
  - The resting glow on the player's portrait now turns on and off with the **Resting** icon.
- Minimap: a new **Addon Buttons** section holds FlareUI Minimap Button and everything about the Addon Button Drawer.
- XP bar: **Show Bubbles** is now **Bubbles**: Off, 10 or 20. Your choice carries over.
- Quest Tracker:
  - Finished quests show a green **(Complete)** after their name, also when collapsed.
  - Quest item buttons get FlareUI's frame border.
- Chat: a tab with unread messages glows softly behind its name, in bronze, or your whisper colour for whispers.
- Hide Clutter: **Loot Alerts** is now called **Loot Toasts**.
- Resource Bars: **Druid Mana** and **Paladin Seals** can be set up and placed in Edit Mode on any class. They still only show where they apply.
- Cooldown Manager: the Tracked Buffs icons have the same border as the cooldowns.
- Edit Mode: the HUD Tooltip sample matches FlareUI's look, and the battleground score frame is fully opaque.

## Fixed
- Action bars: a hidden stance bar no longer comes back when you change forms in a fight. The same goes for hidden pet and possess bars.
- Action bars: changing forms no longer freezes the game for a moment with the stance bar hidden.
- Action bars: with **FlareUI Borders**, pet bar icons no longer poke out of their border.
- Buff Reminders: in an open-world group, reminders no longer vanish:
  - **Thorns** on Tanks Only reminds you about yourself when the group has no tank.
  - **Only Provider** only counts players of your class that you can see.
- Bags: the keyring and crafting bag show the first time you open the backpack after a /reload in a fight, by parchinskiy.
- Bags: picking up items no longer rebuilds the whole backpack, so bag updates are lighter, by parchinskiy.

# FlareUI 6.6

Tooltips got tidied up, the mouse ring rode off into the sunset, and a big stack of your Discord reports is fixed.

## New
- Tooltips › Look: **Tooltip Corner** (Auto). Pick the corner of the HUD Tooltip box your tooltips grow from. Auto keeps Blizzard's nearest corner, which can flip sides when you move the box.
- Tooltips › Mouseover: **Offset X** and **Offset Y** (0). Move tooltips that follow your mouse up to 50 pixels away from it.
- Quality of Life › Hide Clutter: **Loot Alerts** (off). Hides Blizzard's loot pop-ups:
  - items you win or loot
  - upgrades
  - money

## Changed
- Tooltips: the settings are reorganised.
  - The Settings tab now has **Look**, **Mouseover** and **Visibility**, in that order.
  - **Mouseover** is one dropdown: **All Tooltips**, **None**, or tick only the kinds you want. It replaces the Mouseover switch and the six switches per kind. Your choices carry over.
  - The old Visibility tab is now **Tweaks**. It holds the switches for what tooltips show.
- Quality of Life: the **Mouse Ring** is gone. It made FlareUI heavier, few players used it, and cursor addons do it better.
- Chat: with Chattynator loaded, FlareUI's chat stays off and leaves the chat to Chattynator. The Chat page says why.
- Buff Reminders › Visibility: the **In Combat** choice is gone. It did nothing: the reminders always hide in fights.
- Minimap: while OneForAll's **Collect minimap buttons** is on, **Addons in the Drawer** lists only the addons that can go in the drawer.

## Fixed
- Action bars: a hidden stance bar no longer comes back when you change forms in a fight. The same goes for a hidden pet bar.
- Fade groups: a bar that's off (in Edit Mode, or the pet bar with no pet) no longer shows its group when you point at its spot.
- Quality of Life › Vendor: **Enhanced Vendor Purchases** works again. Shift-click a vendor item to see the Stack and MAX buttons.
- Bags: sorting no longer stalls with the keyring or crafting bag sections shown, by parchinskiy.
- Party frames (ring styles): the level number shows in its circle again.
- Meters: a second meter window drags by its header again. Before, only a tiny spot next to the timer worked.
- Chat (Gamepad mode): the chat tabs stay fully visible. They stayed faint until you pointed the mouse at them.
- Radials (controller): **Release the Stick to Use** works when you roll the stick from one direction to the next.

# FlareUI 6.5.1

A quick round of fixes. Gamepad players get their chat tabs back, and FlareUI now gets along with ClassicUI Forever.

## New
- Edit Mode: the **HUD Tooltip** box shows a sample tooltip. You can still see and drag it with the overlays hidden (the eye button).

## Changed
- Action bars: **Show Button Art** no longer hides Action Bar 1's bar art. Edit Mode's **Hide Bar Art** controls it again, as before 6.5.
- Profiles: pasting an Edit Mode layout code into **Import** now tells you where it goes: Esc › Edit Mode › Layout › Import.
- Resource Bars › **Druid Mana**: the tip now points to **Mana on Shapeshift** in the player frame's Edit Mode settings, for a mana bar on the frame itself.
- French: the 6.5 phrases now match the rest of the translation, by Braincell80.

## Fixed
- Gamepad mode: the chat tabs show again. They worked, but you couldn't see them.
- About: the Discord button opens a working invite.
- With ClassicUI Forever:
  - Faded action bars no longer show up when you point at another bar.
  - Tooltip **Frame Opacity** works.

# FlareUI 6.5

**Restart the game fully after updating** (not just /reload): this version adds new files.

Bankers and vendors stop making small talk, full bags make room for your loot, and FlareUI now speaks Dutch. Plus a big stack of fixes from your Discord reports.

## New
- Language: **Nederlands** (Dutch), by LouCryox. Pick it in Settings › Language.
- Quality of Life › Convenience:
  - **Skip Gossip** (off): bankers, vendors, trainers, innkeepers and flight masters open their window at once when they have nothing else to say. Hold Shift to talk normally. It never skips in dungeons or raids.
  - **Delete Junk When Full** (off): with your bags full, clicking an item in the loot window first deletes your cheapest grey item to make room. The chat says what was deleted.
- Minimap: **FlareUI Minimap Button** (on), above **Addon Button Drawer**.
  - It shows on the minimap, or in the drawer when the drawer is on.
  - Right-click the button to hide it. Turn the switch back on to bring it back.
- Bags & Looting › Item Slots: **Skin Item Slots** (on). Turn it off to keep Blizzard's slots, for example when another addon skins your bags.
- Bags & Looting › Fonts: **Item Level**, for the item level numbers in your bags and on the character sheet. It shows while **Item Level** is on.
- Unit frames › Health Text and Power Text:
  - **Value | Percent**
  - **Value <  > Percent** (Forever Style only): the value at the bar's left end, the percent at its right end.
- Bags: pointing at the keyring or crafting bag icon lights up its slots in the backpack.
- `/fui padlog`: prints the right stick's moves while a controller radial is open, for "Release the Stick to Use" reports.

## Changed
- Action bars: with **Show Button Art** off, Action Bar 1 drops its bar art too, as if its **Hide Bar Art** were on in Edit Mode.
- Bags: **Upgrade Arrow** is gone. Its guesses weren't reliable. Addons like Pawn do this properly.
- Bags & Looting › Item Slots: **Rarity Colours** now comes before **Thicker Borders**. Both grey out when **Skin Item Slots** is off.
- Bags: item level numbers use the new **Item Level** font, not **Bag Items**. If you had set a Bag Items font, set Item Level too.
- Unit frames: **Value [Max]** now sits right below **Value** in the Health Text and Power Text lists.
- French: every phrase added since 6.2 reviewed, and wording made consistent, by Braincell80.

## Fixed
- Chat: switching tabs could make the chat disappear until /reload.
- Chat: separate chat windows no longer show Blizzard's own tab next to FlareUI's.
- Edit Mode: switching between layouts no longer sends frames back to their default spots. Frames you never moved in one layout keep their spots from the other.
- Meters › threat window:
  - It no longer snaps with **Snap to Elements** off.
  - The arrow keys move it straight, not diagonally.
  - It stays put after /reload. Your saved spot may shift once after updating.
- Meters: the meter is styled from the first fight after a reload.
- FlareUI Style: auras and cast bars draw above the portrait ring and the elite dragon, instead of under them.
  - Unit frames, boss frames and party frames
- Spellbook: with **Keep Page 1 in Stealth**, spells on bar 1 no longer glow as if they weren't on your bars.
- Cooldown Manager: with **Skin Cooldown Manager** on, the Utility icons' border now matches the Essential icons'.
- Mail Address Book: **Your Characters** fills in the first and last name. Each alt shows its full name after you log in on it once.
- Unit frames: "Ghost" is now translated.

# FlareUI 6.4.1

A round of fixes from your reports, plus one small option for poison users.

## New
- Buff Reminders › When and Where: **On Mouseover** is a new **Where** choice for Class Buffs, Weapon Buffs, Pets and Consumables.
  - Those icons stay hidden until you point at the reminder row.
  - They can still be clicked, and they don't play the reminder sound.

## Changed
- Gamepad mode: the chat uses Blizzard's own tabs.
- Raid frames: with **Groups** set to Columns, **Growth** is back, as From the Middle, Right or Left.
- Meters: hovering the meter while it fades holds it in place. Moving away lets the fade finish.
- Minimap: while OneForAll's **Collect minimap buttons** is on, FlareUI leaves addon buttons on the minimap for it.

## Fixed
- Gamepad mode: closing a chat box with Esc no longer breaks the controller.
- Player cast bar: **Latency Zone** shows each cast's real delay, not the game's slow network average.
- Action bars: buttons no longer flash as the global cooldown ends on bars with a **Visibility** or a **Fade Group**.


# FlareUI 6.4

**Restart the game fully after updating** (not just /reload): this version adds a new file.

Fonts moved out of Edit Mode and back to the settings panel. Borders can now be turned off entirely, and party and raid frames can sit flush against each other. Every line of settings text got shorter, too.

## New
- Borders: **None** is the first choice in every Border list.
  - Unit frames, party, raid and boss frames
  - Cast bars, resource bars and the XP bar
- XP bar: **Border** (FlareUI Thin), in its Edit Mode window.
- Forever Style: every frame off the bronze plate now has Border options.
  - Simple pet, simple target of target and target of focus
  - Raid Style party frames and raid frames
  - Party pet and target frames, and their cast bars
- Party frames, Raid Style:
  - **Power Text** (None)
  - **Power Bar for Mana Users Only** (off)
  - **Dispel Icons** (Middle of the Health Bar) now has a place, like on the raid frames
  - Three more aura places: **Inside, Centre**, **Inside, Centre Left** and **Inside, Centre Right**
- Raid frames: **Absorb Texture** (FlareUI Striped).
- Target and focus frames: **Flip Portrait** (off), in FlareUI and Forever Style.
- Meters:
  - **Visibility**: a new **In an Instance** choice.
  - Threat › **Visibility** (With the Meter) for the separate threat window: With the Meter, In an Instance, In a Group or In Combat.
- `/fui saylog`: checks that every Say and Yell line reaches your chat, and flags any that don't.

## Changed
- Fonts are back on the settings panel, out of Edit Mode.
  - New **Fonts** tabs: Unit Frames, Resource Bars, Buffs & Debuffs, Buff Reminders, Minimap and Quest Tracker.
  - One section per frame. Every section starts closed.
  - Each font has its own **Reset**, on its heading.
  - **Apply to All** and **Apply to Both** are gone. **Global Font** gives every font one face.
  - Your fonts carry over.
- Party and raid frames: **Spacing** is measured between the bars, so 0 makes them touch.
  - Raid Style party frames and raid frames, including **Group Spacing** and the main tank frames.
  - Your current spacing is adjusted, so your frames stay where they are.
- Switches that add a part now say **Show**, and are on by default.
  - Cast bars: **Show Icon** and **Show Spell Timer**
  - Action bars: **Show Keybind Text** and **Show Macro Text**
  - Quest Tracker: **Show Quest Level** and **Show Completed Objectives**
  - Your settings carry over.
- Edit Mode, unit frames:
  - **Mirror** is now **Mirror Bars**.
  - The **Aura Ordering** section is gone. **Sort By** sits under Debuffs in Auras; **Reverse Order** and **Your Auras First** sit under Only My Buffs / Debuffs.
  - **Range Check** moved from Look to Frame.
- Settings text: shorter, plainer descriptions and tips everywhere, in every language.
- XP bar: rested XP starts after quest XP instead of hiding behind it, and is light blue.

## Fixed
- Unit frames: changing **Aura Timer** shows or hides the timers at once, not only after a reload.
- Party frames: **Reset To Default** from Raid Style no longer stretches the Classic frames.
  - Frames already stretched: select them in Classic and press Reset To Default once.
- Fishing: **Double-Click to Fish** catches the second click every time.
- Bags:
  - The search box fits the window at fewer **Columns**.
  - With a two-handed weapon, upgrade arrows only compare main-hand and off-hand items.
  - Closing the backpack with B also closes the reagent bag, so your next bank visit opens your bags.

# FlareUI 6.3.2

## Changed
- Action bars: buttons without a keybind no longer show Blizzard's range dot while **Status Colouring** is on; the button turns red out of range instead. With Status Colouring off, the dot is back. Thanks for the report!

## Fixed
- Action bars: the range dot no longer shows as a "?" box with some keybind fonts. Thanks for the report!
- Settings and Edit Mode: long dropdowns, such as fonts from a font pack, scroll after 20 entries instead of running off the screen. Thanks for the report!
- Bags: **Uncollected Appearances** only marks weapons and armour that can change your look.

# FlareUI 6.3.1

## Fixed
- Blizzard's own text keeps its sizes again. FlareUI's settings window was changing the size of the game's fonts as soon as it loaded: buff timers, window titles, quest text and more. The new font options weren't the cause; they stay off unless you pick them. Thanks for the report!

# FlareUI 6.3

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## Highlights
- **One font for everything**: a **Global Font** on the Settings page, and every font can follow it.
- **A font for every frame**: unit frames, buffs, the tracker, resource bars and the minimap set their fonts in Edit Mode, frame by frame.
- **Smoother play**: a pass over everything that could cause short lag spikes, above all with gathering and quest addons.

## New
- Settings › **Global Font** (Friz Quadrata TT): one font for all of FlareUI's text, set in one place.
  - Every font dropdown now starts with **Global**, and every font that used Friz Quadrata follows it. Chat text and action bar text keep Arial Narrow.
  - **Use Global Font Everywhere** sets every FlareUI font to Global. Sizes, outlines and shadows stay.
  - **Reset All Fonts** puts every font back to its default.
  - **Game Text** (off): Blizzard's own text takes the Global Font too: menus, windows, quest text, nameplates and more.
  - **Nameplate Font** (Default): the names on Blizzard's nameplates.
  - **Combat Text Font** (Default): the damage and healing numbers over what you hit. It changes the next time you log in.
- Edit Mode: a **Fonts** section, always the last one, for each frame. Pick a text, then its **Font**, **Outline**, **Shadow** and **Size**.
  - **Unit frames**: each frame its own fonts for **Names**, **Health Text**, **Level**, **Power Text**, **Cast Name**, **Cast Countdown**, **Aura Timers** and **Aura Stacks**. Party, raid and boss frames too. Each frame style keeps its own.
  - **Player Cast Bar**: its own **Cast Name** and **Cast Countdown**.
  - **Buffs** and **Debuffs**: each their own **Aura Timers** and **Aura Stacks**.
  - **Buff Reminders**: **Counts** and **Time Left**.
  - **Quest Tracker**, every **resource bar** and the **minimap** (zone name, clock and info text).
  - **Apply to All** gives the same fonts to every frame of the kind; **Reset Fonts** puts the frame's back.
- More fonts in the Fonts tabs:
  - Action Bars › **XP Bar**: the bar's numbers. It used the Keybinds font before.
  - Radial Menu: a new **Fonts** tab with **Button Names** and **Counts**.
  - Bags & Looting › **Gold**: the money at the bottom of your bags.
- Bags & Looting › Bags: **Item Level** (off) on weapons and armour, in their quality's colour, in your bags and on the character sheet. Thanks for the request!
- Bags & Looting › Bags: **Uncollected Appearances** (off): an eye on gear whose look you can still learn. Thanks for the request!
- Tooltips: **Show Item Level** (off) on weapons and armour. Thanks for the request!
- Meters › Threat: **Separate Window** (off): threat in its own window, moved and sized in Edit Mode. Thanks for the request!
- Action Bars › Bars Appearance:
  - **Borderless Micro Menu** (off) and **Borderless Bag Bar** (off).
  - **Collapsible Bag Bar** (off): an arrow beside the backpack folds the other bags away. Needs Borderless Bag Bar. Thanks for the request!
- Unit frames › Health Text, Forever Style: **Percent <  > Value**: the percent at the bar's left end, the full value at its right. Thanks for the request!
- Health Text: **Value | Health Lost**, such as "1234 | -216".
- Radial Menu › Options: **Sub-Radials** (Reset on Close): a sub-radial opens on its first button, or on the one you used last with **Remember**.
- Minimap › Style: three cards, **Square (Clean)**, **Square (Header)** and **Round**.
- Minimap: **Latency** (off), under Framerate: your home and world latency at the bottom right.
- **Français**: French is in the language list on its own now, with every new text translated.

## Changed
- Edit Mode now holds the fonts of Unit Frames, Buffs & Debuffs, Minimap, Resource Bars and Quest Tracker, and their pages lost their Fonts tab. A **Fonts** row on each page opens Edit Mode. Your fonts carry over.
- Fonts tabs: each font starts closed, and fonts are grouped in titled sections, such as **Action Bars** and **XP Bar**.
- Bar text choices: **Value | Percent** is now **Percent | Value**, and **Current (Max)** is now **Value [Max]**. **Current (Max) | Percent** is gone; it becomes Value [Max].
- Settings › UI Scale: the **Blizzard's** choice is now called **Off**, and says that any other choice replaces Blizzard's UI Scale each time you log in. Thanks for the report!
- Buff Reminders:
  - Rogue poisons and other weapon buffs are recognised by kind, so Forever's reworked poisons count. Low charges start at 5. Thanks for the report!
  - Forever's hunter aspects, Trueshot Aura, Fel Armor, elixirs, food and oils are recognised more reliably.
  - Paladin auras and hunter aspects count only when they're yours.
- Minimap: the Fading section opens and closes like the others.
- Loot Rolls and Toasts: their Scale shows plain numbers.
- Bags: clicking the keyring or reagent bag icon opens and closes the combined backpack while that bag is part of it. Thanks to parchinskiy!

## Fixed
- Short lag spikes: FlareUI no longer handles the map pins of gathering and quest addons, and a long list of other places do less work. Thanks for the report!
- Buffs & Debuffs: no more slowdown after using Edit Mode in a fight or an instance.
- Fishing: **Double-Click to Fish** works with Blizzard's Cast on Key Down. Thanks for the report!
- Minimap: the square minimap is put back properly after ForeverFarmHUD or FarmHud; FlareUI explains the farming HUDs once. Thanks for the report!
- Bags: the keyring and reagent sections show the new-item glow like the rest, and lose it when you close your bags. Thanks to parchinskiy!
- Bags: a hidden reagent window no longer blocks clicks on the backpack with Move Any Window on. Thanks to parchinskiy!
- Russian: buttons and other text show their letters with FlareUI in Russian on a game client in another language.

# FlareUI 6.2

## Highlights
- **A settings window that looks like Blizzard's**: Friz Quadrata text, WoW's yellow titles, and Blizzard's own checkboxes, dropdowns, sliders, buttons and scroll bars.
- **Minimap › Header**: pick a headerless square minimap in a heavy bronze frame, or the bordered one with its title bar.

## New
- Minimap › Style: **Header** (Headerless), for the square minimap.
  - **Headerless**: the map framed in the heavy bronze border of the settings window, its buttons and zone name on the map.
  - **Bordered**: the frame's bronze title bar over the map, the buttons and zone name in it, as before 6.1.1.
  - Both are the same size, so switching doesn't move your minimap.
- Minimap: a **FlareUI button** when you untick FlareUI in **Addons in the Drawer**. Left-click opens the settings, right-click puts FlareUI back in the drawer, drag it along the edge to move it. It never shows while the drawer is off.
- Tooltips › Look: **Frame Opacity** (100%), under Scale. Thanks for the request!
- Loot Feed: **Alignment** (Left). Right puts the icons on the right, with the text before them. Thanks for the request!
- Buff Reminders, warlocks with Demonic Sacrifice and Demonic Pact: a **Demonic Sacrifice** reminder while you have none of its buffs, and your pet and Soul Link are still asked for. Thanks for the report!
- What's New: **Don't Show on Login** (off), at the bottom of the page. These notes then stay here instead of opening after an update. Thanks for the report!
- Settings, in Gamepad mode: options the Gamepad UI doesn't let FlareUI run are greyed, with a red note saying so. Thanks for the report!

## Changed
- Settings window: a new, more Blizzard-like look.
  - All text in Friz Quadrata, the game's own font, in white, with titles in WoW's yellow.
  - Blizzard's own checkboxes, choice arrows, dropdowns, sliders and scroll bars.
  - Buttons and tabs in Blizzard's grey with a bronze rim.
  - The plain stone background, with darker boxes so the options read more easily.
  - The module list on the left has no checkboxes; turn a module on or off beside its page title.
- Buff Reminders › Your Own: **Custom Reminders** and **Hidden Reminders** are now lists. Untick one to remove it or bring it back; **None** does them all. Thanks for the request!
- Bags & Looting: FlareUI leaves your bags alone while a bag addon runs (Bagnon, Baganator, AdiBags, ArkInventory, BetterBags, BagSmith and more), so its sorting and cleanup work as they should. Looting features keep working. Thanks for the report!
- Action bars: druids' Prowl turns Action Bar 1 to the prowl page again, as Stealth does for rogues. **Keep Page 1 in Stealth** still keeps your Cat Form page.
- Minimap › Addons in the Drawer: one line per addon, under its real name.
- Buff Reminders: druids no longer get an Omen of Clarity reminder. It's a random proc on Forever, nothing to keep up.

## Fixed
- Minimap: the game no longer hangs when you turn GatherLite's HUD or FarmHud on or off. Thanks for the report!
- Minimap: Social Diary's button works in the addon drawer again. Thanks for the report!
- Minimap, square style: the border's shadow and corners are no longer cut off by the map.
- Chat: TradeSkillMaster's settings no longer show an error on their General page. Thanks for the report!
- Tooltips: Russian clients show a player's class again. Thanks for the report!
- Fast Auto-Loot no longer stops working until a reload. Thanks for the report!
- Cast bars: your own casts and profession casts no longer turn grey on the target or focus bar. Casts you can't interrupt still do.
- Buff Reminders: the Passive Pet reminder no longer flashes as you dismount. Thanks for the report!

# FlareUI 6.1.1

## New
- Minimap: **Addons in the Drawer** (all), under **Addon Button Drawer**: tick the addons whose buttons go in the drawer. The others are left alone on the minimap, where their addon puts them. Changes take effect after a reload.
  - It replaces Shift+Right-Click on drawer icons, which clashed with addons' own right-click menus. Buttons you kept on the minimap that way stay out of the drawer.
- Settings › Sync Blizz UI: **Hide Pop-up Alerts** (off): syncs still happen, with no pop-up asking to reload, on every character. The pop-up's new **Hide These Alerts** button turns it on.

## Changed
- Minimap, square style: addon buttons left out of the drawer sit on the border, packed along the bottom from beside the sundial. Drag one along the border and it stays where you drop it, through every reload. Thanks for the report!
- Minimap, square style: the bronze border is drawn under the map, so no addon button can end up beneath it.
- Unit frames › player frame › Visibility: **Missing Health** and **Missing Mana** can no longer be ticked together; ticking one unticks the other. The game hides both from addons, so the two can't be combined. If you had both, Missing Mana stays. Thanks for the report!
- Action bars: **Active Highlight** follows the button's own frame, round corners and all, instead of a square. Thanks for the report!

## Fixed
- Minimap: the **Middle-Click Menu** opens again. Other clicks ping the map as usual. Thanks for the report!
- Minimap: addon buttons no longer move around on every reload, and RareScanner's button shows again when left out of the drawer. Thanks for the report!
- Resource bars: Blizzard's own swing timer no longer appears in busy fights when FlareUI's swing bars are on. Thanks for the report!
- Unit frames: the player frame now fades as it should with Missing Health and Missing Mana both set (see Changed). Thanks for the report!

# FlareUI 6.1

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## Highlights
- **Buff Reminders** is now its own page, with much more to track: talent buffs, weapon oils and stones, elixirs, supplies, durability and your own custom reminders.
- **Mouseover** is now a Visibility condition you tick, so bars and frames show on hover only when you want them to.
- **Tooltips** get a Visibility tab: when each kind shows, and which ones follow your mouse.

## New
- Buff Reminders: its own page in the Combat group, with its own switch. Your settings carry over.
  - **Reminders** tab: Class Buffs, Weapons, Consumables, Upkeep and Your Own.
  - **When and Where** tab: when a buff counts as running out, where each kind shows, and which group buffs to hide.
  - **Alerts** tab: **Sound** and **Ready Check Alert**.
  - Its Edit Mode window gains **Alerts** (**Glow When Missing**, **Glow When Running Out**, **Time Left**) and **Hide While Mounted**.
  - It no longer needs Buffs & Debuffs to be on.
- Buff Reminders: talent and class buffs, once you know the spell. Thanks for the request!
  - Priest: **Divine Spirit** on your group, and **Shadowform** (not while you're the healer).
  - Druid: **Omen of Clarity**. Hunter: **Trueshot Aura** and an **Aspect** reminder (a click puts your last one back).
  - Warlock: **Soul Link** while your pet is out, and a **Soulstone** on your group's healer.
  - Warrior: **Battle Shout** on you and your party.
- Buff Reminders: **Extra Buffs** (none) adds **Shadow Protection** and **Moonkin Form** when ticked.
- Buff Reminders: **Weapon Oil / Stone** (off), for every class. Click to use one from your bags; right-click to pick which. Sharpening stones go on blades, weightstones on maces and staves.
- Buff Reminders: **Playstyle** (Automatic) picks which oil or stone comes first: stones for melee and tanks, wizard oil for casters, mana oil for healers.
- Buff Reminders: **Elixirs and More**: tick the elixirs, Zanza, juju and Blasted Lands buffs you want kept up. Click to use one from your bags.
- Buff Reminders: **Low Supplies** (off) for reagents and ammo, **Low Durability** (off) below 20%, and **Worn Trinkets** (off) for an Argent Dawn trinket or Carrot on a Stick still on in a dungeon or raid.
- Buff Reminders: **Add Custom Reminder**: your own reminder by spell name or ID, or an item. Right-click its icon to remove it.
- Buff Reminders: right-click an icon to **Snooze Until Recast**.
- Buff Reminders: where each kind shows: **Class Buffs**, **Weapon Buffs**, **Pets** and **Consumables**, each Always, In Dungeons and Raids, or In Raids.
- Buff Reminders: icons that use an item show how many you have; a buff running out shows its time left; a poison low on charges counts as running out.
- Tooltips: a **Visibility** tab.
  - **Visibility**: World, Unit Frames, Action/Data Bars, Buffs/Debuffs, Party/Raid Auras and the new **Everything Else** (the minimap, menus and more): Always, Hide in Combat or Never.
  - **Mouseover**: which of them appear at your mouse. Each follows the main **Mouseover** on the Settings tab; a change here is an exception for that kind. Thanks for the request!
- Edit Mode › player frame › Fading: **Link Pet Frame** (off): the pet frame fades with the player frame, and pointing at either shows both. Thanks for the idea!
- Bags & Looting: **Open with Character Window** (off): your bags open and close with the character window. Thanks for the request!
- Bags & Looting › Fonts: **Free Bag Slots** (Default): the font of the free-slot count on the backpack button. Thanks for the request!

## Changed
- Visibility: **Mouseover** is now a condition you tick with the others, on every faded bar and frame and on Fake CM. Without it, pointing at a faded frame doesn't show it.
  - If you had conditions set, Mouseover is ticked for you, so nothing changes until you untick it.
  - Nothing ticked now means Always.
- Tooltips: **Anchor** is now **Mouseover**, a switch on the Settings tab for every tooltip at once. Your choice carries over.
- Bags & Looting: the bank and guild bank now open your bags, as the vendor and mailbox do.
- Minimap: the **Middle-Click Menu** works as before 6.0.3 again: a middle click opens the menu without a ping, and the square map's corners ping. In battlegrounds the game keeps the map's clicks to itself, so there's no menu there.
- Loot Feed: money shows just the coins you looted, without the gold icon. Thanks for the request!
- Unit frames: in the ring styles, Target of Target and Target of Focus have their portrait on the left, so the bar runs left to right clear of it.
- Radial menu: the catalog's sections stay on one line, and an empty catalog says why.
- Buff Reminders: Food and Flask is a switch, with its place under When and Where.
- Buff Reminders: an oil or stone on a warlock's weapon no longer brings up the Firestone reminder. Thanks for the report!

## Fixed
- Action bars: **Active Highlight** no longer leaves spells like Rend or Thunder Clap lit after you use them. Thanks for the report!
- Buffs: a sharpening stone's or oil's icon no longer disappears after you die. Thanks for the report!
- Buff Reminders: food buffs not called "Well Fed" (Nightfin Soup, Grilled Squid and more) count, and Demonic Sacrifice no longer asks for your pet.
- Edit Mode: FlareUI's loot rolls, toasts and other frames keep working after an update read with /reload; FlareUI now tells you to restart instead. Thanks for the report!
- Radial menu: the **Professions** catalog finds your professions.
- Settings: longer translations fit their buttons, and the About page scrolls. Thanks to parchinskiy!

# FlareUI 6.0.3

**Restart the game fully after updating** (not just /reload): this version adds a new file.

**Please check your settings.** Some defaults changed in this version (listed under **Defaults**). Options you already set yourself keep your choice; options you never touched take the new default.

## Highlights
- **Bags & Looting** is now its own page, with its own switch.
- **Flight Timer** and **Paladin Seals**: two new resource bars.
- **Weapon buffs** in Buff Reminders: warlock stones, off-hand weapons, and clicks that put poisons and imbues on the right hand.

## New
- Bags & Looting: a page of its own, out of Quality of Life.
  - **Bags** tab: **Bag Window**, **Item Slots** and **Tools** sections.
  - **Looting** tab: **Faster Auto Loot**, **Skip Loot Confirmations** and the **Loot Feed**.
  - **Fonts** tab: **Bag Items** and **Loot Feed**.
  - Your settings carry over. Its switch starts on if you had Quality of Life on.
- Bags & Looting › Bags: **Category Filters** (off). A button beside the cleanup button opens a drawer: **Quest Items**, **Equipment**, **Materials** or **Consumables**. Everything else dims. Right-click the button to clear it. Thanks to parchinskiy for the idea!
- Bags & Looting › Fonts: **Bag Items** (Default) sets the font of the stack counts and cooldown numbers on your bag items.
- Resource bars: **Flight Timer** (off). A bar while you're on a flight path, with where you're going and the time left.
  - Each route is learned the first time you fly it. Until then the bar counts up.
  - Learned times also show on the flight map when you point at a destination.
- Resource bars: **Paladin Seals** (off). One bar with your seal's name and time left, in that seal's own colour. Pick each seal's colour in **Bar Colours**.
- Buff Reminders: weapon buffs. Thanks for the report!
  - Warlocks: a **Firestone** or **Spellstone** reminder. Click to make one, or to put one from your bags on your weapon.
  - Off-hand weapons get their own reminder, for rogues and dual-wielding shamans.
  - Only your class's own weapon buff counts: a sharpening stone no longer hides a poison or imbue reminder.
  - Rogues: click to put a poison from your bags on that hand.
  - Shamans: click to put the imbue on that hand.
  - Right-click an icon to pick which poison, imbue or stone goes on each hand (**Last Used** by default).
- Action bars: **Active Highlight** (off), in **Button Appearance**. Your stance or form, a queued Heroic Strike, Cleave, Maul or Raptor Strike, and a repeating Auto Shot get a gold edge and a light. Queued attacks pulse. Thanks for the request!
- Action bars › XP Bar: **Show Bubbles** (off) divides the XP, reputation and honor bars into 20 parts, like the classic bar. Thanks to mateuszmalek!
- Edit Mode: Blizzard's **Totem Bar** gets **Size** and a **Fading** section with fade groups, like the action bars. Thanks for the request!
- Minimap: **Framerate** (off): your framerate at the bottom right of the map, **Always** or **On Mouseover**. Thanks for the request!
- Damage Meter: **Fade Delay** (Instant), after **Faded Opacity**: how long the meter stays before it fades.
- Radial menu: drag radials in the **Radials** list to reorder them.
- Radial menu: **groups**. Right-click a radial to **Add to New Group...**, move it to a group or take it out.
  - Click a group's row (or its **+ / −**) to fold or open it.
  - Right-click a group to **Rename...** or **Ungroup** it.
  - Drag radials into a group, and drag a group to move it.
- Radial menu: a **Professions** catalog with your professions and Smelting, Disenchant, Find Herbs, Find Minerals, Basic Campfire and Pick Lock.
- Fonts: every font on every **Fonts** tab has a **Reset** button.

## Changed
- Unit frames and resource bars: **Colour Palette** is now **Frame Colours** and **Bar Colours**: a **Pick Your Colours** button you always see.
  - In its window, the palette list at the bottom offers **FlareUI** (default), **Blizzard** and **Custom**.
  - Change any colour and the palette becomes **Custom**. **Reset** gives your colours back.
  - **Apply** saves and closes. Closing with unsaved colours asks whether to keep them.
- Minimap: **Coordinates on Mouseover** is now **Coordinates**: **Off**, **Always** or **On Mouseover**. It is the same option as Blizzard's own coordinates. If you had Coordinates on Mouseover off, you get **Always**.
- Minimap: the addon drawer's **Open on Mouseover** closes sooner after the pointer leaves.
- Quest tracker: **Colour Names by Difficulty** is now **Colour by Difficulty**.
- Loot Feed: a single item shows just its name, and several show "Name x3". Thanks to Nico-Mayer!
- Radial menu: a new radial is available to **All Characters** by default.
- Radial menu: **Quest Items** has a new icon.
- Settings: options reordered on the Action Bars, Minimap, Quest Tracker, Tooltips and Damage Meter pages, so related ones sit together.
- Quality of Life has a new icon; the bag icon went to Bags & Looting.

## Defaults
- On: **Party Frames** and **Raid Frames** (with Unit Frames), Buffs & Debuffs **Timer Colour** and **Arrival Animation**, Damage Meter **Pull Warning** and **Pull Aggro Line**.
- Off: Action bars **Stop Auto-Add Spells**, Minimap **Middle-Click Menu**, Quest tracker **Completed Last** and **Auto Minimize in Instances**, Tooltips **Show Threat**, **Map Pins on "/way"**, **Gamepad Mode Prompt**, and every bag option.
- Chat, Damage Meter and Quest Tracker: **Frame Opacity** 60%.
- Minimap: **Coordinates** On Mouseover.
- New default spots for Buff Reminders, toasts, loot rolls, Combo Points, the swing timers and the new bars.

## Fixed
- Minimap: clicking the map in a battleground no longer causes a blocked-action error. Thanks for the report!
- Quest tracker: **Sort By** By Zone no longer reorders quests by distance as you move. Thanks for the report!
- Quest tracker: **Wrap Long Text** no longer cuts off a longer objective. Thanks to parchinskiy!
- Gamepad UI: settings dropdowns opened with the mouse no longer cause an error. Thanks for the report!
- Action bars: with **Clean Keybind Text** off, long key names stay on one line instead of covering the icon. Thanks for the report!
- Radial menu: the **Available To** list of a new radial opens over its popup, not under it.
- Radial menu: the selected button's highlight in the **Buttons** list sits centred.

# FlareUI 6.0.2

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## New
- Player frame: **Missing Mana** in its **Visibility** list (Edit Mode). Tick it with **Missing Health** and the frame shows while either bar is below full. Thanks for the request!
- Quality of Life › Fonts: **Zone Text** (Default) changes the font of the zone name that appears as you enter a new area. Its size stays Blizzard's. Thanks for the request!
- Quality of Life › Hide Clutter: **Flag Carrier Frames** (off) hides the two flag carrier frames under the minimap in battlegrounds. Thanks for the question!

## Changed
- Action bars: **Auto Paging for Stealth** is now **Keep Page 1 in Stealth** (off). The game now turns Action Bar 1 to its stealth page by itself; this option keeps your normal buttons instead. Thanks for the report!
  - Druids keep their Cat Form page while prowling.
  - If you had Auto Paging for Stealth off, Keep Page 1 in Stealth starts on.
- Action bars: **Skin Cooldown Manager** is now off by default. Turn it on in **Bar Appearance**.

## Fixed
- Player cast bar: your casts never turn grey. Thanks for the report!
  - **Range Check** is gone from the cast bar: with it off, every cast turned grey.
  - Blizzard's own cast bar keeps its normal colour for your casts too.
- Action bars: a hidden **Stance Bar** stays hidden in combat. It came back, for example when Stealth came off cooldown, until the fight ended. Thanks for the report!
- Action bars: with **Keep Bar 1 in Stances**, the spellbook's "not on your bars" glow matches the bar you see. Thanks for the report!
- Minimap: addon buttons you keep on the minimap with the addon drawer sit above the map border. Thanks for the report!
- Russian: the Damage Meter's **Threat** tab and the **Open Configuration** button in Blizzard's options no longer show squares. Thanks for the report!
- Settings: slider values such as **Default** next to Bags › **Columns** no longer get cut off in long translations. Thanks for the report!
- Unit frames, FlareUI Style: the last bit of shadow at the top of the portrait ring is gone.
- Radial menu: a **Party Spell** slice shows the spell's name while you're alone, not your own name.

# FlareUI 6.0.1

## Changed
- Action bars: **Skin Cooldown Manager** follows Blizzard's own Cooldown Manager switch. While the Cooldown Manager is off, FlareUI leaves it alone and the option is greyed out. Thanks for the report!
- Settings: a tab's NEW badge sits centred on the tab's top edge.

## Fixed
- Player cast bar: your own casts keep their normal colour. Some spells turned the bar grey, whatever **Range Check** was set to. Thanks for the report!
- Nameplates: with **Hide Level**, crowd control icons sit right beside the health bar again, without a gap. Thanks for the report!
- Unit frames, FlareUI Style: the portrait ring's rim is clean at the bottom, and nothing shows through beside the portrait.
- Settings: long translations, such as Russian, no longer run past buttons, card titles, section headers or the page list. Text wraps, then shrinks to fit.

# FlareUI 6.0

**Restart the game fully after updating** (not just /reload): this version adds new files.

FlareUI 6.0 brings a whole new settings window. We rebuilt it from the ground up, with one goal: make it as easy to use as we can. Every page now shows a live example of what it changes, drawn by the real frames, so you see the result before you leave the window. Options sit in clear sections, search takes you straight to them, and the whole window wears WoW: Forever's own bronze and stone. Tell us what still feels hard to find. Thanks to Jeor for starting this!

## Highlights
- **A new settings window**: live previews, clearer pages, better search, and a look that matches the game.
- **Custom colours**: pick your own colour for every unit frame and resource bar.
- **Profiles follow you**: a profile now brings its frame positions to every character that uses it.

## Settings window
- Every page shows a live preview of what it changes, drawn by the real frames in your current style.
- A new **Settings** page holds **Sync**, **Move Any Window**, **UI Scale** and **Language**.
- Search shows how many options it found; press **Enter** to jump to the first one.
- Module switches sit in the list on the left, so you can turn a module on or off without opening it.
- A new look: WoW: Forever's heavy bronze frame, a stone background, stone switches and round game icons.
- The **setup tour** (/fui tour) has the same look.

## New
- Unit frames: **Colour Palette** gets **Custom**. **Pick Your Colours** opens a window with every bar colour and live samples beside them. Thanks for the request!
  - Click a colour to change it; right-click it to go back to the palette's own. **Reset All** clears them.
  - Custom starts from the palette you had.
- Resource bars: their own **Colour Palette** (FlareUI, Blizzard or Custom), in the new **Look** section. Until you change it, it follows the unit frames' palette. Thanks for the request!
- Settings: **Text Scale** (100%), under **UI Scale**, makes all text larger or smaller without changing the frames. Thanks for the question!
- Action bars: a new **Bar Appearance** section. Thanks for the request!
  - **Skin Action Bars** (on) gives every bar's buttons FlareUI's bronze frame.
  - **Bar Scale** (111%) sizes every button, in 0.5% steps.
  - **Skin Cooldown Manager** moved here, and now frames the Essential and Utility cooldown icons too.
- Buff Reminders: more reminders.
  - Druids: **Thorns**.
  - Paladins: **Righteous Fury** while you're the group's tank, and an aura when none is on.
  - Warriors: a stance when you have none.
  - Warlocks: a **Healthstone** in your bags.
  - Pets left on **Passive**. Click the icon to set them to Defensive.
  - **Camping and Rest** (off): Forever's camp benefits and the Cozy Sleeping Bag's Well-Rested. Click to use the bag.
  - **Gathering Tracking** (off): Find Herbs or Find Minerals when it's off.
- Buff Reminders: right-click an icon to **Hide Until Reload** or **Never Remind Me**. **Hidden Reminders** brings them back.
- Buff Reminders: **Remind Before It Ends** can be set apart for dungeons and raids.
- Buff Reminders: **Group Buff Filters** hide group buffs while you're a tank, healer, damage dealer or have no role (all off).
- Buff Reminders, in Edit Mode:
  - **Count Text** (Missing / Total, Missing Only or Off), **Spacing** and **Opacity**.
  - **Growth** can start from the middle.
  - A **Fading** section: **Visibility** (Solo, In a Party, In a Raid, **In Combat**), **Hide in Rested Areas**, **Fade Speed** and **Opacity**.
- Loot Feed: **Show Skill-Ups** (off) adds skill gains, like "Mining 76", to the feed. Thanks for the request!
- Loot Feed: font, size, outline and shadow, in a new **Quality of Life › Fonts** tab. Thanks for the request!
- Tooltips › Show Tooltips: **On Buffs/Debuffs** (Always) and **On Party/Raid Auras** (Never). Set the second to Always or Hide in Combat to see tooltips on party and raid aura icons. Thanks for the request!
- Swing timers: **Bar Text** and **Timer** (both on), in Edit Mode's **Look**, hide the swing's name or the seconds left. Thanks for the request!
- Player cast bar: **Range Check** (off) greys the bar while your target is out of range. It's in the cast bar's **Look** and in the player frame's **Cast Bar** section. Thanks for the question!
- Minimap: in the addon button drawer, **Shift+Right-Click** an icon to keep that addon's button on the minimap. Do it again to put it back. Thanks for the request!
- Loot rolls and toasts: **Scale** in their Edit Mode dialogs.
- Edit Mode: the Quest Tracker, Totems, Buffs/Debuffs, XP Bar and Buff Reminders get a **Frame** section. The tracker, the auras and the XP bar get a **Fading** section.

## Changed
- Profiles: a profile's frame positions now follow it to characters on other Edit Mode layouts. Thanks for the report!
  - Switching profiles offers the Edit Mode layout it was set up on, or explains how to copy it.
  - **New** asks whether to copy your current profile or start from defaults. **Duplicate** is gone.
  - The Profiles page explains what a profile holds.
- Shields: the part that doesn't fit after your health (all of it at full health) now shows over the health bar, from its end backwards. You see how much shield is left as you're hit. Unit frames, party and raid frames, and the Health resource bar. Thanks for the request!
- Buff Reminders: the **Blessing**, **Thorns** and **Pet Reminders** rows are gone, to keep the page short.
  - Pick who gets your Blessing or Thorns (**Tanks Only**, **Only Me** or **Everyone**) from the icon's right-click menu.
  - Pets you turned off, and Thorns set to Off, carry over as hidden reminders.
- Buff Reminders: **Visibility**, **Hide in Rested Areas** and **Opacity** moved to the Edit Mode **Fading** section.
- Party and raid frames: Edit Mode samples show an incoming heal and a shield, as the unit frames' do. Thanks for the question!
- Unit frames, FlareUI Style: the portrait ring keeps its full rim on the bars' side, as in Forever Style.
- Edit Mode: every FlareUI dialog's sections start closed after a reload.
- Edit Mode: **Range Check** is the first switch in **Look** and **Show Level** the first in **Frame**. **Spell Pushback** comes before **Latency Zone**.
- Edit Mode: the ring's threat number sits over the middle of the ring.
- Loot rolls: a bronze border.
- Battleground objectives: a tidier Edit Mode sample, and the real scores sit on FlareUI's Thick plate.
- Damage Meter: Blizzard's Edit Mode dialog for the meter no longer shows **Visibility**, **Transparency** or **Background**. They did nothing with FlareUI's meter: use **Settings › Damage Meter**. Thanks for the report!
- UI Scale: its tip now says **Pixel Perfect** is about sharp borders. Text is sharp at any scale.

## Fixed
- Unit frames: no more blocked-action errors when a druid shapeshifts in combat with the ring styles. Thanks for the report!
- Chat: undocked windows, such as World, no longer come back lower after login, over the main chat's tabs. Thanks for the report!
- Nameplates: with **Hide Level**, the quest badge sits beside the health bar, not under it. Thanks for the report!
- XP bar: the border draws over the bar, so its corners no longer show square ends. Thanks for the report!
- Minimap: addon buttons on the square minimap's edge no longer sit under its border. Thanks for the report!
- Bags: empty slots in **Integrated Bag Buttons** no longer show an "Equip Container" tooltip.

# FlareUI 5.1.2

## New
- Minimap: a one-time notice when Lueur, NodeSight or Nodeworthy is on. Their node scanning makes the minimap flash, and that comes from them, not FlareUI. The Minimap settings page says so too while one is loaded. Thanks for the report!

## Changed
- Loot Feed: the lowest **Minimum Quality** choice is now called **All Items**. It already showed every item. Thanks for the feedback!

## Fixed
- Loot Feed: single items show again; only stacks and money did. It now also works whatever language your game is in. Thanks for the report!
- Bags: the **Upgrade Arrow** no longer marks weaker gear, such as grey cloth bracers over green mail ones. Armour only gets the arrow when it loses no stat, armour included. Thanks for the report!
- Cast bars: **Hide Spell Timer** stays on after the first cast. Thanks for the report!
- Minimap: no black box while gathering addons scan. Thanks to Jeor for the fix!
- Settings: tabs no longer run past the edge of the page when they show NEW.

# FlareUI 5.1.1

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Highlights
- **Moved frames come back.** Since 5.1, a unit frame moved in Edit Mode could vanish or get stuck in the top-right corner. Fixed, and lost frames return to where you dropped them. Thanks for the reports!
- **Buff Reminders**, a **Loot Feed** and a **Mouse Ring**, with more of what you asked for from other addons.

## New
- **Russian** translation. Pick it in **Settings › Language**, or let FlareUI follow your game's language. Thanks to parchinskiy for the translation!
- Buffs and debuffs: **Buff Reminders** (off), on its own **Buff Reminders** tab. Thanks for the request!
  - An icon for each of your class's buffs missing on you or your group, or about to run out. Click it to cast the buff.
  - Covers group buffs, self buffs, weapon imbues and poisons.
  - Paladins: **Blessing** (Automatic) gives warriors, rogues and hunters Might, and everyone else Wisdom, or one blessing for everyone.
  - **Pet Reminders** (on): hunters call, revive or mend their pet; warlocks summon theirs.
  - **Food and Flask** (off): a reminder in dungeons and raids, or always.
  - **When It Shows**: Solo, In a Party, In a Raid, **Hide in Rested Areas** (off) and **Only When You're the Only Provider** (off).
  - **Alerts**: a **Sound** (off) and gold or orange glows (off).
  - Edit Mode: **Orientation**, **Growth** and **Icon Size**. Hidden in a fight.
- Quality of Life: a **Bags and Looting** tab, with the bag options, looting and the new Loot Feed.
- Bags: **Keyring in Backpack** (off) and **Crafting Bag in Backpack** (off) add them to the bottom of the combined backpack. Thanks for the request!
- Looting: **Loot Feed** (off) floats what you loot up beside you, so you don't have to read the chat. Thanks for the request!
  - **Position**: **At the Cursor** (default), or **Where Placed** in Edit Mode.
  - **Minimum Quality** (Poor) and **Show Money** (on).
- Quality of Life › Gameplay › Cursor: **Mouse Ring** (Off) puts a bronze ring round your cursor: **Always**, **In Combat** or **While Right-Clicking**.
  - **Size** (40) and **Thickness** (3).
  - **Cast Ring**, **GCD Ring** and **Swing Ring** arcs (off).
  - **Out-of-Range Colour** (off) turns it red while your target is out of reach.
  - **Class Colours** and **Hide While Turning** (off).
- Quality of Life › Advanced: **UI Scale** (Blizzard's) sets the size of the whole interface as you log in. Pick **Pixel Perfect**, a preset for 4K, 1440p or 1080p screens, or **Custom** (30% to 200%). Thanks for the request!
- Quality of Life › Interface: **Wider Vendor Window** (off) shows 20 items a page.
- Minimap: **Open on Mouseover** (off), under **Addon Button Drawer**, opens the drawer when you point at the day/night button. Thanks for the request!
- Chat › Formatting, all off. Thanks for the request!
  - **Race Icons** and **Class Icons** before player names.
  - **Item and Spell Icons** inside links.
  - **Whisper Markers**: a green > for whispers you get, a red < for ones you send.
  - **Colon After Names**: "[Aria]: hello".
- Chat: with **Better Player Names** on, Say lines start with a clickable **[Say]** label (**[S]** with short channel names). Click it to switch your chat back to Say. Thanks to parchinskiy for the feature!
- Unit frames: **Range Check** (on), in the Look section of the target, focus, party, raid and boss frames. Off, the frame never fades for distance. Thanks for the report!
- Resource bars: **Range Check** (on) for the three swing timers.

## Changed
- Quality of Life: **Buy More Than One Stack** is now **Enhanced Vendor Purchases**, with **Stack** and **MAX** buttons, items that don't stack, and its progress above the vendor window. Your setting carries over.
- Chat: **Short Channel Names** is now **Channel Names**: **Full**, **Short** ("[2. Trade]") or **Number** ("[2]"). If you had it on, you get Number.
- Chat: the **Formatting** options are in a new order.
- Quality of Life: **Convenience** is now at the top of the Gameplay tab.
- Action bars: **Skin Cooldown Manager** moved to the bottom of **Tweaks**. Your setting carries over.
- Player frame: the **Mana on Shapeshift** bar is as tall as the power bar, so its number is easier to read. Thanks for the report!
- Tooltips: **Compare with Shift** is now off by default.

## Fixed
- Unit frames: frames moved in Edit Mode no longer vanish or jump to the top-right corner. Thanks for the reports!
- Resource bars: swing timers now turn red when your target is out of range.
- Minimap: addon buttons on the edge of the square minimap no longer slip behind its border. Thanks for the report!
- Settings and tour: buttons grow to fit longer translated labels, and the profile buttons move to two rows when they need the room. Thanks to parchinskiy for the fix!

# FlareUI 5.1

## Highlights
- **Fading for more frames.** Unit frames, resource bars, the player cast bar and the gryphons get a **Fading** section at the bottom of their Edit Mode dialog, with the same **Visibility** choices as the action bars.
- **Missing Health** keeps the player frame, pet frame and health bar visible while that unit is hurt.

## New
- Unit frames (player, pet, target, focus, target of target, target of focus): **Visibility**. They fade at once.
  - Player and pet only: **Faded Opacity** and **Missing Health**.
  - This replaces **Fade Player and Pet**. If you had it on, both frames keep the same behaviour.
- Resource bars: **Fade Group**, **Visibility**, **Fade Speed** and **Faded Opacity**.
  - A fade group lets a bar fade with your action bars.
  - The health bar also has **Missing Health**.
  - Your old Visibility choice carries over.
- FlareUI Player Cast Bar: **Visibility** (Always) and **Faded Opacity**.
- Gryphons: each **End Cap** dialog has its own fading, fade groups included. Both start on **Same as Action Bar 1**, so nothing changes until you pick something else.
- Edit Mode: **FlareUI Battleground Objectives** moves the scores at the top of the screen. Needs **Move Any Window** on. Thanks for the request!
- Quest tracker: **Colour Names by Difficulty** (off) colours quest names like their level. Complete and focused quests stay green and blue.
- Quest tracker: FlareUI's tracker works in Gamepad mode again. **Force Blizzard Tracker** (off), in Quality of Life › Gamepad, shows Blizzard's there instead. Thanks for the feedback!

## Changed
- Health bars: shields now start after your health and incoming heals, as in Blizzard's frames, so missing health is never hidden behind them. Thanks for the report!
- Nameplates: combo points sit below the enemy's cast bar, so a cast no longer covers them. Thanks for the report!
- Resource bars: new default places, and **In Combat** by default for the health, power, druid mana and combo point bars. Bars you placed yourself don't move.
- Settings window: switches about the same thing now sit together on every page.
  - **Completed Last** moved to the quest tracker's Quests section.
  - **Pet Food Marker** and **Auto Type "delete"** moved to Bags and Looting.
  - Quality of Life's Controller section is now **Gamepad**.

## Fixed
- Quest tracker: the Forever tracker sections of Shortest Path, SkillUp and Adventure Guide Forever no longer disappear while FlareUI's Quest Tracker is on. Thanks to the players who tracked it down!
- Minimap: EnhanceQoL can no longer move the day/night button (and the Addon Button Drawer) over the calendar.
- Minimap: the map no longer chases your cursor when a Lueur 1.6 scan pauses over a window or while you turn the camera.
- Radials: a radial on LT or RT + L3 no longer takes L3's Auto Run outside fights. In a fight L3 stays with the radial, because the game locks bindings in combat. Thanks for the report!

# FlareUI 5.0.6

## Fixed
- Minimap: gathering addons that read nodes by sliding the hidden minimap under your cursor (Lueur, NodeSight, Nodeworthy) work with FlareUI now:
  - The minimap no longer ends up outside its frame after gathering, and no longer shows while it chases the cursor.
  - The mouse wheel zooms the camera again during their scans, instead of the hidden minimap.
  - Auto zoom-out and **Coordinates on Hover** wait for a scan to finish instead of cutting it short or flashing.
  - A faded-out minimap keeps being scanned.
- Minimap: Gathercraft can read the minimap's tooltip again, and its tracking button no longer causes errors in a fight.
- Action bars: turning **Show button art** off no longer throws a Lua error. Thanks to parchinskiy for the fix!

# FlareUI 5.0.5

## Changed
- Buffs and debuffs: the **Border** aura swipe draws a thicker ring around the icon, so the time left is easier to read. Thanks for the feedback!

## Fixed
- Target and focus no longer fade when you stand right next to an enemy. Range fading checked the first rank of your spells, which the game stops counting once you learn a higher one: a warrior or rogue was left with only Charge or Throw, which can't reach up close. It now uses the best rank you know. Thanks to the players who reported it!

# FlareUI 5.0.4

## Changed
- Forever and FlareUI styles: the **rest, combat and threat glows** now tint the portrait's own border with a soft pulse, instead of a bright line around it. Threat comes first while you have it.

## Fixed
- Controllers: both analog sticks work again with FlareUI on. Since 5.0 the controller radial kept listening to the sticks all the time; now it only listens while it is open. Thanks to the player who reported it!

# FlareUI 5.0.3

## Changed
- Unit Frames: **Player Cast Bar** has its own switch again, next to Main Frames. Turn it off and Blizzard's cast bar comes back (after a reload). Thanks to everyone who missed it!
- Player frame, Edit Mode: **Standalone Cast Bar** is gone. The **Cast Bar** section stays, for a cast bar on the player frame itself, now off by default and apart from the Player Cast Bar.
- The settings window is a little taller, so the Unit Frames page fits without scrolling.

# FlareUI 5.0.2

## New
- **Italian** and **Latin American Spanish**, and a full **Spanish (Spain)** translation. Pick one in **Settings → Language**, or let FlareUI follow your game's language.
- **Portuguese (Brazil)** is complete again, with shorter labels that fit the settings and the words players use: buffs, debuffs, pet, cast bar, frames.
- Tooltips: **Simplified Item Stats** (off). Item tooltips say "+12 Spell Power" instead of "Equip: Increases damage and healing done by magical spells and effects by up to 12.", set bonuses too.

## Changed
- Item tooltips show stats as the game writes them again. The short form, always on since 5.0, is now the **Simplified Item Stats** switch under Tooltips. Thanks to everyone who asked!

## Fixed
- Minimap: with a node-finding addon and Find Minerals or Find Herbs on, the coordinates, the header bar (tracking, zone, clock and calendar), the mail icon and the day/night badge no longer fly across the screen with your cursor or flicker. Thanks to the players who reported it!

# FlareUI 5.0.1

## New
- **Visibility is now a list of toggles** on bars, the XP bar, buffs, debuffs, the quest tracker, the minimap, Resource Bars and the Fake Cooldown Manager. Tick **In Combat**, **Has a Target**, **Has an Attackable Target**, **In a Group** or **Not Mounted** in any mix: any one of them shows it. Your current choice carries over.
- Buffs & Debuffs: **Skin Cooldown Manager** (on). Blizzard's Cooldown Manager in FlareUI's look: its bars like FlareUI's cast bars, its buff icons like your FlareUI buffs. Everything it lets you set still works. Thanks to the player who asked!
- Action Bars: the **FlareUI XP Bar** switch is back (on). Off brings back Blizzard's XP and reputation bars after a reload.
- Player frame, Edit Mode: a **Cast Bar** section, for a cast bar on the frame itself. *(Reworked in 5.0.3.)*

## Changed
- Health, power and threat numbers show in full up to 9,999 ("8742", not "8.7K").
- **Settings read the same everywhere.** Names are in Title Case, options are grouped the same way (dropdowns, then sliders, then switches) in the settings and in every Edit Mode dialog, and one thing has one name. The renames you may look for:
  - **Visibility** (was Show Condition or Show) and **Faded Opacity** (was Min Alpha)
  - **Border**, **Buff Size**, **Debuff Size**, **Growth**, **XP Text**, **Threat Text**, **Sort By**
  - **Keep Bar 1 in Stances**, **Hide Bubbles in Instances**, **Controller Bar**
  - **Off** instead of None on Health Text, Power Text, Aura Swipe and Aura Timer

  Searching an old name still finds the option.
- Action Bars: **Steady attack highlight** is gone. Attack, Auto Shot and Shoot blink as Blizzard's do.

# FlareUI 5.0

Biggest update for FlareUI yet. Every single aspect of the addon is improved in an inversely proportional rate to the developer's health. Read the LotR sized changelog below to find out what changed.

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Highlights
- **Bags**: columns, gaps between bags, bag slots down the side of the backpack, rarity colours, a junk coin and an **upgrade arrow** on gear that beats what you wear.
- **Proc Glow** lights spells that a proc buff empowers: Fingers of Frost, Missile Barrage, Shadow Trance, Maelstrom Weapon, Eclipse and more.
- **Cast bars**: "Interrupted by" with the kicker's name, a tick showing when your interrupt is back, a latency zone, channel ticks and a spell queue mark.
- **Target and focus**: range fading, **Show Threat** and **Highlight Purgeable Buffs**.
- **Damage Meter**: a **Threat Meter** section with a pull aggro line, a pull warning and the tank's lead.
- **Radial Menu**: a **Party** category to cast on group members, a **Quest Items** button, range tint, item counts and spell charges, and controller buttons for each radial.
- **Controller**: the settings window works with the gamepad again, and the controller can rumble for alerts and procs.
- **Quest Tracker**: rewards in tooltips, Pin to Top, timer bars and Wowhead links.
- **XP bar**: its tooltip is back, with XP per hour and time to level.
- **Item tooltips**: "+12 Spell Power" instead of a long Equip line, and gear comparison only while you hold Shift.
- **Settings**: a **Language** page, profile import with a preview, profile Rename, and a much smarter search.

## Unit Frames
### New
- Target, focus and boss frames fade when the unit is out of range, like party and raid frames. Measured with your own spells, so it follows your class's range.
- Target and focus: **Show Threat** (off), below Combo Points in Edit Mode: your threat on the unit as a percent, in the threat colours, matching the Damage Meter's Threat tab. In FlareUI and Forever Style it's a big number above the portrait ring; in Addon Style it follows the health value, like "75% | 42%". Tanking, it shows your lead over the next in line.
- Target and focus: **Highlight Purgeable Buffs** (off), below Only My Debuffs: buffs you or your group can purge or dispel come first, with Blizzard's stealable border.
- Cast bars: an interrupted cast or channel stays up for a moment in red, saying **Interrupted by** and who kicked it, in their class colour. Your own failed cast says **Failed** the same way.
- Cast bars, enemy casts: a white tick shows where in the cast your interrupt comes off cooldown. It's gone once your interrupt is ready (the bar turns green) and on casts that can't be interrupted.
- Player cast bar:
  - **Latency Zone** (on): the end of the bar your latency covers, in red.
  - **Spell Pushback** (off): how far being hit has set your cast back, like "+0.5".
  - **Channel Ticks** (off): bronze lines where each tick of a channelled spell lands.
  - **Spell Queue Window** (off): a mark near the end of the bar; press your next spell after it and it goes off as soon as this one ends.
  - It greys out while your target is out of the spell's range, and its **Border Texture** can be changed in Forever Style too.
  - Edit Mode's sample takes turns between a cast and a channel to show all of this.
- Pet frame: a **Cast Bar** for your pet's casts, with the target frame's options. Off by default.
- Health Text on every frame: **Health Lost** (how much health is missing, like "-1.2K") and **Current (Max) | Percent** (like "18K (24K) | 75%").
- Power Text on every frame is a dropdown with the same choices as Health Text (apart from Health Lost): None, Percent, Value (the default), Value | Percent, Current (Max) and Current (Max) | Percent.
- **Timer colour** (off), below Aura timer: aura timers turn yellow under 10 seconds and red under 5.
- **Aura swipe** in the Unit Frames settings (Both by default): how the time left shows on the aura icons of every unit, party, raid and boss frame.
- The target frame's **Combo Points**: in FlareUI Style a dropdown above Show Level, **Classic** (gems round the portrait, the default), **Modern** (the bar along the health bar) or **Off**; in Addon Style a switch.
- The five-second rule spark also runs on the Mana on Shapeshift strip, for druids powershifting.
- Totems: **Aura Swipe** and **Aura Timer** in Edit Mode, with a live preview, and new default places in each style.
### Changed
- Health Text: **Current | Max** is now **Current (Max)**, like "18K (24K)", and **Value + Percent** is **Value | Percent**.
- Unit frame styles save only what you changed from the defaults, so later updates to a default reach every style, and shared profile strings get smaller.
- Edit Mode: **Class Colours** sits below Background Opacity, and **Cast Bar Border Texture** right below Cast Bar Texture, on every frame that has them.
- A unit with more shield than missing health (at full health too) shows Blizzard's shield glow at the end of its health bar, on every frame.
- Player cast bar: a finished cast fills the bar and fades out, as Blizzard's does.
- **Player cast bar** is part of **Main frames** in the Unit Frames settings.
- Focus frame: **Hide Auras** is gone. Set Buffs and Debuffs to Off for the same result; if it was on, that's done for you.
### Fixed
- Pinging an enemy through a FlareUI frame in a dungeon or raid no longer causes an error that stopped pings until a /reload.
- Target of Target and Target of Focus show a player's class colour when the target is a creature, and the right name and level when the target switches who it's targeting.
- Other players' Russian, Chinese and Korean letters no longer show as boxes on FlareUI's frames, Damage Meter rows and tooltips, whatever font you picked.
- A fight starting while Edit Mode is open no longer leaves sample frames stuck on screen, or buff timers frozen on sample times.
- Portraits no longer stay blank after a loading screen.
- A unit that dies clears its power text at once, Smooth Bar Animations no longer leave a sliver of health on a dead unit, and a hunter feigning death no longer shows "Dead".
- Cast bars: a channel chained right after another no longer shows without its bar, and the player cast bar can no longer stay up if the game misses the cast's end.
- Range fading for druids in Cat or Bear Form uses melee range.
- Combo points update when your points move to a new target.
- Addon Style: the ready check mark sits in the middle of the health bar.
- Totems: in Edit Mode, right-clicking the sample totems can no longer dismiss a real totem.

## Party, Raid and Boss Frames
### New
- Main tanks: **Tank Targets** (off), in Edit Mode: what each main tank is targeting, in a small frame below or right of theirs. Click it to target that mob.
- Raid: **Power Text** (None by default) and **Power Bar for Mana Users Only** (off).
- Boss frames: **Highlight Purgeable Buffs** (off): buffs and enrages your group can purge, dispel or soothe come first.
- Boss frames close up when a boss despawns, so there's no empty slot between the bosses still up, in combat too.
- A dead member fades by the distance to their corpse, measured with your resurrection spell.
- Hovering a party or raid member's buff or debuff shows the member's tooltip instead, so mouseover healing isn't covered. Boss frames keep their aura tooltips.
### Fixed
- Party frames show when you join a group in combat, instead of after the fight. Raid frames and Hide Player Frame while in party react too.
- Dispel Icons: one symbol per debuff type you can dispel, each type always in the same spot.
- Dispellable Debuffs Only: boss debuffs and other important ones (like Living Bomb) stay visible, as with Blizzard's own option.
- Key bindings from click-cast addons like Clique work when hovering the frames.
- A pet called mid-fight no longer covers the next party frame: room for a pet is kept under hunters and warlocks.
- A member whose class arrives late gets their class colour at once, and a member who disconnects or comes back fades or brightens at once.
- The phasing icon only shows for members within 250 yards.
- When bosses swap slots mid-fight, each frame shows the right name and auras.
- Forever Style: incoming heals and shields are no longer drawn too long.
- Only My Debuffs: flagging yourself for PvP switches the target's debuffs to yours without retargeting.

## Resource Bars
### New
- Swing timers (all off, at the bottom of each bar's Frame section in Edit Mode): **Stand-Still Zone** on the Ranged bar, **Queued Attack Colour** on the Main-Hand bar (gold while Heroic Strike, Cleave, Maul or Raptor Strike waits) and **Waiting State** (full and grey while auto attack is on but no swing runs).
- Power bar: **GCD Spark** (off): a spark crosses the bar during the global cooldown.
- Health bar: its own **Class Colours** and **Low Health Colour** (off): red under 30% health.
- The power and druid mana bars shade the mana your current cast will cost.
- Power and mana text: a **Percent** choice.
### Fixed
- Swing timers follow the classic rules mid-swing: attack speed changes (Flurry, Slice and Dice, Rapid Fire) speed up or slow the swing in progress, parrying hastens your next main-hand swing, and finishing a cast (Slam, a heal, Aimed Shot) restarts the swing.
- Swing timers keep dimming out of range, stop on death, restart at a swapped weapon's speed, and end the off-hand bar when it's removed.
- Incoming heals on the health bar keep their green colour.
- With only swing timers on, Blizzard's Personal Resource Display is left alone.
- A fight starting in Edit Mode no longer leaves the bars on sample values.

## Action Bars and Proc Glow
### New
- Proc Glow lights spells that a proc buff empowers: Ice Lance with Fingers of Frost, Arcane Missiles with Missile Barrage, Fire Blast with Wake of Fire, Shadow Bolt with Shadow Trance, Soul Fire with Decimation, Starfire with Eclipse, Lightning Bolt with Maelstrom Weapon, Aimed, Arcane and Multi-Shot with Rapid Killing, Holy Nova with Searing Light, and Holy Light with Infusion of Light. In a fight the glow follows the game's own proc alert, or the buff's icon when you track it in Blizzard's Cooldown Manager. Forever's spell IDs come from ProcDoc by wsmaxcy, with thanks.
- **Dim on cooldown** (off), at the end of the Tweaks section: buttons turn grey while their spell or item is on cooldown (not the global cooldown).
- Each bar's Show Condition: **Not mounted** (travel forms and flight paths count as riding) and **Combat + In a group**.
- Faded bars show while your spellbook is open, so you can drag spells onto them, and in Quick Keybind mode.
- Fake Cooldown Manager: a button flashes the moment its cooldown is ready again.
### Changed
- **Auto-Paging for Stealth** covers druids: Prowl in Cat Form switches Action Bar 1 to its own page.
- **Update Spell Ranks** catches up: ranks learned while it was off move onto your bars at login. The first run on a character moves every spell to its best rank; after that, a lower rank you place yourself stays.
- Edit Mode shows an orange line under Visibility when Blizzard's own Bar Visible hides the bar anyway.
- The FlareUI XP bar is always on with the Action Bars module; place and size it in Edit Mode.
- The red "most options are in Edit Mode" banner is gone from the Action Bars and Unit Frames settings.
### Fixed
- Hide Pet Bar (and the stance, possess and totem bars): a pet revived or called in a fight no longer brings the pet bar back.
- Rogue Stealth paging: Shift+number and the page keys turn the page again while stealthed.
- The out-of-range tint follows a button's new spell at once after a stance, form or page change.
- Clean Keybinds: controller buttons keep their icons, numpad "." shows as "N.", and large keybind fonts are no longer cut off.
- Proc Glow: buff-proc glows no longer stick after a fight, and Overpower, Revenge and the like no longer blink off as the global cooldown ends.
- Faded bars: no cooldown flash on bars faded below half, a flyout opened from a faded bar stays up, bars set to show in combat come up on the first frame of a fight, and changes made during a fight count at once.

## Buffs and Debuffs
- **Visibility** in the Buffs and Debuffs Edit Mode panels: Fade group, Show, Fade Speed and Min Alpha, as on the action bars.
- **Aura Swipe** and **Aura Timer** in the Buffs and Debuffs Edit Mode dialogs, with the samples changing as you pick.
- **Timer colour** (off): timers turn yellow under 10 seconds and red under 5.
- **Aura icon shape**, **Aura swipe** and **Aura timer** are named as in the Unit Frames settings.
- Changing an aura size or font restyles the icons in place, also inside dungeons and raids, instead of leaving hidden icons behind until a /reload.

## Radial Menu
### New
- A **Party** category in the Catalog: your helpful spells, spread over your group as a button for you and each party member. Aim at a person and cast without changing your target; buttons turn red when they're out of range.
- **Quest Items**, first in the Catalog's Items: one button holding your quests' usable items. Switch between them with the mouse wheel (LB and RB on a controller).
- Buttons turn red when their spell or item is out of range, stackable items show how many you carry, spells with charges show their charges, and world markers show a check mark while placed.
- **Radial scale** at the top of Options > Look: 70% to 150%.
- Setting a key the game already uses asks first, and the radial list shows "also bound to …" in orange.
### Changed
- With Update Spell Ranks on, a spell button casts the best rank each character knows; a lower rank you put on a radial on purpose stays.
- A shared radial leaves out spells, items and mounts this character doesn't have; the editor lists them greyed.
- Toggle: pressing the key again closes the radial without using anything; only a click uses a button.
- During a hold, Escape or a left-click cancels the radial.
- Macro buttons run your macro as it is now, and renaming a radial keeps macros typed with its old name working.
- Mount buttons summon by name, with the Mount Journal's own "can't use" check.
- Radials tab: the live preview sits at the foot of the right column with **Undo changes**, the Catalog got the room, and buttons show as the radial's own round buttons.
### Fixed
- World marker buttons show the marker they place (each icon was wrong).
- Pressing Shift, Ctrl or Alt while holding a radial key no longer loses the release and leaves an invisible layer over the screen.
- Holding two radial keys, letting go of the first no longer fires a button of the second.
- Toggle on a mouse button fires the aimed button on the second press, as with a key.
- Menu Position changed during a fight no longer makes the lit button and the one that fires differ.
- The editor stores a dragged spell as the spell, never its spellbook slot, and a cancelled key capture no longer clears Undo.

## Controller and Gamepad Mode
### New
- The settings window works with the controller again: the D-pad moves, A uses, LB and RB switch tabs, LT and RT switch pages, B closes. In the Radials tab X removes a button and Y picks it up to move it.
- Radial Menu: a **Controller** row for each radial: **Controller stick** (L3 or R3, alone or with LT, RT or both: up to eight radials) and **Gamepad bar** (put a radial on a slot of your controller bar).
- Radial Menu: the aimed button stays lit when you let go of the stick and R3 uses it; **Release the stick to use** (on) and **Press again to repeat** (off).
- Quality of Life > Controller: **Rumble on alerts** and **Rumble on procs** (both off).
### Changed
- Radial Menu: **Controller support** is on by default (it only acts in the Gamepad UI), and L3 stays Auto Run unless you give it a radial.
- Quest Tracker: in Gamepad mode the game's own tracker shows, so D-pad Up, its quest items and its menus work with the controller.
### Fixed
- The camera holds still while you aim a radial in a fight.
- FlareUI no longer opens Blizzard menus or windows that can hang the game in Gamepad mode, and What's New no longer opens by itself there.
- Faster Camera Zoom leaves the stick's zoom alone.
- With ConsolePort, Improved Forever, Easy Controller or Controller Forever loaded, FlareUI leaves the controller to them.

## Chat
### New
- **Copy chat button** (on): a small note icon in the top right corner of each chat window opens Copy Chat for it. It replaces the tab menu's Copy Chat entry.
- **Min Alpha**, below Fade Speed: how far the chat fades out, 0% (the default) to 90%.
- Saved History keeps conversation only (what players say and your whispers, including whisper tabs), each line with the time it was said, and a grey "Saved history ends here" line between sessions.
### Fixed
- The arrow-key history brings back a line with its channel, so a recalled whisper goes to the same person.
- Up and Down don't recall during chat lockdown (boss fights, rated PvP), and secure commands such as /cast are no longer kept.
- A whisper you start switches to its new whisper tab straight away.
- Close in the tab menu gives the window's channels back to the main window, as Blizzard's does; whisper windows no longer offer Pop Out or Lock.
- Saved History: Battle.net friends come back as the right friend, lines come back in their own colours above today's chat, and the Combat Log is no longer saved.
- Web addresses are clickable on lines that also hold a link, and clicking a cut-off tab scrolls the tab row correctly.

## Damage Meter and Threat
### New
- A **Threat Meter** section (all off): **Pull aggro line** (110% of the tank's threat in melee, 130% at range), **Pull warning** (your bar flashes from 85%) and **Tank's lead**. Turning one on shows sample rows on the Threat tab.
- **Threat Value Display**: percent (the default), value and percent, or value only. The mouse wheel scrolls a long list.
- **Reset on entering a dungeon** (off).
- **Min Alpha**, below Fade Speed.
- The meter's gear menu has a **FlareUI Settings** entry.
### Changed
- The settings have a **Frame** tab and a **Tweaks** tab. The Toggle Threat Meter key binding is gone (the radial's Toggle Threat Meter still works).
- A note at the top when Blizzard's own Visibility for the meter hides it in fights, with a button to Edit Mode.
### Fixed
- **Match chat size** makes the meter exactly the chat's size.
- The Combat Timer shows the length of the segment each window shows, and keeps counting after a /reload in a fight.
- Threat tab: no swapping places on equal threat, no "0 0%" rows, no freezing when the mob is only your target's target, and pets take their owner's colour.
- The Countdown button shows only for those allowed to start one, and the Ready Check and Countdown buttons follow promotions in a fight.
- A long list no longer slides under the title row in a fight, and the meter shows fully while its settings page is open.

## Quest Tracker
### New
- A quest's tooltip lists its rewards: XP, money and items.
- **Pin to Top** and **Wowhead Link** in a quest's right-click menu.
- Timed quests show a thin bar under the timer.
- **Visibility** in its Edit Mode panel, as on the action bars.
### Fixed
- Quests offered by an item or an area show at the top, with "Click to view quest".
- In a fight with quest item buttons showing, the list holds still and the buttons stay usable, so a button can't end up beside the wrong quest.
- Clicking a quest opens the map on that quest the first time, also with map addons like OpenMap.
- Minimizing a tall tracker near the top of the screen no longer drops it to the bottom.
- Scenario objectives follow Blizzard's own rules, and objectives that fill a bar show their percentage.
- No more "Auras cannot be accessed when secret" error from Blizzard_MawBuffs on level-up.

## Minimap and XP Bar
### New
- Minimap (square): the whole square zooms and pings, corners included.
- **Middle-click menu** (on): game panels from a middle-click on the map. Not in combat.
- **Coordinates on hover** (on): the coordinates show only while you point at the map.
- The zone map (Shift+M) gets FlareUI's thin bronze border, and its tab drags it.
- XP bar: a tooltip again, with XP, rested XP, quest XP and **XP per hour** with the time to level; standing on reputation, progress on honor. It lists each quest ready to hand in with its XP.
- XP bar: **Quest XP** is a choice: Off, Finished quests, All quests or Quests in this zone. Your setting carries over.
- XP bar: a short light runs over the fill when you gain XP.
### Changed
- Addon Button Bag: smaller buttons, six to a row, and it also collects buttons on the minimap's backdrop or named by other icon libraries.
- Auto zoom out sits right below Style.
### Fixed
- With a node addon such as Lueur and Find Minerals or Find Herbs on, a black square no longer chases the mouse cursor.
- Edit Mode's minimap options are no longer removed from Blizzard's own list.
- An addon loaded later gets its minimap button into the Addon Button Bag too.
- The Toggle Minimap key is no longer undone when a faded map fades back in.
- XP bar: a level-up lands at once, and a faded bar no longer catches the mouse.

## Tooltips
- Item tooltips: simpler stat lines. "Equip: Increases damage and healing done by magical spells and effects by up to 12." reads "+12 Spell Power", set bonuses included.
- **Compare with Shift** (on): the tooltips of the gear you wear show beside an item only while you hold Shift. Turning it off restores your own setting. The Tweaks section is in two columns.
- **On action/data bars** (renamed from On action bars) also covers the XP bar.
- Set to Never on action bars, pet bar, macro, mount, toy and flyout tooltips hide too, and chat link comparison tooltips follow the tooltip scale.

## Quality of Life
### New
- **Bags and Looting** with options for Blizzard's bag windows: **Columns**, **Gaps between bags**, **Integrated bag buttons**, **Rarity colours**, **Thicker borders**, **Junk coin** and **Upgrade arrow** (a green arrow on gear you can wear that scores higher than what you have on). They stand aside when another bag addon is loaded.
- **Open flight map at once** (off): a flight master with no quest for you opens the flight map straight away. Hold Shift to talk normally.
- **Fade map while moving**, **Double-click to fish** and **Fishing sounds** (all off).
- **Buy more than one stack** (off): Shift+click to buy several stacks at once.
- Nameplates: **Level before name** (off).
### Changed
- Durability Warning also shows in the middle of the screen with a sound, ignores thrown weapons, and notices items that mend themselves.
- Sell Junk says how many items it sold and the gold that came in, sells what the server skipped a moment later, and Auto Repair says when you can't afford it.
- Hide Error Messages keeps "bag is full" errors and hides ping errors.
- Alert Sounds: no alert for your own ready check, and no double sound.
- Gameplay is laid out in two columns, and Combat enemy plates comes first in Nameplates. The Party frames title option is gone.
- Max Camera Zoom, turned off, puts back Blizzard's own default.
### Fixed
- Auto Accept Quests no longer takes grey or repeatable quests the game hasn't fully loaded, and Auto Turn-In leaves quests that take battleground marks to you.
- Move Any Frame: a window that closes while you drag it keeps its position; the loot window and windows the game protects are left alone.
- Auto-type "delete" no longer keeps the cursor in the box, so Enter can't delete by mistake.
- Faster Auto Loot empties a loot window that reports its items a moment late.
- Skip Loot Confirmations also skips the Disenchant roll confirmation.
- Camera and nameplate settings are remembered per character when the game saves them per character.

## Settings and Profiles
### New
- A **Language** page, thanks to parchinskiy: turn off **Use the game language** to pick English or any translation the addon has. The settings window makes room for longer text.
- Profile import shows a preview: tick which parts to take, as a new profile or into the one in use, with the version and UI scale the string was made with, and any missing fonts or textures.
- Profiles: **Rename**, without a reload.
- Search understands other words ("transparency" finds Opacity, "aggro" finds Threat), plurals and words run together, lists matching tabs and sections first, and finds Edit Mode and font settings.
- Shift + mouse wheel over the settings window sizes it, 70% to 130%.
### Changed
- Closing the settings window with changes waiting for a reload asks "Reload now / Later".
- About: the slash commands sit one per line.
- Spanish (Mexico) clients use the Spanish (Spain) translation where there is no Mexican one.
### Fixed
- Each character's profile choice sticks across restarts and no longer spreads to your other characters.
- A damaged or hostile profile string can't freeze the game or break a frame.
- A "Reload now" button left up when a fight starts no longer turns invisible while still catching clicks, and Escape or Enter in a fight no longer answers a dialog while also reaching the game.
- Opening FlareUI from Options > AddOns no longer closes Blizzard's options window in a way that could lose key binding changes.
- Reset every setting no longer ticks again Edit Mode checkboxes you had unticked.

## Performance
- Party and raid frames: health, heals and shields are drawn at most once per frame per member, a pull no longer redraws everyone at once, and power ticks only move the bar.
- Power bars only redraw for their own power type, and only frames that are shown listen for range.
- Proc Glow reads the Cooldown Manager only when something changes, instead of four times a second.
- Chat: names are formatted once per message, lines shown in several windows once, and the hidden Combat Log no longer costs anything.
- Damage Meter and Threat tab: rows are styled once, and in a raid the threat list only redraws for its own mob.
- Radial Menu: pressing a radial key no longer rebuilds every radial.
- Settings search waits for you to pause typing, and the window draws each page once.
- Many smaller savings across Resource Bars, the XP bar, the Quest Tracker, faded bars and Show Threat.

## For Testers
- `/fui errors`: the last 20 errors FlareUI caught quietly, with version, build, language, class and level, ready to copy into a bug report. `/fui errors clear` empties it.
- `/fui taint`: notes when one of Blizzard's controller systems turns tainted, and the addon the game blames. `/fui taint report` lists them.
- `/fui perf`: the report's "highest" column is labelled "highest 1 s average".
- Several safety checks on values the game keeps secret in combat and instances.

# FlareUI 4.3

Radials that know which character they belong to, a cleaner Radial Menu page, an official FlareUI Edit Mode layout, a round minimap and two action bar tweaks.

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## New
- Radial Menu: each radial has its own **Available to** (all characters, all Alliance or Horde characters, all characters of a class, or only this character) and its own **Key**, shared by every character that gets it. Your characters pick up their radials at login, so a Druid radial stays on your Druids. Two radials can share a key: on a character that gets both, the narrower one wins. Tick **Only this character** to give one character its own key.
- Radial Menu: **Copy** a radial (handy for a Horde or class version), and **Create macro** right next to its key.
- Minimap: **Style**, Square (the default) or Round, Forever's own round minimap, thanks to parchinskiy. Needs a reload.
- The **FlareUI Edit Mode layout**: copy its code from the bottom of the About page (or the new page in the setup tour) and import it in Edit Mode to set your screen up like ours.
- Action Bars, Tweaks: **Steady attack highlight** (on): Attack, Auto Shot and Shoot stay lit in red while they're on, instead of blinking.
- Action Bars, Tweaks: **Gryphons behind bars** (off): the art at each end of the main bar sits behind your bars instead of over them.

## Changed
- Radial Menu page: one Radials tab with your radials on the right, what opens on this character below them, and a bigger editor with a two-column Catalog. The Keybinds tab is gone: your keys were moved onto your radials and every character keeps the keys it had.
- Radial Menu now sits below Quality of Life in the settings list.
- Party frames: new default places for Forever Style and FlareUI Style (frames you already moved stay where they are).
- Quest Tracker: an empty tracker says why, instead of looking minimized.

## Fixed
- Action bar 1: the page arrows no longer hide under the left gryphon.
- Pet bar with Show button art: the frames no longer hang over each other.

# FlareUI 4.2

Stack counts get their own font, chat windows can be made click-through from the tab menu, and every aura frame now follows one shared set of rules, which fixes several aura bugs.

## New
- Buffs & Debuffs and Unit Frames: **Aura stacks** font on the Fonts tab, with face, size, outline and shadow for stack counts, separate from the timers. It starts as a copy of your timer font, so nothing changes until you edit it. On unit frames its size can be **Auto** (the default), sized to the icon.
- Chat: **Make Uninteractable** in the chat tab's right-click menu, Blizzard's own option. Links in that window stop reacting and it can't be resized. Docked windows switch together. Right-click the tab again to undo it.

## Changed
- Unit Frames, Aura timers font: its Size now works. **Auto** (the default) keeps sizing the timer to the icon.
- Party, raid and main tank frames: with dispel icons on, a debuff you can dispel shows only as its dispel icon, no longer a second time in the debuff row, like Blizzard's raid frames.
- Boss frames pick their debuffs the same way as the target frame, no longer by party-frame rules.
- The "Restore your Edit Mode layout?" prompt after switching characters now reloads your interface to finish the switch.

## Fixed
- Target, focus and pet: **Only My Debuffs** hid other players' debuffs on friendly units and on yourself. It now filters enemies only, like Blizzard's target frame.
- Action bars could vanish in combat until the fight ended after restoring an Edit Mode layout from FlareUI's prompt.
- A Lua error when opening Edit Mode in combat or in an instance with Buffs & Debuffs on.
- Party and raid frames: the dispel highlight added a hidden slot each time you changed its look in Edit Mode.
- Pet frame: Hide Buffs no longer hides timed buffs while the pet is far away, like target and focus.

# FlareUI 4.1

Your damage meter as a chat tab, a real Clear All for raid markers, and two fixes.

## New
- Damage Meter: **Meter tab in the chat**, off by default, thanks to Gregory Duhamel. A Meter tab joins your chat tabs and shows Blizzard's meter inside the chat window, at the chat's size. Click a chat tab to get the chat back, in combat too. A chat tab whose messages arrive while the meter covers them lights up. Find it in Settings > Damage Meter > Meter Tab, with:
  - **Open the Meter tab**: When clicked, In combat (back to the chat after the fight, the default), In group or At login.
  - **Ignore chat fade**: the chat window stays up while the Meter tab is open.
  - While the tab is on, the meter's own Visibility waits, and it doesn't show in the Gamepad UI.
- Radial menu: **Clear All Markers** removes every raid marker on players and enemies at once. Add it from the Markers category in the radial menu editor. New radials get it on their own.

## Changed
- Radial menu: the two old clear slices now say what they do: **Clear Target's Marker** and **Clear World Markers** (the flares on the ground). If your "Clear All" slice never removed the marks over heads, it was Clear World Markers: swap it for Clear All Markers.
- Combat + Attackable Target (Fake Cooldown Manager, fading bars and Resource Bars): a dead target no longer counts, so clicking a corpse to loot it doesn't bring the bars back.

## Fixed
- Player cast bar with Cinematic: it no longer stays hidden after a login or /reload.

# FlareUI 4.0

A lighter FlareUI: the same features, doing far less work behind the scenes. Plus separate buff and debuff sizes, a lighter Forever bar texture and macro cooldowns in the radial menu.

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Performance
FlareUI got a full performance pass. Nothing was removed or changed in how it looks or works; it just stops redoing work that hasn't changed. In our own testing, FlareUI's CPU use stayed under 0.2%.
- Power bars: a power change was drawn twice in the same frame. Now once. Most noticeable for energy and rage.
- Resource Bars: each power tick now only moves the bar and its number, and the Druid Mana bar ignores energy and rage ticks.
- Quest tracker: it reads the quest log once per redraw instead of three times, no longer rebuilds the whole list every 2 seconds while you stand still, and skips text and fonts that haven't changed.
- Fading bars: bars that have finished fading are no longer checked 20 times a second.
- Proc glows: only warriors and paladins follow the target's health (for Execute and Hammer of Wrath).
- Party frames: in a raid, the hidden party frames no longer re-lay out on every roster change or raid pet change, and hidden pet and target tiles wait until they show.
- Threat meter: no work while it's hidden or faded out, and it reuses its lists instead of building new ones up to five times a second.
- Unit frames: fewer updates per health and power tick on the player frame, the mana cost overlay and the quest icon.
- New: **/fui perf** measures FlareUI with Blizzard's addon profiler. `/fui perf start <name>` records a scenario, `/fui perf stop` saves it and `/fui perf report` gives you text to paste in a bug report.

## New
- Every frame with auras: **Buffs Size** and **Debuffs Size** replace Aura Size, so each can have its own size. Both start at your old Aura Size. On party, raid and boss frames, dispel icons follow Debuffs Size.
- Health Text: **Current | Max** on every unit, party, raid and boss frame, in every style, and on the Resource Bars health bar.
- Bar textures: **FlareUI Forever (Light)**, the Forever texture as bright as FlareUI Flat. FlareUI Forever stays as it was, and stays the default.
- Mana on Shapeshift: the druid mana strip now shows its number when Power Text is on.
- Radial menu: a macro shows the cooldown, the usable state and the icon of the spell or item it would cast right now, following `#showtooltip` and conditions like `[mod:shift]`. In the radial menu editor, macros show that spell's or item's tooltip.

## Changed
- Target of target and target of focus always show the first name only, whatever Full Player Names is set to.

## Fixed
- Party frames: pets now fade when out of range, like the members.

# FlareUI 3.0.9

Quests that accept and turn themselves in, swing timers only when you're swinging, and FlareUI in Brazilian Portuguese.

## New
- Quality of Life: **Auto accept quests** and **Auto turn-in quests**, both off by default. Hold Shift to stop them for a moment. Repeatable quests, a choice of rewards, a gold cost and PvP quests always wait for you, and grey quests aren't auto-accepted. They do nothing in the Gamepad UI.
- Quality of Life: **Gamepad mode prompt**, on by default. Turn it off to stop FlareUI asking about Blizzard's Gamepad UI when you press a controller button, handy for ConsolePort. `/fui pad` still switches.
- Resource Bars: **Only When In Use** in the Show dropdown of the swing timers. A bar appears when its weapon swings, so there's no off-hand or ranged bar unless you're using one.
- Brazilian Portuguese translation, thanks to paulovnas.

## Changed
- Swing timers now default to Only When In Use. If yours were on Combat, they probably changed too: pick Combat in each bar's Show dropdown in Edit Mode to go back.
- Chat: an unread whisper tab now shows in your whisper colour instead of red, and Battle.net whispers in their own colour.

## Fixed
- Chat: closing a tab scrolls the tabs back to the first one.
- Minimap: the day/night button goes back to its corner if something moves it. Players with EnhanceQoL reported it stuck over the calendar and clock.
- Move Any Frame: a group finder page still detached from its window now snaps back when it opens, even with Move Any Frame off.

# FlareUI 3.0.8

Cleaner portraits on faded frames, Forever Style draws Blizzard's whole ring, and windows are easier to move and close.

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Changed
- FlareUI Style party, raid and boss frames: the selected frame now gets a brighter border instead of white lines.
- Forever Style: the dispel glow on the name box is stronger, in Edit Mode's preview too.
- Move Any Frame: a window starts moving as soon as you drag its title bar, with no dead zone.

## Fixed
- FlareUI Style: on a faded or out of range frame, the end of the bars no longer shows through the portrait.
- FlareUI and Forever Style: the ring and portrait no longer show through the level disc on a faded frame.
- Forever Style: the portrait ring is whole, with its full shadow, and joins the frame in a straight line.
- Target, focus, party and raid frames: Hide Buffs hid every buff on a group member too far away to see, because the game sends no durations at that distance. It now pauses for them. With Only My Buffs on, party and raid frames can still show none at that distance.
- Move Any Frame: the close button works across its whole area on the AddOns window and others without a portrait.
- Combat text no longer draws behind the swing timers and other Resource Bars.

# FlareUI 3.0.7

Fixes a Lua error from 3.0.6 on cast bars.

## Fixed
- Cast bars: since 3.0.6, enemy casts in combat could flood you with Lua errors from Backdrop.lua, which could also appear when you opened Edit Mode.

# FlareUI 3.0.6

The group finder stays in one piece when you move it, and crafting shows the right icon on your cast bar.

## Fixed
- Move Any Frame: moving or scaling the Looking for Group window pulled its pages away from the window and its tabs, and it stayed that way. It now moves and scales as one window. If yours came apart, it goes back together and returns to its default spot.
- Cast bars: crafting showed a question mark or the wrong icon. It now shows the item you're making.

# FlareUI 3.0.5

Fewer options on your frames: four that we couldn't confirm work properly on Forever are gone.

## Removed
- Party, raid and main tank frames: **Big Defensive**. It showed everyday buffs such as paladin seals and herb gathering in the middle of the frame.
- Party, raid and main tank frames: **Bigger Boss Debuffs**. Boss debuffs now show at the same size as the others.
- Party, raid and main tank frames, player frame: **Focus Boss Debuffs**. Every debuff your other settings allow now shows in boss fights too.
- Party and raid frames: **Missing Buffs**.

# FlareUI 3.0.4

See everyone's buffs on party and raid frames, DoesItDie on your target and focus frames, and new tooltip options.

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## New
- Unit frames: **DoesItDie** now works on FlareUI's target and focus frames, with no setup: a mark for the damage your DoTs still have left, and a skull when that's enough to kill. Its own marker, skull and focus settings still apply.
- Tooltips: **Show guild name** (on by default), **Show guild ranks** and **Hide faction**. Blizzard can hide tooltip text in instances and some fights, and these options can't change those tooltips.
- Edit Mode: clicking or dragging a portrait ring, level disc, attached cast bar, party pet or party target now selects its frame.

## Changed
- Party and raid frames, main tanks: **Only My Buffs** is on by default, and turning it off now really shows everyone's buffs. Before, off still hid most of them. Raid frames only hold three icons, so **Hide Buffs** on a time limit helps there.
- Boss frames: every buff on the boss now shows, apart from what **Hide Buffs** leaves out.
- Buffs and debuffs: timers read s, m, h and d in every language, in the Buffs & Debuffs frames and on unit frames.

## Fixed
- Boss frames: **Hide Buffs** did nothing.
- Cinematic: FlareUI's player cast bar stays up between fights, so hearthing, gathering and quest objects show their cast. Cinematic's Cast bar row no longer hides it.

# FlareUI 3.0.3

A NEW tag now points out recently added options.

## New
- Settings: new options show a **NEW** tag, and so do their tab and page. Once you've opened a page and moved on, its tags are gone for good. New installs don't get them.
- Options > AddOns: FlareUI's row shows a **NEW** tag while any of its pages still has one. Not in the Gamepad UI.

## Changed
- Action Bars: **Button art** is now **Show button art**.
- Quest Tracker: **Collapse completed quests** is now **Collapse completed**.

# FlareUI 3.0.2

Better proc glows on your action bars.

## New
- Proc Glow: **Victory Rush** now glows while you can use it, and goes dark during its cooldown.

## Fixed
- Proc Glow: Revenge goes dark after you use it, instead of staying lit for the rest of its window. It comes back when you next block, dodge or parry. Blizzard can hide your casts in dungeons and raids, so there it may stay lit as before.
- Proc Glow: a glow should no longer flicker or go out when you press another ability during the global cooldown.
- Proc Glow: procs already active when you reload now glow right away, and a glow that got stuck clears the next time you change zones.
- Proc Glow: reaction abilities are now checked by class, so a spell with the same name on another class no longer glows by mistake.
- Performance: Proc Glow does less work on classes with no reaction abilities.

# FlareUI 3.0.1

Simpler action bar paging, class colours for each frame, and more ways to read your XP.

## New
- Unit frames: **Class Colours** is now in each frame's Edit Mode dialog, under Look, on the player, target, focus, target of target, target of focus, party and raid frames. It's on by default. If you had the old option off, every frame starts off. The Resource Bars' health bar follows the player frame.
- XP bar: **XP Bar Numbers** in the Action Bars settings shows current / max, a percentage, both, or what's left to go. Reputation and honor use it too.
- Action Bars: **No Auto-Paging for Stances** keeps a warrior's Action Bar 1 on its page when changing stance. It's off by default, but stays on if you'd already stopped stance paging in 3.0.

## Changed
- Action Bars: **Allow Auto-paging** is now one toggle, **Auto-Paging for Stealth**, for rogues. Druid forms and warrior stances are back to Blizzard's own paging, and bars 2 to 8 no longer page. If you'd set it to No Auto-Paging, the new toggle starts off.
- Quest Tracker: shift-click now tracks and untracks quests. Ctrl-click sets the focus.
- Unit Frames settings: **Class colours** moved to Edit Mode.
- Action Bars settings: **Fade Options** is gone from the page. Fading is still in each bar's Edit Mode dialog.

## Fixed
- Action Bars: reports of druid form paging not working since 3.0 should be fixed by the paging change above.

# FlareUI 3.0

Portrait versions of your target of target and focus target frames, smooth bars, a much better Quest Tracker, and animations where they count. This one's big, so here's the lot.

## New
- Unit frames: **Target of Target** and **Target of Focus** now have small portrait versions in FlareUI and Forever Style, like the pet. **Simple "Target Of"** in the Unit Frames settings keeps the plain frames, and the two keep separate settings and positions.
- Unit frames, Resource Bars: **Smooth Bar Animations** in Edit Mode makes health and power glide to their new value. It's off by default, and sits under Background Opacity on every frame that has it. Target of Target and Target of Focus don't have it.
- Pet frames: **Auras** and **Aura Ordering** in Edit Mode, in every style. Buffs and Debuffs are off by default.
- Target, focus and boss frames: **Hide Buffs** in Edit Mode, set to Permanent by default, which is how they already behaved.
- Resource Bars: **Background Opacity** in Edit Mode.
- Buffs & Debuffs: **Arrival animation** fades new icons in as they drop into place. It's off by default.
- Buffs & Debuffs: opening the settings page shows sample icons, so you can see your Timer, Icon Shape and Swipe choices as you change them.
- Quest Tracker: quests slide in when accepted and out when turned in, the rest make room, and a finished objective gets a soft sheen.
- Quest Tracker: timed quests show a countdown that goes from green to yellow, orange and red, even on a collapsed quest, and they stay listed when you leave their zone.
- Quest Tracker: completed quests show their own text, like where to turn them in. Auto-complete quests finish when you click them.
- Quest Tracker: scenario objectives show above your quests, a line shows the gold a quest still needs, and your focused quest shows its next waypoint when the game gives one.
- Quest Tracker: new options in the settings:
  - **Collapse completed quests**
  - **Hide finished objectives**
  - **Hide quest level**
  - **Focus buttons**
  - **Voice buttons**, with the Spoken addon
- Quest Tracker: **By progress** in Objective Sorting, and **Quest Spacing** in Edit Mode.
- Quest Tracker: **Show on Map** and **Link to Chat** in the right-click menu, and shift-click a zone heading to fold all its quests.

## Changed
- Forever Style: **Background Opacity** is gone from unit, party and boss frames. The frame's own art is the background there, and the slider only painted over it.
- Forever Style: Target of Target and Target of Focus use smaller text.
- Action Bars, Unit Frames: the banner pointing to Edit Mode is shorter and harder to miss.
- Buffs: the default position moved down by one pixel. Only frames you haven't moved follow it.
- Fake Cooldown Manager: the setup button and its right-click hint only show as available when a bar uses it.

## Fixed
- Action Bars: **No Auto-Paging** now really stops Action Bar 1 changing page with a warrior's stance. Picking another bar for Auto-Paging does the same.
- Quest Tracker: quest levels use the same colours as the quest log.
- Quest Tracker: failed quests now say so.
- Quest Tracker: opening a quest from the tracker in combat or in the Gamepad UI is now refused with a message. It could cause errors or break controller bindings.
- Buffs & Debuffs: sample timers now show in Edit Mode.
- Party, raid and boss frames: possible errors from hidden names in instances.
- Quality of Life: Sync Blizz UI could fail to save your chat windows.
- The prompt to reload after copying interface settings now tells you how if you answer it in combat.
- Performance: less work in raids, mainly on party and raid frames, roster changes, threat on hidden frames, swing timers, and big guilds with Level Before Names on.
- A smaller download.

# FlareUI 2.10.0

A setup tour for new players, and a mana bar for druids in Bear and Cat Form.

## New
- A **setup tour** now greets new players. It shows what each part of FlareUI does, lets you turn each one on and pick your unit frame style, and explains where the options live. Nothing changes until you click **Reload and finish** on the last page, and you can skip it from the first page.
- About: a **Start Tour** button runs the tour again, and so does `/fui tour`.
- Player frame: **Mana on Shapeshift** in Edit Mode shows a thin mana bar under the power bar when a druid is in a form that doesn't use mana. It's off by default, and isn't available in Forever Style.

## Fixed
- Chat: voice chat's "who's speaking" names no longer sit on top of the mute buttons or flash to the left when someone stops talking. They stay above the chat's left edge. Other alerts that share that spot follow the same stack.

# FlareUI 2.9.0

The Combat Log's filter buttons are back, nameplates can hide names, and voice chat no longer sits on top of your chat.

## New
- Chat: the Combat Log's filter buttons now show in a small bar at the top of its window, with the log text below it. They were hidden before.
- Quality of Life: **Hide Names** in the Nameplates section hides unit names on Blizzard's nameplates. It's off by default. Friendly players shown by name only keep their names.

## Changed
- FlareUI palette: mana bars are a brighter, more saturated blue, so they're easier to tell from shaman health bars.
- Chat: voice chat's mute and deafen buttons and its "who's speaking" names now sit above the chat window, and the names no longer jump from side to side. Other alerts that share that spot, like voice channel prompts and Delves toasts, move above the chat too.

## Fixed
- Chat: clicking the Combat Log tab no longer makes the whole window shorter.
- Edit Mode: clicking a chat tab no longer makes the chat's selection box and size options disappear. The tab stays put while Edit Mode is open, and docked tabs all share the main window's size.

# FlareUI 2.8.1

A text option for your power bars, and a clear message if FlareUI doesn't load properly.

## New
- Resource Bars: the power and druid mana bars have a **Text** option in Edit Mode, to show the value or nothing.

## Fixed
- If FlareUI's files don't load completely, it now says so in chat and tells you what to do, and `/fui` shows the same message. Before, you'd only get a line about a missing library, and `/fui` did nothing. If you see this, restart the game, and reinstall FlareUI if it keeps happening.

# FlareUI 2.8.0

Your fonts work again, shaman and rogue health bars stand out from their power bars, and Edit Mode shows where a frame will land.

## New
- Chat: **Increase line height** in Tweaks adds a little space between chat lines. It's off by default.
- Edit Mode: while you drag a FlareUI frame, a ghost shows where it will land. Snapping needs Snap to Elements on, and the grid counts while Show Grid is on.

## Changed
- FlareUI palette: shaman health bars are a deeper blue and rogue health bars a deeper yellow, so they're easier to tell from mana and energy. Names, tooltips and the Blizzard palette keep the usual class colours.
- Edit Mode: the Frames checkboxes for FlareUI's frames turn on once when a frame first runs, this update included, so it's there when you open Edit Mode. The tick may appear after your next reload. Untick one and it stays unticked.
- Resource Bars: bars only snap to each other when Snap to Elements is on.

## Fixed
- Fonts: most fonts showed as Friz Quadrata. Any font you pick now loads, and text switches to it as soon as the game has it.
- Fonts: on non-English clients, text falls back to the game's own font for your language. FlareUI's fonts are now listed on Russian clients too. Fira Condensed and Roboto Condensed have Cyrillic letters; the other three don't.
- Addon button drawer: minimap buttons with no frame name now go in the drawer, such as Forever++'s.

# FlareUI 2.7.0

More control over how your bars, XP bar and minimap fade, and a sign pointing at the options that were there all along.

## New
- Edit Mode: yes, FlareUI has more options. No, they didn't go anywhere. They've been in Edit Mode this whole time, behind the buttons that say Edit, which take you right to them. Since those buttons turned out to be a little too subtle, the Unit Frames and Action Bars pages now have a banner saying so, with an **Open Edit Mode** button. Edit Mode itself now tells you to click a FlareUI frame the first time you open it. You've got this.
- Action bars, XP bar: each one now has its own **Fade Speed** and **Min Alpha** in Edit Mode, so a bar can fade to see-through instead of disappearing.
- Fade groups: **Fade group** is now the top option, and a group shares its Show Condition, Fade Speed and Min Alpha. Pick a group to see what's set for it. A change from any bar in the group applies to all of them.
- Minimap: it can now fade too, with Show Condition and Fade Speed in Edit Mode. It fades on its own, all the way out, because the game won't let addons fade the player arrow or quest marks.
- Party frames: your own frame in the party now shows the Five-Second Rule spark when the player frame has it on.

## Changed
- Fade Player and Pet: now one percentage, below Colour Palette, choosing how far the frames fade. 100% is no fading. If you were already fading, it shows 0%, the same as before.
- Action bars: Fade Speed moved from the settings page to each bar in Edit Mode. Your old speed stays until you change it.
- Edit Mode: bar, XP bar and minimap options now sit under a **Visibility** title.

## Removed
- Minimap: Map Size is gone, as it didn't work well. The map goes back to its default size. Use Edit Mode's Scale to resize the whole minimap.

# FlareUI 2.6.2

A fix for errors when changing fonts.

## Fixed
- Fonts: picking a font that won't load no longer causes errors, as it did on the Buffs & Debuffs page. That text uses Friz Quadrata instead, in every module.

# FlareUI 2.6.1

A fix for the round minimap showing inside the square one.

## Fixed
- Minimap: Forever's round map frame no longer shows inside the square minimap when another addon tints it, as BetterBlizzFrames does at every login.

# FlareUI 2.6.0

Pet frames in your frame style, portraits you can click, and the option to hide your player frame while in a party.

## New
- Pet frame: in FlareUI Style and Forever Style the pet frame now follows your style, as a small version of your player frame. Your old pet frame settings are kept: turn on **Simple Pet Frame** in Unit Frames > Look to go back to the plain frame. Addon Style keeps the plain frame.
- Party frames: **Hide Player Frame while in party**, below Show Player in Edit Mode. Your player and pet frames hide while you're in a party, and come back solo and in a raid. Your frame in the party has the same right-click menu.

## Changed
- Unit Frames settings: every option in this section now applies to all styles, including Fade Player and Pet, colours, names, auras and fonts. The values from the style you're using now become the ones used everywhere.
- Unit Frames settings: Full Player Names now sits above Class Colours.
- Party and boss frames: the default Spacing is 14 in every style. Spacing you already have stays as it is.
- FlareUI Totems: new default positions, sizes and totems per row in FlareUI Style and Forever Style. Totems you've already set up stay as they are.

## Fixed
- Portraits and level discs in FlareUI Style and Forever Style now work like the rest of the frame: click to select, right-click for the menu, hover for the tooltip, and click casting and pings.
- Minimap: a problem elsewhere during startup can no longer leave a round map inside the square frame.

# FlareUI 2.5.4

A clean edge for the minimap.

## Fixed
- Minimap: the map no longer pokes out past the border art at its right-hand corners.

# FlareUI 2.5.3

A small polish patch for Hide Micro Menu, the hover highlight and Forever Style.

## Changed
- Unit, party, raid and boss frames: the hover highlight is softer.
- Forever Style: the FlareUI Totems frame's default position is one pixel lower.
- FlareUI now shows under the User Interface category in the game's addon list.

## Fixed
- Hide Micro Menu: flashing micro button alerts and their tips, such as "unopened collectibles", no longer show while the menu is hidden.
- Forever Style: the name box's glow now fills the box at any frame width.

# FlareUI 2.5.2

A big launch-day cleanup: dozens of fixes across every module, and FlareUI now gives way to TomTom, Questie and OpenMap where they overlap.

## Changed
- Works with other addons: TomTom keeps /way, and FlareUI's Map pins on "/way" option greys out while TomTom is loaded. FlareUI's nameplate quest marks step aside while Questie's nameplate icons are on. Move Any Frame leaves the world map to OpenMap.
- Quest Tracker: Minimize during fights and in instances now opens the tracker again afterwards, unless you minimized or expanded it yourself.
- Profiles: exported strings only carry what you changed, so they are much shorter. Imports ignore values of the wrong type.
- Addon Button Bag: buttons their addon has hidden are no longer pulled into the bag.
- Proc Glow: uses less CPU in fights. Reactive abilities can take up to a tenth of a second to light up.

## Fixed
- Settings: searching no longer stops with a Lua error, "/way" style searches find results, and profile changes show right away.
- Reload Now works whatever your Cast on Key Down setting is, and an invisible leftover button no longer opens chat when clicked in combat.
- Chat: a whisper tab no longer breaks the tab bars when the whisper arrives in an instance. Whisper windows now follow your settings and keep their tab list up to date, tabs flash when a new whisper arrives, Filter Settings opens on the right window, and chat fades evenly.
- Raid frames: changing the layout while in a raid no longer leaves tiles misplaced or stretched. Main tank frames stop at four, and closing Edit Mode in combat removes the samples right away.
- Party and boss frames: Only My Debuffs, the aura font and border changes apply without a reload. Party frames show sample buffs as soon as Edit Mode opens, and the portrait dispel spot holds four icons.
- Unit frames: the PvP crest and level colour follow faction changes, the high level skull updates on level changes, heal and absorb bars follow maximum health changes, and clearing a target plays its sound again. Reset on the Forever Style focus frame no longer shrinks it.
- Damage Meter: Match Chat Size now works, the settings page no longer touches Blizzard's meter while the module is off, new windows are styled straight away, and hidden meters no longer show themselves at the start of a pull.
- Quest Tracker: a quest's tooltip and highlight no longer get stuck after the list updates, and Hide When Empty ignores hidden quests.
- Action bars: turning Status Colours off restores normal icons right away, out of range colours stay on after an icon updates, and #showtooltip macros use their spell's colours. Stop Auto-Add gives the setting back when turned off or when the module is off.
- Hide options: a hidden bar comes back when you untick its option, also after a visit to Edit Mode. A pet bar shown in combat hides again after it, and changes made in combat apply when it ends.
- Quality of Life: turning camera or tutorial options off restores your own values. Sync Blizz UI no longer asks for a reload just because the camera moved, and no longer fights Enemy Nameplates in Combat Only.
- Reset every setting keeps what's needed to restore your game settings, such as enemy nameplates.
- Tooltips: item quality borders stay on instead of being reset.
- Radial Menu: an extra key on an empty radial no longer fires the main radial, and switching to an empty radial closes the old one. You can drop spells on occupied rows in the editor, the Spells list hides spells you haven't learned, and a % in a radial's name no longer breaks Create Macro.
- Minimap: turning the Addon Button Bag off brings back Blizzard's addon compartment. The bag no longer ignores clicks after closing it during a drag, and opens away from the screen edge at any scale.
- Resource Bars: off-hand and ranged swing bars show after login, and the Five-Second Rule spark follows its option right away.
- XP Bar: follows the show honor as experience setting right away.
- A /reload in combat no longer leaves Blizzard's buffs or frames on screen after the fight.

# FlareUI 2.5.1

Copy a whole chat tab, smarter spell rank upgrades, and faded action bars that show when you drag a spell.

## New
- Chat: **Copy Chat** in a tab's right-click menu opens a window with that tab's lines as plain text, all selected for Ctrl+C. Lines the game keeps hidden, such as chat inside instances, are left out, and the window says so.

## Fixed
- Update spell ranks: a Train All visit now takes your buttons to the newest rank whatever order the ranks were learned in, and a button also moves if you skipped a rank in between. Lower ranks you keep on your bars on purpose still stay.
- Action bars: faded bars now show while you drag a spell or item, without Fake Cooldown Manager bars.
- Damage Meter: a window saved as collapsed can be expanded again: its button shows in the middle of the window.

# FlareUI 2.5.0

See when your interrupt is ready, jump straight to a setting from search, and spell ranks in the radial editor.

## New
- Cast bars: an enemy's cast bar on the target, focus and boss frames turns green while your interrupt is ready (Kick, Pummel, Shield Bash, Counterspell, Earth Shock or Silence). While it's on cooldown the bar keeps its normal colour, and casts you can't interrupt stay grey.
- Settings: click the path above a search result to open its page, scrolled to the setting, which flashes briefly.
- Settings: new options can show a **NEW** label on their row, page and tab. Search for "new" to list them.
- Radial Menu editor: spells show their rank ("Frostbolt (Rank 3)"), so you can tell the ranks apart and search for one. Hovering a spell or item in the Catalog or the Buttons list shows its game tooltip.

## Changed
- Unit, party, raid and boss frames: the hover highlight is brighter, a soft glow over the health bar that's easier to see.
- Settings: search ignores accents, so "ecran" finds "Écran".

## Fixed
- Player and pet frames set to fade now stay visible while you're missing health.
- Cast bars: casts you can't interrupt now turn grey during combat too.
- Auto repair no longer says "Repaired" when you couldn't afford it. After selling junk it waits for the gold to arrive, then repairs.
- Auras: changing aura options no longer piles up hidden aura icons in the background.

# FlareUI 2.4.5

Launch-day fixes: whisper tabs, Target of Target, and nothing reloads your UI in a fight.

## Fixed
- Chat: a new whisper tab no longer opens with an empty window, and whisper tabs now fade in and out like your other chat windows.
- Target of Target and Target of Focus: health and power now update during the fight, not only when the target changes.
- Reload questions: if one was closed during combat, pressing Enter could still reload the UI. Enter now opens the chat as usual, and a dialog shown in combat no longer blocks your movement keys.
- Settings: closing the window in combat no longer leaves a clickable **Reload now** button on screen.
- Quest Tracker: **Minimize in combat** now works.
- Raid frames: Missing Buffs no longer throws errors when you die during a boss fight, and no longer marks members who are too far away to check.
- Raid frames: your own frame no longer flickers faded, and members whose range can't be checked are no longer faded.
- Quality of Life: turning the module off now puts back the game settings it changed (enemy nameplates, camera zoom, tutorials). Sync Blizz UI no longer copies "enemy nameplates off" from Combat Plates to your other characters.
- Radial Menu: **Create macro** now allows up to 30 character macros, and a Toggle keybind with no radial left no longer errors.
- Fake Cooldown Manager: bars no longer stay clickable after dropping a spell during combat.
- Target frame: the Elite & Rare icon follows changes, and an old ready check mark no longer shows on a new target.
- XP bar: hides more reliably when you reach max level.

# FlareUI 2.4.4

Share your FlareUI profile as a text string.

## New
- Profiles: **Export** and **Import** buttons under the profile options. Export shows the profile in use as a string to copy; Import takes a pasted string and adds it as a new profile (your current one is never overwritten). Radial menus and Blizzard's Edit Mode layouts aren't included.

## Changed
- Profiles: the profile options sit in a **Profile** section.
- About: the note on copying links now ends the thanks line.
- Radial Menu: **Game Menu** is gone from the Panels library (it couldn't open the game menu from a radial).

# FlareUI 2.4.3

Party frames in a row again, a modern combo bar for FlareUI Style, and Only My Buffs on the player frame.

## New
- Party frames: **Orientation** is back (Vertical or Horizontal), between Style and Growth. In a row, Growth reads Right or Left. Each frame leaves room for its side auras, a pet or target on its right, and the ring in FlareUI and Forever Style.
- Target frame, FlareUI Style: **Modern Combo Points** at the bottom of Look (off by default). The combo points show as Addon Style's bar along the top of the health bar instead of gems round the portrait.
- Player frame: **Only My Buffs** right below Aura Size (off by default): only the buffs you cast on yourself.

# FlareUI 2.4.2

A bigger minimap without a bulkier frame, and a cast bar switch on the target and focus frames.

## New
- Minimap: **Map Size** in Edit Mode, in a panel under the minimap's dialog. It grows or shrinks the map itself; the border, header and buttons keep their size. Blizzard's Size slider is now called **Scale** and still scales the whole minimap.
- Target and focus frames: a **Cast Bar** switch at the top of the Cast Bar section (on by default), like the one on party and boss frames.

## Changed
- Target and focus frames: Cast Bar Texture now sits right below Cast Bar Position.
- Party and boss frames: Cast Bar Texture now sits above Cast Bar Height.

# FlareUI 2.4.1

Aura ordering on every aura frame, and the swipe choice back on Buffs & Debuffs.

## New
- **Aura Ordering**, a new section right below Auras in Edit Mode on every unit frame with auras: player, target, focus, pet and their targets, party, raid, main tanks and boss frames.
- Aura Ordering: **Sort By** (Default, Order Applied, Time Left or Name), **Reverse Order**, and **Your Auras First** (with Time Left or Name). Default keeps Blizzard's order; nothing changes until you pick one. On party, raid and boss frames the buff and debuff rows are sorted; Bigger Boss Debuffs, dispel icons and the big defensive keep their order.
- Buffs & Debuffs: the same Aura Ordering options in a new section of their settings page (Order Applied by default, as before). The icon shape and timer options now sit under **General**.
- Buffs & Debuffs: **Swipe** is back in General: Over the icon, Around the border, Both or None.

## Changed
- The aura swipe now runs over the icon and its border together (**Both**): the default on Buffs & Debuffs, and on every unit frame aura (player, target, focus, pet, party, raid, main tanks and boss).
- Buffs & Debuffs, Around the border: a slightly thicker ring and richer border colours.

# FlareUI 2.4.0

New aura filters, party and boss frames on Forever Style's frame plate, Growth for party and raid frames, a reworked controller radial, and a full clean-up pass.

## New
- Party and boss frames in **Forever Style** now sit on the frame plate like the player and target frames, with a **Scale** slider. The name box glows for your target and for dispellable debuffs, and the ring flashes on aggro. Forever Style now also uses the ring party and boss frames.
- Party frames: **Growth** (Down or Up), right below Style.
- Raid frames: **Growth** (From the Middle, Down or Up), right below Sample Raid, for groups in rows. The main tank frames follow it.
- Party frames: **Pets** and **Party Targets** dropdowns (Off, Bottom of the Frame, Right of the Frame) above Spacing. They replace the Show Pets and Show Party Targets checkboxes. Both on the right stack, both at the bottom share a row.
- **Hide Buffs** on the player, party and raid frames (right below Debuffs): hide permanent buffs (the default), or buffs longer than 15, 10, 5 or 1 minutes. Off shows every buff.
- **Only My Buffs** on party and raid frames: only the buffs you cast.
- **Dispellable Debuffs Only** on party and raid frames: only the debuffs you can dispel.
- **Focus Boss Debuffs** on the player, party and raid frames: in a boss fight, only the boss and role debuffs show. Every debuff shows elsewhere.
- Main tank frames have their own Power Bar Height, aura places, Aura Size and aura filters, in Frame and Auras sections.
- Raid frames: new inside aura places (Centre, Centre Left, Centre Right); the places drop the "Inside," text.
- Raid frames: **Group Numbers** are now "Group N" headings above each group. Edit Mode samples follow Sort By and show a sample big defensive.
- Target and focus frames (FlareUI and Forever Style): **High Level Skull** in Icons (on by default). It shows the skull for mobs whose level reads "??". Off shows a red "??".
- Pet frame: **Happiness Position** (Centre, Right of the Frame, Left of the Frame) under Pet Happiness.
- Radial Menu: **Game Menu** and **Macros** in the Panels library.
- Radial Menu: right-click closes an open radial in Hold activation.
- Radial Menu, controller: LB and RB switch the aimed button's sub-radial choice. The centre shows the right stick icon in the Gamepad UI.
- Quest Tracker: now works in the Gamepad UI too.

## Changed
- Radial Menu, controller: **L3** opens the radial, the right stick aims, **R3** uses the button, and B or L3 closes it. The camera holds still while it is open and you can keep walking. R3 is the ping again whenever the radial is closed.
- Enemy and neutral levels use Blizzard's own difficulty colours (green, yellow, orange, red, grey) on every frame and tooltip, in every style. Friendly levels stay gold.
- **Mirror** on target, focus and boss frames, in FlareUI and Forever Style, only turns the bars' direction now. The portrait and icons keep their places.
- Party frames: the **Orientation** option is gone; party frames are always vertical.
- Party and boss frames: auras above or below the frame take one row, so the frames sit closer together.
- Party, raid and main tank frames: the big defensive is a fixed size (larger on the Forever Style plate). Missing buffs sit centred under it. Every aura sample in Edit Mode has its border.
- Raid and main tank defaults: new aura places and sizes, height 60, and a main tank position at the bottom left.
- Party and focus frames show first names only outside Forever Style (Full Player Names still decides elsewhere).
- Tooltips: the name line shows the name only. One tag at the end of the level line: (Boss) in red, (Elite) and (Rare) in gold; the elite "+" is gone. Players read "Level N Race Class" in white, and the faction line is coloured (Horde red, Alliance blue).
- The pet happiness face is a little smaller.
- A clean-up pass across the whole addon: faster chat lines, damage meter timer, tooltips, quest tracker and nameplate quest tags, plus tidier code.

## Fixed
- Radial Menu in the Gamepad UI: opening the bags (or Social) from a radial no longer causes a "blocked" error and a long freeze.
- Hide Tutorials now closes every tutorial tip, not only some.
- The player's level no longer turns gold after a level-up in the ring styles.
- Proc Glow no longer leaves a glow stuck after it is switched off and on.
- Radial Menu: deleting a radial and pressing Undo restores its keybinds too. A slot keeps its highlight when an item finishes loading.
- Settings: the "module is off" card no longer covers search results. The welcome screen counts Resource Bars as a module.
- Chat and damage meter hooks are no longer added again on every settings change.
- The weapon enchant tooltip no longer keeps lines from the last unit you hovered.

# FlareUI 2.3.1

## New
- Tooltips: **Show threat** (on by default, above Show target): turn it off to hide your threat percentage on enemy tooltips.

# FlareUI 2.3.0

Radial Menu opening options, chat link tooltips, and more control over how every unit frame looks.

## New
- Radial Menu: **Menu position** (Options tab): open radials at your mouse cursor (the default) or in the middle of the screen. Radial macros open there too.
- Radial Menu: **Activation** (Options tab): **Hold** (as before: hold the key, point, release) or **Toggle**: press the key to open the radial and keep it open. Left-click or press the key again uses the slice you point at, right-click goes back a level or closes, Escape closes. Middle-click a nested radial to open it in place of the current one; the mouse wheel still steps through it.
- Chat: **Link tooltips on hover** (Tweaks, on by default): point at an item, spell or quest link in chat to see its tooltip, without clicking.
- Unit Frames: **Background Opacity** at the end of Look in Edit Mode, on every unit frame (player, target, focus, pet, player cast bar, target of target, target of focus, party, raid and boss): how dark the empty part of the bars is, from 0% to 100%. Cast bars follow their frame's setting.
- Unit Frames: **Full Player Names** (Look, on by default): players' first names and surnames on every unit frame. Off shows the first name only.

## Changed
- Unit Frames: **Border Texture** is now on every frame in FlareUI Style and Addon Style, the player, target and focus frames included. Forever Style has no border options at all: its border is fixed on every frame.
- Unit Frames: the level of a friendly unit (anything you can't attack) shows in Blizzard's gold, in every style. Enemies keep the difficulty colours.
- Bar and border dropdowns: FlareUI's own options come first, then a line and the bars or borders other addons add, A-Z. LibSharedMedia's built-in Blizzard bars and borders are no longer listed.
- FlareUI's options in those dropdowns: FlareUI Thick and FlareUI Thin for Border Texture; None and FlareUI Frames for the Chat, Damage Meter and Quest Tracker borders; FlareUI Flat, FlareUI Forever and FlareUI Striped for Bar, Cast Bar and Absorb Texture. A frame already set to something no longer listed keeps it.
- **Frame Texture** is gone from Cast Bar Texture and Absorb Texture.

# FlareUI 2.2.1

## Fixed
- Target and focus frames: switching straight from one target to another no longer leaves the last target's debuffs on the frame. They showed up as duplicates, and their timers sat at 0 or were missing (reported in a dungeon). Party, boss and raid frames get the same fix when a new unit takes a frame (a new boss, a roster change).
- Target and focus frames: **Only My Debuffs** now shows only the debuffs you cast. Before, it showed every player's debuffs.

# FlareUI 2.2.0

Improvements from your feedback: whole-width aura rows, cast bars that make room for auras, tooltip level colours and a tidier minimap.

## New
- Unit Frames: buffs and debuffs can go **Top** or **Bottom**, across the frame's whole width. Party and boss frames get **Above the Frame**, **Below the Frame**, **Inside, Top** and **Inside, Bottom**. A whole-width place greys out the other places on that edge for the other kind of aura.
- Tooltips: the target's level is coloured by difficulty against yours (grey, green, yellow, orange, red), as quests are.
- Minimap: a **Fonts** tab for the zone name and the clock.
- Minimap: drag and drop the buttons in the addon button drawer to reorder them. The order is kept, and new addons go last.

## Changed
- Target, focus, party and boss frames: auras sit right against the frame. The cast bar shows next to the frame and, while it shows, pushes the auras on its side out past it; they come back when the cast ends.
- Party frames: **Left of the Frame** is gone from the aura places, and boss frames lose **Right of the Frame**. Auras set there move to the other side.

# FlareUI 2.1.1

## Changed
- Bar texture dropdowns (bars, absorbs, cast bars, the XP bar) no longer list LibSharedMedia's built-in Blizzard textures (Blizzard, Blizzard Character Skills Bar, Blizzard Raid Bar, Solid). A frame already set to one keeps it. Textures from other media addons still show.
- Libraries updated: LibSharedMedia-3.0 (latest) and AceDB-3.0 (Ace3's WoW Forever character names). Your settings are kept.

# FlareUI 2.1.0

Two new looks: Forever Style unit frames on Blizzard's own frame plate, and FlareUI Style party and boss frames with the portrait ring.

## New
- Unit Frames: **Frame style** (Unit Frames > Look) has three choices: **FlareUI** (the bronze ring beside FlareUI's bars, the default), **Forever** (new) and **Addon** (plain frames). Each style keeps its own setup: sizes, positions, totems, and the party and boss frames.
- Forever Style: the player, target and focus frames on Blizzard's Forever frame plate, with its name box, health and power slots and the bronze ring. **Scale** in Edit Mode sizes the frame in Blizzard's proportions, Width stretches it. The name sits in the name box, the health and power texts in the middle of their bars.
- FlareUI Style: the **party and boss frames get the portrait ring**. Party frames: the player frame's ring and level disc, the role icon where the PvP crest sits, the leader crown and raid marker on the ring, the ready check and summon / resurrect / phase icons on the portrait. Boss frames: the target frame's ring and level disc (a skull for ?? bosses) with Blizzard's elite, boss and rare frames. Both have **Portrait Size**. Raid-Style party frames stay as they are.
- **FlareUI Forever** bar texture: Blizzard's Forever health bar art, now the default for every bar (unit, party, raid, boss and resource bars, every cast bar, the XP bar). Absorbs keep FlareUI Striped.
- Party Frames: **Dispel Icons** is a switch and sits on the portrait: up to four, two to a row (in the middle of the health bar on frames without a portrait).
- Damage Meter: a **Header** font in the Fonts tab, for the title row (Damage Meter or Threat, the session and its timer).
- XP Bar: **Bar Texture**.
- Unit Frames: **PvP Timer** in Addon Style too, **Show Level** on every frame, **Hide Auras** on the focus frame.
- Boss Frames: **Mirror** and **Only My Debuffs** (both on by default), and **Absorb Texture**.
- Edit Mode: sample incoming heals and shields on the unit frames, sample aura timers, and portraits on the party and boss samples.
- The Target, Focus and Pet Edit Mode dialogs have the "FlareUI settings" button too.

## Changed
- Each style has its own defaults for the player, target, focus, pet, totems, party and boss frames: sizes and positions to fit its look.
- Classic combo points follow the style: always on in FlareUI and Forever Style, off in Addon Style (the option is gone).
- Party and boss auras above or below the frame fit as many to a row as the frame's width allows, as the unit frames' auras do. Auras above or below any frame sit closer to it.
- Aura size: 18 on the focus frame, 24 on the player and target frames, by default.
- Incoming heals use the frame's bar texture. Shields always grow back from the end of the bar (Absorb Reverse Fill is gone).
- The dispel highlight colours the frame's own border.
- Party, boss and raid frames show no timers on auras inside the frame.
- Unit Frames page: Colour palette sits under Frame style; Hide Player and Pet is now **Fade Player and Pet**.
- Party Frames: Party Targets is now **Show Party Targets** and Pets **Show Pets**; Spacing sits under Orientation; Target Gap is gone (fixed); Portrait sits above Health Text; Dispel Highlight above Dispel Icons (raid frames too).
- Raid Frames: Spacing and Group Spacing moved to the Raid section, under Groups.
- Icons: Raid Target is now **Raid Markers**.
- Only My Debuffs is no longer on the player frame. Power Bar for Healers Only is gone: party and raid frames show everyone's power when Power Bar Height is above 0.
- The PvP timer sits right beside the PvP crest.

## Fixed
- Minimap: the addon button bag no longer takes in Questie's quest markers (or other addons' map pins), which stretched it down the screen.
- Damage Meter: the bar font reaches every row, group members joining later included.

# FlareUI 2.0.15

## New
- Action Bars: **Allow Auto-paging** (last in Tweaks, Action Bar 1 by default): the bar switches to its own page in Stealth, a druid form or a warrior stance. Forever doesn't switch any bar by itself. The new page starts empty: fill it while in that form.

## Changed
- Unit Frames: the Frame section of the player, target and focus dialogs is reordered: Width, Height, Power Bar Height, Portrait Size (was Ring Size), Portrait, Health Text, Power Text.
- Settings: the window is a little taller.

# FlareUI 2.0.14

Ready for Forever's new client build: the minimap and the Forever style frames follow Blizzard's new look.

## Changed
- Minimap: the header uses Forever's new buttons: the bronze zone plate under the zone name and clock, and the new tracking and calendar buttons.
- Forever style frames: the player's portrait has the round ring, mirroring the target's, as Blizzard's player frame now does.
- Forever style frames: the PvP crest sits where Blizzard's new frames put it, without a disc and in front of the level disc. The level disc and number are a little smaller, as on Blizzard's frames.
- Forever style frames: the combo points around the target's portrait are placed and sized as Blizzard's, clear of the ring and above the PvP crest.
- Forever style frames: fighting in a rested area, the player's ring shows the combat glow and swords, as Blizzard's frame now does.

## Removed
- Minimap: the group size flag. Forever's minimap no longer has an instance difficulty banner.

## Fixed
- Minimap: works again after Forever's client update (it stopped with "could not find the Blizzard minimap cluster").
- Minimap: the addon button bag no longer shows an addon twice when it has its own minimap button and an entry in Blizzard's addon menu.

# FlareUI 2.0.13

## Fixed
- Auras: setting the aura text outline to **None** no longer causes a Lua error.

# FlareUI 2.0.12

## Fixed
- Damage Meter: no more Lua error about `durationSeconds` when a fight starts or ends. FlareUI no longer runs Blizzard's own visibility check for the meter; it reads Blizzard's answer instead.

# FlareUI 2.0.11

See what your party is targeting, and a fix for the ranged swing timer.

## New
- Party Frames: **Party Targets** (in the Party section, off by default): a small frame beside each member shows what they are targeting (under each member when the party is horizontal). Click one to target it too. **Target Gap** sets the space between them, and the **Target** section has the width, height and border.

## Changed
- Party Frames: the Party section is reordered: Style, Orientation, Sort by Role, Show Player, Pets, Party Targets, then Spacing.

## Fixed
- Resource Bars: the **Ranged Swing** bar (and the off-hand one) no longer stays hidden when the game hides your attack speed.
- Tooltips: no more Lua error about a forbidden object when hovering a buff or debuff on an enemy nameplate (fixed in 2.0.10).

# FlareUI 2.0.9

Tidier Edit Mode dialogs, more options back for your frames, and a big clean-up under the hood.

## New
- Party Frames: **Missing Buffs** (under Auras, off by default): out of combat, the group buffs a member lacks that you can cast show in the corner across from the buffs.
- Party Frames: a **Pet** section for the pet frames' width, height and border, shown while Pets is on.
- Boss Frames: a **Boss** section with Growth and a new **Spacing** slider.

## Back again
- Cast bars (Player Cast Bar, target, focus, party and boss): **Hide Icon** and **Hide Spell Timer**; target, focus, party and boss also get **Cast Bar Height**, **Texture** and **Border Texture**.
- Unit Frames and Party Frames: **Absorb Texture** and **Absorb Reverse Fill** in the Look section.
- Party and Raid Frames: **Big Defensive** and its size; Party Frames: **Spacing**.
- Action Bars: **Clean keybind text**, **Button art** and **Stop auto-add spells**.

## Changed
- Edit Mode: every FlareUI frame's dialog uses the same sections in the same order: Frame (Width and Height first), Look (textures), Cast Bar, Auras, Icons. Resource bars have Frame and Look sections too.
- Damage Meter: it remembers whether you picked Threat or damage, even after a reload. Threat View in Combat goes back to your pick after the fight.
- Damage Meter: it always shows in Edit Mode, whatever its visibility.
- Quest Tracker: the default width is 250.

## Fixed
- Ability Proc glow: Overpower, Revenge, Execute and the other reaction abilities glow again.
- Resource Bars: the Fonts tab's text size now changes the bars' text.
- Tooltips, Damage Meter, Unit Frames and the durability warning: fewer chances of Lua errors from hidden combat values.
- Status colouring: switching it off clears the grey from your buttons at once.
- Clean keybind text: switching it off brings Blizzard's labels back without a reload.
- Chat: the header buttons can no longer flicker between shown and hidden.
- Addon bag: an addon with both a minimap button and an addon-drawer entry shows once.
- Radial macros: a macro naming a radial that doesn't exist prints a message instead of an error.
- Changing unit frame fonts or colours updates raid and boss frames right away.

# FlareUI 2.0.8

## Changed
- Quest Tracker: **Shift + click** or **Ctrl + click** a quest to focus it, and again to unfocus it. While you're typing in chat, Shift + click still links the quest. Untrack Quest is in the right-click menu.
- Nameplates: the quest "!" sits just beside the nameplate instead of over its edge.

# FlareUI 2.0.7

## Fixed
- Damage Meter: no more Lua error about `durationSeconds` during fights. FlareUI no longer brings the meter up itself in combat: Blizzard does when the fight starts, and FlareUI's Visibility catches up when it ends.

# FlareUI 2.0.6

## Fixed
- Tooltips: **Health bar** and **Show target** now work on players' tooltips too, not only NPCs and pets. The Show tooltips rules (like Hide in combat) apply to players as well.

# FlareUI 2.0.5

## Changed
- Move any window: the mouse wheel over a window zooms the camera again; only Ctrl + mouse wheel resizes the window.
- Chat: Copy Line is gone.

## Fixed
- Fake CM: a bar you take off the cooldown display can be clicked again right away, without a reload.
- Move any window: Ctrl + right-click to reset a window's size no longer pins a window you never moved, and does nothing in combat on windows the game locks.
- Gray out known items: turning it off clears the grey from the vendor page at once.
- Chat Formatting: the explanations now match what each option does.

# FlareUI 2.0.4

New Quality of Life helpers, your chat formatting back, and a settings panel that explains every option on its own.

## New
**Quality of Life** (all off until you switch them on)
- **Gray out known items:** recipes and items you already know are greyed out at vendors.
- **Mail address book:** a button beside Send Mail's "To:" lists your other characters and the last one you mailed.
- **Alert sounds:** ready checks, summons, resurrections, group invites and dungeon queues flash the taskbar and play a sound, even with sound effects off.
- **Pet food marker:** a paw marks the food in your bags your hunter pet eats.
- **Skip loot confirmations:** no "will bind to you" question when you loot or roll.
- **Combat enemy plates:** enemy nameplates show only during fights.
- **Frame numbers:** hides the damage numbers on your portrait and the health and power numbers on Blizzard's frames.

**More options**
- Action Bars: **Update spell ranks**: a newly learned rank replaces the old one on your bars (lower ranks you placed on purpose stay).
- Chat, Damage Meter and Quest Tracker: **Frame Border**, with None to hide it.
- Move any window: **Ctrl + mouse wheel** resizes a window again; Ctrl + right-click resets it.

## Changed
- Chat: the **Formatting** options are back (better NPC and player names, timestamps, short channel names, level before names).
- Settings panel: every option has its own explanation, with lists where it helps, and the dog is back in the info panel.
- Chat has Frame, Tweaks and Fonts tabs; Quality of Life has Gameplay, Interface and Advanced tabs; Tooltips has Look and Tweaks sections; Quest Tracker has a Frame section, with Display above Minimize.
- Action Bars: Fake Cooldown Manager has its own **FakeCM** tab and no on/off switch: it's on while a bar is picked.
- A few options have clearer names, like **Train all skills** and **Hide level box**.
- Translations: the dots and bullets that kept some phrases from translating are gone.
- FlareUI is about 7 MB smaller.

## Fixed
- Dungeon Journal's minimap button goes in the addon drawer and can be clicked.
- Legacy Forever's tracker section no longer disappears when FlareUI's quest tracker is on.
- Clicking a link in the settings opens the copy box in front of the panel, with a sound.

# FlareUI 2.0.3

## Fixed
- Unit Frames: with **Hide Player and Pet** on, your player and pet frames now show at the same moment as the target frame when you pick a target, instead of a moment later.

# FlareUI 2.0.2

## Fixed
- Unit Frames: **Hide Player and Pet** (was Hide Player and Pet out of combat) hid your frames too often. They now hide only while you're out of combat, have no target and are at full health. Pointing at either frame still shows both.

# FlareUI 2.0.1

You asked for your options back: fonts, textures, fade speeds and more are in. The settings are easier to scan too.

## New
**Fonts**
- A Fonts tab on Action Bars, Unit Frames, Resource Bars, Buffs & Debuffs, Chat, Damage Meter, Quest Tracker and Tooltips: font, size, outline and shadow for each text.

**Look**
- **Bar Texture** and **Border Texture** for each unit frame (player, target, focus, pet, their targets, party, raid, boss, cast bar) and each resource bar, in a Look section of its Edit Mode dialog. The Forever style's bronze frames keep their own border.

**Fading**
- **Fade Speed** (Instant, Fast, Slow) for action bars, chat and the damage meter.
- Action bars: five fade groups instead of three.
- Chat: **Visibility** (Always visible, Chat interactions, Combat + chat interactions) and **Fade Delay** (how long the chat stays after showing).
- Damage meter: every show and hide fades, whether combat, a group or the mouse brings it.

**More options**
- Unit Frames: **Hide Player and Pet out of combat**. Pointing at either one shows both.
- Action Bars: **XP Bar Text**, on mouseover or always.
- Chat: **Edit Box Opacity**.
- Damage Meter: switches for the **Combat timer**, the **Ready check button** and the **Countdown button**.
- Quest Tracker: a **Display** section (zone headings, completed last, quest tags, wrap long text, tracked recipes, quest count, hide when empty) and **Minimize to a button**.
- Tooltips: **Tooltip Scale**, **Health bar** and **Show target**.
- Minimap: **FPS and Latency on Clock** can be turned off.

**Settings panel**
- Click a section's title to fold it away.
- Shorter, clearer explanations in the info panel, with lists where it helps.
- Two columns for switches, and a taller window.

## Changed
- The player frame's Show option moved from Edit Mode to the Unit Frames page (Hide Player and Pet out of combat).
- Chat: the tab menu's Font Size is gone. Set the chat's size in Settings > Chat > Fonts.
- Damage meter: with Threat view in combat, the meter switches back to damage only once it has faded out after a fight.
- Action bars fade out a moment sooner after the mouse leaves.

## Fixed
- The sound of picking a target is back.
- The flight path window can be moved again. The clock, opened mail, the stable, loot history, the group finder lists and the dressing room can be moved too.
- Unit frame and party, raid and boss borders sit flush against the bars, with no gap.
- Your 1.x settings brought over by the import now include fonts, textures, the new options and the tooltip scale.

# FlareUI 2.0

A new settings panel that explains every option, Forever-style unit frames, and raid and boss frames.

This is the biggest update for this addon so far. The goal was to simplify, improve the UX, make it way more user friendly (especially for new players) and focus on the true core of FlareUI: improve, not replace, Forever's interface.

**Your 1.x settings come along:** the first time you log in, FlareUI brings over your radial menus and keybinds, your profiles, every module's on/off switch, the options the new panel still offers, your frames' Edit Mode settings and positions, and each character's quest tracker, chat history and Sync Blizz UI data. Options that 2.0 no longer has (fonts, borders, textures, the old show rules) start from the new defaults. Unit frames start in the new Forever style; switch on Addon Style Frames to get your 1.x frames back as they were.

## New

**Settings panel**
- One window for everything: modules on the left, each with its own on/off switch, the options in the middle, and an info panel on the right.
- Hover any option to see a picture of what it does and a short explanation.
- Search every setting by name.
- Changes that need a reload are collected in a bar at the bottom, with one Reload button.
- Profiles in Advanced: start a new one, duplicate the one in use, delete, or reset FlareUI.
- Opens with /fui, from the minimap's addon button, from a key binding, or from Blizzard's Options > AddOns.

**Unit Frames**
- Forever style (the default): player, target and focus in the game's own bronze ring frames. Addon Style Frames switches to FlareUI's clean frames, and each style keeps its own setup.
- Raid frames, with sizes per raid size and main tank frames.
- Boss frames, mirrored like the target frame.
- Main Frames: one switch for player, pet, target and focus.
- Colour palette (FlareUI's softer tones or Blizzard's) and one Class Colours switch for every frame.

**Damage Meter**
- Visibility: always, in combat, in a group, or hidden, plus Show on Mouseover.

**Quality of Life**
- Hide Level on enemy nameplates, with the quest mark on the health bar's edge.

**Radial Menu**
- A new character starts with the radial setup of the last character you changed it on.
- The radial editor is part of the Radial Menu page, with a live preview.

## Changed
- Fewer, clearer options: font, border and texture choices are gone, and each frame keeps its designed look.
- The radial key always opens the radial chosen in the Keybinds tab.
- Battle.net toasts appear above the chat, with a bronze border.
- Mana cost preview on the mana bar is always on.

## Removed
- The old settings window.

# FlareUI 1.6.5

## Fixed
- **Unit Frames:** Classic Combo Points work again after Forever's October update, which rebuilt the game's combo points. They now use Blizzard's new combo point art and animations, still in a row on the target frame, filling from the left.

# FlareUI 1.6.4

## New
- **Radial Menu:** an Emotes category in the radial editor: the 22 animated emotes (Wave, Dance, Salute, Sit and more), each with its own icon. They work in combat too.
- **Chat:** Up and Down (with or without Shift or Alt) step through the last 50 lines you sent, kept across reloads. Down past the newest gives back what you were typing.
- **Chat:** with the edit box inside the chat window, the newest lines move up above it while you type, and drop back when it closes.

## Fixed
- **Chat:** sharing a map pin in chat (shift-click) could be blocked with an error after using Copy Line. Copy Line now puts the line in the chat box only when it is already open, and in the copy box otherwise.

## Removed
- **Chat:** the /tt command (whisper your target).

# FlareUI 1.6.3

## Fixed
- **Buffs / Debuffs:** weapon enchants (shaman imbues like Rockbiter Weapon, poisons, oils, sharpening stones) now show at the start of your buffs, with their timer and the weapon's tooltip. They never appeared before: the game data FlareUI read them from is empty in Forever. Right-click no longer removes a weapon enchant: Forever allows that only in Blizzard's own buff frame.

# FlareUI 1.6.2

## Fixed
- **Move Any Frame:** opening the spellbook (or another window Blizzard loads on first use) for the first time during combat no longer causes an "action blocked" error. The window becomes movable once combat ends.

# FlareUI 1.6.1

Bug fixes for bag windows, Sync Blizz UI and the action bar gryphons.

## New
- **Bag Header Tooltip** (Tweaks > Windows & Settings, off by default): Blizzard's "Backpack / click for bag settings" tooltip on a bag window's header is now hidden unless you turn it on.

## Fixed
- **Bags (Move Any Frame):** left-click anywhere on a bag window's header opens its menu again (Assign To, Ignore This Bag, sorting), as in Blizzard's UI. Press and drag the title to move the window. Right-click on the header, or on the bag icon, opens the menu too.
- **Sync Blizz UI:** a character copying from the source now switches to the source's Edit Mode layout again while Remember Layout per Mode is on. It happens once per character, and that layout becomes the one remembered for the mode.
- **Action Bars:** the gryphons no longer disappear after hiding the interface with Alt+Z (with Hide Bar Art on for Action Bar 1).

# FlareUI 1.6

A quest tracker of FlareUI's own, a bag for every addon's minimap button, and a big clean-up that makes FlareUI lighter while you play.

## New

**Quest Tracker** (Modules, off by default)
- FlareUI's own quest tracker in place of Blizzard's: your tracked quests and tracked recipes in a FlareUI window, placed and sized in Edit Mode ("FlareUI Quest Tracker").
- **Current Zone First** and **Nearest First:** quests of the zone you are in go to the top, the rest follow by distance as you move. **Completed Last** sinks quests ready to turn in.
- **Zone Headings** you can collapse, a **Zone / All** switch in the header, and an optional **Quest Count** ("Quests 14/25").
- **Quest Level** and **Quest Tags** in front of the name (+ elite, g3 group of three, d dungeon, r raid, pvp), **Numbers Last** ("Boar Tusks: 3/8") and **Wrap Long Text**.
- Quest item buttons beside their quest, usable in combat, with cooldowns and a red tint while out of range.
- Hover a quest for its description, objectives and your party's progress. Click to open it in the quest log, shift-click to link it in chat (or untrack it), middle-click to collapse it, right-click for Focus, Share, Untrack and Abandon.
- **Minimize** to the header, or to a single "+" button (**Minimize Style**). A keybind too: Key Bindings > AddOns > FlareUI.
- **Auto-Minimize:** minimize or expand the tracker when you enter a dungeon, raid, battleground, arena, city or inn, the open world, or combat.
- **Untrack High-Level Quests:** quests too far above your level are untracked when you accept them, and tracked again once you are close enough.
- Its own fonts, border and background opacity. Thanks to BetterQuestTracker by deface (MIT) for parts of the quest ordering, item buttons and party progress.

**Minimap**
- **Addon Button Bag** (on): click the day/night badge to open a bag with every addon's minimap button and the addons of Blizzard's addon compartment. It closes on a second click, on Escape, on a click elsewhere or after you use a button.
- The player coordinates under the map are now in Blizzard's gold, a size larger and clear of the frame. The world map's coordinates match.

**Experience Bar**
- **Show Tooltip** (Action Bars > General, FlareUI XP Bar): turn off the tooltip on the bar.

## Changed
- **Five-Second Rule** is now off by default, on the player frame (Edit Mode) and on the Power and Mana resource bars. Turn it on in Edit Mode where you want it.
- **Radial Menu:** the dividers and the hub ring are now in FlareUI's bronze.
- **Performance:** FlareUI does far less work while you play.
  - Chat no longer runs its fading timers on every message (including every combat log line), and does nothing at all for them with Auto-Hide off.
  - Faded bars no longer do work every frame while nothing is fading.
  - Threat updates on the target and focus frames only re-colour the border.
  - Combo points on the target frame, the Combo Points bar and the nameplates only update when your combo points change, not on every energy tick.
  - The radial menu no longer rebuilds itself whenever any item is loaded by the game.
- More of FlareUI's text can now be translated.

## Fixed
- **Minimap:** Blizzard's round frame art could show under the square map after logging in with Rotate Minimap on.
- **Buffs / Debuffs:** an error in dungeons and raids (with Blizzard's addon restrictions active) while restyling the weapon enchant buttons. They now wait for the restrictions to lift.
- **Chat:** Forever's "Refreshing your world" notice is placed just above the chat again.
- **Tweaks:** Nameplate Combo Points could error on a target whose hostility the game keeps hidden.
- **Fake CM:** the Setup Mode switch no longer stays "on" after a reload while the bars are locked.

# FlareUI 1.5.1

A new look for the radial menu, new chat options and more for Sync Blizz UI.

## New

**Radial Menu**
- The radial now looks like Blizzard's ping wheel: a dark backdrop, a line between every two buttons, and the slice you point at lights up.
- It fades in and out like the ping wheel, with the buttons gliding out from the middle.
- **Button names:** the button you point at shows its name beside it. Long names go on two lines. Turn it off with **Show Button Names** (Radial Menu > Look).
- A button that holds another radial shows a row of dots under it, one per option, with the current one lit. Scroll the mouse wheel to change it.

**Chat** (Chat > Message Formatting, all off by default)
- **Level Before Names:** a player's level in parentheses before their name, in difficulty colours, like "(42) [Name]". Known for your group, guild, friends, /who results and players you have targeted or seen nearby.
- **Copy Line:** shift-click a message's timestamp to put that message in your chat box, ready to edit or send. Needs timestamps: Better Timestamps, or Blizzard's own.

**Sync Blizz UI**
- Now also copies the "Color Name by Class" boxes in the chat settings, Block Guild Invites, and your bags' settings (Assign To, Ignore This Bag, junk selling, and the backpack's sort setting).

## Changed
- **Chat:** Better Player Names, Better NPC Names, Short Channel Names and Better Timestamps now change Blizzard's own chat line instead of replacing it, so a formatted line keeps Blizzard's own player link and line data.
- **Chat:** Better Player Names now also colours names in numbered channels (Trade, General...), instance chat and whispers. Whispers keep their "whispers:" and "To" wording.
- **Chat:** Better Timestamps now applies to every chat message, not only player and NPC lines.

# FlareUI 1.5

The biggest update yet: party frames, resource bars, separate chat windows, and FlareUI can now be translated.

## New

**Party Frames** (Unit Frames > General > Frames > Party, off by default)
- Party frames in the unit frames' look, placed and set up in Edit Mode ("FlareUI Party Frames"). FlareUI makes no raid frames.
- Two styles, each with its own settings: **Classic** (larger frames, like the player frame) and **Raid Style** (compact frames with their auras inside).
- Auras follow Blizzard's raid frame rules: buffs, debuffs, dispellable debuffs with a coloured highlight, bigger boss debuffs, big defensives and private auras. They can sit inside the frame, beside it, above or below it.
- Cast bars, pet frames (only a frame with a pet makes room for it), leader, role, raid marker, ready check and status icons, each with its own size.
- **Sort by Role** (on): tank, healer, then damage. **Show Player**, power bar for **Healers Only**, and out-of-range fading.
- Edit Mode shows a sample party (warrior, priest, warlock with a pet, hunter with a pet, rogue) with sample auras.

**Resource Bars** (Unit Frames > General > Resource Bars, all off by default)
- Seven bars, each switched on by itself and placed in Edit Mode: **Health**, **Power**, **Mana**, **Combo Points**, **Main-Hand Swing**, **Off-Hand Swing** and **Ranged Swing**.
- **Mana** shows when mana is not your main power: a druid's mana in Bear and Cat Form.
- **Power** and **Mana** show the **Five-Second Rule** spark after a mana spell.
- **Combo Points:** segments in a flame red, or **Classic Combo Points** (round gems that light up with a shine).
- Swing timers turn red when the target is out of range.
- A bar that is on hides Blizzard's own (the Personal Resource Display, the swing timers).

**Chat**
- **Pop Out:** right-click a chat tab to give that window its own frame (a trade or spam window beside your main chat). Drag it by its tab or header, resize it from the corner. Its tab menu has **Dock** and **Lock Window**. The game remembers where it is.

**Unit Frames**
- **Target of Focus** frame (off by default).
- Frames with nothing to show in Edit Mode (pet, target of target, focus...) now show a sample there.

**Action Bars**
- **Auto-Paging** (General > Functionality): pick the bar that switches pages with your stance or form. Action Bar 1 by default, as Blizzard does.
- **Bar Scaling:** the **Possess Bar**.

**Visibility**
- **Hide Totem Bar.**

**Translations**
- FlareUI can now be translated on CurseForge: https://legacy.curseforge.com/wow/addons/flareui/localization. Text with no translation yet shows in English.

## Changed
- **Borders:** a new **FlareUI Thin**, slimmer, with corners that stay neat on thin bars. It is now the default for the pet, target of target and target of focus frames, every cast bar, the resource bars and the XP bar. The previous Thin is now **FlareUI Frames**, still the default for chat and the damage meter. If you picked the old Thin yourself somewhere, pick FlareUI Frames to get it back.
- **Unit frames, new default sizes and places** (only where you haven't moved or resized them): player and target 70 tall, focus 35, player cast bar 300 x 25 and higher up, target of target 100 x 25 under the target's cast bar.
- **Target frame combo points:** flame red (was teal), with thin black lines between the points.
- **Edit Mode:** a bar hidden by Visibility (stance bar, pet bar, totem bar) now stays hidden in Edit Mode too.

## Fixed
- **Move Any Frame:** a moved window no longer opens at Blizzard's spot and jumps to yours a moment later.
- **Move Any Frame:** the **Map & Quest Log** can be moved (it couldn't be dragged at all).
- **Pet action bar:** its button art was drawn full size.
- **Edit Mode settings:** changing a dropdown no longer scrolls the settings window back to the top.

# FlareUI 1.4.4

Quieter defaults: most quality-of-life extras now start off, FlareUI says less in chat, and a few small additions.

## Changed
- **Defaults:** these now start **off** (turn them on in the settings if you want them):
  - **Chat:** Extend Chat History, Save Chat History, Better NPC Names, Better Player Names, Short Channel Names.
  - **Tweaks:** Auto-Type DELETE, Hide Error Messages, Hide Party Title, Hide Contextual Tips, Hide Portrait Numbers, Sell Junk Automatically, Repair Automatically, Durability Warning, Faster Auto Loot, Train All Button, Max Camera Zoom, Faster Camera Zoom.
  - They switch off with this update even if you had them on: turn the ones you use back on.
- **Damage Meter:** the **Combat Timer** now starts on (it turns on with this update; switch it off in the Damage Meter settings if you prefer).
- **Tweaks:** with Max Camera Zoom, Faster Camera Zoom or Hide Contextual Tips off, FlareUI no longer resets Blizzard's own camera and tutorial settings. It only puts back what it changed itself. Hide Party Title and Hide Portrait Numbers work the same way.
- **Less chat:** FlareUI no longer posts a line when you switch Gamepad mode, when Move Any Frame pauses in Gamepad mode, after Sync Blizz UI, after restoring your Edit Mode layout, or when a radial closes itself.
- **Buffs / Debuffs:** the Gamepad mode note moved to a **Warning** section at the bottom of the settings.

## New
- **Radial Menu:** a **Social** panel button (the Friends window).
- **Radial Menu:** deleting a radial now asks first.

# FlareUI 1.4.3

A new XP bar, and fixes for Lua errors around Edit Mode layouts and party frames.

## Fixed
- **Party frames / Edit Mode:** with **Hide Pet Bar** on, closing Edit Mode or switching layouts threw Lua errors from the party frames (CompactUnitFrame.lua). Hiding the pet bar in Edit Mode moved whatever was snapped to it. It no longer does. The raid manager hide had the same problem and is fixed too.
- **Remember Layout per Mode:** switching the Gamepad UI on or off now asks **Restore your ... Edit Mode layout?** after the reload, instead of switching by itself. FlareUI switching the layout on its own caused the same party frame errors. Restore, Enter or the controller's A button switches the layout and closes the prompt.
- **Remember Layout per Mode:** the prompt sometimes didn't show after turning the Gamepad UI on. FlareUI saved Blizzard's fallback layout as your gamepad layout during the switch. If you saw this, pick your gamepad layout once in Edit Mode.
- **Sync Blizz UI:** the copied Edit Mode layout is now switched by the **Reload Now** button, not by FlareUI on its own (the same party frame errors). It is only copied for the input mode you're in, and not while Remember Layout per Mode is on.
- **Lua errors from Blizzard_MawBuffs ("secret" auras)** after FlareUI scaled the minimap or the quest tracker, or hid Blizzard frames. FlareUI now scales and hides Edit Mode frames without running Edit Mode's own code.
- FlareUI's prompts no longer show controller buttons while you play with keyboard and mouse.

## New
- **FlareUI XP Bar** (Action Bars > General > XP / Honor Bars > Style): one bar with XP and your watched reputation (or honor) side by side, placed and sized in Edit Mode. At max level it shows reputation and honor. **Show Text** (on mouseover or always) and **Text Format** options. **Blizzard Bars** keeps the previous reskin of Blizzard's bars. Visibility fades it as the XP bar. If you had **Reskin** on, you now get the FlareUI XP Bar: pick **Blizzard Bars** for the previous look.

## Changed
- **Buffs / Debuffs:** a note on the General tab explains that the module does not work in Gamepad mode. Blizzard keeps its own buff frame there for controller navigation.
- **World refresh:** FlareUI no longer touches Blizzard's world refresh notice (it no longer moves it above the chat or recolours its border). Blizzard's own notice is back.

# FlareUI 1.4.2

The cooldown swipe is back on your buffs and debuffs, unit frames get FlareUI's aura icons, and a round of settings clean-up.

## Fixed
- **Buffs / Debuffs:** the cooldown swipe (Border or Icon) didn't show on real auras since 1.4, only on the Edit Mode samples. It's back.
- **Buffs / Debuffs:** with Square icons, the Icon swipe now stays inside the icon's cut corners instead of darkening past them.
- **Settings:** some sliders showed grey boxes instead of bronze ones, depending on the tab you opened and where you hovered. They're all bronze now.

## New

**Unit Frames**
- The auras on your unit frames now use FlareUI's aura icons: the bronze bevel or round ring, debuffs coloured by type, and the cooldown swipe. Whether the Buffs / Debuffs module is on or not.
- Each frame sets its own aura **Shape**, **Cooldown Swipe** and **Timer** in Edit Mode (Auras section). Timer has a **No Timer** choice, which replaces the Aura Timers checkbox (if you had it off, your auras start on No Timer).
- **Fonts > Aura Text:** the font of the aura timers and stacks. Its size follows each frame's Aura Size.
- **Class Color** checkbox per frame (Edit Mode > Look), on by default. Off, players' health bars are the classic health green. NPCs keep their friendly / hostile colours.
- The Edit Mode settings fold into sections you open with a click: Frame, Look, Absorbs, Cast Bar, Auras and Icons, with the section names in gold.

**Chat**
- **Edit Box Position:** below the chat frame, above it, or inside it (as before). It replaces the Edit Box X / Y Offset sliders.

**Buffs / Debuffs**
- Timer: two more choices, **Middle of the Icon** and **No Timer**.

**Tooltips**
- **Fonts** tab: Title and Content font, size, outline and shadow. They start at Blizzard's tooltip fonts.

## Changed
- **Bar textures:** FlareUI now ships two, **FlareUI Flat** and **FlareUI Striped** (absorbs). Armory, Charcoal, Minimalist and Smooth are gone; every bar that used Armory by default is now FlareUI Flat, and a bar set to one of the removed textures switches to FlareUI Flat.
- **Damage Meter:** the bars keep Blizzard's own texture (the Bar Texture option is gone). How to Use now starts by reminding you that the meter needs **Enable Damage Meter** on in Blizzard's Settings > Advanced Options.
- **Unit Frames:** Value + Percent health reads `12.4K | 87%`. The Player Cast Bar's Texture setting is now called Bar Texture.
- **Buffs / Debuffs:** new defaults are Round icons with the Icon swipe and the timer under the icon. The Border swipe darkens more (70%), so it's easier to see. Settings you picked yourself stay.
- **Tweaks:** the page is split into two tabs, **Interface** and **Gameplay**. Remember Layout per Mode and Offer Gamepad Mode moved to Interface > Windows & Settings.
- **Fonts:** every font setting now has Enable Shadow on by default.
- **Tab order:** Action Bars is General / Visibility / Fonts / Bar Scaling / Fake CM; Tooltips is General / Visibility / Fonts / Anchor.
- **Edit Mode:** no divider line between Reset To Default and Reset To Default Position.

# FlareUI 1.4.1

Your requests: totem timers, movable loot rolls and toasts, smoother fades, and threat in combat.

## New
- **Totem timers:** with FlareUI's player frame on, shamans lost Blizzard's totem timers, which hang off the player frame FlareUI replaces. They are back on their own Edit Mode frame, FlareUI Totems, under the player frame. They are Blizzard's own timers, so right-click a totem to dismiss it as before. In Edit Mode, set the frame's Size and Totems per Row (4 for one row, 2 for a 2 x 2 grid); four sample totems show while you place it.
- **Loot rolls and toasts you can move:** Need / Greed / Pass frames and Blizzard's pop-up toasts (new recipe learned, achievements, loot won) no longer sit stuck above the action bars. Place them in Edit Mode with FlareUI Loot Rolls and FlareUI Toasts, each with a sample to see while you place it. Toasts no longer climb over the loot rolls either. Part of Tweaks: Windows & Settings > Move Loot Rolls & Toasts.
- **Damage Meter:** Features > Threat View in Combat. The meter switches to the Threat tab when combat starts and back to Blizzard's view when it ends. Off by default.

## Fixed
- Action bar fading: fades in and out were choppy, about ten steps a second. They now run smoothly at your frame rate.

## Changed
- Unit Frames: the pet frame is 120 wide again by default, with its right edge lined up with the player frame's. This only changes a size and position you never set yourself.

# FlareUI 1.4

A new module for your buffs and debuffs, and FlareUI's own frame borders.

## New: Buffs / Debuffs

Your buffs and debuffs in FlareUI's style, in place of Blizzard's buff frame. Switch it on in General > Buffs / Debuffs.

- Two frames you place in Edit Mode, FlareUI Buffs and FlareUI Debuffs, each with its own icon size, icons per row, maximum icons, spacing, and growth direction (left or right, wrapping up or down).
- In Edit Mode, every slot fills with sample icons, so you can see how far each frame can grow before you place it.
- Square icons in a bronze bevel with 45° corners, or round icons in the spellbook's passive ring.
- Debuff borders take the colour of their type: Magic, Curse, Disease, Poison and the rest.
- Cooldown swipe, three ways: a sweep over the icon with a bright edge, the border itself running out around the icon, or none.
- The timer under the icon or along its bottom edge; stacks in the top right corner.
- Weapon enchants (poisons, oils) show before your buffs.
- Right-click a buff or a weapon enchant to cancel it.
- Boss debuffs that Blizzard keeps private still show, just past the debuff frame.
- Works in dungeons and in combat: Blizzard draws the auras into FlareUI's frames.
- In Gamepad mode Blizzard's own buff frame stays, as part of its controller navigation.

## New: FlareUI Borders

- Two new borders in every border dropdown: FlareUI Thick and FlareUI Thin, a bronze bevel lit from above with soft 45° corners.
- They are the new defaults: Thin for the chat, the damage meter and the XP bar, Thick for the unit frames and cast bars. A border you picked yourself stays as it is.

## Fixed
- XP bar: Blizzard's grey frame art could come back inside FlareUI's border.

## Changed
- Chat > How to Use is shorter.

# FlareUI 1.3.1

Fixes from your reports, and a handful of new options.

## Fixed
- Chat: clicking a quest or item link on the last line of the chat opened the chat box instead of the link.
- Chat: shift-clicking a player's name invited them to your group. That's now an option, off by default: Chat > Improvements > Shift-Click to Invite.
- Minimap: a Rotate Minimap setting switched on before FlareUI kept the map rotating with a round border, and the option is hidden. FlareUI now keeps the map still; turn the Minimap module off and your own setting comes back.
- Tooltips: the defaults now match Blizzard's. Tooltips sit in the bottom-right corner, and ability tooltips on the action bars and unit tooltips on the frames show again, so hovering a group member shows their location. This only changes settings you never touched.

## New

**Unit Frames**
- Move, size and switch off each frame's icons in Edit Mode: pick one in the new Icon dropdown, then set Show Icon, Icon X, Icon Y and Icon Scale. The picked icon shows on the frame while Edit Mode is open. These replace the Elements switches in the settings window; an icon you had switched off there stays off.
- Aura Timers (Edit Mode, Auras): switch off the countdown numbers on buffs and debuffs.

**Chat**
- Drag the header buttons to change their order, the way you drag tabs.

**Damage Meter**
- Ready Check and Countdown buttons in the header. Ready Check shows when you lead or assist a group; Countdown shows while you're in a group, starts a 10-second pull timer and cancels it on a right-click. Each can be switched off in Damage Meter > Features.

**Minimap**
- Edit Mode's Size slider is back: it scales the whole minimap, frame, header and all.

## Changed
- The quest "!" on the target frame sits in the middle of the health bar, under the raid marker.
- Damage Meter: Match Chat Frame Size needs the Chat module (it matches FlareUI's chat frame only).

# FlareUI 1.3

**Grab your controller!** FlareUI now works with Blizzard's Gamepad UI on WoW: Forever, from the first button press to the last setting. Pick up a controller and FlareUI offers to switch; put it down and `/fui pad` brings the keyboard and mouse back.

## New: Controller Support

**Switching modes**
- Press any button on a controller while playing with keyboard and mouse, and FlareUI asks whether to switch to Gamepad mode (Blizzard's Gamepad UI). Answer with A or B, or click. It asks once a session and never in combat; turn it off with Tweaks > Convenience > Offer Gamepad Mode.
- `/fui pad` switches either way, at any time.
- Chat tells you which mode you are in after every switch, whether FlareUI or Blizzard's own setting made it.
- Remember Layout per Mode (Tweaks > Convenience, on by default): switching the Gamepad UI on or off resets Edit Mode to its default layout. FlareUI now brings back the layout you last used in each mode.

**Radial Menu**
- Press R3 to open your main radial, aim with the right stick, and press R3 again to use the button you point at. B closes it. The camera holds still while you aim, and the ping menu moves to L3. Turn it on with Radial Menu > Controller > Enable Controller Support.
- The radial editor works with the controller too: move with the D-pad, switch categories with the shoulder buttons, X removes a button, Y picks one up to reorder it.
- New radial buttons: FlareUI Settings, and Toggle Threat Meter (flips the Damage Meter between its own view and the threat view).

**Settings**
- The whole FlareUI settings window works with the controller. The D-pad moves between options and A uses them. Sliders and dropdowns are grabbed with A and changed with the D-pad. LB/RB switch tabs, LT/RT switch sections and B closes. Button icons show where each one leads.
- Open them with `/fui`, the FlareUI Settings radial button, or a key of your choice (Blizzard's Keybindings > AddOns > FlareUI > Open Settings).

**Chat**
- The D-pad stays on the edit box instead of wandering into FlareUI's chat buttons.
- Y opens the tab settings on every chat tab, and LB/RB icons show how to switch tabs.
- The chat uses the IM style in Gamepad mode: the Classic style hangs the game when a slash command is typed. Your own style comes back in keyboard and mouse mode.

**Unit Frames and more**
- Y opens the target menu with FlareUI's unit frames, just as it does with Blizzard's.
- Blizzard's gamepad cast bar steps aside when FlareUI's player cast bar is on.
- Tooltips show in Gamepad mode, in Blizzard's default place (there is no cursor to follow there). Your placement settings come back with the mouse.

## New
- FlareUI's own dialogs replace Blizzard's popups, and **Reload Now finally reloads**: on Forever it never did, it only told you to type /reload.
- A welcome line in chat at login.

**Chat**
- Header Buttons options (Chat > General): show or hide Social, Chat Channels, Chat Menu and Volume. The buttons line up from the right.

**Damage Meter**
- Match Chat Frame Size: the meter takes the size of your chat frame.
- Threat Toggle Keybind: one key flips the meter between its own view and the threat view.

**Unit Frames**
- Classic Combo Points moved to the target frame's Edit Mode settings and now sit at the frame's bottom-right.

## Changed
- Combo points (Classic Combo and nameplate combo points) use Blizzard's high-resolution red gems with bronze rims and a shine when they fill.
- Nameplate tweaks stand aside when another nameplate addon is running.
- Tweaks: the Hide options are laid out in rows of three.
- Chat and Damage Meter background opacity now default to 60%.
- Damage Meter > Features: Combat Timer comes first, then Threat Meter Tab.

## Fixed
- A Lua error from the objective tracker after a reload in combat.
- The 1.2.1 notes said FlareUI picked up new combo point art from that patch. The art was not in the game files; this release brings the new look instead.

# FlareUI 1.2.1

Fix for WoW: Forever build 1.60.1.70170.

## Fixed
- A Lua error at login with the Tweaks module on. It also stopped Auto-Type DELETE, the Train All button and hiding the quest tracker in boss fights from working.

## Changed
- Tweaks: the World Refresh Dialog option is gone. Since this patch the game no longer opens that dialog by itself; it only opens when you click the refresh countdown above the chat.
- The new combo point art from this patch shows on FlareUI's nameplate combo points and Classic Combo too.

# FlareUI 1.2

## New

**Unit Frames**
- Portraits on the player, target and focus frames: pick None, 3D or Class Icon in each frame's Edit Mode settings. The portrait sits in a square on the frame's left, or on the right of a mirrored frame. On mirrored frames the 3D portrait turns to face the bars; class icons keep their orientation, and NPCs show the 3D portrait.

**Radial Menu**
- Extra keybinds: up to 5 more keys per character, each opening a radial of its own (Radial Menu settings > Extra Keybind). They work like the main keybind: hold, aim, release, in combat too. A key can only open one radial; giving it to another row takes it from the old one.

## Fixed
- Sync Blizz UI: chat tab message filters and channels were copied but only showed after a second reload. Sync now offers its reload when they change.
- Damage Meter: a threat row could show the previous player's icon flipped or cropped.

# FlareUI 1.1.2

Urgent fixes for dungeons, raids and battlegrounds.

## Fixed
- Tooltips: hovering any unit inside an instance (or in a PvP match) threw a Lua error. Blizzard hides the unit from addons there; FlareUI now finds it another way, or leaves the tooltip as Blizzard drew it.
- Nameplate quest tags no longer error on nameplates whose unit is hidden from addons.
- Unit frames: the quest icon never showed for normal quest mobs, only for the rare "quest bosses". It now shows when your target or focus is part of one of your active quests.

## Changed
- Quest icons are a simple yellow "!" instead of the shield, both on nameplates (Tweaks > Tag Quest Objectives) and on the target and focus frames, where it sits on the right edge. The unit frame element is now called Quest Icon.
- Chat: the Message Formatting options say they work outside instances only, where Blizzard hides chat messages from addons.

# FlareUI 1.1.1

## New

**Radial Menu**
- Radial macros: `/click FUIRadial <RadialName>` (the name without spaces, any case) opens any radial at your cursor, so a radial can sit on an action bar, use macro conditionals ([pet], [mod:shift]...) or be opened by a button of another radial. A macro radial stays open: click a button to use it, or press the macro again to use the button you point at; right-click or Escape closes it. Works in combat.
- Radial Macros group in the Radial Menu settings: how it works, and each radial's macro line to copy.

## Fixed
- Tooltips settings: the Show with Shift option had the wrong width.
- Unit frame auras: the stack count and timer could sit under a debuff's dispel border.

# FlareUI 1.1

A big one: new features in almost every module.

## New

**Unit Frames**
- Five-second-rule spark: after you cast a spell that costs mana, a spark crosses your mana bar for the five seconds your spirit regen is paused.
- Pet happiness: your hunter pet's happy / content / unhappy face in the middle of the pet frame, with Blizzard's tooltip (damage, loyalty, diet). Switch it off in the pet frame's Edit Mode settings (Happiness).

**Damage Meter**
- Threat tab: a second view beside the meter's title, like the chat tabs. It lists your group's threat on your target, highest first, with how close each player is to pulling aggro. It follows the meter's bar style, spec icons and class colours. Option: Threat Meter Tab.
- Right-click the meter's title to choose what it tracks (Damage Done, DPS, Healing...).
- Combat Timer option: how long the fight has lasted, in the title row.
- How to Use tips in the Damage Meter settings.

**Chat**
- Short Channel Names (on by default): [2. Trade - City] becomes [2], [Guild] becomes [G].
- No Bubbles in Instances: chat bubbles off inside dungeons, raids and battlegrounds, back to your own setting outside.
- How to Use tips in Chat > General.

**Tweaks**
- Auto-Type DELETE: fills in DELETE when you destroy a rare or better item.
- Train All Button at class and profession trainers.
- Hide the Quest Tracker in Boss Fights.
- New Convenience group (Faster Auto Loot moved there); Camera & Loot is now Camera.

**Tooltips**
- Item IDs and Spell IDs options.

**Minimap**
- FPS & Latency on Clock: your framerate and latency in the clock's tooltip.

**Radial Menu**
- Cooldown swipes on the buttons, and unusable buttons dimmed (blue when you are out of mana).

## Changed
- Unit frame icons: the leader crown sits at the top-left corner and is a little bigger; the quest icon on the target frame sits on the top edge and is bigger; the raid marker sits in the middle of the health bar on every frame, at half its height. The pet frame no longer shows a raid marker.
- The pet frame is wider by default (160), its right edge in line with the player frame.
- The Blizzard Art Border option is gone.
- The Modules page no longer has About FlareUI and Inspired by (the credits are on the CurseForge page).

## Fixed
- A unit's health bar could show up on FlareUI's own tooltips, such as the chat volume button's.
- Minimap clock: the whole clock answers the mouse (only a small spot in its middle did), and its tooltip shows at once.
