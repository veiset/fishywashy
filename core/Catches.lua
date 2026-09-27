local _, ns = ...
local Config, Storage = ns.Config, ns.Storage

-- Records every fishing cast and everything looted from fishing.
local Catches = {}
ns.Catches = Catches

local GetSpellName = ns.Utils.GetSpellName
local FISHING = GetSpellName(7620)
-- The Fishing spell's name, in the client's language
Catches.FISHING = FISHING

local listeners = {}
-- The cast in progress: { time, startedAt, stoppedAt }
local currentCast

function Catches.IsFishingSpell(spellID)
    return GetSpellName(spellID) == FISHING
end

function Catches.OnChange(callback)
    table.insert(listeners, callback)
end

local function NotifyChange()
    for _, callback in ipairs(listeners) do
        callback()
    end
end

-- Forget every catch and cast this session, which also resets the stats
function Catches.Reset()
    Storage.ClearCatches()
    NotifyChange()
end

-- Forget everything, including the all-time stats
function Catches.ResetAll()
    Storage.ClearAll()
    NotifyChange()
end

-- The most recent catches and missed casts, newest first. Misses are { missed = true, time }.
function Catches.GetRecent(limit)
    local catches, casts = Storage.GetCatches(), Storage.GetCasts()
    local c, m = #catches, #casts
    local recent = {}
    while #recent < limit do
        while m > 0 and casts[m].caught do
            m = m - 1
        end
        local catch, miss = catches[c], casts[m]
        if not catch and not miss then break end
        -- Casts saved before end times were recorded only have their start time
        local missTime = miss and (miss.ended or miss.time)
        if miss and (not catch or missTime > catch.time) then
            table.insert(recent, { missed = true, time = missTime })
            m = m - 1
        else
            table.insert(recent, catch)
            c = c - 1
        end
    end
    return recent
end

local function FinishCast(caught)
    if not currentCast then return end
    Storage.AddCast({
        time = currentCast.time,
        ended = time(),
        caught = caught,
        seconds = caught and (GetTime() - currentCast.startedAt) or nil,
    })
    currentCast = nil
end

local function StartCast()
    if currentCast then
        local stoppedAt = currentCast.stoppedAt
        if stoppedAt and GetTime() - stoppedAt < Config.RECAST_WINDOW then
            -- Recast: forget the old cast rather than count it as missed
            currentCast = nil
        else
            FinishCast(false)
            NotifyChange()
        end
    end
    currentCast = { time = time(), startedAt = GetTime() }
end

local function StopCast()
    local cast = currentCast
    if not cast then return end
    cast.stoppedAt = GetTime()
    C_Timer.After(Config.LOOT_GRACE, function()
        if currentCast == cast then
            FinishCast(false)
            NotifyChange()
        end
    end)
end

local function RecordLoot()
    if not IsFishingLoot() then return end
    for slot = 1, GetNumLootItems() do
        -- Money has no item link
        local link = GetLootSlotLink(slot)
        if link then
            local icon, _, quantity = GetLootSlotInfo(slot)
            Storage.AddCatch({
                itemID = tonumber(link:match("item:(%d+)")),
                link = link,
                icon = icon,
                quantity = quantity,
                time = time(),
                zone = GetRealZoneText(),
                subzone = GetSubZoneText(),
            })
        end
    end
    FinishCast(true)
    NotifyChange()
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_OPENED")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "LOOT_OPENED" then
        RecordLoot()
    elseif Catches.IsFishingSpell(spellID) then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            StartCast()
        else
            StopCast()
        end
    end
end)
