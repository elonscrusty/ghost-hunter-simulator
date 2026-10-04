--!strict
-- PET HATCHERY egg panel (looks like the hunter crate panel). The world pedestals (server World/Hatchery) carry a
-- "View" ProximityPrompt with attribute Egg = egg id; triggering it opens this panel for that
-- egg: price, lock state, a grid of every possible pet with its rarity, bonus and EXACT odds, and a
-- BUY & HATCH button. The server ("BuyEgg") checks, rolls, charges and saves in one step;
-- each purchase carries a request id, and a failed/timed-out request is retried ONCE with the
-- SAME id, so a retry can never charge twice or roll again. The hatch plays as a crate-style
-- cinematic (Reveal.PlayPet) of the result the server already saved.
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
local PetPortrait = require(Client.UI.PetPortrait)
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

-- One pet card, laid out like a CratePanel hunter card (rarity gradient, round picture).
local function petCard(order: number, pet: Config.PetDef, chance: number)
	local r = Config.Rarities[pet.Rarity]
	local card: Frame = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 62, Parent = list })
	Kit.Corner(card, UDim.new(0, 14))
	Kit.Stroke(card, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(card, if r then r.Color else Theme.Panel3, if r then r.Color2 else Theme.Panel, 90)
	local pic: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(80, 80),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = pet.Color:Lerp(Color3.new(0, 0, 0), 0.5),
		ZIndex = 63,
		Parent = card,
	})
	Kit.Corner(pic, UDim.new(1, 0))
	Kit.Stroke(pic, 3, pet.Glow, Enum.ApplyStrokeMode.Border)
	PetPortrait.New(pic, pet.Id)
	Kit.Label(card, string.upper(pet.Name), { Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 92), ZIndex = 64, Style = "Body", Fit = true })
	Kit.Label(card, r and r.Name or string.upper(pet.Rarity), { Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 113), ZIndex = 64, Color = Color3.fromRGB(255, 255, 240), Style = "Small", Fit = true })
	-- two short lines (a one-line "+25% POWER for all hunters" was cut to "+25% PO…" here)
	local bonus = string.gsub(PetsPanel.BonusText(pet.Bonus.Kind, pet.Bonus.Value), " for all hunters", "")
	Kit.Label(card, bonus, { Size = UDim2.new(0.6, -8, 0, 28), Position = UDim2.new(0, 8, 1, -32), ZIndex = 64, Color = Theme.Ecto, Align = Enum.TextXAlignment.Left, Style = "Tiny", Wrap = true })
	Kit.Label(card, pct(chance), { Size = UDim2.new(0.4, 0, 0, 24), Position = UDim2.new(1, -8, 1, -29), AnchorPoint = Vector2.new(1, 0), ZIndex = 64, Align = Enum.TextXAlignment.Right, Style = "Heading", Fit = true })
end

local function refresh()
	local d = State.Data
	local egg = currentEgg and Config.Eggs[currentEgg]
	if not d or not egg then
		return
	end
	panel.Title.Text = string.upper(egg.Name)
	Kit.IconText(priceLabel, string.format("🔮 %s  •  you have 🔮 %s", Format.Commas(egg.Price), Format.Short(d.Shards or 0)))
	if Eggs.Unlocked(egg, d.TowerCheckpoint or 0) then
		Kit.IconText(lockLabel, if egg.Unlock > 0 then string.format("UNLOCKED (Tower checkpoint %d)", egg.Unlock) else "Open to everyone")
		lockLabel.TextColor3 = Theme.Good
	else
		Kit.IconText(lockLabel, string.format("🔒 Unlock: Tower checkpoint %d (yours: %d)", egg.Unlock, d.TowerCheckpoint or 0))
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
			petCard(i, pet, o.Chance)
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

local hatch: (string?, boolean) -> ()
hatch = function(eggId: string?, fromAgain: boolean)
	local d = State.Data
	local egg = eggId and Config.Eggs[eggId]
	-- HATCH AGAIN runs while the reveal card is still up; the BUY button never does
	if busy or (not fromAgain and Reveal.IsPlaying()) or not eggId or not egg or not d then
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
		local id = eggId :: string
		Reveal.PlayPet({ Egg = id, Pet = pet.Id }, function()
			hatch(id, true)
		end)
	end
end

local function buy()
	hatch(currentEgg, false)
end

function Hatchery.Open(eggId: string)
	if not Config.Eggs[eggId] or Reveal.IsPlaying() then
		return
	end
	currentEgg = eggId
	fill(eggId)
	panel:Open()
	refresh()
end

function Hatchery.Init()
	panel = Kit.Panel("Hatchery", "PET HATCHERY", Vector2.new(700, 420), "Purple")
	local body = panel.Body
	priceLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 10), Color = SHARD, Style = "Currency", Fit = true, ZIndex = 62 })
	lockLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 40), Style = "Small", Fit = true, ZIndex = 62 })
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -146),
		Position = UDim2.fromOffset(0, 64),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = body,
	})
	-- cards wrap onto more rows (and scroll) when the panel is narrow (phones, portrait)
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(148, 160),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = list })
	reasonLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -72), Font = Theme.Body, Style = "Small", Fit = true, Stroke = 0, ZIndex = 62 })
	buyButton = Kit.Button(body, {
		Text = "🥚 BUY & HATCH",
		Color = "Gray",
		Size = UDim2.fromOffset(280, 50),
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
