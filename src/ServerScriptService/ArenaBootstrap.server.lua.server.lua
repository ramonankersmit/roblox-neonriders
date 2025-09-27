-- ServerScriptService/ArenaBootstrap.server.lua
-- Bouwt een grote arena met neon muren + spawnpoints die naar het midden kijken.

local Workspace = game:GetService("Workspace")

-- === Instellingen ===
local ARENA_SIZE_X = 2000
local ARENA_SIZE_Z = 2000
local FLOOR_Y      = 0
local WALL_H       = 80
local WALL_THICK   = 2
local WALL_COLOR   = Color3.fromRGB(255, 120, 0) -- Tron-achtig oranje voor arena
local FLOOR_COLOR  = Color3.fromRGB(30, 30, 30)

-- === Helpers ===
local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local Arena  = ensureFolder(Workspace, "Arena")
local Walls  = ensureFolder(Arena, "ArenaWalls")
local Spawns = ensureFolder(Workspace, "SpawnPoints")

-- === Vloer ===
local floor = Arena:FindFirstChild("ArenaFloor")
if not floor then
	floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Anchored = true
	floor.Material = Enum.Material.Concrete
	floor.Color = FLOOR_COLOR
	floor.Size = Vector3.new(ARENA_SIZE_X, 1, ARENA_SIZE_Z)
	floor.CFrame = CFrame.new(0, FLOOR_Y, 0)
	floor.Parent = Arena
else
	floor.Size = Vector3.new(ARENA_SIZE_X, 1, ARENA_SIZE_Z)
	floor.CFrame = CFrame.new(0, FLOOR_Y, 0)
end

-- === Muren ===
Walls:ClearAllChildren()
local function makeWall(name, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.Neon
	p.Color = WALL_COLOR
	p.Size = size
	p.CFrame = cf
	p.Parent = Walls
	return p
end

local hx = ARENA_SIZE_X/2
local hz = ARENA_SIZE_Z/2
local hY = WALL_H/2

makeWall("ArenaWall_Front",
	Vector3.new(ARENA_SIZE_X+WALL_THICK*2, WALL_H, WALL_THICK),
	CFrame.new(0, FLOOR_Y + hY, -hz - WALL_THICK/2))

makeWall("ArenaWall_Back",
	Vector3.new(ARENA_SIZE_X+WALL_THICK*2, WALL_H, WALL_THICK),
	CFrame.new(0, FLOOR_Y + hY,  hz + WALL_THICK/2))

makeWall("ArenaWall_Left",
	Vector3.new(WALL_THICK, WALL_H, ARENA_SIZE_Z+WALL_THICK*2),
	CFrame.new(-hx - WALL_THICK/2, FLOOR_Y + hY, 0))

makeWall("ArenaWall_Right",
	Vector3.new(WALL_THICK, WALL_H, ARENA_SIZE_Z+WALL_THICK*2),
	CFrame.new( hx + WALL_THICK/2, FLOOR_Y + hY, 0))

-- === Spawnpoints die naar het midden kijken ===
local function makeSpawn(name, pos)
	local target = Vector3.new(0, FLOOR_Y + 3, 0) -- midden
	local cf = CFrame.lookAt(pos, target)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = false
	p.Size = Vector3.new(2,1,2)
	p.CFrame = cf
	p.Parent = Spawns
end

Spawns:ClearAllChildren()
local margin = 18
local y = FLOOR_Y + 3

-- Hoeken
makeSpawn("Spawn_NW", Vector3.new(-hx+margin, y, -hz+margin))
makeSpawn("Spawn_NE", Vector3.new( hx-margin, y, -hz+margin))
makeSpawn("Spawn_SE", Vector3.new( hx-margin, y,  hz-margin))
makeSpawn("Spawn_SW", Vector3.new(-hx+margin, y,  hz-margin))

-- Zijkanten midden
makeSpawn("Spawn_N", Vector3.new(0, y, -hz+margin))
makeSpawn("Spawn_E", Vector3.new( hx-margin, y, 0))
makeSpawn("Spawn_S", Vector3.new(0, y,  hz-margin))
makeSpawn("Spawn_W", Vector3.new(-hx+margin, y, 0))
