# FlareUI 7.1.4

Your bags can now mark the gear in your equipment sets, and the Loot Feed shows how many of each item you already have. Auras above and below the unit frames go back to the corner.

**We need your help testing:**
- **Bags, Equipment Set Icon:** turn it on in **Item Icons**. Items in any of your equipment sets should show a small padlock in the top left corner, and nothing else should.
- **Loot Feed, Owned Count:** loot an item you already carry. Its icon should show your new total.

## Heads up
Some things change even if you change nothing:
- **Unit frames, auras Above the Frame and Below the Frame:** back in the corner, as before 7.1.3.
- **Loot Feed:** item icons now show how many you have in your bags. Turn it off under **Show**.
- **Bags & Looting, Item Slots:** six switches became one **Item Icons** dropdown, and **Plain Empty Slots** moved into **Skin Item Slots**. What you picked is kept.
- **New players only:** **Chat Style** starts on **Classic Style**. Your setup stays as it is.

## New

### Bags & Looting
- **Equipment Set Icon** (off): a small padlock on bag items in one of your equipment sets. It's only a marker: you can still sell the item.
- **Loot Feed, Owned Count** (on): how many you have in your bags, on each item's icon.

## Changed
- **Bags & Looting, Item Icons:** one dropdown in place of **Junk Coin**, **Item Level**, **Uncollected Appearances**, **Pet Food Marker** and **BoE Text**, with the new **Equipment Set Icon**.
- **Bags & Looting, Skin Item Slots:** **Plain Empty Slots** is now a choice here. It works with the skin **Off** too.
- **Loot Feed, Show:** one dropdown in place of **Show Money** and **Show Skill-Ups**, with the new **Owned Count**.
- **Chat Style:** **Reset** goes to **Classic Style**.

## Fixed
- **Proc glows:** Stormstrike and other spells with their own cooldown glowed as if their cooldown had reset.
- **Nameplates, hunters below level 12:** plates out of range didn't fade.

### Translations
- French updated for 7.1.3. By Brainc3ll.
- Simplified and Traditional Chinese updated for 7.1.3. By AreChen.

# FlareUI 7.1.3

Raid frames you can set up per raid size, nameplates that show the whole plate when the unit itself starts a fight, and borders on the meter's bars. New players now start with a ready-made setup, and yours stays as it is.

**We need your help testing:**
- **Raid frames:** in Edit Mode, pick a **Raid Size** and change something. Join a raid of that size and check your change is there, and only there.
- **Nameplates, Show Whole Plate > When It Fights:** a Name Only plate should show in full while that unit is fighting, even when you aren't.
- **Meters:** each bar has a FlareUI Thin border. Try every bar style, with class icons on and off.

## Heads up
Some things change even if you change nothing:
- **New players only:** FlareUI's defaults changed for new installs. Your setup stays exactly as it is, with one exception:
  - **FlareUI Style, frames you never moved:** focus, pet, target of target, target of focus, totems and flag carriers sit up to 20 pixels from where they were. Move them back in Edit Mode if you like.
- **Nameplates, Show Plates in Combat:** moved. It's now **Name Only Mode > Show Whole Plate > When You Fight**, set for each plate type. What you picked before is kept.
- **Delete Junk When Full:** moved from Quality of Life to **Bags & Looting > Bags > Tweaks**. Your setting is kept.
- **Meters:** each bar now has a FlareUI Thin border in place of Blizzard's bright edge.
- **Totem bar:** its timers read like the unit frames': bare seconds, then "m" and "h".
- **Gryphons on Always:** they now dim with the main action bar when something dims it, like OLEDGuard.
- **Party and raid frames, Tooltips module off:** aura icons now show their tooltips, as on Blizzard's frames.

## Highlights
- **Raid frames, every setting per Raid Size:** up to 10, 25 and 40 players each keep their own Edit Mode settings. A size you never change uses your shared settings.
- **Nameplates, Show Whole Plate:** in Name Only Mode, show the whole plate **When You Fight**, **When It Fights**, or both.

## New

### Nameplates
- **Show Whole Plate** (None): in the Name Only Mode section, for each plate type. **When It Fights** shows the whole plate while that unit is in a fight.
- **Crowd Control, Aura Icon Shape, Aura Swipe and Aura Timer:** back, for the Crowd Control and Defensives icons. Until you pick one, each follows the Auras section.
- **Test in Game:** plates also show sample buffs, debuffs, crowd control and defensives, and the elite and rare dragons.

### Unit Frames
- **Raid frames:** every Edit Mode setting is saved per **Raid Size**, except positions, main tank frames, icons and Fading.

