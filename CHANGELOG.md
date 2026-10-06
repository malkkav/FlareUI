# FlareUI 1.6

A quest tracker of FlareUI's own, a bag for every addon's minimap button, and a big clean-up that makes FlareUI lighter while you play.

## New

**Quest Tracker** (Modules, off by default)
- FlareUI's own quest tracker in place of Blizzard's: your tracked quests and tracked recipes in a FlareUI window, placed and sized in Edit Mode ("FlareUI Quest Tracker").
- **Current Zone First** and **Nearest First:** quests of the zone you are in go to the top, the rest follow by distance as you move. **Completed Last** sinks quests ready to turn in.
- **Zone Headings** you can collapse, a **Zone / All** switch in the header, and an optional **Quest Count** ("Quests 14/25").
- **Quest Level** and **Quest Tags** in front of the name (+ elite, g3 group of three, d dungeon, r raid, pvp), **Numbers Last** ("Boar Tusks: 3/8") and **Wrap Long Text**.
- Quest item buttons beside their quest, usable in combat, with cooldowns and a red tint while out of range.
- Hover a quest for its description, objectives and your party's progress. Click to open it in the quest log, shift-click to link it in chat (or untrack it), middle-click to collapse it, right-click for Focus, Share, Untrack and Abandon.
- **Minimize** to the header, or to a single "+" button (**Minimize Style**). A keybind too: Key Bindings > AddOns > FlareUI.
- **Auto-Minimize:** minimize or expand the tracker when you enter a dungeon, raid, battleground, arena, city or inn, the open world, or combat.
- **Untrack High-Level Quests:** quests too far above your level are untracked when you accept them, and tracked again once you are close enough.
- Its own fonts, border and background opacity. Thanks to BetterQuestTracker by deface (MIT) for parts of the quest ordering, item buttons and party progress.

**Minimap**
- **Addon Button Bag** (on): click the day/night badge to open a bag with every addon's minimap button and the addons of Blizzard's addon compartment. It closes on a second click, on Escape, on a click elsewhere or after you use a button.
- The player coordinates under the map are now in Blizzard's gold, a size larger and clear of the frame. The world map's coordinates match.

**Experience Bar**
- **Show Tooltip** (Action Bars > General, FlareUI XP Bar): turn off the tooltip on the bar.

## Changed
- **Five-Second Rule** is now off by default, on the player frame (Edit Mode) and on the Power and Mana resource bars. Turn it on in Edit Mode where you want it.
- **Radial Menu:** the dividers and the hub ring are now in FlareUI's bronze.
- **Performance:** FlareUI does far less work while you play.
  - Chat no longer runs its fading timers on every message (including every combat log line), and does nothing at all for them with Auto-Hide off.
  - Faded bars no longer do work every frame while nothing is fading.
  - Threat updates on the target and focus frames only re-colour the border.
  - Combo points on the target frame, the Combo Points bar and the nameplates only update when your combo points change, not on every energy tick.
  - The radial menu no longer rebuilds itself whenever any item is loaded by the game.
- More of FlareUI's text can now be translated.

## Fixed
- **Minimap:** Blizzard's round frame art could show under the square map after logging in with Rotate Minimap on.
- **Buffs / Debuffs:** an error in dungeons and raids (with Blizzard's addon restrictions active) while restyling the weapon enchant buttons. They now wait for the restrictions to lift.
- **Chat:** Forever's "Refreshing your world" notice is placed just above the chat again.
- **Tweaks:** Nameplate Combo Points could error on a target whose hostility the game keeps hidden.
- **Fake CM:** the Setup Mode switch no longer stays "on" after a reload while the bars are locked.

# FlareUI 1.5.1

A new look for the radial menu, new chat options and more for Sync Blizz UI.

## New

**Radial Menu**
- The radial now looks like Blizzard's ping wheel: a dark backdrop, a line between every two buttons, and the slice you point at lights up.
- It fades in and out like the ping wheel, with the buttons gliding out from the middle.
- **Button names:** the button you point at shows its name beside it. Long names go on two lines. Turn it off with **Show Button Names** (Radial Menu > Look).
- A button that holds another radial shows a row of dots under it, one per option, with the current one lit. Scroll the mouse wheel to change it.

**Chat** (Chat > Message Formatting, all off by default)
- **Level Before Names:** a player's level in parentheses before their name, in difficulty colours, like "(42) [Name]". Known for your group, guild, friends, /who results and players you have targeted or seen nearby.
- **Copy Line:** shift-click a message's timestamp to put that message in your chat box, ready to edit or send. Needs timestamps: Better Timestamps, or Blizzard's own.

**Sync Blizz UI**
- Now also copies the "Color Name by Class" boxes in the chat settings, Block Guild Invites, and your bags' settings (Assign To, Ignore This Bag, junk selling, and the backpack's sort setting).

