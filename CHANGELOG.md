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
- **Visibility** on bars, the XP bar, buffs, debuffs, the quest tracker and the minimap is now a list of toggles: tick **In Combat**, **Has a Target**, **Has an Attackable Target**, **In a Group** and **Not Mounted** in any mix, and any one of them shows it. **Always** and **Mouseover** clear the rest. Your current choice carries over (Combat + Target is now In Combat and Has a Target ticked).
- The same toggles for:
  - **Resource Bars → Visibility**: also **In a Group** and **Not Mounted**. Swing timers keep **Only When In Use**.
  - **Fake Cooldown Manager → Visibility**.
- Player frame, Edit Mode: a **Cast Bar** section like the target's, topped by **Standalone Cast Bar** (on). On, your cast bar is the FlareUI Player Cast Bar, placed on its own as before. Off, it hangs off the player frame instead, with Cast Bar Position, Texture, Border, Height, Hide Icon, Hide Spell Timer, and the standalone bar's Latency Zone, Spell Pushback, Channel Ticks and Spell Queue Window, in your own cast colours.
- Buffs & Debuffs: **Skin Cooldown Manager** (on): Blizzard's Cooldown Manager in FlareUI's look. Tracked Bars look like FlareUI's cast bars (the unit frames' bar texture, a thin bronze border, the cast bar font); Tracked Buffs icons look like your FlareUI buffs and follow Aura Icon Shape and Aura Swipe. Everything Blizzard's Cooldown Manager lets you set still works. Thanks to the player who asked!
- Action Bars, XP Bar: the **FlareUI XP Bar** switch is back (on). Off brings back Blizzard's XP and reputation bars. Needs a reload.

## Changed
- Health, power and threat numbers show in full up to 9,999 ("8742" rather than "8.7K"), then shorten as before (12K, 1.2M).
- One name for when a frame appears: **Visibility** everywhere (it was Show Condition, Show or Visibility). Searching the old names still finds it. Chat and Damage Meter keep their single-choice Visibility.
- In Edit Mode, FlareUI's fading rows sit under a **Fading** title, and **Min Alpha** is now **Faded Opacity** (also in the Chat and Damage Meter settings).
- Every setting name, choice, tab and button is now in Title Case, in the settings and in Edit Mode alike, so a setting reads the same wherever you open it.
- Settings say the same thing the same way. A few you may look for:
  - **Border** (was Frame Border or Border Texture), **Buff Size** and **Debuff Size**, **Growth** on buffs and debuffs, **Scale** on Tooltips.
  - **XP Text** and **XP Text Visibility** (were XP Bar Numbers and XP Bar Text), **Threat Text** (was Threat Value Display), **Sort By** on the Quest Tracker.
  - **Keep Bar 1 in Stances** (was No Auto-Paging for Stances), **Hide Bubbles in Instances** (was No bubbles in instances), **Proc Glow**, **Fake CM Setup Mode**, **Controller Bar** on the Radial Menu.
  - **Off** instead of None where it turns a feature off: Health Text, Power Text, Aura Swipe and Aura Timer.
  - Searching the old names still finds them.
- Options are grouped by type everywhere: dropdowns first, then sliders, then switches, in the settings and in every Edit Mode dialog. The same option now sits in the same place on the player, target, focus, party, raid and boss frames.
- The XP Bar's options sit under the **FlareUI XP Bar** switch, and the Meter tab's options under **Meter Tab in the Chat**.
- Action Bars, Tweaks: **Steady attack highlight** is gone. Attack, Auto Shot and Shoot blink as Blizzard's do.

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

# FlareUI 4.3

Radials that know which character they belong to, a cleaner Radial Menu page, an official FlareUI Edit Mode layout, a round minimap and two action bar tweaks.

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## New
- Radial Menu: each radial has its own **Available to** (all characters, all Alliance or Horde characters, all characters of a class, or only this character) and its own **Key**, shared by every character that gets it. Your characters pick up their radials at login, so a Druid radial stays on your Druids. Two radials can share a key: on a character that gets both, the narrower one wins. Tick **Only this character** to give one character its own key.
- Radial Menu: **Copy** a radial (handy for a Horde or class version), and **Create macro** right next to its key.
- Minimap: **Style**, Square (the default) or Round, Forever's own round minimap, thanks to parchinskiy. Needs a reload.
- The **FlareUI Edit Mode layout**: copy its code from the bottom of the About page (or the new page in the setup tour) and import it in Edit Mode to set your screen up like ours.
- Action Bars, Tweaks: **Steady attack highlight** (on): Attack, Auto Shot and Shoot stay lit in red while they're on, instead of blinking.
- Action Bars, Tweaks: **Gryphons behind bars** (off): the art at each end of the main bar sits behind your bars instead of over them.

