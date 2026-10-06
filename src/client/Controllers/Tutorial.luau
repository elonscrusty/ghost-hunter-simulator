--!strict
-- First-time guidance without walls of text:
--   1 TAP A GHOST!  →  2 COLLECT ECTOPLASM!  →  3 OPEN A HUNTER CRATE!  →
--   4 EQUIP YOUR NEW HUNTER!  →  5 UNLOCK THE CEMETERY!  →  done  →  MENU TOUR (MenuTour)
-- A glowing breadcrumb trail on the ground + a bouncing arrow over the target show where to
-- go; menu buttons pulse when they're the next step. After the tutorial a small NEXT GOAL
-- chip keeps the next zone in view. Progress is saved (server only accepts forward steps).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local WorldLabel = require(Client.UI.WorldLabel)
local Hud = require(script.Parent.Hud)
local Ghosts = require(script.Parent.Ghosts)
local Orbs = require(script.Parent.Orbs)
local Reveal = require(script.Parent.Reveal)
local CratePanel = require(script.Parent.CratePanel)
local HuntersPanel = require(script.Parent.HuntersPanel)
local Sound = require(script.Parent.Sound)
local MenuTour = require(script.Parent.MenuTour)

local Tutorial = {}

local player = Players.LocalPlayer
local STEPS = #Config.Tutorial.Steps
local step = 0 -- 0 = not loaded yet
local promptFrame: Frame
local promptLabel: TextLabel
local promptSub: TextLabel
local goalChip: Frame
local goalLabel: TextLabel
local goalFill: Frame
local dots: { BasePart } = {}
local marker: BillboardGui
local markerPart: Part
local guideTarget: (() -> Vector3?)? = nil
local guideUntil = math.huge
local framed = false

local DOTS = 12
local SPACING = 3.6

--------------------------------------------------------------------------------
-- guide (breadcrumbs + marker)
--------------------------------------------------------------------------------
local function setGuide(fn: (() -> Vector3?)?, seconds: number?)
	guideTarget = fn
	guideUntil = if seconds then os.clock() + seconds else math.huge
end
Tutorial.SetGuide = setGuide

local function rootPart(): BasePart?
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local hidden = CFrame.new(0, -400, 0)
local dotsHidden = true
local parts: { BasePart } = {}
local cfs: { CFrame } = {}

local function hideDots()
	if dotsHidden then
		return -- nothing to do: no per-frame writes while the guide is off
	end
	dotsHidden = true
	for _, d in dots do
		d.CFrame = hidden
	end
end

local function updateGuide()
	local root = rootPart()
	local target = if guideTarget and os.clock() < guideUntil then guideTarget() else nil
	if not root or not target or Reveal.IsPlaying() then
		hideDots()
		if marker.Enabled then
			marker.Enabled = false
		end
		return
	end
	markerPart.CFrame = CFrame.new(target)
	marker.Enabled = true
	local from = root.Position - Vector3.new(0, 2.7, 0)
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 6 then
		hideDots()
		return
	end
	dotsHidden = false
	local dir = flat.Unit
	local t = os.clock()
	local offset = (t * 6) % SPACING -- dots flow toward the target
	local groundEnd = math.min(target.Y, from.Y + 2)
	table.clear(parts)
	table.clear(cfs)
	for i, d in dots do
		local along = 2.5 + (i - 1) * SPACING + offset
		if along > dist - 2 then
			table.insert(parts, d)
			table.insert(cfs, hidden)
		else
			local k = along / dist
			local y = from.Y + (groundEnd - from.Y) * k + 0.35
			local pulse = 0.75 + 0.25 * math.sin(t * 6 - i * 0.6)
			d.Size = Vector3.new(pulse, pulse, pulse)
			table.insert(parts, d)
			table.insert(cfs, CFrame.new(from.X + dir.X * along, y, from.Z + dir.Z * along))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

--------------------------------------------------------------------------------
-- prompts
--------------------------------------------------------------------------------
local shownText = ""
local function setPrompt(text: string?, sub: string?)
	if not text then
		if promptFrame.Visible then
			promptFrame.Visible = false
			shownText = ""
		end
		return
	end
	promptSub.Text = sub or ""
	promptSub.Visible = sub ~= nil
	if text ~= shownText then
		shownText = text
		promptLabel.Text = text
		promptFrame.Visible = true
		local sc = promptFrame:FindFirstChildOfClass("UIScale") :: UIScale
		sc.Scale = 0.5
		Kit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		Sound.Play("Select")
	end
end

