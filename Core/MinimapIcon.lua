local _, NS = ...

NS.MinimapIcon = NS.MinimapIcon or {}
local MinimapIcon = NS.MinimapIcon

local ADDON_NAME = "BlizzItemGlowFix"
local ICON_PATH = "Interface\\AddOns\\BlizzItemGlowFix\\Media\\BIGFIcon.tga"

local dataObject
local dbIconLib
local configCallbackRegistered = false

local function GetMinimapSettings()
    if not NS.Config or not NS.Config.GetTable then
        return nil
    end

    local db = NS.Config.GetTable("Global")
    if type(db) ~= "table" then
        return nil
    end

    db.minimap = db.minimap or {}

    if type(db.minimap.hide) ~= "boolean" then
        db.minimap.hide = false
    end

    if type(db.minimap.minimapPos) ~= "number" then
        db.minimap.minimapPos = 220
    end

    return db.minimap
end

local function ApplyVisibility()
    if not dbIconLib then
        return
    end

    local settings = GetMinimapSettings()
    if not settings then
        return
    end

    if settings.hide then
        dbIconLib:Hide(ADDON_NAME)
    else
        dbIconLib:Show(ADDON_NAME)
    end
end

local function ShowOptions()
    if NS.ToggleGUI then
        NS.ToggleGUI()
    end
end

local function CreateDataObject()
    if dataObject or not LibStub then
        return dataObject
    end

    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then
        return nil
    end

    dataObject = ldb:NewDataObject(ADDON_NAME, {
        type = "launcher",
        text = ADDON_NAME,
        icon = ICON_PATH,
        OnClick = function(_, button)
            if button == "LeftButton" or button == "RightButton" then
                ShowOptions()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or type(tooltip.AddLine) ~= "function" then
                return
            end

            tooltip:AddLine(NS.L and NS.L("BlizzItemGlowFix") or "BlizzItemGlowFix")
            tooltip:AddLine(NS.L and NS.L("Left Click: Open/Close") or "Left Click: Open/Close", 1, 1, 1)
            tooltip:AddLine(NS.L and NS.L("Right Click: Open/Close") or "Right Click: Open/Close", 1, 1, 1)
        end,
    })

    return dataObject
end

function MinimapIcon.RefreshVisibility()
    ApplyVisibility()
end

function MinimapIcon.Initialize()
    if not LibStub then
        return
    end

    if not dbIconLib then
        dbIconLib = LibStub:GetLibrary("LibDBIcon-1.0", true)
    end

    if not dbIconLib then
        return
    end

    local settings = GetMinimapSettings()
    local launcher = CreateDataObject()
    if not settings or not launcher then
        return
    end

    if not dbIconLib:IsRegistered(ADDON_NAME) then
        dbIconLib:Register(ADDON_NAME, launcher, settings)
    end

    if not configCallbackRegistered and NS.Config and NS.Config.RegisterCallback then
        NS.Config.RegisterCallback(function(key)
            if key == "minimap.hide" then
                MinimapIcon.RefreshVisibility()
            end
        end)
        configCallbackRegistered = true
    end

    MinimapIcon.RefreshVisibility()
end
