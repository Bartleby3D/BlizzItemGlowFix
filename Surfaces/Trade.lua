local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Trade = NS.Surfaces.Trade or {}
local Surface = NS.Surfaces.Trade

local initialized = false
local hooksInstalled = false
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil

local MAX_TRADE_ITEMS = tonumber(_G.MAX_TRADE_ITEMS) or 7
local TRADE_ENCHANT_SLOT = tonumber(_G.TRADE_ENCHANT_SLOT) or MAX_TRADE_ITEMS
local function GetTradeFrame()
    return _G.TradeFrame
end

local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

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
    config.tradeEnabled = baseConfig.tradeEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function MakeButtonInfo(side, index)
    if type(side) ~= "string" or side == "" then
        return nil
    end

    index = tonumber(index)
    if not index or index <= 0 then
        return nil
    end

    return {
        side = side,
        index = index,
    }
end

local function SetButtonInfo(button, info)
    if button then
        button.__BlizzItemGlowFixTradeInfo = info
    end
end

local function GetButtonInfo(button)
    return button and button.__BlizzItemGlowFixTradeInfo or nil
end

local function GetPlayerButton(index)
    return _G["TradePlayerItem" .. tostring(index) .. "ItemButton"]
end

local function GetTargetButton(index)
    return _G["TradeRecipientItem" .. tostring(index) .. "ItemButton"]
end

local function EnumerateButtons(callback)
    if type(callback) ~= "function" then
        return
    end

    for index = 1, MAX_TRADE_ITEMS do
        local playerButton = GetPlayerButton(index)
        if playerButton then
            callback(playerButton, "player", index)
        end

        local targetButton = GetTargetButton(index)
        if targetButton then
            callback(targetButton, "target", index)
        end
    end
end

local function ResetEarlySignature(button)
    if not button then
        return
    end

    button.__BlizzItemGlowFixTradeSigSide = nil
    button.__BlizzItemGlowFixTradeSigIndex = nil
    button.__BlizzItemGlowFixTradeSigItemID = nil
    button.__BlizzItemGlowFixTradeSigItemLink = nil
    button.__BlizzItemGlowFixTradeSigStackCount = nil
    button.__BlizzItemGlowFixTradeSigQuality = nil
    button.__BlizzItemGlowFixTradeSigConfigVersion = nil
    button.__BlizzItemGlowFixTradeSigDynamicVersion = nil
    button.__BlizzItemGlowFixTradeSigEmpty = nil
end

local function ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return false
    end

    local isEmpty = entry == nil
    local side = entry and entry.side or nil
    local index = entry and entry.index or nil
    local itemID = entry and entry.itemID or nil
    local itemLink = entry and entry.itemLink or nil
    local stackCount = entry and (entry.stackCount or 0) or 0
    local quality = entry and entry.quality or nil

    return button.__BlizzItemGlowFixTradeSigSide == side
        and button.__BlizzItemGlowFixTradeSigIndex == index
        and button.__BlizzItemGlowFixTradeSigItemID == itemID
        and button.__BlizzItemGlowFixTradeSigItemLink == itemLink
        and button.__BlizzItemGlowFixTradeSigStackCount == stackCount
        and button.__BlizzItemGlowFixTradeSigQuality == quality
        and button.__BlizzItemGlowFixTradeSigConfigVersion == configVersion
        and button.__BlizzItemGlowFixTradeSigDynamicVersion == dynamicVersion
        and button.__BlizzItemGlowFixTradeSigEmpty == isEmpty
end

local function MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return
    end

    button.__BlizzItemGlowFixTradeSigSide = entry and entry.side or nil
    button.__BlizzItemGlowFixTradeSigIndex = entry and entry.index or nil
    button.__BlizzItemGlowFixTradeSigItemID = entry and entry.itemID or nil
    button.__BlizzItemGlowFixTradeSigItemLink = entry and entry.itemLink or nil
    button.__BlizzItemGlowFixTradeSigStackCount = entry and (entry.stackCount or 0) or 0
    button.__BlizzItemGlowFixTradeSigQuality = entry and entry.quality or nil
    button.__BlizzItemGlowFixTradeSigConfigVersion = configVersion
    button.__BlizzItemGlowFixTradeSigDynamicVersion = dynamicVersion
    button.__BlizzItemGlowFixTradeSigEmpty = entry == nil
end

local function GetValidLink(link)
    if type(link) == "string" and link ~= "" then
        return link
    end

    return nil
end

local function ResolveItemID(itemLink, itemID)
    if itemID then
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
            return itemID
        end
    end

    if itemLink and type(GetItemInfoInstant) == "function" then
        local ok, resolvedItemID = pcall(GetItemInfoInstant, itemLink)
        if ok then
            resolvedItemID = tonumber(resolvedItemID)
            if resolvedItemID and resolvedItemID > 0 then
                return resolvedItemID
            end
        end
    end

    return nil
end

local function NormalizeQuality(quality)
    quality = tonumber(quality)
    if quality and quality >= 0 then
        return quality
    end

    return nil
end

local function BuildPlayerEntry(index)
    index = tonumber(index)
    if not index or index <= 0 or type(GetTradePlayerItemInfo) ~= "function" then
        return nil
    end

    local name, texture, stackCount, quality, enchantment = GetTradePlayerItemInfo(index)
    local itemLink = type(GetTradePlayerItemLink) == "function" and GetValidLink(GetTradePlayerItemLink(index)) or nil
    local itemID = ResolveItemID(itemLink, nil)
    local hasRenderableTradeData = itemLink ~= nil or itemID ~= nil or name ~= nil or texture ~= nil or enchantment ~= nil
    if not hasRenderableTradeData and not stackCount then
        return nil
    end

    return {
        side = "player",
        index = index,
        itemLink = itemLink,
        itemID = itemID,
        quality = NormalizeQuality(quality),
        stackCount = stackCount or 0,
        hasNoValue = false,
        isQuestItem = false,
        isEnchantSlot = index == TRADE_ENCHANT_SLOT,
        hasRenderableTradeData = hasRenderableTradeData,
    }
