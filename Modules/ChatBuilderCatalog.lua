local _, ns = ...
local L = ns.L

-- Message-group tokens match Forever's ChatConfigFrame.lua. Availability is checked at runtime.
-- These are filter templates, never startup defaults or whole-layout replacements.
ns.ChatBuilderCatalog = {
    categories = {
        { key = "conversations", name = L["Conversations"], entries = {
            {"SAY", L["Say"]}, {"YELL", L["Yell"]}, {"EMOTE", L["Emotes"]},
            {"WHISPER", L["Whispers"]}, {"BN_WHISPER", L["Battle.net whispers"]},
            {"GUILD", L["Guild"]}, {"OFFICER", L["Officer"]}, {"GUILD_DISCORD", L["Guild Discord"]},
            {"GUILD_ACHIEVEMENT", L["Guild announcements"]}, {"ACHIEVEMENT", L["Achievements"]},
            {"VOICE_TEXT", L["Voice transcription"]},
        } },
        { key = "groups", name = L["Groups"], entries = {
            {"PARTY", L["Party"]}, {"PARTY_LEADER", L["Party leader"]},
            {"RAID", L["Raid"]}, {"RAID_LEADER", L["Raid leader"]}, {"RAID_WARNING", L["Raid warnings"]},
            {"INSTANCE_CHAT", L["Instance"]}, {"INSTANCE_CHAT_LEADER", L["Instance leader"]},
            {"PING", L["Pings"]}, {"BG_HORDE", L["Battleground: Horde"]},
            {"BG_ALLIANCE", L["Battleground: Alliance"]}, {"BG_NEUTRAL", L["Battleground: Neutral"]},
        } },
        { key = "channels", name = L["Public Channels"], entries = {} },
        { key = "rewards", name = L["Rewards & Progress"], entries = {
            {"LOOT", L["Item loot"]}, {"CURRENCY", L["Currency"]}, {"MONEY", L["Money loot"]},
            {"COMBAT_XP_GAIN", L["Experience"]}, {"COMBAT_HONOR_GAIN", L["Honor"]},
            {"COMBAT_FACTION_CHANGE", L["Reputation"]}, {"SKILL", L["Skill gains"]},
            {"TRADESKILLS", L["Tradeskills"]}, {"OPENING", L["Opening"]},
            {"COLLECTED_APPEARANCE", L["Appearance collection"]},
        } },
        { key = "system", name = L["System"], entries = {
            {"SYSTEM", L["System messages"]}, {"ERRORS", L["Errors"]}, {"IGNORED", L["Ignored"]},
            {"CHANNEL", L["Channel notices"]}, {"TARGETICONS", L["Target icons"]},
            {"BN_INLINE_TOAST_ALERT", L["Blizzard service alerts"]}, {"PET_INFO", L["Pet information"]},
            {"COMBAT_MISC_INFO", L["Miscellaneous combat information"]},
        } },
        { key = "npcs", name = L["NPCs & Encounters"], entries = {
            {"MONSTER_SAY", L["NPC say"]}, {"MONSTER_EMOTE", L["NPC emotes"]},
            {"MONSTER_YELL", L["NPC yell"]}, {"MONSTER_WHISPER", L["NPC whispers"]},
            {"MONSTER_BOSS_EMOTE", L["Boss emotes"]}, {"MONSTER_BOSS_WHISPER", L["Boss whispers"]},
        } },
    },
    presets = {
        {id="general", name=L["General"], messages={"SAY","YELL","EMOTE","WHISPER","BN_WHISPER","GUILD","PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER","SYSTEM","MONSTER_SAY","MONSTER_YELL","MONSTER_EMOTE","MONSTER_WHISPER","MONSTER_BOSS_EMOTE","MONSTER_BOSS_WHISPER"}, channels={"zone:1","zone:22"}},
        {id="social", name=L["Friends & Guild"], messages={"SAY","YELL","EMOTE","WHISPER","BN_WHISPER","GUILD","OFFICER","GUILD_DISCORD","GUILD_ACHIEVEMENT","ACHIEVEMENT"}, channels={}},
        {id="group", name=L["Party & Raid"], messages={"PARTY","PARTY_LEADER","RAID","RAID_LEADER","RAID_WARNING","INSTANCE_CHAT","INSTANCE_CHAT_LEADER","WHISPER","BN_WHISPER","MONSTER_BOSS_EMOTE","MONSTER_BOSS_WHISPER","PING","BG_HORDE","BG_ALLIANCE","BG_NEUTRAL"}, channels={}},
        {id="loot", name=L["Loot"], messages={"LOOT","CURRENCY","MONEY","COMBAT_XP_GAIN","COMBAT_HONOR_GAIN","COMBAT_FACTION_CHANGE","SKILL","TRADESKILLS","OPENING","COLLECTED_APPEARANCE"}, channels={}},
        {id="trade", name=L["Trade"], messages={"WHISPER","BN_WHISPER"}, channels={"zone:2","zone:42"}},
        {id="blank", name=L["Blank"], messages={}, channels={}},
    },
    channelNames = { ["zone:1"]=L["General"], ["zone:2"]=L["Trade"], ["zone:22"]=L["Local Defense"], ["zone:42"]=L["Services"] },
}
