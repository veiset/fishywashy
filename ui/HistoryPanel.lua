local _, ns = ...
local Config, Panel, Catches = ns.Config, ns.Panel, ns.Catches

-- The most recent catches and unsuccessful casts.
local HistoryPanel = {}
ns.HistoryPanel = HistoryPanel

local function FormatTimeSince(timestamp)
    local seconds = time() - timestamp
    if seconds < 60 then
        return seconds .. "s ago"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m ago"
    else
        return math.floor(seconds / 3600) .. "h ago"
    end
end

function HistoryPanel.Create(parent)
    local panel = Panel.Create(parent, "History", "No fish caught yet")

    function panel.Refresh()
        panel:SetEntries(Catches.GetRecent(Config.RECENT_CATCHES), function(catch)
            if catch.missed then
                return Panel.FormatMiss(), FormatTimeSince(catch.time)
            end
            local text = Panel.FormatItem(catch.icon, catch.link)
            if catch.quantity > 1 then
                text = text .. " x" .. catch.quantity
            end
            return text, FormatTimeSince(catch.time)
        end)
    end

    Catches.OnChange(panel.Refresh)
    panel.Refresh()
    -- Keep the "time ago" labels current
    C_Timer.NewTicker(1, panel.Refresh)
    return panel
end
