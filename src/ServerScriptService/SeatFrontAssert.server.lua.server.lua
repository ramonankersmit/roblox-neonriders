-- File: ServerScriptService/SeatFrontAssert.server.lua

-- (Optioneel) Console-check om verkeerde seat-oriëntatie snel te detecteren.

local function dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end

for _, seat in ipairs(workspace:GetDescendants()) do
	if seat:IsA("VehicleSeat") then
		local model = seat:FindFirstAncestorOfClass("Model")
		if model and model.PrimaryPart then
			local d = dot(seat.CFrame.LookVector, model.PrimaryPart.CFrame.LookVector)
			if d < 0.5 then
				warn(("[SeatFrontAssert] '%s': seat-front wijkt af van vehicle-front (dot=%.2f). Roteer de VehicleSeat."):format(model.Name, d))
			end
		end
	end
end

workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("VehicleSeat") then
		local model = inst:FindFirstAncestorOfClass("Model")
		if model and model.PrimaryPart then
			local d = dot(inst.CFrame.LookVector, model.PrimaryPart.CFrame.LookVector)
			if d < 0.5 then
				warn(("[SeatFrontAssert] '%s': seat-front wijkt af van vehicle-front (dot=%.2f). Roteer de VehicleSeat."):format(model.Name, d))
			end
		end
	end
end)
