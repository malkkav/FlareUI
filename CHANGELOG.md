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

# FlareUI 6.3

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## Highlights
- **One font for everything**: a **Global Font** on the Settings page, and every font can follow it.
- **A font for every frame**: unit frames, buffs, the tracker, resource bars and the minimap set their fonts in Edit Mode, frame by frame.
- **Smoother play**: a pass over everything that could cause short lag spikes, above all with gathering and quest addons.

## New
- Settings › **Global Font** (Friz Quadrata TT): one font for all of FlareUI's text, set in one place.
  - Every font dropdown now starts with **Global**, and every font that used Friz Quadrata follows it. Chat text and action bar text keep Arial Narrow.
  - **Use Global Font Everywhere** sets every FlareUI font to Global. Sizes, outlines and shadows stay.
  - **Reset All Fonts** puts every font back to its default.
  - **Game Text** (off): Blizzard's own text takes the Global Font too: menus, windows, quest text, nameplates and more.
  - **Nameplate Font** (Default): the names on Blizzard's nameplates.
  - **Combat Text Font** (Default): the damage and healing numbers over what you hit. It changes the next time you log in.
- Edit Mode: a **Fonts** section, always the last one, for each frame. Pick a text, then its **Font**, **Outline**, **Shadow** and **Size**.
  - **Unit frames**: each frame its own fonts for **Names**, **Health Text**, **Level**, **Power Text**, **Cast Name**, **Cast Countdown**, **Aura Timers** and **Aura Stacks**. Party, raid and boss frames too. Each frame style keeps its own.
  - **Player Cast Bar**: its own **Cast Name** and **Cast Countdown**.
  - **Buffs** and **Debuffs**: each their own **Aura Timers** and **Aura Stacks**.
  - **Buff Reminders**: **Counts** and **Time Left**.
  - **Quest Tracker**, every **resource bar** and the **minimap** (zone name, clock and info text).
  - **Apply to All** gives the same fonts to every frame of the kind; **Reset Fonts** puts the frame's back.
- More fonts in the Fonts tabs:
  - Action Bars › **XP Bar**: the bar's numbers. It used the Keybinds font before.
  - Radial Menu: a new **Fonts** tab with **Button Names** and **Counts**.
  - Bags & Looting › **Gold**: the money at the bottom of your bags.
- Bags & Looting › Bags: **Item Level** (off) on weapons and armour, in their quality's colour, in your bags and on the character sheet. Thanks for the request!
- Bags & Looting › Bags: **Uncollected Appearances** (off): an eye on gear whose look you can still learn. Thanks for the request!
- Tooltips: **Show Item Level** (off) on weapons and armour. Thanks for the request!
- Meters › Threat: **Separate Window** (off): threat in its own window, moved and sized in Edit Mode. Thanks for the request!
- Action Bars › Bars Appearance:
  - **Borderless Micro Menu** (off) and **Borderless Bag Bar** (off).
  - **Collapsible Bag Bar** (off): an arrow beside the backpack folds the other bags away. Needs Borderless Bag Bar. Thanks for the request!
- Unit frames › Health Text, Forever Style: **Percent <  > Value**: the percent at the bar's left end, the full value at its right. Thanks for the request!
- Health Text: **Value | Health Lost**, such as "1234 | -216".
- Radial Menu › Options: **Sub-Radials** (Reset on Close): a sub-radial opens on its first button, or on the one you used last with **Remember**.
- Minimap › Style: three cards, **Square (Clean)**, **Square (Header)** and **Round**.
- Minimap: **Latency** (off), under Framerate: your home and world latency at the bottom right.
- **Français**: French is in the language list on its own now, with every new text translated.

