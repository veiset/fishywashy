local _, ns = ...
local Utils, Storage, CharacterInfo = ns.Utils, ns.Storage, ns.CharacterInfo

-- Bait (fishing lures) is applied as a temporary enchant on the fishing pole.
local Bait = {}
ns.Bait = Bait

local GetItemInfo, GetItemCount, GetItemIcon = Utils.GetItemInfo, Utils.GetItemCount, Utils.GetItemIcon

-- Macro that uses the bait and applies it to the main hand (the fishing pole)
function Bait.GetApplyMacro(itemID)
    return "/use item:" .. itemID .. "\n/use " .. CharacterInfo.MAIN_HAND_SLOT
end

-- How long to wait, after a bait button is clicked, for the bait to leave the bags
local USE_TIMEOUT = 10
local CHECK_INTERVAL = 0.5

-- Baits whose button was clicked and that are waiting to be used up
local watching = {}

-- Called when a bait's button is clicked: counts the bait as used once one actually leaves
-- the bags, so extra clicks, failed casts and refused replacements don't count
function Bait.WatchForUse(itemID)
    if watching[itemID] then return end
    watching[itemID] = true
    local before = GetItemCount(itemID)
    local checks = 0
    local ticker
    ticker = C_Timer.NewTicker(CHECK_INTERVAL, function()
        checks = checks + 1
        if GetItemCount(itemID) < before then
            local _, link = GetItemInfo(itemID)
            Storage.AddBaitUsed(itemID, link, GetItemIcon(itemID))
        elseif checks < USE_TIMEOUT / CHECK_INTERVAL then
            return
        end
        watching[itemID] = nil
        ticker:Cancel()
    end)
end

-- Seconds left on the bait, or nil when none is applied.
function Bait.GetTimeLeft()
    local hasEnchant, expiration = GetWeaponEnchantInfo()
    if hasEnchant then
        return expiration / 1000
    end
end
