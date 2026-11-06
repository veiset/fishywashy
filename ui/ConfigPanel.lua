local _, ns = ...
local Utils, Panel, Storage, Sound, Catches, EasyCast = ns.Utils, ns.Panel, ns.Storage, ns.Sound, ns.Catches,
    ns.EasyCast

-- The settings checkboxes, the volume slider and the reset-all button.
local ConfigPanel = {}
ns.ConfigPanel = ConfigPanel

local HEIGHT = 205
-- Checkboxes start a little left of the text, so their labels line up with it
local LEFT = Panel.LEFT - 2

StaticPopupDialogs["FISHYWASHY_RESET_ALL"] = {
    text = "Delete ALL FishyWashy data, including global stats, zones and history? This can't be undone.",
    button1 = YES,
    button2 = NO,
    OnAccept = function() Catches.ResetAll() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Right-aligned on the checkbox row starting at top, with the value at the right edge
local function CreateVolumeSlider(parent, top)
    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- Checkboxes are 18 high, so the row's middle is 9 below its top
    valueText:SetPoint("RIGHT", parent, "TOPRIGHT", -10, top - 9)
    valueText:SetWidth(32)
    valueText:SetJustifyH("RIGHT")

    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(100, 14)
    slider:SetPoint("RIGHT", valueText, "LEFT", -6, 0)
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

-- Short names for the mouse buttons; keys use the game's own names
local MOUSE_BUTTON_NAMES = {
    BUTTON2 = "Right-click",
    BUTTON3 = "Middle-click",
    BUTTON4 = "Mouse 4",
    BUTTON5 = "Mouse 5",
}
-- Mouse buttons as clicks name them, to the binding names. Not the left button, which cancels.
local CLICK_BINDINGS = {
    RightButton = "BUTTON2",
    MiddleButton = "BUTTON3",
    Button4 = "BUTTON4",
    Button5 = "BUTTON5",
}
-- Held with another key rather than set on their own
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

local function GetKeyName(key)
    return MOUSE_BUTTON_NAMES[key] or GetBindingText(key)
end

-- Sizes a small button to its text
local function FitToText(button)
    button:SetWidth(button:GetFontString():GetStringWidth() + 18)
end

-- A button for the key or mouse button in settingKey. Clicking it waits for a key press, or
-- a click on it with another mouse button, to set instead. Escape or a left-click cancels.
-- Otherwise it shows getText(), or the key's name when not given; button.Refresh() shows it
-- again. onSet, when given, is called once a key is set.
local function CreateKeyButton(parent, settingKey, getText, onSet)
    local button = Panel.CreateSmallButton(parent, "", 0)
    button:RegisterForClicks("AnyUp")

    local function Show(text)
        button:SetText(text)
        FitToText(button)
    end
    local function StopListening()
        button:EnableKeyboard(false)
        Show(getText and getText() or GetKeyName(Storage.GetSetting(settingKey)))
    end
    local function SetKey(key)
        Storage.SetSetting(settingKey, key)
        StopListening()
        if onSet then onSet() end
    end

    button:SetScript("OnClick", function(self, mouseButton)
        if not self:IsKeyboardEnabled() then
            if mouseButton == "LeftButton" then
                self:EnableKeyboard(true)
                Show("Press a key")
            end
        elseif CLICK_BINDINGS[mouseButton] then
            SetKey(CLICK_BINDINGS[mouseButton])
        else
            StopListening()
        end
    end)
    button:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            StopListening()
        elseif not MODIFIER_KEYS[key] then
            local modifiers = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "")
            SetKey(modifiers .. key)
        end
    end)
    button:SetScript("OnHide", StopListening)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click, then press a key, or click here with the mouse button to use")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button.Refresh = StopListening
    StopListening()
    return button
end

