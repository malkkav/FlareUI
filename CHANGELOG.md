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

---

Older versions (6.4 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
