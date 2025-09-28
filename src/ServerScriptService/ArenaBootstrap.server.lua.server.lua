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
local Platforms = ensureFolder(Arena, "Platforms")
local Barriers = ensureFolder(Arena, "Barriers")
local CityProps = ensureFolder(Arena, "CityProps")

local function addStandardAttachments(part)
	local center = Instance.new("Attachment")
	center.Name = "CenterAttachment"
	center.Parent = part

	local top = Instance.new("Attachment")
	top.Name = "TopAttachment"
	top.Position = Vector3.new(0, part.Size.Y/2, 0)
	top.Parent = part

	local bottom = Instance.new("Attachment")
	bottom.Name = "BottomAttachment"
	bottom.Position = Vector3.new(0, -part.Size.Y/2, 0)
	bottom.Parent = part

	local forward = Instance.new("Attachment")
	forward.Name = "ForwardAttachment"
	forward.Position = Vector3.new(0, 0, -part.Size.Z/2)
	forward.Parent = part

	local backward = Instance.new("Attachment")
	backward.Name = "BackwardAttachment"
	backward.Position = Vector3.new(0, 0, part.Size.Z/2)
	backward.Parent = part

	local right = Instance.new("Attachment")
	right.Name = "RightAttachment"
	right.Position = Vector3.new(part.Size.X/2, 0, 0)
	right.Parent = part

	local left = Instance.new("Attachment")
	left.Name = "LeftAttachment"
	left.Position = Vector3.new(-part.Size.X/2, 0, 0)
	left.Parent = part
end

local function createPart(props)
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = props.anchored ~= false
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.Metal
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Transparency = props.transparency or 0
	part.Reflectance = props.reflectance or 0
	part.Size = props.size
	part.CFrame = props.cframe
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent
	addStandardAttachments(part)
	return part
end

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
return createPart({
name = name,
parent = Walls,
size = size,
cframe = cf,
material = Enum.Material.Neon,
color = WALL_COLOR
})
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

-- === Platforms & hoogteverschillen ===
Platforms:ClearAllChildren()
local platformHeights = {
	{height = FLOOR_Y + 10, scale = 0.85},
	{height = FLOOR_Y + 20, scale = 0.65},
	{height = FLOOR_Y + 35, scale = 0.45},
}

for index, info in ipairs(platformHeights) do
	local zOffset = (ARENA_SIZE_Z * info.scale) / 2 - 25
	local xOffset = (ARENA_SIZE_X * info.scale) / 2 - 25
	local walkwayWidth = 18 - (index * 2)
	local lengthX = ARENA_SIZE_X * info.scale
	local lengthZ = ARENA_SIZE_Z * info.scale

	createPart({
		name = string.format("PlatformNorth_Layer%d", index),
		parent = Platforms,
		size = Vector3.new(lengthX, 2, walkwayWidth),
		cframe = CFrame.new(0, info.height, -zOffset),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(20, 20, 20),
	})

	createPart({
		name = string.format("PlatformSouth_Layer%d", index),
		parent = Platforms,
		size = Vector3.new(lengthX, 2, walkwayWidth),
		cframe = CFrame.new(0, info.height, zOffset),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(20, 20, 20),
	})

	createPart({
		name = string.format("PlatformEast_Layer%d", index),
		parent = Platforms,
		size = Vector3.new(walkwayWidth, 2, lengthZ),
		cframe = CFrame.new(xOffset, info.height, 0),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(20, 20, 20),
	})

	createPart({
		name = string.format("PlatformWest_Layer%d", index),
		parent = Platforms,
		size = Vector3.new(walkwayWidth, 2, lengthZ),
		cframe = CFrame.new(-xOffset, info.height, 0),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(20, 20, 20),
	})
end

local centralStage = createPart({
	name = "CentralStage",
	parent = Platforms,
	size = Vector3.new(160, 4, 160),
	cframe = CFrame.new(0, FLOOR_Y + 12, 0),
	material = Enum.Material.Neon,
	color = Color3.fromRGB(255, 80, 0),
})
centralStage.Transparency = 0.05

-- === Transparante barrières ===
Barriers:ClearAllChildren()
local barrierHeight = FLOOR_Y + 30
local barrierThickness = 4

createPart({
	name = "BarrierNorth",
	parent = Barriers,
	size = Vector3.new(centralStage.Size.X + 40, barrierHeight, barrierThickness),
	cframe = CFrame.new(0, FLOOR_Y + barrierHeight / 2, -centralStage.Size.Z / 2 - barrierThickness / 2),
	material = Enum.Material.ForceField,
	color = Color3.fromRGB(0, 180, 255),
	transparency = 0.4,
})

createPart({
	name = "BarrierSouth",
	parent = Barriers,
	size = Vector3.new(centralStage.Size.X + 40, barrierHeight, barrierThickness),
	cframe = CFrame.new(0, FLOOR_Y + barrierHeight / 2, centralStage.Size.Z / 2 + barrierThickness / 2),
	material = Enum.Material.ForceField,
	color = Color3.fromRGB(0, 180, 255),
	transparency = 0.4,
})

