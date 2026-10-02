--!strict
-- Ghost spawning, wandering, targeting and server-authoritative damage.
--
-- Movement is NOT simulated per frame on the server. Each ghost has a straight wander segment
-- (attributes From, To, T0, Dur in server time); the server evaluates the position only when it
-- needs it (range checks, drops) and every client animates the model locally along the same
-- segment. One loop handles all ghosts, so there is no per-ghost Heartbeat connection.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Rules = require(GH.Logic.Rules)
local Signal = require(GH.Signal)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local DropService = require(script.Parent.DropService)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local GhostService = {}

export type Ghost = {
	Uid: number,
	Def: Config.GhostDef,
	Model: Model,
	Spirit: number,
	Max: number,
	From: Vector3,
	To: Vector3,
	T0: number,
	Dur: number,
	NextMove: number,
	Center: Vector3,
	Radius: number,
	Alive: boolean,
	Event: boolean,
	Area: number?, -- index into Config.Layout.GhostAreas (nil for event ghosts)
	Damage: { [Player]: number },
	DirtySpirit: boolean,
}

local buildHitbox: (Config.GhostDef, Vector3) -> Model
local ghosts: { [number]: Ghost } = {}
local nextUid = 1
local folder: Folder
local rng = Random.new()

-- Ready = os.clock() when damage may start (hunters need time to run over).
-- Auto = picked by the Auto Attack pass (manual picks are never replaced automatically).
type Target = { Uid: number, Ready: number, Auto: boolean }
local targets: { [Player]: Target } = {}

-- Auto Attack toggle (session only, default OFF). Only honoured while the player owns the pass.
local autoOn: { [Player]: boolean } = {}

local zoneRanges: { { number } } = {}
for _, z in Config.Zones do
	table.insert(zoneRanges, { z.MinZ, z.MaxZ })
end

local killedSignal = Signal.new()
GhostService.Killed = killedSignal -- (ghost: Ghost, killer: Player?) by reference

local function now(): number
	return workspace:GetServerTimeNow()
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

function GhostService.Position(g: Ghost, t: number?): Vector3
	local a = if g.Dur > 0 then math.clamp(((t or now()) - g.T0) / g.Dur, 0, 1) else 1
	return g.From:Lerp(g.To, smooth(a))
end

function GhostService.Get(uid: number): Ghost?
	return ghosts[uid]
end

function GhostService.All(): { [number]: Ghost }
	return ghosts
end

local function randomPoint(center: Vector3, radius: number, hover: number): Vector3
	local a = rng:NextNumber() * math.pi * 2
	local r = math.sqrt(rng:NextNumber()) * radius
	return Vector3.new(center.X + math.cos(a) * r, center.Y + hover, center.Z + math.sin(a) * r)
end

-- A random point that keeps clear of the other live ghosts of the same spawn area (first try
-- that leaves `spacing` studs, else the roomiest of a few tries), so ghosts don't stack and
-- each one stays easy to tap.
local SPREAD_TRIES = 5
local function spacedPoint(center: Vector3, radius: number, hover: number, area: number?, self: Ghost?, spacing: number): Vector3
	local best, bestGap = randomPoint(center, radius, hover), -1
	if area == nil then
		return best
	end
	local want = spacing * spacing
	for i = 1, SPREAD_TRIES do
		local p = if i == 1 then best else randomPoint(center, radius, hover)
		local gap = math.huge
		for _, o in ghosts do
			if o ~= self and o.Alive and o.Area == area then
				local q = o.To
				local dx, dz = p.X - q.X, p.Z - q.Z
				gap = math.min(gap, dx * dx + dz * dz)
			end
		end
		if gap >= want then
			return p
		end
		if gap > bestGap then
			best, bestGap = p, gap
		end
	end
	return best
end

local function setSegment(g: Ghost, to: Vector3)
	local t = now()
	local from = GhostService.Position(g, t)
	g.From = from
	g.To = to
	g.T0 = t
	g.Dur = math.max(0.5, (to - from).Magnitude / math.max(g.Def.Speed, 0.1))
	g.NextMove = t + g.Dur + rng:NextNumber(0.4, g.Def.Wander)
	local m = g.Model
	m:SetAttribute("From", g.From)
	m:SetAttribute("To", g.To)
	m:SetAttribute("T0", g.T0)
	m:SetAttribute("Dur", g.Dur)
end

-- The server's ghost is only an invisible, generously sized tap target (Core) with the
-- attachments beams and labels use. Every client builds the visual rig (GhostRig) locally,
-- so a kill/respawn replicates one part instead of a whole model.
function buildHitbox(def: Config.GhostDef, pos: Vector3): Model
	local s = def.Scale
	local model = Instance.new("Model")
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1, 1, 1) * (Config.Combat.HitboxDiameter * s)
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = true
	core.CastShadow = false
	core.CFrame = CFrame.new(pos)
	core.Parent = model
	local attachments: { [string]: number } = { Center = 0, Top = 2.4 * s, Bottom = -2.1 * s }
	for name, y in attachments do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(0, y, 0)
		a.Parent = core
	end
	model.PrimaryPart = core
	return model
