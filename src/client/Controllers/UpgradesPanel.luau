--!strict
-- UPGRADES: Pickup Radius, Ectoplasm Bonus, Movement Speed. Level pips, current → next value
-- and an escalating price; the server validates every purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)
local Effects = require(script.Parent.Effects)

local UpgradesPanel = {}

type Row = { Pips: { Frame }, Value: TextLabel, Buy: TextButton }

local panel: Kit.Panel
local rows: { [string]: Row } = {}

local function fmt(up: Config.UpgradeDef, v: number): string
	if up.Format == "percent" then
		return "+" .. math.floor(v * 100 + 0.5) .. "%"
	elseif up.Format == "studs" then
		return v .. " studs"
	end
	return tostring(v)
end

local function refresh()
	local d = State.Data
	if not d then
		return
	end
	for id, row in rows do
		local up = Config.Upgrades[id]
		local level = d.Upgrades[id] or 1
		for i, pip in row.Pips do
			pip.BackgroundColor3 = if i <= level then Theme.Ecto else Theme.Bg
		end
		local cur = Rules.UpgradeValue(up.Levels, level)
		local cost = Rules.UpgradeCost(up.Costs, level)
		if cost then
			row.Value.Text = fmt(up, cur) .. "  →  " .. fmt(up, Rules.UpgradeValue(up.Levels, level + 1))
			Kit.SetButtonText(row.Buy, "💚 " .. Format.Short(cost))
			row.Buy:SetAttribute("Color", if d.Ecto >= cost then "Green" else "Gray")
		else
			row.Value.Text = fmt(up, cur) .. "  (MAX)"
			Kit.SetButtonText(row.Buy, "MAXED ★")
			row.Buy:SetAttribute("Color", "Orange")
		end
	end
end

function UpgradesPanel.Init()
	panel = Kit.Panel("Upgrades", "UPGRADES", Vector2.new(780, 470), "Green")
	local list: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 1, -20), Position = UDim2.fromOffset(0, 18), BackgroundTransparency = 1, ZIndex = 61, Parent = panel.Body })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, id in Config.UpgradeOrder do
		local up = Config.Upgrades[id]
		local r: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 118), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.4, LayoutOrder = i, ZIndex = 62, Parent = list })
		Kit.Corner(r, UDim.new(0, 18))
		local icon: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(88, 88), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = r })
		Kit.Corner(icon, UDim.new(0, 18))
		Kit.Stroke(icon, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
		Kit.Gradient(icon, Theme.Panel3, Theme.Panel, 90)
		Kit.Label(icon, up.Icon, { Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 64, Stroke = 0 })
		Kit.Label(r, up.Name, { Size = UDim2.fromOffset(330, 32), Position = UDim2.fromOffset(118, 10), Align = Enum.TextXAlignment.Left, ZIndex = 63 })
		Kit.Label(r, up.Description, { Size = UDim2.fromOffset(340, 22), Position = UDim2.fromOffset(118, 44), Align = Enum.TextXAlignment.Left, Color = Theme.Muted, Font = Theme.Body, ZIndex = 63, Stroke = 0 })
		local value = Kit.Label(r, "", { Size = UDim2.fromOffset(300, 26), Position = UDim2.fromOffset(118, 74), Align = Enum.TextXAlignment.Left, Color = Theme.Ecto, ZIndex = 63 })
		local pipRow: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(150, 20), Position = UDim2.new(1, -220, 0, 16), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 63, Parent = r })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = pipRow })
		local pips = {}
		for _ = 1, #up.Levels do
			local pip: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(24, 18), BackgroundColor3 = Theme.Bg, ZIndex = 64, Parent = pipRow })
			Kit.Corner(pip, UDim.new(0, 6))
			Kit.Stroke(pip, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
			table.insert(pips, pip)
		end
		local buy = Kit.Button(r, {
			Text = "",
			Color = "Green",
			Size = UDim2.fromOffset(190, 66),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			ZIndex = 64,
			OnClick = function()
				local res = State.Request("BuyUpgrade", id)
				if res.ok then
					Sound.Play("Upgrade")
					Kit.Toast(up.Name .. " upgraded to level " .. tostring(res.Level) .. "!", "Good")
					local char = game:GetService("Players").LocalPlayer.Character
					local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						Effects.Burst(root.Position, { Color = Theme.Ecto, Count = 30, Size = 0.8, Speed = 16 })
						Effects.Ring(root.Position - Vector3.new(0, 2.8, 0), Theme.Ecto, 8, 0.5)
					end
				else
					Kit.Toast(res.err or "Can't buy that yet", "Bad")
				end
			end,
		})
		rows[id] = { Pips = pips, Value = value, Buy = buy }
	end
	Hud.RegisterPanel("Upgrades", function()
		panel:Toggle()
	end)
end

function UpgradesPanel.Start()
	panel.OnOpen.Event:Connect(refresh)
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

function UpgradesPanel.Open()
	if not panel.IsOpen then
		panel:Open()
	end
end

return UpgradesPanel