local function tapWord(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Gamepad1 then
		return "PRESS (X) TO TARGET A GHOST!"
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "TAP A GHOST!"
	end
	return "CLICK A GHOST!"
end

local function nearestGhost(): Vector3?
	local root = rootPart()
	if not root then
		return nil
	end
	local d = State.Data
	local best, bestD = nil, math.huge
	for _, e in Ghosts.All() do
		if e.Def.Kind ~= "Event" and (not d or d.Zones[e.Def.Zone]) then
			local dist = (e.Pos - root.Position).Magnitude
			if dist < bestD then
				best, bestD = e, dist
			end
		end
	end
	return if best then best.Pos + Vector3.new(0, 2.5 * best.Def.Scale + 1, 0) else nil
end

local function cratePos(): Vector3?
	local p = Config.Layout.CrateStations.Beginner
	return p + Vector3.new(0, 8, 0)
end

local function gatePos(): Vector3?
	local g = Config.Layout.Gates.Cemetery
	return if g then Vector3.new(0, 10, g.Z - 4) else nil
end

-- Boss Tower intro goal (after the tutorial): grants nothing, just points the way once the
-- player is strong enough. Hidden for good after their first tower run.
local TOWER_GUIDE_SECONDS = 15
local TOWER_CYCLE = 30 -- the chip shows the tower for the first TOWER_SHOW s of each cycle
local TOWER_SHOW = 10
local towerPointed = false

local function towerPos(): Vector3?
	return Config.Layout.TowerEntrance.Pad + Vector3.new(0, 8, 0) -- the party pad in the lobby
end

local function wantsTowerGoal(d: any): boolean
	if (tonumber(d.TowerRuns) or 0) > 0 then
		return false
	end
	local school = Config.Zones[3]
	return (school ~= nil and d.Zones[school.Id] == true) or State.CountOwned() >= 6
end

local function advance(to: number, skipped: boolean?)
	if to <= step then
		return
	end
	step = to
	task.spawn(State.Request, "Tutorial", to)
	if to > STEPS then
		setPrompt(nil)
		setGuide(nil)
		Hud.Pulse("Hunters", false)
		Hud.Banner("TUTORIAL COMPLETE!", "Keep hunting, collecting and unlocking!", Theme.Gold)
		if not skipped then
			MenuTour.AfterTutorial() -- then a quick tour of the menu buttons (SKIP leaves it out)
		end
	end
end

-- Pulsing ring on a button inside a menu: while a menu is open the guidance lives on the
-- button itself (a prompt pill would sit under/over the menu).
local rings: { [GuiObject]: Frame } = {}
local function pulseRing(b: GuiObject, on: boolean)
	local existing = rings[b]
	if on and not existing then
		local ring: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 80, Parent = b })
		Kit.Corner(ring, UDim.new(0, 12))
		local st = Kit.Stroke(ring, 4, Theme.Ecto, Enum.ApplyStrokeMode.Border)
		rings[b] = ring
		task.spawn(function()
			while ring.Parent do
				ring.Size = UDim2.fromScale(1, 1)
				st.Transparency = 0
				Kit.Tween(ring, 0.8, { Size = UDim2.new(1, 20, 1, 20) })
				Kit.Tween(st, 0.8, { Transparency = 1 })
				task.wait(0.9)
			end
		end)
	elseif not on and existing then
		existing:Destroy()
		rings[b] = nil
	end
end

local function setEquipRing(on: boolean)
	pulseRing(HuntersPanel.EquipBestButton(), on)
end

-- One-time camera framing of the nearest ghost for brand-new players.
local function frameGhost()
	if framed then
		return
	end
	framed = true
	local root = rootPart()
	local target = nearestGhost()
	local cam = workspace.CurrentCamera
	if not root or not target or not cam then
		return
	end
	local start = cam.CFrame
	local eye = root.Position + Vector3.new(0, 5, 0) - (target - root.Position).Unit * 10
	local look = CFrame.lookAt(eye, target)
	cam.CameraType = Enum.CameraType.Scriptable
	local tw = TweenService:Create(cam, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { CFrame = look })
	tw:Play()
	tw.Completed:Wait()
	task.wait(0.8)
	local back = TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = start })
	back:Play()
	back.Completed:Wait()
	if not Reveal.IsPlaying() then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local collectedOnce = false

