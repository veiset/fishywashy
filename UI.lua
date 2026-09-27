local _, ns = ...
local Config, Storage, Bait, Catches = ns.Config, ns.Storage, ns.Bait, ns.Catches
local Panel, ConfigPanel, StatsPanel, HistoryPanel = ns.Panel, ns.ConfigPanel, ns.StatsPanel, ns.HistoryPanel

local UI = {}
ns.UI = UI

local frame

local WIDTH = 285
local BAIT_TOP = -30
local SHOW_CONFIG_TOP = -61
local ACTIONS_BOTTOM = -84

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

function UI.Init()
    frame = CreateMainFrame()
    CreateBaitStatus(frame)
    CreateBaitButtons(frame)

    local stats = StatsPanel.Create(frame)
    local history = HistoryPanel.Create(frame)
    history:SetPoint("TOPLEFT", stats, "BOTTOMLEFT")
    history:SetPoint("TOPRIGHT", stats, "BOTTOMRIGHT")

    local config
    -- The frame holds secure buttons, so it can't be resized, shown or hidden in combat;
    -- these are retried when combat ends.
    local function UpdateHeight()
        if InCombatLockdown() then return end
        local height = -ACTIONS_BOTTOM + 2
        if Storage.GetSetting("showConfig") then
            height = height + config:GetHeight()
        end
        if Storage.GetSetting("showStats") then
            height = height + stats:GetHeight() + history:GetHeight()
        end
        AnchorByTopLeft(frame)
        frame:SetHeight(height)
    end

    config = ConfigPanel.Create(frame, stats, UpdateHeight)
    config:SetPoint("TOPLEFT", 0, ACTIONS_BOTTOM)
    config:SetPoint("TOPRIGHT", 0, ACTIONS_BOTTOM)

    -- The stats sit under the config panel when it's open, and take its place when it's closed
    local function ApplyShowConfig()
        local show = Storage.GetSetting("showConfig")
        config:SetShown(show)
        stats:ClearAllPoints()
        if show then
            stats:SetPoint("TOPLEFT", config, "BOTTOMLEFT")
            stats:SetPoint("TOPRIGHT", config, "BOTTOMRIGHT")
        else
            stats:SetPoint("TOPLEFT", 0, ACTIONS_BOTTOM)
            stats:SetPoint("TOPRIGHT", 0, ACTIONS_BOTTOM)
        end
        UpdateHeight()
    end
    local _, showConfigLabel = Panel.CreateSettingCheckbox(frame, SHOW_CONFIG_TOP, "Show config", "showConfig",
        ApplyShowConfig)
    ApplyShowConfig()

    local function ApplyShowStats()
        local show = Storage.GetSetting("showStats")
        stats:SetShown(show)
        history:SetShown(show)
        UpdateHeight()
    end
    local showStats = Panel.CreateSettingCheckbox(frame, SHOW_CONFIG_TOP, "Show stats", "showStats", ApplyShowStats)
    showStats:ClearAllPoints()
    showStats:SetPoint("LEFT", showConfigLabel, "RIGHT", 16, 0)
    ApplyShowStats()

    local resetButton = CreateSmallButton(frame, "Reset", 46)
    resetButton:SetPoint("TOPRIGHT", -10, BAIT_TOP - 5)
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show("FISHYWASHY_RESET")
    end)

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