## Changed
- Radial Menu page: one Radials tab with your radials on the right, what opens on this character below them, and a bigger editor with a two-column Catalog. The Keybinds tab is gone: your keys were moved onto your radials and every character keeps the keys it had.
- Radial Menu now sits below Quality of Life in the settings list.
- Party frames: new default places for Forever Style and FlareUI Style (frames you already moved stay where they are).
- Quest Tracker: an empty tracker says why, instead of looking minimized.

## Fixed
- Action bar 1: the page arrows no longer hide under the left gryphon.
- Pet bar with Show button art: the frames no longer hang over each other.

# FlareUI 4.2

Stack counts get their own font, chat windows can be made click-through from the tab menu, and every aura frame now follows one shared set of rules, which fixes several aura bugs.

## New
- Buffs & Debuffs and Unit Frames: **Aura stacks** font on the Fonts tab, with face, size, outline and shadow for stack counts, separate from the timers. It starts as a copy of your timer font, so nothing changes until you edit it. On unit frames its size can be **Auto** (the default), sized to the icon.
- Chat: **Make Uninteractable** in the chat tab's right-click menu, Blizzard's own option. Links in that window stop reacting and it can't be resized. Docked windows switch together. Right-click the tab again to undo it.

## Changed
- Unit Frames, Aura timers font: its Size now works. **Auto** (the default) keeps sizing the timer to the icon.
- Party, raid and main tank frames: with dispel icons on, a debuff you can dispel shows only as its dispel icon, no longer a second time in the debuff row, like Blizzard's raid frames.
- Boss frames pick their debuffs the same way as the target frame, no longer by party-frame rules.
- The "Restore your Edit Mode layout?" prompt after switching characters now reloads your interface to finish the switch.

## Fixed
- Target, focus and pet: **Only My Debuffs** hid other players' debuffs on friendly units and on yourself. It now filters enemies only, like Blizzard's target frame.
- Action bars could vanish in combat until the fight ended after restoring an Edit Mode layout from FlareUI's prompt.
- A Lua error when opening Edit Mode in combat or in an instance with Buffs & Debuffs on.
- Party and raid frames: the dispel highlight added a hidden slot each time you changed its look in Edit Mode.
- Pet frame: Hide Buffs no longer hides timed buffs while the pet is far away, like target and focus.

# FlareUI 4.1

Your damage meter as a chat tab, a real Clear All for raid markers, and two fixes.

## New
- Damage Meter: **Meter tab in the chat**, off by default, thanks to Gregory Duhamel. A Meter tab joins your chat tabs and shows Blizzard's meter inside the chat window, at the chat's size. Click a chat tab to get the chat back, in combat too. A chat tab whose messages arrive while the meter covers them lights up. Find it in Settings > Damage Meter > Meter Tab, with:
  - **Open the Meter tab**: When clicked, In combat (back to the chat after the fight, the default), In group or At login.
  - **Ignore chat fade**: the chat window stays up while the Meter tab is open.
  - While the tab is on, the meter's own Visibility waits, and it doesn't show in the Gamepad UI.
- Radial menu: **Clear All Markers** removes every raid marker on players and enemies at once. Add it from the Markers category in the radial menu editor. New radials get it on their own.

## Changed
- Radial menu: the two old clear slices now say what they do: **Clear Target's Marker** and **Clear World Markers** (the flares on the ground). If your "Clear All" slice never removed the marks over heads, it was Clear World Markers: swap it for Clear All Markers.
- Combat + Attackable Target (Fake Cooldown Manager, fading bars and Resource Bars): a dead target no longer counts, so clicking a corpse to loot it doesn't bring the bars back.

## Fixed
- Player cast bar with Cinematic: it no longer stays hidden after a login or /reload.

---

Older versions (4.0 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