## Changed
- Edit Mode now holds the fonts of Unit Frames, Buffs & Debuffs, Minimap, Resource Bars and Quest Tracker, and their pages lost their Fonts tab. A **Fonts** row on each page opens Edit Mode. Your fonts carry over.
- Fonts tabs: each font starts closed, and fonts are grouped in titled sections, such as **Action Bars** and **XP Bar**.
- Bar text choices: **Value | Percent** is now **Percent | Value**, and **Current (Max)** is now **Value [Max]**. **Current (Max) | Percent** is gone; it becomes Value [Max].
- Settings › UI Scale: the **Blizzard's** choice is now called **Off**, and says that any other choice replaces Blizzard's UI Scale each time you log in. Thanks for the report!
- Buff Reminders:
  - Rogue poisons and other weapon buffs are recognised by kind, so Forever's reworked poisons count. Low charges start at 5. Thanks for the report!
  - Forever's hunter aspects, Trueshot Aura, Fel Armor, elixirs, food and oils are recognised more reliably.
  - Paladin auras and hunter aspects count only when they're yours.
- Minimap: the Fading section opens and closes like the others.
- Loot Rolls and Toasts: their Scale shows plain numbers.
- Bags: clicking the keyring or reagent bag icon opens and closes the combined backpack while that bag is part of it. Thanks to parchinskiy!

## Fixed
- Short lag spikes: FlareUI no longer handles the map pins of gathering and quest addons, and a long list of other places do less work. Thanks for the report!
- Buffs & Debuffs: no more slowdown after using Edit Mode in a fight or an instance.
- Fishing: **Double-Click to Fish** works with Blizzard's Cast on Key Down. Thanks for the report!
- Minimap: the square minimap is put back properly after ForeverFarmHUD or FarmHud; FlareUI explains the farming HUDs once. Thanks for the report!
- Bags: the keyring and reagent sections show the new-item glow like the rest, and lose it when you close your bags. Thanks to parchinskiy!
- Bags: a hidden reagent window no longer blocks clicks on the backpack with Move Any Window on. Thanks to parchinskiy!
- Russian: buttons and other text show their letters with FlareUI in Russian on a game client in another language.

# FlareUI 6.2

## Highlights
- **A settings window that looks like Blizzard's**: Friz Quadrata text, WoW's yellow titles, and Blizzard's own checkboxes, dropdowns, sliders, buttons and scroll bars.
- **Minimap › Header**: pick a headerless square minimap in a heavy bronze frame, or the bordered one with its title bar.

## New
- Minimap › Style: **Header** (Headerless), for the square minimap.
  - **Headerless**: the map framed in the heavy bronze border of the settings window, its buttons and zone name on the map.
  - **Bordered**: the frame's bronze title bar over the map, the buttons and zone name in it, as before 6.1.1.
  - Both are the same size, so switching doesn't move your minimap.
- Minimap: a **FlareUI button** when you untick FlareUI in **Addons in the Drawer**. Left-click opens the settings, right-click puts FlareUI back in the drawer, drag it along the edge to move it. It never shows while the drawer is off.
- Tooltips › Look: **Frame Opacity** (100%), under Scale. Thanks for the request!
- Loot Feed: **Alignment** (Left). Right puts the icons on the right, with the text before them. Thanks for the request!
- Buff Reminders, warlocks with Demonic Sacrifice and Demonic Pact: a **Demonic Sacrifice** reminder while you have none of its buffs, and your pet and Soul Link are still asked for. Thanks for the report!
- What's New: **Don't Show on Login** (off), at the bottom of the page. These notes then stay here instead of opening after an update. Thanks for the report!
- Settings, in Gamepad mode: options the Gamepad UI doesn't let FlareUI run are greyed, with a red note saying so. Thanks for the report!

## Changed
- Settings window: a new, more Blizzard-like look.
  - All text in Friz Quadrata, the game's own font, in white, with titles in WoW's yellow.
  - Blizzard's own checkboxes, choice arrows, dropdowns, sliders and scroll bars.
  - Buttons and tabs in Blizzard's grey with a bronze rim.
  - The plain stone background, with darker boxes so the options read more easily.
  - The module list on the left has no checkboxes; turn a module on or off beside its page title.
- Buff Reminders › Your Own: **Custom Reminders** and **Hidden Reminders** are now lists. Untick one to remove it or bring it back; **None** does them all. Thanks for the request!
- Bags & Looting: FlareUI leaves your bags alone while a bag addon runs (Bagnon, Baganator, AdiBags, ArkInventory, BetterBags, BagSmith and more), so its sorting and cleanup work as they should. Looting features keep working. Thanks for the report!
- Action bars: druids' Prowl turns Action Bar 1 to the prowl page again, as Stealth does for rogues. **Keep Page 1 in Stealth** still keeps your Cat Form page.
- Minimap › Addons in the Drawer: one line per addon, under its real name.
- Buff Reminders: druids no longer get an Omen of Clarity reminder. It's a random proc on Forever, nothing to keep up.

