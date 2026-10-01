--!strict
-- Zone gate confirm: "UNLOCK CEMETERY?" with cost, progress and what you get. The gate's
-- ProximityPrompt opens it; the server checks cost, order and distance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)

local GatePanel = {}

local panel: Kit.Panel
local costLabel: TextLabel
local fill: Frame
local progressLabel: TextLabel
local unlockButton: TextButton
local current: string? = nil
local busy = false

local function refresh()
	local d = State.Data
	local zone = current and Config.ZoneById[current]
	if not d or not zone then
		return
	end
	panel.Title.Text = "UNLOCK " .. zone.Name .. "?"
	costLabel.Text = "💚 " .. Format.Commas(zone.Cost) .. " ECTOPLASM"
	local frac = math.clamp(d.Ecto / math.max(zone.Cost, 1), 0, 1)
	Kit.Tween(fill, 0.25, { Size = UDim2.fromScale(math.max(frac, 0.03), 1) })
	progressLabel.Text = Format.Short(math.min(d.Ecto, zone.Cost)) .. " / " .. Format.Short(zone.Cost)
	if d.Zones[zone.Id] then
		Kit.SetButtonText(unlockButton, "UNLOCKED ✓")
		unlockButton:SetAttribute("Color", "Gray")
	elseif d.Ecto >= zone.Cost then
		Kit.SetButtonText(unlockButton, "UNLOCK!")
		unlockButton:SetAttribute("Color", "Green")
	else
		Kit.SetButtonText(unlockButton, "NEED " .. Format.Short(zone.Cost - d.Ecto) .. " MORE")
		unlockButton:SetAttribute("Color", "Gray")
	end
end

function GatePanel.Open(zoneId: string)
	if not Config.ZoneById[zoneId] then
		return
	end
	current = zoneId
	refresh()
	panel:Open()
end

function GatePanel.Init()
	panel = Kit.Panel("Gate", "UNLOCK?", Vector2.new(520, 330), "Green")
	local body = panel.Body
	costLabel = Kit.Label(body, "", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 14), Color = Theme.Ecto, Style = "Heading", ZIndex = 62 })
	local bar: Frame = Kit.new("Frame", { Size = UDim2.new(0.8, 0, 0, 24), Position = UDim2.new(0.1, 0, 0, 48), BackgroundColor3 = Theme.Bg, ZIndex = 62, Parent = body })
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	fill = Kit.new("Frame", { Size = UDim2.fromScale(0.03, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = bar })
	Kit.Corner(fill, UDim.new(1, 0))
	Kit.Gradient(fill, Theme.Ecto, Theme.Ecto2, 0)
	progressLabel = Kit.Label(bar, "", { Style = "Small", ZIndex = 64 })
	local perks: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 86), Position = UDim2.fromOffset(0, 84), BackgroundTransparency = 1, ZIndex = 61, Parent = body })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 38), CellPadding = UDim2.fromOffset(10, 8), Parent = perks })
	for _, p in { "👻 NEW GHOSTS", "📦 NEW CRATE", "🔦 BETTER HUNTERS", "💚 HIGHER REWARDS" } do
		local f: Frame = Kit.new("Frame", { BackgroundColor3 = Theme.Panel3, ZIndex = 62, Parent = perks })
		Kit.Corner(f, UDim.new(0, 10))
		Kit.Label(f, p, { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), Style = "Body", Fit = true, ZIndex = 63 })
	end
	unlockButton = Kit.Button(body, {
		Text = "UNLOCK!",
		Color = "Green",
		Size = UDim2.fromOffset(260, 50),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = function()
			local zoneId = current
			local d = State.Data
			if busy or not zoneId or not d or d.Zones[zoneId] then
				return
			end
			if d.Ecto < (Config.ZoneById[zoneId] :: Config.ZoneDef).Cost then
				Kit.Toast("Defeat more ghosts to earn Ectoplasm!", "Bad")
				return
			end
			busy = true
			local res = State.Request("UnlockZone", zoneId)
			busy = false
			if res.ok then
				panel:Close()
			else
				Kit.Toast(res.err or "Couldn't unlock", "Bad")
			end
		end,
	})
end

function GatePanel.Start()
	State.EctoChanged:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return GatePanel
