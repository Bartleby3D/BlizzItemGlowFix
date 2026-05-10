local _, NS = ...

NS.ItemLevelResolver = NS.ItemLevelResolver or {}
local Resolver = NS.ItemLevelResolver

local ITEM_LEVEL_LINE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemLevel or nil
local ITEM_LEVEL_PATTERN = type(ITEM_LEVEL) == "string" and ITEM_LEVEL:gsub("%%d", "(%%d+)") or nil

local function NormalizeItemLevel(value)
    value = tonumber(value)
    if value and value > 0 then
        return value
    end

    return nil
end

function Resolver.GetItemLevelFromTooltipData(tooltipData)
    if type(tooltipData) ~= "table" then
        return nil, nil
    end

    local dataInstanceID = NormalizeItemLevel(tooltipData.dataInstanceID) or tonumber(tooltipData.dataInstanceID)
    if type(tooltipData.lines) ~= "table" then
        return nil, dataInstanceID
    end

    for _, line in ipairs(tooltipData.lines) do
        local lineMatches = ITEM_LEVEL_LINE_TYPE and line.type == ITEM_LEVEL_LINE_TYPE or ITEM_LEVEL_LINE_TYPE == nil
        if lineMatches then
            local itemLevel = NormalizeItemLevel(line.itemLevel)
            if itemLevel then
                return itemLevel
            end

            local leftText = line.leftText
            if ITEM_LEVEL_PATTERN and type(leftText) == "string" then
                itemLevel = NormalizeItemLevel(leftText:match(ITEM_LEVEL_PATTERN))
                if itemLevel then
                    return itemLevel, nil
                end
            end
        end
    end

    return nil, dataInstanceID
end

function Resolver.ResolveFromTooltipGetter(tooltipGetter, ...)
    if type(tooltipGetter) ~= "function" then
        return nil
    end

    local ok, tooltipData = pcall(tooltipGetter, ...)
    if not ok then
        return nil, nil
    end

    return Resolver.GetItemLevelFromTooltipData(tooltipData)
end

function Resolver.ResolveFromItemLocation(itemLocation)
    if not itemLocation then
        return nil
    end

    if itemLocation.IsValid and not itemLocation:IsValid() then
        return nil
    end

    if C_Item and C_Item.DoesItemExist and not C_Item.DoesItemExist(itemLocation) then
        return nil
    end

    if C_Item and type(C_Item.GetCurrentItemLevel) == "function" then
        return NormalizeItemLevel(C_Item.GetCurrentItemLevel(itemLocation))
    end

    return nil
end

function Resolver.ResolveFromBagSlot(bagID, slotID)
    if not (ItemLocation and ItemLocation.CreateFromBagAndSlot) then
        return nil
    end

    return Resolver.ResolveFromItemLocation(ItemLocation:CreateFromBagAndSlot(bagID, slotID))
end

function Resolver.ResolveFromPlayerEquipmentSlot(slotID)
    if not (ItemLocation and ItemLocation.CreateFromEquipmentSlot) then
        return nil
    end

    return Resolver.ResolveFromItemLocation(ItemLocation:CreateFromEquipmentSlot(slotID))
end

function Resolver.ResolveFromInventorySlot(unit, slotID)
    if type(unit) ~= "string" or unit == "" or slotID == nil then
        return nil
    end

    if unit == "player" then
        return Resolver.ResolveFromPlayerEquipmentSlot(slotID)
    end

    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, unit, slotID)
end

function Resolver.ResolveFromGuildBankSlot(tabID, slotID)
    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetGuildBankItem, tabID, slotID)
end

function Resolver.ResolveFromLootSlot(slotIndex)
    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetLootItem, slotIndex)
end

function Resolver.ResolveFromMerchantEntry(mode, index)
    if mode == "merchant" then
        return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetMerchantItem, index)
    end

    if mode == "buyback" or mode == "buybackPreview" then
        return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetBuybackItem, index)
    end

    return nil
end

function Resolver.ResolveFromSendMail(index)
    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetSendMailItem, index)
end

function Resolver.ResolveFromInboxItem(messageIndex, attachmentIndex)
    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetInboxItem, messageIndex, attachmentIndex)
end

function Resolver.ResolveFromTradeEntry(side, index)
    if side == "player" then
        return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetTradePlayerItem, index)
    end

    if side == "target" then
        return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetTradeTargetItem, index)
    end

    return nil
end

function Resolver.ResolveFromQuestReward(isQuestLogContext, rewardType, rewardIndex, questID)
    if isQuestLogContext then
        return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetQuestLogItem, rewardType, rewardIndex, questID)
    end

    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetQuestItem, rewardType, rewardIndex)
end

function Resolver.ResolveFromHyperlink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    return Resolver.ResolveFromTooltipGetter(C_TooltipInfo and C_TooltipInfo.GetHyperlink, itemLink)
end
