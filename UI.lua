local _, ns = ...
local Storage, Sound, Bait, Catches, Stats = ns.Storage, ns.Sound, ns.Bait, ns.Catches, ns.Stats

local UI = {}
ns.UI = UI

local frame

local WIDTH = 285
local BAIT_TOP = -58
local ADVANCED_STATS_TOP = -89
local INCLUDE_MISSED_TOP = -109
local ACTIONS_BOTTOM = -132
local RECENT_CATCHES = 5
local MISSED_ICON = "Interface/Icons/Trade_Fishing"
local ROW_HEIGHT = 16

local function CreateDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.2)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 6, y)
    line:SetPoint("TOPRIGHT", -6, y)
end

-- Anchor by the top-left corner so height changes only move the bottom edge
local function AnchorByTopLeft(f)
    local left, top = f:GetLeft(), f:GetTop()
    if not left then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "FishyWashyFrame", UIParent, "BackdropTemplate")
    f:SetWidth(WIDTH)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.5)
    f:SetBackdropBorderColor(1, 1, 1, 0.6)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        AnchorByTopLeft(self)
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("FishyWashy")
    CreateDivider(f, -24)
    return f
end

local function CreateEnableCheckbox(parent)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    -- 30% smaller than the template, centred on the same row
    local size = check:GetHeight()
    check:SetSize(size * 0.7, size * 0.7)
    check:SetPoint("LEFT", parent, "TOPLEFT", 8, -28 - size / 2)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText("Fishing volume")

    check:SetChecked(Storage.GetSetting("enabled"))
    check:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        Storage.SetSetting("enabled", enabled)
        if not enabled then
            Sound.Restore()
        end
    end)
    return label
end

