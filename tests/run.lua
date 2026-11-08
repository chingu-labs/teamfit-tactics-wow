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
assert(loadfile("legacy/Quest.lua"))("TeamfitTactics", ns)
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

test("retired commands cannot modify or reinterpret legacy step data", function()
    local saved = { version = 1, active = { steps = 650, source = "manual" } }
    TeamfitTacticsDB = saved
    SlashCmdList = {}
    local messages = {}
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, value) table.insert(messages, value) end }
    assert(loadfile("TeamfitTactics/Addon.lua"))()
    for _, command in ipairs({ "steps 9999", "start 2000", "finish" }) do
        SlashCmdList.TEAMFITTACTICS(command)
        equal(TeamfitTacticsDB, saved)
        equal(saved.active.steps, 650)
        equal(saved.active.source, "manual")
        assert(messages[#messages]:find("removed", 1, true))
    end
    SlashCmdList.TEAMFITTACTICS("")
    assert(messages[#messages]:find("isn't available yet", 1, true))
end)

print(passed .. " tests passed")
