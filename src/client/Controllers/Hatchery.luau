--!strict
-- PET HATCHERY egg panel + hatch animation. The world pedestals (server World/Hatchery) carry a
-- "View" ProximityPrompt with attribute Egg = egg id; triggering it opens this panel for that
-- egg: price, lock state, every possible pet with its rarity, bonus and EXACT odds, and a
-- BUY & HATCH button. The server ("BuyEgg") checks, rolls, charges and saves in one step;
-- each purchase carries a request id, and a failed/timed-out request is retried ONCE with the
-- SAME id, so a retry can never charge twice or roll again. The hatch animation only shows the
-- result the server already saved.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Eggs = require(GH.Logic.Eggs)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Sound = require(script.Parent.Sound)
local PetsPanel = require(script.Parent.PetsPanel)
local Reveal = require(script.Parent.Reveal)

local Hatchery = {}

local SHARD = Color3.fromRGB(200, 160, 255)
local REQUEST_TIMEOUT = 12 -- seconds before a buy request counts as lost and is retried
-- errors worth one retry with the same request id (the server may or may not have hatched)
local RETRY_ERRORS: { [string]: boolean } = {
	["Connection hiccup, try again"] = true,
	["Slow down!"] = true,
	["Something went wrong"] = true,
	["One moment..."] = true,
	["Loading..."] = true,
}

local panel: Kit.Panel
local priceLabel: TextLabel
local lockLabel: TextLabel
local list: ScrollingFrame
local buyButton: TextButton
local reasonLabel: TextLabel
local currentEgg: string? = nil
local busy = false
local playing = false

local function countPets(d: any): number
	local n = 0
	for _ in d.Pets or {} do
		n += 1
	end
	return n
end

local function pct(chance: number): string
	return string.format("%g%%", chance)
end

-- Why the egg can't be bought right now (nil = it can).
local function blockReason(egg: Config.EggDef, d: any): string?
	if not Eggs.Unlocked(egg, d.TowerCheckpoint or 0) then
		return string.format("Locked: reach Boss Tower checkpoint %d", egg.Unlock)
	end
	if countPets(d) >= Config.PetRules.MaxOwned then
		return "Your pet room is full!"
	end
	if (d.Shards or 0) < egg.Price then
		return string.format("Needs %s more Spirit Shards (Boss Tower)", Format.Commas(egg.Price - (d.Shards or 0)))
	end
	return nil
end

local function petRow(order: number, pet: Config.PetDef, chance: number)
	local r = Config.Rarities[pet.Rarity]
	local rc = if r then r.Color else Theme.Text
	local f: Frame = Kit.new("Frame", { Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 62, Parent = list })
	Kit.Corner(f, UDim.new(0, 12))
	Kit.Stroke(f, 2.5, rc, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(f, Theme.Panel3, Theme.Panel, 90)
	local orb: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(8, 7), BackgroundColor3 = pet.Color, ZIndex = 63, Parent = f })
	Kit.Corner(orb, UDim.new(1, 0))
	Kit.Stroke(orb, 2, pet.Glow, Enum.ApplyStrokeMode.Border)
	Kit.Icon(orb, "pet_" .. pet.Id, PetsPanel.ShapeIcon[pet.Shape] or "👻", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Icon", TextSize = 22, Stroke = 0, ZIndex = 64 })
	Kit.Label(f, pet.Name, { Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(58, 5), Align = Enum.TextXAlignment.Left, Style = "Body", Fit = true, ZIndex = 63 })
	local rarity = string.upper(r and r.Name or pet.Rarity)
	Kit.Label(f, rarity, { Size = UDim2.new(0, 90, 0, 18), Position = UDim2.fromOffset(58, 30), Align = Enum.TextXAlignment.Left, Color = rc, Style = "Tiny", Fit = true, ZIndex = 63 })
	Kit.Label(f, PetsPanel.BonusText(pet.Bonus.Kind, pet.Bonus.Value), { Size = UDim2.new(1, -250, 0, 18), Position = UDim2.fromOffset(150, 30), Align = Enum.TextXAlignment.Left, Color = Theme.Ecto, Font = Theme.Body, Style = "Tiny", Fit = true, ZIndex = 63 })
	Kit.Label(f, pct(chance), { Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -10, 0, 0), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = Theme.Gold, Style = "Heading", Fit = true, ZIndex = 63 })
end

