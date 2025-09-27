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
        local camera = workspace.CurrentCamera
        if not camera then return end

        local camCFrame = camera.CFrame
        local forward = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
        local right = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z)

        if forward.Magnitude == 0 or right.Magnitude == 0 then return end
        forward = forward.Unit
        right = right.Unit

        local v = Vector3.zero
        if down.W then v += forward end
        if down.S then v -= forward end
        if down.A then v -= right   end
        if down.D then v += right   end

        if v.Magnitude > 0 then
                hum:Move(v.Unit, false)
        else
                hum:Move(Vector3.zero, false)
        end
end)
