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

# FlareUI 7.0.11

Surnames on their own, spell ranks in a drawer, smarter party spells on the radials, and threat numbers that agree with each other.

**We need your help testing:**
- **Threat numbers** as a tank in a dungeon: nameplates, target frame and meter.
- **Nameplates** in big pulls: their auras, and how smooth it feels.
- **Radial Menu:** the new rank drawer, and party spells while you're alone.
- **Loot Roll Window:** **Fade in Combat**, with a real roll during a fight.
- **Nameplates** with **Smooth Animated Bars**: its colours on our plates.

## Heads up
Some things look or work differently even if you change nothing:
- **Bags & Looting:** **Warn Before Selling Set Gear** and **Warn Before Selling Quest Items** are gone for now. They may have caused items to be blocked by the game.
- **Meters:** with **Tank's Lead** on, the tank's percent is now their threat against second place, like "125%". It used to show "100% (+25%)".
- **Party and Raid Frames:** **Show Name** is now a list on raid frames and the party's Raid Style: Off, First Name, Last Name or Full Name. Your choice is kept.
- **Nameplates:** **Show Full Name** for Name Only plates is now **Show Name**: First Name, Last Name or Full Name. Your choice is kept.
- **Radial Menu:** a party spell you use alone goes to your friendly target first.
- **Nameplates** with **Smooth Animated Bars**: a theme picked for nameplates there now colours our plates.

## Highlights
- **Last Name** on unit frames and nameplates.
- **Radial Menu:** one entry per spell, with every rank in a drawer.
- **Threat numbers** are the same on nameplates, unit frames and the meter.

## New

### Names
- **Last Name** in every name list:
  - Health Text and Name Above Frames on unit frames
  - Show Name on raid frames and the party's Raid Style
  - Health Text, Names Above Plate and Name Only on nameplates
- Someone without a surname shows their name.
- Forever Style keeps its own name.

### Radial Menu
- **Spell ranks:** the Catalog shows each spell once. Adding it gives you your best rank.
  - The small arrow on its icon opens every rank.
  - Search still finds single ranks, like "rank 3".
  - With a controller, the Catalog still lists every rank.
- **Party spells:** alone, they go to your friendly target, and to you when you have none. The button shows your target's name.
- **Uses left:** spells that need a reagent show how many uses you have, like the action bars.

### Loot Rolls
- **Fade in Combat** (off) in Edit Mode, for the Loot Roll Window. These bring it back:
  - Pointing at it
  - The last 5 seconds of a roll you haven't decided on
  - The end of the fight
- **Faded Opacity** (30): how see-through it gets.

## Changed
- **Setup tour** (`/fui tour`): new pages for Nameplates, for Bags & Looting, and for Buffs and Reminders. The Cooldown Manager is now part of the Bars page.
- **Nameplates** with **Smooth Animated Bars**:
  - A theme picked under its Nameplates shows on our plates.
  - With its **Your Colours on Their Bars** on, plates and your target's DoT marker work again, if plates and target both have a theme. Game Colour and Class Color keep FlareUI's fill.
- **Performance:**
  - Less work each frame on nameplates, the dispel glow and the chat.
  - New nameplates load their buffs and debuffs a few plates at a time, for smaller spikes in big pulls.

## Fixed
- **Threat:** as a tank in a dungeon, nameplates could stay at 100%, and unit frames could show no number.
- **Threat:** nameplates, unit frames and the meter could show different numbers for the same mob.
- **Radial Menu:** a lower rank of a party spell could turn into your best rank. It now stays, and its rank shows in the list.

# FlareUI 7.0.10

A hotfix for quest clicks that only opened the quest log, plus Smooth Animated Bars on nameplates.

**We need your help testing:**
- **Quest Tracker:** clicking quests from other zones, and Craftsman's Writs.
- **Nameplates** with **Smooth Animated Bars**: please tell us how it looks and runs.

## New
- **Nameplates:** support for **Smooth Animated Bars**. Its own nameplate switches turn the liquid on.
  - With its DoTs on Nameplates on, your DoTs show on your target's plate.
  - With its **Your Colours on Their Bars** on, nameplates keep FlareUI's fill.

## Fixed
- **Quest Tracker:** clicking a quest from another zone, or one with no location like a Craftsman's Writ, often opened only the quest log.
- **Quest Tracker:** with the map open full size, or with its quest list closed, some quests didn't open.

# FlareUI 7.0.9

