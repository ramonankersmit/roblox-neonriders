local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local plr = Players.LocalPlayer

-- Hoe jij je EIGEN walls ziet (wordt lokaal toegepast, overschrijft server-waarde indien hoger)
local MY_WALL_ALPHA = 0.60  -- effectief wordt max(server.Transparency, LocalTransparencyModifier)

local function applyAlphaToFolder(folder)
	-- zet meteen op bestaande stukken
	for _,d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = MY_WALL_ALPHA
		end
	end
	-- en op nieuwe segmenten
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = MY_WALL_ALPHA
		end
	end)
end

local function tryHookMyWalls()
	local name = plr.Name .. "_Walls"
	local f = Workspace:FindFirstChild(name)
	if f then applyAlphaToFolder(f) end
end

-- alvast proberen (als walls al bestaan)
tryHookMyWalls()

-- bij nieuwe rondes/respawns komt er weer een nieuwe folder
Workspace.ChildAdded:Connect(function(child)
	if child.Name == plr.Name .. "_Walls" then
		applyAlphaToFolder(child)
	end
end)
