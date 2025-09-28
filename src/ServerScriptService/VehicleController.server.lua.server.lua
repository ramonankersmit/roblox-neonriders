-- File: ServerScriptService/VehicleController.server.lua
-- Stuurt voertuigen op basis van VehicleSeat .Throttle/.Steer of (fallback) Remotes.VehicleInput.
-- Fixes:
--  - Network ownership correct (geen anchored assembly)
--  - Geen "OnServerEvent ontbreekt" meer

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- ===== afstelbare constants =====
local FWD_SPEED    = 80    -- basis snelheid vooruit/achteruit
local TURN_FACTOR  = 2     -- draaikracht
local UNANCHOR_ON_DRIVE = true

-- ===== state =====
local seatByPlayer = {}      -- [player] = Seat/VehicleSeat
local vehicleByPlayer = {}   -- [player] = Model

-- ===== helpers =====
local function getVehicleModelFromSeat(seat: Instance): Model?
	if not seat then return nil end
	local model = seat:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	if not model.PrimaryPart then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				model.PrimaryPart = d
				break
			end
		end
	end
	return model
end

local function unanchorAssembly(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

local function setOwner(model: Model, plr: Player?)
	if not model or not model.PrimaryPart then return end
	local root = model.PrimaryPart
	if root.CanSetNetworkOwnership then
		root:SetNetworkOwner(plr) -- nil => server
	end
end

local function applyVehiclePhysics(model: Model, throttle: number, steer: number)
	if not model or not model.PrimaryPart then return end
	local root = model.PrimaryPart

	-- Vooruit langs LookVector
	local v = root.CFrame.LookVector * (FWD_SPEED * throttle)
	root.AssemblyLinearVelocity = Vector3.new(v.X, root.AssemblyLinearVelocity.Y, v.Z)

	-- Y-yaw
	local yaw = steer * TURN_FACTOR * root.AssemblyMass
	root:ApplyAngularImpulse(Vector3.new(0, yaw, 0))
end

local function beginDriving(plr: Player, seat: Instance)
	local vehicle = getVehicleModelFromSeat(seat)
	if not vehicle then return end
	seatByPlayer[plr] = seat
	vehicleByPlayer[plr] = vehicle

	if UNANCHOR_ON_DRIVE then
		unanchorAssembly(vehicle)  -- eigenaarschap kan NIET op geankerde (of aan anchored gelaste) assemblies. :contentReference[oaicite:1]{index=1}
	end
	setOwner(vehicle, plr)
end

local function endDriving(plr: Player)
	local vehicle = vehicleByPlayer[plr]
	if vehicle then setOwner(vehicle, nil) end
	seatByPlayer[plr] = nil
	vehicleByPlayer[plr] = nil
end

-- ===== Seat/VehicleSeat detecteren voor alle seats in de game =====
local function attachSeat(seat: Seat)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if hum and hum.Parent then
			local plr = Players:GetPlayerFromCharacter(hum.Parent)
			if plr then beginDriving(plr, seat) end
		else
			-- bestuurder weg
			for plr, s in pairs(seatByPlayer) do
				if s == seat then endDriving(plr) end
			end
		end
	end)

	-- Als het een VehicleSeat is, lees direct Throttle/Steer (WASD wordt automatisch doorgegeven). :contentReference[oaicite:2]{index=2}
	if seat:IsA("VehicleSeat") then
		seat:GetPropertyChangedSignal("Throttle"):Connect(function()
			local model = getVehicleModelFromSeat(seat)
			if model then applyVehiclePhysics(model, seat.Throttle, seat.Steer) end
		end)
		seat:GetPropertyChangedSignal("Steer"):Connect(function()
			local model = getVehicleModelFromSeat(seat)
			if model then applyVehiclePhysics(model, seat.Throttle, seat.Steer) end
		end)
	end
end

for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("Seat") then attachSeat(inst) end
end
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Seat") then attachSeat(inst) end
end)

-- ===== Fallback: als een client toch Remotes.VehicleInput vuruurt, verwerk 'm hier =====
local remotes = RS:WaitForChild("Remotes")
local VehicleInput = remotes:WaitForChild("VehicleInput") -- server handler voorkomt je queue-spam. :contentReference[oaicite:3]{index=3}

VehicleInput.OnServerEvent:Connect(function(plr, throttle: number, steer: number)
	local vehicle = vehicleByPlayer[plr]
	-- Als mapping ontbreekt, probeer de huidige seat van deze speler te vinden
	if not vehicle then
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		if seat then
			beginDriving(plr, seat)
			vehicle = vehicleByPlayer[plr]
		end
	end
	if vehicle then
		applyVehiclePhysics(vehicle, throttle or 0, steer or 0)
	end
end)
