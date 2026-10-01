--!strict
-- Always-on HUD, kept compact so the screen stays free for seeing and tapping ghosts:
-- Ectoplasm counter, crew power, active boosts, menu buttons (one column on big screens,
-- a 2-column block in the top-left on phones, clear of the thumbstick), settings, the
-- AUTO ATTACK toggle (pass owners only), toasts, announcements and zone banners.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Format = require(GH.Logic.Format)
local Rules = require(GH.Logic.Rules)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Sound = require(script.Parent.Sound)

local Hud = {}

local player = Players.LocalPlayer
local openers: { [string]: () -> () } = {}
Hud.Buttons = {} :: { [string]: TextButton }

local ectoLabel: TextLabel
local ectoPill: Frame
local powerLabel: TextLabel
local boostHolder: Frame
local dailyBadge: Frame
local menu: Frame
local menuGrid: UIGridLayout
local autoButton: TextButton
local shownEcto = 0
local targetEcto = 0
local bannerLabel: TextLabel
local bannerSub: TextLabel
local announceFrame: Frame

function Hud.RegisterPanel(name: string, open: () -> ())
	openers[name] = open
end

function Hud.Open(name: string)
	local fn = openers[name]
	if fn then
		fn()
	end
end

-- Pulsing ring on a menu button (tutorial).
local pulses: { [string]: Frame } = {}
function Hud.Pulse(name: string, on: boolean)
	local b = Hud.Buttons[name]
	if not b then
		return
	end
	if on and not pulses[name] then
		local ring: Frame = Kit.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 20,
			Parent = b,
		})
		Kit.Corner(ring, UDim.new(0, 14))
		local st = Kit.Stroke(ring, 4, Theme.Ecto, Enum.ApplyStrokeMode.Border)
		pulses[name] = ring
		task.spawn(function()
			while ring.Parent do
				ring.Size = UDim2.fromScale(1, 1)
				st.Transparency = 0
				Kit.Tween(ring, 0.8, { Size = UDim2.fromScale(1.35, 1.35) })
				Kit.Tween(st, 0.8, { Transparency = 1 })
				task.wait(0.9)
			end
		end)
	elseif not on and pulses[name] then
		pulses[name]:Destroy()
		pulses[name] = nil
	end
end

