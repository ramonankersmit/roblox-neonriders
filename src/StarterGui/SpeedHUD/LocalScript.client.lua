-- SpeedHUD.client.lua
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local SpeedEvent = RS:WaitForChild("SpeedEvent")
local plr = Players.LocalPlayer

local TIERS = {60, 80, 110}  -- toonwaarden; server valideert

-- Minimalistische HUD
local gui = Instance.new("ScreenGui")
gui.Name = "SpeedHUD"; gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local frame = Instance.new("Frame"); frame.Parent = gui
frame.AnchorPoint = Vector2.new(1,1)
frame.Position = UDim2.fromScale(0.98, 0.95)
frame.Size = UDim2.fromOffset(240, 52)
frame.BackgroundTransparency = 0.3
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
frame.BorderSizePixel = 0
frame.Visible = true

local uiList = Instance.new("UIListLayout", frame)
uiList.FillDirection = Enum.FillDirection.Horizontal
uiList.Padding = UDim.new(0, 6)
uiList.VerticalAlignment = Enum.VerticalAlignment.Center
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function makeBtn(i, label)
	local b = Instance.new("TextButton")
	b.Name = "Tier"..i
	b.Size = UDim2.fromOffset(70, 36)
	b.Text = label
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(0,0,0)
	b.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	b.AutoButtonColor = true
	b.Parent = frame
	b.MouseButton1Click:Connect(function()
		SpeedEvent:FireServer(i)
	end)
	return b
end

local b1 = makeBtn(1, "1")
local b2 = makeBtn(2, "2")
local b3 = makeBtn(3, "3")

-- Toetsen 1/2/3 als sneltoets
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.One  then SpeedEvent:FireServer(1) end
	if input.KeyCode == Enum.KeyCode.Two  then SpeedEvent:FireServer(2) end
	if input.KeyCode == Enum.KeyCode.Three then SpeedEvent:FireServer(3) end
end)

-- (opt.) actuele snelheid tonen in de knoppen: luister naar leaderstats
task.spawn(function()
	local ls = plr:WaitForChild("leaderstats", 5)
	if not ls then return end
	local spd = ls:WaitForChild("Speed", 5)
	if not spd then return end
	local function paint()
		-- highlight op basis van actuele speed
		local cur = spd.Value
		for i,btn in ipairs({b1,b2,b3}) do
			local isOn = (cur == TIERS[i])
			btn.BackgroundColor3 = isOn and Color3.fromRGB(0,255,180) or Color3.fromRGB(0,255,255)
		end
	end
	spd:GetPropertyChangedSignal("Value"):Connect(paint)
	paint()
end)
