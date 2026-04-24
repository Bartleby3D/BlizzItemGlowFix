local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.ProfessionJournal = NS.Surfaces.ProfessionJournal or {}
local Surface = NS.Surfaces.ProfessionJournal

local initialized = false
local hooksInstalled = false
local loaderFrame = nil
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil
local knownButtons = setmetatable({}, { __mode = "k" })

local WATCHED_ADDONS = {
    Blizzard_Professions = true,
    Blizzard_ProfessionsTemplates = true,
}
local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
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

local function GetProfessionsFrame()
    return _G.ProfessionsFrame
end

local function GetCraftingPage()
    local frame = GetProfessionsFrame()
    return frame and frame.CraftingPage or nil
end

local function GetSchematicForm()
    local page = GetCraftingPage()
    return page and page.SchematicForm or nil
end
local function IsJournalSlot(slot)
    local form = GetSchematicForm()
    if not (slot and form) then
        return false
    end

    return slot == form.enchantSlot
        or slot == form.salvageSlot
        or slot == form.recraftSlot
        or HasAncestor(slot, form)
end

local function IsJournalButton(button)
    if not button then
        return false
    end

    local page = GetCraftingPage()
    if page and type(page.InventorySlots) == "table" then
        for _, inventorySlot in ipairs(page.InventorySlots) do
            if inventorySlot == button then
                return true
            end
        end
    end

    local form = GetSchematicForm()
    if form and HasAncestor(button, form) then
        return true
    end

    return false
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
    config.professionJournalEnabled = baseConfig.professionJournalEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function TrackButton(button)
    if not button then
        return
    end

    knownButtons[button] = true
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

