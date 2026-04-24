local _, NS = ...

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")

local refreshKeys = {
    bagsEnabled = true,
    characterFrameEnabled = true,
    inspectEnabled = true,
    characterBankEnabled = true,
    warbandBankEnabled = true,
    guildBankEnabled = true,
    merchantEnabled = true,
    mailEnabled = true,
    tradeEnabled = true,
    lootEnabled = true,
    questsEnabled = true,
    professionJournalEnabled = true,
    craftingOrdersEnabled = true,
    borderSectionEnabled = true,
    borderStyle = true,
    borderStyleScale = true,
    borderGlowEnabled = true,
    borderHoverEnabled = true,
    borderHoverColor = true,
    borderMinQuality = true,
    ilvlSectionEnabled = true,
    ilvlFontSize = true,
    ilvlOffsetX = true,
    ilvlOffsetY = true,
    ilvlUseQualityColor = true,
    ilvlMinQuality = true,
    ilvlTextColor = true,
    stackTextEnabled = true,
    stackFontSize = true,
    stackOffsetX = true,
    stackOffsetY = true,
    stackJustifyH = true,
    stackTextColor = true,
    iconsSectionEnabled = true,
    junkIconEnabled = true,
    junkIconSize = true,
    junkIconOffsetX = true,
    junkIconOffsetY = true,
    upgradeIconEnabled = true,
    upgradeIconSize = true,
    upgradeIconOffsetX = true,
    upgradeIconOffsetY = true,
    transmogIconEnabled = true,
    transmogIconSize = true,
    transmogIconOffsetX = true,
    transmogIconOffsetY = true,
    questIconEnabled = true,
    questIconSize = true,
    questIconOffsetX = true,
    questIconOffsetY = true,
    enchantIconEnabled = true,
    enchantIconCharacterInspectOnly = true,
    enchantIconSize = true,
    enchantIconOffsetX = true,
    enchantIconOffsetY = true,
    generalFont = true,
    generalTextStyle = true,
}

bootstrap:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "BlizzItemGlowFix" then
            return
        end

        if NS.Config and NS.Config.EnsureDB then
            NS.Config.EnsureDB()
        elseif NS.InitializeDB then
            NS.InitializeDB()
        end

        if NS.RuntimeConfig and NS.RuntimeConfig.Invalidate then
            NS.RuntimeConfig.Invalidate()
        end

        if NS.Config and NS.Config.RegisterCallback then
            NS.Config.RegisterCallback(function(key)
                if not refreshKeys[key] then
                    return
                end

                if NS.Invalidation and NS.Invalidation.OnConfigChanged then
                    NS.Invalidation.OnConfigChanged()
                end
            end)
        end

        return
    end

    if event == "PLAYER_LOGIN" then
        if NS.ItemDataStore and NS.ItemDataStore.PreloadEquippedItems then
            NS.ItemDataStore.PreloadEquippedItems()
        end
        if NS.AssetWarmup and NS.AssetWarmup.WarmupAssets then
            NS.AssetWarmup.WarmupAssets()
        end
        if NS.MinimapIcon and NS.MinimapIcon.Initialize then
            NS.MinimapIcon.Initialize()
        end
        if NS.SurfaceRegistry and NS.SurfaceRegistry.InitializeAll then
            NS.SurfaceRegistry.InitializeAll()
        end
        if NS.Invalidation and NS.Invalidation.RefreshVisible then
            NS.Invalidation.RefreshVisible("login")
        end
    end
end)
