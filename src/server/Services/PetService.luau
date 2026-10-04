--!strict
-- Ghost pets (v1.6): bought with Spirit Shards (Boss Tower only), up to Config.PetRules.MaxEquipped
-- equipped. Equipped pets boost ALL of the owner's hunters (Normal, Shiny, Mega) everywhere
-- (world and tower): Power, Ecto, HP or Recovery. Bonuses are recomputed from the saved
-- equipped list every time (PlayerInfo.PetBonuses), so nothing can stack twice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)
local HunterService = require(script.Parent.HunterService)
local Remotes = require(script.Parent.Remotes)

local PetService = {}

local lastBuy: { [Player]: number } = {}

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
	-- equipped pets replicate to everyone for the follower visuals ("PetId,PetId")
	local function publish(player: Player)
		local d = DataService.Get(player)
		if not d then
			return
		end
		local ids = {}
		for _, uid in d.EquippedPets do
			local pet = d.Pets[uid]
			if pet and Config.Pets[pet.Id] then
				table.insert(ids, pet.Id)
			end
		end
		player:SetAttribute("Pets", table.concat(ids, ","))
	end
	DataService.AddDecorator(function(player, _s)
		publish(player)
	end)
end

return PetService
