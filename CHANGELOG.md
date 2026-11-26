# FlareUI 7.1

A big tidy-up of the settings: fewer rows, clearer names and a smarter Info Panel. Plus a batch of fixes from Discord.

**Restart the game fully after updating.** This version adds a new file, and a /reload doesn't load it.

**We need your help testing:**
- **Forever Style, rogues and druids:** build combo points on a target. They should show round the target's portrait.
- **Edit Mode:** open any unit frame. Check the new **Icons**, **Bar Effects** and cast bar **Show** lists.
- **Friendly Name Only plates with Show Target's Plate:** target a player, then clear the target. The name should show once, every time.
- **Druids with Keep Page 1 > On Shapeshift:** go into Cat and Bear Form. Action Bar 1 should stay on its first page.

## Heads up
Some things change even if you change nothing:
- **Nameplates, Click-Through:** now one setting for all plates. If you had it on for any plate type, it's now on for all of them.
- **Nameplates, Name Only Mode:** no longer greys out the other options. Show Plates in Combat and Show Target's Plate still give the plate its bar.
- **Nameplates, Crowd Control and Defensives:** their icons use the Auras look. Their own Aura Icon Shape, Aura Swipe and Aura Timer are gone.
- **Forever Style:** the name box always shows the full name, as on Blizzard's frames. Show Name is gone from Forever Style.
- **Swing bars:** Waiting State, Queued Attack Colour and Stand-Still Zone are always on.
- **Swing bars, Off-Hand Swing:** shows only with a weapon in your off hand.
- **Quest Tracker:** finished quests always show "(Complete)".
- **Buff Reminders:** the In Dungeons and In Raids timings are gone. Remind Before It Ends counts everywhere.
- **Gryphons:** now part of Quality of Life. They work with Action Bars off, and go back to Blizzard's with Quality of Life off.

## Highlights
- **Info Panel:** a small grey line under each option's title shows its default, whether it needs a reload, and what it needs to be on (in orange while that greys it out). Choice names in lists are gold, and every description was rewritten to be shorter and clearer.
- **Edit Mode, unit frames:** related switches are now one dropdown each, on every frame:
  - **Bar Effects:** Bar Animations, Bar Edge Glow, Damage Trail
  - **Icons:** resting, leader, PvP, ready check, raid markers and the rest, now in Look
  - **Show** (cast bars): Icon, Spell Timer, Centred Spell Name, Edge Glow, Latency, Spell Pushback
  - **Text** (swing, flight, seal and duration bars): Name, Timer, Icon
- **Copy Look to All Frames:** a button in each unit frame's Edit Mode window. It copies that frame's Bar Texture, Border, Absorb Texture, Background, Class Colours and Bar Effects to every other frame.

## New

### Unit Frames
- Party: cast bar **Position** (Above or Below). Auras on that side move past it.
- Flag carriers: **Range Check** (off) and, in Modern Style, **Portrait** (None or Class Icon).
- Main tank targets: **Target Border** and **Show Target Markers**, as on party targets.
- Pet: **Threat Glow** in every style, the simple pet frame too.

### Resource Bars
- Health, power and mana bars: **Values on Mouseover**.
- Druid Mana: **In Caster Form** is now a choice in its **Visibility** list.

### Nameplates
- Name Only Mode: **Show Level**, the level in front of the name.

### Action Bars
- **Keep Page 1** gets **On Shapeshift** for druids' Cat and Bear Form (off).

### Minimap
- **Border:** your Shared Media borders, under a line below FlareUI Thick. They may not line up with the map's edge.
- Round minimap: with **Below the Map** on, the Info Bar can use all three cells.

## Changed

