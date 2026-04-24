local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Mail = NS.Surfaces.Mail or {}
local Surface = NS.Surfaces.Mail

local initialized = false
local hooksInstalled = false
local addonLoadedFrame = nil
local cachedSurfaceConfig = nil
local cachedSurfaceConfigVersion = nil

local SEND_PREFIX = "SendMailAttachment"
local OPEN_PREFIX = "OpenMailAttachmentButton"
local INBOX_PREFIX = "MailItem"
local FALLBACK_SEND_MAX = 12
local FALLBACK_OPEN_MAX = 16
local FALLBACK_INBOX_MAX = 7

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
    config.mailEnabled = baseConfig.mailEnabled ~= false

    cachedSurfaceConfig = config
    cachedSurfaceConfigVersion = version
    return config
end

local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetInboxDisplayCount()
    return tonumber(_G.INBOXITEMS_TO_DISPLAY) or FALLBACK_INBOX_MAX
end

local function GetSendAttachmentCount()
    return tonumber(_G.ATTACHMENTS_MAX_SEND) or FALLBACK_SEND_MAX
end

local function GetOpenAttachmentCount()
    return tonumber(_G.ATTACHMENTS_MAX) or tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or FALLBACK_OPEN_MAX
end

local function GetInboxFrame()
    return _G.InboxFrame
end

local function GetSendMailFrame()
    return _G.SendMailFrame
end

local function GetOpenMailFrame()
    return _G.OpenMailFrame
end

local function GetMailFrame()
    return _G.MailFrame
end

local function GetCurrentOpenMailID()
    local inboxFrame = GetInboxFrame()
    return inboxFrame and inboxFrame.openMailID or nil
end

local function HasInboxDataReady()
    if type(GetInboxNumItems) ~= "function" then
        return false
    end

    local itemCount = GetInboxNumItems()
    itemCount = tonumber(itemCount) or 0
    return itemCount > 0
end

local function MakeButtonInfo(kind, index)
    if type(kind) ~= "string" or kind == "" then
        return nil
    end

    index = tonumber(index)
    if not index or index <= 0 then
        return nil
    end

    return {
        kind = kind,
        index = index,
    }
end

local function SetButtonInfo(button, kind, index)
    if button then
        button.__BlizzItemGlowFixMailInfo = MakeButtonInfo(kind, index)
    end
end

local function GetButtonInfo(button)
    return button and button.__BlizzItemGlowFixMailInfo or nil
end

local function IterateSendButtons(callback)
    if type(callback) ~= "function" then
        return
    end

    local frame = GetSendMailFrame()
    if frame and type(frame.SendMailAttachments) == "table" then
        for index = 1, GetSendAttachmentCount() do
            local button = frame.SendMailAttachments[index]
            if button then
                SetButtonInfo(button, "send", index)
                callback(button, index)
            end
        end
        return
    end

    for index = 1, GetSendAttachmentCount() do
        local button = _G[SEND_PREFIX .. tostring(index)]
        if button then
            SetButtonInfo(button, "send", index)
            callback(button, index)
        end
    end
end

local function IterateOpenButtons(callback)
    if type(callback) ~= "function" then
        return
    end

    local frame = GetOpenMailFrame()
    if frame and type(frame.OpenMailAttachments) == "table" then
        for index = 1, GetOpenAttachmentCount() do
            local button = frame.OpenMailAttachments[index]
            if button then
                SetButtonInfo(button, "open", index)
                callback(button, index)
            end
        end
        return
    end

    for index = 1, GetOpenAttachmentCount() do
        local button = _G[OPEN_PREFIX .. tostring(index)]
        if button then
            SetButtonInfo(button, "open", index)
            callback(button, index)
        end
    end
end

local function IterateInboxButtons(callback)
    if type(callback) ~= "function" then
        return
    end

    for index = 1, GetInboxDisplayCount() do
        local button = _G[INBOX_PREFIX .. tostring(index) .. "Button"]
        if button then
            SetButtonInfo(button, "inbox", index)
            callback(button, index)
        end
    end
end

local function GetValidLink(link)
    if type(link) == "string" and link ~= "" then
        return link
    end
    return nil
end

local function BuildSendEntry(index)
    index = tonumber(index)
    if not index or index <= 0 or type(GetSendMailItem) ~= "function" then
        return nil
    end

    local name, itemID, texture, stackCount, quality = GetSendMailItem(index)
    if not name and not itemID and not texture and not stackCount then
        return nil
    end

    local itemLink = type(GetSendMailItemLink) == "function" and GetValidLink(GetSendMailItemLink(index)) or nil
    if not itemLink and not itemID then
        return nil
    end

    return {
        kind = "send",
        index = index,
        itemLink = itemLink,
        itemID = itemID,
        quality = (quality ~= nil and quality >= 0) and quality or nil,
        stackCount = stackCount or 0,
        hasNoValue = false,
        isQuestItem = false,
    }
