local _, NS = ...

NS.AssetWarmup = NS.AssetWarmup or {}
local Warmup = NS.AssetWarmup

local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()
local hiddenTextures = {}
local hiddenFontString = hiddenFrame:CreateFontString(nil, "OVERLAY")

local queuedButtons = setmetatable({}, { __mode = "k" })
local queueList = {}
local queueIndex = 1
local driver = CreateFrame("Frame")
driver:Hide()

local function ResolveWarmupFontFlags(style)
    if style == "OUTLINE" then
        hiddenFontString:SetShadowOffset(0, 0)
        hiddenFontString:SetShadowColor(0, 0, 0, 0)
        return "OUTLINE"
    elseif style == "THICKOUTLINE" then
        hiddenFontString:SetShadowOffset(0, 0)
        hiddenFontString:SetShadowColor(0, 0, 0, 0)
        return "THICKOUTLINE"
    elseif style == "SHADOW" then
        hiddenFontString:SetShadowOffset(1, -1)
        hiddenFontString:SetShadowColor(0, 0, 0, 1)
        return ""
    end

    hiddenFontString:SetShadowOffset(0, 0)
    hiddenFontString:SetShadowColor(0, 0, 0, 0)
    return ""
end

local function PrepareButtonNow(button)
    if not button then
        return false
    end

    if button.__BlizzItemGlowFixPrepared then
            return false
    end

    if NS.BorderRenderer and NS.BorderRenderer.PrepareButton then
        NS.BorderRenderer.PrepareButton(button)
    end
    if NS.TextRenderer and NS.TextRenderer.PrepareButton then
        NS.TextRenderer.PrepareButton(button)
    end
    if NS.IconRenderer and NS.IconRenderer.PrepareButton then
        NS.IconRenderer.PrepareButton(button)
    end

    button.__BlizzItemGlowFixPrepared = true
    return true
end

local function FlushButtonQueue()
    local processed = 0
    while queueIndex <= #queueList and processed < 16 do
        local button = queueList[queueIndex]
        queueList[queueIndex] = nil
        queueIndex = queueIndex + 1
        queuedButtons[button] = nil
        PrepareButtonNow(button)
        processed = processed + 1
    end

    if queueIndex > #queueList then
        wipe(queueList)
        queueIndex = 1
        driver:SetScript("OnUpdate", nil)
        driver:Hide()
    end
end

function Warmup.PrepareButtonNow(button)
    return PrepareButtonNow(button)
end

function Warmup.QueueButton(button)
    if not button then
        return
    end

    local buttonType = type(button)
    if buttonType ~= "table" and buttonType ~= "userdata" then
        return
    end

    if button.__BlizzItemGlowFixPrepared or queuedButtons[button] then
        return
    end

    queuedButtons[button] = true
    queueList[#queueList + 1] = button

    if not driver:IsShown() then
        driver:Show()
        driver:SetScript("OnUpdate", FlushButtonQueue)
    end
end

function Warmup.WarmupAssets()
    if not NS.RuntimeConfig or not NS.RuntimeConfig.GetSnapshot then
        return
    end

    local snapshot = NS.RuntimeConfig.GetSnapshot()
    if not snapshot then
        return
    end

    local fontFlags = ResolveWarmupFontFlags(snapshot.textFlags)
    hiddenFontString:SetFont(snapshot.fontPath or "Fonts\\FRIZQT__.TTF", snapshot.ilvlFontSize or 14, fontFlags)
    hiddenFontString:SetText("999")

    local style = snapshot.borderStyleData
    if style then
        hiddenTextures[1] = hiddenTextures[1] or hiddenFrame:CreateTexture(nil, "ARTWORK")
        hiddenTextures[2] = hiddenTextures[2] or hiddenFrame:CreateTexture(nil, "ARTWORK")
        hiddenTextures[1]:SetTexture(style.borderTexture)
        hiddenTextures[2]:SetTexture(style.glowTexture)
    end

    hiddenTextures[3] = hiddenTextures[3] or hiddenFrame:CreateTexture(nil, "ARTWORK")
    hiddenTextures[4] = hiddenTextures[4] or hiddenFrame:CreateTexture(nil, "ARTWORK")
    hiddenTextures[5] = hiddenTextures[5] or hiddenFrame:CreateTexture(nil, "ARTWORK")
    hiddenTextures[6] = hiddenTextures[6] or hiddenFrame:CreateTexture(nil, "ARTWORK")

    if hiddenTextures[3].SetAtlas then hiddenTextures[3]:SetAtlas("Front-Gold-Icon", false) end
    if hiddenTextures[4].SetAtlas then hiddenTextures[4]:SetAtlas("bags-greenarrow", false) end
    if hiddenTextures[5].SetAtlas then hiddenTextures[5]:SetAtlas("lootroll-icon-transmog", false) end
    if hiddenTextures[6].SetAtlas then hiddenTextures[6]:SetAtlas("worldquest-icon-firstaid", false) end
end
