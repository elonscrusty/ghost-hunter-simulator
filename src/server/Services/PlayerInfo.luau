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

function PlayerInfo.SetPass(player: Player, key: string, owned: boolean)
	passes[player] = passes[player] or {}
	passes[player][key] = owned
end

function PlayerInfo.HasPass(player: Player, key: string): boolean
	local p = passes[player]
	return p ~= nil and p[key] == true
end

function PlayerInfo.Forget(player: Player)
	passes[player] = nil
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

function PlayerInfo.AddBoost(d: DataService.Data, boost: string, seconds: number)
	local now = os.time()
	local cur = math.max(d.Boosts[boost] or 0, now)
	d.Boosts[boost] = math.min(cur + seconds, now + Config.Boosts.MaxStackSeconds)
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
	return Rules.EctoMultiplier(bonus, PlayerInfo.BoostActive(d, "Ecto"), Config.Boosts.Ecto.Multiplier, passMul)
end

function PlayerInfo.LuckMultiplier(player: Player): number
	local d = DataService.Get(player)
	if d and PlayerInfo.BoostActive(d, "Luck") then
		return Config.Boosts.Luck.Multiplier
	end
	return 1
end

function PlayerInfo.PickupRadius(player: Player): number
	local d = DataService.Get(player)
	local lv = if d then d.Upgrades.PickupRadius or 1 else 1
	return Rules.UpgradeValue(Config.Upgrades.PickupRadius.Levels, lv)
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
		s.PickupRadius = PlayerInfo.PickupRadius(player)
		s.ZoneMultiplier = PlayerInfo.ZoneMultiplier(player)
		local owned = {}
		for _, p in Config.GamePasses do
			owned[p.Key] = PlayerInfo.HasPass(player, p.Key)
		end
		s.Passes = owned
	end)
end

return PlayerInfo
