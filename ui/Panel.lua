local _, ns = ...
local Storage = ns.Storage

-- A panel in the main frame: a divider, a small heading with an optional value on the
-- right, optional subheading lines, and rows of left-aligned item + right-aligned value.
-- The panel grows and shrinks to fit the rows it's filled with.
local Panel = {}
ns.Panel = Panel

local ROW_HEIGHT = 16
local HEADER_HEIGHT = 19
local GAP = 6
local MISSED_ICON = "Interface/Icons/Trade_Fishing"

function Panel.CreateDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.2)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 6, y)
    line:SetPoint("TOPRIGHT", -6, y)
end

-- A small checkbox with a label, bound to a boolean setting. Returns the checkbox and label.
function Panel.CreateSettingCheckbox(parent, top, text, settingKey, onChange)
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
    return check, label
end

function Panel.FormatItem(icon, link)
    return ("|T%s:14|t %s"):format(icon, link)
end

function Panel.FormatMiss()
    return Panel.FormatItem(MISSED_ICON, "|cff9d9d9dUnsuccessful|r")
end

local PanelMethods = {}

local function UpdateHeight(self)
    self:SetHeight(self.headerHeight + math.max(self.rowCount, 1) * ROW_HEIGHT + GAP)
end

local function GetRow(self, i)
    local row = self.rows[i]
    if not row then
        local y = -(i - 1) * ROW_HEIGHT
        local value = self:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        value:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -10, y)
        local item = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        item:SetPoint("TOPLEFT", self.body, "TOPLEFT", 12, y)
        item:SetPoint("RIGHT", value, "LEFT", -6, 0)
        item:SetJustifyH("LEFT")
        item:SetWordWrap(false)
        row = { item = item, value = value }
        self.rows[i] = row
    end
    return row
end

function PanelMethods:SetHeadingValue(text)
    self.headingValue:SetText(text)
end

-- Sets the left and right text of subheading line i
function PanelMethods:SetSubheading(i, left, right)
    self.subheadings[i].left:SetText(left)
    self.subheadings[i].right:SetText(right)
end

function PanelMethods:SetSubheadingsShown(shown)
    for _, subheading in ipairs(self.subheadings) do
        subheading.left:SetShown(shown)
        subheading.right:SetShown(shown)
    end
    self.headerHeight = HEADER_HEIGHT + (shown and #self.subheadings * ROW_HEIGHT or 0)
    self.body:SetPoint("TOPLEFT", 0, -self.headerHeight)
    self.body:SetPoint("TOPRIGHT", 0, -self.headerHeight)
    UpdateHeight(self)
end

-- Fills the panel with one row per entry; format(entry) returns the item and value text
function PanelMethods:SetEntries(entries, format)
    for i, entry in ipairs(entries) do
        local row = GetRow(self, i)
        local itemText, valueText = format(entry)
        row.item:SetText(itemText)
        row.value:SetText(valueText)
    end
    for i = #entries + 1, #self.rows do
        self.rows[i].item:SetText("")
        self.rows[i].value:SetText("")
    end
    self.empty:SetShown(#entries == 0)
    self.rowCount = #entries
    UpdateHeight(self)
end

function Panel.Create(parent, title, emptyMessage, subheadingCount)
    local panel = CreateFrame("Frame", nil, parent)
    for name, method in pairs(PanelMethods) do
        panel[name] = method
    end
    Panel.CreateDivider(panel, 0)

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", 12, -5)
    heading:SetText(title)
    panel.headingValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.headingValue:SetPoint("TOPRIGHT", -10, -5)

    panel.subheadings = {}
    for i = 1, subheadingCount or 0 do
        local y = -HEADER_HEIGHT - (i - 1) * ROW_HEIGHT
        local right = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        right:SetPoint("TOPRIGHT", -10, y)
        local left = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        left:SetPoint("TOPLEFT", 12, y)
        left:SetPoint("RIGHT", right, "LEFT", -6, 0)
        left:SetJustifyH("LEFT")
        panel.subheadings[i] = { left = left, right = right }
    end

    -- Rows hang off the body, which moves up when the subheadings are hidden
    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetHeight(1)

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 12, 0)
    panel.empty:SetText(emptyMessage)

    panel.rows = {}
    panel.rowCount = 0
    panel:SetSubheadingsShown(true)
    return panel
end
