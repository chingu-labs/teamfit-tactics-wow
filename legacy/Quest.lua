-- Retired manual prototype. Not loaded by the product addon.
local _, ns = ...
local Quest = {}
ns.Quest = Quest

Quest.MAX_HISTORY = 20
Quest.MAX_STEPS = 1000000

local function wholeNumber(value, minimum)
    return type(value) == "number" and value >= minimum
        and value <= Quest.MAX_STEPS and value == math.floor(value)
end

local function validTime(value)
    return type(value) == "number" and value >= 0 and value < math.huge
        and value == math.floor(value)
end

local function validQuest(quest, finished)
    return type(quest) == "table" and wholeNumber(quest.goal, 1)
        and wholeNumber(quest.steps, 0) and validTime(quest.startedAt)
        and quest.source == "manual"
        and (not finished or (validTime(quest.finishedAt) and quest.finishedAt >= quest.startedAt))
end

function Quest.Restore(saved)
    if saved == nil then
        return {
            version = 1, goal = 2000, history = {},
            finishedQuests = 0, completedQuests = 0, totalSteps = 0, hidden = false,
        }
    end
    if type(saved) ~= "table" or saved.version ~= 1 then
        return nil, "Unsupported saved data. Your existing data has been preserved."
    end
    if not wholeNumber(saved.goal, 1) or type(saved.history) ~= "table"
        or #saved.history > Quest.MAX_HISTORY
        or (saved.active ~= nil and not validQuest(saved.active, false)) then
        return nil, "Invalid saved quest data. Your existing data has been preserved."
    end
    for _, quest in ipairs(saved.history) do
        if not validQuest(quest, true) then
            return nil, "Invalid saved recap. Your existing data has been preserved."
        end
    end
    for _, key in ipairs({ "finishedQuests", "completedQuests", "totalSteps" }) do
        if not validTime(saved[key]) then
            return nil, "Invalid saved totals. Your existing data has been preserved."
        end
    end
    return saved
end

function Quest.Start(state, goal, now)
    if state.active then
        return nil, "Finish your current walking quest before starting another."
    end
    if not wholeNumber(goal, 1) then
        return nil, "Enter a whole-number goal from 1 to 1,000,000 steps."
    end
    if not validTime(now) then
        return nil, "The current time is unavailable. Try again."
    end
    state.goal = goal
    state.active = { goal = goal, steps = 0, startedAt = now, source = "manual" }
    return state.active
end

function Quest.SetSteps(state, steps)
    if not state.active then
        return nil, "Start a walking quest first."
    end
    if not wholeNumber(steps, 0) then
        return nil, "Enter a whole-number session total from 0 to 1,000,000 steps."
    end
    state.active.steps = steps
    return state.active
end

function Quest.Finish(state, now)
    local active = state.active
    if not active then
        return nil, "There is no walking quest to finish."
    end
    if not validTime(now) or now < active.startedAt then
        return nil, "The clock moved backwards. Try finishing again after it catches up."
    end
    local recap = {
        goal = active.goal, steps = active.steps, source = active.source,
        startedAt = active.startedAt, finishedAt = now,
    }
    table.insert(state.history, 1, recap)
    if #state.history > Quest.MAX_HISTORY then
        table.remove(state.history)
    end
    state.finishedQuests = state.finishedQuests + 1
    state.totalSteps = state.totalSteps + recap.steps
    if recap.steps >= recap.goal then
        state.completedQuests = state.completedQuests + 1
    end
    state.active = nil
    return recap
end

function Quest.Progress(state)
    if not state.active then
        return 0
    end
    return math.min(1, state.active.steps / state.active.goal)
end
