--!strict
-- THE VOID EMPEROR HUD (World 2 final boss). Shows only what the server says: workspace
-- attributes VE* (state, phase, Spirit, pylons, crown, circles; also correct for late joiners),
-- player attributes VEMirror / VEShare, and Fx "VoidEmperor" moments. It sends nothing.
--   * portal open: a pill for everyone who has the Void Throne ("join in 42s")
--   * near the arena while idle: "wakes in 12:34"
--   * fight (near the arena or once you dealt damage): a top bar with phase, timer, Spirit bar
--     with the phase walls, what to do right now and your damage share
--   * phase 2: the crowned copy gets a gold outline + crown marker; the next one flashes during
--     the 2 s tell
--   * phase 3: the arena dims a little (local colour correction while you're near it)
--   * final 5%: a short, gentle camera shake
-- Mobile: fixed text sizes (Kit labels, no TextScaled), no text scale tweens, no buttons.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Layout = require(GH.Logic.Layout)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local State = require(Client.State)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local VoidEmperorHud = {}

local C = Config.VoidEmperor
local player = Players.LocalPlayer
local DARK_A, DARK_B = Color3.fromRGB(28, 22, 44), Color3.fromRGB(8, 6, 14)
local STAR = Color3.fromRGB(255, 240, 200)
local NEAR = C.Radius + 110 -- studs from the centre where the HUD shows without having fought

local PHASE_NAMES = { "THE CROWN", "THE SPLIT", "THE LAST LIGHT" }

local bar: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local fill: Frame
local spiritLabel: TextLabel
local goalLabel: TextLabel
local shareLabel: TextLabel
local pill: Frame
local pillLabel: TextLabel

local crownMark: { Highlight: Highlight, Gui: BillboardGui }? = nil
local tellMark: Highlight? = nil
local dark: ColorCorrectionEffect? = nil
local shakeUntil = 0

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function num(name: string): number
	local v = workspace:GetAttribute(name)
	return if type(v) == "number" then v else 0
end

local function hasZone(): boolean
	local d = State.Data
	return d ~= nil and type(d.Zones) == "table" and d.Zones[C.Zone] == true
end

local function near(): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = root.Position - C.Center
	return Vector3.new(d.X, 0, d.Z).Magnitude <= NEAR
end

local function ghostModel(uid: number): Model?
	if uid == 0 then
		return nil
	end
	local folder = workspace:FindFirstChild("Ghosts")
	local m = folder and folder:FindFirstChild("Ghost_" .. uid)
	return if m and m:IsA("Model") then m else nil
end

--------------------------------------------------------------------------------
-- Crown marker (phase 2)
--------------------------------------------------------------------------------
local function clearCrown()
	if crownMark then
		crownMark.Highlight:Destroy()
		crownMark.Gui:Destroy()
		crownMark = nil
	end
end

local function clearTell()
	if tellMark then
		tellMark:Destroy()
		tellMark = nil
	end
end

local function markCrown(uid: number)
	clearCrown()
	local m = ghostModel(uid)
	if not m then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "VECrown"
	h.FillTransparency = 1
	h.OutlineColor = Theme.Gold
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = m
	h.Parent = m
	local def = Config.Ghosts[C.Ghost]
	local gui = Instance.new("BillboardGui")
	gui.Name = "VECrownMark"
	gui.Size = UDim2.fromOffset(64, 64)
	gui.StudsOffset = Vector3.new(0, 2.6 * def.Scale + 6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local core = m.PrimaryPart
	if core then
		gui.Adornee = core
	end
	gui.Parent = m
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Text = "👑"
	icon.TextSize = 44 -- fixed size (no TextScaled)
	icon.Font = Theme.Title
	icon.Parent = gui
	crownMark = { Highlight = h, Gui = gui }
end

local function markTell(uid: number)
	clearTell()
	local m = ghostModel(uid)
	if not m then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "VECrownNext"
	h.FillTransparency = 1
	h.OutlineColor = Color3.new(1, 1, 1)
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = m
	h.Parent = m
	tellMark = h
end

--------------------------------------------------------------------------------
-- Arena mood (phase 3) + roar shake
--------------------------------------------------------------------------------
local function setDark(on: boolean)
	if on and not dark then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "VoidEmperorDark"
		cc.Brightness = 0
		cc.Saturation = 0
		cc.Parent = Lighting
		dark = cc
		Kit.Tween(cc, 1.5, { Brightness = -0.12, Saturation = -0.25 })
	elseif not on and dark then
		local cc = dark
		dark = nil
		Kit.Tween(cc, 1, { Brightness = 0, Saturation = 0 })
		task.delay(1.1, function()
			cc:Destroy()
		end)
	end
end

local function shake(seconds: number)
	shakeUntil = os.clock() + seconds
end

--------------------------------------------------------------------------------
-- Bar
--------------------------------------------------------------------------------
local function goalText(phase: number, t: number): (string, Color3)
	local mirror = player:GetAttribute("VEMirror")
	if type(mirror) == "number" and mirror > t then
		return string.format("🪞 MIRRORED! Your hunters are confused for %ds - tap the 👑 copy", math.ceil(mirror - t)), Theme.Bad
	end
	if phase == 1 then
		local kneel = num("VEKneel")
		if kneel > t then
			return string.format("⬇️ HE KNEELS! Double damage for %ds - hit him now!", math.ceil(kneel - t)), Theme.Gold
		end
		local up = num("VEPylons")
		if up > 0 then
			return string.format("💎 Split up and break the Void Pylons! %d left (he takes 10%% damage)", up), Theme.Text
		end
		return "Pylons down! Push him to the wall before they come back!", Theme.Ecto
	elseif phase == 2 then
		local hop = num("VEHopAt")
		local left = math.max(0, math.ceil(hop - t))
		if num("VECrownNext") ~= 0 then
			return "⚠️ The crown is about to jump! Watch the flashing copy", Theme.Gold
		end
		return string.format("👑 Only the CROWNED copy takes damage! Crown jumps in %ds", left), Theme.Text
	elseif phase == 3 then
		local need, held = num("VENeed"), num("VEHeld")
		if workspace:GetAttribute("VEFinal") == true then
			if workspace:GetAttribute("VEShield") == true then
				return "🌟 FINAL STAND! Everyone into the centre light!", Theme.Gold
			end
			return "🌟 FINAL STAND! Shield down - finish him!", Theme.Gold
		end
		if workspace:GetAttribute("VEShield") == true then
			return string.format("🛡️ VOID SHIELD UP! Stand in the light circles: %d/%d held", held, need), Theme.Bad
		end
		return string.format("✨ Shield down! Keep the circles held (%d/%d) and attack!", held, need), Theme.Ecto
	end
	return "", Theme.Text
end

local function update()
	local st = workspace:GetAttribute("VEState")
	local t = serverNow()
	local at = num("VEAt")
	local isNear = near()
	local share = player:GetAttribute("VEShare")
	local fighting = st == "Fight" and (isNear or (type(share) == "number" and share > 0))
	bar.Visible = fighting
	if st == "Open" and hasZone() then
		pill.Visible = true
		pillLabel.Text = string.format("🌌 THE VOID EMPEROR AWAKENS · join in the Void Throne arena: %ds", math.max(0, math.ceil(at - t)))
	elseif st == "Idle" and isNear and hasZone() and at > t then
		pill.Visible = true
		pillLabel.Text = "🌌 The Void Emperor wakes in " .. Format.Time(at - t)
	elseif st == "Fight" and not fighting and isNear then
		pill.Visible = true
		pillLabel.Text = "🌌 The Void Emperor fight is on!"
	else
		pill.Visible = false
	end

	local phase = num("VEPhase")
	if st ~= "Fight" then
		clearCrown()
		clearTell()
		setDark(false)
		return
	end
	-- crown marker (refreshed every update: copies can stream in late)
	local crown = num("VECrown")
	if phase == 2 and crown ~= 0 then
		local m = ghostModel(crown)
		if not crownMark or not m or crownMark.Highlight.Parent ~= m then
			markCrown(crown)
		end
	else
		clearCrown()
	end
	local nextUid = num("VECrownNext")
	if phase == 2 and nextUid ~= 0 then
		local m = ghostModel(nextUid)
		if not tellMark or not m or tellMark.Parent ~= m then
			markTell(nextUid)
		end
		local tm = tellMark
		if tm then
			tm.OutlineTransparency = if math.floor(os.clock() * 6) % 2 == 0 then 0 else 0.7
		end
	else
		clearTell()
	end
	setDark(phase == 3 and isNear)

	if not fighting then
		return
	end
	local dev = workspace:GetAttribute("VEDev") == true
	titleLabel.Text = string.format("👑 VOID EMPEROR · %s%s", PHASE_NAMES[phase] or "", if dev then " (DEV)" else "")
	local left = math.max(0, at - t)
	timerLabel.Text = "⏱ " .. Format.Time(left)
	timerLabel.TextColor3 = if left < 30 then Theme.Bad else Theme.Text
	local hp, max = num("VEHp"), math.max(1, num("VEMax"))
	fill.Size = UDim2.fromScale(math.clamp(hp / max, 0.005, 1), 1)
	spiritLabel.Text = Format.Short(hp) .. " / " .. Format.Short(max) .. " SPIRIT"
	local text, color = goalText(phase, t)
	goalLabel.Text = text
	goalLabel.TextColor3 = color
	if type(share) == "number" and share > 0 then
		shareLabel.Text = if dev then "Your damage: " .. Format.Percent(share) .. " · DEV FIGHT: no rewards" else "Your damage: " .. Format.Percent(share)
	else
		shareLabel.Text = if dev then "DEV FIGHT: no rewards" else "Attack to earn a share of the reward!"
	end
end

--------------------------------------------------------------------------------
-- Moments
--------------------------------------------------------------------------------
local function onFx(data: any)
	if type(data) ~= "table" then
		return
	end
	local kind = data.Kind
	local isNear = near()
	local share = player:GetAttribute("VEShare")
	local involved = isNear or (type(share) == "number" and share > 0)
	if kind == "Open" then
		if hasZone() then
			Hud.Announce("🌌 THE VOID EMPEROR AWAKENS! Join in the Void Throne arena", STAR, Color3.fromRGB(150, 110, 255))
			Sound.Play("BossAppear")
		end
	elseif kind == "Start" then
		if involved then
			Hud.Announce("👑 THE VOID EMPEROR RISES! Break his pylons!", STAR, Color3.fromRGB(150, 110, 255))
			Sound.Play("BossAppear")
		end
	elseif kind == "Closed" then
		if isNear then
			Kit.Toast("Nobody answered the call... the Void Emperor sleeps again.", "Bad")
		end
	elseif not involved then
		return
	elseif kind == "Kneel" then
		Hud.Announce("⬇️ HE KNEELS! DOUBLE DAMAGE!", Theme.Gold, Color3.fromRGB(255, 140, 60))
		Sound.Play("ZoneUnlock")
	elseif kind == "PylonsBack" then
		Kit.Toast("💎 The Void Pylons are back! Break them again!", "Bad")
	elseif kind == "Phase" then
		if data.Phase == 2 then
			Hud.Announce("👑 THE SPLIT! Hit only the crowned copy!", STAR, Color3.fromRGB(150, 110, 255))
		elseif data.Phase == 3 then
			Hud.Announce("✨ THE LAST LIGHT! Hold the light circles!", STAR, Color3.fromRGB(255, 220, 120))
		end
		Sound.Play("BossAppear")
	elseif kind == "CrownTell" then
		Sound.Play("Select")
	elseif kind == "CirclesMove" then
		Kit.Toast("✨ The light circles moved!", "Good")
	elseif kind == "Mirror" then
		Kit.Toast("🪞 Wrong copy! Your hunters are mirrored for " .. C.MirrorSeconds .. "s", "Bad")
		Sound.Play("Error")
	elseif kind == "Roar" then
		Hud.Announce("🌟 FINAL STAND! Everyone into the centre light!", Theme.Gold, Color3.fromRGB(255, 255, 255))
		Sound.Play("BigPoof")
		shake(1.4)
	elseif kind == "Won" then
		Hud.Announce("🏆 THE VOID EMPEROR IS DEFEATED!", Theme.Gold, Color3.fromRGB(255, 255, 255))
		Sound.Play("ZoneUnlock")
	elseif kind == "Failed" then
		Hud.Announce("😈 He laughs and sinks into the throne... Try again next time!", Color3.fromRGB(200, 170, 255), DARK_A)
	end
end

local function onReward(data: any)
	if type(data) ~= "table" or data.Kind ~= "Reward" then
		return
	end
	local ecto = tonumber(data.Ecto) or 0
	local pct = tonumber(data.Pct) or 0
	if data.Dev == true then
		Kit.Toast("DEV FIGHT: no rewards (you did " .. Format.Percent(pct) .. " of the damage)", "Good")
	elseif data.Small == true then
		Kit.Toast("Deal more damage next time to earn a share of the Void Emperor's reward!", "Bad")
	elseif ecto > 0 then
		local text = string.format("👑 VOID EMPEROR: %s damage -> +💚%s", Format.Percent(pct), Format.Short(ecto))
		if data.Crate == true then
			text ..= " + a FREE VOID CRATE!"
		end
		Kit.Toast(text, "Good")
		if data.First == true then
			task.delay(1.5, function()
				Hud.Announce("⭐ FIRST VICTORY! You beat the Void Emperor!", Theme.Gold, STAR)
			end)
		end
	end
end

function VoidEmperorHud.Init()
	local screen = Kit.Screen()
	local stack = Hud.TopStack
	bar = Kit.new("Frame", {
		Name = "VoidEmperorBar",
		Size = UDim2.fromOffset(430, 112),
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
	Kit.Gradient(bar, DARK_A, DARK_B, 90)
	-- drawn smaller than the full HUD so it blocks less of the fight (same rule as the Boss Tower
	-- bar: a fixed layout scale, never animated, with a floor so phone text stays readable)
	local BAR_SCALE, BAR_FLOOR = 0.7, 0.6
	local barScale: UIScale = Kit.new("UIScale", { Scale = Layout.SubScale(BAR_SCALE, Kit.UIScale(), BAR_FLOOR), Parent = bar })
	Kit.LayoutScale(barScale)
	Kit.ScaleChanged:Connect(function(k: number)
		barScale.Scale = Layout.SubScale(BAR_SCALE, k, BAR_FLOOR)
	end)
	titleLabel = Kit.Label(bar, "👑 VOID EMPEROR", { Size = UDim2.new(0.74, 0, 0, 22), Position = UDim2.fromOffset(10, 4), Align = Enum.TextXAlignment.Left, Color = STAR, Style = "Heading", Fit = true, ZIndex = 31 })
	timerLabel = Kit.Label(bar, "", { Size = UDim2.new(0.24, 0, 0, 22), Position = UDim2.new(1, -10, 0, 4), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Style = "Body", Fit = true, ZIndex = 31 })
	local track: Frame = Kit.new("Frame", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 31), BackgroundColor3 = Color3.fromRGB(14, 10, 24), ZIndex = 31, Parent = bar })
	Kit.Corner(track, UDim.new(1, 0))
	Kit.Stroke(track, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	fill = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 32, Parent = track })
	Kit.Corner(fill, UDim.new(1, 0))
	Kit.Gradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 130, 255), 0)
	-- phase walls on the bar
	for _, w in C.Walls do
		Kit.new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromScale(w, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Theme.Gold, BorderSizePixel = 0, ZIndex = 33, Parent = track })
	end
	spiritLabel = Kit.Label(track, "", { Style = "Small", ZIndex = 34 })
	goalLabel = Kit.Label(bar, "", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 60), Style = "Small", Fit = true, ZIndex = 31 })
	shareLabel = Kit.Label(bar, "", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 86), Style = "Small", Color = Theme.Gold, Fit = true, ZIndex = 31 })

	pill = Kit.new("Frame", {
		Name = "VoidEmperorPill",
		Size = UDim2.fromOffset(400, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 30,
		LayoutOrder = 3,
		Parent = stack or screen,
	})
	if not stack then
		pill.Position = UDim2.new(0.5, 0, 0, 60)
		pill.AnchorPoint = Vector2.new(0.5, 0)
	end
	Kit.Corner(pill, UDim.new(1, 0))
	Kit.Stroke(pill, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(pill, DARK_A, DARK_B, 90)
	pillLabel = Kit.Label(pill, "", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Style = "Small", Color = STAR, Fit = true, ZIndex = 31 })
end

function VoidEmperorHud.Start()
	State.OnFx("VoidEmperor", function(data: any)
		if type(data) == "table" and data.Kind == "Reward" then
			onReward(data)
		else
			onFx(data)
		end
		update()
	end)
	for _, attr in { "VEState", "VEPhase", "VECrown", "VECrownNext", "VEShield", "VEFinal" } do
		workspace:GetAttributeChangedSignal(attr):Connect(update)
	end
	-- roar: a short camera shake that fades out (gentle; skipped when nothing is due)
	RunService:BindToRenderStep("VoidEmperorShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left <= 0 then
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			local a = 0.35 * math.min(1, left)
			cam.CFrame *= CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				update()
			end)
			if not ok then
				warn("[VoidEmperorHud] " .. tostring(err))
			end
			task.wait(0.25)
		end
	end)
end

return VoidEmperorHud
