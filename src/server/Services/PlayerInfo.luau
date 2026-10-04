--!strict
-- Derived per-player numbers (slots, multipliers, radius) from data + game passes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)

local PlayerInfo = {}

-- Game passes owned this session (filled by ShopService).
local passes: { [Player]: { [string]: boolean } } = {}
-- Pass keys whose ownership Roblox couldn't confirm (check kept failing). They count as NOT owned
-- for gameplay, but the shop won't re-sell them and equipped slots are never trimmed for them.
local unknownPasses: { [Player]: { [string]: boolean } } = {}
-- Players whose first pass check has finished this session (until then every pass is unknown).
local passesChecked: { [Player]: boolean } = {}

function PlayerInfo.SetPass(player: Player, key: string, owned: boolean)
	passes[player] = passes[player] or {}
	passes[player][key] = owned
	local u = unknownPasses[player]
	if u then
		u[key] = nil -- a definite answer replaces "unknown"
	end
end

function PlayerInfo.SetPassUnknown(player: Player, key: string)
	if not player.Parent then
		return
	end
	unknownPasses[player] = unknownPasses[player] or {}
	unknownPasses[player][key] = true
end

function PlayerInfo.SetPassesChecked(player: Player)
	if player.Parent then
		passesChecked[player] = true
	end
end

-- True while this pass's ownership isn't known yet (first check still running, or it failed).
function PlayerInfo.PassUnknown(player: Player, key: string): boolean
	if not passesChecked[player] then
		return true
	end
	local u = unknownPasses[player]
	return u ~= nil and u[key] == true
end

function PlayerInfo.HasUnknownPasses(player: Player): boolean
	local u = unknownPasses[player]
	return u ~= nil and next(u) ~= nil
end

function PlayerInfo.HasPass(player: Player, key: string): boolean
	local p = passes[player]
	return p ~= nil and p[key] == true
end

-- Global Ectoplasm multiplier (2X ECTOPLASM event, set by GlobalEventService; 1 = off).
local globalEcto = 1
function PlayerInfo.SetGlobalEctoMultiplier(m: number)
	globalEcto = m
end

-- Server-wide luck (Robux product): os.time() expiry, shared by everyone in this server.
local serverLuckUntil = 0

function PlayerInfo.ServerLuckUntil(): number
	return serverLuckUntil
end

-- uncapped = a paid (Robux) grant: never throw bought time away, even past the usual cap
function PlayerInfo.AddServerLuck(seconds: number, uncapped: boolean?)
	local now = os.time()
	local total = math.max(serverLuckUntil, now) + seconds
	serverLuckUntil = if uncapped then total else math.min(total, now + Config.ServerLuck.MaxStackSeconds)
end

-- AUTO OPEN pass, or the legacy (hidden, no longer sold) Auto Attack pass: Auto Attack itself is
-- free for everyone now, so its old buyers get Auto Open instead
function PlayerInfo.HasAutoOpen(player: Player): boolean
	return PlayerInfo.HasPass(player, Config.AutoOpen.Pass)
		or (Config.LegacyAutoAttackGrantsAutoOpen and PlayerInfo.HasPass(player, "AutoAttack"))
end

function PlayerInfo.HasPermanentSkip(player: Player): boolean
	return PlayerInfo.HasPass(player, Config.CrateSkip.Pass)
end

function PlayerInfo.Forget(player: Player)
	passes[player] = nil
	unknownPasses[player] = nil
	passesChecked[player] = nil
end

local function passDef(key: string): Config.PassDef?
	for _, p in Config.GamePasses do
		if p.Key == key then
			return p
		end
	end
	return nil
end

function PlayerInfo.Slots(player: Player): number
	local extra = 0
	local def = passDef("ExtraSlots")
	if def and PlayerInfo.HasPass(player, "ExtraSlots") then
		extra = def.Slots or 0
	end
	return Config.Inventory.BaseSlots + extra
end

function PlayerInfo.BoostActive(d: DataService.Data, boost: string): boolean
	local t = d.Boosts[boost]
	return t ~= nil and t > os.time()
end

-- uncapped = a paid (Robux) grant: never throw bought time away, even past the usual cap
function PlayerInfo.AddBoost(d: DataService.Data, boost: string, seconds: number, uncapped: boolean?)
	local now = os.time()
	local cur = math.max(d.Boosts[boost] or 0, now)
	d.Boosts[boost] = if uncapped then cur + seconds else math.min(cur + seconds, now + Config.Boosts.MaxStackSeconds)
end