end

local function BuildOpenEntry(index)
    index = tonumber(index)
    local mailID = GetCurrentOpenMailID()
    if not index or index <= 0 or not mailID or type(GetInboxItem) ~= "function" then
        return nil
    end

    local name, itemID, texture, stackCount, quality = GetInboxItem(mailID, index)
    if not name and not itemID and not texture and not stackCount then
        return nil
    end

    local itemLink = type(GetInboxItemLink) == "function" and GetValidLink(GetInboxItemLink(mailID, index)) or nil
    if not itemLink and not itemID then
        return nil
    end

    return {
        kind = "open",
        index = index,
        mailID = mailID,
        itemLink = itemLink,
        itemID = itemID,
        quality = (quality ~= nil and quality >= 0) and quality or nil,
        stackCount = stackCount or 0,
        hasNoValue = false,
        isQuestItem = false,
    }
end

local function BuildInboxEntry(displayIndex)
    displayIndex = tonumber(displayIndex)
    if not displayIndex or displayIndex <= 0 or type(GetInboxHeaderInfo) ~= "function" then
        return nil
    end

    local pageNum = (GetInboxFrame() and GetInboxFrame().pageNum) or 1
    local inboxIndex = ((pageNum - 1) * GetInboxDisplayCount()) + displayIndex
    local _, _, _, _, _, _, _, itemCount = GetInboxHeaderInfo(inboxIndex)
    if not itemCount or itemCount <= 0 or type(GetInboxItem) ~= "function" then
        return nil
    end

    local name, itemID, texture, stackCount, quality = GetInboxItem(inboxIndex, 1)
    if not name and not itemID and not texture and not stackCount then
        return nil
    end

    local itemLink = type(GetInboxItemLink) == "function" and GetValidLink(GetInboxItemLink(inboxIndex, 1)) or nil
    if not itemLink and not itemID then
        return nil
    end

    return {
        kind = "inbox",
        index = displayIndex,
        inboxIndex = inboxIndex,
        pageNum = pageNum,
        itemLink = itemLink,
        itemID = itemID,
        quality = (quality ~= nil and quality >= 0) and quality or nil,
        stackCount = stackCount or 0,
        hasNoValue = false,
        isQuestItem = false,
    }
end

local function BuildEntry(kind, index)
    if kind == "send" then
        return BuildSendEntry(index)
    elseif kind == "open" then
        return BuildOpenEntry(index)
    elseif kind == "inbox" then
        return BuildInboxEntry(index)
    end

    return nil
end

local function ResolveCurrentEntry(button)
    local info = GetButtonInfo(button)
    if not info then
        return nil
    end

    return BuildEntry(info.kind, info.index)
end

local function BuildSlotKey(entry)
    if not entry then
        return nil
    end

    if entry.kind == "send" then
        return table.concat({ "mail", "send", tostring(entry.index or 0) }, ":")
    elseif entry.kind == "open" then
        return table.concat({ "mail", "open", tostring(entry.mailID or 0), tostring(entry.index or 0) }, ":")
    elseif entry.kind == "inbox" then
        return table.concat({ "mail", "inbox", tostring(entry.pageNum or 0), tostring(entry.inboxIndex or 0), tostring(entry.index or 0) }, ":")
    end

    return table.concat({ "mail", tostring(entry.kind or "unknown"), tostring(entry.index or 0) }, ":")
end

local function ClearButton(button, reason)
    if not button then
        return
    end

    button.__BlizzItemGlowFixMailInfo = nil
    NS.Renderer.ClearButton(button, reason or "mailClear")
end

local function ClearSendButtons(reason)
    IterateSendButtons(function(button)
        ClearButton(button, reason)
    end)
end

local function ClearOpenButtons(reason)
    IterateOpenButtons(function(button)
        ClearButton(button, reason)
    end)
end

local function ClearInboxButtons(reason)
    IterateInboxButtons(function(button)
        ClearButton(button, reason)
    end)
end

local function UpdateButton(button, info, config)
    if not button then
        return
    end

    info = info or GetButtonInfo(button)
    if not info then
        ClearButton(button, "mailMissingInfo")
        return
    end

    config = BuildSurfaceConfig(config)
    if not config or not config.mailEnabled then
        ClearButton(button, "mailDisabled")
        return
    end

    local entry = BuildEntry(info.kind, info.index)
    if not entry then
        ClearButton(button, "mailEmpty")
        return
    end

    local wantItemLevel = config.ilvlSectionEnabled == true or (config.iconsSectionEnabled == true and config.upgradeIconEnabled == true)
    local snapshot = NS.ItemDataStore.GetExternalItemSnapshot(
        BuildSlotKey(entry),
        entry.itemLink,
        entry.itemID,
        entry.quality,
        entry.stackCount,
        entry.hasNoValue,
        entry.isQuestItem,
        wantItemLevel,
        function()
            local currentEntry = ResolveCurrentEntry(button)
            if not currentEntry then
                ClearButton(button, "mailCallbackEmpty")
                return
            end

            UpdateButton(button, GetButtonInfo(button), nil)
        end,
        button
    )

    NS.Renderer.UpdateSnapshot(button, snapshot, config, "mail")
