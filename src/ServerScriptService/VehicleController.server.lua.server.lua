local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local remotes = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 5)
local vehicleInput = remotes and (remotes:FindFirstChild("VehicleInput") or remotes:WaitForChild("VehicleInput", 5))

if not remotes then
	warn("[VehicleController] Remotes ontbreekt")
elseif not vehicleInput then
	warn("[VehicleController] VehicleInput ontbreekt")
end

local FWD_SPEED = 60
local TURN_RATE = 2

local function cleanupExternalWelds(model)
	if not model then
		return
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			local part0, part1 = descendant.Part0, descendant.Part1
			if (part0 and not model:IsAncestorOf(part0)) or (part1 and not model:IsAncestorOf(part1)) then
				descendant.Enabled = false
			end
		end
	end
end

local function unanchorAssembly(model)
	if not model then
		return
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

local function getRootPart(model, seat)
	if not model then
		return nil
	end

	local root = model.PrimaryPart
	if root and root:IsA("BasePart") then
		return root
	end

	if seat and seat:IsA("BasePart") then
		return seat
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local activeSeats = {}
local trackedSeats = {}

local function applyInput(root, throttle, steer)
	if not root then
		return
	end

	if typeof(throttle) ~= "number" then
		throttle = tonumber(throttle) or 0
	end

	if typeof(steer) ~= "number" then
		steer = tonumber(steer) or 0
	end

	throttle = math.clamp(throttle, -1, 1)
	steer = math.clamp(steer, -1, 1)

	local currentVelocity = root.AssemblyLinearVelocity
	local forward = root.CFrame.LookVector * (FWD_SPEED * throttle)
	root.AssemblyLinearVelocity = Vector3.new(forward.X, currentVelocity.Y, forward.Z)

	local mass = root.AssemblyMass
	if mass > 0 then
		root:ApplyAngularImpulse(Vector3.new(0, steer * TURN_RATE * mass, 0))
	end
end

local function deactivateSeat(seat, clearOwner)
	local state = activeSeats[seat]
	if not state then
		return
	end

	if clearOwner and state.root and state.root.Parent then
		local success, err = pcall(function()
			state.root:SetNetworkOwner(nil)
		end)
		if not success then
			warn("[VehicleController] Failed to clear network owner: ", err)
		end
	end

	activeSeats[seat] = nil
end

local function activateSeat(seat, player)
	if not seat or not player then
		return
	end

	local vehicle = seat:FindFirstAncestorOfClass("Model")
	if not vehicle then
		return
	end

	local root = getRootPart(vehicle, seat)
	if not root then
		return
	end

	local state = activeSeats[seat]
	if not state then
		state = {}
		activeSeats[seat] = state
	end

	state.player = player
	state.vehicle = vehicle
	state.root = root
	state.usesVehicleSeat = seat:IsA("VehicleSeat")

	if state.usesVehicleSeat then
		state.throttle = seat.Throttle
		state.steer = seat.Steer
	else
		state.throttle = 0
		state.steer = 0
	end

	cleanupExternalWelds(vehicle)
	unanchorAssembly(vehicle)

	if root.CanSetNetworkOwnership then
		local canSet, reason = root:CanSetNetworkOwnership()
		if not canSet then
			warn("[VehicleController] CanSetNetworkOwnership=false: ", reason)
		else
			local currentOwner = root:GetNetworkOwner()
			if currentOwner ~= player then
				root:SetNetworkOwner(player)
			end
		end
	end
end

local function updateSeatInputFromSeat(seat)
	local state = activeSeats[seat]
	if not state or not state.usesVehicleSeat then
		return
	end

	state.throttle = math.clamp(seat.Throttle or 0, -1, 1)
	state.steer = math.clamp(seat.Steer or 0, -1, 1)
end

local function handleOccupantChanged(seat)
	local occupant = seat.Occupant
	if occupant and occupant.Parent then
		local player = Players:GetPlayerFromCharacter(occupant.Parent)
		if player then
			activateSeat(seat, player)
			if seat:IsA("VehicleSeat") then
				updateSeatInputFromSeat(seat)
			end
			return
		end
	end

	deactivateSeat(seat, true)
end

local function resolveSeatForPlayer(player)
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local seatPart = humanoid.SeatPart
	if not seatPart or seatPart.Occupant ~= humanoid then
		return nil
	end

	return seatPart
end

local function updateSeatInputFromRemote(player, throttle, steer)
	local seat = resolveSeatForPlayer(player)
	if not seat or seat:IsA("VehicleSeat") then
		return
	end

	throttle = tonumber(throttle) or 0
	steer = tonumber(steer) or 0

	throttle = math.clamp(throttle, -1, 1)
	steer = math.clamp(steer, -1, 1)

	local state = activeSeats[seat]
	if not state or state.player ~= player then
		activateSeat(seat, player)
		state = activeSeats[seat]
	end

	if not state then
		return
	end

	state.throttle = throttle
	state.steer = steer
end

local function disconnectSeat(seat)
	local tracked = trackedSeats[seat]
	if tracked then
		for _, connection in ipairs(tracked.connections) do
			connection:Disconnect()
		end
	end
	trackedSeats[seat] = nil
	deactivateSeat(seat, true)
end

local function trackSeat(seat)
	if trackedSeats[seat] then
		return
	end

	local tracked = {
		connections = {}
	}
	trackedSeats[seat] = tracked

	local function onOccupantChanged()
		handleOccupantChanged(seat)
	end

	tracked.connections[#tracked.connections + 1] = seat:GetPropertyChangedSignal("Occupant"):Connect(onOccupantChanged)

	if seat:IsA("VehicleSeat") then
		local function onInputChanged()
			updateSeatInputFromSeat(seat)
		end

		tracked.connections[#tracked.connections + 1] = seat:GetPropertyChangedSignal("Throttle"):Connect(onInputChanged)
		tracked.connections[#tracked.connections + 1] = seat:GetPropertyChangedSignal("Steer"):Connect(onInputChanged)
	end

	tracked.connections[#tracked.connections + 1] = seat.AncestryChanged:Connect(function(_, parent)
		if not parent then
			disconnectSeat(seat)
		end
	end)

	onOccupantChanged()
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
		trackSeat(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
		trackSeat(descendant)
	end
end)

RunService.Heartbeat:Connect(function()
	for seat, state in pairs(activeSeats) do
		if not seat.Parent or not state.root or not state.root.Parent then
			deactivateSeat(seat, true)
		else
			applyInput(state.root, state.throttle or 0, state.steer or 0)
		end
	end
end)

if vehicleInput then
	vehicleInput.OnServerEvent:Connect(function(player, throttle, steer)
		updateSeatInputFromRemote(player, throttle, steer)
	end)
end
