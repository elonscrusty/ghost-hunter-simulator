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
-- v1.6 shared rewards
local function sum(t) local n = 0 for _, v in t do n += v end return n end
T.split_equal_damage = function()
	local o = Rules.SplitPool(100, { 40, 40 })
	eq(o[1], 50); eq(o[2], 50)
end
T.split_unequal_damage = function()
	local o = Rules.SplitPool(100, { 70, 30 })
	eq(o[1], 70); eq(o[2], 30)
end
T.split_rounding_keeps_pool = function()
	local o = Rules.SplitPool(10, { 1, 1, 1 })
	eq(sum(o), 10); eq(o[1], 4); eq(o[2], 3); eq(o[3], 3)
	local o2 = Rules.SplitPool(7, { 0.333, 0.667 })
	eq(sum(o2), 7); eq(o2[2], 5)
	local o3 = Rules.SplitPool(1, { 1, 1, 1, 1 })
	eq(sum(o3), 1)
end
T.split_largest_remainder = function()
	-- exact 2.6 / 4.4 / 3.0 -> floors 2/4/3 (=9), the 1 leftover goes to the .6 remainder
	local o = Rules.SplitPool(10, { 26, 44, 30 })
	eq(o[1], 3); eq(o[2], 4); eq(o[3], 3)
end
T.split_zero_contribution_gets_nothing = function()
	local o = Rules.SplitPool(50, { 0, 10, -5, 0 / 0 })
	eq(o[1], 0); eq(o[2], 50); eq(o[3], 0); eq(o[4], 0)
	eq(sum(Rules.SplitPool(50, { 0, 0 })), 0)
	eq(sum(Rules.SplitPool(0, { 1, 2 })), 0)
end
T.split_multiple_hunters_sum_per_player = function()
	-- player A's three hunters + player B's one hunter: weights are per-player totals
	local a = 10 + 15 + 5
	local b = 30
	local o = Rules.SplitPool(60, { a, b })
	eq(o[1], 30); eq(o[2], 30)
end
T.pool_members_ignore_tiny_contributors = function()
	eq(Rules.PoolMembers({ 90, 1, 1, 8 }, 0.1), 1)
	eq(Rules.PoolMembers({ 50, 50 }, 0.1), 2)
	eq(Rules.PoolMembers({}, 0.1), 1)
end
T.retaliation_rotates_targets = function()
	eq(Rules.NextTarget({}, nil), nil)
	eq(Rules.NextTarget({ "1:a" }, "1:a"), "1:a") -- only one hunter: always that one
	local keys = { "2:b", "1:a", "1:c" }
	eq(Rules.NextTarget(keys, nil), "1:a")
	eq(Rules.NextTarget(keys, "1:a"), "1:c")
	eq(Rules.NextTarget(keys, "1:c"), "2:b")
	eq(Rules.NextTarget(keys, "2:b"), "1:a") -- wraps
	eq(Rules.NextTarget({ "1:a", "2:b" }, "1:c"), "2:b") -- last target left: next one after it
end
T.overkill_not_counted = function()
	eq(Rules.Effective(500, 20), 20)
	eq(Rules.Effective(5, 20), 5)
	eq(Rules.Effective(5, 0), 0)
	eq(Rules.Effective(-1, 20), 0)
	eq(Rules.Effective(0 / 0, 20), 0)
end
T.retaliation_hit_capped = function()
	eq(Rules.RetaliationHit(1000, 0.04, 100, 0.25), 25)
	eq(Rules.RetaliationHit(100, 0.04, 1000, 0.25), 4)
	eq(Rules.RetaliationHit(1, 0.01, 1, 0.1), 1)
end
T.recovery_bonus = function()
	eq(Rules.RecoverySeconds(120, 0), 120)
	eq(Rules.RecoverySeconds(120, 0.25), 90)
	eq(Rules.RecoverySeconds(120, 5), 12)
end
T.pet_bonuses_add_and_cap = function()
	local b = Rules.PetBonuses({ { Kind = "Power", Value = 0.3 }, { Kind = "Power", Value = 0.4 }, { Kind = "Ecto", Value = 0.05 } }, { Power = 0.6 })
	eq(b.Power, 0.6); eq(b.Ecto, 0.05)
