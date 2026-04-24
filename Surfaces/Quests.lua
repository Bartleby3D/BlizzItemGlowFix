local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Quests = NS.Surfaces.Quests or {}
local Surface = NS.Surfaces.Quests

local initialized = false
local hooksInstalled = false
local eventFrame = nil
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil
local lastFrameSignature = setmetatable({}, { __mode = "k" })
local pendingDelayedRefresh = setmetatable({}, { __mode = "k" })
local delayedRefreshAttempts = setmetatable({}, { __mode = "k" })
local delayedRefreshKeys = setmetatable({}, { __mode = "k" })
local delayedRefreshTokens = setmetatable({}, { __mode = "k" })
local RefreshFrame

local MAX_REWARD_BUTTONS = tonumber(_G.MAX_NUM_ITEMS) or 12
local DELAYED_REFRESH_INTERVAL = 0.1
local MAX_DELAYED_REFRESH_ATTEMPTS = 2
local COMMON_QUALITY = (Enum and Enum.ItemQuality and Enum.ItemQuality.Common) or 1
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
    config.questsEnabled = baseConfig.questsEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetFrameName(frame)
    return frame and frame.GetName and frame:GetName() or nil
end

local function GetQuestInfoFrame()
    return _G.QuestInfoFrame
end

local function GetRewardsFrames()
    local frames = {}
    local seen = {}

    local questFrame = _G.QuestInfoRewardsFrame
    local mapFrame = _G.MapQuestInfoRewardsFrame

    if questFrame and not seen[questFrame] then
        seen[questFrame] = true
        frames[#frames + 1] = questFrame
    end

    if mapFrame and not seen[mapFrame] then
        seen[mapFrame] = true
        frames[#frames + 1] = mapFrame
    end

    local infoFrame = GetQuestInfoFrame()
    local activeRewardsFrame = infoFrame and infoFrame.rewardsFrame or nil
    if activeRewardsFrame and not seen[activeRewardsFrame] then
        seen[activeRewardsFrame] = true
        frames[#frames + 1] = activeRewardsFrame
    end

    return frames
end

local function ForEachRewardsFrame(callback)
    if type(callback) ~= "function" then
        return
    end

    local frames = GetRewardsFrames()
    for index = 1, #frames do
        callback(frames[index])
    end
end

local function IsQuestLogContext(rewardsFrame)
    if rewardsFrame == _G.MapQuestInfoRewardsFrame then
        return true
    end

    local infoFrame = GetQuestInfoFrame()
    return infoFrame and infoFrame.questLog == true or false
end

local function GetOwningRewardsFrame(region)
    if not region then
        return nil
    end

    local taggedOwner = region.__BlizzItemGlowFixQuestRewardsFrame
    if taggedOwner then
        return taggedOwner
    end

    local frame = region
    while frame do
        if frame == _G.QuestInfoRewardsFrame or frame == _G.MapQuestInfoRewardsFrame then
            return frame
        end

        frame = frame.GetParent and frame:GetParent() or nil
    end

    return nil
end

local SPECIAL_REWARD_POOL_NAMES = {
    "spellRewardPool",
    "followerRewardPool",
    "reputationRewardPool",
}

local SPECIAL_REWARD_FRAME_KEYS = {
    "MoneyFrame",
    "HonorFrame",
    "SkillPointFrame",
    "ArtifactXPFrame",
    "TitleFrame",
    "WarModeBonusFrame",
    "XPFrame",
}

local function IsTextureLike(region)
    if not region then
        return false
    end

    local objectType = region.GetObjectType and region:GetObjectType() or nil
    return objectType == "Texture"
end

local function IsFrameLike(frame)
    if not frame or not frame.IsObjectType then
        return false
    end

    return frame:IsObjectType("Button") or frame:IsObjectType("Frame")
end

local DIRECT_ICON_FIELD_CHAINS = {
    { "Icon" },
    { "icon" },
    { "IconTexture" },
    { "iconTexture" },
    { "ItemButton", "Icon" },
    { "ItemButton", "icon" },
    { "ItemButton", "IconTexture" },
    { "ItemButton", "iconTexture" },
    { "NameFrame", "Icon" },
    { "NameFrame", "icon" },
    { "PortraitFrame", "Portrait" },
    { "PortraitFrame", "portrait" },
    { "AdventuresFollowerPortraitFrame", "Portrait" },
    { "AdventuresFollowerPortraitFrame", "portrait" },
}

local NAMED_ICON_SUFFIXES = {
    "Icon",
    "IconTexture",
    "icon",
    "iconTexture",
}

local function GetFieldChainValue(root, chain)
    local value = root
    for index = 1, #chain do
        value = value and value[chain[index]] or nil
        if not value then
            return nil
        end
    end
    return value
end

local function GetNamedIconRegion(button)
    if not button then
        return nil
    end

    for index = 1, #DIRECT_ICON_FIELD_CHAINS do
        local region = GetFieldChainValue(button, DIRECT_ICON_FIELD_CHAINS[index])
        if IsTextureLike(region) and region.__BlizzItemGlowFixOverlayTexture ~= true then
            return region
        end
    end

    local buttonName = GetFrameName(button)
    if type(buttonName) == "string" and buttonName ~= "" then
        for index = 1, #NAMED_ICON_SUFFIXES do
            local region = _G[buttonName .. NAMED_ICON_SUFFIXES[index]]
            if IsTextureLike(region) and region.__BlizzItemGlowFixOverlayTexture ~= true then
                return region
            end
        end
    end

    return nil
end

local function GetDirectChildNamedIconRegion(button)
    if not button or type(button.GetChildren) ~= "function" then
        return nil
    end

    local childCount = select("#", button:GetChildren())
    for index = 1, childCount do
        local child = select(index, button:GetChildren())
        local region = child and GetNamedIconRegion(child) or nil
        if region then
            return region
        end
    end

    return nil
end

local function IsCompositeMoneyFrame(frame)
    if not frame then
        return false
    end

    if frame.GoldButton ~= nil or frame.SilverButton ~= nil or frame.CopperButton ~= nil then
        return GetNamedIconRegion(frame) == nil
    end

    return false
end

local function ResolveDirectRenderRegion(button)
    if not button or IsCompositeMoneyFrame(button) then
        return nil
    end

    return GetNamedIconRegion(button)
end

local function ResolveRenderRegion(button)
    if not button or IsCompositeMoneyFrame(button) then
        return nil
    end

    return GetNamedIconRegion(button) or GetDirectChildNamedIconRegion(button) or nil
end

local function TrackButton(button, rewardsFrame)
    if button then
        button.__BlizzItemGlowFixQuestRewardsFrame = rewardsFrame
        button.__BlizzItemGlowFixRenderRegion = ResolveRenderRegion(button)
    end
end

local function NormalizeQuality(quality)
    quality = tonumber(quality)
    if quality and quality >= 0 then
        return quality
    end

    return nil
end

local function ResolveItemID(itemLink, itemID)
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
        return itemID
    end

    if type(itemLink) == "string" and itemLink ~= "" and type(GetItemInfoInstant) == "function" then
        local ok, resolvedItemID = pcall(GetItemInfoInstant, itemLink)
        if ok then
            resolvedItemID = tonumber(resolvedItemID)
            if resolvedItemID and resolvedItemID > 0 then
                return resolvedItemID
            end
        end
    end

    return nil
end

local function GetRewardIndex(button)
    if not button then
        return nil
    end

    local rewardIndex = button.rewardIndex or button.id
    if rewardIndex == nil and type(button.GetID) == "function" then
        rewardIndex = button:GetID()
    end

    rewardIndex = tonumber(rewardIndex)
    if rewardIndex and rewardIndex > 0 then
        return rewardIndex
    end

    return nil
end

local function GetRewardType(button)
    if not button then
        return nil
    end

    local rewardType = button.type
    if rewardType == "choice" or rewardType == "reward" then
        return rewardType
    end

    return nil
end

local function GetRewardObjectType(button)
    if not button then
        return nil
    end

    local objectType = button.objectType
    if type(objectType) == "string" and objectType ~= "" then
        return objectType
    end

    return "item"
end

local function GetValidLink(link)
    if type(link) == "string" and link ~= "" then
        return link
    end

    return nil
end

local function GetQuestLogQuestID(rewardsFrame)
    if rewardsFrame and type(rewardsFrame.questID) == "number" and rewardsFrame.questID > 0 then
        return rewardsFrame.questID
    end

    local infoFrame = GetQuestInfoFrame()
    if infoFrame and type(infoFrame.questID) == "number" and infoFrame.questID > 0 then
        return infoFrame.questID
    end

    if C_QuestLog and type(C_QuestLog.GetSelectedQuest) == "function" then
        local questID = C_QuestLog.GetSelectedQuest()
        if type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function GetActiveQuestID(rewardsFrame)
    local questID = GetQuestLogQuestID(rewardsFrame)
    if questID then
        return questID
    end

    local infoFrame = GetQuestInfoFrame()
    if infoFrame and type(infoFrame.questID) == "number" and infoFrame.questID > 0 then
        return infoFrame.questID
    end

    if type(GetQuestID) == "function" then
        questID = GetQuestID()
        if type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function BuildDelayedRefreshKey(rewardsFrame)
    if not rewardsFrame then
        return nil
    end

    return table.concat({
        GetFrameName(rewardsFrame) or "QuestInfoRewardsFrame",
        tostring(GetActiveQuestID(rewardsFrame) or 0),
        tostring(rewardsFrame.numQuestChoices or rewardsFrame.numChoices or 0),
        tostring(rewardsFrame.numQuestRewards or rewardsFrame.numRewards or 0),
    }, "\031")
end

local function ResetDelayedRefresh(rewardsFrame)
    if not rewardsFrame then
        return
    end

    pendingDelayedRefresh[rewardsFrame] = nil
    delayedRefreshAttempts[rewardsFrame] = nil
    delayedRefreshKeys[rewardsFrame] = nil
    delayedRefreshTokens[rewardsFrame] = (tonumber(delayedRefreshTokens[rewardsFrame]) or 0) + 1
end

local function ScheduleDelayedRefresh(rewardsFrame)
    if not rewardsFrame or not IsFrameShown(rewardsFrame) or pendingDelayedRefresh[rewardsFrame] then
        return
    end

    local key = BuildDelayedRefreshKey(rewardsFrame)
    if delayedRefreshKeys[rewardsFrame] ~= key then
        delayedRefreshKeys[rewardsFrame] = key
        delayedRefreshAttempts[rewardsFrame] = 0
    end

    local attempts = tonumber(delayedRefreshAttempts[rewardsFrame]) or 0
    if attempts >= MAX_DELAYED_REFRESH_ATTEMPTS then
        return
    end

    delayedRefreshAttempts[rewardsFrame] = attempts + 1
    pendingDelayedRefresh[rewardsFrame] = true

    local token = (tonumber(delayedRefreshTokens[rewardsFrame]) or 0) + 1
    delayedRefreshTokens[rewardsFrame] = token

    C_Timer.After(DELAYED_REFRESH_INTERVAL, function()
        if delayedRefreshTokens[rewardsFrame] ~= token or delayedRefreshKeys[rewardsFrame] ~= key then
            return
        end

        pendingDelayedRefresh[rewardsFrame] = nil

        if not rewardsFrame or not IsFrameShown(rewardsFrame) then
            return
        end

        lastFrameSignature[rewardsFrame] = nil
        RefreshFrame(rewardsFrame, BuildSurfaceConfig())
    end)
end

local function GetQuestCurrencyQuality(rewardsFrame, rewardIndex, rewardType)
    rewardIndex = tonumber(rewardIndex)
    if not rewardsFrame or not rewardIndex or rewardIndex <= 0 then
        return nil
    end

    if IsQuestLogContext(rewardsFrame) then
        local questID = GetQuestLogQuestID(rewardsFrame)
        local isChoice = rewardType == "choice"

        if questID and C_QuestLog and type(C_QuestLog.GetQuestRewardCurrencyInfo) == "function" then
            local info = C_QuestLog.GetQuestRewardCurrencyInfo(questID, rewardIndex, isChoice)
            if type(info) == "table" and info.quality ~= nil then
                return NormalizeQuality(info.quality)
            end
        end

        if type(GetQuestLogRewardCurrencyInfo) == "function" then
            local _, _, _, quality = GetQuestLogRewardCurrencyInfo(rewardIndex, questID)
            if quality ~= nil then
                return NormalizeQuality(quality)
            end
        end

        return nil
    end

    if C_QuestInfoSystem and type(C_QuestInfoSystem.GetQuestRewardCurrencies) == "function" then
        local infos = C_QuestInfoSystem.GetQuestRewardCurrencies()
        local info = type(infos) == "table" and infos[rewardIndex] or nil
        if type(info) == "table" and info.quality ~= nil then
            return NormalizeQuality(info.quality)
        end
    end

    if type(GetQuestCurrencyInfo) == "function" then
        local _, _, _, quality = GetQuestCurrencyInfo("reward", rewardIndex)
        if quality ~= nil then
            return NormalizeQuality(quality)
        end
    end

    return nil
end

local function GetQualityFromLink(link)
    if type(link) ~= "string" or link == "" or type(GetItemInfo) ~= "function" then
        return nil
    end

    local _, _, quality = GetItemInfo(link)
    return NormalizeQuality(quality)
end

local function GetQualityFromIconBorder(frame)
    if not frame or not ITEM_QUALITY_COLORS then
        return nil
    end

    local border = frame.IconBorder or frame.iconBorder
    if not border then
        local name = GetFrameName(frame)
        if type(name) == "string" and name ~= "" then
            border = _G[name .. "IconBorder"] or _G[name .. "iconBorder"]
        end
    end

    if not border or not border.GetVertexColor then
        return nil
    end

    local r, g, b = border:GetVertexColor()
    if not r or not g or not b then
        return nil
    end

    local bestQuality
    local bestDistance

    for quality, color in pairs(ITEM_QUALITY_COLORS) do
        if type(color) == "table" and color.r and color.g and color.b then
            local dr = r - color.r
            local dg = g - color.g
            local db = b - color.b
            local distance = (dr * dr) + (dg * dg) + (db * db)
            if not bestDistance or distance < bestDistance then
                bestDistance = distance
                bestQuality = quality
            end
        end
    end

    if bestDistance and bestDistance <= 0.02 then
        return NormalizeQuality(bestQuality)
    end

    return nil
end

local function GetSpecialRewardBorderQuality(frame)
    if not frame then
        return COMMON_QUALITY
    end

    return NormalizeQuality(frame.quality or frame.itemQuality or frame.rewardQuality)
        or GetQualityFromIconBorder(frame)
        or COMMON_QUALITY
end

local function GetRewardItemLink(rewardsFrame, button, rewardType, rewardIndex)
    if not rewardsFrame or not button then
        return nil
    end

    local directLink = button.link or button.itemLink or button.hyperlink
    if type(directLink) == "string" and directLink ~= "" then
        return directLink
    end

    if rewardType ~= "choice" and rewardType ~= "reward" then
        return nil
    end

    if GetRewardObjectType(button) == "currency" then
        return nil
    end

    rewardIndex = tonumber(rewardIndex)
    if not rewardIndex or rewardIndex <= 0 then
        return nil
    end

    if IsQuestLogContext(rewardsFrame) then
        if type(GetQuestLogItemLink) == "function" then
            return GetValidLink(GetQuestLogItemLink(rewardType, rewardIndex))
        end
        return nil
    end

    if type(GetQuestItemLink) == "function" then
        return GetValidLink(GetQuestItemLink(rewardType, rewardIndex))
    end

    return nil
end

local function GetRewardItemInfo(rewardsFrame, rewardType, rewardIndex)
    rewardIndex = tonumber(rewardIndex)
    if rewardType ~= "choice" and rewardType ~= "reward" then
        return nil, nil
    end
    if not rewardIndex or rewardIndex <= 0 then
        return nil, nil
    end

    local stackCount, quality = nil, nil

    if IsQuestLogContext(rewardsFrame) then
        if rewardType == "choice" and type(GetQuestLogChoiceInfo) == "function" then
            local _, _, quantity, itemQuality = GetQuestLogChoiceInfo(rewardIndex)
            stackCount = quantity
            quality = itemQuality
        elseif rewardType == "reward" and type(GetQuestLogRewardInfo) == "function" then
            local _, _, quantity, itemQuality = GetQuestLogRewardInfo(rewardIndex)
            stackCount = quantity
            quality = itemQuality
        end
    elseif type(GetQuestItemInfo) == "function" then
        local _, _, quantity, itemQuality = GetQuestItemInfo(rewardType, rewardIndex)
        stackCount = quantity
        quality = itemQuality
    end

    stackCount = tonumber(stackCount) or 0
    quality = NormalizeQuality(quality)
    return stackCount, quality
end

local function IsMoneyRewardFrame(frame, rewardsFrame)
    if not frame or not rewardsFrame then
        return false
    end

    if frame == rewardsFrame.MoneyFrame then
        return ResolveDirectRenderRegion(frame) ~= nil and not IsCompositeMoneyFrame(frame)
    end

    if frame == _G.QuestInfoMoneyFrame then
        return (frame.GetParent and frame:GetParent() == rewardsFrame or false)
            and ResolveDirectRenderRegion(frame) ~= nil
            and not IsCompositeMoneyFrame(frame)
    end

    return false
end

local function IsRenderableRewardButton(button, rewardsFrame)
    if not button or not rewardsFrame then
        return false
    end

    if not button.IsObjectType or not button:IsObjectType("Button") then
        return false
    end

    local rewardType = GetRewardType(button)
    if rewardType ~= "choice" and rewardType ~= "reward" then
        return false
    end

    return GetOwningRewardsFrame(button) == rewardsFrame or button:GetParent() == rewardsFrame
end

local function IsSpecialRewardFrame(frame, rewardsFrame)
    if not IsFrameLike(frame) or not rewardsFrame then
        return false
    end

    local parent = frame.GetParent and frame:GetParent() or nil
    if GetOwningRewardsFrame(frame) ~= rewardsFrame and parent ~= rewardsFrame then
        return false
    end

    if IsCompositeMoneyFrame(frame) then
        return false
    end

    return ResolveRenderRegion(frame) ~= nil
end

local function GetElementKind(frame, rewardsFrame)
    if IsMoneyRewardFrame(frame, rewardsFrame) then
        return "money"
    end

    if IsRenderableRewardButton(frame, rewardsFrame) then
        return "reward"
    end

    if IsSpecialRewardFrame(frame, rewardsFrame) then
        return "special"
    end

    return nil
end

local function VisitElement(frame, rewardsFrame, seen, callback, includeHidden)
    if not frame or seen[frame] or type(callback) ~= "function" then
        return
    end

    local kind = GetElementKind(frame, rewardsFrame)
    if not kind then
        return
    end

    if not includeHidden and frame.IsShown and not frame:IsShown() then
        return
    end

    seen[frame] = true
    TrackButton(frame, rewardsFrame)
    callback(frame, kind)
end

local function EnumerateTableButtons(buttonTable, rewardsFrame, seen, callback, includeHidden)
    if type(buttonTable) ~= "table" then
        return
    end

    for index = 1, #buttonTable do
        VisitElement(buttonTable[index], rewardsFrame, seen, callback, includeHidden)
    end

    for _, button in pairs(buttonTable) do
        VisitElement(button, rewardsFrame, seen, callback, includeHidden)
    end
end

local function EnumerateNamedButtons(rewardsFrame, seen, callback, includeHidden)
    local frameName = GetFrameName(rewardsFrame)
    if type(frameName) ~= "string" or frameName == "" then
        return
    end

    for index = 1, MAX_REWARD_BUTTONS do
        VisitElement(_G[frameName .. "QuestInfoItem" .. tostring(index)], rewardsFrame, seen, callback, includeHidden)
    end

    if rewardsFrame == _G.QuestInfoRewardsFrame then
        for index = 1, MAX_REWARD_BUTTONS do
            VisitElement(_G["QuestInfoItem" .. tostring(index)], rewardsFrame, seen, callback, includeHidden)
        end
    end
end

local function EnumerateSpecialFrameKeys(rewardsFrame, seen, callback, includeHidden)
    for index = 1, #SPECIAL_REWARD_FRAME_KEYS do
        local key = SPECIAL_REWARD_FRAME_KEYS[index]
        local frame = rewardsFrame[key]
        if frame and (includeHidden or not frame.IsShown or frame:IsShown()) then
            VisitElement(frame, rewardsFrame, seen, callback, includeHidden)
        end
    end
end

local function EnumerateActivePoolObjects(pool, callback)
    if not pool or type(pool.EnumerateActive) ~= "function" or type(callback) ~= "function" then
        return
    end

    for object in pool:EnumerateActive() do
        callback(object)
    end
end

local function EnumerateSpecialPools(rewardsFrame, seen, callback, includeHidden)
    for index = 1, #SPECIAL_REWARD_POOL_NAMES do
        local poolName = SPECIAL_REWARD_POOL_NAMES[index]
        EnumerateActivePoolObjects(rewardsFrame[poolName], function(frame)
            if frame and (includeHidden or not frame.IsShown or frame:IsShown()) then
                VisitElement(frame, rewardsFrame, seen, callback, includeHidden)
            end
        end)
    end
end

local function EnumerateRewardButtons(rewardsFrame, callback, includeHidden)
    if not rewardsFrame or type(callback) ~= "function" then
        return
    end

    local seen = {}
    EnumerateTableButtons(rewardsFrame.RewardButtons, rewardsFrame, seen, callback, includeHidden)
    EnumerateTableButtons(rewardsFrame.rewardButtons, rewardsFrame, seen, callback, includeHidden)
    EnumerateNamedButtons(rewardsFrame, seen, callback, includeHidden)
    EnumerateSpecialFrameKeys(rewardsFrame, seen, callback, includeHidden)
    EnumerateSpecialPools(rewardsFrame, seen, callback, includeHidden)
end

local function BuildEntry(rewardsFrame, button, kind)
    if not rewardsFrame or not button then
        return nil
    end

    kind = kind or GetElementKind(button, rewardsFrame)
    if kind == "money" or kind == "special" then
        local borderQuality = GetSpecialRewardBorderQuality(button)
        return {
            rewardType = kind,
            rewardIndex = tonumber(button.rewardIndex or button.id or (type(button.GetID) == "function" and button:GetID()) or 0) or 0,
            objectType = kind,
            itemLink = nil,
            itemID = nil,
            quality = nil,
            borderQuality = borderQuality,
            forceBorder = borderQuality ~= nil,
            presentationKind = kind,
            stackCount = 0,
            hasNoValue = false,
            isQuestItem = false,
        }
    end

    if kind ~= "reward" then
        return nil
    end

    local rewardType = GetRewardType(button)
    local rewardIndex = GetRewardIndex(button)
    if rewardType ~= "choice" and rewardType ~= "reward" then
        return nil
    end
    if not rewardIndex then
        return nil
    end

    local objectType = GetRewardObjectType(button)
    local quality = NormalizeQuality(button.quality or button.itemQuality or button.rewardQuality)
    local stackCount = 0

    if objectType == "currency" then
        quality = quality or GetQuestCurrencyQuality(rewardsFrame, rewardIndex, rewardType) or GetQualityFromIconBorder(button) or COMMON_QUALITY
        return {
            rewardType = rewardType,
            rewardIndex = rewardIndex,
            objectType = objectType,
            itemLink = nil,
            itemID = nil,
            quality = quality,
            borderQuality = nil,
            forceBorder = false,
            presentationKind = "reward",
            stackCount = 0,
            hasNoValue = false,
            isQuestItem = false,
        }
    end

    local itemLink = GetRewardItemLink(rewardsFrame, button, rewardType, rewardIndex)
    local itemID = ResolveItemID(itemLink, button.itemID or button.itemId)
    local infoStackCount, infoQuality = GetRewardItemInfo(rewardsFrame, rewardType, rewardIndex)

    if infoStackCount and infoStackCount > 0 then
        stackCount = infoStackCount
    end
    quality = quality or infoQuality or GetQualityFromLink(itemLink) or GetQualityFromIconBorder(button)

    if not itemLink and not itemID then
        ScheduleDelayedRefresh(rewardsFrame)
        return nil
    end

    return {
        rewardType = rewardType,
        rewardIndex = rewardIndex,
        objectType = objectType,
        itemLink = itemLink,
        itemID = itemID,
        quality = quality,
        borderQuality = nil,
        forceBorder = false,
        presentationKind = "reward",
        stackCount = stackCount,
        hasNoValue = false,
        isQuestItem = false,
    }
end

local function BuildLightweightSnapshot(entry)
    if not entry then
        return nil
    end

    return {
        itemID = entry.itemID,
        itemLink = entry.itemLink,
        quality = entry.quality,
        borderQuality = entry.borderQuality,
        forceBorder = entry.forceBorder == true,
        presentationKind = entry.presentationKind,
        stackCount = entry.stackCount or 0,
        hasNoValue = entry.hasNoValue == true,
        isQuestItem = entry.isQuestItem == true,
        isEquippable = false,
        itemLevel = nil,
        pending = false,
    }
end

local function BuildSlotKey(rewardsFrame, entry)
    local frameName = GetFrameName(rewardsFrame) or "QuestInfoRewardsFrame"
    local questID = GetActiveQuestID(rewardsFrame) or 0
    return table.concat({
        "quest",
        frameName,
        tostring(questID),
        tostring(entry.rewardType or "reward"),
        tostring(entry.rewardIndex or 0),
        tostring(entry.objectType or "item"),
    }, ":")
end

local function ClearButton(button, reason)
    if not button then
        return
    end

    button.__BlizzItemGlowFixQuestRewardsFrame = nil
    button.__BlizzItemGlowFixRenderRegion = nil
    NS.Renderer.ClearButton(button, reason or "surfaceClear")
end

local function BuildRecordSortKey(record)
    local entry = record and record.entry or nil
    local button = record and record.button or nil
    local buttonName = GetFrameName(button) or tostring(button)
    if not entry then
        return table.concat({ "_", buttonName }, "\031")
    end

    return table.concat({
        tostring(entry.rewardType or ""),
        tostring(entry.rewardIndex or 0),
        tostring(entry.objectType or ""),
        tostring(entry.itemID or 0),
        tostring(entry.itemLink or ""),
        buttonName,
    }, "\031")
end

local function BuildFrameSignature(rewardsFrame, configVersion, dynamicVersion, records)
    local parts = {
        tostring(GetFrameName(rewardsFrame) or "QuestInfoRewardsFrame"),
        tostring(GetActiveQuestID(rewardsFrame) or 0),
        tostring(configVersion or 0),
        tostring(dynamicVersion or 0),
    }

    for index = 1, #records do
        local entry = records[index].entry
        if not entry then
            parts[#parts + 1] = "_"
        else
            parts[#parts + 1] = table.concat({
                tostring(entry.rewardType or ""),
                tostring(entry.rewardIndex or 0),
                tostring(entry.objectType or ""),
                tostring(entry.itemID or 0),
                tostring(entry.itemLink or ""),
                tostring(entry.quality or ""),
                tostring(entry.borderQuality or ""),
                tostring(entry.forceBorder == true),
                tostring(entry.presentationKind or ""),
                tostring(entry.stackCount or 0),
            }, "\031")
        end
    end

    return table.concat(parts, "\030")
end

local function UpdateButton(button, rewardsFrame, config, entry)
    if not button then
        return
    end
    TrackButton(button, rewardsFrame)

    config = BuildSurfaceConfig(config)
    if not config or not config.questsEnabled then
        ClearButton(button, "questDisabled")
        return
    end

    if button.IsShown and not button:IsShown() then
        ClearButton(button, "questHidden")
        return
    end

    entry = entry or BuildEntry(rewardsFrame, button)
    if not entry then
        ClearButton(button, "questEmpty")
        return
    end

    local snapshot
    if entry.itemLink or entry.itemID then
        local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
        snapshot = NS.ItemDataStore.GetExternalItemSnapshot(
            BuildSlotKey(rewardsFrame, entry),
            entry.itemLink,
            entry.itemID,
            entry.quality,
            entry.stackCount,
            entry.hasNoValue,
            entry.isQuestItem,
            wantItemLevel,
            function()
                local currentFrame = GetOwningRewardsFrame(button)
                if not currentFrame or not IsFrameShown(currentFrame) then
                    ClearButton(button, "questCallbackMissing")
                    return
                end

                UpdateButton(button, currentFrame, nil, nil)
            end,
            button
        )
        if snapshot then
            snapshot.borderQuality = entry.borderQuality
            snapshot.forceBorder = entry.forceBorder == true
            snapshot.presentationKind = entry.presentationKind
        end
    else
        snapshot = BuildLightweightSnapshot(entry)
    end

    if not snapshot then
        ClearButton(button, "questUnrenderable")
        return
    end

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "quests")
end

local function ClearFrame(rewardsFrame, reason)
    if not rewardsFrame then
        return
    end
    lastFrameSignature[rewardsFrame] = nil
    ResetDelayedRefresh(rewardsFrame)
    EnumerateRewardButtons(rewardsFrame, function(button)
        ClearButton(button, reason)
    end, true)
end

local function ClearAll(reason)
    ForEachRewardsFrame(function(rewardsFrame)
        ClearFrame(rewardsFrame, reason or "surfaceClear")
    end)
end

function RefreshFrame(rewardsFrame, config)
    if not rewardsFrame then
        return
    end

    config = BuildSurfaceConfig(config)
    if not config or not config.questsEnabled then
        ClearFrame(rewardsFrame, "questDisabled")
        return
    end

    local configVersion = NS.RuntimeConfig and NS.RuntimeConfig.GetVersion and NS.RuntimeConfig.GetVersion() or 0
    local dynamicVersion = NS.Renderer and NS.Renderer._dynamicVersion or 0
    local records = {}

    EnumerateRewardButtons(rewardsFrame, function(button, kind)
        if button.IsShown and not button:IsShown() then
            ClearButton(button, "questHidden")
            return
        end

        records[#records + 1] = {
            button = button,
            entry = BuildEntry(rewardsFrame, button, kind),
        }
    end, true)

    table.sort(records, function(left, right)
        return BuildRecordSortKey(left) < BuildRecordSortKey(right)
    end)
    local signature = BuildFrameSignature(rewardsFrame, configVersion, dynamicVersion, records)
    if lastFrameSignature[rewardsFrame] == signature then
        return
    end
    lastFrameSignature[rewardsFrame] = signature

    for index = 1, #records do
        local record = records[index]
        if record.entry then
            UpdateButton(record.button, rewardsFrame, config, record.entry)
        else
            ClearButton(record.button, "questEmpty")
        end
    end
end

local function RefreshVisible(config)
    ForEachRewardsFrame(function(rewardsFrame)
        if IsFrameShown(rewardsFrame) then
            RefreshFrame(rewardsFrame, config)
        end
    end)
end

local function HookRewardsFrame(rewardsFrame)
    if not rewardsFrame or rewardsFrame.__BlizzItemGlowFixQuestHooked then
        return
    end

    rewardsFrame.__BlizzItemGlowFixQuestHooked = true

    if rewardsFrame.HookScript then
        rewardsFrame:HookScript("OnShow", function(frame)
            RefreshFrame(frame, BuildSurfaceConfig())
        end)

        rewardsFrame:HookScript("OnHide", function(frame)
            ClearFrame(frame, "surfaceClear")
        end)
    end
end

local function EnsureFrameHooks()
    ForEachRewardsFrame(HookRewardsFrame)
end

local function EnsureEventFrame()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("QUEST_FINISHED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            EnsureFrameHooks()
        elseif event == "QUEST_FINISHED" then
            ClearAll("surfaceClear")
        end
    end)
end

local function InstallHooks()
    if hooksInstalled then
        EnsureFrameHooks()
        return
    end

    hooksInstalled = true
    EnsureEventFrame()
    EnsureFrameHooks()

    if type(QuestInfo_ShowRewards) == "function" then
        hooksecurefunc("QuestInfo_ShowRewards", function()
            EnsureFrameHooks()
            local infoFrame = GetQuestInfoFrame()
            local rewardsFrame = infoFrame and infoFrame.rewardsFrame or nil
            if rewardsFrame and IsFrameShown(rewardsFrame) then
                RefreshFrame(rewardsFrame, BuildSurfaceConfig())
            else
                RefreshVisible(BuildSurfaceConfig())
            end
        end)
    end

    if type(QuestInfo_Display) == "function" then
        hooksecurefunc("QuestInfo_Display", function()
            EnsureFrameHooks()
            RefreshVisible(BuildSurfaceConfig())
        end)
    end
end

local function EnsureHooks()
    InstallHooks()
end

function Surface.RefreshVisible()
    EnsureHooks()
    RefreshVisible(BuildSurfaceConfig())
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    EnsureHooks()
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("quests", Surface)
end
