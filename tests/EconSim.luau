-- Economy simulation driven by the real Config (via the stubbed tests/_Config.luau that
-- tools/check.sh generates). Simulates a solo player who always farms the best-paying ghost
-- they can reach, equips their best crew, buys upgrades when they're cheap relative to the
-- next goal, opens crates and unlocks zones as soon as they can afford them.
--   cd tests && luau EconSim.luau        (prints median/p10/p90 milestone times)
local Config = require("./_Config")
local Rules = require("../src/shared/Logic/Rules")

local RUNS = tonumber((...)) or 300
local MAX_T = 40 * 3600

local seed = 777
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function powerOf(id) return Config.Hunters[id].Power end
local function rarityOrder(id) return Config.Rarities[Config.Hunters[id].Rarity].Order end

local milestones = { "first_kill", "first_crate", "first_upgrade", "crew_x2" }
for i, z in Config.Zones do
	if i > 1 then
		table.insert(milestones, string.lower(z.Id))
		table.insert(milestones, "crate_" .. z.Crate)
	end
end
for _, z in Config.Zones do
	table.insert(milestones, "index_" .. z.Id)
end
table.insert(milestones, "index_all")
table.insert(milestones, "all_upgrades")
local results = {}
for _, m in milestones do results[m] = {} end
local finalPower = {}

