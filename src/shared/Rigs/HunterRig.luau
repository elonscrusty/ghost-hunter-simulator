--!strict
-- Chibi ghost-hunter rigs built from plain Parts (no asset IDs).
--
--   HunterRig.Build(hunterId) -> Rig        animated rig: anchored Root at the feet, Motor6D limbs
--   HunterRig.Pose(rig, state, t, blend?)   procedural pose ("Idle" | "Run" | "Attack" | "Celebrate")
--   HunterRig.BuildStatic(hunterId) -> Model fully anchored, posed copy for ViewportFrame portraits
--
-- Layout (studs, model space, facing -Z): feet at Y=0, hips at Y=0.92, torso 0.9..1.95,
-- head (1.9 ball) centred at Y=2.77. Total height ~3.8-4.4 depending on hair/hat.
-- Joints sit at the waist (Root->Torso), neck, shoulders and hips, so Motor6D.Transform
-- rotates each bone around its joint.

local Config = require(script.Parent.Parent.Config)
local U = require(script.Parent.RigUtil)

local HunterRig = {}

export type Rig = {
	Model: Model,
	Root: BasePart,
	Motors: { [string]: Motor6D },
	Tip: Attachment,
	Height: number,
	HunterId: string,
}

type Deco = { Part: BasePart, Offset: CFrame }
type DecoMap = { [BasePart]: { Deco } }

-- body measurements
local HIP_Y = 0.92
local TORSO_SIZE = Vector3.new(1.3, 1.05, 0.85)
local TORSO_HALF_H = 0.5 -- waist joint sits this far below the torso centre
local NECK = Vector3.new(0, 0.525, 0) -- torso-local
local HEAD_UP = 0.82 -- head centre above the neck
local HEAD_D = 1.9
local SHOULDER = Vector3.new(0.86, 0.36, 0) -- torso-local (X mirrored)
local ARM_SIZE = Vector3.new(0.42, 0.78, 0.42)
local ARM_DROP = 0.3 -- arm centre below the shoulder
local HIP = Vector3.new(0.32, -0.5, 0) -- torso-local (X mirrored)
local LEG_SIZE = Vector3.new(0.5, 0.7, 0.55)
local LEG_DROP = 0.33
local GRIP = CFrame.new(0, -0.45, -0.05) * CFrame.Angles(-math.pi / 6, 0, 0) -- arm-local tool frame (-Z = muzzle)

