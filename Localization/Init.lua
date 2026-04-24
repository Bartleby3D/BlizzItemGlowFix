local _, NS = ...

NS._locales = NS._locales or {}
NS._activeLocale = (GetLocale and GetLocale()) or "enUS"

function NS.AddLocale(locale, tbl)
    if type(locale) ~= "string" or type(tbl) ~= "table" then return end
    NS._locales[locale] = tbl
end

function NS.L(key)
    if key == nil then return "" end
    if type(key) ~= "string" then return tostring(key) end

    local active = NS._locales[NS._activeLocale]
    if active and active[key] ~= nil then
        return active[key]
    end

    local en = NS._locales["enUS"]
    if en and en[key] ~= nil then
        return en[key]
    end

    return key
end