local function CreateVolumeSlider(parent, anchor)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(100, 14)
    slider:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    slider:SetBackdrop({
        bgFile = "Interface/Buttons/UI-SliderBar-Background",
        edgeFile = "Interface/Buttons/UI-SliderBar-Border",
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(32, 32)
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", slider, "RIGHT", 6, 0)

    local function ShowValue(value)
        valueText:SetText(math.floor(value * 100 + 0.5) .. "%")
    end

    local volume = Storage.GetSetting("volume")
    slider:SetValue(volume)
    ShowValue(volume)
    slider:SetScript("OnValueChanged", function(_, value)
        Storage.SetSetting("volume", value)
        ShowValue(value)
        Sound.UpdateVolume()
    end)
end

local function CreateBaitStatus(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPRIGHT", -10, -9)
    text:SetJustifyH("RIGHT")

    local function Update()
        if not Bait.HasFishingPole() then
            text:SetText("Bait: no fishing pole equipped")
            return
        end
        local timeLeft = Bait.GetTimeLeft()
        if timeLeft then
            text:SetText(("Bait: |cff40ff40applied|r (%d:%02d)"):format(timeLeft / 60, timeLeft % 60))
        else
            text:SetText("Bait: |cffff4040none|r")
        end
    end

    Update()
    C_Timer.NewTicker(1, Update)
end

local BAIT_BUTTON_SIZE = 28
local BAIT_BUTTON_SPACING = 4

local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- Secure button that applies one kind of bait; only clicks on secure buttons may use items.
local function CreateBaitButton(parent, itemID)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(BAIT_BUTTON_SIZE, BAIT_BUTTON_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", Bait.GetApplyMacro(itemID))

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(GetItemIcon(itemID))
    button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -1, 1)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
    return button
end

local function CreateBaitButtons(parent)
    local buttons = {}
    for _, itemID in ipairs(Bait.ITEMS) do
        buttons[itemID] = CreateBaitButton(parent, itemID)
    end

    local emptyText = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 12, BAIT_TOP - 8)
    emptyText:SetText("No bait in bags")

    local function Update()
        -- Secure buttons can't be shown, hidden or moved in combat
        if InCombatLockdown() then return end
        local x = 12
        for _, itemID in ipairs(Bait.ITEMS) do
            local button = buttons[itemID]
            local count = Bait.GetCount(itemID)
            if count > 0 then
                button.count:SetText(count)
                button:SetPoint("TOPLEFT", x, BAIT_TOP)
                button:Show()
                x = x + BAIT_BUTTON_SIZE + BAIT_BUTTON_SPACING
            else
                button:Hide()
            end
        end
        emptyText:SetShown(x == 12)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", Update)
    Update()
end

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

local function FormatItem(icon, link)
    return ("|T%s:14|t %s"):format(icon, link)
end

local function FormatMiss()
    return FormatItem(MISSED_ICON, "|cff9d9d9dUnsuccessful|r")
end

-- A small checkbox with a label, bound to a boolean setting
local function CreateSettingCheckbox(parent, top, text, settingKey, onChange)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(18, 18)
    check:SetPoint("TOPLEFT", 10, top)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(text)
    -- Let clicks on the label toggle the checkbox too
    check:SetHitRectInsets(0, -(label:GetStringWidth() + 2), 0, 0)
    check:SetChecked(Storage.GetSetting(settingKey))
    check:SetScript("OnClick", function(self)
        Storage.SetSetting(settingKey, self:GetChecked())
        onChange()
    end)
end

local function CreateSmallButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 18)
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetText(text)
    return button
end

StaticPopupDialogs["FISHYWASHY_RESET"] = {
    text = "Reset all FishyWashy stats and history?",
    button1 = YES,
    button2 = NO,
    OnAccept = function() Catches.Reset() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local SECTION_HEADER_HEIGHT = 19
local SECTION_GAP = 6

local function UpdateSectionHeight(section)
    section:SetHeight(section.headerHeight + math.max(section.rowCount, 1) * ROW_HEIGHT + SECTION_GAP)
end

local function SetSubheadingsShown(section, shown)
    for _, subheading in ipairs(section.subheadings) do
        subheading.left:SetShown(shown)
        subheading.right:SetShown(shown)
    end
    section.headerHeight = SECTION_HEADER_HEIGHT + (shown and #section.subheadings * ROW_HEIGHT or 0)
    section.body:SetPoint("TOPLEFT", 0, -section.headerHeight)
    section.body:SetPoint("TOPRIGHT", 0, -section.headerHeight)
    UpdateSectionHeight(section)
end

-- A divider, a small heading, optional subheading lines, and rows of
-- left-aligned item + right-aligned value.
-- The section grows and shrinks to fit the rows it's filled with.
local function CreateSection(parent, title, emptyMessage, subheadingCount)
    local section = CreateFrame("Frame", nil, parent)
    CreateDivider(section, 0)

    section.heading = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.heading:SetPoint("TOPLEFT", 12, -5)
    section.heading:SetText(title)
    section.headingValue = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.headingValue:SetPoint("TOPRIGHT", -10, -5)

    section.subheadings = {}
    for i = 1, subheadingCount or 0 do
        local y = -SECTION_HEADER_HEIGHT - (i - 1) * ROW_HEIGHT
        local right = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        right:SetPoint("TOPRIGHT", -10, y)
        local left = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        left:SetPoint("TOPLEFT", 12, y)
        left:SetPoint("RIGHT", right, "LEFT", -6, 0)
        left:SetJustifyH("LEFT")
        section.subheadings[i] = { left = left, right = right }
    end

    -- Rows hang off the body, which moves up when the subheadings are hidden
    section.body = CreateFrame("Frame", nil, section)
    section.body:SetHeight(1)

    section.empty = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    section.empty:SetPoint("TOPLEFT", section.body, "TOPLEFT", 12, 0)
    section.empty:SetText(emptyMessage)

    section.rows = {}
    section.rowCount = 0
    SetSubheadingsShown(section, true)
    return section
end

local function GetRow(section, i)
    local row = section.rows[i]
    if not row then
        local y = -(i - 1) * ROW_HEIGHT
        local value = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        value:SetPoint("TOPRIGHT", section.body, "TOPRIGHT", -10, y)
        local item = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        item:SetPoint("TOPLEFT", section.body, "TOPLEFT", 12, y)
        item:SetPoint("RIGHT", value, "LEFT", -6, 0)
        item:SetJustifyH("LEFT")
        item:SetWordWrap(false)
        row = { item = item, value = value }
        section.rows[i] = row
    end
    return row
end

-- Fills the section with one row per entry; format(entry) returns the item and value text
local function FillSection(section, entries, format)
    for i, entry in ipairs(entries) do
        local row = GetRow(section, i)
        local itemText, valueText = format(entry)
        row.item:SetText(itemText)
        row.value:SetText(valueText)
    end
    for i = #entries + 1, #section.rows do
        section.rows[i].item:SetText("")
        section.rows[i].value:SetText("")
    end
    section.empty:SetShown(#entries == 0)
    section.rowCount = #entries
    UpdateSectionHeight(section)
end

local function FormatDuration(seconds)
    if seconds < 3600 then
        return ("%dm %02ds"):format(seconds / 60, seconds % 60)
    end
    return ("%dh %02dm"):format(seconds / 3600, seconds % 3600 / 60)
end

local function CreateStats(parent)
    local section = CreateSection(parent, "Stats", "No fish caught yet", 2)
    local rates, casts = section.subheadings[1], section.subheadings[2]
    local caught = 0

    local function UpdateRates()
        rates.left:SetText(("Fish/hour: %.0f"):format(Stats.GetPerHour(caught)))
        rates.right:SetText("Session: " .. FormatDuration(Stats.GetSessionLength()))
    end

    local function UpdateCasts()
        local rate, missed, average = Stats.GetCastSummary()
        casts.left:SetText(rate and ("Catch rate: %.0f%% (%d unsuccessful)"):format(rate, missed) or "Catch rate: -")
        casts.right:SetText(average and ("%.1fs per catch"):format(average) or "- per catch")
    end

    local function Update()
        local total, entries
        total, entries, caught = Stats.GetSummary(Storage.GetSetting("statsIncludeMissed"))
        section.headingValue:SetText("Total: " .. total)
        FillSection(section, entries, function(entry)
            local text = entry.missed and FormatMiss() or FormatItem(entry.icon, entry.link)
            return text, ("%d (%.0f%%)"):format(entry.count, entry.percent)
        end)
        UpdateRates()
        UpdateCasts()
    end
    section.Update = Update

    Catches.OnChange(Update)
    Update()
    C_Timer.NewTicker(1, UpdateRates)
    return section
end

local function CreateHistory(parent)
    local section = CreateSection(parent, "History", "No fish caught yet")

    local function Update()
        FillSection(section, Catches.GetRecent(RECENT_CATCHES), function(catch)
            if catch.missed then
                return FormatMiss(), FormatTimeSince(catch.time)
            end
            local text = FormatItem(catch.icon, catch.link)
            if catch.quantity > 1 then
                text = text .. " x" .. catch.quantity
            end
            return text, FormatTimeSince(catch.time)
        end)
    end

    Catches.OnChange(Update)
    Update()
    -- Keep the "time ago" labels current
    C_Timer.NewTicker(1, Update)
    return section
end

function UI.Init()
    frame = CreateMainFrame()
    local label = CreateEnableCheckbox(frame)
    CreateVolumeSlider(frame, label)
    CreateBaitStatus(frame)
    CreateBaitButtons(frame)
    local stats = CreateStats(frame)
    stats:SetPoint("TOPLEFT", 0, ACTIONS_BOTTOM)
    stats:SetPoint("TOPRIGHT", 0, ACTIONS_BOTTOM)
    local history = CreateHistory(frame)
    history:SetPoint("TOPLEFT", stats, "BOTTOMLEFT")
    history:SetPoint("TOPRIGHT", stats, "BOTTOMRIGHT")

    -- The frame holds secure buttons, so it can't be resized, shown or hidden in combat;
    -- these are retried when combat ends.
    local function UpdateHeight()
        if InCombatLockdown() then return end
        local height = -ACTIONS_BOTTOM + 2
        if Storage.GetSetting("showStats") then
            height = height + stats:GetHeight() + history:GetHeight()
        end
        AnchorByTopLeft(frame)
        frame:SetHeight(height)
    end

    local function ApplyAdvancedStats()
        SetSubheadingsShown(stats, Storage.GetSetting("showAdvancedStats"))
    end
    ApplyAdvancedStats()

    CreateSettingCheckbox(frame, ADVANCED_STATS_TOP, "Show advanced stats", "showAdvancedStats", function()
        ApplyAdvancedStats()
        UpdateHeight()
    end)
    CreateSettingCheckbox(frame, INCLUDE_MISSED_TOP, "Include unsuccessful in stats", "statsIncludeMissed", function()
        -- The missed row changes the stats' height
        stats.Update()
        UpdateHeight()
    end)

    local resetButton = CreateSmallButton(frame, "Reset", 46)
    resetButton:SetPoint("TOPRIGHT", -10, BAIT_TOP - 5)
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show("FISHYWASHY_RESET")
    end)

    local toggleButton = CreateSmallButton(frame, "", 72)
    toggleButton:SetPoint("RIGHT", resetButton, "LEFT", -4, 0)
    local function ApplyShowStats()
        local show = Storage.GetSetting("showStats")
        stats:SetShown(show)
        history:SetShown(show)
        toggleButton:SetText(show and "Hide stats" or "Show stats")
        UpdateHeight()
    end
    toggleButton:SetScript("OnClick", function()
        Storage.SetSetting("showStats", not Storage.GetSetting("showStats"))
        ApplyShowStats()
    end)
    ApplyShowStats()

    -- Only show the frame while a fishing pole is equipped
    local function UpdateVisibility()
        if InCombatLockdown() then return end
        frame:SetShown(Bait.HasFishingPole())
    end

    Catches.OnChange(UpdateHeight)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        UpdateHeight()
        UpdateVisibility()
    end)
    UpdateHeight()
    UpdateVisibility()
end

function UI.Toggle()
    if InCombatLockdown() then return end
    frame:SetShown(not frame:IsShown())
end
