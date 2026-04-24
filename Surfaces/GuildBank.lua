local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.GuildBank = NS.Surfaces.GuildBank or {}
local Surface = NS.Surfaces.GuildBank

local initialized = false
local hooked = false
local addonLoadedFrame = nil
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil

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
    config.bagsEnabled = baseConfig.guildBankEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function GetGuildBankFrame()
    return _G.GuildBankFrame
end

local function EnumerateButtons(frame, visitor)
    if not frame or type(visitor) ~= "function" then
        return
    end

    local columns = frame.Columns
    if type(columns) ~= "table" then
        return
    end

    for _, column in ipairs(columns) do
        local buttons = column and column.Buttons
        if type(buttons) == "table" then
            for _, button in ipairs(buttons) do
                if button then
                    visitor(button)
                end
            end
        end
    end
end

local function ClearVisible(frame, reason)
    EnumerateButtons(frame, function(button)
        NS.Renderer.ClearButton(button, reason or "guildBankClear")
    end)
end

local function UpdateButton(button, tabID, config)
    if not button then
        return
    end

    local slotID = button.GetID and button:GetID() or nil
    if slotID == nil then
        NS.Renderer.ClearButton(button, "guildBankInvalidSlot")
        return
    end

    NS.Renderer.UpdateGuildBankButton(button, tabID, slotID, config, "guildBank", function(currentButton)
        local frame = GetGuildBankFrame()
        if not frame or frame.mode ~= "bank" then
            return nil, nil
        end

        local currentTab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or nil
        local currentSlot = currentButton and currentButton.GetID and currentButton:GetID() or nil
        return currentTab, currentSlot
    end)
end

local function RefreshVisibleInternal(reason)
    local frame = GetGuildBankFrame()
    if not frame or not frame.IsShown or not frame:IsShown() then
        return
    end

    local config = BuildSurfaceConfig()
    if not config or not config.bagsEnabled then
        ClearVisible(frame, "guildBankDisabled")
        return
    end

    if frame.mode ~= "bank" then
        ClearVisible(frame, "guildBankMode")
        return
    end

    local tabID = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or nil
    if not tabID or tabID <= 0 then
        ClearVisible(frame, "guildBankNoTab")
        return
    end
    local buttonCount = 0

    EnumerateButtons(frame, function(button)
        buttonCount = buttonCount + 1
        UpdateButton(button, tabID, config)
    end)
end

local function InstallHooks()
    if hooked then
        return
    end

    local frame = GetGuildBankFrame()
    if not frame or type(frame.Update) ~= "function" then
        return
    end

    hooked = true

    hooksecurefunc(frame, "Update", function(self)
        if self and self.mode == "bank" then
            RefreshVisibleInternal("update")
        end
    end)
end

local function EnsureHooks()
    InstallHooks()
end

function Surface.RefreshVisible(reason)
    EnsureHooks()
    RefreshVisibleInternal(reason)
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    EnsureHooks()

    if not hooked then
        addonLoadedFrame = CreateFrame("Frame")
        addonLoadedFrame:RegisterEvent("ADDON_LOADED")
        addonLoadedFrame:SetScript("OnEvent", function(_, event, addonName)
            if event == "ADDON_LOADED" and addonName == "Blizzard_GuildBankUI" then
                EnsureHooks()
                if hooked and addonLoadedFrame then
                    addonLoadedFrame:UnregisterAllEvents()
                    addonLoadedFrame:SetScript("OnEvent", nil)
                    addonLoadedFrame = nil
                end
            end
        end)
    end
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("guildBank", Surface)
end
