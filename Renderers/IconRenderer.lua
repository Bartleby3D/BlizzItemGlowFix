local _, NS = ...

NS.IconRenderer = NS.IconRenderer or {}
local IconRenderer = NS.IconRenderer
local LAI = LibStub and LibStub:GetLibrary("LibAppropriateItems-1.0", true) or nil

local stateByButton = setmetatable({}, { __mode = "k" })
local equippedItemLevelCache = {}
local equipLocCacheByItemID = {}
local transmogSourceCacheByLink = {}
local transmogCollectableCacheBySourceID = {}

local DEFAULT_ITEM_ICON_SIZE = 37

local SLOT_HEAD = 1
local SLOT_NECK = 2
local SLOT_SHOULDER = 3
local SLOT_BODY = 4
local SLOT_CHEST = 5
local SLOT_WAIST = 6
local SLOT_LEGS = 7
local SLOT_FEET = 8
local SLOT_WRIST = 9
local SLOT_HANDS = 10
local SLOT_FINGER_1 = 11
local SLOT_FINGER_2 = 12
local SLOT_TRINKET_1 = 13
local SLOT_TRINKET_2 = 14
local SLOT_BACK = 15
local SLOT_MAIN_HAND = 16
local SLOT_OFF_HAND = 17
local SLOT_TABARD = 19

local EQUIP_LOC_TO_SLOTS = {
    INVTYPE_HEAD = { SLOT_HEAD },
    INVTYPE_NECK = { SLOT_NECK },
    INVTYPE_SHOULDER = { SLOT_SHOULDER },
    INVTYPE_BODY = { SLOT_BODY },
    INVTYPE_CHEST = { SLOT_CHEST },
    INVTYPE_ROBE = { SLOT_CHEST },
    INVTYPE_WAIST = { SLOT_WAIST },
    INVTYPE_LEGS = { SLOT_LEGS },
    INVTYPE_FEET = { SLOT_FEET },
    INVTYPE_WRIST = { SLOT_WRIST },
    INVTYPE_HAND = { SLOT_HANDS },
    INVTYPE_FINGER = { SLOT_FINGER_1, SLOT_FINGER_2 },
    INVTYPE_TRINKET = { SLOT_TRINKET_1, SLOT_TRINKET_2 },
    INVTYPE_CLOAK = { SLOT_BACK },
    INVTYPE_WEAPON = { SLOT_MAIN_HAND, SLOT_OFF_HAND },
    INVTYPE_2HWEAPON = { SLOT_MAIN_HAND },
    INVTYPE_WEAPONMAINHAND = { SLOT_MAIN_HAND },
    INVTYPE_WEAPONOFFHAND = { SLOT_OFF_HAND },
    INVTYPE_HOLDABLE = { SLOT_OFF_HAND },
    INVTYPE_SHIELD = { SLOT_OFF_HAND },
    INVTYPE_RANGED = { SLOT_MAIN_HAND },
    INVTYPE_RANGEDRIGHT = { SLOT_MAIN_HAND },
    INVTYPE_THROWN = { SLOT_MAIN_HAND },
    INVTYPE_TABARD = { SLOT_TABARD },
}

local ENCHANTABLE_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_FINGER = true,
    INVTYPE_WEAPON = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
}

local function GetState(button)
    local state = stateByButton[button]
    if state then
        return state
    end

    state = {}
    stateByButton[button] = state
    return state
end

local function EnsureIconTexture(button, key, atlas, subLevel)
    local state = GetState(button)
    local texture = state[key]
    if texture then
        return texture
    end

    texture = button:CreateTexture(nil, "OVERLAY", nil, subLevel or 1)
    texture.__BlizzItemGlowFixOverlayTexture = true
    if atlas and texture.SetAtlas then
        texture:SetAtlas(atlas, false)
    end
    texture:Hide()
    state[key] = texture
    return texture
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
    local region = GetRenderRegion(button)
    if not button or not region or region == button then
        return 1
    end

    local width = region.GetWidth and region:GetWidth() or 0
    local height = region.GetHeight and region:GetHeight() or 0
    local side = math.min(tonumber(width) or 0, tonumber(height) or 0)
    if side <= 0 or side >= DEFAULT_ITEM_ICON_SIZE then
        return 1
    end

    return Clamp(side / DEFAULT_ITEM_ICON_SIZE, 0.5, 1)
