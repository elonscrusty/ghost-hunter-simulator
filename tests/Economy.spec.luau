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
	-- worlds cover every zone exactly once, in order
	local worldStart = {}
	local expect = 1
	for _, w in Config.Worlds do
		assert(w.First == expect and w.Last >= w.First, "world " .. w.Name .. " must start at zone " .. expect)
		worldStart[w.First] = true
		expect = w.Last + 1
	end
	assert(expect == #Config.Zones + 1, "worlds must end at the last zone")
	local portal = Config.Layout.Portals.ToWorld2
	for i, z in Config.Zones do
		assert(Config.Layout.ZoneSpawns[z.Id], "spawn " .. z.Id)
		assert(Config.Layout.CrateStations[z.Crate], "station " .. z.Id)
		if i > 1 and not worldStart[i] then
			-- inside a world: a gate wall at MinZ, touching the previous zone
			local g = Config.Layout.Gates[z.Id]
			assert(g and g.Z == z.MinZ, "gate " .. z.Id)
			assert(Config.Zones[i - 1].MaxZ == z.MinZ, "zones must touch " .. z.Id)
		elseif i > 1 then
			-- first zone of a later world: no gate wall, bought at the portal at the end of the
			-- previous world (inside the previous zone), with a gap before this world's track
			assert(not Config.Layout.Gates[z.Id], "first zone of a world has no gate " .. z.Id)
			assert(portal.Zone == z.Id, "portal sells " .. z.Id)
			-- the portal's boss requirement is the previous world's last boss
			local boss = Config.Ghosts[portal.Boss]
			assert(boss and boss.Kind == "Boss" and boss.Zone == Config.Zones[i - 1].Id, "portal boss must be the boss of " .. Config.Zones[i - 1].Id)
			local prev = Config.Zones[i - 1]
			assert(portal.Position.Z > prev.MinZ and portal.Position.Z < prev.MaxZ, "portal stands in " .. prev.Id)
			assert(z.MinZ > prev.MaxZ, "gap between worlds before " .. z.Id)
			local back = Config.Layout.Portals.ToWorld1
			assert(back.Position.Z > z.MinZ and back.Position.Z < z.MaxZ, "return portal stands in " .. z.Id)
			assert(back.Arrive.Z > prev.MinZ and back.Arrive.Z < prev.MaxZ, "return portal lands in " .. prev.Id)
			for _, a in Config.Layout.GhostAreas do
				local d = math.sqrt((a.Center.X - portal.Position.X) ^ 2 + (a.Center.Z - portal.Position.Z) ^ 2)
				assert(d > a.Radius + 20, "portal too close to the " .. a.Ghost .. " area")
			end
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
local AGREED = { Common = 46, Uncommon = 32, Rare = 14, Legendary = 5.5, Mythic = 1.8, Secret = 0.55, Ultra = 0.15 } -- owner-approved odds (v1.16)
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
	assert(math.abs(common - AGREED.Common / 100) < 0.01, "Common rolled " .. common)
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
-- display odds (Rules.Odds, used by the crate panel) are exactly the slices Rules.Roll uses,
-- under every luck stack a player can have (boost x2, Lucky Hunter x1.5, server luck x2, lucky opens x2)
T.display_odds_equal_roll_slices_under_luck = function()
	local lucks = { 1, 1.5, 2, 3, 4, 6, 8, 12, 24 }
	for id, crate in Config.Crates do
		if #crate.Pool > 0 then
			for _, luck in lucks do
				local odds, acc = Rules.Odds(crate.Pool, order, luck, Config.LuckAffectsFromOrder), 0
				for _, e in crate.Pool do
					local p = odds[e.Hunter]
					assert(p == p and p > 0, id .. " " .. e.Hunter .. " unreachable at luck " .. luck)
					local mid = acc + p / 2
					assert(Rules.Roll(crate.Pool, order, luck, Config.LuckAffectsFromOrder, mid) == e.Hunter, id .. " roll slice " .. e.Hunter)
					acc += p
				end
				assert(math.abs(acc - 1) < 1e-9, id .. " odds sum " .. acc .. " at luck " .. luck)
			end
		end
	end
end

T.every_hunter_obtainable_exactly_once = function()
	local src = {}
	for _, c in Config.Crates do
		for _, e in c.Pool do
			src[e.Hunter] = (src[e.Hunter] or 0) + 1
		end
	end
	for _, h in Config.Exclusives do
		src[h] = (src[h] or 0) + 1
	end
	for id in Config.Hunters do
		assert(src[id] == 1, id .. " is in " .. tostring(src[id] or 0) .. " crates/exclusive slots (want 1)")
	end
end

T.zone_multiplier_rises = function()
	local zm = Config.Daily.ZoneMultiplier
	for i = 2, #zm do
		assert(zm[i] > zm[i - 1], "Daily.ZoneMultiplier must rise at " .. i)
	end
end

-- P1 audit: a solo Boss Tower run pays at most 1.5x the Ecto/min of farming the player's zone.
-- Same models as tests/EconSim.luau (farming with starting upgrades; a crew of 4 equal hunters
-- climbs while a room takes <= 60 s, with boss retaliation and knockouts), but deterministic: the
-- boss hits the standing hunters in turn. Crews of 4x the zone's Uncommon..Legendary hunter
-- (EconSim's arrival crews are at least that strong) must stay <= 1.5x; an under-geared crew of
-- 4x Commons <= 2x.
T.tower_ecto_close_to_farming = function()
	local TC, RT = Config.Tower, Config.Retaliation
	local U = Config.Upgrades
	local radius, speed = U.PickupRadius.Levels[1], U.MoveSpeed.Levels[1]
	local overhead = Config.Combat.EngageDelay + 0.6 + (Config.Drops.ScatterMax + 6) / radius * (16 / speed) * 1.2
	local DT = 0.1
	for zi, z in Config.Zones do
		for k, h in zoneHunters(z.Id) do
			local power = h.Power * Config.Inventory.BaseSlots
			local limit = if k == 1 then 2 else 1.5
			local farm = 0
			for _, g in Config.Ghosts do
				local gz = Config.ZoneById[g.Zone].Order
				if gz <= zi and g.Kind ~= "Event" and g.Kind ~= "Tower" and (g.Kind == "Normal" or g.Spirit / power <= 25) then
					farm = math.max(farm, g.Reward / (g.Spirit / power + overhead))
				end
			end
			local zm = Config.Daily.ZoneMultiplier[zi]
			local perSpirit = Rules.ZoneEctoPerSpirit(Config.Ghosts, z.Id) / zm
			local hp, lastHit, outUntil = { 1, 1, 1, 1 }, { -99, -99, -99, -99 }, { -1, -1, -1, -1 }
			local now, turn, ecto, secs = 0, 0, 0, 0
			local function tick(dt)
				now += dt
				for i = 1, 4 do
					if now >= outUntil[i] and hp[i] <= 0 then
						hp[i] = 1
					end
					if now >= outUntil[i] and now - lastHit[i] >= RT.RegenDelay then
						hp[i] = math.min(1, hp[i] + RT.RegenPerSecond * dt)
					end
				end
			end
			for r = 1, 400 do
				local bossHP, hit = Rules.TowerScale(r, TC :: any, power)
				if bossHP / power > 60 then
					break
				end
				local left, roomT, nextHit = bossHP, 0, TC.Interval
				while left > 0 and roomT <= TC.RoomSeconds do
					local up = {}
					for i = 1, 4 do
						if now >= outUntil[i] then
							table.insert(up, i)
						end
					end
					if #up == 0 then
						break
					end
					left -= power * #up / 4 * DT
					roomT += DT
					tick(DT)
					if roomT >= nextHit then
						nextHit += TC.Interval
						turn += 1
						local i = up[turn % #up + 1]
						hp[i] -= hit
						lastHit[i] = now
						if hp[i] <= 0 then
							outUntil[i] = now + RT.RecoverySeconds
						end
					end
				end
				if left > 0 then
					break
				end
				local _, e = Rules.TowerReward(r, TC :: any, roomT, bossHP, perSpirit)
				ecto += e * zm
				secs += roomT + TC.RoomOverheadSeconds
				tick(TC.RoomOverheadSeconds)
			end
			if secs > 0 then
				local ratio = (ecto / secs) / farm
				assert(ratio <= limit, string.format("%s crew %g: tower pays %.2fx farming", z.Id, power, ratio))
			end
		end
	end
end

-- P1 audit: Lucky Opens (pack + the opens themselves) give more Rare+ per Ecto than plain opens
T.lucky_opens_beat_plain_per_ecto = function()
	local L = Config.LuckyOpens
	local function order(id) return Config.Rarities[Config.Hunters[id].Rarity].Order end
	local rare = Config.Rarities.Rare.Order
	for id, c in Config.Crates do
		if #c.Pool > 0 then
			local base = Rules.Odds(c.Pool, order, 1, Config.LuckAffectsFromOrder)
			local lucky = Rules.Odds(c.Pool, order, L.Multiplier, Config.LuckAffectsFromOrder)
			local b, l = 0, 0
			for _, e in c.Pool do
				if order(e.Hunter) >= rare then
					b += base[e.Hunter]
					l += lucky[e.Hunter]
				end
			end
			local luckyPerPrice = l * L.Opens / (L.Opens + L.PriceMultiplier)
			assert(luckyPerPrice > b * 1.1, id .. ": lucky opens must clearly beat plain opens per Ecto")
		end
	end
end

-- smaller Ecto pack is worse per Robux than the Barrel, but not wildly worse
T.ecto_packs_per_robux = function()
	local function per(key)
		for _, p in Config.Products do
			if p.Key == key then
				return p.Amount / tonumber(string.match(p.PriceLabel, "%d+"))
			end
		end
		error("missing " .. key)
	end
	local sack, barrel = per("Ecto1"), per("Ecto2")
	assert(sack < barrel and sack >= barrel * 0.6, string.format("sack %.1f vs barrel %.1f Ecto/R$", sack, barrel))
end

-- locked: the cheapest egg takes about 3-5 beginner tower runs (a beginner run reaches ~room 5)
T.cheapest_egg_takes_3_to_5_beginner_runs = function()
	local cheapest = math.huge
	for _, e in Config.Eggs do
		cheapest = math.min(cheapest, e.Price)
	end
	local shards = 0
	for r = 1, 5 do
		shards += (Rules.TowerReward(r, Config.Tower :: any))
	end
	local runs = cheapest / shards
	assert(runs >= 3 and runs <= 5, "cheapest egg = " .. runs .. " room-5 runs")
	-- rewards stay finite past the scaling cap
	local s, e = Rules.TowerReward(1e9, Config.Tower :: any)
	assert(s == s and e == e and s < math.huge and e < math.huge, "tower reward not finite")
end

T.pet_bonus_caps_cover_every_kind = function()
	for id, pet in Config.Pets do
		local cap = Config.PetRules.Caps[pet.Bonus.Kind]
		assert(cap and cap > 0 and cap <= 1, id .. " bonus kind " .. pet.Bonus.Kind .. " has no sane cap")
		-- a pet never shows more than it can give (the total cap limits every bonus kind)
		assert(pet.Bonus.Value > 0 and pet.Bonus.Value <= cap, id .. " bonus above its cap")
	end
end
return T
