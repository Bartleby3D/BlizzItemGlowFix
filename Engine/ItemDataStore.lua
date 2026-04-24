local _, NS = ...

NS.ItemDataStore = NS.ItemDataStore or {}
local Store = NS.ItemDataStore

local pendingBySlot = {}
local slotSnapshotCache = {}
local derivedByItemKey = {}

local function BuildSlotKey(prefix, id1, id2)
    return tostring(prefix) .. ":" .. tostring(id1) .. ":" .. tostring(id2)
end

local function GetItemInfoValue(itemLink, itemID)
    return itemLink or itemID
end

local function GetItemKey(itemLink, itemID)
    if type(itemLink) == "string" and itemLink ~= "" then
        return itemLink
    end

    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
        return "itemid:" .. tostring(itemID)
    end

    return nil
end

local function GetDerivedEntry(itemKey)
    if not itemKey then
        return nil
    end

    local entry = derivedByItemKey[itemKey]
    if entry then
        return entry
    end

    entry = {}
    derivedByItemKey[itemKey] = entry
    return entry
end

local function RegisterPendingCallback(slotKey, callbackKey, onResolved, requestFactory)
    if type(onResolved) ~= "function" then
        return nil
    end

    local pending = pendingBySlot[slotKey]
    if not pending then
        pending = {
            waiting = false,
            callbacks = {},
            list = {},
            requestFactory = nil,
        }
        pendingBySlot[slotKey] = pending
    end

    if type(requestFactory) == "function" then
        pending.requestFactory = requestFactory
    end

    if callbackKey ~= nil then
        pending.callbacks[callbackKey] = onResolved
    else
        pending.list[#pending.list + 1] = onResolved
    end

    return pending
end

local function FirePendingCallbacks(slotKey)
    local pending = pendingBySlot[slotKey]
    pendingBySlot[slotKey] = nil
    slotSnapshotCache[slotKey] = nil

    if not pending then
        return
    end

    if type(pending.callbacks) == "table" then
        for _, callback in pairs(pending.callbacks) do
            NS.SafeCall("ItemDataStore callback", callback)
        end
    end

    if type(pending.list) == "table" then
        for index = 1, #pending.list do
            NS.SafeCall("ItemDataStore callback", pending.list[index])
        end
    end
end

local function RequestAsync(slotKey)
    local pending = pendingBySlot[slotKey]
    if not pending or pending.waiting or type(pending.requestFactory) ~= "function" then
        return
    end

    if not Item then
        return
    end

    local item = pending.requestFactory()
    if not item or (item.IsItemEmpty and item:IsItemEmpty()) or not item.ContinueOnItemLoad then
        return
    end

    pending.waiting = true
    item:ContinueOnItemLoad(function()
        FirePendingCallbacks(slotKey)
    end)
end

local function ResolveIsEquippable(itemInfoValue, itemKey)
    local entry = GetDerivedEntry(itemKey)
    if entry and entry.isEquippable ~= nil then
        return entry.isEquippable == true
    end

    local isEquippable = itemInfoValue and C_Item and C_Item.IsEquippableItem and C_Item.IsEquippableItem(itemInfoValue) or false
    if entry then
        entry.isEquippable = isEquippable == true
    end

    return isEquippable == true
end

local function ResolveQuality(itemInfoValue, quality)
    if quality ~= nil then
        return quality
    end

    if not itemInfoValue then
        return nil
    end

    if C_Item and type(C_Item.GetItemQualityByID) == "function" then
        local resolved = NS.TryCall("ItemDataStore.GetItemQualityByID", C_Item.GetItemQualityByID, itemInfoValue)
        if type(resolved) == "number" then
            return resolved
        end
    end

    if C_Item and type(C_Item.GetItemInfo) == "function" then
        local itemInfo = NS.TryCall("ItemDataStore.GetItemInfo", C_Item.GetItemInfo, itemInfoValue)
        if type(itemInfo) == "table" and type(itemInfo.quality) == "number" then
            return itemInfo.quality
        end
    end

    if type(GetItemInfo) == "function" then
        local _, _, resolved = NS.TryCall("ItemDataStore.GetItemInfoLegacy", GetItemInfo, itemInfoValue)
        if type(resolved) == "number" then
            return resolved
        end
    end

    return nil
end

local function ResolveItemLevel(itemInfoValue, itemKey)
    local entry = GetDerivedEntry(itemKey)
    if entry and type(entry.itemLevel) == "number" and entry.itemLevel > 0 then
        return entry.itemLevel
    end

    if not (itemInfoValue and C_Item and C_Item.GetDetailedItemLevelInfo) then
        return nil
    end

    local itemLevel = C_Item.GetDetailedItemLevelInfo(itemInfoValue)
    if type(itemLevel) == "number" and itemLevel > 0 then
        if entry then
            entry.itemLevel = itemLevel
        end
        return itemLevel
    end

    return nil
end

local function BuildSnapshotFromInfo(slotKey, itemID, itemLink, quality, stackCount, hasNoValue, isQuestItem, wantItemLevel, onResolved, callbackKey, requestFactory, bagID, slotID)
    local cached = slotSnapshotCache[slotKey]
    if cached
        and cached.wantItemLevel == (wantItemLevel == true)
        and cached.itemID == itemID
        and cached.itemLink == itemLink
        and cached.quality == quality
        and cached.stackCount == (stackCount or 0)
        and cached.hasNoValue == (hasNoValue == true)
        and cached.isQuestItem == (isQuestItem == true)
    then
        if cached.pending and onResolved then
            RegisterPendingCallback(slotKey, callbackKey, onResolved, requestFactory)
        end
        return cached.snapshot
    end

    local itemInfoValue = GetItemInfoValue(itemLink, itemID)
    quality = ResolveQuality(itemInfoValue, quality)
    local itemKey = GetItemKey(itemLink, itemID)
    local isEquippable = ResolveIsEquippable(itemInfoValue, itemKey)

    local snapshot = {
        bagID = bagID,
        slotID = slotID,
        itemID = itemID,
        itemLink = itemLink,
        quality = quality,
        stackCount = stackCount or 0,
        hasNoValue = hasNoValue == true,
        isQuestItem = isQuestItem == true,
        isEquippable = isEquippable,
        itemLevel = nil,
        pending = false,
    }

    local needsAsync = false

    if quality == nil and onResolved then
        RegisterPendingCallback(slotKey, callbackKey, onResolved, requestFactory)
        snapshot.pending = true
        needsAsync = true
    end

    if wantItemLevel and isEquippable then
        local itemLevel = ResolveItemLevel(itemInfoValue, itemKey)
        if itemLevel then
            snapshot.itemLevel = itemLevel
        elseif onResolved then
            RegisterPendingCallback(slotKey, callbackKey, onResolved, requestFactory)
            snapshot.pending = true
            needsAsync = true
        end
    end

    if needsAsync then
        RequestAsync(slotKey)
    end

    slotSnapshotCache[slotKey] = {
        itemID = itemID,
        itemLink = itemLink,
        quality = quality,
        stackCount = stackCount or 0,
        hasNoValue = hasNoValue == true,
        isQuestItem = isQuestItem == true,
        wantItemLevel = wantItemLevel == true,
        snapshot = snapshot,
        pending = snapshot.pending == true,
    }

    return snapshot
end

local function GetItemIDFromLinkOrID(itemLink, itemID)
    if itemID then
        return itemID
    end

    if type(GetItemInfoInstant) == "function" and itemLink then
        local itemIDFromLink = GetItemInfoInstant(itemLink)
        if type(itemIDFromLink) == "number" and itemIDFromLink > 0 then
            return itemIDFromLink
        end
    end

    return nil
end

local function GetQuestState(bagID, slotID)
    if not (C_Container and C_Container.GetContainerItemQuestInfo) then
        return false
    end

    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID)
    if type(questInfo) == "table" then
        return questInfo.isQuestItem == true or questInfo.questID ~= nil
    end

    return false
