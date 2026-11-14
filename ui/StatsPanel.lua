local _, ns = ...
local Utils, Config, Panel, Storage, Catches, Stats = ns.Utils, ns.Config, ns.Panel, ns.Storage, ns.Catches,
    ns.Stats

-- Totals, rates and the share of each item caught.
local StatsPanel = {}
ns.StatsPanel = StatsPanel

function StatsPanel.Create(parent)
    local panel = Panel.Create(parent, "Stats", "No fish caught yet", 3)
    panel:SetMaxRows(Config.STATS_ROWS)
    local caught = 0

    -- Per hour over the whole session, then per hour spent fishing, which leaves out breaks
    local function UpdateRates()
        local session, fishing = Stats.GetSessionLength(), Stats.GetFishingTime()
        panel:SetSubheading(1,
            ("Fish/hour: %.0f"):format(Stats.GetPerHour(caught, session)),
            "Session: " .. Utils.FormatDuration(session))
        panel:SetSubheading(2,
            ("Fish/hour fishing: %.0f"):format(Stats.GetPerHour(caught, fishing)),
            "Fishing: " .. Utils.FormatDuration(fishing))
    end

    local function UpdateCasts()
        panel:SetSubheading(3, Panel.FormatCastSummary(Stats.GetCastSummary()))
    end

    function panel.Refresh()
        local total, entries
        total, entries, caught = Stats.GetSummary(Storage.GetSetting("statsIncludeMissed"))
        panel:SetHeadingValue("Total: " .. total)
        -- Advanced stats: the two fish/hour lines and the catch rate line
        panel:SetSubheadingsShown(Storage.GetSetting("showAdvancedStats"))
        panel:SetEntries(entries, function(entry)
            local text = entry.missed and Panel.FormatMiss() or Panel.FormatItem(entry.icon, entry.link)
            return text, Utils.FormatCount(entry.count, entry.percent)
        end)
        UpdateRates()
        UpdateCasts()
    end

    Catches.OnChange(panel.Refresh)
    panel.Refresh()
    C_Timer.NewTicker(1, UpdateRates)
    return panel
end
