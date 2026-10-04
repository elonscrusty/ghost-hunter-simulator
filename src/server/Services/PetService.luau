--!strict
-- Ghost pets (v1.6): bought with Spirit Shards (Boss Tower only), up to Config.PetRules.MaxEquipped
-- equipped. Equipped pets boost ALL of the owner's hunters (Normal, Shiny, Mega) everywhere
-- (world and tower): Power, Ecto, HP or Recovery. Bonuses are recomputed from the saved
-- equipped list every time (PlayerInfo.PetBonuses), so nothing can stack twice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)
local HunterService = require(script.Parent.HunterService)
local Remotes = require(script.Parent.Remotes)

local PetService = {}

local lastBuy: { [Player]: number } = {}

local NICK_MAX = 20 -- characters

-- Roblox text filter for a nickname everyone can see. Returns nil when filtering fails.
local function filterNick(player: Player, text: string): string?
	local ok, res = pcall(function()
		local r = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(res) == "string" then res else nil
end

local function count(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Adds a pet to a profile (purchase or event reward). Returns the new pet uid.
function PetService.Add(d: DataService.Data, petId: string): string?
	if not Config.Pets[petId] then
		return nil
	end
	local uid = "p" .. d.PetNextUid
	d.PetNextUid += 1
	d.Pets[uid] = { Id = petId, T = os.time() }
	if #d.EquippedPets < Config.PetRules.MaxEquipped then
		table.insert(d.EquippedPets, uid)
	end
	return uid
end

-- Pet bonuses changed: refresh crew power (Power / HP bonuses) and the client snapshot.
local function refresh(player: Player)
	HunterService.Refresh(player)
end
PetService.Refresh = refresh

function PetService.Init()
	Remotes.Register("BuyPet", "Default", function(player, petId)
		local d = DataService.Get(player)
		if not d then
			return Remotes.Fail("Loading...")
		end
		if type(petId) ~= "string" then
			return Remotes.Fail("Unknown pet")
		end
		local def = Config.Pets[petId]
		if not def or def.Price == nil then
			return Remotes.Fail("That pet isn't for sale")
		end
		-- a double tap can't buy twice by accident
		local now = os.clock()
		if lastBuy[player] and now - lastBuy[player] < 1 then
			return Remotes.Fail("One moment...")
		end
		if count(d.Pets) >= Config.PetRules.MaxOwned then
			return Remotes.Fail("Your pet room is full!")
		end
		local price = def.Price :: number
		if d.Shards < price then
			return Remotes.Fail(string.format("Needs %s Spirit Shards (earn them in the Boss Tower)", Format.Commas(price)))
		end
		lastBuy[player] = now
		-- check + spend + add happen in one step (no yield), so the same shards can't be spent twice
		d.Shards -= price
		local uid = PetService.Add(d, petId)
		refresh(player)
		DataService.Save(player)
		return { ok = true, Uid = uid, Shards = d.Shards }
	end)

	Remotes.Register("EquipPet", "Inventory", function(player, uid, on)
		if player:GetAttribute("InTower") then
			return Remotes.Fail("Can't change pets inside the Boss Tower")
		end
		local d = DataService.Get(player)
		if not d or type(uid) ~= "string" or type(on) ~= "boolean" then
			return Remotes.Fail("Unknown pet")
		end
		local pet = d.Pets[uid]
		if not pet or not Config.Pets[pet.Id] then
			return Remotes.Fail("Unknown pet")
		end
		local i = table.find(d.EquippedPets, uid)
		if on and not i then
			if #d.EquippedPets >= Config.PetRules.MaxEquipped then
				return Remotes.Fail(string.format("Only %d pets can follow you at once", Config.PetRules.MaxEquipped))
			end
			table.insert(d.EquippedPets, uid)
		elseif not on and i then
			table.remove(d.EquippedPets, i)
		end
		refresh(player)
		return { ok = true }
	end)

	-- Nickname a pet. Only the FILTERED text is ever stored or shown; empty text clears it.
	Remotes.Register("RenamePet", "Default", function(player, uid, text)
		local d = DataService.Get(player)
		if not d or type(uid) ~= "string" or not d.Pets[uid] then
			return Remotes.Fail("Unknown pet")
		end
		if type(text) ~= "string" or #text > 200 then
			return Remotes.Fail("Bad name")
		end
		-- invisible characters (zero-width, direction marks) can't make a "blank" name
		for _, cp in { 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0xFEFF } do
			text = string.gsub(text, utf8.char(cp), "")
		end
		text = string.match(string.gsub(text, "%c", " "), "^%s*(.-)%s*$") or ""
		local n = utf8.len(text)
		if not n or n > NICK_MAX or #text > 40 then
			return Remotes.Fail(string.format("Names can be up to %d letters", NICK_MAX))
		end
		local nick: string? = nil
		if n > 0 then
			nick = filterNick(player, text) -- yields
			if not nick then
				-- filter unavailable: keep the current (already filtered) name, store nothing new
				return Remotes.Fail("Couldn't check that name right now, try again later")
			end
		end
		local pet = d.Pets[uid] -- re-read after the yield
		if not pet then
			return Remotes.Fail("Unknown pet")
		end
		pet.Nick = if nick and #nick <= 40 and string.find(nick, "%S") then nick else nil
		refresh(player)
		DataService.Save(player)
		return { ok = true, Nick = pet.Nick }
	end)

	DataService.AddDecorator(function(player, s)
		local d = DataService.Get(player)
		if d then
			s.Pets = d.Pets
			s.EquippedPets = d.EquippedPets
			s.Shards = d.Shards
		end
	end)
end

function PetService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
	-- equipped pets replicate to everyone for the follower visuals: "Pets" = "PetId,PetId" and
	-- "PetNames" = the matching filtered nicknames, one per line ("" = default name). Names are
	-- set first so the follower rebuild on "Pets" already sees them.
	local function publish(player: Player)
		local d = DataService.Get(player)
		if not d then
			return
		end
		local ids, names = {}, {}
		for _, uid in d.EquippedPets do
			local pet = d.Pets[uid]
			if pet and Config.Pets[pet.Id] then
				table.insert(ids, pet.Id)
				table.insert(names, (string.gsub(pet.Nick or "", "%c", " ")))
			end
		end
		player:SetAttribute("PetNames", table.concat(names, "\n"))
		player:SetAttribute("Pets", table.concat(ids, ","))
	end
	DataService.AddDecorator(function(player, _s)
		publish(player)
	end)
end

return PetService
