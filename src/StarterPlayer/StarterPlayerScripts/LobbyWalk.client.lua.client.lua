-- Simpele WASD alleen in de lobby (RoundActive=false). Breekt de camera niet.
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService"); local RunService=game:GetService("RunService")
local plr=Players.LocalPlayer; local RoundActive=RS:WaitForChild("RoundActive")

local keys = {W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,D=Enum.KeyCode.D}
local down = {}
local lastHumanoid
local lastAutoRotate
local lastRoot
local currentYaw = 0

local function restoreAutoRotate()
        if lastHumanoid and lastHumanoid.Parent then
                if lastAutoRotate ~= nil then
                        lastHumanoid.AutoRotate = lastAutoRotate
                end
        end
        lastHumanoid = nil
        lastAutoRotate = nil
        lastRoot = nil
        currentYaw = 0
end

local function canControlHumanoid()
        if not RoundActive.Value then return true end
        return plr:GetAttribute("JoinRound") ~= true
end

UIS.InputBegan:Connect(function(i,g) if g then return end; for k,code in pairs(keys) do if i.KeyCode==code then down[k]=true end end end)
UIS.InputEnded:Connect(function(i,g) if g then return end; for k,code in pairs(keys) do if i.KeyCode==code then down[k]=false end end end)

local function extractYaw(cf)
        local _, y, _ = cf:ToOrientation()
        return y
end

local function updateRootOrientation(root)
        local pos = root.Position
        root.CFrame = CFrame.new(pos) * CFrame.Angles(0, currentYaw, 0)
end

RunService.RenderStepped:Connect(function(dt)
        local controlling = canControlHumanoid()
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then
                restoreAutoRotate()
                return
        end

        if not controlling then
                restoreAutoRotate()
                return
        end

        if lastHumanoid ~= hum then
                restoreAutoRotate()
                lastHumanoid = hum
                lastAutoRotate = hum.AutoRotate
        end
        if hum.AutoRotate then
                hum.AutoRotate = false
        end

        local root = char:FindFirstChild("HumanoidRootPart")

        if root then
                if lastRoot ~= root then
                        currentYaw = extractYaw(root.CFrame)
                        lastRoot = root
                end
        else
                lastRoot = nil
        end

        local turnInput = 0
        if down.D then turnInput += 1 end
        if down.A then turnInput -= 1 end

        local forwardInput = 0
        if down.W then forwardInput += 1 end
        if down.S then forwardInput -= 1 end

        if root then
                local turn = 0
                if turnInput > 0 then turn -= 1 end
                if turnInput < 0 then turn += 1 end

                local TURN_SPEED = math.rad(180)
                if turn ~= 0 then
                        currentYaw += TURN_SPEED * dt * turn
                        updateRootOrientation(root)
                else
                        -- keep the root aligned to stored yaw even when standing still
                        updateRootOrientation(root)
                end

                local forwardVec = root.CFrame.LookVector
                forwardVec = Vector3.new(forwardVec.X, 0, forwardVec.Z)
                if forwardVec.Magnitude > 0 then
                        forwardVec = forwardVec.Unit
                end

                local moveDir = forwardVec * forwardInput
                if moveDir.Magnitude > 1 then
                        moveDir = moveDir.Unit
                end

                hum:Move(moveDir, false)
        end
end)

plr.CharacterRemoving:Connect(function()
        restoreAutoRotate()
end)
