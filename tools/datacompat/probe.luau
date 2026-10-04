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
check(d.Settings.Tour == false, "menu tour not forced on saves from before it existed")
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
check(newer.Upgrades.PickupRadius == #Config.Upgrades.PickupRadius.Levels, "out-of-range upgrade clamped to max for use, not reset")
check(newer.Extra._over.Upgrades.PickupRadius.v == 99, "out-of-range upgrade level kept in Extra")

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

-- rolling update: a profile saved by a NEWER schema is refused (never loaded or saved here)
local V = Config.DataSchemaVersion
check(DS._TooNew({ Version = V + 1, Ecto = 5 }) == true, "newer schema version refused")
check(DS._TooNew({ Version = V }) == false and DS._TooNew({ Ecto = 5 }) == false and DS._TooNew(nil) == false, "current/old/missing version accepted")
check(DS._TooNew({ Version = 0 / 0 }) == false, "NaN version is not 'newer'")
check(migrate({ Version = V - 1 }).Version == V, "older version stamped up to the current one")

-- NaN / inf / negative numbers become safe values; wrong types are kept in Extra
local nan, inf = 0 / 0, math.huge
local bad = migrate({
	Ecto = -50, TotalEcto = inf, SkipTokens = nan, Tutorial = nan, NextUid = inf, PetNextUid = nan,
	Stats = { Ghosts = nan, Crates = inf, Events = 2, Seconds = -inf }, Daily = { Last = inf, Streak = nan },
	Boosts = { Luck = nan, Ecto = 1800000000 }, FreeCrates = { Beginner = inf, Other = 2 },
	Shards = inf, TowerBest = nan, Hunters = { ["4"] = { Id = "RookieHunter", Tier = nan } },
	Knocked = { ["4"] = inf }, Pets = { p2 = { Id = "BooBat", T = nan } },
})
local function fin(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) ~= math.huge
end
check(bad.Ecto == 0 and bad.TotalEcto == 0 and bad.SkipTokens == 0 and fin(bad.Tutorial), "bad currencies -> 0")
check(fin(bad.NextUid) and bad.NextUid >= 5 and fin(bad.PetNextUid) and bad.PetNextUid >= 3, "bad uid counters -> above existing uids")
check(bad.Stats.Ghosts == 0 and bad.Stats.Crates == 0 and bad.Stats.Events == 2 and bad.Stats.Seconds == 0, "bad stats -> 0, good kept")
check(fin(bad.Daily.Last) and fin(bad.Daily.Streak), "bad daily -> finite")
check(bad.Boosts.Luck == nil and bad.Boosts.Ecto == 1800000000, "bad boost dropped, good kept")
check(bad.FreeCrates.Beginner == nil and bad.FreeCrates.Other == 2, "bad free crate count dropped, good kept")
check(bad.Shards == 0 and bad.TowerBest == 0 and bad.Hunters["4"] ~= nil and bad.Hunters["4"].Tier == nil, "bad shards/tower/tier -> 0, hunter kept")
check(bad.Knocked["4"] == nil and bad.Pets.p2 ~= nil and bad.Pets.p2.T == 0, "bad knockout dropped, pet kept")
local loopy = migrate({ Hunters = { ["1"] = { Id = "RookieHunter" } } })
loopy.NextUid = inf
local newUid = DS.NewUid(loopy)
check(newUid == "2" and loopy.Hunters[newUid] == nil and fin(loopy.NextUid), "NewUid recovers from an infinite NextUid")
local typed = migrate({ Ecto = "lots", Hunters = 5, Settings = "x", Version = "2" })
check(typed.Extra._bad_Ecto == "lots" and typed.Extra._bad_Hunters == 5 and typed.Extra._bad_Settings == "x", "wrong-type fields kept in Extra")
check(typed.Ecto == 0 and next(typed.Hunters) == nil and typed.Settings.Sfx == true and typed.Version == V, "wrong-type fields reset to defaults")
check(migrate({ Ecto = 12.5 }).Ecto == 12.5, "fractional Ectoplasm kept")

-- values above this version's caps are clamped where used but the originals are kept
local upMax = #Config.Upgrades.PickupRadius.Levels
local capped = migrate({
	Upgrades = { PickupRadius = upMax + 2 },
	LuckyOpens = { Beginner = Config.LuckyOpens.MaxStack + 10, Other = 3 },
	Hunters = { ["1"] = { Id = "RookieHunter", Tier = Config.Merge.MaxTier + 1, NoRefund = true, Dev = true } },
	Settings = { Music = false, FromTheFuture = true },
	Pets = { p1 = { Id = "BooBat", T = 1, Nick = string.rep("a", 60) } },
})
check(capped.Upgrades.PickupRadius == upMax and capped.LuckyOpens.Beginner == Config.LuckyOpens.MaxStack and capped.LuckyOpens.Other == 3, "over-cap upgrade/lucky opens clamped for use")
check(capped.Hunters["1"].Tier == Config.Merge.MaxTier and capped.Hunters["1"].NoRefund == true and capped.Hunters["1"].Dev == true, "over-cap tier clamped, extra hunter fields kept")
check(capped.Settings.FromTheFuture == nil and capped.Settings.Music == false and capped.Pets.p1.Nick == nil and capped.Pets.p1 ~= nil, "unknown setting / long nick not used here")
local o = capped.Extra._over
check(o ~= nil and o.Upgrades.PickupRadius.v == upMax + 2 and o.LuckyOpens.Beginner.v == Config.LuckyOpens.MaxStack + 10, "over-cap originals kept in Extra")
check(o ~= nil and o.Tier["1"].v == Config.Merge.MaxTier + 1 and o.Settings.FromTheFuture == true and #o.Nick.p1 == 60, "tier/setting/nick originals kept in Extra")
local again = migrate(capped)
check(again.Extra._over ~= nil and again.Extra._over.Tier["1"].v == Config.Merge.MaxTier + 1 and again.Upgrades.PickupRadius == upMax, "kept originals survive another load")
-- a version with higher caps gets the originals back (unless the value changed in between)
again.LuckyOpens.Other = nil
local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end
local spent = migrate(copy(again)) -- migrate reuses the saved tables: keep `again` untouched
spent.LuckyOpens.Beginner = 5
local oldTier, oldStack, oldLevels = Config.Merge.MaxTier, Config.LuckyOpens.MaxStack, Config.Upgrades.PickupRadius.Levels
Config.Merge.MaxTier = oldTier + 5
Config.LuckyOpens.MaxStack = oldStack + 100
local more = table.clone(oldLevels)
for _ = 1, 5 do
	table.insert(more, oldLevels[#oldLevels])
end
Config.Upgrades.PickupRadius.Levels = more
local raised = migrate(again)
local raisedSpent = migrate(spent)
Config.Merge.MaxTier, Config.LuckyOpens.MaxStack, Config.Upgrades.PickupRadius.Levels = oldTier, oldStack, oldLevels
check(raised.Upgrades.PickupRadius == upMax + 2 and raised.LuckyOpens.Beginner == oldStack + 10 and raised.Hunters["1"].Tier == oldTier + 1, "originals restored when the cap allows")
check(raised.Extra._over == nil or (raised.Extra._over.Tier == nil and raised.Extra._over.Upgrades == nil), "restored originals leave Extra")
check(raisedSpent.LuckyOpens.Beginner == 15, "spent lucky opens keep their parked surplus (5 left + 10 parked)")

-- uid tables saved as arrays (number keys) get string keys; nothing lost on a clash
local arr = migrate({
	Hunters = { [1] = { Id = "RookieHunter" }, [2] = { Id = "VoidHunter" }, [7] = { Id = "RookieHunter", Locked = true }, ["7"] = { Id = "VoidHunter" } },
	Discovered = { [3] = true, RookieHunter = true }, Equipped = { "1", "2" }, NextUid = 3,
})
check(arr.Hunters["1"] ~= nil and arr.Hunters["2"] ~= nil and arr.Hunters[1 :: any] == nil, "numeric hunter keys converted to strings")
local n7 = 0
for _, h in arr.Hunters do
	if h.Id == "RookieHunter" and h.Locked == true then
		n7 += 1
	end
end
check(n7 == 1 and arr.Hunters["7"].Id == "VoidHunter", "clashing numeric hunter kept under a new uid")
check(#arr.Equipped == 2 and arr.NextUid > 8, "equipped kept, uids above every hunter")
check(arr.Discovered["3"] == true and arr.Discovered.RookieHunter == true, "numeric discovery keys converted")

-- garbage / missing data never crashes and gives a fresh profile
local blank = migrate(nil)
check(blank.Ecto == 0 and blank.Zones.Neighborhood == true, "empty save -> fresh profile")

print(string.format("datacompat: %d failed", fails))
