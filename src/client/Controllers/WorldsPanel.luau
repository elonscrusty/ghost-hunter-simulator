--!strict
-- WORLDS (Fast Travel): a card per zone. Unlocked zones teleport you to their arrival pad
-- (the server checks ownership and places you); locked zones show a lock and their price.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Icons = require(GH.Icons)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local WorldsPanel = {}

type Card = { Frame: Frame, Status: TextLabel, Lock: TextLabel, Go: TextButton }

local player = Players.LocalPlayer
local panel: Kit.Panel
local cards: { [string]: Card } = {}
local busy = false

local zoneRanges: { { number } } = {}
for _, z in Config.Zones do
	table.insert(zoneRanges, { z.MinZ, z.MaxZ })
end

local function currentZone(): string?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local z = Config.Zones[Rules.ZoneIndexAt(root.Position.Z, zoneRanges)]
	return if z then z.Id else nil
end

local function refresh()
	local d = State.Data
	if not d then
		return
	end
	local here = currentZone()
	for _, z in Config.Zones do
		local c = cards[z.Id]
		local owned = d.Zones[z.Id] == true
		c.Lock.Visible = not owned
		c.Frame.BackgroundTransparency = if owned then 0 else 0.35
		if not owned then
			c.Status.Text = "🔒 " .. Format.Short(z.Cost)
			c.Status.TextColor3 = Theme.Muted
			Kit.SetButtonText(c.Go, "LOCKED")
			c.Go:SetAttribute("Color", "Gray")
		elseif z.Id == here then
			c.Status.Text = "YOU ARE HERE"
			c.Status.TextColor3 = Theme.Ecto
			Kit.SetButtonText(c.Go, "HERE")
			c.Go:SetAttribute("Color", "Gray")
		else
			c.Status.Text = "UNLOCKED"
			c.Status.TextColor3 = Theme.Ecto
			Kit.SetButtonText(c.Go, "GO!")
			c.Go:SetAttribute("Color", "Green")
		end
	end
end

local function travel(zone: Config.ZoneDef)
	local d = State.Data
	if busy or not d then
		return
	end
	if not d.Zones[zone.Id] then
		Kit.Toast("Unlock " .. zone.Name .. " at its gate first!", "Bad")
		return
	end
	if zone.Id == currentZone() then
		panel:Close()
		return
	end
	busy = true
	local res = State.Request("Travel", zone.Id)
	busy = false
	if res.ok then
		panel:Close()
		Sound.Play("ZoneUnlock")
		Hud.Banner(zone.Name, "Fast travel complete!", zone.Accent)
	else
		Kit.Toast(res.err or "Can't travel right now", "Bad")
	end
end

function WorldsPanel.Init()
	panel = Kit.Panel("Worlds", "WORLDS", Vector2.new(720, 420), "Blue")
	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -8),
		Position = UDim2.fromOffset(0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(160, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), Parent = list })
	for _, z in Config.Zones do
		local f: Frame = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = z.Order, ZIndex = 62, Parent = list })
		Kit.Corner(f, UDim.new(0, 14))
		Kit.Stroke(f, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
		Kit.Gradient(f, z.Accent:Lerp(Theme.Panel3, 0.35), z.FogColor, 90)
		Kit.Label(f, tostring(z.Order), { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(6, 6), Style = "Heading", ZIndex = 64 })
		-- optional uploaded zone badge (docs/ICON_PROMPTS.md) between the number and the lock
		local hasIcon = Icons.Get(Icons.ForZone(z.Id)) ~= nil
		if hasIcon then
			Kit.Icon(f, Icons.ForZone(z.Id), "", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 63 })
		end
		Kit.Label(f, z.Name, { Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, if hasIcon then 38 else 32), Style = "Body", ZIndex = 64 })
		local status = Kit.Label(f, "", { Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 74), Style = "Small", Fit = true, ZIndex = 64 })
		local lock = Kit.Label(f, "🔒", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -6, 0, 4), AnchorPoint = Vector2.new(1, 0), Style = "Icon", Stroke = 0, ZIndex = 65 })
		local go = Kit.Button(f, {
			Text = "GO!",
			Color = "Green",
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			ZIndex = 64,
			OnClick = function()
				travel(z)
			end,
		})
		cards[z.Id] = { Frame = f, Status = status, Lock = lock, Go = go }
		if z.Order == 1 then
			panel.Primary = go
		end
	end
	Hud.RegisterPanel("Worlds", function()
		panel:Toggle()
	end)
end

function WorldsPanel.Start()
	panel.OnOpen:Connect(refresh)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return WorldsPanel
