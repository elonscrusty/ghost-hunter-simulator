--!strict
-- Developer-only tools (DEV button + Studio chat commands). A player is a dev ONLY when the game
-- runs in Studio, or when their UserId is listed in Config.DevUserIds (live servers); being the
-- place creator or a group owner does NOT make anyone a dev. Every command is re-checked here on
-- the server, so the button showing up on a client means nothing by itself.
-- Every command only touches the calling dev's OWN profile, except the clearly global ones
-- (2X Ectoplasm on all servers, Server Luck in this server, the Rare Pet launch event).
-- NOTE: in a live server these change the dev's REAL saved profile, so the DANGER commands
-- (STUDIO_ONLY) only run in Studio, where saves use the separate "studio" data scope.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local DevTools = require(GH.Logic.DevTools)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local PetService = require(script.Parent.PetService)
local CrewService = require(script.Parent.CrewService)
local GlobalEventService = require(script.Parent.GlobalEventService)
local RarePetEventService = require(script.Parent.RarePetEventService)
local TradeService = require(script.Parent.TradeService)
local Remotes = require(script.Parent.Remotes)

local DevService = {}

local devs: { [Player]: boolean } = {}

local function checkDev(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	-- live servers: ONLY the explicitly allowed developer UserIds (Config.DevUserIds)
	return table.find(Config.DevUserIds, player.UserId) ~= nil
end

function DevService.IsDev(player: Player): boolean
	return devs[player] == true
end

local MAX_TOWER_ROOM = Config.Tower.MaxScaledRoom
local ECTO2X_HOURS = 48 -- "ON" is always timed: never an endless global event
local BOOST_SECONDS = 1800
local SERVER_LUCK_SECONDS = 900
local MAX_COPIES = Config.Merge.Count -- GiveHunter count: 1 up to a full merge set

-- Wipe / lock commands: Studio only (the dev's separate Studio save), never a live save.
local STUDIO_ONLY: { [string]: boolean } = {
	ResetProgress = true,
	EctoClear = true,
	RemoveDevHunters = true,
	LockAreas = true,
	RarePetAddMinutes = true,
}

-- Dev-granted hunters: no release refund and can't be traded (they never leave the dev's profile).
local function markDevHunter(d: DataService.Data, uid: string?)
	local h = if uid then d.Hunters[uid] else nil
	if h then
		(h :: any).NoRefund = true;
		(h :: any).Dev = true
	end
end

local function plural(n: number, word: string, many: string?): string
	return n .. " " .. (if n == 1 then word else many or word .. "s")
end

local function zoneArg(arg: any): Config.ZoneDef?
	return if type(arg) == "string" then Config.ZoneById[arg] else nil
end

local function moveTo(player: Player, pos: Vector3, face: Vector3?): string?
	if player:GetAttribute("InTower") then
		return "Leave the Boss Tower first"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return "Spawn first"
	end
	root.AssemblyLinearVelocity = Vector3.zero
	char:PivotTo(if face then CFrame.lookAt(pos, face) else CFrame.new(pos))
	return nil
end

-- Services required lazily (they load after DevService's dependencies).
local function lazy(name: string): any?
	local mod = (script.Parent :: any):FindFirstChild(name)
	if not mod then
		return nil
	end
	local ok, m = pcall(require, mod)
	return if ok and type(m) == "table" then m else nil
end

-- Quick trips around the lobby (outside the Boss Tower only)
local SPOTS: { [string]: { Pos: Vector3, Name: string } } = {
	Lobby = { Pos = Config.Layout.Spawn + Vector3.new(0, 4, 0), Name = "the lobby" },
	Tower = { Pos = Config.Layout.TowerEntrance.Pad + Vector3.new(0, 4, 8), Name = "the Boss Tower" },
	Hatchery = { Pos = Config.Layout.Hatchery + Vector3.new(0, 4, 8), Name = "the Pet Hatchery" },
	TradeBooth = { Pos = Config.Layout.TradeBooth + Vector3.new(0, 4, 8), Name = "the Trading booth" },
	-- in front of the World 2 portal at the end of the Throne
	Portal = { Pos = Config.Layout.Portals.ToWorld1.Arrive + Vector3.new(0, 1, 0), Name = "the World 2 portal" },
}

type Cmd = (player: Player, d: DataService.Data, arg: any, arg2: any) -> (string?, string?) -- error, message

local CMDS: { [string]: Cmd } = {}

--------------------------------------------------------------------------------
-- MONEY
--------------------------------------------------------------------------------
CMDS.Ecto = function(player, _d, arg)
	local n = DevTools.Grant("Ecto", arg)
	if not n then
		return "Bad amount"
	end
	DataService.AddEcto(player, n)
	return nil, "Gave " .. Format.Short(n) .. " Ectoplasm"
end

CMDS.Shards = function(player, d, arg)
	-- spendable shards only; TowerShards stays the earned-reward record
	local n = DevTools.Grant("Shards", arg)
	if not n then
		return "Amount must be a whole number 1-" .. Format.Short(DevTools.SHARDS_MAX)
	end
	d.Shards += n
	DataService.Changed(player)
	return nil, "Gave " .. Format.Short(n) .. " Spirit Shards"
end

CMDS.SkipTokens = function(player, d)
	d.SkipTokens = math.min(d.SkipTokens + 10, Config.CrateSkip.MaxTokens)
	DataService.Changed(player)
	return nil, "Crate Skips: " .. d.SkipTokens
end

--------------------------------------------------------------------------------
-- AREAS & TRAVEL
--------------------------------------------------------------------------------
local W2 = Config.Layout.Portals.ToWorld2

-- Own every area up to and including order `last` (+ the Ghost King flag once World 2 is owned).
local function unlockTo(player: Player, d: DataService.Data, last: number)
	for _, z in Config.Zones do
		if z.Order <= last then
			d.Zones[z.Id] = true
		end
	end
	if d.Zones[W2.Zone] then
		d.BossesBeaten[W2.Boss] = true -- owning World 2 implies the portal boss was beaten
	end
	DataService.Changed(player)
end

CMDS.Zones = function(player, d)
	unlockTo(player, d, #Config.Zones)
	return nil, "All " .. #Config.Zones .. " areas unlocked (both worlds)"
end

CMDS.UnlockTo = function(player, d, arg)
	local z = zoneArg(arg)
	if not z then
		return "Unknown area"
	end
	unlockTo(player, d, z.Order)
	return nil, "Unlocked areas 1-" .. z.Order .. " (up to " .. z.Name .. ")"
end

CMDS.TeleportArea = function(player, d, arg)
	local z = zoneArg(arg)
	local spawnPos = if z then (Config.Layout.ZoneSpawns :: any)[z.Id] :: Vector3? else nil
	if not z or not spawnPos then
		return "Unknown area"
	end
	if not d.Zones[z.Id] then
		return "Unlock " .. z.Name .. " first (tap UNLOCK)"
	end
	local err = moveTo(player, spawnPos, spawnPos + Vector3.new(0, 0, 1))
	return err, if err then nil else "Went to " .. z.Name
end

CMDS.Teleport = function(player, _d, arg)
	local spot = if type(arg) == "string" then SPOTS[arg] else nil
	if not spot then
		return "Unknown place"
	end
	local err = moveTo(player, spot.Pos)
	return err, if err then nil else "Went to " .. spot.Name
end

--------------------------------------------------------------------------------
-- HUNTERS
--------------------------------------------------------------------------------
CMDS.GiveHunter = function(player, d, arg, arg2)
	local def = if type(arg) == "string" then Config.Hunters[arg] else nil
	local n = if arg2 == nil then 1 else DevTools.Int(arg2, 1, MAX_COPIES)
	if not def or not n then
		return "Unknown hunter"
	end
	for _ = 1, n do
		markDevHunter(d, (HunterService.Add(player, def.Id)))
	end
	HunterService.Refresh(player)
	return nil, "Gave " .. (if n == 1 then "" else n .. "x ") .. def.Name
end

CMDS.GiveSet = function(player, d, arg)
	-- one of every hunter of an area (its crate set + its Exclusive)
	local z = zoneArg(arg)
	if not z then
		return "Unknown area"
	end
	local n = 0
	for id, def in Config.Hunters do
		if def.Zone == z.Id then
			markDevHunter(d, (HunterService.Add(player, id)))
			n += 1
		end
	end
	HunterService.Refresh(player)
	return nil, "Gave " .. plural(n, "hunter") .. " from " .. z.Name
end

CMDS.Hunters = function(player, d)
	-- one of every hunter the dev doesn't own yet (all areas; storage cap ignored)
	local owned: { [string]: boolean } = {}
	for _, h in d.Hunters do
		owned[h.Id] = true
	end
	local n = 0
	for id in Config.Hunters do
		if not owned[id] then
			markDevHunter(d, (HunterService.Add(player, id)))
			n += 1
		end
	end
	HunterService.Refresh(player)
	return nil, if n == 0 then "You already own every hunter" else "Gave " .. plural(n, "new hunter")
end

CMDS.Exclusive = function(player, d)
	-- the same grant as buying the Exclusive Crate (the Exclusive of your best area)
	local uid = HunterService.GrantExclusive(player)
	if not uid then
		return "No Exclusive for your best area"
	end
	markDevHunter(d, uid)
	local h = d.Hunters[uid]
	local def = if h then Config.Hunters[h.Id] else nil
	return nil, "Gave " .. (if def then def.Name else "an Exclusive")
end

CMDS.IndexAll = function(player, d)
	-- complete the Index: every hunter in Normal, Shiny and Mega
	for id in Config.Hunters do
		d.Discovered[id] = true
		for tier = 1, Config.Merge.MaxTier do
			d.Variants[id .. ":" .. tier] = true
		end
	end
	DataService.Changed(player)
	return nil, "Index complete (all hunters, all forms)"
end

local function setCrewTier(player: Player, d: DataService.Data, tier: number): number
	local n = 0
	for _, uid in d.Equipped do
		local h = d.Hunters[uid]
		if h and (h.Tier or 0) < tier then -- never downgrades; only hunters it changes get the dev flag
			(h :: any).Tier = tier
			d.Variants[h.Id .. ":" .. tier] = true
			markDevHunter(d, uid)
			n += 1
		end
	end
	HunterService.Refresh(player)
	return n
end

CMDS.ShinyCrew = function(player, d)
	return nil, plural(setCrewTier(player, d, 1), "crew hunter") .. " made " .. Config.Tiers[1].Name
end

CMDS.MegaCrew = function(player, d)
	return nil, plural(setCrewTier(player, d, Config.Merge.MaxTier), "crew hunter") .. " made " .. Config.Tiers[Config.Merge.MaxTier].Name
end

CMDS.MergeCopies = function(player, d)
	-- Merge.Count - 1 more copies of each equipped hunter (enough to test a merge)
	local n = 0
	for _, uid in table.clone(d.Equipped) do
		local h = d.Hunters[uid]
		if h then
			for _ = 1, Config.Merge.Count - 1 do
				markDevHunter(d, (HunterService.Add(player, h.Id)))
				n += 1
			end
		end
	end
	HunterService.Refresh(player)
	return nil, "Gave " .. plural(n, "copy", "copies") .. " of your crew (Normal tier)"
end

CMDS.KnockCrew = function(player, d)
	-- knock out the equipped crew for 30 s (tests knockouts, countdowns and recovery)
	for _, uid in d.Equipped do
		d.Knocked[uid] = os.time() + 30
	end
	HunterService.Refresh(player)
	return nil, "Crew knocked out for 30 seconds"
end

CMDS.HealAll = function(player, d)
	table.clear(d.Knocked)
	CrewService.HealAll(player)
	HunterService.Refresh(player)
	return nil, "All hunters healed"
end

--------------------------------------------------------------------------------
-- PETS
--------------------------------------------------------------------------------
local function petCount(d: DataService.Data): number
	local n = 0
	for _ in d.Pets do
		n += 1
	end
	return n
end

CMDS.GivePet = function(player, d, arg)
	local def = if type(arg) == "string" then Config.Pets[arg] else nil
	if not def then
		return "Unknown pet"
	end
	if petCount(d) >= Config.PetRules.MaxOwned then
		return "Pet storage full (" .. Config.PetRules.MaxOwned .. ")"
	end
	PetService.Add(d, def.Id)
	PetService.Refresh(player)
	DataService.Save(player)
	return nil, "Gave " .. def.Name
end

CMDS.AllPets = function(player, d)
	-- one copy of each pet the dev doesn't own yet (repeat-safe, storage cap respected)
	local owned: { [string]: boolean } = {}
	for _, pet in d.Pets do
		owned[pet.Id] = true
	end
	local n, count = 0, petCount(d)
	for _, petId in Config.PetOrder do
		if Config.Pets[petId] and not owned[petId] and count < Config.PetRules.MaxOwned then
			PetService.Add(d, petId)
			owned[petId] = true
			n += 1
			count += 1
		end
	end
	PetService.Refresh(player)
	DataService.Save(player)
	return nil, if n == 0 then "You already own every pet" else "Gave " .. plural(n, "new pet")
end

CMDS.UnlockEggs = function(player, d)
	-- the tower checkpoint every egg needs (only ever raises the checkpoint and best room)
	local need = 0
	for _, egg in Config.Eggs do
		need = math.max(need, egg.Unlock)
	end
	d.TowerCheckpoint = math.max(d.TowerCheckpoint, need)
	d.TowerBest = math.max(d.TowerBest, need)
	DataService.Changed(player)
	return nil, "All eggs unlocked (tower checkpoint " .. d.TowerCheckpoint .. ")"
end

--------------------------------------------------------------------------------
-- BOSSES & EVENTS
--------------------------------------------------------------------------------
CMDS.TowerRoom = function(player, _d, arg)
	local room = DevTools.Int(arg, 1, MAX_TOWER_ROOM)
	if not room then
		return "Room must be a whole number 1-" .. MAX_TOWER_ROOM
	end
	local TS = lazy("TowerService")
	if not TS or type(TS.DevStart) ~= "function" then
		return "Tower test runs not available"
	end
	local err = TS.DevStart(player, room)
	return err, if err then nil else "Test run started at room " .. room
end

CMDS.TowerCheckpoint = function(player, d, arg)
	-- set the saved checkpoint, up or down (tests egg locks and where runs may start)
	local room = DevTools.Int(arg, 0, MAX_TOWER_ROOM)
	if not room then
		return "Room must be a whole number 0-" .. MAX_TOWER_ROOM
	end
	if player:GetAttribute("InTower") then
		return "Leave the Boss Tower first"
	end
	local cp = DevTools.Checkpoint(room, Config.Tower.CheckpointEvery)
	d.TowerCheckpoint = cp
	d.TowerBest = math.max(d.TowerBest, cp)
	DataService.Changed(player)
	return nil, "Tower checkpoint set to room " .. cp
end

CMDS.VoidEmperor = function(player)
	-- test fight right now (teleports the dev into the arena; dev fights pay nothing)
	local VE = lazy("VoidEmperorService")
	local err = if VE and type(VE.DevStart) == "function" then VE.DevStart(player) else "Void Emperor not available"
	return err, if err then nil else "The Void Emperor fight is starting"
end

CMDS.GhostKing = function(player, d, arg)
	-- true: count THE GHOST KING as beaten (World 2 portal requirement); false: forget it
	-- (only while World 2's first area isn't owned, so the save stays consistent)
	if arg == false then
		if d.Zones[W2.Zone] then
			return "You own " .. Config.ZoneById[W2.Zone].Name .. ", so he must stay beaten"
		end
		d.BossesBeaten[W2.Boss] = nil
	elseif arg == true then
		d.BossesBeaten[W2.Boss] = true
	else
		return "Bad value"
	end
	DataService.Changed(player)
	return nil, "Ghost King: " .. (if arg then "BEATEN (the World 2 portal can open)" else "NOT beaten")
end

CMDS.Ecto2x = function(_player, _d, arg)
	-- GLOBAL 2X Ectoplasm (all servers): true = ON for 48 h, false = OFF
	if type(arg) ~= "boolean" then
		return "Bad value"
	end
	local err = GlobalEventService.SetEcto2x(arg, if arg then ECTO2X_HOURS * 3600 else nil)
	if err then
		return err
	end
	return nil, if arg then "2X Ectoplasm ON for " .. ECTO2X_HOURS .. " hours (all servers)" else "2X Ectoplasm OFF (all servers)"
end

CMDS.ServerLuck = function()
	PlayerInfo.AddServerLuck(SERVER_LUCK_SECONDS)
	for _, other in Players:GetPlayers() do
		DataService.Changed(other) -- only refreshes everyone's Server Luck timer
	end
	return nil, "Server Luck +15 minutes (this server)"
end

CMDS.RarePetAddMinutes = function(player)
	-- Studio only: +5 minutes of rare pet event play time (tests the reward without waiting)
	local err = RarePetEventService.StudioAddMinutes(player, 5)
	return err, if err then nil else "+5 minutes of Rare Pet event play"
end

--------------------------------------------------------------------------------
-- PLAYER
--------------------------------------------------------------------------------
CMDS.Boost = function(player, d, arg)
	local def = if type(arg) == "string" and arg ~= "MaxStackSeconds" then (Config.Boosts :: any)[arg] else nil
	if type(def) ~= "table" then
		return "Unknown boost"
	end
	PlayerInfo.AddBoost(d, arg, BOOST_SECONDS)
	DataService.Changed(player)
	return nil, tostring(def.Name) .. " boost +30 minutes"
end

CMDS.LuckyOpens = function(player, d)
	for id in Config.Crates do
		d.LuckyOpens[id] = Config.LuckyOpens.MaxStack
	end
	DataService.Changed(player)
	return nil, "Lucky Opens maxed on every crate"
end

CMDS.MaxUpgrades = function(player, d)
	for id, up in Config.Upgrades do
		d.Upgrades[id] = #up.Levels
	end
	DataService.Changed(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = PlayerInfo.WalkSpeed(player)
	end
	return nil, "All upgrades maxed"
end

CMDS.AllPasses = function(player)
	-- every game pass for this visit only (testing; nothing is saved or bought)
	for _, pass in Config.GamePasses do
		PlayerInfo.SetPass(player, pass.Key, true)
	end
	local shop = lazy("ShopService")
	if shop and type(shop.ApplyPassLooks) == "function" then
		shop.ApplyPassLooks(player)
	end
	HunterService.Refresh(player)
	return nil, "All game passes on (until you leave)"
end

CMDS.AutoAttack = function(player)
	-- the LEGACY Auto Attack pass (no longer sold; Auto Attack is free): owning it grants Auto Open
	PlayerInfo.SetPass(player, "AutoAttack", true)
	HunterService.Refresh(player)
	return nil, "Old Auto Attack pass on (gives Auto Open, until you leave)"
end

CMDS.DailyDay = function(player, d, arg)
	-- the daily reward is ready now, on day `arg` of the streak
	local days = #Config.Daily.Rewards
	local day = DevTools.Int(arg, 1, days)
	if not day then
		return "Day must be 1-" .. days
	end
	if day == 1 then
		d.Daily.Last = 0
		d.Daily.Streak = 0
	else
		d.Daily.Streak = day - 1
		d.Daily.Last = os.time() - Config.Daily.Cooldown
	end
	DataService.Changed(player)
	return nil, "Daily reward ready now (day " .. day .. ")"
end

CMDS.Tutorial = function(player, d)
	d.Tutorial = 1
	DataService.Changed(player)
	return nil, "Tutorial restarted"
end

CMDS.UpdateAgain = function(player, d)
	d.SeenUpdate = "" -- the WHAT'S NEW popup shows again on the next join
	DataService.Changed(player)
	return nil, "What's New will show again next time you join"
end

CMDS.TourAgain = function(player, d)
	d.Settings.Tour = true -- the menu tour runs again on the next join (tutorial finished)
	DataService.Changed(player)
	return nil, "Menu tour will run again next time you join"
end

--------------------------------------------------------------------------------
-- DANGER ZONE (STUDIO_ONLY)
--------------------------------------------------------------------------------
local function busyWith(player: Player): string?
	if TradeService.InTrade(player) then
		return "Finish or cancel your trade first"
	end
	if player:GetAttribute("InTower") then
		return "Leave the Boss Tower first"
	end
	return HunterService.FrozenReason(player)
end

CMDS.ResetProgress = function(player)
	-- the dev's OWN progress only (back to a new player); purchases/passes are kept
	local busy = busyWith(player)
	if busy then
		return busy
	end
	if not DataService.ResetProgress(player) then
		return "Couldn't reset"
	end
	-- a new profile starts with the starter hunter equipped (normally given on join)
	local fresh = DataService.Get(player)
	local uid = HunterService.Add(player, Config.StarterHunter)
	if fresh and uid then
		fresh.Equipped = { uid }
	end
	HunterService.Refresh(player)
	player:LoadCharacter() -- back to spawn (the old area may be locked now)
	return nil, "Your progress was reset"
end

CMDS.EctoClear = function(player, d)
	DataService.AddEcto(player, -d.Ecto)
	return nil, "Your Ectoplasm is now 0"
end

CMDS.RemoveDevHunters = function(player, d)
	-- removes every hunter the dev tools gave or changed (Dev flag); always keeps at least the starter
	local busy = busyWith(player)
	if busy then
		return busy
	end
	local n = 0
	for uid, h in d.Hunters do
		if (h :: any).Dev and not HunterService.BusyReason(player, uid) then
			d.Hunters[uid] = nil
			d.Knocked[uid] = nil
			local i = table.find(d.Equipped, uid)
			if i then
				table.remove(d.Equipped, i)
			end
			n += 1
		end
	end
	if next(d.Hunters) == nil then
		local uid = HunterService.Add(player, Config.StarterHunter)
		if uid then
			d.Equipped = { uid }
		end
	end
	HunterService.EnsureEquipped(player)
	HunterService.Refresh(player)
	return nil, "Removed " .. plural(n, "test hunter")
end

CMDS.LockAreas = function(player, d)
	-- back to only area 1 owned (the Ghost King flag is cleared too)
	if player:GetAttribute("InTower") then
		return "Leave the Boss Tower first"
	end
	for _, z in Config.Zones do
		if z.Order > 1 then
			d.Zones[z.Id] = nil
		end
	end
	d.BossesBeaten[W2.Boss] = nil
	DataService.Changed(player)
	player:LoadCharacter() -- back to spawn (you may be standing in a locked area)
	return nil, "Locked every area except " .. Config.Zones[1].Name
end

-- Runs one dev command; returns an error text or nil (+ extra result fields; Msg is the
-- confirmation line the panel shows).
function DevService.Run(player: Player, cmd: string, arg: any, arg2: any): (string?, any)
	if cmd == "StartRarePetEvent" then
		-- GLOBAL launch event: ONLY Config.RarePetEvent.AdminUserIds (any tester in Studio, where it
		-- stays in memory). Checked here AND inside the service; dev status alone is not enough.
		if not RarePetEventService.IsAdmin(player) then
			return "Not allowed"
		end
		local res = RarePetEventService.Activate(player)
		return (if res.ok then nil else res.err or "Failed"), { Event = res.Event, Created = res.Created }
	elseif cmd == "RarePetStatus" then
		if not RarePetEventService.IsAdmin(player) then
			return "Not allowed"
		end
		return nil, { Event = RarePetEventService.Status() }
	end
	if not devs[player] then
		return "Not allowed"
	end
	local fn = CMDS[cmd]
	if not fn then
		return "Unknown command"
	end
	if STUDIO_ONLY[cmd] and not RunService:IsStudio() then
		return "Only in Studio (keeps your real save safe)"
	end
	local d = DataService.Get(player)
	if not d then
		return "Loading..."
	end
	local err, msg = fn(player, d, arg, arg2)
	if err then
		return err
	end
	return nil, { Msg = msg }
end

function DevService.Init()
	Remotes.Register("Dev", "Default", function(player, cmd, arg, arg2)
		if type(cmd) ~= "string" then
			return Remotes.Fail("Bad command")
		end
		local err, extra = DevService.Run(player, cmd, arg, arg2)
		local res: { [string]: any } = if err then Remotes.Fail(err) else { ok = true }
		if type(extra) == "table" then
			for k, v in extra do
				res[k] = v
			end
		end
		return res
	end)
end

local CHAT: { [string]: { Cmd: string, Arg: any } } = {
	["/reset-daily"] = { Cmd = "DailyDay", Arg = 1 },
	["/autoattack"] = { Cmd = "AutoAttack" },
	["/zones"] = { Cmd = "Zones" },
	["/hunters"] = { Cmd = "Hunters" },
	["/maxupgrades"] = { Cmd = "MaxUpgrades" },
	["/tutorial"] = { Cmd = "Tutorial" },
}

function DevService.Start()
	local function hook(player: Player)
		task.spawn(function()
			devs[player] = checkDev(player)
			-- the client shows the DEV button for this attribute; the server still checks every call
			player:SetAttribute("IsDev", devs[player])
		end)
		player.Chatted:Connect(function(msg)
			if not devs[player] then
				return
			end
			local n = msg:match("^/ecto%s+(%d+)$")
			local c = CHAT[msg]
			if n then
				DevService.Run(player, "Ecto", tonumber(n))
			elseif c then
				DevService.Run(player, c.Cmd, c.Arg)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		devs[player] = nil
	end)
end

return DevService
