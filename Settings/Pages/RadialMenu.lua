local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- RADIAL MENU
-- Tabs: Radials (the radials list and live preview in the info panel's column, the editor in the
-- middle; Settings/RadialEditor.lua draws it) and Options.
--------------------------------------------------
local function RM() return ns.RadialMenu end

S:Module{
    key = "rm", group = "interface", order = 30, enabled = "radialmenu.enabled",
    tabs = {
        {
            -- the radials list and the live preview take the info panel's column (preview)
            key = "radials", preview = true,
            custom = function(host, column)
                if ns.RadialEditorEmbed then ns.RadialEditorEmbed.Build(host, column) end
            end,
            refresh = function() if ns.RadialEditorEmbed then ns.RadialEditorEmbed.Refresh() end end,
        },
        { key = "options" },
    },
}

-- search-only rows (the tab draws its own controls); their button opens the Radials tab
local function OpenRadials() ns.SettingsPanel:Open("rm", "radials") end
for _, key in ipairs({ "rm.scope", "rm.key", "rm.ownKey", "rm.padStick", "rm.padBar", "rm.overview", "rm.macroCreate" }) do
    S:Row{ key = key, kind = "button", tab = "radials", buttonText = L["Open"], apply = OpenRadials }
end

local function ApplyOpening() if RM() and RM().ApplyOpening then RM():ApplyOpening() end end
S:Row{ key = "rm.position", kind = "choice", tab = "options", path = "radialmenu.position", choices = { "cursor", "center" }, apply = ApplyOpening }
S:Row{ key = "rm.activation", kind = "choice", tab = "options", path = "radialmenu.activation", choices = { "hold", "toggle" }, apply = ApplyOpening }
local SCALES = {}
for _, v in ipairs({ 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5 }) do SCALES[#SCALES + 1] = { v, (v * 100) .. "%" } end
S:Row{ key = "rm.scale", kind = "range", tab = "options", path = "radialmenu.scale", choices = SCALES }
S:Row{ key = "rm.names", tab = "options", path = "radialmenu.showNames" }
S:Row{
    key = "rm.pad", tab = "options",
    get = function() return RM() and RM():IsControllerEnabled() or false end,
    set = function(on) if RM() then RM():SetControllerEnabled(on) end end,
    disabled = function() return ns.OtherControllerAddon() ~= nil end,
}
S:Row{
    key = "rm.padRelease", tab = "options", parent = "rm.pad",
    get = function() return RM() and RM():IsPadReleaseOn() or false end,
    set = function(on) if RM() then RM():SetPadReleaseOn(on) end end,
    disabled = function() return ns.OtherControllerAddon() ~= nil end,
}
S:Row{
    key = "rm.padRepeat", tab = "options", parent = "rm.pad",
    get = function() return RM() and RM():IsPadRepeatOn() or false end,
    set = function(on) if RM() then RM():SetPadRepeatOn(on) end end,
    disabled = function() return ns.OtherControllerAddon() ~= nil end,
}
-- which button does what in an open controller radial, with the controller's own icons where the
-- client has them; it follows the two switches above
S:Row{
    key = "rm.padLegend", kind = "legend", tab = "options",
    lines = function()
        -- the button in gold, then what it does
        local function Line(button, does) return "|cffffd100" .. button .. "|r   " .. does end
        local function K(key) return ns.KeyText(key) end
        local lines = {
            Line(L["Right stick"], L["aim"]),
            RM() and RM():IsPadReleaseOn() and Line(L["Let go of the stick"], L["use the lit button"]) or nil,
            Line(K("PADRSTICK"), L["use the lit button"]),
            Line(K(GAMEPAD_FACE_RIGHT or "PAD2"), L["close"]),
            Line(K(GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER") .. " / " .. K(GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER"),
                L["switch the aimed button's choice"]),
            RM() and RM():IsPadRepeatOn() and Line(L["The radial's button again"], L["use the last button"]) or nil,
        }
        local out = {}
        for i = 1, 6 do if lines[i] then out[#out + 1] = lines[i] end end
        return out
    end,
}
