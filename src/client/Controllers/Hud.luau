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
local ProximityPromptService = game:GetService("ProximityPromptService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Icons = require(GH.Icons)
local Format = require(GH.Logic.Format)
local Rules = require(GH.Logic.Rules)
local Layout = require(GH.Logic.Layout)
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
local shardLabel: TextLabel
local tradeButton: TextButton
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
	-- Ectoplasm + power + Spirit Shards: three same-size pills side by side, centred in the top bar row
	local PILL_W = 160
	local top = Kit.TopBar()
	local row: Frame = Kit.new("Frame", {
		Name = "Counters",
		Size = UDim2.fromOffset(PILL_W * 3 + 14 * 2, 40),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = top,
	})
	ectoPill = Kit.new("Frame", {
		Name = "Ecto",
		Size = UDim2.fromOffset(PILL_W, 40),
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
		Size = UDim2.fromOffset(PILL_W, 40),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = row,
	})
	Kit.Corner(power, UDim.new(1, 0))
	Kit.Stroke(power, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(power, Theme.Panel2, Theme.Bg, 90)
	Kit.Icon(power, "power", "⚡", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, -12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Style = "Icon", TextSize = 30, Stroke = 0, ZIndex = 4 })
	powerPrefix = ""
	powerLabel = Kit.Label(power, "0 POWER", { Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(42, 0), Color = Theme.Gold, Style = "Heading", Fit = true })
	-- Spirit Shards (Hud.ShardsPill: target for shard fly-in effects)
	local shards: Frame = Kit.new("Frame", {
		Name = "Shards",
		Size = UDim2.fromOffset(PILL_W, 40),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = row,
	})
	Kit.Corner(shards, UDim.new(1, 0))
	Kit.Stroke(shards, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(shards, Theme.Panel2, Theme.Bg, 90)
	Kit.new("UIScale", { Parent = shards })
	Kit.Icon(shards, "shards", "🔮", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, -12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Style = "Icon", TextSize = 30, Stroke = 0, ZIndex = 4 })
	shardLabel = Kit.Label(shards, "0", { Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(42, 0), Color = Color3.fromRGB(200, 160, 255), Style = "Currency", Fit = true })
	Hud.ShardsPill = shards
	Hud.Counters = { Ecto = ectoPill, Power = power, Shards = shards } -- menu tour targets
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
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = false,
		Parent = stack,
	})
	-- 3+ active boosts wrap onto a second row instead of spilling past the stack's sides
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Wraps = true, Parent = boostHolder })
end

-- HUD layout
--   LEFT  (vertical): HUNTERS, INDEX, WORLDS, PETS (PETS appears once Boss Tower/shards start)
--   RIGHT (vertical, bottom-anchored stack): UPGRADES, SHOP, DAILY, then the free AUTO ATTACK
--   toggle, then the lower-right row: [DEV] [TRADE] FEEDBACK SETTINGS. On touch screens the stack sits
--   above the Roblox jump button; on desktop the left column starts under the chat window.
--   Short phone screens (Layout.Menu) get shorter cells, the lower-right row moves left of the
--   jump button and the lift shrinks, so labels stay >= 10 px and taps >= 44 px.
local MENU_LEFT = {
	{ Name = "Hunters", Icon = "🔦", Text = "HUNTERS", Color = "Orange" },
	{ Name = "Index", Icon = "📖", Text = "INDEX", Color = "Blue" },
	{ Name = "Worlds", Icon = "🌍", Text = "WORLDS", Color = "Teal" },
	{ Name = "Pets", Icon = "🐾", Text = "PETS", Color = "Purple" },
}
local MENU_RIGHT = {
	{ Name = "Upgrades", Icon = "🧲", Text = "UPGRADES", Color = "Green" },
	{ Name = "Shop", Icon = "🛒", Text = "SHOP", Color = "Pink" },
	{ Name = "Daily", Icon = "🎁", Text = "DAILY", Color = "Purple" },
}
-- sizes (cells, gaps, corner buttons, AUTO toggle) live in Shared/Logic/Layout, which also
-- decides how far the menus may shrink on small screens (readable labels, 44 px taps)
local CELL_MAX = Layout.Cell
local GAP = Layout.Gap
local SMALL = Layout.SmallButton -- settings / feedback / trade / dev buttons
local ROW_COUNT = 4 -- DEV, TRADE, FEEDBACK, SETTINGS (the most that can show)

