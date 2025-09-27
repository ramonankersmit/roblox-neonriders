-- DisableDefaultCamera.client.lua — persistente purge + harde Scriptable-lock
local Players = game:GetService("Players")
local player  = Players.LocalPlayer
local cam     = workspace.CurrentCamera

local CameraGuard = require(script.Parent:WaitForChild("CameraGuard"))
local GUARD_ID = "DisableDefaultCamera"

local BAD = { PlayerModule=true, PlayerScriptsLoader=true }

local function nuke(child)
	if BAD[child.Name] then
		print(("[Fix] Removing %s"):format(child:GetFullName()))
		child:Destroy()
	end
end

local function purge()
	-- Freecam GUI
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		local fc = pg:FindFirstChild("Freecam"); if fc then fc:Destroy() end
		pcall(function()
			pg.ChildAdded:Connect(function(ch)
				if ch.Name=="Freecam" then task.defer(function() if ch and ch.Parent then ch:Destroy() end end) end
			end)
		end)
	end
	-- Standaard camera scripts
	local ps = player:FindFirstChild("PlayerScripts")
	if ps then
		for _,ch in ipairs(ps:GetChildren()) do nuke(ch) end
		pcall(function()
			ps.ChildAdded:Connect(function(ch) nuke(ch) end)
		end)
	end
end

-- Init + na elke respawn meerdere keren voor zekerheid
purge()
task.defer(purge)
task.delay(2, purge)
player.CharacterAdded:Connect(function()
	task.defer(purge)
	task.delay(0.25, purge)
	task.delay(2, purge)
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
