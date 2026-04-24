local _, NS = ...

NS.Renderer = NS.Renderer or {}
local Renderer = NS.Renderer

local stateByButton = setmetatable({}, { __mode = "k" })
Renderer._dynamicVersion = Renderer._dynamicVersion or 0

local function GetButtonState(button)
    local state = stateByButton[button]
    if state then
        return state
    end

    state = {}
    stateByButton[button] = state
    return state
end

local function GetBorderGlowOffset(surfaceKey)
    if NS.BorderGlowCalibration and NS.BorderGlowCalibration.GetAnchorOffset then
        return NS.BorderGlowCalibration.GetAnchorOffset(surfaceKey)
    end

    return 0, 0
end

local function SnapshotMatchesState(state, snapshot, configVersion, dynamicVersion, surfaceKey)
    if not state then
        return false
    end

    if state.configVersion ~= configVersion or state.dynamicVersion ~= dynamicVersion or state.surfaceKey ~= surfaceKey then
        return false
    end

    if not snapshot then
        return state.isEmpty == true
    end

    return state.isEmpty ~= true
        and state.itemID == snapshot.itemID
        and state.itemLink == snapshot.itemLink
        and state.quality == snapshot.quality
        and state.borderQuality == snapshot.borderQuality
        and state.forceBorder == (snapshot.forceBorder == true)
        and state.presentationKind == snapshot.presentationKind
        and state.stackCount == snapshot.stackCount
        and state.hasNoValue == (snapshot.hasNoValue == true)
        and state.isQuestItem == (snapshot.isQuestItem == true)
        and state.isEquippable == (snapshot.isEquippable == true)
        and state.itemLevel == snapshot.itemLevel
        and state.pending == (snapshot.pending == true)
end

local function StoreSnapshotState(state, snapshot, configVersion, dynamicVersion, surfaceKey)
    state.configVersion = configVersion
    state.dynamicVersion = dynamicVersion
    state.surfaceKey = surfaceKey

    if not snapshot then
        state.isEmpty = true
        state.itemID = nil
        state.itemLink = nil
        state.quality = nil
        state.borderQuality = nil
        state.forceBorder = nil
        state.presentationKind = nil
        state.stackCount = nil
        state.hasNoValue = nil
        state.isQuestItem = nil
        state.isEquippable = nil
        state.itemLevel = nil
        state.pending = nil
        return
    end

    state.isEmpty = false
    state.itemID = snapshot.itemID
    state.itemLink = snapshot.itemLink
    state.quality = snapshot.quality
    state.borderQuality = snapshot.borderQuality
    state.forceBorder = snapshot.forceBorder == true
    state.presentationKind = snapshot.presentationKind
    state.stackCount = snapshot.stackCount
    state.hasNoValue = snapshot.hasNoValue == true
    state.isQuestItem = snapshot.isQuestItem == true
    state.isEquippable = snapshot.isEquippable == true
    state.itemLevel = snapshot.itemLevel
    state.pending = snapshot.pending == true
end

local function FormatItemLevel(snapshot, config)
    if not config.ilvlSectionEnabled or not snapshot or not snapshot.itemLevel then
        return nil
    end

    if snapshot.quality ~= nil and snapshot.quality < config.ilvlMinQuality then
        return nil
    end

    if not snapshot.isEquippable then
        return nil
    end

    local itemLevel = tonumber(snapshot.itemLevel)
    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    return tostring(math.floor(itemLevel + 0.5))
end

local function ApplySnapshot(button, snapshot, config, configVersion, dynamicVersion, surfaceKey)
    surfaceKey = surfaceKey or "bags"

    local state = GetButtonState(button)
    if SnapshotMatchesState(state, snapshot, configVersion, dynamicVersion, surfaceKey) then
        return
    end

    StoreSnapshotState(state, snapshot, configVersion, dynamicVersion, surfaceKey)

    local offsetX, offsetY = GetBorderGlowOffset(surfaceKey)
    local hoverState = config.hoverState

    if not snapshot then
        NS.BorderRenderer.ConfigureHover(button, hoverState, offsetX, offsetY)
        NS.BorderRenderer.Hide(button, hoverState.enabled)
        NS.TextRenderer.Hide(button)
        NS.IconRenderer.Hide(button)
        return
    end

    local borderQuality = snapshot.borderQuality
    if borderQuality == nil then
        borderQuality = snapshot.quality
    end
    local borderColor = NS.BorderRenderer.ResolveColor(borderQuality, snapshot.isQuestItem)
    local showBorder = config.borderSectionEnabled and borderColor ~= nil and (snapshot.forceBorder or snapshot.isQuestItem or (borderQuality ~= nil and borderQuality >= config.borderMinQuality))
    NS.BorderRenderer.Apply(button, {
        visible = showBorder,
        color = borderColor,
        styleData = config.borderStyleData,
        scale = config.borderStyleScale,
        showGlow = config.borderGlowEnabled,
        hover = hoverState,
        offsetX = offsetX,
        offsetY = offsetY,
    })

    NS.TextRenderer.Apply(button, {
        itemLevel = FormatItemLevel(snapshot, config),
        quality = snapshot.quality,
        useQualityColor = config.ilvlUseQualityColor,
    }, config)

    NS.IconRenderer.Apply(button, snapshot, config, surfaceKey or "bags")
end

function Renderer.InvalidateDynamicState()
    Renderer._dynamicVersion = (Renderer._dynamicVersion or 0) + 1
end