local function floatText(text: string, color: Color3)
	local l = Kit.Label(Kit.Overlay(), text, {
		Size = UDim2.fromOffset(160, 24),
		Position = UDim2.new(0.5, 0, 0, 62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = color,
		Style = "Heading",
		ZIndex = 80,
	})
	Kit.Tween(l, 0.8, { Position = UDim2.new(0.5, 0, 0, 40), TextTransparency = 1 })
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		Kit.Tween(st, 0.8, { Transparency = 1 })
	end
	task.delay(0.85, function()
		l:Destroy()
	end)
end

local function buildTop(screen: ScreenGui)
	-- Ectoplasm pill
	ectoPill = Kit.new("Frame", {
		Name = "Ecto",
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.new(0.5, 10, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = screen,
	})
	Kit.Corner(ectoPill, UDim.new(1, 0))
	Kit.Stroke(ectoPill, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(ectoPill, Theme.Panel2, Theme.Bg, 90)
	Kit.new("UIScale", { Parent = ectoPill })
	local orb: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, -12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = ectoPill,
	})
	Kit.Corner(orb, UDim.new(1, 0))
	Kit.Stroke(orb, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(orb, Theme.Ecto, Theme.Ecto2, 135)
	local shine: Frame = Kit.new("Frame", { Size = UDim2.fromScale(0.3, 0.24), Position = UDim2.fromScale(0.26, 0.2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, ZIndex = 4, Parent = orb })
	Kit.Corner(shine, UDim.new(1, 0))
	ectoLabel = Kit.Label(ectoPill, "0", { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), Color = Theme.Ecto, Style = "Currency", Fit = true })
	-- crew power
	local power: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(170, 22),
		Position = UDim2.new(0.5, 10, 0, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.25,
		Parent = screen,
	})
	Kit.Corner(power, UDim.new(1, 0))
	powerLabel = Kit.Label(power, "⚡ 0 POWER", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), Color = Theme.Gold, Style = "Small", Fit = true })
	-- boosts (only while active)
	boostHolder = Kit.new("Frame", {
		Size = UDim2.fromOffset(340, 22),
		Position = UDim2.new(0.5, 10, 0, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = boostHolder })
end

local MENU = {
	{ Name = "Hunters", Icon = "🔦", Text = "HUNTERS", Color = "Orange" },
	{ Name = "Index", Icon = "📖", Text = "INDEX", Color = "Blue" },
	{ Name = "Upgrades", Icon = "🧲", Text = "UPGRADES", Color = "Green" },
	{ Name = "Shop", Icon = "🛒", Text = "SHOP", Color = "Pink" },
	{ Name = "Daily", Icon = "🎁", Text = "DAILY", Color = "Purple" },
}
local CELL = 58

-- One column, vertically centred, on tall screens; a 2-wide block in the top-left on short
-- (phone landscape) screens so it never overlaps the movement thumbstick.
local function layoutMenu()
	if Kit.IsCompact() then
		menuGrid.FillDirectionMaxCells = 3
		menu.Size = UDim2.fromOffset(CELL * 2 + 6, CELL * 3 + 12)
		menu.Position = UDim2.fromOffset(8, 56)
		menu.AnchorPoint = Vector2.zero
	else
		menuGrid.FillDirectionMaxCells = 5
		menu.Size = UDim2.fromOffset(CELL, CELL * 5 + 24)
		menu.Position = UDim2.new(0, 10, 0.5, 0)
		menu.AnchorPoint = Vector2.new(0, 0.5)
	end
end

local function buildMenu(screen: ScreenGui)
	menu = Kit.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Parent = screen,
	})
	menuGrid = Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL, CELL),
		CellPadding = UDim2.fromOffset(6, 6),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	for i, m in MENU do
		local b = Kit.Button(menu, {
			Text = "",
			Color = m.Color,
			OnClick = function()
				Hud.Open(m.Name)
			end,
		})
		b.LayoutOrder = i
		Kit.Label(b, m.Icon, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 5), Style = "Icon", Stroke = 0, ZIndex = 3 })
		Kit.Label(b, m.Text, { Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 2, 1, -18), Style = "Tiny", Fit = true, ZIndex = 3 })
		Hud.Buttons[m.Name] = b
	end
	-- red "!" on DAILY when a reward is waiting
	dailyBadge = Kit.new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, 5, 0, -5),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Bad,
		Visible = false,
		ZIndex = 10,
		Parent = Hud.Buttons.Daily,
	})
	Kit.Corner(dailyBadge, UDim.new(1, 0))
	Kit.Stroke(dailyBadge, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Label(dailyBadge, "!", { Style = "Small", ZIndex = 11 })
	layoutMenu()
	Kit.ScaleChanged:Connect(layoutMenu)
end

-- Settings panel (gear, top right)
local function buildSettings(screen: ScreenGui)
	local panel = Kit.Panel("Settings", "SETTINGS", Vector2.new(400, 290), "Gray")
	local list: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel.Body, ZIndex = 61 })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = list })
	local toggles = {
		{ Key = "Music", Text = "MUSIC" },
		{ Key = "Sfx", Text = "SOUND EFFECTS" },
		{ Key = "FastReveal", Text = "FAST CRATE OPENING" },
	}
	local buttons: { [string]: TextButton } = {}
	for _, t in toggles do
		local b = Kit.Button(list, {
			Text = t.Text,
			Color = "Green",
			Size = UDim2.fromOffset(320, 44),
			ZIndex = 62,
			OnClick = function()
				local d = State.Data
				if not d then
					return
				end
				local res = State.Request("Setting", t.Key, not d.Settings[t.Key])
				if not res.ok then
					Kit.Toast(res.err or "Couldn't change that", "Bad")
				end
			end,
		})
		buttons[t.Key] = b
	end
	State.Changed:Connect(function(d)
		for _, t in toggles do
			local on = d.Settings[t.Key] == true
			local b = buttons[t.Key]
			b:SetAttribute("Color", if on then "Green" else "Gray")
			Kit.SetButtonText(b, t.Text .. (if on then ": ON" else ": OFF"))
		end
	end)
	Hud.RegisterPanel("Settings", function()
		panel:Toggle()
	end)
	Kit.Button(screen, {
		Text = "⚙",
		Color = "Gray",
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.new(1, -10, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextStyle = "Heading",
		OnClick = function()
			panel:Toggle()
		end,
	})
end

-- AUTO ATTACK toggle: only shown to Auto Attack pass owners. The server checks ownership.
local busyAuto = false
local function refreshAuto()
	local d = State.Data
	local owned = d ~= nil and d.Passes ~= nil and d.Passes[Config.AutoAttack.Pass] == true
	autoButton.Visible = owned
	local on = player:GetAttribute("AutoAttack") == true
	Kit.SetButtonText(autoButton, if on then "🤖 AUTO: ON" else "🤖 AUTO: OFF")
	autoButton:SetAttribute("Color", if on then "Green" else "Gray")
end

local function buildAuto(screen: ScreenGui)
	autoButton = Kit.Button(screen, {
		Text = "🤖 AUTO: OFF",
		Color = "Gray",
		Size = UDim2.fromOffset(132, 36),
		Position = UDim2.new(1, -10, 0, 58),
		AnchorPoint = Vector2.new(1, 0),
		TextStyle = "Small",
		OnClick = function()
			if busyAuto then
				return
			end
			busyAuto = true
			local on = player:GetAttribute("AutoAttack") == true
			local res = State.Request("AutoAttack", not on)
			busyAuto = false
			if not res.ok then
				Kit.Toast(res.err or "Couldn't switch Auto Attack", "Bad")
			else
				Kit.Toast(if res.On then "AUTO ATTACK ON: your crew picks nearby ghosts" else "AUTO ATTACK OFF: tap a ghost to attack", "Good")
			end
		end,
	})
	autoButton.Name = "AutoAttack"
	autoButton.Visible = false
	player:GetAttributeChangedSignal("AutoAttack"):Connect(refreshAuto)
	State.Changed:Connect(refreshAuto)
end

local function buildBanners()
	local overlay = Kit.Overlay()
	bannerLabel = Kit.Label(overlay, "", {
		Size = UDim2.fromOffset(640, 48),
		Position = UDim2.fromScale(0.5, 0.27),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Ecto,
		Style = "Banner",
		Fit = true,
		ZIndex = 70,
	})
	bannerLabel.TextTransparency = 1
	bannerSub = Kit.Label(overlay, "", {
		Size = UDim2.fromOffset(560, 24),
		Position = UDim2.new(0.5, 0, 0.27, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Text,
		Style = "Body",
		Fit = true,
		ZIndex = 70,
	})
	bannerSub.TextTransparency = 1
	announceFrame = Kit.new("Frame", {
		Size = UDim2.fromOffset(500, 36),
		Position = UDim2.new(0.5, 0, 0, -60),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 75,
		Parent = overlay,
	})
	Kit.Corner(announceFrame, UDim.new(0, 12))
	Kit.Stroke(announceFrame, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(announceFrame, Theme.Gold, Color3.fromRGB(255, 120, 40), 0)
	local l = Kit.Label(announceFrame, "", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Style = "Body", Fit = true, ZIndex = 76 })
	l.Name = "Text"
end

local bannerToken = 0
-- Centre-screen title (zone names, NEW AREA UNLOCKED!). The one place for big text.
function Hud.Banner(title: string, sub: string?, color: Color3?)
	bannerToken += 1
	local my = bannerToken
	bannerLabel.Text = title
	bannerLabel.TextColor3 = color or Theme.Ecto
	bannerSub.Text = sub or ""
	local s1 = bannerLabel:FindFirstChildOfClass("UIStroke") :: UIStroke
	local s2 = bannerSub:FindFirstChildOfClass("UIStroke") :: UIStroke
	bannerLabel.TextTransparency = 1
	bannerSub.TextTransparency = 1
	s1.Transparency = 1
	s2.Transparency = 1
	local sc = bannerLabel:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = bannerLabel })
	sc.Scale = 0.6
	Kit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.Tween(bannerLabel, 0.3, { TextTransparency = 0 })
	Kit.Tween(s1, 0.3, { Transparency = 0 })
	Kit.Tween(bannerSub, 0.3, { TextTransparency = 0 })
	Kit.Tween(s2, 0.3, { Transparency = 0 })
	task.delay(2.4, function()
		if bannerToken ~= my then
			return
		end
		Kit.Tween(bannerLabel, 0.45, { TextTransparency = 1 })
		Kit.Tween(s1, 0.45, { Transparency = 1 })
		Kit.Tween(bannerSub, 0.45, { TextTransparency = 1 })
		Kit.Tween(s2, 0.45, { Transparency = 1 })
	end)
