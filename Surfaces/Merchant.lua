local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Merchant = NS.Surfaces.Merchant or {}
local Surface = NS.Surfaces.Merchant

local initialized = false
local hooked = false
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil
local lastVisibleSurfaceSignature = nil

local MERCHANT_ITEMS_PER_PAGE = tonumber(_G.MERCHANT_ITEMS_PER_PAGE) or 10
local BUYBACK_ITEMS_PER_PAGE = tonumber(_G.BUYBACK_ITEMS_PER_PAGE) or 12
local function GetMerchantFrame()
    return _G.MerchantFrame
end

local function GetSelectedTab(frame)
    frame = frame or GetMerchantFrame()
    if not frame then
        return 1
    end

    return tonumber(frame.selectedTab) or 1
end

local function GetPage(frame)
    frame = frame or GetMerchantFrame()
    if not frame then
        return 1
    end

    return tonumber(frame.page) or 1
end

local function GetMerchantRowButton(index)
    return _G["MerchantItem" .. tostring(index) .. "ItemButton"]
end

local function GetBuybackPreviewButton()
    return _G.MerchantBuyBackItemItemButton
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
    config.merchantEnabled = baseConfig.merchantEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function MakeButtonInfo(mode, index)
    if type(mode) ~= "string" or mode == "" then
        return nil
    end

    index = tonumber(index)
    if mode ~= "buybackPreview" and (not index or index <= 0) then
        return nil
    end

    return {
        mode = mode,
        index = index,
    }
end

local function SetButtonInfo(button, info)
    if button then
        button.__BlizzItemGlowFixMerchantInfo = info
    end
end

local function ResetEarlySignature(button)
    if not button then
        return
    end

    button.__BlizzItemGlowFixMerchantSigMode = nil
    button.__BlizzItemGlowFixMerchantSigIndex = nil
    button.__BlizzItemGlowFixMerchantSigItemID = nil
    button.__BlizzItemGlowFixMerchantSigItemLink = nil
    button.__BlizzItemGlowFixMerchantSigStackCount = nil
    button.__BlizzItemGlowFixMerchantSigQuality = nil
    button.__BlizzItemGlowFixMerchantSigConfigVersion = nil
    button.__BlizzItemGlowFixMerchantSigDynamicVersion = nil
    button.__BlizzItemGlowFixMerchantSigEmpty = nil
end

local function ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return false
    end

    local isEmpty = entry == nil
    local mode = entry and entry.mode or nil
    local index = entry and entry.index or nil
    local itemID = entry and entry.itemID or nil
    local itemLink = entry and entry.itemLink or nil
    local stackCount = entry and (entry.stackCount or 0) or 0
    local quality = entry and entry.quality or nil

    return button.__BlizzItemGlowFixMerchantSigMode == mode
        and button.__BlizzItemGlowFixMerchantSigIndex == index
        and button.__BlizzItemGlowFixMerchantSigItemID == itemID
        and button.__BlizzItemGlowFixMerchantSigItemLink == itemLink
        and button.__BlizzItemGlowFixMerchantSigStackCount == stackCount
        and button.__BlizzItemGlowFixMerchantSigQuality == quality
        and button.__BlizzItemGlowFixMerchantSigConfigVersion == configVersion
        and button.__BlizzItemGlowFixMerchantSigDynamicVersion == dynamicVersion
        and button.__BlizzItemGlowFixMerchantSigEmpty == isEmpty
end

local function MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return
    end

    button.__BlizzItemGlowFixMerchantSigMode = entry and entry.mode or nil
    button.__BlizzItemGlowFixMerchantSigIndex = entry and entry.index or nil
    button.__BlizzItemGlowFixMerchantSigItemID = entry and entry.itemID or nil
    button.__BlizzItemGlowFixMerchantSigItemLink = entry and entry.itemLink or nil
    button.__BlizzItemGlowFixMerchantSigStackCount = entry and (entry.stackCount or 0) or 0
    button.__BlizzItemGlowFixMerchantSigQuality = entry and entry.quality or nil
    button.__BlizzItemGlowFixMerchantSigConfigVersion = configVersion
    button.__BlizzItemGlowFixMerchantSigDynamicVersion = dynamicVersion
    button.__BlizzItemGlowFixMerchantSigEmpty = entry == nil
end

local function ResetVisibleSurfaceSignature()
    lastVisibleSurfaceSignature = nil
end

