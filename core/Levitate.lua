local _, ns = ...
local Utils, Config = ns.Utils, ns.Config

-- Levitate for priests, to fish standing on the water: once it's on, the fishing hotkey casts
-- it again first when it's about to run out.
local Levitate = {}
ns.Levitate = Levitate

local LEVITATE = 1706
-- Its reagent
local LIGHT_FEATHER = 17056
-- The level priests learn it at
local LEVITATE_LEVEL = 34

Levitate.NAME = Utils.GetSpellName(LEVITATE)

-- Whether the character is a priest of the level to learn Levitate. level, when given, is used
-- instead of UnitLevel, which lags behind just after a level-up.
function Levitate.IsAvailable(level)
    local _, class = UnitClass("player")
    return class == "PRIEST" and (level or UnitLevel("player")) >= LEVITATE_LEVEL
end

-- Seconds left on Levitate, math.huge if it doesn't run out, or nil when it's not on
local function GetTimeLeft()
    for i = 1, 40 do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then return nil end
        if aura.spellId == LEVITATE or aura.name == Levitate.NAME then
            if not aura.expirationTime or aura.expirationTime == 0 then
                return math.huge
            end
            return aura.expirationTime - GetTime()
        end
    end
end

-- Whether to cast Levitate again before fishing: it's on with less than
-- Config.LEVITATE_REFRESH seconds left, and the character can cast it now, with a Light Feather
-- and the mana. Never when it's off: the player casts it themselves the first time.
function Levitate.NeedsRecast()
    if not C_UnitAuras or not IsSpellKnown(LEVITATE) or Utils.GetItemCount(LIGHT_FEATHER) == 0
        or not Utils.IsSpellUsable(LEVITATE) then
        return false
    end
    local timeLeft = GetTimeLeft()
    return timeLeft ~= nil and timeLeft < Config.LEVITATE_REFRESH
end
