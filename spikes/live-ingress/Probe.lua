-- Transport fixtures only. This does not collect or display health data.
local addonName = ...
local config = TeamfitLiveProbeConfig
local probe = { used = 0, accepted = 0, duplicates = 0, failures = 0 }
TeamfitLiveProbe = probe
local last, incoming, fatal, ticker

local function integer(value, minimum, maximum)
    return type(value) == "number" and value >= minimum and value <= maximum
        and value == math.floor(value)
end

function probe.Receive(sample)
    incoming = sample
end

function probe.Status(now)
    if fatal then return fatal end
    if probe.used >= config.slots then return "EXHAUSTED - no further live reads" end
    if not last then return "WAITING - no test payload received" end
    if now < last.publishedAt - 2 then return "CLOCK ERROR - freshness unknown" end
    if now - last.publishedAt > config.staleSeconds then return "STALE - publisher not fresh" end
    return "FRESH TRANSPORT FIXTURE - not steps"
end

local display = CreateFrame("Frame", "TeamfitLiveProbeFrame", UIParent, "BackdropTemplate")
display:SetSize(430, 150)
display:SetPoint("CENTER")
display:SetClampedToScreen(true)
display:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
display:SetBackdropColor(0.04, 0.05, 0.06, 0.95)
local text = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOPLEFT", 16, -16)
text:SetWidth(398)
text:SetJustifyH("LEFT")

function probe.Render()
    local now = GetServerTime()
    local age = last and tostring(math.max(0, now - last.publishedAt)) .. "s" or "unavailable"
    local sequence = last and tostring(last.sequence) or "none"
    text:SetText("Teamfit Tactics - TRANSPORT TEST\n" .. probe.Status(now)
        .. "\nFixture sequence: " .. sequence .. " | Age: " .. age
        .. "\nSlots: " .. probe.used .. "/" .. config.slots .. " | Accepted: " .. probe.accepted
        .. "\nFailures: " .. probe.failures .. " | Duplicates: " .. probe.duplicates
        .. "\nNo steps measured. No account connected.")
end

function probe.Tick()
    if fatal or probe.used >= config.slots then
        if ticker then ticker:Cancel() end
        probe.Render()
        return
    end
    probe.used = probe.used + 1
    local slot = string.format("TeamfitLiveProbeSlot%04d", probe.used)
    if C_AddOns.IsAddOnLoaded(slot) then
        fatal = "ALREADY LOADED - no reusable disk read"
        probe.failures = probe.failures + 1
        probe.Render()
        return
    end
    incoming = nil
    local loaded = C_AddOns.LoadAddOn(slot)
    local sample = incoming
    incoming = nil
    local now = GetServerTime()
    if not loaded or type(sample) ~= "table" or sample.fixture ~= true
        or sample.slot ~= probe.used
        or not integer(sample.sequence, 1, 1000000000)
        or not integer(sample.publishedAt, 0, 9007199254740991)
        or sample.publishedAt > now + 2
        or type(sample.run) ~= "string" or not sample.run:match("^[a-f0-9]+$")
        or #sample.run ~= 32 then
        probe.failures = probe.failures + 1
    elseif last and sample.run ~= last.run then
        fatal = "PUBLISHER CHANGED - start a new diagnostic session"
    elseif last and (sample.sequence <= last.sequence or sample.publishedAt < last.publishedAt) then
        probe.duplicates = probe.duplicates + 1
    elseif now - sample.publishedAt <= config.staleSeconds then
        last = sample
        probe.accepted = probe.accepted + 1
    else
        probe.failures = probe.failures + 1
    end
    probe.Render()
end

SLASH_TEAMFITLIVEPROBE1 = "/teamfitprobe"
SlashCmdList.TEAMFITLIVEPROBE = function(command)
    if command == "stop" then
        fatal = "STOPPED - no further reads"
        if ticker then ticker:Cancel() end
    end
    display:Show()
    probe.Render()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    probe.Render()
    ticker = C_Timer.NewTicker(config.intervalSeconds, probe.Tick)
end)
