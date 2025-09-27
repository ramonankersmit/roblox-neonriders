local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local LobbyEvent = RS:WaitForChild("LobbyEvent")

local gui = Instance.new("ScreenGui"); gui.Name="LobbyUI"; gui.ResetOnSpawn=false; gui.Parent=plr:WaitForChild("PlayerGui")
local panel = Instance.new("Frame"); panel.AnchorPoint=Vector2.new(0,1); panel.Position=UDim2.fromScale(0,1)
panel.Size=UDim2.new(0, 300, 0, 180); panel.BackgroundTransparency=0.25; panel.Parent=gui

local title = Instance.new("TextLabel"); title.Size=UDim2.new(1,-10,0,26); title.Position=UDim2.new(0,5,0,4)
title.BackgroundTransparency=1; title.Text="Lobby"; title.Font=Enum.Font.GothamBold; title.TextSize=20; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=panel

local status = Instance.new("TextLabel"); status.Size=UDim2.new(1,-10,0,18); status.Position=UDim2.new(0,5,0,28)
status.BackgroundTransparency=1; status.TextScaled=false; status.Font=Enum.Font.Gotham; status.TextSize=16; status.TextXAlignment=Enum.TextXAlignment.Left; status.Parent=panel

local list = Instance.new("TextLabel"); list.Size=UDim2.new(1,-10,1,-98); list.Position=UDim2.new(0,5,0,48)
list.BackgroundTransparency=1; list.TextXAlignment=Enum.TextXAlignment.Left; list.TextYAlignment=Enum.TextYAlignment.Top
list.Font=Enum.Font.Code; list.TextSize=16; list.Text=""; list.Parent=panel

local btnReady = Instance.new("TextButton"); btnReady.Size=UDim2.new(0,120,0,34); btnReady.Position=UDim2.new(0,10,1,-40)
btnReady.Text="I'm Ready (E)"; btnReady.Parent=panel

local btnStart = Instance.new("TextButton"); btnStart.Size=UDim2.new(0,120,0,34); btnStart.Position=UDim2.new(0,150,1,-40)
btnStart.Text="Start (Y)"; btnStart.Parent=panel; btnStart.AutoButtonColor=true; btnStart.Visible=false

local btnEnd = Instance.new("TextButton"); btnEnd.Size=UDim2.new(0,80,0,26); btnEnd.Position=UDim2.new(1,-90,0,6)
btnEnd.Text="End"; btnEnd.Parent=panel; btnEnd.Visible=false

local RoundActive = RS:WaitForChild("RoundActive")
local lastReady, lastMin = 0, 1
local function refreshButtons()
	btnEnd.Visible   = RoundActive.Value
	btnStart.Visible = (not RoundActive.Value) and (lastReady >= lastMin)
end
RoundActive:GetPropertyChangedSignal("Value"):Connect(refreshButtons)

-- events
btnReady.MouseButton1Click:Connect(function()
	RS.LobbyEvent:FireServer({cmd="toggle_ready"})
end)
btnStart.MouseButton1Click:Connect(function()
	RS.LobbyEvent:FireServer({cmd="start"})
end)
btnEnd.MouseButton1Click:Connect(function()
	RS.LobbyEvent:FireServer({cmd="end"})
end)

-- keyboard shortcuts
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(i,gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.E then btnReady:Activate() end
	if i.KeyCode == Enum.KeyCode.Y then btnStart:Activate() end
end)

LobbyEvent.OnClientEvent:Connect(function(payload)
	if not payload or payload.type ~= "lobby" then return end
	status.Text = ("Players ready: %d / %d"):format(payload.ready or 0, payload.min or 1)

	lastReady = payload.ready or 0
	lastMin   = payload.min or 1
	refreshButtons()

	local lines = {"----------------"}
	for _,row in ipairs(payload.list or {}) do
		table.insert(lines, string.format("%-18s  %s", row.name, row.ready and "READY" or "—"))
	end
	list.Text = table.concat(lines, "\n")

	-- Start zichtbaar als genoeg spelers & ronde nog niet actief
	local roundActive = RS:FindFirstChild("RoundActive")
	local canStart = (payload.ready or 0) >= (payload.min or 1) and roundActive and (roundActive.Value == false)
	btnStart.Visible = canStart
	btnEnd.Visible   = roundActive and roundActive.Value == true
end)
