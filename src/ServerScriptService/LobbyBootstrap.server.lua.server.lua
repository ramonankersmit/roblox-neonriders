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
local base = part{
	Name="LobbyFloor", Anchored=true, Size=Vector3.new(60,1,40),
	Position=Vector3.new(0, lobbyY, -120), Material=Enum.Material.Metal, Color=Color3.fromRGB(35,35,50)
}
local spawn = Instance.new("SpawnLocation")
spawn.Name="LobbySpawn"; spawn.Anchored=true; spawn.Size=Vector3.new(6,1,6)
spawn.Position = base.Position + Vector3.new(0,1,0); spawn.Transparency=0.2
spawn.Neutral=true; spawn.CanCollide=true; spawn.Parent=Workspace

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
