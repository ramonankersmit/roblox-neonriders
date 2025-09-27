-- Verberg ALLE UI behalve LobbyUI zolang RoundActive=false
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local plr = Players.LocalPlayer
local RoundActive = RS:WaitForChild("RoundActive")

local WHITELIST = { LobbyUI = true }  -- alleen deze GUI zichtbaar in lobby

local function apply()
	local inLobby = not RoundActive.Value

	-- Toggle alle ScreenGuis (behalve whitelisted)
	local pg = plr:FindFirstChild("PlayerGui")
	if pg then
		for _,g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") then
				local keep = WHITELIST[g.Name] == true
				g.Enabled = (inLobby and keep) or (not inLobby)
			end
		end
	end

	-- Core GUI’s (playerlist + backpack hotbar) uit in lobby
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not inLobby)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,   not inLobby)
	end)

	-- herbevestig een paar keer in lobby (sommige corescripts togglen terug)
	if inLobby then
		for i=1,5 do
			task.delay(0.2*i, function()
				pcall(function()
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end)
				local pg2 = plr:FindFirstChild("PlayerGui")
				if pg2 then
					for _,g in ipairs(pg2:GetChildren()) do
						if g:IsA("ScreenGui") and WHITELIST[g.Name] ~= true then
							g.Enabled = false
						end
					end
				end
			end)
		end
	end
end

-- init + reageren op wissels/respawns
apply()
RoundActive:GetPropertyChangedSignal("Value"):Connect(apply)
Players.LocalPlayer.CharacterAdded:Connect(function() task.defer(apply) end)