for run = 1, RUNS do
	local t = 0
	local ecto = 0
	local owned = { ["1"] = { Id = Config.StarterHunter } }
	local nextUid = 2
	local equipped = { "1" }
	local discovered = { [Config.StarterHunter] = true }
	local zones = { [Config.Zones[1].Id] = true }
	local up = { PickupRadius = 1, EctoBonus = 1, MoveSpeed = 1 }
	local hit = {}
	local startPower = powerOf(Config.StarterHunter)
	local function mark(name)
		if not hit[name] and results[name] then
			hit[name] = true
			table.insert(results[name], t)
		end
	end
	local function crewPower() return Rules.CrewPower(equipped, owned, powerOf) end
	local function nextZone()
		for _, z in Config.Zones do
			if not zones[z.Id] then return z end
		end
		return nil
	end
	local function bestCrate()
		local best = nil
		for _, z in Config.Zones do
			if zones[z.Id] then best = Config.Crates[z.Crate] end
		end
		return best
	end
	local function zoneComplete(zoneId)
		for id, h in Config.Hunters do
			if h.Zone == zoneId and not discovered[id] then return false end
		end
		return true
	end
	while t < MAX_T do
		-- spend first
		local spent = true
		while spent do
			spent = false
			local nz = nextZone()
			-- with every zone open, the next goal is "a few more crates"
			local goal = if nz then nz.Cost else (bestCrate() :: any).Price * 4
			if nz and ecto >= nz.Cost then
				ecto -= nz.Cost
				zones[nz.Id] = true
				mark(string.lower(nz.Id))
				spent = true
				continue
			end
			-- upgrades that cost <= 12% of the next goal (or anything once everything is unlocked)
			local cheapest, cheapestCost = nil, math.huge
			for id, u in Config.Upgrades do
				local c = Rules.UpgradeCost(u.Costs, up[id])
				if c and c < cheapestCost then cheapest, cheapestCost = id, c end
			end
			if cheapest and ecto >= cheapestCost and cheapestCost <= goal * 0.12 then
				ecto -= cheapestCost
				up[cheapest] += 1
				mark("first_upgrade")
				spent = true
				continue
			end
			local crate = bestCrate()
			local count = 0
			for _ in owned do count += 1 end
			-- storage nearly full: release everything weaker than the weakest equipped hunter
			if count >= Config.Inventory.MaxHunters - 1 then
				local weakest = math.huge
				for _, uid in equipped do weakest = math.min(weakest, powerOf(owned[uid].Id)) end
				for uid, h in owned do
					if not table.find(equipped, uid) and powerOf(h.Id) < weakest then
						owned[uid] = nil
						count -= 1
					end
				end
			end
			-- a crate is worth buying while its best hunter would still improve the crew
			local weakestEq = math.huge
			for _, uid in equipped do weakestEq = math.min(weakestEq, powerOf(owned[uid].Id)) end
			if #equipped < Config.Inventory.BaseSlots then weakestEq = 0 end
			-- expected gain of one more crate vs the weakest equipped hunter
			local gain = 0
			if crate then
				local odds = Rules.Odds(crate.Pool, rarityOrder, 1, Config.LuckAffectsFromOrder)
				for _, e in crate.Pool do gain += odds[e.Hunter] * math.max(0, powerOf(e.Hunter) - weakestEq) end
			end
			local useful = weakestEq == 0 or gain >= 0.1 * weakestEq
			if crate and ecto >= crate.Price and (useful or not nz) and (crate.Price <= goal * 0.25 or not nz) and count < Config.Inventory.MaxHunters then
				ecto -= crate.Price
				local h = Rules.Roll(crate.Pool, rarityOrder, 1, Config.LuckAffectsFromOrder, rnd())
				owned[tostring(nextUid)] = { Id = h }
				nextUid += 1
				discovered[h] = true
				equipped = Rules.EquipBest(owned, powerOf, rarityOrder, Config.Inventory.BaseSlots)
				mark("first_crate")
				mark("crate_" .. crate.Id)
				t += 2.5 -- reveal + equip
				spent = true
			end
		end
		if crewPower() >= startPower * 2 then mark("crew_x2") end
		for _, z in Config.Zones do
			if zoneComplete(z.Id) then mark("index_" .. z.Id) end
		end
		local all = true
		for id in Config.Hunters do if not discovered[id] then all = false end end
		if all then mark("index_all") end
		local maxed = true
		for id, u in Config.Upgrades do if up[id] < #u.Levels then maxed = false end end
		if maxed then mark("all_upgrades") end
		if hit.index_all and hit.all_upgrades and not nextZone() then break end

		-- farm the best ghost for one kill
		local power = crewPower()
		local radius = Rules.UpgradeValue(Config.Upgrades.PickupRadius.Levels, up.PickupRadius)
		local speed = Rules.UpgradeValue(Config.Upgrades.MoveSpeed.Levels, up.MoveSpeed)
		local bonus = Rules.UpgradeValue(Config.Upgrades.EctoBonus.Levels, up.EctoBonus)
		-- overhead per kill: engage delay + hunter run + walking to orbs (less with radius/speed)
		local overhead = Config.Combat.EngageDelay + 0.6 + (Config.Drops.ScatterMax + 6) / radius * (16 / speed) * 1.2
		local best, bestRate, bestTime = nil, 0, 0
		for _, g in Config.Ghosts do
			-- players don't sit on a boss for minutes: only fight ones that die in <= 25 s
			if zones[g.Zone] and g.Kind ~= "Event" and (g.Kind == "Normal" or g.Spirit / power <= 25) then
				local killT = g.Spirit / power + overhead
				local rate = ((g.Reward[1] + g.Reward[2]) / 2) * (1 + bonus) / killT
				if rate > bestRate then best, bestRate, bestTime = g, rate, killT end
			end
		end
		local reward = (best.Reward[1] + rnd() * (best.Reward[2] - best.Reward[1])) * (1 + bonus)
		t += bestTime
		ecto += math.floor(reward + 0.5)
		mark("first_kill")
	end
	table.insert(finalPower, Rules.CrewPower(equipped, owned, powerOf))
end

local function pct(list, p)
	if #list == 0 then return nil end
	table.sort(list)
	return list[math.max(1, math.floor(#list * p + 0.5))]
end
local function fmt(s)
	if not s then return "   never" end
	if s < 120 then return string.format("%6.0fs", s) end
	return string.format("%6.1fm", s / 60)
end
print(string.format("%-22s %8s %8s %8s  reached", "milestone", "p10", "median", "p90"))
for _, m in milestones do
	local l = results[m]
	print(string.format("%-22s %8s %8s %8s  %d/%d", m, fmt(pct(l, 0.1)), fmt(pct(l, 0.5)), fmt(pct(l, 0.9)), #l, RUNS))
end
