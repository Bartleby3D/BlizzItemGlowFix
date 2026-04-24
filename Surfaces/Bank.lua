local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Bank = NS.Surfaces.Bank or {}
local Surface = NS.Surfaces.Bank

local initialized = false
local hookedPanels = setmetatable({}, { __mode = "k" })
local cachedConfigByType = {}
local cachedConfigVersionByType = {}
local mixinHookInstalled = false

local CHARACTER_BANK_TYPE = Enum and Enum.BankType and Enum.BankType.Character or 0
local ACCOUNT_BANK_TYPE = Enum and Enum.BankType and Enum.BankType.Account or 2

local function GetActiveBankType(panel)
    if panel and type(panel.GetActiveBankType) == "function" then
        local bankType = NS.TryCall("Bank.GetActiveBankType", panel.GetActiveBankType, panel)
        if bankType ~= nil then
            return bankType
        end
    end

    if panel == _G.AccountBankPanel then
        return ACCOUNT_BANK_TYPE
    end

    return CHARACTER_BANK_TYPE
end

local function GetSurfaceKey(bankType)
    if bankType == ACCOUNT_BANK_TYPE then
        return "warbandBank"
    end

    return "characterBank"
end

local function IsSurfaceEnabled(baseConfig, bankType)
    if not baseConfig then
        return false
    end

    if bankType == ACCOUNT_BANK_TYPE then
        return baseConfig.warbandBankEnabled ~= false
    end

    return baseConfig.characterBankEnabled ~= false
end

local function BuildSurfaceConfig(bankType, baseConfig)
    baseConfig = baseConfig or (NS.RuntimeConfig and NS.RuntimeConfig.GetSnapshot and NS.RuntimeConfig.GetSnapshot()) or nil
    if not baseConfig then
        return nil
    end

    local version = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    if cachedConfigByType[bankType] and cachedConfigVersionByType[bankType] == version and cachedConfigByType[bankType].__base == baseConfig then
        return cachedConfigByType[bankType]
    end

    local config = {}
    for key, value in pairs(baseConfig) do
        config[key] = value
    end

    config.__base = baseConfig
    config.bagsEnabled = IsSurfaceEnabled(baseConfig, bankType)

    cachedConfigByType[bankType] = config
    cachedConfigVersionByType[bankType] = version
    return config
end

local function EnumerateValidItems(panel, visitor)
    if not panel or type(visitor) ~= "function" or type(panel.EnumerateValidItems) ~= "function" then
        return
    end

    for itemButton in panel:EnumerateValidItems() do
        if itemButton then
            visitor(itemButton)
        end
    end
end

local function GetButtonBankAndSlot(button)
    if not button then
        return nil, nil
    end

    local bankID = button.GetBankTabID and button:GetBankTabID() or button.GetBagID and button:GetBagID() or nil
    local slotID = button.GetContainerSlotID and button:GetContainerSlotID() or button.GetID and button:GetID() or nil
    return bankID, slotID
end

local function ClearButton(button, reason)
    NS.Renderer.ClearButton(button, reason or "surfaceClear")
end

local function ResetEarlySignature(button)
    if not button then
        return
    end

    button.__BlizzItemGlowFixBankSigBagID = nil
    button.__BlizzItemGlowFixBankSigSlotID = nil
    button.__BlizzItemGlowFixBankSigItemID = nil
    button.__BlizzItemGlowFixBankSigItemLink = nil
    button.__BlizzItemGlowFixBankSigStackCount = nil
    button.__BlizzItemGlowFixBankSigQuality = nil
    button.__BlizzItemGlowFixBankSigConfigVersion = nil
    button.__BlizzItemGlowFixBankSigDynamicVersion = nil
    button.__BlizzItemGlowFixBankSigEmpty = nil
end

local function ShouldSkipByEarlySignature(button, bagID, slotID, info, configVersion, dynamicVersion)
    if not button then
        return false
    end

    local isEmpty = info == nil
    local itemID = info and info.itemID or nil
    local itemLink = info and info.hyperlink or nil
    local stackCount = info and (info.stackCount or 0) or 0
    local quality = info and info.quality or nil

    return button.__BlizzItemGlowFixBankSigBagID == bagID
        and button.__BlizzItemGlowFixBankSigSlotID == slotID
        and button.__BlizzItemGlowFixBankSigItemID == itemID
        and button.__BlizzItemGlowFixBankSigItemLink == itemLink
        and button.__BlizzItemGlowFixBankSigStackCount == stackCount
        and button.__BlizzItemGlowFixBankSigQuality == quality
        and button.__BlizzItemGlowFixBankSigConfigVersion == configVersion
        and button.__BlizzItemGlowFixBankSigDynamicVersion == dynamicVersion
        and button.__BlizzItemGlowFixBankSigEmpty == isEmpty
