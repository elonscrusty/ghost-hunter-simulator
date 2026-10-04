--!strict
-- ENDLESS BOSS TOWER HUD. Everything here only shows what the server says (Fx "Tower",
-- Fx "TowerRoomCleared", player attributes InTower / TowerRoom); the buttons only send
-- "TowerStart"(startRoom), "TowerContinue" and "TowerLeave" requests, the server decides the rest.
--   * on the entrance pad: checkpoint info + ENTER (Room 1) / START AT ROOM n (checkpoint + 1)
--     buttons, then a countdown pill with the party size and start room;
--   * in a room: a top bar (ROOM n + boss name, timer, boss Spirit bar, earned this run) and a
--     LEAVE button (tap twice: leaving mid-fight ends your run, rewards you already got are kept);
--   * boss beaten: "BOSS DEFEATED! Rewards collected" banner with your payout, shard orbs pop
--     out of the chest and float to you, then shard icons fly to the top-bar shards counter
--     (presentation only: the server already credited everything);
--   * between rooms: CONTINUE (vote) and LEAVE with the time left and votes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local Effects = require(script.Parent.Effects)
local State = require(Client.State)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local TowerHud = {}

local player = Players.LocalPlayer
local PURPLE_A, PURPLE_B = Color3.fromRGB(80, 50, 140), Color3.fromRGB(40, 20, 70)

-- "Idle" | "Fight" | "Between"
local phase = "Idle"
local room = 0
local bossUid = 0
local endsAt = 0
local padEndsAt = 0 -- countdown on the pad (0 = none)
local padBase = ""
local leaveArmedUntil = 0
local votes, party = 0, 1
local voted = false
local devRun = false -- DEV test run: no rewards
local SHARD = Color3.fromRGB(200, 160, 255)

local bar: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local fill: Frame
local spiritLabel: TextLabel
local earnedLabel: TextLabel
local padPill: Frame
local padLabel: TextLabel
local enterButton: TextButton
local checkpointButton: TextButton
local padInfo: TextLabel
local padBox: Frame
local actions: Frame
local infoLabel: TextLabel
local continueButton: TextButton
local leaveButton: TextButton

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function setEarned(e: any)
	if devRun then
		earnedLabel.Text = "DEV RUN - no rewards"
	elseif type(e) == "table" then
		earnedLabel.Text = string.format("This run: +%s Ecto  ·  +%s Shards", Format.Short(tonumber(e.Ecto) or 0), Format.Commas(tonumber(e.Shards) or 0))
	end
end

local function bossModel(): Model?
	local folder = workspace:FindFirstChild("Ghosts")
	local m = folder and folder:FindFirstChild("Ghost_" .. bossUid)
	return if m and m:IsA("Model") then m else nil
end

local function refreshButtons()
	local inRun = phase ~= "Idle"
	bar.Visible = inRun
	actions.Visible = inRun
	continueButton.Visible = phase == "Between"
	if phase == "Between" then
		Kit.SetButtonText(continueButton, if voted then "✔ WAITING..." else "▶ CONTINUE")
	end
	Kit.SetButtonText(leaveButton, if os.clock() < leaveArmedUntil then "SURE? TAP AGAIN" else "🚪 LEAVE")
end

local function setPhase(p: string)
	phase = p
	if p ~= "Between" then
		voted = false
	end
	refreshButtons()
end

