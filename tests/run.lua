local passed = 0

local function test(name, run)
    local ok, err = pcall(run)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    passed = passed + 1
    print("PASS " .. name)
end

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local ns = {}
assert(loadfile("TeamfitTactics/Quest.lua"))("TeamfitTactics", ns)
local Quest = ns.Quest

test("corrections replace totals and finished quests cannot count twice", function()
    local state = Quest.Restore()
    assert(Quest.Start(state, 2000, 100))
    assert(Quest.SetSteps(state, 2200))
    assert(Quest.SetSteps(state, 1800))
    equal(Quest.Progress(state), 0.9)
    assert(Quest.Finish(state, 200))
    equal(state.totalSteps, 1800)
    equal(state.completedQuests, 0)
    equal(state.finishedQuests, 1)
    equal(Quest.Finish(state, 201), nil)
    equal(state.totalSteps, 1800)
    equal(#state.history, 1)
end)

test("over-goal steps are retained while the progress bar caps at one", function()
    local state = Quest.Restore()
    assert(Quest.Start(state, 2000, 100))
    assert(Quest.SetSteps(state, 3000))
    equal(Quest.Progress(state), 1)
    local recap = assert(Quest.Finish(state, 200))
    equal(recap.steps, 3000)
    equal(recap.source, "manual")
    equal(state.completedQuests, 1)
    equal(state.totalSteps, 3000)
end)

test("invalid input does not start or alter a quest", function()
    local state = Quest.Restore()
    for _, goal in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, "2000", 1000001 }) do
        equal(Quest.Start(state, goal, 100), nil)
        equal(state.active, nil)
    end
    equal(Quest.Start(state, nil, 100), nil)
    equal(Quest.SetSteps(state, 10), nil)
    assert(Quest.Start(state, 2000, 100))
    assert(Quest.SetSteps(state, 50))
    equal(Quest.Start(state, 3000, 101), nil)
    for _, steps in ipairs({ -1, 1.5, math.huge, 0 / 0, "500", 1000001 }) do
        equal(Quest.SetSteps(state, steps), nil)
        equal(state.active.steps, 50)
    end
    equal(Quest.SetSteps(state, nil), nil)
    assert(Quest.SetSteps(state, 0))
end)

test("unfinished quest and zero-step recap survive restore", function()
    local state = Quest.Restore()
    assert(Quest.Start(state, 1500, 100))
    local restored = assert(Quest.Restore(state))
    equal(restored.active.goal, 1500)
    equal(restored.active.steps, 0)
    assert(Quest.Finish(restored, 200))
    equal(restored.history[1].steps, 0)
    equal(restored.completedQuests, 0)
    equal(Quest.Restore(restored), restored)
end)

