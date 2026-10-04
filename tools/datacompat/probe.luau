-- Save-compatibility test: feeds saves shaped like the ones live players have (older versions)
-- through the REAL DataService migration and checks nothing is lost or reset.
-- Run: bash tools/datacompat.sh
local okDS, DS = pcall(require, game:GetService("ServerScriptService").GHServer.Services.DataService)
if not okDS then print("  FAIL loading DataService: " .. tostring(DS)) print("datacompat: 1 failed") return end
local Config = require(game:GetService("ReplicatedStorage").GH.Config) :: any
local migrate = DS._Migrate
local fails = 0
local function check(cond: boolean, msg: string)
	if not cond then
		fails += 1
		print("  FAIL " .. msg)
	end
end

-- v1.0-era save: 3 areas, 5-level upgrades, old settings, receipts, an unknown key
local old = {
	Version = 1,
	Ecto = 123456,
	TotalEcto = 999999,
	Hunters = {
		["1"] = { Id = "RookieHunter", Locked = false, T = 1 },
		["2"] = { Id = "PhantomExorcist", Locked = true, T = 2 },
		["3"] = { Id = "VoidHunter", Locked = false, T = 3 },
		["9"] = { Id = "SomeRemovedHunter", Locked = false, T = 4 },
	},
	NextUid = 10,
	Equipped = { "2", "3", "1" },
	Discovered = { RookieHunter = true, PhantomExorcist = true, VoidHunter = true },
	Zones = { Neighborhood = true, Cemetery = true, School = true },
	Upgrades = { PickupRadius = 5, EctoBonus = 4, MoveSpeed = 3 },
	Daily = { Last = 1700000000, Streak = 5 },
	Boosts = { Luck = 1700000500 },
	FreeCrates = { Beginner = 1 },
	Settings = { Music = false, Sfx = true, FastReveal = true },
	Tutorial = 6,
	Stats = { Ghosts = 500, Crates = 40, Events = 2, Seconds = 9000 },
	Purchases = { "receipt-a", "receipt-b" },
	SomethingFromTheFuture = { x = 1 },
}
local d = migrate(old)
check(d.Ecto == 123456, "Ectoplasm kept")
check(d.TotalEcto == 999999, "TotalEcto kept (leaderboard)")
check(d.Hunters["1"] and d.Hunters["2"] and d.Hunters["3"], "hunters kept")
check(d.Hunters["2"].Locked == true, "locked flag kept")
check(d.Orphans["9"] ~= nil and d.Hunters["9"] == nil, "unknown hunter parked in Orphans, not deleted")
check(#d.Equipped == 3 and d.Equipped[1] == "2", "equipped kept in order")
check(d.NextUid >= 10, "uids never reused")
check(d.Discovered.PhantomExorcist == true, "index discoveries kept")
check(d.Zones.Cemetery and d.Zones.School and d.Zones.Neighborhood, "unlocked areas kept")
check(d.Zones.Carnival == nil, "nothing unlocked that wasn't")
check(d.Upgrades.PickupRadius == 5 and d.Upgrades.EctoBonus == 4 and d.Upgrades.MoveSpeed == 3, "upgrade levels kept")
check(d.Daily.Last == 1700000000 and d.Daily.Streak == 5, "daily streak kept")
check(d.Boosts.Luck == 1700000500, "boosts kept")
check(d.FreeCrates.Beginner == 1, "free crates kept")
check(d.Settings.Music == false and d.Settings.FastReveal == true, "settings kept")
check(d.Tutorial == 6, "tutorial progress kept")
check(d.Stats.Ghosts == 500 and d.Stats.Crates == 40, "stats kept")
check(#d.Purchases == 2 and d.Purchases[1] == "receipt-a", "purchase receipts kept")
check(d.SkipTokens == 0, "new SkipTokens field added as 0")
check(type(d.LuckyOpens) == "table" and next(d.LuckyOpens) == nil, "new LuckyOpens field added as {}")
check(d.Extra.SomethingFromTheFuture ~= nil, "unknown keys preserved in Extra")
check(d.Version == Config.DataSchemaVersion, "version stamped")

-- migrating twice changes nothing (servers re-load saved profiles all the time)
local d2 = migrate(d)
check(d2.Ecto == d.Ecto and d2.NextUid == d.NextUid and #d2.Equipped == #d.Equipped and d2.Orphans["9"] ~= nil, "idempotent")

-- a v1.3 save with SkipTokens and new areas keeps them
local newer = migrate({ Ecto = 5, Zones = { Neighborhood = true, Swamp = true }, SkipTokens = 3, Upgrades = { PickupRadius = 99 } })
check(newer.SkipTokens == 3, "skip tokens kept")
check(newer.Zones.Swamp == true, "late areas kept")
check(newer.Upgrades.PickupRadius == #Config.Upgrades.PickupRadius.Levels, "out-of-range upgrade clamped to max, not reset")

-- a new-format save re-saved by an OLDER server (rolling update) has SkipTokens parked in Extra
local hopped = migrate({ Ecto = 5, Extra = { SkipTokens = 4 } })
check(hopped.SkipTokens == 4 and hopped.Extra.SkipTokens == nil, "skip tokens restored from Extra after an old server")

-- v1.6: old saves get the new fields as safe defaults and keep everything else
check(d.Shards == 0, "new Shards field added as 0")
check(type(d.Pets) == "table" and next(d.Pets) == nil and #d.EquippedPets == 0, "no pets for old saves")
check(type(d.Knocked) == "table" and next(d.Knocked) == nil, "no knockouts for old saves")
check(d.TowerBest == 0 and d.TowerRuns == 0 and d.TowerShards == 0, "tower records start at 0")
check(type(d.EventPlay) == "table" and #d.TradesApplied == 0, "event/trade records start empty")
check(d.Hunters["2"].Tier == nil and d.Hunters["2"].Locked == true, "old hunters stay Normal tier and keep their lock")
check(d.Ecto == 123456 and d.TotalEcto == 999999, "currencies untouched by v1.6 fields")

-- a v1.6 save round-trips: tiers, knockouts, pets, shards, tower and event records
local v16 = migrate({
	Ecto = 10,
	Hunters = { ["1"] = { Id = "RookieHunter", Tier = 2 }, ["2"] = { Id = "RookieHunter", Tier = 9 }, ["3"] = { Id = "RookieHunter", Tier = "x" } },
	Equipped = { "1" },
	Knocked = { ["1"] = 1800000000, ["77"] = 1800000000, ["2"] = "soon" },
	Shards = 55.7,
	Pets = { p1 = { Id = "GlowWisp", T = 5 }, p4 = { Id = "RetiredPet", T = 6 }, bad = 5 },
	PetNextUid = 2,
	EquippedPets = { "p1", "p1", "p4", "nope" },
	TowerBest = 12, TowerRuns = 3, TowerRooms = 20, TowerShards = 140,
	EventPlay = { launch_rare_pet_1 = { S = 900, G = false }, junk = 3 },
	TradesApplied = { "t1", "t2", 5 },
})
check(v16.Hunters["1"].Tier == 2, "mega tier kept")
check(v16.Hunters["2"].Tier == Config.Merge.MaxTier, "out-of-range tier clamped, hunter kept")
check(v16.Hunters["3"] ~= nil and v16.Hunters["3"].Tier == nil, "bad tier value -> Normal, hunter kept")
check(v16.Knocked["1"] == 1800000000 and v16.Knocked["77"] == nil and v16.Knocked["2"] == nil, "knockout timers kept, junk dropped")
check(v16.Shards == 55, "shards kept (floored)")
check(v16.Pets.p1 ~= nil and v16.Pets.p4 ~= nil and v16.Pets.bad == nil, "pets kept (unknown pet ids kept too)")
check(#v16.EquippedPets == 1 and v16.EquippedPets[1] == "p1", "equipped pets de-duplicated and validated")
check(v16.PetNextUid == 5, "pet uids never reused")
check(v16.TowerBest == 12 and v16.TowerRuns == 3 and v16.TowerRooms == 20 and v16.TowerShards == 140, "tower records kept")
check(v16.EventPlay.launch_rare_pet_1.S == 900 and v16.EventPlay.launch_rare_pet_1.G == false and v16.EventPlay.junk == nil, "event progress kept")
check(#v16.TradesApplied == 2, "trade ids kept")
local v16b = migrate(v16)
check(v16b.Shards == 55 and v16b.Hunters["1"].Tier == 2 and #v16b.EquippedPets == 1 and v16b.PetNextUid == 5, "v1.6 migration idempotent")

-- a v1.6 save re-saved by a v1.5 server parks the new fields in Extra: they come back
local rolled = migrate({ Ecto = 1, Extra = { Shards = 30, Pets = { p1 = { Id = "BooBat", T = 1 } }, TowerBest = 4 } })
check(rolled.Shards == 30 and rolled.Pets.p1 ~= nil and rolled.TowerBest == 4, "v1.6 fields restored from Extra after an older server")

-- v1.7: checkpoint + variant discoveries + pet nicknames
check(d.TowerCheckpoint == 0 and type(d.Variants) == "table" and next(d.Variants) == nil, "v1.7 fields default for old saves")
check(d.Discovered.PhantomExorcist == true, "normal discoveries untouched")
local v17 = migrate({ Hunters = { ["1"] = { Id = "RookieHunter", Tier = 1 } }, TowerCheckpoint = 10, Variants = { ["VoidHunter:2"] = true, bad = 5 },
	Pets = { p1 = { Id = "BooBat", T = 1, Nick = "Spooky" }, p2 = { Id = "BooBat", T = 1, Nick = 7 } } })
check(v17.TowerCheckpoint == 10, "checkpoint kept")
check(v17.Variants["VoidHunter:2"] == true and v17.Variants.bad == nil, "variant discoveries kept, junk dropped")
check(v17.Variants["RookieHunter:1"] == true, "owned shiny backfilled as discovered")
check(v17.Pets.p1.Nick == "Spooky" and v17.Pets.p2.Nick == nil and v17.Pets.p2 ~= nil, "pet nicknames kept, bad nick dropped, pet kept")

-- garbage / missing data never crashes and gives a fresh profile
local blank = migrate(nil)
check(blank.Ecto == 0 and blank.Zones.Neighborhood == true, "empty save -> fresh profile")

print(string.format("datacompat: %d failed", fails))
