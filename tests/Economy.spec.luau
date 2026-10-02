-- Sanity checks on Config balance: early game must be fast, later zones must be goals.
local Config = require("./_Config")
local T = {}
-- the 4 base hunters of a zone (Common..Legendary), weakest first
local function zoneHunters(zone)
	local out = {}
	for id, h in Config.Hunters do
		if h.Zone == zone and Config.Rarities[h.Rarity].Order <= 5 then table.insert(out, h) end
	end
	table.sort(out, function(a, b) return a.Power < b.Power end)
	return out
end
local function avg(r) return (r[1] + r[2]) / 2 end

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
T.each_zone_has_one_mythic_and_one_secret = function()
	for _, z in Config.Zones do
		local leg, myth, sec = nil, nil, nil
		for _, h in Config.Hunters do
			if h.Zone == z.Id then
				if h.Rarity == "Legendary" then leg = h end
				if h.Rarity == "Mythic" then assert(not myth, z.Id .. " two mythics"); myth = h end
				if h.Rarity == "Secret" then assert(not sec, z.Id .. " two secrets"); sec = h end
			end
		end
		assert(leg and myth and sec, z.Id .. " needs a legendary, mythic and secret")
		assert(myth.Power > leg.Power and sec.Power > myth.Power, z.Id .. " rarity power order")
		-- chase rewards: under 1% together
		local crate = Config.Crates[z.Crate]
		local total, rare = 0, 0
		for _, e in crate.Pool do
			total += e.Weight
			if e.Hunter == myth.Id or e.Hunter == sec.Id then rare += e.Weight end
		end
		assert(rare / total < 0.01, z.Id .. " mythic/secret too common")
	end
end
return T
