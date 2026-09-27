local _, ns = ...
local Storage = ns.Storage

-- A panel in the main frame: a divider, a small heading with an optional value on the
-- right, optional subheading lines, and rows of left-aligned item + right-aligned value.
-- The panel grows and shrinks to fit the rows it's filled with.
local Panel = {}
ns.Panel = Panel

local ROW_HEIGHT = 16
local HEADER_HEIGHT = 21
local GAP = 6
local EXTRA_WIDTH = 60
local HEADING_LEFT = 12
local MISSED_ICON = "Interface/Icons/Trade_Fishing"

function Panel.CreateDivider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.2)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 6, y)
    line:SetPoint("TOPRIGHT", -6, y)
end

-- A small checkbox with a label, bound to a boolean setting. Returns the checkbox and label.
function Panel.CreateSettingCheckbox(parent, left, top, text, settingKey, onChange)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(18, 18)
    check:SetPoint("TOPLEFT", left, top)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(text)
    -- Let clicks on the label toggle the checkbox too
    check:SetHitRectInsets(0, -(label:GetStringWidth() + 2), 0, 0)
    check:SetChecked(Storage.GetSetting(settingKey))
    check:SetScript("OnClick", function(self)
        Storage.SetSetting(settingKey, self:GetChecked())
        if onChange then onChange() end
    end)
    return check, label
end

function Panel.CreateSmallButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 18)
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- A small button that asks for confirmation with the given StaticPopup
function Panel.CreatePopupButton(parent, text, width, popup)
    return Panel.CreateSmallButton(parent, text, width, function()
        StaticPopup_Show(popup)
    end)
end

-- A white "x" in a small box at the top right, in the same style as the window; turns gold
-- on hover
function Panel.CreateCloseButton(parent, onClick)
    local close = CreateFrame("Button", nil, parent, "BackdropTemplate")
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -2, -5)
    close:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    close:SetBackdropColor(0, 0, 0, 0.5)
    close:SetBackdropBorderColor(1, 1, 1, 0.6)
    close:SetNormalFontObject("GameFontHighlight")
    close:SetHighlightFontObject("GameFontNormal")
    close:SetText("x")
    -- The lowercase x sits low in the font, so lift it to the middle of the box
    close:GetFontString():SetPoint("CENTER", 0, 1)
    close:SetScript("OnClick", onClick)
    return close
end

function Panel.FormatTimeSince(timestamp)
    local seconds = time() - timestamp
    if seconds < 60 then
        return seconds .. "s ago"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m ago"
    elseif seconds < 86400 then
        return math.floor(seconds / 3600) .. "h ago"
    else
        return math.floor(seconds / 86400) .. "d ago"
    end
end

-- The catch rate and seconds-per-catch texts, from a Stats cast summary
function Panel.FormatCastSummary(rate, caught, casts, average)
    return rate and ("Catch rate: %.0f%% (%d/%d)"):format(rate, caught, casts) or "Catch rate: -",
        average and ("%.1fs per catch"):format(average) or "- per catch"
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
        -- Optional fixed-width column at the far right, so the value column stays aligned
        local extra = self:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        extra:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -10, y)
        extra:SetWidth(EXTRA_WIDTH)
        extra:SetJustifyH("RIGHT")
        extra:SetWordWrap(false)
        local value = self:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        local item = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        item:SetPoint("TOPLEFT", self.body, "TOPLEFT", 12, y)
        item:SetPoint("RIGHT", value, "LEFT", -6, 0)
        item:SetJustifyH("LEFT")
        item:SetWordWrap(false)

        -- Shows the panel's tooltip for the row's entry; only takes the mouse when there is one
        local hover = CreateFrame("Frame", nil, self)
        hover:SetPoint("TOPLEFT", self.body, "TOPLEFT", 6, y)
        hover:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -6, y)
        hover:SetHeight(ROW_HEIGHT)
        hover:EnableMouse(false)
        hover:SetScript("OnEnter", function()
            GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
            self.tooltip(hover.entry)
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", GameTooltip_Hide)

        -- Faint background on every other row, for panels that ask for it
        local stripe = self:CreateTexture(nil, "BACKGROUND")
        stripe:SetColorTexture(1, 1, 1, 0.03)
        -- Text sits at the top of its row, so start a little above it to centre the band
        stripe:SetPoint("TOPLEFT", self.body, "TOPLEFT", 6, y + 3)
        stripe:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -6, y + 3)
        stripe:SetHeight(ROW_HEIGHT)
        stripe:Hide()

        row = { item = item, value = value, extra = extra, hover = hover, stripe = stripe, y = y }
        self.rows[i] = row
    end
    return row
