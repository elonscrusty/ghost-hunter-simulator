-- Economy simulation driven by the real Config (via tests/_Config.luau, which tools/check.sh
-- generates). Event-driven: instead of stepping kill by kill, the player farms at the best
-- steady rate they can reach until they can afford their next purchase, so 200 full playthroughs
-- take a few seconds.
--   cd tests && luau EconSim.luau            (or: luau EconSim.luau -a 50   for 50 runs)
-- Player model (solo, no Robux, no boosts, no pets, Normal tier only):
--   * farms the ghost with the best Ecto/second it can reach (bosses only if they die in <= 25 s)
--   * opens the newest crate while its expected power gain is >= 10% of the weakest equipped
--     hunter and the crate costs <= 25% of the next gate; upgrades that cost <= 12% of the gate
--   * unlocks the next gate as soon as it can
-- Prints: per-world pacing (first crate, gate, Ecto/min, minutes per crate), the Boss Tower egg
-- maths at each stage, Lucky Opens value and the pet bonus caps.
local Config = require("./_Config")
local Rules = require("../src/shared/Logic/Rules")

local RUNS = tonumber((...)) or 100
local MAX_T = 400 * 3600
local CRATE_SECONDS = 2.5 -- reveal + equip
local PATIENCE = 60 -- a beginner leaves the tower once a room takes longer than this (seconds)
local ROOM_OVERHEAD = 8 -- walking in, vote, boss intro (seconds per room)

local seed = 777
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function powerOf(id: string, _tier: number?): number
	return Config.Hunters[id].Power
end
local function rarityOrder(id: string): number
	return Config.Rarities[Config.Hunters[id].Rarity].Order
end

local Z = #Config.Zones
local stats = {} -- [zoneIndex] = { entry = {}, firstCrate = {}, epmIn = {}, epmOut = {}, crateMin = {}, crates = {}, power = {} }
for i = 1, Z do
	stats[i] = { entry = {}, firstCrate = {}, epmIn = {}, epmOut = {}, crateMin = {}, crates = {}, power = {} }
end
local finish = {}

-- farming rate (Ecto per second) and the ghost used
local function farmRate(zoneIdx: number, power: number, up: { [string]: number }): (number, string)
	local radius = Rules.UpgradeValue(Config.Upgrades.PickupRadius.Levels, up.PickupRadius)
	local speed = Rules.UpgradeValue(Config.Upgrades.MoveSpeed.Levels, up.MoveSpeed)
	local bonus = Rules.UpgradeValue(Config.Upgrades.EctoBonus.Levels, up.EctoBonus)
	local overhead = Config.Combat.EngageDelay + 0.6 + (Config.Drops.ScatterMax + 6) / radius * (16 / speed) * 1.2
	local bestRate, bestId = 0, "?"
	for id, g in Config.Ghosts do
		local zi = Config.ZoneById[g.Zone].Order
		if zi <= zoneIdx and g.Kind ~= "Event" and g.Kind ~= "Tower" and (g.Kind == "Normal" or g.Spirit / power <= 25) then
			local rate = g.Reward * (1 + bonus) / (g.Spirit / power + overhead)
			if rate > bestRate then
				bestRate, bestId = rate, id
			end
		end
	end
	return bestRate, bestId
end

