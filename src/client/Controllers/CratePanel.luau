--!strict
-- Crate station panel: odds (with luck boost), possible hunters, price and the OPEN button.
-- Opened by the station's ProximityPrompt. The server rolls; we only play the reveal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Icons = require(GH.Icons)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Signal = require(GH.Signal)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local Reveal = require(script.Parent.Reveal)

local CratePanel = {}

local player = Players.LocalPlayer
local panel: Kit.Panel
local list: ScrollingFrame
local openButton: TextButton
local tripleButton: TextButton
local autoButton: TextButton
local luckyButton: TextButton
-- Auto Open results waiting to be shown (the server keeps opening while one plays)
local autoQueue: { any } = {}
local autoPlaying = false
local infoLabel: TextLabel
local luckLabel: TextLabel
local current: string? = nil
local crateIcon: ImageLabel
local busy = false
local openedSignal = Signal.new()
CratePanel.Opened = openedSignal -- (result) after a successful purchase

local function rarityOrder(id: string): number
	local h = Config.Hunters[id]
	return if h then Config.Rarities[h.Rarity].Order else 1
end

local function nearStation(crateId: string): boolean
	local pos = Config.Layout.CrateStations[crateId]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return pos ~= nil and root ~= nil and (root.Position - pos).Magnitude < 28
end

local cardsKey = ""
local refreshCards: (string, any, { [string]: number }, number) -> ()
local refreshButton: (string, any, number) -> ()

local function refresh()
	local crateId = current
	local d = State.Data
	if not crateId or not d then
		return
	end
	local crate = Config.Crates[crateId]
	panel.Title.Text = crate.Name
	local img = Icons.Get(Icons.ForCrate[crateId])
	crateIcon.Image = img or ""
	crateIcon.Visible = img ~= nil
	-- the luck boost ends on the server clock even if no new snapshot arrives
	local luck = if (d.Boosts.Luck or 0) > State.Now() then Config.Boosts.Luck.Multiplier else 1
	if d.LuckyOpens and (d.LuckyOpens[crateId] or 0) > 0 then
		luck *= Config.LuckyOpens.Multiplier
	end
	local odds = Rules.Odds(crate.Pool :: any, rarityOrder, luck, Config.LuckAffectsFromOrder)
	-- cards only change with the crate, luck or discoveries; the button changes with Ectoplasm
	local key = crateId .. "|" .. luck
	for _, e in crate.Pool do
		key ..= if d.Discovered[e.Hunter] then "1" else "0"
	end
	if key ~= cardsKey then
		cardsKey = key
		refreshCards(crateId, d, odds, luck)
	end
	refreshButton(crateId, d, luck)
end

function refreshCards(crateId: string, d: any, odds: { [string]: number }, luck: number)
	local crate = Config.Crates[crateId]
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, e in crate.Pool do
		local def = Config.Hunters[e.Hunter]
		local rar = Config.Rarities[def.Rarity]
		local found = d.Discovered[e.Hunter] == true
		local card: Frame = Kit.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			ZIndex = 62,
			Parent = list,
		})
		Kit.Corner(card, UDim.new(0, 14))
		Kit.Stroke(card, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
		Kit.Gradient(card, rar.Color, rar.Color2, 90)
		local pic: Frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(88, 88),
			Position = UDim2.new(0.5, 0, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(30, 18, 55),
			BackgroundTransparency = 0.3,
			ZIndex = 63,
			Parent = card,
		})
		Kit.Corner(pic, UDim.new(1, 0))
		Portrait.Face(pic, e.Hunter, not found)
		Kit.Label(card, if found then string.upper(def.Name) else "???", { Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 100), ZIndex = 64, Style = "Body", Fit = true })
		Kit.Label(card, rar.Name, { Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 121), ZIndex = 64, Color = Color3.fromRGB(255, 255, 240), Style = "Small", Fit = true })
		Kit.Label(card, "⚡ " .. Format.Commas(def.Power), { Size = UDim2.new(0.55, 0, 0, 22), Position = UDim2.new(0, 8, 1, -28), ZIndex = 64, Color = Theme.Gold, Align = Enum.TextXAlignment.Left, Style = "Small", Fit = true })
		local pct = Kit.Label(card, Format.Percent(odds[e.Hunter]), { Size = UDim2.new(0.45, 0, 0, 24), Position = UDim2.new(1, -8, 1, -29), AnchorPoint = Vector2.new(1, 0), ZIndex = 64, Align = Enum.TextXAlignment.Right, Style = "Heading", Fit = true })
		if luck > 1 and rar.Order >= Config.LuckAffectsFromOrder then
			pct.TextColor3 = Theme.Ecto
		end
	end
