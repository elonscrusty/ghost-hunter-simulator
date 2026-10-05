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

-- Products no longer sold: Buy refuses them; ProcessReceipt still honours old receipts.
local RETIRED_KINDS: { [string]: boolean } = { SummonEvent = true }
local LEGACY_SUMMON_LUCK_SECONDS = 900

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
		PlayerInfo.AddBoost(d, p.Boost, p.Seconds, true) -- paid: never capped away
	elseif p.Kind == "CrateSkip" then
		-- never cap here: this skip is already paid for (the cap is enforced before prompting)
		d.SkipTokens = (d.SkipTokens or 0) + 1
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
		PlayerInfo.AddServerLuck(p.Seconds, true, player) -- paid: never capped away; unused time follows the buyer on shutdown
		Fx.All("Announce", { Text = player.DisplayName .. " turned on SERVER LUCK for everyone! 🍀", Color = "Rare" })
		for _, other in Players:GetPlayers() do
			DataService.Changed(other)
		end
	elseif p.Kind == "SummonEvent" then
		-- RETIRED product (the Giant Poltergeist event is gone and it is no longer sold). An old
		-- or delayed receipt still gets something fair that can never be capped away: the
		-- biggest Ectoplasm pack for the buyer.
		local _ = LEGACY_SUMMON_LUCK_SECONDS
		local pack = 0
		for _, q in Config.Products do
			if q.Kind == "Ecto" and q.Amount and q.Amount > pack then
				pack = q.Amount
			end
		end
		DataService.AddEcto(player, pack * PlayerInfo.ZoneMultiplier(player))
		DataService.Changed(player)
		Fx.Toast(player, "Thanks! The Giant Poltergeist event was retired, so you got a big Ectoplasm pack instead!", "Good")
		return
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

-- Asks Roblox (3 tries with backoff). true/false = answer, nil = still unknown.
local function ownsPass(player: Player, passId: number): boolean?
	for attempt = 1, 3 do
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			return owned == true
		end
		if attempt < 3 then
			task.wait(2 * attempt)
		end
		if not player.Parent then
			return nil
		end
	end
	return nil
end

local RECHECK_SECONDS = 180 -- passes Roblox couldn't confirm are asked about again this often
local checking: { [Player]: boolean } = {}
-- passes bought this session that Roblox hasn't confirmed yet: a "false" answer stays unknown
local unconfirmed: { [Player]: { [string]: boolean } } = {}

-- onlyUnknown = re-check just the passes whose earlier check failed.
local function checkPasses(player: Player, onlyUnknown: boolean?)
	if checking[player] then
		return
	end
	checking[player] = true
	for _, pass in Config.GamePasses do
		if pass.PassId and (not onlyUnknown or PlayerInfo.PassUnknown(player, pass.Key)) then
			local owned = ownsPass(player, pass.PassId :: number)
			if not player.Parent then
				checking[player] = nil
				return -- left while we were asking Roblox
			end
			if owned == nil then
				-- unknown: not owned for gameplay, but never re-sold and slots are never trimmed
				PlayerInfo.SetPass(player, pass.Key, PlayerInfo.HasPass(player, pass.Key))
				PlayerInfo.SetPassUnknown(player, pass.Key)
			elseif not owned and unconfirmed[player] and unconfirmed[player][pass.Key] then
				PlayerInfo.SetPassUnknown(player, pass.Key) -- bought, Roblox's cache is behind: ask again later
			else
				if owned and unconfirmed[player] then
					unconfirmed[player][pass.Key] = nil
				end
				-- never take back a pass granted this session (a purchase can lag Roblox's cache)
				PlayerInfo.SetPass(player, pass.Key, owned or PlayerInfo.HasPass(player, pass.Key))
			end
		end
	end
	checking[player] = nil
	PlayerInfo.SetPassesChecked(player)
	applyPassLooks(player)
	-- pass state is known now: only now may a lost Extra Slots pass trim the equipped list
	HunterService.EnsureEquipped(player)
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
				-- the client's "purchased" flag isn't proof: confirm with Roblox first
				local owned: boolean? = nil
				for attempt = 1, 3 do
					owned = ownsPass(player, passId)
					if owned or not player.Parent then
						break
					end
					task.wait(attempt)
				end
				if not player.Parent then
					return
				end
				if owned then
					PlayerInfo.SetPass(player, pass.Key, true)
					applyPassLooks(player)
					HunterService.Refresh(player)
					Fx.Toast(player, "Thanks! " .. pass.Name .. " unlocked!", "Good")
				elseif not PlayerInfo.HasPass(player, pass.Key) then
					-- not confirmed yet: keep it "unknown" (not re-sold) and let the re-check unlock it
					unconfirmed[player] = unconfirmed[player] or {}
					unconfirmed[player][pass.Key] = true
					PlayerInfo.SetPassUnknown(player, pass.Key)
					Fx.Toast(player, "Checking your " .. pass.Name .. " purchase... it unlocks in a few minutes.", "Good")
				end
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
				if RETIRED_KINDS[p.Kind] then
					return Remotes.Fail("This isn't sold anymore")
				end
				if not p.ProductId then
					return Remotes.Fail("Coming soon!")
				end
				local d = DataService.Get(player)
				if p.Kind == "CrateSkip" and PlayerInfo.HasPermanentSkip(player) then
					return Remotes.Fail("You already have Permanent Crate Skip!")
				end
				if p.Kind == "CrateSkip" and d and (d.SkipTokens or 0) >= Config.CrateSkip.MaxTokens then
					return Remotes.Fail("You already have the most skips you can hold!")
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
				if PlayerInfo.PassUnknown(player, pass.Key) then
					return Remotes.Fail("Still checking your passes, try again in a moment")
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

function ShopService.Start()
	-- passes Roblox couldn't confirm (check failed, or a purchase not visible yet): ask again
	task.spawn(function()
		while true do
			task.wait(RECHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				if PlayerInfo.HasUnknownPasses(player) and DataService.Get(player) then
					task.spawn(checkPasses, player, true)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		checking[player] = nil
		unconfirmed[player] = nil
	end)
end

return ShopService
