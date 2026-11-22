# FlareUI 7.0.2

A quick hotfix for four things 7.0.1 broke or missed. Thanks for reporting them so fast.

## Fixed
- **Quest Tracker:** a left click on a quest opens it again. 7.0.1 only showed "Open your quest log to read this quest" for most quests.
- **Bags:** the crafting bag shows its items in the combined backpack again (**Crafting Bag in Backpack**). 7.0.1 left the section empty when you opened only the backpack.
- **Nameplates:** **Full Name** is a choice in the plate's **Health Text**, so friendly players can show their surname. 7.0.1 drew it but left it out of the list.
- **Nameplates:** the raid marker sits right beside full plates. The **Defensives** icons now go past it instead of pushing it far to the left.

# FlareUI 7.0.1

Sorry, everyone. The new nameplates came with more bugs than they should have, and the fixes took longer than I wanted. This update fixes every nameplate bug you reported, plus a long list of other fixes. Thank you for your patience and for all the reports.

A big thank you to this release's contributors: **alex47** (the Items section, Healing & Damage, the preview fix), **parchinskiy** (collapsible backpack sections), **Braincell1980** (the French translation) and **Archy** (the complete Russian translation).

## Heads up
Some things look or work differently even if you change nothing:
- **Quest Tracker:** the right-click menu no longer has **Open Quest Log** or **Show on Map**. A left click on a quest opens both.
- **Chat:** **Border** now only borders the chat window. The edit box has its own border option and keeps the look it had.
- **Chat:** the Combat Log tab can be moved like any other tab. General stays first.
- **Tooltips:** **Show Item Level**, **Compare with Shift** and **Simplified Item Stats** moved to a new **Items** section on the Content tab.

## Highlights
- **Nameplates:** every bug you reported is fixed, including the stutter when combat starts and ends.
- **Bags:** collapsible backpack sections, and filling crates from the crafting bag works again.
- **Nameplates:** NPC titles like "General Goods" under Name Only names.

## New

### Nameplates
- NPC titles under the name on Name Only plates, in a soft tan. Always on.
- **Threat Percentage** now shows during fights.

### Bags
- Click a section header in **Category Rows** and **Category Rows + Sets** to collapse or expand it. By parchinskiy.
  - Each character remembers its own sections.

### Tooltips
- **Items** section on the Content tab. By alex47.
- **Healing & Damage** (Off): shortens item lines with both healing and damage. By alex47.
  - **Spell Healing / Spell Damage:** both numbers as they are.
  - **Spell Healing / Spell Power:** the damage as Spell Power, plus the extra healing.

### Chat
- **Edit Box Style** (Modern):
  - **FlareUI:** Blizzard's own edit box, in FlareUI's bronze.
  - **Modern:** a dark box.
- **Edit Box Border** (follows your old chat border): **None**, **FlareUI Thick** or **FlareUI Thin**. Shows with Modern only.

### Resource Bars
- **Paladin Seals:** **Show Icon** (off) in Edit Mode puts the seal's icon at the bar's left end.

### Buff Reminders
- **Warlock pet:** right-click the icon to pick the demon a click summons: **Last Used** (default) or any demon you know.
- Every icon's right-click menu has a **FlareUI Settings** link.

### Quest Tracker
- The **Voice Button** also plays quest lines from Wayfarer (Russian voice-over).

### Minimap
- **Info Bar:** gold shows with coin icons, like in your bags.

## Changed
- **Unit Frames (Forever Style):** your own name box takes your class colour when that frame's **Class Colours** is on, as on target and party.
- **Languages:**
  - Russian: complete (739 new strings). By Archy.
  - French: 7.0 strings translated. By Braincell1980.
- **Russian client:** a dash replaces the middle dot "·", which Russian fonts draw as a box.

## Fixed

### Nameplates
- A stutter when combat started and ended.
- **Show Friendly Plates** reset to Off when you picked **Always**. **In Combat** and Quality of Life's **Combat Friendly Plates** didn't work either.
- Chairs, signs, mailboxes and herb or ore nodes got enemy plates.
- Pet and minor names were tiny, even at 200%.
- **Full Name** in Bar Text showed only the first name.
- The raid marker sat far from the name on Name Only plates.
- Friendly players showed two names with the Musician addon.
- Quest marks stayed beside plates when another nameplate addon was running, and couldn't be turned off.