## Changed
- **Chat:** Better Player Names, Better NPC Names, Short Channel Names and Better Timestamps now change Blizzard's own chat line instead of replacing it, so a formatted line keeps Blizzard's own player link and line data.
- **Chat:** Better Player Names now also colours names in numbered channels (Trade, General...), instance chat and whispers. Whispers keep their "whispers:" and "To" wording.
- **Chat:** Better Timestamps now applies to every chat message, not only player and NPC lines.

# FlareUI 1.5

The biggest update yet: party frames, resource bars, separate chat windows, and FlareUI can now be translated.

## New

**Party Frames** (Unit Frames > General > Frames > Party, off by default)
- Party frames in the unit frames' look, placed and set up in Edit Mode ("FlareUI Party Frames"). FlareUI makes no raid frames.
- Two styles, each with its own settings: **Classic** (larger frames, like the player frame) and **Raid Style** (compact frames with their auras inside).
- Auras follow Blizzard's raid frame rules: buffs, debuffs, dispellable debuffs with a coloured highlight, bigger boss debuffs, big defensives and private auras. They can sit inside the frame, beside it, above or below it.
- Cast bars, pet frames (only a frame with a pet makes room for it), leader, role, raid marker, ready check and status icons, each with its own size.
- **Sort by Role** (on): tank, healer, then damage. **Show Player**, power bar for **Healers Only**, and out-of-range fading.
- Edit Mode shows a sample party (warrior, priest, warlock with a pet, hunter with a pet, rogue) with sample auras.

**Resource Bars** (Unit Frames > General > Resource Bars, all off by default)
- Seven bars, each switched on by itself and placed in Edit Mode: **Health**, **Power**, **Mana**, **Combo Points**, **Main-Hand Swing**, **Off-Hand Swing** and **Ranged Swing**.
- **Mana** shows when mana is not your main power: a druid's mana in Bear and Cat Form.
- **Power** and **Mana** show the **Five-Second Rule** spark after a mana spell.
- **Combo Points:** segments in a flame red, or **Classic Combo Points** (round gems that light up with a shine).
- Swing timers turn red when the target is out of range.
- A bar that is on hides Blizzard's own (the Personal Resource Display, the swing timers).

**Chat**
- **Pop Out:** right-click a chat tab to give that window its own frame (a trade or spam window beside your main chat). Drag it by its tab or header, resize it from the corner. Its tab menu has **Dock** and **Lock Window**. The game remembers where it is.

**Unit Frames**
- **Target of Focus** frame (off by default).
- Frames with nothing to show in Edit Mode (pet, target of target, focus...) now show a sample there.

**Action Bars**
- **Auto-Paging** (General > Functionality): pick the bar that switches pages with your stance or form. Action Bar 1 by default, as Blizzard does.
- **Bar Scaling:** the **Possess Bar**.

**Visibility**
- **Hide Totem Bar.**

**Translations**
- FlareUI can now be translated on CurseForge: https://legacy.curseforge.com/wow/addons/flareui/localization. Text with no translation yet shows in English.

