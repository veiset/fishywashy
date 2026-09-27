local _, ns = ...

-- All access to the FishyWashyDB saved variable goes through here.
local Storage = {}
ns.Storage = Storage

local SCHEMA_VERSION = 1

local DEFAULTS = {
    enabled = false,
    volume = 1,
}

local db

function Storage.Init()
    if type(FishyWashyDB) ~= "table" or FishyWashyDB.version == nil then
        FishyWashyDB = { version = SCHEMA_VERSION }
    end
    db = FishyWashyDB
    db.settings = db.settings or {}
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