end

local function UpdateIconLayout(texture, button, size, offsetX, offsetY)
    if not texture then
        return
    end

    local region = GetRenderRegion(button)
    local targetScale = GetTargetScale(button)
    local scaledSize = math.max(6, (size or 0) * targetScale)
    local scaledOffsetX = (offsetX or 0) * targetScale
    local scaledOffsetY = (offsetY or 0) * targetScale
    if texture.__BIGFRegion ~= region or texture.__BIGFSize ~= scaledSize or texture.__BIGFOffsetX ~= scaledOffsetX or texture.__BIGFOffsetY ~= scaledOffsetY then
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", region, "CENTER", scaledOffsetX, scaledOffsetY)
        texture:SetSize(scaledSize, scaledSize)
        texture.__BIGFRegion = region
        texture.__BIGFSize = scaledSize
        texture.__BIGFOffsetX = scaledOffsetX
        texture.__BIGFOffsetY = scaledOffsetY
    end
end

local function HideTexture(texture)
    if texture then
        texture:Hide()
    end
end

local function GetBlizzardJunkIcon(button)
    if not button then
        return nil
    end

    if button.JunkIcon then
        return button.JunkIcon
    end

    local name = button.GetName and button:GetName() or nil
    if type(name) == "string" and name ~= "" then
        return _G[name .. "JunkIcon"]
    end

    return nil
end

local function SetBlizzardJunkIconSuppressed(button, suppressed)
    local texture = GetBlizzardJunkIcon(button)
    if not texture then
        return
    end

    if suppressed then
        if texture.__BIGFOriginalAlpha == nil and texture.GetAlpha then
            texture.__BIGFOriginalAlpha = texture:GetAlpha()
        end
        if texture.SetAlpha then
            texture:SetAlpha(0)
        end
        if texture.Hide then
            texture:Hide()
        end
        texture.__BIGFJunkIconSuppressed = true
        return
    end

    if texture.__BIGFJunkIconSuppressed then
        if texture.SetAlpha then
            texture:SetAlpha(texture.__BIGFOriginalAlpha or 1)
        end
        texture.__BIGFJunkIconSuppressed = nil
    end
end


local function GetEquipLocFromItem(itemInfoValue, itemID)
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
        local cached = equipLocCacheByItemID[itemID]
        if cached ~= nil then
            return cached ~= false and cached or nil
        end
    end

    if not itemInfoValue or type(GetItemInfoInstant) ~= "function" then
        return nil
    end

    local _, _, _, equipLoc = GetItemInfoInstant(itemInfoValue)
    if type(equipLoc) == "string" and equipLoc ~= "" then
        if itemID and itemID > 0 then
            equipLocCacheByItemID[itemID] = equipLoc
        end
        return equipLoc
    end

    if itemID and itemID > 0 then
        equipLocCacheByItemID[itemID] = false
    end
    return nil
end

local function IsTwoHandEquipLoc(equipLoc)
    return equipLoc == "INVTYPE_2HWEAPON"
end

local function GetEquippedEquipLoc(slotID)
    if type(GetInventoryItemLink) ~= "function" then
        return nil
    end

    local itemLink = GetInventoryItemLink("player", slotID)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    return GetEquipLocFromItem(itemLink)
end

local function GetWeaponComparisonSlots(equipLoc)
    local slotList = EQUIP_LOC_TO_SLOTS[equipLoc]
    if type(slotList) ~= "table" then
        return nil
    end

    local mainHandIsTwoHand = IsTwoHandEquipLoc(GetEquippedEquipLoc(SLOT_MAIN_HAND))
    local offHandIsTwoHand = IsTwoHandEquipLoc(GetEquippedEquipLoc(SLOT_OFF_HAND))

    if equipLoc == "INVTYPE_WEAPON" then
        if mainHandIsTwoHand then
            return { SLOT_MAIN_HAND }
        end
        return slotList
    end

    if equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_SHIELD" then
        if mainHandIsTwoHand then
            return nil
        end
        return slotList
    end

    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN" then
        return { SLOT_MAIN_HAND }
    end

    if offHandIsTwoHand then
        return { SLOT_MAIN_HAND }
    end

    return slotList
end