end

function refreshButton(crateId: string, d: any, luck: number)
	local crate = Config.Crates[crateId]
	local free = d.FreeCrates[crateId] or 0
	local price = crate.Price
	if free > 0 then
		Kit.SetButtonText(openButton, "OPEN FREE! (" .. free .. ")")
		openButton:SetAttribute("Color", "Orange")
	elseif d.Ecto >= price then
		Kit.SetButtonText(openButton, "OPEN  💚 " .. Format.Commas(price))
		openButton:SetAttribute("Color", "Green")
	else
		Kit.SetButtonText(openButton, "NEED 💚 " .. Format.Short(price - d.Ecto) .. " MORE")
		openButton:SetAttribute("Color", "Gray")
	end
	if not d.Zones[crate.Zone] then
		infoLabel.Text = "Unlock " .. (Config.ZoneById[crate.Zone] :: Config.ZoneDef).Name .. " to open this crate"
	else
		infoLabel.Text = "Better crates > stronger hunters!"
	end
	local left = if d.LuckyOpens then d.LuckyOpens[crateId] or 0 else 0
	local L = Config.LuckyOpens
	Kit.SetButtonText(luckyButton, string.format("🍀 x%d LUCKY  💚 %s", L.Opens, Format.Short(price * L.PriceMultiplier)))
	luckyButton:SetAttribute("Color", if d.Ecto >= price * L.PriceMultiplier then "Teal" else "Gray")
	luckLabel.Text = if left > 0
		then string.format("🍀 %d LUCKY OPEN%s LEFT: rare odds x%d!", left, if left == 1 then "" else "S", L.Multiplier)
		else "🍀 LUCK BOOST: rare odds boosted!"
	luckLabel.Visible = luck > 1
	local autoOwned = d.Passes and d.Passes[Config.AutoOpen.Pass] == true
	local autoOn = player:GetAttribute("AutoOpen") ~= nil
	Kit.SetButtonText(autoButton, if not autoOwned then "🔒 AUTO OPEN" elseif autoOn then "AUTO OPEN: ON" else "AUTO OPEN: OFF")
	autoButton:SetAttribute("Color", if not autoOwned then "Gray" elseif autoOn then "Green" else "Purple")
	local triple = d.Passes and d.Passes[Config.TripleOpen.Pass] == true
	tripleButton.Visible = triple == true
	openButton.Position = if triple then UDim2.new(0.5, -75, 1, -4) else UDim2.new(0.5, 0, 1, -4)
	if triple then
		Kit.SetButtonText(tripleButton, "OPEN x3  💚 " .. Format.Short(price * Config.TripleOpen.Count))
	end
end

-- Plays the best of several results (Triple Open) and lists the rest as toasts.
local function rarityOf(id: string): number
	local h = Config.Hunters[id]
	return if h then Config.Rarities[h.Rarity].Order else 0
end

local function playResults(crateId: string, first: any, again: (() -> ())?)
	local all = { { Uid = first.Uid, Hunter = first.Hunter, IsNew = first.IsNew == true } }
	for _, m in (first.More or {}) :: { any } do
		table.insert(all, { Uid = m.Uid, Hunter = m.Hunter, IsNew = m.IsNew == true })
	end
	table.sort(all, function(a, b)
		return rarityOf(a.Hunter) > rarityOf(b.Hunter)
	end)
	for _, r in all do
		openedSignal:Fire({ Crate = crateId, Hunter = r.Hunter, Uid = r.Uid, IsNew = r.IsNew })
	end
	local best = all[1]
	Reveal.Play({ Crate = crateId, Hunter = best.Hunter, Uid = best.Uid, IsNew = best.IsNew }, again)
	for i = 2, #all do
		local h = Config.Hunters[all[i].Hunter]
		if h then
			Kit.Toast("Also got: " .. Config.Rarities[h.Rarity].Name .. " " .. h.Name .. (if all[i].IsNew then " (NEW!)" else ""), "Good")
		end
	end
end

