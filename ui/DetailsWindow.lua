local _, ns = ...
local Utils, Panel, Storage, Catches, Stats = ns.Utils, ns.Panel, ns.Storage, ns.Catches, ns.Stats

-- A separate window with every all-time catch, grouped into fish, treasure and junk, and
-- every zone with all its areas.
local DetailsWindow = {}
ns.DetailsWindow = DetailsWindow

local WIDTH = 460
local HEIGHT = 480
local SCROLLBAR_WIDTH = 26
-- Where text starts from the left edge; a little roomier than the main window
local TEXT_LEFT = 12
-- Pixels per mouse wheel notch: two rows
local SCROLL_STEP = 32
-- Seconds between refreshes while the window is open
local REFRESH_INTERVAL = 2

local CATEGORIES = {
    { key = "fish", title = "Fish" },
    { key = "other", title = "Treasure & other" },
    { key = "junk", title = "Junk" },
}

local window
local summary, bait, zones
-- One section per category, by its key
local sections = {}
local shownListeners = {}

-- callback(shown) runs whenever the window opens or closes
function DetailsWindow.OnShownChanged(callback)
    table.insert(shownListeners, callback)
end

local function NotifyShownChanged(shown)
    for _, callback in ipairs(shownListeners) do
        callback(shown)
    end
end

-- The question-mark icon, for items the game hasn't loaded yet
local UNKNOWN_ICON = 134400
local FormatCount = Utils.FormatCount

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
    local panels = { summary, bait }
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
    local total, entries = Stats.GetGlobalSummary()

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

    -- Baits applied with the bait buttons
    local baitTotal, baits = Stats.GetBaitSummary()
    bait:SetHeadingValue(baitTotal .. " used")
    bait:SetEntries(baits, function(entry)
        local lastUsed = entry.lastSeen and Utils.FormatTimeSince(entry.lastSeen) or ""
        local name = Panel.FormatItem(entry.icon or UNKNOWN_ICON, entry.link or ("Item " .. entry.itemID))
        return name, lastUsed, FormatCount(entry.count, entry.percent)
    end, function(entry)
        GameTooltip:SetItemByID(entry.itemID)
    end)

    for _, category in ipairs(CATEGORIES) do
        local section = sections[category.key]
        section:SetHeadingValue(counts[category.key] .. " caught")
        section:SetEntries(byCategory[category.key], function(entry)
            local lastSeen = entry.lastSeen and Utils.FormatTimeSince(entry.lastSeen) or ""
            return Panel.FormatItem(entry.icon, entry.link), lastSeen, FormatCount(entry.count, entry.percent)
        end, ShowItemTooltip)
    end

    -- Zones, each followed by its areas, and each area by its loot table: every item caught
    -- there with its drop rate. Without details per area, each zone has one loot table for all
    -- its areas.
    local zoneRows = {}
    local function AddItemRows(items, indent)
        for _, item in ipairs(items) do
            table.insert(zoneRows, {
                text = indent .. Panel.FormatItem(item.icon, item.link),
                value = FormatCount(item.count, item.percent),
                link = item.link,
            })
        end
    end
    local merge = not Storage.GetSetting("detailsShowAreas")
    for _, zone in ipairs(Stats.GetZoneSummary()) do
        table.insert(zoneRows, { text = zone.zone, value = FormatCount(zone.count, zone.percent), heading = true })
        if merge then
            AddItemRows(Stats.MergeAreaItems(zone), "    ")
        else
            for _, subzone in ipairs(zone.subzones) do
                table.insert(zoneRows, {
                    text = "    " .. Utils.Color(subzone.name, Utils.GREY),
                    value = FormatCount(subzone.count, subzone.percent),
                    heading = true,
                })
                AddItemRows(subzone.items, "        ")
            end
        end
    end
    zones:SetEntries(zoneRows, function(row)
        return row.text, row.value
    end, ShowZoneTooltip)

    Layout(summary:GetParent())
end

-- Chat messages can't be longer than this
local MAX_MESSAGE_LENGTH = 255
local SHARED_TOP_ITEMS = 3

-- "FishyWashy: 312 caught, 45% catch rate (312/690), fishing 311. Top: Raw Brilliant
-- Smallfish 140, ...", from the all-time stats
local function BuildShareMessage()
    local total, entries = Stats.GetGlobalSummary()
    local parts = { ("FishyWashy: %d caught"):format(total) }
    local rate, caught, casts = Stats.GetGlobalCastSummary()
    if rate then
        table.insert(parts, (", %.0f%% catch rate (%d/%d)"):format(rate, caught, casts))
    end
    local skill = ns.CharacterInfo.GetFishingSkill()
    if skill then
        table.insert(parts, (", fishing %d"):format(skill.total))
    end
    local top = {}
    for i = 1, math.min(SHARED_TOP_ITEMS, #entries) do
        -- Plain names: links are long and would use up the message
        local name = Utils.GetLinkName(entries[i].link) or "?"
        table.insert(top, ("%s %d"):format(name, entries[i].count))
    end
    if #top > 0 then
        table.insert(parts, ". Top: " .. table.concat(top, ", "))
    end
    return table.concat(parts):sub(1, MAX_MESSAGE_LENGTH)
end

-- Puts the stats in the chat input box, so the player picks the channel and sends it
local function ShareStats()
    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
    open(BuildShareMessage())
end

local function Create()
    window = CreateFrame("Frame", "FishyWashyDetailsFrame", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    Panel.ApplyWindowBackdrop(window, 0.85)
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
    local close = Panel.CreateCloseButton(window, function() window:Hide() end)
    local share = Panel.CreateSmallButton(window, "Share stats", 84, ShareStats)
    share:SetHeight(16)
    share:SetPoint("RIGHT", close, "LEFT", -6, 0)
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

    summary = Panel.Create(content, "All-time", "No fish caught yet", 2, TEXT_LEFT)
    bait = Panel.Create(content, "Bait used", "No bait used from the bait buttons yet", nil, TEXT_LEFT)
    bait:SetStriped(true)
    for _, category in ipairs(CATEGORIES) do
        sections[category.key] = Panel.Create(content, category.title, "None yet", nil, TEXT_LEFT)
    end
    zones = Panel.Create(content, "Zones", "No fish caught yet", nil, TEXT_LEFT)
    zones:AddHeadingCheckbox("Show details per area", "detailsShowAreas", Refresh)
    -- Striped item rows, as the numbers are far from the names in this wide window
    for _, section in pairs(sections) do
        section:SetStriped(true)
    end
    zones:SetStriped(true)

    window:SetScript("OnShow", function()
        Refresh()
        NotifyShownChanged(true)
    end)
    window:SetScript("OnHide", function()
        NotifyShownChanged(false)
    end)
    Catches.OnChange(function()
        if window:IsShown() then Refresh() end
    end)
    -- Also every few seconds while open, for bait uses and the "time ago" labels
    C_Timer.NewTicker(REFRESH_INTERVAL, function()
        if window:IsShown() then Refresh() end
    end)
end

function DetailsWindow.Toggle()
    if not window then
        -- New frames start shown, so OnShow doesn't run for the first opening
        Create()
        Refresh()
        NotifyShownChanged(true)
        return
    end
    window:SetShown(not window:IsShown())
end
