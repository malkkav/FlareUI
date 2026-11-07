# FlareUI 3.0.9

Quests that accept and turn themselves in, swing timers only when you're swinging, and FlareUI in Brazilian Portuguese.

## New
- Quality of Life: **Auto accept quests** and **Auto turn-in quests**, both off by default. Hold Shift to stop them for a moment. Repeatable quests, a choice of rewards, a gold cost and PvP quests always wait for you, and grey quests aren't auto-accepted. They do nothing in the Gamepad UI.
- Quality of Life: **Gamepad mode prompt**, on by default. Turn it off to stop FlareUI asking about Blizzard's Gamepad UI when you press a controller button, handy for ConsolePort. `/fui pad` still switches.
- Resource Bars: **Only When In Use** in the Show dropdown of the swing timers. A bar appears when its weapon swings, so there's no off-hand or ranged bar unless you're using one.
- Brazilian Portuguese translation, thanks to paulovnas.

## Changed
- Swing timers now default to Only When In Use. If yours were on Combat, they probably changed too: pick Combat in each bar's Show dropdown in Edit Mode to go back.
- Chat: an unread whisper tab now shows in your whisper colour instead of red, and Battle.net whispers in their own colour.

## Fixed
- Chat: closing a tab scrolls the tabs back to the first one.
- Minimap: the day/night button goes back to its corner if something moves it. Players with EnhanceQoL reported it stuck over the calendar and clock.
- Move Any Frame: a group finder page still detached from its window now snaps back when it opens, even with Move Any Frame off.

# FlareUI 3.0.8

Cleaner portraits on faded frames, Forever Style draws Blizzard's whole ring, and windows are easier to move and close.

**Restart the game fully after updating** (not just /reload): this version adds new files.

## Changed
- FlareUI Style party, raid and boss frames: the selected frame now gets a brighter border instead of white lines.
- Forever Style: the dispel glow on the name box is stronger, in Edit Mode's preview too.
- Move Any Frame: a window starts moving as soon as you drag its title bar, with no dead zone.

## Fixed
- FlareUI Style: on a faded or out of range frame, the end of the bars no longer shows through the portrait.
- FlareUI and Forever Style: the ring and portrait no longer show through the level disc on a faded frame.
- Forever Style: the portrait ring is whole, with its full shadow, and joins the frame in a straight line.
- Target, focus, party and raid frames: Hide Buffs hid every buff on a group member too far away to see, because the game sends no durations at that distance. It now pauses for them. With Only My Buffs on, party and raid frames can still show none at that distance.
- Move Any Frame: the close button works across its whole area on the AddOns window and others without a portrait.
- Combat text no longer draws behind the swing timers and other Resource Bars.

# FlareUI 3.0.7

Fixes a Lua error from 3.0.6 on cast bars.

## Fixed
- Cast bars: since 3.0.6, enemy casts in combat could flood you with Lua errors from Backdrop.lua, which could also appear when you opened Edit Mode.

# FlareUI 3.0.6

The group finder stays in one piece when you move it, and crafting shows the right icon on your cast bar.

## Fixed
- Move Any Frame: moving or scaling the Looking for Group window pulled its pages away from the window and its tabs, and it stayed that way. It now moves and scales as one window. If yours came apart, it goes back together and returns to its default spot.
- Cast bars: crafting showed a question mark or the wrong icon. It now shows the item you're making.

# FlareUI 3.0.5

Fewer options on your frames: four that we couldn't confirm work properly on Forever are gone.

## Removed
- Party, raid and main tank frames: **Big Defensive**. It showed everyday buffs such as paladin seals and herb gathering in the middle of the frame.
- Party, raid and main tank frames: **Bigger Boss Debuffs**. Boss debuffs now show at the same size as the others.
- Party, raid and main tank frames, player frame: **Focus Boss Debuffs**. Every debuff your other settings allow now shows in boss fights too.
- Party and raid frames: **Missing Buffs**.

# FlareUI 3.0.4

See everyone's buffs on party and raid frames, DoesItDie on your target and focus frames, and new tooltip options.

**Restart the game fully after updating** (not just /reload): this version adds a new file.

## New
- Unit frames: **DoesItDie** now works on FlareUI's target and focus frames, with no setup: a mark for the damage your DoTs still have left, and a skull when that's enough to kill. Its own marker, skull and focus settings still apply.
- Tooltips: **Show guild name** (on by default), **Show guild ranks** and **Hide faction**. Blizzard can hide tooltip text in instances and some fights, and these options can't change those tooltips.
- Edit Mode: clicking or dragging a portrait ring, level disc, attached cast bar, party pet or party target now selects its frame.

## Changed
- Party and raid frames, main tanks: **Only My Buffs** is on by default, and turning it off now really shows everyone's buffs. Before, off still hid most of them. Raid frames only hold three icons, so **Hide Buffs** on a time limit helps there.
- Boss frames: every buff on the boss now shows, apart from what **Hide Buffs** leaves out.
- Buffs and debuffs: timers read s, m, h and d in every language, in the Buffs & Debuffs frames and on unit frames.

## Fixed
- Boss frames: **Hide Buffs** did nothing.
- Cinematic: FlareUI's player cast bar stays up between fights, so hearthing, gathering and quest objects show their cast. Cinematic's Cast bar row no longer hides it.

# FlareUI 3.0.3

A NEW tag now points out recently added options.

## New
- Settings: new options show a **NEW** tag, and so do their tab and page. Once you've opened a page and moved on, its tags are gone for good. New installs don't get them.
- Options > AddOns: FlareUI's row shows a **NEW** tag while any of its pages still has one. Not in the Gamepad UI.

## Changed
- Action Bars: **Button art** is now **Show button art**.
- Quest Tracker: **Collapse completed quests** is now **Collapse completed**.

# FlareUI 3.0.2

Better proc glows on your action bars.

## New
- Proc Glow: **Victory Rush** now glows while you can use it, and goes dark during its cooldown.

## Fixed
- Proc Glow: Revenge goes dark after you use it, instead of staying lit for the rest of its window. It comes back when you next block, dodge or parry. Blizzard can hide your casts in dungeons and raids, so there it may stay lit as before.
- Proc Glow: a glow should no longer flicker or go out when you press another ability during the global cooldown.
- Proc Glow: procs already active when you reload now glow right away, and a glow that got stuck clears the next time you change zones.
- Proc Glow: reaction abilities are now checked by class, so a spell with the same name on another class no longer glows by mistake.
- Performance: Proc Glow does less work on classes with no reaction abilities.

# FlareUI 3.0.1

Simpler action bar paging, class colours for each frame, and more ways to read your XP.

## New
- Unit frames: **Class Colours** is now in each frame's Edit Mode dialog, under Look, on the player, target, focus, target of target, target of focus, party and raid frames. It's on by default. If you had the old option off, every frame starts off. The Resource Bars' health bar follows the player frame.
- XP bar: **XP Bar Numbers** in the Action Bars settings shows current / max, a percentage, both, or what's left to go. Reputation and honor use it too.
- Action Bars: **No Auto-Paging for Stances** keeps a warrior's Action Bar 1 on its page when changing stance. It's off by default, but stays on if you'd already stopped stance paging in 3.0.