local function buyTriple()
	local crateId = current
	if busy or not crateId or Reveal.IsPlaying() then
		return
	end
	if player:GetAttribute("AutoOpen") then
		Kit.Toast("Turn AUTO OPEN off first", "Bad")
		return
	end
	if not nearStation(crateId) then
		Kit.Toast("Walk to the crate first!", "Bad")
		return
	end
	busy = true
	local res = State.Request("OpenCrate", crateId, Config.TripleOpen.Count)
	busy = false
	if not res.ok then
		Kit.Toast(res.err or "Couldn't open the crate", "Bad")
		return
	end
	panel:Close()
	playResults(crateId, res, nil)
end

local function buy()
	local crateId = current
	if busy or not crateId or Reveal.IsPlaying() then
		return
	end
	if player:GetAttribute("AutoOpen") then
		Kit.Toast("Turn AUTO OPEN off first", "Bad")
		return
	end
	local d = State.Data
	local crate = Config.Crates[crateId]
	if d and (d.FreeCrates[crateId] or 0) <= 0 and d.Ecto < crate.Price then
		Kit.Toast("Defeat ghosts to collect more Ectoplasm!", "Bad")
		return
	end
	if not nearStation(crateId) then
		Kit.Toast("Walk to the crate first!", "Bad")
		return
	end
	busy = true
	local res = State.Request("OpenCrate", crateId)
	busy = false
	if not res.ok then
		Kit.Toast(res.err or "Couldn't open the crate", "Bad")
		return
	end
	panel:Close()
	local result: Reveal.Result = { Crate = crateId, Hunter = res.Hunter, Uid = res.Uid, IsNew = res.IsNew == true }
	openedSignal:Fire(result)
	local function again()
		if busy then
			return
		end
		local dd = State.Data
		if dd and (dd.FreeCrates[crateId] or 0) <= 0 and dd.Ecto < crate.Price then
			Kit.Toast("Not enough Ectoplasm!", "Bad")
			return
		end
		busy = true
		local r2 = State.Request("OpenCrate", crateId)
		busy = false
		if r2.ok then
			local res2: Reveal.Result = { Crate = crateId, Hunter = r2.Hunter, Uid = r2.Uid, IsNew = r2.IsNew == true }
			openedSignal:Fire(res2)
			Reveal.Play(res2, again)
		else
			Kit.Toast(r2.err or "Couldn't open the crate", "Bad")
		end
	end
	Reveal.Play(result, again)
end

function CratePanel.Open(crateId: string)
	if not Config.Crates[crateId] or Reveal.IsPlaying() then
		return
	end
	current = crateId
	refresh()
	panel:Open()
end

