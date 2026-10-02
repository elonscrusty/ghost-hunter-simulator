--!strict
-- Always-on HUD, kept compact so the screen stays free for seeing and tapping ghosts:
-- Ectoplasm counter, crew power, active boosts, menu buttons (one column on big screens,
-- a 2-column block in the top-left on phones, clear of the thumbstick), settings, the
-- AUTO ATTACK toggle (pass owners only), toasts, announcements and zone banners.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Icons = require(GH.Icons)
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
local powerPrefix = "⚡ "
local boostHolder: Frame
local dailyBadge: Frame
local autoButton: TextButton
local shownEcto = 0
local targetEcto = 0
local bannerLabel: TextLabel
local bannerSub: TextLabel
local announceFrame: Frame
local announceToken = 0

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
	-- Ectoplasm + power: two same-size pills side by side, centred in the top bar row
	local top = Kit.TopBar()
	local row: Frame = Kit.new("Frame", {
		Name = "Counters",
		Size = UDim2.fromOffset(190 * 2 + 14, 40),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = top,
	})
	ectoPill = Kit.new("Frame", {
		Name = "Ecto",
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = row,
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
	if Icons.Get("ecto") then
		-- uploaded Ectoplasm icon replaces the drawn orb
		orb.BackgroundTransparency = 1
		shine.Visible = false
		local st = orb:FindFirstChildOfClass("UIStroke")
		if st then
			st.Enabled = false
		end
		local g = orb:FindFirstChildOfClass("UIGradient")
		if g then
			g.Enabled = false
		end
		Kit.Icon(orb, "ecto", "💚", { Size = UDim2.fromScale(1.15, 1.15), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	end
	ectoLabel = Kit.Label(ectoPill, "0", { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), Color = Theme.Ecto, Style = "Currency", Fit = true })
	-- crew power
	local power: Frame = Kit.new("Frame", {
		Name = "Power",
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = row,
	})
	Kit.Corner(power, UDim.new(1, 0))
	Kit.Stroke(power, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(power, Theme.Panel2, Theme.Bg, 90)
	Kit.Icon(power, "power", "⚡", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, -12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Style = "Icon", TextSize = 30, Stroke = 0, ZIndex = 4 })
	powerPrefix = ""
	powerLabel = Kit.Label(power, "0 POWER", { Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(42, 0), Color = Theme.Gold, Style = "Heading", Fit = true })
	-- boosts (only while active)
	-- directly under the counters: next-area progress bar (Tutorial), boss event bar (Boss) and
	-- active boosts, stacked so they never overlap and never sit in the middle of the play area
	local stack: Frame = Kit.new("Frame", {
		Name = "TopStack",
		Size = UDim2.fromOffset(440, 220),
		Position = UDim2.new(0.5, 0, 0, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = top,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 5), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
	Hud.TopStack = stack
	local _ = screen
	boostHolder = Kit.new("Frame", {
		Size = UDim2.fromOffset(340, 22),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = false,
		Parent = stack,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = boostHolder })
end

-- HUD layout
--   LEFT  (vertical): HUNTERS, WORLDS, INDEX
--   RIGHT (vertical, bottom-anchored stack): UPGRADES, SHOP, DAILY, then the free AUTO ATTACK
--   toggle, then the lower-right row: [DEV] FEEDBACK SETTINGS. On touch screens the stack sits
--   above the Roblox jump button; on desktop the left column starts under the chat window.
local MENU_LEFT = {
	{ Name = "Hunters", Icon = "🔦", Text = "HUNTERS", Color = "Orange" },
	{ Name = "Worlds", Icon = "🌍", Text = "WORLDS", Color = "Teal" },
	{ Name = "Index", Icon = "📖", Text = "INDEX", Color = "Blue" },
}
local MENU_RIGHT = {
	{ Name = "Upgrades", Icon = "🧲", Text = "UPGRADES", Color = "Green" },
	{ Name = "Shop", Icon = "🛒", Text = "SHOP", Color = "Pink" },
	{ Name = "Daily", Icon = "🎁", Text = "DAILY", Color = "Purple" },
}
local CELL_MAX = 84
local GAP = 6
local SMALL = 44 -- settings / feedback / dev buttons
local AUTO_W, AUTO_H = 132, 40

local menu: Frame -- left column
local menuScale: UIScale
Hud.TopStack = nil :: Frame?
local rightStack: Frame
local rightScale: UIScale
local lowerRow: Frame
Hud.LowerRow = nil :: Frame? -- other controllers (DEV button) add small buttons here
Hud.RightStack = nil :: Frame?
local chatBottomCache = 0

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Desktop only: bottom of the Roblox chat window (logical px below our inset), read once after
-- joining and on resizes, so the left column starts under it. Phones keep chat collapsed
-- behind its top-bar button (following it live made the menu jump around).
local function readChatBottom()
	chatBottomCache = 0
	if touchOnly() then
		return
	end
	pcall(function()
		local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if cfg and cfg.Enabled then
			local pos = (cfg :: any).AbsolutePosition :: Vector2
			local size = (cfg :: any).AbsoluteSize :: Vector2
			local inset = Kit.Screen().AbsolutePosition.Y
			chatBottomCache = math.max(0, (pos.Y + size.Y - inset) / Kit.UIScale())
		end
	end)
end

-- Room to keep free above the bottom edge on the right (the touch jump button), logical px.
local function bottomReserve(): number
	if not touchOnly() then
		return 10
	end
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local small = math.min(vp.X, vp.Y) < 500 -- Roblox uses the small jump button below 500 px
	local physical = if small then 100 else 225
	return physical / Kit.UIScale()
end

local function columnHeight(n: number): number
	return CELL_MAX * n + GAP * (n - 1)
end

local function layoutMenu()
	local logical = Kit.LogicalSize()
	-- right stack (anchored bottom-right, above the jump button on touch screens)
	local reserve = bottomReserve()
	local rightH = columnHeight(#MENU_RIGHT) + GAP * 2 + AUTO_H + GAP * 2 + SMALL
	local rightW = math.max(CELL_MAX, AUTO_W, SMALL * 3 + GAP * 2)
	local rfit = math.clamp((logical.Y - reserve - 8) / rightH, 0.5, 1)
	rightScale.Scale = rfit
	rightStack.Size = UDim2.fromOffset(rightW, rightH)
	rightStack.Position = UDim2.new(1, -8, 1, -reserve)
	rightStack.AnchorPoint = Vector2.new(1, 1)
	-- left column: same button size as the right, top lined up with the right column's top
	-- (desktop: never above the bottom of the chat window)
	local rightTop = logical.Y - reserve - rightH * rfit
	local top = math.max(4, rightTop, if chatBottomCache > 0 then chatBottomCache + 8 else 0)
	local full = columnHeight(#MENU_LEFT)
	menuScale.Scale = math.min(rfit, math.clamp((logical.Y - top - 10) / full, 0.5, 1))
	menu.Size = UDim2.fromOffset(CELL_MAX, full)
	menu.Position = UDim2.fromOffset(8, top)
	menu.AnchorPoint = Vector2.zero
end

local function menuButton(parent: Instance, i: number, m: any): TextButton
	local b = Kit.Button(parent, {
		Text = "",
		Color = m.Color,
		OnClick = function()
			Hud.Open(m.Name)
		end,
	})
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(CELL_MAX, CELL_MAX)
	Kit.Icon(b, "menu_" .. string.lower(m.Name), m.Icon, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 7), Style = "Icon", TextSize = 36, Stroke = 0, ZIndex = 3 })
	Kit.Label(b, m.Text, { Size = UDim2.new(1, -4, 0, 19), Position = UDim2.new(0, 2, 1, -25), Style = "Tiny", TextSize = 14, Fit = true, ZIndex = 3 })
	Hud.Buttons[m.Name] = b
	return b
end

local function buildMenu(screen: ScreenGui)
	-- LEFT column
	menu = Kit.new("Frame", { Name = "Menu", BackgroundTransparency = 1, Parent = screen })
	menuScale = Kit.new("UIScale", { Parent = menu })
	Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	for i, m in MENU_LEFT do
		menuButton(menu, i, m)
	end
	-- RIGHT stack
	rightStack = Kit.new("Frame", { Name = "RightMenu", BackgroundTransparency = 1, Parent = screen })
	rightScale = Kit.new("UIScale", { Parent = rightStack })
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, GAP * 2),
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rightStack,
	})
	local col: Frame = Kit.new("Frame", { Name = "Column", BackgroundTransparency = 1, Size = UDim2.fromOffset(CELL_MAX, columnHeight(#MENU_RIGHT)), LayoutOrder = 1, Parent = rightStack })
	Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
	for i, m in MENU_RIGHT do
		menuButton(col, i, m)
	end
	lowerRow = Kit.new("Frame", { Name = "LowerRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(SMALL * 3 + GAP * 2, SMALL), LayoutOrder = 3, Parent = rightStack })
	Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = lowerRow })
	Hud.LowerRow = lowerRow
	Hud.RightStack = rightStack
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
	-- desktop: start under the chat window (read after it has appeared; again on resizes)
	task.delay(3, function()
		readChatBottom()
		layoutMenu()
	end)
	Kit.ScaleChanged:Connect(function()
		readChatBottom()
		layoutMenu()
	end)
end

-- Settings panel (gear, top right)
local function buildSettings(screen: ScreenGui)
	local panel = Kit.Panel("Settings", "SETTINGS", Vector2.new(400, 350), "Gray")
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
	Kit.Button(list, {
		Text = "💬 SEND FEEDBACK / REPORT A BUG",
		Color = "Blue",
		Size = UDim2.fromOffset(320, 44),
		TextStyle = "Small",
		ZIndex = 62,
		OnClick = function()
			panel:Close()
			Hud.Open("Feedback")
		end,
	})
	State.OnData(function(d)
		for _, t in toggles do
			local on = d.Settings[t.Key] == true
			local b = buttons[t.Key]
			b:SetAttribute("Color", if on then "Green" else "Gray")
			Kit.SetButtonText(b, t.Text .. (if on then ": ON" else ": OFF"))
			if t.Key == "FastReveal" then
				-- fast crate opening is part of the Permanent Crate Skip pass
				b.Visible = d.Passes ~= nil and d.Passes[Config.CrateSkip.Pass] == true
			end
		end
	end)
	Hud.RegisterPanel("Settings", function()
		panel:Toggle()
	end)
	-- lower-right row: FEEDBACK then SETTINGS (the DEV button, for developers, goes first)
	local _ = screen
	local feedback = Kit.Button(lowerRow, {
		Text = "💬",
		Color = "Blue",
		Size = UDim2.fromOffset(SMALL, SMALL),
		TextStyle = "Heading",
		OnClick = function()
			Hud.Open("Feedback")
		end,
	})
	feedback.LayoutOrder = 2
	local gear = Kit.Button(lowerRow, {
		Text = "",
		Color = "Gray",
		Size = UDim2.fromOffset(SMALL, SMALL),
		TextStyle = "Heading",
		OnClick = function()
			panel:Toggle()
		end,
	})
	gear.LayoutOrder = 3
	Kit.Icon(gear, "menu_settings", "⚙", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Heading", Stroke = 0, ZIndex = 3 })
end

-- AUTO ATTACK toggle: FREE for every player (no pass, no Robux).
local busyAuto = false
local function refreshAuto()
	autoButton.Visible = true -- Auto Attack is free for everyone
	local on = player:GetAttribute("AutoAttack") == true
	Kit.SetButtonText(autoButton, if on then "🤖 AUTO: ON" else "🤖 AUTO: OFF")
	autoButton:SetAttribute("Color", if on then "Green" else "Gray")
end

local function buildAuto(screen: ScreenGui)
	autoButton = Kit.Button(rightStack, {
		Text = "🤖 AUTO: OFF",
		Color = "Gray",
		Size = UDim2.fromOffset(AUTO_W, AUTO_H),
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
	autoButton.LayoutOrder = 2
	autoButton.Visible = false
	player:GetAttributeChangedSignal("AutoAttack"):Connect(refreshAuto)
	State.OnData(function()
		refreshAuto()
	end)
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
		Visible = false,
		ZIndex = 75,
		Parent = overlay,
	})
	Kit.Corner(announceFrame, UDim.new(0, 12))
	Kit.Stroke(announceFrame, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(announceFrame, Theme.Gold, Color3.fromRGB(255, 120, 40), 0)
	local l = Kit.Label(announceFrame, "", { Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(10, 0), Style = "Body", Fit = true, ZIndex = 76 })
	l.Name = "Text"
	-- ✕ (or tapping the bar anywhere) dismisses the announcement right away
	local function dismiss()
		announceToken += 1
		local my = announceToken
		Kit.Tween(announceFrame, 0.2, { Position = UDim2.new(0.5, 0, 0, -60) })
		task.delay(0.2, function()
			if announceToken == my then
				announceFrame.Visible = false
			end
		end)
	end
	local tap: TextButton = Kit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 77, Parent = announceFrame })
	tap.Activated:Connect(dismiss)
	Kit.CloseButton(announceFrame, dismiss, 79)
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

-- Sliding top announcement (legendary hatches, boss events).
function Hud.Announce(text: string, c1: Color3?, c2: Color3?)
	announceToken += 1
	local my = announceToken
	local l = announceFrame:FindFirstChild("Text") :: TextLabel
	l.Text = text
	local g = announceFrame:FindFirstChildOfClass("UIGradient") :: UIGradient
	g.Color = ColorSequence.new(c1 or Theme.Gold, c2 or Color3.fromRGB(255, 120, 40))
	-- below the boss bar / goal chip so event warnings never stack on top of each other
	announceFrame.Visible = true
	Kit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, 100) }, Enum.EasingStyle.Back)
	task.delay(4, function()
		if announceToken == my then
			Kit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, -60) })
			task.wait(0.3)
			if announceToken == my then
				announceFrame.Visible = false -- parked off-screen must not peek under the top bar
			end
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
	local chips: { [string]: any } = {}
	for id, def in Config.Boosts :: any do
		if type(def) == "table" then
			chips[id] = { Icon = def.Icon, Name = def.Name, Expiry = d.Boosts[id] }
		end
	end
	-- server-wide luck someone bought (Robux): everyone sees it
	chips.ServerLuck = { Icon = "🍀", Name = "SERVER LUCK", Expiry = d.ServerLuckUntil }
	-- global 2X Ectoplasm event (developer-controlled; a countdown when it was started for a set time)
	local ends = workspace:GetAttribute("Ecto2xEnds")
	local timed = type(ends) == "number" and ends > 0
	chips.Ecto2x = {
		Icon = "💚",
		Name = "2X ECTOPLASM",
		Expiry = if workspace:GetAttribute("Ecto2x") ~= true then 0 elseif timed then ends else now + 1e9,
		NoTimer = not timed,
	}
	for id, def in chips do
		local expiry = def.Expiry
		local left = if expiry then expiry - now else 0
		local l = boostLabels[id]
		if left > 0 then
			if not l then
				local f: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(150, 22), BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.1, Parent = boostHolder })
				Kit.Corner(f, UDim.new(1, 0))
				l = Kit.Label(f, "", { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), Color = Theme.Ecto, Style = "Tiny", Fit = true })
				boostLabels[id] = l
			end
			Kit.EctoText(l :: TextLabel, def.Icon .. " " .. def.Name .. (if def.NoTimer then "" else " " .. Format.Time(left)))
		elseif l then
			(l.Parent :: Instance):Destroy()
			boostLabels[id] = nil
		end
	end
	boostHolder.Visible = next(boostLabels) ~= nil
	local info = d.DailyInfo
	if info then
		local canClaim = info.CanClaim or info.Wait - (now - (d.ServerTime or now)) <= 0
		dailyBadge.Visible = canClaim
	end
