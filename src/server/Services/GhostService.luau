--!strict
-- Ghost spawning, wandering, targeting and server-authoritative damage.
--
-- Movement is NOT simulated per frame on the server. Each ghost has a straight wander segment
-- (one packed string attribute "Seg" = "fx,fy,fz|tx,ty,tz|t0|dur", server time, so each move
-- replicates one attribute instead of four); the server evaluates the position only when it
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
local CrewService = require(script.Parent.CrewService)
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
	-- effective damage per player (health actually removed; overkill never counts). The record
	-- belongs to this one encounter and goes away with the ghost.
	Damage: { [Player]: number },
	DirtySpirit: boolean,
	Tower: any?, -- Boss Tower run that owns this boss (only its members may fight it)
	HitFrac: number?, -- tower bosses: hit = target base max HP (no pet HP bonus) * this
	NextAttack: number, -- os.clock of the next retaliation
	Pending: { Player: Player, Uid: string, Lands: number, Seen: { Player } }?, -- telegraphed hit in flight
	LastKey: string?, -- "userId:uid" hit last (targets rotate)
}

local buildHitbox: (Config.GhostDef, Vector3) -> Model
local ghosts: { [number]: Ghost } = {}
local byArea: { [number]: { Ghost } } = {} -- live ghosts per spawn area (spacedPoint scans only its own area)
local nextUid = 1
local folder: Folder
local rng = Random.new()

-- Ready = os.clock() when damage may start (hunters need time to run over).
-- Auto = picked by Auto Attack (manual picks are never replaced automatically).
type Target = { Uid: number, Ready: number, Auto: boolean }
local targets: { [Player]: Target } = {}

-- Auto Attack toggle (session only, default OFF). Free for every player.
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
	local peers: { Ghost } = byArea[area] or {}
	for i = 1, SPREAD_TRIES do
		local p = if i == 1 then best else randomPoint(center, radius, hover)
		local gap = math.huge
		for _, o in peers do
			if o ~= self and o.Alive then
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
	local f, o = g.From, g.To
	m:SetAttribute("Seg", string.format("%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.3f|%.3f", f.X, f.Y, f.Z, o.X, o.Y, o.Z, g.T0, g.Dur))
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
export type SpawnOpts = { Spirit: number?, Event: boolean?, Area: number?, Tower: any?, HitFrac: number?, Pos: Vector3? }

function GhostService.Spawn(def: Config.GhostDef, center: Vector3, radius: number, opts: SpawnOpts?): Ghost
	local o: SpawnOpts = opts or {}
	local uid = nextUid
	nextUid += 1
	local spirit = math.floor(o.Spirit or def.Spirit)
	local pos = o.Pos or spacedPoint(center, radius, def.Hover, o.Area, nil, Config.Combat.HitboxDiameter * def.Scale * 1.4)
	local model = buildHitbox(def, pos)
	model.Name = "Ghost_" .. uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("GhostId", def.Id)
	model:SetAttribute("Spirit", spirit)
	model:SetAttribute("MaxSpirit", spirit)
	model:SetAttribute("Zone", def.Zone)
	model:SetAttribute("Event", o.Event == true)
	model:SetAttribute("Tower", o.Tower ~= nil)
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
		Tower = o.Tower,
		HitFrac = o.HitFrac,
		NextAttack = 0,
		Pending = nil,
	}
	ghosts[uid] = g
	if o.Area then
		local list = byArea[o.Area]
		if not list then
			list = {}
			byArea[o.Area] = list
		end
		table.insert(list, g)
	end
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
		if g.Alive and not g.Tower and zone and zone.Order == here and d.Zones[zone.Id] then
			local dist = (GhostService.Position(g, t) - p).Magnitude
			if dist < bestDist then
				best, bestDist = g, dist
			end
		end
	end
	return best
end

-- Contribution list for a finished encounter: players still in the server with damage > 0
-- (stable order: biggest damage first, then UserId).
function GhostService.SplitDamage(g: Ghost): { Players: { Player }, Weights: { number }, Total: number }
	local list = {}
	for player, dmg in g.Damage do
		if player.Parent and dmg > 0 then
			table.insert(list, { P = player, D = dmg })
		end
	end
	table.sort(list, function(a, b)
		if a.D ~= b.D then
			return a.D > b.D
		end
		return a.P.UserId < b.P.UserId
	end)
	local out = { Players = {}, Weights = {}, Total = 0 }
	for _, e in list do
		table.insert(out.Players, e.P)
		table.insert(out.Weights, e.D)
		out.Total += e.D
	end
	return out
end

