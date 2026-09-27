local _, ns = ...
local Config, Storage, Bait, Catches = ns.Config, ns.Storage, ns.Bait, ns.Catches
local Panel, ConfigPanel, StatsPanel, HistoryPanel = ns.Panel, ns.ConfigPanel, ns.StatsPanel, ns.HistoryPanel
local GlobalStatsPanel, ZonesPanel = ns.GlobalStatsPanel, ns.ZonesPanel

local UI = {}
ns.UI = UI

local frame

local WIDTH = 340
local BAIT_TOP = -30
local ACTIONS_BOTTOM = -72

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
    Panel.CreateDivider(f, -24)
    return f
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
    for _, itemID in ipairs(Config.BAIT_ITEMS) do
        buttons[itemID] = CreateBaitButton(parent, itemID)
    end

    local emptyText = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 12, BAIT_TOP - 8)
    emptyText:SetText("No bait in bags")

    local function Update()
        -- Secure buttons can't be shown, hidden or moved in combat
        if InCombatLockdown() then return end
        local x = 12
        for _, itemID in ipairs(Config.BAIT_ITEMS) do
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

StaticPopupDialogs["FISHYWASHY_RESET"] = {
    text = "Reset the session? This clears the session stats and history; global stats are kept.",
    button1 = YES,
    button2 = NO,
    OnAccept = function() Catches.Reset() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function UI.Init()
    frame = CreateMainFrame()
    CreateBaitStatus(frame)
    CreateBaitButtons(frame)

    local stats = StatsPanel.Create(frame)
    local globalStats = GlobalStatsPanel.Create(frame)
    local zones = ZonesPanel.Create(frame)
    local history = HistoryPanel.Create(frame)
    local config

    -- Shows the panels the settings ask for, stacks them under the bait row in this order,
    -- and sizes the frame to fit
    local function Layout()
        config:SetShown(Storage.GetSetting("showConfig"))
        stats:SetShown(Storage.GetSetting("showStats"))
        globalStats:SetShown(Storage.GetSetting("showGlobalStats"))
        zones:SetShown(Storage.GetSetting("showZones"))
        history:SetShown(Storage.GetSetting("showHistory"))

        local height = -ACTIONS_BOTTOM + 2
        local previous
        for _, panel in ipairs({ config, stats, globalStats, zones, history }) do
            if panel:IsShown() then
                panel:ClearAllPoints()
                if previous then
                    panel:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
                    panel:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT")
                else
                    panel:SetPoint("TOPLEFT", 0, ACTIONS_BOTTOM)
                    panel:SetPoint("TOPRIGHT", 0, ACTIONS_BOTTOM)
                end
                previous = panel
                height = height + panel:GetHeight()
            end
        end

        -- The frame holds secure buttons, so it can't be resized in combat; this is retried
        -- when combat ends
        if InCombatLockdown() then return end
        AnchorByTopLeft(frame)
        frame:SetHeight(height)
    end

    config = ConfigPanel.Create(frame, stats, globalStats, Layout)

    -- The advanced lines change the panels' height
    stats:AddHeadingCheckbox("Advanced", "showAdvancedStats", function()
        stats.Refresh()
        Layout()
    end)
    globalStats:AddHeadingCheckbox("Advanced", "globalShowLastSeen", function()
        globalStats.Refresh()
        Layout()
    end)
    history:AddHeadingCheckbox("Graph", "showHistoryGraph", function()
        history.Refresh()
        Layout()
    end)

    -- To the right of the bait buttons: "Show config" above "Reset session", left-aligned
    local resetSession = Panel.CreatePopupButton(frame, "Reset session", 90, "FISHYWASHY_RESET")
    resetSession:SetPoint("TOPRIGHT", -10, BAIT_TOP - 20)
    local showConfig = Panel.CreateSettingCheckbox(frame, 0, 0, "Show config", "showConfig", Layout)
    showConfig:ClearAllPoints()
    showConfig:SetPoint("BOTTOMLEFT", resetSession, "TOPLEFT", 0, 2)

    -- Only show the frame while a fishing pole is equipped
    local function UpdateVisibility()
        if InCombatLockdown() then return end
        frame:SetShown(Bait.HasFishingPole())
    end

    Catches.OnChange(Layout)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        Layout()
        UpdateVisibility()
    end)
    Layout()
    UpdateVisibility()
end

function UI.Toggle()
    if InCombatLockdown() then return end
    frame:SetShown(not frame:IsShown())
end
