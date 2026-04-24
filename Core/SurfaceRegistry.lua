local _, NS = ...

NS.SurfaceRegistry = NS.SurfaceRegistry or {}
local Registry = NS.SurfaceRegistry

Registry._surfaces = Registry._surfaces or {}

function Registry.Register(name, surface)
    if type(name) ~= "string" or name == "" or type(surface) ~= "table" then
        return nil
    end

    Registry._surfaces[name] = surface
    return surface
end

function Registry.Get(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    return Registry._surfaces[name]
end

function Registry.ForEach(visitor)
    if type(visitor) ~= "function" then
        return
    end

    for name, surface in pairs(Registry._surfaces) do
        visitor(name, surface)
    end
end

function Registry.InitializeAll()
    Registry.ForEach(function(_, surface)
        if type(surface.Initialize) == "function" then
            NS.SafeCall("SurfaceRegistry.Initialize", surface.Initialize)
        end
    end)
end

function Registry.RefreshVisible(reason)
    Registry.ForEach(function(_, surface)
        if type(surface.RefreshVisible) == "function" then
            NS.SafeCall("SurfaceRegistry.RefreshVisible", surface.RefreshVisible, reason)
        end
    end)
end
