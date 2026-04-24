local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Loot = NS.Surfaces.Loot or {}
local Surface = NS.Surfaces.Loot

local initialized = false
local hooksInstalled = false
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil
local knownButtons = setmetatable({}, { __mode = "k" })

local function BuildSurfaceConfig(baseConfig)
    baseConfig = baseConfig or (NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot()) or nil
    if not baseConfig then
        return nil
    end

    local version = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    if cachedSurfaceConfig and cachedSurfaceConfigVersion == version and cachedSurfaceConfig.__base == baseConfig then
        return cachedSurfaceConfig
    end

    local config = {}
    for key, value in pairs(baseConfig) do
        config[key] = value
    end

    config.__base = baseConfig
    config.lootEnabled = baseConfig.lootEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetLootFrame()
    return _G.LootFrame
end

local function GetLootScrollRoot()
    local frame = GetLootFrame()
    if not frame then
        return nil
    end

    local scrollBox = frame.ScrollBox
    if scrollBox and scrollBox.ScrollTarget then
        return scrollBox.ScrollTarget
    end

    return scrollBox or frame
end

local function GetElementButton(element)
    if element and element.Item and element.Item.IsObjectType and element.Item:IsObjectType("Button") then
        return element.Item
    end

    return nil
end

local function IsLootElementFrame(frame)
    return frame and type(frame.GetSlotIndex) == "function" and GetElementButton(frame) ~= nil
end

local function TrackButton(button, element)
    if not button then
        return
    end

    knownButtons[button] = true
    button.__BlizzItemGlowFixLootElement = element
end

local function GetTrackedElement(button)
    if not button then
        return nil
    end

    local element = button.__BlizzItemGlowFixLootElement
    if element then
        return element
    end

    local parent = button.GetParent and button:GetParent() or nil
    if IsLootElementFrame(parent) and parent.Item == button then
        return parent
    end

    return nil
end

local function GetSlotIndex(element)
    if not element then
        return nil
    end

    if type(element.GetSlotIndex) == "function" then
        local ok, slotIndex = pcall(element.GetSlotIndex, element)
        slotIndex = ok and tonumber(slotIndex) or nil
        if slotIndex and slotIndex > 0 then
            return slotIndex
        end
    end

    if type(element.GetElementData) == "function" then
        local ok, data = pcall(element.GetElementData, element)
        if ok and type(data) == "table" then
            local slotIndex = tonumber(data.slotIndex)
            if slotIndex and slotIndex > 0 then
                return slotIndex
            end
        end
    end

    local slotIndex = tonumber(element.slotIndex)
    if slotIndex and slotIndex > 0 then
        return slotIndex
    end

    return nil
end

local function GetValidLink(link)
    if type(link) == "string" and link ~= "" then
        return link
    end

    return nil
end

local function IsSupportedLootSlotType(lootSlotType)
    local slotTypes = Enum and Enum.LootSlotType or nil
    if not slotTypes then
        return lootSlotType == 1 or lootSlotType == 2 or lootSlotType == 3
    end

    return lootSlotType == slotTypes.Item or lootSlotType == slotTypes.Currency or lootSlotType == slotTypes.Money
end

local function NormalizeLootInfo(slotIndex)
    if type(GetLootSlotInfo) ~= "function" then
        return nil
    end

    local texture, itemName, quantity, currencyID, itemQuality, locked, isQuestItem = GetLootSlotInfo(slotIndex)
    if currencyID and CurrencyContainerUtil and type(CurrencyContainerUtil.GetCurrencyContainerInfo) == "function" then
        itemName, texture, quantity, itemQuality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, itemName, texture, itemQuality)
    end

    return {
        texture = texture,
        itemName = itemName,
        quantity = quantity,
        currencyID = currencyID,
        itemQuality = itemQuality,
        locked = locked,
        isQuestItem = isQuestItem,
    }
end

local function BuildEntry(slotIndex)
    slotIndex = tonumber(slotIndex)
    if not slotIndex or slotIndex <= 0 then
        return nil
    end

    local lootSlotType = type(GetLootSlotType) == "function" and GetLootSlotType(slotIndex) or nil
    if not IsSupportedLootSlotType(lootSlotType) then
        return nil
    end

    local lootInfo = NormalizeLootInfo(slotIndex)
    if not lootInfo then
        return nil
    end

    local texture = lootInfo.texture
    local itemName = lootInfo.itemName
    local quantity = lootInfo.quantity
    local currencyID = lootInfo.currencyID
    local itemQuality = lootInfo.itemQuality
    local isQuestItem = lootInfo.isQuestItem

    local itemLink = type(GetLootSlotLink) == "function" and GetValidLink(GetLootSlotLink(slotIndex)) or nil
    if not itemName and not itemLink and not texture then
        return nil
    end

    local itemID = nil
    if itemLink and type(GetItemInfoInstant) == "function" then
        local ok, resolvedItemID = pcall(GetItemInfoInstant, itemLink)
        if ok then
            itemID = resolvedItemID
        end
    end

    local slotTypes = Enum and Enum.LootSlotType or nil
    local isMoney = (slotTypes and lootSlotType == slotTypes.Money) or (not slotTypes and lootSlotType == 3)
    local normalizedQuality = (itemQuality ~= nil and itemQuality >= 0) and itemQuality or nil
    if normalizedQuality == nil and isMoney then
        normalizedQuality = (Enum and Enum.ItemQuality and Enum.ItemQuality.Common) or 1
    end

    return {
        slotIndex = slotIndex,
        lootSlotType = lootSlotType,
        currencyID = currencyID,
        itemLink = itemLink,
        itemID = itemID,
        quality = normalizedQuality,
        stackCount = quantity or 0,
        hasNoValue = false,
        isQuestItem = isQuestItem == true,
        isMoney = isMoney,
        hasRenderableLootData = itemLink ~= nil or itemID ~= nil or itemName ~= nil or texture ~= nil,
    }
