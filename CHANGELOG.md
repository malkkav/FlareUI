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

---

Older versions (6.3 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
