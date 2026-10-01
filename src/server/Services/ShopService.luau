--!strict
-- Robux shop: developer products (Ectoplasm packs, boosts) and game passes.
-- ProcessReceipt is idempotent: receipts are recorded in the profile and saved before
-- returning PurchaseGranted, so a purchase is never lost or granted twice.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local ShopService = {}

local function productById(id: number): Config.ProductDef?
	for _, p in Config.Products do
		if p.ProductId == id then
			return p
		end
	end
	return nil
end

local function grantProduct(player: Player, d: DataService.Data, p: Config.ProductDef)
	if p.Kind == "Ecto" and p.Amount then
		DataService.AddEcto(player, p.Amount * PlayerInfo.ZoneMultiplier(player))
	elseif p.Kind == "Boost" and p.Boost and p.Seconds then
		PlayerInfo.AddBoost(d, p.Boost, p.Seconds)
	end
	DataService.Changed(player)
	Fx.Toast(player, "Thanks! " .. p.Name .. " added!", "Good")
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = DataService.WaitFor(player, 20)
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipt = tostring(info.PurchaseId)
	if DataService.HasPurchase(d, receipt) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local p = productById(info.ProductId)
	if not p then
		warn("[Shop] unknown product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(player, d, p)
	DataService.AddPurchase(d, receipt)
	if not DataService.SaveNow(player) then
		-- Roblox will retry the receipt later; our record prevents a double grant in this session
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkPasses(player: Player)
	for _, pass in Config.GamePasses do
		if pass.PassId then
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.PassId :: number)
			end)
			PlayerInfo.SetPass(player, pass.Key, ok and owned == true)
		end
	end
	HunterService.Refresh(player)
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Config.GamePasses do
			if pass.PassId == passId then
				PlayerInfo.SetPass(player, pass.Key, true)
				HunterService.Refresh(player)
				Fx.Toast(player, "Thanks! " .. pass.Name .. " unlocked!", "Good")
			end
		end
	end)

	-- Client asks to buy: server validates the key and prompts (ids never come from the client).
	Remotes.Register("Buy", "Default", function(player, key)
		if type(key) ~= "string" then
			return Remotes.Fail("Bad item")
		end
		for _, p in Config.Products do
			if p.Key == key then
				if not p.ProductId then
					return Remotes.Fail("Coming soon!")
				end
				MarketplaceService:PromptProductPurchase(player, p.ProductId)
				return { ok = true }
			end
		end
		for _, pass in Config.GamePasses do
			if pass.Key == key then
				if not pass.PassId then
					return Remotes.Fail("Coming soon!")
				end
				if PlayerInfo.HasPass(player, pass.Key) then
					return Remotes.Fail("You already own this!")
				end
				MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
				return { ok = true }
			end
		end
		return Remotes.Fail("Bad item")
	end)

	DataService.Loaded:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
end

function ShopService.Start() end

return ShopService