### Bags
- Filling a crate, milling or prospecting from the crafting bag was blocked (**Crafting Bag in Backpack**).

### Quest Tracker
- After you opened a quest from the tracker, the world map could be blocked in a fight.

### Gamepad
- A "blocked action" popup after closing Edit Mode. In Gamepad mode, Edit Mode dropdowns and colour swatches now open FlareUI's own lists. Colour swatches offer ready colours.

### Chat
- The chat tabs took clicks meant for quest, merchant and crafting windows above them.

### Other
- **XP Bar:** a small gap stayed at the bottom of the screen.
- **Settings previews:** squeezed previews cut their text short. By alex47.

# FlareUI 7.0

**Restart the game fully after updating** (not just /reload): this version adds new files.

FlareUI now draws its own nameplates. Every kind of unit gets its own look: enemy players and NPCs, friendly players and NPCs, and minor mobs with pets and totems. Open-world PvP gets full plates, quest givers get a clean name, and you can tweak every one of them with a live preview at your side. The chat also learned a few tricks, and unit frames can show the name above the frame.

## Heads up
Some things look or work differently even if you change nothing:
- **Chat:** a popped-out chat window now fades on its own. It comes back for its own messages only, not for every line in every window.
- **Visibility Never:** a frame set to Never no longer shows tooltips when you point where it is.
- **Radial Menus:** the **Mounts** catalog is now **Collections**, with your mounts and your toys.

## Highlights
- **Nameplates:** FlareUI's own nameplates, with a setup for each unit type.
- **Name Above Plates:** the name above any unit frame, so the bars stay clean.
- **Chat:** fade old lines one by one, and quiet loot and skill-ups.

## New

### Nameplates (new page, off)
- First in the Combat list. A /reload turns it on or off.
- **Unit types**, each with its own setup: **Enemy Player**, **Enemy NPC**, **Friendly Player**, **Friendly NPC** and **Minor** (minor mobs, pets, totems and guardians).
- **Presets** for each unit: **Full**, **Simple**, **Minimal**, **Name Only**. Change any setting and it becomes that unit's own Custom.
  - Friendly players and NPCs start on Name Only.
- **Live Preview** beside the settings, and **Test in Game** to put the look on the plates around you.
- **Plate:** size, **Background Opacity**, **Bar Texture**, **Border**, **Level**, **Bar Effects**, **Colour By**, **Health Text**.
  - **Name Only Mode**: just the name, with **Name Only Size**.
  - **Show Plates in Combat**: picked units leave Name Only in a fight.
- **Extras:**
  - Icons: **Elite & Rare**, **Combo Points**, **Quest Objective**, **Quest Progress**.
  - Threat: **Colour by Threat**, **Role**, **Threat Glow**, **Aggro Flash**, **Threat Scale**, **Threat Percentage**.
  - Colours: **Execute Range**, **Colour Mob Types**, **Party Colour**, **Raid Colour**.
- **Cast Bar:** icon, timer and target, **Kick Ready Colour**, **Kick Ready Mark**, **Flash When Targeted**, **Highlight Important Casts**.
- **Auras:** buffs, debuffs, **Defensives** and **Crowd Control**, each with size and count.
- **Targeting** (all plates): target and non-target scale and opacity, **Out of Range** and **Out of Sight** fading, target **Arrow**, **Border**, **Bar Colour**, **Outer Glow** and **Focus Colour**.
- **Visibility** (all plates):
  - Which enemies and friends get a plate, **Stacking**, **Keep Target on Screen**, **Click-Through**.
  - **Name Only While Unattackable** (off): enemy NPCs you can't attack yet show only their name.
  - The game's names over heads: **NPC Names**, **Player Names**, **Minion Names**.
- **Nameplate Colours** in FlareUI's colour window, and a Fonts tab.
- `/fui plates` prints what the module sees, for bug reports.

