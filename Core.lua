local addonName, ns = ...
local Storage, Sound, UI = ns.Storage, ns.Sound, ns.UI

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
local FISHING = GetSpellName(7620)

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
        print("hello")
    elseif GetSpellName(spellID) == FISHING then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            if Storage.GetSetting("enabled") then Sound.Boost() end
        else
            Sound.Restore()
        end
    end
end)

SLASH_FISHYWASHY1 = "/fishy"
SlashCmdList.FISHYWASHY = UI.Toggle