local function onTower(data: any)
	if type(data) ~= "table" then
		return
	end
	local s = data.State
	if s == "Pad" then
		padEndsAt = tonumber(data.EndsAt) or 0
		padBase = string.format("👻 BOSS TOWER  ·  party %d/%d  ·  Room %d", tonumber(data.Count) or 1, tonumber(data.Max) or Config.Tower.MaxParty, tonumber(data.StartRoom) or 1)
		padPill.Visible = true
	elseif s == "PadCancel" then
		padEndsAt = 0
		padPill.Visible = false
	elseif s == "Fight" then
		padEndsAt = 0
		padPill.Visible = false
		room = tonumber(data.Room) or room
		bossUid = tonumber(data.Uid) or 0
		endsAt = tonumber(data.EndsAt) or 0
		party = tonumber(data.Party) or party
		devRun = data.Dev == true
		titleLabel.Text = string.format("🏰 ROOM %d  ·  %s", room, tostring(data.Boss or "BOSS"))
		fill.Size = UDim2.fromScale(1, 1)
		setEarned(data.Earned)
		setPhase("Fight")
		Sound.Play("BossAppear")
		Hud.Banner("ROOM " .. room, "Tap the boss to attack it!", Theme.Ecto)
	elseif s == "Votes" then
		votes = tonumber(data.Votes) or 0
		party = tonumber(data.Party) or party
	elseif s == "Ended" then
		setPhase("Idle")
		bossUid = 0
		local e = data.Earned
		local sub = tostring(data.Reason or "")
		if devRun then
			sub ..= "\nDEV RUN - no rewards"
		elseif type(e) == "table" then
			sub ..= string.format("\nBest room: %d  ·  +%s Ecto  ·  +%s Shards", tonumber(data.Best) or 0, Format.Short(tonumber(e.Ecto) or 0), Format.Commas(tonumber(e.Shards) or 0))
		end
		Hud.Banner("TOWER RUN OVER", sub, Theme.Gold)
		devRun = false
	end
end

