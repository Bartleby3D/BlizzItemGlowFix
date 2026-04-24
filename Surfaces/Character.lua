local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Character = NS.Surfaces.Character or {}
local Surface = NS.Surfaces.Character

local initialized = false
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

local function IsPaperDollVisible()
    return _G.CharacterFrame and _G.CharacterFrame.IsShown and _G.CharacterFrame:IsShown()
        and _G.PaperDollFrame and _G.PaperDollFrame.IsShown and _G.PaperDollFrame:IsShown()
end

local function RefreshTrackedButtons()
    wipe(trackedButtonList)
    wipe(trackedButtons)

    for index = 1, #SLOT_NAMES do
        local button = _G["Character" .. SLOT_NAMES[index]]
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
    config.characterFrameEnabled = baseConfig.characterFrameEnabled ~= false
    config.upgradeIconEnabled = false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function UpdateButton(button, config)
    if not button then
        return
    end

    if not config or config.characterFrameEnabled == false then
        NS.Renderer.ClearButton(button, "characterDisabled")
        return
    end

    local slotID = button.GetID and button:GetID() or nil
    if slotID == nil then
        NS.Renderer.ClearButton(button, "characterInvalidSlot")
        return
    end

    NS.Renderer.UpdateInventoryButton(button, "player", slotID, config, "character")
end

function Surface.RefreshVisible()
    if not IsPaperDollVisible() then
        return
    end
    local buttonCount = 0
    local config = BuildSurfaceConfig()

    local buttons = GetTrackedButtons()
    for index = 1, #buttons do
        buttonCount = buttonCount + 1
        UpdateButton(buttons[index], config)
    end
end

local function RefreshButton(button)
    if not IsTrackedButton(button) then
        return
    end

    if not IsPaperDollVisible() then
        return
    end
    UpdateButton(button, BuildSurfaceConfig())
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    RefreshTrackedButtons()

    if type(PaperDollItemSlotButton_Update) == "function" then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            RefreshButton(button)
        end)
    end
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("character", Surface)
end
