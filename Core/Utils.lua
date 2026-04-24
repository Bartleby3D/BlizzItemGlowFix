local _, NS = ...


local unpack = unpack or table.unpack

if NS.USE_SAFE_CALLS == nil then
    NS.USE_SAFE_CALLS = true
end

local function BuildSafeErrorMessage(context, err)
    local message = tostring(err)
    if type(context) == "string" and context ~= "" then
        message = context .. ": " .. message
    end

    if type(debugstack) == "function" then
        local stack = debugstack(3, 20, 20)
        if type(stack) == "string" and stack ~= "" then
            message = message .. "\n" .. stack
        end
    end

    return message
end

function NS.SafeCall(context, func, ...)
    if type(func) ~= "function" then
        return false
    end

    local args = { ... }

    local function ErrorHandler(err)
        local message = BuildSafeErrorMessage(context, err)

        if type(CallErrorHandler) == "function" then
            CallErrorHandler(message)
        else
            local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
            if type(handler) == "function" then
                handler(message)
            end
        end

        return message
    end

    return xpcall(function()
        return func(unpack(args))
    end, ErrorHandler)
end


function NS.Call(context, func, ...)
    if type(func) ~= "function" then
        return false
    end

    if NS.USE_SAFE_CALLS == false then
        return true, func(...)
    end

    return NS.SafeCall(context, func, ...)
end

function NS.TryCall(context, func, ...)
    local ok, result1, result2, result3, result4, result5 = NS.Call(context, func, ...)
    if ok then
        return result1, result2, result3, result4, result5
    end
    return nil
end

function NS.Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function NS.GetConfig(key, defaultValue, context)
    if key == nil or not (NS.Config and NS.Config.Get) then
        return defaultValue
    end

    local value = NS.Config.Get(key, context or "Global")
    if value == nil then
        return defaultValue
    end

    return value
end

function NS.GetConfigColor(key, defaultR, defaultG, defaultB, defaultA, context)
    if NS.Config and NS.Config.GetColor then
        local r, g, b, a = NS.Config.GetColor(key, context or "Global")
        if r ~= nil or g ~= nil or b ~= nil or a ~= nil then
            return r or defaultR or 1, g or defaultG or 1, b or defaultB or 1, a or defaultA or 1
        end
    end

    return defaultR or 1, defaultG or 1, defaultB or 1, defaultA or 1
end

function NS.GetConfigClamped(key, defaultValue, minValue, maxValue, context)
    return NS.Clamp(NS.GetConfig(key, defaultValue, context), minValue, maxValue)
end


local function PixelRoundNearest(value)
    if value == nil then return 0 end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function GetPixelToUIUnitFactor()
    local _, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight <= 0 then
        return 1
    end
    return 768.0 / physicalHeight
end

local function GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
    uiUnitSize = tonumber(uiUnitSize) or 0
    layoutScale = tonumber(layoutScale) or 1
    if layoutScale == 0 then
        return uiUnitSize
    end
    if uiUnitSize == 0 and (not minPixels or minPixels == 0) then
        return 0
    end

    local uiUnitFactor = GetPixelToUIUnitFactor()
    local numPixels = PixelRoundNearest((uiUnitSize * layoutScale) / uiUnitFactor)
    if minPixels then
        if uiUnitSize < 0 then
            if numPixels > -minPixels then
                numPixels = -minPixels
            end
        else
            if numPixels < minPixels then
                numPixels = minPixels
            end
        end
    end

    return numPixels * uiUnitFactor / layoutScale
end

function NS.PixelSnapValue(region, value, minPixels)
    if not region or not region.GetEffectiveScale then
        return tonumber(value) or 0
    end
    return GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels)
end

function NS.PixelSnapSetSize(region, width, height, minWidthPixels, minHeightPixels)
    if not region then return end
    region:SetSize(
        NS.PixelSnapValue(region, width, minWidthPixels),
        NS.PixelSnapValue(region, height, minHeightPixels)
    )
end

function NS.PixelSnapSetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY, minOffsetXPixels, minOffsetYPixels)
    if not region then return end
    region:SetPoint(
        point,
        relativeTo,
        relativePoint,
        NS.PixelSnapValue(region, offsetX, minOffsetXPixels),
        NS.PixelSnapValue(region, offsetY, minOffsetYPixels)
    )
end



function NS.VisitDescendants(rootFrame, visitor)
    if not rootFrame or type(visitor) ~= "function" then
        return
    end

    local stack = { rootFrame }
    local stackSize = 1

    while stackSize > 0 do
        local frame = stack[stackSize]
        stack[stackSize] = nil
        stackSize = stackSize - 1

        if frame then
            visitor(frame)

            local numChildren = frame.GetNumChildren and frame:GetNumChildren() or 0
            if numChildren > 0 and frame.GetChildren then
                for index = numChildren, 1, -1 do
                    local child = select(index, frame:GetChildren())
                    if child then
                        stackSize = stackSize + 1
                        stack[stackSize] = child
                    end
                end
            end
        end
    end
end
