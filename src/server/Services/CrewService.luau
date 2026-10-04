--!strict
-- Hunter health, knockouts and recovery (v1.6).
--  * HP lives only in this server session (hunters start every session healthy); max HP comes
--    from the hunter's (tiered) power and the owner's pet HP bonus.
--  * A hunter at 0 HP is KNOCKED OUT: d.Knocked[uid] = os.time() when it recovers. The timer is
--    real time, so it keeps running while the player is offline and rejoining can't reset or
--    skip it. Knocked-out hunters are never deleted; they just don't fight until they recover.
-- Ghosts call CrewService.Hit through GhostService, only for crews attacking that ghost.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local Fx = require(script.Parent.Fx)

local CrewService = {}

type Health = { HP: number, LastHit: number }
local health: { [Player]: { [string]: Health } } = {}
local dirty: { [Player]: boolean } = {}

local R = Config.Retaliation

function CrewService.MaxHP(player: Player, uid: string): number
	return Rules.HunterMaxHP(HunterService.HunterPower(player, uid), R.HPPerPower, PlayerInfo.PetBonus(player, "HP"))
end

local function entry(player: Player, uid: string): Health
	local h = health[player]
	if not h then
		h = {}
		health[player] = h
	end
	local e = h[uid]
	if not e then
		e = { HP = CrewService.MaxHP(player, uid), LastHit = 0 }
		h[uid] = e
	end
	return e
end

-- Crew uids that can be hit right now.
function CrewService.Targets(player: Player): { string }
	return HunterService.ActiveUids(player)
end

-- Pushes "uid=pct,..." for the owner's HP bars (and everyone's crew rigs).
local function publish(player: Player)
	local parts = {}
	for _, uid in CrewService.Targets(player) do
		local e = entry(player, uid)
		local pct = math.clamp(math.floor(e.HP / CrewService.MaxHP(player, uid) * 100 + 0.5), 0, 100)
		table.insert(parts, uid .. "=" .. pct)
	end
	player:SetAttribute("CrewHP", table.concat(parts, ","))
end

-- Damages one hunter. Returns true if it was knocked out by this hit.
function CrewService.Hit(player: Player, uid: string, amount: number): boolean
	local d = DataService.Get(player)
	if not d or amount ~= amount or amount <= 0 then
		return false
	end
	if not d.Hunters[uid] or HunterService.IsKnocked(d, uid) then
		return false
	end
	local e = entry(player, uid)
	e.HP -= amount
	e.LastHit = os.clock()
	dirty[player] = true
	if e.HP > 0 then
		return false
	end
	local seconds = Rules.RecoverySeconds(R.RecoverySeconds, PlayerInfo.PetBonus(player, "Recovery"))
	d.Knocked[uid] = os.time() + math.ceil(seconds)
	local list = health[player]
	if list then
		list[uid] = nil
	end
	HunterService.Refresh(player)
	local def = Config.Hunters[d.Hunters[uid].Id]
	Fx.To(player, "Knocked", { Uid = uid, Name = def and def.Name or "Hunter", Until = d.Knocked[uid] })
	if #HunterService.ActiveUids(player) == 0 and player:GetAttribute("InTower") ~= true then
		Fx.Toast(player, "Your whole crew is recovering! Equip other hunters (EQUIP BEST) or wait for them.", "Bad")
	end
	return true
end

-- Heals a hunter fully (e.g. entering a new tower room).
function CrewService.HealAll(player: Player)
	health[player] = nil
	dirty[player] = true
end

local function regenTick(dt: number)
	local now = os.clock()
	for player, list in health do
		for uid, e in list do
			local max = CrewService.MaxHP(player, uid)
			if e.HP > max then
				e.HP = max
				dirty[player] = true
			elseif e.HP < max and now - e.LastHit >= R.RegenDelay then
				e.HP = math.min(max, e.HP + max * R.RegenPerSecond * dt)
				dirty[player] = true
			end
		end
	end
	for player in dirty do
		if player.Parent then
			publish(player)
		end
	end
	table.clear(dirty)
end

-- Knockout timers end on the server clock (also covers hunters that recovered offline).
local function recoveryTick()
	local t = os.time()
	for _, player in Players:GetPlayers() do
		local d = DataService.Get(player)
		if d then
			local any = false
			for uid, untilT in d.Knocked do
				if untilT <= t then
					d.Knocked[uid] = nil
					any = true
					local h = d.Hunters[uid]
					local def = h and Config.Hunters[h.Id]
					Fx.To(player, "Recovered", { Uid = uid, Name = def and def.Name or "Hunter" })
				end
			end
			if any then
				HunterService.Refresh(player)
				dirty[player] = true
			end
		end
	end
end

function CrewService.Init()
	DataService.AddDecorator(function(player, s)
		local d = DataService.Get(player)
		if d then
			s.Knocked = d.Knocked
		end
	end)
end

function CrewService.Start()
	Players.PlayerRemoving:Connect(function(player)
		health[player] = nil
		dirty[player] = nil
	end)
	DataService.Loaded:Connect(function(player)
		dirty[player] = true
	end)
	task.spawn(function()
		local last = os.clock()
		local nextRecover = 0
		while true do
			task.wait(0.5)
			local c = os.clock()
			local dt = math.min(c - last, 2)
			last = c
			local ok, err = pcall(function()
				regenTick(dt)
				if c >= nextRecover then
					nextRecover = c + 1
					recoveryTick()
				end
			end)
			if not ok then
				warn("[Crew] tick error: " .. tostring(err))
			end
		end
	end)
end

return CrewService
