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

-- the radial whose macro line the Radial Macros group shows; the character's own radial at first
local macroRadial

local function MacroRadialID()
    local rm = RM()
    if not rm then return nil end
    if not (macroRadial and rm:GetRadial(macroRadial)) then macroRadial = rm:GetAssignedRadialID() end
    return macroRadial
end

local MACRO_HELP = "You can use a radial macro from your action bars or from another radial, and it accepts any macro conditionals.\n\n"
    .. "Pressing the macro opens the radial and keeps it open. Click a button, or press the macro again, to use the button you are pointing at. Right-click or Escape closes the radial.\n\n"
    .. "Use the tool below to create a macro command for any of your radials:"

-- With controller support on in the Gamepad UI only the main radial is reachable (R3), so the extra
-- keybind rows are greyed out there; with keyboard and mouse they work as ever.
local function ControllerOnly()
    return RM() and RM():IsControllerEnabled() and ns.IsGamepadUI() or false
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
                    type = "keybinding", name = "Main Radial Keybind", order = 10, width = 1.0,
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
                -- extra keybind rows are added below (ExtraKeybindRows)
                addExtra = {
                    type = "execute", name = "Extra Keybind", order = 900, width = 1.0,
                    desc = "Add another keybind on this character, opening a radial of its own.",
                    disabled = ControllerOnly,
                    hidden = function()
                        return not RM() or #RM():GetExtraBindings() >= RM().MAX_EXTRA_KEYS
                    end,
                    func = function()
                        if RM() then RM():AddExtraBinding() end
                        AceConfigRegistry:NotifyChange("FlareUI")
                    end,
                },
            }
        },

        padGroup = {
            type = "group", name = "Controller", order = 25, inline = true,
            args = {
                help = { type = "description", fontSize = "medium", order = 10,
                    name = "Press R3 to open the main radial menu and to select a radial button. The ping menu moves to L3." },
                controller = {
                    type = "toggle", name = "Enable Controller Support", order = 20, width = 1.4,
                    get = function() return RM() and RM():IsControllerEnabled() or false end,
                    set = function(_, val) if RM() then RM():SetControllerEnabled(val) end end,
                },
            },
        },

        macroGroup = {
            type = "group", name = "Radial Macros", order = 30, inline = true,
            args = {
                help = { type = "description", fontSize = "medium", order = 10, name = MACRO_HELP },
                spacer1 = { type = "description", name = " ", order = 15 },
                radial = {
                    type = "select", name = "Radial", order = 20, width = 1.0,
                    values = function()
                        local values = RadialValues()
                        values[""] = nil
                        return values
                    end,
                    sorting = function()
                        local order = RadialSorting()
                        table.remove(order, 1)
                        return order
                    end,
                    get = function() return MacroRadialID() end,
                    set = function(_, val) macroRadial = val end,
                },
                spacer2 = { type = "description", name = "", width = 0.1, order = 21 },
                macro = {
                    type = "input", name = "Macro Line", order = 30, width = 1.6,
                    desc = "Select it (Ctrl+A) and copy it (Ctrl+C) into a macro.",
                    get = function() return RM() and RM():GetMacroText(MacroRadialID()) or "" end,
                    set = function() end,
                },
            }
        },
    },
}

-- Extra keybind rows: [key] [radial] [Remove], one per extra keybind on this character, each shown
-- only while it exists. The "Extra Keybind" button (order 900) follows the last one.
local function ExtraValue(index, field)
    local extra = RM() and RM():GetExtraBindings()[index]
    return extra and extra[field]
end

local function NoExtra(index)
    return not (RM() and RM():GetExtraBindings()[index])
end

local function ExtraKeybindRows(args)
    local values = function()
        local t = RadialValues()
        t[""] = nil
        return t
    end
    local sorting = function()
        local order = RadialSorting()
        table.remove(order, 1)
        return order
    end
    for i = 1, (ns.RadialMenu and ns.RadialMenu.MAX_EXTRA_KEYS) or 5 do
        local base = 100 + i * 10
        local hidden = function() return NoExtra(i) end
        args["extraBreak" .. i] = { type = "description", name = " ", order = base, width = "full", hidden = hidden }
        args["extraKey" .. i] = {
            type = "keybinding", name = "Extra Keybind", order = base + 1, width = 1.0, hidden = hidden, disabled = ControllerOnly,
            desc = "Hold the bound key to open the radial chosen beside it.",
            get = function() return ExtraValue(i, "key") or "" end,
            set = function(_, val) if RM() then RM():SetExtraKey(i, val) end end,
        }
        args["extraSpacer" .. i] = { type = "description", name = "", width = 0.1, order = base + 2, hidden = hidden }
        args["extraRadial" .. i] = {
            type = "select", name = "Radial", order = base + 3, width = 1.0, hidden = hidden, disabled = ControllerOnly,
            values = values, sorting = sorting,
            get = function() return ExtraValue(i, "radial") end,
            set = function(_, val) if RM() then RM():SetExtraRadial(i, val) end end,
        }
        args["extraSpacerB" .. i] = { type = "description", name = "", width = 0.1, order = base + 4, hidden = hidden }
        args["extraRemove" .. i] = {
            type = "execute", name = "Remove", order = base + 5, width = 0.5, hidden = hidden, disabled = ControllerOnly,
            func = function()
                if RM() then RM():RemoveExtraBinding(i) end
                AceConfigRegistry:NotifyChange("FlareUI")
            end,
        }
    end
    args.addExtraBreak = {
        type = "description", name = " ", order = 899, width = "full",
        hidden = function() return not RM() or #RM():GetExtraBindings() >= RM().MAX_EXTRA_KEYS end,
    }
end
ExtraKeybindRows(ns.Options.args.radialmenu.args.generalGroup.args)

-- The radial editor calls this after the library changes, so an open settings page redraws the radial
-- dropdown with the new names.
function ns.RefreshRadialOptions()
    AceConfigRegistry:NotifyChange("FlareUI")
end
