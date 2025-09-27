-- Simpele WASD alleen in de lobby (RoundActive=false). Breekt de camera niet.
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService"); local RunService=game:GetService("RunService")
local plr=Players.LocalPlayer; local RoundActive=RS:WaitForChild("RoundActive")

local dir = Vector3.new()
local keys = {W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,D=Enum.KeyCode.D}
local down = {}

local function canControlHumanoid()
        if not RoundActive.Value then return true end
        return plr:GetAttribute("JoinRound") ~= true
end

UIS.InputBegan:Connect(function(i,g) if g then return end; for k,code in pairs(keys) do if i.KeyCode==code then down[k]=true end end end)
UIS.InputEnded:Connect(function(i,g) if g then return end; for k,code in pairs(keys) do if i.KeyCode==code then down[k]=false end end end)

RunService.RenderStepped:Connect(function()
        if not canControlHumanoid() then return end
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        local cam = workspace.CurrentCamera; if not cam then return end

        local right = 0
        if down.D then right += 1 end
        if down.A then right -= 1 end

        local forward = 0
        if down.W then forward += 1 end
        if down.S then forward -= 1 end

        if right ~= 0 or forward ~= 0 then
                local camCF = cam.CFrame
                local camForward = camCF.LookVector
                camForward = Vector3.new(camForward.X, 0, camForward.Z)
                if camForward.Magnitude < 1e-4 then
                        camForward = Vector3.new(0, 0, -1)
                else
                        camForward = camForward.Unit
                end

                local camRight = camCF.RightVector
                camRight = Vector3.new(camRight.X, 0, camRight.Z)
                if camRight.Magnitude < 1e-4 then
                        camRight = Vector3.new(camForward.Z, 0, -camForward.X)
                else
                        camRight = camRight.Unit
                end

                local moveDir = camForward * forward + camRight * right
                if moveDir.Magnitude > 1 then
                        moveDir = moveDir.Unit
                end

                hum:Move(moveDir, false)
        else
                hum:Move(Vector3.zero, false)
        end
end)
