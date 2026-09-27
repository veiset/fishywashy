local _, ns = ...
local Utils, Config, Storage, Bait, Catches = ns.Utils, ns.Config, ns.Storage, ns.Bait, ns.Catches
local CharacterInfo = ns.CharacterInfo
local Panel, ConfigPanel, StatsPanel, HistoryPanel = ns.Panel, ns.ConfigPanel, ns.StatsPanel, ns.HistoryPanel
local ZonesPanel, DetailsWindow = ns.ZonesPanel, ns.DetailsWindow

local UI = {}
ns.UI = UI

local frame
-- Closed with the X or /fishy; stays hidden until a fishing pole is equipped or /fishy is used
local closed = false
-- Whether the frame should be shown; applied now, or when combat ends
local wanted = false

-- The frame holds secure buttons, so it can't be shown or hidden in combat
local function ApplyVisibility()
    if InCombatLockdown() then return end
    frame:SetShown(wanted)
end

local WIDTH = 286
-- The bait row, then a row of three buttons
local BAIT_TOP = -33
local ACTIONS_ROW_TOP = -67
local ACTION_BUTTON_WIDTH = 86
local ACTION_BUTTON_HEIGHT = 22
local ACTIONS_BOTTOM = -94

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
    Panel.ApplyWindowBackdrop(f, 0.5)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        AnchorByTopLeft(self)
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 7, -8)
    title:SetText("FishyWashy")
    Panel.CreateDivider(f, -24)
    return f
end

