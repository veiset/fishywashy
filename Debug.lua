local _, ns = ...
local Storage, Catches = ns.Storage, ns.Catches

-- Prints fishing-related events to chat, to learn what the client sends for each outcome.
local Debug = {}
ns.Debug = Debug

local SPELL_EVENTS = {
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP",
}
local OTHER_EVENTS = { "UI_ERROR_MESSAGE", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED" }

local KNOWN_ERRORS = {}
if ERR_FISH_ESCAPED then KNOWN_ERRORS[ERR_FISH_ESCAPED] = "ERR_FISH_ESCAPED" end
if ERR_FISH_NOT_HOOKED then KNOWN_ERRORS[ERR_FISH_NOT_HOOKED] = "ERR_FISH_NOT_HOOKED" end

-- When the last fishing cast was sent, for the timestamps
local castSentAt

local function Log(message)
    local elapsed = castSentAt and ("+%.2fs"):format(GetTime() - castSentAt) or "-"
    DEFAULT_CHAT_FRAME:AddMessage(("|cff33ff99FishyWashy|r |cff888888[%s]|r %s"):format(elapsed, message))
end

local function OnSpellEvent(event, ...)
    -- UNIT_SPELLCAST_SENT has the target before the cast GUID and spell ID
    local spellID
    if event == "UNIT_SPELLCAST_SENT" then
        spellID = select(4, ...)
    else
        spellID = select(3, ...)
    end
    if not Catches.IsFishingSpell(spellID) then return end

    if event == "UNIT_SPELLCAST_SENT" then
        castSentAt = GetTime()
    end
    local details = ""
    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local _, _, _, startMS, endMS = UnitChannelInfo("player")
        if endMS then
            details = (" (lasts %.1fs, ends in %.1fs)"):format((endMS - startMS) / 1000, endMS / 1000 - GetTime())
        end
    end
    Log(event:gsub("^UNIT_SPELLCAST_", "") .. details)
end

local function OnOtherEvent(event, ...)
    if event == "UI_ERROR_MESSAGE" then
        local errorType, message = ...
        local known = KNOWN_ERRORS[message]
        Log(("UI_ERROR_MESSAGE %s: %s%s"):format(tostring(errorType), tostring(message),
            known and (" |cffffff00<" .. known .. ">|r") or ""))
    else
        Log(("%s autoLoot=%s fishing=%s"):format(event, tostring((...)), tostring(IsFishingLoot())))
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event:find("^UNIT_SPELLCAST_") then
        OnSpellEvent(event, ...)
    else
        OnOtherEvent(event, ...)
    end
end)

local function Apply()
    if Storage.GetSetting("debug") then
        for _, event in ipairs(SPELL_EVENTS) do
            events:RegisterUnitEvent(event, "player")
        end
        for _, event in ipairs(OTHER_EVENTS) do
            events:RegisterEvent(event)
        end
    else
        events:UnregisterAllEvents()
    end
end

function Debug.Init()
    Apply()
end

function Debug.Toggle()
    local enabled = not Storage.GetSetting("debug")
    Storage.SetSetting("debug", enabled)
    Apply()
    print("FishyWashy debug " .. (enabled and "on" or "off"))
end
