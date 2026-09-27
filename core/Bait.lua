local _, ns = ...
local Utils, Storage = ns.Utils, ns.Storage

-- Bait (fishing lures) is applied as a temporary enchant on the fishing pole.
local Bait = {}
ns.Bait = Bait

-- The equipment slot the fishing pole goes in
Bait.MAIN_HAND_SLOT = 16
local MAIN_HAND_SLOT = Bait.MAIN_HAND_SLOT
local WEAPON_CLASS = 2
local FISHING_POLE_SUBCLASS = 20

local GetItemInfo, GetItemInfoInstant = Utils.GetItemInfo, Utils.GetItemInfoInstant
local GetItemCount, GetItemIcon = Utils.GetItemCount, Utils.GetItemIcon

-- Macro that uses the bait and applies it to the main hand (the fishing pole)
function Bait.GetApplyMacro(itemID)
    return "/use item:" .. itemID .. "\n/use " .. MAIN_HAND_SLOT
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

function Bait.HasFishingPole()
    local itemID = GetInventoryItemID("player", MAIN_HAND_SLOT)
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)
    return classID == WEAPON_CLASS and subclassID == FISHING_POLE_SUBCLASS
end

-- The trained fishing rank, and the temporary bonus on top of it, which in practice is the
-- applied bait. nil if Fishing isn't found.
local function GetRankAndLure()
    if GetProfessions then
        -- Newer clients: Fishing is the fourth profession slot
        local fishing = select(4, GetProfessions())
        if fishing then
            local _, _, rank, _, _, _, _, modifier = GetProfessionInfo(fishing)
            return rank, modifier or 0
        end
    elseif GetNumSkillLines then
        -- Older clients list it among the skills; missing if its section is collapsed
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, modifier = GetSkillLineInfo(i)
            if not isHeader and name == ns.Catches.FISHING then
                return rank, modifier
            end
        end
    end
end

-- The fishing number in a line such as "Increased Fishing +3." or
-- "Your Fishing Skill is increased by 8." (English wording only)
local function FishingNumber(line)
    return tonumber(line and line:match("[Ff]ishing[^%d]-(%d+)"))
end

-- The pole's own bonus, from its "Equip: Increased Fishing +3." tooltip line
local function GetRodBonus()
    local tooltip = C_TooltipInfo and C_TooltipInfo.GetInventoryItem("player", MAIN_HAND_SLOT)
    for _, line in ipairs(tooltip and tooltip.lines or {}) do
        -- Only the "Equip:" line; "Requires Fishing (1)" is not a bonus
        if line.leftText and line.leftText:match("^Equip:") then
            local bonus = FishingNumber(line.leftText)
            if bonus then return bonus end
        end
    end
    return 0
end

-- The skill number in a buff line such as "Your Fishing Skill is increased by 8." (English
-- wording only). Stricter than FishingNumber, so buffs like "Uncommon Fishing" that mention
-- fishing and a number without raising the skill aren't counted.
local function FishingSkillNumber(line)
    return tonumber(line and line:match("[Ff]ishing [Ss]kill[^%d]-(%d+)"))
end

-- Reads the buffs: the fishing skill bonus from buffs such as food, when the last of those runs
-- out (GetTime, or nil), and the other fishing buffs, such as "Uncommon Fishing":
-- { { name, icon, expires } }
local function ScanBuffs()
    local total, expires, others = 0, nil, {}
    for i = 1, 40 do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end
        local tooltip = C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", aura.auraInstanceID)
        local bonus
        for _, line in ipairs(tooltip and tooltip.lines or {}) do
            bonus = FishingSkillNumber(line.leftText)
            if bonus then break end
        end
        local auraExpires = aura.expirationTime and aura.expirationTime > 0 and aura.expirationTime or nil
        if bonus then
            total = total + bonus
            if auraExpires then
                expires = math.max(expires or 0, auraExpires)
            end
        elseif aura.name and aura.name:find("Fishing") then
            table.insert(others, { name = aura.name, icon = aura.icon, expires = auraExpires })
        end
    end
    return total, expires, others
end

-- The last buffs that could be read
local lastBuffBonus = 0
local lastBuffExpires
local lastOtherBuffs = {}

-- Buffs can't be read by addons in combat, and sometimes just after it, so keep the last
-- known bonus until they can be read again
local function GetBuffBonus()
    if not (C_UnitAuras and C_TooltipInfo) or InCombatLockdown() then
        return lastBuffBonus
    end
    local ok, bonus, expires, others = pcall(ScanBuffs)
    if ok then
        lastBuffBonus, lastBuffExpires, lastOtherBuffs = bonus, expires, others
    end
    return lastBuffBonus
end

-- The first fishing buff that doesn't raise the skill, such as "Uncommon Fishing":
-- { name, icon, timeLeft (nil if it doesn't run out) }, or nil. Uses the last buff scan.
function Bait.GetOtherFishingBuff()
    local buff = lastOtherBuffs[1]
    if not buff then return nil end
    local timeLeft = buff.expires and buff.expires - GetTime()
    if timeLeft and timeLeft <= 0 then return nil end
    return { name = buff.name, icon = buff.icon, timeLeft = timeLeft }
end

-- Seconds left on the fishing skill buff (such as fishing food), or nil when there is none.
-- Uses the last buff scan, which runs with the fishing skill every second.
function Bait.GetFoodBuffTimeLeft()
    local left = lastBuffExpires and lastBuffExpires - GetTime()
    if left and left > 0 then
        return left
    end
end

-- The first food from Config.FOOD_ITEMS that is in the bags, or nil
function Bait.GetBestFood()
    for _, itemID in ipairs(ns.Config.FOOD_ITEMS) do
        if GetItemCount(itemID) > 0 then
            return itemID
        end
    end
end

-- Fishing skill and where it comes from: { rank, lure, rod, buffs, total }, or nil if
-- Fishing isn't found
function Bait.GetFishingSkill()
    local rank, lure = GetRankAndLure()
    if not rank then return nil end
    local skill = { rank = rank, lure = lure or 0, rod = GetRodBonus(), buffs = GetBuffBonus() }
    skill.total = skill.rank + skill.lure + skill.rod + skill.buffs
    return skill
end

-- Seconds left on the bait, or nil when none is applied.
function Bait.GetTimeLeft()
    local hasEnchant, expiration = GetWeaponEnchantInfo()
    if hasEnchant then
        return expiration / 1000
    end
end