test("history stays bounded without dropping lifetime totals", function()
    local state = Quest.Restore()
    for i = 1, 25 do
        assert(Quest.Start(state, 100, i * 100))
        assert(Quest.SetSteps(state, 100 + i))
        assert(Quest.Finish(state, i * 100 + 10))
    end
    equal(#state.history, 20)
    equal(state.history[1].steps, 125)
    equal(state.history[20].steps, 106)
    equal(state.totalSteps, 2825)
    equal(state.completedQuests, 25)
end)

test("unknown or invalid saved state is rejected without overwriting it", function()
    local future = { version = 2, important = "keep" }
    equal(Quest.Restore(future), nil)
    equal(future.important, "keep")
    local invalid = Quest.Restore()
    invalid.history = { { goal = 100, steps = 5 } }
    equal(Quest.Restore(invalid), nil)
    equal(#invalid.history, 1)
end)

test("backwards clock cannot finish or mutate an active quest", function()
    local state = Quest.Restore()
    assert(Quest.Start(state, 100, 200))
    equal(Quest.Finish(state, 100), nil)
    assert(state.active)
    equal(#state.history, 0)
    assert(Quest.Finish(state, 201))
end)

-- Explicit UI doubles: no fallback methods, game simulation, or rendering.
local methods = {}
for _, method in ipairs({
    "SetSize", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "ClearAllPoints",
    "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetNumeric", "SetMaxLetters",
    "ClearFocus", "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues",
    "SetAllPoints", "SetColorTexture", "SetWidth", "SetJustifyH",
}) do
    methods[method] = function() end
end
function methods:SetPoint(...) self.point = { ... } end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetText(text) self.text = tostring(text) end
function methods:GetText() return self.text or "" end
function methods:SetEnabled(enabled)
    assert(type(enabled) == "boolean")
    self.enabled = enabled
end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:GetCenter() return 500, 400 end
function methods:SetValue(value) self.value = value end

local function widget()
    return setmetatable({ scripts = {}, events = {}, children = {} }, { __index = methods })
end
function methods:CreateFontString()
    local child = widget()
    table.insert(self.children, child)
    return child
end
function methods:CreateTexture() return widget() end

local now = 1000
local function boot(saved)
    TeamfitTacticsDB = saved
    TeamfitTacticsTracker = nil
    UIParent = widget()
    SlashCmdList = {}
    local frames, messages = {}, {}
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(messages, text) end }
    GetServerTime = function() return now end
    CreateFrame = function(_, name, parent)
        local frame = widget()
        table.insert(frames, frame)
        if name then _G[name] = frame end
        if parent then table.insert(parent.children, frame) end
        return frame
    end
    local addon = {}
    for _, file in ipairs({ "Quest", "Tracker", "Addon" }) do
        assert(loadfile("TeamfitTactics/" .. file .. ".lua"))("TeamfitTactics", addon)
    end
    local events = frames[1]
    events.scripts.OnEvent(events, "ADDON_LOADED", "AnotherAddon")
    equal(TeamfitTacticsTracker, nil)
    events.scripts.OnEvent(events, "ADDON_LOADED", "TeamfitTactics")
    equal(events.events.ADDON_LOADED, nil)
    return TeamfitTacticsTracker, messages
end

test("slash command lifecycle updates the tracker and saves one recap", function()
    local tracker, messages = boot()
    equal(tracker.shown, true)
    equal(tracker.start.enabled, true)
    equal(tracker.steps.enabled, false)
    SlashCmdList.TEAMFITTACTICS("start 2000")
    equal(tracker.goal.enabled, false)
    SlashCmdList.TEAMFITTACTICS("steps 2500")
    equal(tracker.progress.value, 1)
    assert(messages[#messages]:find("goal reached", 1, true))
    now = 1100
    SlashCmdList.TEAMFITTACTICS("finish")
    equal(#TeamfitTacticsDB.history, 1)
    equal(TeamfitTacticsDB.history[1].steps, 2500)
    equal(tracker.start.enabled, true)
    SlashCmdList.TEAMFITTACTICS("finish")
    equal(#TeamfitTacticsDB.history, 1)
    SlashCmdList.TEAMFITTACTICS("history")
    assert(messages[#messages]:find("2500 / 2000 steps (manual)", 1, true))
end)

test("button and keyboard paths use the same quest lifecycle", function()
    local tracker = boot()
    tracker.goal:SetText("1500")
    tracker.start.scripts.OnClick()
    equal(TeamfitTacticsDB.active.goal, 1500)
    tracker.steps:SetText("900")
    tracker.steps.scripts.OnEnterPressed(tracker.steps)
    equal(TeamfitTacticsDB.active.steps, 900)
    tracker.finish.scripts.OnClick()
    equal(TeamfitTacticsDB.history[1].steps, 900)
    tracker.goal:SetText("1000")
    tracker.goal.scripts.OnEnterPressed(tracker.goal)
    tracker.steps:SetText("500")
    tracker.update.scripts.OnClick()
    equal(TeamfitTacticsDB.active.steps, 500)
end)

test("hide, reload, restore, and reset position preserve the active quest", function()
    local tracker = boot()
    SlashCmdList.TEAMFITTACTICS("start 2000")
    SlashCmdList.TEAMFITTACTICS("steps 650")
    SlashCmdList.TEAMFITTACTICS("")
    equal(tracker.shown, false)
    tracker = boot(TeamfitTacticsDB)
    equal(tracker.shown, false)
    equal(tracker.steps:GetText(), "650")
    tracker.scripts.OnDragStop(tracker)
    equal(TeamfitTacticsDB.position.x, 0)
    SlashCmdList.TEAMFITTACTICS("resetposition")
    equal(tracker.shown, true)
    equal(TeamfitTacticsDB.position, nil)
    equal(TeamfitTacticsDB.active.steps, 650)
end)

test("unsupported saved data prevents initialization and remains intact", function()
    local future = { version = 99, preserve = true }
    local tracker, messages = boot(future)
    equal(tracker, nil)
    equal(TeamfitTacticsDB, future)
    assert(future.preserve)
    equal(SlashCmdList.TEAMFITTACTICS, nil)
    assert(messages[1]:find("preserved", 1, true))
end)

print(passed .. " tests passed")