end

-- Creates a ghost. `spirit` overrides the config value (event ghost scaling).
export type SpawnOpts = { Spirit: number?, Event: boolean?, Area: number? }

function GhostService.Spawn(def: Config.GhostDef, center: Vector3, radius: number, opts: SpawnOpts?): Ghost
	local o: SpawnOpts = opts or {}
	local uid = nextUid
	nextUid += 1
	local spirit = math.floor(o.Spirit or def.Spirit)
	local pos = spacedPoint(center, radius, def.Hover, o.Area, nil, Config.Combat.HitboxDiameter * def.Scale * 1.4)
	local model = buildHitbox(def, pos)
	model.Name = "Ghost_" .. uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("GhostId", def.Id)
	model:SetAttribute("Spirit", spirit)
	model:SetAttribute("MaxSpirit", spirit)
	model:SetAttribute("Zone", def.Zone)
	model:SetAttribute("Event", o.Event == true)
	local g: Ghost = {
		Uid = uid,
		Def = def,
		Model = model,
		Spirit = spirit,
		Max = spirit,
		From = pos,
		To = pos,
		T0 = now(),
		Dur = 0,
		NextMove = 0,
		Center = center,
		Radius = radius,
		Alive = true,
		Event = o.Event == true,
		Area = o.Area,
		Damage = {},
		DirtySpirit = false,
	}
	ghosts[uid] = g
	setSegment(g, pos)
	g.NextMove = now() + rng:NextNumber(0, def.Wander)
	model.Parent = folder
	return g
end

local function rootPos(player: Player): Vector3?
	local root = Remotes.Root(player)
	return if root then root.Position else nil
end

local function setTarget(player: Player, uid: number?, auto: boolean?)
	local g = uid and ghosts[uid]
	if uid and g then
		-- damage starts once the crew could plausibly have run to the ghost
		local p = rootPos(player)
		local run = if p then (GhostService.Position(g) - p).Magnitude / Config.Combat.HunterRunSpeed else 0
		targets[player] = { Uid = uid, Ready = os.clock() + Config.Combat.EngageDelay + math.min(run, 2), Auto = auto == true }
		player:SetAttribute("Target", uid)
	else
		targets[player] = nil
		player:SetAttribute("Target", 0)
	end
end

function GhostService.AutoActive(player: Player): boolean
	return autoOn[player] == true -- FREE for every player (no pass)
end

-- Auto Attack pick: nearest living ghost the player may fight, in the zone the player is
-- standing in (so hunters never run through zone walls), within Config.AutoAttack.Range.
local function autoCandidate(player: Player): Ghost?
	local d = DataService.Get(player)
	local p = rootPos(player)
	if not d or not p then
		return nil
	end
	local here = Rules.ZoneIndexAt(p.Z, zoneRanges)
	local best, bestDist = nil, Config.AutoAttack.Range
	local t = now()
	for _, g in ghosts do
		local zone = Config.ZoneById[g.Def.Zone]
		if g.Alive and zone and zone.Order == here and d.Zones[zone.Id] then
			local dist = (GhostService.Position(g, t) - p).Magnitude
			if dist < bestDist then
				best, bestDist = g, dist
			end
		end
	end
	return best
end

-- Removes a ghost. reward=false for escapes/cleanup.
function GhostService.Remove(g: Ghost, killer: Player?, reward: boolean)
	if not g.Alive then
		return
	end
	g.Alive = false
	ghosts[g.Uid] = nil
	local pos = GhostService.Position(g)
	g.Model:SetAttribute("Spirit", 0)
	g.Model:SetAttribute("Dead", true)
	Fx.All("Poof", {
		Uid = g.Uid,
		Pos = pos,
		Scale = g.Def.Scale,
		Color = g.Def.Glow,
		Big = g.Def.Kind ~= "Normal",
		Escaped = not reward,
	})
	task.delay(1.2, function()
		g.Model:Destroy()
	end)

	if reward and not g.Event then
		-- helpers get their own drops; the bar to count as a helper drops when many crews pile on
		local helpers = 0
		for player in g.Damage do
			if player.Parent then
				helpers += 1
			end
		end
		local minShare = g.Max * math.min(Config.Combat.ContributorShare, 0.5 / math.max(helpers, 1))
		for player, dmg in g.Damage do
			if player.Parent and (player == killer or dmg >= minShare) then
				local d = DataService.Get(player)
				if d then
					local base = g.Def.Reward -- fixed per ghost type
					local total = math.max(1, math.floor(base * PlayerInfo.EctoMultiplier(player) + 0.5))
					DropService.Spawn(player, pos, total, g.Def.Drops, nil)
					d.Stats.Ghosts += 1
				end
			end
		end
	end
	if reward then
		killedSignal:Fire(g, killer)
	end

	-- Hunters on this ghost come home. Only Auto Attack owners with the toggle ON get a new
	-- ghost picked for them; everyone else chooses their next ghost by clicking/tapping it.
	for player, tg in targets do
		if tg.Uid == g.Uid then
			local nextG = if GhostService.AutoActive(player) then autoCandidate(player) else nil
			setTarget(player, if nextG then nextG.Uid else nil, true)
		end
	end

	if g.Area then
		local area = Config.Layout.GhostAreas[g.Area]
		task.delay(g.Def.Respawn, function()
			GhostService.Spawn(g.Def, area.Center, area.Radius, { Area = g.Area })
		end)
	end
