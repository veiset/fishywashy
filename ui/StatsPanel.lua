local _, ns = ...
local Utils, Panel, Storage, Catches, Stats = ns.Utils, ns.Panel, ns.Storage, ns.Catches, ns.Stats

-- Totals, rates and the share of each item caught.
local StatsPanel = {}
ns.StatsPanel = StatsPanel

function StatsPanel.Create(parent)
    local panel = Panel.Create(parent, "Stats", "No fish caught yet", 2)
    local caught = 0

    local function UpdateRates()
        panel:SetSubheading(1,
            ("Fish/hour: %.0f"):format(Stats.GetPerHour(caught)),
            "Session: " .. Utils.FormatDuration(Stats.GetSessionLength()))
    end

    local function UpdateCasts()
        panel:SetSubheading(2, Panel.FormatCastSummary(Stats.GetCastSummary()))
    end

    function panel.Refresh()
        local total, entries
        total, entries, caught = Stats.GetSummary(Storage.GetSetting("statsIncludeMissed"))
        panel:SetHeadingValue("Total: " .. total)
        -- Advanced stats: the fish/hour and catch rate lines
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
