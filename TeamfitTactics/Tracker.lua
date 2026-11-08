local _, ns = ...

local function label(parent, text, x, y, font)
    local result = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    result:SetPoint("TOPLEFT", x, y)
    result:SetText(text)
    return result
end

local function input(parent, x, y)
    local result = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    result:SetSize(130, 24)
    result:SetPoint("TOPLEFT", x, y)
    result:SetAutoFocus(false)
    result:SetNumeric(true)
    result:SetMaxLetters(7)
    result:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return result
end

local function button(parent, text, x, y, width, action)
    local result = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    result:SetSize(width, 26)
    result:SetPoint("TOPLEFT", x, y)
    result:SetText(text)
    result:SetScript("OnClick", action)
    return result
end

function ns.CreateTracker(state, actions)
    local frame = CreateFrame("Frame", "TeamfitTacticsTracker", UIParent, "BackdropTemplate")
    frame:SetSize(350, 362)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.055, 0.065, 0.075, 0.96)
    frame:SetBackdropBorderColor(0.35, 0.39, 0.42, 1)

    function frame:ResetPosition()
        state.position = nil
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local position = state.position
    if type(position) == "table" and type(position.x) == "number"
        and type(position.y) == "number" and position.x == position.x
        and position.y == position.y and math.abs(position.x) < 100000
        and math.abs(position.y) < 100000 then
        frame:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    else
        frame:ResetPosition()
    end
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and y and parentX and parentY then
            state.position = { x = x - parentX, y = y - parentY }
        end
    end)

    label(frame, "Teamfit Tactics", 18, -18, "GameFontNormalLarge")
    label(frame, "Walking quest", 18, -43, "GameFontHighlightSmall")
    button(frame, "X", 306, -12, 28, function()
        state.hidden = true
        frame:Hide()
    end)
    label(frame, "Goal (steps)", 18, -77)
    frame.goal = input(frame, 24, -98)
    frame.start = button(frame, "Start quest", 190, -98, 140, function()
        actions.start(tonumber(frame.goal:GetText()))
    end)
    frame.goal:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        actions.start(tonumber(self:GetText()))
    end)

    frame.progress = CreateFrame("StatusBar", nil, frame)
    frame.progress:SetPoint("TOPLEFT", 18, -142)
    frame.progress:SetSize(312, 16)
    frame.progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    frame.progress:SetStatusBarColor(0.32, 0.78, 0.53)
    frame.progress:SetMinMaxValues(0, 1)
    local background = frame.progress:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.15, 0.18, 0.20, 1)
    frame.progressText = label(frame, "", 18, -167, "GameFontHighlight")

    label(frame, "Session steps (manual)", 18, -198)
    frame.steps = input(frame, 24, -219)
    frame.update = button(frame, "Update total", 190, -219, 140, function()
        actions.steps(tonumber(frame.steps:GetText()))
    end)
    frame.steps:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        actions.steps(tonumber(self:GetText()))
    end)
    frame.finish = button(frame, "Finish quest", 18, -257, 130, function()
        actions.finish()
    end)
    frame.summary = label(frame, "", 18, -299, "GameFontHighlightSmall")
    frame.summary:SetWidth(312)
    frame.summary:SetJustifyH("LEFT")
    label(frame, "Manual progress only. No leaderboard credit.", 18, -338, "GameFontDisableSmall")

    function frame:Refresh()
        local active = state.active
        self.goal:SetText(tostring(state.goal))
        self.steps:SetText(tostring(active and active.steps or 0))
        self.progress:SetValue(ns.Quest.Progress(state))
        self.goal:SetEnabled(not active)
        self.start:SetEnabled(not active)
        self.steps:SetEnabled(active ~= nil)
        self.update:SetEnabled(active ~= nil)
        self.finish:SetEnabled(active ~= nil)
        if active then
            local suffix = active.steps >= active.goal and " - Goal reached!" or ""
            self.progressText:SetText(active.steps .. " / " .. active.goal .. " steps" .. suffix)
        else
            self.progressText:SetText("Set a goal for your next walking quest.")
        end
        local last = state.history[1]
        if last then
            self.summary:SetText("Last quest: " .. last.steps .. " / " .. last.goal
                .. " steps\nGoals completed: " .. state.completedQuests)
        else
            self.summary:SetText("Enter steps taken during this quest,\nnot your whole-day total.")
        end
    end

    frame:Refresh()
    frame:SetShown(not state.hidden)
    return frame
end