## Fixed
- Minimap: the game no longer hangs when you turn GatherLite's HUD or FarmHud on or off. Thanks for the report!
- Minimap: Social Diary's button works in the addon drawer again. Thanks for the report!
- Minimap, square style: the border's shadow and corners are no longer cut off by the map.
- Chat: TradeSkillMaster's settings no longer show an error on their General page. Thanks for the report!
- Tooltips: Russian clients show a player's class again. Thanks for the report!
- Fast Auto-Loot no longer stops working until a reload. Thanks for the report!
- Cast bars: your own casts and profession casts no longer turn grey on the target or focus bar. Casts you can't interrupt still do.
- Buff Reminders: the Passive Pet reminder no longer flashes as you dismount. Thanks for the report!

# FlareUI 6.1.1

## New
- Minimap: **Addons in the Drawer** (all), under **Addon Button Drawer**: tick the addons whose buttons go in the drawer. The others are left alone on the minimap, where their addon puts them. Changes take effect after a reload.
  - It replaces Shift+Right-Click on drawer icons, which clashed with addons' own right-click menus. Buttons you kept on the minimap that way stay out of the drawer.
- Settings › Sync Blizz UI: **Hide Pop-up Alerts** (off): syncs still happen, with no pop-up asking to reload, on every character. The pop-up's new **Hide These Alerts** button turns it on.

## Changed
- Minimap, square style: addon buttons left out of the drawer sit on the border, packed along the bottom from beside the sundial. Drag one along the border and it stays where you drop it, through every reload. Thanks for the report!
- Minimap, square style: the bronze border is drawn under the map, so no addon button can end up beneath it.
- Unit frames › player frame › Visibility: **Missing Health** and **Missing Mana** can no longer be ticked together; ticking one unticks the other. The game hides both from addons, so the two can't be combined. If you had both, Missing Mana stays. Thanks for the report!
- Action bars: **Active Highlight** follows the button's own frame, round corners and all, instead of a square. Thanks for the report!

## Fixed
- Minimap: the **Middle-Click Menu** opens again. Other clicks ping the map as usual. Thanks for the report!
- Minimap: addon buttons no longer move around on every reload, and RareScanner's button shows again when left out of the drawer. Thanks for the report!
- Resource bars: Blizzard's own swing timer no longer appears in busy fights when FlareUI's swing bars are on. Thanks for the report!
- Unit frames: the player frame now fades as it should with Missing Health and Missing Mana both set (see Changed). Thanks for the report!

# FlareUI 6.1

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## Highlights
- **Buff Reminders** is now its own page, with much more to track: talent buffs, weapon oils and stones, elixirs, supplies, durability and your own custom reminders.
- **Mouseover** is now a Visibility condition you tick, so bars and frames show on hover only when you want them to.
- **Tooltips** get a Visibility tab: when each kind shows, and which ones follow your mouse.

## New
- Buff Reminders: its own page in the Combat group, with its own switch. Your settings carry over.
  - **Reminders** tab: Class Buffs, Weapons, Consumables, Upkeep and Your Own.
  - **When and Where** tab: when a buff counts as running out, where each kind shows, and which group buffs to hide.
  - **Alerts** tab: **Sound** and **Ready Check Alert**.
  - Its Edit Mode window gains **Alerts** (**Glow When Missing**, **Glow When Running Out**, **Time Left**) and **Hide While Mounted**.
  - It no longer needs Buffs & Debuffs to be on.
