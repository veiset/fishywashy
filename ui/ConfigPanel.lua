local _, ns = ...
local Utils, Panel, Storage, Sound, Catches = ns.Utils, ns.Panel, ns.Storage, ns.Sound, ns.Catches

-- The settings checkboxes, the volume slider and the reset-all button.
local ConfigPanel = {}
ns.ConfigPanel = ConfigPanel

local HEIGHT = 193
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

-- onLayoutChange is called when a setting changes which panels show or how tall they are
function ConfigPanel.Create(parent, stats, onLayoutChange)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetHeight(HEIGHT)
    Panel.CreateDivider(panel, 0)

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", Panel.LEFT, -5)
    heading:SetText("Config")

    Panel.CreateSettingCheckbox(panel, LEFT, -19, "Fishing volume", "enabled", function()
        if not Storage.GetSetting("enabled") then
            Sound.Restore()
        end
    end)
    CreateVolumeSlider(panel, -19)
    -- Takes effect from the next cast
    Panel.CreateSettingCheckbox(panel, LEFT, -39, "Sound while alt-tabbed " .. Utils.Color("(when fishing)", Utils.GREY),
        "soundInBackground")
    Panel.CreateSettingCheckbox(panel, LEFT, -59, "Double right-click to cast " .. Utils.Color("(when rod equipped)", Utils.GREY),
        "rightClickCast")

    Panel.CreateSettingCheckbox(panel, LEFT, -79, "Include unsuccessful in stats", "statsIncludeMissed", function()
        -- The unsuccessful row changes the stats' height
        stats.Refresh()
        onLayoutChange()
    end)

    -- Which panels to show, set a little apart from the other options
    Panel.CreateSettingCheckbox(panel, LEFT, -107, "Show stats", "showStats", onLayoutChange)
    Panel.CreateSettingCheckbox(panel, LEFT, -127, "Show zones", "showZones", onLayoutChange)
    Panel.CreateSettingCheckbox(panel, LEFT, -147, "Show history", "showHistory", onLayoutChange)

    local resetAll = Panel.CreatePopupButton(panel, "Reset all data", 100, "FISHYWASHY_RESET_ALL")
    resetAll:SetPoint("TOPLEFT", Panel.LEFT, -169)

    return panel
end
