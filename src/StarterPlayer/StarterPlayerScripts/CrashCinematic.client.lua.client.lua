-- CrashCinematic.client.lua (debug + archivable + zichtbare ragdoll)
-- Cinematic top-shot + cycle shatter + lokale ragdoll, met fail-safe reset en debug.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local plr = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local RoundActive = RS:WaitForChild("RoundActive")
local activeCleanup = nil  -- zolang niet nil => cinematic actief

-- Client-bus
local bus = RS:FindFirstChild("ClientBus") or Instance.new("Folder")
bus.Name = "ClientBus"; bus.Parent = RS
local CamEvt = bus:FindFirstChild("CamCinematic") or Instance.new("BindableEvent")
CamEvt.Name = "CamCinematic"; CamEvt.Parent = bus

local CrashEvent = RS:WaitForChild("CrashEvent")

-- ===== Debug =====
local DEBUG = true
local function marker(pos, color, sz, t)
	if not DEBUG then return end
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255,0,0)
	p.Size = Vector3.new(sz or 1, sz or 1, sz or 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = Workspace
	Debris:AddItem(p, t or 2)
end

-- ===== Tuning =====
local DURATION           = 1.6
local CAM_UP             = 12
local CAM_BACK           = 14
local CAM_SIDE           = 8
local CAM_FOV            = 62

local SHATTER_FORCE      = 120
local SHATTER_SPIN       = 50

local RAGDOLL_LIFETIME   = 4.0
local RAGDOLL_FADE_DELAY = 1.5
local RAGDOLL_FADE_TIME  = 2.0
local RAGDOLL_PHYS       = PhysicalProperties.new(1.0, 0.6, 0.35, 1, 1)

-- ===== Utils =====
local function fwdFromYaw(yaw) return (CFrame.Angles(0, yaw, 0)).LookVector end
local function randUnit()
	local x,y,z = math.random()-0.5, math.random()-0.5, math.random()-0.5
	local v = Vector3.new(x,y,z); return (v.Magnitude > 0) and v.Unit or Vector3.new(0,1,0)
end
local function safeResetCamera(crashPos, yaw)
	local fwd = fwdFromYaw(yaw)
	local pos = crashPos - fwd*16 + Vector3.new(0, 10, 0) + Vector3.new(6, 0, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(pos, crashPos + fwd*8)
end

-- ===== Shatter (cycle, lokaal) =====
local function spawnCycleShatter(cycleModel, crashPos)
	if not cycleModel or not cycleModel.Parent then return end
	local ok, clone = pcall(function() return cycleModel:Clone() end)
	if not ok or not clone then if DEBUG then warn("[CycleShatter] clone failed") end; return end
	clone.Name = "CycleShatter_LOCAL"
	clone.Parent = Workspace
	clone:PivotTo(CFrame.new(crashPos))

	-- maak alles los/zichtbaar
	for _,d in ipairs(clone:GetDescendants()) do
		if d and d:IsA("WeldConstraint") then d:Destroy()
		elseif d and d:IsA("BasePart") then
			d.Anchored, d.CanCollide = false, true
			d.CustomPhysicalProperties = RAGDOLL_PHYS
			d.Material = Enum.Material.Neon
			d.Color = Color3.fromRGB(80,160,255)
			d.Transparency = 0
			pcall(function() d.CollisionGroup = "Default" end)
		end
	end

	-- impulsen
	local parts = {}
	for _,p in ipairs(clone:GetDescendants()) do
		if p and p:IsA("BasePart") then
			local dir = (p.Position - crashPos); dir = (dir.Magnitude < 0.1) and randUnit() or dir.Unit
			local mass = (p.AssemblyMass and p.AssemblyMass > 0) and p.AssemblyMass or 1
			p:ApplyImpulse((dir + Vector3.new(0,0.4,0) + 0.25*randUnit()) * SHATTER_FORCE * mass)
			p:ApplyAngularImpulse(randUnit() * SHATTER_SPIN * mass)
			table.insert(parts, p)
		end
	end
	if DEBUG then warn(("[CycleShatter] parts=%d"):format(#parts)) end

	-- fade na delay
	task.delay(RAGDOLL_FADE_DELAY, function()
		for _,p in ipairs(parts) do
			if p and p.Parent then
				TweenService:Create(p, TweenInfo.new(RAGDOLL_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
			end
		end
	end)

	Debris:AddItem(clone, DURATION + RAGDOLL_LIFETIME)
end

-- ===== Ragdoll (avatar, lokaal) =====
local function spawnLocalRagdoll(character, crashPos)
	if not character or not character.Parent then if DEBUG then warn("[Ragdoll] no character") end; return end

	-- Sommige games hebben character.Archivable=false → clone faalt stil.
	local oldArch = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function() return character:Clone() end)
	character.Archivable = oldArch

	if not ok or not clone then if DEBUG then warn("[Ragdoll] clone failed") end; return end

	clone.Name = "Ragdoll_LOCAL"
	clone.Parent = Workspace

	-- scripts eruit
	for _,d in ipairs(clone:GetDescendants()) do
		if d and (d:IsA("Script") or d:IsA("LocalScript")) then d:Destroy() end
	end

	-- Belangrijk: clone zichtbaar maken (LTM van live char kan 1 zijn)
	for _,bp in ipairs(clone:GetDescendants()) do
		if bp and bp:IsA("BasePart") then
			bp.LocalTransparencyModifier = 0
			if (bp.Transparency or 0) > 0.95 then bp.Transparency = 0 end
			-- debug styling → fel rood
			bp.Material = Enum.Material.Neon
			bp.Color = Color3.fromRGB(255,80,80)
		end
	end

	-- positioneer
	local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
	if root then clone:PivotTo(CFrame.new(crashPos)) end

	-- joints los
	local okBreak = pcall(function() clone:BreakJoints() end)
	if not okBreak then if DEBUG then warn("[Ragdoll] BreakJoints failed") end end

	-- humanoid weg
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then hum:Destroy() end

	-- physics + impulsen
	local parts = {}
	for _,p in ipairs(clone:GetDescendants()) do
		if p and p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
			p.Massless = false
			p.CustomPhysicalProperties = RAGDOLL_PHYS
			pcall(function() p.CollisionGroup = "Default" end)

			local dir = (p.Position - crashPos)
			dir = (dir.Magnitude < 0.1) and Vector3.new(0,1,0) or dir.Unit
			local mass = (p.AssemblyMass and p.AssemblyMass > 0) and p.AssemblyMass or 1
			p:ApplyImpulse((dir + Vector3.new(0,0.7,0)) * SHATTER_FORCE * 0.6 * mass)
			p:ApplyAngularImpulse(Vector3.new(
				(math.random()-0.5)*2, (math.random()-0.5)*2, (math.random()-0.5)*2
				).Unit * (SHATTER_SPIN * 0.6) * mass)

			table.insert(parts, p)
		end
	end
	if DEBUG then warn(("[Ragdoll] parts=%d"):format(#parts)) end
	marker(crashPos + Vector3.new(0,2,0), Color3.fromRGB(255,0,0), 1.5, 2)

	-- fade na delay
	task.delay(RAGDOLL_FADE_DELAY, function()
		for _,p in ipairs(parts) do
			if p and p.Parent then
				TweenService:Create(p, TweenInfo.new(RAGDOLL_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
			end
		end
	end)

	Debris:AddItem(clone, DURATION + RAGDOLL_LIFETIME)
end

-- ===== Cinematic =====
local function playCinematic(crashPos, yaw)
	if DEBUG then warn("[Cine] start", crashPos) end
	CamEvt:Fire({type="start", pos=crashPos, yaw=yaw})

	-- verberg live character lokaal
	local char = Players.LocalPlayer.Character
	local hidden = {}
	if char then
		for _,bp in ipairs(char:GetDescendants()) do
			if bp and bp:IsA("BasePart") then
				hidden[bp] = bp.LocalTransparencyModifier
				bp.LocalTransparencyModifier = 1
			end
		end
	end

	local fwd = fwdFromYaw(yaw)
	local right = Vector3.new(fwd.Z, 0, -fwd.X)
	local startPos = crashPos - fwd*CAM_BACK + right*CAM_SIDE + Vector3.new(0, CAM_UP, 0)
	local endPos   = crashPos - fwd*(CAM_BACK*0.6) + right*(CAM_SIDE*0.4) + Vector3.new(0, CAM_UP*1.1, 0)

	local blur = Instance.new("BlurEffect"); blur.Size = 8; blur.Parent = camera
	local fovStart = camera.FieldOfView
	TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = CAM_FOV}):Play()

	local tValue = Instance.new("NumberValue"); tValue.Value = 0
	local camConn
	camConn = RunService:BindToRenderStep("CrashCinematicCam", Enum.RenderPriority.Camera.Value + 2, function()
		local t = tValue.Value
		local pos = startPos:Lerp(endPos, t)
		camera.CFrame = CFrame.new(pos, crashPos)
	end)

	local tween = TweenService:Create(tValue, TweenInfo.new(DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Value = 1})

	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		if DEBUG then warn("[Cine] stop") end

		-- stop onze renderloop
		if camConn then RunService:UnbindFromRenderStep("CrashCinematicCam"); camConn = nil end

		-- effectjes weg, FOV terug
		if blur then blur:Destroy() end
		camera.FieldOfView = fovStart

		-- maak local character weer zichtbaar (LTM terug)
		local nowChar = Players.LocalPlayer.Character
		if nowChar then
			for _,bp in ipairs(nowChar:GetDescendants()) do
				if bp:IsA("BasePart") then bp.LocalTransparencyModifier = 0 end
			end
		end

		-- 1 frame later pas de stop naar de controller → één schrijver per frame
		task.spawn(function()
			RunService.RenderStepped:Wait()
			CamEvt:Fire({type="stop", pos=crashPos, yaw=yaw})
		end)

		activeCleanup = nil
	end
	activeCleanup = cleanup
	
	tween.Completed:Connect(function() cleanup() end)
	tween:Play()
	task.delay(DURATION + 0.1, cleanup)   -- timeout 1
	task.delay(DURATION + 0.7, cleanup)   -- timeout 2
end

RoundActive:GetPropertyChangedSignal("Value"):Connect(function()
	if not RoundActive.Value and activeCleanup then
		activeCleanup()
	end
end)

-- ===== Event van server =====
CrashEvent.OnClientEvent:Connect(function(payload)
	warn("[CrashEvent] client got payload")
	if not payload then return end
	local pos = payload.pos or Vector3.new()
	local yaw = payload.yaw or 0
	local cycleModel = payload.cycle

	marker(pos, Color3.fromRGB(0,255,0), 1.25, 2) -- toon crash plek
	playCinematic(pos, yaw)

	-- visuals
	task.spawn(function() pcall(spawnCycleShatter, cycleModel, pos) end)
	task.spawn(function()
		local ch = Players.LocalPlayer.Character
		if ch then spawnLocalRagdoll(ch, pos) else warn("[Ragdoll] no LocalPlayer.Character at crash") end
	end)
end)
