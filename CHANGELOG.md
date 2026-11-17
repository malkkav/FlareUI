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
