local _, NS = ...

NS.RuntimeConfig = NS.RuntimeConfig or {}
local RuntimeConfig = NS.RuntimeConfig

local styleMap = {
    style1 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style1_Border.tga",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style1_Glow.tga",
        borderScale = 1.9,
        glowScale = 1.95,
    },
    style2 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style2_Border.tga",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style2_Glow.tga",
        borderScale = 1.85,
        glowScale = 1.9,
    },
    style3 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style3_Border.png",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style3_Glow.png",
        borderScale = 3.2,
        glowScale = 3.2,
    },
    style4 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style4_Border.png",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style4_Glow.png",
        borderScale = 1.75,
        glowScale = 1.75,
    },
    style5 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style5_Border.png",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style5_Glow.png",
        borderScale = 1.95,
        glowScale = 1.95,
    },
    style6 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style6_Border.png",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style6_Glow.png",
        borderScale = 1.85,
        glowScale = 1.85,
    },
    style7 = {
        borderTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style7_Border.png",
        glowTexture = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\Style7_Glow.png",
        borderScale = 1.6,
        glowScale = 1.6,
    },
}

RuntimeConfig._version = RuntimeConfig._version or 0
RuntimeConfig._snapshot = RuntimeConfig._snapshot or nil
RuntimeConfig._snapshotVersion = RuntimeConfig._snapshotVersion or -1

function RuntimeConfig.Invalidate()
    RuntimeConfig._version = (RuntimeConfig._version or 0) + 1
end

function RuntimeConfig.GetVersion()
    return RuntimeConfig._version or 0
end

function RuntimeConfig.GetStyle(styleKey)
    return styleMap[styleKey] or styleMap.style7
end

