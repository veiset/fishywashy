local _, ns = ...
local Config, Panel, Storage, Catches, ActivityGraph = ns.Config, ns.Panel, ns.Storage, ns.Catches, ns.ActivityGraph

-- A graph of when you fish, then the most recent catches and unsuccessful casts.
local HistoryPanel = {}
ns.HistoryPanel = HistoryPanel

function HistoryPanel.Create(parent)
    local panel = Panel.Create(parent, "History", "No fish caught yet")
    local redrawGraph = ActivityGraph.Create(panel:AddHeaderContent(ActivityGraph.HEIGHT))

    function panel.Refresh()
        local showGraph = Storage.GetSetting("showHistoryGraph")
        panel:SetHeaderContentShown(showGraph)
        panel:SetHeadingValue(showGraph and ActivityGraph.FormatBusiest() or "")
        redrawGraph()
        panel:SetEntries(Catches.GetRecent(Config.RECENT_CATCHES), function(catch)
            if catch.missed then
                return Panel.FormatMiss(), Panel.FormatTimeSince(catch.time)
            end
            local text = Panel.FormatItem(catch.icon, catch.link)
            if catch.quantity > 1 then
                text = text .. " x" .. catch.quantity
            end
            return text, Panel.FormatTimeSince(catch.time)
        end)
    end

    Catches.OnChange(panel.Refresh)
    panel.Refresh()
    -- Keep the "time ago" labels current
    C_Timer.NewTicker(1, panel.Refresh)
    return panel
end
