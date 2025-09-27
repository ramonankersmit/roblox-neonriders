-- DisableDefaultCamera.client.lua — disable Roblox default camera controls and enforce Scriptable lock
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local CameraGuard = require(script.Parent:WaitForChild("CameraGuard"))
local GUARD_ID = "DisableDefaultCamera"

local function disableDefaultControls()
    local playerScripts = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 5)
    if not playerScripts then
        warn("[DisableDefaultCamera] PlayerScripts not found; skipping controls disable")
        return
    end

    local playerModuleScript = playerScripts:FindFirstChild("PlayerModule") or playerScripts:WaitForChild("PlayerModule", 5)
    if not playerModuleScript then
        warn("[DisableDefaultCamera] PlayerModule not found; skipping controls disable")
        return
    end

    local okModule, playerModule = pcall(require, playerModuleScript)
    if not okModule or not playerModule then
        warn("[DisableDefaultCamera] Failed to require PlayerModule", okModule and "(nil)" or playerModule)
        return
    end

    local okControls, controls = pcall(function()
        if type(playerModule) == "table" and typeof(playerModule.GetControls) == "function" then
            return playerModule:GetControls()
        end
    end)
    if not okControls or not controls then
        warn("[DisableDefaultCamera] PlayerModule:GetControls unavailable; default controls stay enabled")
        return
    end

    local okDisable, err = pcall(function()
        controls:Disable()
    end)
    if not okDisable then
        warn("[DisableDefaultCamera] Controls:Disable failed", err)
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
