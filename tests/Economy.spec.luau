-- Sanity checks on Config balance: early game must be fast, later zones must be goals.
local Config = require("./_Config")
local T = {}
local Rules = require("../src/shared/Logic/Rules")
-- the 4 base hunters of a zone (Common..Legendary), weakest first. Extra hunters that share a tier
-- have the same power, so one per rarity is enough.
local function zoneHunters(zone)
	local out, seen = {}, {}
	for id, h in Config.Hunters do
		if h.Zone == zone and Config.Rarities[h.Rarity].Order <= 5 and not seen[h.Rarity] then
			seen[h.Rarity] = true
			table.insert(out, h)
		end
	end
	table.sort(out, function(a, b) return a.Power < b.Power end)
	return out
end
local function avg(r) return r end

T.every_reference_exists = function()
	for id, c in Config.Crates do
		assert(Config.ZoneById[c.Zone], "crate zone " .. id)
		for _, e in c.Pool do
			local h = Config.Hunters[e.Hunter]; assert(h, "crate hunter " .. e.Hunter)
			assert(Config.Rarities[h.Rarity] and Config.Rarities[h.Rarity].Enabled, "rarity " .. h.Rarity)
		end
	end
	for _, z in Config.Zones do assert(Config.Crates[z.Crate], "zone crate " .. z.Id) end
	for _, a in Config.Layout.GhostAreas do assert(Config.Ghosts[a.Ghost], a.Ghost) end
	for id, h in Config.Hunters do assert(Config.ZoneById[h.Zone], id); assert(h.Id == id, id) end
	for id, g in Config.Ghosts do assert(g.Id == id, id); assert(Config.ZoneById[g.Zone], id) end
	assert(Config.Hunters[Config.StarterHunter])
	for id, u in Config.Upgrades do assert(#u.Costs == #u.Levels - 1, id) end
end

T.four_hunters_per_zone_with_rising_power = function()
	local prevTop = 0
	for _, z in Config.Zones do
		local hs = zoneHunters(z.Id)
		assert(#hs == 4, z.Id)
		-- each zone's common is stronger than the previous zone's rare-ish mid tier
		assert(hs[1].Power > prevTop * 0.5, z.Id .. " common too weak vs previous zone")
		prevTop = hs[4].Power
	end
end

T.first_crate_within_a_minute = function()
	local g = Config.Ghosts.WanderingSpirit
	local starter = Config.Hunters[Config.StarterHunter].Power
	local secondsPerKill = g.Spirit / starter + 2 -- +2s walking/retarget
	local perSecond = avg(g.Reward) / secondsPerKill
	local t = Config.Crates.Beginner.Price / perSecond
	assert(t < 60, "first crate takes " .. t .. "s")
	assert(g.Spirit / starter <= 8, "first ghost takes too long")
end

T.cemetery_is_a_session_goal = function()
	-- typical crew after ~8 beginner crates: one each of the three lower tiers + rookie
	local crew = 5 + 9 + 16 + 9
	local g = Config.Ghosts.MischiefGhost
	local perSecond = avg(g.Reward) / (g.Spirit / crew + 2)
	local minutes = Config.ZoneById.Cemetery.Cost / perSecond / 60
	assert(minutes > 2 and minutes < 15, "cemetery takes " .. minutes .. " min")
end

T.school_needs_more_progression = function()
	local crew = 85 + 50 + 50 + 30
	local g = Config.Ghosts.CryptGhost
	local perSecond = avg(g.Reward) / (g.Spirit / crew + 2)
	local minutes = Config.ZoneById.School.Cost / perSecond / 60
	assert(minutes > 10 and minutes < 60, "school takes " .. minutes .. " min")
end

T.better_ghosts_pay_more_per_spirit_in_new_zone = function()
	-- reward per spirit may fall within a zone (bosses are slower but bigger), but every zone's
	-- weakest ghost must pay much more per kill than the previous zone's weakest
	assert(avg(Config.Ghosts.GraveSpirit.Reward) > avg(Config.Ghosts.MischiefGhost.Reward) * 2)
	assert(avg(Config.Ghosts.HallwayHaunt.Reward) > avg(Config.Ghosts.CryptGhost.Reward) * 2)
end

T.crates_priced_against_zone_income = function()
	for _, z in Config.Zones do
		local crate = Config.Crates[z.Crate]
		assert(crate.Price < z.Cost or z.Cost == 0, z.Id)
	end
end
T.zone_curve_is_smooth_and_rising = function()
	local prev = nil
	for i, z in Config.Zones do
		local hs = zoneHunters(z.Id)
		local crate = Config.Crates[z.Crate]
		if prev then
			local ph = zoneHunters(prev.Id)
			-- a previous Legendary stays useful early on: stronger than the next zone's Common...
			assert(ph[4].Power > hs[1].Power, z.Id .. ": previous legendary weaker than new common")
			-- ...but the new Rare is an obvious upgrade over it
			assert(hs[3].Power > ph[4].Power, z.Id .. ": new rare doesn't beat previous legendary")
			assert(z.Cost > prev.Cost * 3, z.Id .. " cost curve too flat")
			assert(crate.Price > Config.Crates[prev.Crate].Price * 3, z.Id .. " crate curve too flat")
		end
		assert(z.Order == i, z.Id .. " order")
		prev = z
	end
end

T.every_zone_has_layout_and_a_boss = function()
	assert(#Config.Daily.ZoneMultiplier == #Config.Zones, "ZoneMultiplier per zone")
	for i, z in Config.Zones do
		assert(Config.Layout.ZoneSpawns[z.Id], "spawn " .. z.Id)
		assert(Config.Layout.CrateStations[z.Crate], "station " .. z.Id)
		if i > 1 then
			local g = Config.Layout.Gates[z.Id]
			assert(g and g.Z == z.MinZ, "gate " .. z.Id)
			assert(Config.Zones[i - 1].MaxZ == z.MinZ, "zones must touch " .. z.Id)
		end
		local hasBoss, hasNormal = false, false
		for _, g in Config.Ghosts do
			if g.Zone == z.Id and (g.Kind == "Boss" or g.Kind == "MiniBoss") then hasBoss = true end
			if g.Zone == z.Id and g.Kind == "Normal" then hasNormal = true end
		end
		assert(hasBoss and hasNormal, "ghosts " .. z.Id)
	end
end

T.ghost_areas_stay_inside_their_zone = function()
	for _, a in Config.Layout.GhostAreas do
		local g = Config.Ghosts[a.Ghost]
		local z = Config.ZoneById[g.Zone]
		assert(a.Center.Z - a.Radius > z.MinZ + 20 and a.Center.Z + a.Radius < z.MaxZ - 10, a.Ghost .. " area leaves its zone")
		assert(math.abs(a.Center.X) + a.Radius <= Config.Layout.HalfWidth - 8, a.Ghost .. " area too close to the side wall")
	end
end

T.big_rewards_use_few_valuable_drops = function()
	for id, g in Config.Ghosts do
		assert(g.Drops <= 18, id .. " spawns too many orbs")
	end
end

T.next_zone_ghosts_pay_more = function()
	for i = 2, #Config.Zones do
		local function weakest(zoneId)
			local best = nil
			for _, g in Config.Ghosts do
				if g.Zone == zoneId and g.Kind == "Normal" and (not best or g.Spirit < best.Spirit) then best = g end
			end
			return best
		end
		local a, b = weakest(Config.Zones[i - 1].Id), weakest(Config.Zones[i].Id)
		assert(avg(b.Reward) > avg(a.Reward) * 3, Config.Zones[i].Id .. " weakest ghost doesn't pay enough more")
	end
end
T.each_zone_has_mythic_secret_and_one_ultra = function()
	for _, z in Config.Zones do
		local leg, myth, sec, ultra = nil, nil, nil, nil
		for _, h in Config.Hunters do
			if h.Zone == z.Id then
				if h.Rarity == "Legendary" then leg = h end
				if h.Rarity == "Mythic" then myth = h end
				if h.Rarity == "Secret" then assert(not sec, z.Id .. " two secrets"); sec = h end
				if h.Rarity == "Ultra" then assert(not ultra, z.Id .. " two ultras"); ultra = h end
			end
		end
		assert(leg and myth and sec and ultra, z.Id .. " needs a legendary, mythic, secret and ultra")
		assert(myth.Power > leg.Power and sec.Power > myth.Power and ultra.Power > sec.Power, z.Id .. " rarity power order")
		local r = ultra.Power / sec.Power
		assert(r >= 2.4 and r <= 2.6, z.Id .. " ultra should be ~2.5x the secret, got x" .. r)
	end
end

-- owner's agreed chest distribution (percent per rarity, every zone crate)
local AGREED = { Common = 50, Uncommon = 35, Rare = 10, Legendary = 3.5, Mythic = 1, Secret = 0.4, Ultra = 0.1 }
local function order(id: string): number return Config.Rarities[Config.Hunters[id].Rarity].Order end -- by hunter id, like the server

T.crate_pools_match_agreed_distribution = function()
	for _, z in Config.Zones do
		local crate = Config.Crates[z.Crate]
		local sum, cat, ultras, seen = 0, {}, 0, {}
		for _, e in crate.Pool do
			local h = Config.Hunters[e.Hunter]
			assert(h, z.Crate .. ": missing hunter " .. e.Hunter)
			assert(not seen[e.Hunter], z.Crate .. ": duplicate " .. e.Hunter); seen[e.Hunter] = true
			assert(AGREED[h.Rarity], z.Crate .. ": unexpected rarity " .. h.Rarity)
			assert(e.Weight > 0, z.Crate .. ": zero weight " .. e.Hunter)
			sum += e.Weight
			cat[h.Rarity] = (cat[h.Rarity] or 0) + e.Weight
			if h.Rarity == "Ultra" then ultras += 1; assert(h.Zone == z.Id, z.Crate .. ": ultra zone") end
		end
		assert(math.abs(sum - 100) < 1e-9, z.Crate .. " pool sums to " .. sum)
		for r, pct in AGREED do
			assert(cat[r], z.Crate .. " has no " .. r)
			assert(math.abs(cat[r] - pct) < 1e-9, z.Crate .. " " .. r .. " is " .. cat[r] .. "%, want " .. pct)
		end
		assert(ultras == 1, z.Crate .. " needs exactly one Ultra")
		local odds, total = Rules.Odds(crate.Pool, order, 1, Config.LuckAffectsFromOrder), 0
		for _, p in odds do total += p end
		assert(math.abs(total - 1) < 1e-9, z.Crate .. " odds sum to " .. total)
		assert(math.abs(odds[crate.Pool[1].Hunter] * 100 - crate.Pool[1].Weight) < 1e-9, z.Crate .. " weight is the exact percent")
	end
end

T.seeded_roll_matches_distribution = function()
	local pool = Config.Crates.Beginner.Pool
	math.randomseed(20261004)
	local nxt = math.random
	local n, counts = 200000, {}
	for _ = 1, n do
		local r = Config.Hunters[Rules.Roll(pool, order, 1, Config.LuckAffectsFromOrder, nxt())].Rarity
		counts[r] = (counts[r] or 0) + 1
	end
	local common = (counts.Common or 0) / n
	assert(math.abs(common - 0.5) < 0.01, "Common rolled " .. common)
	local ultra = counts.Ultra or 0
	assert(ultra > 0 and ultra / n < 0.003, "Ultra rolled " .. ultra .. " / " .. n)
end
T.early_curve_is_smooth = function()
	-- owner's targets: first area chest 600, second 5,000; no 1,500 -> 40,000 cliff
	assert(Config.Crates.Haunted.Price == 600, "Haunted crate 600")
	assert(Config.Crates.Elite.Price == 5000, "Elite crate 5,000")
	for i = 3, 5 do
		local r = Config.Zones[i].Cost / Config.Zones[i - 1].Cost
		assert(r <= 12, Config.Zones[i].Id .. " jump too big: x" .. r)
	end
	local prev = 0
	for _, z in Config.Zones do
		local c = Config.Crates[z.Crate].Price
		assert(c > prev, z.Id .. " crate must cost more than the previous area's")
		prev = c
	end
end

T.ghost_rewards_are_fixed_numbers = function()
	for id, g in Config.Ghosts do
		assert(type(g.Reward) == "number", id .. " reward must be one fixed base number")
	end
end

T.auto_attack_is_not_sold = function()
	for _, p in Config.GamePasses do
		if p.Key == "AutoAttack" then
			assert(p.Hidden == true, "Auto Attack is free: the old pass must stay hidden")
		end
	end
end
return T
