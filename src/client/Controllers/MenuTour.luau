--!strict
-- MENU TOUR: right after the tutorial (and from Settings > MENU TOUR) a short walk through the
-- HUD: one menu button / counter at a time gets a pulsing outline and a bobbing arrow, the
-- other buttons dim a little, and a small tip card has NEXT / SKIP TOUR. Nothing opens by
-- itself and nothing is blocked: the tour only draws on the overlay (its highlight pieces
-- never take input) and steps aside while a menu is open or the HUD is hidden.
-- Saved state: Settings.Tour = "tour still owed" (set when the tutorial is finished, cleared
-- when the tour ends), so a player who leaves mid-tour gets it again next time, and players
-- who finished the tutorial before the tour existed are never forced into it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local MenuTour = {}

type Step = { Title: string, Tip: string, Target: (() -> GuiObject?)? }

local function button(name: string): () -> GuiObject?
	return function()
		return Hud.Buttons[name]
	end
end

local function counter(name: string): () -> GuiObject?
	return function()
		return Hud.Counters[name]
	end
end

local function autoButton(): GuiObject?
	local stack = Hud.RightStack
	local b = stack and stack:FindFirstChild("AutoAttack")
	return if b and b:IsA("GuiObject") then b else nil
end

local STEPS: { Step } = {
	{ Title = "💚 ECTOPLASM", Tip = "Your money: defeat ghosts and collect it.", Target = counter("Ecto") },
	{ Title = "⚡ POWER", Tip = "Damage per second of your whole crew.", Target = counter("Power") },
	{ Title = "🔮 SPIRIT SHARDS", Tip = "Won in the Boss Tower.", Target = counter("Shards") },
	{ Title = "🔦 HUNTERS", Tip = "Your crew: equip, merge and release hunters.", Target = button("Hunters") },
	{ Title = "📖 INDEX", Tip = "Every hunter & pet you've found.", Target = button("Index") },
	{ Title = "🌍 WORLDS", Tip = "Travel to any area you've unlocked.", Target = button("Worlds") },
	{ Title = "🐾 PETS", Tip = "Equip pets for extra bonuses.", Target = button("Pets") },
	{ Title = "🧲 UPGRADES", Tip = "Spend Ectoplasm on permanent upgrades.", Target = button("Upgrades") },
	{ Title = "🛒 SHOP", Tip = "Boosts, passes and Ectoplasm packs.", Target = button("Shop") },
	{ Title = "🎁 DAILY", Tip = "A free reward every day!", Target = button("Daily") },
	{ Title = "🤖 AUTO", Tip = "Auto-attack nearby ghosts. Free for everyone!", Target = autoButton },
	{ Title = "💬 FEEDBACK", Tip = "Send ideas or report a bug.", Target = button("Feedback") },
	{ Title = "⚙ SETTINGS", Tip = "Music, sounds, names, and this tour again.", Target = button("Settings") },
	{ Title = "🏠 LOBBY BOOTHS", Tip = "Find the MERGE, TRADING, PET HATCHERY and BOSS TOWER booths in the lobby!" },
}

local BOX_H = 132
local DIM_TRANSPARENCY = 0.55

local running = false
local index = 0
local conn: RBXScriptConnection? = nil
local holder: Frame -- zero-size container on the overlay: draws, never covers anything
local box: Frame
local titleLabel: TextLabel
local tipLabel: TextLabel
local countLabel: TextLabel
local nextButton: TextButton
local ring: Frame
local ringStroke: UIStroke
local arrow: TextLabel
local dims: { [GuiObject]: Frame } = {}

-- On screen right now: every ancestor visible, its ScreenGui enabled and it has a size.
local function shown(g: GuiObject?): boolean
	if not g or g.AbsoluteSize.X < 1 then
		return false
	end
	local node: Instance? = g
	while node do
		if node:IsA("LayerCollector") then
			return node.Enabled
		elseif node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return false
end

local function targetOf(i: number): GuiObject?
	local s = STEPS[i]
	return if s and s.Target then s.Target() else nil
end