end

local function MarkEarlySignature(button, bagID, slotID, info, configVersion, dynamicVersion)
    if not button then
        return
    end

    button.__BlizzItemGlowFixBankSigBagID = bagID
    button.__BlizzItemGlowFixBankSigSlotID = slotID
    button.__BlizzItemGlowFixBankSigItemID = info and info.itemID or nil
    button.__BlizzItemGlowFixBankSigItemLink = info and info.hyperlink or nil
    button.__BlizzItemGlowFixBankSigStackCount = info and (info.stackCount or 0) or 0
    button.__BlizzItemGlowFixBankSigQuality = info and info.quality or nil
    button.__BlizzItemGlowFixBankSigConfigVersion = configVersion
    button.__BlizzItemGlowFixBankSigDynamicVersion = dynamicVersion
    button.__BlizzItemGlowFixBankSigEmpty = info == nil
end

local function FindOwningPanel(frame)
    local current = frame
    for _ = 1, 6 do
        if not current then
            return nil
        end
        if type(current.GetActiveBankType) == "function" and type(current.EnumerateValidItems) == "function" then
            return current
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return nil
end

local function UpdateButtonForPanel(panel, button)
    if not panel or not button then
        return
    end

    local bankType = GetActiveBankType(panel)
    local surfaceKey = GetSurfaceKey(bankType)
    local config = BuildSurfaceConfig(bankType)
    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Renderer and NS.Renderer._dynamicVersion or 0
    local canUseBank = not (C_Bank and type(C_Bank.CanUseBank) == "function") or C_Bank.CanUseBank(bankType)
    local bankID, slotID = GetButtonBankAndSlot(button)
    local info = nil

    if config and config.bagsEnabled and canUseBank and bankID ~= nil and slotID ~= nil and C_Container and C_Container.GetContainerItemInfo then
        info = C_Container.GetContainerItemInfo(bankID, slotID)
        if ShouldSkipByEarlySignature(button, bankID, slotID, info, configVersion, dynamicVersion) then
            return
        end
    else
        ResetEarlySignature(button)
    end

    if not config or not config.bagsEnabled then
        ClearButton(button, "bankDisabled")
    elseif not canUseBank then
        ClearButton(button, "bankUnavailable")
    elseif bankID == nil or slotID == nil then
        ClearButton(button, "bankInvalidSlot")
    else
        NS.Renderer.UpdateBagButton(button, bankID, slotID, config, surfaceKey, GetButtonBankAndSlot)
        MarkEarlySignature(button, bankID, slotID, info, configVersion, dynamicVersion)
    end
end

local function BootstrapPanel(panel)
    if not panel then
        return
    end
    local buttonCount = 0

    EnumerateValidItems(panel, function(button)
        buttonCount = buttonCount + 1
        UpdateButtonForPanel(panel, button)
    end)
end

local function InstallGlobalButtonHook()
    if mixinHookInstalled then
        return
    end

    local mixin = _G.BankPanelItemButtonMixin
    if type(mixin) ~= "table" or type(mixin.Refresh) ~= "function" then
        return
    end

    mixinHookInstalled = true
    hooksecurefunc(mixin, "Refresh", function(button)
        local panel = FindOwningPanel(button)
        if panel then
            UpdateButtonForPanel(panel, button)
        end
    end)
end

local function HookPanel(panel)
    if not panel or hookedPanels[panel] then
        return
    end

    hookedPanels[panel] = true
    InstallGlobalButtonHook()

end

local function HookDiscoveredPanels()
    HookPanel(_G.BankPanel)
    HookPanel(_G.AccountBankPanel)
end

function Surface.RefreshVisible()
    HookDiscoveredPanels()

    if _G.BankPanel and _G.BankPanel.IsShown and _G.BankPanel:IsShown() then
        BootstrapPanel(_G.BankPanel)
    end

    if _G.AccountBankPanel and _G.AccountBankPanel.IsShown and _G.AccountBankPanel:IsShown() then
        BootstrapPanel(_G.AccountBankPanel)
    end
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    HookDiscoveredPanels()
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("bank", Surface)
end
