-- CameraGuard.lua
-- Houdt bij welk script de camera mag schrijven in het huidige render-frame.
-- Scripts vragen via tryAcquire/release exclusieve toegang zodat de camera
-- maar één keer per frame wordt gezet.

local RunService = game:GetService("RunService")

local CameraGuard = {}

local activeWriter = nil
local activeReason = nil
local frameSerial = 0
local warnedForFrame = {}

RunService.RenderStepped:Connect(function()
    frameSerial += 1
    activeWriter = nil
    activeReason = nil
    warnedForFrame = {}
end)

function CameraGuard:tryAcquire(id, reason)
    assert(id, "CameraGuard: id required")
    if activeWriter == nil or activeWriter == id then
        activeWriter = id
        activeReason = reason
        return true
    end

    local warnKey = id .. "@" .. frameSerial
    if not warnedForFrame[warnKey] then
        warnedForFrame[warnKey] = true
        warn(("[CameraGuard] %s blocked by %s (%s)"):format(
            id,
            tostring(activeWriter),
            tostring(activeReason or "no-reason")
        ))
    end

    return false
end

function CameraGuard:release(id)
    if activeWriter == id then
        activeWriter = nil
        activeReason = nil
        return true
    end
    return false
end

function CameraGuard:currentWriter()
    return activeWriter, activeReason
end

return CameraGuard

