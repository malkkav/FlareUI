# FlareUI 7.0.8

A small fix for errors in group content, with two more fixes from your reports.

## Fixed
- **Unit Frames:** **Values on Mouseover** spammed errors in dungeons and raids.
- **Nameplates:** with **Names Above Plate**, names could show the colour of another player or enemy.
- **Minimap:** an error in the addon drawer with addons that put thousands of pins on the minimap.

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
