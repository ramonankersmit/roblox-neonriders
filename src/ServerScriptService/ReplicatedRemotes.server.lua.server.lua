-- File: ServerScriptService/ReplicatedRemotes.server.lua
-- Zorgt dat ReplicatedStorage.Remotes.VehicleInput bestaat (voorkomt je "OnServerEvent?" spam).
local RS = game:GetService("ReplicatedStorage")
local rem = RS:FindFirstChild("Remotes") or Instance.new("Folder")
rem.Name = "Remotes"; rem.Parent = RS
if not rem:FindFirstChild("VehicleInput") then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "VehicleInput"
	ev.Parent = rem
end
-- Optionele no-op handler zodat clientcalls nooit in de wachtrij blijven hangen:
rem.VehicleInput.OnServerEvent:Connect(function() end)  -- stilhouden