end

local announceToken = 0
-- Sliding top announcement (legendary hatches, boss events).
function Hud.Announce(text: string, c1: Color3?, c2: Color3?)
	announceToken += 1
	local my = announceToken
	local l = announceFrame:FindFirstChild("Text") :: TextLabel
	l.Text = text
	local g = announceFrame:FindFirstChildOfClass("UIGradient") :: UIGradient
	g.Color = ColorSequence.new(c1 or Theme.Gold, c2 or Color3.fromRGB(255, 120, 40))
	-- below the boss bar / goal chip so event warnings never stack on top of each other
	Kit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, 174) }, Enum.EasingStyle.Back)
	task.delay(4, function()
		if announceToken == my then
			Kit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, -60) })
		end
	end)
end

local boostLabels: { [string]: TextLabel } = {}
local function refreshBoosts()
	local d = State.Data
	if not d then
		return
	end
	local now = State.Now()
	for id, def in Config.Boosts :: any do
		if type(def) ~= "table" then
			continue
		end
		local expiry = d.Boosts[id]
		local left = if expiry then expiry - now else 0
		local l = boostLabels[id]
		if left > 0 then
			if not l then
				local f: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(150, 22), BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.1, Parent = boostHolder })
				Kit.Corner(f, UDim.new(1, 0))
				l = Kit.Label(f, "", { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), Color = Theme.Ecto, Style = "Tiny", Fit = true })
				boostLabels[id] = l
			end
			(l :: TextLabel).Text = def.Icon .. " " .. def.Name .. " " .. Format.Time(left)
		elseif l then
			(l.Parent :: Instance):Destroy()
			boostLabels[id] = nil
		end
	end
	local info = d.DailyInfo
	if info then
		local canClaim = info.CanClaim or info.Wait - (now - (d.ServerTime or now)) <= 0
		dailyBadge.Visible = canClaim
	end
