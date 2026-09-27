local _, ns = ...

-- Bait (fishing lures) is applied as a temporary enchant on the fishing pole.
local Bait = {}
ns.Bait = Bait

local MAIN_HAND_SLOT = 16
local WEAPON_CLASS = 2
local FISHING_POLE_SUBCLASS = 20

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

function Bait.GetCount(itemID)
    return GetItemCount(itemID)
end

-- Macro that uses the bait and applies it to the main hand (the fishing pole)
function Bait.GetApplyMacro(itemID)
    return "/use item:" .. itemID .. "\n/use " .. MAIN_HAND_SLOT
end

function Bait.HasFishingPole()
    local itemID = GetInventoryItemID("player", MAIN_HAND_SLOT)
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)
    return classID == WEAPON_CLASS and subclassID == FISHING_POLE_SUBCLASS
end

-- Seconds left on the bait, or nil when none is applied.
function Bait.GetTimeLeft()
    local hasEnchant, expiration = GetWeaponEnchantInfo()
    if hasEnchant then
        return expiration / 1000
    end
end
