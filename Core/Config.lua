local _, NS = ...

NS.Config = NS.Config or {}

NS.Config.callbacks = NS.Config.callbacks or {}

function NS.Config.RegisterCallback(callback)
    if type(callback) ~= "function" then return end
    table.insert(NS.Config.callbacks, callback)
end

local function NotifyCallbacks(key, value, context)
    for _, callback in ipairs(NS.Config.callbacks) do
        NS.Call("Config callback (" .. tostring(key) .. ")", callback, key, value, context)
    end
end

local function EnsureRoot()
    if NS.DB and NS.DB.GetRoot then
        return NS.DB.GetRoot()
    end

    if NS.DB and NS.DB.Init and BlizzItemGlowFixDB == nil then
        return NS.DB.Init()
    end

    BlizzItemGlowFixDB = BlizzItemGlowFixDB or {}
    BlizzItemGlowFixDB.Global = BlizzItemGlowFixDB.Global or {}
    return BlizzItemGlowFixDB
end

function NS.Config.EnsureDB()
    return EnsureRoot()
end


function NS.Config.GetTable(context)
    local db = EnsureRoot()
    if not db then return nil end

    if context == nil or context == "Global" then
        db.Global = db.Global or {}
        return db.Global
    end

    local ctx = tostring(context)
    db[ctx] = db[ctx] or {}
    return db[ctx]
end

local function SplitPath(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local path = {}
    for part in string.gmatch(key, "[^%.]+") do
        path[#path + 1] = part
    end

    if #path == 0 then
        return nil
    end

    return path
end

local function GetValueByPath(rootTable, key)
    if type(rootTable) ~= "table" or key == nil then
        return nil
    end

    local path = SplitPath(key)
    if not path then
        return nil
    end

    local current = rootTable
    for i = 1, #path do
        if type(current) ~= "table" then
            return nil
        end
        current = current[path[i]]
        if current == nil then
            return nil
        end
    end

    return current
end

local function SetValueByPath(rootTable, key, value)
    if type(rootTable) ~= "table" or key == nil then
        return false
    end

    local path = SplitPath(key)
    if not path then
        return false
    end

    local current = rootTable
    for i = 1, #path - 1 do
        local part = path[i]
        if type(current[part]) ~= "table" then
            current[part] = {}
        end
        current = current[part]
    end

    current[path[#path]] = value
    return true
end

function NS.Config.Get(key, context)
    if key == nil then return nil end
    local t = NS.Config.GetTable(context)
    if not t then return nil end
    return GetValueByPath(t, key)
end

function NS.Config.Set(key, value, context)
    if key == nil then return end
    local t = NS.Config.GetTable(context)
    if not t then return end
    if SetValueByPath(t, key, value) then
        NotifyCallbacks(key, value, context)
    end
end

function NS.Config.GetColor(key, context)
    local value = NS.Config.Get(key, context)
    if type(value) ~= "table" then
        return 1, 1, 1, 1
    end
    return value.r or 1, value.g or 1, value.b or 1, value.a or 1
end

function NS.Config.SetColor(key, r, g, b, a, context)
    if key == nil then return end
    NS.Config.Set(key, {
        r = r,
        g = g,
        b = b,
        a = a or 1,
    }, context)
end
