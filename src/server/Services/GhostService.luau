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
local GhostRig = require(GH.Rigs.GhostRig)
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

local ghosts: { [number]: Ghost } = {}
local nextUid = 1
local folder: Folder
local rng = Random.new()

-- Ready = os.clock() when damage may start (hunters need time to run over).
type Target = { Uid: number, Ready: number }
local targets: { [Player]: Target } = {}

local killedSignal = Instance.new("BindableEvent")
GhostService.Killed = killedSignal.Event -- (ghost: Ghost, killer: Player?)

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

-- Creates a ghost. `spirit` overrides the config value (event ghost scaling).
export type SpawnOpts = { Spirit: number?, Event: boolean?, Area: number? }

function GhostService.Spawn(def: Config.GhostDef, center: Vector3, radius: number, opts: SpawnOpts?): Ghost
	local o: SpawnOpts = opts or {}
	local uid = nextUid
	nextUid += 1
	local spirit = math.floor(o.Spirit or def.Spirit)
	local pos = randomPoint(center, radius, def.Hover)
	local model = GhostRig.Build(def.Id)
	model.Name = "Ghost_" .. uid
	model:PivotTo(CFrame.new(pos))
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

local function setTarget(player: Player, uid: number?)
	local g = uid and ghosts[uid]
	if uid and g then
		-- damage starts once the crew could plausibly have run to the ghost
		local p = rootPos(player)
		local run = if p then (GhostService.Position(g) - p).Magnitude / Config.Combat.HunterRunSpeed else 0
		targets[player] = { Uid = uid, Ready = os.clock() + Config.Combat.EngageDelay + math.min(run, 2) }
		player:SetAttribute("Target", uid)
	else
		targets[player] = nil
		player:SetAttribute("Target", 0)
	end
end

-- Nearest living, non-event ghost in an unlocked zone within `range` of the player.
local function nearestFor(player: Player, range: number): Ghost?
	local d = DataService.Get(player)
	local p = rootPos(player)
	if not d or not p then
		return nil
	end
	local best, bestDist = nil, range
	local t = now()
	for _, g in ghosts do
		if g.Alive and not g.Event and d.Zones[g.Def.Zone] then
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
		local minShare = g.Max * Config.Combat.ContributorShare
		for player, dmg in g.Damage do
			if player.Parent and (player == killer or dmg >= minShare) then
				local d = DataService.Get(player)
				if d then
					local base = rng:NextInteger(g.Def.Reward[1], g.Def.Reward[2])
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

	-- Hunters on this ghost move on: auto-target the next nearest ghost, or come home.
	for player, tg in targets do
		if tg.Uid == g.Uid then
			local d = DataService.Get(player)
			local nextG = if d and d.Settings.AutoTarget and not g.Event then nearestFor(player, 55) else nil
			setTarget(player, if nextG then nextG.Uid else nil)
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
		return
	end
	setTarget(player, uid)
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
			setSegment(g, randomPoint(g.Center, g.Radius, g.Def.Hover))
		end
	end
end

function GhostService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Ghosts"
	folder.Parent = workspace
	Net.Event("SelectTarget").OnServerEvent:Connect(onSelect)
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
		for _, g in ghosts do
			g.Damage[player] = nil
		end
	end)
	task.spawn(function()
		local tick = Config.Combat.TickSeconds
		local last = os.clock()
		while true do
			task.wait(tick)
			local c = os.clock()
			-- cap dt so a server hitch can't produce a burst of damage
			damageTick(math.min(c - last, tick * 2))
			last = c
			moveTick()
		end
	end)
end

-- Tutorial / UI helper: closest ghost the player can fight.
GhostService.NearestFor = nearestFor

return GhostService
