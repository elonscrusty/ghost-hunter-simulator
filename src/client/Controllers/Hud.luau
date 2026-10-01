--!strict
-- Always-on HUD: Ectoplasm counter, crew power, boosts, main menu buttons, settings,
-- toasts, announcements and zone banners.
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
		Kit.Corner(ring, UDim.new(0, 18))
		local st = Kit.Stroke(ring, 5, Theme.Ecto, Enum.ApplyStrokeMode.Border)
		pulses[name] = ring
		task.spawn(function()
			while ring.Parent do
				ring.Size = UDim2.fromScale(1, 1)
				st.Transparency = 0
				Kit.Tween(ring, 0.8, { Size = UDim2.fromScale(1.4, 1.4) })
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
		Size = UDim2.fromOffset(200, 34),
		Position = UDim2.new(0.5, 0, 0, 78),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = color,
		ZIndex = 80,
	})
	Kit.Tween(l, 0.9, { Position = UDim2.new(0.5, 0, 0, 40), TextTransparency = 1 })
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		Kit.Tween(st, 0.9, { Transparency = 1 })
	end
	task.delay(0.95, function()
		l:Destroy()
	end)
end

local function buildTop(screen: ScreenGui)
	-- Ectoplasm pill
	ectoPill = Kit.new("Frame", {
		Name = "Ecto",
		Size = UDim2.fromOffset(250, 58),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = screen,
	})
	Kit.Corner(ectoPill, UDim.new(1, 0))
	Kit.Stroke(ectoPill, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(ectoPill, Theme.Panel2, Theme.Bg, 90)
	Kit.new("UIScale", { Parent = ectoPill })
	local orb: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(66, 66),
		Position = UDim2.new(0, -14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = ectoPill,
	})
	Kit.Corner(orb, UDim.new(1, 0))
	Kit.Stroke(orb, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(orb, Theme.Ecto, Theme.Ecto2, 135)
	local shine: Frame = Kit.new("Frame", { Size = UDim2.fromScale(0.32, 0.26), Position = UDim2.fromScale(0.26, 0.2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, ZIndex = 4, Parent = orb })
	Kit.Corner(shine, UDim.new(1, 0))
	ectoLabel = Kit.Label(ectoPill, "0", { Size = UDim2.new(1, -70, 0.72, 0), Position = UDim2.new(0, 60, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = Theme.Ecto, Stroke = 3 })
	-- crew power
	local power: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(210, 30),
		Position = UDim2.new(0.5, 0, 0, 72),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		Parent = screen,
	})
	Kit.Corner(power, UDim.new(1, 0))
	Kit.Stroke(power, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	powerLabel = Kit.Label(power, "⚡ 0 CAPTURE POWER", { Size = UDim2.fromScale(0.92, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Gold })
	-- boosts
	boostHolder = Kit.new("Frame", {
		Size = UDim2.fromOffset(400, 30),
		Position = UDim2.new(0.5, 0, 0, 108),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = boostHolder })
end

local MENU = {
	{ Name = "Hunters", Icon = "🔦", Text = "HUNTERS", Color = "Orange" },
	{ Name = "Index", Icon = "📖", Text = "INDEX", Color = "Blue" },
	{ Name = "Upgrades", Icon = "🧲", Text = "UPGRADES", Color = "Green" },
	{ Name = "Shop", Icon = "🛒", Text = "SHOP", Color = "Pink" },
	{ Name = "Daily", Icon = "🎁", Text = "DAILY", Color = "Purple" },
}

local function buildMenu(screen: ScreenGui)
	local col: Frame = Kit.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(96, 5 * 96),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = col })
	for i, m in MENU do
		local b = Kit.Button(col, {
			Text = "",
			Color = m.Color,
			Size = UDim2.fromOffset(88, 88),
			OnClick = function()
				Hud.Open(m.Name)
			end,
		})
		b.LayoutOrder = i
		Kit.SetButtonText(b, "")
		Kit.Label(b, m.Icon, { Size = UDim2.fromScale(0.62, 0.55), Position = UDim2.fromScale(0.5, 0.38), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 0, ZIndex = 3 })
		Kit.Label(b, m.Text, { Size = UDim2.fromScale(0.94, 0.24), Position = UDim2.fromScale(0.5, 0.82), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
		Hud.Buttons[m.Name] = b
	end
	-- red "!" badge on DAILY when claimable
	dailyBadge = Kit.new("Frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Bad,
		Visible = false,
		ZIndex = 10,
		Parent = Hud.Buttons.Daily,
	})
	Kit.Corner(dailyBadge, UDim.new(1, 0))
	Kit.Stroke(dailyBadge, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Label(dailyBadge, "!", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 })
end

-- Settings panel (gear, top right)
local function buildSettings(screen: ScreenGui)
	local panel = Kit.Panel("Settings", "SETTINGS", Vector2.new(460, 380), "Gray")
	local list: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel.Body, ZIndex = 61 })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = list })
	local toggles = {
		{ Key = "Music", Text = "MUSIC" },
		{ Key = "Sfx", Text = "SOUND EFFECTS" },
		{ Key = "FastReveal", Text = "FAST CRATE OPENING" },
		{ Key = "AutoTarget", Text = "AUTO NEXT GHOST" },
	}
	local buttons: { [string]: TextButton } = {}
	for _, t in toggles do
		local b = Kit.Button(list, {
			Text = t.Text,
			Color = "Green",
			Size = UDim2.fromOffset(380, 56),
			ZIndex = 62,
			OnClick = function()
				local d = State.Data
				if not d then
					return
				end
				local new = not d.Settings[t.Key]
				local res = State.Request("Setting", t.Key, new)
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
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, -12, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		OnClick = function()
			panel:Toggle()
		end,
	})
