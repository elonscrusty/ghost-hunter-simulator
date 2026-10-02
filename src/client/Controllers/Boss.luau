--!strict
-- GIANT POLTERGEIST event presentation: warning announcement + countdown, a beacon over the
-- arena, dramatic spawn (flash, rings, camera shake), a big boss Spirit bar with timer, and
-- defeat / escape banners. Rewards arrive as normal Ectoplasm drops (the shower).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Signal = require(GH.Signal)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local State = require(Client.State)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Ghosts = require(script.Parent.Ghosts)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Boss = {}

local player = Players.LocalPlayer
local frame: Frame
local fill: Frame
local spiritLabel: TextLabel
local timerLabel: TextLabel
local titleLabel: TextLabel
local goButton: TextButton
local beacon: Part? = nil
local state = "Idle"
local warnAt = 0
local endsAt = 0
local bossUid = 0
local arenaPos = Config.Layout.EventArena.Center
local dismissed = false -- the player closed the event bar for this event (a small pill reopens it)
local reopen: TextButton

local function setBeacon(on: boolean)
	if on and not beacon then
		local b = Instance.new("Part")
		b.Name = "BossBeacon"
		b.Shape = Enum.PartType.Cylinder
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = Color3.fromRGB(255, 120, 230)
		b.Transparency = 0.55
		b.Size = Vector3.new(220, 5, 5)
		b.CFrame = CFrame.new(arenaPos + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.rad(90))
		b.Parent = workspace
		beacon = b
		task.spawn(function()
			while beacon == b do
				TweenService:Create(b, TweenInfo.new(0.6), { Transparency = 0.8 }):Play()
				task.wait(0.6)
				TweenService:Create(b, TweenInfo.new(0.6), { Transparency = 0.45 }):Play()
				task.wait(0.6)
			end
		end)
	elseif not on and beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function show(on: boolean)
	reopen.Visible = on and dismissed
	if on and dismissed then
		on = false
	end
	if on == frame.Visible then
		return
	end
	frame.Visible = true
	local sc = frame:FindFirstChildOfClass("UIScale") :: UIScale
	if on then
		sc.Scale = 0.4
		Kit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		Kit.Tween(sc, 0.2, { Scale = 0.4 })
		task.delay(0.2, function()
			frame.Visible = false
		end)
	end
end

local function nearArena(): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - arenaPos).Magnitude < 150
end

local function onBoss(data: any)
	if data.Pos then
		arenaPos = data.Pos
	end
	if data.State == "Warning" then
		state = "Warning"
		dismissed = false -- every new event shows its bar again
		warnAt = data.At or 0
		Hud.Announce("⚠️ GIANT POLTERGEIST INCOMING!", Color3.fromRGB(255, 120, 230), Color3.fromRGB(255, 200, 60))
		Sound.Play("BossAppear")
		setBeacon(true)
		titleLabel.Text = "⚠️ GIANT POLTERGEIST"
		fill.Size = UDim2.fromScale(1, 1)
		spiritLabel.Text = "APPEARS SOON!"
		goButton.Visible = not nearArena()
		show(true)
	elseif data.State == "Active" then
		state = "Active"
		bossUid = data.Uid or 0
		endsAt = data.EndsAt or 0
		titleLabel.Text = "👑 GIANT POLTERGEIST"
		setBeacon(true)
		Sound.Boss(true)
		show(true)
		if nearArena() then
			Sound.Play("BossAppear")
			Effects.Flash(arenaPos + Vector3.new(0, 14, 0), Color3.fromRGB(255, 120, 230), 30, 0.7)
			Effects.Ring(arenaPos + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 230, 90), 40, 0.9)
			Effects.Burst(arenaPos + Vector3.new(0, 14, 0), { Color = Color3.fromRGB(255, 120, 230), Color2 = Color3.fromRGB(255, 230, 90), Count = 120, Size = 2.5, Speed = 40, Life = 1.2 })
			-- camera shake
			task.spawn(function()
				local cam = workspace.CurrentCamera
				local t0 = os.clock()
				while os.clock() - t0 < 0.6 and cam.CameraType ~= Enum.CameraType.Scriptable do
					local k = 0.6 * (1 - (os.clock() - t0) / 0.6)
					cam.CFrame *= CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
					RunService.RenderStepped:Wait()
				end
			end)
		end
	elseif data.State == "Defeated" then
		state = "Idle"
		dismissed = false
		Sound.Boss(false)
		setBeacon(false)
		show(false)
		Hud.Banner("GIANT POLTERGEIST DEFEATED!", "Grab the Ectoplasm shower!", Theme.Gold)
		if data.Pos and nearArena() then
			Effects.Poof(data.Pos, Color3.fromRGB(255, 120, 230), 4, true)
			Effects.Ring(arenaPos + Vector3.new(0, 0.4, 0), Theme.Ecto, 45, 1)
		end
	elseif data.State == "Escaped" then
		state = "Idle"
		dismissed = false
		Sound.Boss(false)
		setBeacon(false)
		show(false)
		Hud.Banner("IT ESCAPED...", "It'll be back. Bring more hunters!", Theme.Muted)
	end
