local _, ns = ...
local Config, Storage, Bait, Catches = ns.Config, ns.Storage, ns.Bait, ns.Catches

-- Double right-click on the world to cast Fishing while a fishing pole is equipped.
local EasyCast = {}
ns.EasyCast = EasyCast

-- Only clicks on secure buttons may cast spells, so the second click of a double-click is
-- briefly bound to this button
local button = CreateFrame("Button", "FishyWashyCastButton", UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "spell")
button:SetAttribute("spell", Catches.FISHING)
button:SetScript("PostClick", function(self)
    if not InCombatLockdown() then
        ClearOverrideBindings(self)
    end
end)

local lastClick = 0

WorldFrame:HookScript("OnMouseDown", function(_, mouseButton)
    if mouseButton ~= "RightButton" then return end
    -- Bindings can't be changed in combat; right-clicking a unit should still target or loot it
    if not Storage.GetSetting("rightClickCast") or InCombatLockdown() or UnitExists("mouseover")
        or not Bait.HasFishingPole() then
        return
    end
    local now = GetTime()
    if now - lastClick < Config.DOUBLE_CLICK_TIME then
        lastClick = 0
        SetOverrideBindingClick(button, true, "BUTTON2", "FishyWashyCastButton")
    else
        lastClick = now
    end
end)

-- Don't leave the binding behind if combat starts before it was used
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    ClearOverrideBindings(button)
end)