### Unit Frames
- **Name Above Plates** (Off), in the Text section in Edit Mode: First Name or Full Name above the frame, on the left, centre or right.
  - Auras and a cast bar above the frame move up to make room.
  - On the player, target, focus, pet, target of target, target of focus, party, boss and flag carrier frames. Not on Forever Style, which has its name box.

### Chat
- **Only Chat Messages**: a new Visibility choice. Only lines people write bring the chat back; loot, skill-ups and XP stay quiet.
- **Fade Old Lines** (off), under Fading in Edit Mode: lines fade one by one, oldest first. Pointing at the chat or typing brings them back.

### Visibility
- **Not in a Capital City**: last on every Visibility list, the reverse of In a Capital City.
- **Fade Delay** goes up to 1 minute (chat and meter).

### Radial Menus
- **Collections** catalog: mounts, then toys.
- Small titles split the catalog's lists: Mounts and Toys, Spells and Pet Spells, Target and World Markers, General and Character Macros, Professions and Profession Spells.

### Other
- **XP Bar:** **Show Tooltip** (off) brings the bar's tooltip back.
- `/fui buff` opens the Buff Reminders settings.

## Changed
- Settings text: clearer descriptions and tips, using the options' real names.
- Faster in several places: nameplate colours, buff reminder aura checks, resource bar text and the heal bars on party frames.
- French: the 6.14 phrases. By Brainc3ll.

## Fixed
- Chat: the mouse wheel scrolls the chat again, also when the game's own chat scroll setting is off.

# FlareUI 6.14

**Restart the game fully after updating** (not just /reload): this version adds new files.

A new page joins the Combat list: **Cooldowns**, built by brudi, brings FlareUI's look and a few handy extras to Blizzard's Cooldown Manager. Your backpack can now sort itself into rows, and the Edit Mode windows finally stay where you put them.

## Heads up
Some things look or work differently even if you change nothing:
- **Skin Cooldown Manager** moved from Action Bars to the new **Cooldowns** page. If it was on, Cooldowns is on too.
- **Category Filters** is now a choice in **Bag View** (Bags & Looting › Bag Window). If you had filters on, you get Category Filters: the buttons by the search box when there's room, the drawer otherwise.
- **XP Bar:** **FlareUI XP Bar** is now called **Bar Style**, and its tooltip is gone. It covered the bar's own text.
- **Edit Mode:** settings windows no longer jump next to the frame you click. They open at the top right, then wherever you last dragged one.

## Highlights
- **Cooldowns:** Blizzard's Cooldown Manager in FlareUI's style. By brudi.
- **Bag View:** the combined backpack sorted into category rows. By andrzejskibinski.
- **In a Capital City:** a new Visibility condition on every frame.

## New

### Cooldowns (new page, off)
- First in the Combat list. It changes Blizzard's own Cooldown Manager bars.
- **Cooldown Manager** section:
  - **Enable Blizzard Cooldown Manager**: the same switch as in the game's options.
  - **Advanced Cooldown Settings**: opens Blizzard's window where you pick what each bar tracks.
- **Skin Cooldown Manager** (off): Tracked Bars like FlareUI's cast bars, icons with FlareUI's borders.
- **Bar Colour**: the Tracked Bars' colour, in FlareUI's colour window.
- Icons (all off):
  - **Show Keybind Text**: your keybinds on the Essential and Utility icons.
  - **Show Button Presses**: an icon lights up while you hold its key.
  - **Soften Active Overlay**: a faint swipe over a running effect, so you can see the icon.
  - **Show Cooldown During Effect**: the ability's own cooldown in the icon's corner.
- Fonts tab: **Keybinds**, **Counts**, **Cooldown Numbers** and **Bar Text**.
- Edit Mode, on each Cooldown Manager bar:
  - **Growth** (Blizzard): Tracked Buffs and Tracked Bars packed together, growing right, left, down, up or from the middle.
  - **Icon Shape** (Square): Square or Rectangle.
  - **Fading**, as on every other frame.

### Bags
- **Bag View** (All Items), in Bags & Looting › Bag Window:
  - **Category Filters**: the filter buttons, as before.
  - **Category Rows**: the combined backpack in sections: Quest Items, Equipment, Materials, Consumables, Junk and Other.
  - **Category Rows + Sets**: a section for each equipment set too.