end

function Store.PreloadEquippedItems()
    if not (C_Item and C_Item.RequestLoadItemDataByID and type(GetInventoryItemID) == "function") then
        return
    end

    for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
end

function Store.GetBagSlotSnapshot(bagID, slotID, wantItemLevel, onResolved, callbackKey)
    if bagID == nil or slotID == nil then
        return nil
    end

    if not (C_Container and C_Container.GetContainerItemInfo) then
        return nil
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    local slotKey = BuildSlotKey("bag", bagID, slotID)
    if not info then
        slotSnapshotCache[slotKey] = nil
        pendingBySlot[slotKey] = nil
        return nil
    end

    local itemID = info.itemID or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bagID, slotID)) or nil
    local itemLink = info.hyperlink
    local quality = info.quality
    local stackCount = info.stackCount or 0
    local hasNoValue = info.hasNoValue == true
    local isQuestItem = GetQuestState(bagID, slotID)

    return BuildSnapshotFromInfo(
        slotKey,
        itemID,
        itemLink,
        quality,
        stackCount,
        hasNoValue,
        isQuestItem,
        wantItemLevel,
        onResolved,
        callbackKey,
        function()
            return Item:CreateFromBagAndSlot(bagID, slotID)
        end,
        bagID,
        slotID
    )
