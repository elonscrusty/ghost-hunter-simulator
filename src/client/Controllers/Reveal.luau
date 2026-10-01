--!strict
-- Crate opening cinematic. Plays on a private stage far from the map with a scripted camera:
--   crate drops in → bounces → shakes (rare+: levitates while rarity energy converges) →
--   locks pop → lid flies open → light burst → the hunter leaps out and poses → result card.
-- Intensity comes from Config.Rarities (RevealPause, ShakeIntensity, Particles, Darken,
-- CameraPunch). Commons are quick; "Fast crate opening" in settings shortens everything; SKIP
-- jumps straight to the result. Every step is written as anim(duration, apply(alpha)) so a
-- skip simply applies each step's end state.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local HunterRig = require(GH.Rigs.HunterRig)
local CrateRig = require(GH.Rigs.CrateRig)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local Targeting = require(script.Parent.Targeting)

local Reveal = {}

export type Result = {
	Crate: string,
	Hunter: string,
	Uid: string,
	IsNew: boolean,
}

local player = Players.LocalPlayer
local STAGE = Vector3.new(0, 900, -2500)
local CAM_FOV = 50

local playing = false
local skipping = false
local stage: Folder? = nil
local gui: ScreenGui? = nil
local cc: ColorCorrectionEffect? = nil
local rays: Frame? = nil
local raySpeed = 20
local poseConn: RBXScriptConnection? = nil
local hunterRig: HunterRig.Rig? = nil
local hunterState = "Idle"
local againFn: (() -> ())? = nil
local finishedSignal = Instance.new("BindableEvent")
Reveal.Finished = finishedSignal.Event -- (result)
local startedSignal = Instance.new("BindableEvent")
Reveal.Started = startedSignal.Event

function Reveal.IsPlaying(): boolean
	return playing
end

local function fast(): boolean
	local d = State.Data
	return d ~= nil and d.Settings.FastReveal == true
end

-- Runs fn(alpha) every frame for `t` seconds (alpha 0→1). On skip: fn(1) immediately.
local function anim(t: number, fn: (number) -> ())
	if skipping or t <= 0 then
		fn(1)
		return
	end
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / t, 0, 1)
		fn(a)
		if a >= 1 or skipping then
			if skipping then
				fn(1)
			end
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function easeOutBack(a: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
end

local function easeOutBounce(a: number): number
	local n1, d1 = 7.5625, 2.75
	if a < 1 / d1 then
		return n1 * a * a
	elseif a < 2 / d1 then
		a -= 1.5 / d1
		return n1 * a * a + 0.75
	elseif a < 2.5 / d1 then
		a -= 2.25 / d1
		return n1 * a * a + 0.9375
	end
	a -= 2.625 / d1
	return n1 * a * a + 0.984375
end

local controls: any = nil
local function setControls(on: boolean)
	if not controls then
		local ok, mod = pcall(function()
			local ps = player:WaitForChild("PlayerScripts")
			return (require :: any)(ps:WaitForChild("PlayerModule"))
		end)
		if ok and mod then
			controls = mod:GetControls()
		end
	end
	if controls then
		pcall(function()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end)
	end
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = stage
	return p
end

local function buildStage(rarity: Config.RarityDef)
	local f = Instance.new("Folder")
	f.Name = "GHReveal"
	f.Parent = workspace
	stage = f
	-- floor disc with glowing trim
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 18, 18), Color = Color3.fromRGB(45, 28, 80), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(STAGE - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 19, 19), Color = rarity.Color, Material = Enum.Material.Neon, CFrame = CFrame.new(STAGE - Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	-- backdrop with spinning rays (SurfaceGui, unaffected by lighting)
	local back = part({ Size = Vector3.new(70, 44, 1), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 6, 14)) })
	local sg: SurfaceGui = Kit.new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 14,
		LightInfluence = 0,
		Brightness = 1,
		Parent = back,
	})
	local bg: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sg })
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 10, 40)),
			ColorSequenceKeypoint.new(0.5, rarity.Color2:Lerp(Color3.fromRGB(40, 20, 70), 0.55)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 40)),
		}),
		Rotation = 90,
		Parent = bg,
	})
	local holder: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(1400, 1400),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = bg,
	})
	-- six full-length bars through the centre = twelve rays (GUI rotation pivots on the centre)
	for i = 0, 5 do
		local ray: Frame = Kit.new("Frame", {
			Size = UDim2.new(0, 110, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Rotation = i * 30,
			Parent = holder,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.35),
				NumberSequenceKeypoint.new(0.5, 0.15),
				NumberSequenceKeypoint.new(0.58, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	rays = holder
	-- lights
	local l1 = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 7, -6)) })
	Kit.new("PointLight", { Range = 22, Brightness = 2.2, Color = Color3.fromRGB(255, 240, 255), Parent = l1 })
	local l2 = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 3, 3)) })
	Kit.new("PointLight", { Name = "RarityLight", Range = 16, Brightness = 0, Color = rarity.Color, Parent = l2 })
