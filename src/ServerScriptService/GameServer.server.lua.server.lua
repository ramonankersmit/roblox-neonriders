-- GameServer.server.lua
-- Tron LightCycle game met trail walls en arena (clean: GEEN PoseEvent meer)

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local ServerStorage    = game:GetService("ServerStorage")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")

-- Remotes (zonder PoseEvent)
local TurnEvent      = ReplicatedStorage:WaitForChild("TurnEvent")
local RoundEvent     = ReplicatedStorage:WaitForChild("RoundEvent")
local DistanceEvent  = ReplicatedStorage:WaitForChild("DistanceEvent")
local CrashEvent     = ReplicatedStorage:WaitForChild("CrashEvent")
local SpeedEvent     = ReplicatedStorage:WaitForChild("SpeedEvent")
local RoundActiveVal = ReplicatedStorage:WaitForChild("RoundActive")

-- Content
local CycleTemplate  = ServerStorage:WaitForChild("LightCycle")
local SpawnFolder    = Workspace:WaitForChild("SpawnPoints")

--=====================
-- Tuning
--=====================
local TICK_DT         = 1/30
local TURN_RATE       = math.rad(140)
local TURN_THRESH     = 0.20

local WALL_THICK      = 0.2
local WALL_HEIGHT     = 10
local SEG_MIN_LEN     = 1.0
local BOCHT_EXTRA     = 0.5
local TRAIL_OFFSET    = 1.5
local SEG_STEP        = 1.0

local DIST_MAX        = 5000
local DISPLAY_BUFFER  = 0.3
local HEAD_CLEARANCE  = 1.0
local COLLISION_MARGIN= 0.6

local WALL_ALPHA      = 0.2 -- 0=opaak, 1=onzichtbaar

-- 3 snelheidsstanden
local SPEED_TIERS     = {60, 80, 110}
local DEFAULT_TIER    = 2

-- [plr] = {model,pos,yaw,steer,running,lastTrail,wallsFolder,speedTier,speed,scoreAcc}
local cycles = {}

--=====================
-- Helpers
--=====================
local function getSpawns()
	local list = {}
	for _,p in ipairs(SpawnFolder:GetChildren()) do
		if p:IsA("BasePart") then table.insert(list, p.CFrame) end
	end
	if #list == 0 then table.insert(list, CFrame.new(0,3,0)) end
	return list
end

local function fwdFromYaw(yaw)
	return (CFrame.Angles(0, yaw, 0)).LookVector
end

local function orientSpawn(cframe)
	return CFrame.new(cframe.Position, cframe.Position + cframe.LookVector)
end

local function getForwardOffset(c)
	if not c._halfLen then
		if c.model then
			local size = c.model:GetExtentsSize()
			c._halfLen = (size and size.Z or 4) * 0.5
		else
			c._halfLen = 2
		end
	end
	return c._halfLen + HEAD_CLEARANCE
end

local function raycastForward(c, maxDist)
	local fwd    = fwdFromYaw(c.yaw)
	local origin = c.pos + Vector3.new(0, 2, 0) + fwd * getForwardOffset(c)
	local dir    = fwd * maxDist

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {c.model}

	local res = Workspace:Raycast(origin, dir, params)
	return res, origin
end

local function resetHumanoidForLobby(plr)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- herstel standaard gedrag
	hum.WalkSpeed = 16
	hum.JumpPower = 50
	hum.AutoRotate = true
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	hum.Jump = false
	for _,bp in ipairs(char:GetDescendants()) do
		if bp:IsA("BasePart") then bp.CanCollide = true end
	end
end

local function cleanupCycle(plr)
	local c = cycles[plr]
	if not c then return end
	c.running = false
	if c.model then c.model:Destroy() end
	if c.wallsFolder then c.wallsFolder:Destroy() end
	cycles[plr] = nil
end

-- Als de lobby "End" doet → alles netjes stoppen en schoonmaken
RoundActiveVal:GetPropertyChangedSignal("Value"):Connect(function()
	if not RoundActiveVal.Value then
		for plr,_ in pairs(cycles) do
			cleanupCycle(plr)
			resetHumanoidForLobby(plr)
		end
	end
end)

--=====================
-- Walls
--=====================
local function makeWallSegment(folder, a, b, color)
	local dir = (b - a)
	local len = dir.Magnitude
	if len < SEG_MIN_LEN then
		b = a + (dir.Magnitude == 0 and Vector3.new(0,0,SEG_MIN_LEN) or dir.Unit * SEG_MIN_LEN)
		dir = (b - a)
		len = dir.Magnitude
	end

	local mid  = a + dir * 0.5
	local part = Instance.new("Part")
	part.Name              = "WallSeg"
	part.Anchored          = true
	part.CanCollide        = true
	part.Material          = Enum.Material.Neon
	part.Color             = color or Color3.fromRGB(0,255,255)
	part.Transparency      = WALL_ALPHA
	part.CastShadow        = false
	part.Size              = Vector3.new(WALL_THICK, WALL_HEIGHT, len)
	part.CFrame            = CFrame.lookAt(mid, b) * CFrame.new(0, WALL_HEIGHT/2, 0)
	part.Parent            = folder
	return part
