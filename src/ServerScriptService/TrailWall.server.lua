-- File: ServerScriptService/TrailWall.server.lua
-- Bouwt een "Tron-muur" achter elk voertuig met een (Vehicle)Seat zodra iemand instapt.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Tune
local WALL_HEIGHT       = 10
local WALL_THICKNESS    = 1
local MIN_SEG_LEN       = 6        -- elke ~6 studs een segment
local COLOR             = Color3.fromRGB(0, 255, 255)

-- Per bestuurder: {model=Model, seat=Seat, lastPos=Vector3, baseY=number}
local active = {}

local function getModelFromSeat(seat: Instance): Model?
	if not seat then return nil end
	local m = seat:FindFirstAncestorOfClass("Model")
	if not m then return nil end
	if not m.PrimaryPart then
		-- kies eerste BasePart als PrimaryPart
		for _,d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then m.PrimaryPart = d; break end
		end
	end
	return m
end

local function createSegment(p0: Vector3, p1: Vector3, baseY: number)
	-- Center + lengte over XZ; hou Y vast (muur op vaste hoogte)
	local mid = Vector3.new( (p0.X+p1.X)/2, baseY + WALL_HEIGHT/2, (p0.Z+p1.Z)/2 )
	local lookAt = Vector3.new(p1.X, mid.Y, p1.Z)
	local len = (Vector3.new(p1.X, 0, p1.Z) - Vector3.new(p0.X, 0, p0.Z)).Magnitude
	if len < 0.001 then return end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Neon
	part.Color = COLOR
	part.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, len)
	part.CFrame = CFrame.lookAt(mid, lookAt)  -- Z-as = lengte langs rijrichting. :contentReference[oaicite:1]{index=1}
	part.Name = "LightWall"
	part.Parent = workspace
end

-- start/stop bij zitten
local function attachSeat(seat: Seat)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if hum and hum.Parent then
			local plr = Players:GetPlayerFromCharacter(hum.Parent)
			local model = getModelFromSeat(seat)
			if not (plr and model and model.PrimaryPart) then return end

			-- muur-basishoogte: onderkant seat (muur "uit de vloer")
			local baseY = (seat.Position.Y - seat.Size.Y/2)

			active[plr] = {
				model = model,
				seat  = seat,
				lastPos = Vector3.new(model.PrimaryPart.Position.X, 0, model.PrimaryPart.Position.Z),
				baseY = baseY
			}
		else
			-- stop muur
			for plr, rec in pairs(active) do
				if rec.seat == seat then active[plr] = nil end
			end
		end
	end)
end

-- hook alle bestaande en toekomstige seats
for _,inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("Seat") then attachSeat(inst) end
end
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Seat") then attachSeat(inst) end
end)

-- teken muur-segmenten
RunService.Heartbeat:Connect(function()
	for plr, rec in pairs(active) do
		local model = rec.model
		if not (model and model.PrimaryPart and rec.seat.Parent) then
			active[plr] = nil
		else
			local cur = Vector3.new(model.PrimaryPart.Position.X, 0, model.PrimaryPart.Position.Z)
			if (cur - rec.lastPos).Magnitude >= MIN_SEG_LEN then
				createSegment(rec.lastPos, cur, rec.baseY)
				rec.lastPos = cur
			end
		end
	end
end)