## Changed
- **Borders:** a new **FlareUI Thin**, slimmer, with corners that stay neat on thin bars. It is now the default for the pet, target of target and target of focus frames, every cast bar, the resource bars and the XP bar. The previous Thin is now **FlareUI Frames**, still the default for chat and the damage meter. If you picked the old Thin yourself somewhere, pick FlareUI Frames to get it back.
- **Unit frames, new default sizes and places** (only where you haven't moved or resized them): player and target 70 tall, focus 35, player cast bar 300 x 25 and higher up, target of target 100 x 25 under the target's cast bar.
- **Target frame combo points:** flame red (was teal), with thin black lines between the points.
- **Edit Mode:** a bar hidden by Visibility (stance bar, pet bar, totem bar) now stays hidden in Edit Mode too.

## Fixed
- **Move Any Frame:** a moved window no longer opens at Blizzard's spot and jumps to yours a moment later.
- **Move Any Frame:** the **Map & Quest Log** can be moved (it couldn't be dragged at all).
- **Pet action bar:** its button art was drawn full size.
- **Edit Mode settings:** changing a dropdown no longer scrolls the settings window back to the top.

# FlareUI 1.4.4

Quieter defaults: most quality-of-life extras now start off, FlareUI says less in chat, and a few small additions.

## Changed
- **Defaults:** these now start **off** (turn them on in the settings if you want them):
  - **Chat:** Extend Chat History, Save Chat History, Better NPC Names, Better Player Names, Short Channel Names.
  - **Tweaks:** Auto-Type DELETE, Hide Error Messages, Hide Party Title, Hide Contextual Tips, Hide Portrait Numbers, Sell Junk Automatically, Repair Automatically, Durability Warning, Faster Auto Loot, Train All Button, Max Camera Zoom, Faster Camera Zoom.
  - They switch off with this update even if you had them on: turn the ones you use back on.
- **Damage Meter:** the **Combat Timer** now starts on (it turns on with this update; switch it off in the Damage Meter settings if you prefer).
- **Tweaks:** with Max Camera Zoom, Faster Camera Zoom or Hide Contextual Tips off, FlareUI no longer resets Blizzard's own camera and tutorial settings. It only puts back what it changed itself. Hide Party Title and Hide Portrait Numbers work the same way.
- **Less chat:** FlareUI no longer posts a line when you switch Gamepad mode, when Move Any Frame pauses in Gamepad mode, after Sync Blizz UI, after restoring your Edit Mode layout, or when a radial closes itself.
- **Buffs / Debuffs:** the Gamepad mode note moved to a **Warning** section at the bottom of the settings.

## New
- **Radial Menu:** a **Social** panel button (the Friends window).
- **Radial Menu:** deleting a radial now asks first.

# FlareUI 1.4.3

A new XP bar, and fixes for Lua errors around Edit Mode layouts and party frames.

## Fixed
- **Party frames / Edit Mode:** with **Hide Pet Bar** on, closing Edit Mode or switching layouts threw Lua errors from the party frames (CompactUnitFrame.lua). Hiding the pet bar in Edit Mode moved whatever was snapped to it. It no longer does. The raid manager hide had the same problem and is fixed too.
- **Remember Layout per Mode:** switching the Gamepad UI on or off now asks **Restore your ... Edit Mode layout?** after the reload, instead of switching by itself. FlareUI switching the layout on its own caused the same party frame errors. Restore, Enter or the controller's A button switches the layout and closes the prompt.
- **Remember Layout per Mode:** the prompt sometimes didn't show after turning the Gamepad UI on. FlareUI saved Blizzard's fallback layout as your gamepad layout during the switch. If you saw this, pick your gamepad layout once in Edit Mode.
- **Sync Blizz UI:** the copied Edit Mode layout is now switched by the **Reload Now** button, not by FlareUI on its own (the same party frame errors). It is only copied for the input mode you're in, and not while Remember Layout per Mode is on.
- **Lua errors from Blizzard_MawBuffs ("secret" auras)** after FlareUI scaled the minimap or the quest tracker, or hid Blizzard frames. FlareUI now scales and hides Edit Mode frames without running Edit Mode's own code.
- FlareUI's prompts no longer show controller buttons while you play with keyboard and mouse.

## New
- **FlareUI XP Bar** (Action Bars > General > XP / Honor Bars > Style): one bar with XP and your watched reputation (or honor) side by side, placed and sized in Edit Mode. At max level it shows reputation and honor. **Show Text** (on mouseover or always) and **Text Format** options. **Blizzard Bars** keeps the previous reskin of Blizzard's bars. Visibility fades it as the XP bar. If you had **Reskin** on, you now get the FlareUI XP Bar: pick **Blizzard Bars** for the previous look.

## Changed
- **Buffs / Debuffs:** a note on the General tab explains that the module does not work in Gamepad mode. Blizzard keeps its own buff frame there for controller navigation.
- **World refresh:** FlareUI no longer touches Blizzard's world refresh notice (it no longer moves it above the chat or recolours its border). Blizzard's own notice is back.

# FlareUI 1.4.2

The cooldown swipe is back on your buffs and debuffs, unit frames get FlareUI's aura icons, and a round of settings clean-up.

## Fixed
- **Buffs / Debuffs:** the cooldown swipe (Border or Icon) didn't show on real auras since 1.4, only on the Edit Mode samples. It's back.
- **Buffs / Debuffs:** with Square icons, the Icon swipe now stays inside the icon's cut corners instead of darkening past them.
- **Settings:** some sliders showed grey boxes instead of bronze ones, depending on the tab you opened and where you hovered. They're all bronze now.

## New

**Unit Frames**
- The auras on your unit frames now use FlareUI's aura icons: the bronze bevel or round ring, debuffs coloured by type, and the cooldown swipe. Whether the Buffs / Debuffs module is on or not.
- Each frame sets its own aura **Shape**, **Cooldown Swipe** and **Timer** in Edit Mode (Auras section). Timer has a **No Timer** choice, which replaces the Aura Timers checkbox (if you had it off, your auras start on No Timer).
- **Fonts > Aura Text:** the font of the aura timers and stacks. Its size follows each frame's Aura Size.
- **Class Color** checkbox per frame (Edit Mode > Look), on by default. Off, players' health bars are the classic health green. NPCs keep their friendly / hostile colours.
- The Edit Mode settings fold into sections you open with a click: Frame, Look, Absorbs, Cast Bar, Auras and Icons, with the section names in gold.

**Chat**
- **Edit Box Position:** below the chat frame, above it, or inside it (as before). It replaces the Edit Box X / Y Offset sliders.

**Buffs / Debuffs**
- Timer: two more choices, **Middle of the Icon** and **No Timer**.

**Tooltips**
- **Fonts** tab: Title and Content font, size, outline and shadow. They start at Blizzard's tooltip fonts.

## Changed
- **Bar textures:** FlareUI now ships two, **FlareUI Flat** and **FlareUI Striped** (absorbs). Armory, Charcoal, Minimalist and Smooth are gone; every bar that used Armory by default is now FlareUI Flat, and a bar set to one of the removed textures switches to FlareUI Flat.
- **Damage Meter:** the bars keep Blizzard's own texture (the Bar Texture option is gone). How to Use now starts by reminding you that the meter needs **Enable Damage Meter** on in Blizzard's Settings > Advanced Options.
- **Unit Frames:** Value + Percent health reads `12.4K | 87%`. The Player Cast Bar's Texture setting is now called Bar Texture.
- **Buffs / Debuffs:** new defaults are Round icons with the Icon swipe and the timer under the icon. The Border swipe darkens more (70%), so it's easier to see. Settings you picked yourself stay.
- **Tweaks:** the page is split into two tabs, **Interface** and **Gameplay**. Remember Layout per Mode and Offer Gamepad Mode moved to Interface > Windows & Settings.
- **Fonts:** every font setting now has Enable Shadow on by default.
- **Tab order:** Action Bars is General / Visibility / Fonts / Bar Scaling / Fake CM; Tooltips is General / Visibility / Fonts / Anchor.
- **Edit Mode:** no divider line between Reset To Default and Reset To Default Position.

# FlareUI 1.4.1

Your requests: totem timers, movable loot rolls and toasts, smoother fades, and threat in combat.

## New
- **Totem timers:** with FlareUI's player frame on, shamans lost Blizzard's totem timers, which hang off the player frame FlareUI replaces. They are back on their own Edit Mode frame, FlareUI Totems, under the player frame. They are Blizzard's own timers, so right-click a totem to dismiss it as before. In Edit Mode, set the frame's Size and Totems per Row (4 for one row, 2 for a 2 x 2 grid); four sample totems show while you place it.
- **Loot rolls and toasts you can move:** Need / Greed / Pass frames and Blizzard's pop-up toasts (new recipe learned, achievements, loot won) no longer sit stuck above the action bars. Place them in Edit Mode with FlareUI Loot Rolls and FlareUI Toasts, each with a sample to see while you place it. Toasts no longer climb over the loot rolls either. Part of Tweaks: Windows & Settings > Move Loot Rolls & Toasts.
- **Damage Meter:** Features > Threat View in Combat. The meter switches to the Threat tab when combat starts and back to Blizzard's view when it ends. Off by default.

## Fixed
- Action bar fading: fades in and out were choppy, about ten steps a second. They now run smoothly at your frame rate.

## Changed
- Unit Frames: the pet frame is 120 wide again by default, with its right edge lined up with the player frame's. This only changes a size and position you never set yourself.

# FlareUI 1.4

A new module for your buffs and debuffs, and FlareUI's own frame borders.

## New: Buffs / Debuffs

Your buffs and debuffs in FlareUI's style, in place of Blizzard's buff frame. Switch it on in General > Buffs / Debuffs.

- Two frames you place in Edit Mode, FlareUI Buffs and FlareUI Debuffs, each with its own icon size, icons per row, maximum icons, spacing, and growth direction (left or right, wrapping up or down).
- In Edit Mode, every slot fills with sample icons, so you can see how far each frame can grow before you place it.
- Square icons in a bronze bevel with 45° corners, or round icons in the spellbook's passive ring.
- Debuff borders take the colour of their type: Magic, Curse, Disease, Poison and the rest.
- Cooldown swipe, three ways: a sweep over the icon with a bright edge, the border itself running out around the icon, or none.
- The timer under the icon or along its bottom edge; stacks in the top right corner.
- Weapon enchants (poisons, oils) show before your buffs.
- Right-click a buff or a weapon enchant to cancel it.
- Boss debuffs that Blizzard keeps private still show, just past the debuff frame.
- Works in dungeons and in combat: Blizzard draws the auras into FlareUI's frames.
- In Gamepad mode Blizzard's own buff frame stays, as part of its controller navigation.

## New: FlareUI Borders

- Two new borders in every border dropdown: FlareUI Thick and FlareUI Thin, a bronze bevel lit from above with soft 45° corners.
- They are the new defaults: Thin for the chat, the damage meter and the XP bar, Thick for the unit frames and cast bars. A border you picked yourself stays as it is.

## Fixed
- XP bar: Blizzard's grey frame art could come back inside FlareUI's border.

## Changed
- Chat > How to Use is shorter.

# FlareUI 1.3.1

Fixes from your reports, and a handful of new options.

## Fixed
- Chat: clicking a quest or item link on the last line of the chat opened the chat box instead of the link.
- Chat: shift-clicking a player's name invited them to your group. That's now an option, off by default: Chat > Improvements > Shift-Click to Invite.
- Minimap: a Rotate Minimap setting switched on before FlareUI kept the map rotating with a round border, and the option is hidden. FlareUI now keeps the map still; turn the Minimap module off and your own setting comes back.
- Tooltips: the defaults now match Blizzard's. Tooltips sit in the bottom-right corner, and ability tooltips on the action bars and unit tooltips on the frames show again, so hovering a group member shows their location. This only changes settings you never touched.

## New

**Unit Frames**
- Move, size and switch off each frame's icons in Edit Mode: pick one in the new Icon dropdown, then set Show Icon, Icon X, Icon Y and Icon Scale. The picked icon shows on the frame while Edit Mode is open. These replace the Elements switches in the settings window; an icon you had switched off there stays off.
- Aura Timers (Edit Mode, Auras): switch off the countdown numbers on buffs and debuffs.

**Chat**
- Drag the header buttons to change their order, the way you drag tabs.

**Damage Meter**
- Ready Check and Countdown buttons in the header. Ready Check shows when you lead or assist a group; Countdown shows while you're in a group, starts a 10-second pull timer and cancels it on a right-click. Each can be switched off in Damage Meter > Features.

**Minimap**
- Edit Mode's Size slider is back: it scales the whole minimap, frame, header and all.

## Changed
- The quest "!" on the target frame sits in the middle of the health bar, under the raid marker.
- Damage Meter: Match Chat Frame Size needs the Chat module (it matches FlareUI's chat frame only).

# FlareUI 1.3

**Grab your controller!** FlareUI now works with Blizzard's Gamepad UI on WoW: Forever, from the first button press to the last setting. Pick up a controller and FlareUI offers to switch; put it down and `/fui pad` brings the keyboard and mouse back.

## New: Controller Support

**Switching modes**
- Press any button on a controller while playing with keyboard and mouse, and FlareUI asks whether to switch to Gamepad mode (Blizzard's Gamepad UI). Answer with A or B, or click. It asks once a session and never in combat; turn it off with Tweaks > Convenience > Offer Gamepad Mode.
- `/fui pad` switches either way, at any time.
- Chat tells you which mode you are in after every switch, whether FlareUI or Blizzard's own setting made it.
- Remember Layout per Mode (Tweaks > Convenience, on by default): switching the Gamepad UI on or off resets Edit Mode to its default layout. FlareUI now brings back the layout you last used in each mode.

**Radial Menu**
- Press R3 to open your main radial, aim with the right stick, and press R3 again to use the button you point at. B closes it. The camera holds still while you aim, and the ping menu moves to L3. Turn it on with Radial Menu > Controller > Enable Controller Support.
- The radial editor works with the controller too: move with the D-pad, switch categories with the shoulder buttons, X removes a button, Y picks one up to reorder it.
- New radial buttons: FlareUI Settings, and Toggle Threat Meter (flips the Damage Meter between its own view and the threat view).

**Settings**
- The whole FlareUI settings window works with the controller. The D-pad moves between options and A uses them. Sliders and dropdowns are grabbed with A and changed with the D-pad. LB/RB switch tabs, LT/RT switch sections and B closes. Button icons show where each one leads.
- Open them with `/fui`, the FlareUI Settings radial button, or a key of your choice (Blizzard's Keybindings > AddOns > FlareUI > Open Settings).

**Chat**
- The D-pad stays on the edit box instead of wandering into FlareUI's chat buttons.
- Y opens the tab settings on every chat tab, and LB/RB icons show how to switch tabs.
- The chat uses the IM style in Gamepad mode: the Classic style hangs the game when a slash command is typed. Your own style comes back in keyboard and mouse mode.

**Unit Frames and more**
- Y opens the target menu with FlareUI's unit frames, just as it does with Blizzard's.
- Blizzard's gamepad cast bar steps aside when FlareUI's player cast bar is on.
- Tooltips show in Gamepad mode, in Blizzard's default place (there is no cursor to follow there). Your placement settings come back with the mouse.

## New
- FlareUI's own dialogs replace Blizzard's popups, and **Reload Now finally reloads**: on Forever it never did, it only told you to type /reload.
- A welcome line in chat at login.

**Chat**
- Header Buttons options (Chat > General): show or hide Social, Chat Channels, Chat Menu and Volume. The buttons line up from the right.

**Damage Meter**
- Match Chat Frame Size: the meter takes the size of your chat frame.
- Threat Toggle Keybind: one key flips the meter between its own view and the threat view.

**Unit Frames**
- Classic Combo Points moved to the target frame's Edit Mode settings and now sit at the frame's bottom-right.

## Changed
- Combo points (Classic Combo and nameplate combo points) use Blizzard's high-resolution red gems with bronze rims and a shine when they fill.
- Nameplate tweaks stand aside when a nameplate addon such as Platynator is running.
- Tweaks: the Hide options are laid out in rows of three.
- Chat and Damage Meter background opacity now default to 60%.
- Damage Meter > Features: Combat Timer comes first, then Threat Meter Tab.

## Fixed
- A Lua error from the objective tracker after a reload in combat.
- The 1.2.1 notes said FlareUI picked up new combo point art from that patch. The art was not in the game files; this release brings the new look instead.

# FlareUI 1.2.1

Fix for WoW: Forever build 1.60.1.70170.

## Fixed
- A Lua error at login with the Tweaks module on. It also stopped Auto-Type DELETE, the Train All button and hiding the quest tracker in boss fights from working.

## Changed
- Tweaks: the World Refresh Dialog option is gone. Since this patch the game no longer opens that dialog by itself; it only opens when you click the refresh countdown above the chat.
- The new combo point art from this patch shows on FlareUI's nameplate combo points and Classic Combo too.

# FlareUI 1.2

## New

**Unit Frames**
- Portraits on the player, target and focus frames: pick None, 3D or Class Icon in each frame's Edit Mode settings. The portrait sits in a square on the frame's left, or on the right of a mirrored frame. On mirrored frames the 3D portrait turns to face the bars; class icons keep their orientation, and NPCs show the 3D portrait.

**Radial Menu**
- Extra keybinds: up to 5 more keys per character, each opening a radial of its own (Radial Menu settings > Extra Keybind). They work like the main keybind: hold, aim, release, in combat too. A key can only open one radial; giving it to another row takes it from the old one.

## Fixed
- Sync Blizz UI: chat tab message filters and channels were copied but only showed after a second reload. Sync now offers its reload when they change.
- Damage Meter: a threat row could show the previous player's icon flipped or cropped.

# FlareUI 1.1.2

Urgent fixes for dungeons, raids and battlegrounds.

## Fixed
- Tooltips: hovering any unit inside an instance (or in a PvP match) threw a Lua error. Blizzard hides the unit from addons there; FlareUI now finds it another way, or leaves the tooltip as Blizzard drew it.
- Nameplate quest tags no longer error on nameplates whose unit is hidden from addons.
- Unit frames: the quest icon never showed for normal quest mobs, only for the rare "quest bosses". It now shows when your target or focus is part of one of your active quests.

## Changed
- Quest icons are a simple yellow "!" instead of the shield, both on nameplates (Tweaks > Tag Quest Objectives) and on the target and focus frames, where it sits on the right edge. The unit frame element is now called Quest Icon.
- Chat: the Message Formatting options say they work outside instances only, where Blizzard hides chat messages from addons.

# FlareUI 1.1.1

## New

**Radial Menu**
- Radial macros: `/click FUIRadial <RadialName>` (the name without spaces, any case) opens any radial at your cursor, so a radial can sit on an action bar, use macro conditionals ([pet], [mod:shift]...) or be opened by a button of another radial. A macro radial stays open: click a button to use it, or press the macro again to use the button you point at; right-click or Escape closes it. Works in combat.
- Radial Macros group in the Radial Menu settings: how it works, and each radial's macro line to copy.

## Fixed
- Tooltips settings: the Show with Shift option had the wrong width.
- Unit frame auras: the stack count and timer could sit under a debuff's dispel border.

# FlareUI 1.1

A big one: new features in almost every module.

## New

**Unit Frames**
- Five-second-rule spark: after you cast a spell that costs mana, a spark crosses your mana bar for the five seconds your spirit regen is paused.
- Pet happiness: your hunter pet's happy / content / unhappy face in the middle of the pet frame, with Blizzard's tooltip (damage, loyalty, diet). Switch it off in the pet frame's Edit Mode settings (Happiness).

**Damage Meter**
- Threat tab: a second view beside the meter's title, like the chat tabs. It lists your group's threat on your target, highest first, with how close each player is to pulling aggro. It follows the meter's bar style, spec icons and class colours. Option: Threat Meter Tab.
- Right-click the meter's title to choose what it tracks (Damage Done, DPS, Healing...).
- Combat Timer option: how long the fight has lasted, in the title row.
- How to Use tips in the Damage Meter settings.

**Chat**
- Short Channel Names (on by default): [2. Trade - City] becomes [2], [Guild] becomes [G].
- No Bubbles in Instances: chat bubbles off inside dungeons, raids and battlegrounds, back to your own setting outside.
- How to Use tips in Chat > General.

**Tweaks**
- Auto-Type DELETE: fills in DELETE when you destroy a rare or better item.
- Train All Button at class and profession trainers.
- Hide the Quest Tracker in Boss Fights.
- New Convenience group (Faster Auto Loot moved there); Camera & Loot is now Camera.

**Tooltips**
- Item IDs and Spell IDs options.

**Minimap**
- FPS & Latency on Clock: your framerate and latency in the clock's tooltip.

**Radial Menu**
- Cooldown swipes on the buttons, and unusable buttons dimmed (blue when you are out of mana).

## Changed
- Unit frame icons: the leader crown sits at the top-left corner and is a little bigger; the quest icon on the target frame sits on the top edge and is bigger; the raid marker sits in the middle of the health bar on every frame, at half its height. The pet frame no longer shows a raid marker.
- The pet frame is wider by default (160), its right edge in line with the player frame.
- The Blizzard Art Border option is gone.
- The Modules page no longer has About FlareUI and Inspired by (the credits are on the CurseForge page).

## Fixed
- A unit's health bar could show up on FlareUI's own tooltips, such as the chat volume button's.
- Minimap clock: the whole clock answers the mouse (only a small spot in its middle did), and its tooltip shows at once.