end
local towerCfg = { BaseHP = 180, HPGrowth = 1.15, FiveRoomBump = 1.25, MinKillSeconds = 4, HitFractionBase = 0.1, HitFractionGrowth = 1.05,
	HitFractionCap = 0.95, MaxScaledRoom = 400, ShardsBase = 4, ShardsPerRoom = 1.5, EctoBase = 150, MilestoneEvery = { [10] = 3, [5] = 2 } }
T.tower_scaling_grows_and_stays_finite = function()
	local h1, f1 = Rules.TowerScale(1, towerCfg, 0)
	local h2 = Rules.TowerScale(2, towerCfg, 0)
	local h6 = Rules.TowerScale(6, towerCfg, 0)
	local h5, f5 = Rules.TowerScale(5, towerCfg, 0)
	eq(h1, 180)
	assert(math.abs(h2 / h1 - 1.15) < 0.01, "+15% per room")
	assert(h6 / h5 > 1.4, "extra bump after room 5") -- 1.15 * 1.25
	assert(f5 > f1 and (f5 / f1) < (h5 / h1), "damage grows more gently than health")
	local hBig, fBig = Rules.TowerScale(1e12, towerCfg, 1e308)
	assert(hBig < math.huge and hBig == hBig and fBig <= 0.95)
	-- kill times for three kinds of team (seconds = hp / power)
	local function secs(room, power) return (Rules.TowerScale(room, towerCfg, power)) / power end
	assert(secs(1, 20) <= 10, "beginner crew clears room 1 in ~9 s")
	assert(secs(5, 20) > secs(1, 20) * 1.5, "beginner feels the climb by room 5")
	assert(secs(1, 1e6) == 4, "a Mega team still needs MinKillSeconds per room")
	assert(secs(60, 1e6) > secs(20, 1e6), "even a Mega team hits a wall eventually")
end
T.tower_rewards_and_checkpoints = function()
	local s1 = Rules.TowerReward(1, towerCfg)
	eq(s1, 5)
	eq((Rules.TowerReward(5, towerCfg)), 23) -- floor((4 + 7.5) * 2)
	local total = 0
	for r = 1, 5 do total += (Rules.TowerReward(r, towerCfg)) end
	assert(total >= 40, "intro run buys the 40-shard pet: " .. total)
	eq(Rules.TowerCheckpoint(4, 5), 0)
	eq(Rules.TowerCheckpoint(5, 5), 5)
	eq(Rules.TowerCheckpoint(14, 5), 10)
end
T.merge_rules = function()
	local owned = {
		a = { Id = "X" }, b = { Id = "X" }, c = { Id = "X" }, d = { Id = "X" }, e = { Id = "X" },
		f = { Id = "X", Locked = true }, g = { Id = "Y" }, h = { Id = "X", Tier = 1 }, m = { Id = "X", Tier = 2 },
	}
	local free = function() return nil end
	local ok, _, id, tier = Rules.MergeCheck(owned, { "a", "b", "c", "d", "e" }, 5, 2, free)
	assert(ok and id == "X" and tier == 0)
	assert(not (Rules.MergeCheck(owned, { "a", "b", "c", "d" }, 5, 2, free)))
	assert(not (Rules.MergeCheck(owned, { "a", "a", "c", "d", "e" }, 5, 2, free)))
	assert(not (Rules.MergeCheck(owned, { "a", "b", "c", "d", "f" }, 5, 2, free)))
	assert(not (Rules.MergeCheck(owned, { "a", "b", "c", "d", "g" }, 5, 2, free)))
	assert(not (Rules.MergeCheck(owned, { "a", "b", "c", "d", "h" }, 5, 2, free)))
	assert(not (Rules.MergeCheck(owned, { "a", "b", "c", "d", "zz" }, 5, 2, free)))
	assert(not (Rules.MergeCheck({ m1 = owned.m, m2 = owned.m, m3 = owned.m, m4 = owned.m, m5 = owned.m }, { "m1", "m2", "m3", "m4", "m5" }, 5, 2, free)))
	local busy = function(uid) return if uid == "c" then "In a trade" else nil end
	local ok2, err = Rules.MergeCheck(owned, { "a", "b", "c", "d", "e" }, 5, 2, busy)
	assert(not ok2 and err == "In a trade")
end
T.event_credit_window = function()
	eq(Rules.EventCredit(99, 100, 200, 5), 0)
	eq(Rules.EventCredit(100, 100, 200, 5), 5)
	eq(Rules.EventCredit(198, 100, 200, 5), 2)
	eq(Rules.EventCredit(200, 100, 200, 5), 0)
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
