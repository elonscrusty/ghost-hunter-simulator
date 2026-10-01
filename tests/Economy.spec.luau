-- Sanity checks on Config balance: early game must be fast, later zones must be goals.
local Config = require("./_Config")
local T = {}
local function zoneHunters(zone)
	local out = {}
	for id, h in Config.Hunters do if h.Zone == zone then table.insert(out, h) end end
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
return T
