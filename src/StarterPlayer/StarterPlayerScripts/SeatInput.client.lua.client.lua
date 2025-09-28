local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local remotes = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 5)
local vehicleInput = remotes and (remotes:FindFirstChild("VehicleInput") or remotes:WaitForChild("VehicleInput", 5))
local remoteWarningShown = false

if not remotes then
	warn("[SeatInput] Remotes folder ontbreekt")
elseif not vehicleInput then
	warn("[SeatInput] VehicleInput ontbreekt")
end

local controls do
	local playerModule = localPlayer:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
		or localPlayer.PlayerScripts:WaitForChild("PlayerModule", 3)

	if playerModule then
		local success, module = pcall(require, playerModule)
		if success and module.GetControls then
			controls = module:GetControls()
		end
	end
end

local driving = false
local throttle = 0
local steer = 0
local renderConnection

local function ensureVehicleInput()
	if vehicleInput then
		return vehicleInput
	end

	local remotesFolder = RS:FindFirstChild("Remotes")
	if remotesFolder then
		vehicleInput = remotesFolder:FindFirstChild("VehicleInput")
	end

	if not vehicleInput and not remoteWarningShown then
		remoteWarningShown = true
		warn("[SeatInput] VehicleInput ontbreekt")
	end

	return vehicleInput
end

local function sendInput()
	if driving then
		local remote = ensureVehicleInput()
		if remote then
			remote:FireServer(throttle, steer)
		end
	end
end

local function drive(_, state, input)
	local keyCode = input.KeyCode
	local down = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change

	if keyCode == Enum.KeyCode.W then
		throttle = down and 1 or (throttle == 1 and 0 or throttle)
	elseif keyCode == Enum.KeyCode.S then
		throttle = down and -1 or (throttle == -1 and 0 or throttle)
	elseif keyCode == Enum.KeyCode.A then
		steer = down and -1 or (steer == -1 and 0 or steer)
	elseif keyCode == Enum.KeyCode.D then
		steer = down and 1 or (steer == 1 and 0 or steer)
	end

	sendInput()

	return Enum.ContextActionResult.Sink
end

local function bindDriving()
	if driving then
		return
	end

	local remote = ensureVehicleInput()
	if not remote then
		return
	end

	if controls and controls.Disable then
		controls:Disable()
	end

	CAS:BindActionAtPriority("DriveSeat", drive, false, 3000, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D)

	renderConnection = RunService.RenderStepped:Connect(sendInput)
	driving = true
	sendInput()
end

local function unbindDriving()
	if not driving then
		return
	end

	driving = false
	throttle = 0
	steer = 0

	CAS:UnbindAction("DriveSeat")

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if controls and controls.Enable then
		controls:Enable()
	end

	local remote = ensureVehicleInput()
	if remote then
		remote:FireServer(0, 0)
	end
end

local function handleSeatChange(humanoid)
	humanoid.Seated:Connect(function(isSeated, seatPart)
		if isSeated and seatPart and (seatPart:IsA("Seat") or seatPart:IsA("VehicleSeat")) then
			humanoid.AutoRotate = false
			humanoid.Sit = true

			if seatPart:IsA("VehicleSeat") then
				unbindDriving()
			else
				bindDriving()
			end
		else
			humanoid.AutoRotate = true
			unbindDriving()
		end
	end)

	humanoid.Died:Connect(function()
		humanoid.AutoRotate = true
		unbindDriving()
	end)
end

local function onCharacter(character)
	unbindDriving()

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	humanoid.AutoRotate = true
	handleSeatChange(humanoid)
end

if localPlayer.Character then
	onCharacter(localPlayer.Character)
end

localPlayer.CharacterAdded:Connect(onCharacter)
