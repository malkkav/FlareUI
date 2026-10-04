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
