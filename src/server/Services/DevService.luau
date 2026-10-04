--!strict
-- Owner-only developer tools (DEV button + Studio chat commands). A player is a dev when the
-- game runs in Studio, when they created the game (or own the group that did), or when their
-- UserId is in Config.DevUserIds. Every command is re-checked here on the server, so the
-- button showing up on a client means nothing by itself.
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
local Remotes = require(script.Parent.Remotes)

local DevService = {}

local devs: { [Player]: boolean } = {}

local function checkDev(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.DevUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

function DevService.IsDev(player: Player): boolean
	return devs[player] == true
end

local MAX_ECTO_GRANT = 1e12
local MAX_SHARD_GRANT = 1e6
local MAX_TOWER_ROOM = 400

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
		local count = 0
		for _ in d.Hunters do
			count += 1
		end
		for id in Config.Hunters do
			if count >= PlayerInfo.MaxHunters(player) then
				break
			end
			HunterService.Add(player, id)
			count += 1
		end
		HunterService.Refresh(player)
	elseif cmd == "MaxUpgrades" then
		for id, up in Config.Upgrades do
			d.Upgrades[id] = #up.Levels
		end
		DataService.Changed(player)
	elseif cmd == "Ecto2x" then
		-- GLOBAL 2X Ectoplasm (all servers); arg = true (until OFF) / false / hours (timed, 1-168)
		local err
		if type(arg) == "number" and arg == arg then
			err = GlobalEventService.SetEcto2x(true, math.clamp(arg, 1, 168) * 3600)
		else
			err = GlobalEventService.SetEcto2x(arg == true)
		end
		if err then
			return err
		end
	elseif cmd == "ResetProgress" then
		-- the dev's OWN progress only (back to a new player); purchases/passes are kept
		if not DataService.ResetProgress(player) then
			return "Couldn't reset"
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
		HunterService.GrantExclusive(player)
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