## Changed
- Action Bars: **Allow Auto-paging** is now one toggle, **Auto-Paging for Stealth**, for rogues. Druid forms and warrior stances are back to Blizzard's own paging, and bars 2 to 8 no longer page. If you'd set it to No Auto-Paging, the new toggle starts off.
- Quest Tracker: shift-click now tracks and untracks quests. Ctrl-click sets the focus.
- Unit Frames settings: **Class colours** moved to Edit Mode.
- Action Bars settings: **Fade Options** is gone from the page. Fading is still in each bar's Edit Mode dialog.

## Fixed
- Action Bars: reports of druid form paging not working since 3.0 should be fixed by the paging change above.

# FlareUI 3.0

Portrait versions of your target of target and focus target frames, smooth bars, a much better Quest Tracker, and animations where they count. This one's big, so here's the lot.

## New
- Unit frames: **Target of Target** and **Target of Focus** now have small portrait versions in FlareUI and Forever Style, like the pet. **Simple "Target Of"** in the Unit Frames settings keeps the plain frames, and the two keep separate settings and positions.
- Unit frames, Resource Bars: **Smooth Bar Animations** in Edit Mode makes health and power glide to their new value. It's off by default, and sits under Background Opacity on every frame that has it. Target of Target and Target of Focus don't have it.
- Pet frames: **Auras** and **Aura Ordering** in Edit Mode, in every style. Buffs and Debuffs are off by default.
- Target, focus and boss frames: **Hide Buffs** in Edit Mode, set to Permanent by default, which is how they already behaved.
- Resource Bars: **Background Opacity** in Edit Mode.
- Buffs & Debuffs: **Arrival animation** fades new icons in as they drop into place. It's off by default.
- Buffs & Debuffs: opening the settings page shows sample icons, so you can see your Timer, Icon Shape and Swipe choices as you change them.
- Quest Tracker: quests slide in when accepted and out when turned in, the rest make room, and a finished objective gets a soft sheen.
- Quest Tracker: timed quests show a countdown that goes from green to yellow, orange and red, even on a collapsed quest, and they stay listed when you leave their zone.
- Quest Tracker: completed quests show their own text, like where to turn them in. Auto-complete quests finish when you click them.
- Quest Tracker: scenario objectives show above your quests, a line shows the gold a quest still needs, and your focused quest shows its next waypoint when the game gives one.
- Quest Tracker: new options in the settings:
  - **Collapse completed quests**
  - **Hide finished objectives**
  - **Hide quest level**
  - **Focus buttons**
  - **Voice buttons**, with the Spoken addon
- Quest Tracker: **By progress** in Objective Sorting, and **Quest Spacing** in Edit Mode.
- Quest Tracker: **Show on Map** and **Link to Chat** in the right-click menu, and shift-click a zone heading to fold all its quests.

## Changed
- Forever Style: **Background Opacity** is gone from unit, party and boss frames. The frame's own art is the background there, and the slider only painted over it.
- Forever Style: Target of Target and Target of Focus use smaller text.
- Action Bars, Unit Frames: the banner pointing to Edit Mode is shorter and harder to miss.
- Buffs: the default position moved down by one pixel. Only frames you haven't moved follow it.
- Fake Cooldown Manager: the setup button and its right-click hint only show as available when a bar uses it.

## Fixed
- Action Bars: **No Auto-Paging** now really stops Action Bar 1 changing page with a warrior's stance. Picking another bar for Auto-Paging does the same.
- Quest Tracker: quest levels use the same colours as the quest log.
- Quest Tracker: failed quests now say so.
- Quest Tracker: opening a quest from the tracker in combat or in the Gamepad UI is now refused with a message. It could cause errors or break controller bindings.
- Buffs & Debuffs: sample timers now show in Edit Mode.
- Party, raid and boss frames: possible errors from hidden names in instances.
- Quality of Life: Sync Blizz UI could fail to save your chat windows.
- The prompt to reload after copying interface settings now tells you how if you answer it in combat.
- Performance: less work in raids, mainly on party and raid frames, roster changes, threat on hidden frames, swing timers, and big guilds with Level Before Names on.
- A smaller download.

# FlareUI 2.10.0

A setup tour for new players, and a mana bar for druids in Bear and Cat Form.

## New
- A **setup tour** now greets new players. It shows what each part of FlareUI does, lets you turn each one on and pick your unit frame style, and explains where the options live. Nothing changes until you click **Reload and finish** on the last page, and you can skip it from the first page.
- About: a **Start Tour** button runs the tour again, and so does `/fui tour`.
- Player frame: **Mana on Shapeshift** in Edit Mode shows a thin mana bar under the power bar when a druid is in a form that doesn't use mana. It's off by default, and isn't available in Forever Style.

## Fixed
- Chat: voice chat's "who's speaking" names no longer sit on top of the mute buttons or flash to the left when someone stops talking. They stay above the chat's left edge. Other alerts that share that spot follow the same stack.

# FlareUI 2.9.0

The Combat Log's filter buttons are back, nameplates can hide names, and voice chat no longer sits on top of your chat.

## New
- Chat: the Combat Log's filter buttons now show in a small bar at the top of its window, with the log text below it. They were hidden before.
- Quality of Life: **Hide Names** in the Nameplates section hides unit names on Blizzard's nameplates. It's off by default. Friendly players shown by name only keep their names.

## Changed
- FlareUI palette: mana bars are a brighter, more saturated blue, so they're easier to tell from shaman health bars.
- Chat: voice chat's mute and deafen buttons and its "who's speaking" names now sit above the chat window, and the names no longer jump from side to side. Other alerts that share that spot, like voice channel prompts and Delves toasts, move above the chat too.

## Fixed
- Chat: clicking the Combat Log tab no longer makes the whole window shorter.
- Edit Mode: clicking a chat tab no longer makes the chat's selection box and size options disappear. The tab stays put while Edit Mode is open, and docked tabs all share the main window's size.

# FlareUI 2.8.1

A text option for your power bars, and a clear message if FlareUI doesn't load properly.

## New
- Resource Bars: the power and druid mana bars have a **Text** option in Edit Mode, to show the value or nothing.

## Fixed
- If FlareUI's files don't load completely, it now says so in chat and tells you what to do, and `/fui` shows the same message. Before, you'd only get a line about a missing library, and `/fui` did nothing. If you see this, restart the game, and reinstall FlareUI if it keeps happening.

# FlareUI 2.8.0

Your fonts work again, shaman and rogue health bars stand out from their power bars, and Edit Mode shows where a frame will land.

## New
- Chat: **Increase line height** in Tweaks adds a little space between chat lines. It's off by default.
- Edit Mode: while you drag a FlareUI frame, a ghost shows where it will land. Snapping needs Snap to Elements on, and the grid counts while Show Grid is on.

## Changed
- FlareUI palette: shaman health bars are a deeper blue and rogue health bars a deeper yellow, so they're easier to tell from mana and energy. Names, tooltips and the Blizzard palette keep the usual class colours.
- Edit Mode: the Frames checkboxes for FlareUI's frames turn on once when a frame first runs, this update included, so it's there when you open Edit Mode. The tick may appear after your next reload. Untick one and it stays unticked.
- Resource Bars: bars only snap to each other when Snap to Elements is on.

