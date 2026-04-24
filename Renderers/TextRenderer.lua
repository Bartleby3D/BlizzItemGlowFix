local _, NS = ...

NS.TextRenderer = NS.TextRenderer or {}
local TextRenderer = NS.TextRenderer

local stateByButton = setmetatable({}, { __mode = "k" })

local DEFAULT_ITEM_ICON_SIZE = 37

local COUNT_FIELD_CANDIDATES = {
    "Count",
    "CountText",
    "StackCount",
    "stackCount",
    "ItemCount",
    "itemCount",
}

local NESTED_COUNT_CANDIDATES = {
    { "NameFrame", "Count" },
    { "ItemButton", "Count" },
    { "Item", "Count" },
}

local function IsObjectType(object, objectType)
    local valueType = type(object)
    if valueType ~= "table" and valueType ~= "userdata" then
        return false
    end

    if type(object.GetObjectType) ~= "function" then
        return false
    end

    return object:GetObjectType() == objectType
end

local function GetState(button)
    local state = stateByButton[button]
    if state then
        return state
    end

    state = {}
    stateByButton[button] = state
    return state
end

local function GetRenderRegion(button)
    local region = button and button.__BlizzItemGlowFixRenderRegion or nil
    if region and region.GetWidth and region.GetHeight then
        return region
    end
    return button
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetTargetScale(button)
    local renderRegion = GetRenderRegion(button)
    if not button or not renderRegion or renderRegion == button then
        return 1
    end

    local width = renderRegion.GetWidth and renderRegion:GetWidth() or 0
    local height = renderRegion.GetHeight and renderRegion:GetHeight() or 0
    local side = math.min(tonumber(width) or 0, tonumber(height) or 0)
    if side <= 0 or side >= DEFAULT_ITEM_ICON_SIZE then
        return 1
    end

    return Clamp(side / DEFAULT_ITEM_ICON_SIZE, 0.5, 1)
end

local function GetNamedChildFontString(button, suffix)
    if not button or type(suffix) ~= "string" or suffix == "" then
        return nil
    end

    if type(button.GetName) ~= "function" then
        return nil
    end

    local name = button:GetName()
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local region = _G[name .. suffix]
    if IsObjectType(region, "FontString") then
        return region
    end

    return nil
end

local function GetCountText(button)
    if not button then
        return nil
    end

    for index = 1, #COUNT_FIELD_CANDIDATES do
        local region = button[COUNT_FIELD_CANDIDATES[index]]
        if IsObjectType(region, "FontString") then
            return region
        end
    end

    for index = 1, #COUNT_FIELD_CANDIDATES do
        local region = GetNamedChildFontString(button, COUNT_FIELD_CANDIDATES[index])
        if region then
            return region
        end
    end

    for index = 1, #NESTED_COUNT_CANDIDATES do
        local chain = NESTED_COUNT_CANDIDATES[index]
        local parent = button[chain[1]]
        local region = parent and parent[chain[2]] or nil
        if IsObjectType(region, "FontString") then
            return region
        end
    end

    return nil
end

local function EnsureCountState(button, fontString)
    if not button or not fontString then
        return nil
    end

    local state = GetState(button)
    state.countText = fontString

    if state.originalCountCaptured then
        return state
    end

    if type(fontString.GetFont) == "function" then
        local path, size, flags = fontString:GetFont()
        state.originalCountFontPath = path
        state.originalCountFontSize = size
        state.originalCountFontFlags = flags
    end

    if type(fontString.GetTextColor) == "function" then
        local r, g, b, a = fontString:GetTextColor()
        state.originalCountColor = {
            r = r or 1,
            g = g or 1,
            b = b or 1,
            a = a or 1,
        }
    end

    if type(fontString.GetPoint) == "function" then
        local point, relativeTo, relativePoint, xOfs, yOfs = fontString:GetPoint(1)
        state.originalCountPoint = point
        state.originalCountRelativeTo = relativeTo
        state.originalCountRelativePoint = relativePoint
        state.originalCountOffsetX = xOfs or 0
        state.originalCountOffsetY = yOfs or 0
    end

    if type(fontString.GetJustifyH) == "function" then
        state.originalCountJustifyH = fontString:GetJustifyH()
    end
    if type(fontString.GetJustifyV) == "function" then
        state.originalCountJustifyV = fontString:GetJustifyV()
    end

    if type(fontString.GetShadowOffset) == "function" then
        local shadowX, shadowY = fontString:GetShadowOffset()
        state.originalCountShadowOffsetX = shadowX or 0
        state.originalCountShadowOffsetY = shadowY or 0
    end
    if type(fontString.GetShadowColor) == "function" then
        local shadowR, shadowG, shadowB, shadowA = fontString:GetShadowColor()
        state.originalCountShadowColor = {
            r = shadowR or 0,
            g = shadowG or 0,
            b = shadowB or 0,
            a = shadowA or 1,
        }
    end

    state.originalCountCaptured = true
    return state
