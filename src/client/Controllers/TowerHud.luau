--!strict
-- ENDLESS BOSS TOWER HUD. Everything here only shows what the server says (Fx "Tower",
-- Fx "TowerRoomCleared", player attributes InTower / TowerRoom); the buttons only send
-- "TowerStart", "TowerContinue" and "TowerLeave" requests, the server decides the rest.
--   * on the entrance pad: ENTER BOSS TOWER button, then a countdown pill with the party size;
--   * in a room: a top bar (ROOM n + boss name, timer, boss Spirit bar, earned this run) like
--     the Giant Poltergeist bar, and a LEAVE button (tap twice: leaving mid-fight ends your run,
--     rewards you already got are kept);
--   * between rooms: CONTINUE (vote) and LEAVE with the time left and votes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
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

local bar: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local fill: Frame
local spiritLabel: TextLabel
local earnedLabel: TextLabel
local padPill: Frame
local padLabel: TextLabel
local enterButton: TextButton
local actions: Frame
local infoLabel: TextLabel
local continueButton: TextButton
local leaveButton: TextButton

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function setEarned(e: any)
	if type(e) == "table" then
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
		padBase = string.format("👻 BOSS TOWER  ·  party %d/%d", tonumber(data.Count) or 1, tonumber(data.Max) or Config.Tower.MaxParty)
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
		if type(e) == "table" then
			sub ..= string.format("\nBest room: %d  ·  +%s Ecto  ·  +%s Shards", tonumber(data.Best) or 0, Format.Short(tonumber(e.Ecto) or 0), Format.Commas(tonumber(e.Shards) or 0))
		end
		Hud.Banner("TOWER RUN OVER", sub, Theme.Gold)
	end
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
	spiritLabel.Text = "Chest opened!"
	setPhase("Between")
	Sound.Play("ZoneUnlock")
	local ecto, shards = tonumber(data.Ecto) or 0, tonumber(data.Shards) or 0
	local sub = if ecto > 0 or shards > 0 then string.format("+%s Ecto  ·  +%s Spirit Shards", Format.Commas(ecto), Format.Commas(shards)) else "Deal damage to the boss to earn a share!"
	Hud.Banner("ROOM " .. room .. " CLEARED!", sub, Theme.Gold)
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

local function onEnter()
	local res = State.Request("TowerStart")
	if not res.ok and res.err then
		Kit.Toast(res.err, "Bad")
	end
end

function TowerHud.Init()
	local screen = Kit.Screen()
	local stack = Hud.TopStack

	-- top bar (same look as the Giant Poltergeist bar)
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

	-- bottom-centre: ENTER (on the pad) and the run actions
	enterButton = Kit.Button(screen, {
		Text = "🏰 ENTER BOSS TOWER",
		Color = "Purple",
		Size = UDim2.fromOffset(230, 48),
		Position = UDim2.new(0.5, 0, 1, -96),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 25,
		OnClick = onEnter,
	})
	enterButton.Visible = false
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
	local plaza = map and map:FindFirstChild("EventArena")
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
			enterButton.Visible = here and padEndsAt == 0
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