local function refresh()
	local d = State.Data
	local egg = currentEgg and Config.Eggs[currentEgg]
	if not d or not egg then
		return
	end
	panel.Title.Text = string.upper(egg.Name)
	priceLabel.Text = string.format("🔮 %s  •  you have %s", Format.Commas(egg.Price), Format.Short(d.Shards or 0))
	if Eggs.Unlocked(egg, d.TowerCheckpoint or 0) then
		lockLabel.Text = if egg.Unlock > 0 then string.format("UNLOCKED (Tower checkpoint %d)", egg.Unlock) else "Open to everyone"
		lockLabel.TextColor3 = Theme.Good
	else
		lockLabel.Text = string.format("🔒 LOCKED: clear Boss Tower checkpoint %d (yours: %d)", egg.Unlock, d.TowerCheckpoint or 0)
		lockLabel.TextColor3 = Theme.Bad
	end
	local reason = blockReason(egg, d)
	buyButton:SetAttribute("Color", if reason then "Gray" else "Green")
	reasonLabel.Text = reason or "Odds are exact: every hatch is rolled by the server"
	reasonLabel.TextColor3 = if reason then Theme.Bad else Theme.Muted
end

local function fill(eggId: string)
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local egg = Config.Eggs[eggId]
	for i, o in egg.Odds do
		local pet = Config.Pets[o.Pet]
		if pet then
			petRow(i, pet, o.Chance)
		end
	end
end

-- Request with a timeout: a lost reply counts as a failure (the caller retries with the same id).
local function requestBuy(eggId: string, requestId: string): any
	local result: any = nil
	task.spawn(function()
		local r = State.Request("BuyEgg", eggId, requestId)
		if result == nil then
			result = r
		end
	end)
	local t0 = os.clock()
	while result == nil and os.clock() - t0 < REQUEST_TIMEOUT do
		task.wait(0.1)
	end
	if result == nil then
		result = { ok = false, err = "Connection hiccup, try again" }
	end
	return result
end

--------------------------------------------------------------------------------
-- Hatch animation: egg wobbles, a soft crack, the pet appears. Brightness stays controlled
-- (half-dim backdrop, a 30% flash at most) so nothing blooms on phones.
--------------------------------------------------------------------------------
local function playHatch(egg: Config.EggDef, pet: Config.PetDef)
	playing = true
	local r = Config.Rarities[pet.Rarity]
	local rc = if r then r.Color else Theme.Text
	local root: Frame = Kit.new("Frame", { Name = "HatchFx", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 80, Parent = Kit.Overlay() })
	Kit.Tween(root, 0.3, { BackgroundTransparency = 0.45 })
	local eggFrame: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(150, 190),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = egg.Color,
		ZIndex = 81,
		Parent = root,
	})
	Kit.Corner(eggFrame, UDim.new(0.5, 0))
	Kit.Stroke(eggFrame, 4, egg.Accent, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(eggFrame, egg.Color:Lerp(Color3.new(1, 1, 1), 0.25), egg.Color, 90)
	local scale = Kit.new("UIScale", { Scale = 0.6, Parent = eggFrame })
	Kit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.4)
	-- wobble, getting stronger
	for i = 1, 6 do
		Sound.Play("CrateShake", 0.05)
		local a = 4 + i * 2
		Kit.Tween(eggFrame, 0.09, { Rotation = if i % 2 == 0 then a else -a })
		task.wait(0.1)
		Kit.Tween(eggFrame, 0.09, { Rotation = 0 })
		task.wait(0.12 + (6 - i) * 0.03)
	end
	-- soft crack: a zigzag line across the egg
	local crack = Kit.Label(eggFrame, "⚡", { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Icon", TextSize = 44, Stroke = 0, ZIndex = 82 })
	crack.TextColor3 = egg.Accent
	task.wait(0.35)
	local flash: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, ZIndex = 83, Parent = root })
	Kit.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	Kit.Tween(scale, 0.2, { Scale = 0.2 })
	Kit.Tween(eggFrame, 0.2, { BackgroundTransparency = 1 })
	if r and r.Sound then
		Sound.Play(r.Sound)
	else
		Sound.Play("Upgrade")
	end
	task.wait(0.2)
	eggFrame:Destroy()
	-- the pet card
	local card: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(300, 290),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 84,
		Parent = root,
	})
	Kit.Corner(card, UDim.new(0, 18))
	Kit.Stroke(card, 4, rc, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(card, Theme.Panel3, Theme.Panel, 90)
	local cardScale = Kit.new("UIScale", { Scale = 0.5, Parent = card })
	Kit.Tween(cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.Label(card, "YOU HATCHED", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 10), Color = Theme.Muted, Style = "Small", Fit = true, ZIndex = 85 })
	local orb: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0.5, 0, 0, 38), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = pet.Color, ZIndex = 85, Parent = card })
	Kit.Corner(orb, UDim.new(1, 0))
	Kit.Stroke(orb, 3, pet.Glow, Enum.ApplyStrokeMode.Border)
	Kit.Icon(orb, "pet_" .. pet.Id, PetsPanel.ShapeIcon[pet.Shape] or "👻", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Icon", TextSize = 44, Stroke = 0, ZIndex = 86 })
	Kit.Label(card, string.upper(pet.Name), { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 128), Style = "Title", Fit = true, ZIndex = 85 })
	Kit.Label(card, string.upper(r and r.Name or pet.Rarity), { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 160), Color = rc, Style = "Heading", Fit = true, ZIndex = 85 })
	Kit.Label(card, PetsPanel.BonusText(pet.Bonus.Kind, pet.Bonus.Value), { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 186), Color = Theme.Ecto, Font = Theme.Body, Style = "Small", Fit = true, ZIndex = 85 })
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Kit.Tween(root, 0.2, { BackgroundTransparency = 1 })
		Kit.Tween(cardScale, 0.15, { Scale = 0.7 })
		task.delay(0.2, function()
			root:Destroy()
			playing = false
		end)
	end
	Kit.Button(card, { Text = "NICE!", Color = "Green", Size = UDim2.fromOffset(160, 44), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 86, OnClick = close })
	task.delay(8, close)
