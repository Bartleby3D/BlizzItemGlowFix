local _, NS = ...

NS.BorderRenderer = NS.BorderRenderer or {}
local BorderRenderer = NS.BorderRenderer

local overlays = setmetatable({}, { __mode = "k" })
local QUEST_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }

local function SetDefaultBorderVisible(button, visible)
    if button and button.IconBorder and button.IconBorder.SetAlpha then
        button.IconBorder:SetAlpha(visible and 1 or 0)
    end
end

local function GetRenderRegion(button)
    local region = button and button.__BlizzItemGlowFixRenderRegion or nil
    if region and region.GetWidth and region.GetHeight then
        return region
    end
    return button
end

local function ApplyScale(texture, button, scale, offsetX, offsetY)
    local region = GetRenderRegion(button)
    if region == texture then
        region = button
    end

    texture:ClearAllPoints()
    texture:SetPoint("CENTER", region, "CENTER", offsetX or 0, offsetY or 0)
    texture:SetSize((region:GetWidth() or 37) * scale, (region:GetHeight() or 37) * scale)
end

local function EnsureOverlay(button)
    local overlay = overlays[button]
    if overlay then
        return overlay
    end

    overlay = {
        isHovered = false,
        hoverAllowed = false,
    }

    overlay.border = button:CreateTexture(nil, "ARTWORK", nil, 7)
    overlay.border.__BlizzItemGlowFixOverlayTexture = true
    overlay.border:Hide()

    overlay.glow = button:CreateTexture(nil, "ARTWORK", nil, 6)
    overlay.glow.__BlizzItemGlowFixOverlayTexture = true
    overlay.glow:SetBlendMode("ADD")
    overlay.glow:Hide()

    overlay.hover = button:CreateTexture(nil, "OVERLAY", nil, 1)
    overlay.hover.__BlizzItemGlowFixOverlayTexture = true
    overlay.hover:Hide()

    if not button.__BlizzItemGlowFixHoverHooked then
        button:HookScript("OnEnter", function(self)
            local current = overlays[self]
            if current then
                current.isHovered = true
                BorderRenderer.UpdateHover(self)
            end
        end)
        button:HookScript("OnLeave", function(self)
            local current = overlays[self]
            if current then
                current.isHovered = false
                BorderRenderer.UpdateHover(self)
            end
        end)
        button:HookScript("OnHide", function(self)
            local current = overlays[self]
            if current then
                current.isHovered = false
                BorderRenderer.UpdateHover(self)
            end
        end)
        button.__BlizzItemGlowFixHoverHooked = true
    end

    overlays[button] = overlay
    return overlay
end

function BorderRenderer.PrepareButton(button)
    if button then
        EnsureOverlay(button)
    end
end

function BorderRenderer.UpdateHover(button)
    local overlay = overlays[button]
    if not overlay then
        return
    end

    if not overlay.hoverAllowed or not overlay.isHovered then
        overlay.hover:Hide()
        return
    end

    local style = overlay.hoverStyleData
    local hoverScale = overlay.hoverScale
    local color = overlay.hoverColor

    if not style or not hoverScale or not color then
        local snapshot = NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot() or nil
        if not snapshot or not snapshot.borderHoverEnabled then
            overlay.hover:Hide()
            return
        end
        style = style or snapshot.borderStyleData
        hoverScale = hoverScale or snapshot.borderStyleScale
        color = color or snapshot.borderHoverColor
    end

    if not style then
        overlay.hover:Hide()
        return
    end

    overlay.hover:SetTexture(style.borderTexture)
    overlay.hover:SetBlendMode("BLEND")
    ApplyScale(overlay.hover, button, style.borderScale * hoverScale, overlay.anchorOffsetX, overlay.anchorOffsetY)
    overlay.hover:SetVertexColor(color.r or 1, color.g or 0.84, color.b or 0, color.a or 1)
    overlay.hover:Show()
end

function BorderRenderer.ConfigureHover(button, hoverState, offsetX, offsetY)
    if not button then
        return
    end

    local overlay = EnsureOverlay(button)
    overlay.anchorOffsetX = offsetX or 0
    overlay.anchorOffsetY = offsetY or 0

    if not hoverState or not hoverState.enabled then
        overlay.hoverAllowed = false
        overlay.hoverStyleData = nil
        overlay.hoverScale = nil
        overlay.hoverColor = nil
        overlay.hover:Hide()
        return
    end

    overlay.hoverAllowed = true
    overlay.hoverStyleData = hoverState.styleData
    overlay.hoverScale = hoverState.scale or 1
    overlay.hoverColor = hoverState.color
    BorderRenderer.UpdateHover(button)
end

function BorderRenderer.Hide(button, keepHover)
    local overlay = overlays[button]
    if overlay then
        overlay.border:Hide()
        overlay.glow:Hide()

        if keepHover then
            BorderRenderer.UpdateHover(button)
        else
            overlay.hoverAllowed = false
            overlay.hoverStyleData = nil
            overlay.hoverScale = nil
            overlay.hoverColor = nil
            overlay.hover:Hide()
        end
    end
    SetDefaultBorderVisible(button, true)
end

function BorderRenderer.Apply(button, borderState)
    local hoverState = borderState and borderState.hover or nil
    local offsetX = borderState and borderState.offsetX or 0
    local offsetY = borderState and borderState.offsetY or 0

    BorderRenderer.ConfigureHover(button, hoverState, offsetX, offsetY)

    if not borderState or not borderState.visible then
        BorderRenderer.Hide(button, hoverState and hoverState.enabled)
        return
    end

    local overlay = EnsureOverlay(button)
    local style = borderState.styleData
    local color = borderState.color or QUEST_COLOR

    overlay.border:SetTexture(style.borderTexture)
    overlay.border:SetBlendMode("BLEND")
    overlay.border:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    ApplyScale(overlay.border, button, style.borderScale * borderState.scale, offsetX, offsetY)
    overlay.border:Show()

    if borderState.showGlow then
        overlay.glow:SetTexture(style.glowTexture)
        overlay.glow:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, 0.9)
        ApplyScale(overlay.glow, button, style.glowScale * borderState.scale, offsetX, offsetY)
        overlay.glow:Show()
    else
        overlay.glow:Hide()
    end

    SetDefaultBorderVisible(button, false)
    BorderRenderer.UpdateHover(button)
end

function BorderRenderer.ResolveColor(quality, isQuestItem)
    if isQuestItem then
        return QUEST_COLOR
    end

    if quality == nil or not ITEM_QUALITY_COLORS or not ITEM_QUALITY_COLORS[quality] then
        return nil
    end

    local color = ITEM_QUALITY_COLORS[quality]
    return {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = 1,
    }
end