### Settings, merged into one dropdown each
- Action Bars: **Keep Page 1** (In Stealth, In Stances, On Shapeshift) and Fake Cooldown Manager **Bars**.
- Nameplates: **Target Highlight**, **Threat Effects**, **Quest Marks** (Icon, Progress), **Kick Ready** (Colour, Mark), **Group Colours** (Party, Raid) and **Under the Name** (Title, Guild).
- Meters: **Pull Warning** (Flash, Sound; the sound can play on its own now) and **Auto Reset**.
- Chat: **Names** (Better Player Names, Better NPC Names, Level Before Names).
- Tooltips: **Guild** (Off, Name, Name and Rank).
- General: **Language**, with Game Language first.
- Bags & Looting: **Loot Window** (Off, Grow Down, Grow Up). Elixirs: **All in Your Bags** is now the top choice of **Elixirs and More**.
- Quality of Life: **Rumble** (Alerts, Procs). Buff Reminders: **Hide** (In Rested Areas, While Mounted) in Edit Mode.

### Settings, moved and renamed
- Quality of Life: Extras and Systems are one **Extras** tab. General: the General tab is now **Account**, and fonts are split into **Global Font** and **Game Fonts**.
- **Fake CM** is now **Fake Cooldown Manager** everywhere. Its note says why you'd use it over Blizzard's.
- Sizes in % are now **Scale** (Combat Text, Drawer Button, Name Only, Level Disc).
- Nameplate Font is now **World Names Font**: it sets the names over characters in the world and on Blizzard's nameplates.
- Nameplates: Health Text is **Bar Text**, Threat Percentage is **Threat Text**. Show Plates in Combat moved to Visibility.
- Tooltips: Coloured Borders and Class-Coloured Names moved to the first tab.
- Raid: the group order row is now **Group Order**, and Groups is **Orientation**.
- Many smaller regroups, so every section reads in the same order.

### Unit Frames
- **Bar Text** on mirrored frames: Left and Right in the menu are now the screen's sides. Your frames look the same as before.
- Edit Mode: **Combo Points** moved to Look. Opacity on Buff Reminders moved to Fading.

### Removed
- Pet: **Only My Debuffs** (it only emptied the list).
- Target and target of target: **Has a Target** in Visibility (always true on those frames).

## Fixed

### Unit Frames
- Forever Style: combo points didn't show on the target frame.
- The player frame's **Cast Name** and **Spell Timer** fonts showed while the Player Cast Bar was on, though they don't style it. They now hide then; the bar's fonts are under **Player Cast Bar**.

### Nameplates
- Friendly Name Only plates with **Show Target's Plate** and **Names Above Plate**: the name went missing on your target and showed twice after.

### Minimap
- The **FlareUI Minimap Button** switch was greyed out with Drawer Style Off.

### Edit Mode
- Raid: two rows were called Sort By.
- Loot Rolls: **Faded Opacity** showed above the switch that turns it on.

# FlareUI 7.0.18

Dragons for Modern frames, and the end of blocked bag items (we hope, for real this time).

**Restart the game fully after updating.** This version brings new art files, and a /reload doesn't load them.

**We need your help testing:**
- **Bags:** visit the guild bank, then your bank. Afterwards, right-click a potion or a recipe in your bags. It should work.
- **Druids:** fly from Moonglade to Rut'theran twice. The second flight should count down.
- **Portrait > Class Icon:** target an enemy player. You should see their class icon, not their face.
- **Cast bar with Edge Glow:** get a cast interrupted. The glow should go away with the cast.

## Heads up
Some things change even if you change nothing:
- **Bags:** FlareUI no longer opens your bags with the guild bank. Press B to open them there.
- **Open with Character Window** is gone from Bags & Looting. Your bags no longer open with the character window.
- **Modern frames:** elites, rares and bosses no longer get a gold or silver border. The border stays bronze, and a dragon shows instead (see Changed).
- **Modern boss frames and flag carriers** start a few pixels further left. Only if you never moved them.

## New

### Unit Frames
- Target of Target and Target of Focus: **Portrait** (2D or Class Icon) in Edit Mode, in FlareUI Style and Forever Style, with **Simple Target of Target** off.

## Changed

### Unit Frames
- Modern, **Elite & Rare** icon: Blizzard's dragon now wraps around the outer end of the target, focus and boss frames, instead of the skull.
  - Gold for elites
  - Silver for rares
  - Gold with wings for bosses

