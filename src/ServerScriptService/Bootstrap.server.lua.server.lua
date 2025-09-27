-- Maakt TurnEvent/RoundEvent, arena, spawns en LightCycle aan (met Seat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- RemoteEvents
local TurnEvent  = ReplicatedStorage:FindFirstChild("TurnEvent")  or Instance.new("RemoteEvent", ReplicatedStorage)
TurnEvent.Name = "TurnEvent"
local RoundEvent = ReplicatedStorage:FindFirstChild("RoundEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
RoundEvent.Name = "RoundEvent"
local CrashEvent = ReplicatedStorage:FindFirstChild("CrashEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
CrashEvent.Name = "CrashEvent"
local SpeedEvent = ReplicatedStorage:FindFirstChild("SpeedEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
SpeedEvent.Name = "SpeedEvent"
local LobbyEvent = ReplicatedStorage:FindFirstChild("LobbyEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
LobbyEvent.Name = "LobbyEvent"

local TimeSync = ReplicatedStorage:FindFirstChild("TimeSync") or Instance.new("RemoteEvent")
TimeSync.Name = "TimeSync"; TimeSync.Parent = ReplicatedStorage

-- beantwoord pings met server os.clock()
TimeSync.OnServerEvent:Connect(function(plr, clientSendTs)
	TimeSync:FireClient(plr, clientSendTs, os.clock())
end)

-- Optioneel: vlag die aangeeft of een ronde actief is
local RoundActive = ReplicatedStorage:FindFirstChild("RoundActive") or Instance.new("BoolValue", ReplicatedStorage)
RoundActive.Name = "RoundActive"
RoundActive.Value = false

-- Arena
if not Workspace:FindFirstChild("ArenaFloor") then
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(500, 2, 500)
	floor.Position = Vector3.new(0, 0, 0)
	floor.Material = Enum.Material.Asphalt
	floor.Color = Color3.fromRGB(25, 25, 25)
	floor.Parent = Workspace
end

-- Spawns
local spawns = Workspace:FindFirstChild("SpawnPoints")
if not spawns then
	spawns = Instance.new("Folder"); spawns.Name = "SpawnPoints"; spawns.Parent = Workspace
	for _,cf in ipairs({
		CFrame.new(-160,3,-160),
		CFrame.new(160,3,-160),
		CFrame.new(-160,3,160),
		CFrame.new(160,3,160),
		}) do
		local p = Instance.new("Part")
		p.Name = "Spawn"; p.Anchored = true; p.CanCollide = false; p.Transparency = 1
		p.Size = Vector3.new(2,2,2); p.CFrame = cf; p.Parent = spawns
	end
end

-- LightCycle (Chassis + Seat + Glow)
if not ServerStorage:FindFirstChild("LightCycle") then
	local model = Instance.new("Model"); model.Name = "LightCycle"

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"; chassis.Size = Vector3.new(4,2,6)
	chassis.Material = Enum.Material.Metal; chassis.Color = Color3.fromRGB(0,170,255)
	chassis.Anchored = true; chassis.Parent = model

	-- Seat: 180° gedraaid zodat speler naar voren kijkt
	local seat = Instance.new("Seat")
	seat.Name = "Seat"; seat.Size = Vector3.new(2,1,2)
	seat.Transparency = 1; seat.CanCollide = false; seat.Anchored = true; seat.Parent = model
	seat.CFrame = chassis.CFrame * CFrame.new(0, 1.4, -0.4)
	local wSeat = Instance.new("WeldConstraint"); wSeat.Part0 = chassis; wSeat.Part1 = seat; wSeat.Parent = model

	local glow = Instance.new("Part")
	glow.Name = "Glow"; glow.Size = Vector3.new(4.2,0.2,6.2)
	glow.Material = Enum.Material.Neon; glow.Color = Color3.fromRGB(0,255,255)
	glow.CanCollide = false; glow.Anchored = true; glow.Parent = model
	local wGlow = Instance.new("WeldConstraint"); wGlow.Part0 = chassis; wGlow.Part1 = glow; wGlow.Parent = model
	glow.Position = chassis.Position + Vector3.new(0,1.3,0)

	model.PrimaryPart = chassis; model.Parent = ServerStorage
end
