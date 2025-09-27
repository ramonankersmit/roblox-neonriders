-- DisableDefaultCamera.client.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer
local ps = lp:WaitForChild("PlayerScripts")

-- Wacht robuust op PlayerModule (max ~3s), dan disable controls.
local function getPlayerModule(timeout)
    -- eerst snelle lookup
    local pm = ps:FindFirstChild("PlayerModule")
    if pm then return pm end

    -- probeer een beperkte WaitForChild (geen infinite yield)
    pm = ps:WaitForChild("PlayerModule", timeout or 3)
    if pm then return pm end

    -- als hij er nog niet is: luister kort op nieuwe children (race-free)
    local found
    local conn
    conn = ps.ChildAdded:Connect(function(child)
        if child.Name == "PlayerModule" then
            found = child
        end
    end)

    -- wacht tot het eind van de frame of 2 seconden, wat eerst komt
    local t0 = os.clock()
    repeat
        RunService.Heartbeat:Wait()
        if found then break end
    until (os.clock() - t0) > 2

    if conn then conn:Disconnect() end
    return found
end

local pm = getPlayerModule(3)
if not pm then
    warn("[DisableDefaultCamera] PlayerModule not found; default controls stay enabled")
    return
end

local ok, playerModule = pcall(require, pm)
if not ok or type(playerModule) ~= "table" or type(playerModule.GetControls) ~= "function" then
    warn("[DisableDefaultCamera] PlayerModule:GetControls unavailable; default controls stay enabled")
    return
end

local ok2, controls = pcall(function() return playerModule:GetControls() end)
if ok2 and controls and type(controls.Disable) == "function" then
    controls:Disable()  -- officiële, ondersteunde manier (i.p.v. modules verwijderen)
    print("[DisableDefaultCamera] Default controls disabled")
else
    warn("[DisableDefaultCamera] Controls module missing; default controls stay enabled")
end