## Fixed

### Bags & Looting
- Items in your bags could not be used after a bank visit, until you typed /reload. The cause was FlareUI opening your bags for the guild bank or the character window.
- Buying a bank tab or a guild bank tab was blocked after the same visits.

### Unit Frames
- **Portrait > Class Icon** showed the 2D picture on enemy players.
- Cast bars: **Edge Glow** stayed on the bar after a cast was interrupted or failed.

### Chat
- IM chat style: with **Edit Box Position** Above or Below, the chat box disappeared when you stopped typing. It now stays, faint and clickable, as in Blizzard's IM style. Inside works as before.

### Resource Bars
- **Flight Timer:** the druid flight from Moonglade never counted down. It is now learned like any other flight.

# FlareUI 7.0.17

New unit frame art, a combat ring you can't miss, and a pile of fixes from Discord and GitHub.

**Restart the game fully after updating.** This version brings new art files, and a /reload doesn't load them.

**We need your help testing:**
- **Combat:** start a fight. The ring around your portrait flares, then stays red. In Forever Style, your name box turns red too.
- **Hunters:** fight in melee range. Your nameplates and frames should stay fully visible.
- **Range Check as a warrior, hunter or Bear Form druid:** step out of range. The target's frame should fade.
- **Druids:** fly from Moonglade to Rut'theran. The Flight Timer should know the flight the next time.
- **Battlegrounds:** the PvP icon shows on your frame and your party's.

## Heads up
Some things look different even if you change nothing:
- **Target Highlight > Bar:** it brightens your target's bar instead of colouring it. Its colour is gone from Pick Your Colours.
- **Party Members** nameplate colour is mint green, so it no longer looks like a mage's or a shaman's.
- **Square minimap with Border: Header:** the frame is 16 px taller at the bottom, so the map starts under the title bar.
- **Player Cast Bar:** **Width** now counts the icon. Your bar keeps its size. The default is 275.

## New

### Unit Frames
- **Show Latency** (on): the end of the cast bar shows your latency. In the Player Cast Bar's Behaviour section and in the player frame's Cast Bar section.
- With Plumber installed, clicking your pet's happiness face opens Plumber's pet food menu.

### Nameplates
- **Show Target's Plate** (off) for Name Only Mode: your target gets its full plate back. Set per unit type.

### Resource Bars
- **Bar Edge Glow** (off) on the power and mana bars.

### Buffs & Debuffs
- Totems: **Aura Icon Shape** (Round).

### Cooldown Manager
- Tracked Bars, in Edit Mode, with Growth Up or Down:
  - **Sort By** (Blizzard): Blizzard, Newest First or Newest Last
  - **Max Bars** (20)

### Quest Tracker
- **Sort By:** a new choice, By Zone and Level.

### Buff Reminders
- **Greater Blessings** (off) in the Blessing reminder's menu.

### Fading
- **Opacity** (100) under Faded Opacity, in every Visibility Fading section: how visible the frame is when it isn't faded.

### For addon authors
- **FlareUI_QuestTrackerAPI:** place your own buttons beside the quest tracker's rows. See API.md on GitHub.

## Changed

### Unit Frames
- New ring and plate art:
  - The portrait sits in the middle of its ring.
  - FlareUI Style: the whole ring and its shadow show, and the level lines up with the bars.
  - Forever Style: the bars sit inside the plate's slots.
- **Combat Glow:**
  - When a fight starts, the ring gives two quick, bright pulses.
  - During the fight it stays clearly red and never fades out.
  - Forever Style: your name box turns red and pulses with it.
- Forever Style party: **Show Name** is a choice now: Off, First Name, Last Name or Full Name.
- **Player Cast Bar:** **Width** counts the icon. By Nico-Mayer.

### Nameplates
- New quest mark art. It sits 2 px from the plate.
- The threat box uses your target's border colour and Outer Glow.

### Buff Reminders
- Food and Flask is now **Consumables to Watch**: None, Food, Flask, Elixirs.
- **Elixirs and More** lists elixirs by what they give. Your ticks are kept.

