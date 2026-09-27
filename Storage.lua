local _, ns = ...

-- All access to the FishyWashyDB saved variable goes through here.
local Storage = {}
ns.Storage = Storage

local SCHEMA_VERSION = 1

local DEFAULTS = {
    enabled = false,
    volume = 1,
    showStats = true,
    statsIncludeMissed = false,
    showAdvancedStats = true,
    debug = false,
}

local db

function Storage.Init()
    if type(FishyWashyDB) ~= "table" or FishyWashyDB.version == nil then
        FishyWashyDB = { version = SCHEMA_VERSION }
    end
    db = FishyWashyDB
    db.settings = db.settings or {}
    db.catches = db.catches or {}
    db.casts = db.casts or {}
    db.statsStart = db.statsStart or (db.catches[1] and db.catches[1].time) or time()
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

-- Every fishing catch, oldest first: { itemID, link, icon, quantity, time, zone }
function Storage.AddCatch(catch)
    table.insert(db.catches, catch)
end

function Storage.GetCatches()
    return db.catches
end

-- Every fishing cast, oldest first: { time, ended, caught, seconds }; seconds is set for caught casts
function Storage.AddCast(cast)
    table.insert(db.casts, cast)
end

function Storage.GetCasts()
    return db.casts
end

-- Clears the catches and casts that the stats are built from
function Storage.ClearCatches()
    db.catches = {}
    db.casts = {}
    db.statsStart = time()
end

-- When the stats were last reset
function Storage.GetStatsStart()
    return db.statsStart
end
