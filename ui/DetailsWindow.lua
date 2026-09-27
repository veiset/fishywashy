local _, ns = ...
local Panel, Storage, Catches, Stats = ns.Panel, ns.Storage, ns.Catches, ns.Stats

-- A separate window with every all-time catch, grouped into fish, treasure and junk, and
-- every zone with all its areas.
local DetailsWindow = {}
ns.DetailsWindow = DetailsWindow

local WIDTH = 460
local HEIGHT = 480
local SCROLLBAR_WIDTH = 26
-- Pixels per mouse wheel notch: two rows
local SCROLL_STEP = 32

local CATEGORIES = {
    { key = "fish", title = "Fish" },
    { key = "other", title = "Treasure & other" },
    { key = "junk", title = "Junk" },
}

local window
local summary, zones
local sections = {}

local function FormatCount(count, percent)
    return ("%d (%.0f%%)"):format(count, percent)
end

local function ShowItemTooltip(entry)
    GameTooltip:SetHyperlink(entry.link)
end

-- Item rows in the loot tables show the item; zone and area rows explain the numbers
local function ShowZoneTooltip(row)
    if row.link then
        GameTooltip:SetHyperlink(row.link)
    else
        GameTooltip:SetText("Items caught here, and their share")
    end
end

-- Stacks the sections in the scroll area and sizes it to fit
local function Layout(content)
    local height = 0
    local previous
    local panels = { summary }
    for _, category in ipairs(CATEGORIES) do
        table.insert(panels, sections[category.key])
    end
    table.insert(panels, zones)
    for _, panel in ipairs(panels) do
        panel:ClearAllPoints()
        if previous then
            panel:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
            panel:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT")
        else
            panel:SetPoint("TOPLEFT")
            panel:SetPoint("TOPRIGHT")
        end
        previous = panel
        height = height + panel:GetHeight()
    end
    content:SetHeight(height)
end

local function Refresh()
    local total, entries = Stats.GetGlobalSummary(false)

    -- Split the items into the categories, keeping their share of all items
    local byCategory, counts = {}, {}
    for _, category in ipairs(CATEGORIES) do
        byCategory[category.key] = {}
        counts[category.key] = 0
    end
    for _, entry in ipairs(entries) do
        local key = Stats.GetItemCategory(entry.itemID, entry.link)
        table.insert(byCategory[key], entry)
        counts[key] = counts[key] + entry.count
    end

    -- Summary: one row per category, plus the casts that caught nothing
    local caught, unsuccessful = Storage.GetGlobalCasts()
    local rows = {}
    for _, category in ipairs(CATEGORIES) do
        table.insert(rows, { name = category.title, count = counts[category.key] })
    end
    summary:SetHeadingValue("Total: " .. total)
    summary:SetSubheading(1, Panel.FormatCastSummary(Stats.GetGlobalCastSummary()))
    summary:SetSubheading(2, "Sessions: " .. Storage.GetGlobalSessions(),
        ("Unsuccessful casts: %d"):format(unsuccessful))
    summary:SetEntries(total > 0 and rows or {}, function(row)
        return row.name, FormatCount(row.count, row.count / total * 100)
    end)

    for _, category in ipairs(CATEGORIES) do
        local section = sections[category.key]
        section:SetHeadingValue(counts[category.key] .. " caught")
        section:SetEntries(byCategory[category.key], function(entry)
            local lastSeen = entry.lastSeen and Panel.FormatTimeSince(entry.lastSeen) or ""
            return Panel.FormatItem(entry.icon, entry.link), lastSeen, FormatCount(entry.count, entry.percent)
        end, ShowItemTooltip)
    end

    -- Zones, each followed by its areas, and each area by its loot table: every item caught
    -- there with its drop rate
    local zoneRows = {}
    for _, zone in ipairs(Stats.GetZoneSummary()) do
        table.insert(zoneRows, { text = zone.zone, value = FormatCount(zone.count, zone.percent), heading = true })
        for _, subzone in ipairs(zone.subzones) do
            table.insert(zoneRows, {
                text = "    |cff9d9d9d" .. subzone.name .. "|r",
                value = FormatCount(subzone.count, subzone.percent),
                heading = true,
            })
            for _, item in ipairs(subzone.items) do
                table.insert(zoneRows, {
                    text = "        " .. Panel.FormatItem(item.icon, item.link),
                    value = FormatCount(item.count, item.percent),
                    link = item.link,
                })
            end
        end
    end
    zones:SetEntries(zoneRows, function(row)
        return row.text, row.value
    end, ShowZoneTooltip)

    Layout(summary:GetParent())
end

local function Create()
    window = CreateFrame("Frame", "FishyWashyDetailsFrame", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    window:SetBackdropColor(0, 0, 0, 0.85)
    window:SetBackdropBorderColor(1, 1, 1, 0.6)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    -- Escape closes it
    table.insert(UISpecialFrames, "FishyWashyDetailsFrame")

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("FishyWashy all-time stats")
    Panel.CreateCloseButton(window, function() window:Hide() end)
    Panel.CreateDivider(window, -24)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -26)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_WIDTH, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(WIDTH - SCROLLBAR_WIDTH)
    scroll:SetScrollChild(content)
    -- The template scrolls half the window per wheel notch; move a couple of rows instead
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local position = self:GetVerticalScroll() - delta * SCROLL_STEP
        self:SetVerticalScroll(math.max(0, math.min(position, self:GetVerticalScrollRange())))
    end)

    summary = Panel.Create(content, "All-time", "No fish caught yet", 2)
    for _, category in ipairs(CATEGORIES) do
        sections[category.key] = Panel.Create(content, category.title, "None yet")
    end
    zones = Panel.Create(content, "Zones", "No fish caught yet")
    -- Striped item rows, as the numbers are far from the names in this wide window
    for _, section in pairs(sections) do
        section:SetStriped(true)
    end
    zones:SetStriped(true)

    window:SetScript("OnShow", Refresh)
    Catches.OnChange(function()
        if window:IsShown() then Refresh() end
    end)
end

function DetailsWindow.Toggle()
    if not window then
        Create()
        Refresh()
        return
    end
    window:SetShown(not window:IsShown())
end
