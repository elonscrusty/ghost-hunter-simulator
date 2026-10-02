--!strict
-- SHOP: Robux products (Ectoplasm packs, boosts) and game passes. Items without an id in
-- Config show "SOON". Purchases are prompted and granted by the server only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Icons = require(GH.Icons)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)

local ShopPanel = {}

local panel: Kit.Panel
local passButtons: { [string]: TextButton } = {}
local ectoLabels: { [string]: TextLabel } = {}

local function card(parent: Instance, order: number, iconKey: string?, icon: string, name: string, sub: string, price: string, available: boolean, color: string, onBuy: () -> ()): (TextButton, TextLabel)
	local f: Frame = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 62, Parent = parent })
	Kit.Corner(f, UDim.new(0, 14))
	Kit.Stroke(f, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local c = Theme.Buttons[color] or Theme.Buttons.Purple
	Kit.Gradient(f, c[1], c[2], 90)
	Kit.Icon(f, iconKey, icon, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), Style = "Icon", TextSize = 32, ZIndex = 63, Stroke = 0 })
	Kit.Label(f, name, { Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, 48), Style = "Body", ZIndex = 63 })
	local subLabel = Kit.Label(f, sub, { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 84), ZIndex = 63, Color = Color3.fromRGB(255, 255, 230), Font = Theme.Body, Style = "Tiny", Stroke = 1 })
	local b = Kit.Button(f, {
		Text = if available then price else "SOON",
		Color = if available then "Green" else "Gray",
		Size = UDim2.new(1, -16, 0, 38),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 64,
		OnClick = onBuy,
	})
	return b, subLabel
end

local function buy(key: string)
	local res = State.Request("Buy", key)
	if not res.ok then
		Kit.Toast(res.err or "Can't buy that right now", "Bad")
	end
end

local function refresh()
	local d = State.Data
	if not d then
		return
	end
	local mult = d.ZoneMultiplier or 1
	for _, p in Config.Products do
		local l = ectoLabels[p.Key]
		if l and p.Amount then
			l.Text = "+" .. Format.Short(p.Amount * mult) .. " ECTOPLASM"
		end
	end
	for _, pass in Config.GamePasses do
		local b = passButtons[pass.Key]
		if b and d.Passes and d.Passes[pass.Key] then
			Kit.SetButtonText(b, "OWNED ✓")
			b:SetAttribute("Color", "Gray")
		end
	end
end

function ShopPanel.Init()
	panel = Kit.Panel("Shop", "SHOP", Vector2.new(780, 500), "Pink")
	local scroll: ScrollingFrame = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.fromOffset(0, 10),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	-- cards wrap to as many rows as the panel width needs
	local function section(order: number, title: string): Frame
		Kit.Label(scroll, title, { Size = UDim2.new(1, 0, 0, 24), Style = "Heading", ZIndex = 62 }).LayoutOrder = order
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 61, Parent = scroll })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 168), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		return row
	end
	local prodRow = section(1, "BOOSTS & ECTOPLASM")
	for i, p in Config.Products do
		local sub = if p.Kind == "Ecto" then "+" .. Format.Short(p.Amount or 0) .. " ECTOPLASM" else Format.Time(p.Seconds or 0) .. " BOOST"
		local _, subLabel = card(prodRow, i, Icons.ForProduct[p.Key], p.Icon, p.Name, sub, p.PriceLabel, p.ProductId ~= nil, if p.Kind == "Ecto" then "Green" else "Purple", function()
			buy(p.Key)
		end)
		if p.Kind == "Ecto" then
			ectoLabels[p.Key] = subLabel
		end
	end
	local passRow = section(3, "GAME PASSES (FOREVER)")
	for i, pass in Config.GamePasses do
		local sub = if pass.Blurb then pass.Blurb elseif pass.Slots then "+" .. pass.Slots .. " EQUIPPED HUNTERS" else "x" .. tostring(pass.Multiplier or 2) .. " ALL ECTOPLASM"
		local b = card(passRow, i, Icons.ForProduct[pass.Key], pass.Icon, pass.Name, sub, pass.PriceLabel, pass.PassId ~= nil, "Orange", function()
			buy(pass.Key)
		end)
		passButtons[pass.Key] = b
	end
	Kit.Label(scroll, "Ectoplasm packs grow with the furthest area you've unlocked. Auto Attack only picks targets for you: same damage, same rewards.", { Size = UDim2.new(1, -10, 0, 36), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 62, Stroke = 0 }).LayoutOrder = 5
	Hud.RegisterPanel("Shop", function()
		panel:Toggle()
	end)
end

function ShopPanel.Start()
	panel.OnOpen:Connect(refresh)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return ShopPanel
