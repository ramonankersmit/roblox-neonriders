-- ListClientScripts.client.lua (tijdelijk)
local plr = game:GetService("Players").LocalPlayer
local function dump(container, tag)
	task.wait(2) -- even laten spawnen
	print("=== LocalScripts in", tag, "===")
	for _,d in ipairs(container:GetDescendants()) do
		if d:IsA("LocalScript") then print(d:GetFullName()) end
	end
end
dump(plr:WaitForChild("PlayerScripts"), "PlayerScripts")
dump(plr:WaitForChild("PlayerGui"), "PlayerGui")
dump(game:GetService("ReplicatedFirst"), "ReplicatedFirst")