local function CreateBaitStatus(parent)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- A fixed start, so the ticking bait timer only changes the end of the text
    text:SetPoint("TOPLEFT", 102, -8)
    text:SetJustifyH("LEFT")

    local skill

    -- Hovering the text shows where the fishing skill comes from
    local hover = CreateFrame("Frame", nil, parent)
    hover:SetAllPoints(text)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        if not skill then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Fishing skill")
        GameTooltip:AddDoubleLine("Rank", skill.rank, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Bait", "+" .. skill.lure, 1, 1, 1, 0.25, 1, 0.25)
        GameTooltip:AddDoubleLine("Fishing pole", "+" .. skill.rod, 1, 1, 1, 0.25, 1, 0.25)
        GameTooltip:AddDoubleLine("Buffs", "+" .. skill.buffs, 1, 1, 1, 0.25, 1, 0.25)
        GameTooltip:AddDoubleLine("Total", skill.total, 1, 0.82, 0, 0.47, 0.47, 1)
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", GameTooltip_Hide)

    local function Update()
        if not CharacterInfo.HasFishingPole() then
            skill = nil
            text:SetText("Bait: no fishing pole equipped")
            return
        end
        skill = CharacterInfo.GetFishingSkill()
        local timeLeft = Bait.GetTimeLeft()
        local bait
        if timeLeft then
            -- The skill bonus comes from the bait, so show it in place of "applied" when known
            local applied = skill and skill.lure > 0 and ("+%d"):format(skill.lure) or "applied"
            bait = ("Bait: %s (%s)"):format(Utils.Color(applied, Utils.GREEN), Utils.FormatClock(timeLeft))
        else
            bait = "Bait: " .. Utils.Color("none", Utils.RED)
        end
        -- "Fishing 311   Bait: +75 (9:30)", with the total skill in light blue
        if skill then
            text:SetText(("Fishing %s   %s"):format(Utils.Color(skill.total, Utils.SKILL_BLUE), bait))
        else
            text:SetText(bait)
        end
    end

    Update()
    C_Timer.NewTicker(1, Update)
end

local BAIT_BUTTON_SIZE = 28
local BAIT_BUTTON_SPACING = 4

local GetItemIcon = Utils.GetItemIcon

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
    -- Counted once the bait actually leaves the bags
    button:HookScript("PostClick", function()
        Bait.WatchForUse(itemID)
    end)
    button:Hide()
    return button
end

local function CreateBaitButtons(parent)
    local buttons = {}
    for _, itemID in ipairs(Config.BAIT_ITEMS) do
        buttons[itemID] = CreateBaitButton(parent, itemID)
    end

    local emptyText = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", Panel.LEFT, BAIT_TOP - 8)
    emptyText:SetText("No bait in bags")

    local function Update()
        -- Secure buttons can't be shown, hidden or moved in combat
        if InCombatLockdown() then return end
        local x = Panel.LEFT
        for _, itemID in ipairs(Config.BAIT_ITEMS) do
            local button = buttons[itemID]
            local count = Utils.GetItemCount(itemID)
            if count > 0 then
                button.count:SetText(count)
                button:SetPoint("TOPLEFT", x, BAIT_TOP)
                button:Show()
                x = x + BAIT_BUTTON_SIZE + BAIT_BUTTON_SPACING
            else
                button:Hide()
            end
        end
        emptyText:SetShown(x == Panel.LEFT)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", Update)
    Update()
end

local FOOD_BUTTON_SIZE = 24

-- Very small time-left text under an icon, so it doesn't cover the icon's count
local function CreateTinyTimer(icon)
    local text = icon:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    text:SetPoint("TOP", icon, "BOTTOM", 0, -1)
    return text
end

-- At the right end of the bait row: the best food from Config.FOOD_ITEMS in the bags, to eat
-- with a click. While a fishing food buff is up the icon dims and shows the time left.
-- Nothing shows when there's no such food in the bags.
local function CreateFoodButton(parent)
    -- Secure, as only clicks on secure buttons may use items
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    -- A little smaller than the bait buttons, to leave room for the timer under it
    button:SetSize(FOOD_BUTTON_SIZE, FOOD_BUTTON_SIZE)
    button:SetPoint("TOPRIGHT", -10, BAIT_TOP + 2)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "item")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -1, 1)
    local timeLeft = CreateTinyTimer(button)

    local foodID
    button:SetScript("OnEnter", function(self)
        if not foodID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(foodID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    -- Which food the button eats: only changeable out of combat
    local function UpdateFood()
        if InCombatLockdown() then return end
        foodID = CharacterInfo.GetBestFood()
        button:SetShown(foodID ~= nil)
        if foodID then
            button:SetAttribute("item", "item:" .. foodID)
            icon:SetTexture(GetItemIcon(foodID))
            count:SetText(Utils.GetItemCount(foodID))
        end
    end

    -- The buff timer, which can update any time
    local function UpdateTimer()
        local left = CharacterInfo.GetFoodBuffTimeLeft()
        timeLeft:SetText(left and Utils.FormatShortTime(left) or "")
        icon:SetDesaturated(left ~= nil)
        icon:SetAlpha(left and 0.6 or 1)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", UpdateFood)
    UpdateFood()
    UpdateTimer()
    C_Timer.NewTicker(1, UpdateTimer)
    return button
end

-- Left of the food: another fishing buff you have, such as "Uncommon Fishing", with its time
-- left under it. Shows only while you have one.
local function CreateFishingBuffIcon(parent, foodButton)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(FOOD_BUTTON_SIZE, FOOD_BUTTON_SIZE)
    frame:EnableMouse(true)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local timeLeft = CreateTinyTimer(frame)

    local buff
    frame:SetScript("OnEnter", function(self)
        if not buff then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(buff.name)
        if buff.timeLeft then
            GameTooltip:AddLine(Utils.FormatShortTime(buff.timeLeft) .. " left", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)

    local function Update()
        buff = CharacterInfo.GetOtherFishingBuff()
        frame:SetShown(buff ~= nil)
        if not buff then return end
        icon:SetTexture(buff.icon)
        timeLeft:SetText(buff.timeLeft and Utils.FormatShortTime(buff.timeLeft) or "")
        -- Next to the food button, or at the right edge when there's no food
        frame:ClearAllPoints()
        if foodButton:IsShown() then
            frame:SetPoint("RIGHT", foodButton, "LEFT", -6, 0)
        else
            frame:SetPoint("TOPRIGHT", -10, BAIT_TOP + 2)
        end
    end

    Update()
    C_Timer.NewTicker(1, Update)
end

StaticPopupDialogs["FISHYWASHY_RESET"] = {
    text = "Start a new session? This clears the session stats and history; global stats are kept.",
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
    CreateFishingBuffIcon(frame, CreateFoodButton(frame))

    local stats = StatsPanel.Create(frame)
    local zones = ZonesPanel.Create(frame)
    local history = HistoryPanel.Create(frame)
    local config

    -- Shows the panels the settings ask for, stacks them under the bait row in this order,
    -- and sizes the frame to fit
    local function Layout()
        config:SetShown(Storage.GetSetting("showConfig"))
        stats:SetShown(Storage.GetSetting("showStats"))
        zones:SetShown(Storage.GetSetting("showZones"))
        history:SetShown(Storage.GetSetting("showHistory"))

        local height = -ACTIONS_BOTTOM + 2
        local previous
        for _, panel in ipairs({ config, stats, zones, history }) do
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

    config = ConfigPanel.Create(frame, stats, Layout)

    -- Keep the frame fitted to its panels whatever changed their height, such as rows added
    -- while the frame was hidden; at most once per screen refresh
    local layoutQueued = false
    local function QueueLayout()
        if layoutQueued then return end
        layoutQueued = true
        C_Timer.After(0, function()
            layoutQueued = false
            Layout()
        end)
    end
    for _, panel in ipairs({ config, stats, zones, history }) do
        panel:HookScript("OnSizeChanged", QueueLayout)
    end
    frame:HookScript("OnShow", QueueLayout)

    -- The advanced lines change the panels' height
    stats:AddHeadingCheckbox("Advanced", "showAdvancedStats", function()
        stats.Refresh()
        Layout()
    end)
    history:AddHeadingCheckbox("Graph", "showHistoryGraph", function()
        history.Refresh()
        Layout()
    end)

    -- One row of buttons under the bait
    local configButton
    -- Reads "Hide config" and stays lit while the config panel is open
    local function UpdateConfigButton()
        local shown = Storage.GetSetting("showConfig")
        configButton:SetText(shown and "Hide config" or "Show config")
        Panel.SetButtonActive(configButton, shown)
    end
    configButton = Panel.CreateSmallButton(frame, "", ACTION_BUTTON_WIDTH, function()
        Storage.SetSetting("showConfig", not Storage.GetSetting("showConfig"))
        UpdateConfigButton()
        Layout()
    end)
    configButton:SetPoint("TOPLEFT", Panel.LEFT, ACTIONS_ROW_TOP)
    UpdateConfigButton()
    local globalStatsButton = Panel.CreateSmallButton(frame, "Global stats", ACTION_BUTTON_WIDTH, DetailsWindow.Toggle)
    globalStatsButton:SetPoint("LEFT", configButton, "RIGHT", 4, 0)
    -- Stays lit while the all-time stats window is open, however it was opened or closed
    DetailsWindow.OnShownChanged(function(shown)
        Panel.SetButtonActive(globalStatsButton, shown)
    end)
    local newSession = Panel.CreatePopupButton(frame, "New session", ACTION_BUTTON_WIDTH, "FISHYWASHY_RESET")
    newSession:SetPoint("LEFT", globalStatsButton, "RIGHT", 4, 0)
    for _, button in ipairs({ configButton, globalStatsButton, newSession }) do
        button:SetHeight(ACTION_BUTTON_HEIGHT)
    end

    Panel.CreateCloseButton(frame, function()
        if InCombatLockdown() then return end
        closed = true
        wanted = false
        ApplyVisibility()
    end)

    -- Opens the frame when a fishing pole is equipped, unless it was closed. Never hides it,
    -- so a frame opened with /fishy stays open after combat or a loading screen.
    local function ShowIfFishing()
        if CharacterInfo.HasFishingPole() and not closed then
            wanted = true
        end
        ApplyVisibility()
    end

    Catches.OnChange(Layout)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- Fires once the equipment is known again, e.g. after a loading screen
    events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    events:SetScript("OnEvent", function(_, event, slot)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Right after a loading screen (boats, hearthstone) the main hand can look empty
            -- for a moment, so check again once it has settled instead of hiding now
            C_Timer.After(1, function()
                Layout()
                ShowIfFishing()
            end)
            return
        end
        if event == "PLAYER_EQUIPMENT_CHANGED" and slot == CharacterInfo.MAIN_HAND_SLOT then
            -- Only changing the main hand opens or hides the frame: equipping a fishing pole
            -- opens it, even after it was closed, and unequipping it hides it
            wanted = CharacterInfo.HasFishingPole()
            closed = false
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Apply anything that was blocked during combat
            Layout()
            ApplyVisibility()
            return
        end
        Layout()
        ShowIfFishing()
    end)
    Layout()
    ShowIfFishing()
end

function UI.Toggle()
    if InCombatLockdown() then return end
    wanted = not frame:IsShown()
    closed = not wanted
    ApplyVisibility()
end