type Cell = { Button: TextButton, Icon: GuiObject, Label: TextLabel }
local leftCells: { Cell } = {}
local rightCells: { Cell } = {}
local menu: Frame -- left column
local menuScale: UIScale
local menuList: UIListLayout
local rightColumn: Frame
local rightColumnList: UIListLayout
local rightList: UIListLayout
local rowScale: UIScale -- the corner-button row's own scale while it sits beside the jump button
local rowList: UIListLayout
local screenGui: ScreenGui
Hud.TopStack = nil :: Frame?
Hud.ShardsPill = nil :: Frame?
Hud.Counters = {} :: { [string]: Frame }
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
-- MENU_LIFT is added on top so both menu columns sit a little higher; on a short phone screen
-- Layout.Menu uses less of it when the full lift would make the menus unreadable / untappable.
local MENU_LIFT = 90 -- owner: a bit higher again (was 40)
local function jumpReserve(): number
	if not touchOnly() then
		return 10
	end
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local small = math.min(vp.X, vp.Y) < 500 -- Roblox uses the small jump button below 500 px
	local physical = if small then 100 else 225
	return physical / Kit.UIScale()
end

-- Touch only: logical distance from our screen's right edge to the jump button's left edge
-- (Roblox: 70 px button at (1, -95) below 500 px, else 120 px at (1, -170), device pixels).
-- Measured as if our screen reached the device edge: with a notch inset the row just sits a
-- little further left, never on the jump button.
local function jumpLeft(): number?
	if not touchOnly() then
		return nil
	end
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local small = math.min(vp.X, vp.Y) < 500
	return (if small then 95 else 170) / Kit.UIScale()
end

-- one menu cell: compact cells are shorter (smaller icon), the label keeps its room
local function sizeCell(c: Cell, h: number, compact: boolean)
	c.Button.Size = UDim2.fromOffset(CELL_MAX, h)
	local iconH = if compact then 34 else 44
	c.Icon.Size = UDim2.new(1, 0, 0, iconH)
	c.Icon.Position = UDim2.fromOffset(0, if compact then 4 else 7)
	if c.Icon:IsA("TextLabel") then
		Kit.FitText(c.Icon, if compact then 28 else 36, 0, false) -- emoji fallback
	end
	c.Label.Position = UDim2.new(0, Layout.LabelPad, 1, if compact then -22 else -25)
end

