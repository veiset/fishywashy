local _, ns = ...

-- All access to the FishyWashyDB saved variable goes through here.
local Storage = {}
ns.Storage = Storage

local SCHEMA_VERSION = 1

local DEFAULTS = {
    enabled = true,
    volume = 0.85,
    soundInBackground = true,
    rightClickCast = false,
    showStats = true,
    statsIncludeMissed = false,
    showAdvancedStats = true,
    showConfig = true,
    showGlobalStats = true,
    showZones = true,
    showHistory = true,
    showHistoryGraph = true,
    globalShowLastSeen = true,
}

local db

-- All-time totals, kept through session resets:
--   globalItems        { [itemID] = { link, icon, count, lastSeen } }
--   globalZones        { [zone] = { count, subzones = { [subzone] = count } } }, items caught there
--   globalHours        { [hour + 1] = casts started in that hour of the day, local time }
--   globalCaughtCasts, globalUnsuccessful, globalCatchSeconds
--   globalSessions     sessions started, counting the current one

local function AddItemToGlobal(catch)
    local item = db.globalItems[catch.itemID]
    if not item then
        item = { count = 0 }
        db.globalItems[catch.itemID] = item
    end
    item.link = catch.link
    item.icon = catch.icon
    item.count = item.count + catch.quantity
    item.lastSeen = catch.time
end

local function AddZoneToGlobal(catch)
    if not catch.zone then return end
    local zone = db.globalZones[catch.zone]
    if not zone then
        zone = { count = 0, subzones = {} }
        db.globalZones[catch.zone] = zone
    end
    zone.count = zone.count + catch.quantity
    -- The subzone is empty away from named areas, and missing on older catches
    if catch.subzone and catch.subzone ~= "" then
        zone.subzones[catch.subzone] = (zone.subzones[catch.subzone] or 0) + catch.quantity
    end
end

local function AddHourToGlobal(cast)
    local hour = date("*t", cast.time).hour + 1
    db.globalHours[hour] = (db.globalHours[hour] or 0) + 1
end

local function AddCastCountsToGlobal(cast)
    if cast.caught then
        db.globalCaughtCasts = db.globalCaughtCasts + 1
        db.globalCatchSeconds = db.globalCatchSeconds + cast.seconds
    else
        db.globalUnsuccessful = db.globalUnsuccessful + 1
    end
end

-- Creates an all-time total missing from older saved data, starting it from this session's history
local function InitGlobal(key, initial, history, add)
    if db[key] then return end
    db[key] = initial
    for _, entry in ipairs(history) do
        add(entry)
    end
end

function Storage.Init()
    if type(FishyWashyDB) ~= "table" or FishyWashyDB.version == nil then
        FishyWashyDB = { version = SCHEMA_VERSION }
    end
    db = FishyWashyDB
    db.settings = db.settings or {}
    db.catches = db.catches or {}
    db.casts = db.casts or {}
    db.statsStart = db.statsStart or (db.catches[1] and db.catches[1].time) or time()

    InitGlobal("globalItems", {}, db.catches, AddItemToGlobal)
    InitGlobal("globalZones", {}, db.catches, AddZoneToGlobal)
    -- Older saved data kept only a count per zone
    for name, zone in pairs(db.globalZones) do
        if type(zone) == "number" then
            db.globalZones[name] = { count = zone, subzones = {} }
        end
    end
    InitGlobal("globalHours", {}, db.casts, AddHourToGlobal)
    if not db.globalCaughtCasts then
        db.globalCaughtCasts, db.globalUnsuccessful, db.globalCatchSeconds = 0, 0, 0
        for _, cast in ipairs(db.casts) do
            AddCastCountsToGlobal(cast)
        end
    end
    db.globalSessions = db.globalSessions or 1
end

function Storage.GetSetting(key)
    local value = db.settings[key]
    if value == nil then
        return DEFAULTS[key]
    end
    return value
end

function Storage.SetSetting(key, value)
    db.settings[key] = value
end

-- The player's own sound settings, kept while boosted so they survive a logout or crash.
function Storage.GetSoundBackup()
    return db.soundBackup
end

function Storage.SetSoundBackup(backup)
    db.soundBackup = backup
end

-- Every fishing catch this session, oldest first: { itemID, link, icon, quantity, time, zone, subzone }.
-- Also counted in the all-time totals.
function Storage.AddCatch(catch)
    table.insert(db.catches, catch)
    AddItemToGlobal(catch)
    AddZoneToGlobal(catch)
end

function Storage.GetCatches()
    return db.catches
end

-- Every fishing cast this session, oldest first: { time, ended, caught, seconds }; seconds is set
-- for caught casts. Also counted in the all-time totals.
function Storage.AddCast(cast)
    table.insert(db.casts, cast)
    AddCastCountsToGlobal(cast)
    AddHourToGlobal(cast)
end

function Storage.GetCasts()
    return db.casts
end

-- Starts a new session: clears the session's catches and casts; the all-time totals are kept
function Storage.ClearCatches()
    db.catches = {}
    db.casts = {}
    db.statsStart = time()
    db.globalSessions = db.globalSessions + 1
end

-- Deletes all catches, casts and all-time totals; the settings are kept
function Storage.ClearAll()
    FishyWashyDB = { version = SCHEMA_VERSION, settings = db.settings, soundBackup = db.soundBackup }
    Storage.Init()
end

-- When the stats were last reset
function Storage.GetStatsStart()
    return db.statsStart
end

function Storage.GetGlobalItems()
    return db.globalItems
end

function Storage.GetGlobalZones()
    return db.globalZones
end

function Storage.GetGlobalHours()
    return db.globalHours
end

-- Casts caught, casts unsuccessful, and seconds from cast to catch summed over the caught casts
function Storage.GetGlobalCasts()
    return db.globalCaughtCasts, db.globalUnsuccessful, db.globalCatchSeconds
end

-- Sessions started, counting the current one
function Storage.GetGlobalSessions()
    return db.globalSessions
end
