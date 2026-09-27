local addonName, ns = ...
local Storage, Sound, Catches, Debug, UI = ns.Storage, ns.Sound, ns.Catches, ns.Debug, ns.UI

-- Skip the sound of the cast itself before boosting
local BOOST_DELAY = 0.5

local boostTimer

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

events:SetScript("OnEvent", function(self, event, arg1, _, spellID)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent(event)
        Storage.Init()
        -- Settings left boosted by a logout or crash mid-cast
        Sound.Restore()
        UI.Init()
        Debug.Init()
        print("hello")
    elseif Catches.IsFishingSpell(spellID) then
        if boostTimer then
            boostTimer:Cancel()
            boostTimer = nil
        end
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            boostTimer = C_Timer.NewTimer(BOOST_DELAY, function()
                boostTimer = nil
                if Storage.GetSetting("enabled") then Sound.Boost() end
            end)
        else
            Sound.Restore()
        end
    end
end)

SLASH_FISHYWASHY1 = "/fishy"
SlashCmdList.FISHYWASHY = function(message)
    if message:lower():match("^%s*debug%s*$") then
        Debug.Toggle()
    else
        UI.Toggle()
    end
end
