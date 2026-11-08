-- The manual prototype is retired. Keep its SavedVariables intact, but never
-- relabel them as measured steps or load them into a live counter.
SLASH_TEAMFITTACTICS1 = "/teamfit"
SlashCmdList.TEAMFITTACTICS = function(text)
    local message
    if text:match("%S") then
        message = "Manual step entry has been removed. No step data was changed."
    else
        message = "Live step tracking isn't available yet. No step data is collected."
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff67ce94Teamfit Tactics:|r " .. message)
end
