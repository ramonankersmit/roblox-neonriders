-- StarterGui/DistanceHUD/LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DistanceEvent = ReplicatedStorage:WaitForChild("DistanceEvent")

-- === UI opbouwen (1 Text + 1 Bar) ===
local gui = script.Parent
-- alles leegmaken zodat er geen oude labels achterblijven
for _,child in ipairs(gui:GetChildren()) do
	if child ~= script then child:Destroy() end
end
gui.ResetOnSpawn = true

local container = Instance.new("Frame")
container.Name = "TronHUD"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.fromScale(0.5, 0.03)
container.Size = UDim2.fromScale(0.5, 0.1)
container.BackgroundTransparency = 1
container.Parent = gui

local label = Instance.new("TextLabel")
label.Name = "DistanceLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0)
label.Size = UDim2.fromScale(1, 0.45)
label.BackgroundTransparency = 1
label.Text = "Afstand muur: —"
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(0, 255, 255) -- Tron cyaan
label.Parent = container

-- Bar container (met glansrand)
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.fromScale(0.5, 1)
bar.Size = UDim2.fromScale(1, 0.4)
bar.BackgroundColor3 = Color3.fromRGB(10, 20, 25)
bar.BorderSizePixel = 0
bar.Parent = container

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = bar

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(0, 255, 255)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = bar

-- Vulling
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.AnchorPoint = Vector2.new(0, 0.5)
fill.Position = UDim2.fromScale(0, 0.5)
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
fill.BorderSizePixel = 0
fill.Parent = bar

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 10)
fillCorner.Parent = fill

local grad = Instance.new("UIGradient")
grad.Rotation = 0
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 120, 255))
}
grad.Parent = fill

-- parameters
local MAX_BAR_DIST = 600      -- afstand waarbij de balk “vol” is (pas aan naar smaak)
local EMA_ALPHA    = 0.25     -- smoothing (0..1)
local currentShown = nil      -- gesmoothe weergave

local function setBarFraction(frac)
	frac = math.clamp(frac, 0, 1)
	fill:TweenSize(UDim2.fromScale(frac, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.08, true)
end

local function updateHUD(dist)
	if dist == nil then
		-- reset tijdens dood/respawn/countdown
		label.Text = "Afstand muur: —"
		setBarFraction(0)
		currentShown = nil
		return
	end

	if type(dist) ~= "number" or dist < 0 or dist == math.huge then
		-- “oneindig ver”
		label.Text = "Afstand muur: ∞"
		setBarFraction(1)
		return
	end

	-- smoothing
	if currentShown == nil then
		currentShown = dist
	else
		currentShown = currentShown + EMA_ALPHA * (dist - currentShown)
	end

	label.Text = ("Distance wall: %.1f studs"):format(currentShown)

	-- Bar: hoe dichterbij, hoe korter (klassiek proximity)
	-- Zet evt. om naar “langer bij dichterbij” met 1 - frac
	local frac = math.clamp(currentShown / MAX_BAR_DIST, 0, 1)
	setBarFraction(1 - frac)
end

DistanceEvent.OnClientEvent:Connect(updateHUD)
