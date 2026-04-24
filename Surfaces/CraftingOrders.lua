local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.CraftingOrders = NS.Surfaces.CraftingOrders or {}
local Surface = NS.Surfaces.CraftingOrders

local initialized = false
local hooksInstalled = false
local loaderFrame = nil
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil
local knownButtons = setmetatable({}, { __mode = "k" })

local WATCHED_ADDONS = {
    Blizzard_ProfessionsCustomerOrders = true,
    Blizzard_ProfessionsTemplates = true,
}
local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function IsFrameVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible()
end

local function GetParent(frame)
    return frame and frame.GetParent and frame:GetParent() or nil
end

local function HasAncestor(frame, target)
    local current = frame
    while current do
        if current == target then
            return true
        end
        current = GetParent(current)
    end

    return false
end

local function GetOrdersFrame()
    return _G.ProfessionsCustomerOrdersFrame
end

local function GetOrdersForm()
    local frame = GetOrdersFrame()
    return frame and frame.Form or nil
end

local function IsOrdersForm(form)
    local ordersForm = GetOrdersForm()
    return form ~= nil and form == ordersForm
end

local function IsOrdersSlot(slot)
    local form = GetOrdersForm()
    if not (slot and form) then
        return false
    end

    return HasAncestor(slot, form)
end

local function IsOrdersButton(button)
    local form = GetOrdersForm()
    return button ~= nil and form ~= nil and HasAncestor(button, form)
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
    config.craftingOrdersEnabled = baseConfig.craftingOrdersEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function TrackButton(button)
    if button then
        knownButtons[button] = true
    end
end

local function GetValidLink(link)
    if type(link) == "string" and link ~= "" then
        return link
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

local function GetQualityFromLinkOrItemID(itemLink, itemID)
    if type(GetItemInfo) ~= "function" then
        return nil
    end

    local itemInfoValue = itemLink or itemID
    if not itemInfoValue then
        return nil
    end

    local _, _, quality = GetItemInfo(itemInfoValue)
    return NormalizeQuality(quality)
end

local function GetQualityFromButtonBorder(button)
    local border = button and (button.IconBorder or button.iconBorder or button.ProfessionQualityOverlay) or nil
    if not (border and border.GetVertexColor and ITEM_QUALITY_COLORS) then
        return nil
    end

    local r, g, b = border:GetVertexColor()
    if not r then
        return nil
    end

    for quality, color in pairs(ITEM_QUALITY_COLORS) do
        local dr = math.abs((color.r or 0) - r)
        local dg = math.abs((color.g or 0) - g)
        local db = math.abs((color.b or 0) - b)
        if dr <= 0.02 and dg <= 0.02 and db <= 0.02 then
            return quality
        end
    end

    return nil
end