local function tick()
	local d = State.Data
	if not d or step == 0 then
		return
	end
	local panel = Kit.CurrentPanel()
	if step > STEPS then
		-- NEXT GOAL chip
		local nextZone: Config.ZoneDef? = nil
		for _, z in Config.Zones do
			if not d.Zones[z.Id] then
				nextZone = z
				break
			end
		end
		local calm = not panel and not Reveal.IsPlaying()
		if calm and wantsTowerGoal(d) and (not towerPointed or os.clock() % TOWER_CYCLE < TOWER_SHOW) then
			goalChip.Visible = true
			goalLabel.Text = "TRY THE BOSS TOWER (east of spawn)!"
			goalFill.Size = UDim2.fromScale(1, 1)
			if not towerPointed then
				-- point the trail at it once per session; it then fades on its own
				towerPointed = true
				setGuide(towerPos, TOWER_GUIDE_SECONDS)
			end
		elseif nextZone and calm and nextZone.Id == Config.Layout.Portals.ToWorld2.Zone and not (d.BossesBeaten and d.BossesBeaten[Config.Layout.Portals.ToWorld2.Boss]) then
			-- World 2's portal first needs THE GHOST KING beaten
			goalChip.Visible = true
			goalLabel.Text = "NEXT: DEFEAT " .. Config.Ghosts[Config.Layout.Portals.ToWorld2.Boss].Name .. " TO OPEN WORLD 2"
			goalFill.Size = UDim2.fromScale(0.02, 1)
		elseif nextZone and calm then
			goalChip.Visible = true
			goalLabel.Text = "NEXT: UNLOCK " .. nextZone.Name .. "  " .. Format.Short(math.min(d.Ecto, nextZone.Cost)) .. " / " .. Format.Short(nextZone.Cost)
			goalFill.Size = UDim2.fromScale(math.clamp(d.Ecto / nextZone.Cost, 0.02, 1), 1)
		elseif not nextZone and calm then
			-- every area open: the goal becomes the full Hunter Index
			local total, found = 0, 0
			for id, h in Config.Hunters do
				if h.Rarity == "Exclusive" then
					continue -- Robux-only hunters are never a required goal
				end
				total += 1
				if d.Discovered[id] then
					found += 1
				end
			end
			goalChip.Visible = found < total
			goalLabel.Text = "NEXT: DISCOVER EVERY HUNTER  " .. found .. " / " .. total
			goalFill.Size = UDim2.fromScale(math.clamp(found / math.max(total, 1), 0.02, 1), 1)
		else
			goalChip.Visible = false
		end
		return
	end
	goalChip.Visible = false
	if Reveal.IsPlaying() or (panel ~= nil and panel ~= "Crate" and panel ~= "Hunters") then
		setPrompt(nil)
		return
	end
	local target = (player:GetAttribute("Target") :: number?) or 0
	if step == 1 then
		setPrompt(tapWord(), "to send your hunters!")
		setGuide(nearestGhost)
		if target ~= 0 then
			advance(2)
		end
	elseif step == 2 then
		if Orbs.Count() > 0 then
			setPrompt("COLLECT ECTOPLASM!", "Walk close - it flies to you!")
			setGuide(function()
				local root = rootPart()
				return if root then Orbs.Nearest(root.Position) else nil
			end)
		elseif target ~= 0 then
			setPrompt("YOUR HUNTER IS ON IT!", "Ghosts POOF into Ectoplasm")
			setGuide(nil)
		else
			setPrompt(tapWord())
			setGuide(nearestGhost)
		end
		if collectedOnce then
			advance(3)
		end
	elseif step == 3 then
		local price = Config.Crates.Beginner.Price
		if (d.Stats.Crates or 0) >= 1 then
			pulseRing(CratePanel.Button(), false)
			advance(4)
		elseif d.Ecto >= price or (d.FreeCrates.Beginner or 0) > 0 then
			if CratePanel.IsOpen() then
				setPrompt(nil)
				pulseRing(CratePanel.Button(), true)
				setGuide(nil)
			else
				pulseRing(CratePanel.Button(), false)
				setPrompt("OPEN A HUNTER CRATE!", "Follow the trail to the crate")
				setGuide(cratePos)
			end
		else
			setPrompt("COLLECT " .. price .. " ECTOPLASM", Format.Commas(d.Ecto) .. " / " .. price .. "  -  tap more ghosts!")
			setGuide(if target == 0 then nearestGhost else nil)
		end
	elseif step == 4 then
		-- done once a second hunter is equipped (or all you own, if you released the new one)
		if #d.Equipped >= math.min(2, State.CountOwned()) then
			Hud.Pulse("Hunters", false)
			setEquipRing(false)
			advance(5)
		elseif panel == "Hunters" then
			setPrompt(nil)
			Hud.Pulse("Hunters", false)
			setEquipRing(true)
		else
			setPrompt("EQUIP YOUR NEW HUNTER!", "Open HUNTERS")
			Hud.Pulse("Hunters", true)
			setEquipRing(false)
		end
		setGuide(nil)
	elseif step == 5 then
		local zone = Config.ZoneById.Cemetery
		if d.Zones.Cemetery then
			advance(6)
		elseif panel then
			setPrompt(nil)
		elseif d.Ecto >= zone.Cost then
			setPrompt("UNLOCK THE CEMETERY!", "Follow the trail to the gate")
			setGuide(gatePos)
		else
			setPrompt("UNLOCK THE CEMETERY!", "Defeat ghosts to save up - " .. Format.Commas(d.Ecto) .. " / " .. Format.Commas(zone.Cost))
			setGuide(nil)
		end
	end
