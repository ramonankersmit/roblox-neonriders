local RS = game:GetService("ReplicatedStorage")
local REMOTES = RS:WaitForChild("Remotes")
local VEHICLE_INPUT = REMOTES:WaitForChild("VehicleInput")

local FWD_SPEED = 60
local TURN_RATE = 2

local function resolveVehicle(player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local seatPart = humanoid.SeatPart
	if not seatPart or seatPart.Occupant ~= humanoid then
		return
	end

	local vehicle = seatPart:FindFirstAncestorOfClass("Model")
	return vehicle, seatPart
end

local function applyInput(root, throttle, steer)
	if not root then
		return
	end

	if typeof(throttle) ~= "number" then
		throttle = 0
	end

	if typeof(steer) ~= "number" then
		steer = 0
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

VEHICLE_INPUT.OnServerEvent:Connect(function(player, throttle, steer)
	local vehicle, seatPart = resolveVehicle(player)
	if not vehicle then
		return
	end

	local root = vehicle.PrimaryPart or seatPart
	if root and root.CanSetNetworkOwnership then
		local currentOwner = root:GetNetworkOwner()
		if currentOwner ~= player then
			root:SetNetworkOwner(player)
		end
	end

	applyInput(root, throttle, steer)
end)
