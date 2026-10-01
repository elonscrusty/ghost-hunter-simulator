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
	local sum = 0
	for _, pl in Players:GetPlayers() do
		sum += math.min(HunterService.CrewPower(pl), Config.Event.PowerCap)
	end
	return Config.Event.SpiritBase + Config.Event.SpiritPerPower * sum
end

local function reward(g: GhostService.Ghost)
	local total = 0
	local participants = {}
	for player, dmg in g.Damage do
		if player.Parent and dmg >= g.Max * Config.Event.MinContribution then
			table.insert(participants, player)
			total += dmg
		end
	end
	local arena = Config.Layout.EventArena
	for _, player in participants do
		local d = DataService.Get(player)
		if d then
			local share = Rules.EventShare(g.Damage[player], total, #participants, Config.Event.MinShare, Config.Event.MaxShare)
			local amount = Config.Event.RewardBase * PlayerInfo.ZoneMultiplier(player) * share * PlayerInfo.EctoMultiplier(player)
			amount = math.floor(amount + 0.5)
			-- Ectoplasm shower over the arena
			DropService.Spawn(player, arena.Center + Vector3.new(0, 12, 0), amount, Config.Event.RewardDrops, { 4, arena.Radius - 4 })
			d.Stats.Events += 1
			Fx.Toast(player, "GIANT POLTERGEIST DEFEATED! +" .. Format.Commas(amount) .. " Ectoplasm incoming!", "Good")
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
			runSafely()
			task.wait(Config.Event.Interval + rng:NextNumber(-30, 30))
		end
	end)
end

-- Studio/testing helper: start an event now (used by the admin command in Main).
function EventService.TriggerNow()
	task.spawn(runSafely)
end

return EventService