-- "Fishing hotkey (when rod equipped)" over [Double right-click] [Set hotkey] [None], with the
-- chosen one lit. Set hotkey waits for a key, then shows the key in its place.
local function CreateCastModeButtons(parent, top)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- On a row as tall as a checkbox's
    label:SetPoint("LEFT", parent, "TOPLEFT", Panel.LEFT, top - 9)
    label:SetText("Fishing hotkey " .. Utils.Color("(when rod equipped)", Utils.GREY))

    local buttons = {}
    local function Update()
        local mode = Storage.GetSetting("castMode")
        for buttonMode, button in pairs(buttons) do
            Panel.SetButtonActive(button, buttonMode == mode)
        end
        buttons.hotkey.Refresh()
    end
    local function Select(mode)
        Storage.SetSetting("castMode", mode)
        Update()
        EasyCast.UpdateHotkey()
    end

    buttons.doubleClick = Panel.CreateSmallButton(parent, "Double right-click", 0, function()
        Select("doubleClick")
    end)
    buttons.hotkey = CreateKeyButton(parent, "castKey", function()
        local key = Storage.GetSetting("castMode") == "hotkey" and Storage.GetSetting("castKey")
        return key and GetKeyName(key) or "Set hotkey"
    end, function()
        Select("hotkey")
    end)
    buttons.none = Panel.CreateSmallButton(parent, "None", 0, function()
        Select("none")
    end)
    FitToText(buttons.doubleClick)
    FitToText(buttons.none)

    buttons.doubleClick:SetPoint("TOPLEFT", Panel.LEFT, top - 19)
    buttons.hotkey:SetPoint("LEFT", buttons.doubleClick, "RIGHT", 3, 0)
    buttons.none:SetPoint("LEFT", buttons.hotkey, "RIGHT", 3, 0)
    Update()
end

-- onLayoutChange is called when a setting changes which panels show or how tall they are
function ConfigPanel.Create(parent, stats, onLayoutChange)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetHeight(HEIGHT)
    Panel.CreateDivider(panel, 0)

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", Panel.LEFT, -5)
    heading:SetText("Config")

    -- Casting and reeling in first, a little below the heading. Two rows: the label, then the
    -- buttons.
    CreateCastModeButtons(panel, -25)
    -- "Reel in with [Right-click] (no need to aim)"
    local _, reelInLabel = Panel.CreateSettingCheckbox(panel, LEFT, -65, "Reel in with", "reelIn")
    local reelInKey = CreateKeyButton(panel, "reelInKey")
    reelInKey:SetPoint("LEFT", reelInLabel, "RIGHT", 4, 0)
    local reelInHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reelInHint:SetPoint("LEFT", reelInKey, "RIGHT", 4, 0)
    reelInHint:SetText(Utils.Color("(no need to aim)", Utils.GREY))

    -- The rest, set a little apart from casting and reeling in
    Panel.CreateSettingCheckbox(panel, LEFT, -93, "Fishing volume", "enabled", function()
        if not Storage.GetSetting("enabled") then
            Sound.Restore()
        end
    end)
    CreateVolumeSlider(panel, -93)
    -- Takes effect from the next cast
    Panel.CreateSettingCheckbox(panel, LEFT, -113, "Sound while alt-tabbed " .. Utils.Color("(when fishing)", Utils.GREY),
        "soundInBackground")
    Panel.CreateSettingCheckbox(panel, LEFT, -133, "Include unsuccessful in stats", "statsIncludeMissed", function()
        -- The unsuccessful row changes the stats' height
        stats.Refresh()
        onLayoutChange()
    end)
    -- "Show stats  Show zones  Show history" on one row, set a little apart
    local _, previous = Panel.CreateSettingCheckbox(panel, LEFT, -159, "Show stats", "showStats", onLayoutChange)
    for _, show in ipairs({ { "Show zones", "showZones" }, { "Show history", "showHistory" } }) do
        local check, label = Panel.CreateSettingCheckbox(panel, 0, 0, show[1], show[2], onLayoutChange)
        check:ClearAllPoints()
        check:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        previous = label
    end

    local resetAll = Panel.CreatePopupButton(panel, "Reset all data", 100, "FISHYWASHY_RESET_ALL")
    resetAll:SetPoint("TOPLEFT", Panel.LEFT, -181)

    return panel
end