-- Bonuses from the player's EQUIPPED ghost pets: { Power, Ecto, HP, Recovery } fractions.
-- Computed from the saved equipped list every time (never accumulated), so re-equipping,
-- reconnecting or respawning can't stack a bonus twice.
function PlayerInfo.PetBonuses(player: Player): { [string]: number }
	local d = DataService.Get(player)
	if not d then
		return {}
	end
	local list = {}
	local seen = {}
	for _, uid in d.EquippedPets do
		local pet = d.Pets[uid]
		local def = pet and Config.Pets[pet.Id]
		if def and not seen[uid] and #list < Config.PetRules.MaxEquipped then
			seen[uid] = true
			table.insert(list, def.Bonus)
		end
	end
	return Rules.PetBonuses(list, Config.PetRules.Caps)
end

function PlayerInfo.PetBonus(player: Player, kind: string): number
	return PlayerInfo.PetBonuses(player)[kind] or 0
end

function PlayerInfo.EctoMultiplier(player: Player): number
	local d = DataService.Get(player)
	if not d then
		return 1
	end
	local up = Config.Upgrades.EctoBonus
	local bonus = Rules.UpgradeValue(up.Levels, d.Upgrades.EctoBonus or 1)
	local passMul = 1
	local def = passDef("DoubleEcto")
	if def and PlayerInfo.HasPass(player, "DoubleEcto") then
		passMul = def.Multiplier or 1
	end
	local vip = passDef("VIP")
	if vip and PlayerInfo.HasPass(player, "VIP") then
		passMul *= vip.Multiplier or 1
	end
	-- FinalReward = BaseGhostReward * this (upgrades, boost, passes, global event)
	return Rules.EctoMultiplier(bonus, PlayerInfo.BoostActive(d, "Ecto"), Config.Boosts.Ecto.Multiplier, passMul)
		* globalEcto
		* (1 + PlayerInfo.PetBonus(player, "Ecto"))
end

function PlayerInfo.LuckMultiplier(player: Player): number
	local d = DataService.Get(player)
	local m = 1
	if d and PlayerInfo.BoostActive(d, "Luck") then
		m *= Config.Boosts.Luck.Multiplier
	end
	local lucky = passDef("LuckyHunter")
	if lucky and PlayerInfo.HasPass(player, "LuckyHunter") then
		m *= lucky.Multiplier or 1
	end
	if serverLuckUntil > os.time() then
		m *= Config.ServerLuck.Multiplier
	end
	return m
end

function PlayerInfo.MaxHunters(player: Player): number
	local def = passDef("Storage")
	if def and PlayerInfo.HasPass(player, "Storage") then
		return Config.Inventory.MaxHunters + (def.Storage or 0)
	end
	return Config.Inventory.MaxHunters
end

function PlayerInfo.PickupRadius(player: Player): number
	local d = DataService.Get(player)
	local lv = if d then d.Upgrades.PickupRadius or 1 else 1
	local r = Rules.UpgradeValue(Config.Upgrades.PickupRadius.Levels, lv)
	local magnet = passDef("SuperMagnet")
	if magnet and PlayerInfo.HasPass(player, "SuperMagnet") then
		r *= magnet.Multiplier or 1
	end
	return r
end

function PlayerInfo.WalkSpeed(player: Player): number
	local d = DataService.Get(player)
	local lv = if d then d.Upgrades.MoveSpeed or 1 else 1
	return Rules.UpgradeValue(Config.Upgrades.MoveSpeed.Levels, lv)
end

-- Index (1-based) of the furthest unlocked zone, used to scale flat rewards.
function PlayerInfo.BestZone(player: Player): number
	local d = DataService.Get(player)
	local best = 1
	if d then
		for i, z in Config.Zones do
			if d.Zones[z.Id] then
				best = math.max(best, i)
			end
		end
	end
	return best
end

function PlayerInfo.ZoneMultiplier(player: Player): number
	local m = Config.Daily.ZoneMultiplier
	return m[math.min(PlayerInfo.BestZone(player), #m)]
end

function PlayerInfo.Init()
	DataService.AddDecorator(function(player, s)
		s.Slots = PlayerInfo.Slots(player)
		s.EctoMultiplier = PlayerInfo.EctoMultiplier(player)
		s.LuckMultiplier = PlayerInfo.LuckMultiplier(player)
		-- luck without the timed boost (pass, Server Luck): the crate panel adds the boost itself
		local dd = DataService.Get(player)
		s.LuckOther = s.LuckMultiplier / (if dd and PlayerInfo.BoostActive(dd, "Luck") then Config.Boosts.Luck.Multiplier else 1)
		s.PickupRadius = PlayerInfo.PickupRadius(player)
		s.ZoneMultiplier = PlayerInfo.ZoneMultiplier(player)
		s.MaxHunters = PlayerInfo.MaxHunters(player)
		s.ServerLuckUntil = serverLuckUntil
		s.PetBonuses = PlayerInfo.PetBonuses(player)
		local owned = {}
		for _, p in Config.GamePasses do
			owned[p.Key] = PlayerInfo.HasPass(player, p.Key)
		end
		owned[Config.AutoOpen.Pass] = PlayerInfo.HasAutoOpen(player)
		s.Passes = owned
	end)
end

return PlayerInfo