## Fixed
- Fonts: most fonts showed as Friz Quadrata. Any font you pick now loads, and text switches to it as soon as the game has it.
- Fonts: on non-English clients, text falls back to the game's own font for your language. FlareUI's fonts are now listed on Russian clients too. Fira Condensed and Roboto Condensed have Cyrillic letters; the other three don't.
- Addon button drawer: minimap buttons with no frame name now go in the drawer, such as Forever++'s.

# FlareUI 2.7.0

More control over how your bars, XP bar and minimap fade, and a sign pointing at the options that were there all along.

## New
- Edit Mode: yes, FlareUI has more options. No, they didn't go anywhere. They've been in Edit Mode this whole time, behind the buttons that say Edit, which take you right to them. Since those buttons turned out to be a little too subtle, the Unit Frames and Action Bars pages now have a banner saying so, with an **Open Edit Mode** button. Edit Mode itself now tells you to click a FlareUI frame the first time you open it. You've got this.
- Action bars, XP bar: each one now has its own **Fade Speed** and **Min Alpha** in Edit Mode, so a bar can fade to see-through instead of disappearing.
- Fade groups: **Fade group** is now the top option, and a group shares its Show Condition, Fade Speed and Min Alpha. Pick a group to see what's set for it. A change from any bar in the group applies to all of them.
- Minimap: it can now fade too, with Show Condition and Fade Speed in Edit Mode. It fades on its own, all the way out, because the game won't let addons fade the player arrow or quest marks.
- Party frames: your own frame in the party now shows the Five-Second Rule spark when the player frame has it on.

## Changed
- Fade Player and Pet: now one percentage, below Colour Palette, choosing how far the frames fade. 100% is no fading. If you were already fading, it shows 0%, the same as before.
- Action bars: Fade Speed moved from the settings page to each bar in Edit Mode. Your old speed stays until you change it.
- Edit Mode: bar, XP bar and minimap options now sit under a **Visibility** title.

## Removed
- Minimap: Map Size is gone, as it didn't work well. The map goes back to its default size. Use Edit Mode's Scale to resize the whole minimap.

# FlareUI 2.6.2

A fix for errors when changing fonts.

## Fixed
- Fonts: picking a font that won't load no longer causes errors, as it did on the Buffs & Debuffs page. That text uses Friz Quadrata instead, in every module.

# FlareUI 2.6.1

A fix for the round minimap showing inside the square one.

## Fixed
- Minimap: Forever's round map frame no longer shows inside the square minimap when another addon tints it, as BetterBlizzFrames does at every login.

# FlareUI 2.6.0

Pet frames in your frame style, portraits you can click, and the option to hide your player frame while in a party.

## New
- Pet frame: in FlareUI Style and Forever Style the pet frame now follows your style, as a small version of your player frame. Your old pet frame settings are kept: turn on **Simple Pet Frame** in Unit Frames > Look to go back to the plain frame. Addon Style keeps the plain frame.
- Party frames: **Hide Player Frame while in party**, below Show Player in Edit Mode. Your player and pet frames hide while you're in a party, and come back solo and in a raid. Your frame in the party has the same right-click menu.

## Changed
- Unit Frames settings: every option in this section now applies to all styles, including Fade Player and Pet, colours, names, auras and fonts. The values from the style you're using now become the ones used everywhere.
- Unit Frames settings: Full Player Names now sits above Class Colours.
- Party and boss frames: the default Spacing is 14 in every style. Spacing you already have stays as it is.
- FlareUI Totems: new default positions, sizes and totems per row in FlareUI Style and Forever Style. Totems you've already set up stay as they are.

## Fixed
- Portraits and level discs in FlareUI Style and Forever Style now work like the rest of the frame: click to select, right-click for the menu, hover for the tooltip, and click casting and pings.
- Minimap: a problem elsewhere during startup can no longer leave a round map inside the square frame.

# FlareUI 2.5.4

A clean edge for the minimap.

## Fixed
- Minimap: the map no longer pokes out past the border art at its right-hand corners.

# FlareUI 2.5.3

A small polish patch for Hide Micro Menu, the hover highlight and Forever Style.

## Changed
- Unit, party, raid and boss frames: the hover highlight is softer.
- Forever Style: the FlareUI Totems frame's default position is one pixel lower.
- FlareUI now shows under the User Interface category in the game's addon list.

## Fixed
- Hide Micro Menu: flashing micro button alerts and their tips, such as "unopened collectibles", no longer show while the menu is hidden.
- Forever Style: the name box's glow now fills the box at any frame width.

# FlareUI 2.5.2

A big launch-day cleanup: dozens of fixes across every module, and FlareUI now gives way to TomTom, Questie and OpenMap where they overlap.

## Changed
- Works with other addons: TomTom keeps /way, and FlareUI's Map pins on "/way" option greys out while TomTom is loaded. FlareUI's nameplate quest marks step aside while Questie's nameplate icons are on. Move Any Frame leaves the world map to OpenMap.
- Quest Tracker: Minimize during fights and in instances now opens the tracker again afterwards, unless you minimized or expanded it yourself.
- Profiles: exported strings only carry what you changed, so they are much shorter. Imports ignore values of the wrong type.
- Addon Button Bag: buttons their addon has hidden are no longer pulled into the bag.
- Proc Glow: uses less CPU in fights. Reactive abilities can take up to a tenth of a second to light up.

## Fixed
- Settings: searching no longer stops with a Lua error, "/way" style searches find results, and profile changes show right away.
- Reload Now works whatever your Cast on Key Down setting is, and an invisible leftover button no longer opens chat when clicked in combat.
- Chat: a whisper tab no longer breaks the tab bars when the whisper arrives in an instance. Whisper windows now follow your settings and keep their tab list up to date, tabs flash when a new whisper arrives, Filter Settings opens on the right window, and chat fades evenly.
- Raid frames: changing the layout while in a raid no longer leaves tiles misplaced or stretched. Main tank frames stop at four, and closing Edit Mode in combat removes the samples right away.
- Party and boss frames: Only My Debuffs, the aura font and border changes apply without a reload. Party frames show sample buffs as soon as Edit Mode opens, and the portrait dispel spot holds four icons.
- Unit frames: the PvP crest and level colour follow faction changes, the high level skull updates on level changes, heal and absorb bars follow maximum health changes, and clearing a target plays its sound again. Reset on the Forever Style focus frame no longer shrinks it.
- Damage Meter: Match Chat Size now works, the settings page no longer touches Blizzard's meter while the module is off, new windows are styled straight away, and hidden meters no longer show themselves at the start of a pull.
- Quest Tracker: a quest's tooltip and highlight no longer get stuck after the list updates, and Hide When Empty ignores hidden quests.
- Action bars: turning Status Colours off restores normal icons right away, out of range colours stay on after an icon updates, and #showtooltip macros use their spell's colours. Stop Auto-Add gives the setting back when turned off or when the module is off.
- Hide options: a hidden bar comes back when you untick its option, also after a visit to Edit Mode. A pet bar shown in combat hides again after it, and changes made in combat apply when it ends.
- Quality of Life: turning camera or tutorial options off restores your own values. Sync Blizz UI no longer asks for a reload just because the camera moved, and no longer fights Enemy Nameplates in Combat Only.
- Reset every setting keeps what's needed to restore your game settings, such as enemy nameplates.
- Tooltips: item quality borders stay on instead of being reset.
- Radial Menu: an extra key on an empty radial no longer fires the main radial, and switching to an empty radial closes the old one. You can drop spells on occupied rows in the editor, the Spells list hides spells you haven't learned, and a % in a radial's name no longer breaks Create Macro.
- Minimap: turning the Addon Button Bag off brings back Blizzard's addon compartment. The bag no longer ignores clicks after closing it during a drag, and opens away from the screen edge at any scale.
- Resource Bars: off-hand and ranged swing bars show after login, and the Five-Second Rule spark follows its option right away.
- XP Bar: follows the show honor as experience setting right away.
- A /reload in combat no longer leaves Blizzard's buffs or frames on screen after the fight.

