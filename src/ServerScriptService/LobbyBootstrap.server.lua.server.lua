-- ServerScriptService/LobbyBootstrap.server.lua
local Workspace = game:GetService("Workspace")

local function part(props)
	local p = Instance.new("Part")
	for k,v in pairs(props) do p[k] = v end
	p.Parent = Workspace
	return p
end

-- Lobby boven de arena
local lobbyY = 25
local baseSize = Vector3.new(60 * 1.5, 1, 40 * 1.5)
local base = part{
        Name="LobbyFloor", Anchored=true, Size=baseSize,
        Position=Vector3.new(0, lobbyY, -120), Material=Enum.Material.Metal, Color=Color3.fromRGB(35,35,50)
}
local spawn = Instance.new("SpawnLocation")
spawn.Name="LobbySpawn"; spawn.Anchored=true; spawn.Size=Vector3.new(6,1,6)
spawn.Position = base.Position + Vector3.new(0,1,0); spawn.Transparency=0.2
spawn.Neutral=true; spawn.CanCollide=true; spawn.Parent=Workspace

local wallHeight = 12
local wallThickness = 1
local halfX = base.Size.X * 0.5
local halfZ = base.Size.Z * 0.5

local function makeWall(name, size, position)
        part{
                Name = name,
                Anchored = true,
                Size = size,
                Position = position,
                Material = Enum.Material.Glass,
                Transparency = 0.3,
                Color = Color3.fromRGB(180, 220, 255),
                CanCollide = true,
        }
end

makeWall("LobbyWallNorth", Vector3.new(base.Size.X + wallThickness * 2, wallHeight, wallThickness), base.Position + Vector3.new(0, wallHeight * 0.5, -halfZ - wallThickness * 0.5))
makeWall("LobbyWallSouth", Vector3.new(base.Size.X + wallThickness * 2, wallHeight, wallThickness), base.Position + Vector3.new(0, wallHeight * 0.5, halfZ + wallThickness * 0.5))
makeWall("LobbyWallEast",  Vector3.new(wallThickness, wallHeight, base.Size.Z + wallThickness * 2), base.Position + Vector3.new(halfX + wallThickness * 0.5, wallHeight * 0.5, 0))
makeWall("LobbyWallWest",  Vector3.new(wallThickness, wallHeight, base.Size.Z + wallThickness * 2), base.Position + Vector3.new(-halfX - wallThickness * 0.5, wallHeight * 0.5, 0))

local function pillar(name, offset, text)
	local p = part{
		Name=name, Anchored=true, Size=Vector3.new(2,8,2),
		Position=base.Position + offset, Material=Enum.Material.Neon, Color=Color3.fromRGB(0,170,255)
	}
	local att = Instance.new("Attachment", p)
	local prompt = Instance.new("ProximityPrompt", att)
	prompt.ActionText = text
	prompt.ObjectText  = "Light Races"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	return p, prompt
end

-- Ready-zuil links, Start-zuil rechts
_G.Lobby_ReadyPart, _G.Lobby_ReadyPrompt = pillar("LobbyReady", Vector3.new(-15,5,0), "Toggle Ready")
_G.Lobby_StartPart, _G.Lobby_StartPrompt = pillar("LobbyStart", Vector3.new( 15,5,0), "Start Game")
