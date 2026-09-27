local _, ns = ...
local Panel, Storage, Sound, Catches = ns.Panel, ns.Storage, ns.Sound, ns.Catches

-- The settings checkboxes, the volume slider and the reset button.
local ConfigPanel = {}
ns.ConfigPanel = ConfigPanel

local HEIGHT = 105

StaticPopupDialogs["FISHYWASHY_RESET"] = {
    text = "Reset the session? This clears all FishyWashy stats and history.",
    button1 = YES,
    button2 = NO,
    OnAccept = function() Catches.Reset() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

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

-- onLayoutChange is called when a setting changes the stats panel's height
function ConfigPanel.Create(parent, stats, onLayoutChange)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetHeight(HEIGHT)
    Panel.CreateDivider(panel, 0)

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", 12, -5)
    heading:SetText("Config")

    local _, volumeLabel = Panel.CreateSettingCheckbox(panel, -19, "Fishing volume", "enabled", function()
        if not Storage.GetSetting("enabled") then
            Sound.Restore()
        end
    end)
    CreateVolumeSlider(panel, volumeLabel)

    local function ApplyAdvancedStats()
        stats:SetSubheadingsShown(Storage.GetSetting("showAdvancedStats"))
    end
    ApplyAdvancedStats()
    Panel.CreateSettingCheckbox(panel, -39, "Show advanced stats", "showAdvancedStats", function()
        ApplyAdvancedStats()
        onLayoutChange()
    end)

    Panel.CreateSettingCheckbox(panel, -59, "Include unsuccessful in stats", "statsIncludeMissed", function()
        -- The unsuccessful row changes the stats' height
        stats.Refresh()
        onLayoutChange()
    end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(90, 18)
    reset:SetPoint("TOPLEFT", 12, -81)
    reset:SetNormalFontObject("GameFontNormalSmall")
    reset:SetHighlightFontObject("GameFontHighlightSmall")
    reset:SetText("Reset session")
    reset:SetScript("OnClick", function()
        StaticPopup_Show("FISHYWASHY_RESET")
    end)

    return panel
end