end

local function RefreshSendVisible(config)
    if not IsFrameShown(GetSendMailFrame()) then
        return
    end
    local buttonCount = 0
    config = BuildSurfaceConfig(config)

    if not config or not config.mailEnabled then
        ClearSendButtons("mailDisabled")
        return
    end

    IterateSendButtons(function(button, index)
        buttonCount = buttonCount + 1
        UpdateButton(button, MakeButtonInfo("send", index), config)
    end)
end

local function RefreshOpenVisible(config)
    if not IsFrameShown(GetOpenMailFrame()) then
        return
    end
    local buttonCount = 0
    config = BuildSurfaceConfig(config)

    if not config or not config.mailEnabled then
        ClearOpenButtons("mailDisabled")
        return
    end

    IterateOpenButtons(function(button, index)
        buttonCount = buttonCount + 1
        UpdateButton(button, MakeButtonInfo("open", index), config)
    end)
end

local function RefreshInboxVisible(config)
    if not IsFrameShown(GetInboxFrame()) then
        return
    end
    local buttonCount = 0
    config = BuildSurfaceConfig(config)

    if not config or not config.mailEnabled then
        ClearInboxButtons("mailDisabled")
        return
    end

    IterateInboxButtons(function(button, index)
        buttonCount = buttonCount + 1
        UpdateButton(button, MakeButtonInfo("inbox", index), config)
    end)
end

local function ClearVisible(reason)
    if IsFrameShown(GetInboxFrame()) then
        ClearInboxButtons(reason or "surfaceClear")
    end
    if IsFrameShown(GetSendMailFrame()) then
        ClearSendButtons(reason or "surfaceClear")
    end
    if IsFrameShown(GetOpenMailFrame()) then
        ClearOpenButtons(reason or "surfaceClear")
    end
end

local function ClearAll(reason)
    ClearInboxButtons(reason or "surfaceClear")
    ClearSendButtons(reason or "surfaceClear")
    ClearOpenButtons(reason or "surfaceClear")
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    if not (type(InboxFrame_Update) == "function" and type(SendMailFrame_Update) == "function" and type(OpenMail_Update) == "function" and type(MailFrame_Show) == "function") then
        return
    end

    hooksInstalled = true

    hooksecurefunc("MailFrame_Show", function()
        local config = BuildSurfaceConfig()

        if config and config.mailEnabled then
            if HasInboxDataReady() then
                RefreshInboxVisible(config)
            end
            RefreshSendVisible(config)
            RefreshOpenVisible(config)
        else
            ClearVisible("mailDisabled")
        end
    end)

    hooksecurefunc("InboxFrame_Update", function()
        RefreshInboxVisible(BuildSurfaceConfig())
    end)

    hooksecurefunc("SendMailFrame_Update", function()
        RefreshSendVisible(BuildSurfaceConfig())
    end)

    hooksecurefunc("OpenMail_Update", function()
        RefreshOpenVisible(BuildSurfaceConfig())
    end)

    local openMailFrame = GetOpenMailFrame()
    if openMailFrame and openMailFrame.HookScript then
        openMailFrame:HookScript("OnShow", function()
            RefreshOpenVisible(BuildSurfaceConfig())
        end)
    end

    local mailFrame = GetMailFrame()
    if mailFrame and mailFrame.HookScript then
        mailFrame:HookScript("OnHide", function()
            ClearAll("surfaceClear")
        end)
    end
end

local function EnsureHooks()
    InstallHooks()
end

function Surface.RefreshVisible()
    EnsureHooks()

    local mailFrame = GetMailFrame()
    if not IsFrameShown(mailFrame) then
        return
    end

    local config = BuildSurfaceConfig()
    if not config or not config.mailEnabled then
        ClearVisible("mailDisabled")
        return
    end

    RefreshInboxVisible(config)
    RefreshSendVisible(config)
    RefreshOpenVisible(config)
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true

    EnsureHooks()

    if not hooksInstalled then
        addonLoadedFrame = CreateFrame("Frame")
        addonLoadedFrame:RegisterEvent("ADDON_LOADED")
        addonLoadedFrame:SetScript("OnEvent", function(_, event, addonName)
            if event == "ADDON_LOADED" and (addonName == "Blizzard_MailFrame" or addonName == "Blizzard_MailUI") then
                EnsureHooks()
                if hooksInstalled and addonLoadedFrame then
                    addonLoadedFrame:UnregisterAllEvents()
                    addonLoadedFrame:SetScript("OnEvent", nil)
                    addonLoadedFrame = nil
                end
            end
        end)
    end
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("mail", Surface)
end
