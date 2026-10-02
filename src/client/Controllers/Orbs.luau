--!strict
-- Ectoplasm orbs (visual only; the server owns values and decides pickups).
--   Drops   → orbs pop out of the poof on an arc, bounce twice, then hover and glow.
--   Pickup  → as soon as an orb is inside your pickup radius it starts accelerating toward you
--             (predicted locally so it feels instant); it is "eaten" when the server confirms
--             the pickup (Collect). Unconfirmed orbs wait at your side briefly, then go back.
-- One RenderStepped loop moves every orb with BulkMoveTo; parts are pooled.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Signal = require(GH.Signal)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Orbs = {}

type Orb = {
	Id: number,
	Part: BasePart,
	Value: number,
	Start: Vector3,
	Land: Vector3,
	T0: number,
	FlyDur: number,
	Phase: string, -- Fly | Rest | Magnet | Held | Fade
	Confirmed: boolean,
	MagnetT0: number,
	MagnetFrom: Vector3,
	HeldT0: number,
	NoPredictUntil: number,
	ExpireAt: number,
	Spin: number,
	Size: number,
	Pos: Vector3,
}

local player = Players.LocalPlayer
local orbs: { [number]: Orb } = {}
local pool: { BasePart } = {}
local folder: Folder
local hidden = CFrame.new(0, -500, 0)
local streak = 0
local lastPickup = 0
local ring: Part
local ringGui: SurfaceGui
local ringStroke: UIStroke
local ringAlpha = 0
local collectedSignal = Signal.new()
Orbs.Collected = collectedSignal -- (amount)

local GREEN = Theme.Ecto
local CYAN = Theme.Ecto2

local function getPart(): BasePart
	local p = table.remove(pool)
	if p then
		p.Transparency = 0.05
		return p
	end
	local b = Instance.new("Part")
	b.Name = "Ecto"
	b.Shape = Enum.PartType.Ball
	b.Material = Enum.Material.Neon
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	b.Transparency = 0.05
	b.CFrame = hidden
	b.Parent = folder
	return b
end

local function release(o: Orb)
	orbs[o.Id] = nil
	o.Part.CFrame = hidden
	if #pool < 300 then
		table.insert(pool, o.Part)
	else
		o.Part:Destroy()
	end
end

local function rootPart(): BasePart?
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function radius(): number
	local d = State.Data
	return if d and d.PickupRadius then d.PickupRadius else Config.Upgrades.PickupRadius.Levels[1]
end