- The **+** button (more bag space) sits at the left end of the gold bar.

### Visibility
- **In a Capital City**: last on every Visibility list. Shows the frame in Stormwind, Ironforge, Darnassus, Orgrimmar, Thunder Bluff and Undercity.

### Edit Mode
- The FlareUI layout code (About page and setup tour) has the new layout.

## Changed
- Settings window: a little taller, so every page fits in the list.
- Minimap › Addon Buttons: the preview follows **Drawer Button Size**, **FlareUI Minimap Button** and **Drawer Style** as you change them. By parchinskiy.
- XP Bar settings: **Bar Texture**, **Border**, **Separators** and **Pick Your Colours** sit right under **Bar Style**.
- French: the 6.13 phrases. By Brainc3ll.

## Fixed
- Custom fonts: text drawn before its font loaded no longer stays blank after login (the Info Bar, keybinds and more).
- Chat: the **Copy Chat** button opens Copy Chat again.
- Quest Tracker: a plain "Ready for turn-in" line is grey, as on Blizzard's tracker.
- Quest Tracker on Visibility **Never**: no more tooltips or clicks where it was.
- Buff Reminders: the food reminder remembers food you eat anywhere, also from /use macros.
- Fake CM: its Visibility names were one place off.

# FlareUI 6.13

**Restart the game fully after updating** (not just /reload): this version adds new art files.

A huge thank-you to parchinskiy, a great collaborator who tracked down and fixed the hardest bug we've had so far: the bags breaking your clicks after a bank visit. This patch is also the big settings clean-up: every page and Edit Mode window got the same order, the same words and the same rules, and the unit frames now offer the same options in every style.

## Heads up
Some things look or work differently even if you change nothing:
- **Vendor** options moved to **Bags & Looting**, and now follow that page's switch. If Bags & Looting is off, turn it on to keep Auto Sell Junk, Auto Repair and the rest.
- **Quest Tracker:** the new **Colour Scheme** starts at **FlareUI**: softer, bronze-toned colours on the FlareUI and Modern styles. Pick **Blizzard** for the old colours.
- **Quest Tracker:** new installs start with the **Modern** style. Your current style stays as it is.
- **Names on unit frames:** outside Forever Style, the name is now a pick in **Health Text** only. If you had **Show Name** off, the name is back: untick it in Health Text.
- **Party (Classic) and boss frames:** **Health Text** and **Power Text** are now the Left / Centre / Right picker. Your old choice carries over.
- **Gryphons:** the **Same as Action Bar 1** Visibility choice is gone. Gryphons that used it now join bar 1's fade group, or copy its Visibility.
- **Minimap drawer:** **Addons in the Drawer: None** now keeps every addon button on the minimap's edge. **Drawer Style: Off** turns the drawer off. If you had None, your drawer is now set to Off.
- **Bar textures** renamed: FlareUI Forever is **FlareUI Dark**, FlareUI Forever (Light) is **FlareUI Light**. Your picks carry over.
- **Aura Swipe** and **Aura Timer** left the Buffs and Debuffs Edit Mode windows: set them in Settings › Buffs & Debuffs. The totems' are in Buffs & Debuffs › **Totems**.
- **Shields** over health bars are lighter (40%, was 75%), so the health under them shows.

## Highlights
- **Settings clean-up:** dropdowns, then sliders, then switches everywhere; one word for each idea; fewer, clearer sections.
- **Unit frame parity:** the same options on every frame and style where they make sense.
- **Chat and Meters:** the FlareUI **Frame Style**.
- **Loot Feed:** square or round icons with a border in the item's quality colour.
- **Values on Mouseover:** health and power numbers only while you point at a frame, as Blizzard's option.

## New

