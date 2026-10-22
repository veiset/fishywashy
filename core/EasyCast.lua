local _, ns = ...
local Config, Storage, CharacterInfo, Catches = ns.Config, ns.Storage, ns.CharacterInfo, ns.Catches

-- Double right-click on the world to cast Fishing while a fishing pole is equipped, and reel in
-- with a key or mouse button, right-click by default, while fishing.

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

-- The mouse is over the bobber when the game shows its tooltip. Only the English name is
-- known, so other languages always allow casting.
local BOBBER_NAME = "fishing bobber"

local function IsOverBobber()
    local line = GameTooltip:IsShown() and GameTooltipTextLeft1:GetText()
    return line and line:lower() == BOBBER_NAME
end

local function ClearBinding()
    if not InCombatLockdown() then
        ClearOverrideBindings(button)
    end
end

-- While the line is out, the reel-in key is bound to the game's interact key, which interacts
-- with the bobber without having to click on it. The game's "Enable Interact Key" option is turned
-- on while fishing if it's off, and set back after.
local interact = CreateFrame("Frame")

-- SoftTargetInteract is 0 for off, 1 for gamepad only, 2 for keyboard and mouse only and 3 for
-- both; "Enable Interact Key" sets 3
local INTERACT_KEY_ON = "3"
-- The player's own SoftTargetInteract while it's turned on for fishing, or nil
local savedInteractKey

local function BindInteract()
    if not Storage.GetSetting("reelIn") or InCombatLockdown() then return end
    local current = GetCVar("SoftTargetInteract")
    if (tonumber(current) or 0) < 2 then
        savedInteractKey = current
        SetCVar("SoftTargetInteract", INTERACT_KEY_ON)
    end
    SetOverrideBinding(interact, true, Storage.GetSetting("reelInKey"), "INTERACTTARGET")
end

local function ClearInteract()
    if InCombatLockdown() then return end
    ClearOverrideBindings(interact)
    if savedInteractKey then
        SetCVar("SoftTargetInteract", savedInteractKey)
        savedInteractKey = nil
    end
end

WorldFrame:HookScript("OnMouseDown", function(_, mouseButton)
    if mouseButton ~= "RightButton" then return end
    -- Bindings can't be changed in combat; right-clicking a unit should still target or loot it
    if not Storage.GetSetting("rightClickCast") or InCombatLockdown() or UnitExists("mouseover")
        or not CharacterInfo.HasFishingPole() then
        return
    end
    -- While the line is out, right-clicks on the bobber are for looting it. Once the cast
    -- has ended its fading tooltip no longer matters.
    if UnitChannelInfo("player") == Catches.FISHING and IsOverBobber() then
        lastClick = 0
        return
    end
    local now = GetTime()
    if now - lastClick < Config.DOUBLE_CLICK_TIME then
        lastClick = 0
        SetOverrideBindingClick(button, true, "BUTTON2", "FishyWashyCastButton")
        -- Normally used up by this click; never leave it behind for a later right-click
        C_Timer.After(Config.DOUBLE_CLICK_TIME, ClearBinding)
    else
        lastClick = now
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Logging out mid-cast sets the interact key back too
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if Catches.IsFishingSpell(spellID) then BindInteract() end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        ClearInteract()
    else
        -- Don't leave the bindings behind if combat starts or a loading screen comes before
        -- they were used
        ClearBinding()
        ClearInteract()
        lastClick = 0
    end
end)
