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

    NS.Renderer.UpdateInventoryButton(button, unit, slotID, config, "inspect")
end

function Surface.RefreshVisible()
    if not IsInspectPaperDollVisible() then
        return
    end

    local unit = GetInspectUnit()
    if type(unit) ~= "string" or unit == "" then
        return
    end
    local buttonCount = 0
    local config = BuildSurfaceConfig()

    local buttons = GetTrackedButtons()
    for index = 1, #buttons do
        buttonCount = buttonCount + 1
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

local function InstallHooks()
    if hooksInstalled then
        return
    end

    if not (_G.InspectFrame and _G.InspectPaperDollFrame) then
        return
    end

    hooksInstalled = true
    RefreshTrackedButtons()

    if type(InspectPaperDollItemSlotButton_Update) == "function" then
        hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
            RefreshButton(button)
        end)
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