end

local seeded = false
local function onData(d: any)
	powerLabel.Text = powerPrefix .. Format.Short(d.CrewPower or 0) .. " POWER"
	targetEcto = d.Ecto
	if not seeded then
		-- first snapshot: show the balance as-is (no count-up from 0 on every join)
		seeded = true
		shownEcto = d.Ecto
		ectoLabel.Text = Format.Short(d.Ecto)
	end
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
	-- TopStack lives in the top-bar ScreenGui (drawn above the HUD screen), so hide it while a
	-- panel is open (it would cover the panel's title) or the HUD is hidden (crate reveal)
	local stack = Hud.TopStack
	if stack then
		local function syncStack()
			stack.Visible = screen.Enabled and Kit.CurrentPanel() == nil
		end
		screen:GetPropertyChangedSignal("Enabled"):Connect(syncStack)
		Kit.PanelOpened:Connect(function()
			task.defer(syncStack)
		end)
	end
end

-- [VIP] chat tag for VIP pass owners (the server sets the player's "VIP" attribute)
local function hookVipChat()
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local props = Instance.new("TextChatMessageProperties")
			local src = message.TextSource
			local who = src and Players:GetPlayerByUserId(src.UserId)
			if who and who:GetAttribute("VIP") == true then
				props.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
			end
			return props
		end
	end)
end

function Hud.Start()
	hookVipChat()
	State.OnData(onData)
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
	State.OnFx("Toast", function(data: any)
		Kit.Toast(data.Text, data.Color)
	end)
	State.OnFx("Announce", function(data: any)
		local r = Config.Rarities[data.Color]
		Hud.Announce(data.Text, r and r.Color, r and r.Color2)
	end)
end

return Hud
