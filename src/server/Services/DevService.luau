--!strict
-- Developer-only tools (DEV button + Studio chat commands). A player is a dev ONLY when the game
-- runs in Studio, or when their UserId is listed in Config.DevUserIds (live servers); being the
-- place creator or a group owner does NOT make anyone a dev. Every command is re-checked here on
-- the server, so the button showing up on a client means nothing by itself.
-- NOTE: in a live server these change the dev's REAL saved profile.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
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

local MAX_ECTO_GRANT = 1e12
local MAX_SHARD_GRANT = 1e6
local MAX_TOWER_ROOM = 400
local ECTO2X_DEFAULT_HOURS = 48 -- "ON" without hours: never an endless global event

-- Dev-granted hunters: no release refund and can't be traded (they never leave the dev's profile).
local function markDevHunter(d: DataService.Data, uid: string?)
	local h = if uid then d.Hunters[uid] else nil
	if h then
		(h :: any).NoRefund = true;
		(h :: any).Dev = true
	end
end

-- whole number in [lo, hi], else nil
local function int(arg: any, lo: number, hi: number): number?
	if type(arg) ~= "number" or arg ~= arg or arg % 1 ~= 0 or arg < lo or arg > hi then
		return nil
	end
	return arg
end

-- Runs one dev command; returns an error text or nil (+ optional extra result fields).
function DevService.Run(player: Player, cmd: string, arg: any): (string?, any)
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
	local d = DataService.Get(player)
	if not d then
		return "Loading..."
	end
	if cmd == "Ecto" then
		local n = tonumber(arg)
		if not n or n ~= n or n <= 0 then
			return "Bad amount"
		end
		DataService.AddEcto(player, math.min(math.floor(n), MAX_ECTO_GRANT))
	elseif cmd == "Zones" then
		for _, z in Config.Zones do
			d.Zones[z.Id] = true
		end
		DataService.Changed(player)
	elseif cmd == "Hunters" then
		-- one of every hunter the dev doesn't own yet (all areas, incl. new ones; storage cap ignored)
		local owned: { [string]: boolean } = {}
		for _, h in d.Hunters do
			owned[h.Id] = true
		end
		for id in Config.Hunters do
			if not owned[id] then
				markDevHunter(d, (HunterService.Add(player, id)))
			end
		end
		HunterService.Refresh(player)
	elseif cmd == "IndexAll" then
		-- complete the Index: every hunter in Normal, Shiny and Mega + every pet seen
		for id in Config.Hunters do
			d.Discovered[id] = true
			d.Variants[id .. ":1"] = true
			d.Variants[id .. ":2"] = true
		end
		DataService.Changed(player)
	elseif cmd == "MegaCrew" then
		-- equipped hunters become Mega (tests tiers, power and HP without merging)
		for _, uid in d.Equipped do
			local h = d.Hunters[uid]
			if h and (h.Tier or 0) < Config.Merge.MaxTier then -- only hunters it changes get the dev flag
				(h :: any).Tier = Config.Merge.MaxTier
				d.Variants[h.Id .. ":" .. Config.Merge.MaxTier] = true
				markDevHunter(d, uid)
			end
		end
		HunterService.Refresh(player)
	elseif cmd == "ShinyCrew" then
		for _, uid in d.Equipped do
			local h = d.Hunters[uid]
			if h and (h.Tier or 0) < 1 then -- never downgrades a Mega
				(h :: any).Tier = 1
				d.Variants[h.Id .. ":1"] = true
				markDevHunter(d, uid)
			end
		end
		HunterService.Refresh(player)
	elseif cmd == "MergeCopies" then
		-- 4 more copies of each equipped hunter (5 in total: enough to test a merge)
		for _, uid in table.clone(d.Equipped) do
			local h = d.Hunters[uid]
			if h then
				for _ = 1, Config.Merge.Count - 1 do
					markDevHunter(d, (HunterService.Add(player, h.Id)))
				end
			end
		end
		HunterService.Refresh(player)
	elseif cmd == "Teleport" then
		-- quick trips around the lobby (outside the Boss Tower only)
		if player:GetAttribute("InTower") then
			return "Leave the Boss Tower first"
		end
		local spots: { [string]: Vector3 } = {
			Lobby = Config.Layout.Spawn,
			Tower = Config.Layout.TowerEntrance.Pad,
			Hatchery = Config.Layout.Hatchery,
		}
		local spot = if type(arg) == "string" then spots[arg] else nil
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not spot or not char or not root then
			return "Can't teleport"
		end
		local to = spot + Vector3.new(0, 4, if arg == "Lobby" then 0 else 8)
		char:PivotTo(CFrame.new(to))
	elseif cmd == "UnlockEggs" then
		-- the tower checkpoint every egg needs (checkpoint and best room only ever go up)
		local need = 0
		for _, egg in Config.Eggs do
			need = math.max(need, egg.Unlock)
		end
		d.TowerCheckpoint = math.max(d.TowerCheckpoint, need)
		d.TowerBest = math.max(d.TowerBest, need)
		DataService.Changed(player)
	elseif cmd == "LuckyOpens" then
		for id in Config.Crates do
			d.LuckyOpens[id] = Config.LuckyOpens.MaxStack
		end
		DataService.Changed(player)
	elseif cmd == "SkipTokens" then
		d.SkipTokens += 10
		DataService.Changed(player)
	elseif cmd == "Boosts" then
		PlayerInfo.AddBoost(d, "Ecto", 1800)
		PlayerInfo.AddBoost(d, "Luck", 1800)
		DataService.Changed(player)
	elseif cmd == "KnockCrew" then
		-- knock out the equipped crew for 30 s (tests knockouts, countdowns and recovery)
		for _, uid in d.Equipped do
			d.Knocked[uid] = os.time() + 30
		end
		HunterService.Refresh(player)
	elseif cmd == "MaxUpgrades" then
		for id, up in Config.Upgrades do
			d.Upgrades[id] = #up.Levels
		end
		DataService.Changed(player)
	elseif cmd == "Ecto2x" then
		-- GLOBAL 2X Ectoplasm (all servers); arg = true (48 h) / false (OFF) / hours (timed, 1-168)
		local err
		if type(arg) == "number" and arg == arg then
			err = GlobalEventService.SetEcto2x(true, math.clamp(arg, 1, 168) * 3600)
		elseif arg == true then
			err = GlobalEventService.SetEcto2x(true, ECTO2X_DEFAULT_HOURS * 3600)
		else
			err = GlobalEventService.SetEcto2x(false)
		end
		if err then
			return err
		end
	elseif cmd == "ResetProgress" then
		-- the dev's OWN progress only (back to a new player); purchases/passes are kept
		if TradeService.InTrade(player) then
			return "Finish or cancel your trade first"
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
	elseif cmd == "AllPets" then
		-- one copy of each pet the dev doesn't own yet (repeat-safe)
		local owned: { [string]: boolean } = {}
		for _, pet in d.Pets do
			owned[pet.Id] = true
		end
		for _, petId in Config.PetOrder do
			if Config.Pets[petId] and not owned[petId] then
				PetService.Add(d, petId)
				owned[petId] = true
			end
		end
		PetService.Refresh(player)
		DataService.Save(player)
	elseif cmd == "HealAll" then
		table.clear(d.Knocked)
		CrewService.HealAll(player)
		HunterService.Refresh(player)
	elseif cmd == "Shards" then
		-- spendable shards only; TowerShards stays the earned-reward record
		local n = int(arg, 1, MAX_SHARD_GRANT)
		if not n then
			return "Amount must be a whole number 1-1000000"
		end
		d.Shards += n
		DataService.Changed(player)
	elseif cmd == "TowerRoom" then
		local room = int(arg, 1, MAX_TOWER_ROOM)
		if not room then
			return "Room must be a whole number 1-400"
		end
		-- lazy require: TowerService loads after DevService's dependencies
		local ok, TS = pcall(require, (script.Parent :: any).TowerService)
		if not ok or type(TS) ~= "table" or type(TS.DevStart) ~= "function" then
			return "Tower dev jump not available"
		end
		local err = TS.DevStart(player, room)
		if err then
			return err
		end
	elseif cmd == "ResetDaily" then
		d.Daily.Last = 0
		DataService.Changed(player)
	elseif cmd == "AutoAttack" then
		-- the LEGACY Auto Attack pass (no longer sold; Auto Attack is free): owning it grants Auto Open
		PlayerInfo.SetPass(player, "AutoAttack", true)
		HunterService.Refresh(player)
	elseif cmd == "AllPasses" then
		-- every game pass for this session only (testing; nothing is saved or bought)
		for _, pass in Config.GamePasses do
			PlayerInfo.SetPass(player, pass.Key, true)
		end
		local shop = (script.Parent :: any).ShopService
		if shop then
			local ok, mod = pcall(require, shop)
			if ok and mod.ApplyPassLooks then
				mod.ApplyPassLooks(player)
			end
		end
		HunterService.Refresh(player)
	elseif cmd == "ServerLuck" then
		PlayerInfo.AddServerLuck(900)
		for _, other in Players:GetPlayers() do
			DataService.Changed(other)
		end
	elseif cmd == "Exclusive" then
		markDevHunter(d, (HunterService.GrantExclusive(player)))
	elseif cmd == "RarePetAddMinutes" then
		-- Studio only: +N minutes of rare pet event play time (tests the reward without waiting)
		local err = RarePetEventService.StudioAddMinutes(player, tonumber(arg) or 5)
		if err then
			return err
		end
	elseif cmd == "Tutorial" then
		d.Tutorial = 1
		DataService.Changed(player)
	else
		return "Unknown command"
	end
	return nil
end

function DevService.Init()
	Remotes.Register("Dev", "Default", function(player, cmd, arg)
		if type(cmd) ~= "string" then
			return Remotes.Fail("Bad command")
		end
		local err, extra = DevService.Run(player, cmd, arg)
		local res: { [string]: any } = if err then Remotes.Fail(err) else { ok = true }
		if type(extra) == "table" then
			for k, v in extra do
				res[k] = v
			end
		end
		return res
	end)
end

local CHAT: { [string]: string } = {
	["/reset-daily"] = "ResetDaily",
	["/autoattack"] = "AutoAttack",
	["/zones"] = "Zones",
	["/hunters"] = "Hunters",
	["/maxupgrades"] = "MaxUpgrades",
	["/tutorial"] = "Tutorial",
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
			local n = msg:match("^/ecto%s+(%d+)")
			if n then
				DevService.Run(player, "Ecto", tonumber(n))
			elseif CHAT[msg] then
				DevService.Run(player, CHAT[msg], nil)
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
