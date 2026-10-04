--!strict
-- GIANT POLTERGEIST: a periodic server-wide boss everyone can attack. Spirit scales with the
-- crews in the server; rewards scale with each participant's share of the damage.
-- Client messages (Fx "Boss"): { State = "Warning"|"Active"|"Defeated"|"Escaped", At = serverTime, Uid?, EndsAt? }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local GhostService = require(script.Parent.GhostService)
local DropService = require(script.Parent.DropService)
local Fx = require(script.Parent.Fx)

local EventService = {}

local current: GhostService.Ghost? = nil
local state = "Idle"
local endsAt = 0
local rng = Random.new()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function spiritFor(): number
	-- only crews near the arena count (late-game players elsewhere on the map must not make
	-- the boss unbeatable for the players who are actually there)
	local sum = 0
	local arena = Config.Layout.EventArena.Center
	for _, pl in Players:GetPlayers() do
		local char = pl.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - arena).Magnitude <= Config.Event.JoinRadius then
			sum += math.min(HunterService.CrewPower(pl), Config.Event.PowerCap)
		end
	end
	return Config.Event.SpiritBase + Config.Event.SpiritPerPower * sum
end

local function reward(g: GhostService.Ghost)
	local total = 0
	local participants = {}
	for player, dmg in g.Damage do
		-- counts if they dealt 1% of the boss, or ~MinSeconds of their own crew's damage (so a
		-- small crew fighting next to a huge one still participates)
		local ownShare = HunterService.CrewPower(player) * Config.Event.MinSeconds
		if player.Parent and dmg > 0 and (dmg >= g.Max * Config.Event.MinContribution or dmg >= ownShare) then
			table.insert(participants, player)
			total += dmg
		end
	end
	local arena = Config.Layout.EventArena
	-- SHARED POOL: RewardBase per participant, split by each participant's share of the damage
	-- (whole units, largest remainder), then scaled by that player's zone and Ectoplasm
	-- multipliers. Participants are everyone who dealt damage (no damage = no reward).
	local _ = total
	local shares = GhostService.SplitDamage(g)
	local pool = Rules.SplitPool(Config.Event.RewardBase * #shares.Players, shares.Weights)
	for i, player in shares.Players do
		local d = DataService.Get(player)
		if d and pool[i] > 0 then
			local amount = math.floor(pool[i] * PlayerInfo.ZoneMultiplier(player) * PlayerInfo.EctoMultiplier(player) + 0.5)
			-- Ectoplasm shower over the arena
			DropService.Spawn(player, arena.Center + Vector3.new(0, 12, 0), amount, Config.Event.RewardDrops, { 4, arena.Radius - 4 })
			d.Stats.Events += 1
			Fx.To(player, "Payout", { Name = g.Def.Name, Pct = shares.Weights[i] / shares.Total, Ecto = amount })
			Fx.Toast(player, string.format("GIANT POLTERGEIST DEFEATED! %d%% of the damage: +%s Ectoplasm!", math.floor(shares.Weights[i] / shares.Total * 100 + 0.5), Format.Commas(amount)), "Good")
		end
	end
end

local function runEvent()
	if state ~= "Idle" then
		return
	end
	local arena = Config.Layout.EventArena
	state = "Warning"
	Fx.All("Boss", { State = "Warning", At = serverNow() + Config.Event.WarningSeconds, Pos = arena.Center })
	task.wait(Config.Event.WarningSeconds)
	if #Players:GetPlayers() == 0 then
		state = "Idle"
		return
	end
	local def = Config.Ghosts[Config.Event.Ghost]
	local g = GhostService.Spawn(def, arena.Center, arena.Radius * 0.35, { Spirit = spiritFor(), Event = true })
	current = g
	state = "Active"
	endsAt = serverNow() + Config.Event.Duration
	g.Model:SetAttribute("EndsAt", endsAt)
	Fx.All("Boss", { State = "Active", Uid = g.Uid, EndsAt = endsAt, Pos = arena.Center })
	while g.Alive and serverNow() < endsAt do
		task.wait(0.2)
	end
	-- `g` is our own reference, so this works no matter how the ghost was removed
	if g.Alive then
		GhostService.Remove(g, nil, false)
		Fx.All("Boss", { State = "Escaped" })
	else
		Fx.All("Boss", { State = "Defeated", Pos = GhostService.Position(g) })
		reward(g)
	end
	current = nil
	state = "Idle"
end

-- Runs one event safely: an error can never leave the event system stuck.
local function runSafely()
	local ok, err = pcall(function()
		runEvent()
	end)
	if not ok then
		warn("[Event] " .. tostring(err))
		if current and current.Alive then
			pcall(GhostService.Remove, current, nil, false)
		end
		Fx.All("Boss", { State = "Escaped" })
		state = "Idle"
		current = nil
	end
end

-- Start an event now (DEV button / Summon product). While one is running the request is
-- queued and starts shortly after the current one ends.
local queued = 0
local running = false

local function runGuarded()
	if running then
		queued += 1
		return
	end
	running = true
	runSafely()
	while queued > 0 do
		queued -= 1
		task.wait(8)
		runSafely()
	end
	running = false
end

function EventService.Init()
	-- late joiners see the current boss
	DataService.Loaded:Connect(function(player)
		if state == "Active" and current then
			Fx.To(player, "Boss", { State = "Active", Uid = current.Uid, EndsAt = endsAt, Pos = Config.Layout.EventArena.Center })
		end
	end)
end

function EventService.Start()
	task.spawn(function()
		task.wait(Config.Event.FirstDelay)
		while true do
			-- a summoned event may already be running: skip this slot instead of queueing a second one
			if not running then
				runGuarded()
			end
			task.wait(Config.Event.Interval + rng:NextNumber(-30, 30))
		end
	end)
end

function EventService.TriggerNow()
	task.spawn(runGuarded)
end

function EventService.IsBusy(): boolean
	return running
end

return EventService
