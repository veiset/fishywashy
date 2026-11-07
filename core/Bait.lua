local _, ns = ...
local Utils, Config, Storage, CharacterInfo = ns.Utils, ns.Config, ns.Storage, ns.CharacterInfo

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

-- The game's red, which item tooltips use for requirements the character doesn't meet
local function IsRed(color)
    return color and color.r > 0.99 and color.g < 0.2 and color.b < 0.2
end

-- Whether the character can use the bait yet: most need some fishing skill, such as "Requires
-- Fishing (100)". The game shows that line in red until the skill is high enough, which works
-- in any language. Assumed usable when the tooltip can't be read.
function Bait.CanUse(itemID)
    local tooltip = C_TooltipInfo and C_TooltipInfo.GetItemByID(itemID)
    for _, line in ipairs(tooltip and tooltip.lines or {}) do
        if line.leftText and IsRed(line.leftColor) then
            return false
        end
    end
    return true
end

-- The strongest bait in the bags that the character can use, from Config.BAIT_ITEMS, or nil
-- when there's none
function Bait.GetBest()
    for _, itemID in ipairs(Config.BAIT_ITEMS) do
        if GetItemCount(itemID) > 0 and Bait.CanUse(itemID) then
            return itemID
        end
    end
end

-- Seconds left on the bait, or nil when none is applied.
function Bait.GetTimeLeft()
    local hasEnchant, expiration = GetWeaponEnchantInfo()
    if hasEnchant then
        return expiration / 1000
    end
end
