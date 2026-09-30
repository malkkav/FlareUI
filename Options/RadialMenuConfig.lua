local _, ns = ...

--------------------------------------------------
-- RADIAL MENU OPTIONS
-- One page: the way in to the radial editor, the binding and which radial this character opens. The
-- radial's size follows its button count (RadialRadius), so there is no setting for it. Radial contents
-- are edited in the standalone Radial Editor, not here - a declarative options tree is the wrong
-- shape for a drag-and-drop list.
-- Radials live in db.global, so the editor and the radial choice both work on the account-wide library
-- rather than the shared profile. The choice itself belongs to the character; see GetAssignedRadialID.
--------------------------------------------------
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local function RM() return ns.RadialMenu end

-- The library in its own order, read afresh each time so a radial added, renamed or removed in the
-- editor shows up here straight away.
local function RadialValues()
    local rm, values = RM(), { [""] = "|cff808080None|r" }
    if not rm then return values end
    for _, id in ipairs(rm:GetRadialOrder()) do
        local data = rm:GetRadial(id)
        if data then values[id] = data.name end
    end
    return values
end

local function RadialSorting()
    local rm, order = RM(), { "" }
    if not rm then return order end
    for _, id in ipairs(rm:GetRadialOrder()) do
        if rm:GetRadial(id) then order[#order + 1] = id end
    end
    return order
end

ns.Options.args.radialmenu = {
    type = "group", name = "Radial Menu", order = 35,
    hidden = function() return not ns.db.profile.radialmenu.enabled end,
    args = {
        header = { type = "header", name = "Radial Menu", order = 0 },

        editorSpacerTop = { type = "description", name = " ", order = 5 },

        openEditor = {
            type = "execute", name = "Open Radial Editor (|cffffff00/fui re|r)", order = 10, width = "full",
            desc = "Build and edit your radials.",
            func = function() ns.ShowRadialEditor() end,
        },

        editorSpacerBottom = { type = "description", name = " ", order = 15 },

        generalGroup = {
            type = "group", name = "General", order = 20, inline = true,
            args = {
                key = {
                    type = "keybinding", name = "Radial Menu Keybind", order = 10, width = 1.0,
                    desc = "Hold the bound key to open the radial",
                    get = function() return RM() and RM():GetKey() or "" end,
                    set = function(_, val) if RM() then RM():SetKey(val) end end,
                },
                spacer1 = { type = "description", name = "", width = 0.1, order = 11 },
                radial = {
                    type = "select", name = "Radial for This Character", order = 30, width = 1.0,
                    desc = "The radial the keybind opens on this character.",
                    values = RadialValues, sorting = RadialSorting,
                    get = function() return RM() and RM():GetAssignedRadialID() or "" end,
                    set = function(_, val) if RM() then RM():SetAssignedRadialID(val ~= "" and val or nil) end end,
                },
            }
        },
    },
}

-- The radial editor calls this after the library changes, so an open settings page redraws the radial
-- dropdown with the new names.
function ns.RefreshRadialOptions()
    AceConfigRegistry:NotifyChange("FlareUI")
end