end

local function onSelect(player: Player, uid: any)
	if not Remotes.Allow(player, "SelectTarget") then
		return
	end
	if uid == nil or uid == 0 then
		setTarget(player, nil)
		return
	end
	if type(uid) ~= "number" then
		return
	end
	local g = ghosts[uid]
	local d = DataService.Get(player)
	local p = rootPos(player)
	if not g or not g.Alive or not d or not p then
		return
	end
	if not d.Zones[g.Def.Zone] then
		Fx.Toast(player, "Unlock " .. (Config.ZoneById[g.Def.Zone] :: Config.ZoneDef).Name .. " first!", "Bad")
		return
	end
	if (GhostService.Position(g) - p).Magnitude > Config.Combat.MaxRange + 15 then
		Fx.Toast(player, "Get closer to that ghost!", "Bad")
		return
	end
	local cur = targets[player]
	if cur and cur.Uid == uid then
		cur.Auto = false -- the player chose it: Auto Attack OFF won't drop it
		return
	end
	setTarget(player, uid, false)
end

-- Gives Auto Attack players a ghost whenever their crew is idle.
local function autoTick()
	for player, on in autoOn do
		if on and not targets[player] and player.Parent and GhostService.AutoActive(player) then
			local g = autoCandidate(player)
			if g then
				setTarget(player, g.Uid, true)
			end
		end
	end
end

local function damageTick(dt: number)
	local t = now()
	local clock = os.clock()
	for player, tg in targets do
		local g = ghosts[tg.Uid]
		if not g or not g.Alive or not player.Parent then
			targets[player] = nil
			if player.Parent then
				player:SetAttribute("Target", 0)
			end
			continue
		end
		local p = rootPos(player)
		if not p then
			continue
		end
		local dist = (GhostService.Position(g, t) - p).Magnitude
		if dist > Config.Combat.MaxRange * 1.4 then
			setTarget(player, nil) -- walked away: hunters come home
			continue
		end
		if dist > Config.Combat.MaxRange or clock < tg.Ready then
			continue
		end
		local power = HunterService.CrewPower(player)
		if power <= 0 then
			continue
		end
		local dmg = power * dt
		g.Spirit -= dmg
		g.Damage[player] = (g.Damage[player] or 0) + dmg
		g.DirtySpirit = true
		if g.Spirit <= 0 then
			GhostService.Remove(g, player, true)
		end
	end
	for _, g in ghosts do
		if g.DirtySpirit and g.Alive then
			g.DirtySpirit = false
			g.Model:SetAttribute("Spirit", math.max(0, math.ceil(g.Spirit)))
		end
	end
end

local function moveTick()
	local t = now()
	for _, g in ghosts do
		if g.Alive and t >= g.NextMove then
			setSegment(g, spacedPoint(g.Center, g.Radius, g.Def.Hover, g.Area, g, Config.Combat.HitboxDiameter * g.Def.Scale * 1.4))
		end
	end
end

function GhostService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Ghosts"
	folder.Parent = workspace
	Net.Event("SelectTarget").OnServerEvent:Connect(onSelect)

	-- AUTO ATTACK toggle: FREE for everyone. It only automates picking targets: damage,
	-- rewards and pickups are exactly the same as tapping ghosts yourself.
	Remotes.Register("AutoAttack", "Default", function(player, on)
		if type(on) ~= "boolean" then
			return Remotes.Fail("Bad value")
		end
		if on then
			autoOn[player] = true
		else
			autoOn[player] = nil
		end
		player:SetAttribute("AutoAttack", on)
		if not on then
			-- back to manual: a ghost Auto Attack picked is dropped, one you chose is kept
			local tg = targets[player]
			if tg and tg.Auto then
				setTarget(player, nil)
			end
		end
		return { ok = true, On = on }
	end)
end

function GhostService.Start()
	for i, area in Config.Layout.GhostAreas do
		local def = Config.Ghosts[area.Ghost]
		for _ = 1, area.Count do
			GhostService.Spawn(def, area.Center, area.Radius, { Area = i })
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		targets[player] = nil
		autoOn[player] = nil
		for _, g in ghosts do
			g.Damage[player] = nil
		end
	end)
	task.spawn(function()
		local tick = Config.Combat.TickSeconds
		local last = os.clock()
		local nextAuto = 0
		while true do
			task.wait(tick)
			local c = os.clock()
			-- cap dt so a server hitch can't produce a burst of damage
			local dt = math.min(c - last, tick * 2)
			last = c
			local ok, err = pcall(function()
				damageTick(dt)
				moveTick()
				if c >= nextAuto then
					nextAuto = c + Config.AutoAttack.ScanSeconds
					autoTick()
				end
			end)
			if not ok then
				warn("[Ghosts] tick error: " .. tostring(err))
			end
		end
	end)
end

return GhostService
