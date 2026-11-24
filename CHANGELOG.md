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

# FlareUI 7.0.8

A small fix for errors in group content, with two more fixes from your reports.

## Fixed
- **Unit Frames:** **Values on Mouseover** spammed errors in dungeons and raids.
- **Nameplates:** with **Names Above Plate**, names could show the colour of another player or enemy.
- **Minimap:** an error in the addon drawer with addons that put thousands of pins on the minimap.

---

Older versions (7.0.7 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