local function GetItemInfoValue(snapshot)
    if not snapshot then
        return nil
    end
    return snapshot.itemLink or snapshot.itemID
end

local function GetEquipLoc(snapshot)
    if not snapshot then
        return nil
    end

    return GetEquipLocFromItem(GetItemInfoValue(snapshot), snapshot.itemID)
end

local function GetEquippedItemLevel(slotID)
    slotID = tonumber(slotID)
    if not slotID or slotID <= 0 then
        return nil
    end

    local cachedLevel = equippedItemLevelCache[slotID]
    if cachedLevel ~= nil then
        return cachedLevel or nil
    end

    if ItemLocation and C_Item and C_Item.GetCurrentItemLevel then
        local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
        if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
            if not C_Item.DoesItemExist or C_Item.DoesItemExist(itemLocation) then
                local itemLevel = NS.TryCall("IconRenderer.GetEquippedItemLevel", C_Item.GetCurrentItemLevel, itemLocation)
                if type(itemLevel) == "number" and itemLevel > 0 then
                    equippedItemLevelCache[slotID] = itemLevel
                    return itemLevel
                end
            end
        end
    end

    if type(GetInventoryItemLink) == "function" and type(GetDetailedItemLevelInfo) == "function" then
        local itemLink = GetInventoryItemLink("player", slotID)
        if type(itemLink) == "string" and itemLink ~= "" then
            local itemLevel = GetDetailedItemLevelInfo(itemLink)
            if type(itemLevel) == "number" and itemLevel > 0 then
                equippedItemLevelCache[slotID] = itemLevel
                return itemLevel
            end
        end
    end

    equippedItemLevelCache[slotID] = false
    return nil
end

local function GetItemLevel(snapshot)
    if not snapshot then
        return nil
    end

    local itemLevel = tonumber(snapshot.itemLevel)
    if itemLevel and itemLevel > 0 then
        return itemLevel
    end

    local itemInfoValue = GetItemInfoValue(snapshot)
    if itemInfoValue and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemInfoValue)
        if type(itemLevel) == "number" and itemLevel > 0 then
            return itemLevel
        end
    end

    return nil
end

local function IsAppropriateUpgradeItem(snapshot)
    if not snapshot then
        return false
    end

    if not LAI or type(LAI.IsAppropriate) ~= "function" then
        return true
    end

    local itemRef = snapshot.itemID or snapshot.itemLink
    if not itemRef then
        return false
    end

    local appropriate = NS.TryCall("IconRenderer.IsAppropriate", LAI.IsAppropriate, LAI, itemRef)
    return appropriate == true
end

local function ShouldShowUpgradeIcon(snapshot, config)
    if not config or not config.iconsSectionEnabled or not config.upgradeIconEnabled then
        return false
    end

    if not snapshot or not snapshot.itemLink or not snapshot.isEquippable then
        return false
    end

    if not IsAppropriateUpgradeItem(snapshot) then
        return false
    end

    if C_Item and type(C_Item.GetItemInfo) == "function" then
        local itemInfo = NS.TryCall("IconRenderer.GetItemInfo", C_Item.GetItemInfo, snapshot.itemLink or snapshot.itemID)
        if type(itemInfo) == "table" and type(itemInfo.requiredLevel) == "number" and itemInfo.requiredLevel > UnitLevel("player") then
            return false
        end
    end

    local itemLevel = GetItemLevel(snapshot)
    if not itemLevel then
        return false
    end

    local equipLoc = GetEquipLoc(snapshot)
    if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then
        return false
    end

    local slotList = GetWeaponComparisonSlots(equipLoc)
    if type(slotList) ~= "table" then
        return false
    end

    for _, slotID in ipairs(slotList) do
        local equippedLink = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slotID) or nil
        local equippedItemLevel = GetEquippedItemLevel(slotID)
        if not equippedLink then
            return true
        end
        if equippedItemLevel and itemLevel > equippedItemLevel then
            return true
        end
    end

    return false
end

