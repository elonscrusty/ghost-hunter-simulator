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
local EventService = require(script.Parent.EventService)

local ShopService = {}

local function productById(id: number): Config.ProductDef?
	for _, p in Config.Products do
		if p.ProductId == id then
			return p
		end
	end
	return nil
end

local function nextLockedZone(d: DataService.Data): Config.ZoneDef?
	for _, z in Config.Zones do
		if not d.Zones[z.Id] then
			return z
		end
	end
	return nil
end

local function grantProduct(player: Player, d: DataService.Data, p: Config.ProductDef)
	if p.Kind == "Ecto" and p.Amount then
		DataService.AddEcto(player, p.Amount * PlayerInfo.ZoneMultiplier(player))
	elseif p.Kind == "Boost" and p.Boost and p.Seconds then
		PlayerInfo.AddBoost(d, p.Boost, p.Seconds)
	elseif p.Kind == "CrateSkip" then
		d.SkipTokens = math.min((d.SkipTokens or 0) + 1, Config.CrateSkip.MaxTokens)
		Fx.To(player, "SkipGranted", {})
	elseif p.Kind == "SkipArea" then
		local z = nextLockedZone(d)
		if z then
			d.Zones[z.Id] = true
			Fx.To(player, "ZoneUnlocked", { Zone = z.Id })
		else
			-- everything was already open (bought twice quickly): pay out a big Ectoplasm pack instead
			DataService.AddEcto(player, (p.Amount or 0) * PlayerInfo.ZoneMultiplier(player))
		end
	elseif p.Kind == "ExclusiveCrate" then
		local uid, hunterId, isNew = HunterService.GrantExclusive(player)
		if uid and hunterId then
			Fx.To(player, "Exclusive", { Uid = uid, Hunter = hunterId, IsNew = isNew })
		end
	elseif p.Kind == "ServerLuck" and p.Seconds then
		PlayerInfo.AddServerLuck(p.Seconds)
		Fx.All("Announce", { Text = player.DisplayName .. " turned on SERVER LUCK for everyone! 🍀", Color = "Rare" })
		for _, other in Players:GetPlayers() do
			DataService.Changed(other)
		end
	elseif p.Kind == "SummonEvent" then
		Fx.All("Announce", { Text = player.DisplayName .. " summoned the GIANT POLTERGEIST! 👻", Color = "Legendary" })
		EventService.TriggerNow()
	end
	DataService.Changed(player)
	Fx.Toast(player, "Thanks! " .. p.Name .. " added!", "Good")
end

-- Cosmetic / social pass effects that other players can see.
local function applyPassLooks(player: Player)
	player:SetAttribute("VIP", PlayerInfo.HasPass(player, "VIP"))
	player:SetAttribute("RainbowBeams", PlayerInfo.HasPass(player, "RainbowBeams"))
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = root:FindFirstChild("GHSparkleTrail")
	if PlayerInfo.HasPass(player, "SparkleTrail") and not old then
		local a0 = Instance.new("Attachment")
		a0.Name = "GHTrailA"
		a0.Position = Vector3.new(0, 0.6, 0.4)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "GHTrailB"
		a1.Position = Vector3.new(0, -1.6, 0.4)
		a1.Parent = root
		local t = Instance.new("Trail")
		t.Name = "GHSparkleTrail"
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = 0.6
		t.LightEmission = 0.6
		t.FaceCamera = true
		t.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 220)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 240, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 140)),
		})
		t.Transparency = NumberSequence.new(0.2, 1)
		t.Parent = root
	end
	-- VIP tag over the head
	local head = (char :: Model):FindFirstChild("Head")
	if head and PlayerInfo.HasPass(player, "VIP") and not head:FindFirstChild("GHVipTag") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "GHVipTag"
		bb.Size = UDim2.fromOffset(60, 20)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.Parent = head
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = "👑 VIP"
		l.Font = Enum.Font.FredokaOne
		l.TextSize = 16
		l.TextColor3 = Color3.fromRGB(255, 215, 80)
		l.TextStrokeTransparency = 0.3
		l.Parent = bb
	end
end
ShopService.ApplyPassLooks = applyPassLooks

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
		-- already granted in this session; only confirm once it is really saved
		return if DataService.SaveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
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
			if not player.Parent then
				return -- left while we were asking Roblox
			end
			PlayerInfo.SetPass(player, pass.Key, ok and owned == true)
		end
	end
	applyPassLooks(player)
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
				applyPassLooks(player)
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
				local d = DataService.Get(player)
				if p.Kind == "CrateSkip" and PlayerInfo.HasPermanentSkip(player) then
					return Remotes.Fail("You already have Permanent Crate Skip!")
				end
				if p.Kind == "SkipArea" and d and not nextLockedZone(d) then
					return Remotes.Fail("Every area is already unlocked!")
				end
				if p.Kind == "ExclusiveCrate" and d then
					local count = 0
					for _ in d.Hunters do
						count += 1
					end
					if count >= PlayerInfo.MaxHunters(player) then
						return Remotes.Fail("Hunter storage full! Release some hunters first.")
					end
				end
				if p.Kind == "ServerLuck" and PlayerInfo.ServerLuckUntil() - os.time() + (p.Seconds or 0) > Config.ServerLuck.MaxStackSeconds then
					return Remotes.Fail("Server luck is already maxed!")
				end
				if p.Kind == "SummonEvent" and EventService.IsBusy() then
					return Remotes.Fail("The Giant Poltergeist is already here!")
				end
				if p.Kind == "Boost" and p.Boost and p.Seconds then
					-- boosts stack up to a cap; don't sell time that would be thrown away
					local left = if d then (d.Boosts[p.Boost] or 0) - os.time() else 0
					if left + p.Seconds > Config.Boosts.MaxStackSeconds then
						return Remotes.Fail("That boost is already stacked to the max!")
					end
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
				if pass.Key == Config.AutoOpen.Pass and PlayerInfo.HasAutoOpen(player) then
					return Remotes.Fail("You already have Auto Open!")
				end
				if pass.Hidden then
					return Remotes.Fail("This isn't sold anymore")
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
	-- trail / VIP tag again after every respawn
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 10)
			char:WaitForChild("Head", 10)
			applyPassLooks(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
end

function ShopService.Start() end

return ShopService
