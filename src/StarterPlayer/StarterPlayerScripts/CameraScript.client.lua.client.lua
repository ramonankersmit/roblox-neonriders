-- CameraController.client.lua — centrale chasecamera met CameraGuard mutex.
-- Houdt de camera exclusief vast zodat slechts één script per frame schrijft.
-- Front/back chase wisselbaar met F, FPV met V.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local cam    = Workspace.CurrentCamera
cam.CameraType    = Enum.CameraType.Scriptable
cam.CameraSubject = nil

local CameraGuard = require(script.Parent:WaitForChild("CameraGuard"))
local GUARD_ID = "CameraController"

-- ===== Duplicate guard =====
pcall(function() RunService:UnbindFromRenderStep("LightRaceCam") end)
do
        local token = cam:FindFirstChild("LightRaceCamActive")
	if token then
		warn("[CameraController] duplicate instance; aborting")
		return
	else
		Instance.new("BoolValue", cam).Name = "LightRaceCamActive"
	end
end

local function SetCam(cf, fov, reason)
        if not CameraGuard:tryAcquire(GUARD_ID, reason) then
                return false
        end
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CameraSubject = nil
        if fov then cam.FieldOfView = fov end
        cam.CFrame = cf
        CameraGuard:release(GUARD_ID)
        return true
end

-- ===== Bus / cinematic handshake =====
local bus    = RS:FindFirstChild("ClientBus") or Instance.new("Folder", RS)
bus.Name     = "ClientBus"; bus.Parent = RS
local CamEvt = bus:FindFirstChild("CamCinematic") or Instance.new("BindableEvent", bus)
CamEvt.Name  = "CamCinematic"; CamEvt.Parent = bus

local cineActive       = false
local pendingSnap      = nil -- {pos=Vector3, look=Vector3, fov=number}
local snapDelayFrames  = 0   -- wacht x frames voor we de snap zetten (tegen dubbele writes)
local controllerBound  = false
local onRender

local function bindControllerLoop()
	if controllerBound or not onRender then return end
	print("[CameraController] Binding LightRaceCam; controllerBound=", controllerBound, "cineActive=", cineActive)
	RunService:BindToRenderStep("LightRaceCam", Enum.RenderPriority.Last.Value, onRender)
	controllerBound = true
end

local function unbindControllerLoop()
        if not controllerBound then return end
        print("[CameraController] Unbinding LightRaceCam; controllerBound=", controllerBound, "cineActive=", cineActive)
        RunService:UnbindFromRenderStep("LightRaceCam")
        controllerBound = false
end

CamEvt.Event:Connect(function(payload)
        if not payload or not payload.type then return end
        if payload.type == "start" then
                unbindControllerLoop()
                cineActive = true
        elseif payload.type == "stop" then
                cineActive = false
                -- seed voor eerste chase-frame na cinematic
                local cycle = nil
                for _,m in ipairs(Workspace:GetChildren()) do
                        if m:IsA("Model") and m.Name == (player.Name .. "_Cycle") then cycle = m; break end
                end
		local pos, look, fov
		if cycle and cycle.PrimaryPart then
			local ppCF = cycle.PrimaryPart.CFrame
			local fwd, right = ppCF.LookVector, ppCF.RightVector
			local up = Vector3.new(0,1,0)
			-- standaard seed (achter-view); wordt zo nodig front gezet door renderChase
			local CHASE_BACK, CHASE_SIDE, CHASE_UP = 12.0, 3.2, 9.0
			local CHASE_LOOK_AHEAD = 14
			local base = ppCF.Position
			pos  = base - fwd*CHASE_BACK + right*CHASE_SIDE + up*CHASE_UP
			look = base + fwd*CHASE_LOOK_AHEAD + up*(CHASE_UP*0.6)
			fov  = 70
		else
			local snapPos = payload.pos or Vector3.new()
			local yaw     = payload.yaw or 0
			local fwd = (CFrame.Angles(0, yaw, 0)).LookVector
			local right = Vector3.new(fwd.Z,0,-fwd.X)
			local up = Vector3.new(0,1,0)
			local CHASE_BACK, CHASE_SIDE, CHASE_UP = 12.0, 3.2, 9.0
			local CHASE_LOOK_AHEAD = 14
			pos  = snapPos - fwd*CHASE_BACK + right*CHASE_SIDE + up*CHASE_UP
			look = snapPos + fwd*CHASE_LOOK_AHEAD + up*(CHASE_UP*0.6)
			fov  = 70
		end
                pendingSnap = {pos = pos, look = look, fov = fov}
                snapDelayFrames = 2
                bindControllerLoop()
        end
end)

