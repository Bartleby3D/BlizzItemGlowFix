local _, NS = ...

SLASH_BLIZZITEMGLOWFIX1 = "/bigf"
SLASH_BLIZZITEMGLOWFIX2 = "/blizzitemglowfix"
SlashCmdList["BLIZZITEMGLOWFIX"] = function()
    if NS.ToggleGUI then
        NS.ToggleGUI()
    end
end