local function AppendEntrySignature(parts, entry)
    if not entry then
        parts[#parts + 1] = "_"
        return
    end

    parts[#parts + 1] = table.concat({
        tostring(entry.mode or ""),
        tostring(entry.index or 0),
        tostring(entry.itemID or 0),
        tostring(entry.itemLink or ""),
        tostring(entry.stackCount or 0),
        tostring(entry.quality or ""),
    }, "\031")
end

local function BuildVisibleSurfaceSignature(selectedTab, page, configVersion, dynamicVersion, rowEntries, previewEntry)
    local parts = {
        tostring(selectedTab or 0),
        tostring(page or 0),
        tostring(configVersion or 0),
        tostring(dynamicVersion or 0),
    }

    for index = 1, #rowEntries do
        AppendEntrySignature(parts, rowEntries[index])
    end

    AppendEntrySignature(parts, previewEntry)
    return table.concat(parts, "\030")
end

local function ClearButton(button, reason)
    if not button then
        return
    end

    button.__BlizzItemGlowFixMerchantInfo = nil
    ResetEarlySignature(button)
    NS.Renderer.ClearButton(button, reason or "merchantClear")
end

local function ClearAllButtons(reason)
    ResetVisibleSurfaceSignature()
    for index = 1, BUYBACK_ITEMS_PER_PAGE do
        ClearButton(GetMerchantRowButton(index), reason)
    end
    ClearButton(GetBuybackPreviewButton(), reason)
end

local function BuildMerchantEntry(index)
    index = tonumber(index)
    if not index or index <= 0 then
        return nil
    end

    local itemLink = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(index) or nil
    local itemID = type(GetMerchantItemID) == "function" and GetMerchantItemID(index) or nil
    if not itemLink and not itemID then
        return nil
    end

    local info = C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" and C_MerchantFrame.GetItemInfo(index) or nil
    return {
        mode = "merchant",
        index = index,
        itemLink = itemLink,
        itemID = itemID,
        quality = type(info) == "table" and info.quality or nil,
        stackCount = type(info) == "table" and (info.stackCount or 0) or 0,
        hasNoValue = false,
        isQuestItem = false,
    }
end

local function BuildBuybackEntry(index, mode)
    index = tonumber(index)
    if not index or index <= 0 then
        return nil
    end

    local itemLink = type(GetBuybackItemLink) == "function" and GetBuybackItemLink(index) or nil
    local itemID = itemLink and type(GetItemInfoInstant) == "function" and GetItemInfoInstant(itemLink) or nil
    if not itemLink and not itemID then
        return nil
    end

    local _, _, _, quantity = type(GetBuybackItemInfo) == "function" and GetBuybackItemInfo(index) or nil

    return {
        mode = mode or "buyback",
        index = index,
        itemLink = itemLink,
        itemID = itemID,
        quality = nil,
        stackCount = quantity or 0,
        hasNoValue = false,
        isQuestItem = false,
    }
end

local function ResolveCurrentEntry(button)
    local info = button and button.__BlizzItemGlowFixMerchantInfo or nil
    if type(info) ~= "table" then
        return nil
    end

    local frame = GetMerchantFrame()
    if not frame or not frame.IsShown or not frame:IsShown() then
        return nil
    end

    local selectedTab = GetSelectedTab(frame)
    if info.mode == "merchant" then
        if selectedTab ~= 1 then
            return nil
        end
        return BuildMerchantEntry(info.index)
    end

    if info.mode == "buyback" then
        if selectedTab ~= 2 then
            return nil
        end
        return BuildBuybackEntry(info.index, "buyback")
    end

    if info.mode == "buybackPreview" then
        if selectedTab ~= 1 then
            return nil
        end

        local currentIndex = type(GetNumBuybackItems) == "function" and GetNumBuybackItems() or 0
        if currentIndex <= 0 then
            return nil
        end

        return BuildBuybackEntry(currentIndex, "buybackPreview")
    end

    return nil
end

local function GetEntrySlotKey(entry)
    if not entry then
        return nil
    end

    if entry.mode == "merchant" then
        return "merchant:item:" .. tostring(entry.index or 0)
    end

    if entry.mode == "buyback" then
        return "merchant:buyback:" .. tostring(entry.index or 0)
    end

    if entry.mode == "buybackPreview" then
        return "merchant:buybackPreview:" .. tostring(entry.index or 0)
    end

    return "merchant:unknown"
end