A bug-fixing update: we went through the open reports and fixed as many as we could. It also adds sharper outlines for every font.

**We need your help testing.** These were hard to reproduce, so please tell us if they're fixed for you:
- **Controller:** walking while a radial is open, and placing a radial on a controller button.
- **Blocked items:** potions, armor kits and quest items that the game blocked. If it happens again, send us what `/fui errors` shows.
- **Chat:** switching tabs during a fight.
- **Quest Tracker:** clicking a quest while the map is open on a zone.
- **Druids:** **Keep Page 1 in Stealth**.
- **Crafting Bag in Backpack:** if its section stays empty, send us what `/fui errors` shows.

## Heads up
Some things look or work differently even if you change nothing:
- **Action Bars:** gryphons with a changed **Scale** may move once, to where Edit Mode has them saved.
- **Nameplates:** Questie's quest icon sits beside the plate, left of the level box. If you moved it in Questie to make up for our plates, set it again there.
- **Nameplates:** with **Colour Names by Class**, names on class-coloured bars are a lighter shade.
- **Nameplates:** bars fill their border, so the whole plate is about 2 pixels smaller. The bar keeps its size.
- **Chat:** player and link icons are as big as the text.
- **Chat and Meters:** with **Border** on None and **Background Opacity** at 0%, the line under the header hides too.
- **Bags & Looting:** Bank Window and Vendor have their own **Bank & Vendor** tab.

## Highlights
- **Sharp Outline** for every font.
- **Nameplates:** Name Only has its own font.
- **Chat:** whispers bring a faded chat back.

## New

### Fonts
- **Sharp Outline** in every **Outline** list: cleaner edges at any size. Some fonts draw stray lines with it.
- **Outline** (Each Font's Own) on the General page, under Global Font: one outline for every FlareUI font. Needs a reload.

### Nameplates
- **Name Only** on the Fonts tab: its own font, size, outline and shadow. It starts as your Names font.
  - **Name Only Size** is now a % of that font.
- **Threat Percentage** is a list: Off, In a Group, In an Instance or Always. If you had it on, it's on Always.

### Bags & Looting
- **Warn Before Selling Set Gear** (off): asks before you sell gear from a saved equipment set. By BillChirico.
- **Warn Before Selling Quest Items** (off): asks before you sell quest items. By BillChirico.

### Bug reports
- `/fui errors` says more about blocked items.

## Changed
- **Radial Menu:** near a screen edge, it moves in so every button fits. Nothing is picked until you move the mouse.
- **Bags & Looting:** the Tools section is called **Tweaks**.
- **Chat:** whispers, Battle.net ones too, bring a faded chat back even when another tab is shown.
- **Chat:** every popped-out window that takes a message comes back, not only the first.
- **Minimap:** the Info Bar's gold uses the bags' coins, size and gaps.
- **Bags:** **Auto Open Containers** waits while an armor kit or a spell is waiting for its item.
- **Nameplates:** fewer updates for the same result. By parchinskiy.

## Fixed
- **Gamepad UI:**
  - Another try at walking while a radial is open.
  - Placing a radial on a controller button could fail with "Failed to pick up an action".
- **Quest Tracker:** clicking a quest with the map open on a zone didn't open the quest.
- **Action Bars:** gryphons with a changed **Scale** moved at every login.
- **Action Bars:** another try at **Keep Page 1 in Stealth** showing the Prowl page (druids).
- **Nameplates:** there was a dark gap between the bars and their border.
- **Nameplates:** Questie's quest icon sat over the level box on your target.
- **Edit Mode:** with Snap on, the minimap and the chat stopped short of the screen edge.
- **Chat:**
  - Another try at tabs that don't switch during a fight: they could stay stuck with the **Meter Tab** on.
  - With **Fade Delay** at 0, new messages never brought the chat back.
  - In a fade group, changing **Visibility** on another frame could turn off New Messages.
  - With **Fade Old Lines**, lines could start fading under the mouse.
- **Bags:** another try at the crafting bag missing from the combined backpack with **Crafting Bag in Backpack** on.
- **Sync Blizz UI:** other characters were asked to reload when nothing had really changed.
- **Buff Reminders:** another try at potions and kits blocked by the game.
- **Raid Frames:** click-casting didn't work on the main tanks' targets.
- **Meters:** the warning about Blizzard's own Visibility setting could be missed.
- **Settings:** **Show Item Level** showed a player in its preview.

---

Older versions (7.0.8 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
