-- Blizzard font overrides keep stock metrics and can be restored after a late-loaded font pack.
local setup = dofile("tools/tests/fixtures/settings-addon.lua")
local ui, ns = setup()
local E, S, GF = ui.env, ns.Settings, ns.GameFonts
local game = E.CreateFont("GameFontNormal")
game:SetFont("stock/game.ttf", 15, "OUTLINE")
local plate = E.CreateFont("SystemFont_NamePlate")
plate:SetFont("stock/nameplate.ttf", 12, "")
local korean = E.CreateFont("GameFontNormalKorean")
korean:SetFont("stock/kr.ttf", 17, "THICKOUTLINE")
local own = E.CreateFont("FlareUI_Own")
own:SetFont("stock/addon.ttf", 13, "")
function game:GetFontObjectForAlphabet(alphabet) if alphabet == "korean" then return korean end end
ns.FontFamily = { alphabets = { "roman", "korean" } }
ns.SetFontObjectFaceUnscaled = function(object, path, size, flags) object:SetFont(path, size, flags) end
local defaultDamage = "stock/damage.ttf"
E.DAMAGE_TEXT_FONT, E.UNIT_NAME_FONT = defaultDamage, "stock/unit.ttf"
E.GetFonts = function() return { "GameFontNormal", "SystemFont_NamePlate", "FlareUI_Own", "MissingFont" } end

local db = {
    gameText = true,
    nameplate = { face = "Optional Pack" },
    combat = { face = "Custom Combat", path = "stock/cached-combat.ttf" },
    files = { ["Optional Pack"] = "pack/cached-plate.ttf" },
}
ns.db.profile.fonts = db
local media = E.LibStub("LibSharedMedia-3.0")
local packLoaded = false
function media:Fetch(_, name)
    if name == "Optional Pack" then return packLoaded and "pack/loaded-plate.ttf" or nil end
    return "stock/global.ttf"
end
GF.OnLoad()
local face, size, flags = game:GetFont()
assert(face == "stock/global.ttf" and size == 15 and flags == "OUTLINE", "game fonts retain size and outline")
assert(korean:GetFont() == "stock/kr.ttf" and own:GetFont() == "stock/addon.ttf", "language-specific and addon-owned fonts stay intact")
assert(plate:GetFont() == "pack/cached-plate.ttf" and E.UNIT_NAME_FONT == "pack/cached-plate.ttf")
assert(E.DAMAGE_TEXT_FONT == "stock/cached-combat.ttf" and not GF.Stale(), "cached media is available before the font pack registers")

local calls = 0
S:Module{ key = "test", enabled = "test.enabled" }
S:SetPath("test.enabled", true)
local function restyle() calls = calls + 1 end
local family = { face = "Custom", size = 15, flags = "OUTLINE" }
local original = { face = "Custom", size = 15, flags = "OUTLINE" }
S:FontRows{ module = "test", apply = restyle, fonts = {
    { key = "text", font = function() return family end, default = function() return original end },
    { key = "more", path = "test.font", noSize = true },
} }
assert(not S:AnyFontChanged())
packLoaded = true
assert(GF.Stale())
ui:emit("PLAYER_ENTERING_WORLD")
assert(db.combat.path == "Fonts/Custom Combat" and plate:GetFont() == "pack/cached-plate.ttf",
    "entering world saves combat text for next login and defers the refresh")
ui:flushTimers()
assert(plate:GetFont() == "pack/loaded-plate.ttf" and db.files["Optional Pack"] == "pack/loaded-plate.ttf" and calls == 1)
game:SetFont("STOCK\\GLOBAL.TTF", 15, "OUTLINE")
assert(not GF.Stale(), "capitalization and slash direction do not mark the same font stale")
plate:SetFont("other/addon.ttf", 12, "")
assert(GF.Stale(), "another addon changing nameplate font calls for a redraw")
S:UseGlobalFontEverywhere()
assert(family.face == ns.GLOBAL_FONT and family.size == 15 and family.flags == "OUTLINE" and calls == 2,
    "global face updates every module only once while keeping configured metrics")
local heading = S.rows["test.font.text"]
assert(heading.reset.can())
heading.reset.run()
assert(family.face == "Custom" and family.size == 15 and calls == 3)

db.gameText = false
db.nameplate.face = ""
korean:SetFont("other/kr.ttf", 11, "")
GF.Apply(false)
assert(game:GetFont() == "stock/game.ttf" and plate:GetFont() == "stock/nameplate.ttf"
    and korean:GetFont() == "stock/kr.ttf" and E.UNIT_NAME_FONT == "stock/unit.ttf",
    "clearing overrides restores Blizzard's original files and alphabet members")
db.combat.face = ""
GF.SaveCombatPath()
assert(db.combat.path == nil)

print("PASS: game fonts, cached media, font family snapshots and global face")
