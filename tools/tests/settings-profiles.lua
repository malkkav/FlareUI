-- Drive profile dialogs and the import picker through the same callbacks as the live window.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, db = ui.env, ns.db
local active = { chat = { opacity = 0.2 }, tweaks = { fasterLoot = true } }
db.sv = { profiles = { Main = active, Other = {} }, profileKeys = { player = "Main", alt = "Other" } }
db.keys = { profile = "Main" }
db.global.characters = { player = { profileName = "Main" }, alt = { profileName = "Other" } }
function db:GetCurrentProfile() return self.keys.profile end
function db:GetProfiles()
    local names = {}
    for name in pairs(self.sv.profiles) do names[#names + 1] = name end
    return names
end
function db:SetProfile(name)
    self.keys.profile = name
    self.sv.profiles[name] = self.sv.profiles[name] or {}
end
function db:CopyProfile(name) self.sv.profiles[self.keys.profile] = E.CopyTable(self.sv.profiles[name]) end
function db:DeleteProfile(name) self.sv.profiles[name] = nil end

ns.defaults.profile.chat = { opacity = 0.8, frameStyle = "modern", copyButton = false }
ns.ProfileChanges = function(saved, defaults)
    assert(saved == active and defaults == ns.defaults.profile)
    return { chat = { opacity = 0.2 } }
end
local payload, lastExport
E.Enum.CompressionMethod = { Deflate = 1 }
E.C_EncodingUtil = {
    SerializeCBOR = function(value) lastExport = value; return "cbor" end,
    CompressString = function(value, method) assert(value == "cbor" and method == 1); return "compressed" end,
    EncodeBase64 = function(value) assert(value == "compressed"); return "encoded" end,
    DecodeBase64 = function(value) assert(value == "encoded"); return "compressed" end,
    DecompressString = function(value, method) assert(value == "compressed" and method == 1); return "cbor" end,
    DeserializeCBOR = function(value) assert(value == "cbor"); return payload end,
}
local media = E.LibStub("LibSharedMedia-3.0")
function media:IsValid(_, name) return name == "Known" end
ui:load("Settings/Pages/Chat.lua", ns)
ui:load("Settings/Pages/BagsLooting.lua", ns)
ui:load("Settings/Pages/Advanced.lua", ns)
local D = ns.Dialogs

D.FLAREUI_NEW_PROFILE.OnAccept(nil, " Other ")
assert(#ui.errors == 1 and db:GetCurrentProfile() == "Main", "an existing profile cannot be created over")
D.FLAREUI_DUPLICATE_PROFILE.OnAccept({ from = "Main" }, "  Backup  ")
assert(db:GetCurrentProfile() == "Backup" and db.sv.profiles.Backup ~= active and db.sv.profiles.Backup.chat.opacity == 0.2,
    "duplication trims the new name and copies the selected profile")
D.FLAREUI_DELETE_PROFILE.OnAccept({ name = "Backup" })
assert(db.sv.profiles.Backup == nil, "accepting delete removes the selected copy")

db:SetProfile("Main")
D.FLAREUI_RENAME_PROFILE.OnAccept({ from = "Main" }, "Renamed")
assert(db:GetCurrentProfile() == "Renamed" and db.sv.profiles.Renamed == active and not db.sv.profiles.Main,
    "renaming moves the existing profile table")
assert(db.sv.profileKeys.player == "Renamed" and db.global.characters.player.profileName == "Renamed"
    and db.sv.profileKeys.alt == "Other" and db.global.characters.alt.profileName == "Other",
    "only characters using the old name follow the rename")

assert(D.FLAREUI_EXPORT_PROFILE.editText() == "FlareUI1:encoded")
assert(lastExport.name == "Renamed" and lastExport.profile.chat.opacity == 0.2 and lastExport.addon == "FlareUI",
    "export frames the addon version, name, and profile changes")
D.FLAREUI_IMPORT_PROFILE.OnAccept(nil, "5 0 59 UIParent")
assert(ui.errors[#ui.errors]:find("Edit Mode layout code", 1, true))
D.FLAREUI_IMPORT_PROFILE.OnAccept(nil, "FlareUI1:broken")
assert(ui.errors[#ui.errors]:find("isn't a FlareUI profile", 1, true))
payload = {
    addon = "FlareUI", name = "Renamed", version = "9.1-beta3", uiScale = 0.9,
    profile = {
        chat = { opacity = 0.4, copyButton = "wrong type", font = { face = "Missing Face" }, columns = 200 },
        tweaks = { fasterLoot = false, other = string.rep("x", 513) },
        extra = { count = 2, invalidNumber = math.huge },
    },
}
D.FLAREUI_IMPORT_PROFILE.OnAccept(nil, "  FlareUI1:encoded  ")
assert(not E.FlareUI_ImportPicker, "the picker appears after the input dialog closes")
ui:flushTimers()
local picker = assert(E.FlareUI_ImportPicker)
assert(picker:IsShown() and picker.name:GetText() == "Renamed (2)", "the picker suggests a unique name")
assert(picker.info:GetText():find("newer than yours", 1, true) and picker.info:GetText():find("0.90", 1, true))
assert(#picker.checks == 3 and picker.missing:GetText():find("Missing Face", 1, true),
    "the picker separates importable parts and reports missing media")
picker.checks[1]:Click()
assert(picker.missing:GetText() == "", "clearing the owning part clears its missing media warning")
picker.checks[1]:Click()
picker.checks[2]:Click()
picker.checks[3]:Click()
picker.intoRadio:Click()
assert(not picker.name:IsEnabled(), "importing into the current profile disables the new name")
picker.import:Click()
assert(not picker:IsShown() and ui.dialogs[#ui.dialogs].key == "FLAREUI_RELOAD")
assert(active.chat.opacity == 0.4 and active.chat.frameStyle == "modern" and active.chat.copyButton == false and active.chat.columns == nil,
    "selected roots merge with defaults and discard the invalid boolean and oversized count")
assert(active.tweaks.fasterLoot and active.extra == nil, "unticked parts are untouched")

ns.ShowImportPicker(payload)
picker.import:Click()
local imported = db.sv.profiles["Renamed (2)"]
assert(db:GetCurrentProfile() == "Renamed (2)" and imported.chat.opacity == 0.4 and imported.extra.count == 2)
assert(imported.tweaks.fasterLoot == false and imported.tweaks.other == nil and imported.extra.invalidNumber == nil,
    "a new profile keeps valid false values and removes invalid lengths and numbers")

print("PASS: profile dialogs, selective import, defaults and validation")