end

local function buildGui(): (ScreenGui, TextButton)
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = "GHRevealGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Kit.new("UIScale", { Scale = Kit.UIScale(), Parent = g })
	local skip = Kit.Button(g, {
		Text = "SKIP ⏩",
		Color = "Gray",
		Size = UDim2.fromOffset(150, 56),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 5,
		OnClick = function()
			skipping = true
		end,
	})
	gui = g
	return g, skip
end

local function flash(color: Color3, t: number)
	local g = gui
	if not g then
		return
	end
	local f: Frame = Kit.new("Frame", { Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), BackgroundColor3 = color, BackgroundTransparency = 0.1, ZIndex = 20, Parent = g })
	Kit.Tween(f, t, { BackgroundTransparency = 1 })
	task.delay(t, function()
		f:Destroy()
	end)
end

local function cameraShake(intensity: number, t: number)
	local cam = workspace.CurrentCamera
	if not cam or skipping then
		return
	end
	local base = cam.CFrame
	anim(t, function(a)
		local k = intensity * (1 - a)
		cam.CFrame = base * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
	cam.CFrame = base
end

local function resultCard(g: ScreenGui, res: Result, rarity: Config.RarityDef)
	local def = Config.Hunters[res.Hunter]
	local d = State.Data
	local card: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(560, 250),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 10,
		Parent = g,
	})
	Kit.Corner(card, UDim.new(0, 24))
	Kit.Stroke(card, 5, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(card, Theme.Panel2, Theme.Bg, 90)
	local sc = Kit.new("UIScale", { Scale = 0.3, Parent = card })
	Kit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	-- rarity ribbon
	local ribbon: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(300, 46),
		Position = UDim2.new(0.5, 0, 0, -22),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = card,
	})
	Kit.Corner(ribbon, UDim.new(0, 14))
	Kit.Stroke(ribbon, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(ribbon, rarity.Color, rarity.Color2, 0)
	Kit.Label(ribbon, rarity.Name, { Size = UDim2.fromScale(0.9, 0.78), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 13, Stroke = 3 })
	Kit.Label(card, string.upper(def.Name), { Size = UDim2.new(1, -40, 0, 54), Position = UDim2.fromOffset(20, 30), ZIndex = 11, Stroke = 4 })
	Kit.Label(card, "⚡ " .. Format.Commas(def.Power) .. " CAPTURE POWER", { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 86), Color = Theme.Gold, ZIndex = 11 })
	Kit.Label(card, def.Blurb, { Size = UDim2.new(1, -60, 0, 28), Position = UDim2.fromOffset(30, 122), Color = Theme.Muted, Font = Theme.Body, ZIndex = 11, Stroke = 0 })
	if res.IsNew then
		local stamp = Kit.Label(card, "NEW!", { Size = UDim2.fromOffset(120, 50), Position = UDim2.new(1, 10, 0, 6), AnchorPoint = Vector2.new(1, 0), Color = Theme.Ecto, ZIndex = 14, Stroke = 4 })
		stamp.Rotation = 14
		local ssc = Kit.new("UIScale", { Scale = 3, Parent = stamp })
		Kit.Tween(ssc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	-- buttons
	local row: Frame = Kit.new("Frame", {
		Size = UDim2.new(1, -40, 0, 64),
		Position = UDim2.new(0, 20, 1, -78),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = card,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), Parent = row })
	local equipped = d and table.find(d.Equipped, res.Uid) ~= nil
	local slots = if d then d.Slots or Config.Inventory.BaseSlots else Config.Inventory.BaseSlots
	if d and not equipped then
		local free = #d.Equipped < slots
		-- with full slots, offer EQUIP BEST only if this hunter beats the weakest equipped one
		local weakest = math.huge
		for _, uid in d.Equipped do
			local h = d.Hunters[uid]
			if h then
				weakest = math.min(weakest, Config.Hunters[h.Id].Power)
			end
		end
		if free or def.Power > weakest then
			local b: TextButton
			b = Kit.Button(row, {
				Text = if free then "EQUIP" else "EQUIP BEST",
				Color = "Green",
				Size = UDim2.fromOffset(160, 60),
				ZIndex = 12,
				OnClick = function()
					local r = if free then State.Request("Equip", res.Uid) else State.Request("EquipBest")
					if r.ok then
						Kit.SetButtonText(b, "EQUIPPED ✓")
						b:SetAttribute("Color", "Gray")
						b.Active = false
					else
						Kit.Toast(r.err or "Couldn't equip", "Bad")
					end
				end,
			})
			b.Name = "EquipButton"
		end
	end
	if againFn then
		local crate = Config.Crates[res.Crate]
		local fnAgain = againFn
		Kit.Button(row, {
			Text = "AGAIN 💚" .. Format.Short(crate.Price),
			Color = "Purple",
			Size = UDim2.fromOffset(170, 60),
			ZIndex = 12,
			OnClick = function()
				fnAgain()
			end,
		})
	end
	Kit.Button(row, {
		Text = "OK",
		Color = "Blue",
		Size = UDim2.fromOffset(120, 60),
		ZIndex = 12,
		OnClick = function()
			Reveal.Close()
		end,
	})