end

local function EnsureItemLevelFont(button)
    local state = GetState(button)
    if state.itemLevelFont then
        return state.itemLevelFont
    end

    local fontString = button:CreateFontString(nil, "OVERLAY")
    fontString:SetDrawLayer("OVERLAY", 7)
    state.itemLevelFont = fontString
    return fontString
end

local function NormalizeTextStyle(style)
    if style == "NONE" or style == "SHADOW" or style == "OUTLINE" or style == "THICKOUTLINE" then
        return style
    end
    return "OUTLINE"
end

local function ApplyTextStyle(fontString, style)
    if not fontString then
        return ""
    end

    style = NormalizeTextStyle(style)

    if style == "SHADOW" then
        if type(fontString.SetShadowOffset) == "function" then
            fontString:SetShadowOffset(1, -1)
        end
        if type(fontString.SetShadowColor) == "function" then
            fontString:SetShadowColor(0, 0, 0, 1)
        end
        return ""
    end

    if type(fontString.SetShadowOffset) == "function" then
        fontString:SetShadowOffset(0, 0)
    end
    if type(fontString.SetShadowColor) == "function" then
        fontString:SetShadowColor(0, 0, 0, 0)
    end

    if style == "OUTLINE" then
        return "OUTLINE"
    elseif style == "THICKOUTLINE" then
        return "THICKOUTLINE"
    end

    return ""
end

local function ApplyFont(fontString, fontPath, size, style)
    if not fontString then
        return
    end

    local fontFlags = ApplyTextStyle(fontString, style)

    if NS.Fonts and NS.Fonts.ApplyToFontString then
        NS.Fonts.ApplyToFontString(fontString, size, fontFlags)
        return
    end

    fontString:SetFont(fontPath, size, fontFlags)
end

local function RestoreCountText(button)
    local state = stateByButton[button]
    if not state or not state.originalCountCaptured then
        return
    end

    local fontString = state.countText or GetCountText(button)
    if not fontString then
        return
    end

    if type(fontString.SetFont) == "function" and state.originalCountFontPath then
        fontString:SetFont(state.originalCountFontPath, state.originalCountFontSize or 12, state.originalCountFontFlags)
    end

    if type(fontString.SetTextColor) == "function" and type(state.originalCountColor) == "table" then
        local color = state.originalCountColor
        fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end

    if type(fontString.SetShadowOffset) == "function" then
        fontString:SetShadowOffset(state.originalCountShadowOffsetX or 0, state.originalCountShadowOffsetY or 0)
    end
    if type(fontString.SetShadowColor) == "function" and type(state.originalCountShadowColor) == "table" then
        local shadowColor = state.originalCountShadowColor
        fontString:SetShadowColor(shadowColor.r or 0, shadowColor.g or 0, shadowColor.b or 0, shadowColor.a or 1)
    end

    if type(fontString.ClearAllPoints) == "function" and state.originalCountPoint then
        fontString:ClearAllPoints()
        fontString:SetPoint(
            state.originalCountPoint,
            state.originalCountRelativeTo,
            state.originalCountRelativePoint,
            state.originalCountOffsetX or 0,
            state.originalCountOffsetY or 0
        )
    end

    if type(fontString.SetJustifyH) == "function" and state.originalCountJustifyH then
        fontString:SetJustifyH(state.originalCountJustifyH)
    end
    if type(fontString.SetJustifyV) == "function" and state.originalCountJustifyV then
        fontString:SetJustifyV(state.originalCountJustifyV)
    end