function RuntimeConfig.BuildSnapshot()
    local fontKey = NS.Fonts and NS.Fonts.GetSelectedFontKey and NS.Fonts.GetSelectedFontKey() or nil
    local fontPath = NS.Fonts and NS.Fonts.GetSelectedFontPath and NS.Fonts.GetSelectedFontPath() or "Fonts\\FRIZQT__.TTF"
    local textFlags = NS.GetConfig("generalTextStyle", "OUTLINE", "Global")
    local styleKey = NS.GetConfig("borderStyle", "style7", "Global")
    local style = RuntimeConfig.GetStyle(styleKey)
    local borderHoverR, borderHoverG, borderHoverB, borderHoverA = NS.GetConfigColor("borderHoverColor", 1, 0.84, 0, 1, "Global")
    local ilvlTextR, ilvlTextG, ilvlTextB, ilvlTextA = NS.GetConfigColor("ilvlTextColor", 0.95, 0.95, 0.95, 1, "Global")
    local stackTextR, stackTextG, stackTextB, stackTextA = NS.GetConfigColor("stackTextColor", 1, 1, 1, 1, "Global")

    return {
        bagsEnabled = NS.GetConfig("bagsEnabled", true, "Global") ~= false,
        characterFrameEnabled = NS.GetConfig("characterFrameEnabled", true, "Global") ~= false,
        inspectEnabled = NS.GetConfig("inspectEnabled", true, "Global") ~= false,
        characterBankEnabled = NS.GetConfig("characterBankEnabled", true, "Global") ~= false,
        warbandBankEnabled = NS.GetConfig("warbandBankEnabled", true, "Global") ~= false,
        guildBankEnabled = NS.GetConfig("guildBankEnabled", true, "Global") ~= false,
        merchantEnabled = NS.GetConfig("merchantEnabled", true, "Global") ~= false,
        mailEnabled = NS.GetConfig("mailEnabled", true, "Global") ~= false,
        tradeEnabled = NS.GetConfig("tradeEnabled", true, "Global") ~= false,
        lootEnabled = NS.GetConfig("lootEnabled", true, "Global") ~= false,
        questsEnabled = NS.GetConfig("questsEnabled", true, "Global") ~= false,
        professionJournalEnabled = NS.GetConfig("professionJournalEnabled", true, "Global") ~= false,
        craftingOrdersEnabled = NS.GetConfig("craftingOrdersEnabled", true, "Global") ~= false,

        borderSectionEnabled = NS.GetConfig("borderSectionEnabled", true, "Global") ~= false,
        borderStyle = styleKey,
        borderStyleData = style,
        borderStyleScale = NS.GetConfigClamped("borderStyleScale", 1, 0.5, 1.5, "Global"),
        borderGlowEnabled = NS.GetConfig("borderGlowEnabled", false, "Global") == true,
        borderHoverEnabled = NS.GetConfig("borderHoverEnabled", true, "Global") ~= false,
        borderMinQuality = tonumber(NS.GetConfig("borderMinQuality", 0, "Global")) or 0,
        borderHoverColor = {
            r = borderHoverR,
            g = borderHoverG,
            b = borderHoverB,
            a = borderHoverA,
        },

        ilvlSectionEnabled = NS.GetConfig("ilvlSectionEnabled", true, "Global") ~= false,
        ilvlFontSize = NS.GetConfigClamped("ilvlFontSize", 14, 6, 32, "Global"),
        ilvlOffsetX = tonumber(NS.GetConfig("ilvlOffsetX", 1, "Global")) or 1,
        ilvlOffsetY = tonumber(NS.GetConfig("ilvlOffsetY", -10, "Global")) or -10,
        ilvlUseQualityColor = NS.GetConfig("ilvlUseQualityColor", true, "Global") ~= false,
        ilvlMinQuality = tonumber(NS.GetConfig("ilvlMinQuality", 2, "Global")) or 2,
        ilvlTextColor = {
            r = ilvlTextR,
            g = ilvlTextG,
            b = ilvlTextB,
            a = ilvlTextA,
        },

        stackTextEnabled = NS.GetConfig("stackTextEnabled", true, "Global") ~= false,
        stackFontSize = NS.GetConfigClamped("stackFontSize", 12, 6, 32, "Global"),
        stackOffsetX = tonumber(NS.GetConfig("stackOffsetX", 1, "Global")) or 1,
        stackOffsetY = tonumber(NS.GetConfig("stackOffsetY", 0, "Global")) or 0,
        stackJustifyH = NS.GetConfig("stackJustifyH", "CENTER", "Global") or "CENTER",
        stackTextColor = {
            r = stackTextR,
            g = stackTextG,
            b = stackTextB,
            a = stackTextA,
        },

        iconsSectionEnabled = NS.GetConfig("iconsSectionEnabled", true, "Global") ~= false,
        junkIconEnabled = NS.GetConfig("junkIconEnabled", false, "Global") == true,
        junkIconSize = NS.GetConfigClamped("junkIconSize", 14, 8, 32, "Global"),
        junkIconOffsetX = tonumber(NS.GetConfig("junkIconOffsetX", -10, "Global")) or -10,
        junkIconOffsetY = tonumber(NS.GetConfig("junkIconOffsetY", 10, "Global")) or 10,
        upgradeIconEnabled = NS.GetConfig("upgradeIconEnabled", true, "Global") == true,
        upgradeIconSize = NS.GetConfigClamped("upgradeIconSize", 15, 8, 32, "Global"),
        upgradeIconOffsetX = tonumber(NS.GetConfig("upgradeIconOffsetX", -11, "Global")) or -11,
        upgradeIconOffsetY = tonumber(NS.GetConfig("upgradeIconOffsetY", 10, "Global")) or 10,
        transmogIconEnabled = NS.GetConfig("transmogIconEnabled", true, "Global") == true,
        transmogIconSize = NS.GetConfigClamped("transmogIconSize", 15, 8, 32, "Global"),
        transmogIconOffsetX = tonumber(NS.GetConfig("transmogIconOffsetX", 0, "Global")) or 0,
        transmogIconOffsetY = tonumber(NS.GetConfig("transmogIconOffsetY", 10, "Global")) or 10,
        questIconEnabled = NS.GetConfig("questIconEnabled", true, "Global") == true,
        questIconSize = NS.GetConfigClamped("questIconSize", 30, 8, 32, "Global"),
        questIconOffsetX = tonumber(NS.GetConfig("questIconOffsetX", -9.5, "Global")) or -9.5,
        questIconOffsetY = tonumber(NS.GetConfig("questIconOffsetY", 0, "Global")) or 0,
        enchantIconEnabled = NS.GetConfig("enchantIconEnabled", true, "Global") == true,
        enchantIconCharacterInspectOnly = NS.GetConfig("enchantIconCharacterInspectOnly", true, "Global") == true,
        enchantIconSize = NS.GetConfigClamped("enchantIconSize", 10, 8, 32, "Global"),
        enchantIconOffsetX = tonumber(NS.GetConfig("enchantIconOffsetX", 10.5, "Global")) or 10.5,
        enchantIconOffsetY = tonumber(NS.GetConfig("enchantIconOffsetY", 10.5, "Global")) or 10.5,

        fontKey = fontKey,
        fontPath = fontPath,
        textFlags = textFlags,
        hoverState = {
            enabled = NS.GetConfig("borderSectionEnabled", true, "Global") ~= false and NS.GetConfig("borderHoverEnabled", true, "Global") ~= false,
            styleData = style,
            scale = NS.GetConfigClamped("borderStyleScale", 1, 0.5, 1.5, "Global"),
            color = {
                r = borderHoverR,
                g = borderHoverG,
                b = borderHoverB,
                a = borderHoverA,
            },
        },
    }
end

function RuntimeConfig.GetSnapshot()
    local version = RuntimeConfig.GetVersion()
    if RuntimeConfig._snapshot and RuntimeConfig._snapshotVersion == version then
        return RuntimeConfig._snapshot
    end

    RuntimeConfig._snapshot = RuntimeConfig.BuildSnapshot()
    RuntimeConfig._snapshotVersion = version
    return RuntimeConfig._snapshot
end