end

-- A setting checkbox right after the heading
function PanelMethods:AddHeadingCheckbox(text, settingKey, onChange)
    local check = Panel.CreateSettingCheckbox(self, 0, 0, text, settingKey, onChange)
    check:ClearAllPoints()
    check:SetPoint("LEFT", self.heading, "RIGHT", 6, 0)
end

-- Gives every other row a faint background, so names are easy to match with their numbers.
-- Entries with heading = true are left plain.
function PanelMethods:SetStriped(striped)
    self.striped = striped
end

-- Gives the value column a fixed width with left-aligned text, instead of fitting its text
function PanelMethods:SetValueWidth(width)
    self.valueWidth = width
end

function PanelMethods:SetHeadingValue(text)
    self.headingValue:SetText(text)
end

-- Sets the left and right text of subheading line i
function PanelMethods:SetSubheading(i, left, right)
    self.subheadings[i].left:SetText(left)
    self.subheadings[i].right:SetText(right)
end

-- Reserves space under the heading and subheadings for custom content, such as a graph.
-- Returns a frame that fills the space.
function PanelMethods:AddHeaderContent(height)
    self.content = CreateFrame("Frame", nil, self)
    self.content:SetHeight(height)
    self:SetSubheadingsShown(self.subheadingsShown)
    return self.content
end

function PanelMethods:SetHeaderContentShown(shown)
    self.content:SetShown(shown)
    self:SetSubheadingsShown(self.subheadingsShown)
end

function PanelMethods:SetSubheadingsShown(shown)
    self.subheadingsShown = shown
    for _, subheading in ipairs(self.subheadings) do
        subheading.left:SetShown(shown)
        subheading.right:SetShown(shown)
    end
    self.headerHeight = HEADER_HEIGHT + (shown and #self.subheadings * ROW_HEIGHT or 0)
    if self.content and self.content:IsShown() then
        self.content:SetPoint("TOPLEFT", 0, -self.headerHeight)
        self.content:SetPoint("TOPRIGHT", 0, -self.headerHeight)
        self.headerHeight = self.headerHeight + self.content:GetHeight()
    end
    self.body:SetPoint("TOPLEFT", 0, -self.headerHeight)
    self.body:SetPoint("TOPRIGHT", 0, -self.headerHeight)
    UpdateHeight(self)
end

-- Fills the panel with one row per entry. format(entry) returns the item and value text, and
-- optionally text for an extra column to the right of the value. The optional tooltip(entry)
-- fills GameTooltip when a row is hovered.
function PanelMethods:SetEntries(entries, format, tooltip)
    self.tooltip = tooltip
    local texts, hasExtra = {}, false
    for i, entry in ipairs(entries) do
        texts[i] = { format(entry) }
        hasExtra = hasExtra or texts[i][3] ~= nil
    end
    -- The value sits at the right edge, or left of the extra column when there is one
    local valueRight = hasExtra and -(10 + EXTRA_WIDTH + 6) or -10
    -- Stripes alternate between plain rows; rows marked heading are never striped and start
    -- the alternation again
    local stripeIndex = 0
    for i, text in ipairs(texts) do
        local row = GetRow(self, i)
        row.value:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", valueRight, row.y)
        if self.valueWidth then
            row.value:SetWidth(self.valueWidth)
            row.value:SetJustifyH("LEFT")
            row.value:SetWordWrap(false)
        end
        row.item:SetText(text[1])
        row.value:SetText(text[2])
        row.extra:SetText(text[3] or "")
        row.hover.entry = entries[i]
        row.hover:EnableMouse(tooltip ~= nil)
        if entries[i].heading then
            stripeIndex = 0
            row.stripe:Hide()
        else
            stripeIndex = stripeIndex + 1
            row.stripe:SetShown(self.striped and stripeIndex % 2 == 0)
        end
    end
    for i = #entries + 1, #self.rows do
        self.rows[i].item:SetText("")
        self.rows[i].value:SetText("")
        self.rows[i].extra:SetText("")
        self.rows[i].hover:EnableMouse(false)
        self.rows[i].stripe:Hide()
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

    panel.heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.heading:SetPoint("TOPLEFT", HEADING_LEFT, -5)
    panel.heading:SetText(title)
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
