-- File: StarterPlayer/StarterPlayerScripts/CameraScript.client.lua
-- Lobby = third-person (achter/boven). Zittend (in-game) = first-person langs Seat-front.
-- Eén camera-eigenaar, draait als allerlaatste (geen jitter/flip).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer
local currentSeat -- Seat of VehicleSeat

local function onChar(char)
	local hum = char:WaitForChild("Humanoid")
	hum.Seated:Connect(function(isSeated, seatPart)
		if isSeated and seatPart and seatPart:IsA("Seat") then
			currentSeat = seatPart
			hum.AutoRotate = false
			hum.Sit = true
		else
			currentSeat = nil
			hum.AutoRotate = true
		end
	end)
end

if lp.Character then onChar(lp.Character) end
lp.CharacterAdded:Connect(onChar)

local function thirdPerson(char)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local pivot = hrp.CFrame
	local eye = (pivot * CFrame.new(0, 6, 12)).Position
	return CFrame.new(eye, pivot.Position)
end

local function firstPersonSeat(seat)
	local seatCF = seat.CFrame
	local eye = (seatCF * CFrame.new(0, 2.2, 0.1)).Position
	return CFrame.new(eye, eye + seatCF.LookVector)
end

RunService:BindToRenderStep("LightRaceCam", Enum.RenderPriority.Last.Value, function()
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end

	local pg = lp:FindFirstChildOfClass("PlayerGui")
	local inLobby = pg and pg:FindFirstChild("LobbyUI") ~= nil

	if inLobby then
		local cf = thirdPerson(lp.Character)
		if cf then cam.CFrame = cf; return end
	elseif currentSeat and currentSeat.Parent then
		cam.CFrame = firstPersonSeat(currentSeat)
		return
	end

	local cf = thirdPerson(lp.Character)
	if cf then cam.CFrame = cf end
end)