end

local function teardownStage()
	if poseConn then
		poseConn:Disconnect()
		poseConn = nil
	end
	if stage then
		stage:Destroy()
		stage = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	hunterRig = nil
	rays = nil
end

-- Ends the reveal and gives the camera back.
function Reveal.Close()
	if not playing then
		return
	end
	teardownStage()
	if cc then
		cc.Brightness = 0
		cc.Saturation = 0
		cc.Contrast = 0
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	Kit.Screen().Enabled = true
	setControls(true)
	Targeting.SetBlocked(false)
	playing = false
	finishedSignal:Fire()
end

-- Plays the opening for a server-confirmed result. `again` (optional) re-buys the same crate.
function Reveal.Play(res: Result, again: (() -> ())?)
	local def = Config.Hunters[res.Hunter]
	local crateDef = Config.Crates[res.Crate]
	if not def or not crateDef then
		return
	end
	local rarity = Config.Rarities[def.Rarity]
	againFn = again
	if playing then
		teardownStage() -- "AGAIN": keep the camera, rebuild the stage
	end
	playing = true
	skipping = false
	startedSignal:Fire()
	Targeting.SetBlocked(true)
	setControls(false)
	Kit.Screen().Enabled = false
	buildStage(rarity)
	local g, skip = buildGui()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = CAM_FOV
	local camCF = CFrame.lookAt(STAGE + Vector3.new(0, 4.6, -13), STAGE + Vector3.new(0, 2.6, 0))
	cam.CFrame = camCF
	flash(Color3.new(1, 1, 1), 0.35)

	local f = if fast() then 0.5 else 1
	local my = stage

	-- crate
	local crate = CrateRig.Build(res.Crate)
	crate.Model:ScaleTo(1.25)
	crate.Model.Parent = stage
	local base = CFrame.new(STAGE)
	local function placeCrate(cf: CFrame)
		crate.Model:PivotTo(cf)
	end
	placeCrate(base + Vector3.new(0, 9, 0))

	-- rays spin + hunter poses
	raySpeed = 20
	local hunterT0 = os.clock()
	poseConn = RunService.RenderStepped:Connect(function(dt: number)
		if rays then
			rays.Rotation = (rays.Rotation + dt * raySpeed) % 360
		end
		if hunterRig then
			HunterRig.Pose(hunterRig, hunterState, os.clock() - hunterT0, 1)
		end
	end)

	Sound.Play("CrateBuy")
	-- 1) drop in with a bounce
	anim(0.45 * f, function(a)
		placeCrate(base + Vector3.new(0, 9 * (1 - easeOutBounce(a)), 0))
	end)
	if stage ~= my then
		return
	end
	-- 2) shake (+ levitate, darken and converging energy for rarer pulls)
	local shakeT = (0.55 + rarity.RevealPause) * f
	local levitate = if rarity.Order >= 3 then 1.4 else 0
	local charge: ParticleEmitter? = nil
	if rarity.RevealPause > 0.3 and not skipping then
		local sphere = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 2.5, 0)) })
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Texture = Effects.Textures.Sparkle
		e.Color = ColorSequence.new(rarity.Color, rarity.Color2)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
		e.Speed = NumberRange.new(9, 12)
		e.Lifetime = NumberRange.new(0.45, 0.6)
		e.Rate = 0
		e.Parent = sphere
		charge = e
	end
	if cc and rarity.Darken > 0 and not skipping then
		TweenService:Create(cc, TweenInfo.new(shakeT * 0.6), { Brightness = -rarity.Darken * 0.35, Saturation = -rarity.Darken * 0.4 }):Play()
	end
	local rl = (if stage then stage:FindFirstChild("RarityLight", true) else nil) :: any
	if not skipping then
		Sound.Play("CrateShake")
	end
	local nextShakeSound = os.clock() + 0.45
	anim(shakeT, function(a)
		local k = rarity.ShakeIntensity * (0.4 + a)
		local tt = os.clock()
		local wob = CFrame.Angles(math.sin(tt * 38) * 0.06 * k, math.sin(tt * 29) * 0.1 * k, math.sin(tt * 47) * 0.09 * k)
		local lift = levitate * math.sin(math.min(a * 1.6, 1) * math.pi / 2)
		placeCrate(base * CFrame.new(math.sin(tt * 53) * 0.12 * k, lift, 0) * wob)
		raySpeed = 20 + 160 * a * rarity.Order / 5
		if charge then
			charge.Rate = 15 + 110 * a
		end
		if rl then
			rl.Brightness = 3 * a * math.min(1, rarity.Order / 3)
		end
		if tt >= nextShakeSound and a < 0.95 then
			nextShakeSound = tt + 0.45
			Sound.Play("CrateShake", 0.1)
		end
	end)
	if charge then
		charge.Rate = 0
	end
	if stage ~= my then
		return
	end
	placeCrate(base + Vector3.new(0, levitate, 0))
	-- 3) locks pop off
	if not skipping then
		Sound.Play("LockPop")
	end
	anim(0.22 * f, function(a)
		local e = easeOutBack(a)
		crate.Motors.LockL.Transform = CFrame.new(-1.2 * e, 1.4 * e - 2.5 * a * a, -0.8 * e) * CFrame.Angles(0, 0, 2.5 * a)
		crate.Motors.LockR.Transform = CFrame.new(1.2 * e, 1.4 * e - 2.5 * a * a, -0.8 * e) * CFrame.Angles(0, 0, -2.5 * a)
	end)
	-- drop the padlocks (and their welded shackles) out of sight
	crate.Motors.LockL.Transform = CFrame.new(0, -60, 0)
	crate.Motors.LockR.Transform = CFrame.new(0, -60, 0)
	-- 4) lid flies open + light burst
	local burstPos = crate.Burst.WorldPosition
	if not skipping then
		Sound.Play(rarity.Sound)
		flash(rarity.Color, 0.45)
		Effects.Flash(burstPos, rarity.Color, 5 + rarity.Order, 0.5)
		Effects.Burst(burstPos, { Color = rarity.Color, Color2 = Color3.new(1, 1, 1), Count = rarity.Particles, Size = 0.9, Speed = 26, Life = 1.1, Gravity = 18 })
		Effects.Ring(STAGE + Vector3.new(0, 0.2, 0), rarity.Color, 10, 0.6)
		if cc then
			TweenService:Create(cc, TweenInfo.new(0.5), { Brightness = 0.12, Saturation = 0.15 }):Play()
			task.delay(0.5, function()
				if cc then
					TweenService:Create(cc, TweenInfo.new(0.6), { Brightness = 0, Saturation = 0 }):Play()
				end
			end)
		end
		if rarity.CameraPunch then
			cam.FieldOfView = CAM_FOV - 10
			TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Back), { FieldOfView = CAM_FOV }):Play()
			task.spawn(cameraShake, 0.5 * rarity.ShakeIntensity, 0.35)
		end
	end
	crate.Glow.Color = rarity.Color
	anim(0.3 * f, function(a)
		crate.Motors.Lid.Transform = CFrame.Angles(math.rad(115) * easeOutBack(a), 0, 0)
		crate.Glow.Transparency = 1 - 0.85 * a
	end)
	if stage ~= my then
		return
	end
	-- 5) hunter leaps out
	local rig = HunterRig.Build(res.Hunter)
	rig.Model:ScaleTo(1.2)
	rig.Model.Parent = stage
	hunterRig = rig
	hunterState = "Celebrate"
	hunterT0 = os.clock()
	local from = STAGE + Vector3.new(0, levitate + 0.6, 0.2)
	local to = STAGE + Vector3.new(0, 0, -3.4)
	anim(0.55 * f, function(a)
		local p = from:Lerp(to, a) + Vector3.new(0, 5.5 * 4 * a * (1 - a), 0)
		local spin = (1 - a) * math.pi * 2
		rig.Model:PivotTo(CFrame.new(p) * CFrame.Angles(0, spin, 0))
	end)
	rig.Model:PivotTo(CFrame.new(to))
	-- the crate settles back down behind the hunter
	placeCrate(base)
	if not skipping then
		Effects.Ring(to + Vector3.new(0, 0.15, 0), Color3.new(1, 1, 1), 5, 0.4)
		Effects.Burst(to + Vector3.new(0, 3, 0), { Color = rarity.Color, Count = math.floor(rarity.Particles / 3), Size = 0.6, Speed = 14, Life = 0.7 })
	end
	if stage ~= my then
		return
	end
	-- 6) legendary title slam
	if rarity.Order >= 5 and not skipping then
		local title = Kit.Label(g, rarity.Name .. "!", { Size = UDim2.fromOffset(700, 110), Position = UDim2.fromScale(0.5, 0.22), AnchorPoint = Vector2.new(0.5, 0.5), Color = rarity.Color, ZIndex = 8, Stroke = 5 })
		Kit.new("UIGradient", { Color = ColorSequence.new(rarity.Color, rarity.Color2), Rotation = 90, Parent = title })
		local tsc = Kit.new("UIScale", { Scale = 3, Parent = title })
		Kit.Tween(tsc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.spawn(cameraShake, 0.35, 0.3)
	end
	skip.Visible = false
	skipping = false
	raySpeed = 25
	cam.CFrame = camCF
	resultCard(g, res, rarity)
end

function Reveal.Init()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "GHRevealCC"
	effect.Parent = Lighting
	cc = effect
end

function Reveal.Start()
	-- respawning mid-reveal must not leave the camera stuck
	player.CharacterAdded:Connect(function()
		if playing then
			Reveal.Close()
		end
	end)
end

return Reveal
