-- PurgeConflicts.client.lua
-- Verwijdert alle bekende "tweede camera-writers" en ruimt conflicterende UI op.
-- Zet dit in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local KILL_NAMES = {
        -- local “proxies” die eerder stotter/dubbel beeld gaven
        ["LocalRenderProxy"]   = true,
        ["LocalRenderProxy.client"] = true,
        ["LocalRiderProxy"]    = true,
        ["LocalRiderProxy.client"]  = true,
        ["PoseHandshake"]      = true,
        ["PoseHandshake.client"]= true,
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
        local pg = player:WaitForChild("PlayerGui", 10)

        -- Freecam & co in PlayerGui
        scanAndPurge(pg, "PlayerGui initial")

        -- 2) Blijf waken: als er later iets bijkomt, direct weggooien
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

-- CameraScript neemt de camera volledig over, dus we hoeven hier niet langer
-- de CurrentCamera te forceren. Het enige wat we doen is de bekende
-- proxy/freecam UI's opruimen zodra ze verschijnen.
