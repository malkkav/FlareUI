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