-- Steps with a target are skipped while that target is hidden (PETS before it's unlocked).
local function usable(i: number): boolean
	local s = STEPS[i]
	return s ~= nil and (s.Target == nil or shown(targetOf(i)))
end

-- Rect of a gui object in the overlay's logical coordinates.
local function rectOf(g: GuiObject): (Vector2, Vector2)
	local overlay = Kit.Overlay()
	local k = math.max(Kit.UIScale(), 0.05)
	return (g.AbsolutePosition - overlay.AbsolutePosition) / k, g.AbsoluteSize / k
end

local function finish(markDone: boolean)
	if not running then
		return
	end
	running = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	holder.Visible = false
	for _, f in dims do
		f:Destroy()
	end
	table.clear(dims)
	local d = State.Data
	if markDone and d and d.Settings.Tour == true then
		task.spawn(State.Request, "Setting", "Tour", false)
	end
end

local function show(i: number)
	while i <= #STEPS and not usable(i) do
		i += 1
	end
	if i > #STEPS then
		finish(true)
		return
	end
	index = i
	local s = STEPS[i]
	titleLabel.Text = s.Title
	Kit.EctoText(tipLabel, s.Tip)
	local total, at = 0, 0
	for j in STEPS do
		if usable(j) or j == i then
			total += 1
			if j <= i then
				at += 1
			end
		end
	end
	countLabel.Text = at .. " / " .. total
	Kit.SetButtonText(nextButton, if i == #STEPS then "DONE!" else "NEXT")
	Sound.Play("Select")
end

-- Keeps the highlight on its target every frame (menus rescale and move with the screen).
local function update()
	local hudOn = Kit.Screen().Enabled and Kit.CurrentPanel() == nil
	holder.Visible = hudOn
	if not hudOn then
		return
	end
	local logical = Kit.LogicalSize()
	local target = targetOf(index)
	local tPos, tSize = Vector2.zero, Vector2.zero
	if target and shown(target) then
		tPos, tSize = rectOf(target)
		ring.Visible = true
		ring.Position = UDim2.fromOffset(tPos.X + tSize.X / 2, tPos.Y + tSize.Y / 2)
		ring.Size = UDim2.fromOffset(tSize.X + 10, tSize.Y + 10)
		arrow.Visible = true
		local cx = tPos.X + tSize.X / 2
		if cx < logical.X * 0.35 then
			arrow.Text = "⬅" -- left column: arrow to its right
			arrow.Position = UDim2.fromOffset(tPos.X + tSize.X + 30, tPos.Y + tSize.Y / 2)
		elseif cx > logical.X * 0.65 then
			arrow.Text = "➡"
			arrow.Position = UDim2.fromOffset(tPos.X - 30, tPos.Y + tSize.Y / 2)
		else
			arrow.Text = "⬆" -- top counters: arrow underneath
			arrow.Position = UDim2.fromOffset(cx, tPos.Y + tSize.Y + 28)
		end
	else
		target = nil
		ring.Visible = false
		arrow.Visible = false
	end
	-- light dim over the other visible tour targets
	local seen: { [GuiObject]: boolean } = {}
	for j in STEPS do
		local g = targetOf(j)
		if g and g ~= target and shown(g) then
			seen[g] = true
			local frame = dims[g]
			if not frame then
				local f: Frame = Kit.new("Frame", {
					Name = "TourDim",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = DIM_TRANSPARENCY,
					Active = false,
					Interactable = false,
					ZIndex = 80,
					Parent = holder,
				})
				Kit.Corner(f, UDim.new(0, 12))
				dims[g] = f
				frame = f
			end
			local p, sz = rectOf(g)
			frame.Position = UDim2.fromOffset(p.X + sz.X / 2, p.Y + sz.Y / 2)
			frame.Size = UDim2.fromOffset(sz.X, sz.Y)
		end
	end
	for g, f in dims do
		if not seen[g] then
			f:Destroy()
			dims[g] = nil
		end
	end
	-- tip card: centred, moved up/down when it would sit on the highlighted target
	local w = math.clamp(logical.X - 40, 260, 400)
	box.Size = UDim2.fromOffset(w, BOX_H)
	local x0 = (logical.X - w) / 2
	local function covers(y: number): boolean
		if not target then
			return false
		end
		return tPos.X < x0 + w and tPos.X + tSize.X > x0 and tPos.Y < y + BOX_H and tPos.Y + tSize.Y > y
	end
	local y = logical.Y * 0.45 - BOX_H / 2
	if covers(y) then
		y = if not covers(logical.Y * 0.2) then logical.Y * 0.2 else logical.Y * 0.7 - BOX_H
	end
	box.Position = UDim2.fromOffset(x0, math.max(8, y))
end

local function begin()
	if running then
		show(1)
		return
	end
	running = true
	holder.Visible = true
	show(1)
	conn = RunService.RenderStepped:Connect(update)
end

function MenuTour.Begin()
	begin()
end

function MenuTour.IsRunning(): boolean
	return running
end

-- Called by the tutorial when its last step is done: remember the tour is owed (a player who
-- leaves right away gets it next time), then start it once the screen is free.
function MenuTour.AfterTutorial()
	local d = State.Data
	if d and d.Settings.Tour ~= true then
		task.spawn(State.Request, "Setting", "Tour", true)
	end
	task.delay(3, function()
		Kit.WhenFree(begin)
	end)
end

function MenuTour.Init()
	local overlay = Kit.Overlay()
	holder = Kit.new("Frame", {
		Name = "MenuTour",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		ZIndex = 80,
		Parent = overlay,
	})
	ring = Kit.new("Frame", {
		Name = "TourRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Active = false,
		Interactable = false,
		ZIndex = 82,
		Parent = holder,
	})
	Kit.Corner(ring, UDim.new(0, 16))
	ringStroke = Kit.Stroke(ring, 4, Theme.Ecto, Enum.ApplyStrokeMode.Border)
	arrow = Kit.Label(holder, "⬅", { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Ecto, Style = "Banner", ZIndex = 83 })
	arrow.Active = false
	arrow.Interactable = false
	-- the tip card
	box = Kit.new("Frame", {
		Name = "TourTip",
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 86,
		Parent = holder,
	})
	Kit.Corner(box, UDim.new(0, 16))
	Kit.Stroke(box, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(box, Theme.Panel2, Theme.Panel, 90)
	titleLabel = Kit.Label(box, "", { Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 8), Color = Theme.Ecto, Style = "Heading", Fit = true, ZIndex = 87 })
	tipLabel = Kit.Label(box, "", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 36), Style = "Body", Wrap = true, ZIndex = 87 })
	countLabel = Kit.Label(box, "", { Size = UDim2.fromOffset(70, 20), Position = UDim2.new(0.5, 0, 1, -28), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Tiny", Fit = true, ZIndex = 87 })
	Kit.Button(box, {
		Text = "SKIP TOUR",
		Color = "Gray",
		Size = UDim2.fromOffset(110, 38),
		Position = UDim2.new(0, 12, 1, -10),
		AnchorPoint = Vector2.new(0, 1),
		TextStyle = "Small",
		ZIndex = 88,
		OnClick = function()
			finish(true)
		end,
	})
	nextButton = Kit.Button(box, {
		Text = "NEXT",
		Color = "Green",
		Size = UDim2.fromOffset(110, 38),
		Position = UDim2.new(1, -12, 1, -10),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 88,
		OnClick = function()
			show(index + 1)
		end,
	})
	-- pulse the outline (size + stroke fade only; no text is scaled)
	task.spawn(function()
		while true do
			if running and ring.Visible then
				ringStroke.Transparency = 0
				Kit.Tween(ringStroke, 0.8, { Transparency = 0.85 })
				task.wait(0.9)
			else
				task.wait(0.3)
			end
		end
	end)
	-- bob the arrow toward its target
	local bob = Kit.new("UIPadding", { Parent = arrow })
	task.spawn(function()
		while true do
			if running and arrow.Visible then
				local horizontal = arrow.Text ~= "⬆"
				local sign = if arrow.Text == "➡" then 1 else -1
				Kit.Tween(bob, 0.4, if horizontal then { PaddingLeft = UDim.new(0, if sign > 0 then 10 else 0), PaddingRight = UDim.new(0, if sign < 0 then 10 else 0) } else { PaddingBottom = UDim.new(0, 10), PaddingTop = UDim.new(0, 0) }, Enum.EasingStyle.Sine)
				task.wait(0.4)
				Kit.Tween(bob, 0.4, { PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0), PaddingTop = UDim.new(0, 0) }, Enum.EasingStyle.Sine)
				task.wait(0.4)
			else
				task.wait(0.3)
			end
		end
	end)
	Hud.RegisterPanel("MenuTour", begin) -- Settings > MENU TOUR replays it
end

function MenuTour.Start()
	task.spawn(function()
		local d = State.WaitForData()
		-- owed from an earlier session (left mid-tour): show it again once things settle
		if d.Settings.Tour == true and (d.Tutorial or 1) > #Config.Tutorial.Steps then
			task.wait(5)
			Kit.WhenFree(function()
				local now = State.Data
				if now and now.Settings.Tour == true then
					begin()
				end
			end)
		end
	end)
end

return MenuTour