end

local function onData(d: any)
	powerLabel.Text = "⚡ " .. Format.Short(d.CrewPower or 0) .. " POWER"
	targetEcto = d.Ecto
	refreshBoosts()
end

local lastZone = 0
local zoneRanges: { { number } } = {}
for _, z in Config.Zones do
	table.insert(zoneRanges, { z.MinZ, z.MaxZ })
end

function Hud.Init()
	local screen = Kit.Screen()
	Kit.SetSound(function(name)
		Sound.Play(name)
	end)
	buildTop(screen)
	buildMenu(screen)
	buildSettings(screen)
	buildAuto(screen)
	buildBanners()
end

function Hud.Start()
	State.Changed:Connect(onData)
	State.EctoChanged:Connect(function(new: number, old: number)
		targetEcto = new
		if new > old then
			floatText("+" .. Format.Short(new - old), Theme.Ecto)
			local sc = ectoPill:FindFirstChildOfClass("UIScale") :: UIScale
			sc.Scale = 1.1
			Kit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	-- smooth count-up
	RunService.RenderStepped:Connect(function(dt: number)
		if shownEcto ~= targetEcto then
			local diff = targetEcto - shownEcto
			local step = diff * math.min(1, dt * 10)
			if math.abs(diff) < 1 or math.abs(step) < 1 then
				shownEcto = targetEcto
			else
				shownEcto += step
			end
			ectoLabel.Text = Format.Short(math.floor(shownEcto + 0.5))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshBoosts()
			-- zone banner when walking into a different zone
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local idx = Rules.ZoneIndexAt(root.Position.Z, zoneRanges)
				if idx ~= lastZone then
					if lastZone ~= 0 then
						local z = Config.Zones[idx]
						Hud.Banner(z.Name, nil, z.Accent)
					end
					lastZone = idx
				end
			end
		end
	end)
	Net.Event("Fx").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Toast" then
			Kit.Toast(data.Text, data.Color)
		elseif kind == "Announce" then
			local r = Config.Rarities[data.Color]
			Hud.Announce(data.Text, r and r.Color, r and r.Color2)
		end
	end)
end

return Hud