local function GetTransmogSourceID(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" or not C_TransmogCollection or type(C_TransmogCollection.GetItemInfo) ~= "function" then
        return nil
    end

    local cached = transmogSourceCacheByLink[itemLink]
    if type(cached) == "number" and cached > 0 then
        return cached
    end

    local _, sourceID = NS.TryCall("IconRenderer.GetTransmogSourceID", C_TransmogCollection.GetItemInfo, itemLink)
    if type(sourceID) == "number" and sourceID > 0 then
        transmogSourceCacheByLink[itemLink] = sourceID
        return sourceID
    end

    return nil
end

local function CanCollectTransmogSource(sourceID)
    if type(sourceID) ~= "number" or sourceID <= 0 or not C_TransmogCollection then
        return false
    end

    local cached = transmogCollectableCacheBySourceID[sourceID]
    if cached ~= nil then
        return cached
    end

    local uncertain = false

    if type(C_TransmogCollection.AccountCanCollectSource) == "function" then
        local hasItemData, canCollect = NS.TryCall("IconRenderer.AccountCanCollectSource", C_TransmogCollection.AccountCanCollectSource, sourceID)
        if hasItemData == true and canCollect ~= nil then
            local result = canCollect == true
            transmogCollectableCacheBySourceID[sourceID] = result
            return result
        elseif hasItemData == false then
            uncertain = true
        end
    end

    if type(C_TransmogCollection.PlayerCanCollectSource) == "function" then
        local hasItemData, canCollect = NS.TryCall("IconRenderer.PlayerCanCollectSource", C_TransmogCollection.PlayerCanCollectSource, sourceID)
        if hasItemData == true and canCollect ~= nil then
            local result = canCollect == true
            transmogCollectableCacheBySourceID[sourceID] = result
            return result
        elseif hasItemData == false then
            uncertain = true
        end
    end

    if type(C_TransmogCollection.GetSourceInfo) == "function" then
        local sourceInfo = NS.TryCall("IconRenderer.GetSourceInfo", C_TransmogCollection.GetSourceInfo, sourceID)
        if type(sourceInfo) == "table" and sourceInfo.isCollected ~= nil then
            local result = sourceInfo.isCollected ~= true
            transmogCollectableCacheBySourceID[sourceID] = result
            return result
        end
    end

    if uncertain then
        return false
    end

    return false
end

local function ShouldShowTransmogIcon(snapshot, config)
    if not config or not config.iconsSectionEnabled or not config.transmogIconEnabled then
        return false
    end

    if not snapshot or not snapshot.itemLink or not snapshot.isEquippable or not C_TransmogCollection then
        return false
    end

    local sourceID = GetTransmogSourceID(snapshot.itemLink)
    if not sourceID or not CanCollectTransmogSource(sourceID) then
        return false
    end

    if type(C_TransmogCollection.GetAppearanceSourceInfo) == "function" then
        local result1, _, _, _, result5 = NS.TryCall("IconRenderer.GetAppearanceSourceInfo", C_TransmogCollection.GetAppearanceSourceInfo, sourceID)
        if type(result1) == "table" and result1.isCollected ~= nil then
            return result1.isCollected ~= true
        elseif result5 ~= nil then
            return result5 ~= true
        end
    end

    if type(C_TransmogCollection.PlayerHasTransmogByItemInfo) == "function" then
        local hasTransmog = NS.TryCall("IconRenderer.PlayerHasTransmogByItemInfo", C_TransmogCollection.PlayerHasTransmogByItemInfo, snapshot.itemLink)
        if hasTransmog ~= nil then
            return hasTransmog ~= true
        end
    end

    return false
end

local function GetItemString(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    return itemLink:match("|H(item:[^|]+)|h") or itemLink:match("^(item:[^|]+)") or nil
end

local function GetItemEnchantID(itemLink)
    local itemString = GetItemString(itemLink)
    if not itemString then
        return nil
    end

    local enchantID = itemString:match("^item:[%-]?%d+:([%-]?%d*)")
    if enchantID == nil or enchantID == "" then
        return 0
    end

    return tonumber(enchantID) or 0
end

local function IsEnchantableEquipLoc(equipLoc)
    return type(equipLoc) == "string" and ENCHANTABLE_EQUIP_LOCS[equipLoc] == true
end

local function ShouldShowEnchantIcon(snapshot, config, context)
    if not config or not config.iconsSectionEnabled or not config.enchantIconEnabled then
        return false
    end

    if config.enchantIconCharacterInspectOnly and context ~= "character" and context ~= "inspect" then
        return false
    end

    if not snapshot or not snapshot.itemLink or not snapshot.isEquippable then
        return false
    end

    local equipLoc = GetEquipLoc(snapshot)
    if not IsEnchantableEquipLoc(equipLoc) then
        return false
    end

    local enchantID = GetItemEnchantID(snapshot.itemLink)
    if enchantID == nil then
        return false
    end

    return enchantID <= 0
end

function IconRenderer.PrepareButton(button)
    return button
end

function IconRenderer.InvalidateCaches(reason)
    if reason == "PLAYER_EQUIPMENT_CHANGED" or reason == "TRANSMOG_COLLECTION_UPDATED" or reason == "PLAYER_ENTERING_WORLD" then
        wipe(equippedItemLevelCache)
    end

    if reason == "TRANSMOG_COLLECTION_UPDATED" then
        wipe(transmogSourceCacheByLink)
        wipe(transmogCollectableCacheBySourceID)
    end
end

function IconRenderer.Hide(button)
    local state = stateByButton[button]
    if not state then
        return
    end

    HideTexture(state.junkIcon)
    HideTexture(state.upgradeIcon)
    HideTexture(state.transmogIcon)
    HideTexture(state.questIcon)
    HideTexture(state.enchantIcon)
    SetBlizzardJunkIconSuppressed(button, false)
end

function IconRenderer.Apply(button, snapshot, config, context)
    if not button or not config or not config.iconsSectionEnabled then
        IconRenderer.Hide(button)
        return
    end

    local poorQuality = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
    local showJunk = config.junkIconEnabled and snapshot and snapshot.quality == poorQuality
    local showUpgrade = ShouldShowUpgradeIcon(snapshot, config)
    local showTransmog = ShouldShowTransmogIcon(snapshot, config)
    local showQuest = config.questIconEnabled and snapshot and snapshot.isQuestItem == true
    local showEnchant = ShouldShowEnchantIcon(snapshot, config, context)

    local state = stateByButton[button]

    SetBlizzardJunkIconSuppressed(button, showJunk == true)

    if showJunk then
        local texture = EnsureIconTexture(button, "junkIcon", "Front-Gold-Icon", 1)
        UpdateIconLayout(texture, button, config.junkIconSize, config.junkIconOffsetX, config.junkIconOffsetY)
        texture:Show()
    elseif state then
        HideTexture(state.junkIcon)
    end

    if showUpgrade then
        local texture = EnsureIconTexture(button, "upgradeIcon", "bags-greenarrow", 2)
        UpdateIconLayout(texture, button, config.upgradeIconSize, config.upgradeIconOffsetX, config.upgradeIconOffsetY)
        texture:Show()
    elseif state then
        HideTexture(state.upgradeIcon)
    end

    if showTransmog then
        local texture = EnsureIconTexture(button, "transmogIcon", "lootroll-icon-transmog", 3)
        UpdateIconLayout(texture, button, config.transmogIconSize, config.transmogIconOffsetX, config.transmogIconOffsetY)
        texture:Show()
    elseif state then
        HideTexture(state.transmogIcon)
    end

    if showQuest then
        local texture = EnsureIconTexture(button, "questIcon", "Crosshair_Quest_32", 4)
        UpdateIconLayout(texture, button, config.questIconSize, config.questIconOffsetX, config.questIconOffsetY)
        texture:Show()
    elseif state then
        HideTexture(state.questIcon)
    end

    if showEnchant then
        local texture = EnsureIconTexture(button, "enchantIcon", "worldquest-icon-firstaid", 5)
        UpdateIconLayout(texture, button, config.enchantIconSize, config.enchantIconOffsetX, config.enchantIconOffsetY)
        texture:Show()
    elseif state then
        HideTexture(state.enchantIcon)
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
driver:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function(_, event)
    IconRenderer.InvalidateCaches(event)
    if NS.ItemDataStore and NS.ItemDataStore.PreloadEquippedItems and (event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD") then
        NS.ItemDataStore.PreloadEquippedItems()
    end
    if NS.Invalidation and NS.Invalidation.OnDynamicChanged then
        NS.Invalidation.OnDynamicChanged(event)
    elseif NS.Renderer and NS.Renderer.InvalidateDynamicState then
        NS.Renderer.InvalidateDynamicState()
    end
end)
