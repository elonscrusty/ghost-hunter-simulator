--!strict
-- Hunter inventory, equipping and crate opening (server-authoritative rolls).
-- Replicates each player's crew to everyone through player attributes:
--   Crew = "HunterId|tier|uid,..." (equipped hunters that can fight, in order), CrewPower = number.
-- v1.6: hunter tiers (Normal / Shiny / Mega), knockouts (d.Knocked, real-time timers), merging,
-- and a per-player "busy" registry so one hunter can't be merged, traded or released at once.
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
-- player -> token of their running Auto Open loop (a new token stops the old loop)
local autoOpen: { [Player]: {} } = {}
-- player -> os.clock() before which their Auto Open may not open again (OFF/ON spam can't speed it up)
local autoNext: { [Player]: number } = {}
HunterService.GrantExclusive = nil :: any

local rng = Random.new()
local STATION_RANGE = 30

local function powerOf(id: string, tier: number?): number
	local h = Config.Hunters[id]
	local t = Config.Tiers[tier or 0] or Config.Tiers[0]
	return if h then Rules.HunterPower(h.Power, t.Mult) else 0
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

-- player -> uid -> reason ("In a trade", ...) while another system holds that hunter
local busy: { [Player]: { [string]: string } } = {}

function HunterService.SetBusy(player: Player, uid: string, reason: string?)
	local b = busy[player]
	if not b then
		if reason == nil or not player.Parent then
			return -- nothing to clear / player already left (never re-create their entry)
		end
		b = {}
		busy[player] = b
	end
	(b :: { [string]: string? })[uid] = reason
end

function HunterService.BusyReason(player: Player, uid: string): string?
	local b = busy[player]
	return if b then b[uid] else nil
end

function HunterService.IsKnocked(d: DataService.Data, uid: string): boolean
	local t = d.Knocked[uid]
	return t ~= nil and t > os.time()
end

-- Equipped hunters that can fight right now (not knocked out), in equipped order.
function HunterService.ActiveUids(player: Player): { string }
	local d = DataService.Get(player)
	local out = {}
	if d then
		for _, uid in d.Equipped do
			if d.Hunters[uid] and not HunterService.IsKnocked(d, uid) then
				table.insert(out, uid)
			end
		end
	end
	return out
end

function HunterService.HunterPower(player: Player, uid: string): number
	local d = DataService.Get(player)
	local h = d and d.Hunters[uid]
	return if h then powerOf(h.Id, h.Tier) else 0
end

-- Damage per second of the player's crew: hunters that can fight (+ pet Power bonus).
function HunterService.CrewPower(player: Player): number
	local d = DataService.Get(player)
	if not d then
		return 0
	end
	local base = Rules.CrewPower(HunterService.ActiveUids(player), d.Hunters, powerOf)
	return base * (1 + PlayerInfo.PetBonus(player, "Power"))
end

-- Pushes the crew to attributes (for everyone's visuals) and re-syncs the owner.
function HunterService.Refresh(player: Player)
	local d = DataService.Get(player)
	if not d then
		return
	end
	local ids = {}
	for _, uid in HunterService.ActiveUids(player) do
		local h = d.Hunters[uid]
		table.insert(ids, string.format("%s|%d|%s", h.Id, h.Tier or 0, uid))
	end
	player:SetAttribute("Crew", table.concat(ids, ","))
	player:SetAttribute("CrewPower", HunterService.CrewPower(player))
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
-- hunters that can fight (EQUIP BEST skips knocked-out ones)
local function fitHunters(d: DataService.Data): { [string]: DataService.HunterRecord }
	local out = {}
	for uid, h in d.Hunters do
		if not HunterService.IsKnocked(d, uid) then
			out[uid] = h
		end
	end
	return out
end

local function ensureEquipped(player: Player, d: DataService.Data)
	if #d.Equipped == 0 then
		d.Equipped = Rules.EquipBest(fitHunters(d), powerOf, rarityOrder, PlayerInfo.Slots(player))
		if #d.Equipped == 0 then
			d.Equipped = Rules.EquipBest(d.Hunters, powerOf, rarityOrder, PlayerInfo.Slots(player))
		end
	end
	-- lost the extra-slots pass: keep only as many equipped as there are slots
	while #d.Equipped > PlayerInfo.Slots(player) do
		table.remove(d.Equipped)
	end
end

function HunterService.EnsureEquipped(player: Player)
	local d = DataService.Get(player)
	if d then
		ensureEquipped(player, d)
	end
end

-- Ectoplasm price of the crate a hunter comes from (release refund / merge cost base).
local function cratePrice(id: string): number
	local def = Config.Hunters[id]
	local zone = def and Config.ZoneById[def.Zone]
	local crate = zone and Config.Crates[zone.Crate]
	return if crate then crate.Price else 0
end
HunterService.CratePrice = cratePrice

local function crateRoll(player: Player, crate: Config.CrateDef, extraLuck: number): string
	return Rules.Roll(crate.Pool :: any, rarityOrder, PlayerInfo.LuckMultiplier(player) * extraLuck, Config.LuckAffectsFromOrder, rng:NextNumber())
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
	if countOwned(d) >= PlayerInfo.MaxHunters(player) then
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
	-- a bought Lucky Open for this crate is used up by this (paid or free) open
	local lucky = (d.LuckyOpens[crateId] or 0) > 0
	if lucky then
		d.LuckyOpens[crateId] -= 1
		if d.LuckyOpens[crateId] <= 0 then
			d.LuckyOpens[crateId] = nil
		end
	end
	local hunterId = crateRoll(player, crate, if lucky then Config.LuckyOpens.Multiplier else 1)
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
	return { ok = true, Uid = uid, Hunter = hunterId, IsNew = isNew, Free = usedFree, Crate = crateId, Lucky = lucky }
end

local function validUid(d: DataService.Data, uid: any): boolean
	return type(uid) == "string" and #uid < 20 and d.Hunters[uid] ~= nil
end

function HunterService.Init()
	DataService.AddDecorator(function(player, s)
		s.CrewPower = HunterService.CrewPower(player)
	end)

	-- (crateId, count?): count 3 only with the Triple Open pass; stops early when money or storage
	-- runs out. Returns the first result plus `More` = the extra results.
	Remotes.Register("OpenCrate", "OpenCrate", function(player, crateId, count)
		local n = if count == Config.TripleOpen.Count and PlayerInfo.HasPass(player, Config.TripleOpen.Pass) then count else 1
		local first = openCrate(player, crateId)
		if not first.ok or n == 1 then
			return first
		end
		local more = {}
		for _ = 2, n do
			local r = openCrate(player, crateId)
			if not r.ok then
				break
			end
			table.insert(more, { Uid = r.Uid, Hunter = r.Hunter, IsNew = r.IsNew })
		end
		first.More = more
		return first
	end)

	-- LUCKY OPENS: pay Ectoplasm (crate price x PriceMultiplier) for the next few opens of this
	-- crate at higher luck. Bound to the crate, so cheap crates can't buy luck for expensive ones.
	Remotes.Register("BuyLuckyOpens", "Default", function(player, crateId)
		if type(crateId) ~= "string" then
			return Remotes.Fail("Bad crate")
		end
		local crate = Config.Crates[crateId]
		local d = DataService.Get(player)
		if not crate or not d or not Config.Layout.CrateStations[crateId] then
			return Remotes.Fail("Bad crate")
		end
		if not d.Zones[crate.Zone] then
			return Remotes.Fail("Unlock this zone first!")
		end
		local L = Config.LuckyOpens
		local have = d.LuckyOpens[crateId] or 0
		if have + L.Opens > L.MaxStack then
			return Remotes.Fail("You already have plenty of lucky opens for this crate!")
		end
		if not DataService.Spend(player, crate.Price * L.PriceMultiplier) then
			return Remotes.Fail("Not enough Ectoplasm!")
		end
		d.LuckyOpens[crateId] = have + L.Opens
		DataService.Changed(player)
		return { ok = true, Left = d.LuckyOpens[crateId] }
	end)

	-- CRATE SKIP: the reveal is client-side only (the hunter is already rolled and saved), so a
	-- skip never touches the reward. Permanent Crate Skip owners skip for free; otherwise one
	-- bought Single Crate Skip token is used.
	Remotes.Register("UseSkip", "Default", function(player)
		local d = DataService.Get(player)
		if not d then
			return Remotes.Fail("Loading...")
		end
		if PlayerInfo.HasPermanentSkip(player) then
			return { ok = true, Permanent = true }
		end
		if (d.SkipTokens or 0) > 0 then
			d.SkipTokens -= 1
			DataService.Changed(player)
			return { ok = true, Left = d.SkipTokens }
		end
		return { ok = false, err = "NeedSkip" }
	end)

	-- AUTO OPEN (game pass): one server loop per player re-opens the chosen crate through the
	-- normal openCrate checks (zone, distance, price, storage), so it can't bypass anything or
	-- run twice at once. Stops on OFF, failure, leaving, or when the pass is missing.
	Remotes.Register("AutoOpen", "Default", function(player, crateId)
		if crateId == nil or crateId == false then
			autoOpen[player] = nil
			player:SetAttribute("AutoOpen", nil)
			return { ok = true, On = false }
		end
		if not PlayerInfo.HasAutoOpen(player) then
			return Remotes.Fail("NeedPass")
		end
		if type(crateId) ~= "string" or not Config.Crates[crateId] or not Config.Layout.CrateStations[crateId] then
			return Remotes.Fail("Bad crate")
		end
		local token = {}
		autoOpen[player] = token
		player:SetAttribute("AutoOpen", crateId)
		task.spawn(function()
			local waitLeft = (autoNext[player] or 0) - os.clock()
			if waitLeft > 0 then
				task.wait(waitLeft)
			end
			while autoOpen[player] == token and player.Parent do
				local interval = if PlayerInfo.HasPermanentSkip(player) then Config.AutoOpen.FastInterval else Config.AutoOpen.Interval
				autoNext[player] = os.clock() + interval
				local r = openCrate(player, crateId)
				if autoOpen[player] ~= token then
					break
				end
				if not r.ok then
					autoOpen[player] = nil
					player:SetAttribute("AutoOpen", nil)
					Fx.To(player, "AutoOpenStopped", { Reason = r.err })
					break
				end
				Fx.To(player, "AutoOpened", { Crate = crateId, Hunter = r.Hunter, Uid = r.Uid, IsNew = r.IsNew })
				task.wait(interval)
			end
		end)
		return { ok = true, On = true }
	end)

	-- Robux Exclusive Crate (granted by ShopService after a purchase)
	HunterService.GrantExclusive = function(p: Player): (string?, string?, boolean)
		local zone = Config.Zones[PlayerInfo.BestZone(p)]
		local hunterId = zone and Config.Exclusives[zone.Id]
		if not hunterId then
			return nil, nil, false
		end
		local uid, isNew = HunterService.Add(p, hunterId)
		local d = DataService.Get(p)
		if uid and d and d.Hunters[uid] then
			d.Hunters[uid].Locked = true -- paid hunter: protect it from an accidental release
		end
		HunterService.Refresh(p)
		local def = Config.Hunters[hunterId]
		Fx.All("Announce", { Text = string.format("%s got the EXCLUSIVE %s!", p.DisplayName, string.upper(def.Name)), Color = "Exclusive" })
		return uid, hunterId, isNew
	end

	Remotes.Register("Equip", "Inventory", function(player, uid)
		if player:GetAttribute("InTower") then
			return Remotes.Fail("Can't change your crew inside the Boss Tower")
		end
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
		if player:GetAttribute("InTower") then
			return Remotes.Fail("Can't change your crew inside the Boss Tower")
		end
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
		if player:GetAttribute("InTower") then
			return Remotes.Fail("Can't change your crew inside the Boss Tower")
		end
		local d = DataService.Get(player)
		if not d then
			return Remotes.Fail("Loading...")
		end
		local best = Rules.EquipBest(fitHunters(d), powerOf, rarityOrder, PlayerInfo.Slots(player))
		if #best == 0 then
			return Remotes.Fail("All your hunters are recovering!")
		end
		d.Equipped = best
		HunterService.Refresh(player)
		return { ok = true, Power = HunterService.CrewPower(player) }
	end)

	Remotes.Register("Lock", "Inventory", function(player, uid, locked)
		local d = DataService.Get(player)
		if not d or not validUid(d, uid) or type(locked) ~= "boolean" then
			return Remotes.Fail("Unknown hunter")
		end
		local why = HunterService.BusyReason(player, uid)
		if why then
			return Remotes.Fail(why)
		end
		d.Hunters[uid].Locked = locked
		DataService.Changed(player)
		return { ok = true }
	end)

	-- Releases (deletes) unlocked, unequipped hunters for a small refund.
	Remotes.Register("Release", "Inventory", function(player, uids)
		local d = DataService.Get(player)
		if not d or type(uids) ~= "table" or #uids == 0 or #uids > PlayerInfo.MaxHunters(player) then
			return Remotes.Fail("Nothing selected")
		end
		local refund = 0
		local released = 0
		local total = countOwned(d)
		for _, uid in uids do
			if total - released <= 1 then
				break
			end
			if validUid(d, uid) and not table.find(d.Equipped, uid) and not d.Hunters[uid].Locked and not HunterService.BusyReason(player, uid) then
				refund += math.floor(cratePrice(d.Hunters[uid].Id) * Config.Inventory.ReleaseRefund)
				d.Hunters[uid] = nil
				d.Knocked[uid] = nil
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

	-- MERGE: 5 identical hunters (same hunter, same tier, unlocked, not busy, not knocked out)
	-- -> 1 hunter of the next tier. All checks and the swap happen in one step on the server, so a
	-- repeated request finds the hunters already gone and fails harmlessly.
	Remotes.Register("Merge", "Inventory", function(player, uids)
		if player:GetAttribute("InTower") then
			return Remotes.Fail("Can't change your crew inside the Boss Tower")
		end
		local d = DataService.Get(player)
		if not d then
			return Remotes.Fail("Loading...")
		end
		local ok, err, id, tier = Rules.MergeCheck(d.Hunters :: any, uids, Config.Merge.Count, Config.Merge.MaxTier, function(uid)
			local why = HunterService.BusyReason(player, uid)
			if why then
				return why
			end
			return if HunterService.IsKnocked(d, uid) then "Knocked-out hunters can't be merged" else nil
		end)
		if not ok then
			return Remotes.Fail(err or "Can't merge those")
		end
		local hunterId, fromTier = id :: string, tier :: number
		local newTier = fromTier + 1
		local cost = math.floor(cratePrice(hunterId) * (Config.Merge.CostMult[newTier] or 1))
		if cost > 0 and not DataService.Spend(player, cost) then
			return Remotes.Fail("Merging costs " .. Format.Commas(cost) .. " Ectoplasm")
		end
		-- consume, then create; the new hunter takes the first equipped slot of the consumed ones
		local slot: number? = nil
		for _, uid in uids :: { string } do
			local i = table.find(d.Equipped, uid)
			if i then
				slot = if slot then math.min(slot, i) else i
			end
		end
		local keep = {}
		for _, uid in d.Equipped do
			if not table.find(uids :: { string }, uid) then
				table.insert(keep, uid)
			end
		end
		for _, uid in uids :: { string } do
			d.Hunters[uid] = nil
			d.Knocked[uid] = nil
		end
		local newUid = DataService.NewUid(d)
		d.Hunters[newUid] = { Id = hunterId, Locked = false, T = os.time(), Tier = newTier }
		d.Variants[hunterId .. ":" .. newTier] = true -- Shiny/Mega variant discovered (Index)
		if slot then
			table.insert(keep, math.min(slot, #keep + 1), newUid)
		end
		d.Equipped = keep
		ensureEquipped(player, d)
		HunterService.Refresh(player)
		DataService.Save(player)
		local tdef = Config.Tiers[newTier]
		local def = Config.Hunters[hunterId]
		if newTier >= 2 then
			Fx.AllExcept(player, "Announce", { Text = string.format("%s merged a %s %s!", player.DisplayName, tdef.Name, string.upper(def.Name)), Color = "Exclusive" })
		end
		return { ok = true, Uid = newUid, Hunter = hunterId, Tier = newTier, Cost = cost }
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
		local t = os.time()
		for uid, untilT in d.Knocked do
			if untilT <= t then
				d.Knocked[uid] = nil -- recovered while offline
			end
		end
		ensureEquipped(player, d)
		HunterService.Refresh(player)
	end)
end

function HunterService.Start()
	Players.PlayerRemoving:Connect(function(player)
		autoOpen[player] = nil -- stops their Auto Open loop
		autoNext[player] = nil
		busy[player] = nil
		PlayerInfo.Forget(player)
	end)
end

return HunterService
