--!strict
-- WORLDS (Fast Travel): a card per zone. Unlocked zones teleport you to their arrival pad
-- (the server checks ownership and places you); locked zones show a lock and their price.
-- WORLD 1 / WORLD 2 tabs (Config.Worlds) show one world's zones at a time. A world whose first
-- zone isn't owned yet has a locked-looking tab and a hint row saying how to get in (open the
-- portal at the end of the Throne; first defeat THE GHOST KING). Phone rules: 44 px tabs, fixed
-- text sizes via Kit labels (no TextScaled, no text scale tweens).
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

type Card = { Frame: Frame, Status: TextLabel, Lock: GuiObject, Go: TextButton }

local player = Players.LocalPlayer
local panel: Kit.Panel
local cards: { [string]: Card } = {}
local busy = false
local worldFirsts: { number } = {}
for _, w in Config.Worlds do
	table.insert(worldFirsts, w.First)
end
local tab = 1 -- world shown
local tabButtons: { [number]: TextButton } = {}
local hintRow: Frame
local hintLabel: TextLabel
local list: ScrollingFrame

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

-- How to get into world `wi` (nil when its first zone is owned).
local function worldHint(d: any, wi: number): string?
	local w = Config.Worlds[wi]
	local first = w and Config.Zones[w.First]
	if not first or d.Zones[first.Id] then
		return nil
	end
	local portal = Config.Layout.Portals.ToWorld2
	local prev = Config.Zones[w.First - 1]
	if first.Id == portal.Zone then
		if prev and not d.Zones[prev.Id] then
			return "🔒 Unlock " .. prev.Name .. ", then defeat " .. Config.Ghosts[portal.Boss].Name .. " to open the portal."
		elseif not (d.BossesBeaten and d.BossesBeaten[portal.Boss]) then
			return "🔒 Defeat " .. Config.Ghosts[portal.Boss].Name .. " to open the portal at the end of " .. (if prev then prev.Name else "World 1") .. "."
		end
		return "🔒 Open the portal at the end of " .. (if prev then prev.Name else "World 1") .. ": 💚 " .. Format.Short(first.Cost)
	end
	return "🔒 Unlock " .. first.Name .. " to enter " .. w.Name .. "."
end

local function refresh()
	local d = State.Data
	if not d then
		return
	end
	local here = currentZone()
	for wi, b in tabButtons do
		local w = Config.Worlds[wi]
		local open = worldHint(d, wi) == nil
		Kit.SetButtonText(b, (if open then "" else "🔒 ") .. w.Name)
		b:SetAttribute("Color", if wi == tab then "Blue" elseif open then "Purple" else "Gray")
	end
	local hint = worldHint(d, tab)
	hintRow.Visible = hint ~= nil
	if hint then
		Kit.IconText(hintLabel, hint)
	end
	local top = if hint then 106 else 56
	list.Position = UDim2.fromOffset(0, top)
	list.Size = UDim2.new(1, 0, 1, -(top + 2))
	for _, z in Config.Zones do
		local c = cards[z.Id]
		c.Frame.Visible = Rules.WorldOf(z.Order, worldFirsts) == tab
		local owned = d.Zones[z.Id] == true
		c.Lock.Visible = not owned
		c.Frame.BackgroundTransparency = if owned then 0 else 0.35
		if not owned then
			Kit.IconText(c.Status, "💚 " .. Format.Short(z.Cost))
			c.Status.TextColor3 = Theme.Muted
			Kit.SetButtonText(c.Go, "LOCKED")
			c.Go:SetAttribute("Color", "Gray")
		elseif z.Id == here then
			Kit.IconText(c.Status, "YOU ARE HERE")
			c.Status.TextColor3 = Theme.Ecto
			Kit.SetButtonText(c.Go, "HERE")
			c.Go:SetAttribute("Color", "Gray")
		else
			Kit.IconText(c.Status, "UNLOCKED")
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

local function setTab(wi: number)
	if not Config.Worlds[wi] then
		return
	end
	tab = wi
	list.CanvasPosition = Vector2.zero
	refresh()
end

function WorldsPanel.Init()
	panel = Kit.Panel("Worlds", "WORLDS", Vector2.new(720, 420), "Blue")
	-- WORLD 1 / WORLD 2 tabs (44 px tall: phone tap size)
	local tabRow: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 6), BackgroundTransparency = 1, ZIndex = 62, Parent = panel.Body })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabRow })
	for wi, w in Config.Worlds do
		local b = Kit.Button(tabRow, {
			Text = w.Name,
			Color = if wi == 1 then "Blue" else "Gray",
			Size = UDim2.fromOffset(170, 44),
			ZIndex = 63,
			OnClick = function()
				setTab(wi)
			end,
		})
		b.LayoutOrder = wi
		tabButtons[wi] = b
	end
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -58),
		Position = UDim2.fromOffset(0, 56),
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
	-- hint row under the tabs for a world you can't enter yet (the card grid moves down)
	hintRow = Kit.new("Frame", { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 56), BackgroundColor3 = Theme.Panel3, Visible = false, ZIndex = 62, Parent = panel.Body })
	Kit.Corner(hintRow, UDim.new(0, 14))
	Kit.Stroke(hintRow, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	hintLabel = Kit.Label(hintRow, "", { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Style = "Small", Fit = true, ZIndex = 64 })
	hintLabel.TextWrapped = true
	for _, z in Config.Zones do
		local f: Frame = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = z.Order, ZIndex = 62, Parent = list })
		Kit.Corner(f, UDim.new(0, 14))
		Kit.Stroke(f, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
		Kit.Gradient(f, z.Accent:Lerp(Theme.Panel3, 0.35), z.FogColor, 90)
		Kit.Label(f, tostring(z.Order), { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(6, 6), Style = "Heading", ZIndex = 64 })
		-- optional uploaded zone badge (icon-prompts/) between the number and the lock
		local hasIcon = Icons.Get(Icons.ForZone(z.Id)) ~= nil
		if hasIcon then
			Kit.Icon(f, Icons.ForZone(z.Id), "", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 63 })
		end
		Kit.Label(f, z.Name, { Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, if hasIcon then 38 else 32), Style = "Body", ZIndex = 64 })
		local status = Kit.Label(f, "", { Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 74), Style = "Small", Fit = true, ZIndex = 64 })
		local lock = Kit.Icon(f, "lock", "🔒", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -6, 0, 4), AnchorPoint = Vector2.new(1, 0), Style = "Icon", Stroke = 0, ZIndex = 65 })
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
	panel.OnOpen:Connect(function()
		-- open on the world you're standing in
		local here = currentZone()
		local z = here and Config.ZoneById[here]
		setTab(if z then Rules.WorldOf(z.Order, worldFirsts) else 1)
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return WorldsPanel