local function spawnDrops(origin: Vector3, list: { any }, removed: { number }?)
	local now = os.clock()
	-- the server retired these (too many uncollected orbs): fade them out like a timeout
	if type(removed) == "table" then
		for _, id in removed do
			local old = orbs[id]
			if old and old.Phase ~= "Magnet" and old.Phase ~= "Held" then
				old.Phase = "Fade"
				old.T0 = now
			end
		end
	end
	for i, item in list do
		local id, land, value = item[1], item[2], item[3]
		if type(id) ~= "number" or typeof(land) ~= "Vector3" or type(value) ~= "number" or orbs[id] then
			continue
		end
		-- size by value relative to your best area (ZoneMultiplier ~ typical income there), so
		-- boss and big drops stand out in every zone instead of all late orbs being max size
		local rel = value / math.max(1, (State.Data and State.Data.ZoneMultiplier) or 1)
		local size = math.clamp(0.9 + 0.35 * math.log10(math.max(1, rel)), 0.9, 1.9)
		local part = getPart()
		part.Size = Vector3.new(size, size, size)
		part.Color = GREEN:Lerp(CYAN, math.random() * 0.6)
		local o: Orb = {
			Id = id,
			Part = part,
			Value = value,
			Start = origin,
			Land = land,
			T0 = now + (i - 1) * 0.025, -- tiny stagger so a burst "sprays"
			FlyDur = 0.45 + math.random() * 0.25,
			Phase = "Fly",
			Confirmed = false,
			MagnetT0 = 0,
			MagnetFrom = origin,
			HeldT0 = 0,
			NoPredictUntil = 0,
			ExpireAt = now + Config.Drops.Lifetime,
			Spin = math.random() * 6.28,
			Size = size,
			Pos = origin,
		}
		orbs[id] = o
	end
	-- ectoplasm splash where the ghost popped
	Effects.Burst(origin, { Color = GREEN, Color2 = CYAN, Count = math.min(6 + #list * 2, 30), Size = 0.7, Speed = 14, Life = 0.5, Gravity = 25 })
	Sound.Play("Drop", 0.1)
end

local function startMagnet(o: Orb)
	if o.Phase == "Magnet" or o.Phase == "Held" or o.Phase == "Fade" then
		return
	end
	o.Phase = "Magnet"
	o.MagnetT0 = os.clock()
	o.MagnetFrom = o.Pos
end

local function eat(o: Orb, at: Vector3)
	local now = os.clock()
	if now - lastPickup < 0.6 then
		streak = math.min(streak + 1, 14)
	else
		streak = 0
	end
	lastPickup = now
	Effects.Burst(at, { Color = o.Part.Color, Count = 5, Size = 0.45, Speed = 6, Life = 0.35 })
	Sound.Play("Pickup", 0.02, 1 + streak * 0.045) -- rising pitch on a pickup streak
	release(o)
	collectedSignal:Fire(o.Value)
end

local function onCollect(ids: { number }, _total: number)
	for _, id in ids do
		local o = orbs[id]
		if o then
			o.Confirmed = true
			if o.Phase == "Held" then
				local r = rootPart()
				eat(o, if r then r.Position else o.Pos)
			else
				startMagnet(o)
			end
		end
	end
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function step(dt: number)
	local now = os.clock()
	local root = rootPart()
	local rpos = if root then root.Position else nil
	local rad = radius()
	local r2 = rad * rad
	local nearCount = 0
	table.clear(parts)
	table.clear(cframes)
	for _, o in orbs do
		local pos: Vector3
		if o.Phase == "Fly" then
			local a = math.clamp((now - o.T0) / o.FlyDur, 0, 1)
			local dist = (o.Land - o.Start).Magnitude
			local arc = (2.5 + dist * 0.35) * 4 * a * (1 - a)
			pos = o.Start:Lerp(o.Land, a) + Vector3.new(0, arc, 0)
			if a >= 1 then
				o.Phase = "Rest"
				o.T0 = now
			end
		elseif o.Phase == "Rest" then
			local b = now - o.T0
			local bounce = 0
			if b < 0.5 then
				local k = b / 0.5
				bounce = math.abs(math.sin(k * math.pi * 2)) * 1.3 * (1 - k)
			end
			pos = o.Land + Vector3.new(0, 0.35 + bounce + math.sin(now * 3 + o.Spin) * 0.22, 0)
			if now >= o.ExpireAt then
				o.Phase = "Fade"
				o.T0 = now
			elseif rpos and now >= o.NoPredictUntil then
				local dx, dz = pos.X - rpos.X, pos.Z - rpos.Z
				if dx * dx + dz * dz <= r2 and math.abs(pos.Y - rpos.Y) < 14 then
					startMagnet(o)
				end
			end
			if rpos and (pos - rpos).Magnitude < rad + 25 then
				nearCount += 1
			end
		elseif o.Phase == "Magnet" then
			local a = math.clamp((now - o.MagnetT0) / Config.Drops.FlyTime, 0, 1)
			local target = if rpos then rpos else o.MagnetFrom
			local e = a * a -- accelerate in
			pos = o.MagnetFrom:Lerp(target, e) + Vector3.new(0, math.sin(a * math.pi) * 2, 0)
			if a >= 1 then
				if o.Confirmed then
					eat(o, target)
					continue
				end
				o.Phase = "Held"
				o.HeldT0 = now
			end
		elseif o.Phase == "Held" then
			pos = if rpos then rpos else o.Pos
			if now - o.HeldT0 > 1.2 then
				-- server didn't agree (moved away too fast?) - send it back to where it was
				o.Phase = "Rest"
				o.T0 = now - 1
				o.NoPredictUntil = now + 1.5
				pos = o.Land
			end
		else -- Fade
			local a = math.clamp((now - o.T0) / 0.4, 0, 1)
			local s = o.Size * (1 - a)
			o.Part.Size = Vector3.new(s, s, s) + Vector3.new(0.05, 0.05, 0.05)
			pos = o.Land + Vector3.new(0, 0.35, 0)
			if a >= 1 then
				release(o)
				continue
			end
		end
		o.Pos = pos
		table.insert(parts, o.Part)
		-- hidden while held at the player (waiting for the server)
		table.insert(cframes, if o.Phase == "Held" then hidden else CFrame.new(pos) * CFrame.Angles(0, now * 2 + o.Spin, 0))
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- pickup radius ring: fades in while orbs are lying around nearby
	local want = if nearCount > 0 and rpos then 1 else 0
	ringAlpha += (want - ringAlpha) * math.min(1, dt * 6)
	if rpos and ringAlpha > 0.02 then
		local d = rad * 2
		if math.abs(ring.Size.X - d) > 0.05 then
			ring.Size = Vector3.new(d, 0.1, d)
			local pps = math.clamp(math.floor(600 / d), 6, 30)
			ringGui.PixelsPerStud = pps
			ringStroke.Thickness = math.max(2, 0.4 * pps)
		end
		ring.CFrame = CFrame.new(rpos.X, rpos.Y - 2.85, rpos.Z)
		ringStroke.Transparency = 1 - 0.55 * ringAlpha
		ringGui.Enabled = true
	elseif ringGui.Enabled then
		ringGui.Enabled = false
		ring.CFrame = hidden
	end
end

function Orbs.Count(): number
	local n = 0
	for _, o in orbs do
		if o.Phase == "Rest" or o.Phase == "Fly" then
			n += 1
		end
	end
	return n
end

function Orbs.Nearest(pos: Vector3): Vector3?
	local best, bestD = nil, math.huge
	for _, o in orbs do
		if o.Phase == "Rest" then
			local d = (o.Pos - pos).Magnitude
			if d < bestD then
				best, bestD = o.Pos, d
			end
		end
	end
	return best
end

function Orbs.Init()
	folder = Instance.new("Folder")
	folder.Name = "GHOrbs"
	folder.Parent = workspace
	ring = Instance.new("Part")
	ring.Name = "PickupRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Size = Vector3.new(28, 0.1, 28)
	ring.CFrame = hidden
	ring.Parent = folder
	ringGui = Kit.new("SurfaceGui", {
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20,
		LightInfluence = 0,
		Brightness = 2,
		Enabled = false,
		Parent = ring,
	})
	local circle: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = ringGui })
	Kit.Corner(circle, UDim.new(1, 0))
	ringStroke = Kit.new("UIStroke", { Thickness = 6, Color = GREEN, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = circle })
end

function Orbs.Start()
	Net.Event("Drops").OnClientEvent:Connect(spawnDrops)
	Net.Event("Collect").OnClientEvent:Connect(onCollect)
	RunService.RenderStepped:Connect(step)
end

return Orbs
