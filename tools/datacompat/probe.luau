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

-- garbage / missing data never crashes and gives a fresh profile
local blank = migrate(nil)
check(blank.Ecto == 0 and blank.Zones.Neighborhood == true, "empty save -> fresh profile")

print(string.format("datacompat: %d failed", fails))