end

local function GetVerticalPart(point)
    if type(point) ~= "string" or point == "" then
        return "BOTTOM"
    end

    if string.find(point, "TOP", 1, true) then
        return "TOP"
    end
    if string.find(point, "BOTTOM", 1, true) then
        return "BOTTOM"
    end
    return "CENTER"
end

local function GetAnchorForJustify(originalPoint, justifyH)
    local vertical = GetVerticalPart(originalPoint)
    if justifyH == "LEFT" then
        return vertical .. "LEFT", vertical .. "LEFT"
    elseif justifyH == "CENTER" then
        return vertical, vertical
    end
    return vertical .. "RIGHT", vertical .. "RIGHT"
end

local function ApplyCountText(button, snapshot)
    local countText = GetCountText(button)
    if not countText then
        return
    end

    local state = EnsureCountState(button, countText)
    if not snapshot or not snapshot.stackTextEnabled then
        RestoreCountText(button)
        return
    end

    local justifyH = snapshot.stackJustifyH
    if justifyH ~= "LEFT" and justifyH ~= "CENTER" then
        justifyH = "RIGHT"
    end

    local anchorPoint, relativePoint = GetAnchorForJustify(state.originalCountPoint, justifyH)
    local targetScale = GetTargetScale(button)
    local baseX = state.originalCountOffsetX or 0
    local baseY = state.originalCountOffsetY or 0

    if justifyH == "LEFT" then
        baseX = math.abs(baseX)
    elseif justifyH == "CENTER" then
        baseX = 0
    end

    ApplyFont(countText, snapshot.fontPath, math.max(6, (snapshot.stackFontSize or 12) * targetScale), snapshot.textFlags)

    local color = snapshot.stackTextColor or {}
    countText:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    countText:ClearAllPoints()
    countText:SetPoint(
        anchorPoint,
        GetRenderRegion(button),
        relativePoint,
        (baseX * targetScale) + ((snapshot.stackOffsetX or 0) * targetScale),
        (baseY * targetScale) + ((snapshot.stackOffsetY or 0) * targetScale)
    )

    if type(countText.SetJustifyH) == "function" then
        countText:SetJustifyH(justifyH)
    end
    if type(countText.SetJustifyV) == "function" then
        countText:SetJustifyV(state.originalCountJustifyV or "MIDDLE")
    end
end

function TextRenderer.PrepareButton(button)
    if not button then
        return
    end

    EnsureItemLevelFont(button)

    local countText = GetCountText(button)
    if countText then
        EnsureCountState(button, countText)
    end
end

function TextRenderer.Hide(button)
    if not button then
        return
    end

    RestoreCountText(button)

    local state = stateByButton[button]
    if state and state.itemLevelFont then
        state.itemLevelFont:Hide()
    end
end

function TextRenderer.Apply(button, textState, snapshot)
    if not button then
        return
    end

    ApplyCountText(button, snapshot)

    local itemLevelText = EnsureItemLevelFont(button)
    if not textState or not textState.itemLevel then
        itemLevelText:Hide()
        return
    end

    local targetScale = GetTargetScale(button)
    ApplyFont(itemLevelText, snapshot.fontPath, math.max(6, (snapshot.ilvlFontSize or 12) * targetScale), snapshot.textFlags)
    local renderRegion = GetRenderRegion(button)
    itemLevelText:ClearAllPoints()
    itemLevelText:SetPoint("CENTER", renderRegion, "CENTER", (snapshot.ilvlOffsetX or 0) * targetScale, (snapshot.ilvlOffsetY or 0) * targetScale)

    if textState.useQualityColor and textState.quality ~= nil and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[textState.quality] then
        local color = ITEM_QUALITY_COLORS[textState.quality]
        itemLevelText:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)
    else
        local color = snapshot.ilvlTextColor or {}
        itemLevelText:SetTextColor(color.r or 0.95, color.g or 0.95, color.b or 0.95, color.a or 1)
    end

    itemLevelText:SetText(textState.itemLevel)
    itemLevelText:Show()
end