# FlareUI 2.5.1

Copy a whole chat tab, smarter spell rank upgrades, and faded action bars that show when you drag a spell.

## New
- Chat: **Copy Chat** in a tab's right-click menu opens a window with that tab's lines as plain text, all selected for Ctrl+C. Lines the game keeps hidden, such as chat inside instances, are left out, and the window says so.

## Fixed
- Update spell ranks: a Train All visit now takes your buttons to the newest rank whatever order the ranks were learned in, and a button also moves if you skipped a rank in between. Lower ranks you keep on your bars on purpose still stay.
- Action bars: faded bars now show while you drag a spell or item, without Fake Cooldown Manager bars.
- Damage Meter: a window saved as collapsed can be expanded again: its button shows in the middle of the window.

# FlareUI 2.5.0

See when your interrupt is ready, jump straight to a setting from search, and spell ranks in the radial editor.

## New
- Cast bars: an enemy's cast bar on the target, focus and boss frames turns green while your interrupt is ready (Kick, Pummel, Shield Bash, Counterspell, Earth Shock or Silence). While it's on cooldown the bar keeps its normal colour, and casts you can't interrupt stay grey.
- Settings: click the path above a search result to open its page, scrolled to the setting, which flashes briefly.
- Settings: new options can show a **NEW** label on their row, page and tab. Search for "new" to list them.
- Radial Menu editor: spells show their rank ("Frostbolt (Rank 3)"), so you can tell the ranks apart and search for one. Hovering a spell or item in the Catalog or the Buttons list shows its game tooltip.

## Changed
- Unit, party, raid and boss frames: the hover highlight is brighter, a soft glow over the health bar that's easier to see.
- Settings: search ignores accents, so "ecran" finds "Écran".

## Fixed
- Player and pet frames set to fade now stay visible while you're missing health.
- Cast bars: casts you can't interrupt now turn grey during combat too.
- Auto repair no longer says "Repaired" when you couldn't afford it. After selling junk it waits for the gold to arrive, then repairs.
- Auras: changing aura options no longer piles up hidden aura icons in the background.

# FlareUI 2.4.5

Launch-day fixes: whisper tabs, Target of Target, and nothing reloads your UI in a fight.

## Fixed
- Chat: a new whisper tab no longer opens with an empty window, and whisper tabs now fade in and out like your other chat windows.
- Target of Target and Target of Focus: health and power now update during the fight, not only when the target changes.
- Reload questions: if one was closed during combat, pressing Enter could still reload the UI. Enter now opens the chat as usual, and a dialog shown in combat no longer blocks your movement keys.
- Settings: closing the window in combat no longer leaves a clickable **Reload now** button on screen.
- Quest Tracker: **Minimize in combat** now works.
- Raid frames: Missing Buffs no longer throws errors when you die during a boss fight, and no longer marks members who are too far away to check.
- Raid frames: your own frame no longer flickers faded, and members whose range can't be checked are no longer faded.
- Quality of Life: turning the module off now puts back the game settings it changed (enemy nameplates, camera zoom, tutorials). Sync Blizz UI no longer copies "enemy nameplates off" from Combat Plates to your other characters.
- Radial Menu: **Create macro** now allows up to 30 character macros, and a Toggle keybind with no radial left no longer errors.
- Fake Cooldown Manager: bars no longer stay clickable after dropping a spell during combat.
- Target frame: the Elite & Rare icon follows changes, and an old ready check mark no longer shows on a new target.
- XP bar: hides more reliably when you reach max level.

# FlareUI 2.4.4

Share your FlareUI profile as a text string.

## New
- Profiles: **Export** and **Import** buttons under the profile options. Export shows the profile in use as a string to copy; Import takes a pasted string and adds it as a new profile (your current one is never overwritten). Radial menus and Blizzard's Edit Mode layouts aren't included.