-- ===== Round flow (force FPV tijdens countdown) =====
local RoundEvent      = RS:FindFirstChild("RoundEvent")
local RoundActiveVal  = RS:WaitForChild("RoundActive")
local forceFPV        = true

if RoundEvent then
	RoundEvent.OnClientEvent:Connect(function(kind)
		if kind == "countdown" then forceFPV = true end
		if kind == "go"        then forceFPV = false end
	end)
end

-- ===== Manual toggles =====
local useCockpitManual = false
local controllerEnabled = true   -- K: toggelt onze writer
local frontChase = false         -- F: wissel front/back chase (default: achtervolg-view)
local resetSmoothing             -- forward declare zodat we 'm vanuit toggles kunnen aanroepen
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.V then
		useCockpitManual = not useCockpitManual
	elseif input.KeyCode == Enum.KeyCode.K then
		controllerEnabled = not controllerEnabled
		print("[CamGuard] controllerEnabled=", controllerEnabled)
        elseif input.KeyCode == Enum.KeyCode.F then
                frontChase = not frontChase
                if resetSmoothing then resetSmoothing() end -- voorkom smoothing-blend tussen front/back
                print("[Cam] chase mode =", frontChase and "FRONT" or "BACK")
        end
end)

-- ===== Tuning =====
-- BACK-CHASE offsets
local CHASE_BACK, CHASE_SIDE, CHASE_UP  = 12.0, 3.2, 9.0
local CHASE_LOOK_AHEAD, CHASE_FOV       = 14, 70

-- FRONT-CHASE offsets (camera vóór de cycle, kijkend naar de cycle)
local FRONT_AHEAD, FRONT_SIDE, FRONT_UP = 11.0, 0.0, 9.0
-- Je kunt FRONT_SIDE bv. 1.5 zetten voor een schuin-front effect

local ANTICLIP_PUSH                     = 0.6
-- FPV
local FPV_FOV, FPV_HEAD_BACK, FPV_AHEAD = 80, 0.12, 11
local FPV_SEAT_Y, FPV_SEAT_Z            = 2.1, -0.10
-- ===== Helpers =====
local function getCycle()
        for _,m in ipairs(Workspace:GetChildren()) do
                if m:IsA("Model") and m.Name == (player.Name .. "_Cycle") then
                        return m
		end
	end
end

local function myWallsFolder()
	return Workspace:FindFirstChild(player.Name .. "_Walls")
end