-- Removes a ghost. reward=false for escapes/cleanup.
function GhostService.Remove(g: Ghost, killer: Player?, reward: boolean)
	if not g.Alive then
		return
	end
	g.Alive = false
	ghosts[g.Uid] = nil
	local list = g.Area and byArea[g.Area]
	if list then
		local i = table.find(list, g)
		if i then
			list[i] = list[#list]
			list[#list] = nil
		end
	end
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

	if reward and not g.Event and not g.Tower then
		-- SHARED REWARD: the ghost's reward is one pool, split by each player's share of the
		-- damage (all of their hunters; overkill never counts). Whole units, largest remainder,
		-- so the base pool is always paid out exactly. No last-hit bonus; no damage, no reward.
		-- Each share is then scaled by that player's own Ectoplasm multiplier (upgrades, passes,
		-- boosts, pets, events).
		local shares = GhostService.SplitDamage(g)
		local pool = Rules.SplitPool(g.Def.Reward, shares.Weights)
		for i, player in shares.Players do
			local base = pool[i]
			local d = DataService.Get(player)
			if d and shares.Weights[i] > 0 then
				d.Stats.Ghosts += 1
				-- bosses beaten (kill credit = any share of the damage, so party play counts);
				-- THE GHOST KING opens the World 2 portal (Config.Layout.Portals.ToWorld2.Boss)
				if (g.Def.Kind == "Boss" or g.Def.Kind == "MiniBoss") and not d.BossesBeaten[g.Def.Id] then
					d.BossesBeaten[g.Def.Id] = true
					DataService.Changed(player)
					if g.Def.Id == Config.Layout.Portals.ToWorld2.Boss then
						Fx.To(player, "Announce", { Text = g.Def.Name .. " IS BEATEN! The portal to World 2 can now be opened!", Color = "Legendary" })
					end
				end
				if base > 0 then
					local total = math.max(1, math.floor(base * PlayerInfo.EctoMultiplier(player) + 0.5))
					DropService.Spawn(player, pos, total, g.Def.Drops, nil)
					if #shares.Players > 1 or g.Def.Kind ~= "Normal" then
						Fx.To(player, "Payout", { Name = g.Def.Name, Pct = shares.Weights[i] / shares.Total, Ecto = total })
					end
				end
			end
		end
	end
	if reward then
		killedSignal:Fire(g, killer)
	end

	-- Hunters on this ghost come home. Only players with Auto Attack ON get a new
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
	if g.Tower then
		if not (g.Tower :: any).Members[player] then
			return -- only the party that owns this tower room may fight its boss
		end
	elseif not d.Zones[g.Def.Zone] then
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
		local dmg = Rules.Effective(power * dt, g.Spirit) -- overkill never counts
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

-- Players whose crews are attacking `g` right now (same condition that deals damage).
local function attackers(g: Ghost, t: number, clock: number): { Player }
	local out = {}
	for player, tg in targets do
		if tg.Uid == g.Uid and clock >= tg.Ready and player.Parent then
			local p = rootPos(player)
			if p and (GhostService.Position(g, t) - p).Magnitude <= Config.Combat.MaxRange then
				table.insert(out, player)
			end
		end
	end
	return out
end

-- GHOST RETALIATION: a ghost only fights back against crews attacking it. Every Interval it
-- telegraphs a hit on one hunter of one attacking crew (Fx "GhostWindup"); when the windup ends
-- the hit only lands if that crew is STILL attacking this ghost (retreat or switching target
-- dodges it). Other players and unrelated hunters are never hit.
local function retaliationTick()
	local t = now()
	local clock = os.clock()
	local RC = Config.Retaliation
	for _, g in ghosts do
		if not g.Alive then
			continue
		end
		local pend = g.Pending
		if pend and clock >= pend.Lands then
			g.Pending = nil
			local tg = targets[pend.Player]
			local list = attackers(g, t, clock)
			local still = tg and tg.Uid == g.Uid and table.find(list, pend.Player) ~= nil
			-- everyone fighting this ghost sees the bolt land (or fizzle); damage only if the SAME
			-- hunter is still eligible (never redirected to someone else)
			for _, p in pend.Seen do -- everyone who saw the windup sees the bolt land / fizzle
				if not table.find(list, p) then
					table.insert(list, p)
				end
			end
			if still and table.find(CrewService.Targets(pend.Player), pend.Uid) then
				-- sized from the hunter's HP WITHOUT the pet HP bonus (the HP pool keeps it), so HP
				-- pets always mean more hits to a knockout, in the tower and in the world
				local maxHP = CrewService.BaseMaxHP(pend.Player, pend.Uid)
				local hit
				if g.HitFrac then
					hit = maxHP * g.HitFrac
				else
					local kind = g.Def.Kind
					hit = Rules.RetaliationHit(g.Max, RC.HitPerSpirit[kind] or RC.HitPerSpirit.Normal, maxHP, RC.HitCap[kind] or RC.HitCap.Normal)
				end
				local ko = CrewService.Hit(pend.Player, pend.Uid, hit)
				for _, p in list do
					if p.Parent then
						Fx.To(p, "GhostHit", { Ghost = g.Uid, Hunter = pend.Uid, Owner = pend.Player.UserId, Knocked = ko })
					end
				end
			else
				for _, p in list do
					if p.Parent then
						Fx.To(p, "GhostHit", { Ghost = g.Uid, Hunter = pend.Uid, Owner = pend.Player.UserId, Dodged = true })
					end
				end
			end
		end
		if g.Pending == nil and clock >= g.NextAttack then
			local list = attackers(g, t, clock)
			if #list == 0 then
				g.NextAttack = clock + 0.5 -- passive until someone attacks it
				continue
			end
			-- every eligible hunter of every attacking player; rotate so hits spread out
			local keys: { string } = {}
			local who: { [string]: { P: Player, U: string } } = {}
			for _, p in list do
				for _, uid in CrewService.Targets(p) do
					local key = p.UserId .. ":" .. uid
					table.insert(keys, key)
					who[key] = { P = p, U = uid }
				end
			end
			local key = Rules.NextTarget(keys, g.LastKey)
			if not key then
				g.NextAttack = clock + 0.5
				continue
			end
			local pick = who[key]
			g.LastKey = key
			local interval = if g.Tower then Config.Tower.Interval else RC.Interval
			g.NextAttack = clock + interval -- one attack per interval, whoever the target is
			g.Pending = { Player = pick.P, Uid = pick.U, Lands = clock + RC.Windup, Seen = table.clone(list) }
			for _, p in list do
				Fx.To(p, "GhostWindup", { Ghost = g.Uid, Hunter = pick.U, Owner = pick.P.UserId, Time = RC.Windup })
			end
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
				retaliationTick()
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
