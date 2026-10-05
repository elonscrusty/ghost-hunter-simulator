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
	assert(Eggs.Hatchable(Config.Eggs, "GlowWisp") and not Eggs.Hatchable(Config.Eggs, "LanternSpirit"), "event pets aren't hatchable")
	for _, id in Config.EggOrder do
		assert(Config.Eggs[id], "EggOrder " .. id)
	end
end

T.design_numbers = function()
	local e = Config.Eggs
	eq(e.HauntedEgg.Price, 200); eq(e.HauntedEgg.Unlock, 0)
	eq(e.PhantomEgg.Price, 1200); eq(e.PhantomEgg.Unlock, 10)
	eq(e.MoonlightEgg.Price, 5000); eq(e.MoonlightEgg.Unlock, 25)
	eq(e.CursedEgg.Price, 20000); eq(e.CursedEgg.Unlock, 50)
	local want = {
		GhostPhoenix = 35, CrystalSkull = 35, PhantomKing = 12.5, GhostCarousel = 12.5,
		GhostMusicBox = 2.25, GhostShipBottle = 2.25, GhostBalloonRide = 0.5,
	}
	local n = 0
	for _, o in e.CursedEgg.Odds do
		n += 1
		eq(o.Chance, want[o.Pet], "CursedEgg " .. o.Pet)
	end
	eq(n, 7, "CursedEgg pet count")
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
			assert(math.abs(pct - o.Chance) < 0.05, string.format("%s %s %.2f vs %g", id, o.Pet, pct, o.Chance))
		end
	end
	-- random sanity: Legendary pets stay rare (Moonlight Egg: 10% in total)
	math.randomseed(7)
	local legendary = 0
	for _ = 1, 20000 do
		local pet = Config.Pets[Eggs.Roll(Config.Eggs.MoonlightEgg, math.random())]
		if pet.Rarity == "Legendary" then
			legendary += 1
		end
	end
	assert(legendary > 1700 and legendary < 2300, "legendary ~10%: " .. legendary)
end

-- fractional chances: the cumulative sums land exactly on the boundaries
T.fractional_roll_boundaries = function()
	local egg = Config.Eggs.CursedEgg
	eq(Eggs.Roll(egg, 0.6999), "CrystalSkull")
	eq(Eggs.Roll(egg, 0.70), "PhantomKing")
	eq(Eggs.Roll(egg, 0.8249), "PhantomKing")
	eq(Eggs.Roll(egg, 0.825), "GhostCarousel")
	eq(Eggs.Roll(egg, 0.9499), "GhostCarousel")
	eq(Eggs.Roll(egg, 0.95), "GhostMusicBox")
	eq(Eggs.Roll(egg, 0.9725), "GhostShipBottle")
	eq(Eggs.Roll(egg, 0.9949), "GhostShipBottle")
	eq(Eggs.Roll(egg, 0.995), "GhostBalloonRide")
	eq(Eggs.Roll(egg, 1 - 1e-12), "GhostBalloonRide")
end

-- every pet rarity exists (Mythic/Secret/Ultra pets show like the others)
T.pet_rarities_known = function()
	for id, pet in Config.Pets do
		assert(Config.Rarities[pet.Rarity], id .. " rarity " .. pet.Rarity)
	end
end

T.unlock_gates = function()
	local e = Config.Eggs
	assert(Eggs.Unlocked(e.HauntedEgg, 0))
	assert(not Eggs.Unlocked(e.PhantomEgg, 5))
	assert(Eggs.Unlocked(e.PhantomEgg, 10))
	assert(not Eggs.Unlocked(e.MoonlightEgg, 20))
	assert(Eggs.Unlocked(e.MoonlightEgg, 25))
	assert(Eggs.Unlocked(e.MoonlightEgg, 40))
	assert(not Eggs.Unlocked(e.CursedEgg, 49))
	assert(Eggs.Unlocked(e.CursedEgg, 50))
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

T.every_pet_obtainable = function()
	local inEgg = {}
	for _, egg in Config.Eggs do
		for _, o in egg.Odds do
			inEgg[o.Pet] = true
		end
	end
	for id in Config.Pets do
		assert(inEgg[id] or id == Config.RarePetEvent.Pet, id .. " is in no egg and is not the event pet")
	end
	assert(Config.Pets[Config.RarePetEvent.Pet], "event pet exists")
	-- the Cursed Egg's own pets are in that egg only
	for _, id in { "PhantomKing", "GhostCarousel", "GhostMusicBox", "GhostShipBottle", "GhostBalloonRide" } do
		local eggsWith = 0
		for _, egg in Config.Eggs do
			for _, o in egg.Odds do
				eggsWith += if o.Pet == id then 1 else 0
			end
		end
		eq(eggsWith, 1, id .. " egg count")
	end
	-- PetOrder (Index, dev tools) lists every pet exactly once; ids match their keys
	local seen, n = {}, 0
	for _, id in Config.PetOrder do
		assert(Config.Pets[id] and not seen[id], "PetOrder " .. id)
		seen[id] = true
	end
	for id, pet in Config.Pets do
		n += 1
		eq(pet.Id, id, "pet id")
	end
	eq(#Config.PetOrder, n, "PetOrder lists every pet")
	-- egg prices rise in EggOrder
	local prevPrice = 0
	for _, id in Config.EggOrder do
		assert(Config.Eggs[id].Price > prevPrice, id .. " price order")
		prevPrice = Config.Eggs[id].Price
	end
end

return T
