# FlareUI 6.2 (unreleased)

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## Highlights
- **Buff Reminders** gets a new Reminders tab: your reminder bar as it looks in game, a spellbook to pick from, and the picked reminder's own settings.

## New
- Buff Reminders: pick what to be reminded of from a spellbook. The tabs are your class's reminders, each spellbook line, your bags and upkeep (supplies, durability, trinkets, camping, gathering). Click a buff to put it on the bar.
  - Any spell in your spellbook that isn't harmful can be a reminder, and so can a consumable in your bags. No more typing spell IDs.
  - Spells you haven't learned yet and spells that leave no buff are greyed out.
- Buff Reminders: each reminder can have its own **Check On** (Me, Party, Raid), **Remind Me** (how long before it runs out) and **Show** (Always, Instances, Raids). **Use Defaults** puts it back.
- Buff Reminders: move a reminder left or right on the bar. The blessing, weapon buff per hand, and who keeps Thorns or the Soulstone can be picked on the page too, as well as with a right-click.

## Changed
- Buff Reminders: **When and Where** is now **Defaults**: the values a reminder takes until it has its own.
- Buff Reminders: Extra Buffs, Weapon Oil / Stone, Food and Flask, Elixirs and More, Low Supplies, Low Durability, Worn Trinkets, Camping and Rest, Gathering Tracking, Add Custom Reminder and Hidden Reminders are gone from the settings: put the reminder on the bar instead. Your bar starts with what you had on.
- Buff Reminders: right-click **Never Remind Me** takes the reminder off the bar.

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

# FlareUI 5.1.2

## New
- Minimap: a one-time notice when Lueur, NodeSight or Nodeworthy is on. Their node scanning makes the minimap flash, and that comes from them, not FlareUI. The Minimap settings page says so too while one is loaded. Thanks for the report!

## Changed
- Loot Feed: the lowest **Minimum Quality** choice is now called **All Items**. It already showed every item. Thanks for the feedback!

## Fixed
- Loot Feed: single items show again; only stacks and money did. It now also works whatever language your game is in. Thanks for the report!
- Bags: the **Upgrade Arrow** no longer marks weaker gear, such as grey cloth bracers over green mail ones. Armour only gets the arrow when it loses no stat, armour included. Thanks for the report!
- Cast bars: **Hide Spell Timer** stays on after the first cast. Thanks for the report!
- Minimap: no black box while gathering addons scan. Thanks to Jeor for the fix!
- Settings: tabs no longer run past the edge of the page when they show NEW.

# FlareUI 5.1.1

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Highlights
- **Moved frames come back.** Since 5.1, a unit frame moved in Edit Mode could vanish or get stuck in the top-right corner. Fixed, and lost frames return to where you dropped them. Thanks for the reports!
- **Buff Reminders**, a **Loot Feed** and a **Mouse Ring**, with more of what you asked for from other addons.

## New
- **Russian** translation. Pick it in **Settings › Language**, or let FlareUI follow your game's language. Thanks to parchinskiy for the translation!
- Buffs and debuffs: **Buff Reminders** (off), on its own **Buff Reminders** tab. Thanks for the request!
  - An icon for each of your class's buffs missing on you or your group, or about to run out. Click it to cast the buff.
  - Covers group buffs, self buffs, weapon imbues and poisons.
  - Paladins: **Blessing** (Automatic) gives warriors, rogues and hunters Might, and everyone else Wisdom, or one blessing for everyone.
  - **Pet Reminders** (on): hunters call, revive or mend their pet; warlocks summon theirs.
  - **Food and Flask** (off): a reminder in dungeons and raids, or always.
  - **When It Shows**: Solo, In a Party, In a Raid, **Hide in Rested Areas** (off) and **Only When You're the Only Provider** (off).
  - **Alerts**: a **Sound** (off) and gold or orange glows (off).
  - Edit Mode: **Orientation**, **Growth** and **Icon Size**. Hidden in a fight.
- Quality of Life: a **Bags and Looting** tab, with the bag options, looting and the new Loot Feed.
- Bags: **Keyring in Backpack** (off) and **Crafting Bag in Backpack** (off) add them to the bottom of the combined backpack. Thanks for the request!
- Looting: **Loot Feed** (off) floats what you loot up beside you, so you don't have to read the chat. Thanks for the request!
  - **Position**: **At the Cursor** (default), or **Where Placed** in Edit Mode.
  - **Minimum Quality** (Poor) and **Show Money** (on).
- Quality of Life › Gameplay › Cursor: **Mouse Ring** (Off) puts a bronze ring round your cursor: **Always**, **In Combat** or **While Right-Clicking**.
  - **Size** (40) and **Thickness** (3).
  - **Cast Ring**, **GCD Ring** and **Swing Ring** arcs (off).
  - **Out-of-Range Colour** (off) turns it red while your target is out of reach.
  - **Class Colours** and **Hide While Turning** (off).