local function raycast_exclude(fromPos, toPos, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	return Workspace:Raycast(fromPos, (toPos - fromPos), params)
end

-- ===== State =====
local lastCycle   = nil
local clipArmed   = false

resetSmoothing = function()
        clipArmed = false
end
Players.LocalPlayer.CharacterAdded:Connect(resetSmoothing)
RoundActiveVal:GetPropertyChangedSignal("Value"):Connect(resetSmoothing)

-- ===== Chase compute (back & front) =====
local function computeChaseBack(baseCF, cycle)
	local pos   = baseCF.Position
	local fwd   = baseCF.LookVector
	local right = baseCF.RightVector
	local up    = Vector3.new(0,1,0)

	local wantPos  = pos - fwd*CHASE_BACK + right*CHASE_SIDE + up*CHASE_UP
	local wantLook = pos + fwd*CHASE_LOOK_AHEAD + up*(CHASE_UP*0.6)

	-- Anti-clip: negeer eigen cycle/character/walls
	local exclude = {cycle, player.Character}
	local walls = myWallsFolder(); if walls then table.insert(exclude, walls) end
	local target = pos + up*(CHASE_UP*0.6)
	local hit = raycast_exclude(target, wantPos, exclude)
	if hit then
		local dir = (wantPos - target).Unit
		wantPos = hit.Position - dir * ANTICLIP_PUSH
		clipArmed = true
	else
		if clipArmed then
			local extra = raycast_exclude(target, wantPos + (wantPos - target).Unit * 0.25, exclude)
			if extra then
				local dir = (wantPos - target).Unit
				wantPos = extra.Position - dir * ANTICLIP_PUSH
			else
				clipArmed = false
			end
		end
	end
	return wantPos, wantLook
end

local function computeChaseFront(baseCF, cycle)
	local pos   = baseCF.Position
	local fwd   = baseCF.LookVector
	local right = baseCF.RightVector
	local up    = Vector3.new(0,1,0)

	-- camera vóór de cycle, kijkend naar de cycle
	local wantPos  = pos + fwd*FRONT_AHEAD + right*FRONT_SIDE + up*FRONT_UP
	local wantLook = pos + up*(FRONT_UP*0.6)

	-- Anti-clip: negeer eigen cycle/character/walls
	local exclude = {cycle, player.Character}
	local walls = myWallsFolder(); if walls then table.insert(exclude, walls) end
	local target = wantLook -- we kijken naar de cycle; cast vanaf target naar camera
	local hit = raycast_exclude(target, wantPos, exclude)
	if hit then
		local dir = (wantPos - target).Unit
		wantPos = hit.Position - dir * ANTICLIP_PUSH
		clipArmed = true
	else
		if clipArmed then
			local extra = raycast_exclude(target, wantPos + (wantPos - target).Unit * 0.25, exclude)
			if extra then
				local dir = (wantPos - target).Unit
				wantPos = extra.Position - dir * ANTICLIP_PUSH
			else
				clipArmed = false
			end
		end
	end
	return wantPos, wantLook
end

-- ===== Renderers =====
local function renderChase(cycle)
        local pp = cycle.PrimaryPart; if not pp then return end
        local baseCF = pp.CFrame
        local wantPos, wantLook
	if frontChase then
		wantPos, wantLook = computeChaseFront(baseCF, cycle)
	else
		wantPos, wantLook = computeChaseBack(baseCF, cycle)
	end

        SetCam(CFrame.new(wantPos, wantLook), CHASE_FOV, frontChase and "chase_front" or "chase_back")
end

local function renderFPV(cycle)
	local char = player.Character
        local head = char and char:FindFirstChild("Head")
        local eye, ahead

        if head and head:IsA("BasePart") then
                local headCF = head.CFrame
                eye   = (headCF * CFrame.new(0, 0, FPV_HEAD_BACK)).Position
                ahead = eye + headCF.LookVector * FPV_AHEAD
        else
                local pp = cycle.PrimaryPart
                local baseCF = pp and pp.CFrame or CFrame.new()
                eye   = (baseCF * CFrame.new(0, FPV_SEAT_Y, FPV_SEAT_Z)).Position
                ahead = eye + baseCF.LookVector * FPV_AHEAD
        end

	-- mini anti-clip vlak voor de cam
	local hit = raycast_exclude(eye, eye + (ahead - eye).Unit * 0.7, {cycle, char})
	if hit then eye = eye + (ahead - eye).Unit * 0.35 end

	SetCam(CFrame.new(eye, ahead), FPV_FOV, "fpv")
	resetSmoothing()
end

local function renderLobby()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local forward = root.CFrame.LookVector
        forward = Vector3.new(forward.X, 0, forward.Z)
        if forward.Magnitude < 1e-4 then
                forward = Vector3.new(0, 0, -1)
        else
                forward = forward.Unit
        end

        local rootPos = root.Position
        local eye = rootPos - forward * 14 + Vector3.new(0, 8, 0)
        local look = rootPos + forward * 6 + Vector3.new(0, 2, 0)
        SetCam(CFrame.new(eye, look), 70, "lobby")
end

-- ===== Render loop (single writer) =====
onRender = function(_dt)
	if workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	end

	if not controllerEnabled then return end
	if cineActive then return end

	if pendingSnap then
                if snapDelayFrames > 0 then
                        snapDelayFrames -= 1
                        return
                end
                if SetCam(CFrame.new(pendingSnap.pos, pendingSnap.look), pendingSnap.fov or CHASE_FOV, "snap") then
                        resetSmoothing()
                        pendingSnap = nil
                end
                return
        end

        if not RoundActiveVal.Value then
                renderLobby()
                return
        end

        local cycle = getCycle()
        if not cycle or not cycle.PrimaryPart then
                return
        end

        if cycle ~= lastCycle then
                lastCycle = cycle
                resetSmoothing()
        end

        if (forceFPV or useCockpitManual) then
                renderFPV(cycle)
        else
                renderChase(cycle)
        end
end

bindControllerLoop()
