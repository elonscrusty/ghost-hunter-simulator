-- Pet egg rules + the egg table in Config.
local Eggs = require("../src/shared/Logic/Eggs")
local Config = require("./_Config")
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local T = {}

T.every_egg_totals_100 = function()
	local n = 0
	for id, egg in Config.Eggs do
		n += 1
		eq(Eggs.Total(egg), 100, id)
		eq(egg.Id, id, "egg id")
		assert(egg.Price > 0, id .. " price")
		for _, o in egg.Odds do
			assert(Config.Pets[o.Pet], id .. " unknown pet " .. o.Pet)
			assert(o.Chance > 0, id .. " zero chance")
			assert(o.Pet ~= "LanternSpirit", "event pet must stay out of eggs")
		end
	end
	eq(n, #Config.EggOrder, "EggOrder lists every egg")
	for _, id in Config.EggOrder do
		assert(Config.Eggs[id], "EggOrder " .. id)
	end
end

T.design_numbers = function()
	local e = Config.Eggs
	eq(e.HauntedEgg.Price, 200); eq(e.HauntedEgg.Unlock, 0)
	eq(e.PhantomEgg.Price, 1200); eq(e.PhantomEgg.Unlock, 10)
	eq(e.MoonlightEgg.Price, 5000); eq(e.MoonlightEgg.Unlock, 25)
	for id, pet in Config.Pets do
		eq(pet.Price, nil, id .. " is no longer sold directly")
	end
end

T.roll_boundaries = function()
	local egg = { Unlock = 0, Odds = { { Pet = "A", Chance = 40 }, { Pet = "B", Chance = 35 }, { Pet = "C", Chance = 25 } } }
	eq(Eggs.Roll(egg, 0), "A")
	eq(Eggs.Roll(egg, 0.3999), "A")
	eq(Eggs.Roll(egg, 0.4), "B")
	eq(Eggs.Roll(egg, 0.7499), "B")
	eq(Eggs.Roll(egg, 0.75), "C")
	eq(Eggs.Roll(egg, 1 - 1e-12), "C")
	for id, e in Config.Eggs do
		eq(Eggs.Roll(e, 0), e.Odds[1].Pet, id .. " r=0")
		eq(Eggs.Roll(e, 1 - 1e-12), e.Odds[#e.Odds].Pet, id .. " r~1")
	end
end

T.distribution_matches_odds = function()
	local N = 20000
	for id, egg in Config.Eggs do
		local counts = {}
		for i = 0, N - 1 do
			local p = Eggs.Roll(egg, (i + 0.5) / N)
			counts[p] = (counts[p] or 0) + 1
		end
		for _, o in egg.Odds do
			local pct = (counts[o.Pet] or 0) / N * 100
			assert(math.abs(pct - o.Chance) < 0.05, string.format("%s %s %.2f vs %d", id, o.Pet, pct, o.Chance))
		end
	end
	-- random sanity: rare pets stay rare
	math.randomseed(7)
	local phoenix = 0
	for _ = 1, 20000 do
		if Eggs.Roll(Config.Eggs.MoonlightEgg, math.random()) == "GhostPhoenix" then
			phoenix += 1
		end
	end
	assert(phoenix > 1700 and phoenix < 2300, "phoenix ~10%: " .. phoenix)
end

T.unlock_gates = function()
	local e = Config.Eggs
	assert(Eggs.Unlocked(e.HauntedEgg, 0))
	assert(not Eggs.Unlocked(e.PhantomEgg, 5))
	assert(Eggs.Unlocked(e.PhantomEgg, 10))
	assert(not Eggs.Unlocked(e.MoonlightEgg, 20))
	assert(Eggs.Unlocked(e.MoonlightEgg, 25))
	assert(Eggs.Unlocked(e.MoonlightEgg, 40))
end

T.request_ids = function()
	assert(Eggs.ValidRequestId("{8C1B2A3D-1111-2222-3333-444455556666}"))
	assert(Eggs.ValidRequestId("abc_1"))
	assert(not Eggs.ValidRequestId(""))
	assert(not Eggs.ValidRequestId(string.rep("a", 41)))
	assert(not Eggs.ValidRequestId("a b"))
	assert(not Eggs.ValidRequestId(5))
end

T.prune_keeps_newest = function()
	local recs = {}
	for i = 1, 25 do
		recs["r" .. i] = { Egg = "HauntedEgg", Pet = "GlowWisp", Uid = "p" .. i, T = 100 }
	end
	local drop = Eggs.Prune(recs, 20)
	eq(#drop, 5)
	local dropped = {}
	for _, id in drop do
		dropped[id] = true
	end
	for i = 1, 5 do
		assert(dropped["r" .. i], "oldest dropped r" .. i)
	end
	eq(#Eggs.Prune({ a = { Egg = "x", Pet = "y", Uid = "p1", T = 1 } }, 20), 0)
end

return T
