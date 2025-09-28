-- File: ServerScriptService/SeatAutoAlignAndDrive.server.lua
-- 1) Zet elke (Vehicle)Seat bij instappen vooruit gelijk aan het voertuig (geen Studio-handwerk nodig).
-- 2) Maakt de assembly non-anchored en geeft network ownership aan de bestuurder.
-- 3) Als het een VehicleSeat is: leest Throttle/Steer en duwt simpel vooruit + yaw.

local Players = game:GetService("Players")

local FWD_SPEED    = 80   -- studs/s
local TURN_FACTOR  = 2

local function getModelFromSeat(seat)
	if not seat then return nil end
	local m = seat:FindFirstAncestorOfClass("Model")
	if not m then return nil end
	if not m.PrimaryPart then
		for _,d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then m.PrimaryPart = d; break end
		end
	end
	return m
end

local function unanchorAll(model)
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
end

local function setOwner(model, plr)
	if model and model.PrimaryPart and model.PrimaryPart.CanSetNetworkOwnership then
		model.PrimaryPart:SetNetworkOwner(plr)  -- nil = server
	end
end

local function alignSeatToModelFront(seat, model)
	if not (seat and model and model.PrimaryPart) then return end
	seat.CFrame = CFrame.new(seat.Position, seat.Position + model.PrimaryPart.CFrame.LookVector)
end

local function applyDrive(model, throttle, steer)
	if not (model and model.PrimaryPart) then return end
	local root = model.PrimaryPart
	local f = root.CFrame.LookVector * (FWD_SPEED * throttle)
	root.AssemblyLinearVelocity = Vector3.new(f.X, root.AssemblyLinearVelocity.Y, f.Z)
	root:ApplyAngularImpulse(Vector3.new(0, steer * TURN_FACTOR * root.AssemblyMass, 0))
end

local function attachSeat(seat)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if hum and hum.Parent then
			local plr = Players:GetPlayerFromCharacter(hum.Parent)
			local model = getModelFromSeat(seat)
			if plr and model then
				alignSeatToModelFront(seat, model)   -- altijd goed vooruit
				unanchorAll(model)                   -- ownership kan niet op anchored/welded-to-anchored
				setOwner(model, plr)
			end
		else
			local model = getModelFromSeat(seat)
			if model then setOwner(model, nil) end
		end
	end)

	if seat:IsA("VehicleSeat") then
		seat:GetPropertyChangedSignal("Throttle"):Connect(function()
			applyDrive(getModelFromSeat(seat), seat.Throttle, seat.Steer)
		end)
		seat:GetPropertyChangedSignal("Steer"):Connect(function()
			applyDrive(getModelFromSeat(seat), seat.Throttle, seat.Steer)
		end)
	end
end

-- Hook alle huidige + toekomstige seats (Seat én VehicleSeat)
for _,inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("Seat") then attachSeat(inst) end
end
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Seat") then attachSeat(inst) end
end)