function Renderer.UpdateSnapshot(button, snapshot, config, surfaceKey)
    if not button then
        return
    end

    config = config or (NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot()) or nil
    if not config then
        Renderer.ClearButton(button, "missingConfig")
        return
    end

    if not button.__BlizzItemGlowFixPrepared and NS.AssetWarmup and NS.AssetWarmup.PrepareButtonNow then
        NS.AssetWarmup.PrepareButtonNow(button)
    end

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = Renderer._dynamicVersion or 0
    ApplySnapshot(button, snapshot, config, configVersion, dynamicVersion, surfaceKey or "bags")
end

function Renderer.ClearButton(button, reason)
    if not button then
        return
    end

    local state = stateByButton[button]
    if state and state.isEmpty == true and reason == "surfaceClear" then
        return
    end

    if state then
        state.configVersion = nil
        state.dynamicVersion = nil
        state.surfaceKey = nil
        state.isEmpty = nil
        state.itemID = nil
        state.itemLink = nil
        state.quality = nil
        state.borderQuality = nil
        state.forceBorder = nil
        state.presentationKind = nil
        state.stackCount = nil
        state.hasNoValue = nil
        state.isQuestItem = nil
        state.isEquippable = nil
        state.itemLevel = nil
        state.pending = nil
    end

    if NS.BorderRenderer then
        NS.BorderRenderer.Hide(button)
    end
    if NS.TextRenderer then
        NS.TextRenderer.Hide(button)
    end
    if NS.IconRenderer then
        NS.IconRenderer.Hide(button)
    end
end

function Renderer.UpdateBagButton(button, bagID, slotID, config, surfaceKey, resolver)
    if not button or bagID == nil or slotID == nil then
        Renderer.ClearButton(button, "invalidInput")
        return
    end

    config = config or (NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot()) or nil
    if not config or not config.bagsEnabled then
        Renderer.ClearButton(button, "disabled")
        return
    end

    if not button.__BlizzItemGlowFixPrepared and NS.AssetWarmup and NS.AssetWarmup.PrepareButtonNow then
        NS.AssetWarmup.PrepareButtonNow(button)
    end

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = Renderer._dynamicVersion or 0
    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local callbackResolver = type(resolver) == "function" and resolver or function(currentButton)
        local currentBag = currentButton.GetBagID and currentButton:GetBagID() or nil
        local currentSlot = currentButton.GetContainerSlotID and currentButton:GetContainerSlotID() or currentButton.GetID and currentButton:GetID() or nil
        return currentBag, currentSlot
    end

    local snapshot = NS.ItemDataStore.GetBagSlotSnapshot(bagID, slotID, wantItemLevel, function()
        local currentBag, currentSlot = callbackResolver(button)
        if currentBag == nil or currentSlot == nil then
            Renderer.ClearButton(button, "callbackInvalid")
            return
        end
        Renderer.UpdateBagButton(button, currentBag, currentSlot, nil, surfaceKey, resolver)
    end, button)

    ApplySnapshot(button, snapshot, config, configVersion, dynamicVersion, surfaceKey or "bags")
end

function Renderer.UpdateInventoryButton(button, unit, slotID, config, surfaceKey)
    if not button or type(unit) ~= "string" or unit == "" or slotID == nil then
        Renderer.ClearButton(button, "invalidInput")
        return
    end

    config = config or (NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot()) or nil
    if not config then
        Renderer.ClearButton(button, "missingConfig")
        return
    end

    if not button.__BlizzItemGlowFixPrepared and NS.AssetWarmup and NS.AssetWarmup.PrepareButtonNow then
        NS.AssetWarmup.PrepareButtonNow(button)
    end

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = Renderer._dynamicVersion or 0
    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local snapshot = NS.ItemDataStore.GetInventorySlotSnapshot(unit, slotID, wantItemLevel, function()
        Renderer.UpdateInventoryButton(button, unit, slotID, config, surfaceKey)
    end, button)

    ApplySnapshot(button, snapshot, config, configVersion, dynamicVersion, surfaceKey or "character")
end

function Renderer.UpdateGuildBankButton(button, tabID, slotID, config, surfaceKey, resolver)
    if not button or tabID == nil or slotID == nil then
        Renderer.ClearButton(button, "invalidInput")
        return
    end

    config = config or (NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot()) or nil
    if not config or not config.bagsEnabled then
        Renderer.ClearButton(button, "disabled")
        return
    end

    if not button.__BlizzItemGlowFixPrepared and NS.AssetWarmup and NS.AssetWarmup.PrepareButtonNow then
        NS.AssetWarmup.PrepareButtonNow(button)
    end

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = Renderer._dynamicVersion or 0
    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local callbackResolver = type(resolver) == "function" and resolver or function(currentButton)
        return GetCurrentGuildBankTab and GetCurrentGuildBankTab() or nil, currentButton.GetID and currentButton:GetID() or nil
    end

    local snapshot = NS.ItemDataStore.GetGuildBankSlotSnapshot(tabID, slotID, wantItemLevel, function()
        local currentTab, currentSlot = callbackResolver(button)
        if currentTab == nil or currentSlot == nil then
            Renderer.ClearButton(button, "callbackInvalid")
            return
        end
        Renderer.UpdateGuildBankButton(button, currentTab, currentSlot, nil, surfaceKey, resolver)
    end, button)

    ApplySnapshot(button, snapshot, config, configVersion, dynamicVersion, surfaceKey or "guildBank")
end