end

local function buildBanners()
	local overlay = Kit.Overlay()
	bannerLabel = Kit.Label(overlay, "", {
		Size = UDim2.fromOffset(760, 80),
		Position = UDim2.fromScale(0.5, 0.26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Ecto,
		Stroke = 4,
		ZIndex = 70,
	})
	bannerLabel.TextTransparency = 1
	bannerSub = Kit.Label(overlay, "", {
		Size = UDim2.fromOffset(640, 40),
		Position = UDim2.fromScale(0.5, 0.26),
		AnchorPoint = Vector2.new(0.5, -1.2),
		Color = Theme.Text,
		ZIndex = 70,
	})
	bannerSub.TextTransparency = 1
	announceFrame = Kit.new("Frame", {
		Size = UDim2.fromOffset(700, 52),
		Position = UDim2.new(0.5, 0, 0, -80),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 75,
		Parent = overlay,
	})
	Kit.Corner(announceFrame, UDim.new(0, 16))
	Kit.Stroke(announceFrame, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(announceFrame, Theme.Gold, Color3.fromRGB(255, 120, 40), 0)
	local l = Kit.Label(announceFrame, "", { Size = UDim2.new(1, -24, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 76 })
	l.Name = "Text"
end

local bannerToken = 0
-- Big centre-screen title (zone names, NEW AREA UNLOCKED!).
function Hud.Banner(title: string, sub: string?, color: Color3?)
	bannerToken += 1
	local my = bannerToken
	bannerLabel.Text = title
	bannerLabel.TextColor3 = color or Theme.Ecto
	bannerSub.Text = sub or ""
	bannerLabel.TextTransparency = 1
	bannerSub.TextTransparency = 1
	local s1 = bannerLabel:FindFirstChildOfClass("UIStroke") :: UIStroke
	local s2 = bannerSub:FindFirstChildOfClass("UIStroke") :: UIStroke
	s1.Transparency = 1
	s2.Transparency = 1
	bannerLabel.Size = UDim2.fromOffset(500, 50)
	Kit.Tween(bannerLabel, 0.4, { TextTransparency = 0, Size = UDim2.fromOffset(760, 80) }, Enum.EasingStyle.Back)
	Kit.Tween(s1, 0.4, { Transparency = 0 })
	Kit.Tween(bannerSub, 0.4, { TextTransparency = 0 })
	Kit.Tween(s2, 0.4, { Transparency = 0 })
	task.delay(2.6, function()
		if bannerToken ~= my then
			return
		end
		Kit.Tween(bannerLabel, 0.5, { TextTransparency = 1 })
		Kit.Tween(s1, 0.5, { Transparency = 1 })
		Kit.Tween(bannerSub, 0.5, { TextTransparency = 1 })
		Kit.Tween(s2, 0.5, { Transparency = 1 })
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
	Kit.Tween(announceFrame, 0.35, { Position = UDim2.new(0.5, 0, 0, 150) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		if announceToken == my then
			Kit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) })
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
				local f: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(180, 30), BackgroundColor3 = Theme.Panel2, Parent = boostHolder })
				Kit.Corner(f, UDim.new(1, 0))
				Kit.Stroke(f, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
				l = Kit.Label(f, "", { Size = UDim2.fromScale(0.9, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Ecto })
				boostLabels[id] = l
			end
			(l :: TextLabel).Text = def.Icon .. " " .. def.Name .. "  " .. Format.Time(left)
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
	powerLabel.Text = "⚡ " .. Format.Short(d.CrewPower or 0) .. " CAPTURE POWER"
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
	buildBanners()
end

function Hud.Start()
	State.Changed:Connect(onData)
	State.EctoChanged:Connect(function(new: number, old: number)
		targetEcto = new
		if new > old then
			floatText("+" .. Format.Short(new - old), Theme.Ecto)
			local sc = ectoPill:FindFirstChildOfClass("UIScale") :: UIScale
			sc.Scale = 1.12
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
