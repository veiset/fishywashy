local _, ns = ...
local Config, Storage, CharacterInfo, Catches, Bait = ns.Config, ns.Storage, ns.CharacterInfo, ns.Catches, ns.Bait

-- Cast Fishing with a double right-click on the world or with a hotkey while a fishing pole is
-- equipped, and reel in with a key or mouse button, right-click by default, while fishing.
local EasyCast = {}
ns.EasyCast = EasyCast

-- Only clicks on secure buttons may cast spells, so the second click of a double-click, or the
-- hotkey, is bound to this button
local button = CreateFrame("Button", "FishyWashyCastButton", UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "spell")
button:SetAttribute("spell", Catches.FISHING)

-- The bait this click applies instead of casting, or nil
local baitToApply

-- With auto bait on and no bait applied, the click applies the strongest bait in the bags that
-- the fishing skill allows instead, and the next one casts. Attributes can only change out of combat, which is also the
-- only time the double-click and the hotkey are bound.
button:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    baitToApply = Storage.GetSetting("autoBait") and not Bait.GetTimeLeft() and Bait.GetBest() or nil
    if baitToApply then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", Bait.GetApplyMacro(baitToApply))
    else
        self:SetAttribute("type", "spell")
    end
end)
button:SetScript("PostClick", function(self)
    -- Counted once the bait actually leaves the bags
    if baitToApply then
        Bait.WatchForUse(baitToApply)
    end
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
-- The key bound to reel in now, or nil
local reelInBound

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
    reelInBound = Storage.GetSetting("reelInKey")
    SetOverrideBinding(interact, true, reelInBound, "INTERACTTARGET")
end

local function ClearInteract()
    if InCombatLockdown() then return end
    ClearOverrideBindings(interact)
    reelInBound = nil
    if savedInteractKey then
        SetCVar("SoftTargetInteract", savedInteractKey)
        savedInteractKey = nil
    end
end

-- The hotkey casts Fishing while a fishing pole is equipped, out of combat
local hotkey = CreateFrame("Frame")
-- The key bound to cast now, or nil
local hotkeyBound

-- Binds the hotkey, or clears it, to match the settings, the fishing pole and the line.
-- Called again whenever any of them change.
function EasyCast.UpdateHotkey()
    if InCombatLockdown() then return end
    local key = Storage.GetSetting("castMode") == "hotkey" and CharacterInfo.HasFishingPole()
        and Storage.GetSetting("castKey") or nil
    -- While the line is out the same key reels in, so one key can both cast and reel in
    if key == reelInBound then
        key = nil
    end
    if key == hotkeyBound then return end
    ClearOverrideBindings(hotkey)
    if key then
        SetOverrideBindingClick(hotkey, true, key, "FishyWashyCastButton")
    end
    hotkeyBound = key
end

local function ClearHotkey()
    if InCombatLockdown() then return end
    ClearOverrideBindings(hotkey)
    hotkeyBound = nil
end

WorldFrame:HookScript("OnMouseDown", function(_, mouseButton)
    if mouseButton ~= "RightButton" then return end
    -- Bindings can't be changed in combat; right-clicking a unit should still target or loot it
    if Storage.GetSetting("castMode") ~= "doubleClick" or InCombatLockdown() or UnitExists("mouseover")
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
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Fires once the equipment is known again, e.g. after a loading screen
events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
-- Logging out mid-cast sets the interact key back too
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if Catches.IsFishingSpell(spellID) then BindInteract() end
        EasyCast.UpdateHotkey()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        ClearInteract()
        EasyCast.UpdateHotkey()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED"
        or event == "PLAYER_REGEN_ENABLED" then
        EasyCast.UpdateHotkey()
    else
        -- Don't leave the bindings behind if combat starts or a loading screen comes before
        -- they were used; the hotkey is bound again after combat, or once the pole is known
        ClearBinding()
        ClearInteract()
        ClearHotkey()
        lastClick = 0
        if event == "PLAYER_ENTERING_WORLD" then
            EasyCast.UpdateHotkey()
        end
    end
end)
