local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Inspect = NS.Surfaces.Inspect or {}
local Surface = NS.Surfaces.Inspect

local initialized = false
local hooksInstalled = false
local eventDriver = nil
local trackedButtons = setmetatable({}, { __mode = "k" })
local trackedButtonList = {}
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil
local averageItemLevelText = nil

local SLOT_NAMES = {
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "ShirtSlot",
    "TabardSlot",
    "WristSlot",
    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",
    "MainHandSlot",
    "SecondaryHandSlot",
}


local AVERAGE_ITEM_LEVEL_QUALITY_SLOT_IDS = {
    INVSLOT_HEAD,
    INVSLOT_NECK,
    INVSLOT_SHOULDER,
    INVSLOT_BACK,
    INVSLOT_CHEST,
    INVSLOT_WRIST,
    INVSLOT_HAND,
    INVSLOT_WAIST,
    INVSLOT_LEGS,
    INVSLOT_FEET,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_TRINKET1,
    INVSLOT_TRINKET2,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
}

local RefreshAverageItemLevel

local function GetInspectUnit()
    return _G.InspectFrame and _G.InspectFrame.unit or nil
end

local function IsInspectPaperDollVisible()
    return _G.InspectFrame and _G.InspectFrame.IsShown and _G.InspectFrame:IsShown()
        and _G.InspectPaperDollFrame and _G.InspectPaperDollFrame.IsShown and _G.InspectPaperDollFrame:IsShown()
end