local function BuildReagentEntryFromReagent(slot, button, reagent)
    if not reagent then
        return nil
    end

    local transaction = slot and slot.GetTransaction and slot:GetTransaction() or nil
    local recipeID = transaction and transaction.GetRecipeID and transaction:GetRecipeID() or nil
    local slotIndex = slot and slot.GetSlotIndex and slot:GetSlotIndex() or nil
    local currencyID = reagent.currencyID
    local itemLink = GetValidLink(reagent.itemLink or reagent.hyperlink)
    local itemID = reagent.itemID
    local quality = NormalizeQuality(reagent.quality)
        or GetCurrencyQuality(currencyID)
        or GetQualityFromLinkOrItemID(itemLink, itemID)
        or GetQualityFromButtonBorder(button)

    return {
        kind = "reagent",
        recipeID = recipeID,
        slotIndex = slotIndex,
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

local function BuildReagentEntry(slot)
    if not (slot and IsJournalSlot(slot)) then
        return nil
    end

    local button = slot.Button
    if not button then
        return nil
    end

    local reagent = slot.GetReagent and slot:GetReagent() or nil
    if not reagent and button.GetReagent then
        reagent = button:GetReagent()
    end

    return BuildReagentEntryFromReagent(slot, button, reagent)
end

local function GetItemObjectLink(item)
    if not item then
        return nil
    end

    if item.GetItemLink then
        return GetValidLink(item:GetItemLink())
    end

    return nil
end

local function GetItemObjectID(item)
    if not item then
        return nil
    end

    if item.GetItemID then
        return item:GetItemID()
    end

    return nil
end

local function GetItemObjectStackCount(item)
    if not item then
        return 0
    end

    if item.GetStackCount then
        local count = item:GetStackCount()
        count = tonumber(count)
        if count and count > 0 then
            return count
        end
    end

    return 0
end

local function GetItemObjectQuality(item, button)
    if not item then
        return GetQualityFromButtonBorder(button)
    end

    if item.GetItemQuality then
        local quality = NormalizeQuality(item:GetItemQuality())
        if quality ~= nil then
            return quality
        end
    end

    local itemLink = GetItemObjectLink(item)
    local itemID = GetItemObjectID(item)
    return GetQualityFromLinkOrItemID(itemLink, itemID) or GetQualityFromButtonBorder(button)
end

local function BuildItemObjectEntry(kind, recipeID, slotIndex, button, item)
    if not button then
        return nil
    end

    if not item then
        return nil
    end

    local itemLink = GetItemObjectLink(item)
    local itemID = GetItemObjectID(item)
    local quality = GetItemObjectQuality(item, button)

    if not itemLink and not itemID and quality == nil then
        return nil
    end

    return {
        kind = kind,
        recipeID = recipeID,
        slotIndex = slotIndex,
        itemLink = itemLink,
        itemID = itemID,
        quality = quality,
        stackCount = GetItemObjectStackCount(item),
        hasNoValue = false,
        isQuestItem = false,
        lightweight = not itemLink and not itemID,
    }
end

local function GetCurrentRecipeID()
    local form = GetSchematicForm()
    local recipeInfo = form and form.GetRecipeInfo and form:GetRecipeInfo() or nil
    return recipeInfo and recipeInfo.recipeID or nil
end

local function BuildEnchantEntry(slot)
    if not (slot and IsJournalSlot(slot)) then
        return nil
    end

    return BuildItemObjectEntry("enchant", GetCurrentRecipeID(), nil, slot.Button, slot.allocationItem)
end

local function BuildSalvageEntry(slot)
    if not (slot and IsJournalSlot(slot)) then
        return nil
    end

    return BuildItemObjectEntry("salvage", GetCurrentRecipeID(), nil, slot.Button, slot.allocationItem)
end

local function BuildRecraftEntry(kind, button, item)
    if not (button and IsJournalButton(button)) then
        return nil
    end

    local form = GetSchematicForm()
    local recipeInfo = form and form.GetRecipeInfo and form:GetRecipeInfo() or nil
    local recipeID = recipeInfo and recipeInfo.recipeID or nil
    return BuildItemObjectEntry(kind, recipeID, nil, button, item)
end

local function BuildGearEntry(slotID)
    slotID = tonumber(slotID)
    if not slotID or slotID <= 0 then
        return nil
    end

    if type(GetInventoryItemLink) ~= "function" or type(GetInventoryItemID) ~= "function" then
        return nil
    end

    local itemLink = GetInventoryItemLink("player", slotID)
    local itemID = GetInventoryItemID("player", slotID)
    if not itemLink and not itemID then
        return nil
    end

    local quality = nil
    if type(GetInventoryItemQuality) == "function" then
        quality = NormalizeQuality(GetInventoryItemQuality("player", slotID))
    end
    quality = quality or GetQualityFromLinkOrItemID(itemLink, itemID)

    return {
        kind = "gear",
        slotID = slotID,
        itemLink = itemLink,
        itemID = itemID,
        quality = quality,
        stackCount = 0,
        hasNoValue = false,
        isQuestItem = false,
        lightweight = false,
    }
end

local function MakeButtonInfoFromEntry(entry, owner)
    if not entry then
        return nil
    end

    return {
        kind = entry.kind,
        owner = owner,
        slotID = entry.slotID,
        recipeID = entry.recipeID,
        slotIndex = entry.slotIndex,
        itemLink = entry.itemLink,
        itemID = entry.itemID,
        quality = entry.quality,
        stackCount = entry.stackCount or 0,
        hasNoValue = entry.hasNoValue == true,
        isQuestItem = entry.isQuestItem == true,
        lightweight = entry.lightweight == true,
    }
end

local function SetButtonInfo(button, info)
    if button then
        button.__BlizzItemGlowFixProfessionJournalInfo = info
    end
end

local function GetButtonInfo(button)
    return button and button.__BlizzItemGlowFixProfessionJournalInfo or nil
end

local function ResetEarlySignature(button)
    if not button then
        return
    end

    button.__BlizzItemGlowFixProfessionJournalSigKind = nil
    button.__BlizzItemGlowFixProfessionJournalSigSlotID = nil
    button.__BlizzItemGlowFixProfessionJournalSigRecipeID = nil
    button.__BlizzItemGlowFixProfessionJournalSigSlotIndex = nil
    button.__BlizzItemGlowFixProfessionJournalSigItemID = nil
    button.__BlizzItemGlowFixProfessionJournalSigItemLink = nil
    button.__BlizzItemGlowFixProfessionJournalSigQuality = nil
    button.__BlizzItemGlowFixProfessionJournalSigStackCount = nil
    button.__BlizzItemGlowFixProfessionJournalSigConfigVersion = nil
    button.__BlizzItemGlowFixProfessionJournalSigDynamicVersion = nil
    button.__BlizzItemGlowFixProfessionJournalSigEmpty = nil
end

local function ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return false
    end

    local isEmpty = entry == nil
    return button.__BlizzItemGlowFixProfessionJournalSigKind == (entry and entry.kind or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigSlotID == (entry and entry.slotID or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigRecipeID == (entry and entry.recipeID or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigSlotIndex == (entry and entry.slotIndex or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigItemID == (entry and entry.itemID or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigItemLink == (entry and entry.itemLink or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigQuality == (entry and entry.quality or nil)
        and button.__BlizzItemGlowFixProfessionJournalSigStackCount == (entry and (entry.stackCount or 0) or 0)
        and button.__BlizzItemGlowFixProfessionJournalSigConfigVersion == configVersion
        and button.__BlizzItemGlowFixProfessionJournalSigDynamicVersion == dynamicVersion
        and button.__BlizzItemGlowFixProfessionJournalSigEmpty == isEmpty
end

local function MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    if not button then
        return
    end

    button.__BlizzItemGlowFixProfessionJournalSigKind = entry and entry.kind or nil
    button.__BlizzItemGlowFixProfessionJournalSigSlotID = entry and entry.slotID or nil
    button.__BlizzItemGlowFixProfessionJournalSigRecipeID = entry and entry.recipeID or nil
    button.__BlizzItemGlowFixProfessionJournalSigSlotIndex = entry and entry.slotIndex or nil
    button.__BlizzItemGlowFixProfessionJournalSigItemID = entry and entry.itemID or nil
    button.__BlizzItemGlowFixProfessionJournalSigItemLink = entry and entry.itemLink or nil
    button.__BlizzItemGlowFixProfessionJournalSigQuality = entry and entry.quality or nil
    button.__BlizzItemGlowFixProfessionJournalSigStackCount = entry and (entry.stackCount or 0) or 0
    button.__BlizzItemGlowFixProfessionJournalSigConfigVersion = configVersion
    button.__BlizzItemGlowFixProfessionJournalSigDynamicVersion = dynamicVersion
    button.__BlizzItemGlowFixProfessionJournalSigEmpty = entry == nil
end

local function BuildSlotKey(entry)
    if not entry then
        return nil
    end

    if entry.kind == "gear" then
        return table.concat({ "professionJournal", "gear", tostring(entry.slotID or 0) }, ":")
    end

    return table.concat({
        "professionJournal",
        tostring(entry.kind or ""),
        tostring(entry.recipeID or 0),
        tostring(entry.slotIndex or 0),
    }, ":")
end

local function BuildLightweightSnapshot(entry)
    if not entry then
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
    for button in pairs(knownButtons) do
        ClearButton(button, reason)
    end
end

local function ResolveCurrentEntry(button)
    local info = GetButtonInfo(button)
    if not info then
        return nil
    end

    if info.kind == "gear" then
        return BuildGearEntry(info.slotID)
    elseif info.kind == "reagent" then
        return BuildReagentEntry(info.owner)
    elseif info.kind == "enchant" then
        return BuildEnchantEntry(info.owner)
    elseif info.kind == "salvage" then
        return BuildSalvageEntry(info.owner)
    elseif info.kind == "recraftInput" or info.kind == "recraftOutput" then
        return {
            kind = info.kind,
            recipeID = info.recipeID,
            itemLink = info.itemLink,
            itemID = info.itemID,
            quality = info.quality,
            stackCount = info.stackCount or 0,
            hasNoValue = info.hasNoValue == true,
            isQuestItem = info.isQuestItem == true,
            lightweight = info.lightweight == true,
        }
    end

    return nil
end

local function UpdateButton(button, entry, owner, config)
    if not button then
        return
    end

    TrackButton(button)

    config = BuildSurfaceConfig(config)
    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Renderer and NS.Renderer._dynamicVersion or 0

    SetButtonInfo(button, MakeButtonInfoFromEntry(entry, owner))

    if not config or not config.professionJournalEnabled then
        ClearButton(button, "professionJournalDisabled")
        return
    end

    if not IsJournalButton(button) then
        ClearButton(button, "professionJournalWrongContext")
        return
    end

    if ShouldSkipByEarlySignature(button, entry, configVersion, dynamicVersion) then
        return
    end

    if not entry then
        ClearButton(button, "professionJournalEmpty")
        MarkEarlySignature(button, nil, configVersion, dynamicVersion)
        return
    end

    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local snapshot

    if entry.kind == "gear" then
        snapshot = NS.ItemDataStore.GetInventorySlotSnapshot(
            "player",
            entry.slotID,
            wantItemLevel,
            function()
                if not IsFrameShown(GetCraftingPage()) then
                    ClearButton(button, "professionJournalCallbackHidden")
                    return
                end

                local currentEntry = ResolveCurrentEntry(button)
                UpdateButton(button, currentEntry, nil, nil)
            end,
            button
        )
    elseif entry.itemLink or entry.itemID then
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
                if not IsFrameShown(GetCraftingPage()) then
                    ClearButton(button, "professionJournalCallbackHidden")
                    return
                end

                local currentEntry = ResolveCurrentEntry(button)
                UpdateButton(button, currentEntry, nil, nil)
            end,
            button
        )
    else
        snapshot = BuildLightweightSnapshot(entry)
    end

    if not snapshot then
        ClearButton(button, "professionJournalUnrenderable")
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
        return
    end

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "professionJournal")

    if snapshot.pending then
        ResetEarlySignature(button)
    else
        MarkEarlySignature(button, entry, configVersion, dynamicVersion)
    end
end

local function UpdateReagentSlot(slot, config)
    if not (slot and IsJournalSlot(slot) and slot.Button) then
        return
    end
    UpdateButton(slot.Button, BuildReagentEntry(slot), slot, config)
end

local function UpdateEnchantSlot(slot, config)
    if not (slot and IsJournalSlot(slot) and slot.Button) then
        return
    end
    UpdateButton(slot.Button, BuildEnchantEntry(slot), slot, config)
end

local function UpdateSalvageSlot(slot, config)
    if not (slot and IsJournalSlot(slot) and slot.Button) then
        return
    end
    UpdateButton(slot.Button, BuildSalvageEntry(slot), slot, config)
end

local function UpdateRecraftInputButton(button, item, config)
    if not (button and IsJournalButton(button)) then
        return
    end
    UpdateButton(button, BuildRecraftEntry("recraftInput", button, item), nil, config)
end

local function UpdateRecraftOutputButton(button, item, config)
    if not (button and IsJournalButton(button)) then
        return
    end
    UpdateButton(button, BuildRecraftEntry("recraftOutput", button, item), nil, config)
end

local function GetGearSlotID(button)
    if not button then
        return nil
    end

    local slotID = button.slotID or (button.GetID and button:GetID()) or nil
    slotID = tonumber(slotID)
    if slotID and slotID > 0 then
        return slotID
    end

    return nil
end

local function IsJournalGearButton(button)
    local page = GetCraftingPage()
    if not (button and page and type(page.InventorySlots) == "table") then
        return false
    end

    for _, inventorySlot in ipairs(page.InventorySlots) do
        if inventorySlot == button then
            return true
        end
    end

    return false
end

local function UpdateGearButton(button, config)
    if not IsJournalGearButton(button) then
        return
    end
    UpdateButton(button, BuildGearEntry(GetGearSlotID(button)), nil, config)
end

local function RefreshVisible(config)
    local page = GetCraftingPage()
    if not IsFrameShown(page) then
        return
    end
    local buttonCount = 0

    config = BuildSurfaceConfig(config)
    if not config or not config.professionJournalEnabled then
        ClearAllButtons("professionJournalDisabled")
        return
    end

    local form = GetSchematicForm()
    if IsFrameShown(form) and form.reagentSlotPool and form.reagentSlotPool.EnumerateActive then
        for slot in form.reagentSlotPool:EnumerateActive() do
            if slot and slot.Button then
                buttonCount = buttonCount + 1
                UpdateButton(slot.Button, BuildReagentEntry(slot), slot, config)
            end
        end

        if form.enchantSlot and IsFrameShown(form.enchantSlot) and form.enchantSlot.Button then
            buttonCount = buttonCount + 1
            UpdateButton(form.enchantSlot.Button, BuildEnchantEntry(form.enchantSlot), form.enchantSlot, config)
        end

        if form.salvageSlot and IsFrameShown(form.salvageSlot) and form.salvageSlot.Button then
            buttonCount = buttonCount + 1
            UpdateButton(form.salvageSlot.Button, BuildSalvageEntry(form.salvageSlot), form.salvageSlot, config)
        end

        if form.recraftSlot and IsFrameShown(form.recraftSlot) then
            if form.recraftSlot.InputSlot and IsFrameShown(form.recraftSlot.InputSlot) then
                buttonCount = buttonCount + 1
                UpdateButton(form.recraftSlot.InputSlot, ResolveCurrentEntry(form.recraftSlot.InputSlot), nil, config)
            end

            if form.recraftSlot.OutputSlot and IsFrameShown(form.recraftSlot.OutputSlot) then
                buttonCount = buttonCount + 1
                UpdateButton(form.recraftSlot.OutputSlot, ResolveCurrentEntry(form.recraftSlot.OutputSlot), nil, config)
            end
        end
    end

    if type(page.InventorySlots) == "table" then
        for _, inventorySlot in ipairs(page.InventorySlots) do
            if IsFrameShown(inventorySlot) then
                buttonCount = buttonCount + 1
                UpdateButton(inventorySlot, BuildGearEntry(GetGearSlotID(inventorySlot)), nil, config)
            end
        end
    end
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    local page = GetCraftingPage()
    local form = GetSchematicForm()
    if not page or not form then
        return
    end

    if type(ProfessionsReagentSlotMixin) ~= "table" or type(ProfessionsReagentSlotMixin.Update) ~= "function" then
        return
    end
    if type(ProfessionsEnchantSlotMixin) ~= "table" or type(ProfessionsEnchantSlotMixin.Update) ~= "function" then
        return
    end
    if type(ProfessionsSalvageSlotMixin) ~= "table" or type(ProfessionsSalvageSlotMixin.Update) ~= "function" then
        return
    end
    if type(ProfessionsRecraftInputSlotMixin) ~= "table" or type(ProfessionsRecraftInputSlotMixin.Init) ~= "function" then
        return
    end
    if type(ProfessionsRecraftOutputSlotMixin) ~= "table" or type(ProfessionsRecraftOutputSlotMixin.Init) ~= "function" then
        return
    end
    if type(PaperDollItemSlotButton_Update) ~= "function" then
        return
    end

    hooksInstalled = true

    if page.HookScript then
        page:HookScript("OnHide", function()
            ClearAllButtons("surfaceClear")
        end)
    end

    hooksecurefunc(ProfessionsReagentSlotMixin, "Update", function(slot)
        UpdateReagentSlot(slot, BuildSurfaceConfig())
    end)

    hooksecurefunc(ProfessionsEnchantSlotMixin, "Update", function(slot)
        UpdateEnchantSlot(slot, BuildSurfaceConfig())
    end)

    hooksecurefunc(ProfessionsSalvageSlotMixin, "Update", function(slot)
        UpdateSalvageSlot(slot, BuildSurfaceConfig())
    end)

    hooksecurefunc(ProfessionsRecraftInputSlotMixin, "Init", function(button, item)
        UpdateRecraftInputButton(button, item, BuildSurfaceConfig())
    end)

    hooksecurefunc(ProfessionsRecraftOutputSlotMixin, "Init", function(button, item)
        UpdateRecraftOutputButton(button, item, BuildSurfaceConfig())
    end)

    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        UpdateGearButton(button, BuildSurfaceConfig())
    end)
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
    NS.SurfaceRegistry.Register("professionJournal", Surface)
end
