local _, NS = ...

NS.Fonts = NS.Fonts or {}

local Fonts = NS.Fonts
local CUSTOM_FONT_KEY = "Roboto Condensed Bold"
local CUSTOM_FONT_PATH = "Interface\\AddOns\\BlizzItemGlowFix\\Fonts\\RobotoCondensed-Bold.ttf"

local customFontRegistered = false
local fallbackFonts = {
    { text = CUSTOM_FONT_KEY, value = CUSTOM_FONT_KEY },
}

local function GetLocaleDefaultFontPath()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "ruRU" then
        return "Fonts\\FRIZQT___CYR.TTF"
    elseif locale == "koKR" then
        return "Fonts\\2002.TTF"
    elseif locale == "zhCN" then
        return "Fonts\\ARKai_T.ttf"
    elseif locale == "zhTW" then
        return "Fonts\\bLEI00D.ttf"
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetLSM()
    if not LibStub or type(LibStub.GetLibrary) ~= "function" then
        return nil
    end
    return LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

local function GetAllLocaleMask(media)
    if not media then
        return nil
    end

    return (media.LOCALE_BIT_western or 0)
        + (media.LOCALE_BIT_ruRU or 0)
        + (media.LOCALE_BIT_koKR or 0)
        + (media.LOCALE_BIT_zhCN or 0)
        + (media.LOCALE_BIT_zhTW or 0)
end

function Fonts.GetDefaultFontKey()
    local media = GetLSM()
    if media and type(media.GetDefault) == "function" then
        return media:GetDefault(media.MediaType.FONT)
    end
    return nil
end



function Fonts.RegisterCustomFont()
    if customFontRegistered then
        return true
    end

    local media = GetLSM()
    if not media or type(media.Register) ~= "function" then
        return false
    end

    local localeMask = GetAllLocaleMask(media)
    media:Register(media.MediaType.FONT, CUSTOM_FONT_KEY, CUSTOM_FONT_PATH, localeMask)
    customFontRegistered = true
    return true
end

local function BuildFontOptionsFromLSM(media)
    local list = media and media:List(media.MediaType.FONT)
    if type(list) ~= "table" then
        return nil
    end

    local options = {}
    local seen = {}

    for index = 1, #list do
        local name = list[index]
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            options[#options + 1] = {
                text = name,
                value = name,
            }
        end
    end

    if not seen[CUSTOM_FONT_KEY] then
        table.insert(options, 1, {
            text = CUSTOM_FONT_KEY,
            value = CUSTOM_FONT_KEY,
        })
    end

    return options
end

function Fonts.GetAvailableFontOptions()
    Fonts.RegisterCustomFont()

    local media = GetLSM()
    local options = BuildFontOptionsFromLSM(media)
    if type(options) == "table" and #options > 0 then
        return options
    end

    return fallbackFonts
end

function Fonts.IsValidFontKey(fontKey)
    if type(fontKey) ~= "string" or fontKey == "" then
        return false
    end

    if fontKey == CUSTOM_FONT_KEY then
        return true
    end

    local media = GetLSM()
    return media and media:IsValid(media.MediaType.FONT, fontKey) or false
end

function Fonts.GetSelectedFontKey()
    local fontKey = NS.GetConfig("generalFont", nil, "Global")
    if Fonts.IsValidFontKey(fontKey) then
        return fontKey
    end

    local defaultKey = Fonts.GetDefaultFontKey()
    if Fonts.IsValidFontKey(defaultKey) then
        return defaultKey
    end

    return nil
end

function Fonts.GetFontPath(fontKey)
    if fontKey == nil or fontKey == "" then
        return GetLocaleDefaultFontPath()
    end

    local media = GetLSM()
    if media and type(media.Fetch) == "function" then
        local path = media:Fetch(media.MediaType.FONT, fontKey, true)
        if type(path) == "string" and path ~= "" then
            return path
        end
    end

    if fontKey == CUSTOM_FONT_KEY then
        return CUSTOM_FONT_PATH
    end

    return GetLocaleDefaultFontPath()
end

function Fonts.GetSelectedFontPath()
    return Fonts.GetFontPath(Fonts.GetSelectedFontKey())
end

function Fonts.ApplyToFontString(fontString, size, flags, fontKey)
    if not fontString or type(fontString.SetFont) ~= "function" then
        return false
    end

    local _, currentSize, currentFlags = fontString:GetFont()
    local resolvedSize = tonumber(size) or tonumber(currentSize) or 12
    local resolvedFlags = flags
    if resolvedFlags == nil then
        resolvedFlags = currentFlags
    end

    local path = Fonts.GetFontPath(fontKey or Fonts.GetSelectedFontKey())
    if type(path) ~= "string" or path == "" then
        return false
    end

    fontString:SetFont(path, resolvedSize, resolvedFlags)
    return true
end

Fonts.RegisterCustomFont()
