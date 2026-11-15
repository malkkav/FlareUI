-- Run from the repository root: luajit tools/tests/group-custom-text.lua
-- Exercise the actual shared party/raid/boss tile update and layout functions.
local function read(path)
    local f = assert(io.open(path)); local s = f:read('*a'); f:close(); return s
end
local function section(s, first, last)
    local a = assert(s:find(first, 1, true), first)
    local b = assert(s:find(last, a, true), last)
    return s:sub(a, b - 1)
end
local unit = read('Modules/UnitFrames.lua')
local party = read('Modules/PartyFrames.lua')
local preview = party:sub((assert(party:find('ApplyPreview = function(f)', 1, true))))
local UF = {}
assert(loadstring('return function(UF) local unpack = unpack; local ns = {ShortNumber = function(n) if n >= 10000 then return tostring(n / 1000) .. "K" end return tostring(n) end}; local L = setmetatable({}, {__index = function(_, k) return k end});\n'
    .. section(unit, 'local SPLIT_MODE =', '-- Current (Max) | Percent was removed')
    .. '\nUF.testHealthModes = HEALTH_TEXT_MODES; end'))()(UF)
for _, modes in ipairs({UF.testHealthModes, UF.POWER_TEXT_MODES}) do
    local count = 0
    for _, mode in ipairs(modes) do if mode.value == 'custom' then count = count + 1 end end
    assert(count == 1, 'All shared text dropdowns must offer Custom exactly once')
end
local noop = function() end
local Region = {}; Region.__index = Region
function Region:SetText(text) self.text = text; self.clears = self.clears + 1 end
function Region:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function Region:SetPoint(...) self.point = {...} end
function Region:ClearAllPoints() self.point = nil end
function Region:SetJustifyH(v) self.justify = v end
function Region:Hide() self.shown = false end
function Region:Show() self.shown = true end
function Region:SetShown(v) self.shown = not not v end
function Region:IsShown() return self.shown end
function Region:GetFont() return 'font', 12, '' end
function Region:GetShadowColor() return 0, 0, 0, 1 end
function Region:GetShadowOffset() return 0, 0 end
function Region:GetTextColor() return 1, 1, 1, 1 end
for _, name in ipairs({'SetFont','SetShadowColor','SetShadowOffset','SetTextColor','SetAlpha',
    'SetMinMaxValues','SetValue','SetStatusBarColor','SetReverseFill','SetSize','SetWidth','SetHeight'}) do Region[name] = noop end
local function region() return setmetatable({shown = true, clears = 0}, Region) end
function Region:GetParent() return self end
function Region:CreateFontString() return region() end

