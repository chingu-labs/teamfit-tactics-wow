-- API doubles check our state machine only, not real WoW file loading or rendering.
local count = 0
local function test(name, run)
    local ok, err = pcall(run)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    count = count + 1
    print("PASS " .. name)
end

local function sample(sequence, time, run)
    return { fixture = true, sequence = sequence, publishedAt = time,
        run = run or string.rep("a", 32) }
end

local function boot(samples, capacity)
    local now, loaded, frames = 1000, {}, {}
    local timer = { cancelled = false }
    function timer:Cancel() self.cancelled = true end
    local methods = {}
    for _, name in ipairs({ "SetSize", "SetPoint", "SetClampedToScreen", "SetBackdrop",
        "SetBackdropColor", "SetWidth", "SetJustifyH", "Show", "RegisterEvent", "UnregisterEvent" }) do
        methods[name] = function() end
    end
    function methods:SetText(text) self.text = text end
    function methods:SetScript(event, action) self[event] = action end
    function methods:CreateFontString() return setmetatable({}, { __index = methods }) end
    UIParent = {}
    SlashCmdList = {}
    CreateFrame = function()
        local frame = setmetatable({}, { __index = methods })
        table.insert(frames, frame)
        return frame
    end
    GetServerTime = function() return now end
    C_Timer = { NewTicker = function(interval, callback)
        assert(interval == 5)
        timer.callback = callback
        return timer
    end }
    C_AddOns = {
        IsAddOnLoaded = function(name) return loaded[name] == true end,
        LoadAddOn = function(name)
            local index = tonumber(name:match("(%d+)$"))
            loaded[name] = true
            local value = samples[index]
            if not value then return nil, "MISSING" end
            value.slot = index
            TeamfitLiveProbe.Receive(value)
            return true
        end,
    }
    TeamfitLiveProbeConfig = { slots = capacity or 8, intervalSeconds = 5, staleSeconds = 15 }
    assert(loadfile("spikes/live-ingress/Probe.lua"))("TeamfitLiveProbe")
    frames[2].OnEvent(frames[2], "ADDON_LOADED", "TeamfitLiveProbe")
    return TeamfitLiveProbe, function(value) now = value end, timer, loaded
end

test("fresh fixtures arrive from successive slots without reloading", function()
    local probe, clock, timer = boot({ sample(1, 1000), sample(2, 1005) })
    timer.callback()
    clock(1005)
    timer.callback()
    assert(probe.used == 2 and probe.accepted == 2)
    assert(probe.Status(1005):find("FRESH", 1, true))
    assert(probe.Status(1021):find("STALE", 1, true))
end)

test("duplicates and backwards sequence cannot refresh freshness", function()
    local probe, clock, timer = boot({ sample(2, 1000), sample(2, 1005), sample(1, 1010) })
    timer.callback()
    clock(1005)
    timer.callback()
    clock(1010)
    timer.callback()
    assert(probe.accepted == 1 and probe.duplicates == 2)
    assert(probe.Status(1016):find("STALE", 1, true))
end)

test("pool exhaustion stops reads and never leaves a live label", function()
    local probe, _, timer = boot({ sample(1, 1000), sample(2, 1000) }, 2)
    timer.callback()
    timer.callback()
    assert(probe.Status(1000):find("EXHAUSTED", 1, true))
    timer.callback()
    assert(timer.cancelled and probe.used == 2)
end)

test("loaded slots are never treated as renewable disk reads", function()
    local probe, _, timer, loaded = boot({ sample(1, 1000) })
    loaded.TeamfitLiveProbeSlot0001 = true
    timer.callback()
    assert(probe.Status(1000):find("ALREADY LOADED", 1, true))
    assert(probe.accepted == 0)
end)

test("publisher changes fail closed instead of mixing sessions", function()
    local probe, _, timer = boot({ sample(1, 1000), sample(2, 1000, string.rep("b", 32)) })
    timer.callback()
    timer.callback()
    assert(probe.Status(1000):find("PUBLISHER CHANGED", 1, true))
    timer.callback()
    assert(timer.cancelled and probe.accepted == 1)
end)

test("failed reads and invalid timestamps never create a measurement", function()
    local probe, _, timer = boot({ false, sample(1, 1030), sample(2, 900) })
    timer.callback()
    timer.callback()
    timer.callback()
    assert(probe.failures == 3 and probe.accepted == 0)
    assert(probe.Status(1000):find("WAITING", 1, true))
end)

test("stop prevents future loads", function()
    local probe, _, timer = boot({ sample(1, 1000), sample(2, 1000) })
    timer.callback()
    SlashCmdList.TEAMFITLIVEPROBE("stop")
    timer.callback()
    assert(timer.cancelled and probe.used == 1)
    assert(probe.Status(1000):find("STOPPED", 1, true))
end)

print(count .. " transport state tests passed (API doubles only)")
