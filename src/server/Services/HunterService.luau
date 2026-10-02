--!strict
-- Hunter inventory, equipping and crate opening (server-authoritative rolls).
-- Replicates each player's crew to everyone through player attributes:
--   Crew = "HunterId,HunterId,..." (equipped order), CrewPower = number.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local HunterService = {}

local rng = Random.new()
local STATION_RANGE = 30

local function powerOf(id: string): number
	local h = Config.Hunters[id]
	return if h then h.Power else 0
end

local function rarityOrder(id: string): number
	local h = Config.Hunters[id]
	local r = h and Config.Rarities[h.Rarity]
	return if r then r.Order else 1
end
HunterService.PowerOf = powerOf
HunterService.RarityOrder = rarityOrder

local function countOwned(d: DataService.Data): number
	local n = 0
	for _ in d.Hunters do
		n += 1
	end
	return n
end

function HunterService.CrewPower(player: Player): number
	local d = DataService.Get(player)
	if not d then
		return 0
	end
	return Rules.CrewPower(d.Equipped, d.Hunters, powerOf)
end

-- Pushes the crew to attributes (for everyone's visuals) and re-syncs the owner.
function HunterService.Refresh(player: Player)
	local d = DataService.Get(player)
	if not d then
		return
	end
	local ids = {}
	for _, uid in d.Equipped do
		local h = d.Hunters[uid]
		if h then
			table.insert(ids, h.Id)
		end
	end
	player:SetAttribute("Crew", table.concat(ids, ","))
	player:SetAttribute("CrewPower", Rules.CrewPower(d.Equipped, d.Hunters, powerOf))
	DataService.Changed(player)
end

function HunterService.Add(player: Player, hunterId: string): (string?, boolean)
	local d = DataService.Get(player)
	if not d or not Config.Hunters[hunterId] then
		return nil, false
	end
	local uid = DataService.NewUid(d)
	d.Hunters[uid] = { Id = hunterId, Locked = false, T = os.time() }
	local isNew = not d.Discovered[hunterId]
	d.Discovered[hunterId] = true
	return uid, isNew
end

-- A profile with nothing equipped (new player) gets its best hunters equipped.
local function ensureEquipped(player: Player, d: DataService.Data)
	if #d.Equipped == 0 then
		d.Equipped = Rules.EquipBest(d.Hunters, powerOf, rarityOrder, PlayerInfo.Slots(player))
	end
end

local function crateRoll(player: Player, crate: Config.CrateDef): string
	return Rules.Roll(crate.Pool :: any, rarityOrder, PlayerInfo.LuckMultiplier(player), Config.LuckAffectsFromOrder, rng:NextNumber())
end

-- Opens one crate. `free` = paid by a free-crate token (daily day 7) instead of Ectoplasm.
local function openCrate(player: Player, crateId: any): any
	if type(crateId) ~= "string" then
		return Remotes.Fail("Bad crate")
	end
	local crate = Config.Crates[crateId]
	local d = DataService.Get(player)
	if not crate or not d then
		return Remotes.Fail("Bad crate")
	end
	if not d.Zones[crate.Zone] then
		return Remotes.Fail("Unlock this zone first!")
	end
	local station = Config.Layout.CrateStations[crateId]
	if not station or not Remotes.Near(player, station, STATION_RANGE) then
		return Remotes.Fail("Walk to the crate first!")
	end
	if countOwned(d) >= Config.Inventory.MaxHunters then
		return Remotes.Fail("Hunter storage full! Release some hunters.")
	end
	local usedFree = false
	if (d.FreeCrates[crateId] or 0) > 0 then
		d.FreeCrates[crateId] -= 1
		if d.FreeCrates[crateId] <= 0 then
			d.FreeCrates[crateId] = nil
		end
		usedFree = true
	elseif not DataService.Spend(player, crate.Price) then
		return Remotes.Fail("Not enough Ectoplasm!")
	end
	local hunterId = crateRoll(player, crate)
	local uid, isNew = HunterService.Add(player, hunterId)
	d.Stats.Crates += 1
	local def = Config.Hunters[hunterId]
	local rarity = Config.Rarities[def.Rarity]
	if rarity.Announce then
		Fx.AllExcept(player, "Announce", {
			Text = string.format("%s hatched a %s %s!", player.DisplayName, rarity.Name, string.upper(def.Name)),
			Color = def.Rarity,
		})
	end
	DataService.Changed(player)
	return { ok = true, Uid = uid, Hunter = hunterId, IsNew = isNew, Free = usedFree, Crate = crateId }
end

local function validUid(d: DataService.Data, uid: any): boolean
	return type(uid) == "string" and #uid < 20 and d.Hunters[uid] ~= nil
end

function HunterService.Init()
	DataService.AddDecorator(function(player, s)
		s.CrewPower = HunterService.CrewPower(player)
	end)

	Remotes.Register("OpenCrate", "OpenCrate", openCrate)

	Remotes.Register("Equip", "Inventory", function(player, uid)
		local d = DataService.Get(player)
		if not d or not validUid(d, uid) then
			return Remotes.Fail("Unknown hunter")
		end
		if table.find(d.Equipped, uid) then
			return { ok = true }
		end
		if #d.Equipped >= PlayerInfo.Slots(player) then
			return Remotes.Fail("All slots full! Unequip one first.")
		end
		table.insert(d.Equipped, uid)
		HunterService.Refresh(player)
		return { ok = true }
	end)

	Remotes.Register("Unequip", "Inventory", function(player, uid)
		local d = DataService.Get(player)
		if not d or not validUid(d, uid) then
			return Remotes.Fail("Unknown hunter")
		end
		local i = table.find(d.Equipped, uid)
		if not i then
			return { ok = true }
		end
		if #d.Equipped <= 1 then
			return Remotes.Fail("Keep at least one hunter equipped!")
		end
		table.remove(d.Equipped, i)
		HunterService.Refresh(player)
		return { ok = true }
	end)

	Remotes.Register("EquipBest", "Inventory", function(player)
		local d = DataService.Get(player)
		if not d then
			return Remotes.Fail("Loading...")
		end
		d.Equipped = Rules.EquipBest(d.Hunters, powerOf, rarityOrder, PlayerInfo.Slots(player))
		HunterService.Refresh(player)
		return { ok = true, Power = HunterService.CrewPower(player) }
	end)

	Remotes.Register("Lock", "Inventory", function(player, uid, locked)
		local d = DataService.Get(player)
		if not d or not validUid(d, uid) or type(locked) ~= "boolean" then
			return Remotes.Fail("Unknown hunter")
		end
		d.Hunters[uid].Locked = locked
		DataService.Changed(player)
		return { ok = true }
	end)

	-- Releases (deletes) unlocked, unequipped hunters for a small refund.
	Remotes.Register("Release", "Inventory", function(player, uids)
		local d = DataService.Get(player)
		if not d or type(uids) ~= "table" or #uids == 0 or #uids > Config.Inventory.MaxHunters then
			return Remotes.Fail("Nothing selected")
		end
		local refund = 0
		local released = 0
		local total = countOwned(d)
		for _, uid in uids do
			if total - released <= 1 then
				break
			end
			if validUid(d, uid) and not table.find(d.Equipped, uid) and not d.Hunters[uid].Locked then
				local def = Config.Hunters[d.Hunters[uid].Id]
				local crate = Config.Crates[(Config.ZoneById[def.Zone] :: Config.ZoneDef).Crate]
				refund += math.floor((if crate then crate.Price else 0) * Config.Inventory.ReleaseRefund)
				d.Hunters[uid] = nil
				released += 1
			end
		end
		if released == 0 then
			return Remotes.Fail("Can't release equipped or locked hunters")
		end
		if refund > 0 then
			DataService.AddEcto(player, refund)
		end
		DataService.Changed(player)
		Fx.Toast(player, string.format("Released %d hunter%s (+%s Ectoplasm)", released, if released == 1 then "" else "s", Format.Commas(refund)))
		return { ok = true, Released = released, Refund = refund }
	end)

	DataService.Loaded:Connect(function(player: Player)
		-- always work on the live profile (never a copy)
		local d = DataService.Get(player)
		if not d then
			return
		end
		if next(d.Hunters) == nil then
			HunterService.Add(player, Config.StarterHunter)
		end
		ensureEquipped(player, d)
		HunterService.Refresh(player)
	end)
end

function HunterService.Start()
	Players.PlayerRemoving:Connect(function(player)
		PlayerInfo.Forget(player)
	end)
end

return HunterService
