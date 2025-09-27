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
        if not workspace.CurrentCamera then return end

        local x = 0
        if down.D then x += 1 end
        if down.A then x -= 1 end

        local z = 0
        if down.S then z += 1 end
        if down.W then z -= 1 end

        local move = Vector3.new(x, 0, z)
        if move.Magnitude > 0 then
                hum:Move(move.Unit, true)
        else
                hum:Move(Vector3.zero, false)
        end
end)