end

local function BuildSlotKey(entry)
    if not entry then
        return nil
    end

    local slotTypeKey = "item"
    local slotTypes = Enum and Enum.LootSlotType or nil
    if entry.isMoney or (slotTypes and entry.lootSlotType == slotTypes.Money) then
        slotTypeKey = "money"
    elseif entry.currencyID or (slotTypes and entry.lootSlotType == slotTypes.Currency) then
        slotTypeKey = "currency"
    end

    return table.concat({ "loot", slotTypeKey, tostring(entry.slotIndex or 0) }, ":")
end

local function BuildLightweightSnapshot(entry)
    if not entry or not entry.hasRenderableLootData then
        return nil
    end

    return {
        itemID = entry.itemID,
        itemLink = entry.itemLink,
        quality = entry.quality,
        stackCount = entry.stackCount or 0,
        hasNoValue = entry.hasNoValue == true,
        isQuestItem = entry.isQuestItem == true,
        isEquippable = false,
        itemLevel = nil,
        pending = false,
    }
end

local function ClearButton(button, reason)
    if not button then
        return
    end

    button.__BlizzItemGlowFixLootElement = nil
    NS.Renderer.ClearButton(button, reason or "surfaceClear")
end

local function ClearAll(reason)
    for button in pairs(knownButtons) do
        ClearButton(button, reason)
    end
end

local function UpdateElement(element, config)
    local button = GetElementButton(element)
    if not button then
        return
    end

    TrackButton(button, element)

    config = BuildSurfaceConfig(config)
    if not config or not config.lootEnabled then
        ClearButton(button, "lootDisabled")
        return
    end

    local slotIndex = GetSlotIndex(element)
    if not slotIndex then
        ClearButton(button, "lootInvalidSlot")
        return
    end

    local entry = BuildEntry(slotIndex)
    if not entry then
        ClearButton(button, "lootNonItem")
        return
    end

    local snapshot = nil
    if entry.itemLink or entry.itemID then
        local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
        snapshot = NS.ItemDataStore.GetExternalItemSnapshot(
            BuildSlotKey(entry),
            entry.itemLink,
            entry.itemID,
            entry.quality,
            entry.stackCount,
            entry.hasNoValue,
            entry.isQuestItem,
            wantItemLevel,
            function()
                local currentElement = GetTrackedElement(button)
                if not currentElement then
                    ClearButton(button, "lootCallbackMissing")
                    return
                end

                UpdateElement(currentElement, nil)
            end,
            button
        )
    else
        snapshot = BuildLightweightSnapshot(entry)
    end

    if not snapshot then
        ClearButton(button, "lootUnrenderable")
        return
    end

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "loot")
end

local function RefreshVisible(config)
    local frame = GetLootFrame()
    if not IsFrameShown(frame) then
        return
    end
    local buttonCount = 0

    config = BuildSurfaceConfig(config)
    if not config or not config.lootEnabled then
        ClearAll("lootDisabled")
        return
    end

    local root = GetLootScrollRoot()
    if root and NS.VisitDescendants then
        NS.VisitDescendants(root, function(child)
            if IsLootElementFrame(child) then
                buttonCount = buttonCount + 1
                UpdateElement(child, config)
            end
        end)
    end
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    local elementMixin = _G.LootFrameElementMixin
    local frame = GetLootFrame()
    if type(elementMixin) ~= "table" or type(elementMixin.Init) ~= "function" or not frame then
        return
    end

    hooksInstalled = true

    hooksecurefunc(elementMixin, "Init", function(element)
        UpdateElement(element, BuildSurfaceConfig())
    end)

    if frame.HookScript then
        frame:HookScript("OnHide", function()
            ClearAll("surfaceClear")
        end)
    end
end

local function EnsureHooks()
    InstallHooks()
end

function Surface.RefreshVisible()
    EnsureHooks()
    RefreshVisible(BuildSurfaceConfig())
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    EnsureHooks()
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("loot", Surface)
end