end

local function buy()
	local eggId = currentEgg
	local d = State.Data
	local egg = eggId and Config.Eggs[eggId]
	if busy or playing or not eggId or not egg or not d then
		return
	end
	local reason = blockReason(egg, d)
	if reason then
		Kit.Toast(reason, "Bad")
		return
	end
	busy = true
	Kit.SetButtonText(buyButton, "HATCHING...")
	local requestId = HttpService:GenerateGUID(false)
	local res = requestBuy(eggId, requestId)
	if not res.ok and RETRY_ERRORS[tostring(res.err)] then
		task.wait(1.2)
		res = requestBuy(eggId, requestId) -- same id: the server returns the saved result if it already hatched
	end
	busy = false
	Kit.SetButtonText(buyButton, "🥚 BUY & HATCH")
	if not res.ok then
		local msg = res.err or "Can't do that right now"
		if RETRY_ERRORS[tostring(res.err)] then
			msg ..= " - if your shards went down, your pet is already in PETS"
		end
		Kit.Toast(msg, "Bad")
		return
	end
	local pet: Config.PetDef? = if type(res.Pet) == "string" then Config.Pets[res.Pet] else nil
	panel:Close()
	if pet then
		playHatch(egg, pet)
		Kit.Toast("You got " .. pet.Name .. "! Equip it in PETS.", "Good")
	end
end

function Hatchery.Open(eggId: string)
	if not Config.Eggs[eggId] or playing then
		return
	end
	currentEgg = eggId
	fill(eggId)
	panel:Open()
	refresh()
end

function Hatchery.Init()
	panel = Kit.Panel("Hatchery", "PET HATCHERY", Vector2.new(600, 480), "Purple")
	local body = panel.Body
	priceLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 10), Color = SHARD, Style = "Currency", Fit = true, ZIndex = 62 })
	lockLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 40), Style = "Small", Fit = true, ZIndex = 62 })
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -142),
		Position = UDim2.fromOffset(0, 66),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = list })
	reasonLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -72), Font = Theme.Body, Style = "Small", Fit = true, Stroke = 0, ZIndex = 62 })
	buyButton = Kit.Button(body, {
		Text = "🥚 BUY & HATCH",
		Color = "Gray",
		Size = UDim2.fromOffset(240, 46),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = function()
			task.spawn(buy)
		end,
	})
	panel.Primary = buyButton
end

function Hatchery.Start()
	local player = Players.LocalPlayer
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player or Reveal.IsPlaying() then
			return
		end
		local eggId = prompt:GetAttribute("Egg")
		if eggId == nil and prompt.Parent then
			eggId = prompt.Parent:GetAttribute("Egg")
		end
		if type(eggId) == "string" then
			Hatchery.Open(eggId)
		end
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return Hatchery
