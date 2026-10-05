--!strict
-- THE VOID EMPEROR: World 2's final boss, a server-authoritative team fight in the Void Throne
-- arena (Config.VoidEmperor, rules in Logic/VoidEmperor).
--
-- Flow: Idle -> Open (portal / join window, JoinSeconds) -> Fight -> Idle.
--   * the portal opens every IntervalSeconds, after HeraldKills Void Herald kills on the server,
--     or when GatherPlayers wait in the ring (GatherCooldown after the last fight)
--   * players in the ring (with the Void Throne unlocked) when the window ends set the Spirit:
--     SpiritSeconds * max(sum(min(crew power, PowerCap)), MinCrews * PowerRef)
--   * phase 1 THE CROWN: 4 pylon ghosts (PylonShare each); he takes ShieldTaken while any
--     stands, kneels KneelSeconds (KneelTaken) when all fall; pylons return after
--     PylonReturnSeconds if the 66% wall wasn't reached
--   * phase 2 THE SPLIT: 3 copies circle the arena; only the crowned one takes damage; the crown
--     hops every CrownHopSeconds (CrownTellSeconds warning); picking a copy without the crown
--     "mirrors" that player (no damage for MirrorSeconds); Auto Attack follows the crown
--   * phase 3 THE LAST LIGHT: light circles; the Void Shield is down only while every active
--     circle is held; circles move every CircleMoveSeconds; last FinalShare = one centre circle
--   * TimeLimit: he escapes; participants keep FailShare of their reward
-- Every boss piece is a normal GhostService ghost (Event = true: it pays nothing itself), so
-- tapping, Auto Attack, crews and retaliation work as everywhere else. GhostService calls each
-- piece's Filter with the crew's raw damage; the boss Spirit lives here (one pool shared by the
-- body and the copies) and walls/shields only ever REDUCE damage. Nothing here hurts players.
-- Rewards (once per fight, participants only): Ectoplasm (player's own multiplier) + a free
-- Void Crate open on a win. No Spirit Shards (Boss Tower only), nothing bought changes the fight.
--
-- Clients read workspace attributes VE* (state for late joiners) and Fx "VoidEmperor" moments
-- (VoidEmperorHud). Player attributes: VEMirror (server time it ends), VEShare (damage share).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local VER = require(GH.Logic.VoidEmperor)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local GhostService = require(script.Parent.GhostService)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local VoidEmperorService = {}

local C = Config.VoidEmperor
local TICK = 0.2
local ORBIT_SPEED = 0.05 -- rad/s the copies circle the arena (slow: easy to tap on a phone)
local ORBIT_STEP = 2 -- seconds between copy move orders
local KNEEL_DROP = 10 -- studs he sinks while kneeling
local DEV_SPIRIT_SECONDS = 60 -- dev test fights: ~1 min of the dev's own crew (no rewards)

type Ghost = GhostService.Ghost

type Fight = {
	Id: number,
	Dev: boolean,
	Phase: number,
	Max: number,
	Hp: number,
	EndsAt: number,
	Body: Ghost,
	Copies: { Ghost }, -- phase 2 (Copies[1] is the body)
	Crown: number,
	NextCrown: number,
	NextHop: number,
	Told: boolean,
	LostCrownAt: { [number]: number }, -- copy uid -> server time it lost the crown
	OrbitAt: number,
	Pylons: { Ghost },
	PylonsUp: number,
	PylonsDownAt: number?,
	KneelEnds: number,
	Circles: { BasePart },
	CircleBase: { Vector3 }, -- offsets from the arena centre (ground level)
	CircleY: number,
	Moves: number,
	NextMove: number,
	Final: boolean,
	ShieldDown: boolean,
	Dealt: { [Player]: number }, -- effective damage (boss Spirit + pylons)
	Mirror: { [Player]: number }, -- server time the mirror ends
	LastTarget: { [Player]: number },
	Done: boolean,
	Folder: Folder,
}

local state: string = "Idle" -- Idle | Open | Fight
local fight: Fight? = nil
local openEnds = 0
local nextAt = 0 -- scheduled opening (server time)
local lastEnd = -math.huge
local heraldKills = 0
local fightId = 0
local devOpen = false -- the current join window was opened from the DEV panel
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setAttr(name: string, v: any)
	if workspace:GetAttribute(name) ~= v then
		workspace:SetAttribute(name, v)
	end
end

--------------------------------------------------------------------------------
-- Arena helpers
--------------------------------------------------------------------------------
local function rootOf(player: Player): BasePart?
	local root = Remotes.Root(player)
	if root then
		local hum = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			return nil
		end
	end
	return root
end

local function inRing(pos: Vector3): boolean
	local d = pos - C.Center
	return Vector3.new(d.X, 0, d.Z).Magnitude <= C.Radius and math.abs(d.Y) <= 40
end

-- Players standing in the arena who can fight (Void Throne unlocked).
local function challengers(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		local d = DataService.Get(p)
		local root = rootOf(p)
		if d and d.Zones[C.Zone] and root and inRing(root.Position) then
			table.insert(out, p)
		end
	end
	return out
end

-- Map marker parts (VoidPylonSpot1..4 / VoidLightSpot1..4, built by the Void Throne map).
local function spot(name: string): Instance?
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local zone = map:FindFirstChild(C.Zone)
	local found = (zone and zone:FindFirstChild(name, true)) or map:FindFirstChild(name, true)
	return if found and found:IsA("PVInstance") then found else nil
end

local function ring(i: number, count: number, radius: number): Vector3
	local a = VER.CircleAngle(math.pi / 4, i, count, 0)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

local function pylonSpots(): { Vector3 }
	local out = {}
	for i = 1, 4 do
		local s = spot("VoidPylonSpot" .. i)
		local p = if s then (s :: PVInstance):GetPivot().Position else C.Center + ring(i, 4, C.PylonRadius)
		table.insert(out, Vector3.new(p.X, C.Center.Y, p.Z))
	end
	return out
end

-- Light circle base offsets (from the centre) and the ground height they sit on.
local function lightSpots(): ({ Vector3 }, number)
	local out = {}
	local y = C.Center.Y
	for i = 1, C.Circles do
		local s = spot("VoidLightSpot" .. i)
		if s then
			local pos = (s :: PVInstance):GetPivot().Position
			if s:IsA("BasePart") then
				y = math.max(y, pos.Y + s.Size.Y / 2)
			end
			table.insert(out, Vector3.new(pos.X - C.Center.X, 0, pos.Z - C.Center.Z))
		else
			table.insert(out, ring(i, C.Circles, C.LightRadius))
		end
	end
	return out, y
end

--------------------------------------------------------------------------------
-- Boss pieces
--------------------------------------------------------------------------------
local function sinceCrownLost(f: Fight, uid: number, t: number): number
	local lost = f.LostCrownAt[uid]
	return if lost then t - lost else math.huge
end

local function syncSpirit(f: Fight)
	local hp = math.max(0, f.Hp)
	for _, g in { f.Body, table.unpack(f.Copies) } do
		if g.Alive then
			g.Spirit = hp
		end
	end
end

local function bossFilter(f: Fight, g: Ghost): (Player, number) -> number
	return function(player: Player, raw: number): number
		if f.Done or fight ~= f then
			return 0
		end
		local t = now()
		local mult = VER.Taken({
			Phase = f.Phase,
			PylonsUp = f.PylonsUp,
			Kneeling = t < f.KneelEnds,
			Crowned = f.Phase ~= 2 or f.Copies[f.Crown] == g,
			ShieldDown = f.ShieldDown,
			Mirrored = (f.Mirror[player] or 0) > t,
		}, C.ShieldTaken, C.KneelTaken)
		local hit = VER.Apply(f.Hp, f.Max, raw, mult, VER.Floor(f.Phase, C.Walls))
		if hit > 0 then
			f.Hp -= hit
			f.Dealt[player] = (f.Dealt[player] or 0) + hit
			syncSpirit(f)
		end
		return 0 -- the pool above is the boss's Spirit; GhostService only shows it
	end
end

local function pylonFilter(f: Fight, g: Ghost): (Player, number) -> number
	return function(player: Player, raw: number): number
		if f.Done or fight ~= f or (f.Mirror[player] or 0) > now() then
			return 0
		end
		local hit = math.min(raw, g.Spirit)
		if hit == hit and hit > 0 then
			f.Dealt[player] = (f.Dealt[player] or 0) + hit
		end
		return raw
	end
end

local function spawnPiece(def: Config.GhostDef, center: Vector3, radius: number, spirit: number): Ghost
	return GhostService.Spawn(def, center, radius, { Spirit = spirit, Event = true })
end

local function removePiece(g: Ghost)
	if g.Alive then
		local ok, err = pcall(function()
			GhostService.Remove(g, nil, false)
		end)
		if not ok then
			warn("[VoidEmperor] remove failed: " .. tostring(err))
		end
	end
end

local function moveTo(g: Ghost, center: Vector3, radius: number)
	g.Center = center
	g.Radius = radius
	g.NextMove = 0 -- GhostService's mover picks a new segment on its next tick
end

local function spawnPylons(f: Fight)
	local def = Config.Ghosts[C.Pylon]
	f.Pylons = {}
	for _, p in pylonSpots() do
		local g = spawnPiece(def, p, 1, math.max(1, f.Max * C.PylonShare))
		g.Filter = pylonFilter(f, g)
		table.insert(f.Pylons, g)
	end
	f.PylonsUp = #f.Pylons
	f.PylonsDownAt = nil
end

local function crownedUid(f: Fight): number
	local g = f.Copies[f.Crown]
	return if g then g.Uid else 0
end

-- Auto Attack follows the crown: crews auto-picked onto a copy that lost it move over.
local function moveAutoTargets(f: Fight)
	local crown = f.Copies[f.Crown]
	if not crown then
		return
	end
	for _, p in Players:GetPlayers() do
		local t = p:GetAttribute("Target")
		for i, g in f.Copies do
			if i ~= f.Crown and t == g.Uid then
				GhostService.MoveAutoTarget(p, crown.Uid)
			end
		end
	end
end

local function setCrown(f: Fight, idx: number)
	local t = now()
	local old = f.Copies[f.Crown]
	if old and f.Crown ~= idx then
		f.LostCrownAt[old.Uid] = t
	end
	f.Crown = idx
	for i, g in f.Copies do
		g.NoAuto = i ~= idx
	end
	f.NextHop = t + C.CrownHopSeconds
	f.Told = false
	setAttr("VECrown", crownedUid(f))
	setAttr("VECrownNext", 0)
	moveAutoTargets(f)
end

--------------------------------------------------------------------------------
-- Phases
--------------------------------------------------------------------------------
local function enterPhase2(f: Fight)
	f.Phase = 2
	for _, g in f.Pylons do
		removePiece(g)
	end
	f.Pylons = {}
	f.PylonsUp = 0
	f.PylonsDownAt = nil
	f.KneelEnds = 0
	local def = Config.Ghosts[C.Ghost]
	f.Copies = { f.Body }
	for i = 2, C.Copies do
		local a = (i - 1) * 2 * math.pi / C.Copies
		local pos = C.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * C.CopyOrbit
		local g = spawnPiece(def, pos, 1, f.Max)
		g.Filter = bossFilter(f, g)
		g.NoAuto = true
		table.insert(f.Copies, g)
	end
	syncSpirit(f)
	for _, g in f.Copies do
		g.Model:SetAttribute("Spirit", math.ceil(f.Hp))
	end
	f.LostCrownAt = {}
	-- copies that never wore the crown count as "lost it long ago" (picking one is a mistake)
	for i, g in f.Copies do
		if i ~= 1 then
			f.LostCrownAt[g.Uid] = -math.huge
		end
	end
	f.Crown = 1
	setCrown(f, 1)
	f.OrbitAt = 0
	Fx.All("VoidEmperor", { Kind = "Phase", Phase = 2 })
end

local function placeCircles(f: Fight)
	local count = #f.Circles
	local turn = VER.CircleAngle(0, 1, count, f.Moves)
	local rot = CFrame.Angles(0, -turn, 0)
	for i, part in f.Circles do
		local off = if f.Final then Vector3.zero else rot * f.CircleBase[i]
		local r = if f.Final then C.FinalRadius else C.CircleRadius
		part.Size = Vector3.new(0.2, r * 2, r * 2)
		part.CFrame = CFrame.new(C.Center.X + off.X, f.CircleY + 0.12, C.Center.Z + off.Z) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

local function enterPhase3(f: Fight)
	f.Phase = 3
	for i, g in f.Copies do
		if i ~= 1 then
			removePiece(g)
		end
	end
	f.Copies = {}
	f.Body.NoAuto = false
	moveTo(f.Body, C.Center, 2)
	setAttr("VECrown", 0)
	setAttr("VECrownNext", 0)
	local base, y = lightSpots()
	f.CircleBase = base
	f.CircleY = y
	f.Circles = {}
	for i = 1, #base do
		local part = Instance.new("Part")
		part.Name = "LightCircle" .. i
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(255, 250, 225)
		part.Transparency = 0.45
		part.Parent = f.Folder
		table.insert(f.Circles, part)
	end
	f.Moves = 0
	f.NextMove = now() + C.CircleMoveSeconds
	placeCircles(f)
	Fx.All("VoidEmperor", { Kind = "Phase", Phase = 3 })
end

--------------------------------------------------------------------------------
-- Rewards (once per fight)
--------------------------------------------------------------------------------
local function pay(f: Fight, won: boolean)
	local list: { { P: Player, D: number } } = {}
	local total = 0
	for p, dealt in f.Dealt do
		if p.Parent and DataService.Get(p) and VER.IsParticipant(dealt, f.Max, HunterService.CrewPower(p), C.MinContribution, C.MinSeconds) then
			table.insert(list, { P = p, D = dealt })
			total += dealt
		elseif p.Parent and dealt > 0 then
			Fx.To(p, "VoidEmperor", { Kind = "Reward", Won = won, Ecto = 0, Pct = 0, Small = true, Dev = f.Dev })
		end
	end
	table.sort(list, function(a, b)
		if a.D ~= b.D then
			return a.D > b.D
		end
		return a.P.UserId < b.P.UserId
	end)
	local weights = {}
	for _, e in list do
		table.insert(weights, e.D)
	end
	local zoneMult = Config.Daily.ZoneMultiplier[C.RewardZone] or 1
	local bases = VER.Rewards(weights, C.RewardBase, zoneMult, C.MinShare, C.MaxShare, won, C.FailShare)
	for i, e in list do
		local p = e.P
		local d = DataService.Get(p)
		if not d then
			continue
		end
		local pct = if total > 0 then e.D / total else 0
		if f.Dev then
			Fx.To(p, "VoidEmperor", { Kind = "Reward", Won = won, Ecto = 0, Pct = pct, Dev = true })
			continue
		end
		local base = bases[i] or 0
		local ecto = if base > 0 then math.max(1, math.floor(base * PlayerInfo.EctoMultiplier(p) + 0.5)) else 0
		if ecto > 0 then
			DataService.AddEcto(p, ecto)
		end
		d.Stats.Events += 1
		local first = false
		if won then
			d.FreeCrates[C.Crate] = (d.FreeCrates[C.Crate] or 0) + 1
			local rec = d.EventPlay[C.Record]
			if not rec then
				rec = { S = 0, G = false }
				d.EventPlay[C.Record] = rec
			end
			first = not rec.G
			rec.S += 1 -- wins
			rec.G = true -- beaten at least once (the earned-only "Emperor's Bane" record)
		end
		DataService.Changed(p)
		DataService.Save(p)
		Fx.To(p, "VoidEmperor", { Kind = "Reward", Won = won, Ecto = ecto, Pct = pct, Crate = won, First = first })
	end
end

--------------------------------------------------------------------------------
-- Fight lifecycle
--------------------------------------------------------------------------------
local function clearAttrs()
	for _, n in { "VEPhase", "VEHp", "VEMax", "VEPylons", "VEKneel", "VECrown", "VECrownNext", "VEHopAt", "VENeed", "VEHeld", "VEShield", "VEFinal", "VEBody", "VEDev" } do
		workspace:SetAttribute(n, nil)
	end
	for _, p in Players:GetPlayers() do
		p:SetAttribute("VEMirror", nil)
		p:SetAttribute("VEShare", nil)
	end
end

local function toIdle()
	state = "Idle"
	fight = nil
	devOpen = false
	lastEnd = now()
	nextAt = lastEnd + C.IntervalSeconds
	heraldKills = 0
	clearAttrs()
	setAttr("VEState", "Idle")
	setAttr("VEAt", nextAt)
end

local function finish(f: Fight, won: boolean)
	if f.Done then
		return
	end
	f.Done = true -- from here every filter returns 0 and nothing pays twice
	for _, g in f.Pylons do
		removePiece(g)
	end
	for _, g in f.Copies do
		removePiece(g)
	end
	removePiece(f.Body)
	pcall(function()
		f.Folder:Destroy()
	end)
	local ok, err = pcall(function()
		pay(f, won)
	end)
	if not ok then
		warn("[VoidEmperor] payout error: " .. tostring(err))
	end
	Fx.All("VoidEmperor", { Kind = if won then "Won" else "Failed", Dev = f.Dev })
	toIdle()
end

local function startFight(joined: { Player }, dev: boolean)
	local powers = {}
	for _, p in joined do
		table.insert(powers, HunterService.CrewPower(p))
	end
	local spirit
	if dev then
		local sum = 0
		for _, pw in powers do
			sum += math.max(0, pw)
		end
		spirit = math.max(1000, math.floor(DEV_SPIRIT_SECONDS * sum))
	else
		spirit = VER.Spirit(powers, C.SpiritSeconds, C.MinCrews, C.PowerRef, C.PowerCap)
	end
	fightId += 1
	local folder = Instance.new("Folder")
	folder.Name = "VoidEmperorFight"
	folder.Parent = workspace
	local body = spawnPiece(Config.Ghosts[C.Ghost], C.Center, 2, spirit)
	local f: Fight = {
		Id = fightId,
		Dev = dev,
		Phase = 1,
		Max = spirit,
		Hp = spirit,
		EndsAt = now() + C.TimeLimit,
		Body = body,
		Copies = {},
		Crown = 1,
		NextCrown = 1,
		NextHop = 0,
		Told = false,
		LostCrownAt = {},
		OrbitAt = 0,
		Pylons = {},
		PylonsUp = 0,
		PylonsDownAt = nil,
		KneelEnds = 0,
		Circles = {},
		CircleBase = {},
		CircleY = C.Center.Y,
		Moves = 0,
		NextMove = 0,
		Final = false,
		ShieldDown = false,
		Dealt = {},
		Mirror = {},
		LastTarget = {},
		Done = false,
		Folder = folder,
	}
	body.Filter = bossFilter(f, body)
	fight = f
	state = "Fight"
	spawnPylons(f)
	setAttr("VEState", "Fight")
	setAttr("VEAt", f.EndsAt)
	setAttr("VEMax", f.Max)
	setAttr("VEHp", f.Hp)
	setAttr("VEPhase", 1)
	setAttr("VEBody", body.Uid)
	setAttr("VEDev", dev)
	Fx.All("VoidEmperor", { Kind = "Start", Players = #joined, Dev = dev, EndsAt = f.EndsAt })
end

local function openPortal(dev: boolean)
	state = "Open"
	devOpen = dev
	openEnds = now() + (if dev then 0 else C.JoinSeconds)
	setAttr("VEState", "Open")
	setAttr("VEAt", openEnds)
	if not dev then
		Fx.All("VoidEmperor", { Kind = "Open", At = openEnds })
	end
end

local function closeWindow()
	local joined = challengers()
	if #joined == 0 then
		Fx.All("VoidEmperor", { Kind = "Closed" })
		toIdle()
		return
	end
	startFight(joined, devOpen)
end

local function tickFight(f: Fight)
	local t = now()
	if #Players:GetPlayers() == 0 then
		finish(f, false)
		return
	end
	-- won?
	if f.Hp <= 0 or not f.Body.Alive then
		finish(f, f.Hp <= 0)
		return
	end
	if t >= f.EndsAt then
		finish(f, false)
		return
	end

	-- mirror: a fresh pick of a copy without the crown (phase 2)
	for _, p in Players:GetPlayers() do
		local tg = p:GetAttribute("Target")
		local uid = if type(tg) == "number" then tg else 0
		if f.LastTarget[p] ~= uid then
			f.LastTarget[p] = uid
			if f.Phase == 2 and uid ~= 0 then
				for i, g in f.Copies do
					if g.Uid == uid and VER.Mistake(i == f.Crown, sinceCrownLost(f, uid, t), C.MirrorGrace) then
						f.Mirror[p] = t + C.MirrorSeconds
						p:SetAttribute("VEMirror", f.Mirror[p])
						Fx.To(p, "VoidEmperor", { Kind = "Mirror", Until = f.Mirror[p] })
					end
				end
			end
		end
	end

	if f.Phase == 1 then
		local up = 0
		for _, g in f.Pylons do
			if g.Alive then
				up += 1
			end
		end
		if up == 0 and f.PylonsUp > 0 then
			f.PylonsDownAt = t
			f.KneelEnds = t + C.KneelSeconds
			moveTo(f.Body, C.Center - Vector3.new(0, KNEEL_DROP, 0), 1)
			Fx.All("VoidEmperor", { Kind = "Kneel", Until = f.KneelEnds })
		end
		f.PylonsUp = up
		if f.KneelEnds > 0 and t >= f.KneelEnds and f.Body.Center ~= C.Center then
			moveTo(f.Body, C.Center, 2)
		end
		local downAt = f.PylonsDownAt
		if up == 0 and downAt and t >= downAt + C.PylonReturnSeconds then
			spawnPylons(f)
			Fx.All("VoidEmperor", { Kind = "PylonsBack" })
		end
		if VER.Advance(1, f.Hp, f.Max, C.Walls, up) == 2 then
			enterPhase2(f)
		end
	elseif f.Phase == 2 then
		if not f.Told and t >= f.NextHop - C.CrownTellSeconds then
			f.Told = true
			f.NextCrown = VER.NextCrown(f.Crown, #f.Copies, rng:NextNumber())
			local nextG = f.Copies[f.NextCrown]
			setAttr("VECrownNext", if nextG then nextG.Uid else 0)
			Fx.All("VoidEmperor", { Kind = "CrownTell", Uid = if nextG then nextG.Uid else 0, At = f.NextHop })
		end
		if t >= f.NextHop then
			setCrown(f, f.NextCrown)
		end
		if t >= f.OrbitAt then
			f.OrbitAt = t + ORBIT_STEP
			local base = t * ORBIT_SPEED
			for i, g in f.Copies do
				local a = base + (i - 1) * 2 * math.pi / #f.Copies
				moveTo(g, C.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * C.CopyOrbit, 1)
			end
		end
		if VER.Advance(2, f.Hp, f.Max, C.Walls, 0) == 3 then
			enterPhase3(f)
		end
	elseif f.Phase == 3 then
		if not f.Final and VER.Final(f.Hp, f.Max, C.FinalShare) then
			f.Final = true
			placeCircles(f)
			Fx.All("VoidEmperor", { Kind = "Roar" })
		elseif not f.Final and t >= f.NextMove then
			f.Moves += 1
			f.NextMove = t + C.CircleMoveSeconds
			placeCircles(f)
			Fx.All("VoidEmperor", { Kind = "CirclesMove" })
		end
		local here = challengers()
		local need = if f.Final then 1 else math.min(#f.Circles, VER.ActiveCircles(#here, C.Circles))
		local held: { boolean } = {}
		for i = 1, need do
			local part = f.Circles[i]
			local r = part.Size.Y / 2
			held[i] = false
			for _, p in here do
				local root = rootOf(p)
				if root then
					local d = root.Position - part.Position
					if Vector3.new(d.X, 0, d.Z).Magnitude <= r and math.abs(d.Y) <= 12 then
						held[i] = true
						break
					end
				end
			end
		end
		f.ShieldDown = VER.ShieldDown(held, need)
		local count = 0
		for i, part in f.Circles do
			local active = i <= need
			if held[i] then
				count += 1
			end
			part.Transparency = if active then (if held[i] then 0.3 else 0.5) else 1
			part.Color = if held[i] then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(255, 250, 225)
		end
		setAttr("VENeed", need)
		setAttr("VEHeld", count)
		setAttr("VEShield", not f.ShieldDown)
		setAttr("VEFinal", f.Final)
	end

	-- shared state for the HUD
	setAttr("VEPhase", f.Phase)
	setAttr("VEHp", math.max(0, math.ceil(f.Hp)))
	setAttr("VEPylons", f.PylonsUp)
	setAttr("VEKneel", if t < f.KneelEnds then f.KneelEnds else 0)
	setAttr("VEHopAt", if f.Phase == 2 then f.NextHop else 0)
	for _, g in { f.Body, table.unpack(f.Copies) } do
		if g.Alive and g.Model:GetAttribute("Spirit") ~= math.ceil(math.max(0, f.Hp)) then
			g.Model:SetAttribute("Spirit", math.ceil(math.max(0, f.Hp)))
		end
	end
	local total = 0
	for _, dealt in f.Dealt do
		total += dealt
	end
	for p, dealt in f.Dealt do
		if p.Parent then
			local share = if total > 0 then math.floor(dealt / total * 100 + 0.5) / 100 else 0
			if p:GetAttribute("VEShare") ~= share then
				p:SetAttribute("VEShare", share)
			end
		end
	end
end

local nextScan = 0
local function tick()
	local t = now()
	if state == "Idle" then
		if os.clock() < nextScan then
			return
		end
		nextScan = os.clock() + 1
		if #Players:GetPlayers() == 0 then
			return
		end
		local waiting = #challengers()
		if VER.ShouldOpen({
			Now = t,
			NextAt = nextAt,
			HeraldKills = heraldKills,
			HeraldNeed = C.HeraldKills,
			Waiting = waiting,
			GatherNeed = C.GatherPlayers,
			LastEnd = lastEnd,
			GatherCooldown = C.GatherCooldown,
		}) then
			openPortal(false)
		end
	elseif state == "Open" then
		if t >= openEnds then
			closeWindow()
		end
	elseif state == "Fight" then
		local f = fight
		if f then
			tickFight(f)
		else
			toIdle()
		end
	end
end

--------------------------------------------------------------------------------
-- DEV: start a fight right now (no rewards). DevService already checked dev status.
--------------------------------------------------------------------------------
function VoidEmperorService.DevStart(player: Player): string?
	if state ~= "Idle" then
		return if state == "Open" then "The portal is already open: the fight starts soon" else "The Void Emperor fight is already running"
	end
	local d = DataService.Get(player)
	if not d then
		return "Loading..."
	end
	if not d.Zones[C.Zone] then
		return "Unlock the Void Throne first (UNLOCK ALL AREAS)"
	end
	local root = rootOf(player)
	if not root then
		return "Spawn first"
	end
	if not inRing(root.Position) then
		local char = player.Character
		if char then
			char:PivotTo(CFrame.lookAt(C.Center + Vector3.new(0, 4, C.Radius - 14), C.Center + Vector3.new(0, 4, 0)))
		end
		task.wait(0.3)
	end
	if state ~= "Idle" then
		return "The Void Emperor is already awake"
	end
	openPortal(true)
	closeWindow()
	if (state :: string) ~= "Fight" then
		return "Couldn't start (stand inside the arena)"
	end
	return nil
end

function VoidEmperorService.State(): string
	return state
end

function VoidEmperorService.Init()
	nextAt = now() + C.FirstDelay
	setAttr("VEState", "Idle")
	setAttr("VEAt", nextAt)
	workspace:SetAttribute("VECenter", C.Center)
	workspace:SetAttribute("VERadius", C.Radius)
end

function VoidEmperorService.Start()
	GhostService.Killed:Connect(function(g: Ghost, _killer: Player?)
		if g.Def.Id == "VoidHerald" and state == "Idle" then
			heraldKills += 1
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local f = fight
		if f then
			f.Dealt[player] = nil
			f.Mirror[player] = nil
			f.LastTarget[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				warn("[VoidEmperor] tick error: " .. tostring(err))
				local f = fight
				pcall(function()
					if f then
						finish(f, false)
					else
						toIdle()
					end
				end)
				if fight == f and f then
					-- finish itself failed: never leave the boss system stuck (or a boss behind)
					f.Done = true
					for _, g in { f.Body, table.unpack(f.Copies) } do
						removePiece(g)
					end
					for _, g in f.Pylons do
						removePiece(g)
					end
					pcall(function()
						f.Folder:Destroy()
					end)
					toIdle()
				end
			end
		end
	end)
end

return VoidEmperorService