for _ = 1, RUNS do
	local t, ecto = 0, 0
	local owned = { ["1"] = { Id = Config.StarterHunter } }
	local count, nextUid = 1, 2
	local equipped = { "1" }
	local zone = 1
	local up = { PickupRadius = 1, EctoBonus = 1, MoveSpeed = 1 }
	local zoneCrates = 0
	local function crew(): number
		return Rules.CrewPower(equipped, owned, powerOf)
	end
	local function enterZone(i: number)
		zone = i
		zoneCrates = 0
		local r = farmRate(zone, crew(), up)
		local s = stats[i]
		table.insert(s.entry, t)
		table.insert(s.epmIn, r * 60)
		table.insert(s.crateMin, Config.Crates[Config.Zones[i].Crate].Price / (r * 60))
		table.insert(s.power, crew())
	end
	enterZone(1)
	while t < MAX_T do
		local nz = Config.Zones[zone + 1]
		local crate = Config.Crates[Config.Zones[zone].Crate]
		local goal = if nz then nz.Cost else crate.Price * 4
		-- candidate purchases
		local cheapest, cheapestCost = nil, math.huge
		for id, u in Config.Upgrades do
			local c = Rules.UpgradeCost(u.Costs, up[id])
			if c and c < cheapestCost then
				cheapest, cheapestCost = id, c
			end
		end
		local upgradeOk = cheapest ~= nil and cheapestCost <= goal * 0.12
		local weakestEq = math.huge
		for _, uid in equipped do
			weakestEq = math.min(weakestEq, powerOf(owned[uid].Id))
		end
		if #equipped < Config.Inventory.BaseSlots then
			weakestEq = 0
		end
		local odds = Rules.Odds(crate.Pool, rarityOrder, 1, Config.LuckAffectsFromOrder)
		local gain = 0
		for _, e in crate.Pool do
			gain += odds[e.Hunter] * math.max(0, powerOf(e.Hunter) - weakestEq)
		end
		local crateOk = (weakestEq == 0 or gain >= 0.1 * weakestEq or not nz) and (crate.Price <= goal * 0.25 or not nz)
		-- pick the cheapest wanted purchase (gate wins ties)
		local kind, cost = "gate", if nz then nz.Cost else math.huge
		if upgradeOk and cheapestCost < cost then
			kind, cost = "upgrade", cheapestCost
		end
		if crateOk and crate.Price < cost then
			kind, cost = "crate", crate.Price
		end
		if cost == math.huge then
			break -- everything bought / nothing useful left
		end
		local rate = farmRate(zone, crew(), up)
		if ecto < cost then
			t += (cost - ecto) / rate
			ecto = cost
		end
		if t >= MAX_T then
			break
		end
		ecto -= cost
		if kind == "gate" then
			table.insert(stats[zone].epmOut, rate * 60)
			table.insert(stats[zone].crates, zoneCrates)
			enterZone(zone + 1)
		elseif kind == "upgrade" then
			up[cheapest :: string] += 1
		else
			-- storage nearly full: release everything weaker than the weakest equipped hunter
			if count >= Config.Inventory.MaxHunters - 1 then
				for uid, h in owned do
					if not table.find(equipped, uid) and powerOf(h.Id) < weakestEq then
						owned[uid] = nil
						count -= 1
					end
				end
			end
			local h = Rules.Roll(crate.Pool, rarityOrder, 1, Config.LuckAffectsFromOrder, rnd())
			owned[tostring(nextUid)] = { Id = h }
			nextUid += 1
			count += 1
			zoneCrates += 1
			if zoneCrates == 1 then
				table.insert(stats[zone].firstCrate, t - stats[zone].entry[#stats[zone].entry])
			end
			equipped = Rules.EquipBest(owned, powerOf, rarityOrder, Config.Inventory.BaseSlots)
			t += CRATE_SECONDS
			if not nz and zoneCrates >= 40 then
				break
			end
		end
	end
	table.insert(finish, t)
end

local function pct(list: { number }, p: number): number?
	if #list == 0 then
		return nil
	end
	table.sort(list)
	return list[math.max(1, math.floor(#list * p + 0.5))]
end
local function dur(s: number?): string
	if not s then
		return "-"
	end
	if s < 120 then
		return string.format("%.0fs", s)
	elseif s < 7200 then
		return string.format("%.1fm", s / 60)
	end
	return string.format("%.1fh", s / 3600)
end
local function num(x: number?): string
	if not x then
		return "-"
	end
	local a = math.abs(x)
	if a >= 1e12 then
		return string.format("%.2fT", x / 1e12)
	elseif a >= 1e9 then
		return string.format("%.2fB", x / 1e9)
	elseif a >= 1e6 then
		return string.format("%.2fM", x / 1e6)
	elseif a >= 1e4 then
		return string.format("%.1fK", x / 1e3)
	end
	return string.format("%.0f", x)
end

print(string.format("ECONSIM: %d solo runs (median; inWorld = time spent in that world before the next gate)", RUNS))
print(string.format("%-13s %8s %8s %8s %8s %9s %9s %7s %6s %8s %12s", "world", "reached", "1stCrate", "inWorld", "p90", "epm-in", "epm-out", "crateMin", "crates", "crew", "dailyX/meas"))
local zm1 = nil
for i = 1, Z do
	local s = stats[i]
	local nextEntry = stats[i + 1] and stats[i + 1].entry
	local inWorld = {}
	if nextEntry then
		for k, e in nextEntry do
			inWorld[k] = e - s.entry[k]
		end
	end
	local epmIn = pct(s.epmIn, 0.5)
	zm1 = zm1 or epmIn
	print(string.format("%-13s %8s %8s %8s %8s %9s %9s %7.1f %6s %8s %12s",
		Config.Zones[i].Id, dur(pct(s.entry, 0.5)), dur(pct(s.firstCrate, 0.5)), dur(pct(inWorld, 0.5)), dur(pct(inWorld, 0.9)),
		num(epmIn), num(pct(s.epmOut, 0.5)), pct(s.crateMin, 0.5) or 0, num(pct(s.crates, 0.5)), num(pct(s.power, 0.5)),
		num(Config.Daily.ZoneMultiplier[i]) .. "/" .. num((epmIn or 0) / (zm1 or 1))))
end
print("finish (last world + 40 crates): median " .. dur(pct(finish, 0.5)) .. ", p90 " .. dur(pct(finish, 0.9)))
print("  epm = Ecto/min; crateMin = minutes of farming per newest crate on arrival; dailyX/meas = Config ZoneMultiplier vs measured arrival income / world 1")

-- BOSS TOWER: a solo run of 4 equal hunters climbs while a room takes <= PATIENCE s (and the room
-- timer allows it). Retaliation: every Interval s the boss hits a random standing hunter for
-- HitFraction(room) of its max HP; hunters heal RegenPerSecond after RegenDelay; a knocked-out
-- hunter is out for RecoverySeconds (crew damage drops with it). The run ends when all are out.
local TC = Config.Tower
local RT = Config.Retaliation
local DT = 0.1
local function towerRun(power: number, zoneIdx: number): (number, number, number, number)
	local shards, ecto, secs, room = 0, 0, 0, 0
	local hp = { 1, 1, 1, 1 }
	local lastHit = { -99, -99, -99, -99 }
	local outUntil = { -1, -1, -1, -1 }
	local now = 0
	local function standing(): { number }
		local s = {}
		for i = 1, 4 do
			if now >= outUntil[i] then
				if hp[i] <= 0 then
					hp[i] = 1 -- back from a knockout at full health
				end
				table.insert(s, i)
			end
		end
		return s
	end
	local function heal(dt: number)
		for i = 1, 4 do
			if now >= outUntil[i] and now - lastHit[i] >= RT.RegenDelay then
				hp[i] = math.min(1, hp[i] + RT.RegenPerSecond * dt)
			end
		end
	end
	for r = 1, 400 do
		local bossHP, hit = Rules.TowerScale(r, TC :: any, power)
		if bossHP / power > PATIENCE then
			break
		end
		local left, roomT, nextHit = bossHP, 0, TC.Interval
		while left > 0 and roomT <= TC.RoomSeconds do
			local up = standing()
			if #up == 0 then
				break
			end
			left -= power * #up / 4 * DT
			roomT += DT
			now += DT
			if roomT >= nextHit then
				nextHit += TC.Interval
				local i = up[math.floor(rnd() * #up) + 1]
				hp[i] -= hit
				lastHit[i] = now
				if hp[i] <= 0 then
					outUntil[i] = now + RT.RecoverySeconds
				end
			end
			heal(DT)
		end
		if left > 0 then
			break -- wiped or out of time: rewards so far are kept
		end
		local s, e = Rules.TowerReward(r, TC :: any)
		shards += s
		ecto += e * Config.Daily.ZoneMultiplier[zoneIdx]
		secs += roomT + ROOM_OVERHEAD
		now += ROOM_OVERHEAD
		heal(ROOM_OVERHEAD)
		room = r
	end
	return room, shards, ecto, secs
end
print("")
print("BOSS TOWER (solo, leaves when a room takes > " .. PATIENCE .. " s; no pets; egg = runs per egg)")
print(string.format("%-13s %8s %5s %7s %7s %6s %6s %6s %9s %9s", "stage", "crew", "room", "shards", "runMin", "egg1", "egg2", "egg3", "towerEpm", "farmEpm"))
local function towerLine(label: string, power: number, zoneIdx: number, farmEpm: number?)
	local room, shards, ecto, secs = towerRun(power, zoneIdx)
	local e = Config.Eggs
	local function runs(price: number): string
		return if shards > 0 then string.format("%.1f", price / shards) else "inf"
	end
	print(string.format("%-13s %8s %5d %7d %7.1f %6s %6s %6s %9s %9s", label, num(power), room, shards, secs / 60,
		runs(e.HauntedEgg.Price), runs(e.PhantomEgg.Price), runs(e.MoonlightEgg.Price), num(ecto / math.max(secs, 1) * 60), num(farmEpm)))
end
for _, p in { 10, 20, 40 } do
	towerLine("power " .. p, p, 1, nil)
end
for i = 1, Z do
	local p = pct(stats[i].power, 0.5)
	if p then
		towerLine(Config.Zones[i].Id, p, i, pct(stats[i].epmIn, 0.5))
	end
end
do
	local s5, s10 = 0, 0
	for r = 1, 10 do
		local s = Rules.TowerReward(r, TC :: any)
		if r <= 5 then
			s5 += s
		end
		s10 += s
	end
	print(string.format("  shards for rooms 1-5: %d (Haunted Egg = %.1f runs), rooms 1-10: %d (%.1f runs)", s5,
		Config.Eggs.HauntedEgg.Price / s5, s10, Config.Eggs.HauntedEgg.Price / s10))
end

-- LUCKY OPENS: cost of N lucky opens = N crates + the lucky pack; compare expected Rare+ etc.
print("")
local L = Config.LuckyOpens
print(string.format("LUCKY OPENS (pack = %d opens at x%g luck for %g crate prices)", L.Opens, L.Multiplier, L.PriceMultiplier))
do
	local pool = Config.Crates.Beginner.Pool
	local base = Rules.Odds(pool, rarityOrder, 1, Config.LuckAffectsFromOrder)
	local lucky = Rules.Odds(pool, rarityOrder, L.Multiplier, Config.LuckAffectsFromOrder)
	local spend = L.Opens + L.PriceMultiplier -- crate prices for one lucky pack + its opens
	print(string.format("%-10s %10s %10s %16s %16s", "tier+", "base/open", "lucky/open", "lucky per price", "plain per price"))
	for _, rar in { "Rare", "Legendary", "Mythic", "Secret", "Ultra" } do
		local from = Config.Rarities[rar].Order
		local b, l = 0, 0
		for _, e in pool do
			if rarityOrder(e.Hunter) >= from then
				b += base[e.Hunter]
				l += lucky[e.Hunter]
			end
		end
		print(string.format("%-10s %9.3f%% %9.3f%% %16.5f %16.5f", rar, b * 100, l * 100, l * L.Opens / spend, b))
	end
	print("  (per price = expected hits per crate price spent; lucky is worth it only if it beats plain)")
end

-- PET CAPS: best possible equipped total per kind vs the cap
print("")
print(string.format("PET BONUS CAPS (%d equipped)", Config.PetRules.MaxEquipped))
do
	local byKind: { [string]: { number } } = {}
	for _, pet in Config.Pets do
		byKind[pet.Bonus.Kind] = byKind[pet.Bonus.Kind] or {}
		table.insert(byKind[pet.Bonus.Kind], pet.Bonus.Value)
	end
	for kind, cap in Config.PetRules.Caps do
		local vals = byKind[kind] or {}
		table.sort(vals, function(a, b)
			return a > b
		end)
		-- duplicates of the best pet are allowed, so the best stack is MaxEquipped x the best value
		local best = (vals[1] or 0) * Config.PetRules.MaxEquipped
		print(string.format("%-9s cap %3.0f%%  best stack %3.0f%%  %s", kind, cap * 100, best * 100,
			if best > cap then "(cap bites)" else "(cap never reached)"))
	end
end