end

--=====================
-- Collision / Distance
--=====================
local function isBlocking(inst, currentSeg)
	if not inst then return false end
	if inst.Name == "WallSeg" and inst ~= currentSeg then return true end
	if inst.Name:match("^ArenaWall") then return true end
	return false
end

local function distanceToBlockAhead(c, maxDist)
	local res, origin = raycastForward(c, maxDist)
	if res and isBlocking(res.Instance, c.currentSeg) then
		return (res.Position - origin).Magnitude
	end
	return math.huge
end

local function distanceAhead(c)
	if not c or not c.model then return -1 end
	local res, origin = raycastForward(c, DIST_MAX)
	if res and res.Instance then
		local inst = res.Instance
		if inst.Name == "WallSeg" or inst.Name:match("^ArenaWall") then
			local d = (res.Position - origin).Magnitude
			return math.max(0, d - DISPLAY_BUFFER)
		end
	end
	return -1
end

--=====================
-- Lifecycle
--=====================
local function seatCharacterOnCycle(plr, cycleModel)
	local char = plr.Character; if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local seat = cycleModel:FindFirstChild("Seat")
	if not (hum and seat) then return end

	for _,bp in ipairs(char:GetDescendants()) do
		if bp:IsA("BasePart") then bp.CanCollide = false end
	end
	char:MoveTo(seat.Position + Vector3.new(0, 2, 0))

	task.delay(0.05, function()
		if not (seat and seat.Parent and hum and hum.Parent) then return end
		seat:Sit(hum)
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.AutoRotate = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		hum.Jumping:Connect(function() hum.Jump = false end)
		hum.Seated:Connect(function(isSeated)
			if not isSeated then
				task.defer(function()
					if seat and seat.Parent and hum and hum.Parent then
						seat:Sit(hum)
					end
				end)
			end
		end)
	end)
end

local function spawnCycle(plr, spawnCF)
	local prev = cycles[plr]
	if prev then
		if prev.model      then prev.model:Destroy()      end
		if prev.wallsFolder then prev.wallsFolder:Destroy() end
	end

	local m = CycleTemplate:Clone()
	m.Name = plr.Name .. "_Cycle"
	m.Parent = Workspace
	m.PrimaryPart = m:FindFirstChild("Chassis")
	for _,d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end

	local startCF  = orientSpawn(spawnCF + Vector3.new(0, 3, 0))
	m:PivotTo(startCF)
	local startYaw = select(2, startCF:ToOrientation())
	local startPos = startCF.Position

	local walls = Instance.new("Folder"); walls.Name = plr.Name .. "_Walls"; walls.Parent = Workspace

	cycles[plr] = {
		model = m,
		pos = startPos,
		yaw = startYaw,
		steer = 0,
		running = false,
		lastTrail = nil,
		currentSeg = nil,
		wallsFolder = walls,
		speedTier   = (cycles[plr] and cycles[plr].speedTier) or DEFAULT_TIER,
		speed       = SPEED_TIERS[(cycles[plr] and cycles[plr].speedTier) or DEFAULT_TIER],
		scoreAcc    = 0,
	}
	seatCharacterOnCycle(plr, m)
end

local function doCountdownFor(plr, seconds)
	for t = seconds,1,-1 do
		RoundEvent:FireClient(plr, "countdown", t)
		task.wait(1)
	end
	RoundEvent:FireClient(plr, "go")
end

local function seedTrail(plr)
	local c = cycles[plr]; if not c then return end
	local fwd = fwdFromYaw(c.yaw)
	c.lastTrail  = c.pos - fwd * TRAIL_OFFSET
	c.currentSeg = nil
end

-- Input
TurnEvent.OnServerEvent:Connect(function(plr, steer)
	local c = cycles[plr]
	if c and c.running then
		c.steer = math.clamp(tonumber(steer) or 0, -1, 1)
	end
end)

