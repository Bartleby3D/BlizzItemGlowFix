local _, NS = ...

NS.BorderGlowCalibration = NS.BorderGlowCalibration or {}
local Calibration = NS.BorderGlowCalibration

local MAX_OFFSET = 1

-- Internal per-surface anchor calibration for border/glow textures.
-- No UI. No SavedVariables. No profile migration.
-- Values are SetPoint anchor offsets in UI units. Keep them small: -1..1.
local OFFSETS = {
    bags = { x = 0, y = 0 },

    characterBank = { x = 0, y = -0.5 },
    warbandBank = { x = 0, y = -0.5 },
    guildBank = { x = 0, y = -0.5 },

    character = { x = 0, y = -0.5 },
    inspect = { x = 0, y = -0.5 },

    merchant = { x = 0, y = -0.5 },
    mail = { x = 0, y = 0 },
    trade = { x = 0, y = 0 },
    loot = { x = 0, y = -0.5 },
    quests = { x = 0, y = -0.1 },

    professionJournal = { x = -0.5, y = -0.5 },
    craftingOrders = { x = 0, y = 0 },
}

local function Clamp(value)
    value = tonumber(value) or 0

    if value < -MAX_OFFSET then
        return -MAX_OFFSET
    end

    if value > MAX_OFFSET then
        return MAX_OFFSET
    end

    return value
end

function Calibration.GetAnchorOffset(surfaceKey)
    local offset = OFFSETS[surfaceKey]
    if not offset then
        return 0, 0
    end

    return Clamp(offset.x), Clamp(offset.y)
end
