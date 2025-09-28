local RS = game:GetService("ReplicatedStorage")

local REMOTES = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 5)
if not REMOTES then
	warn("[VehicleController] Remotes ontbreekt")
	return
end

local VEHICLE_INPUT = REMOTES:FindFirstChild("VehicleInput") or REMOTES:WaitForChild("VehicleInput", 5)
if not VEHICLE_INPUT then
	warn("[VehicleController] VehicleInput ontbreekt")
	return
end

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

	local model = vehicle
	local root = (model and model.PrimaryPart) or seatPart
	if not root then
		return
	end

	if root.CanSetNetworkOwnership then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("WeldConstraint") then
				local part0, part1 = descendant.Part0, descendant.Part1
				if (part0 and not model:IsAncestorOf(part0)) or (part1 and not model:IsAncestorOf(part1)) then
					descendant.Enabled = false
				end
			end
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
			end
		end

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

	applyInput(root, throttle, steer)
end)
