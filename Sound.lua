local _, ns = ...
local Config, Storage, Catches = ns.Config, ns.Storage, ns.Catches

-- Boosts the sound while fishing so the bobber splash is easy to hear.
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

local boostTimer

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if not Catches.IsFishingSpell(spellID) then return end
    if boostTimer then
        boostTimer:Cancel()
        boostTimer = nil
    end
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        boostTimer = C_Timer.NewTimer(Config.BOOST_DELAY, function()
            boostTimer = nil
            if Storage.GetSetting("enabled") then Sound.Boost() end
        end)
    else
        Sound.Restore()
    end
end)
