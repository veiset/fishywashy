local _, ns = ...
local Config, Panel, Storage, Catches, Stats = ns.Config, ns.Panel, ns.Storage, ns.Catches, ns.Stats

-- All-time totals and the share of each item caught; not cleared by resetting the session.
-- Lists the most caught items; the Details window has everything.
local GlobalStatsPanel = {}
ns.GlobalStatsPanel = GlobalStatsPanel

local function FormatEntry(entry)
    if entry.more then
        return ("|cff9d9d9d+ %d more|r"):format(#entry.rest)
    end
    return entry.missed and Panel.FormatMiss() or Panel.FormatItem(entry.icon, entry.link)
end

-- Items show the game's item tooltip; the "more" row lists the items it stands for
local function ShowTooltip(entry)
    if entry.more then
        GameTooltip:SetText(("%d more"):format(#entry.rest))
        for _, rest in ipairs(entry.rest) do
            GameTooltip:AddDoubleLine(FormatEntry(rest), ("%d (%.0f%%)"):format(rest.count, rest.percent),
                1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddLine("The Global stats button shows everything", 0.6, 0.6, 0.6)
    elseif entry.link then
        GameTooltip:SetHyperlink(entry.link)
    else
        GameTooltip:SetText("Casts that caught nothing")
    end
end

-- The first Config.GLOBAL_STATS_ROWS entries, then one row adding up the rest
local function TopEntries(entries)
    if #entries <= Config.GLOBAL_STATS_ROWS then
        return entries
    end
    local top, more = {}, { more = true, count = 0, percent = 0, rest = {} }
    for i, entry in ipairs(entries) do
        if i <= Config.GLOBAL_STATS_ROWS then
            table.insert(top, entry)
        else
            table.insert(more.rest, entry)
            more.count = more.count + entry.count
            more.percent = more.percent + entry.percent
        end
    end
    table.insert(top, more)
    return top
end

function GlobalStatsPanel.Create(parent)
    local panel = Panel.Create(parent, "Global stats", "No fish caught yet")

    function panel.Refresh()
        -- With "Current zone", only what was caught in the zone you're in
        local zone = Storage.GetSetting("globalCurrentZone") and GetRealZoneText() or nil
        local total, entries = Stats.GetGlobalSummary(Storage.GetSetting("statsIncludeMissed"), zone)
        panel:SetHeadingValue("Total: " .. total)
        panel:SetEntries(TopEntries(entries), function(entry)
            return FormatEntry(entry), ("%d (%.0f%%)"):format(entry.count, entry.percent)
        end, ShowTooltip)
    end

    Catches.OnChange(panel.Refresh)
    local events = CreateFrame("Frame")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", panel.Refresh)
    panel.Refresh()
    return panel
end