local function GetCurrencyQuality(currencyID)
    if not (currencyID and C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function") then
        return nil
    end

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    return currencyInfo and NormalizeQuality(currencyInfo.quality) or nil
end

local function GetSlotID(slot)
    if not slot then
        return nil
    end

    local schematic = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic() or nil
    if schematic and schematic.slotInfo and schematic.slotInfo.mcrSlotID then
        return schematic.slotInfo.mcrSlotID
    end

    if slot.reagentSlotSchematic and slot.reagentSlotSchematic.slotInfo and slot.reagentSlotSchematic.slotInfo.mcrSlotID then
        return slot.reagentSlotSchematic.slotInfo.mcrSlotID
    end

    if slot.slotInfo and slot.slotInfo.mcrSlotID then
        return slot.slotInfo.mcrSlotID
    end

    return nil
end

local function GetSlotIndex(slot)
    if not slot then
        return nil
    end

    if slot.GetSlotIndex then
        local slotIndex = slot:GetSlotIndex()
        if slotIndex ~= nil then
            return slotIndex
        end
    end

    local schematic = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic() or nil
    if schematic and schematic.slotIndex ~= nil then
        return schematic.slotIndex
    end

    if slot.reagentSlotSchematic and slot.reagentSlotSchematic.slotIndex ~= nil then
        return slot.reagentSlotSchematic.slotIndex
    end

    return slot.slotIndex
end

local function GetOrderSkillLineAbilityID(form)
    if not form then
        return nil
    end

    local order = form.GetOrder and form:GetOrder() or nil
    if order and order.spellID then
        return order.spellID
    end

    if form.orderInfo and form.orderInfo.spellID then
        return form.orderInfo.spellID
    end

    return nil
end

local function GetObjectReagent(object)
    if not object then
        return nil
    end

    if object.GetReagent then
        local reagent = object:GetReagent()
        if reagent then
            return reagent
        end
    end

    return object.reagent
end

local function BuildReagentEntryFromReagent(slot, button, reagent)
    if not reagent then
        return nil
    end

    local form = GetOrdersForm()
    local itemLink = GetValidLink(reagent.itemLink or reagent.hyperlink)
    local itemID = reagent.itemID
    local currencyID = reagent.currencyID
    local quality = NormalizeQuality(reagent.quality)
        or GetCurrencyQuality(currencyID)
        or GetQualityFromLinkOrItemID(itemLink, itemID)
        or GetQualityFromButtonBorder(button)

    return {
        kind = "reagent",
        slotID = GetSlotID(slot),
        slotIndex = GetSlotIndex(slot),
        skillLineAbilityID = GetOrderSkillLineAbilityID(form),
        itemLink = itemLink,
        itemID = itemID,
        currencyID = currencyID,
        quality = quality,
        stackCount = 0,
        hasNoValue = false,
        isQuestItem = false,
        lightweight = not itemLink and not itemID,
    }
end

local function BuildSlotEntry(slot)
    if not (slot and IsOrdersSlot(slot)) then
        return nil
    end

    local button = slot.Button or slot
    local reagent = GetObjectReagent(slot) or GetObjectReagent(button)
    return BuildReagentEntryFromReagent(slot, button, reagent)
end

local function BuildLightweightSnapshot(entry)
    if not entry then
        return nil
    end

    return {
        itemLink = entry.itemLink,
        itemID = entry.itemID,
        quality = entry.quality,
        stackCount = entry.stackCount or 0,
        itemLevel = nil,
        hasNoValue = entry.hasNoValue == true,
        isQuestItem = entry.isQuestItem == true,
        junkIcon = false,
        upgradeIcon = false,
        transmogIcon = false,
        enchantIcon = false,
        borderHoverEnabled = true,
        pending = false,
    }
end

local function StoreButtonInfo(button, info)
    if button then
        button.__BlizzItemGlowFixCraftingOrdersInfo = info
        TrackButton(button)
    end
end

local function GetStoredButtonInfo(button)
    return button and button.__BlizzItemGlowFixCraftingOrdersInfo or nil
end

local function ResolveCurrentEntry(button)
    if not IsOrdersButton(button) then
        return nil
    end

    local info = GetStoredButtonInfo(button)
    if not info then
        return nil
    end

    if info.slot then
        return BuildSlotEntry(info.slot)
    end

    return nil
end

local function ResetEarlySignature(button)
    if not button then
        return
    end

    button.__BlizzItemGlowFixCraftingOrdersSigKind = nil
    button.__BlizzItemGlowFixCraftingOrdersSigSlotID = nil
    button.__BlizzItemGlowFixCraftingOrdersSigSlotIndex = nil
    button.__BlizzItemGlowFixCraftingOrdersSigSkillLineAbilityID = nil
    button.__BlizzItemGlowFixCraftingOrdersSigItemID = nil
    button.__BlizzItemGlowFixCraftingOrdersSigItemLink = nil
    button.__BlizzItemGlowFixCraftingOrdersSigCurrencyID = nil
    button.__BlizzItemGlowFixCraftingOrdersSigQuality = nil
    button.__BlizzItemGlowFixCraftingOrdersSigStackCount = nil
    button.__BlizzItemGlowFixCraftingOrdersSigConfigVersion = nil
    button.__BlizzItemGlowFixCraftingOrdersSigDynamicVersion = nil
    button.__BlizzItemGlowFixCraftingOrdersSigEmpty = nil
end

local function ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return false
    end

    return button.__BlizzItemGlowFixCraftingOrdersSigKind == (entry and entry.kind or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigSlotID == (entry and entry.slotID or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigSlotIndex == (entry and entry.slotIndex or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigSkillLineAbilityID == (entry and entry.skillLineAbilityID or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigItemID == (entry and entry.itemID or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigItemLink == (entry and entry.itemLink or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigCurrencyID == (entry and entry.currencyID or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigQuality == (entry and entry.quality or nil)
        and button.__BlizzItemGlowFixCraftingOrdersSigStackCount == (entry and (entry.stackCount or 0) or 0)
        and button.__BlizzItemGlowFixCraftingOrdersSigConfigVersion == configVersion
        and button.__BlizzItemGlowFixCraftingOrdersSigDynamicVersion == dynamicVersion
        and button.__BlizzItemGlowFixCraftingOrdersSigEmpty == (entry == nil)
end

local function MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return
    end

    button.__BlizzItemGlowFixCraftingOrdersSigKind = entry and entry.kind or nil
    button.__BlizzItemGlowFixCraftingOrdersSigSlotID = entry and entry.slotID or nil
    button.__BlizzItemGlowFixCraftingOrdersSigSlotIndex = entry and entry.slotIndex or nil
    button.__BlizzItemGlowFixCraftingOrdersSigSkillLineAbilityID = entry and entry.skillLineAbilityID or nil
    button.__BlizzItemGlowFixCraftingOrdersSigItemID = entry and entry.itemID or nil
    button.__BlizzItemGlowFixCraftingOrdersSigItemLink = entry and entry.itemLink or nil
    button.__BlizzItemGlowFixCraftingOrdersSigCurrencyID = entry and entry.currencyID or nil
    button.__BlizzItemGlowFixCraftingOrdersSigQuality = entry and entry.quality or nil
    button.__BlizzItemGlowFixCraftingOrdersSigStackCount = entry and (entry.stackCount or 0) or 0
    button.__BlizzItemGlowFixCraftingOrdersSigConfigVersion = configVersion
    button.__BlizzItemGlowFixCraftingOrdersSigDynamicVersion = dynamicVersion
    button.__BlizzItemGlowFixCraftingOrdersSigEmpty = entry == nil
end

local function BuildSlotKey(entry)
    return table.concat({
        "craftingOrders",
        tostring(entry.kind or "slot"),
        tostring(entry.slotID or 0),
        tostring(entry.slotIndex or 0),
        tostring(entry.skillLineAbilityID or 0),
        tostring(entry.itemID or 0),
        tostring(entry.itemLink or ""),
        tostring(entry.currencyID or 0),
    }, ":")
end

local function ClearButton(button, reason)
    if not button then
        return
    end

    NS.Renderer.ClearButton(button, reason or "surfaceClear")
    StoreButtonInfo(button, nil)
    ResetEarlySignature(button)
end

local function ClearAllButtons(reason)
    for button in pairs(knownButtons) do
        ClearButton(button, reason)
    end
end

local function UpdateButton(button, entry, slot, config)
    if not button then
        return
    end

    config = BuildSurfaceConfig(config)
    if not config or not config.craftingOrdersEnabled then
        ClearButton(button, "craftingOrdersDisabled")
        return
    end

    if not IsOrdersButton(button) then
        ClearButton(button, "craftingOrdersWrongContext")
        return
    end

    if not IsFrameShown(button) or not IsFrameVisible(button) then
        ClearButton(button, "craftingOrdersHidden")
        return
    end

    StoreButtonInfo(button, { slot = slot })

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Invalidation and NS.Invalidation.GetDynamicVersion and NS.Invalidation.GetDynamicVersion() or 0

    if ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion) then
        return
    end

    if not entry then
        ClearButton(button, "craftingOrdersEmpty")
        MarkEarlySignature(button, nil, configVersion, dynamicVersion)
        return
    end

    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local snapshot

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
                if not IsFrameShown(GetOrdersForm()) then
                    ClearButton(button, "craftingOrdersCallbackHidden")
                    return
                end

                local currentEntry = ResolveCurrentEntry(button)
                UpdateButton(button, currentEntry, slot, nil)
            end,
            button
        )
    else
        snapshot = BuildLightweightSnapshot(entry)
    end

    if not snapshot then
        ClearButton(button, "craftingOrdersUnrenderable")
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
        return
    end

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "craftingOrders")

    if snapshot.pending then
        ResetEarlySignature(button)
    else
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    end
end

local function UpdateSlot(slot, config)
    if not (slot and IsOrdersSlot(slot)) then
        return
    end

    local button = slot.Button or slot
    if not button then
        return
    end
    UpdateButton(button, BuildSlotEntry(slot), slot, config)
end

local function EnumerateActiveSlots(form, callback)
    if not (form and callback and form.reagentSlotPool and form.reagentSlotPool.EnumerateActive) then
        return
    end

    for slot in form.reagentSlotPool:EnumerateActive() do
        callback(slot)
    end
end

local function HasVisibleReagentSlots(form)
    if not (form and form.reagentSlotPool and form.reagentSlotPool.EnumerateActive) then
        return false
    end

    for slot in form.reagentSlotPool:EnumerateActive() do
        local button = slot and (slot.Button or slot) or nil
        if button and IsFrameShown(button) then
            return true
        end
    end

    return false
end

local function RefreshVisible(config)
    local form = GetOrdersForm()
    if not IsFrameShown(form) then
        return
    end
    local buttonCount = 0

    config = BuildSurfaceConfig(config)
    if not config or not config.craftingOrdersEnabled then
        ClearAllButtons("craftingOrdersDisabled")
        return
    end

    EnumerateActiveSlots(form, function(slot)
        local button = slot and (slot.Button or slot) or nil
        if button and IsFrameShown(button) then
            buttonCount = buttonCount + 1
            UpdateButton(button, BuildSlotEntry(slot), slot, config)
        end
    end)
end

local function AttachSlotHooks(slot)
    if not (slot and IsOrdersSlot(slot) and type(slot) == "table") then
        return
    end

    if not slot.__BlizzItemGlowFixCraftingOrdersHooked_Update and type(slot.Update) == "function" then
        slot.__BlizzItemGlowFixCraftingOrdersHooked_Update = true
        hooksecurefunc(slot, "Update", function(self)
            UpdateSlot(self, BuildSurfaceConfig())
        end)
    end

    if not slot.__BlizzItemGlowFixCraftingOrdersHooked_SetReagent and type(slot.SetReagent) == "function" then
        slot.__BlizzItemGlowFixCraftingOrdersHooked_SetReagent = true
        hooksecurefunc(slot, "SetReagent", function(self)
            UpdateSlot(self, BuildSurfaceConfig())
        end)
    end

    if not slot.__BlizzItemGlowFixCraftingOrdersHooked_ClearReagent and type(slot.ClearReagent) == "function" then
        slot.__BlizzItemGlowFixCraftingOrdersHooked_ClearReagent = true
        hooksecurefunc(slot, "ClearReagent", function(self)
            UpdateSlot(self, BuildSurfaceConfig())
        end)
    end
end

local function TrackActiveSlots(form)
    EnumerateActiveSlots(form, function(slot)
        AttachSlotHooks(slot)
        local button = slot and (slot.Button or slot) or nil
        if button then
            TrackButton(button)
        end
    end)
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    local form = GetOrdersForm()
    if not form then
        return
    end

    if type(ProfessionsCustomerOrderFormMixin) ~= "table" then
        return
    end

    hooksInstalled = true

    if form.HookScript then
        form:HookScript("OnShow", function(self)
            if not IsOrdersForm(self) then
                return
            end
            TrackActiveSlots(self)
            RefreshVisible(BuildSurfaceConfig())
        end)

        form:HookScript("OnHide", function()
            ClearAllButtons("surfaceClear")
        end)
    end

    hooksecurefunc(ProfessionsCustomerOrderFormMixin, "Init", function(self)
        if not IsOrdersForm(self) then
            return
        end
        TrackActiveSlots(self)
        RefreshVisible(BuildSurfaceConfig())
    end)

    if type(ProfessionsCustomerOrderFormMixin.UpdateReagentSlots) == "function" then
        hooksecurefunc(ProfessionsCustomerOrderFormMixin, "UpdateReagentSlots", function(self)
            if not IsOrdersForm(self) then
                return
            end
            TrackActiveSlots(self)
            RefreshVisible(BuildSurfaceConfig())
        end)
    end

    if type(ProfessionsCustomerOrderFormMixin.SetRecraftItemGUID) == "function" then
        hooksecurefunc(ProfessionsCustomerOrderFormMixin, "SetRecraftItemGUID", function(self)
            if not IsOrdersForm(self) or not IsFrameShown(self) then
                return
            end
            TrackActiveSlots(self)
            RefreshVisible(BuildSurfaceConfig())
        end)
    end

    if type(ProfessionsCustomerOrderFormMixin.SetOrderRecipient) == "function" then
        hooksecurefunc(ProfessionsCustomerOrderFormMixin, "SetOrderRecipient", function(self)
            if not IsOrdersForm(self) or not IsFrameShown(self) then
                return
            end
            TrackActiveSlots(self)
            RefreshVisible(BuildSurfaceConfig())
        end)
    end
end

local function EnsureLoader()
    if loaderFrame then
        return
    end

    loaderFrame = CreateFrame("Frame")
    loaderFrame:RegisterEvent("ADDON_LOADED")
    loaderFrame:SetScript("OnEvent", function(_, _, addonName)
        if WATCHED_ADDONS[addonName] then
            InstallHooks()
            local form = GetOrdersForm()
            if form then
                TrackActiveSlots(form)
                if IsFrameShown(form) and HasVisibleReagentSlots(form) then
                    RefreshVisible(BuildSurfaceConfig())
                end
            end
        end
    end)
end

function Surface.RefreshVisible()
    EnsureLoader()
    InstallHooks()
    RefreshVisible(BuildSurfaceConfig())
end

function Surface.Initialize()
    if initialized then
        return
    end

    initialized = true
    EnsureLoader()
    InstallHooks()
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("craftingOrders", Surface)
end