### Meters
- **Bar borders:** each bar in a FlareUI Thin border over a dark fill.

## Changed
- **Unit frames, auras Above the Frame and Below the Frame:** centred on the frame.
- **Auras on two rows:** the icons line up in columns on every frame. Before, the ones after purgeable buffs or weapon enchants sat 2 pixels over.
- **Chat, Modern edit box:** shorter, to fit one line of text.
- **Edit Mode:**
  - A dropdown with several picks reads **None** when nothing is ticked.
  - The Fading box under Blizzard's frames, like the chat, puts its switches two to a line.
  - **Centred Spell Name** is the last choice in the cast bar's **Show** list.
  - **PvP Flag** and **PvP Timer** are the last choices in the unit frames' **Icons** list.
- **Nameplates, Crowd Control and Defensives:** a little further from the plate.
- **Minimap, Info Bar:** **Below the Map** is now a **Position** dropdown (On the Map, Below the Map).
- **Minimap, Addon Buttons:** **Open on Mouseover** is now **Open Drawer on Mouseover**, and **Only on Mouseover** is **Addon Buttons Only on Mouseover**.
- **Meters, Threat Window:** **Off** is now **Meters Tab**, and **In the Meter in Combat** is **Auto-Switch in Combat**.
- **Settings:** many pages reordered so related options sit together, among them Action Bars, XP Bar, Minimap, Quest Tracker, Tooltips, Quality of Life, Meters and Nameplates' Cast Bars.
- **Tooltips:** **Show PvP** shows its line in the preview. **Healing and Damage** takes a full row.

## Fixed
- **Pet frame, Range Check:** stayed faded with your pet right next to you when you weren't in a group.
- **Chat:** a new size in **Settings > Chat > Fonts** didn't reach a window whose size you had picked from its tab.
- **Meters, Bar Texture:** going back to **Blizzard** kept the texture you had picked.
- **Nameplates:** Blizzard's sample auras showed on real plates in Edit Mode.

### Translations
- French updated for 7.1.2. By Brainc3ll.

# FlareUI 7.1.2

One cast bar for a whole batch of crafts, aura timers that read like Blizzard's, and a safer way to reset your settings. Plus fixes for the bugs 7.1.1 brought to the Cooldown Manager and the chat.

**We need your help testing:**
- **Crafting:** turn on **Show Craft Batch** and make 5 of something. One cast bar should run over the whole batch, with the count beside the timer.
- **Nameplate timers:** an aura longer than a minute should show no timer on a nameplate. Under 10 seconds, the timer turns yellow, then red.
- **Shamans:** with Improved Stormstrike, Stormstrike should glow on your bars when it resets.

## Heads up
Some things change even if you change nothing:
- **Aura timers** now read like Blizzard's:
  - The buff and debuff icons by the minimap keep "s", "m" and "h".
  - Unit frames show seconds as a bare number, with "m" and "h" above a minute.
  - Nameplates show seconds as a bare number, and no timer on an aura longer than a minute.
- **Quality of Life, Craft Batch Time:** removed. **Show Craft Batch** on the Player Cast Bar replaces it, and starts off.
- **Chat:** every chat window follows **Settings > Chat > Fonts** again. A font size you picked for a single window on 7.1.1 is cleared once. Pick it again from the tab's right-click menu.
- **Cooldown Manager, Growth From the Middle:** the icons centre on the box where you placed the bar in Edit Mode. This replaces 7.1.1's change, which could push them off the box.
- **Nameplates, Show Enemy Plates / Show Friendly Plates:** if one is set to **In Combat** and you turn plates on in Blizzard's settings outside a fight, FlareUI now takes that as your choice and switches to **Always**.

## Highlights
- **Show Craft Batch:** crafting several of one item runs one Player Cast Bar over the whole batch. The timer shows the time left for all of them, then how many are made, like (2/5).
- **Reset Profile:** resets only the profile in use, so a setup that went wrong no longer means losing every character's settings.

## New

### Unit Frames
- **Player Cast Bar, Show Craft Batch** (off): in Edit Mode, under the cast bar's **Show** list as **Craft Batch**. Works on the Player Cast Bar and on the player frame's cast bar.
- **Settings, Fonts, Player Cast Bar:** shows the cast bar itself, casting, while you change its fonts.

### Action Bars
- **Proc Glow:** lights Stormstrike when Improved Stormstrike resets it. The glow goes out when you use it, or after 8 seconds. Works on macros that cast it.

### Chat
- **Font Size** in the chat tab's right-click menu. A size picked there is that window's own.

