-- ClientControls.client.lua (camera-neutraal)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")

local TurnEvent  = RS:WaitForChild("TurnEvent")
local RoundEvent = RS:WaitForChild("RoundEvent")
local RoundActive = RS:WaitForChild("RoundActive")
local player = Players.LocalPlayer

-- === Block jump (space) ===
local function blockJump(_, state, input)
	return Enum.ContextActionResult.Sink
end
CAS:BindActionAtPriority("BlockJump", blockJump, false, 999999, Enum.KeyCode.Space)

-- === Besturing ===
local running = false
local steer, leftDown, rightDown = 0, false, false
local useSnapTurns = false
local SNAP_TURN_DEGREES = 45

local steeringLabel

local function getSteeringStatus()
	if useSnapTurns then
		return string.format("Sturing: Haaks (%d°)", SNAP_TURN_DEGREES)
	end
	return "Sturing: Vrij (analoog)"
end

local function updateSteeringStatus()
	if steeringLabel then
		steeringLabel.Text = getSteeringStatus()
	end
end

local function setSteer()
	if leftDown and not rightDown then steer = -1
	elseif rightDown and not leftDown then steer = 1
	else steer = 0 end
end

UIS.InputBegan:Connect(function(i,gp)
        if gp then return end

        if i.KeyCode == Enum.KeyCode.T then
                useSnapTurns = not useSnapTurns
                leftDown, rightDown = false, false
                steer = 0

                if not useSnapTurns then
                        if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then
                                leftDown = true
                        end
                        if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then
                                rightDown = true
                        end
                        setSteer()
                end

                updateSteeringStatus()
                if running then
                        TurnEvent:FireServer(0)
                end
                return
        end

        if not running then return end

        if useSnapTurns then
                if i.KeyCode == Enum.KeyCode.A or i.KeyCode == Enum.KeyCode.Left then
                        TurnEvent:FireServer({ snap = -1 })
                elseif i.KeyCode == Enum.KeyCode.D or i.KeyCode == Enum.KeyCode.Right then
                        TurnEvent:FireServer({ snap = 1 })
                end
                return
        end

        if i.KeyCode == Enum.KeyCode.A or i.KeyCode == Enum.KeyCode.Left  then leftDown = true end
        if i.KeyCode == Enum.KeyCode.D or i.KeyCode == Enum.KeyCode.Right then rightDown = true end
        setSteer()
end)
UIS.InputEnded:Connect(function(i,gp)
        if gp or not running then return end
        if useSnapTurns then return end
        if i.KeyCode == Enum.KeyCode.A or i.KeyCode == Enum.KeyCode.Left  then leftDown = false end
        if i.KeyCode == Enum.KeyCode.D or i.KeyCode == Enum.KeyCode.Right then rightDown = false end
        setSteer()
end)

RunService.RenderStepped:Connect(function()
        if running and not useSnapTurns then
                TurnEvent:FireServer(steer)
        end
end)

-- === Countdown HUD ===
local gui = Instance.new("ScreenGui"); gui.ResetOnSpawn = false; gui.Name = "HUD"; gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.3, 0.2); label.Position = UDim2.fromScale(0.35, 0.3)
label.BackgroundTransparency = 1; label.TextScaled = true; label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.new(1,1,1); label.TextStrokeTransparency = 0.2; label.Visible = false; label.Parent = gui

steeringLabel = Instance.new("TextLabel")
steeringLabel.Name = "SteeringStatus"
steeringLabel.Size = UDim2.fromScale(0.24, 0.06)
steeringLabel.Position = UDim2.fromScale(0.04, 0.88)
steeringLabel.BackgroundTransparency = 1
steeringLabel.TextXAlignment = Enum.TextXAlignment.Left
steeringLabel.TextYAlignment = Enum.TextYAlignment.Center
steeringLabel.Font = Enum.Font.Gotham
steeringLabel.TextSize = 24
steeringLabel.TextColor3 = Color3.new(1,1,1)
steeringLabel.TextStrokeTransparency = 0.3
steeringLabel.Parent = gui
updateSteeringStatus()

RoundEvent.OnClientEvent:Connect(function(kind, val)
	if kind == "countdown" then
		label.Visible = true; label.Text = tostring(val); running = false
	elseif kind == "go" then
		label.Text = "GO!"; running = true
		task.delay(0.6, function() if label then label.Visible = false end end)
	end
end)

-- STOP input-loop zodra ronde eindigt
RoundActive:GetPropertyChangedSignal("Value"):Connect(function()
	if not RoundActive.Value then
		running = false
		leftDown, rightDown = false, false
		steer = 0
	end
end)
