local _, ns = ...
local Storage = ns.Storage

-- Aggregates the catch history into stats.
local Stats = {}
ns.Stats = Stats

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

    table.sort(entries, function(a, b) return a.count > b.count end)
    for _, entry in ipairs(entries) do
        entry.percent = entry.count / total * 100
    end
    return total, entries, caught
end

-- Share of casts that were caught, casts caught, all casts, and average seconds from cast to catch.
-- The rate and average are nil until there's data for them.
function Stats.GetCastSummary()
    local casts, caught, seconds = 0, 0, 0
    for _, cast in ipairs(Storage.GetCasts()) do
        casts = casts + 1
        if cast.caught then
            caught = caught + 1
            seconds = seconds + cast.seconds
        end
    end
    local rate = casts > 0 and caught / casts * 100 or nil
    local average = caught > 0 and seconds / caught or nil
    return rate, caught, casts, average
end

-- Seconds since the stats were last reset
function Stats.GetSessionLength()
    return time() - Storage.GetStatsStart()
end

-- Items caught per hour since the stats were last reset
function Stats.GetPerHour(total)
    return total / (math.max(Stats.GetSessionLength(), 1) / 3600)
end
