--!strict
-- SHOP: Robux products (Ectoplasm packs, boosts) and game passes. Items without an id in
-- Config show "SOON". Purchases are prompted and granted by the server only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
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

local function card(parent: Instance, order: number, icon: string, name: string, sub: string, price: string, available: boolean, color: string, onBuy: () -> ()): (TextButton, TextLabel)
	local f: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(196, 232), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 62, Parent = parent })
	Kit.Corner(f, UDim.new(0, 18))
	Kit.Stroke(f, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local c = Theme.Buttons[color] or Theme.Buttons.Purple
	Kit.Gradient(f, c[1], c[2], 90)
	Kit.Label(f, icon, { Size = UDim2.fromOffset(80, 70), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 63, Stroke = 0 })
	Kit.Label(f, name, { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 80), ZIndex = 63 })
	local subLabel = Kit.Label(f, sub, { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 126), ZIndex = 63, Color = Color3.fromRGB(255, 255, 230), Font = Theme.Body })
	local b = Kit.Button(f, {
		Text = if available then price else "SOON",
		Color = if available then "Green" else "Gray",
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.new(0.5, 0, 1, -12),
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
	panel = Kit.Panel("Shop", "SHOP", Vector2.new(900, 560), "Pink")
	local scroll: ScrollingFrame = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -16),
		Position = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		ScrollBarThickness = 10,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local function section(order: number, title: string): Frame
		Kit.Label(scroll, title, { Size = UDim2.new(1, 0, 0, 30), ZIndex = 62 }).LayoutOrder = order
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 240), BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 61, Parent = scroll })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		return row
	end
	local prodRow = section(1, "BOOSTS & ECTOPLASM")
	for i, p in Config.Products do
		local sub = if p.Kind == "Ecto" then "+" .. Format.Short(p.Amount or 0) .. " ECTOPLASM" else Format.Time(p.Seconds or 0) .. " BOOST"
		local _, subLabel = card(prodRow, i, p.Icon, p.Name, sub, p.PriceLabel, p.ProductId ~= nil, if p.Kind == "Ecto" then "Green" else "Purple", function()
			buy(p.Key)
		end)
		if p.Kind == "Ecto" then
			ectoLabels[p.Key] = subLabel
		end
	end
	local passRow = section(3, "GAME PASSES (FOREVER)")
	for i, pass in Config.GamePasses do
		local sub = if pass.Slots then "+" .. pass.Slots .. " EQUIPPED HUNTERS" else "x" .. tostring(pass.Multiplier or 2) .. " ALL ECTOPLASM"
		local b = card(passRow, i, pass.Icon, pass.Name, sub, pass.PriceLabel, pass.PassId ~= nil, "Orange", function()
			buy(pass.Key)
		end)
		passButtons[pass.Key] = b
	end
	Kit.Label(scroll, "Ectoplasm packs grow with the furthest area you've unlocked.", { Size = UDim2.new(1, 0, 0, 24), Color = Theme.Muted, Font = Theme.Body, ZIndex = 62, Stroke = 0 }).LayoutOrder = 5
	Hud.RegisterPanel("Shop", function()
		panel:Toggle()
	end)
end

function ShopPanel.Start()
	panel.OnOpen.Event:Connect(refresh)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return ShopPanel
