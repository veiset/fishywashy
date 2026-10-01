local addonName, ns = ...
local Utils, Storage, Sound, Stats, Catches, UI = ns.Utils, ns.Storage, ns.Sound, ns.Stats, ns.Catches, ns.UI

-- Colours for the start-up message: the addon name, and the parts to notice
local NAME_COLOR = "33ff99"
local HIGHLIGHT_COLOR = "ffd100"

-- "FishyWashy loaded, equip a fishing rod or type /fishy to open", then, once something has
-- been caught, the all-time total, favourite zone and sessions
local function PrintWelcome()
    local name = Utils.Color("FishyWashy", NAME_COLOR)
    print(("%s loaded, equip a fishing rod or type %s to open"):format(name, Utils.Color("/fishy", HIGHLIGHT_COLOR)))

    local total = Stats.GetGlobalSummary()
    if total == 0 then return end
    local caught = ("%s caught so far"):format(Utils.Color(total, HIGHLIGHT_COLOR))
    local zone = Stats.GetZoneSummary()[1]
    if zone then
        caught = ("%s, favourite zone: %s (%.0f%%)"):format(caught, Utils.Color(zone.zone, HIGHLIGHT_COLOR),
            zone.percent)
    end
    caught = ("%s, sessions: %s"):format(caught, Utils.Color(Storage.GetGlobalSessions(), HIGHLIGHT_COLOR))
    print(("%s %s"):format(name, caught))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    Storage.Init()
    -- Settings left boosted by a logout or crash mid-cast
    Sound.Restore()
    UI.Init()
    PrintWelcome()
end)

-- "/fishy" toggles the window; "/fishy debug-reset_all_data" deletes all data, without asking
SLASH_FISHYWASHY1 = "/fishy"
SlashCmdList.FISHYWASHY = function(message)
    if strtrim(message) == "debug-reset_all_data" then
        Catches.ResetAll()
        print(Utils.Color("FishyWashy", NAME_COLOR) .. " all data deleted, settings kept")
        return
    end
    UI.Toggle()
end
