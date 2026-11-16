local H = dofile('tools/tests/perf-helpers.lua')
local s = H.read('Modules/LootRolls.lua')
H.load([[
local math_max = math.max
local RANK = { [1] = 1, [4] = 2, [2] = 3, [0] = 4 }
local group = 5
local function GetNumGroupMembers() return group end
local SECRET = {}
local function Safe(value) if value ~= SECRET then return value end end
local function StateType(state) return Safe(state) end
local function Won(s) return s.won or false end
local function MyRoll(s) return s.roll end
]] .. H.section(s, 'local function SortedRolls(rollInfos)', 'local function RollsTooltip(') .. H.section(s, 'local function Beaten(s, choice, roll)', 'local function FillRow(row, s)') .. [[
local NEED, GREED, PASS = 1, 2, 0
local function Lead(state, roll, isSelf) return { drop = { currentLeader = { state = state, roll = roll, isSelf = isSelf } } } end

assert(Beaten(Lead(NEED, 12), GREED, 99), 'Need beats a higher Greed')
assert(not Beaten(Lead(GREED, 99), NEED, 12), 'Greed never beats Need')
assert(Beaten(Lead(NEED, 80), NEED, 79), 'the same choice, a higher roll')
assert(not Beaten(Lead(NEED, 80), NEED, 80), 'a tie is not lost')
assert(not Beaten(Lead(NEED, 80), NEED, 81), 'a lower leader')
assert(not Beaten(Lead(NEED, 80), NEED, nil), 'your roll is not known yet')
assert(not Beaten(Lead(NEED, 80, true), GREED, 5), 'you lead')
assert(not Beaten({}, NEED, 50) and not Beaten({ drop = {} }, NEED, 50), 'no leader')
assert(Beaten(Lead(GREED, 1), PASS, nil), 'a pass loses to any leader')
assert(not Beaten(Lead(nil, 80), NEED, 50), 'a leader with no readable choice')

local function Roll(others, waiting, isSelf)
    local me = { playerName = 'me', state = NEED, roll = 90, isSelf = true }
    local infos = { me }
    for i = 1, others do infos[#infos + 1] = { playerName = 'p' .. i, state = GREED, roll = i } end
    for i = 1, waiting do infos[#infos + 1] = { playerName = 'w' .. i } end
    local lead = isSelf and me or infos[2]
    return { choice = NEED, roll = 90, status = 'waiting', drop = { currentLeader = lead, rollInfos = infos } }
end
assert(Decided(Roll(4, 0, true)), 'you lead and all five chose')
assert(not Decided(Roll(3, 1, true)), 'one still to choose')
assert(not Decided(Roll(3, 0, true)), 'the list is shorter than the group')
assert(not Decided(Roll(4, 0, false)), 'someone else leads')
local hidden = Roll(4, 0, true)
hidden.drop.rollInfos[3].playerName = SECRET
assert(not Decided(hidden), 'a player the game hides is not counted')
hidden = Roll(4, 0, true)
hidden.drop.rollInfos[3].state = SECRET
assert(not Decided(hidden), 'a choice the game hides is still to come')
assert(not Decided({}) and not Decided({ drop = {} }), 'no leader')
group = 0
assert(Decided(Roll(0, 0, true)), 'alone: your own roll decides')
group = 5

local won, lost = Outcome(Roll(4, 0, true))
assert(won and not lost, 'decided early counts as won')
won, lost = Outcome(Roll(3, 1, true))
assert(not won and not lost, 'leading is neither won nor lost')
local beaten = Roll(3, 1, false)
beaten.choice, beaten.roll, beaten.drop.currentLeader = GREED, 1, { state = NEED, roll = 2 }
won, lost = Outcome(beaten)
assert(not won and lost, 'beaten before the roll ends')
local done = Roll(3, 1, true)
done.status = 'done'
won, lost = Outcome(done)
assert(not won and lost, 'ended without a win')
done.won = true
won, lost = Outcome(done)
assert(won and not lost, 'the game named you the winner')
]])
print('PASS: loot roll rows know a lost roll and a decided win before the roll ends')
