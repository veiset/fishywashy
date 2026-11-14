local _, ns = ...
local Storage, CharacterInfo = ns.Storage, ns.CharacterInfo

-- While a fishing pole is equipped, the game's Auto Loot follows the autoLoot setting: on when
-- it's checked and off when it's not, whatever the player's own setting is. Once the pole is
-- unequipped, it's set back to the player's own setting.
local AutoLoot = {}
ns.AutoLoot = AutoLoot

local CVAR = "autoLootDefault"

-- Sets Auto Loot to match the setting while the pole is equipped, or back to the player's own
-- setting when it's not. Called again whenever either changes. Changes wait until combat ends.
function AutoLoot.Update()
    if InCombatLockdown() then return end
    local wanted = CharacterInfo.HasFishingPole() and (Storage.GetSetting("autoLoot") and "1" or "0") or nil
    local backup = Storage.GetAutoLootBackup()
    if wanted and not backup then
        local current = GetCVar(CVAR)
        if current ~= wanted then
            -- Saved first, so a logout or crash before it's set back still restores it
            Storage.SetAutoLootBackup(current)
            SetCVar(CVAR, wanted)
        end
    elseif wanted and wanted == backup then
        -- The setting now matches the player's own, so there's nothing to set back later
        SetCVar(CVAR, backup)
        Storage.SetAutoLootBackup(nil)
    elseif wanted then
        if GetCVar(CVAR) ~= wanted then
            SetCVar(CVAR, wanted)
        end
    elseif backup then
        SetCVar(CVAR, backup)
        Storage.SetAutoLootBackup(nil)
    end
end

local function Restore()
    local backup = Storage.GetAutoLootBackup()
    if backup then
        SetCVar(CVAR, backup)
        Storage.SetAutoLootBackup(nil)
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
        -- The player's own setting is what's saved, even when logging out with the pole on
        Restore()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Right after a loading screen the main hand can look empty for a moment, so check
        -- once it has settled
        C_Timer.After(1, AutoLoot.Update)
    else
        AutoLoot.Update()
    end
end)
