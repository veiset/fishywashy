local _, ns = ...
local Storage = ns.Storage

local Sound = {}
ns.Sound = Sound

local VOLUME_CVARS = { "Sound_MasterVolume", "Sound_SFXVolume" }
local FIXED_CVARS = {
    Sound_EnableSFX = "1",
    Sound_MusicVolume = "0",
    Sound_AmbienceVolume = "0",
}

function Sound.IsBoosted()
    return Storage.GetSoundBackup() ~= nil
end

function Sound.UpdateVolume()
    if not Sound.IsBoosted() then return end
    local volume = Storage.GetSetting("volume")
    for _, cvar in ipairs(VOLUME_CVARS) do
        SetCVar(cvar, volume)
    end
end

function Sound.Boost()
    if Sound.IsBoosted() then return end
    local backup = {}
    for _, cvar in ipairs(VOLUME_CVARS) do
        backup[cvar] = GetCVar(cvar)
    end
    for cvar, value in pairs(FIXED_CVARS) do
        backup[cvar] = GetCVar(cvar)
        SetCVar(cvar, value)
    end
    Storage.SetSoundBackup(backup)
    Sound.UpdateVolume()
end

function Sound.Restore()
    local backup = Storage.GetSoundBackup()
    if not backup then return end
    for cvar, value in pairs(backup) do
        SetCVar(cvar, value)
    end
    Storage.SetSoundBackup(nil)
end
