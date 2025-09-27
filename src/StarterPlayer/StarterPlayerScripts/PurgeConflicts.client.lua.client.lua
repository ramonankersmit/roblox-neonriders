-- PurgeConflicts.client.lua
-- Verwijdert alle bekende "tweede camera-writers" en houdt de camera hard op Scriptable.
-- Zet dit in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local KILL_NAMES = {
	-- local “proxies” die eerder stotter/dubbel beeld gaven
	["LocalRenderProxy"]   = true,
	["LocalRenderProxy.client"] = true,
	["LocalRiderProxy"]    = true,
	["LocalRiderProxy.client"]  = true,
	["PoseHandshake"]      = true,
	["PoseHandshake.client"]= true,
	-- loader die vaak default PlayerModule/CameraModule activeert
	["PlayerScriptsLoader"] = true,
	-- default PlayerModule die CameraModule levert
	["PlayerModule"]        = true,
	-- in sommige templates staat nog een Freecam ui/script in PlayerGui
	["Freecam"]             = true,
	["FreecamScript"]       = true,
}

local function isKillName(name)
	return KILL_NAMES[name] == true
end

local function safeDestroy(inst, why)
	if not inst or not inst.Parent then return end
	pcall(function()
		print(("[PurgeCam] Removing %s (%s)"):format(inst:GetFullName(), why or "conflict"))
		inst:Destroy()
	end)
end

local function scanAndPurge(container, tag)
	if not container then return end
	for _,inst in ipairs(container:GetDescendants()) do
		if isKillName(inst.Name) then
			safeDestroy(inst, tag or "scan")
		end
	end
	-- ook directe children
	for _,inst in ipairs(container:GetChildren()) do
		if isKillName(inst.Name) then
			safeDestroy(inst, tag or "scan")
		end
	end
end

-- 1) Eerste sweep zodra PlayerScripts/PlayerGui er zijn
task.defer(function()
	local ps = player:WaitForChild("PlayerScripts", 10)
	local pg = player:WaitForChild("PlayerGui", 10)

	-- Freecam & co in PlayerGui
	scanAndPurge(pg, "PlayerGui initial")

	-- Proxies/Loader/PlayerModule in PlayerScripts
	scanAndPurge(ps, "PlayerScripts initial")

	-- 2) Blijf waken: als er later iets bijkomt, direct weggooien
	if ps then
		ps.ChildAdded:Connect(function(ch)
			if isKillName(ch.Name) then safeDestroy(ch, "PlayerScripts.ChildAdded") end
			-- ook subchildren (soms spawnt PlayerModule CameraModule later)
			ch.DescendantAdded:Connect(function(d)
				if isKillName(d.Name) then safeDestroy(d, "PlayerScripts.DescendantAdded") end
			end)
		end)
		ps.DescendantAdded:Connect(function(d)
			if isKillName(d.Name) then safeDestroy(d, "PlayerScripts.DescendantAdded2") end
		end)
	end

	if pg then
		pg.ChildAdded:Connect(function(ch)
			if isKillName(ch.Name) then safeDestroy(ch, "PlayerGui.ChildAdded") end
			ch.DescendantAdded:Connect(function(d)
				if isKillName(d.Name) then safeDestroy(d, "PlayerGui.DescendantAdded") end
			end)
		end)
		pg.DescendantAdded:Connect(function(d)
			if isKillName(d.Name) then safeDestroy(d, "PlayerGui.DescendantAdded2") end
		end)
	end
end)

-- 3) Camera hard locken op Scriptable (voorkomt Custom push)
local camTypeConn
camTypeConn = cam:GetPropertyChangedSignal("CameraType"):Connect(function()
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		print(("[PurgeCam] Forcing CameraType back to Scriptable (was %s)"):format(tostring(cam.CameraType)))
		cam.CameraType = Enum.CameraType.Scriptable
	end
end)

-- 4) Bij start: alvast netjes zetten
cam.CameraType = Enum.CameraType.Scriptable
cam.CameraSubject = nil

-- 5) Extra failsafe: elke frame even checken of iemand anders schrijft
--    (NIET de camera verplaatsen; enkel type/subject bewaken)
RunService.RenderStepped:Connect(function()
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	if cam.CameraSubject ~= nil then
		-- wij sturen de camera zelf; geen subject
		cam.CameraSubject = nil
	end
end)