### Translations
- French updated. By Brainc3ll.

## Fixed

### Unit Frames
- **Mana on Shapeshift:** the left text hid behind the portrait in FlareUI Style.
- The PvP icon didn't show in battlegrounds, on unit and party frames.
- **Range Check:** warriors, hunters and Bear Form druids were always in range. The spells it used, such as Heroic Strike, count at any distance.

### Nameplates
- Hunters: plates and frames faded when the target was close.
- The quest mark was stretched.
- **Colour Mob Types > Caster** didn't work in dungeons.
- **Party Colour** and **Raid Colour** turned grey in Name Only Mode.

### Minimap
- The XP bar went under the minimap after you clicked it.
- **Square minimap with Border: Header:** the map sat under the title bar.

### Buff Reminders
- Custom reminders: unticking one could remove another.
- **Pet to Summon > Last Used:** the pet you already had out didn't count.

### Flight Timer
- Flights started by talking to someone, such as Moonglade to Rut'theran, were never learned.

### Move Any Window
- With TSM, Blizzard's profession window popped onto the screen.

# FlareUI 7.0.16

Aura corners that use the whole frame, a threat number that knows you're the tank, and a long list of fixes.

**We need your help testing:**
- **Dispel icons:** a friend with a Magic, Curse, Disease or Poison debuff shows the icon. Enemies never do.
- **Threat Percentage:** tank a few mobs in a group. The ones you hold are green, the ones you lost are red.
- **Buffs and debuffs Above or Below the Frame, or in one corner only:** smaller icons or a wider frame fit more on a line.
- **Meter:** use Create a New Tab, then check the new tab's list in a fight.
- **Loot window:** Growth on Up, then drag the window and loot again.

## Heads up
Some things look different even if you change nothing:
- **Buffs and debuffs in a corner:** with nothing in the corner across from them, they use the whole width of the frame.
- **Cooldown Manager:** the Essential and Utility icons and Tracked Buffs fill from the middle. Pick another **Growth** in Edit Mode to change it.
- **Name Only Mode:** the name colours from before 7.0.15 are back.
- **Skin Item Slots:** Colour by Rarity starts at green. Grey and white items have the bronze border.
- **Threat Percentage:** its colours follow your Role.
- **Loot Feed and loot rolls:** they show above the bags and other windows.

## New

### Unit Frames
- **Center Spell Name** (off): the spell's name in the middle of the cast bar.
  - In Edit Mode, in every frame's Cast Bar section
  - For the Player Cast Bar, in its Look section

### Nameplates
- Crowd control and defensive icons have their own **Aura Icon Shape**, **Aura Swipe** and **Aura Timer**. Until you pick something, they follow the other auras.

### Bags & Looting
- **Loot Window:** **Growth** (Down) and **Row Order** (Top to Bottom). By Xentinus.
- **Crafting Bag in Backpack:** each soul bag in your bag slots gets its own section.

### Cooldown Manager
- **Growth** (From the Middle) for the Essential and Utility icons, in Edit Mode.

### Minimap
- **Info Bar:** Friends and Guild. They count who is online. Point at them to see who.

## Changed

### Nameplates
- **Threat Percentage** colours:
  - Tank: green while you hold the mob, orange when you're losing it, red when you lost it
  - Damage & Healer: green while you're safe, red when it's on you
  - The green is your **You Hold It** colour
- **Name Only Mode:** names have FlareUI's colours again, and titles and guilds have a colour of their own.
- The target arrows push the quest mark and the other marks beside the plate out of the way.

### Unit Frames
- **Show Spell Pushback** comes after Edge Glow.

### Bags & Looting
- **Reverse Bag Fill** works with Category Rows. Each section fills that way under its header.

### Meters
- The gear menu's Show New Window is now called **Create a New Tab**, because that's what it does.

### Quest Tracker
- **Zone Headings** greys out with Sort By on By Level or By Progress, where there are no headings.

### Buff Reminders
- Pet Reminders are for a missing or dead pet. The one for a hurt pet never showed, so it's gone.

