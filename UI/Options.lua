local _, NS = ...

local QUALITY_FALLBACK_NAMES = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
}

local QUALITY_ORDER = { 0, 1, 2, 3, 4 }

local function GetQualityLabel(quality)
    local globalName = _G["ITEM_QUALITY" .. tostring(quality) .. "_DESC"]
    if type(globalName) == "string" and globalName ~= "" then
        return globalName
    end
    local fallbackKey = QUALITY_FALLBACK_NAMES[quality]
    if fallbackKey then
        return NS.L(fallbackKey)
    end
    return string.format("%s %s", NS.L("Quality"), tostring(quality))
end

local function BuildQualityThresholdOptions()
    local options = {}
    for _, quality in ipairs(QUALITY_ORDER) do
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or nil
        if color then
            options[#options + 1] = {
                text = GetQualityLabel(quality),
                value = quality,
                color = {
                    r = color.r or 1,
                    g = color.g or 1,
                    b = color.b or 1,
                    a = color.a or 1,
                },
            }
        end
    end
    return options
end

NS.UIData = {
    mainTitle = "Settings",
    subTabs = {
        { key = "general",  text = "General" },
        { key = "border",   text = "Borders",  toggleKey = "borderSectionEnabled" },
        { key = "ilvl",     text = "iLvl",     toggleKey = "ilvlSectionEnabled" },
        { key = "icons",    text = "Icons",  toggleKey = "iconsSectionEnabled" },
        { key = "modules",  text = "Modules",  toggleKey = "modulesSectionEnabled" },
    },
    pages = {
        general = {
            { type = "header", text = "Font settings" },
            {
                type = "dropdown",
                text = "Font",
                dbKey = "generalFont",
                options = function()
                    return NS.Fonts and NS.Fonts.GetAvailableFontOptions and NS.Fonts.GetAvailableFontOptions() or {
                        { text = NS.L("Roboto Condensed Bold"), value = "Roboto Condensed Bold" },
                    }
                end,
                currentValue = function()
                    return NS.Fonts and NS.Fonts.GetSelectedFontKey and NS.Fonts.GetSelectedFontKey() or nil
                end,
            },
            {
                type = "dropdown",
                text = "Style",
                dbKey = "generalTextStyle",
                options = {
                    { text = "Disable", value = "NONE" },
                    { text = "Shadow", value = "SHADOW" },
                    { text = "Outline", value = "OUTLINE" },
                    { text = "Thick outline", value = "THICKOUTLINE" },
                },
            },

            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Stack count" },
            { type = "checkbox", text = "Enable", dbKey = "stackTextEnabled" },
            { type = "slider", text = "Size", dbKey = "stackFontSize", min = 5, max = 20, step = 1, visibleWhenKey = "stackTextEnabled" },
            { type = "slider", text = "Offset X", dbKey = "stackOffsetX", min = -20, max = 20, step = 0.5, visibleWhenKey = "stackTextEnabled" },
            { type = "slider", text = "Offset Y", dbKey = "stackOffsetY", min = -20, max = 20, step = 0.5, visibleWhenKey = "stackTextEnabled" },
            {
                type = "dropdown",
                text = "Alignment",
                dbKey = "stackJustifyH",
                visibleWhenKey = "stackTextEnabled",
                options = {
                    { text = "Left", value = "LEFT" },
                    { text = "Center", value = "CENTER" },
                    { text = "Right", value = "RIGHT" },
                },
            },
            { type = "color", text = "Text color", dbKey = "stackTextColor", visibleWhenKey = "stackTextEnabled" },

            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Minimap" },
            { type = "checkbox", text = "Hide minimap icon", dbKey = "minimap.hide" },
        },
        border = {
            { type = "header", text = "Border style" },
            { type = "spacer", size = -5 },
            {
                type = "dropdown",
                text = "Style selection",
                dbKey = "borderStyle",
                options = {
                    { text = "Style 1", value = "style1" },
                    { text = "Style 2", value = "style2" },
                    { text = "Style 3", value = "style3" },
                    { text = "Style 4", value = "style4" },
                    { text = "Style 5", value = "style5" },
                    { text = "Style 6", value = "style6" },
                    { text = "Style 7", value = "style7" },
                },
            },

            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Style settings" },
            { type = "checkbox", text = "Enable Border Glow", dbKey = "borderGlowEnabled" },
            { type = "slider", text = "Border Style Scale", dbKey = "borderStyleScale", min = 0.5, max = 1.5, step = 0.01 },

            { type = "spacer", size = -3 },
            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Hover border on mouseover" },
            { type = "checkbox", text = "Enable", dbKey = "borderHoverEnabled" },
            { type = "color", text = "Color selection", dbKey = "borderHoverColor", visibleWhenKey = "borderHoverEnabled" },

            { type = "spacer", size = -3 },
            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Additional settings" },
            {
                type = "dropdown",
                text = "Show borders from quality",
                dbKey = "borderMinQuality",
                options = BuildQualityThresholdOptions,
            },
        },
        ilvl = {
            { type = "header", text = "iLvl settings" },
            { type = "slider", text = "Font size", dbKey = "ilvlFontSize", min = 5, max = 20, step = 1 },
            { type = "slider", text = "Offset X", dbKey = "ilvlOffsetX", min = -20, max = 20, step = 0.5 },
            { type = "slider", text = "Offset Y", dbKey = "ilvlOffsetY", min = -20, max = 20, step = 0.5 },
            {
                type = "dropdown",
                text = "Show iLvl from quality",
                dbKey = "ilvlMinQuality",
                options = BuildQualityThresholdOptions,
            },
            { type = "checkbox", text = "Use item quality color", dbKey = "ilvlUseQualityColor" },
            {
                type = "color",
                text = "Text color",
                dbKey = "ilvlTextColor",
                visibleWhen = function(context)
                    return NS.GetConfig("ilvlUseQualityColor", true, context or "Global") == false
                end,
            },
        },
        icons = {
            { type = "header", text = "Junk icon" },
            { type = "checkbox", text = "Enable", dbKey = "junkIconEnabled" },
            { type = "slider", text = "Size", dbKey = "junkIconSize", min = 5, max = 30, step = 1, visibleWhenKey = "junkIconEnabled" },
            { type = "slider", text = "Offset X", dbKey = "junkIconOffsetX", min = -20, max = 20, step = 0.5, visibleWhenKey = "junkIconEnabled" },
            { type = "slider", text = "Offset Y", dbKey = "junkIconOffsetY", min = -20, max = 20, step = 0.5, visibleWhenKey = "junkIconEnabled" },

            { type = "spacer", size = -3 },
            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Equipment upgrade icon" },
            { type = "checkbox", text = "Enable", dbKey = "upgradeIconEnabled" },
            { type = "slider", text = "Size", dbKey = "upgradeIconSize", min = 5, max = 30, step = 1, visibleWhenKey = "upgradeIconEnabled" },
            { type = "slider", text = "Offset X", dbKey = "upgradeIconOffsetX", min = -20, max = 20, step = 0.5, visibleWhenKey = "upgradeIconEnabled" },
            { type = "slider", text = "Offset Y", dbKey = "upgradeIconOffsetY", min = -20, max = 20, step = 0.5, visibleWhenKey = "upgradeIconEnabled" },

            { type = "spacer", size = -3 },
            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Uncollected transmog icon" },
            { type = "checkbox", text = "Enable", dbKey = "transmogIconEnabled" },
            { type = "slider", text = "Size", dbKey = "transmogIconSize", min = 5, max = 30, step = 1, visibleWhenKey = "transmogIconEnabled" },
            { type = "slider", text = "Offset X", dbKey = "transmogIconOffsetX", min = -20, max = 20, step = 0.5, visibleWhenKey = "transmogIconEnabled" },
            { type = "slider", text = "Offset Y", dbKey = "transmogIconOffsetY", min = -20, max = 20, step = 0.5, visibleWhenKey = "transmogIconEnabled" },

            { type = "spacer", size = -3 },
            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Quest item icon" },
            { type = "checkbox", text = "Enable", dbKey = "questIconEnabled" },
            { type = "slider", text = "Size", dbKey = "questIconSize", min = 5, max = 30, step = 1, visibleWhenKey = "questIconEnabled" },
            { type = "slider", text = "Offset X", dbKey = "questIconOffsetX", min = -20, max = 20, step = 0.5, visibleWhenKey = "questIconEnabled" },
            { type = "slider", text = "Offset Y", dbKey = "questIconOffsetY", min = -20, max = 20, step = 0.5, visibleWhenKey = "questIconEnabled" },

            { type = "spacer", size = -3 },
            { type = "separator" },
            { type = "spacer", size = -8 },

            { type = "header", text = "Missing enchant icon" },
            { type = "checkbox", text = "Enable", dbKey = "enchantIconEnabled" },
            { type = "checkbox", text = "Only Character Frame and Inspect", dbKey = "enchantIconCharacterInspectOnly", visibleWhenKey = "enchantIconEnabled" },
            { type = "slider", text = "Size", dbKey = "enchantIconSize", min = 5, max = 30, step = 1, visibleWhenKey = "enchantIconEnabled" },
            { type = "slider", text = "Offset X", dbKey = "enchantIconOffsetX", min = -20, max = 20, step = 0.5, visibleWhenKey = "enchantIconEnabled" },
            { type = "slider", text = "Offset Y", dbKey = "enchantIconOffsetY", min = -20, max = 20, step = 0.5, visibleWhenKey = "enchantIconEnabled" },
        },
        modules = {
            { type = "header", text = "* Modules in red are experimental", textColor = { 1, 0.25, 0.25, 1 } },
            { type = "checkbox", text = "Character window", dbKey = "characterFrameEnabled" },
            { type = "checkbox", text = "Bags", dbKey = "bagsEnabled" },
            { type = "checkbox", text = "Character bank", dbKey = "characterBankEnabled" },
            { type = "checkbox", text = "Warband bank", dbKey = "warbandBankEnabled" },
            { type = "checkbox", text = "Inspect", dbKey = "inspectEnabled" },
            { type = "checkbox", text = "Mail", dbKey = "mailEnabled" },
            { type = "checkbox", text = "Trade", dbKey = "tradeEnabled" },
            { type = "checkbox", text = "Merchant", dbKey = "merchantEnabled" },
            { type = "checkbox", text = "Guild bank", dbKey = "guildBankEnabled" },
            { type = "checkbox", text = "Loot", dbKey = "lootEnabled" },
            { type = "checkbox", text = "Quests", dbKey = "questsEnabled", textColor = { 1, 0.25, 0.25, 1 } },
            { type = "checkbox", text = "Profession journal", dbKey = "professionJournalEnabled", textColor = { 1, 0.25, 0.25, 1 } },
            { type = "checkbox", text = "Crafting orders", dbKey = "craftingOrdersEnabled", textColor = { 1, 0.25, 0.25, 1 } },
        },
    },
}
