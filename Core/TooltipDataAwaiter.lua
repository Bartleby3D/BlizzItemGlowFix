local _, NS = ...

NS.TooltipDataAwaiter = NS.TooltipDataAwaiter or {}
local Awaiter = NS.TooltipDataAwaiter

local frame = Awaiter._frame
if not frame then
    frame = CreateFrame("Frame")
    Awaiter._frame = frame
end

Awaiter._pendingByInstanceID = Awaiter._pendingByInstanceID or {}

local function UpdateEventRegistration()
    if next(Awaiter._pendingByInstanceID) then
        frame:RegisterEvent("TOOLTIP_DATA_UPDATE")
    else
        frame:UnregisterEvent("TOOLTIP_DATA_UPDATE")
    end
end

function Awaiter.Track(dataInstanceID)
    dataInstanceID = tonumber(dataInstanceID)
    if not dataInstanceID or dataInstanceID <= 0 then
        return nil
    end

    Awaiter._pendingByInstanceID[dataInstanceID] = true
    UpdateEventRegistration()
    return dataInstanceID
end

function Awaiter.Untrack(dataInstanceID)
    dataInstanceID = tonumber(dataInstanceID)
    if not dataInstanceID or dataInstanceID <= 0 then
        return
    end

    Awaiter._pendingByInstanceID[dataInstanceID] = nil
    UpdateEventRegistration()
end

frame:SetScript("OnEvent", function(_, event, dataInstanceID)
    if event ~= "TOOLTIP_DATA_UPDATE" then
        return
    end

    dataInstanceID = tonumber(dataInstanceID)
    if not dataInstanceID or not Awaiter._pendingByInstanceID[dataInstanceID] then
        return
    end

    Awaiter._pendingByInstanceID[dataInstanceID] = nil
    UpdateEventRegistration()

    if NS.ItemDataStore and NS.ItemDataStore.NotifyTooltipDataUpdated then
        NS.ItemDataStore.NotifyTooltipDataUpdated(dataInstanceID)
    end
end)