## Fixed

### Unit Frames
- A Lua error with buffs and debuffs in places that share an edge, such as Above the Frame and Above the Frame, Left.
- Buffs and debuffs in a corner wrapped at the middle of the frame, even with nothing in the other corner.
- Dispel icons showed where you can't dispel:
  - Players of the other faction who aren't flagged for PvP
  - Bleeds
  - Party and raid members under Mind Control
- **Threat Text:** 0% on a mob only you have threat on, where the game hides the numbers.
- The interrupt colour counted an interrupt your stance or shield didn't allow.
- "Interrupted by" stayed on the cast bar for your next target.
- **Name Above Frames:** names in other alphabets showed as boxes.

### Nameplates
- Rows of buffs and debuffs fit one icon less since 7.0.9.
- **Threat Percentage:** a red 0% on a mob only you have threat on, where the game hides the numbers.
- A plate reused in a fight could show dispel icons on an enemy.
- Plates kept the wrong type when you changed sides, as in a duel.

### Action Bars
- **Update Spell Ranks** left out the controller bars.
- The range colours also changed buttons that aren't FlareUI's.
- **Sharp Outline:** text that stayed on screen after its bar faded out should go now. We couldn't see it ourselves, so tell us if it stays.

### Radial Menu
- Party buttons kept old names after the group changed in a fight.
- Some spell ranks were wrong right after logging in.
- Party spells in a sub-radial now spread over your group.

### Meters
- The separate threat window didn't follow the meter's Opacity.
- Pointing at the separate threat window didn't bring back a faded meter.
- **Bar Texture:** it could go back to Blizzard's after a while. We couldn't find the cause, but it now puts itself right.

### Quest Tracker
- Share Quest could be blocked when a fight started with the menu open.
- Item buttons could use the wrong quest's item, and took clicks while faded out.

### Minimap
- A farming HUD that takes the map no longer gets our click area, fading and hidden dots.

### Buff Reminders
- Short buffs counted as running out too early, such as Battle Shout.

### Quality of Life
- Accept Summons no longer takes a summons out of the starting area or into a scenario. You answer those.

### Languages
- **Hungarian:** two lines had wrong letters. By Xentinus.

# FlareUI 7.0.15

A hotfix for the Lua error when you change target in a fight (our own doing, from 7.0.14), plus a few fixes and small additions.

**We need your help testing:**
- **Dispel icons:** change target in a fight with debuffs up. Friends show the icons, enemies don't.
- **Raid Manager:** join a group in and out of a fight, with it hidden.
- **Druids:** **Mana on Shapeshift** with Smooth Animated Bars.
- **Nameplates:** the colours in **Name Only Mode**.

## Heads up
Some things look different even if you change nothing:
- **Name Only Mode:** titles and guilds take the name's colour, and names take the colours Blizzard gives them. Colours you picked yourself stay.
- **Raid Manager:** if you hid it but play without our Action Bars, it's hidden now.
- **Bags & Looting:** with a font picked for Item Level, the BoE mark takes it too.

## New

### Nameplates
- **Copy From**, in Plate Setup: puts another unit's whole setup on the one you're editing. Undo Changes takes it back.

## Changed

### Nameplates
- **Name Only Mode:** Blizzard's colours for names, titles and guilds.

### Unit Frames
- **Only Mana Power Bars** (off) works in every party style, Forever Style too.
- A **Frame Style** you pick waits for the reload. By mateuszmalek.

### Bags & Looting
- The BoE mark takes the Item Level font, in the bags and the loot window.

### Languages
- **Russian:** shorter names for the Nameplates tabs and Plate Setup.

## Fixed

### Unit Frames
- A Lua error each time you changed target in a fight.
- The player and target frames got shorter when you switched **Frame Style** and back. By mateuszmalek.
- **Smooth Animated Bars** left out the **Mana on Shapeshift** bar.

### Nameplates
- The target arrows hitched at each end of their bounce.

### Quality of Life
- A hidden **Raid Manager** still showed with Action Bars off, or when you joined a group in a fight.
