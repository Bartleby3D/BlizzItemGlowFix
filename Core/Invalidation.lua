local _, NS = ...

NS.Invalidation = NS.Invalidation or {}
local Invalidation = NS.Invalidation

function Invalidation.RefreshVisible(reason)
    if NS.SurfaceRegistry and NS.SurfaceRegistry.RefreshVisible then
        NS.SurfaceRegistry.RefreshVisible(reason)
    end
end

function Invalidation.OnConfigChanged()
    if NS.RuntimeConfig and NS.RuntimeConfig.Invalidate then
        NS.RuntimeConfig.Invalidate()
    end
    if NS.AssetWarmup and NS.AssetWarmup.WarmupAssets then
        NS.AssetWarmup.WarmupAssets()
    end

    Invalidation.RefreshVisible("config")
end

function Invalidation.OnDynamicChanged(reason)
    if NS.Renderer and NS.Renderer.InvalidateDynamicState then
        NS.Renderer.InvalidateDynamicState()
    end

    Invalidation.RefreshVisible(reason or "dynamic")
end