end

function Tutorial.Init()
	local screen = Kit.Screen()
	-- compact pill low in the middle of the screen (between the thumbstick and jump button)
	promptFrame = Kit.new("Frame", {
		Name = "TutorialPrompt",
		Size = UDim2.fromOffset(400, 58),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 40,
		Parent = screen,
	})
	Kit.Corner(promptFrame, UDim.new(0, 14))
	Kit.new("UIScale", { Parent = promptFrame })
	promptLabel = Kit.Label(promptFrame, "", { Size = UDim2.new(1, -70, 0, 28), Position = UDim2.fromOffset(12, 4), Color = Theme.Ecto, Style = "Heading", Fit = true, ZIndex = 41 })
	promptSub = Kit.Label(promptFrame, "", { Size = UDim2.new(1, -70, 0, 20), Position = UDim2.fromOffset(12, 32), Color = Theme.Text, Style = "Small", Fit = true, ZIndex = 41 })
	Kit.Button(promptFrame, {
		Text = "SKIP",
		Color = "Gray",
		Size = UDim2.fromOffset(58, 40),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextStyle = "Tiny",
		ZIndex = 42,
		OnClick = function()
			advance(STEPS + 1, true)
		end,
	})
	-- pulse the prompt gently
	task.spawn(function()
		local sc = promptFrame:FindFirstChildOfClass("UIScale") :: UIScale
		while true do
			if promptFrame.Visible then
				Kit.Tween(sc, 0.5, { Scale = 1.04 }, Enum.EasingStyle.Sine)
				task.wait(0.5)
				Kit.Tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Sine)
			end
			task.wait(0.5)
		end
	end)
	-- NEXT GOAL bar: directly under the Ectoplasm / Power counters (Hud.TopStack)
	goalChip = Kit.new("Frame", {
		Size = UDim2.fromOffset(360, 24),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2,
		Visible = false,
		ZIndex = 20,
		LayoutOrder = 1,
		Parent = Hud.TopStack or screen,
	})
	Kit.Corner(goalChip, UDim.new(1, 0))
	Kit.Stroke(goalChip, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	goalFill = Kit.new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Theme.Ecto, BackgroundTransparency = 0.55, ZIndex = 21, Parent = goalChip })
	Kit.Corner(goalFill, UDim.new(1, 0))
	goalLabel = Kit.Label(goalChip, "", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Style = "Small", Fit = true, ZIndex = 22 })

	-- breadcrumbs + marker
	local folder = Instance.new("Folder")
	folder.Name = "GHGuide"
	folder.Parent = workspace
	for _ = 1, DOTS do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.9, 0.9, 0.9)
		p.Material = Enum.Material.Neon
		p.Color = Theme.Ecto
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = hidden
		p.Parent = folder
		table.insert(dots, p)
	end
	markerPart = Instance.new("Part")
	markerPart.Anchored = true
	markerPart.CanCollide = false
	markerPart.CanQuery = false
	markerPart.CanTouch = false
	markerPart.Transparency = 1
	markerPart.Size = Vector3.new(1, 1, 1)
	markerPart.CFrame = hidden
	markerPart.Parent = folder
	-- device-scaled bouncing arrow over the target (always readable, never huge)
	marker = WorldLabel.New({
		Name = "GuideArrow",
		Adornee = markerPart,
		Parent = folder,
		Size = Vector2.new(Theme.World.Marker, Theme.World.Marker),
		Offset = Vector3.new(0, 2.5, 0),
		MaxDistance = 600,
		AlwaysOnTop = true,
	})
	marker.Enabled = false
	local arrow = WorldLabel.Text(marker, "⬇", { Color = Theme.Ecto, Style = "Banner", Stroke = 3 })
	task.spawn(function()
		while true do
			Kit.Tween(arrow, 0.45, { Position = UDim2.fromScale(0, 0.2) }, Enum.EasingStyle.Sine)
			task.wait(0.45)
			Kit.Tween(arrow, 0.45, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Sine)
			task.wait(0.45)
		end
	end)
end

-- DEV panel REPLAY TUTORIAL: back to step 1 (the server already reset the saved step)
function Tutorial.Restart()
	step = 1
	collectedOnce = false
end

function Tutorial.Start()
	Orbs.Collected:Connect(function()
		collectedOnce = true
	end)
	RunService.RenderStepped:Connect(updateGuide)
	task.spawn(function()
		local d = State.WaitForData()
		step = math.clamp(d.Tutorial or 1, 1, STEPS + 1)
		if step == 1 then
			-- let the world settle, then frame the first ghost
			task.wait(2)
			if (player:GetAttribute("Target") or 0) == 0 then
				frameGhost()
			end
		end
		while true do
			tick()
			task.wait(0.25)
		end
	end)
end

return Tutorial