### Unit Frames
- **Values on Mouseover** (off), in each frame's Text section in Edit Mode: health and power numbers show only while you point at the frame. On every unit frame, party, raid, boss and flag carrier frame.
- **Level Disc Size** (100%), in each frame's Text section, FlareUI and Forever Style, with **Show Level** on. It replaces the one slider in Settings. By SSyl.
- **Show Combat Text** (off), player and pet, FlareUI and Forever Style: Blizzard's hit and heal numbers on the portrait. Its font is in Unit Frames › Fonts › **Combat Text**.
- **Portrait Scale** (100%) is back on FlareUI Style frames, now on party, boss and flag carrier frames too.
- **Show Weapon Enchants** (on), player frame: the enchants follow **Hide Buffs** too.
- **Combo Points** is one dropdown in every style: **Off**, **Classic** (the gems) or **Modern** (a bar). Forever Style's gems can now be turned off.
- Focus frame: **Leader**, **PvP Flag** and **Quest Objective** icons, as on the target frame.
- Target and focus: **Dispel Highlight** (Off), for a friendly unit you can dispel.
- Pet frame: **Range Check** (off).
- Boss frames: **High Level Skull** (on), FlareUI and Forever Style.
- Flag carrier frames: **Class Colours**.
- Party, boss and flag carrier cast bars: their own **Background**; boss and flag carriers also get **Position** (Above or Below). Cast bar **Height** goes up to 40 on every frame.
- Main Tanks: **Target Frame Width** and **Target Frame Height** for Tank Targets (Auto follows the tank's frame).
- Player Cast Bar: **Show Speed** and **Hide Speed** in its Fading.
- Mirror Bars has a description.

### Chat
- **Frame Style** (Modern): **FlareUI** puts the quest tracker's look on the chat.
- **Whisper Sound** (Off): Raid Warning, Alarm or Whisper. The speaker button plays it.
- Middle-click a whisper tab to close it.
- **Icons** dropdown: **Item and Spell Icons**, **Race Icons**, **Class Icons** (were three switches).
- **Notifications** section: **Tab Glow** and **Whisper Sound**.

### Meters
- **Frame Style** (Modern), as on the chat.
- **Bar Texture** (Blizzard).
- **Threat Window**: **Off**, **Separate Window** or **In the Meter in Combat** (were two switches).

### Quest Tracker
- **Colour Scheme**: **Blizzard** or **FlareUI** (default).
- **Header Buttons**: **Filter**, **Sort**, **Auto Accept** and **Auto Turn-In** box buttons on the header.
- **Hide Scroll Bar** (off).
- **Auto Minimize** dropdown: **In Instances**, **In Combat**, **On Flight Paths** (new).
- **Show Untracked Quests** works without Zone Headings: the untracked ones come after your tracked quests.

### Bags & Looting
- **Loot Feed** is now **Off**, **Square Icons** or **Round Icons**. Each icon has a border in the item's quality colour.
- Loot Feed: **Scale** in its Edit Mode window.
- **Skin Item Slots**: **Colour by Rarity** is back, under a line in the dropdown (on).

### Buffs & Debuffs
- **Aura Filters** (was Hide Auras): each spell can be **Hide** or **Show**. Shown spells get their own row and skip the other filters.
- **Totems** section: **Aura Swipe** and **Aura Timer** for your totems.
- **Never** in the Visibility of the buff and debuff frames.

### Buff Reminders
- A reminder waits while its spell is on cooldown (Fear Ward).
- Food: a click eats the food that last gave you Well Fed.
- **Upkeep** dropdown (was six switches), with **Weapon Oil / Stone** in it.
- **Icon Alerts** dropdown in Edit Mode: **Glow When Missing**, **Glow When Running Out**, **Time Left**.

### Minimap
- **Minimap Icons** section: one **Icons** dropdown (**Sundial**, **Group Finder**, **Vehicle Exit**, **Durability Warning**) and **Reset Minimap Icons**.
- Info Bar: **Experience**.
- Happy Camper and Lore Forever buttons sit in the minimap's button row.
- The day/night sundial lights up under your mouse and has a tooltip. By parchinskiy.

### Action Bars
- Gryphons: **Scale** in each gryphon's Edit Mode window.
- XP Bar: **Bar Texture** and **Border** are in Settings › Action Bars › XP Bar (were in Edit Mode).

### Everywhere
- **Never** in every Edit Mode Visibility, first in the list. A unit frame on Never takes no clicks.
- Sound dropdowns have a speaker button that plays the sound.

## Changed

### Settings
- Every page and Edit Mode window: dropdowns first, then sliders, then switches.
- Options that depend on another one sit in line and grey out, no longer indented.
- Names, one word per idea:
  - **Background Opacity** (was Frame Opacity), **Scale** for sizes in %, **Max Buffs** and **Max Debuffs** (were Buff Amount and Debuff Amount), **Border** on cast bars (was Border Texture), **Centre**, **Off** first in every list.
  - **Sync Blizzard UI**, **Keep Page 1 in Stances**, **Threat Text** (was Show Threat, now in the Text section), **At the Cursor** (Tooltips, was Mouseover), **Show My Frame in a Party / Raid** (were Hide Player Frame).
  - Fonts: **Counts**, **Macro Text**, **Spell Timer**.
  - Section names: **Bars**, **Buttons**, **Spell Behaviour**, **Frames**, **Controller**, **Consumables**, **Auras** and **Ordering**.
  - Unit frame aura places read **Above the Frame**, **Below the Frame, Left** and so on.
  - Quest Tracker style **Custom** is **Modern**; Unit Frames **Addon Style** is **Modern Style**; borders **FlareUI Thin** and **FlareUI Thick**.
- Quality of Life's **Interface** tab is now **Extras**.
- Minimap sections: **Look**, **Info Bar**, **Tweaks**, **Minimap Icons**, **Addon Buttons**.
- Quest Tracker tabs: **Frame**, **Behaviour**, **Fonts**; **Header Buttons** moved to Frame.
- Buff Reminders: the **Alerts** tab joined **When and Where**.
- Portrait, Flip Portrait and Mirror Bars moved to each frame's **Look** section in Edit Mode.
- Simple Pet Frame, Simple Target of Target and Level Disc Size are hidden in Modern Style, where they do nothing.
- Edit Mode rows that do nothing on a Fake Cooldown Manager bar are hidden there.
- Aura sizes: 8 to 48 on every frame (raid tiles 8 to 30).
- Meters: **Match Chat Size** and the Meter Tab rows grey out with Chat off, instead of hiding.
- **Open Flight Map at Once** moved to Map & Mail.

### Look
- One bronze for the ring styles' frames, rings and boss dragons, and for the minimap's Blizzard art.
- Warmer colours across the settings, tooltips and windows; aura borders a lighter bronze.
- Bronze header icons on the chat, meters and loot rolls are darker.
- Quest Tracker: a plain "Ready for turn-in" line is grey, as Blizzard's.

## Fixed
- **Bags:** after a bank visit, right-clicks on items stopped working (Cozy Sleeping Bag, bank tabs). The keyring and crafting bag now use Blizzard's own clicks. By parchinskiy.
- Gryphons faded with action bar 1 whatever their Visibility said.
- Raid frames: Width and Height only moved the gaps with Tank Targets on.
- Chat: an error when switching tabs in a fight; an error in the tab bar under combat restrictions.
- Edit Mode: an error with hidden auras under restrictions.
- Minimap FlareUI Thin and Thick borders: the map's corners now follow the border's angled corners.
- Minimap drawer: takes buttons from EnhanceQoL and HidingBar. By AreChen.
- Info Bar dividers stay one pixel wide at any UI scale. By Celbrund.
- Small action buttons (stance, pet, possess, totem): thinner border, no overlap. By Celbrund.
- Radial Menu: Sub-Radials reset on close kept the last button's name and icon.
- Radial emote labels in Russian lost their first letter.
- Keybinds sometimes missing at the first login.
- The layout restore box: Not Now keeps your layout, and a restore that didn't stick isn't offered again.
- Details! chat embed fits FlareUI's chat window.
- Quest Tracker: lines kept their old colours after a Colour Scheme switch.
- Totem Bar Scale showed with Action Bars off.

## Translations
- **Hungarian**, new. By Xentinus. Loot roll buttons use FlareUI's Need, Greed, Pass and Transmog words where your language has them.
- French: the 6.12 phrases. By Brainc3ll.

---

Older versions (6.12 and before): [CHANGELOG-history.md](CHANGELOG-history.md).
