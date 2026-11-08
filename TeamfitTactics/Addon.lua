local addonName, ns = ...
local Quest = ns.Quest

local function message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff67ce94Teamfit Tactics:|r " .. text)
end

local function recapText(recap)
    local result = recap.steps >= recap.goal and "Goal completed!" or "Quest saved."
    return result .. " " .. recap.steps .. " / " .. recap.goal .. " steps (manual)."
end

local function initialize()
    local state, restoreError = Quest.Restore(TeamfitTacticsDB)
    if not state then
        message(restoreError)
        return
    end
    TeamfitTacticsDB = state
    local tracker
    local actions = {}

    local function refresh(result, err, text)
        if not result then
            message(err)
            return
        end
        tracker:Refresh()
        if text then message(text) end
    end

    function actions.start(goal)
        local result, err = Quest.Start(state, goal, GetServerTime())
        refresh(result, err, result and "Walking quest started. Enter your session steps as you go.")
    end

    function actions.steps(total)
        local previous = state.active and state.active.steps or 0
        local result, err = Quest.SetSteps(state, total)
        local reached = result and previous < result.goal and result.steps >= result.goal
        refresh(result, err, reached and "Walking goal reached! Finish the quest to save your recap.")
    end

    function actions.finish()
        local result, err = Quest.Finish(state, GetServerTime())
        refresh(result, err, result and recapText(result))
    end

    tracker = ns.CreateTracker(state, actions)
    SLASH_TEAMFITTACTICS1 = "/teamfit"
    SlashCmdList.TEAMFITTACTICS = function(text)
        local command, argument = text:match("^%s*(%S*)%s*(.-)%s*$")
        command = command:lower()
        if command == "" then
            state.hidden = not state.hidden
            tracker:SetShown(not state.hidden)
        elseif command == "start" then
            actions.start(tonumber(argument))
        elseif command == "steps" then
            actions.steps(tonumber(argument))
        elseif command == "finish" and argument == "" then
            actions.finish()
        elseif command == "history" and argument == "" then
            if #state.history == 0 then message("No finished walking quests yet.") end
            for i = 1, math.min(5, #state.history) do
                message(recapText(state.history[i]))
            end
        elseif command == "resetposition" and argument == "" then
            tracker:ResetPosition()
            state.hidden = false
            tracker:Show()
        else
            message("/teamfit: show/hide | start <goal> | steps <total> | finish | history | resetposition")
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    initialize()
end)