local function layoutMenu()
	local logical = Kit.LogicalSize()
	local L = Layout.Menu({
		Scale = Kit.UIScale(),
		Width = logical.X,
		Height = logical.Y,
		Reserve = jumpReserve(),
		Lift = MENU_LIFT,
		JumpLeft = jumpLeft(),
		-- desktop: never above the bottom of the chat window
		TopMin = if chatBottomCache > 0 then chatBottomCache + 8 else 0,
		Left = #MENU_LEFT,
		Right = #MENU_RIGHT,
		Small = ROW_COUNT,
	})
	local R = L.Right
	-- right stack (anchored bottom-right, above the jump button on touch screens)
	rightScale.Scale = L.RightScale
	rightStack.Size = UDim2.fromOffset(L.RightW, L.RightH)
	rightStack.Position = UDim2.new(1, -Layout.Margin, 1, -L.RightBottom)
	rightStack.AnchorPoint = Vector2.new(1, 1)
	rightList.Padding = UDim.new(0, R.RowGap)
	rightColumnList.Padding = UDim.new(0, R.Gap)
	rightColumn.Size = UDim2.fromOffset(CELL_MAX, Layout.ColumnHeight(R, #MENU_RIGHT))
	for _, c in rightCells do
		sizeCell(c, R.CellH, L.Compact)
	end
	if autoButton then
		autoButton.Size = UDim2.fromOffset(Layout.AutoW, R.AutoH)
	end
	-- corner buttons: the stack's bottom row, or (short touch screens) left of the jump button
	lowerRow.Size = UDim2.fromOffset(L.RowW, R.Small)
	rowList.Padding = UDim.new(0, R.Gap)
	for _, b in lowerRow:GetChildren() do
		if b:IsA("GuiButton") then
			b.Size = UDim2.fromOffset(R.Small, R.Small)
		end
	end
	local rowParent: Instance = if L.RowBeside then screenGui else rightStack
	rowScale.Scale = if L.RowBeside then L.RightScale else 1
	if lowerRow.Parent ~= rowParent then
		lowerRow.Parent = rowParent
		Kit.Refit(lowerRow)
	end
	if L.RowBeside then
		lowerRow.Position = UDim2.new(1, -L.RowRight, 1, -L.RowBottom)
		lowerRow.AnchorPoint = Vector2.new(1, 1)
	end
	-- left column: same button size as the right, top lined up with the right column's top
	menuScale.Scale = L.LeftScale
	menuList.Padding = UDim.new(0, L.Left.Gap)
	for _, c in leftCells do
		sizeCell(c, L.Left.CellH, L.Compact)
	end
	menu.Size = UDim2.fromOffset(CELL_MAX, L.LeftH)
	menu.Position = UDim2.fromOffset(Layout.Margin, L.LeftTop)
	menu.AnchorPoint = Vector2.zero
end

local function menuButton(parent: Instance, i: number, m: any, cells: { Cell }): TextButton
	local b = Kit.Button(parent, {
		Text = "",
		Color = m.Color,
		OnClick = function()
			Hud.Open(m.Name)
		end,
	})
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(CELL_MAX, CELL_MAX)
	local icon = Kit.Icon(b, "menu_" .. string.lower(m.Name), m.Icon, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 7), Style = "Icon", TextSize = 36, Stroke = 0, ZIndex = 3 })
	-- the label's text fit counts the menu's own scale, so it may grow a little on phones: it
	-- gets the cell's whole width
	local label = Kit.Label(b, m.Text, { Size = UDim2.new(1, -2 * Layout.LabelPad, 0, 19), Position = UDim2.new(0, Layout.LabelPad, 1, -25), Style = "Tiny", TextSize = Layout.LabelSize, Fit = true, ZIndex = 3 })
	table.insert(cells, { Button = b, Icon = icon, Label = label })
	Hud.Buttons[m.Name] = b
	return b
end

