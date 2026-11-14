-- API doubles verify state behavior only, not real WoW loading or rendering.
local count = 0
local function test(name, run)
    local ok, err = pcall(run)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    count = count + 1
    print("PASS " .. name)
end

local function sample(sequence, observed, stepCount, available, run)
    return { schemaVersion = 1, source = "kingsmith-wilink", sequence = sequence,
        observedAt = observed, steps = stepCount, available = available,
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
    function methods:SetText(value) self.text = value end
    function methods:SetScript(event, action) self[event] = action end
    function methods:CreateFontString() return setmetatable({}, { __index = methods }) end
    UIParent = {}
    SlashCmdList = {}
    DEFAULT_CHAT_FRAME = { AddMessage = function() end }
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
            TeamfitTactics.Receive(value)
            return true
        end,
    }
    TeamfitTacticsConfig = { slots = capacity or 8, intervalSeconds = 5, staleSeconds = 15 }
    assert(loadfile("TeamfitTactics/Addon.lua"))("TeamfitTactics")
    frames[2].OnEvent(frames[2], "ADDON_LOADED", "TeamfitTactics")
    return TeamfitTactics, function(value) now = value end, timer, loaded
end

test("fresh measured steps update and stale readings disappear", function()
    local tracker, clock, timer = boot({ sample(1, 1000, 10, true), sample(2, 1005, 18, true) })
    timer.callback()
    clock(1005)
    timer.callback()
    assert(tracker.accepted == 2 and tracker.CurrentSteps(1005) == 18)
    assert(tracker.Status(1005):find("LIVE", 1, true))
    assert(tracker.CurrentSteps(1021) == nil)
    assert(tracker.Status(1021):find("STALE", 1, true))
end)

test("unavailable readings clear steps and may report zero", function()
    local tracker, clock, timer = boot({ sample(1, 1000, 10, true), sample(2, 1005, 0, false) })
    timer.callback()
    clock(1005)
    timer.callback()
    assert(tracker.accepted == 2 and tracker.CurrentSteps(1005) == nil)
    assert(tracker.Status(1005):find("DISCONNECTED", 1, true))
end)

test("idle unavailable generation does not bind the later source session", function()
    local tracker, clock, timer = boot({
        sample(1, 1000, 0, false, string.rep("a", 32)),
        sample(1, 1005, 4, true, string.rep("b", 32)),
    })
    timer.callback()
    clock(1005)
    timer.callback()
    assert(tracker.accepted == 2 and tracker.CurrentSteps(1005) == 4)
end)

test("stale first reading cannot bind a source session", function()
    local tracker, clock, timer = boot({
        sample(1, 980, 10, true, string.rep("a", 32)),
        sample(1, 1005, 3, true, string.rep("b", 32)),
    })
    timer.callback()
    assert(tracker.accepted == 0 and tracker.CurrentSteps(1000) == nil)
    clock(1005)
    timer.callback()
    assert(tracker.accepted == 1 and tracker.CurrentSteps(1005) == 3)
end)

test("backwards sequence and measured steps cannot refresh freshness", function()
    local tracker, clock, timer = boot({
        sample(2, 1000, 10, true), sample(2, 1005, 11, true), sample(3, 1010, 9, true),
    })
    timer.callback()
    clock(1005)
    timer.callback()
    clock(1010)
    timer.callback()
    assert(tracker.accepted == 1 and tracker.duplicates == 2)
    assert(tracker.CurrentSteps(1016) == nil)
end)

test("changed active source fails closed and clears an unavailable reading", function()
    local tracker, clock, timer = boot({
        sample(1, 1000, 5, true), sample(1, 1005, 0, false, string.rep("b", 32)),
    })
    timer.callback()
    clock(1005)
    timer.callback()
    assert(tracker.CurrentSteps(1005) == nil)
    assert(tracker.Status(1005):find("SOURCE SESSION CHANGED", 1, true))
end)

test("payload injection outside the expected load is ignored", function()
    local tracker, _, timer = boot({ sample(1, 1000, 7, true) })
    tracker.Receive({ slot = 1, schemaVersion = 1, source = "kingsmith-wilink",
        sequence = 999, observedAt = 1000, steps = 999, available = true,
        run = string.rep("a", 32) })
    timer.callback()
    assert(tracker.CurrentSteps(1000) == 7)
end)

test("pool exhaustion and stop never leave a live count", function()
    local tracker, _, timer = boot({ sample(1, 1000, 7, true) }, 1)
    timer.callback()
    assert(tracker.CurrentSteps(1000) == nil)
    assert(tracker.Status(1000):find("EXHAUSTED", 1, true))
    timer.callback()
    assert(timer.cancelled)

    tracker, _, timer = boot({ sample(1, 1000, 7, true), sample(2, 1005, 8, true) })
    timer.callback()
    SlashCmdList.TEAMFITTACTICS("stop")
    timer.callback()
    assert(timer.cancelled and tracker.used == 1 and tracker.CurrentSteps(1000) == nil)
end)

test("legacy saved data is never read, changed, or relabeled", function()
    local saved = { version = 1, active = { steps = 650, source = "manual" } }
    TeamfitTacticsDB = saved
    local tracker, _, timer = boot({ sample(1, 1000, 7, true) })
    timer.callback()
    SlashCmdList.TEAMFITTACTICS("steps 9999")
    assert(TeamfitTacticsDB == saved and saved.active.steps == 650)
    assert(tracker.CurrentSteps(1000) == 7)
end)

print(count .. " addon step state tests passed (API doubles only)")
