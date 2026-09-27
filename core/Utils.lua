local _, ns = ...

-- Small helpers shared by the rest of the addon.
local Utils = {}
ns.Utils = Utils

-- Item and spell functions moved into C_Item and C_Spell in newer clients
Utils.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
Utils.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
Utils.GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
Utils.GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
Utils.GetSpellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo

-- Text colours, as used with Utils.Color
Utils.GREY = "9d9d9d"
Utils.GREEN = "40ff40"
Utils.RED = "ff4040"
Utils.SKILL_BLUE = "7777ff"

-- The text in a colour, such as Utils.GREY
function Utils.Color(text, color)
    return "|cff" .. color .. text .. "|r"
end

-- "6 (46%)"
function Utils.FormatCount(count, percent)
    return ("%d (%.0f%%)"):format(count, percent)
end

-- "12s ago", "5m ago", "3h ago" or "2d ago"
function Utils.FormatTimeSince(timestamp)
    local seconds = time() - timestamp
    if seconds < 60 then
        return seconds .. "s ago"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m ago"
    elseif seconds < 86400 then
        return math.floor(seconds / 3600) .. "h ago"
    else
        return math.floor(seconds / 86400) .. "d ago"
    end
end

-- "12m 34s", or "1h 05m" from an hour
function Utils.FormatDuration(seconds)
    if seconds < 3600 then
        return ("%dm %02ds"):format(seconds / 60, seconds % 60)
    end
    return ("%dh %02dm"):format(seconds / 3600, seconds % 3600 / 60)
end

-- "45s", or "9m" from a minute
function Utils.FormatShortTime(seconds)
    if seconds < 60 then
        return ("%ds"):format(seconds)
    end
    return ("%dm"):format(seconds / 60)
end

-- "9:30"
function Utils.FormatClock(seconds)
    return ("%d:%02d"):format(seconds / 60, seconds % 60)
end

-- The item name in an item link, such as "Raw Brilliant Smallfish", or nil
function Utils.GetLinkName(link)
    return link and link:match("%[(.-)%]")
end
