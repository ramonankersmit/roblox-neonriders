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
local lastReleasedId = nil
local lastReleaseFrame = 0

RunService.RenderStepped:Connect(function()
    frameSerial += 1
    activeWriter = nil
    activeReason = nil
    warnedForFrame = {}
    lastReleasedId = nil
    lastReleaseFrame = frameSerial
end)

function CameraGuard:tryAcquire(id, reason)
    assert(id, "CameraGuard: id required")
    if activeWriter == nil then
        if lastReleaseFrame == frameSerial and lastReleasedId and lastReleasedId ~= id then
            -- iemand anders heeft deze frame al geschreven; blokkeer overige schrijvers
            return false
        end
    end

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
        lastReleasedId = id
        lastReleaseFrame = frameSerial
        -- we houden de writer "bezet" voor de rest van het frame zodat niemand anders meer schrijft
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