### Profiles
- **Reset Profile:** puts the profile in use back to FlareUI's defaults. Your other profiles stay as they are.

## Changed
- **Reset FlareUI:** its warning now says it resets every profile on all your characters.
- **Nameplates, Click-Through:** the description now says it's one setting for every plate type.

## Fixed
- **Raid frames, Raid Size:** picking a size now updates Width, Height and Power Height in the Edit Mode dialog. Your values were always saved per size.
- **Cooldown Manager:** Tracked Buffs with 6 or more auras sat off-centre.
- **Cooldown Manager:** Essential and Utility icons could sit far to one side of their box.
- **Chat:** new and whisper windows stopped following your Fonts size.
- **Nameplates:** plates turned on in Blizzard's settings were turned off again at every login while In Combat was picked.
- **Loot Window:** Blizzard's empty Loot Window box showed beside FlareUI's in Edit Mode.
- **Settings:** opening General with **Sync Blizzard UI** off could cause an error. By AreChen.
- **Bags and Loot Window:** the German and Korean "BoE" marks were too long to fit on the icon.

### Translations
- French updated for 7.1.1. By Brainc3ll.
- Hungarian updated for 7.1.1. By Xentinus.

# FlareUI 7.1.1

Your requests, built: raid frames that size themselves to the raid, a Battleground choice in every Visibility list, and fading for party, raid and boss frames. Plus a pile of fixes from Discord.

**Restart the game fully after updating.** This version adds new files, and a /reload doesn't load them.

**We need your help testing:**
- **Raid frames:** pick a **Raid Size** in Edit Mode, change its Width, then join raids of different sizes. The frames should switch size.
- **Sync Blizzard UI:** log in on an alt. It should ask you once whether to copy, and never again.
- **Gryphons:** with Action Bar 1's Icon Size below 100%, drag them and nudge them with the arrow keys. They should move smoothly.
- **Fake Cooldown Manager:** turn on **Show Only When Ready** and use a spell with a long cooldown.

## Heads up
Some things change even if you change nothing:
- **Visibility, In an Instance:** now means dungeons and raids only. Battlegrounds and arenas have their own choice, **In a Battleground**. Every list that had In an Instance ticked gets In a Battleground ticked too, so nothing hides or shows differently.
- **Sync Blizzard UI:** no longer copies on its own.
  - Each of your other characters asks once, at its next login. After that, copy with **Copy Now**.
  - Characters that already synced aren't asked. They get one chat line instead.
  - **Hide Pop-up Alerts** is gone.
- **Quality of Life, Nameplate Combo Points:** back, and off by default. 7.1 always showed combo points on Blizzard's nameplates. Turn it on to keep them.
- **Gryphons:** if Action Bar 1's Icon Size is below 100% and you moved your gryphons, they shift once. Place them again.
- **Cooldown Manager, Growth From the Middle:** a bar with fewer spells than its Columns now stays centred. A bar pinned by its side in Edit Mode moves a little.
- **Auras:** square aura borders are thinner and use the action bars' bronze. Round aura rims use that colour too.
- **Loot Window:** in Edit Mode, Blizzard's **Loot Window** checkbox now shows and hides FlareUI's. Its default spot moved to the right side of the screen (only if you never moved it).
- **Minimap, Shared Media borders:** now as thick as on the chat and meters, and flush with the map's edge, its corners cut to fit. The Info Bar uses the same border.
- **Raid frames:** **Sample Raid** is now **Raid Size**.

## Highlights
- **Raid frames, Raid Size:** Width, Height and Power Height for raids of up to 10, 25 or 40 players. Pick the size in Edit Mode, then set them. A size you never change keeps your current values.
- **In a Battleground:** a new choice in every Visibility list: action bars, unit frames, chat, meters, the Fake Cooldown Manager and Resource Bars.
- **Fading** for Party, Raid, Boss and Flag Carrier frames, as on the other unit frames.

## New

### Unit Frames
- Party, Raid, Boss and Flag Carrier frames: a **Fading** section in Edit Mode:
  - **Visibility**, **Show Speed**, **Hide Speed**, **Faded Opacity**, **Opacity**
- Raid frames: **Raid Size** (Up to 10, 25 or 40 Players). Width, Height and Power Height are set per size. In a raid, the frames use the size that matches your group, and switch after a fight if it grows.

### Action Bars
- Fake Cooldown Manager: **Show Only When Ready** (off). A spell on cooldown hides until it's ready. Its spot stays empty meanwhile.