local factory = assert(loadstring([[
return function(K, region, noop)
    local connected, dead, value = true, false, 80
    local ns = {SetBarValue = noop, PowerColor = function() return 0, 0, 1 end, ClassColorsOn = function() return false end,
        UFRing = {NameBox = function(f) return f.box end, LayoutPlate = noop}}
    local PF = {FontKey = function(f) return f.kind end}
    local CurveConstants = {ScaleTo100 = {}}
    local function TS(f) return f.ctx.Settings() end
    local function RaidTile(f) return f.kind == 'raid' end
    local function OnPlate(f) return f.kind == 'plate' end
    local function Mirrored() return false end
    local function Sides() return 'LEFT', 'RIGHT', 1 end
    local function canaccessvalue() return true end
    local function UnitIsConnected() return connected end
    local function UnitIsDead() return dead end
    local function UnitIsGhost() return false end
    local function UnitHealth() return 18000 end
    local function UnitHealthMax() return 24000 end
    local function UnitHealthPercent() return 75 end
    local function UnitPowerType() return 0 end
    local function UnitPower() return value end
    local function UnitPowerMax() return 200 end
    local function UnitPowerPercent() return value / 2 end
    K.IsDead = function() return dead end
    K.GetHealthColor, K.GetPowerColor, K.ApplyFont, K.Font = noop, noop, noop, noop
    K.OFFLINE_TEXT, K.DEAD_TEXT, K.GHOST_TEXT = 'Offline', 'Dead', 'Ghost'
    K.TEXT_INSET, K.INSET, K.SEPARATOR_HEIGHT = 3, 2, 1
]] .. section(party, 'local function UpdateHealth(f, glide)', '-- Incoming heals and absorbs')
    .. section(party, 'local function PortraitSpace(f)', 'local function LayoutHealClip(f)')
    .. section(party, 'local function LayoutTexts(f)', 'local function LayoutIcons(f)')
    .. 'local function RenderSample(f, data) local st, class = TS(f), "MAGE"; local math_floor = math.floor; local PREVIEW_POWER = {MAGE = "MANA"};\n'
    .. section(preview, '    local mode = st.healthText or "percent"', '    -- a sample incoming heal') .. '\nend\n' .. [[
    for _, kind in ipairs({'plate','raid','classic'}) do
        local st = {healthText = 'custom', powerText = 'custom', powerHeight = 12, portrait = 'none'}
        local f = {fuiUnit = 'party1', kind = kind, powerShown = true, ctx = {Settings = function() return st end}}
        for _, key in ipairs({'Health','Power','Name','Level','HealthText','PowerText','Separator','Portrait','PortraitDivider'}) do f[key] = region() end
        if kind == 'plate' then f.box = region() end
        LayoutBars(f); LayoutTexts(f)
        UpdateHealth(f); UpdatePower(f)
        if kind == 'classic' then
            assert(not f.HealthTextLeft and not f.PowerTextLeft)
            assert(f.HealthText.text == '18K / 24K | 75%')
            assert(f.PowerText.text == '80 / 200 | 40%')
        else
            assert(f.HealthTextLeft.text == '18K / 24K' and f.HealthText.text == '75%')
            assert(f.PowerTextLeft.text == '80 / 200' and f.PowerText.text == '40%')
            assert(f.HealthTextLeft.point[1] == 'LEFT' and f.HealthText.point[1] == 'RIGHT')
            assert(f.HealthTextLeft.clears == 0 and f.PowerTextLeft.clears == 0)
        end
        value = 60; UpdatePowerValue(f)
        assert(f.PowerText.text == (kind == 'classic' and '60 / 200 | 30%' or '30%'))
        connected = false; UpdateHealth(f); UpdatePower(f)
        assert(f.HealthText.text == 'Offline' and f.PowerText.text == '')
        if f.HealthTextLeft then assert(f.HealthTextLeft.text == '' and f.PowerTextLeft.text == '') end
        connected = true; dead = true; UpdateHealth(f); UpdatePower(f)
        assert(f.HealthText.text == 'Dead' and f.PowerText.text == '')
        dead = false; value = 80; UpdateHealth(f); UpdatePower(f)
        assert(f.HealthText.text == (kind == 'classic' and '18K / 24K | 75%' or '75%'))
        if kind == 'raid' then
            st.powerHeight = 4; LayoutBars(f); LayoutTexts(f)
            assert(f.PowerTextLeft.point[1] == 'BOTTOMLEFT' and f.PowerText.point[1] == 'BOTTOMRIGHT')
            st.powerHeight = 0; UpdatePower(f)
            assert(not f.PowerText:IsShown() and not f.PowerTextLeft:IsShown())
            st.powerHeight = 12; UpdatePower(f)
            assert(f.PowerText:IsShown() and f.PowerTextLeft:IsShown())
        end
        RenderSample(f, {health = 0.5, power = 0.5})
        assert(f.HealthText.text == (kind == 'classic' and '12K / 24K | 50%' or '50%'))
        assert(f.PowerText.text == (kind == 'classic' and '4500 / 9000 | 50%' or '50%'))
        RenderSample(f, {health = 0, power = 0, dead = true})
        assert(f.HealthText.text == 'Dead' and f.PowerText.text == '')
        if f.HealthTextLeft then assert(f.HealthTextLeft.text == '' and f.PowerTextLeft.text == '') end
        st.healthText = 'none'; st.powerText = 'none'
        LayoutBars(f); LayoutTexts(f)
        if f.HealthTextLeft then assert(not f.HealthTextLeft:IsShown() and not f.PowerTextLeft:IsShown()) end
    end
end
]]))()
factory(UF, region, noop)
print('PASS: group tile layouts, power ticks, offline/death/recovery, slim/hidden power bars, previews and mode changes')

-- Dialog actions keep each owner's saved settings separate, including empty-side values.
local dialogFactory = assert(loadstring([[
return function(UF)
    local L = setmetatable({}, {__index = function(_, k) return k end})
    local LEM = {SettingType = {Buttons = 'buttons'}}
    local ns = {Dialogs = {}}
    function ns.ShowDialog(key, _, data) ns.key, ns.data = key, data end
]] .. section(unit, 'ns.Dialogs["FLAREUI_UF_CUSTOM_TEXT"] =', 'local function BuildSettings(unit)') .. [[
    local stores = {}
    for _, owner in ipairs({'unit','party-classic','party-raid','raid','boss'}) do
        local db = {healthText = 'custom', powerText = 'custom'}
        stores[owner] = db
        local count = 0
        local function get() return db end
        local function refresh() count = count + 1 end
        for _, key in ipairs({'healthText','powerText'}) do
            local setting = UF.CustomTextSetting(key, get, refresh)
            assert(not setting.hidden())
            for i, button in ipairs(setting.buttons) do
                button.click()
                local def = ns.Dialogs[ns.key]
                assert(def.editText(ns.data) == (i == 1 and '[value] / [max]' or '[percent]'))
                def.OnAccept(ns.data, i == 1 and owner .. ' [value]' or '')
            end
            assert(db[key .. 'CustomLeft'] == owner .. ' [value]' and db[key .. 'CustomRight'] == '')
            db[key] = 'none'; assert(setting.hidden())
        end
        assert(count == 4)
    end
    assert(stores.raid.healthTextCustomLeft ~= stores.boss.healthTextCustomLeft)
end
]]))()
dialogFactory(UF)
print('PASS: shared dialog edits both sides, preserves blank fields and isolates owner profiles')
