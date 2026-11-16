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
