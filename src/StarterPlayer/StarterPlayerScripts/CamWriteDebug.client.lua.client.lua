-- CamWriteDebug.client.lua — detecteer meerdere camera-writes in één frame
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera

local writes = 0
local spamLimiter = 0

-- tel elke CFrame-wijziging
cam:GetPropertyChangedSignal("CFrame"):Connect(function()
	writes += 1
	if writes > 1 and spamLimiter < 6 then
		-- laat zien dat er >1 write was in ditzelfde renderframe
		warn(("[CamDebug] Multiple camera writes this frame: %d"):format(writes))
		-- (optioneel) stacktrace van de laatste schrijver:
		warn(debug.traceback())
		spamLimiter += 1
	end
end)

-- elke RenderStepped = nieuw frame → teller resetten
RunService.RenderStepped:Connect(function()
	writes = 0
end)

-- iemand die CameraType wisselt?
cam:GetPropertyChangedSignal("CameraType"):Connect(function()
	warn("[CamDebug] CameraType changed to:", cam.CameraType)
end)