end

function Store.GetGuildBankSlotSnapshot(tabID, slotID, wantItemLevel, onResolved, callbackKey)
    if type(GetGuildBankItemLink) ~= "function" or type(GetGuildBankItemInfo) ~= "function" then
        return nil
    end

    tabID = tonumber(tabID)
    slotID = tonumber(slotID)
    if not tabID or tabID <= 0 or not slotID or slotID <= 0 then
        return nil
    end

    local itemLink = GetGuildBankItemLink(tabID, slotID)
    local slotKey = BuildSlotKey("guildbank", tabID, slotID)
    if not itemLink then
        slotSnapshotCache[slotKey] = nil
        pendingBySlot[slotKey] = nil
        return nil
    end

    local _, stackCount, _, _, quality = GetGuildBankItemInfo(tabID, slotID)
    local itemID = GetItemIDFromLinkOrID(itemLink, nil)

    return BuildSnapshotFromInfo(
        slotKey,
        itemID,
        itemLink,
        quality,
        stackCount or 0,
        false,
        false,
        wantItemLevel,
        onResolved,
        callbackKey,
        function()
            return Item:CreateFromItemLink(itemLink)
        end,
        tabID,
        slotID
    )
end

function Store.GetInventorySlotSnapshot(unit, slotID, wantItemLevel, onResolved, callbackKey)
    if type(GetInventoryItemLink) ~= "function" or type(GetInventoryItemID) ~= "function" then
        return nil
    end

    if type(unit) ~= "string" or unit == "" or slotID == nil then
        return nil
    end

    local itemLink = GetInventoryItemLink(unit, slotID)
    local itemID = GetInventoryItemID(unit, slotID)
    local slotKey = BuildSlotKey("inventory", unit, slotID)

    if not itemLink and not itemID then
        slotSnapshotCache[slotKey] = nil
        pendingBySlot[slotKey] = nil
        return nil
    end

    local quality = nil
    if type(GetInventoryItemQuality) == "function" then
        quality = GetInventoryItemQuality(unit, slotID)
    end
    if quality == nil and itemLink and C_Item and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(itemLink)
    end

    local requestFactory
    if unit == "player" and Item and Item.CreateFromEquipmentSlot then
        requestFactory = function()
            return Item:CreateFromEquipmentSlot(slotID)
        end
    elseif Item and Item.CreateFromItemLink and type(itemLink) == "string" and itemLink ~= "" then
        requestFactory = function()
            return Item:CreateFromItemLink(itemLink)
        end
    elseif Item and Item.CreateFromItemID and tonumber(itemID) then
        requestFactory = function()
            return Item:CreateFromItemID(itemID)
        end
    end

    local snapshot = BuildSnapshotFromInfo(
        slotKey,
        itemID,
        itemLink,
        quality,
        0,
        false,
        false,
        wantItemLevel,
        onResolved,
        callbackKey,
        requestFactory,
        nil,
        slotID
    )

    if snapshot then
        snapshot.unit = unit
        snapshot.isInventorySlot = true
    end

    return snapshot
end

function Store.GetExternalItemSnapshot(slotKey, itemLink, itemID, quality, stackCount, hasNoValue, isQuestItem, wantItemLevel, onResolved, callbackKey)
    if type(slotKey) ~= "string" or slotKey == "" then
        slotKey = BuildSlotKey("external", itemID or 0, itemLink or "")
    end

    if not itemLink and not itemID then
        slotSnapshotCache[slotKey] = nil
        pendingBySlot[slotKey] = nil
        return nil
    end

    itemID = GetItemIDFromLinkOrID(itemLink, itemID)

    local requestFactory
    if Item and Item.CreateFromItemLink and type(itemLink) == "string" and itemLink ~= "" then
        requestFactory = function()
            return Item:CreateFromItemLink(itemLink)
        end
    elseif Item and Item.CreateFromItemID and tonumber(itemID) then
        requestFactory = function()
            return Item:CreateFromItemID(itemID)
        end
    end

    return BuildSnapshotFromInfo(
        slotKey,
        itemID,
        itemLink,
        quality,
        stackCount or 0,
        hasNoValue == true,
        isQuestItem == true,
        wantItemLevel,
        onResolved,
        callbackKey,
        requestFactory,
        nil,
        nil
    )
end