end

function Boss.Init()
	local screen = Kit.Screen()
	frame = Kit.new("Frame", {
		Name = "BossBar",
		Size = UDim2.fromOffset(420, 62),
		Position = UDim2.new(0.5, 10, 0, 104),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	Kit.Corner(frame, UDim.new(0, 14))
	Kit.Stroke(frame, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(frame, Color3.fromRGB(110, 40, 120), Color3.fromRGB(50, 20, 70), 90)
	Kit.new("UIScale", { Parent = frame })
	titleLabel = Kit.Label(frame, "👑 GIANT POLTERGEIST", { Size = UDim2.new(0.68, 0, 0, 22), Position = UDim2.fromOffset(10, 4), Align = Enum.TextXAlignment.Left, Color = Theme.Gold, Style = "Heading", Fit = true, ZIndex = 31 })
	timerLabel = Kit.Label(frame, "", { Size = UDim2.new(0.3, 0, 0, 22), Position = UDim2.new(1, -10, 0, 4), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Style = "Body", Fit = true, ZIndex = 31 })
	local bar: Frame = Kit.new("Frame", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 31), BackgroundColor3 = Color3.fromRGB(30, 12, 45), ZIndex = 31, Parent = frame })
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	fill = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 32, Parent = bar })
	Kit.Corner(fill, UDim.new(1, 0))
	Kit.Gradient(fill, Color3.fromRGB(255, 120, 230), Color3.fromRGB(255, 220, 80), 0)
	spiritLabel = Kit.Label(bar, "", { Style = "Small", ZIndex = 33 })
	-- "take me there" helper: walks you nowhere, just points the way (see Tutorial arrow)
	goButton = Kit.Button(frame, {
		Text = "📍 SHOW ME",
		Color = "Pink",
		Size = UDim2.fromOffset(140, 40),
		TextStyle = "Small",
		Position = UDim2.new(0.5, 0, 1, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 31,
		OnClick = function()
			Boss.PointRequested:Fire()
		end,
	})
	goButton.Visible = false
	-- ✕ closes the event bar (the event keeps running; the boss's own label still shows)
	Kit.Button(frame, {
		Text = "✕",
		Color = "Red",
		Size = UDim2.fromOffset(30, 30),
		TextStyle = "Body",
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 34,
		OnClick = function()
			dismissed = true
			show(false)
		end,
	})
	-- small pill to bring it back while the event is still on
	reopen = Kit.Button(screen, {
		Text = "👑 EVENT",
		Color = "Pink",
		Size = UDim2.fromOffset(96, 30),
		TextStyle = "Small",
		Position = UDim2.new(0.5, 10, 0, 104),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 30,
		OnClick = function()
			dismissed = false
			show(true)
		end,
	})
	reopen.Visible = false
end

Boss.PointRequested = Signal.new()

function Boss.State(): (string, Vector3)
	return state, arenaPos
end

function Boss.Start()
	State.OnFx("Boss", onBoss)
	RunService.Heartbeat:Connect(function()
		if state == "Warning" then
			local left = math.max(0, warnAt - workspace:GetServerTimeNow())
			timerLabel.Text = Format.Time(left)
			goButton.Visible = not nearArena()
		elseif state == "Active" then
			local left = math.max(0, endsAt - workspace:GetServerTimeNow())
			timerLabel.Text = "⏱ " .. Format.Time(left)
			timerLabel.TextColor3 = if left < 20 then Theme.Bad else Theme.Text
			goButton.Visible = not nearArena()
			local e = Ghosts.Get(bossUid)
			if e then
				local frac = math.clamp(e.Spirit / math.max(e.Max, 1), 0, 1)
				fill.Size = UDim2.fromScale(math.max(frac, 0.01), 1)
				spiritLabel.Text = Format.Short(e.Spirit) .. " / " .. Format.Short(e.Max) .. " SPIRIT"
			end
		end
	end)
end

return Boss