local JOINT_ORDER = { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

local WHITE = Color3.fromRGB(255, 255, 255)
local EYE = Color3.fromRGB(25, 20, 35)
local MOUTH = Color3.fromRGB(110, 35, 50)
local METAL = Color3.fromRGB(90, 95, 115)

local NEON = { Material = Enum.Material.Neon }

local function buildInternal(hunterId: string): (Rig, DecoMap)
	local def = Config.Hunters[hunterId]
	assert(def, "HunterRig: unknown hunter " .. tostring(hunterId))
	local look = def.Look
	local rarity = Config.Rarities[def.Rarity]
	local rarityColor = if rarity then rarity.Color else look.Beam

	local model = Instance.new("Model")
	model.Name = hunterId

	local root = U.Block(Vector3.new(1, 1, 1), CFrame.identity, WHITE, model, { Transparency = 1, Name = "Root", Shadow = false })
	root.Anchored = true
	model.PrimaryPart = root

	local decos: DecoMap = {}
	local motors: { [string]: Motor6D } = {}

	local function bone(name: string, p: BasePart): BasePart
		p.Name = name
		decos[p] = {}
		return p
	end

	local function add(b: BasePart, p: BasePart): BasePart
		U.FixedWeld(b, p)
		table.insert(decos[b], { Part = p, Offset = b.CFrame:ToObjectSpace(p.CFrame) })
		return p
	end
	local function ball(b: BasePart, d: number, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Ball(d, b.CFrame * lcf, color, model, opts))
	end
	local function block(b: BasePart, size: Vector3, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Block(size, b.CFrame * lcf, color, model, opts))
	end
	local function cyl(b: BasePart, len: number, d: number, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Cyl(len, d, b.CFrame * lcf, color, model, opts))
	end
	local function wedge(b: BasePart, size: Vector3, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Wedge(size, b.CFrame * lcf, color, model, opts))
	end

	------------------------------------------------------------------ skeleton
	local torsoC0 = CFrame.new(0, HIP_Y, 0)
	local torsoC1 = CFrame.new(0, -TORSO_HALF_H, 0)
	local torso = bone("Torso", U.Block(TORSO_SIZE, torsoC0 * torsoC1:Inverse(), look.Shirt, model, { Shadow = true }))
	motors.Torso = U.Motor("Torso", root, torso, torsoC0, torsoC1)

	local headC0 = CFrame.new(NECK)
	local headC1 = CFrame.new(0, -HEAD_UP, 0)
	local head = bone("Head", U.Ball(HEAD_D, torso.CFrame * headC0 * headC1:Inverse(), look.Skin, model, { Shadow = true }))
	motors.Head = U.Motor("Head", torso, head, headC0, headC1)

	local arms: { [number]: BasePart } = {}
	local legs: { [number]: BasePart } = {}
	for _, s in { -1, 1 } do
		local side = if s < 0 then "Left" else "Right"
		local aC0 = CFrame.new(SHOULDER.X * s, SHOULDER.Y, SHOULDER.Z)
		local aC1 = CFrame.new(0, ARM_DROP, 0)
		local arm = bone(side .. "Arm", U.Block(ARM_SIZE, torso.CFrame * aC0 * aC1:Inverse(), look.Shirt, model))
		motors[side .. "Arm"] = U.Motor(side .. "Arm", torso, arm, aC0, aC1)
		ball(arm, 0.5, CFrame.new(0, -0.42, 0), look.Skin) -- hand
		arms[s] = arm

		local lC0 = CFrame.new(HIP.X * s, HIP.Y, HIP.Z)
		local lC1 = CFrame.new(0, LEG_DROP, 0)
		local leg = bone(side .. "Leg", U.Block(LEG_SIZE, torso.CFrame * lC0 * lC1:Inverse(), look.Pants, model))
		motors[side .. "Leg"] = U.Motor(side .. "Leg", torso, leg, lC0, lC1)
		-- shoe: bottom exactly at Y=0 (leg centre is at Y=0.59)
		block(leg, Vector3.new(0.6, 0.3, 0.78), CFrame.new(0, 0.15 - (HIP_Y - LEG_DROP), -0.08), look.Shoes)
		legs[s] = leg
	end
	local rArm = arms[1]

	------------------------------------------------------------------ face
	local hat = look.Hat
	local hatColor = look.HatColor or look.Shirt
	for _, s in { -1, 1 } do
		local eyePos = Vector3.new(0.34 * s, 0.0, -0.8)
		ball(head, 0.5, CFrame.new(eyePos), EYE, { Shadow = false })
		ball(head, 0.17, CFrame.new(eyePos + Vector3.new(0.07, 0.1, -0.19)), WHITE)
		if hat ~= "Goggles" then
			block(head, Vector3.new(0.34, 0.08, 0.14), CFrame.new(0.34 * s, 0.37, -0.86) * CFrame.Angles(0.35, 0, -0.14 * s), U.Shade(look.Hair, 0.8))
		end
	end
	-- little open smile: a WedgePart turned into a "▽"
	wedge(head, Vector3.new(0.1, 0.26, 0.26), CFrame.new(0, -0.34, -0.88) * CFrame.Angles(-0.35, 0, 0) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, MOUTH)

	------------------------------------------------------------------ hair
	local covered = hat == "Hood" or hat == "Helmet" or hat == "Beanie"
	local style = look.HairStyle
	local hairTop = 1.25
	local hairColor = look.Hair
	local function cap()
		ball(head, 2.0, CFrame.new(0, 0.25, 0.2), hairColor)
	end
	if style == "None" then
		hairTop = HEAD_D / 2
	elseif style == "Puff" and not covered then
		ball(head, 2.3, CFrame.new(0, 0.5, 0.32), hairColor)
		hairTop = 1.65
	elseif style == "Spiky" and not covered then
		cap()
		wedge(head, Vector3.new(0.45, 1.0, 0.8), CFrame.new(-0.3, 1.05, 0.35) * CFrame.Angles(0.5, 0, 0.25), hairColor)
		wedge(head, Vector3.new(0.45, 1.0, 0.8), CFrame.new(0.3, 1.0, 0.45) * CFrame.Angles(0.55, 0, -0.25), hairColor)
		hairTop = 1.35
	elseif style == "Bob" then
		cap()
		ball(head, 2.06, CFrame.new(0, -0.12, 0.32), hairColor)
	elseif style == "Long" then
		cap()
		block(head, Vector3.new(1.75, 1.6, 0.55), CFrame.new(0, -0.5, 0.72), hairColor)
	else -- Short (and covered Puff/Spiky): a neat hair cap
		cap()
	end
	local lift = hairTop - 1.25

	------------------------------------------------------------------ hat
	if hat == "Cap" then
		ball(head, 2.0, CFrame.new(0, 0.45, 0.12), hatColor)
		cyl(head, 0.1, 1.3, CFrame.new(0, 0.55, -0.95) * CFrame.Angles(-0.12, 0, 0) * U.AxisY, U.Shade(hatColor, 0.85))
	elseif hat == "Beanie" then
		ball(head, 2.06, CFrame.new(0, 0.42, 0.12), hatColor)
		ball(head, 0.6, CFrame.new(0, 1.5, 0.2), U.Mix(hatColor, WHITE, 0.6))
	elseif hat == "Fedora" then
		cyl(head, 0.12, 2.8, CFrame.new(0, 0.78 + lift, 0.08) * CFrame.Angles(-0.06, 0, 0) * U.AxisY, hatColor)
		cyl(head, 0.85, 1.55, CFrame.new(0, 1.2 + lift, 0.08) * U.AxisY, hatColor)
		cyl(head, 0.22, 1.6, CFrame.new(0, 0.92 + lift, 0.08) * U.AxisY, U.Shade(hatColor, 0.45))
	elseif hat == "Hood" then
		ball(head, 2.25, CFrame.new(0, 0.22, 0.3), hatColor)
		wedge(head, Vector3.new(0.55, 0.9, 0.7), CFrame.new(0, 1.2, 0.75) * CFrame.Angles(-0.3, 0, 0), hatColor)
	elseif hat == "Helmet" then
		ball(head, 2.08, CFrame.new(0, 0.48, 0.12), hatColor)
		cyl(head, 0.1, 2.35, CFrame.new(0, 0.5, 0.12) * U.AxisY, U.Shade(hatColor, 0.8))
		local dir = Vector3.new(0, 0.5, -0.87).Unit
		local pos = Vector3.new(0, 0.48, 0.12) + dir * 1.06
		cyl(head, 0.25, 0.45, U.DiscFacing(pos, dir), look.Beam, NEON)
	elseif hat == "Mortarboard" then
		cyl(head, 0.45, 1.5, CFrame.new(0, hairTop - 0.1, 0.1) * U.AxisY, hatColor)
		block(head, Vector3.new(2.1, 0.12, 2.1), CFrame.new(0, hairTop + 0.17, 0.1) * CFrame.Angles(0, math.pi / 4, 0), hatColor)
		block(head, Vector3.new(0.12, 0.6, 0.12), CFrame.new(1.38, hairTop - 0.1, 0.1), Color3.fromRGB(255, 205, 60), NEON)
	elseif hat == "Visor" then
		cyl(head, 0.2, 2.02, CFrame.new(0, 0.5, 0.05) * U.AxisY, U.Shade(hatColor, 0.6))
		block(head, Vector3.new(1.5, 0.08, 0.75), CFrame.new(0, 0.6, -1.05) * CFrame.Angles(-0.2, 0, 0), hatColor, { Material = Enum.Material.Neon, Transparency = 0.35 })
	elseif hat == "Goggles" then
		cyl(head, 0.16, 2.06, CFrame.new(0, 0.52, 0.05) * U.AxisY, U.Shade(hatColor, 0.45))
		for _, s in { -1, 1 } do
			local pos = Vector3.new(0.366 * s, 0.554, -0.817)
			cyl(head, 0.22, 0.5, U.DiscFacing(pos, pos), hatColor, { Material = Enum.Material.Neon, Transparency = 0.15 })
		end
	elseif hat == "Halo" then
		cyl(head, 0.1, 1.3, CFrame.new(0, hairTop + 0.4, 0.1) * CFrame.Angles(0.15, 0, 0) * U.AxisY, hatColor, { Material = Enum.Material.Neon, Transparency = 0.2 })
	end

	------------------------------------------------------------------ body accent / aura
	local badgeCf = CFrame.new(-0.3, 0.2, -0.44) * U.AxisZ
	if look.Aura then
		cyl(torso, 0.08, 0.42, badgeCf, rarityColor, NEON)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Aura"
		pe.Color = ColorSequence.new(rarityColor)
		pe.LightEmission = 1
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(0.9, 1.6)
		pe.Speed = NumberRange.new(0.4, 1.1)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.4, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Acceleration = Vector3.new(0, 1.2, 0)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Parent = torso
	else
		cyl(torso, 0.08, 0.42, badgeCf, look.Beam)
	end

	------------------------------------------------------------------ back
	local back = look.Back
	local backColor = look.BackColor or look.Shirt
	if back == "Backpack" then
		block(torso, Vector3.new(1.0, 1.0, 0.5), CFrame.new(0, 0, 0.65), backColor)
		block(torso, Vector3.new(0.7, 0.4, 0.18), CFrame.new(0, -0.2, 0.95), U.Shade(backColor, 0.75))
	elseif back == "Tank" then
		cyl(torso, 1.2, 0.78, CFrame.new(0, 0.1, 0.75) * U.AxisY, backColor, { Transparency = 0.45 })
		cyl(torso, 1.0, 0.5, CFrame.new(0, 0.1, 0.75) * U.AxisY, backColor, NEON)
		cyl(torso, 0.18, 0.84, CFrame.new(0, 0.75, 0.75) * U.AxisY, METAL, { Material = Enum.Material.Metal })
	elseif back == "Cape" then
		block(torso, Vector3.new(1.35, 1.55, 0.12), CFrame.new(0, -0.3, 0.52) * CFrame.Angles(-0.15, 0, 0), backColor)
		block(torso, Vector3.new(1.45, 0.3, 0.6), CFrame.new(0, 0.5, 0.25), U.Shade(backColor, 0.75))
	elseif back == "Wings" then
		for _, s in { -1, 1 } do
			-- big wing: tall outer edge, tapering into the spine
			wedge(torso, Vector3.new(0.12, 1.4, 1.2), CFrame.new(0.8 * s, 0.35, 0.58) * CFrame.Angles(0, 0, 0.35 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), backColor, { Transparency = 0.1 })
			-- glowing inner feather layer
			wedge(torso, Vector3.new(0.1, 1.0, 0.9), CFrame.new(0.7 * s, 0.0, 0.64) * CFrame.Angles(0, 0, 0.05 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), backColor, { Material = Enum.Material.Neon, Transparency = 0.3 })
		end
	elseif back == "Antenna" then
		block(torso, Vector3.new(0.7, 0.8, 0.4), CFrame.new(0, 0, 0.62), backColor)
		cyl(torso, 1.8, 0.1, CFrame.new(0.25, 1.1, 0.75) * U.AxisY, METAL, { Material = Enum.Material.Metal })
		ball(torso, 0.32, CFrame.new(0.25, 2.0, 0.75), look.Beam, NEON)
	end

	------------------------------------------------------------------ tool (right hand)
	local grip = rArm.CFrame * GRIP
	local tool = look.Tool
	local tc = look.ToolColor
	local beam = look.Beam
	local function tpart(p: BasePart): BasePart
		return add(rArm, p)
	end
	local function T(x: number, y: number, z: number): CFrame
		return grip * CFrame.new(x, y, z)
	end
	local muzzle: BasePart
	local tipWorld: CFrame
	if tool == "Vacuum" then
		local body = tpart(U.Block(Vector3.new(0.55, 0.6, 1.1), T(0, 0.1, -0.25), tc, model))
		tpart(U.Cyl(0.9, 0.42, T(0, 0.05, -1.2) * U.AxisZ, METAL, model, { Material = Enum.Material.Metal }))
		muzzle = tpart(U.Cyl(0.18, 0.64, T(0, 0.05, -1.7) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0.05, -1.82)
		-- hose: a Beam from the back of the vacuum to the hip (follows the animation for free)
		local a0 = U.AttachAt(body, "HoseA", T(0, 0.0, 0.3) * CFrame.Angles(0, 0, -math.pi / 2))
		local a1 = U.AttachAt(torso, "HoseB", torso.CFrame * CFrame.new(0.5, -0.35, if back then 0.6 else 0.3))
		local hose = Instance.new("Beam")
		hose.Name = "Hose"
		hose.Attachment0 = a0
		hose.Attachment1 = a1
		hose.Color = ColorSequence.new(U.Shade(tc, 0.55))
		hose.Width0 = 0.22
		hose.Width1 = 0.26
		hose.FaceCamera = true
		hose.Segments = 12
		hose.CurveSize0 = 0.9
		hose.CurveSize1 = 0
		hose.LightInfluence = 1
		hose.Transparency = NumberSequence.new(0)
		hose.Parent = body
	elseif tool == "Scanner" then
		tpart(U.Block(Vector3.new(0.8, 0.45, 1.2), T(0, 0.1, -0.35), U.Shade(tc, 0.45), model))
		tpart(U.Block(Vector3.new(0.6, 0.06, 0.7), T(0, 0.35, -0.35), tc, model, NEON))
		muzzle = tpart(U.Ball(0.32, T(0, 0.15, -1.0), tc, model, NEON))
		tipWorld = T(0, 0.15, -1.05)
	elseif tool == "Blaster" then
		tpart(U.Block(Vector3.new(0.5, 0.62, 1.05), T(0, 0.12, -0.3), tc, model))
		tpart(U.Cyl(0.8, 0.36, T(0, 0.22, -1.1) * U.AxisZ, METAL, model, { Material = Enum.Material.Metal }))
		muzzle = tpart(U.Cyl(0.16, 0.5, T(0, 0.22, -1.5) * U.AxisZ, beam, model, NEON))
		tpart(U.Wedge(Vector3.new(0.12, 0.3, 0.5), T(0, 0.58, -0.2), U.Shade(tc, 0.7), model))
		tipWorld = T(0, 0.22, -1.6)
	elseif tool == "Cannon" then
		tpart(U.Cyl(2.2, 0.95, T(0.15, 0.45, -0.55) * U.AxisZ, tc, model))
		tpart(U.Ball(1.1, T(0.15, 0.45, 0.45), U.Shade(tc, 0.6), model))
		tpart(U.Cyl(0.18, 1.02, T(0.15, 0.45, -0.4) * U.AxisZ, beam, model, NEON))
		muzzle = tpart(U.Cyl(0.3, 1.18, T(0.15, 0.45, -1.65) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0.15, 0.45, -1.85)
	elseif tool == "Lantern" then
		tpart(U.Cyl(0.18, 0.6, T(0, 0.05, -0.5) * U.AxisY, METAL, model, { Material = Enum.Material.Metal }))
		tpart(U.Block(Vector3.new(0.55, 0.65, 0.55), T(0, -0.3, -0.5), tc, model, { Transparency = 0.4 }))
		muzzle = tpart(U.Ball(0.38, T(0, -0.3, -0.5), beam, model, NEON))
		tipWorld = T(0, -0.3, -0.5)
		local light = Instance.new("PointLight")
		light.Color = beam
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = muzzle
	elseif tool == "Staff" then
		local up = CFrame.Angles(-0.1, 0, 0) -- pole stands nearly upright in the Attack pose
		tpart(U.Cyl(3.0, 0.18, grip * up * CFrame.new(0, 0.55, 0) * U.AxisY, U.Shade(tc, 0.5), model))
		tpart(U.Cyl(0.16, 0.62, grip * up * CFrame.new(0, 2.0, 0) * U.AxisY, tc, model))
		muzzle = tpart(U.Ball(0.62, grip * up * CFrame.new(0, 2.3, 0), beam, model, NEON))
		tipWorld = grip * up * CFrame.new(0, 2.3, 0)
	elseif tool == "Projector" then
		tpart(U.Block(Vector3.new(0.75, 0.7, 1.0), T(0, 0.15, -0.35), tc, model))
		muzzle = tpart(U.Cyl(0.25, 0.55, T(0, 0.15, -0.95) * U.AxisZ, beam, model, NEON))
		tpart(U.Cyl(0.12, 0.65, T(0, 0.75, -0.1), U.Shade(tc, 0.45), model))
		tpart(U.Cyl(0.12, 0.65, T(0, 0.75, -0.65), U.Shade(tc, 0.45), model))
		tipWorld = T(0, 0.15, -1.1)
	else -- Flashlight (default)
		tpart(U.Cyl(1.2, 0.36, T(0, 0, -0.3) * U.AxisZ, U.Shade(tc, 0.7), model))
		tpart(U.Cyl(0.38, 0.62, T(0, 0, -1.05) * U.AxisZ, tc, model))
		muzzle = tpart(U.Cyl(0.06, 0.5, T(0, 0, -1.25) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0, -1.3)
	end
	local tip = U.AttachAt(muzzle, "Tip", tipWorld)

	------------------------------------------------------------------ finish
	local top = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			top = math.max(top, U.TopY(d))
		end
	end

	local rig: Rig = {
		Model = model,
		Root = root,
		Motors = motors,
		Tip = tip,
		Height = top,
		HunterId = hunterId,
	}
	HunterRig.Pose(rig, "Idle", 0, 1)
	return rig, decos
end

function HunterRig.Build(hunterId: string): Rig
	local rig = buildInternal(hunterId)
	return rig
end

------------------------------------------------------------------ procedural poses
local sin, cos, abs, max = math.sin, math.cos, math.abs, math.max
local CFn, CFa = CFrame.new, CFrame.Angles
local AIM = math.pi / 6 -- arm pitch that levels the tool (the grip is tilted -30 degrees)

function HunterRig.Pose(rig: Rig, state: string, t: number, blend: number?)
	local b = if blend == nil then 1 else math.clamp(blend, 0, 1)
	local m = rig.Motors
	local torso, head, la, ra, ll, rl = m.Torso, m.Head, m.LeftArm, m.RightArm, m.LeftLeg, m.RightLeg

	if state == "Run" then
		local w = t * 13
		local s = sin(w)
		local lean = -0.22 * b
		local twist = 0.15 * s * b
		torso.Transform = CFn(0, abs(cos(w)) * 0.22 * b, 0) * CFa(lean, twist, 0)
		-- legs cancel the torso lean/twist so they swing from an upright hip
		local legBase = CFa(0, -twist, 0)
		ll.Transform = legBase * CFa(-lean + 0.95 * s * b, 0, 0)
		rl.Transform = legBase * CFa(-lean - 0.95 * s * b, 0, 0)
		la.Transform = CFa(-0.9 * s * b, 0, -0.12 * b)
		ra.Transform = CFa((0.4 + 0.3 * s) * b, 0, 0.1 * b)
		head.Transform = CFa(-lean * 0.6 + 0.05 * cos(2 * w) * b, -twist * 0.7, 0)
	elseif state == "Attack" then
		local ph = (t * 4) % 1
		local p = (1 - ph) * (1 - ph) * (1 - ph) -- recoil pulse, 4 Hz
		local jx = 0.015 * sin(t * 57) * b
		local jy = 0.015 * sin(t * 43) * b
		local lean = (-0.12 + 0.1 * p) * b
		torso.Transform = CFn(jx, jy, 0.06 * p * b) * CFa(lean, 0, 0)
		ll.Transform = CFa(-lean + 0.28 * b, 0, -0.12 * b)
		rl.Transform = CFa(-lean - 0.22 * b, 0, 0.12 * b)
		ra.Transform = CFa((AIM + 0.18 * p) * b - lean, 0, 0.04 * b)
		la.Transform = CFa((1.15 + 0.1 * p) * b - lean, 0, 0.45 * b)
		head.Transform = CFa(0.06 * b - lean * 0.5 + jy, 0, 0)
	elseif state == "Celebrate" then
		local w = t * 3.6
		local j = abs(sin(w))
		torso.Transform = CFn(0, 0.65 * j * b, 0) * CFa(-0.08 * b, 0.5 * sin(t * 2.4) * b, 0)
		ll.Transform = CFa(0.35 * j * b, 0, -0.15 * j * b)
		rl.Transform = CFa(-0.25 * j * b, 0, 0.15 * j * b)
		la.Transform = CFa(0, 0, (-2.5 - 0.25 * sin(t * 8)) * b)
		ra.Transform = CFa(0.2 * b, 0, (1.7 + 0.8 * max(0, sin(t * 7.2))) * b)
		head.Transform = CFa((-0.18 + 0.05 * sin(w * 2)) * b, 0, 0.12 * sin(w) * b)
	else -- Idle
		local br = sin(t * 2.2)
		torso.Transform = CFn(0, 0.03 * br * b, 0) * CFa(0.025 * br * b, 0, 0)
		head.Transform = CFa(0.04 * sin(t * 1.3) * b, 0.15 * sin(t * 0.6) * b, 0.05 * sin(t * 0.9) * b)
		la.Transform = CFa(0.06 * sin(t * 2.2 + 0.6) * b, 0, -(0.12 + 0.04 * br) * b)
		ra.Transform = CFa((0.22 + 0.05 * br) * b, 0, (0.1 + 0.03 * br) * b)
		ll.Transform = CFa(0, 0, -0.04 * b)
		rl.Transform = CFa(0, 0, 0.04 * b)
	end
end

------------------------------------------------------------------ portrait copy
-- Anchored, posed model for ViewportFrames (no physics runs there, so joints are solved here).
function HunterRig.BuildStatic(hunterId: string): Model
	local rig, decos = buildInternal(hunterId)
	HunterRig.Pose(rig, "Idle", 0.45, 1)
	for _, name in JOINT_ORDER do
		local mo = rig.Motors[name]
		local p0, p1 = mo.Part0, mo.Part1
		if p0 and p1 then
			p1.CFrame = p0.CFrame * mo.C0 * mo.Transform * mo.C1:Inverse()
		end
	end
	for b, list in decos do
		for _, d in list do
			d.Part.CFrame = b.CFrame * d.Offset
		end
	end
	for _, d in rig.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return rig.Model
end

return HunterRig
