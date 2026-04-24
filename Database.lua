local _, NS = ...
NS.DB = NS.DB or {}

local function CopyValue(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do
        out[k] = CopyValue(v)
    end
    return out
end

local function MergeDefaults(dst, defaults)
    if type(defaults) ~= "table" then return dst end
    if type(dst) ~= "table" then dst = {} end

    for k, v in pairs(defaults) do
        if type(v) == "table" then
            dst[k] = MergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

NS.DB.globalDefaults = {
    uiSelectedSubTab = 1,

    characterFrameEnabled = true,
    bagsEnabled = true,
    characterBankEnabled = true,
    warbandBankEnabled = true,
    inspectEnabled = true,
    mailEnabled = true,
    tradeEnabled = true,
    merchantEnabled = true,
    guildBankEnabled = true,
    lootEnabled = true,
    questsEnabled = true,
    professionJournalEnabled = true,
    craftingOrdersEnabled = true,
    borderSectionEnabled = true,
    ilvlSectionEnabled = true,
    iconsSectionEnabled = true,
    modulesSectionEnabled = true,

    minimap = {
        hide = false,
        minimapPos = 220,
    },

    generalFont = "Roboto Condensed Bold",
    generalTextStyle = "OUTLINE",
    stackTextEnabled = true,
    stackFontSize = 12,
    stackOffsetX = 1,
    stackOffsetY = 0,
    stackJustifyH = "CENTER",
    stackTextColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },

    ilvlFontSize = 14,
    ilvlOffsetX = 1,
    ilvlOffsetY = -10,
    ilvlUseQualityColor = true,
    ilvlMinQuality = 2,
    ilvlTextColor = {
        r = 0.95,
        g = 0.95,
        b = 0.95,
        a = 1,
    },

    borderStyle = "style7",
    borderStyleScale = 1,
    borderGlowEnabled = false,
    borderHoverEnabled = true,
    borderHoverColor = {
        r = 1,
        g = 0.84,
        b = 0,
        a = 1,
    },
    borderMinQuality = 0,

    junkIconEnabled = false,
    junkIconSize = 14,
    junkIconOffsetX = -10,
    junkIconOffsetY = 10,

    upgradeIconEnabled = true,
    upgradeIconSize = 15,
    upgradeIconOffsetX = -11,
    upgradeIconOffsetY = 10,

    transmogIconEnabled = true,
    transmogIconSize = 15,
    transmogIconOffsetX = 0,
    transmogIconOffsetY = 10,

    questIconEnabled = true,
    questIconSize = 22,
    questIconOffsetX = -9,
    questIconOffsetY = 0,

    enchantIconEnabled = true,
    enchantIconSize = 10,
    enchantIconOffsetX = 10.5,
    enchantIconOffsetY = 10.5,
    enchantIconCharacterInspectOnly = true,
}

NS.DB.defaults = {
    Global = NS.DB.globalDefaults,
}

local isInitializedThisSession = false

function NS.DB.GetRoot()
    if type(BlizzItemGlowFixDB) == "table" then
        BlizzItemGlowFixDB.Global = MergeDefaults(BlizzItemGlowFixDB.Global, CopyValue(NS.DB.globalDefaults))
        return BlizzItemGlowFixDB
    end

    return NS.DB.Init()
end

function NS.DB.Init()
    if isInitializedThisSession and type(BlizzItemGlowFixDB) == "table" and type(BlizzItemGlowFixDB.Global) == "table" then
        return BlizzItemGlowFixDB
    end

    BlizzItemGlowFixDB = BlizzItemGlowFixDB or {}
    BlizzItemGlowFixDB.Global = MergeDefaults(BlizzItemGlowFixDB.Global, CopyValue(NS.DB.globalDefaults))

    isInitializedThisSession = true
    return BlizzItemGlowFixDB
end

NS.InitializeDB = NS.DB.Init
