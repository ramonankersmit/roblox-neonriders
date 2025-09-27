-- DisableDefaultCamera.client.lua — disable Roblox default camera controls and enforce Scriptable lock
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local CameraGuard = require(script.Parent:WaitForChild("CameraGuard"))
local GUARD_ID = "DisableDefaultCamera"

local function disableDefaultControls()
    local playerScripts = player:WaitForChild("PlayerScripts")
    local okModule, playerModule = pcall(function()
        return require(playerScripts:WaitForChild("PlayerModule"))
    end)
    if okModule and playerModule then
        local okControls, controls = pcall(function()
            return playerModule:GetControls()
        end)
        if okControls and controls then
            controls:Disable()
        end
    end
end

disableDefaultControls()
player.CharacterAdded:Connect(function()
    task.defer(disableDefaultControls)
end)

local locking = false
cam:GetPropertyChangedSignal("CameraType"):Connect(function()
    if locking then return end
    if cam.CameraType ~= Enum.CameraType.Scriptable then
        if CameraGuard:tryAcquire(GUARD_ID, "camTypeChanged") then
            locking = true
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CameraSubject = nil
            locking = false
            CameraGuard:release(GUARD_ID)
        end
    end
end)

if CameraGuard:tryAcquire(GUARD_ID, "init") then
    cam.CameraType = Enum.CameraType.Scriptable
    cam.CameraSubject = nil
    CameraGuard:release(GUARD_ID)
end
