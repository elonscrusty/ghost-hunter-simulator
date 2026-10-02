local Rules = require("../src/shared/Logic/Rules")
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local pool = {
	{ Hunter = "A", Weight = 60 }, { Hunter = "B", Weight = 28 }, { Hunter = "C", Weight = 10 }, { Hunter = "D", Weight = 2 },
}
local order = { A = 1, B = 2, C = 3, D = 5 }
local function ro(id) return order[id] or 1 end
local T = {}
T.odds_sum_to_one = function()
	local o = Rules.Odds(pool, ro, 1, 3)
	local s = 0
	for _, v in o do s += v end
	assert(math.abs(s - 1) < 1e-9)
	eq(o.D, 0.02)
end
T.luck_boosts_rare_plus = function()
	local o = Rules.Odds(pool, ro, 2, 3)
	assert(o.D > 0.02 and o.C > 0.1 and o.A < 0.6)
end
T.roll_edges = function()
	eq(Rules.Roll(pool, ro, 1, 3, 0), "A")
	eq(Rules.Roll(pool, ro, 1, 3, 0.5999), "A")
	eq(Rules.Roll(pool, ro, 1, 3, 0.6), "B")
	eq(Rules.Roll(pool, ro, 1, 3, 0.9999999), "D")
end
T.roll_distribution = function()
	local counts = {}
	local seed = 12345
	local function nxt() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
	for _ = 1, 20000 do
		local h = Rules.Roll(pool, ro, 1, 3, nxt())
		counts[h] = (counts[h] or 0) + 1
	end
	assert(math.abs(counts.A / 20000 - 0.6) < 0.02)
	assert(math.abs(counts.D / 20000 - 0.02) < 0.006)
end
local power = { A = 5, B = 9, C = 16, D = 40 }
local function po(id) return power[id] or 0 end
T.equip_best_picks_strongest = function()
	local owned = { ["1"] = { Id = "A" }, ["2"] = { Id = "D" }, ["3"] = { Id = "B" }, ["4"] = { Id = "A" }, ["5"] = { Id = "C" }, ["6"] = { Id = "B" } }
	local best = Rules.EquipBest(owned, po, ro, 4)
	eq(#best, 4); eq(best[1], "2"); eq(best[2], "5")
	eq(Rules.CrewPower(best, owned, po), 40 + 16 + 9 + 9)
end
T.equip_best_fewer_than_slots = function()
	local best = Rules.EquipBest({ ["7"] = { Id = "A" } }, po, ro, 4)
	eq(#best, 1)
end
T.crew_power_ignores_missing = function()
	eq(Rules.CrewPower({ "1", "x" }, { ["1"] = { Id = "B" } }, po), 9)
end
T.daily_first_claim = function()
	local d = Rules.Daily(1000, 0, 0, 72000, 172800, 7)
	assert(d.CanClaim); eq(d.Day, 1)
end
T.daily_cooldown = function()
	local d = Rules.Daily(1000 + 3600, 1000, 1, 72000, 172800, 7)
	assert(not d.CanClaim); eq(d.Day, 2); eq(d.Wait, 72000 - 3600)
end
T.daily_next_day = function()
	local d = Rules.Daily(1000 + 80000, 1000, 3, 72000, 172800, 7)
	assert(d.CanClaim); eq(d.Day, 4)
end
T.daily_wraps_after_7 = function()
	local d = Rules.Daily(1000 + 80000, 1000, 7, 72000, 172800, 7)
	eq(d.Day, 1)
end
T.daily_streak_reset = function()
	local d = Rules.Daily(1000 + 200000, 1000, 5, 72000, 172800, 7)
	assert(d.CanClaim and d.StreakBroken); eq(d.Day, 1)
end
T.daily_clock_backwards = function()
	assert(not Rules.Daily(500, 1000, 2, 72000, 172800, 7).CanClaim)
end
T.split_sums = function()
	local parts = Rules.Split(17, 4)
	local s = 0
	for _, v in parts do s += v; assert(v >= 4) end
	eq(s, 17); eq(#parts, 4)
	eq(#Rules.Split(2, 5), 2)
	eq(#Rules.Split(0, 5), 0)
end
T.event_share = function()
	eq(Rules.EventShare(50, 100, 2, 0.35, 2.5), 1)
	eq(Rules.EventShare(1, 100, 2, 0.35, 2.5), 0.35)
	eq(Rules.EventShare(100, 100, 5, 0.35, 2.5), 2.5)
end
T.boss_damage_share = function()
	eq(Rules.DamageShare(100, 100), 1) -- solo: the whole reward
	eq(Rules.DamageShare(25, 100), 0.25) -- did 25% of the damage: 25% of the reward
	eq(Rules.DamageShare(0, 100), 0)
	eq(Rules.DamageShare(5, 0), 0)
end
T.limiter = function()
	local l = Rules.NewLimiter(2, 1)
	assert(Rules.Allow(l, "p", 0)); assert(Rules.Allow(l, "p", 0.1)); assert(not Rules.Allow(l, "p", 0.2))
	assert(Rules.Allow(l, "p", 1.05))
	Rules.Forget(l, "p")
	eq(l.hits.p, nil)
end
T.zone_index = function()
	local r = { { -60, 260 }, { 260, 540 }, { 540, 880 } }
	eq(Rules.ZoneIndexAt(0, r), 1); eq(Rules.ZoneIndexAt(300, r), 2); eq(Rules.ZoneIndexAt(900, r), 3); eq(Rules.ZoneIndexAt(-100, r), 1)
end
T.upgrades = function()
	eq(Rules.UpgradeCost({ 10, 20 }, 1), 10); eq(Rules.UpgradeCost({ 10, 20 }, 3), nil)
	eq(Rules.UpgradeValue({ 1, 2, 3 }, 9), 3)
end
return T