### Chat
- Edit Box: **Chat Style** (IM Style or Classic Style), Blizzard's own setting. Takes effect at the next reload.
- Each chat window keeps its own **Font Size**: right-click its tab.

### Buff Reminders
- Mages: a **Mana Gem** reminder. Click it to conjure the best gem you know.
- Soulstone: **Keep It On** (right-click the icon) gets **Tanks**.

### Minimap
- Addon Buttons: **Only on Mouseover** (off). The addon buttons on the minimap's edge hide until you point at the minimap or at one of them. Buttons in the drawer aren't affected.

### Loot
- Loot Rolls: a **Close** button. It clears the rolls you answered or that ended. Rolls still waiting for your choice stay.
- Loot Window: shows sample loot in Edit Mode, so you can see where it goes.

### Commands
- `/fui profile <name>` switches to that profile, for a macro on a key or a radial. Type it alone to list your profiles.

### Translations
- French, Simplified Chinese and Traditional Chinese updated for 7.1.

## Changed
- Swing bars: **Waiting State**, **Queued Attack Colour** and **Stand-Still Zone** are switches again, on by default. If you turned one off before 7.1, it's off again.
- Cast bars: a divider between the icon and the bar, in the bar's own border. On every cast bar with its icon and border on, nameplates included.
- Loot Window: a bronze close button, further right, like the chat's and quest tracker's header buttons.
- Loot Rolls: hold Shift anywhere on a roll's row to compare the item. Pressing Shift while pointing works too.
- Unit frames: the Edit Mode box now covers the portrait and the level disc.
- Border and bar texture lists never show Blizzard's own art. The Minimap's Border list included.
- Nameplates: with Platynator or MFNameplates on, FlareUI's Nameplates step aside, as with Plater.
- About and setup tour: the FlareUI Edit Mode layout code is updated.

## Fixed
- Damage Meter: Russian names showed as boxes in groups.
- Chat: Russian names showed as boxes in the whisper line ("Tell ...").
- Nameplates: combo points showed twice with another combo point addon, and on plates another addon had taken over.
- Loot Feed: the settings preview now shows Round Icons.
- Cooldown Manager: Growth From the Middle didn't stay centred with fewer spells.
- Radial Menu: Sub-Radials on **Remember** forgot the last pick.
- Loot Window: Blizzard's own loot box showed in Edit Mode next to FlareUI's.
- Loot Rolls and Loot Feed drew over Blizzard's Edit Mode window.
- Gryphons jumped around in Edit Mode with Action Bar 1 below 100% Icon Size.
- Fonts: an error after some loading screens ("calling 'GetFont' on bad self").
- Nameplates: a zoom setting could be put back on the wrong character.

# FlareUI 7.1

A big tidy-up of the settings: fewer rows, clearer names and a smarter Info Panel. Plus a batch of fixes from Discord.

**Restart the game fully after updating.** This version adds a new file, and a /reload doesn't load it.

**We need your help testing:**
- **Forever Style, rogues and druids:** build combo points on a target. They should show round the target's portrait.
- **Edit Mode:** open any unit frame. Check the new **Icons**, **Bar Effects** and cast bar **Show** lists.
- **Friendly Name Only plates with Show Target's Plate:** target a player, then clear the target. The name should show once, every time.
- **Druids with Keep Page 1 > On Shapeshift:** go into Cat and Bear Form. Action Bar 1 should stay on its first page.

## Heads up
Some things change even if you change nothing:
- **Nameplates, Click-Through:** now one setting for all plates. If you had it on for any plate type, it's now on for all of them.
- **Nameplates, Name Only Mode:** no longer greys out the other options. Show Plates in Combat and Show Target's Plate still give the plate its bar.
- **Nameplates, Crowd Control and Defensives:** their icons use the Auras look. Their own Aura Icon Shape, Aura Swipe and Aura Timer are gone.
- **Forever Style:** the name box always shows the full name, as on Blizzard's frames. Show Name is gone from Forever Style.
- **Swing bars:** Waiting State, Queued Attack Colour and Stand-Still Zone are always on.
- **Swing bars, Off-Hand Swing:** shows only with a weapon in your off hand.
- **Quest Tracker:** finished quests always show "(Complete)".
- **Buff Reminders:** the In Dungeons and In Raids timings are gone. Remind Before It Ends counts everywhere.
- **Gryphons:** now part of Quality of Life. They work with Action Bars off, and go back to Blizzard's with Quality of Life off.

