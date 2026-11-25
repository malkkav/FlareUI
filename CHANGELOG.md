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

# FlareUI 7.0.14

The blocked bag clicks: potions, recipes, crates and gear that the game refused to use after a visit to the bank. It's the worst bug FlareUI ever had.

**A HUGE thank you to parchinskiy,** who hunted it down test after test until it had nowhere left to hide. Awesome work!

**We need your help testing:**
- **Bags:** use items after you visit the bank, with **Crafting Bag in Backpack** and **Keyring in Backpack** on. If one is still blocked, send us what `/fui errors` shows.
- **Crafting Bag in Backpack:** move, split, search and use items in its section.
- **Bank:** buying bank slots, and opening it twice in a row.
- **Controller:** radials on your bar if you play on two computers.
- **Nameplates:** combo points with your own plate width.

## Heads up
Some things look or work differently even if you change nothing:
- **Nameplates:** combo points follow the plate's width. A width of 150 looks as before. Wider plates get bigger points, narrower ones smaller.
- **Bags & Looting:** switching **Combined Backpack** in FlareUI's settings asks for a reload.
- **Dispel icons:** enemies' debuffs no longer show one on the target, focus and boss frames.

## New

### Quality of Life
- **Nameplate Combo Points** (off): combo points under your target, on Blizzard's own nameplates. It's on the Gameplay tab while FlareUI's Nameplates are off.