Players.PlayerAdded:Connect(function(plr)
	-- leaderstats
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr
	local Score = Instance.new("IntValue"); Score.Name = "Score"; Score.Value = 0; Score.Parent = ls
	local Best  = Instance.new("IntValue"); Best.Name  = "Best";  Best.Value  = 0; Best.Parent = ls
	local Spd   = Instance.new("IntValue"); Spd.Name   = "Speed"; Spd.Value   = SPEED_TIERS[DEFAULT_TIER]; Spd.Parent = ls

	plr.CharacterAdded:Connect(function()
		task.wait(0.2)

		local rs = game:GetService("ReplicatedStorage")
		local roundFlag = rs:FindFirstChild("RoundActive")
		if roundFlag and not roundFlag.Value then
			return -- we zitten in de lobby; niet starten
		end
		if plr:GetAttribute("JoinRound") ~= true then
			return -- niet ingeschreven door lobby
		end
		plr:SetAttribute("JoinRound", nil)

		local spawns = getSpawns()
		local idx = ((plr.UserId % #spawns) + 1)
		spawnCycle(plr, spawns[idx])

		doCountdownFor(plr, 3)
		task.delay(0.1, function()
			if cycles[plr] then
				seedTrail(plr)
				cycles[plr].running = true
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	local c = cycles[plr]
	if c then
		if c.model then c.model:Destroy() end
		if c.wallsFolder then c.wallsFolder:Destroy() end
		cycles[plr] = nil
	end
end)

-- Speed tiers
SpeedEvent.OnServerEvent:Connect(function(plr, tier)
	local rs = game:GetService("ReplicatedStorage")
	local RoundActiveVal = rs:FindFirstChild("RoundActive")
	if RoundActiveVal and RoundActiveVal.Value ~= true then
		return -- in lobby: negeren
	end

	tier = tonumber(tier)
	if not tier or tier < 1 or tier > #SPEED_TIERS then return end
	local c = cycles[plr]; if not c then return end
	c.speedTier = tier
	c.speed = SPEED_TIERS[tier]
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		local v = ls:FindFirstChild("Speed")
		if v then v.Value = c.speed end
	end
end)

--=====================
-- Simulatie
--=====================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	while acc >= TICK_DT do
		acc -= TICK_DT

		for plr, c in pairs(cycles) do
			if c.running and c.model and c.model.PrimaryPart then

				local function isBlocking(inst)
					if not inst then return false end
					if inst.Name == "WallSeg" and inst ~= c.currentSeg then return true end
					if inst.Name:match("^ArenaWall") then return true end
					return false
				end

				-- stuurhoek integratie
				c.yaw -= (c.steer or 0) * TURN_RATE * TICK_DT

				-- VOORUIT projectie zonder extra marge (voorkomt 'te vroeg' crashen)
				local stepSpeed = (c.speed or SPEED)
				local stepDist  = stepSpeed * TICK_DT
				local hit, origin = raycastForward(c, stepDist)

				if hit and isBlocking(hit.Instance) then
					-- ==== CRASH ====
					c.running = false

					local boom = Instance.new("Explosion")
					boom.Position = c.pos
					boom.BlastRadius = 0
					boom.BlastPressure = 0
					boom.Parent = Workspace

					DistanceEvent:FireClient(plr, nil)
					CrashEvent:FireClient(plr, { pos = c.pos, yaw = c.yaw, cycle = c.model })

					-- score & reset
					local ls = plr:FindFirstChild("leaderstats")
					if ls then
						local s = ls:FindFirstChild("Score")
						local b = ls:FindFirstChild("Best")
						if s and b then
							if s.Value > b.Value then b.Value = s.Value end
							s.Value = 0
						end
					end
					c.scoreAcc = 0

					task.delay(1.8, function()
						if not cycles[plr] then return end
						if c.wallsFolder then c.wallsFolder:ClearAllChildren() end
						local spawns = getSpawns()
						local idx = ((plr.UserId % #spawns) + 1)
						spawnCycle(plr, spawns[idx])
						doCountdownFor(plr, 3)
						seedTrail(plr)
						if cycles[plr] then cycles[plr].running = true end
					end)

				else
					-- Geen crash → bewegen + HUD + trail
					local fwd = fwdFromYaw(c.yaw)
					c.pos += fwd * stepDist
					c.model:PivotTo(CFrame.new(c.pos) * CFrame.Angles(0, c.yaw, 0))

					-- HUD afstand
					local dist = distanceAhead(c)
					DistanceEvent:FireClient(plr, (dist < 0) and math.huge or dist)

					-- Trail tekenen
					local tailNow = c.pos - fwd * TRAIL_OFFSET
					if not c.lastTrail then
						c.lastTrail = tailNow
						c.currentSeg = nil
					else
						local d = (tailNow - c.lastTrail).Magnitude
						if d >= SEG_STEP * 0.5 then
							local turningNow = math.abs(c.steer or 0) >= TURN_THRESH
							local thick = WALL_THICK + (turningNow and BOCHT_EXTRA or 0)
							local seg = makeWallSegment(c.wallsFolder, c.lastTrail, tailNow, Color3.fromRGB(0,255,255))
							seg.Size = Vector3.new(thick, WALL_HEIGHT, seg.Size.Z)
							c.lastTrail = tailNow
							c.currentSeg = seg -- eigen verse segment niet als blokkade dit frame
						end
					end

					-- Score op tijd
					c.scoreAcc = (c.scoreAcc or 0) + TICK_DT
					if c.scoreAcc >= 1 then
						c.scoreAcc -= 1
						local ls = plr:FindFirstChild("leaderstats")
						if ls then
							local s = ls:FindFirstChild("Score")
							if s then s.Value += 1 end
						end
					end
				end
			end
		end
	end
end)
