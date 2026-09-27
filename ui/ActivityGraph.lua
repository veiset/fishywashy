local _, ns = ...
local Stats = ns.Stats

-- A 24-bar graph of the hours of the day you cast in, all-time.
local ActivityGraph = {}
ns.ActivityGraph = ActivityGraph

local GRAPH_HEIGHT = 30
-- The bars, the hour labels under them, and a little space
ActivityGraph.HEIGHT = GRAPH_HEIGHT + 20
local BAR_GAP = 1
local LABEL_HOURS = { 0, 6, 12, 18 }

-- Draws the graph in the given frame; returns a function that redraws it
function ActivityGraph.Create(parent)
    local graph = CreateFrame("Frame", nil, parent)
    graph:SetPoint("TOPLEFT", 12, 0)
    graph:SetPoint("TOPRIGHT", -10, 0)
    graph:SetHeight(GRAPH_HEIGHT)
    local baseline = graph:CreateTexture(nil, "ARTWORK")
    baseline:SetColorTexture(1, 1, 1, 0.2)
    baseline:SetHeight(1)
    baseline:SetPoint("BOTTOMLEFT")
    baseline:SetPoint("BOTTOMRIGHT")

    local bars, hoverAreas = {}, {}
    for i = 1, 24 do
        bars[i] = graph:CreateTexture(nil, "ARTWORK")
        bars[i]:SetColorTexture(1, 0.82, 0, 0.8)

        -- Covers the whole hour's column, so short bars are easy to hover
        local hover = CreateFrame("Frame", nil, graph)
        hover:EnableMouse(true)
        hover:SetScript("OnEnter", function(self)
            local hours, _, _, total = Stats.GetActivityByHour()
            local percent = total > 0 and hours[i] / total * 100 or 0
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(("%02d:00-%02d:59"):format(i - 1, i - 1))
            GameTooltip:AddLine(("%.0f%% of casts (%d)"):format(percent, hours[i]), 1, 1, 1)
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", GameTooltip_Hide)
        hoverAreas[i] = hover
    end

    local labels = {}
    for _, hour in ipairs(LABEL_HOURS) do
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetText(("%02d"):format(hour))
        labels[hour] = label
    end

    local function Redraw()
        local slot = graph:GetWidth() / 24
        if slot <= 0 then return end
        local hours, max = Stats.GetActivityByHour()
        for i, bar in ipairs(bars) do
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * slot, 0)
            bar:SetWidth(slot - BAR_GAP)
            bar:SetHeight(max > 0 and math.max(hours[i] / max * GRAPH_HEIGHT, 1) or 1)
            bar:SetShown(hours[i] > 0)
            hoverAreas[i]:ClearAllPoints()
            hoverAreas[i]:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * slot, 0)
            hoverAreas[i]:SetSize(slot, GRAPH_HEIGHT)
        end
        for hour, label in pairs(labels) do
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", hour * slot, -2)
        end
    end
    graph:SetScript("OnSizeChanged", Redraw)
    return Redraw
end

-- "Busiest: 21:00 (18%)", or "" until there are casts
function ActivityGraph.FormatBusiest()
    local _, max, peak, total = Stats.GetActivityByHour()
    return peak and ("Busiest: %02d:00 (%.0f%%)"):format(peak, max / total * 100) or ""
end