local function buildMenu(screen: ScreenGui)
	-- LEFT column
	screenGui = screen
	menu = Kit.new("Frame", { Name = "Menu", BackgroundTransparency = 1, Parent = screen })
	menuScale = Kit.new("UIScale", { Parent = menu })
	Kit.LayoutScale(menuScale)
	menuList = Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	for i, m in MENU_LEFT do
		menuButton(menu, i, m, leftCells)
	end
	-- RIGHT stack
	rightStack = Kit.new("Frame", { Name = "RightMenu", BackgroundTransparency = 1, Parent = screen })
	rightScale = Kit.new("UIScale", { Parent = rightStack })
	Kit.LayoutScale(rightScale)
	rightList = Kit.new("UIListLayout", {
		Padding = UDim.new(0, GAP * 2),
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rightStack,
	})
	rightColumn = Kit.new("Frame", { Name = "Column", BackgroundTransparency = 1, Size = UDim2.fromOffset(CELL_MAX, CELL_MAX * #MENU_RIGHT), LayoutOrder = 1, Parent = rightStack })
	rightColumnList = Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightColumn })
	for i, m in MENU_RIGHT do
		menuButton(rightColumn, i, m, rightCells)
	end
	lowerRow = Kit.new("Frame", { Name = "LowerRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(SMALL * ROW_COUNT + GAP * (ROW_COUNT - 1), SMALL), LayoutOrder = 3, Parent = rightStack })
	rowScale = Kit.new("UIScale", { Parent = lowerRow })
	Kit.LayoutScale(rowScale)
	rowList = Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = lowerRow })
	-- the DEV button (DevPanel) joins later: size it like the rest
	lowerRow.ChildAdded:Connect(function()
		task.defer(layoutMenu)
	end)
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
	local panel = Kit.Panel("Settings", "SETTINGS", Vector2.new(400, 460), "Gray")
	local list: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel.Body, ZIndex = 61 })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = list })
	local toggles = {
		{ Key = "Music", Text = "MUSIC" },
		{ Key = "Sfx", Text = "SOUND EFFECTS" },
		{ Key = "FastReveal", Text = "FAST CRATE OPENING" },
		{ Key = "Names", Text = "HUNTER & PET NAMES" },
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
	Kit.Button(list, {
		Text = "📖 MENU TOUR",
		Color = "Purple",
		Size = UDim2.fromOffset(320, 44),
		ZIndex = 62,
		OnClick = function()
			panel:Close()
			Hud.Open("MenuTour") -- registered by MenuTour
		end,
	})
	State.OnData(function(d)
		-- names over hunters and pets: Crew / PetFollowers read this attribute for new tags
		local namesOn = d.Settings.Names ~= false
		local me = game:GetService("Players").LocalPlayer
		if me:GetAttribute("ShowNames") ~= namesOn then
			me:SetAttribute("ShowNames", namesOn)
			for _, g in workspace:GetDescendants() do
				if g:IsA("BillboardGui") and (g.Name == "Tag" or g.Name == "PetTag") then
					g.Enabled = namesOn
				end
			end
		end
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
	-- lower-right row: [TRADE] FEEDBACK SETTINGS (the DEV button, for developers, goes first)
	local _ = screen
	tradeButton = Kit.Button(lowerRow, {
		Text = "",
		Color = "Teal",
		Size = UDim2.fromOffset(SMALL, SMALL),
		TextStyle = "Heading",
		OnClick = function()
			Hud.Open("Trade")
		end,
	})
	Kit.Icon(tradeButton, "menu_trade", "🤝", { Size = UDim2.fromScale(0.85, 0.85), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Heading", Stroke = 0, ZIndex = 3 })
	tradeButton.LayoutOrder = 2
	tradeButton.Visible = false
	Hud.Buttons.Trade = tradeButton
	local feedback = Kit.Button(lowerRow, {
		Text = "💬",
		Color = "Blue",
		Size = UDim2.fromOffset(SMALL, SMALL),
		TextStyle = "Heading",
		OnClick = function()
			Hud.Open("Feedback")
		end,
	})
	feedback.LayoutOrder = 3
	Hud.Buttons.Feedback = feedback
	local gear = Kit.Button(lowerRow, {
		Text = "",
		Color = "Gray",
		Size = UDim2.fromOffset(SMALL, SMALL),
		TextStyle = "Heading",
		OnClick = function()
			panel:Toggle()
		end,
	})
	gear.LayoutOrder = 4
	Hud.Buttons.Settings = gear
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
		Size = UDim2.fromOffset(Layout.AutoW, Layout.AutoH),
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
		-- on the HUD screen, below panels (ZIndex 60): an announcement must never cover an open
		-- popup's title (it used to sit on the overlay, above every panel)
		ZIndex = 58,
		Parent = Kit.Screen(),
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
	Kit.IconText(bannerSub, sub or "") -- 💚 / 🔮 / ⚡ ... as their uploaded images
	local subIcons: { ImageLabel } = {}
	for _, c in bannerSub:GetChildren() do
		if c:IsA("ImageLabel") and c.Visible then
			table.insert(subIcons, c)
			c.ImageTransparency = 1
			Kit.Tween(c, 0.3, { ImageTransparency = 0 })
		end
	end
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
		for _, c in subIcons do
			Kit.Tween(c, 0.45, { ImageTransparency = 1 })
		end
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
	-- gradual reveal: PETS once the Boss Tower/shards start, TRADE once the player has 5+ hunters
	local shards = d.Shards or 0
	Hud.Buttons.Pets.Visible = shards > 0 or (d.Pets ~= nil and next(d.Pets) ~= nil) or (d.TowerRuns or 0) > 0
	tradeButton.Visible = false -- trading opens from the TRADING booth only (no request spam)
	shardLabel.Text = Format.Short(shards)
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
	layoutMenu() -- again now that the AUTO toggle exists
	buildBanners()
	Hud.Buttons.Pets.Visible = false
	-- world kiosks open their panels (always, even before the menu buttons are revealed)
	local KIOSK_PANELS: { [string]: string } = { Trade = if Config.Trade.Enabled then "Trade" else nil, Pets = "Pets", Merge = "Hunters" } :: any
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local parent = prompt.Parent
		local name = parent and KIOSK_PANELS[tostring(parent:GetAttribute("Kiosk"))]
		if name then
			Hud.Open(name)
		end
	end)
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