local function RefreshTrackedButtons()
    wipe(trackedButtonList)
    wipe(trackedButtons)

    for index = 1, #SLOT_NAMES do
        local button = _G["Inspect" .. SLOT_NAMES[index]]
        if button then
            trackedButtons[button] = true
            trackedButtonList[#trackedButtonList + 1] = button
        end
    end

    return trackedButtonList
end

local function GetTrackedButtons()
    if #trackedButtonList == #SLOT_NAMES then
        return trackedButtonList
    end

    return RefreshTrackedButtons()
end

local function IsTrackedButton(button)
    return button ~= nil and trackedButtons[button] == true
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
    config.inspectEnabled = baseConfig.inspectEnabled ~= false
    config.upgradeIconEnabled = false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function UpdateButton(button, unit, config)
    if not button then
        return
    end

    if not config or config.inspectEnabled == false then
        NS.Renderer.ClearButton(button, "inspectDisabled")
        return
    end

    if type(unit) ~= "string" or unit == "" then
        NS.Renderer.ClearButton(button, "inspectMissingUnit")
        return
    end

    local slotID = button.GetID and button:GetID() or nil
    if slotID == nil then
        NS.Renderer.ClearButton(button, "inspectInvalidSlot")
        return
    end

    NS.Renderer.UpdateInventoryButton(button, unit, slotID, config, "inspect", function(currentButton)
        local currentUnit = GetInspectUnit()
        local currentSlotID = currentButton and currentButton.GetID and currentButton:GetID() or slotID
        return currentUnit, currentSlotID
    end)
end

local function GetAverageItemLevelParent()
    if _G.InspectModelFrame and type(_G.InspectModelFrame.CreateFontString) == "function" then
        return _G.InspectModelFrame
    end

    if _G.InspectPaperDollFrame and type(_G.InspectPaperDollFrame.CreateFontString) == "function" then
        return _G.InspectPaperDollFrame
    end

    return nil
end

local function EnsureAverageItemLevelText()
    if averageItemLevelText then
        return averageItemLevelText
    end

    local parent = GetAverageItemLevelParent()
    if not parent then
        return nil
    end

    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    if text.SetWordWrap then
        text:SetWordWrap(false)
    end
    text:SetPoint("BOTTOM", parent, "BOTTOM", 0, 20)

    averageItemLevelText = text
    return averageItemLevelText
end

local function HideAverageItemLevel()
    if averageItemLevelText and averageItemLevelText.Hide then
        averageItemLevelText:Hide()
    end
end

local function GetAverageItemLevelQuality(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    if type(GetInventoryItemQuality) ~= "function" then
        return nil
    end

    local qualityTotal = 0
    local qualityCount = 0

    for index = 1, #AVERAGE_ITEM_LEVEL_QUALITY_SLOT_IDS do
        local quality = GetInventoryItemQuality(unit, AVERAGE_ITEM_LEVEL_QUALITY_SLOT_IDS[index])
        if quality ~= nil and quality >= 0 then
            qualityTotal = qualityTotal + quality
            qualityCount = qualityCount + 1
        end
    end

    if qualityCount == 0 then
        return nil
    end

    local averageQuality = qualityTotal / qualityCount
    local roundedQuality = math.floor(averageQuality + 0.3)
    if roundedQuality < 0 then
        return 0
    end

    if roundedQuality > 8 then
        return 8
    end

    return roundedQuality
end

local function ApplyAverageItemLevelStyle(text, config, quality)
    if not text or not config then
        return
    end

    text:SetFont(config.fontPath or "Fonts\\FRIZQT__.TTF", math.max(6, config.ilvlFontSize or 14), config.textFlags or "OUTLINE")

    if config.ilvlUseQualityColor and quality ~= nil and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local color = ITEM_QUALITY_COLORS[quality]
        text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)
        return
    end

    local color = config.ilvlTextColor or {}
    text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function GetAverageItemLevel(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    if not (C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function") then
        return nil
    end

    local itemLevel = tonumber(C_PaperDollInfo.GetInspectItemLevel(unit))
    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    return math.floor(itemLevel + 0.5)
end

local function UpdateAverageItemLevel(config)
    if not IsInspectPaperDollVisible() then
        HideAverageItemLevel()
        return
    end

    if not config or config.inspectEnabled == false or config.ilvlSectionEnabled == false then
        HideAverageItemLevel()
        return
    end

    local unit = GetInspectUnit()
    local itemLevel = GetAverageItemLevel(unit)
    if not itemLevel then
        HideAverageItemLevel()
        return
    end

    local text = EnsureAverageItemLevelText()
    if not text then
        return
    end

    local quality = nil
    if config.ilvlUseQualityColor then
        quality = GetAverageItemLevelQuality(unit)
    end

    ApplyAverageItemLevelStyle(text, config, quality)
    text:SetText(string.format("%s %d", NS.L("iLvl"), itemLevel))
    text:Show()
end

function Surface.RefreshVisible()
    local config = BuildSurfaceConfig()

    if not IsInspectPaperDollVisible() then
        HideAverageItemLevel()
        return
    end

    local unit = GetInspectUnit()
    if type(unit) ~= "string" or unit == "" then
        HideAverageItemLevel()
        return
    end

    UpdateAverageItemLevel(config)

    local buttons = GetTrackedButtons()
    for index = 1, #buttons do
        UpdateButton(buttons[index], unit, config)
    end
end

local function RefreshButton(button)
    if not IsTrackedButton(button) then
        return
    end

    if not IsInspectPaperDollVisible() then
        return
    end

    local unit = GetInspectUnit()
    if type(unit) ~= "string" or unit == "" then
        return
    end

    UpdateButton(button, unit, BuildSurfaceConfig())
end

RefreshAverageItemLevel = function()
    UpdateAverageItemLevel(BuildSurfaceConfig())
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    if not (_G.InspectFrame and _G.InspectPaperDollFrame) then
        return
    end

    hooksInstalled = true
    RefreshTrackedButtons()

    if type(InspectPaperDollFrame_UpdateButtons) == "function" then
        hooksecurefunc("InspectPaperDollFrame_UpdateButtons", RefreshAverageItemLevel)
    end

    if type(InspectPaperDollItemSlotButton_Update) == "function" then
        hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
            RefreshButton(button)
        end)
    end

    if _G.InspectPaperDollFrame and _G.InspectPaperDollFrame.HookScript then
        _G.InspectPaperDollFrame:HookScript("OnShow", RefreshAverageItemLevel)
        _G.InspectPaperDollFrame:HookScript("OnHide", HideAverageItemLevel)
    end

    if eventDriver then
        eventDriver:UnregisterEvent("ADDON_LOADED")
        eventDriver:SetScript("OnEvent", nil)
        eventDriver = nil
    end
end

local function OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
        InstallHooks()
    end
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    if type(IsAddOnLoaded) == "function" and IsAddOnLoaded("Blizzard_InspectUI") then
        InstallHooks()
        return
    end

    eventDriver = CreateFrame("Frame")
    eventDriver:RegisterEvent("ADDON_LOADED")
    eventDriver:SetScript("OnEvent", OnEvent)
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("inspect", Surface)
end