## Highlights
- **Info Panel:** a small grey line under each option's title shows its default, whether it needs a reload, and what it needs to be on (in orange while that greys it out). Choice names in lists are gold, and every description was rewritten to be shorter and clearer.
- **Edit Mode, unit frames:** related switches are now one dropdown each, on every frame:
  - **Bar Effects:** Bar Animations, Bar Edge Glow, Damage Trail
  - **Icons:** resting, leader, PvP, ready check, raid markers and the rest, now in Look
  - **Show** (cast bars): Icon, Spell Timer, Centred Spell Name, Edge Glow, Latency, Spell Pushback
  - **Text** (swing, flight, seal and duration bars): Name, Timer, Icon
- **Copy Look to All Frames:** a button in each unit frame's Edit Mode window. It copies that frame's Bar Texture, Border, Absorb Texture, Background, Class Colours and Bar Effects to every other frame.

## New

### Unit Frames
- Party: cast bar **Position** (Above or Below). Auras on that side move past it.
- Flag carriers: **Range Check** (off) and, in Modern Style, **Portrait** (None or Class Icon).
- Main tank targets: **Target Border** and **Show Target Markers**, as on party targets.
- Pet: **Threat Glow** in every style, the simple pet frame too.

### Resource Bars
- Health, power and mana bars: **Values on Mouseover**.
- Druid Mana: **In Caster Form** is now a choice in its **Visibility** list.

### Nameplates
- Name Only Mode: **Show Level**, the level in front of the name.

### Action Bars
- **Keep Page 1** gets **On Shapeshift** for druids' Cat and Bear Form (off).

### Minimap
- **Border:** your Shared Media borders, under a line below FlareUI Thick. They may not line up with the map's edge.
- Round minimap: with **Below the Map** on, the Info Bar can use all three cells.

## Changed

### Settings, merged into one dropdown each
- Action Bars: **Keep Page 1** (In Stealth, In Stances, On Shapeshift) and Fake Cooldown Manager **Bars**.
- Nameplates: **Target Highlight**, **Threat Effects**, **Quest Marks** (Icon, Progress), **Kick Ready** (Colour, Mark), **Group Colours** (Party, Raid) and **Under the Name** (Title, Guild).
- Meters: **Pull Warning** (Flash, Sound; the sound can play on its own now) and **Auto Reset**.
- Chat: **Names** (Better Player Names, Better NPC Names, Level Before Names).
- Tooltips: **Guild** (Off, Name, Name and Rank).
- General: **Language**, with Game Language first.
- Bags & Looting: **Loot Window** (Off, Grow Down, Grow Up). Elixirs: **All in Your Bags** is now the top choice of **Elixirs and More**.
- Quality of Life: **Rumble** (Alerts, Procs). Buff Reminders: **Hide** (In Rested Areas, While Mounted) in Edit Mode.

### Settings, moved and renamed
- Quality of Life: Extras and Systems are one **Extras** tab. General: the General tab is now **Account**, and fonts are split into **Global Font** and **Game Fonts**.
- **Fake CM** is now **Fake Cooldown Manager** everywhere. Its note says why you'd use it over Blizzard's.
- Sizes in % are now **Scale** (Combat Text, Drawer Button, Name Only, Level Disc).
- Nameplate Font is now **World Names Font**: it sets the names over characters in the world and on Blizzard's nameplates.
- Nameplates: Health Text is **Bar Text**, Threat Percentage is **Threat Text**. Show Plates in Combat moved to Visibility.
- Tooltips: Coloured Borders and Class-Coloured Names moved to the first tab.
- Raid: the group order row is now **Group Order**, and Groups is **Orientation**.
- Many smaller regroups, so every section reads in the same order.

### Unit Frames
- **Bar Text** on mirrored frames: Left and Right in the menu are now the screen's sides. Your frames look the same as before.
- Edit Mode: **Combo Points** moved to Look. Opacity on Buff Reminders moved to Fading.

### Removed
- Pet: **Only My Debuffs** (it only emptied the list).
- Target and target of target: **Has a Target** in Visibility (always true on those frames).

## Fixed

### Unit Frames
- Forever Style: combo points didn't show on the target frame.
- The player frame's **Cast Name** and **Spell Timer** fonts showed while the Player Cast Bar was on, though they don't style it. They now hide then; the bar's fonts are under **Player Cast Bar**.

### Nameplates
- Friendly Name Only plates with **Show Target's Plate** and **Names Above Plate**: the name went missing on your target and showed twice after.

### Minimap
- The **FlareUI Minimap Button** switch was greyed out with Drawer Style Off.

### Edit Mode
- Raid: two rows were called Sort By.
- Loot Rolls: **Faded Opacity** showed above the switch that turns it on.