end

local function BuildTargetEntry(index)
    index = tonumber(index)
    if not index or index <= 0 or type(GetTradeTargetItemInfo) ~= "function" then
        return nil
    end

    local name, texture, stackCount, quality, isUsable, enchantment = GetTradeTargetItemInfo(index)
    local itemLink = type(GetTradeTargetItemLink) == "function" and GetValidLink(GetTradeTargetItemLink(index)) or nil
    local itemID = ResolveItemID(itemLink, nil)
    local hasRenderableTradeData = itemLink ~= nil or itemID ~= nil or name ~= nil or texture ~= nil or enchantment ~= nil
    if not hasRenderableTradeData and not stackCount then
        return nil
    end

    return {
        side = "target",
        index = index,
        itemLink = itemLink,
        itemID = itemID,
        quality = NormalizeQuality(quality),
        stackCount = stackCount or 0,
        hasNoValue = false,
        isQuestItem = false,
        isEnchantSlot = index == TRADE_ENCHANT_SLOT,
        isUsable = isUsable == true,
        hasRenderableTradeData = hasRenderableTradeData,
    }
end

local function BuildEntry(side, index)
    if side == "player" then
        return BuildPlayerEntry(index)
    end
    if side == "target" then
        return BuildTargetEntry(index)
    end
    return nil
end

local function ResolveCurrentEntry(button)
    local info = GetButtonInfo(button)
    if not info then
        return nil
    end

    return BuildEntry(info.side, info.index)
end

local function BuildSlotKey(entry)
    if not entry then
        return nil
    end

    return table.concat({ "trade", tostring(entry.side or ""), tostring(entry.index or 0) }, ":")
end

local function BuildLightweightSnapshot(entry)
    if not entry or not entry.hasRenderableTradeData then
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

    SetButtonInfo(button, nil)
    ResetEarlySignature(button)
    NS.Renderer.ClearButton(button, reason or "surfaceClear")
end

local function ClearAllButtons(reason)
    EnumerateButtons(function(button)
        ClearButton(button, reason)
    end)
end

local function UpdateButton(button, entry, config)
    if not button then
        return
    end

    config = BuildSurfaceConfig(config)
    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Renderer and NS.Renderer._dynamicVersion or 0

    SetButtonInfo(button, entry and MakeButtonInfo(entry.side, entry.index) or nil)

    if not config or not config.tradeEnabled then
        ClearButton(button, "tradeDisabled")
        return
    end

    if ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion) then
        return
    end

    if not entry then
        ClearButton(button, "tradeEmpty")
        MarkEarlySignature(button, nil, configVersion, dynamicVersion)
        return
    end

    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local snapshot = nil
    if entry.itemLink or entry.itemID then
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
                if not IsFrameShown(GetTradeFrame()) then
                    ClearButton(button, "tradeCallbackHidden")
                    return
                end

                local currentEntry = ResolveCurrentEntry(button)
                UpdateButton(button, currentEntry, nil)
            end,
            button
        )
    else
        snapshot = BuildLightweightSnapshot(entry)
    end

    if not snapshot then
        ClearButton(button, "tradeUnrenderable")
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
        return
    end

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "trade")

    if snapshot.pending then
        ResetEarlySignature(button)
    else
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    end
end

local function UpdatePlayerSlot(index, config)
    UpdateButton(GetPlayerButton(index), BuildPlayerEntry(index), config)
end

local function UpdateTargetSlot(index, config)
    UpdateButton(GetTargetButton(index), BuildTargetEntry(index), config)
end

local function RefreshVisible(config)
    local frame = GetTradeFrame()
    if not IsFrameShown(frame) then
        return
    end
    local buttonCount = 0

    config = BuildSurfaceConfig(config)
    if not config or not config.tradeEnabled then
        ClearAllButtons("tradeDisabled")
        return
    end

    EnumerateButtons(function(button, side, index)
        buttonCount = buttonCount + 1
        UpdateButton(button, BuildEntry(side, index), config)
    end)
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    local frame = GetTradeFrame()
    if not frame or type(TradeFrame_UpdatePlayerItem) ~= "function" or type(TradeFrame_UpdateTargetItem) ~= "function" then
        return
    end

    hooksInstalled = true

    if frame.HookScript then
        frame:HookScript("OnHide", function()
            ClearAllButtons("surfaceClear")
        end)
    end

    if type(TradeFrame_Update) == "function" then
        hooksecurefunc("TradeFrame_Update", function()
        end)
    end

    hooksecurefunc("TradeFrame_UpdatePlayerItem", function(index)
        UpdatePlayerSlot(index, BuildSurfaceConfig())
    end)

    hooksecurefunc("TradeFrame_UpdateTargetItem", function(index)
        UpdateTargetSlot(index, BuildSurfaceConfig())
    end)
end

function Surface.RefreshVisible()
    InstallHooks()
    RefreshVisible(BuildSurfaceConfig())
end

function Surface.Initialize()
    if initialized then
        return
    end

    initialized = true
    InstallHooks()
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("trade", Surface)
end
