local _, ns = ...
local Storage = ns.Storage

-- Aggregates the catch history into stats.
local Stats = {}
ns.Stats = Stats

-- Sorts entries by count, most first, and sets each one's percent of the total
local function AddShares(entries, total)
    table.sort(entries, function(a, b) return a.count > b.count end)
    for _, entry in ipairs(entries) do
        entry.percent = entry.count / total * 100
    end
end

local function CountMissed()
    local missed = 0
    for _, cast in ipairs(Storage.GetCasts()) do
        if not cast.caught then
            missed = missed + 1
        end
    end
    return missed
end

-- Each item's count and share of the total, most caught first. With includeMissed, missed
-- casts are counted as an entry { missed = true } too.
-- Returns the total the shares are of, the entries, and the number of items caught.
function Stats.GetSummary(includeMissed)
    local caught, byItem, entries = 0, {}, {}
    for _, catch in ipairs(Storage.GetCatches()) do
        local entry = byItem[catch.itemID]
        if not entry then
            entry = { itemID = catch.itemID, link = catch.link, icon = catch.icon, count = 0 }
            byItem[catch.itemID] = entry
            table.insert(entries, entry)
        end
        entry.count = entry.count + catch.quantity
        caught = caught + catch.quantity
    end

    local total = caught
    if includeMissed then
        local missed = CountMissed()
        if missed > 0 then
            table.insert(entries, { missed = true, count = missed })
            total = total + missed
        end
    end

    AddShares(entries, total)
    return total, entries, caught
end

-- All-time count and share of each item, most caught first, and the all-time total. With
-- includeMissed, unsuccessful casts are counted as an entry { missed = true } too.
function Stats.GetGlobalSummary(includeMissed)
    local total, entries = 0, {}
    for itemID, item in pairs(Storage.GetGlobalItems()) do
        table.insert(entries, {
            itemID = itemID, link = item.link, icon = item.icon, count = item.count, lastSeen = item.lastSeen,
        })
        total = total + item.count
    end
    local _, missed = Storage.GetGlobalCasts()
    if includeMissed and missed > 0 then
        table.insert(entries, { missed = true, count = missed })
        total = total + missed
    end
    AddShares(entries, total)
    return total, entries
end

-- Each bait used, how often and its share of all baits used, most used first, and the total
function Stats.GetBaitSummary()
    local total, entries = 0, {}
    for itemID, bait in pairs(Storage.GetGlobalBaitUsed()) do
        table.insert(entries, {
            itemID = itemID, link = bait.link, icon = bait.icon, count = bait.count, lastSeen = bait.lastSeen,
        })
        total = total + bait.count
    end
    AddShares(entries, total)
    return total, entries
end

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local CONSUMABLE_CLASS = 0
local TRADE_GOODS_CLASS = 7

-- "junk" for poor (grey) items, "fish" for food and trade goods such as raw fish, and
-- "other" for everything else, such as chests, clams and recipes
function Stats.GetItemCategory(itemID, link)
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
    -- Not cached yet: links carry the quality as "|cnIQ0:" or as the grey colour
    if not quality and link then
        quality = tonumber(link:match("IQ(%d)")) or (link:find("ff9d9d9d") and 0)
    end
    if quality == 0 then
        return "junk"
    end
    local classID = select(6, GetItemInfoInstant(itemID))
    if classID == CONSUMABLE_CLASS or classID == TRADE_GOODS_CLASS then
        return "fish"
    end
    return "other"
end

-- The items caught in one area and their drop rate: each item's share of that area's catches
local function GetAreaItems(zone, subzone)
    local total, items = 0, {}
    for itemID, item in pairs(Storage.GetGlobalAreaItems(zone, subzone)) do
        table.insert(items, { itemID = itemID, link = item.link, icon = item.icon, count = item.count })
        total = total + item.count
    end
    AddShares(items, total)
    return items
end

-- All-time items caught in each zone and its share of the total, most first, with the zone's
-- areas and each one's share of the zone, most first, and each area's items:
-- { zone, count, percent, subzones = { { name, count, percent, items = { ... } } } }
function Stats.GetZoneSummary()
    local total, entries = 0, {}
    for name, zone in pairs(Storage.GetGlobalZones()) do
        local subzones = {}
        for subzone, count in pairs(zone.subzones) do
            table.insert(subzones, { name = subzone, count = count, items = GetAreaItems(name, subzone) })
        end
        AddShares(subzones, zone.count)
        table.insert(entries, { zone = name, count = zone.count, subzones = subzones })
        total = total + zone.count
    end
    AddShares(entries, total)
    return entries
end

-- All-time casts started in each hour of the day (index 1 is 00:00-00:59), the busiest
-- hour's count, that hour (0-23, nil until there are casts), and the total casts
function Stats.GetActivityByHour()
    local hours, max, peak, total = {}, 0, nil, 0
    local stored = Storage.GetGlobalHours()
    for i = 1, 24 do
        hours[i] = stored[i] or 0
        total = total + hours[i]
        if hours[i] > max then
            max, peak = hours[i], i - 1
        end
    end
    return hours, max, peak, total
end

-- Share of casts that were caught, casts caught, all casts, and average seconds from cast to catch.
-- The rate and average are nil until there's data for them.
local function SummarizeCasts(caught, casts, seconds)
    local rate = casts > 0 and caught / casts * 100 or nil
    local average = caught > 0 and seconds / caught or nil
    return rate, caught, casts, average
end

-- This session's catch rate and average seconds per catch; see SummarizeCasts
function Stats.GetCastSummary()
    local casts, caught, seconds = 0, 0, 0
    for _, cast in ipairs(Storage.GetCasts()) do
        casts = casts + 1
        if cast.caught then
            caught = caught + 1
            seconds = seconds + cast.seconds
        end
    end
    return SummarizeCasts(caught, casts, seconds)
end

-- All-time catch rate and average seconds per catch; see SummarizeCasts
function Stats.GetGlobalCastSummary()
    local caught, unsuccessful, seconds = Storage.GetGlobalCasts()
    return SummarizeCasts(caught, caught + unsuccessful, seconds)
end

-- Seconds since the stats were last reset
function Stats.GetSessionLength()
    return time() - Storage.GetStatsStart()
end

-- Items caught per hour since the stats were last reset
function Stats.GetPerHour(total)
    return total / (math.max(Stats.GetSessionLength(), 1) / 3600)
end