### Radial Menu
- **Pet commands** (Attack, Follow, the stances and the rest of your pet's bar): first under Pet Spells.

## Changed

### Nameplates
- Bigger maximum sizes: height 50, cast bar 40, buffs and debuffs 50, crowd control and defensives 60.
- Plates grow and shrink smoothly with **Target Scale**.

### Chat
- **Fade Delay** shows in Edit Mode with any Visibility while **Fade Old Lines** is on.

## Fixed

### Bags
- Items blocked after a visit to the bank:
  - The crafting bag in the backpack no longer opens Blizzard's bag window. By parchinskiy.
  - Keyring in the backpack: FlareUI cleans up after itself when it opens Blizzard's window.
  - Bags that open with the character window or the guild bank no longer add to it.

### Radial Menu
- Radials on the controller bar broke when you played on two computers. They go by the radial's name now: give it the same name on both.

### Auras
- Dispel icons showed on enemies' debuffs.

### Performance
- **Minimap:** with the coordinates on the Info Bar, less memory while you stand still.
- The language files are smaller: phrases nothing uses any more are gone.

# FlareUI 7.0.13

A fix for the battleground errors that came with 7.0.12, and a check of every part of FlareUI, with more than 50 fixes.

**We need your help testing:**
- **Battlegrounds:** tell us if you still see "cannot be accessed while tainted" errors.
- **Bags:** item clicks after a visit to the bank, with **Move Any Window** on.
- **Groups:** party and raid frames, with **Always Show** auras and after a /reload in a raid.
- **Action bars** that fade to nothing: clicking, dragging spells and starting fights.
- **Controller, rogues and warriors:** the radial in a fight, and **Kick Ready** on your higher ranks.

## Heads up
Some things look or work differently even if you change nothing:
- **Chat:** windows keep 128 lines again. The 500 lines of 7.0.12 caused the battleground errors.
- **Bags:** with **Move Any Window** on, a bag's title only drags. The bag menu (Assign To, Ignore This Bag) opens with a left-click on the bag's icon.
- **Action bars:** a bar faded to nothing, without Mouseover, takes no clicks, drags or tooltips. Its keys still work. In a fight it takes clicks, except on Never.
- **Nameplates:** the game's own fades (distance, not your target) are off, so only FlareUI's options fade plates. Plates you leave to Blizzard lose them too.
- **Nameplates:** a dead mob's plate goes at once. A dead player's stays.
- **Edit Mode layouts:** in a layout where you never moved a frame, it can go back to the spot it has in another layout.

## New

### Quality of Life
- **Mail Address Book:** **Remove from the List**, in its menu.

## Changed

### Bags & Looting
- **Loot Window:** while you are the Master Looter, Blizzard's loot window takes over, with its assign menu.
- **Combine Empty Slots:** free slots in a soul bag or another special bag are counted apart. Locked slots aren't counted.
- **Delete Junk When Full** keeps:
  - Soulbound greys worth nothing, and pieces of equipment sets
  - Greys in bags set to ignore junk selling, and in special bags

### Cooldowns
- **Enable Blizzard Cooldown Manager** tells you why when it can't change.

### Edit Mode
- **FlareUI Settings** in a frame's dialog asks you to save or revert your Edit Mode changes first. It used to drop them.

## Fixed

### Chat
- Errors in battlegrounds, blamed on other addons.

### Bags & Looting
- **Delete Junk When Full** deleted junk for loot you couldn't take yet: locked, yours to hand out, or double-clicked. It also ignored room in the crafting bag and keyring.
- **Plain Empty Slots** hid the padlock on locked slots.
- **Loot Roll Window:** a roll stays while the game still has it open, and never shows an impossible time.

### Nameplates
- Errors in fights with **Tint Health** on By Health, and on enemy players in battlegrounds.
- A tapped mob no longer keeps a threat colour or number.
- **Kick Ready** no longer marks friends' casts.
- No debuff type icon on enemy plates.
- The target arrows no longer move in steps.

### Unit Frames
- **Kick Ready** works for rogues from level 26 and warriors from 32, on nameplates too.
- Pointing at a faded frame's buffs and debuffs brings the frame back.
- **Totems:** with Aura Timer on None, the time is hidden.

### Party and raid frames
- **Always Show** auras from other players show.
- Everyone's buffs show when they share a place with the debuffs.
- A /reload in a raid made up to twice the frames it needed.
- After quick group changes, a frame could show the wrong player.
- Ready check marks no longer stay with the next player.
- Blizzard's hidden party and raid frames no longer work in the background.

### Radial Menu
- Changes made before a fight, such as joining a group or looting potions, are there when it starts.
- A radial that was empty opens once it has something to show.
- Macros that share a name each run their own.

### Buff Reminders
- Demonic Sacrifice only shows with Demonic Pact.
- Reminders on Mouseover appear.
- **Never Remind Me** stays with its own custom reminder when you remove another.

### Meters
- A separate threat window froze while the meter was faded out.
- **Report to Chat** on Deaths sends the time of each death.

### Cooldowns
- The icons no longer jump after an **Icon Shape** change. By Nico-Mayer.

### Resource Bars
- The swing bar knows you are attacking after a /reload.
- **Seals:** no gap beside the icon.
- **XP bar:** a fight in Edit Mode shows the real bar.

### Minimap
- Edit Mode's Icon Size comes back after the map fades.
- **Square:** gathering addons see the map under your mouse again.

### Quest Tracker
- Scrolling and then clicking opened the wrong quest.

### Quality of Life
- **Accept Summons:** a summon you declined no longer makes it take the next one at once.
- Changing a setting on the vendor's Buyback tab could buy back the wrong item.

### Settings
- In Edit Mode, a fight no longer takes your keys, and the dialog's X works.
- **Reset FlareUI** can still undo the nameplate and UI Scale settings FlareUI changed.
- Long tab names no longer overlap.
- Frames keep their spots in a third Edit Mode layout.
- `/fui errors` counts repeated errors, and says more about blocked bag clicks.

# FlareUI 7.0.12

A clean-up of the chat, easier to spot elites in Modern Style, guild names on nameplates and spell ranks on the radials.

**We need your help testing:**
- **Chat:** names, levels and web links on every kind of line, and replying to whispers with R, also in a boss fight.
- **Radial Menu:** party spells while you're alone, with nothing targeted, next to a vendor.
- **Modern Style:** the gold and silver borders, and the level in front of the name above a frame.

## Heads up
Some things look or work differently even if you change nothing:
- **Chat:** only Alt+Up and Alt+Down go through the messages you sent, as in the default chat. The arrows alone no longer do it.
- **Chat:** with **Level Before Names** on, far more people show a level.
- **Modern Style:** target, focus and boss frames get a gold border for elites and bosses, and a silver one for rares.
- **Modern Style:** with **Show Level** on, the level also shows in front of **Name Above Frames**.
- **Pet frame:** the happiness icon beside it is as tall as the health bar.
- **Radial Menu:** **Button Names** is now **Icon Labels**. Your choice is kept.

## New

### Nameplates
- **Show Guild Name** (off) for players in Name Only Mode:
  - Set separately for enemy and friendly players
  - Under the name, or under the title when Show Titles is on

### Radial Menu
- **Show Spell Rank** (Off), for spells below your best rank:
  - **In the Icon:** the rank's number, at the top left
  - **In the Label:** after the name, like "Frostbolt (Rank 2)"
  - **Both**

### Chat
- A warning when another addon that changes the chat is running too, such as Prat or ls_Glass.

## Changed

### Unit Frames
- **Modern Style, elites and rares:**
  - The skull is a third larger
  - The borders follow the **Elite & Rare** icon: turn it off to keep the normal border
  - The threat glow still takes over while you have threat
- **Modern Style, level above the name:** on every frame with both options, except in FlareUI and Forever Style, which have a level disc.

### Chat
- Each window keeps 500 lines to scroll back through (was 128). The Combat Log is unchanged.
- Alt+Up goes back through your last 200 messages (was 50).
- **Level Before Names** uses the level the game sends with each player.
- **Save History:** old lines no longer offer Report, because it could point at the wrong message.

### Languages
- **French:** texts from 7.0.6 to 7.0.11. By Braincell1980.

## Fixed
- **Chat:** web addresses can be clicked in community channels, Discord guild chat and party guide lines.
- **Chat:** **Save History** keeps your last 128 lines of conversation in each window. Loot messages used to push them out.
- **Chat:** **Save History** keeps Discord guild chat.
- **Chat:** **Copy Chat** shows Battle.net friends by name.
- **Radial Menu:** with nothing targeted, a party spell you use alone goes to you. It went to the NPC in front of you.
- **Unit Frames:** **Name Above Frames** shows over the elite dragon in FlareUI Style.

---

Older versions (7.0.11 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