local function UpdateButton(button, entry, config)
    if not button then
        return
    end

    config = config or BuildSurfaceConfig()
    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Renderer and NS.Renderer._dynamicVersion or 0

    if not config or not config.merchantEnabled then
        ClearButton(button, "merchantDisabled")
        return
    end

    if not entry or (not entry.itemLink and not entry.itemID) then
        ClearButton(button, "merchantNoItem")
        return
    end

    if ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion) then
        return
    end

    SetButtonInfo(button, MakeButtonInfo(entry.mode, entry.index))

    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local snapshot = NS.ItemDataStore.GetExternalItemSnapshot(
        GetEntrySlotKey(entry),
        entry.itemLink,
        entry.itemID,
        entry.quality,
        entry.stackCount or 0,
        entry.hasNoValue == true,
        entry.isQuestItem == true,
        wantItemLevel,
        function()
            local currentEntry = ResolveCurrentEntry(button)
            if not currentEntry then
                ClearButton(button, "merchantCallbackInvalid")
                return
            end

            UpdateButton(button, currentEntry, nil)
        end,
        button
    )

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "merchant")

    if snapshot and snapshot.pending then
        ResetEarlySignature(button)
    else
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    end
end

local function RefreshVisibleInternal(reason)
    local buttonCount = 0

    local frame = GetMerchantFrame()
    if not frame or not frame.IsShown or not frame:IsShown() then
        return
    end

    local config = BuildSurfaceConfig()
    if not config or not config.merchantEnabled then
        ClearAllButtons("merchantDisabled")
        return
    end

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Renderer and NS.Renderer._dynamicVersion or 0
    local selectedTab = GetSelectedTab(frame)

    if selectedTab == 2 then

        local rowEntries = {}
        for index = 1, BUYBACK_ITEMS_PER_PAGE do
            rowEntries[index] = BuildBuybackEntry(index, "buyback")
        end

        local surfaceSignature = BuildVisibleSurfaceSignature(selectedTab, 0, configVersion, dynamicVersion, rowEntries, nil)
        if lastVisibleSurfaceSignature == surfaceSignature then
            return
        end

        for index = 1, BUYBACK_ITEMS_PER_PAGE do
            buttonCount = buttonCount + 1
            UpdateButton(GetMerchantRowButton(index), rowEntries[index], config)
        end

        buttonCount = buttonCount + 1
        ClearButton(GetBuybackPreviewButton(), "merchantPreviewHidden")
        lastVisibleSurfaceSignature = surfaceSignature
        return
    end

    local page = GetPage(frame)
    local numMerchantItems = type(GetMerchantNumItems) == "function" and GetMerchantNumItems() or 0
    local rowEntries = {}
    for index = 1, MERCHANT_ITEMS_PER_PAGE do
        local merchantIndex = ((page - 1) * MERCHANT_ITEMS_PER_PAGE) + index
        rowEntries[index] = merchantIndex <= numMerchantItems and BuildMerchantEntry(merchantIndex) or nil
    end

    local buybackIndex = type(GetNumBuybackItems) == "function" and GetNumBuybackItems() or 0
    local previewEntry = buybackIndex > 0 and BuildBuybackEntry(buybackIndex, "buybackPreview") or nil
    local surfaceSignature = BuildVisibleSurfaceSignature(selectedTab, page, configVersion, dynamicVersion, rowEntries, previewEntry)
    if lastVisibleSurfaceSignature == surfaceSignature then
        return
    end

    for index = 1, MERCHANT_ITEMS_PER_PAGE do
        buttonCount = buttonCount + 1
        UpdateButton(GetMerchantRowButton(index), rowEntries[index], config)
    end

    buttonCount = buttonCount + 1
    if previewEntry then
        UpdateButton(GetBuybackPreviewButton(), previewEntry, config)
    else
        ClearButton(GetBuybackPreviewButton(), "merchantNoBuybackPreview")
    end

    lastVisibleSurfaceSignature = surfaceSignature
end

local function InstallHooks()
    if hooked then
        return
    end

    local frame = GetMerchantFrame()
    if type(MerchantFrame_Update) ~= "function" or not frame then
        return
    end

    hooked = true
    frame:HookScript("OnHide", function()
        ResetVisibleSurfaceSignature()
    end)

    hooksecurefunc("MerchantFrame_Update", function()
        RefreshVisibleInternal("update")
    end)
end

function Surface.RefreshVisible(reason)
    InstallHooks()
    RefreshVisibleInternal(reason)
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    InstallHooks()
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("merchant", Surface)
end
