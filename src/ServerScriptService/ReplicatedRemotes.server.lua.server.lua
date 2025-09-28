local RS = game:GetService("ReplicatedStorage")

local remotes = RS:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RS
end

local vehicleInput = remotes:FindFirstChild("VehicleInput")
if not vehicleInput then
	vehicleInput = Instance.new("RemoteEvent")
	vehicleInput.Name = "VehicleInput"
	vehicleInput.Parent = remotes
end