-- UI: a few shard icons fly from the middle of the screen (your character) to the top-bar
-- shards counter; a small "+N" under it ticks up as each one lands. Presentation only.
local function flyToCounter(icons: number, total: number)
	local pill = Hud.ShardsPill
	local gui = pill and pill:FindFirstAncestorOfClass("ScreenGui")
	if not pill or not gui or icons <= 0 then
		return
	end
	local target: Frame = pill
	local sc = gui:FindFirstChildOfClass("UIScale")
	local k = if sc and sc.Scale > 0 then sc.Scale else 1
	local tick = Kit.Label(target, "+0", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, 4), Color = SHARD, Style = "Body", ZIndex = 6 })
	local shown = 0
	for i = 1, icons do
		task.delay((i - 1) * 0.12, function()
			if not target.Parent then
				return
			end
			local from = (gui.AbsoluteSize * Vector2.new(0.5, 0.55)) / k
			local to = (target.AbsolutePosition + target.AbsoluteSize / 2 - gui.AbsolutePosition) / k
			local icon = Kit.Icon(gui, "shards", "🔮", { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Icon", TextSize = 26, Stroke = 0, ZIndex = 40 })
			icon.Position = UDim2.fromOffset(from.X + (math.random() - 0.5) * 60, from.Y + (math.random() - 0.5) * 30)
			Kit.Tween(icon, 0.65, { Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.65, function()
				icon:Destroy()
				shown = if i == icons then total else math.min(total, shown + math.max(1, math.floor(total / icons)))
				tick.Text = "+" .. Format.Commas(shown)
				local ps = target:FindFirstChildOfClass("UIScale")
				if ps then
					ps.Scale = 1.06
					Kit.Tween(ps, 0.2, { Scale = 1 })
				end
				if i == icons then
					task.delay(1.2, function()
						Kit.Tween(tick, 0.4, { TextTransparency = 1 })
						task.delay(0.45, function()
							tick:Destroy()
						end)
					end)
				end
			end)
		end)
	end
end

-- World: soft shard orbs pop out of the opened chest, hover, then float to your character.
-- `done` runs once the last orb arrived.
local function chestOrbs(chestPos: Vector3, count: number, done: () -> ())
	local orbs = {}
	for i = 1, count do
		local o = Instance.new("Part")
		o.Shape = Enum.PartType.Ball
		o.Size = Vector3.new(0.9, 0.9, 0.9)
		o.Material = Enum.Material.Neon
		o.Color = SHARD
		o.Anchored = true
		o.CanCollide = false
		o.CanQuery = false
		o.CanTouch = false
		o.CastShadow = false
		o.Transparency = 1
		o.CFrame = CFrame.new(chestPos)
		o.Parent = Effects.Folder()
		local a = (i / count) * math.pi * 2
		table.insert(orbs, { Part = o, Apex = chestPos + Vector3.new(math.cos(a) * 2.5, 6 + math.random() * 2, math.sin(a) * 2.5), Delay = (i - 1) * 0.08 })
	end
	local t0 = os.clock()
	local POP, HOVER, FLY = 0.5, 0.35, 0.8
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local now = os.clock() - t0
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local home = if root then root.Position else chestPos
		local alive = 0
		for _, o in orbs do
			local p = o.Part
			if not p.Parent then
				continue
			end
			local t = now - o.Delay
			if t < 0 then
				alive += 1
				continue
			end
			p.Transparency = 0.15
			if t < POP then
				local u = 1 - (1 - t / POP) ^ 2
				p.CFrame = CFrame.new(chestPos:Lerp(o.Apex, u))
			elseif t < POP + HOVER then
				p.CFrame = CFrame.new(o.Apex + Vector3.new(0, math.sin((t - POP) * 8) * 0.25, 0))
			elseif t < POP + HOVER + FLY then
				local u = ((t - POP - HOVER) / FLY) ^ 2
				p.CFrame = CFrame.new(o.Apex:Lerp(home, u))
			else
				Effects.Burst(home, { Color = SHARD, Count = 4, Size = 0.4, Speed = 4, Life = 0.4 })
				p:Destroy()
				continue
			end
			alive += 1
		end
		if alive == 0 and conn then
			conn:Disconnect()
			conn = nil
			done()
		end
	end)
end

local function onCleared(data: any)
	if type(data) ~= "table" then
		return
	end
	room = tonumber(data.Room) or room
	endsAt = tonumber(data.EndsAt) or 0
	party = tonumber(data.Party) or party
	votes = 0
	bossUid = 0
	setEarned(data.Earned)
	titleLabel.Text = string.format("🏆 ROOM %d CLEARED!", room)
	fill.Size = UDim2.fromScale(0.01, 1)
	spiritLabel.Text = if devRun then "DEV RUN - no rewards" else "Rewards collected!"
	setPhase("Between")
	Sound.Play("ZoneUnlock")
	local ecto, shards = tonumber(data.Ecto) or 0, tonumber(data.Shards) or 0
	local pct = math.floor((tonumber(data.Pct) or 0) * 100 + 0.5)
	local sub
	if devRun then
		sub = "DEV RUN - no rewards"
	elseif ecto > 0 or shards > 0 then
		sub = string.format("+%s 🔮 Spirit Shards  +%s 💚 Ectoplasm  (you did %d%% of the damage)", Format.Commas(shards), Format.Commas(ecto), pct)
	else
		sub = "You didn't hit this boss, so no share this time. Attack it to earn rewards!"
	end
	Hud.Banner("BOSS DEFEATED! Rewards collected", sub, Theme.Gold)
	local cp = tonumber(data.Checkpoint)
	if cp and cp > 0 then
		Kit.Toast(string.format("🚩 Checkpoint saved! Your next run can start at Room %d", cp + 1), "Good")
	end
	-- the chest lid opens ~0.8 s after the kill (server); orbs pop out right after
	local pos = data.Pos
	if shards > 0 and typeof(pos) == "Vector3" then
		local icons = math.clamp(math.ceil(shards / 5), 3, 8)
		task.delay(1, function()
			chestOrbs(pos + Vector3.new(0, 2.5, 0), icons, function()
				flyToCounter(icons, shards)
			end)
		end)
	end
end

local function onLeave()
	if os.clock() >= leaveArmedUntil then
		leaveArmedUntil = os.clock() + 3
		refreshButtons()
		return
	end
	leaveArmedUntil = 0
	local res = State.Request("TowerLeave")
	if not res.ok and res.err then
		Kit.Toast(res.err, "Bad")
	end
	refreshButtons()
end

local function onContinue()
	if voted then
		return
	end
	local res = State.Request("TowerContinue")
	if res.ok then
		voted = true
	elseif res.err then
		Kit.Toast(res.err, "Bad")
	end
	refreshButtons()
end

local function checkpointOf(): number
	local d = State.Data
	return if d then tonumber(d.TowerCheckpoint) or 0 else 0
end

local function onEnter(startRoom: number)
	local res = State.Request("TowerStart", startRoom)
	if not res.ok and res.err then
		Kit.Toast(res.err, "Bad")
	end
end

function TowerHud.Init()
	local screen = Kit.Screen()
	local stack = Hud.TopStack

	-- top bar (room, timer, boss Spirit, earned this run)
	bar = Kit.new("Frame", {
		Name = "TowerBar",
		Size = UDim2.fromOffset(420, 84),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 30,
		LayoutOrder = 2,
		Parent = stack or screen,
	})
	if not stack then
		bar.Position = UDim2.new(0.5, 0, 0, 60)
		bar.AnchorPoint = Vector2.new(0.5, 0)
	end
	Kit.Corner(bar, UDim.new(0, 14))
	Kit.Stroke(bar, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(bar, PURPLE_A, PURPLE_B, 90)
	titleLabel = Kit.Label(bar, "🏰 ROOM 1", { Size = UDim2.new(0.7, 0, 0, 22), Position = UDim2.fromOffset(10, 4), Align = Enum.TextXAlignment.Left, Color = Theme.Ecto, Style = "Heading", Fit = true, ZIndex = 31 })
	timerLabel = Kit.Label(bar, "", { Size = UDim2.new(0.28, 0, 0, 22), Position = UDim2.new(1, -10, 0, 4), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Style = "Body", Fit = true, ZIndex = 31 })
	local track: Frame = Kit.new("Frame", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 31), BackgroundColor3 = Color3.fromRGB(30, 12, 45), ZIndex = 31, Parent = bar })
	Kit.Corner(track, UDim.new(1, 0))
	Kit.Stroke(track, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	fill = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 32, Parent = track })
	Kit.Corner(fill, UDim.new(1, 0))
	Kit.Gradient(fill, Color3.fromRGB(110, 255, 160), Color3.fromRGB(170, 120, 255), 0)
	spiritLabel = Kit.Label(track, "", { Style = "Small", ZIndex = 33 })
	earnedLabel = Kit.Label(bar, "This run: +0 Ecto  ·  +0 Shards", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 60), Style = "Small", Color = Theme.Gold, Fit = true, ZIndex = 31 })

	-- pad countdown pill
	padPill = Kit.new("Frame", {
		Name = "TowerPadPill",
		Size = UDim2.fromOffset(320, 34),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 30,
		LayoutOrder = 2,
		Parent = stack or screen,
	})
	if not stack then
		padPill.Position = UDim2.new(0.5, 0, 0, 60)
		padPill.AnchorPoint = Vector2.new(0.5, 0)
	end
	Kit.Corner(padPill, UDim.new(1, 0))
	Kit.Stroke(padPill, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(padPill, PURPLE_A, PURPLE_B, 90)
	padLabel = Kit.Label(padPill, "", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Style = "Body", Fit = true, ZIndex = 31 })

	-- bottom-centre: checkpoint info + ENTER / START AT CHECKPOINT (on the pad) and the run actions
	padBox = Kit.new("Frame", {
		Name = "TowerPadBox",
		Size = UDim2.fromOffset(480, 78),
		Position = UDim2.new(0.5, 0, 1, -96),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 25,
		Parent = screen,
	})
	padInfo = Kit.Label(padBox, "", { Size = UDim2.new(1, 0, 0, 22), Style = "Small", Color = Theme.Gold, Fit = true, ZIndex = 26 })
	enterButton = Kit.Button(padBox, {
		Text = "🏰 ENTER BOSS TOWER",
		Color = "Purple",
		Size = UDim2.fromOffset(230, 48),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 26,
		OnClick = function()
			onEnter(1)
		end,
	})
	checkpointButton = Kit.Button(padBox, {
		Text = "⏩ START AT ROOM 6",
		Color = "Green",
		Size = UDim2.fromOffset(230, 48),
		Position = UDim2.new(0.5, 6, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 26,
		OnClick = function()
			onEnter(checkpointOf() + 1)
		end,
	})
	checkpointButton.Visible = false
	actions = Kit.new("Frame", {
		Name = "TowerActions",
		Size = UDim2.fromOffset(340, 82),
		Position = UDim2.new(0.5, 0, 1, -90),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 25,
		Parent = screen,
	})
	infoLabel = Kit.Label(actions, "", { Size = UDim2.new(1, 0, 0, 22), Style = "Body", Fit = true, ZIndex = 26 })
	continueButton = Kit.Button(actions, {
		Text = "▶ CONTINUE",
		Color = "Green",
		Size = UDim2.fromOffset(160, 48),
		Position = UDim2.new(0.5, -6, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 26,
		OnClick = onContinue,
	})
	leaveButton = Kit.Button(actions, {
		Text = "🚪 LEAVE",
		Color = "Red",
		Size = UDim2.fromOffset(160, 48),
		Position = UDim2.new(0.5, 6, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 26,
		OnClick = onLeave,
	})
	continueButton.Visible = false
end

local padPart: BasePart? = nil
local function findPad(): BasePart?
	if padPart and padPart.Parent then
		return padPart
	end
	local map = workspace:FindFirstChild("Map")
	local plaza = map and map:FindFirstChild("TowerEntrance")
	local pad = plaza and plaza:FindFirstChild("TowerPad")
	padPart = if pad and pad:IsA("BasePart") then pad else nil
	return padPart
end

local function onPad(): boolean
	local pad = findPad()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pad or not root then
		return false
	end
	local d = root.Position - pad.Position
	return math.abs(d.Y) < 10 and Vector3.new(d.X, 0, d.Z).Magnitude <= Config.Tower.PadRadius
end

function TowerHud.Start()
	State.OnFx("Tower", onTower)
	State.OnFx("TowerRoomCleared", onCleared)
	-- the server clears InTower when a run ends for us (also on respawn / errors)
	player:GetAttributeChangedSignal("InTower"):Connect(function()
		if player:GetAttribute("InTower") ~= true and phase ~= "Idle" then
			setPhase("Idle")
		end
	end)

	local nextPadCheck = 0
	RunService.Heartbeat:Connect(function()
		local t = serverNow()
		local clock = os.clock()
		-- pad: ENTER button / countdown
		if clock >= nextPadCheck then
			nextPadCheck = clock + 0.25
			local inTower = player:GetAttribute("InTower") == true
			local here = not inTower and onPad()
			padBox.Visible = here and padEndsAt == 0
			if padBox.Visible then
				local cp = checkpointOf()
				local every = Config.Tower.CheckpointEvery
				checkpointButton.Visible = cp > 0
				enterButton.Position = if cp > 0 then UDim2.new(0.5, -6, 1, 0) else UDim2.new(0.5, 0, 1, 0)
				enterButton.AnchorPoint = if cp > 0 then Vector2.new(1, 1) else Vector2.new(0.5, 1)
				Kit.SetButtonText(enterButton, if cp > 0 then "▶ START AT ROOM 1" else "🏰 ENTER BOSS TOWER")
				Kit.SetButtonText(checkpointButton, "⏩ START AT ROOM " .. (cp + 1))
				padInfo.Text = if cp > 0
					then string.format("🚩 Checkpoint: Room %d cleared  ·  skipped rooms give no rewards", cp)
					else string.format("🚩 Clear Room %d to save a checkpoint", every)
			end
			if padEndsAt > 0 and (inTower or t > padEndsAt + 3) then
				padEndsAt = 0
				padPill.Visible = false
			end
			if leaveArmedUntil > 0 and clock >= leaveArmedUntil then
				leaveArmedUntil = 0
				refreshButtons()
			end
		end
		if padEndsAt > 0 then
			local left = math.max(0, math.ceil(padEndsAt - t))
			padLabel.Text = padBase .. "  ·  starts in " .. left
		end
		if phase == "Fight" then
			local left = math.max(0, endsAt - t)
			timerLabel.Text = "⏱ " .. Format.Time(left)
			timerLabel.TextColor3 = if left < 20 then Theme.Bad else Theme.Text
			local m = bossModel()
			if m then
				local hp = tonumber(m:GetAttribute("Spirit")) or 0
				local max = math.max(tonumber(m:GetAttribute("MaxSpirit")) or 1, 1)
				fill.Size = UDim2.fromScale(math.clamp(hp / max, 0.01, 1), 1)
				spiritLabel.Text = Format.Short(hp) .. " / " .. Format.Short(max) .. " SPIRIT"
			end
			infoLabel.Text = if party > 1 then string.format("Party of %d  ·  beat the boss before time runs out!", party) else "Beat the boss before time runs out!"
		elseif phase == "Between" then
			local left = math.max(0, endsAt - t)
			timerLabel.Text = "⏱ " .. Format.Time(left)
			timerLabel.TextColor3 = Theme.Text
			infoLabel.Text = if party > 1
				then string.format("Room %d next in %s  ·  votes %d/%d", room + 1, Format.Time(left), votes, party)
				else string.format("Room %d next? %s left to choose", room + 1, Format.Time(left))
		end
	end)
end

return TowerHud