## Changed
- Profiles: the profile options sit in a **Profile** section.
- About: the note on copying links now ends the thanks line.
- Radial Menu: **Game Menu** is gone from the Panels library (it couldn't open the game menu from a radial).

# FlareUI 2.4.3

Party frames in a row again, a modern combo bar for FlareUI Style, and Only My Buffs on the player frame.

## New
- Party frames: **Orientation** is back (Vertical or Horizontal), between Style and Growth. In a row, Growth reads Right or Left. Each frame leaves room for its side auras, a pet or target on its right, and the ring in FlareUI and Forever Style.
- Target frame, FlareUI Style: **Modern Combo Points** at the bottom of Look (off by default). The combo points show as Addon Style's bar along the top of the health bar instead of gems round the portrait.
- Player frame: **Only My Buffs** right below Aura Size (off by default): only the buffs you cast on yourself.

# FlareUI 2.4.2

A bigger minimap without a bulkier frame, and a cast bar switch on the target and focus frames.

## New
- Minimap: **Map Size** in Edit Mode, in a panel under the minimap's dialog. It grows or shrinks the map itself; the border, header and buttons keep their size. Blizzard's Size slider is now called **Scale** and still scales the whole minimap.
- Target and focus frames: a **Cast Bar** switch at the top of the Cast Bar section (on by default), like the one on party and boss frames.

## Changed
- Target and focus frames: Cast Bar Texture now sits right below Cast Bar Position.
- Party and boss frames: Cast Bar Texture now sits above Cast Bar Height.

# FlareUI 2.4.1

Aura ordering on every aura frame, and the swipe choice back on Buffs & Debuffs.

## New
- **Aura Ordering**, a new section right below Auras in Edit Mode on every unit frame with auras: player, target, focus, pet and their targets, party, raid, main tanks and boss frames.
- Aura Ordering: **Sort By** (Default, Order Applied, Time Left or Name), **Reverse Order**, and **Your Auras First** (with Time Left or Name). Default keeps Blizzard's order; nothing changes until you pick one. On party, raid and boss frames the buff and debuff rows are sorted; Bigger Boss Debuffs, dispel icons and the big defensive keep their order.
- Buffs & Debuffs: the same Aura Ordering options in a new section of their settings page (Order Applied by default, as before). The icon shape and timer options now sit under **General**.
- Buffs & Debuffs: **Swipe** is back in General: Over the icon, Around the border, Both or None.

## Changed
- The aura swipe now runs over the icon and its border together (**Both**): the default on Buffs & Debuffs, and on every unit frame aura (player, target, focus, pet, party, raid, main tanks and boss).
- Buffs & Debuffs, Around the border: a slightly thicker ring and richer border colours.

# FlareUI 2.4.0

New aura filters, party and boss frames on Forever Style's frame plate, Growth for party and raid frames, a reworked controller radial, and a full clean-up pass.

## New
- Party and boss frames in **Forever Style** now sit on the frame plate like the player and target frames, with a **Scale** slider. The name box glows for your target and for dispellable debuffs, and the ring flashes on aggro. Forever Style now also uses the ring party and boss frames.
- Party frames: **Growth** (Down or Up), right below Style.
- Raid frames: **Growth** (From the Middle, Down or Up), right below Sample Raid, for groups in rows. The main tank frames follow it.
- Party frames: **Pets** and **Party Targets** dropdowns (Off, Bottom of the Frame, Right of the Frame) above Spacing. They replace the Show Pets and Show Party Targets checkboxes. Both on the right stack, both at the bottom share a row.
- **Hide Buffs** on the player, party and raid frames (right below Debuffs): hide permanent buffs (the default), or buffs longer than 15, 10, 5 or 1 minutes. Off shows every buff.
- **Only My Buffs** on party and raid frames: only the buffs you cast.
- **Dispellable Debuffs Only** on party and raid frames: only the debuffs you can dispel.
- **Focus Boss Debuffs** on the player, party and raid frames: in a boss fight, only the boss and role debuffs show. Every debuff shows elsewhere.
- Main tank frames have their own Power Bar Height, aura places, Aura Size and aura filters, in Frame and Auras sections.
- Raid frames: new inside aura places (Centre, Centre Left, Centre Right); the places drop the "Inside," text.
- Raid frames: **Group Numbers** are now "Group N" headings above each group. Edit Mode samples follow Sort By and show a sample big defensive.
- Target and focus frames (FlareUI and Forever Style): **High Level Skull** in Icons (on by default). It shows the skull for mobs whose level reads "??". Off shows a red "??".
- Pet frame: **Happiness Position** (Centre, Right of the Frame, Left of the Frame) under Pet Happiness.
- Radial Menu: **Game Menu** and **Macros** in the Panels library.
- Radial Menu: right-click closes an open radial in Hold activation.
- Radial Menu, controller: LB and RB switch the aimed button's sub-radial choice. The centre shows the right stick icon in the Gamepad UI.
- Quest Tracker: now works in the Gamepad UI too.

## Changed
- Radial Menu, controller: **L3** opens the radial, the right stick aims, **R3** uses the button, and B or L3 closes it. The camera holds still while it is open and you can keep walking. R3 is the ping again whenever the radial is closed.
- Enemy and neutral levels use Blizzard's own difficulty colours (green, yellow, orange, red, grey) on every frame and tooltip, in every style. Friendly levels stay gold.
- **Mirror** on target, focus and boss frames, in FlareUI and Forever Style, only turns the bars' direction now. The portrait and icons keep their places.
- Party frames: the **Orientation** option is gone; party frames are always vertical.
- Party and boss frames: auras above or below the frame take one row, so the frames sit closer together.
- Party, raid and main tank frames: the big defensive is a fixed size (larger on the Forever Style plate). Missing buffs sit centred under it. Every aura sample in Edit Mode has its border.
- Raid and main tank defaults: new aura places and sizes, height 60, and a main tank position at the bottom left.
- Party and focus frames show first names only outside Forever Style (Full Player Names still decides elsewhere).
- Tooltips: the name line shows the name only. One tag at the end of the level line: (Boss) in red, (Elite) and (Rare) in gold; the elite "+" is gone. Players read "Level N Race Class" in white, and the faction line is coloured (Horde red, Alliance blue).
- The pet happiness face is a little smaller.
- A clean-up pass across the whole addon: faster chat lines, damage meter timer, tooltips, quest tracker and nameplate quest tags, plus tidier code.

## Fixed
- Radial Menu in the Gamepad UI: opening the bags (or Social) from a radial no longer causes a "blocked" error and a long freeze.
- Hide Tutorials now closes every tutorial tip, not only some.
- The player's level no longer turns gold after a level-up in the ring styles.
- Proc Glow no longer leaves a glow stuck after it is switched off and on.
- Radial Menu: deleting a radial and pressing Undo restores its keybinds too. A slot keeps its highlight when an item finishes loading.
- Settings: the "module is off" card no longer covers search results. The welcome screen counts Resource Bars as a module.
- Chat and damage meter hooks are no longer added again on every settings change.
- The weapon enchant tooltip no longer keeps lines from the last unit you hovered.

# FlareUI 2.3.1

## New
- Tooltips: **Show threat** (on by default, above Show target): turn it off to hide your threat percentage on enemy tooltips.

# FlareUI 2.3.0

Radial Menu opening options, chat link tooltips, and more control over how every unit frame looks.

## New
- Radial Menu: **Menu position** (Options tab): open radials at your mouse cursor (the default) or in the middle of the screen. Radial macros open there too.
- Radial Menu: **Activation** (Options tab): **Hold** (as before: hold the key, point, release) or **Toggle**: press the key to open the radial and keep it open. Left-click or press the key again uses the slice you point at, right-click goes back a level or closes, Escape closes. Middle-click a nested radial to open it in place of the current one; the mouse wheel still steps through it.
- Chat: **Link tooltips on hover** (Tweaks, on by default): point at an item, spell or quest link in chat to see its tooltip, without clicking.
- Unit Frames: **Background Opacity** at the end of Look in Edit Mode, on every unit frame (player, target, focus, pet, player cast bar, target of target, target of focus, party, raid and boss): how dark the empty part of the bars is, from 0% to 100%. Cast bars follow their frame's setting.
- Unit Frames: **Full Player Names** (Look, on by default): players' first names and surnames on every unit frame. Off shows the first name only.

## Changed
- Unit Frames: **Border Texture** is now on every frame in FlareUI Style and Addon Style, the player, target and focus frames included. Forever Style has no border options at all: its border is fixed on every frame.
- Unit Frames: the level of a friendly unit (anything you can't attack) shows in Blizzard's gold, in every style. Enemies keep the difficulty colours.
- Bar and border dropdowns: FlareUI's own options come first, then a line and the bars or borders other addons add, A-Z. LibSharedMedia's built-in Blizzard bars and borders are no longer listed.
- FlareUI's options in those dropdowns: FlareUI Thick and FlareUI Thin for Border Texture; None and FlareUI Frames for the Chat, Damage Meter and Quest Tracker borders; FlareUI Flat, FlareUI Forever and FlareUI Striped for Bar, Cast Bar and Absorb Texture. A frame already set to something no longer listed keeps it.
- **Frame Texture** is gone from Cast Bar Texture and Absorb Texture.

# FlareUI 2.2.1

## Fixed
- Target and focus frames: switching straight from one target to another no longer leaves the last target's debuffs on the frame. They showed up as duplicates, and their timers sat at 0 or were missing (reported in a dungeon). Party, boss and raid frames get the same fix when a new unit takes a frame (a new boss, a roster change).
- Target and focus frames: **Only My Debuffs** now shows only the debuffs you cast. Before, it showed every player's debuffs.

# FlareUI 2.2.0

Improvements from your feedback: whole-width aura rows, cast bars that make room for auras, tooltip level colours and a tidier minimap.

## New
- Unit Frames: buffs and debuffs can go **Top** or **Bottom**, across the frame's whole width. Party and boss frames get **Above the Frame**, **Below the Frame**, **Inside, Top** and **Inside, Bottom**. A whole-width place greys out the other places on that edge for the other kind of aura.
- Tooltips: the target's level is coloured by difficulty against yours (grey, green, yellow, orange, red), as quests are.
- Minimap: a **Fonts** tab for the zone name and the clock.
- Minimap: drag and drop the buttons in the addon button drawer to reorder them. The order is kept, and new addons go last.

## Changed
- Target, focus, party and boss frames: auras sit right against the frame. The cast bar shows next to the frame and, while it shows, pushes the auras on its side out past it; they come back when the cast ends.
- Party frames: **Left of the Frame** is gone from the aura places, and boss frames lose **Right of the Frame**. Auras set there move to the other side.

# FlareUI 2.1.1

## Changed
- Bar texture dropdowns (bars, absorbs, cast bars, the XP bar) no longer list LibSharedMedia's built-in Blizzard textures (Blizzard, Blizzard Character Skills Bar, Blizzard Raid Bar, Solid). A frame already set to one keeps it. Textures from other media addons still show.
- Libraries updated: LibSharedMedia-3.0 (latest) and AceDB-3.0 (Ace3's WoW Forever character names). Your settings are kept.

# FlareUI 2.1.0

Two new looks: Forever Style unit frames on Blizzard's own frame plate, and FlareUI Style party and boss frames with the portrait ring.

## New
- Unit Frames: **Frame style** (Unit Frames > Look) has three choices: **FlareUI** (the bronze ring beside FlareUI's bars, the default), **Forever** (new) and **Addon** (plain frames). Each style keeps its own setup: sizes, positions, totems, and the party and boss frames.
- Forever Style: the player, target and focus frames on Blizzard's Forever frame plate, with its name box, health and power slots and the bronze ring. **Scale** in Edit Mode sizes the frame in Blizzard's proportions, Width stretches it. The name sits in the name box, the health and power texts in the middle of their bars.
- FlareUI Style: the **party and boss frames get the portrait ring**. Party frames: the player frame's ring and level disc, the role icon where the PvP crest sits, the leader crown and raid marker on the ring, the ready check and summon / resurrect / phase icons on the portrait. Boss frames: the target frame's ring and level disc (a skull for ?? bosses) with Blizzard's elite, boss and rare frames. Both have **Portrait Size**. Raid-Style party frames stay as they are.
- **FlareUI Forever** bar texture: Blizzard's Forever health bar art, now the default for every bar (unit, party, raid, boss and resource bars, every cast bar, the XP bar). Absorbs keep FlareUI Striped.
- Party Frames: **Dispel Icons** is a switch and sits on the portrait: up to four, two to a row (in the middle of the health bar on frames without a portrait).
- Damage Meter: a **Header** font in the Fonts tab, for the title row (Damage Meter or Threat, the session and its timer).
- XP Bar: **Bar Texture**.
- Unit Frames: **PvP Timer** in Addon Style too, **Show Level** on every frame, **Hide Auras** on the focus frame.
- Boss Frames: **Mirror** and **Only My Debuffs** (both on by default), and **Absorb Texture**.
- Edit Mode: sample incoming heals and shields on the unit frames, sample aura timers, and portraits on the party and boss samples.
- The Target, Focus and Pet Edit Mode dialogs have the "FlareUI settings" button too.

## Changed
- Each style has its own defaults for the player, target, focus, pet, totems, party and boss frames: sizes and positions to fit its look.
- Classic combo points follow the style: always on in FlareUI and Forever Style, off in Addon Style (the option is gone).
- Party and boss auras above or below the frame fit as many to a row as the frame's width allows, as the unit frames' auras do. Auras above or below any frame sit closer to it.
- Aura size: 18 on the focus frame, 24 on the player and target frames, by default.
- Incoming heals use the frame's bar texture. Shields always grow back from the end of the bar (Absorb Reverse Fill is gone).
- The dispel highlight colours the frame's own border.
- Party, boss and raid frames show no timers on auras inside the frame.
- Unit Frames page: Colour palette sits under Frame style; Hide Player and Pet is now **Fade Player and Pet**.
- Party Frames: Party Targets is now **Show Party Targets** and Pets **Show Pets**; Spacing sits under Orientation; Target Gap is gone (fixed); Portrait sits above Health Text; Dispel Highlight above Dispel Icons (raid frames too).
- Raid Frames: Spacing and Group Spacing moved to the Raid section, under Groups.
- Icons: Raid Target is now **Raid Markers**.
- Only My Debuffs is no longer on the player frame. Power Bar for Healers Only is gone: party and raid frames show everyone's power when Power Bar Height is above 0.
- The PvP timer sits right beside the PvP crest.

## Fixed
- Minimap: the addon button bag no longer takes in Questie's quest markers (or other addons' map pins), which stretched it down the screen.
- Damage Meter: the bar font reaches every row, group members joining later included.

# FlareUI 2.0.15

## New
- Action Bars: **Allow Auto-paging** (last in Tweaks, Action Bar 1 by default): the bar switches to its own page in Stealth, a druid form or a warrior stance. Forever doesn't switch any bar by itself. The new page starts empty: fill it while in that form.

## Changed
- Unit Frames: the Frame section of the player, target and focus dialogs is reordered: Width, Height, Power Bar Height, Portrait Size (was Ring Size), Portrait, Health Text, Power Text.
- Settings: the window is a little taller.

# FlareUI 2.0.14

Ready for Forever's new client build: the minimap and the Forever style frames follow Blizzard's new look.

## Changed
- Minimap: the header uses Forever's new buttons: the bronze zone plate under the zone name and clock, and the new tracking and calendar buttons.
- Forever style frames: the player's portrait has the round ring, mirroring the target's, as Blizzard's player frame now does.
- Forever style frames: the PvP crest sits where Blizzard's new frames put it, without a disc and in front of the level disc. The level disc and number are a little smaller, as on Blizzard's frames.
- Forever style frames: the combo points around the target's portrait are placed and sized as Blizzard's, clear of the ring and above the PvP crest.
- Forever style frames: fighting in a rested area, the player's ring shows the combat glow and swords, as Blizzard's frame now does.

## Removed
- Minimap: the group size flag. Forever's minimap no longer has an instance difficulty banner.

## Fixed
- Minimap: works again after Forever's client update (it stopped with "could not find the Blizzard minimap cluster").
- Minimap: the addon button bag no longer shows an addon twice when it has its own minimap button and an entry in Blizzard's addon menu.

# FlareUI 2.0.13

## Fixed
- Auras: setting the aura text outline to **None** no longer causes a Lua error.

# FlareUI 2.0.12

## Fixed
- Damage Meter: no more Lua error about `durationSeconds` when a fight starts or ends. FlareUI no longer runs Blizzard's own visibility check for the meter; it reads Blizzard's answer instead.

# FlareUI 2.0.11

See what your party is targeting, and a fix for the ranged swing timer.

## New
- Party Frames: **Party Targets** (in the Party section, off by default): a small frame beside each member shows what they are targeting (under each member when the party is horizontal). Click one to target it too. **Target Gap** sets the space between them, and the **Target** section has the width, height and border.

## Changed
- Party Frames: the Party section is reordered: Style, Orientation, Sort by Role, Show Player, Pets, Party Targets, then Spacing.

## Fixed
- Resource Bars: the **Ranged Swing** bar (and the off-hand one) no longer stays hidden when the game hides your attack speed.
- Tooltips: no more Lua error about a forbidden object when hovering a buff or debuff on an enemy nameplate (fixed in 2.0.10).

# FlareUI 2.0.9

Tidier Edit Mode dialogs, more options back for your frames, and a big clean-up under the hood.

## New
- Party Frames: **Missing Buffs** (under Auras, off by default): out of combat, the group buffs a member lacks that you can cast show in the corner across from the buffs.
- Party Frames: a **Pet** section for the pet frames' width, height and border, shown while Pets is on.
- Boss Frames: a **Boss** section with Growth and a new **Spacing** slider.

## Back again
- Cast bars (Player Cast Bar, target, focus, party and boss): **Hide Icon** and **Hide Spell Timer**; target, focus, party and boss also get **Cast Bar Height**, **Texture** and **Border Texture**.
- Unit Frames and Party Frames: **Absorb Texture** and **Absorb Reverse Fill** in the Look section.
- Party and Raid Frames: **Big Defensive** and its size; Party Frames: **Spacing**.
- Action Bars: **Clean keybind text**, **Button art** and **Stop auto-add spells**.

## Changed
- Edit Mode: every FlareUI frame's dialog uses the same sections in the same order: Frame (Width and Height first), Look (textures), Cast Bar, Auras, Icons. Resource bars have Frame and Look sections too.
- Damage Meter: it remembers whether you picked Threat or damage, even after a reload. Threat View in Combat goes back to your pick after the fight.
- Damage Meter: it always shows in Edit Mode, whatever its visibility.
- Quest Tracker: the default width is 250.

## Fixed
- Ability Proc glow: Overpower, Revenge, Execute and the other reaction abilities glow again.
- Resource Bars: the Fonts tab's text size now changes the bars' text.
- Tooltips, Damage Meter, Unit Frames and the durability warning: fewer chances of Lua errors from hidden combat values.
- Status colouring: switching it off clears the grey from your buttons at once.
- Clean keybind text: switching it off brings Blizzard's labels back without a reload.
- Chat: the header buttons can no longer flicker between shown and hidden.
- Addon bag: an addon with both a minimap button and an addon-drawer entry shows once.
- Radial macros: a macro naming a radial that doesn't exist prints a message instead of an error.
- Changing unit frame fonts or colours updates raid and boss frames right away.

# FlareUI 2.0.8

## Changed
- Quest Tracker: **Shift + click** or **Ctrl + click** a quest to focus it, and again to unfocus it. While you're typing in chat, Shift + click still links the quest. Untrack Quest is in the right-click menu.
- Nameplates: the quest "!" sits just beside the nameplate instead of over its edge.

# FlareUI 2.0.7

## Fixed
- Damage Meter: no more Lua error about `durationSeconds` during fights. FlareUI no longer brings the meter up itself in combat: Blizzard does when the fight starts, and FlareUI's Visibility catches up when it ends.

# FlareUI 2.0.6

## Fixed
- Tooltips: **Health bar** and **Show target** now work on players' tooltips too, not only NPCs and pets. The Show tooltips rules (like Hide in combat) apply to players as well.

# FlareUI 2.0.5

## Changed
- Move any window: the mouse wheel over a window zooms the camera again; only Ctrl + mouse wheel resizes the window.
- Chat: Copy Line is gone.

## Fixed
- Fake CM: a bar you take off the cooldown display can be clicked again right away, without a reload.
- Move any window: Ctrl + right-click to reset a window's size no longer pins a window you never moved, and does nothing in combat on windows the game locks.
- Gray out known items: turning it off clears the grey from the vendor page at once.
- Chat Formatting: the explanations now match what each option does.

# FlareUI 2.0.4

New Quality of Life helpers, your chat formatting back, and a settings panel that explains every option on its own.

## New
**Quality of Life** (all off until you switch them on)
- **Gray out known items:** recipes and items you already know are greyed out at vendors.
- **Mail address book:** a button beside Send Mail's "To:" lists your other characters and the last one you mailed.
- **Alert sounds:** ready checks, summons, resurrections, group invites and dungeon queues flash the taskbar and play a sound, even with sound effects off.
- **Pet food marker:** a paw marks the food in your bags your hunter pet eats.
- **Skip loot confirmations:** no "will bind to you" question when you loot or roll.
- **Combat enemy plates:** enemy nameplates show only during fights.
- **Frame numbers:** hides the damage numbers on your portrait and the health and power numbers on Blizzard's frames.

**More options**
- Action Bars: **Update spell ranks**: a newly learned rank replaces the old one on your bars (lower ranks you placed on purpose stay).
- Chat, Damage Meter and Quest Tracker: **Frame Border**, with None to hide it.
- Move any window: **Ctrl + mouse wheel** resizes a window again; Ctrl + right-click resets it.

## Changed
- Chat: the **Formatting** options are back (better NPC and player names, timestamps, short channel names, level before names).
- Settings panel: every option has its own explanation, with lists where it helps, and the dog is back in the info panel.
- Chat has Frame, Tweaks and Fonts tabs; Quality of Life has Gameplay, Interface and Advanced tabs; Tooltips has Look and Tweaks sections; Quest Tracker has a Frame section, with Display above Minimize.
- Action Bars: Fake Cooldown Manager has its own **FakeCM** tab and no on/off switch: it's on while a bar is picked.
- A few options have clearer names, like **Train all skills** and **Hide level box**.
- Translations: the dots and bullets that kept some phrases from translating are gone.
- FlareUI is about 7 MB smaller.

## Fixed
- Dungeon Journal's minimap button goes in the addon drawer and can be clicked.
- Legacy Forever's tracker section no longer disappears when FlareUI's quest tracker is on.
- Clicking a link in the settings opens the copy box in front of the panel, with a sound.

# FlareUI 2.0.3

## Fixed
- Unit Frames: with **Hide Player and Pet** on, your player and pet frames now show at the same moment as the target frame when you pick a target, instead of a moment later.

# FlareUI 2.0.2

## Fixed
- Unit Frames: **Hide Player and Pet** (was Hide Player and Pet out of combat) hid your frames too often. They now hide only while you're out of combat, have no target and are at full health. Pointing at either frame still shows both.

# FlareUI 2.0.1

You asked for your options back: fonts, textures, fade speeds and more are in. The settings are easier to scan too.

## New
**Fonts**
- A Fonts tab on Action Bars, Unit Frames, Resource Bars, Buffs & Debuffs, Chat, Damage Meter, Quest Tracker and Tooltips: font, size, outline and shadow for each text.

**Look**
- **Bar Texture** and **Border Texture** for each unit frame (player, target, focus, pet, their targets, party, raid, boss, cast bar) and each resource bar, in a Look section of its Edit Mode dialog. The Forever style's bronze frames keep their own border.

**Fading**
- **Fade Speed** (Instant, Fast, Slow) for action bars, chat and the damage meter.
- Action bars: five fade groups instead of three.
- Chat: **Visibility** (Always visible, Chat interactions, Combat + chat interactions) and **Fade Delay** (how long the chat stays after showing).
- Damage meter: every show and hide fades, whether combat, a group or the mouse brings it.

**More options**
- Unit Frames: **Hide Player and Pet out of combat**. Pointing at either one shows both.
- Action Bars: **XP Bar Text**, on mouseover or always.
- Chat: **Edit Box Opacity**.
- Damage Meter: switches for the **Combat timer**, the **Ready check button** and the **Countdown button**.
- Quest Tracker: a **Display** section (zone headings, completed last, quest tags, wrap long text, tracked recipes, quest count, hide when empty) and **Minimize to a button**.
- Tooltips: **Tooltip Scale**, **Health bar** and **Show target**.
- Minimap: **FPS and Latency on Clock** can be turned off.

**Settings panel**
- Click a section's title to fold it away.
- Shorter, clearer explanations in the info panel, with lists where it helps.
- Two columns for switches, and a taller window.

## Changed
- The player frame's Show option moved from Edit Mode to the Unit Frames page (Hide Player and Pet out of combat).
- Chat: the tab menu's Font Size is gone. Set the chat's size in Settings > Chat > Fonts.
- Damage meter: with Threat view in combat, the meter switches back to damage only once it has faded out after a fight.
- Action bars fade out a moment sooner after the mouse leaves.

## Fixed
- The sound of picking a target is back.
- The flight path window can be moved again. The clock, opened mail, the stable, loot history, the group finder lists and the dressing room can be moved too.
- Unit frame and party, raid and boss borders sit flush against the bars, with no gap.
- Your 1.x settings brought over by the import now include fonts, textures, the new options and the tooltip scale.

# FlareUI 2.0

A new settings panel that explains every option, Forever-style unit frames, and raid and boss frames.

This is the biggest update for this addon so far. The goal was to simplify, improve the UX, make it way more user friendly (especially for new players) and focus on the true core of FlareUI: improve, not replace, Forever's interface.

**Your 1.x settings come along:** the first time you log in, FlareUI brings over your radial menus and keybinds, your profiles, every module's on/off switch, the options the new panel still offers, your frames' Edit Mode settings and positions, and each character's quest tracker, chat history and Sync Blizz UI data. Options that 2.0 no longer has (fonts, borders, textures, the old show rules) start from the new defaults. Unit frames start in the new Forever style; switch on Addon Style Frames to get your 1.x frames back as they were.

## New

**Settings panel**
- One window for everything: modules on the left, each with its own on/off switch, the options in the middle, and an info panel on the right.
- Hover any option to see a picture of what it does and a short explanation.
- Search every setting by name.
- Changes that need a reload are collected in a bar at the bottom, with one Reload button.
- Profiles in Advanced: start a new one, duplicate the one in use, delete, or reset FlareUI.
- Opens with /fui, from the minimap's addon button, from a key binding, or from Blizzard's Options > AddOns.

**Unit Frames**
- Forever style (the default): player, target and focus in the game's own bronze ring frames. Addon Style Frames switches to FlareUI's clean frames, and each style keeps its own setup.
- Raid frames, with sizes per raid size and main tank frames.
- Boss frames, mirrored like the target frame.
- Main Frames: one switch for player, pet, target and focus.
- Colour palette (FlareUI's softer tones or Blizzard's) and one Class Colours switch for every frame.

**Damage Meter**
- Visibility: always, in combat, in a group, or hidden, plus Show on Mouseover.

**Quality of Life**
- Hide Level on enemy nameplates, with the quest mark on the health bar's edge.

**Radial Menu**
- A new character starts with the radial setup of the last character you changed it on.
- The radial editor is part of the Radial Menu page, with a live preview.

## Changed
- Fewer, clearer options: font, border and texture choices are gone, and each frame keeps its designed look.
- The radial key always opens the radial chosen in the Keybinds tab.
- Battle.net toasts appear above the chat, with a bronze border.
- Mana cost preview on the mana bar is always on.

## Removed
- The old settings window.

# FlareUI 1.6.5

## Fixed
- **Unit Frames:** Classic Combo Points work again after Forever's October update, which rebuilt the game's combo points. They now use Blizzard's new combo point art and animations, still in a row on the target frame, filling from the left.

# FlareUI 1.6.4

## New
- **Radial Menu:** an Emotes category in the radial editor: the 22 animated emotes (Wave, Dance, Salute, Sit and more), each with its own icon. They work in combat too.
- **Chat:** Up and Down (with or without Shift or Alt) step through the last 50 lines you sent, kept across reloads. Down past the newest gives back what you were typing.
- **Chat:** with the edit box inside the chat window, the newest lines move up above it while you type, and drop back when it closes.

## Fixed
- **Chat:** sharing a map pin in chat (shift-click) could be blocked with an error after using Copy Line. Copy Line now puts the line in the chat box only when it is already open, and in the copy box otherwise.

## Removed
- **Chat:** the /tt command (whisper your target).

# FlareUI 1.6.3

## Fixed
- **Buffs / Debuffs:** weapon enchants (shaman imbues like Rockbiter Weapon, poisons, oils, sharpening stones) now show at the start of your buffs, with their timer and the weapon's tooltip. They never appeared before: the game data FlareUI read them from is empty in Forever. Right-click no longer removes a weapon enchant: Forever allows that only in Blizzard's own buff frame.

# FlareUI 1.6.2

## Fixed
- **Move Any Frame:** opening the spellbook (or another window Blizzard loads on first use) for the first time during combat no longer causes an "action blocked" error. The window becomes movable once combat ends.

# FlareUI 1.6.1

Bug fixes for bag windows, Sync Blizz UI and the action bar gryphons.

## New
- **Bag Header Tooltip** (Tweaks > Windows & Settings, off by default): Blizzard's "Backpack / click for bag settings" tooltip on a bag window's header is now hidden unless you turn it on.

## Fixed
- **Bags (Move Any Frame):** left-click anywhere on a bag window's header opens its menu again (Assign To, Ignore This Bag, sorting), as in Blizzard's UI. Press and drag the title to move the window. Right-click on the header, or on the bag icon, opens the menu too.
- **Sync Blizz UI:** a character copying from the source now switches to the source's Edit Mode layout again while Remember Layout per Mode is on. It happens once per character, and that layout becomes the one remembered for the mode.
- **Action Bars:** the gryphons no longer disappear after hiding the interface with Alt+Z (with Hide Bar Art on for Action Bar 1).

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
- Nameplate tweaks stand aside when another nameplate addon is running.
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