function CratePanel.Init()
	panel = Kit.Panel("Crate", "HUNTER CRATE", Vector2.new(700, 380), "Orange")
	-- crate picture in the top-left corner (uploaded icon per crate, see Icons.ForCrate)
	crateIcon = Kit.new("ImageLabel", {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(-14, -34),
		ZIndex = 64,
		Visible = false,
		Parent = panel.Root,
	})
	infoLabel = Kit.Label(panel.Body, "", { Size = UDim2.new(1, -400, 0, 20), Position = UDim2.fromOffset(0, 12), Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, ZIndex = 62 })
	luckLabel = Kit.Label(panel.Body, "🍀 LUCK BOOST: rare odds boosted!", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 32), Color = Theme.Ecto, Style = "Small", ZIndex = 62 })
	luckLabel.Visible = false
	-- cards wrap onto more rows (and scroll) when the panel is narrow (phones, portrait)
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -118),
		Position = UDim2.fromOffset(0, 54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(148, 160),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = list })
	openButton = Kit.Button(panel.Body, {
		Text = "OPEN",
		Color = "Green",
		Size = UDim2.fromOffset(280, 50),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = buy,
	})
	openButton.Name = "OpenButton"
	panel.Primary = openButton
	tripleButton = Kit.Button(panel.Body, {
		Text = "OPEN x3",
		Color = "Purple",
		Size = UDim2.fromOffset(200, 50),
		Position = UDim2.new(0.5, 185, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		TextStyle = "Small",
		ZIndex = 63,
		OnClick = buyTriple,
	})
	tripleButton.Visible = false
	-- LUCKY OPENS (Ectoplasm): next few opens of this crate at higher luck
	luckyButton = Kit.Button(panel.Body, {
		Text = "🍀 LUCKY",
		Color = "Teal",
		Size = UDim2.fromOffset(200, 34),
		Position = UDim2.new(1, -180, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextStyle = "Small",
		ZIndex = 63,
		OnClick = function()
			local crateId = current
			if busy or not crateId then
				return
			end
			busy = true
			local res = State.Request("BuyLuckyOpens", crateId)
			busy = false
			if res.ok then
				Kit.Toast(string.format("🍀 %d lucky opens ready for this crate!", res.Left or Config.LuckyOpens.Opens), "Good")
				refresh()
			else
				Kit.Toast(res.err or "Couldn't buy luck", "Bad")
			end
		end,
	})
	-- AUTO OPEN (game pass; NOT Auto Attack, which is free): locked button prompts the pass
	autoButton = Kit.Button(panel.Body, {
		Text = "🔒 AUTO OPEN",
		Color = "Gray",
		Size = UDim2.fromOffset(170, 34),
		Position = UDim2.new(1, 0, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextStyle = "Small",
		ZIndex = 63,
		OnClick = function()
			local crateId = current
			local d = State.Data
			if busy or not crateId or not d then
				return
			end
			local owned = d.Passes and d.Passes[Config.AutoOpen.Pass] == true
			if not owned then
				local res = State.Request("Buy", Config.AutoOpen.Pass)
				if not res.ok then
					Kit.Toast(res.err or "Auto Open isn't available yet", "Bad")
				end
				return
			end
			if player:GetAttribute("AutoOpen") then
				State.Request("AutoOpen", nil)
				refresh()
				return
			end
			if not nearStation(crateId) then
				Kit.Toast("Walk to the crate first!", "Bad")
				return
			end
			busy = true
			local res = State.Request("AutoOpen", crateId)
			busy = false
			if res.ok then
				panel:Close()
				Kit.Toast("AUTO OPEN: ON - stand still at the crate", "Good")
			else
				Kit.Toast(if res.err == "NeedPass" then "Auto Open is a game pass" else (res.err or "Couldn't start"), "Bad")
			end
		end,
	})
end

function CratePanel.Start()
	-- Robux Exclusive Crate: the server grants the hunter and tells us to play the reveal
	-- AUTO OPEN results: play them one after another (never two reveals at once)
	local function playNextAuto()
		if autoPlaying then
			return
		end
		local nextRes = table.remove(autoQueue, 1)
		if not nextRes then
			return
		end
		autoPlaying = true
		openedSignal:Fire(nextRes)
		Reveal.Play(nextRes, nil, { Auto = true })
	end
	Reveal.Finished:Connect(function()
		if autoPlaying then
			autoPlaying = false
			task.defer(playNextAuto)
		end
	end)
	Reveal.AutoStopped:Connect(function()
		table.clear(autoQueue)
	end)
	State.OnFx("AutoOpened", function(data: any)
		if type(data) ~= "table" or type(data.Hunter) ~= "string" or not Config.Hunters[data.Hunter] then
			return
		end
		local res: Reveal.Result = { Crate = tostring(data.Crate), Hunter = data.Hunter, Uid = tostring(data.Uid), IsNew = data.IsNew == true }
		if #autoQueue >= 3 then
			-- reveals can't keep up: list the extra hunter instead of queueing forever
			local h = Config.Hunters[res.Hunter]
			Kit.Toast("Auto Open: " .. Config.Rarities[h.Rarity].Name .. " " .. h.Name, "Good")
			openedSignal:Fire(res)
			return
		end
		table.insert(autoQueue, res)
		if panel.IsOpen then
			panel:Close()
		end
		playNextAuto()
	end)
	State.OnFx("AutoOpenStopped", function(data: any)
		local reason = if type(data) == "table" and type(data.Reason) == "string" then data.Reason else "stopped"
		Kit.Toast("AUTO OPEN stopped: " .. reason, "Bad")
	end)

	State.OnFx("Exclusive", function(data: any)
		if type(data) == "table" and type(data.Hunter) == "string" and Config.Hunters[data.Hunter] then
			if panel.IsOpen then
				panel:Close()
			end
			local res: Reveal.Result = { Crate = "Exclusive", Hunter = data.Hunter, Uid = tostring(data.Uid), IsNew = data.IsNew == true }
			openedSignal:Fire(res)
			Reveal.Play(res, nil)
		end
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
	State.EctoChanged:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.IsOpen then
				refresh() -- keeps the odds honest when a luck boost runs out
			end
		end
	end)
end

function CratePanel.Button(): TextButton
	return openButton
end

function CratePanel.IsOpen(): boolean
	return panel.IsOpen
end

return CratePanel
