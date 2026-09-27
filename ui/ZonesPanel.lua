local _, ns = ...
local Panel, Catches, Stats = ns.Panel, ns.Catches, ns.Stats

-- All-time items caught per zone, with the zone's most fished area.
local ZonesPanel = {}
ns.ZonesPanel = ZonesPanel

local TOP_SUBZONES = 1
local AREA_WIDTH = 135

-- "Steamwheedle Port 64%", or nil when no areas are known
local function FormatAreas(zone)
    local areas = {}
    for i = 1, math.min(TOP_SUBZONES, #zone.subzones) do
        local subzone = zone.subzones[i]
        table.insert(areas, ("%s %.0f%%"):format(subzone.name, subzone.percent))
    end
    if #areas > 0 then
        return table.concat(areas, ", ")
    end
end

-- Every area fished in the zone, with its share of the zone's catches
local function ShowAreasTooltip(zone)
    GameTooltip:SetText(zone.zone)
    for _, subzone in ipairs(zone.subzones) do
        GameTooltip:AddDoubleLine(subzone.name, ("%.0f%% (%d)"):format(subzone.percent, subzone.count),
            1, 1, 1, 1, 1, 1)
    end
end

function ZonesPanel.Create(parent)
    local panel = Panel.Create(parent, "Zones", "No fish caught yet")
    panel:SetValueWidth(AREA_WIDTH)

    function panel.Refresh()
        -- The area goes in the value column and the count in the fixed right-most column
        panel:SetEntries(Stats.GetZoneSummary(), function(zone)
            return zone.zone, FormatAreas(zone) or "", ("%d (%.0f%%)"):format(zone.count, zone.percent)
        end, ShowAreasTooltip)
    end

    Catches.OnChange(panel.Refresh)
    panel.Refresh()
    return panel
end
