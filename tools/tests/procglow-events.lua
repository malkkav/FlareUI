-- Run from the repository root with LuaJIT.
local F = dofile("tools/tests/fixtures/doesitdie-frames.lua")
local SECRET = {}
local names = {
    [6572] = "Revenge", [6573] = "Revenge",
    [30455] = "Ice Lance", [400669] = "Fingers of Frost",
    [5143] = "Arcane Missiles", [400588] = "Missile Barrage",
}

local function setup(class, slots)
    local now, timers, events = 0, {}
    local facts = { auras = {}, locked = false, flagged = {}, cooldowns = {}, usable = {}, reads = {} }
    local buttons = {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    function env.wipe(t)
        for key in pairs(t) do t[key] = nil end
    end
    function env.canaccessvalue(value) return value ~= SECRET end
    function env.GetTime() return now end
    function env.GetCVarBool(key) return key == "cooldownViewerEnabled" end
    function env.UnitClass() return class, class end
    function env.GetActionInfo(slot)
        facts.reads[slot] = (facts.reads[slot] or 0) + 1
        local action = slots[slot]
        if action then return unpack(action) end
    end
    function env.CreateFrame(kind, _, parent, template)
        local frame = F.frame(kind, parent)
        if template == "ActionButtonSpellAlertTemplate" then
            frame:Hide()
            local function animation()
                return {
                    Play = function(self) self.playing = true end,
                    Stop = function(self) self.playing = false end,
                }
            end
            frame.ProcStartAnim = animation()
            frame.ProcLoop = animation()
            function frame:SetAlphaFromBoolean(value, on, off)
                assert(value == SECRET and on == 1 and off == 0)
                facts.secretAlpha = true
            end
        else
            assert(not events)
            events = frame
        end
        return frame
    end
    env.C_Spell = {
        GetSpellName = function(id) return names[id] end,
        GetSpellCooldown = function(id) return facts.cooldowns[id] end,
    }
    env.C_ActionBar = { IsUsableAction = function(slot) return facts.usable[slot] end }
    env.C_Secrets = { ShouldAurasBeSecret = function() return facts.locked end }
    env.C_SpellActivationOverlay = { IsSpellOverlayed = function(id) return facts.flagged[id] or false end }
    env.C_UnitAuras = {
        GetPlayerAuraBySpellID = function(id) return facts.auras[id] end,
        GetAuraDataBySpellName = function(_, name) return facts.auras[name] end,
    }
    local function timer(delay, callback, repeating)
        local entry = { due = now + delay, delay = delay, fn = callback, repeating = repeating }
        function entry:Cancel() self.cancelled = true end
        timers[#timers + 1] = entry
        return entry
    end
    env.C_Timer = {
        After = timer, NewTimer = timer,
        NewTicker = function(delay, callback) return timer(delay, callback, true) end,
    }
    local function advance(seconds)
        local finish = now + seconds
        while true do
            local first
            for _, entry in ipairs(timers) do
                if not entry.cancelled and entry.due <= finish and (not first or entry.due < first.due) then
                    first = entry
                end
            end
            if not first then break end
            now = first.due
            if first.repeating then first.due = now + first.delay else first:Cancel() end
            first.fn()
        end
        now = finish
    end
    for slot = 1, #slots + 1 do
        local button = F.frame("CheckButton")
        button.action = slot
        function button:GetSize() return self:GetWidth(), self:GetHeight() end
        button:SetSize(40, 40)
        buttons[slot], env["ActionButton" .. slot] = button, button
    end
    local db = { enabled = true, procGlow = false }
    local ns = { db = { profile = { actionbars = db } } }
    setfenv(assert(loadfile("Modules/ProcGlow.lua")), env)("FlareUI", ns)
    ns.ProcGlow:Refresh()
    assert(not events, "a disabled feature should not create its event driver")
    local function enable(on)
        db.procGlow = on
        ns.ProcGlow:Refresh()
        advance(0)
    end
    local function send(event, ...)
        local state = F.state[events]
        assert(state.events[event], "event not registered: " .. event)
        state.scripts.OnEvent(events, event, ...)
    end
    local function shown(slot)
        local glow = buttons[slot].FlareUI_ProcGlow
        return glow and glow:IsShown() or false
    end
    return {
        facts = facts, env = env, buttons = buttons, enable = enable, advance = advance,
        send = send, shown = shown, registered = function(key) return F.state[events].events[key] end,
    }
end

local function revenge()
    local kind = { { "spell", 6573 }, { "macro", 6573, "spell" }, { "item", 42 } }
    local t = setup("WARRIOR", kind)
    t.facts.usable[1], t.facts.usable[2] = true, true
    t.enable(true)
    assert(t.registered("UNIT_HEALTH")[1] == "target" and t.registered("UNIT_COMBAT")[1] == "player")
    assert(t.shown(1) and t.shown(2) and not t.shown(3) and not t.shown(4))
    local glow = t.buttons[1].FlareUI_ProcGlow
    assert(glow:GetWidth() == 56 and glow.ProcStartAnim.playing)

    -- A cast consumes the usable window. Avoiding another hit reopens it.
    t.send("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6572)
    t.advance(0)
    assert(not t.shown(1) and not t.shown(2) and not glow.ProcStartAnim.playing)
    t.send("UNIT_COMBAT", "player", "WOUND", "BLOCK")
    t.advance(0)
    assert(t.shown(1) and t.shown(2))

    -- A GCD should still allow the glow. A real cooldown should suppress it.
    t.facts.cooldowns[6573] = { isActive = true, isOnGCD = true }
    t.send("SPELL_UPDATE_COOLDOWN")
    t.advance(0.1)
    assert(t.shown(1) and t.shown(2))
    t.facts.cooldowns[6573].isOnGCD = false
    t.send("SPELL_UPDATE_COOLDOWN")
    t.advance(0.1)
    assert(not t.shown(1) and not t.shown(2))

    t.facts.cooldowns[6573] = nil
    t.facts.usable[1] = SECRET
    local reads = t.facts.reads[2]
    kind[2] = { "macro", 42, "item" }
    for _ = 1, 8 do t.send("ACTIONBAR_UPDATE_USABLE") end
    t.advance(0.1)
    assert(t.shown(1) and t.facts.secretAlpha and glow.ProcLoop.playing)
    assert(not t.shown(2) and t.facts.reads[2] == reads + 1, "macros refresh, including after a burst of usable events")

    -- A flag by spell name lights all ranks. Blizzard's own visible alert wins on its button.
    t.facts.usable[1] = false
    t.buttons[1].SpellActivationAlert = F.frame("Frame")
    t.send("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 6572)
    t.advance(0)
    assert(not t.shown(1))
    t.buttons[1].SpellActivationAlert:Hide()
    t.send("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 6572)
    t.advance(0)
    assert(t.shown(1))
    t.send("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 6572)
    t.advance(0)
    assert(not t.shown(1))

    kind[3] = { "spell", 6572 }
    t.facts.usable[3] = true
    t.send("ACTIONBAR_SLOT_CHANGED", 3)
    t.advance(0.1)
    assert(t.shown(3), "a slot change must evict its cached item")
    t.enable(false)
    assert(not t.shown(3) and not t.registered("UNIT_COMBAT"))
end

local function mage()
    local slots = { { "spell", 30455 }, { "spell", 5143 } }
    local t = setup("MAGE", slots)
    t.facts.auras[400669] = { expirationTime = 3 }
    t.facts.auras["Missile Barrage"] = { expirationTime = 0 }
    t.enable(true)
    assert(t.shown(1) and t.shown(2) and not t.registered("UNIT_HEALTH"))
    t.advance(3.1)
    assert(not t.shown(1) and t.shown(2), "only the timed proc expires")

    t.facts.locked = true
    t.send("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 5143)
    t.advance(0)
    assert(not t.shown(2))
    t.send("SPELL_ACTIVATION_OVERLAY_SHOW", 400669)
    t.advance(0)
    assert(t.shown(1))
    t.send("SPELLS_CHANGED")
    t.advance(0.1)
    assert(t.shown(1), "rebuilding the spell list preserves a combat proc")
    t.send("SPELL_ACTIVATION_OVERLAY_HIDE")
    t.advance(0)
    assert(not t.shown(1))

    local icon = { cooldownID = 7, isActive = true }
    local viewer = F.frame("Frame")
    function viewer:GetChildren() return icon end
    function viewer:UpdateShownState() end
    function t.env.hooksecurefunc(frame, method, callback)
        local original = frame[method]
        frame[method] = function(...)
            original(...)
            callback(...)
        end
    end
    t.env.BuffIconCooldownViewer = viewer
    t.env.C_CooldownViewer = {
        GetCooldownViewerCooldownInfo = function(id)
            assert(id == 7)
            return { overrideSpellID = SECRET, linkedSpellIDs = { 12, 400669 } }
        end,
    }
    t.send("UNIT_AURA", "player")
    t.advance(0)
    assert(t.shown(1), "a Cooldown Manager link follows its buff while auras are locked")
    icon.isActive = false
    viewer:UpdateShownState()
    t.advance(0)
    assert(not t.shown(1))
    icon.isActive, icon.auraInstanceID = nil, SECRET
    viewer:UpdateShownState()
    t.advance(0)
    assert(t.shown(1), "an opaque aura instance still signals presence")
    t.facts.locked = false
    t.facts.auras = {}
    t.send("PLAYER_REGEN_ENABLED")
    t.advance(0)
    assert(not t.shown(1), "readable auras take precedence over a lagging viewer")
    t.enable(false)
    assert(not t.registered("UNIT_AURA"))
end

revenge()
mage()
print("PASS: reactive action glows, cooldowns, buff expiry and combat Cooldown Manager tracking")