createPart({
	name = "BarrierEast",
	parent = Barriers,
	size = Vector3.new(barrierThickness, barrierHeight, centralStage.Size.Z + 40),
	cframe = CFrame.new(centralStage.Size.X / 2 + barrierThickness / 2, FLOOR_Y + barrierHeight / 2, 0),
	material = Enum.Material.ForceField,
	color = Color3.fromRGB(0, 180, 255),
	transparency = 0.4,
})

createPart({
	name = "BarrierWest",
	parent = Barriers,
	size = Vector3.new(barrierThickness, barrierHeight, centralStage.Size.Z + 40),
	cframe = CFrame.new(-centralStage.Size.X / 2 - barrierThickness / 2, FLOOR_Y + barrierHeight / 2, 0),
	material = Enum.Material.ForceField,
	color = Color3.fromRGB(0, 180, 255),
	transparency = 0.4,
})

-- === Hellingen richting het midden ===
local rampWidth = 22
local rampThickness = 3
local rampStartOffset = centralStage.Size.X / 2 + 140
local rampTargetHeight = centralStage.CFrame.Position.Y + centralStage.Size.Y / 2

local function createRamp(name, startPosition, endPosition)
	local vector = endPosition - startPosition
	local length = vector.Magnitude
	local zAxis = vector.Unit
	local xAxis = zAxis:Cross(Vector3.new(0, 1, 0))
	if xAxis.Magnitude < 0.001 then
		xAxis = Vector3.new(1, 0, 0)
	end
	xAxis = xAxis.Unit
	local yAxis = xAxis:Cross(zAxis).Unit
	return createPart({
		name = name,
		parent = Platforms,
		size = Vector3.new(rampWidth, rampThickness, length),
		cframe = CFrame.fromMatrix((startPosition + endPosition) / 2, xAxis, yAxis, zAxis),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(40, 40, 40),
	})
end

local northStart = Vector3.new(0, FLOOR_Y + 1, -rampStartOffset)
local northEnd = Vector3.new(0, rampTargetHeight, -centralStage.Size.Z / 2 + 3)
local southStart = Vector3.new(0, FLOOR_Y + 1, rampStartOffset)
local southEnd = Vector3.new(0, rampTargetHeight, centralStage.Size.Z / 2 - 3)
local eastStart = Vector3.new(rampStartOffset, FLOOR_Y + 1, 0)
local eastEnd = Vector3.new(centralStage.Size.X / 2 - 3, rampTargetHeight, 0)
local westStart = Vector3.new(-rampStartOffset, FLOOR_Y + 1, 0)
local westEnd = Vector3.new(-centralStage.Size.X / 2 + 3, rampTargetHeight, 0)

createRamp("RampNorth", northStart, northEnd)
createRamp("RampSouth", southStart, southEnd)
createRamp("RampEast", eastStart, eastEnd)
createRamp("RampWest", westStart, westEnd)

-- === Tron-achtige stadsdecoratie ===
CityProps:ClearAllChildren()

local skyscraperPositions = {
	Vector3.new(hx - 60, FLOOR_Y + 150, -hz + 60),
	Vector3.new(-hx + 90, FLOOR_Y + 180, hz - 80),
	Vector3.new(hx - 120, FLOOR_Y + 210, hz - 120),
	Vector3.new(-hx + 140, FLOOR_Y + 165, -hz + 140),
}

for index, pos in ipairs(skyscraperPositions) do
	createPart({
		name = string.format("NeonSkyscraper_%d", index),
		parent = CityProps,
		size = Vector3.new(45, pos.Y * 0.9, 45),
		cframe = CFrame.new(pos.X, pos.Y, pos.Z),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(0, 170, 255),
	})
end

local signOffsets = {
	Vector3.new(0, FLOOR_Y + 80, hz - 100),
	Vector3.new(0, FLOOR_Y + 95, -hz + 120),
	Vector3.new(hx - 140, FLOOR_Y + 90, 0),
	Vector3.new(-hx + 140, FLOOR_Y + 110, 0),
}

for index, pos in ipairs(signOffsets) do
	local sign = createPart({
		name = string.format("FloatingSign_%d", index),
		parent = CityProps,
		size = Vector3.new(120, 10, 2),
		cframe = CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles(0, math.rad(15 * index), 0),
		material = Enum.Material.Neon,
		color = Color3.fromRGB(255, 120, 0),
		canCollide = false,
	})
	sign.Transparency = 0.2
	local glow = createPart({
		name = string.format("FloatingSignGlow_%d", index),
		parent = CityProps,
		size = Vector3.new(140, 12, 4),
		cframe = sign.CFrame * CFrame.new(0, 0, -6),
		material = Enum.Material.ForceField,
		color = Color3.fromRGB(0, 255, 255),
		transparency = 0.5,
		canCollide = false,
	})
	glow.Name = string.format("FloatingSignAura_%d", index)
end
