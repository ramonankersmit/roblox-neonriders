-- EngineAudio.client.lua
-- Speelt motorgeluid per speler en past pitch/volume aan op basis van snelheid.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ENGINE_SOUND_ID = "rbxassetid://1843523065"
local MIN_PITCH = 0.7
local MAX_PITCH = 1.55
local MIN_VOLUME = 0.05
local MAX_VOLUME = 0.6
local SPEED_SMOOTH = 6
local SPEED_FALLOFF = 3
local MAX_EXPECTED_SPEED = 110 -- hoogste snelheid tier op de server

local localPlayer = Players.LocalPlayer
local cycleName = localPlayer.Name .. "_Cycle"

local currentCycle
local engineSound
local ancestryConn
local lastPos
local smoothedSpeed = 0

local function disconnectAncestry()
	if ancestryConn then
		ancestryConn:Disconnect()
		ancestryConn = nil
	end
end

local function detachEngineSound()
	disconnectAncestry()
	currentCycle = nil
	lastPos = nil
	smoothedSpeed = 0
	if engineSound then
		local ok, err = pcall(function()
			engineSound:Stop()
	end)
		if not ok then
			warn("[EngineAudio] kon EngineSound niet stoppen:", err)
		end
		engineSound = nil
	end
end

local function ensureEngineSound(chassis)
	local sound = chassis:FindFirstChild("EngineSound")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "EngineSound"
		sound.SoundId = ENGINE_SOUND_ID
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMaxDistance = 220
		sound.Looped = true
		sound.Volume = 0
		sound.PlaybackSpeed = MIN_PITCH
		sound.Parent = chassis
	elseif sound.SoundId == "" then
		sound.SoundId = ENGINE_SOUND_ID
	end

	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = MIN_PITCH
	if not sound.IsPlaying then
		sound:Play()
	end
	return sound
end

local function attachToCycle(model)
	if currentCycle == model then return end
	detachEngineSound()
	local chassis = model:FindFirstChild("Chassis")
	if not chassis then return end

	engineSound = ensureEngineSound(chassis)
	currentCycle = model
	lastPos = model:GetPivot().Position

	ancestryConn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			detachEngineSound()
		end
	end)
end

local function findCycle()
	return Workspace:FindFirstChild(cycleName)
end

local function onChildAdded(child)
	if child.Name == cycleName and child:IsA("Model") then
		attachToCycle(child)
	end
end

Workspace.ChildAdded:Connect(onChildAdded)
Workspace.ChildRemoved:Connect(function(child)
	if child == currentCycle then
		detachEngineSound()
	end
	end)

local existing = findCycle()
if existing then
	attachToCycle(existing)
end

RunService.RenderStepped:Connect(function(dt)
	if not engineSound then
		smoothedSpeed = math.max(0, smoothedSpeed - dt * SPEED_FALLOFF * MAX_EXPECTED_SPEED)
		return
	end

	if currentCycle and currentCycle.Parent then
		local pivot = currentCycle:GetPivot()
		local pos = pivot.Position
		if lastPos then
			local rawSpeed = (pos - lastPos).Magnitude / math.max(dt, 1e-4)
			smoothedSpeed += (rawSpeed - smoothedSpeed) * (1 - math.exp(-dt * SPEED_SMOOTH))
		else
			smoothedSpeed *= math.exp(-dt * SPEED_FALLOFF)
		end
		lastPos = pos
	else
		smoothedSpeed *= math.exp(-dt * SPEED_FALLOFF)
	end

	smoothedSpeed = math.max(0, math.min(smoothedSpeed, MAX_EXPECTED_SPEED * 1.2))

	local ratio = smoothedSpeed / MAX_EXPECTED_SPEED
	local targetPitch = MIN_PITCH + (MAX_PITCH - MIN_PITCH) * math.clamp(ratio, 0, 1)
	local targetVolume = math.clamp(ratio, 0, 1)
	if targetVolume > 0 then
		targetVolume = MIN_VOLUME + (MAX_VOLUME - MIN_VOLUME) * targetVolume
	else
		targetVolume = 0
	end

	local blend = 1 - math.exp(-dt * SPEED_SMOOTH)
	engineSound.PlaybackSpeed += (targetPitch - engineSound.PlaybackSpeed) * blend
	engineSound.Volume += (targetVolume - engineSound.Volume) * blend
	end)
