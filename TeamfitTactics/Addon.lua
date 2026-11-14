-- Live step ingress remains bounded by a finite pool of load-on-demand slots.
-- Legacy SavedVariables are deliberately never read or written here.
local addonName = ...
local config = TeamfitTacticsConfig
local tracker = { used = 0, accepted = 0, duplicates = 0, failures = 0 }
TeamfitTactics = tracker

local last, incoming, expectedSlot, fatal, ticker
local activeRun, activeSequence, activeSteps

local function integer(value, minimum, maximum)
    return type(value) == "number" and value >= minimum and value <= maximum
        and value == math.floor(value)
end

local function validRun(value)
    return type(value) == "string" and #value == 32
        and value:match("^[a-f0-9]+$") ~= nil
end

-- Payloads are accepted only while the tracker synchronously loads the expected slot.
function tracker.Receive(sample)
    if expectedSlot and type(sample) == "table" and sample.slot == expectedSlot then
        incoming = sample
    end
end

function tracker.Status(now)
    if fatal then return fatal end
    if config and tracker.used >= config.slots then
        return "EXHAUSTED - reconnect after a fresh game launch"
    end
    if not config then return "WAITING - desktop bridge not installed" end
    if not last then return "WAITING - no WalkingPad reading received" end
    if now < last.observedAt - 2 then return "CLOCK ERROR - freshness unknown" end
    if now - last.observedAt > config.staleSeconds then
        return "STALE - WalkingPad reading stopped"
    end
    if not last.available then return "DISCONNECTED - WalkingPad unavailable" end
    return "LIVE - KingSmith WalkingPad"
end

function tracker.CurrentSteps(now)
    if tracker.Status(now):sub(1, 4) == "LIVE" then return last.steps end
    return nil
end

local display = CreateFrame("Frame", "TeamfitTacticsFrame", UIParent, "BackdropTemplate")
display:SetSize(330, 112)
display:SetPoint("CENTER")
display:SetClampedToScreen(true)
display:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
display:SetBackdropColor(0.04, 0.05, 0.06, 0.95)
local text = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOPLEFT", 16, -16)
text:SetWidth(298)
text:SetJustifyH("LEFT")

function tracker.Render()
    local now = GetServerTime()
    local steps = tracker.CurrentSteps(now)
    local count = steps and tostring(steps) or "--"
    local age = last and tostring(math.max(0, now - last.observedAt)) .. "s" or "unavailable"
    local slots = config and (tostring(tracker.used) .. "/" .. tostring(config.slots)) or "not installed"
    text:SetText("Teamfit Tactics\n" .. count .. " measured session steps\n"
        .. tracker.Status(now) .. "\nReading age: " .. age .. " | Slots: " .. slots)
end

function tracker.Tick()
    if fatal or not config or tracker.used >= config.slots then
        if ticker then ticker:Cancel() end
        tracker.Render()
        return
    end
    tracker.used = tracker.used + 1
    local slot = tracker.used
    local name = string.format("TeamfitTacticsSlot%04d", slot)
    if C_AddOns.IsAddOnLoaded(name) then
        fatal = "ALREADY LOADED - no reusable disk read"
        tracker.failures = tracker.failures + 1
        tracker.Render()
        return
    end
    incoming = nil
    expectedSlot = slot
    local loaded = C_AddOns.LoadAddOn(name)
    expectedSlot = nil
    local sample = incoming
    incoming = nil
    local now = GetServerTime()
    local valid = loaded and type(sample) == "table"
        and sample.schemaVersion == 1
        and sample.source == "kingsmith-wilink"
        and sample.slot == slot
        and integer(sample.sequence, 1, 1000000000)
        and integer(sample.observedAt, 0, 9007199254740991)
        and sample.observedAt <= now + 2
        and integer(sample.steps, 0, 9007199254740991)
        and type(sample.available) == "boolean"
        and validRun(sample.run)
    if not valid then
        tracker.failures = tracker.failures + 1
    elseif now - sample.observedAt > config.staleSeconds then
        tracker.failures = tracker.failures + 1
    elseif sample.available and not activeRun then
        activeRun = sample.run
        activeSequence = sample.sequence
        activeSteps = sample.steps
        last = sample
        tracker.accepted = tracker.accepted + 1
    elseif activeRun and sample.run ~= activeRun then
        -- An unavailable reading must immediately clear the visible count even when
        -- the desktop has begun a new source generation. A fresh game launch is
        -- still required before accepting that new generation.
        if not sample.available then last = sample end
        fatal = "SOURCE SESSION CHANGED - relaunch WoW"
    elseif activeRun and (sample.sequence <= activeSequence
        or sample.observedAt < last.observedAt
        or (sample.available and sample.steps < activeSteps)) then
        tracker.duplicates = tracker.duplicates + 1
    else
        last = sample
        if activeRun then
            activeSequence = sample.sequence
            if sample.available then activeSteps = sample.steps end
        end
        tracker.accepted = tracker.accepted + 1
    end
    tracker.Render()
end

SLASH_TEAMFITTACTICS1 = "/teamfit"
SlashCmdList.TEAMFITTACTICS = function(command)
    if command == "stop" then
        fatal = "STOPPED - no further live reads"
        if ticker then ticker:Cancel() end
    elseif command:match("%S") then
        DEFAULT_CHAT_FRAME:AddMessage("|cff67ce94Teamfit Tactics:|r Manual step entry has been removed. No step data was changed.")
    end
    display:Show()
    tracker.Render()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    tracker.Render()
    if config then ticker = C_Timer.NewTicker(config.intervalSeconds, tracker.Tick) end
end)
