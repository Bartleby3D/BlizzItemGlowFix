local _, NS = ...

NS.Surfaces = NS.Surfaces or {}
NS.Surfaces.Bags = NS.Surfaces.Bags or {}
local Surface = NS.Surfaces.Bags

local hookedFrames = setmetatable({}, { __mode = "k" })
local initialized = false

local function ForEachButton(frame, visitor)
    if not frame or type(visitor) ~= "function" then
        return
    end

    if type(frame.EnumerateValidItems) == "function" then
        for _, itemButton in frame:EnumerateValidItems() do
            if itemButton then
                visitor(itemButton)
            end
        end
        return
    end

    local size = frame.size or 0
    local name = frame.GetName and frame:GetName() or nil
    if name and size > 0 then
        for index = 1, size do
            local button = _G[name .. "Item" .. index]
            if button then
                visitor(button)
            end
        end
        return
    end

    if type(frame.Items) == "table" then
        for _, button in ipairs(frame.Items) do
            if button then
                visitor(button)
            end
        end
    end
end

local function GetButtonBagAndSlot(button, fallbackBag)
    if not button then
        return nil, nil
    end

    local bagID = button.GetBagID and button:GetBagID() or fallbackBag
    local slotID = button.GetID and button:GetID() or nil
    return bagID, slotID
end

local function ClearFrame(frame)
    ForEachButton(frame, function(button)
        NS.Renderer.ClearButton(button, "surfaceClear")
    end)
end

local function UpdateButton(button, config, fallbackBag)
    local bagID, slotID = GetButtonBagAndSlot(button, fallbackBag)
    if bagID == nil or slotID == nil then
        NS.Renderer.ClearButton(button, "invalidBagSlot")
        return
    end

    NS.Renderer.UpdateBagButton(button, bagID, slotID, config)
end

local function QueueFrameWarmup(frame)
    ForEachButton(frame, function(button)
        if NS.AssetWarmup and NS.AssetWarmup.QueueButton then
            NS.AssetWarmup.QueueButton(button)
        end
    end)
end

local function UpdateFrame(frame)
    if not frame then
        return
    end
    local buttonCount = 0

    local config = NS.RuntimeConfig.GetSnapshot()
    if not config.bagsEnabled then
        ClearFrame(frame)
        return
    end

    local frameBagID = frame.GetID and frame:GetID() or nil
    ForEachButton(frame, function(button)
        buttonCount = buttonCount + 1
        UpdateButton(button, config, frameBagID)
    end)
end

local function HookFrame(frame)
    if not frame or hookedFrames[frame] then
        return
    end

    hookedFrames[frame] = true

    frame:HookScript("OnHide", function(self)
    end)

    if not frame.__BlizzItemGlowFixWarmupQueued then
        frame.__BlizzItemGlowFixWarmupQueued = true
        if (not frame.IsShown) or (not frame:IsShown()) then
            QueueFrameWarmup(frame)
        end
    end
end

function Surface.RefreshVisible()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.IsShown and combined:IsShown() then
        UpdateFrame(combined)
    end

    local container = _G.ContainerFrameContainer
    local frames = container and container.ContainerFrames
    if type(frames) == "table" then
        for _, frame in ipairs(frames) do
            if frame and frame.IsShown and frame:IsShown() then
                UpdateFrame(frame)
            end
        end
        return
    end

    local frameCount = tonumber(NUM_CONTAINER_FRAMES) or 20
    for index = 1, frameCount do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.IsShown and frame:IsShown() then
            UpdateFrame(frame)
        end
    end
end

function Surface.Initialize()
    if initialized then
        return
    end
    initialized = true
    if type(ContainerFrame_GenerateFrame) == "function" then
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            HookFrame(frame)
        end)
    end

    if _G.ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function(frame)
            HookFrame(frame)
            UpdateFrame(frame)
        end)
    else
        local function HookUpdateItems(frame)
            if not frame or frame.__BlizzItemGlowFixUpdateItemsHooked then
                return
            end
            frame.__BlizzItemGlowFixUpdateItemsHooked = true
            HookFrame(frame)
            hooksecurefunc(frame, "UpdateItems", function(self)
                UpdateFrame(self)
            end)
        end

        HookUpdateItems(_G.ContainerFrameCombinedBags)

        local container = _G.ContainerFrameContainer
        local frames = container and container.ContainerFrames
        if type(frames) == "table" then
            for _, frame in ipairs(frames) do
                HookUpdateItems(frame)
            end
        else
            local frameCount = tonumber(NUM_CONTAINER_FRAMES) or 20
            for index = 1, frameCount do
                HookUpdateItems(_G["ContainerFrame" .. index])
            end
        end
    end

    HookFrame(_G.ContainerFrameCombinedBags)

    local frameCount = tonumber(NUM_CONTAINER_FRAMES) or 20
    for index = 1, frameCount do
        local frame = _G["ContainerFrame" .. index]
        HookFrame(frame)
    end
end

if NS.SurfaceRegistry and NS.SurfaceRegistry.Register then
    NS.SurfaceRegistry.Register("bags", Surface)
end
