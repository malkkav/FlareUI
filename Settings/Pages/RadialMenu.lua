local _, ns = ...
local L = ns.L
local S = ns.Settings

--------------------------------------------------
-- RADIAL MENU
-- Tabs: Radials (a wider window: the radials list in the info panel's column, the editor in the
-- middle; Settings/RadialEditor.lua draws it) and Options.
--------------------------------------------------
local function RM() return ns.RadialMenu end

S:Module{
    key = "rm", group = "Tools", order = 30, enabled = "radialmenu.enabled",
    tabs = {
        {
            -- a wider window; the radials list takes the info panel's column (preview)
            key = "radials", wide = true, preview = true,
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
for _, key in ipairs({ "rm.scope", "rm.key", "rm.ownKey", "rm.overview", "rm.macroCreate" }) do
    S:Row{ key = key, kind = "button", tab = "radials", buttonText = L["Open"], apply = OpenRadials }
end

local function ApplyOpening() if RM() and RM().ApplyOpening then RM():ApplyOpening() end end
S:Row{ key = "rm.position", kind = "choice", tab = "options", path = "radialmenu.position", choices = { "cursor", "center" }, apply = ApplyOpening }
S:Row{ key = "rm.activation", kind = "choice", tab = "options", path = "radialmenu.activation", choices = { "hold", "toggle" }, apply = ApplyOpening }
S:Row{ key = "rm.names", tab = "options", path = "radialmenu.showNames" }
S:Row{
    key = "rm.pad", tab = "options",
    get = function() return RM() and RM():IsControllerEnabled() or false end,
    set = function(on) if RM() then RM():SetControllerEnabled(on) end end,
}
