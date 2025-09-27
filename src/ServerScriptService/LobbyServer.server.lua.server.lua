local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local LobbyEvent = RS:WaitForChild("LobbyEvent")
local RoundActive = RS:WaitForChild("RoundActive")

local MIN_PLAYERS = 1
local COUNTDOWN = 3

local ready = {}
local inRound = {}

local function broadcastLobby()
	local list, readyCount = {}, 0
	for _,plr in ipairs(Players:GetPlayers()) do
		local isReady = ready[plr] == true
		if isReady then readyCount += 1 end
		table.insert(list, {name = plr.Name, ready = isReady})
	end
	for _,plr in ipairs(Players:GetPlayers()) do
		LobbyEvent:FireClient(plr, {type="lobby", total=#Players:GetPlayers(), ready=readyCount, list=list, min=MIN_PLAYERS})
	end
end

local function sendRound(kind, val)
	local RoundEvent = RS:FindFirstChild("RoundEvent")
	if not RoundEvent then return end
	for plr,_ in pairs(inRound) do RoundEvent:FireClient(plr, kind, val) end
end

local function putInLobby(plr)
	local sp = workspace:FindFirstChild("LobbySpawn")
	if sp and plr.Character and plr.Character.PrimaryPart then
		plr.Character:PivotTo(CFrame.new(sp.Position + Vector3.new(0,3,0)))
	end
end

local function startRound()
	if RoundActive.Value then return end
	local participants = {}
	for _,plr in ipairs(Players:GetPlayers()) do
		if ready[plr] then table.insert(participants, plr) end
	end
	if #participants < MIN_PLAYERS then return end

	RoundActive.Value = true
	inRound = {}
	for _,plr in ipairs(participants) do
		inRound[plr] = true
		plr:SetAttribute("JoinRound", true) -- gate voor GameServer
		task.defer(function() if plr.Parent == Players then plr:LoadCharacter() end end)
	end

	for t = COUNTDOWN,1,-1 do sendRound("countdown", t); task.wait(1) end
	sendRound("go")
end

local function endRound()
	RoundActive.Value = false
	inRound = {}
	for plr,_ in pairs(ready) do ready[plr] = false end

	-- ▼ extra: zorg dat niemand nog 'JoinRound' heeft
	for _,plr in ipairs(Players:GetPlayers()) do
		plr:SetAttribute("JoinRound", nil)
	end

	broadcastLobby()
	for _,plr in ipairs(Players:GetPlayers()) do
		plr:SetAttribute("JoinRound", nil)  -- zekerheid
		-- forceer respawn; jouw PlayerAdded/CharacterAdded verplaatst naar LobbySpawn
		task.defer(function()
			if plr and plr.Parent == Players then plr:LoadCharacter() end
		end)
	end
end

-- >>> HIER: UI-commando's uit de client
LobbyEvent.OnServerEvent:Connect(function(plr, msg)
	if type(msg) ~= "table" then return end
	if msg.cmd == "toggle_ready" then
		ready[plr] = not ready[plr]
		LobbyEvent:FireClient(plr, {type="you_ready", ready=ready[plr]})
		broadcastLobby()
	elseif msg.cmd == "start" then
		startRound()
	elseif msg.cmd == "end" then
		if RoundActive.Value then endRound() end
	end
end)

-- join/leave
Players.PlayerAdded:Connect(function(plr)
	ready[plr] = false
	plr.CharacterAdded:Connect(function()
		if not RoundActive.Value then task.wait(0.2); putInLobby(plr) end
	end)
	task.defer(broadcastLobby)
end)

Players.PlayerRemoving:Connect(function(plr)
	ready[plr] = nil
	inRound[plr] = nil
	task.defer(broadcastLobby)
end)

-- ProximityPrompts (optioneel, blijven werken als je ze hebt)
task.spawn(function()
	while not _G.Lobby_StartPrompt do task.wait(0.1) end
	_G.Lobby_StartPrompt.Triggered:Connect(function(_) startRound() end)
	_G.Lobby_ReadyPrompt.Triggered:Connect(function(plr)
		ready[plr] = not ready[plr]; LobbyEvent:FireClient(plr, {type="you_ready", ready=ready[plr]}); broadcastLobby()
	end)
end)
