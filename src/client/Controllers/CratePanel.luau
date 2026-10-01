--!strict
-- Crate station panel: odds (with luck boost), possible hunters, price and the OPEN button.
-- Opened by the station's ProximityPrompt. The server rolls; we only play the reveal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local Reveal = require(script.Parent.Reveal)

local CratePanel = {}

local player = Players.LocalPlayer
local panel: Kit.Panel
local list: Frame
local openButton: TextButton
local infoLabel: TextLabel
local luckLabel: TextLabel
local current: string? = nil
local busy = false
local openedSignal = Instance.new("BindableEvent")
CratePanel.Opened = openedSignal.Event -- (result) after a successful purchase

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
	local luck = d.LuckMultiplier or 1
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
			Size = UDim2.fromOffset(176, 236),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			ZIndex = 62,
			Parent = list,
		})
		Kit.Corner(card, UDim.new(0, 18))
		Kit.Stroke(card, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
		Kit.Gradient(card, rar.Color, rar.Color2, 90)
		local pic: Frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(120, 120),
			Position = UDim2.new(0.5, 0, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(30, 18, 55),
			BackgroundTransparency = 0.3,
			ZIndex = 63,
			Parent = card,
		})
		Kit.Corner(pic, UDim.new(1, 0))
		Portrait.Face(pic, e.Hunter, not found)
		Kit.Label(card, if found then string.upper(def.Name) else "???", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 134), ZIndex = 64 })
		Kit.Label(card, rar.Name, { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 164), ZIndex = 64, Color = Color3.fromRGB(255, 255, 240) })
		Kit.Label(card, "⚡ " .. Format.Commas(def.Power), { Size = UDim2.new(0.55, 0, 0, 26), Position = UDim2.fromOffset(8, 196), ZIndex = 64, Color = Theme.Gold, Align = Enum.TextXAlignment.Left })
		local pct = Kit.Label(card, Format.Percent(odds[e.Hunter]), { Size = UDim2.new(0.42, 0, 0, 28), Position = UDim2.new(1, -8, 0, 195), AnchorPoint = Vector2.new(1, 0), ZIndex = 64, Align = Enum.TextXAlignment.Right })
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
		infoLabel.Text = "Hunters jump out of crates! Better crates → stronger hunters."
	end
	luckLabel.Visible = luck > 1
end

local function buy()
	local crateId = current
	if busy or not crateId or Reveal.IsPlaying() then
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
	panel = Kit.Panel("Crate", "HUNTER CRATE", Vector2.new(820, 470), "Orange")
	infoLabel = Kit.Label(panel.Body, "", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 14), Color = Theme.Muted, Font = Theme.Body, ZIndex = 62, Stroke = 0 })
	luckLabel = Kit.Label(panel.Body, "🍀 LUCK BOOST ACTIVE: rare odds boosted!", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 40), Color = Theme.Ecto, ZIndex = 62 })
	luckLabel.Visible = false
	list = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 240),
		Position = UDim2.fromOffset(0, 70),
		BackgroundTransparency = 1,
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	openButton = Kit.Button(panel.Body, {
		Text = "OPEN",
		Color = "Green",
		Size = UDim2.fromOffset(340, 72),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = buy,
	})
	openButton.Name = "OpenButton"
end

function CratePanel.Start()
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
end

function CratePanel.Button(): TextButton
	return openButton
end

function CratePanel.IsOpen(): boolean
	return panel.IsOpen
end

return CratePanel
