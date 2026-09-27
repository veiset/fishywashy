local addonName, ns = ...
local Storage, Sound, UI = ns.Storage, ns.Sound, ns.UI

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    Storage.Init()
    -- Settings left boosted by a logout or crash mid-cast
    Sound.Restore()
    UI.Init()
    print("FishyWashy loaded, equip a fishing rod or type /fishy to open")
end)

SLASH_FISHYWASHY1 = "/fishy"
SlashCmdList.FISHYWASHY = UI.Toggle
