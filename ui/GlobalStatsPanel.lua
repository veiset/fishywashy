local _, ns = ...
local Panel, Storage, Catches, Stats = ns.Panel, ns.Storage, ns.Catches, ns.Stats

-- All-time totals and the share of each item caught; not cleared by resetting the session.
local GlobalStatsPanel = {}
ns.GlobalStatsPanel = GlobalStatsPanel

function GlobalStatsPanel.Create(parent)
    local panel = Panel.Create(parent, "Global stats", "No fish caught yet", 2)

    function panel.Refresh()
        local total, entries = Stats.GetGlobalSummary(Storage.GetSetting("statsIncludeMissed"))
        -- Advanced stats: the catch rate and sessions lines, and when each item was last caught
        local showLastSeen = Storage.GetSetting("globalShowLastSeen")
        panel:SetHeadingValue("Total: " .. total)
        panel:SetSubheading(1, Panel.FormatCastSummary(Stats.GetGlobalCastSummary()))
        panel:SetSubheading(2, "Sessions: " .. Storage.GetGlobalSessions(), "")
        panel:SetSubheadingsShown(showLastSeen)
        panel:SetEntries(entries, function(entry)
            local text = entry.missed and Panel.FormatMiss() or Panel.FormatItem(entry.icon, entry.link)
            local count = ("%d (%.0f%%)"):format(entry.count, entry.percent)
            if showLastSeen then
                -- Last seen before the count, which keeps the right-most column
                local lastSeen = entry.lastSeen and Panel.FormatTimeSince(entry.lastSeen) or ""
                return text, lastSeen, count
            end
            return text, count
        end)
    end

    Catches.OnChange(panel.Refresh)
    panel.Refresh()
    -- Keep the "last seen" times current
    C_Timer.NewTicker(60, panel.Refresh)
    return panel
end