- Buff Reminders: talent and class buffs, once you know the spell. Thanks for the request!
  - Priest: **Divine Spirit** on your group, and **Shadowform** (not while you're the healer).
  - Druid: **Omen of Clarity**. Hunter: **Trueshot Aura** and an **Aspect** reminder (a click puts your last one back).
  - Warlock: **Soul Link** while your pet is out, and a **Soulstone** on your group's healer.
  - Warrior: **Battle Shout** on you and your party.
- Buff Reminders: **Extra Buffs** (none) adds **Shadow Protection** and **Moonkin Form** when ticked.
- Buff Reminders: **Weapon Oil / Stone** (off), for every class. Click to use one from your bags; right-click to pick which. Sharpening stones go on blades, weightstones on maces and staves.
- Buff Reminders: **Playstyle** (Automatic) picks which oil or stone comes first: stones for melee and tanks, wizard oil for casters, mana oil for healers.
- Buff Reminders: **Elixirs and More**: tick the elixirs, Zanza, juju and Blasted Lands buffs you want kept up. Click to use one from your bags.
- Buff Reminders: **Low Supplies** (off) for reagents and ammo, **Low Durability** (off) below 20%, and **Worn Trinkets** (off) for an Argent Dawn trinket or Carrot on a Stick still on in a dungeon or raid.
- Buff Reminders: **Add Custom Reminder**: your own reminder by spell name or ID, or an item. Right-click its icon to remove it.
- Buff Reminders: right-click an icon to **Snooze Until Recast**.
- Buff Reminders: where each kind shows: **Class Buffs**, **Weapon Buffs**, **Pets** and **Consumables**, each Always, In Dungeons and Raids, or In Raids.
- Buff Reminders: icons that use an item show how many you have; a buff running out shows its time left; a poison low on charges counts as running out.
- Tooltips: a **Visibility** tab.
  - **Visibility**: World, Unit Frames, Action/Data Bars, Buffs/Debuffs, Party/Raid Auras and the new **Everything Else** (the minimap, menus and more): Always, Hide in Combat or Never.
  - **Mouseover**: which of them appear at your mouse. Each follows the main **Mouseover** on the Settings tab; a change here is an exception for that kind. Thanks for the request!
- Edit Mode › player frame › Fading: **Link Pet Frame** (off): the pet frame fades with the player frame, and pointing at either shows both. Thanks for the idea!
- Bags & Looting: **Open with Character Window** (off): your bags open and close with the character window. Thanks for the request!
- Bags & Looting › Fonts: **Free Bag Slots** (Default): the font of the free-slot count on the backpack button. Thanks for the request!

## Changed
- Visibility: **Mouseover** is now a condition you tick with the others, on every faded bar and frame and on Fake CM. Without it, pointing at a faded frame doesn't show it.
  - If you had conditions set, Mouseover is ticked for you, so nothing changes until you untick it.
  - Nothing ticked now means Always.
- Tooltips: **Anchor** is now **Mouseover**, a switch on the Settings tab for every tooltip at once. Your choice carries over.
- Bags & Looting: the bank and guild bank now open your bags, as the vendor and mailbox do.
- Minimap: the **Middle-Click Menu** works as before 6.0.3 again: a middle click opens the menu without a ping, and the square map's corners ping. In battlegrounds the game keeps the map's clicks to itself, so there's no menu there.
- Loot Feed: money shows just the coins you looted, without the gold icon. Thanks for the request!
- Unit frames: in the ring styles, Target of Target and Target of Focus have their portrait on the left, so the bar runs left to right clear of it.
- Radial menu: the catalog's sections stay on one line, and an empty catalog says why.
- Buff Reminders: Food and Flask is a switch, with its place under When and Where.
- Buff Reminders: an oil or stone on a warlock's weapon no longer brings up the Firestone reminder. Thanks for the report!

## Fixed
- Action bars: **Active Highlight** no longer leaves spells like Rend or Thunder Clap lit after you use them. Thanks for the report!
- Buffs: a sharpening stone's or oil's icon no longer disappears after you die. Thanks for the report!
- Buff Reminders: food buffs not called "Well Fed" (Nightfin Soup, Grilled Squid and more) count, and Demonic Sacrifice no longer asks for your pet.
- Edit Mode: FlareUI's loot rolls, toasts and other frames keep working after an update read with /reload; FlareUI now tells you to restart instead. Thanks for the report!
- Radial menu: the **Professions** catalog finds your professions.
- Settings: longer translations fit their buttons, and the About page scrolls. Thanks to parchinskiy!

# FlareUI 6.0.3

**Restart the game fully after updating** (not just /reload): this version adds a new file.

**Please check your settings.** Some defaults changed in this version (listed under **Defaults**). Options you already set yourself keep your choice; options you never touched take the new default.

## Highlights
- **Bags & Looting** is now its own page, with its own switch.
- **Flight Timer** and **Paladin Seals**: two new resource bars.
- **Weapon buffs** in Buff Reminders: warlock stones, off-hand weapons, and clicks that put poisons and imbues on the right hand.

## New
- Bags & Looting: a page of its own, out of Quality of Life.
  - **Bags** tab: **Bag Window**, **Item Slots** and **Tools** sections.
  - **Looting** tab: **Faster Auto Loot**, **Skip Loot Confirmations** and the **Loot Feed**.
  - **Fonts** tab: **Bag Items** and **Loot Feed**.
  - Your settings carry over. Its switch starts on if you had Quality of Life on.
- Bags & Looting › Bags: **Category Filters** (off). A button beside the cleanup button opens a drawer: **Quest Items**, **Equipment**, **Materials** or **Consumables**. Everything else dims. Right-click the button to clear it. Thanks to parchinskiy for the idea!
- Bags & Looting › Fonts: **Bag Items** (Default) sets the font of the stack counts and cooldown numbers on your bag items.
- Resource bars: **Flight Timer** (off). A bar while you're on a flight path, with where you're going and the time left.
  - Each route is learned the first time you fly it. Until then the bar counts up.
  - Learned times also show on the flight map when you point at a destination.
- Resource bars: **Paladin Seals** (off). One bar with your seal's name and time left, in that seal's own colour. Pick each seal's colour in **Bar Colours**.
- Buff Reminders: weapon buffs. Thanks for the report!
  - Warlocks: a **Firestone** or **Spellstone** reminder. Click to make one, or to put one from your bags on your weapon.
  - Off-hand weapons get their own reminder, for rogues and dual-wielding shamans.
  - Only your class's own weapon buff counts: a sharpening stone no longer hides a poison or imbue reminder.
  - Rogues: click to put a poison from your bags on that hand.
  - Shamans: click to put the imbue on that hand.
  - Right-click an icon to pick which poison, imbue or stone goes on each hand (**Last Used** by default).
- Action bars: **Active Highlight** (off), in **Button Appearance**. Your stance or form, a queued Heroic Strike, Cleave, Maul or Raptor Strike, and a repeating Auto Shot get a gold edge and a light. Queued attacks pulse. Thanks for the request!
- Action bars › XP Bar: **Show Bubbles** (off) divides the XP, reputation and honor bars into 20 parts, like the classic bar. Thanks to mateuszmalek!
- Edit Mode: Blizzard's **Totem Bar** gets **Size** and a **Fading** section with fade groups, like the action bars. Thanks for the request!
- Minimap: **Framerate** (off): your framerate at the bottom right of the map, **Always** or **On Mouseover**. Thanks for the request!
- Damage Meter: **Fade Delay** (Instant), after **Faded Opacity**: how long the meter stays before it fades.
- Radial menu: drag radials in the **Radials** list to reorder them.
- Radial menu: **groups**. Right-click a radial to **Add to New Group...**, move it to a group or take it out.
  - Click a group's row (or its **+ / −**) to fold or open it.
  - Right-click a group to **Rename...** or **Ungroup** it.
  - Drag radials into a group, and drag a group to move it.
- Radial menu: a **Professions** catalog with your professions and Smelting, Disenchant, Find Herbs, Find Minerals, Basic Campfire and Pick Lock.
- Fonts: every font on every **Fonts** tab has a **Reset** button.

## Changed
- Unit frames and resource bars: **Colour Palette** is now **Frame Colours** and **Bar Colours**: a **Pick Your Colours** button you always see.
  - In its window, the palette list at the bottom offers **FlareUI** (default), **Blizzard** and **Custom**.
  - Change any colour and the palette becomes **Custom**. **Reset** gives your colours back.
  - **Apply** saves and closes. Closing with unsaved colours asks whether to keep them.
- Minimap: **Coordinates on Mouseover** is now **Coordinates**: **Off**, **Always** or **On Mouseover**. It is the same option as Blizzard's own coordinates. If you had Coordinates on Mouseover off, you get **Always**.
- Minimap: the addon drawer's **Open on Mouseover** closes sooner after the pointer leaves.
- Quest tracker: **Colour Names by Difficulty** is now **Colour by Difficulty**.
- Loot Feed: a single item shows just its name, and several show "Name x3". Thanks to Nico-Mayer!
- Radial menu: a new radial is available to **All Characters** by default.
- Radial menu: **Quest Items** has a new icon.
- Settings: options reordered on the Action Bars, Minimap, Quest Tracker, Tooltips and Damage Meter pages, so related ones sit together.
- Quality of Life has a new icon; the bag icon went to Bags & Looting.

## Defaults
- On: **Party Frames** and **Raid Frames** (with Unit Frames), Buffs & Debuffs **Timer Colour** and **Arrival Animation**, Damage Meter **Pull Warning** and **Pull Aggro Line**.
- Off: Action bars **Stop Auto-Add Spells**, Minimap **Middle-Click Menu**, Quest tracker **Completed Last** and **Auto Minimize in Instances**, Tooltips **Show Threat**, **Map Pins on "/way"**, **Gamepad Mode Prompt**, and every bag option.
- Chat, Damage Meter and Quest Tracker: **Frame Opacity** 60%.
- Minimap: **Coordinates** On Mouseover.
- New default spots for Buff Reminders, toasts, loot rolls, Combo Points, the swing timers and the new bars.

## Fixed
- Minimap: clicking the map in a battleground no longer causes a blocked-action error. Thanks for the report!
- Quest tracker: **Sort By** By Zone no longer reorders quests by distance as you move. Thanks for the report!
- Quest tracker: **Wrap Long Text** no longer cuts off a longer objective. Thanks to parchinskiy!
- Gamepad UI: settings dropdowns opened with the mouse no longer cause an error. Thanks for the report!
- Action bars: with **Clean Keybind Text** off, long key names stay on one line instead of covering the icon. Thanks for the report!
- Radial menu: the **Available To** list of a new radial opens over its popup, not under it.
- Radial menu: the selected button's highlight in the **Buttons** list sits centred.

# FlareUI 6.0.2

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## New
- Player frame: **Missing Mana** in its **Visibility** list (Edit Mode). Tick it with **Missing Health** and the frame shows while either bar is below full. Thanks for the request!
- Quality of Life › Fonts: **Zone Text** (Default) changes the font of the zone name that appears as you enter a new area. Its size stays Blizzard's. Thanks for the request!
- Quality of Life › Hide Clutter: **Flag Carrier Frames** (off) hides the two flag carrier frames under the minimap in battlegrounds. Thanks for the question!

## Changed
- Action bars: **Auto Paging for Stealth** is now **Keep Page 1 in Stealth** (off). The game now turns Action Bar 1 to its stealth page by itself; this option keeps your normal buttons instead. Thanks for the report!
  - Druids keep their Cat Form page while prowling.
  - If you had Auto Paging for Stealth off, Keep Page 1 in Stealth starts on.
- Action bars: **Skin Cooldown Manager** is now off by default. Turn it on in **Bar Appearance**.

## Fixed
- Player cast bar: your casts never turn grey. Thanks for the report!
  - **Range Check** is gone from the cast bar: with it off, every cast turned grey.
  - Blizzard's own cast bar keeps its normal colour for your casts too.
- Action bars: a hidden **Stance Bar** stays hidden in combat. It came back, for example when Stealth came off cooldown, until the fight ended. Thanks for the report!
- Action bars: with **Keep Bar 1 in Stances**, the spellbook's "not on your bars" glow matches the bar you see. Thanks for the report!
- Minimap: addon buttons you keep on the minimap with the addon drawer sit above the map border. Thanks for the report!
- Russian: the Damage Meter's **Threat** tab and the **Open Configuration** button in Blizzard's options no longer show squares. Thanks for the report!
- Settings: slider values such as **Default** next to Bags › **Columns** no longer get cut off in long translations. Thanks for the report!
- Unit frames, FlareUI Style: the last bit of shadow at the top of the portrait ring is gone.
- Radial menu: a **Party Spell** slice shows the spell's name while you're alone, not your own name.

# FlareUI 6.0.1

## Changed
- Action bars: **Skin Cooldown Manager** follows Blizzard's own Cooldown Manager switch. While the Cooldown Manager is off, FlareUI leaves it alone and the option is greyed out. Thanks for the report!
- Settings: a tab's NEW badge sits centred on the tab's top edge.

## Fixed
- Player cast bar: your own casts keep their normal colour. Some spells turned the bar grey, whatever **Range Check** was set to. Thanks for the report!
- Nameplates: with **Hide Level**, crowd control icons sit right beside the health bar again, without a gap. Thanks for the report!
- Unit frames, FlareUI Style: the portrait ring's rim is clean at the bottom, and nothing shows through beside the portrait.
- Settings: long translations, such as Russian, no longer run past buttons, card titles, section headers or the page list. Text wraps, then shrinks to fit.

# FlareUI 6.0

**Restart the game fully after updating** (not just /reload): this version adds new files.

FlareUI 6.0 brings a whole new settings window. We rebuilt it from the ground up, with one goal: make it as easy to use as we can. Every page now shows a live example of what it changes, drawn by the real frames, so you see the result before you leave the window. Options sit in clear sections, search takes you straight to them, and the whole window wears WoW: Forever's own bronze and stone. Tell us what still feels hard to find. Thanks to Jeor for starting this!

## Highlights
- **A new settings window**: live previews, clearer pages, better search, and a look that matches the game.
- **Custom colours**: pick your own colour for every unit frame and resource bar.
- **Profiles follow you**: a profile now brings its frame positions to every character that uses it.

## Settings window
- Every page shows a live preview of what it changes, drawn by the real frames in your current style.
- A new **Settings** page holds **Sync**, **Move Any Window**, **UI Scale** and **Language**.
- Search shows how many options it found; press **Enter** to jump to the first one.
- Module switches sit in the list on the left, so you can turn a module on or off without opening it.
- A new look: WoW: Forever's heavy bronze frame, a stone background, stone switches and round game icons.
- The **setup tour** (/fui tour) has the same look.

## New
- Unit frames: **Colour Palette** gets **Custom**. **Pick Your Colours** opens a window with every bar colour and live samples beside them. Thanks for the request!
  - Click a colour to change it; right-click it to go back to the palette's own. **Reset All** clears them.
  - Custom starts from the palette you had.
- Resource bars: their own **Colour Palette** (FlareUI, Blizzard or Custom), in the new **Look** section. Until you change it, it follows the unit frames' palette. Thanks for the request!
- Settings: **Text Scale** (100%), under **UI Scale**, makes all text larger or smaller without changing the frames. Thanks for the question!
- Action bars: a new **Bar Appearance** section. Thanks for the request!
  - **Skin Action Bars** (on) gives every bar's buttons FlareUI's bronze frame.
  - **Bar Scale** (111%) sizes every button, in 0.5% steps.
  - **Skin Cooldown Manager** moved here, and now frames the Essential and Utility cooldown icons too.
- Buff Reminders: more reminders.
  - Druids: **Thorns**.
  - Paladins: **Righteous Fury** while you're the group's tank, and an aura when none is on.
  - Warriors: a stance when you have none.
  - Warlocks: a **Healthstone** in your bags.
  - Pets left on **Passive**. Click the icon to set them to Defensive.
  - **Camping and Rest** (off): Forever's camp benefits and the Cozy Sleeping Bag's Well-Rested. Click to use the bag.
  - **Gathering Tracking** (off): Find Herbs or Find Minerals when it's off.
- Buff Reminders: right-click an icon to **Hide Until Reload** or **Never Remind Me**. **Hidden Reminders** brings them back.
- Buff Reminders: **Remind Before It Ends** can be set apart for dungeons and raids.
- Buff Reminders: **Group Buff Filters** hide group buffs while you're a tank, healer, damage dealer or have no role (all off).
- Buff Reminders, in Edit Mode:
  - **Count Text** (Missing / Total, Missing Only or Off), **Spacing** and **Opacity**.
  - **Growth** can start from the middle.
  - A **Fading** section: **Visibility** (Solo, In a Party, In a Raid, **In Combat**), **Hide in Rested Areas**, **Fade Speed** and **Opacity**.
- Loot Feed: **Show Skill-Ups** (off) adds skill gains, like "Mining 76", to the feed. Thanks for the request!
- Loot Feed: font, size, outline and shadow, in a new **Quality of Life › Fonts** tab. Thanks for the request!
- Tooltips › Show Tooltips: **On Buffs/Debuffs** (Always) and **On Party/Raid Auras** (Never). Set the second to Always or Hide in Combat to see tooltips on party and raid aura icons. Thanks for the request!
- Swing timers: **Bar Text** and **Timer** (both on), in Edit Mode's **Look**, hide the swing's name or the seconds left. Thanks for the request!
- Player cast bar: **Range Check** (off) greys the bar while your target is out of range. It's in the cast bar's **Look** and in the player frame's **Cast Bar** section. Thanks for the question!
- Minimap: in the addon button drawer, **Shift+Right-Click** an icon to keep that addon's button on the minimap. Do it again to put it back. Thanks for the request!
- Loot rolls and toasts: **Scale** in their Edit Mode dialogs.
- Edit Mode: the Quest Tracker, Totems, Buffs/Debuffs, XP Bar and Buff Reminders get a **Frame** section. The tracker, the auras and the XP bar get a **Fading** section.

## Changed
- Profiles: a profile's frame positions now follow it to characters on other Edit Mode layouts. Thanks for the report!
  - Switching profiles offers the Edit Mode layout it was set up on, or explains how to copy it.
  - **New** asks whether to copy your current profile or start from defaults. **Duplicate** is gone.
  - The Profiles page explains what a profile holds.
- Shields: the part that doesn't fit after your health (all of it at full health) now shows over the health bar, from its end backwards. You see how much shield is left as you're hit. Unit frames, party and raid frames, and the Health resource bar. Thanks for the request!
- Buff Reminders: the **Blessing**, **Thorns** and **Pet Reminders** rows are gone, to keep the page short.
  - Pick who gets your Blessing or Thorns (**Tanks Only**, **Only Me** or **Everyone**) from the icon's right-click menu.
  - Pets you turned off, and Thorns set to Off, carry over as hidden reminders.
- Buff Reminders: **Visibility**, **Hide in Rested Areas** and **Opacity** moved to the Edit Mode **Fading** section.
- Party and raid frames: Edit Mode samples show an incoming heal and a shield, as the unit frames' do. Thanks for the question!
- Unit frames, FlareUI Style: the portrait ring keeps its full rim on the bars' side, as in Forever Style.
- Edit Mode: every FlareUI dialog's sections start closed after a reload.
- Edit Mode: **Range Check** is the first switch in **Look** and **Show Level** the first in **Frame**. **Spell Pushback** comes before **Latency Zone**.
- Edit Mode: the ring's threat number sits over the middle of the ring.
- Loot rolls: a bronze border.
- Battleground objectives: a tidier Edit Mode sample, and the real scores sit on FlareUI's Thick plate.
- Damage Meter: Blizzard's Edit Mode dialog for the meter no longer shows **Visibility**, **Transparency** or **Background**. They did nothing with FlareUI's meter: use **Settings › Damage Meter**. Thanks for the report!
- UI Scale: its tip now says **Pixel Perfect** is about sharp borders. Text is sharp at any scale.

## Fixed
- Unit frames: no more blocked-action errors when a druid shapeshifts in combat with the ring styles. Thanks for the report!
- Chat: undocked windows, such as World, no longer come back lower after login, over the main chat's tabs. Thanks for the report!
- Nameplates: with **Hide Level**, the quest badge sits beside the health bar, not under it. Thanks for the report!
- XP bar: the border draws over the bar, so its corners no longer show square ends. Thanks for the report!
- Minimap: addon buttons on the square minimap's edge no longer sit under its border. Thanks for the report!
- Bags: empty slots in **Integrated Bag Buttons** no longer show an "Equip Container" tooltip.

---

Older versions (5.1.2 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
