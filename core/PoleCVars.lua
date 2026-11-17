local _, ns = ...
local Storage, CharacterInfo = ns.Storage, ns.CharacterInfo

-- Game settings that follow FishyWashy's settings while a fishing pole is equipped, and are set
-- back to the player's own once it's unequipped or on logout.
local PoleCVars = {}
ns.PoleCVars = PoleCVars

-- Each game setting and the value it should have while the pole is equipped, or nil to leave
-- it as the player has it
local WANTED = {
    -- Auto Loot: on or off, whatever the player's own setting is
    autoLootDefault = function()
        return Storage.GetSetting("autoLoot") and "1" or "0"
    end,
    -- Sound in Background, so the splash is heard with another window in front. On for the
    -- whole time rather than per cast, so it's already on whenever the game loses focus.
    Sound_EnableSoundWhenGameIsInBG = function()
        return Storage.GetSetting("soundInBackground") and "1" or nil
    end,
}

local function UpdateCVar(cvar, wanted)
    local backup = Storage.GetPoleCVarBackup(cvar)
    if wanted and not backup then
        local current = GetCVar(cvar)
        if current ~= wanted then
            -- Saved first, so a logout or crash before it's set back still restores it
            Storage.SetPoleCVarBackup(cvar, current)
            SetCVar(cvar, wanted)
        end
    elseif wanted and wanted == backup then
        -- The setting now matches the player's own, so there's nothing to set back later
        SetCVar(cvar, backup)
        Storage.SetPoleCVarBackup(cvar, nil)
    elseif wanted then
        if GetCVar(cvar) ~= wanted then
            SetCVar(cvar, wanted)
        end
    elseif backup then
        SetCVar(cvar, backup)
        Storage.SetPoleCVarBackup(cvar, nil)
    end
end

-- Sets the game settings to match FishyWashy's while the pole is equipped, or back to the
-- player's own when it's not. Called again whenever either changes. Changes wait until combat
-- ends.
function PoleCVars.Update()
    if InCombatLockdown() then return end
    local hasPole = CharacterInfo.HasFishingPole()
    for cvar, getWanted in pairs(WANTED) do
        UpdateCVar(cvar, hasPole and getWanted() or nil)
    end
end

local function RestoreAll()
    for cvar in pairs(WANTED) do
        UpdateCVar(cvar, nil)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Fires once the equipment is known again, e.g. after a loading screen
events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        -- The player's own settings are what's saved, even when logging out with the pole on
        RestoreAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Right after a loading screen the main hand can look empty for a moment, so check
        -- once it has settled
        C_Timer.After(1, PoleCVars.Update)
    else
        PoleCVars.Update()
    end
end)