- Quality of Life › Advanced: **UI Scale** (Blizzard's) sets the size of the whole interface as you log in. Pick **Pixel Perfect**, a preset for 4K, 1440p or 1080p screens, or **Custom** (30% to 200%). Thanks for the request!
- Quality of Life › Interface: **Wider Vendor Window** (off) shows 20 items a page.
- Minimap: **Open on Mouseover** (off), under **Addon Button Drawer**, opens the drawer when you point at the day/night button. Thanks for the request!
- Chat › Formatting, all off. Thanks for the request!
  - **Race Icons** and **Class Icons** before player names.
  - **Item and Spell Icons** inside links.
  - **Whisper Markers**: a green > for whispers you get, a red < for ones you send.
  - **Colon After Names**: "[Aria]: hello".
- Chat: with **Better Player Names** on, Say lines start with a clickable **[Say]** label (**[S]** with short channel names). Click it to switch your chat back to Say. Thanks to parchinskiy for the feature!
- Unit frames: **Range Check** (on), in the Look section of the target, focus, party, raid and boss frames. Off, the frame never fades for distance. Thanks for the report!
- Resource bars: **Range Check** (on) for the three swing timers.

## Changed
- Quality of Life: **Buy More Than One Stack** is now **Enhanced Vendor Purchases**, with **Stack** and **MAX** buttons, items that don't stack, and its progress above the vendor window. Your setting carries over.
- Chat: **Short Channel Names** is now **Channel Names**: **Full**, **Short** ("[2. Trade]") or **Number** ("[2]"). If you had it on, you get Number.
- Chat: the **Formatting** options are in a new order.
- Quality of Life: **Convenience** is now at the top of the Gameplay tab.
- Action bars: **Skin Cooldown Manager** moved to the bottom of **Tweaks**. Your setting carries over.
- Player frame: the **Mana on Shapeshift** bar is as tall as the power bar, so its number is easier to read. Thanks for the report!
- Tooltips: **Compare with Shift** is now off by default.

## Fixed
- Unit frames: frames moved in Edit Mode no longer vanish or jump to the top-right corner. Thanks for the reports!
- Resource bars: swing timers now turn red when your target is out of range.
- Minimap: addon buttons on the edge of the square minimap no longer slip behind its border. Thanks for the report!
- Settings and tour: buttons grow to fit longer translated labels, and the profile buttons move to two rows when they need the room. Thanks to parchinskiy for the fix!

# FlareUI 5.1

## Highlights
- **Fading for more frames.** Unit frames, resource bars, the player cast bar and the gryphons get a **Fading** section at the bottom of their Edit Mode dialog, with the same **Visibility** choices as the action bars.
- **Missing Health** keeps the player frame, pet frame and health bar visible while that unit is hurt.

## New
- Unit frames (player, pet, target, focus, target of target, target of focus): **Visibility**. They fade at once.
  - Player and pet only: **Faded Opacity** and **Missing Health**.
  - This replaces **Fade Player and Pet**. If you had it on, both frames keep the same behaviour.
- Resource bars: **Fade Group**, **Visibility**, **Fade Speed** and **Faded Opacity**.
  - A fade group lets a bar fade with your action bars.
  - The health bar also has **Missing Health**.
  - Your old Visibility choice carries over.
- FlareUI Player Cast Bar: **Visibility** (Always) and **Faded Opacity**.
- Gryphons: each **End Cap** dialog has its own fading, fade groups included. Both start on **Same as Action Bar 1**, so nothing changes until you pick something else.
- Edit Mode: **FlareUI Battleground Objectives** moves the scores at the top of the screen. Needs **Move Any Window** on. Thanks for the request!
- Quest tracker: **Colour Names by Difficulty** (off) colours quest names like their level. Complete and focused quests stay green and blue.
- Quest tracker: FlareUI's tracker works in Gamepad mode again. **Force Blizzard Tracker** (off), in Quality of Life › Gamepad, shows Blizzard's there instead. Thanks for the feedback!

## Changed
- Health bars: shields now start after your health and incoming heals, as in Blizzard's frames, so missing health is never hidden behind them. Thanks for the report!
- Nameplates: combo points sit below the enemy's cast bar, so a cast no longer covers them. Thanks for the report!
- Resource bars: new default places, and **In Combat** by default for the health, power, druid mana and combo point bars. Bars you placed yourself don't move.
- Settings window: switches about the same thing now sit together on every page.
  - **Completed Last** moved to the quest tracker's Quests section.
  - **Pet Food Marker** and **Auto Type "delete"** moved to Bags and Looting.
  - Quality of Life's Controller section is now **Gamepad**.

## Fixed
- Quest tracker: the Forever tracker sections of Shortest Path, SkillUp and Adventure Guide Forever no longer disappear while FlareUI's Quest Tracker is on. Thanks to the players who tracked it down!
- Minimap: EnhanceQoL can no longer move the day/night button (and the Addon Button Drawer) over the calendar.
- Minimap: the map no longer chases your cursor when a Lueur 1.6 scan pauses over a window or while you turn the camera.
- Radials: a radial on LT or RT + L3 no longer takes L3's Auto Run outside fights. In a fight L3 stays with the radial, because the game locks bindings in combat. Thanks for the report!

# FlareUI 5.0.6

## Fixed
- Minimap: gathering addons that read nodes by sliding the hidden minimap under your cursor (Lueur, NodeSight, Nodeworthy) work with FlareUI now:
  - The minimap no longer ends up outside its frame after gathering, and no longer shows while it chases the cursor.
  - The mouse wheel zooms the camera again during their scans, instead of the hidden minimap.
  - Auto zoom-out and **Coordinates on Hover** wait for a scan to finish instead of cutting it short or flashing.
  - A faded-out minimap keeps being scanned.
- Minimap: Gathercraft can read the minimap's tooltip again, and its tracking button no longer causes errors in a fight.
- Action bars: turning **Show button art** off no longer throws a Lua error. Thanks to parchinskiy for the fix!

# FlareUI 5.0.5

## Changed
- Buffs and debuffs: the **Border** aura swipe draws a thicker ring around the icon, so the time left is easier to read. Thanks for the feedback!

## Fixed
- Target and focus no longer fade when you stand right next to an enemy. Range fading checked the first rank of your spells, which the game stops counting once you learn a higher one: a warrior or rogue was left with only Charge or Throw, which can't reach up close. It now uses the best rank you know. Thanks to the players who reported it!

# FlareUI 5.0.4

## Changed
- Forever and FlareUI styles: the **rest, combat and threat glows** now tint the portrait's own border with a soft pulse, instead of a bright line around it. Threat comes first while you have it.

## Fixed
- Controllers: both analog sticks work again with FlareUI on. Since 5.0 the controller radial kept listening to the sticks all the time; now it only listens while it is open. Thanks to the player who reported it!

# FlareUI 5.0.3

## Changed
- Unit Frames: **Player Cast Bar** has its own switch again, next to Main Frames. Turn it off and Blizzard's cast bar comes back (after a reload). Thanks to everyone who missed it!
- Player frame, Edit Mode: **Standalone Cast Bar** is gone. The **Cast Bar** section stays, for a cast bar on the player frame itself, now off by default and apart from the Player Cast Bar.
- The settings window is a little taller, so the Unit Frames page fits without scrolling.

# FlareUI 5.0.2

## New
- **Italian** and **Latin American Spanish**, and a full **Spanish (Spain)** translation. Pick one in **Settings → Language**, or let FlareUI follow your game's language.
- **Portuguese (Brazil)** is complete again, with shorter labels that fit the settings and the words players use: buffs, debuffs, pet, cast bar, frames.
- Tooltips: **Simplified Item Stats** (off). Item tooltips say "+12 Spell Power" instead of "Equip: Increases damage and healing done by magical spells and effects by up to 12.", set bonuses too.

## Changed
- Item tooltips show stats as the game writes them again. The short form, always on since 5.0, is now the **Simplified Item Stats** switch under Tooltips. Thanks to everyone who asked!

## Fixed
- Minimap: with a node-finding addon and Find Minerals or Find Herbs on, the coordinates, the header bar (tracking, zone, clock and calendar), the mail icon and the day/night badge no longer fly across the screen with your cursor or flicker. Thanks to the players who reported it!

# FlareUI 5.0.1

## New
- **Visibility is now a list of toggles** on bars, the XP bar, buffs, debuffs, the quest tracker, the minimap, Resource Bars and the Fake Cooldown Manager. Tick **In Combat**, **Has a Target**, **Has an Attackable Target**, **In a Group** or **Not Mounted** in any mix: any one of them shows it. Your current choice carries over.
- Buffs & Debuffs: **Skin Cooldown Manager** (on). Blizzard's Cooldown Manager in FlareUI's look: its bars like FlareUI's cast bars, its buff icons like your FlareUI buffs. Everything it lets you set still works. Thanks to the player who asked!
- Action Bars: the **FlareUI XP Bar** switch is back (on). Off brings back Blizzard's XP and reputation bars after a reload.
- Player frame, Edit Mode: a **Cast Bar** section, for a cast bar on the frame itself. *(Reworked in 5.0.3.)*

## Changed
- Health, power and threat numbers show in full up to 9,999 ("8742", not "8.7K").
- **Settings read the same everywhere.** Names are in Title Case, options are grouped the same way (dropdowns, then sliders, then switches) in the settings and in every Edit Mode dialog, and one thing has one name. The renames you may look for:
  - **Visibility** (was Show Condition or Show) and **Faded Opacity** (was Min Alpha)
  - **Border**, **Buff Size**, **Debuff Size**, **Growth**, **XP Text**, **Threat Text**, **Sort By**
  - **Keep Bar 1 in Stances**, **Hide Bubbles in Instances**, **Controller Bar**
  - **Off** instead of None on Health Text, Power Text, Aura Swipe and Aura Timer

  Searching an old name still finds the option.
- Action Bars: **Steady attack highlight** is gone. Attack, Auto Shot and Shoot blink as Blizzard's do.

# FlareUI 5.0

Biggest update for FlareUI yet. Every single aspect of the addon is improved in an inversely proportional rate to the developer's health. Read the LotR sized changelog below to find out what changed.

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Highlights
- **Bags**: columns, gaps between bags, bag slots down the side of the backpack, rarity colours, a junk coin and an **upgrade arrow** on gear that beats what you wear.
- **Proc Glow** lights spells that a proc buff empowers: Fingers of Frost, Missile Barrage, Shadow Trance, Maelstrom Weapon, Eclipse and more.
- **Cast bars**: "Interrupted by" with the kicker's name, a tick showing when your interrupt is back, a latency zone, channel ticks and a spell queue mark.
- **Target and focus**: range fading, **Show Threat** and **Highlight Purgeable Buffs**.
- **Damage Meter**: a **Threat Meter** section with a pull aggro line, a pull warning and the tank's lead.
- **Radial Menu**: a **Party** category to cast on group members, a **Quest Items** button, range tint, item counts and spell charges, and controller buttons for each radial.
- **Controller**: the settings window works with the gamepad again, and the controller can rumble for alerts and procs.
- **Quest Tracker**: rewards in tooltips, Pin to Top, timer bars and Wowhead links.
- **XP bar**: its tooltip is back, with XP per hour and time to level.
- **Item tooltips**: "+12 Spell Power" instead of a long Equip line, and gear comparison only while you hold Shift.
- **Settings**: a **Language** page, profile import with a preview, profile Rename, and a much smarter search.

## Unit Frames
### New
- Target, focus and boss frames fade when the unit is out of range, like party and raid frames. Measured with your own spells, so it follows your class's range.
- Target and focus: **Show Threat** (off), below Combo Points in Edit Mode: your threat on the unit as a percent, in the threat colours, matching the Damage Meter's Threat tab. In FlareUI and Forever Style it's a big number above the portrait ring; in Addon Style it follows the health value, like "75% | 42%". Tanking, it shows your lead over the next in line.
- Target and focus: **Highlight Purgeable Buffs** (off), below Only My Debuffs: buffs you or your group can purge or dispel come first, with Blizzard's stealable border.
- Cast bars: an interrupted cast or channel stays up for a moment in red, saying **Interrupted by** and who kicked it, in their class colour. Your own failed cast says **Failed** the same way.
- Cast bars, enemy casts: a white tick shows where in the cast your interrupt comes off cooldown. It's gone once your interrupt is ready (the bar turns green) and on casts that can't be interrupted.
- Player cast bar:
  - **Latency Zone** (on): the end of the bar your latency covers, in red.
  - **Spell Pushback** (off): how far being hit has set your cast back, like "+0.5".
  - **Channel Ticks** (off): bronze lines where each tick of a channelled spell lands.
  - **Spell Queue Window** (off): a mark near the end of the bar; press your next spell after it and it goes off as soon as this one ends.
  - It greys out while your target is out of the spell's range, and its **Border Texture** can be changed in Forever Style too.
  - Edit Mode's sample takes turns between a cast and a channel to show all of this.
- Pet frame: a **Cast Bar** for your pet's casts, with the target frame's options. Off by default.
- Health Text on every frame: **Health Lost** (how much health is missing, like "-1.2K") and **Current (Max) | Percent** (like "18K (24K) | 75%").
- Power Text on every frame is a dropdown with the same choices as Health Text (apart from Health Lost): None, Percent, Value (the default), Value | Percent, Current (Max) and Current (Max) | Percent.
- **Timer colour** (off), below Aura timer: aura timers turn yellow under 10 seconds and red under 5.
- **Aura swipe** in the Unit Frames settings (Both by default): how the time left shows on the aura icons of every unit, party, raid and boss frame.
- The target frame's **Combo Points**: in FlareUI Style a dropdown above Show Level, **Classic** (gems round the portrait, the default), **Modern** (the bar along the health bar) or **Off**; in Addon Style a switch.
- The five-second rule spark also runs on the Mana on Shapeshift strip, for druids powershifting.
- Totems: **Aura Swipe** and **Aura Timer** in Edit Mode, with a live preview, and new default places in each style.
### Changed
- Health Text: **Current | Max** is now **Current (Max)**, like "18K (24K)", and **Value + Percent** is **Value | Percent**.
- Unit frame styles save only what you changed from the defaults, so later updates to a default reach every style, and shared profile strings get smaller.
- Edit Mode: **Class Colours** sits below Background Opacity, and **Cast Bar Border Texture** right below Cast Bar Texture, on every frame that has them.
- A unit with more shield than missing health (at full health too) shows Blizzard's shield glow at the end of its health bar, on every frame.
- Player cast bar: a finished cast fills the bar and fades out, as Blizzard's does.
- **Player cast bar** is part of **Main frames** in the Unit Frames settings.
- Focus frame: **Hide Auras** is gone. Set Buffs and Debuffs to Off for the same result; if it was on, that's done for you.
### Fixed
- Pinging an enemy through a FlareUI frame in a dungeon or raid no longer causes an error that stopped pings until a /reload.
- Target of Target and Target of Focus show a player's class colour when the target is a creature, and the right name and level when the target switches who it's targeting.
- Other players' Russian, Chinese and Korean letters no longer show as boxes on FlareUI's frames, Damage Meter rows and tooltips, whatever font you picked.
- A fight starting while Edit Mode is open no longer leaves sample frames stuck on screen, or buff timers frozen on sample times.
- Portraits no longer stay blank after a loading screen.
- A unit that dies clears its power text at once, Smooth Bar Animations no longer leave a sliver of health on a dead unit, and a hunter feigning death no longer shows "Dead".
- Cast bars: a channel chained right after another no longer shows without its bar, and the player cast bar can no longer stay up if the game misses the cast's end.
- Range fading for druids in Cat or Bear Form uses melee range.
- Combo points update when your points move to a new target.
- Addon Style: the ready check mark sits in the middle of the health bar.
- Totems: in Edit Mode, right-clicking the sample totems can no longer dismiss a real totem.

## Party, Raid and Boss Frames
### New
- Main tanks: **Tank Targets** (off), in Edit Mode: what each main tank is targeting, in a small frame below or right of theirs. Click it to target that mob.
- Raid: **Power Text** (None by default) and **Power Bar for Mana Users Only** (off).
- Boss frames: **Highlight Purgeable Buffs** (off): buffs and enrages your group can purge, dispel or soothe come first.
- Boss frames close up when a boss despawns, so there's no empty slot between the bosses still up, in combat too.
- A dead member fades by the distance to their corpse, measured with your resurrection spell.
- Hovering a party or raid member's buff or debuff shows the member's tooltip instead, so mouseover healing isn't covered. Boss frames keep their aura tooltips.
### Fixed
- Party frames show when you join a group in combat, instead of after the fight. Raid frames and Hide Player Frame while in party react too.
- Dispel Icons: one symbol per debuff type you can dispel, each type always in the same spot.
- Dispellable Debuffs Only: boss debuffs and other important ones (like Living Bomb) stay visible, as with Blizzard's own option.
- Key bindings from click-cast addons like Clique work when hovering the frames.
- A pet called mid-fight no longer covers the next party frame: room for a pet is kept under hunters and warlocks.
- A member whose class arrives late gets their class colour at once, and a member who disconnects or comes back fades or brightens at once.
- The phasing icon only shows for members within 250 yards.
- When bosses swap slots mid-fight, each frame shows the right name and auras.
- Forever Style: incoming heals and shields are no longer drawn too long.
- Only My Debuffs: flagging yourself for PvP switches the target's debuffs to yours without retargeting.

## Resource Bars
### New
- Swing timers (all off, at the bottom of each bar's Frame section in Edit Mode): **Stand-Still Zone** on the Ranged bar, **Queued Attack Colour** on the Main-Hand bar (gold while Heroic Strike, Cleave, Maul or Raptor Strike waits) and **Waiting State** (full and grey while auto attack is on but no swing runs).
- Power bar: **GCD Spark** (off): a spark crosses the bar during the global cooldown.
- Health bar: its own **Class Colours** and **Low Health Colour** (off): red under 30% health.
- The power and druid mana bars shade the mana your current cast will cost.
- Power and mana text: a **Percent** choice.
### Fixed
- Swing timers follow the classic rules mid-swing: attack speed changes (Flurry, Slice and Dice, Rapid Fire) speed up or slow the swing in progress, parrying hastens your next main-hand swing, and finishing a cast (Slam, a heal, Aimed Shot) restarts the swing.
- Swing timers keep dimming out of range, stop on death, restart at a swapped weapon's speed, and end the off-hand bar when it's removed.
- Incoming heals on the health bar keep their green colour.
- With only swing timers on, Blizzard's Personal Resource Display is left alone.
- A fight starting in Edit Mode no longer leaves the bars on sample values.

## Action Bars and Proc Glow
### New
- Proc Glow lights spells that a proc buff empowers: Ice Lance with Fingers of Frost, Arcane Missiles with Missile Barrage, Fire Blast with Wake of Fire, Shadow Bolt with Shadow Trance, Soul Fire with Decimation, Starfire with Eclipse, Lightning Bolt with Maelstrom Weapon, Aimed, Arcane and Multi-Shot with Rapid Killing, Holy Nova with Searing Light, and Holy Light with Infusion of Light. In a fight the glow follows the game's own proc alert, or the buff's icon when you track it in Blizzard's Cooldown Manager. Forever's spell IDs come from ProcDoc by wsmaxcy, with thanks.
- **Dim on cooldown** (off), at the end of the Tweaks section: buttons turn grey while their spell or item is on cooldown (not the global cooldown).
- Each bar's Show Condition: **Not mounted** (travel forms and flight paths count as riding) and **Combat + In a group**.
- Faded bars show while your spellbook is open, so you can drag spells onto them, and in Quick Keybind mode.
- Fake Cooldown Manager: a button flashes the moment its cooldown is ready again.
### Changed
- **Auto-Paging for Stealth** covers druids: Prowl in Cat Form switches Action Bar 1 to its own page.
- **Update Spell Ranks** catches up: ranks learned while it was off move onto your bars at login. The first run on a character moves every spell to its best rank; after that, a lower rank you place yourself stays.
- Edit Mode shows an orange line under Visibility when Blizzard's own Bar Visible hides the bar anyway.
- The FlareUI XP bar is always on with the Action Bars module; place and size it in Edit Mode.
- The red "most options are in Edit Mode" banner is gone from the Action Bars and Unit Frames settings.
### Fixed
- Hide Pet Bar (and the stance, possess and totem bars): a pet revived or called in a fight no longer brings the pet bar back.
- Rogue Stealth paging: Shift+number and the page keys turn the page again while stealthed.
- The out-of-range tint follows a button's new spell at once after a stance, form or page change.
- Clean Keybinds: controller buttons keep their icons, numpad "." shows as "N.", and large keybind fonts are no longer cut off.
- Proc Glow: buff-proc glows no longer stick after a fight, and Overpower, Revenge and the like no longer blink off as the global cooldown ends.
- Faded bars: no cooldown flash on bars faded below half, a flyout opened from a faded bar stays up, bars set to show in combat come up on the first frame of a fight, and changes made during a fight count at once.

## Buffs and Debuffs
- **Visibility** in the Buffs and Debuffs Edit Mode panels: Fade group, Show, Fade Speed and Min Alpha, as on the action bars.
- **Aura Swipe** and **Aura Timer** in the Buffs and Debuffs Edit Mode dialogs, with the samples changing as you pick.
- **Timer colour** (off): timers turn yellow under 10 seconds and red under 5.
- **Aura icon shape**, **Aura swipe** and **Aura timer** are named as in the Unit Frames settings.
- Changing an aura size or font restyles the icons in place, also inside dungeons and raids, instead of leaving hidden icons behind until a /reload.

## Radial Menu
### New
- A **Party** category in the Catalog: your helpful spells, spread over your group as a button for you and each party member. Aim at a person and cast without changing your target; buttons turn red when they're out of range.
- **Quest Items**, first in the Catalog's Items: one button holding your quests' usable items. Switch between them with the mouse wheel (LB and RB on a controller).
- Buttons turn red when their spell or item is out of range, stackable items show how many you carry, spells with charges show their charges, and world markers show a check mark while placed.
- **Radial scale** at the top of Options > Look: 70% to 150%.
- Setting a key the game already uses asks first, and the radial list shows "also bound to …" in orange.
### Changed
- With Update Spell Ranks on, a spell button casts the best rank each character knows; a lower rank you put on a radial on purpose stays.
- A shared radial leaves out spells, items and mounts this character doesn't have; the editor lists them greyed.
- Toggle: pressing the key again closes the radial without using anything; only a click uses a button.
- During a hold, Escape or a left-click cancels the radial.
- Macro buttons run your macro as it is now, and renaming a radial keeps macros typed with its old name working.
- Mount buttons summon by name, with the Mount Journal's own "can't use" check.
- Radials tab: the live preview sits at the foot of the right column with **Undo changes**, the Catalog got the room, and buttons show as the radial's own round buttons.
### Fixed
- World marker buttons show the marker they place (each icon was wrong).
- Pressing Shift, Ctrl or Alt while holding a radial key no longer loses the release and leaves an invisible layer over the screen.
- Holding two radial keys, letting go of the first no longer fires a button of the second.
- Toggle on a mouse button fires the aimed button on the second press, as with a key.
- Menu Position changed during a fight no longer makes the lit button and the one that fires differ.
- The editor stores a dragged spell as the spell, never its spellbook slot, and a cancelled key capture no longer clears Undo.

## Controller and Gamepad Mode
### New
- The settings window works with the controller again: the D-pad moves, A uses, LB and RB switch tabs, LT and RT switch pages, B closes. In the Radials tab X removes a button and Y picks it up to move it.
- Radial Menu: a **Controller** row for each radial: **Controller stick** (L3 or R3, alone or with LT, RT or both: up to eight radials) and **Gamepad bar** (put a radial on a slot of your controller bar).
- Radial Menu: the aimed button stays lit when you let go of the stick and R3 uses it; **Release the stick to use** (on) and **Press again to repeat** (off).
- Quality of Life > Controller: **Rumble on alerts** and **Rumble on procs** (both off).
### Changed
- Radial Menu: **Controller support** is on by default (it only acts in the Gamepad UI), and L3 stays Auto Run unless you give it a radial.
- Quest Tracker: in Gamepad mode the game's own tracker shows, so D-pad Up, its quest items and its menus work with the controller.
### Fixed
- The camera holds still while you aim a radial in a fight.
- FlareUI no longer opens Blizzard menus or windows that can hang the game in Gamepad mode, and What's New no longer opens by itself there.
- Faster Camera Zoom leaves the stick's zoom alone.
- With ConsolePort, Improved Forever, Easy Controller or Controller Forever loaded, FlareUI leaves the controller to them.

## Chat
### New
- **Copy chat button** (on): a small note icon in the top right corner of each chat window opens Copy Chat for it. It replaces the tab menu's Copy Chat entry.
- **Min Alpha**, below Fade Speed: how far the chat fades out, 0% (the default) to 90%.
- Saved History keeps conversation only (what players say and your whispers, including whisper tabs), each line with the time it was said, and a grey "Saved history ends here" line between sessions.
### Fixed
- The arrow-key history brings back a line with its channel, so a recalled whisper goes to the same person.
- Up and Down don't recall during chat lockdown (boss fights, rated PvP), and secure commands such as /cast are no longer kept.
- A whisper you start switches to its new whisper tab straight away.
- Close in the tab menu gives the window's channels back to the main window, as Blizzard's does; whisper windows no longer offer Pop Out or Lock.
- Saved History: Battle.net friends come back as the right friend, lines come back in their own colours above today's chat, and the Combat Log is no longer saved.
- Web addresses are clickable on lines that also hold a link, and clicking a cut-off tab scrolls the tab row correctly.

## Damage Meter and Threat
### New
- A **Threat Meter** section (all off): **Pull aggro line** (110% of the tank's threat in melee, 130% at range), **Pull warning** (your bar flashes from 85%) and **Tank's lead**. Turning one on shows sample rows on the Threat tab.
- **Threat Value Display**: percent (the default), value and percent, or value only. The mouse wheel scrolls a long list.
- **Reset on entering a dungeon** (off).
- **Min Alpha**, below Fade Speed.
- The meter's gear menu has a **FlareUI Settings** entry.
### Changed
- The settings have a **Frame** tab and a **Tweaks** tab. The Toggle Threat Meter key binding is gone (the radial's Toggle Threat Meter still works).
- A note at the top when Blizzard's own Visibility for the meter hides it in fights, with a button to Edit Mode.
### Fixed
- **Match chat size** makes the meter exactly the chat's size.
- The Combat Timer shows the length of the segment each window shows, and keeps counting after a /reload in a fight.
- Threat tab: no swapping places on equal threat, no "0 0%" rows, no freezing when the mob is only your target's target, and pets take their owner's colour.
- The Countdown button shows only for those allowed to start one, and the Ready Check and Countdown buttons follow promotions in a fight.
- A long list no longer slides under the title row in a fight, and the meter shows fully while its settings page is open.

## Quest Tracker
### New
- A quest's tooltip lists its rewards: XP, money and items.
- **Pin to Top** and **Wowhead Link** in a quest's right-click menu.
- Timed quests show a thin bar under the timer.
- **Visibility** in its Edit Mode panel, as on the action bars.
### Fixed
- Quests offered by an item or an area show at the top, with "Click to view quest".
- In a fight with quest item buttons showing, the list holds still and the buttons stay usable, so a button can't end up beside the wrong quest.
- Clicking a quest opens the map on that quest the first time, also with map addons like OpenMap.
- Minimizing a tall tracker near the top of the screen no longer drops it to the bottom.
- Scenario objectives follow Blizzard's own rules, and objectives that fill a bar show their percentage.
- No more "Auras cannot be accessed when secret" error from Blizzard_MawBuffs on level-up.

## Minimap and XP Bar
### New
- Minimap (square): the whole square zooms and pings, corners included.
- **Middle-click menu** (on): game panels from a middle-click on the map. Not in combat.
- **Coordinates on hover** (on): the coordinates show only while you point at the map.
- The zone map (Shift+M) gets FlareUI's thin bronze border, and its tab drags it.
- XP bar: a tooltip again, with XP, rested XP, quest XP and **XP per hour** with the time to level; standing on reputation, progress on honor. It lists each quest ready to hand in with its XP.
- XP bar: **Quest XP** is a choice: Off, Finished quests, All quests or Quests in this zone. Your setting carries over.
- XP bar: a short light runs over the fill when you gain XP.
### Changed
- Addon Button Bag: smaller buttons, six to a row, and it also collects buttons on the minimap's backdrop or named by other icon libraries.
- Auto zoom out sits right below Style.
### Fixed
- With a node addon such as Lueur and Find Minerals or Find Herbs on, a black square no longer chases the mouse cursor.
- Edit Mode's minimap options are no longer removed from Blizzard's own list.
- An addon loaded later gets its minimap button into the Addon Button Bag too.
- The Toggle Minimap key is no longer undone when a faded map fades back in.
- XP bar: a level-up lands at once, and a faded bar no longer catches the mouse.

## Tooltips
- Item tooltips: simpler stat lines. "Equip: Increases damage and healing done by magical spells and effects by up to 12." reads "+12 Spell Power", set bonuses included.
- **Compare with Shift** (on): the tooltips of the gear you wear show beside an item only while you hold Shift. Turning it off restores your own setting. The Tweaks section is in two columns.
- **On action/data bars** (renamed from On action bars) also covers the XP bar.
- Set to Never on action bars, pet bar, macro, mount, toy and flyout tooltips hide too, and chat link comparison tooltips follow the tooltip scale.

## Quality of Life
### New
- **Bags and Looting** with options for Blizzard's bag windows: **Columns**, **Gaps between bags**, **Integrated bag buttons**, **Rarity colours**, **Thicker borders**, **Junk coin** and **Upgrade arrow** (a green arrow on gear you can wear that scores higher than what you have on). They stand aside when another bag addon is loaded.
- **Open flight map at once** (off): a flight master with no quest for you opens the flight map straight away. Hold Shift to talk normally.
- **Fade map while moving**, **Double-click to fish** and **Fishing sounds** (all off).
- **Buy more than one stack** (off): Shift+click to buy several stacks at once.
- Nameplates: **Level before name** (off).
### Changed
- Durability Warning also shows in the middle of the screen with a sound, ignores thrown weapons, and notices items that mend themselves.
- Sell Junk says how many items it sold and the gold that came in, sells what the server skipped a moment later, and Auto Repair says when you can't afford it.
- Hide Error Messages keeps "bag is full" errors and hides ping errors.
- Alert Sounds: no alert for your own ready check, and no double sound.
- Gameplay is laid out in two columns, and Combat enemy plates comes first in Nameplates. The Party frames title option is gone.
- Max Camera Zoom, turned off, puts back Blizzard's own default.
### Fixed
- Auto Accept Quests no longer takes grey or repeatable quests the game hasn't fully loaded, and Auto Turn-In leaves quests that take battleground marks to you.
- Move Any Frame: a window that closes while you drag it keeps its position; the loot window and windows the game protects are left alone.
- Auto-type "delete" no longer keeps the cursor in the box, so Enter can't delete by mistake.
- Faster Auto Loot empties a loot window that reports its items a moment late.
- Skip Loot Confirmations also skips the Disenchant roll confirmation.
- Camera and nameplate settings are remembered per character when the game saves them per character.

## Settings and Profiles
### New
- A **Language** page, thanks to parchinskiy: turn off **Use the game language** to pick English or any translation the addon has. The settings window makes room for longer text.
- Profile import shows a preview: tick which parts to take, as a new profile or into the one in use, with the version and UI scale the string was made with, and any missing fonts or textures.
- Profiles: **Rename**, without a reload.
- Search understands other words ("transparency" finds Opacity, "aggro" finds Threat), plurals and words run together, lists matching tabs and sections first, and finds Edit Mode and font settings.
- Shift + mouse wheel over the settings window sizes it, 70% to 130%.
### Changed
- Closing the settings window with changes waiting for a reload asks "Reload now / Later".
- About: the slash commands sit one per line.
- Spanish (Mexico) clients use the Spanish (Spain) translation where there is no Mexican one.
### Fixed
- Each character's profile choice sticks across restarts and no longer spreads to your other characters.
- A damaged or hostile profile string can't freeze the game or break a frame.
- A "Reload now" button left up when a fight starts no longer turns invisible while still catching clicks, and Escape or Enter in a fight no longer answers a dialog while also reaching the game.
- Opening FlareUI from Options > AddOns no longer closes Blizzard's options window in a way that could lose key binding changes.
- Reset every setting no longer ticks again Edit Mode checkboxes you had unticked.

## Performance
- Party and raid frames: health, heals and shields are drawn at most once per frame per member, a pull no longer redraws everyone at once, and power ticks only move the bar.
- Power bars only redraw for their own power type, and only frames that are shown listen for range.
- Proc Glow reads the Cooldown Manager only when something changes, instead of four times a second.
- Chat: names are formatted once per message, lines shown in several windows once, and the hidden Combat Log no longer costs anything.
- Damage Meter and Threat tab: rows are styled once, and in a raid the threat list only redraws for its own mob.
- Radial Menu: pressing a radial key no longer rebuilds every radial.
- Settings search waits for you to pause typing, and the window draws each page once.
- Many smaller savings across Resource Bars, the XP bar, the Quest Tracker, faded bars and Show Threat.

## For Testers
- `/fui errors`: the last 20 errors FlareUI caught quietly, with version, build, language, class and level, ready to copy into a bug report. `/fui errors clear` empties it.
- `/fui taint`: notes when one of Blizzard's controller systems turns tainted, and the addon the game blames. `/fui taint report` lists them.
- `/fui perf`: the report's "highest" column is labelled "highest 1 s average".
- Several safety checks on values the game keeps secret in combat and instances.

---

Older versions (4.3 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
