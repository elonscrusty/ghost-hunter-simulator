--!strict
-- Floating cute-spooky ghosts built from plain Parts (no asset IDs).
--
--   GhostRig.Build(ghostId) -> Model
--
-- PrimaryPart = "Core": an invisible, anchored, queryable Ball covering the body (tap target).
-- Every other part is unanchored, massless, non-queryable and welded to Core, so moving the
-- ghost is just Model:PivotTo(cf). Pivot = Core centre = body centre. Core holds the
-- attachments "Center", "Top" (above the head/hat, for billboards) and "Bottom" (tail tip).
-- Built at scale 1 (body diameter 3.5) and then scaled with Model:ScaleTo(def.Scale).
-- The ghost faces -Z (its LookVector).

local Config = require(script.Parent.Parent.Config)
local U = require(script.Parent.RigUtil)

local GhostRig = {}

local BODY_D = 3.5
local R = BODY_D / 2
local CORE_D = 4.6

local WHITE = Color3.fromRGB(255, 255, 255)
local EYE = Color3.fromRGB(25, 15, 40)
local MOUTH = Color3.fromRGB(70, 20, 50)
local BLUSH = Color3.fromRGB(255, 150, 190)
local GOLD = Color3.fromRGB(255, 205, 60)
local METAL = Color3.fromRGB(120, 125, 145)
local WOOD = Color3.fromRGB(150, 95, 55)

local NEON = { Material = Enum.Material.Neon }

-- point on the body sphere in direction `dir`, pushed `out` studs off the surface
local function surf(dir: Vector3, out: number): Vector3
	return dir.Unit * (R + out)
end

function GhostRig.Build(ghostId: string): Model
	local def = Config.Ghosts[ghostId]
	assert(def, "GhostRig: unknown ghost " .. tostring(ghostId))
	local style = def.Style
	local color = def.Color
	local glow = def.Glow

	local model = Instance.new("Model")
	model.Name = ghostId

	local core = U.Ball(CORE_D, CFrame.identity, glow, model, { Transparency = 1, Name = "Core", Shadow = false })
	core.Anchored = true
	core.CanQuery = true
	core.Massless = false
	model.PrimaryPart = core

	local function add(p: BasePart): BasePart
		U.Weld(core, p)
		return p
	end
	local function ball(d: number, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return add(U.Ball(d, cf, c, model, opts))
	end
	local function block(size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return add(U.Block(size, cf, c, model, opts))
	end
	local function cyl(len: number, d: number, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return add(U.Cyl(len, d, cf, c, model, opts))
	end
	local function wedge(size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return add(U.Wedge(size, cf, c, model, opts))
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end
	-- "▽" open grin (a WedgePart turned to face out of the body)
	local function grin(pos: Vector3, w: number, c: Color3)
		wedge(Vector3.new(0.2, w, w), U.Facing(pos, pos) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, c)
	end
	-- round "O" mouth
	local function oMouth(pos: Vector3, d: number)
		cyl(0.25, d, U.DiscFacing(pos, pos), MOUTH)
	end
	-- slanted eyebrow over an eye (s = -1 left, 1 right); angry = inner end down
	local function brow(s: number, y: number, angry: boolean, c: Color3, w: number)
		local pos = surf(Vector3.new(0.6 * s, y, -1.38), 0.08)
		local tilt = if angry then 0.35 * s else -0.25 * s
		block(Vector3.new(w, 0.18, 0.2), U.Facing(pos, pos) * CFrame.Angles(0, 0, tilt), c)
	end

	local bodyOpts = { Transparency = 0.12, Shadow = false }

	------------------------------------------------------------------ body + tail
	ball(BODY_D, CFrame.identity, color, { Transparency = 0.12, Shadow = true })
	ball(2.3, CFrame.identity, glow, { Material = Enum.Material.Neon, Transparency = 0.55 }) -- inner glow core
	ball(2.7, at(0, -0.95, 0.45), color, bodyOpts)
	ball(2.0, at(0.15, -1.75, 0.95), color, bodyOpts)
	ball(1.35, at(-0.05, -2.35, 1.45), color, bodyOpts)
	ball(0.8, at(0.2, -2.7, 1.9), color, bodyOpts)

	------------------------------------------------------------------ face
	local eyeColor = if style == "Student" then glow else EYE
	local eyeOpts: U.Opts? = if style == "Student" then NEON else nil
	if style == "Crypt" then
		-- one big eye peeking out between the bandages
		local p = Vector3.new(0, 0.38, -1.45)
		ball(1.15, CFrame.new(p), EYE)
		ball(0.4, CFrame.new(p + Vector3.new(0.2, 0.22, -0.4)), WHITE)
	else
		for _, s in { -1, 1 } do
			local p = Vector3.new(0.6 * s, 0.35, -1.38)
			ball(0.9, CFrame.new(p), eyeColor, eyeOpts)
			ball(0.32, CFrame.new(p + Vector3.new(0.16, 0.18, -0.3)), WHITE)
		end
	end
	local mouthPos = surf(Vector3.new(0, -0.45, -1.65), -0.02)
	if style == "Mischief" or style == "Hallway" or style == "Headmaster" then
		grin(mouthPos, 0.5, MOUTH)
	elseif style == "Giant" then
		grin(mouthPos, 0.85, MOUTH)
	else
		oMouth(mouthPos, if style == "Poltergeist" then 0.75 else 0.6)
	end
	-- nub arms
	for _, s in { -1, 1 } do
		ball(0.95, at(1.7 * s, -0.35, -0.2), color, bodyOpts)
	end
	-- blush (the Giant is too angry to blush)
	if style ~= "Giant" then
		for _, s in { -1, 1 } do
			ball(0.4, at(1.0 * s, -0.12, -1.45), BLUSH)
		end
	end

	------------------------------------------------------------------ styles
	if style == "Mischief" then
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.3, 0.85, 0.5), at(0.8 * s, 1.6, -0.1) * CFrame.Angles(0, 0, -0.35 * s), glow, NEON) -- devil horns
			brow(s, 0.98, false, U.Shade(color, 0.45), 0.6)
		end
		local tongue = mouthPos + Vector3.new(0.12, -0.3, -0.05)
		ball(0.42, CFrame.new(tongue), Color3.fromRGB(255, 90, 130))
		wedge(Vector3.new(0.15, 0.5, 0.45), at(0.25, -2.95, 2.25) * CFrame.Angles(-0.6, 0, 0), glow, NEON) -- spade tail tip
	elseif style == "Poltergeist" then
		-- crown of green flames
		for i = 0, 3 do
			local a = math.pi / 4 + i * math.pi / 2
			wedge(Vector3.new(0.35, 1.0, 0.6), CFrame.Angles(0, a, 0) * at(0, 1.95, -0.7) * CFrame.Angles(-0.35, 0, 0), glow, { Material = Enum.Material.Neon, Transparency = 0.1 })
		end
		-- floating household junk
		cyl(0.12, 1.1, CFrame.Angles(0, 0.6, 0) * at(0, 0.6, -2.7) * CFrame.Angles(0.5, 0, 0.3) * U.AxisY, WHITE) -- plate
		block(Vector3.new(0.9, 1.0, 0.15), CFrame.Angles(0, 2.6, 0) * at(0, -0.2, -2.8) * CFrame.Angles(0.3, 0, 0.4), WOOD) -- chair back
		block(Vector3.new(0.75, 0.25, 0.95), CFrame.Angles(0, 4.4, 0) * at(0, 0.9, -2.7) * CFrame.Angles(0.2, 0.5, -0.3), Color3.fromRGB(230, 80, 90)) -- book
	elseif style == "Grave" then
		local t = at(0.3, 1.62, 0.1) * CFrame.Angles(0, 0, -0.18)
		local stone = Color3.fromRGB(150, 150, 168)
		block(Vector3.new(1.0, 0.9, 0.32), t * at(0, 0.45, 0), stone)
		cyl(0.32, 1.0, t * at(0, 0.9, 0) * U.AxisZ, stone)
		local moss = Color3.fromRGB(90, 190, 90)
		ball(0.45, t * at(-0.38, 0.12, -0.1), moss)
		ball(0.7, at(-0.85, 1.35, 0.3), moss)
	elseif style == "Crypt" then
		local wrap = U.Shade(color, 0.85)
		local function band(tilt: number, offset: number, center: Vector3, radius: number)
			cyl(0.3, radius * 2 + 0.12, CFrame.new(center) * CFrame.Angles(0, 0, tilt) * at(0, offset, 0) * U.AxisY, wrap)
		end
		band(0.2, 1.15, Vector3.zero, math.sqrt(R * R - 1.15 * 1.15))
		band(-0.12, -1.05, Vector3.new(0, 0, 0.2), 1.55)
		band(0.15, 0, Vector3.new(-0.05, -2.35, 1.45), 0.68)
		ball(0.42, CFrame.new(surf(Vector3.new(0, -1.25, -1.2), 0.02)), glow, NEON) -- amber amulet
	elseif style == "Warden" then
		local hood = Color3.fromRGB(70, 50, 120)
		ball(3.1, at(0, 0.6, 0.45), hood)
		wedge(Vector3.new(0.6, 1.1, 1.0), at(0, 2.05, 0.95) * CFrame.Angles(-0.4, 0, 0), hood)
		-- lantern hanging from the right nub
		cyl(0.2, 0.7, at(1.95, -0.75, -0.45) * U.AxisY, METAL, { Material = Enum.Material.Metal })
		block(Vector3.new(0.65, 0.75, 0.65), at(1.95, -1.25, -0.45), Color3.fromRGB(210, 220, 230), { Transparency = 0.45 })
		local flame = ball(0.45, at(1.95, -1.25, -0.45), glow, NEON)
		local pl = Instance.new("PointLight")
		pl.Color = glow
		pl.Range = 8
		pl.Brightness = 1
		pl.Parent = flame
		-- chain + weight from the left nub
		cyl(0.12, 0.45, at(-1.85, -0.78, -0.25), METAL, { Material = Enum.Material.Metal })
		cyl(0.12, 0.45, at(-1.88, -1.12, -0.25) * U.AxisZ, METAL, { Material = Enum.Material.Metal })
		cyl(0.12, 0.45, at(-1.91, -1.46, -0.25), METAL, { Material = Enum.Material.Metal })
		ball(0.65, at(-1.93, -1.9, -0.25), Color3.fromRGB(60, 60, 75), { Material = Enum.Material.Metal })
	elseif style == "Hallway" then
		local frame = Color3.fromRGB(230, 60, 70)
		for _, s in { -1, 1 } do
			local eye = Vector3.new(0.6 * s, 0.35, -1.38)
			cyl(0.08, 1.15, U.DiscFacing(surf(eye, 0.07), eye), frame)
		end
		block(Vector3.new(0.35, 0.09, 0.09), CFrame.new(0, 0.42, -1.78), frame)
		-- lanyard cord + hall pass
		local cordY = -0.85
		cyl(0.1, 2 * math.sqrt(R * R - cordY * cordY) + 0.08, at(0, cordY, 0) * U.AxisY, Color3.fromRGB(60, 120, 255))
		local passPos = surf(Vector3.new(0, -1.2, -1.3), 0.04)
		local f = U.Facing(passPos, passPos)
		block(Vector3.new(0.75, 0.95, 0.08), f, Color3.fromRGB(250, 250, 240))
		block(Vector3.new(0.75, 0.28, 0.1), f * at(0, 0.3, 0), glow, NEON)
	elseif style == "Student" then
		local capColor = Color3.fromRGB(60, 90, 200)
		ball(2.5, at(0, 1.15, 0.2), capColor)
		cyl(0.12, 1.7, at(0, 1.5, -1.35) * CFrame.Angles(-0.1, 0, 0) * U.AxisY, U.Shade(capColor, 0.8))
		local bag = Color3.fromRGB(230, 80, 80)
		block(Vector3.new(1.7, 1.8, 0.8), at(0, -0.1, 1.65), bag)
		block(Vector3.new(1.2, 0.7, 0.3), at(0, -0.5, 2.1), U.Shade(bag, 0.8))
		local bookCf = at(-1.95, -0.35, -0.5) * CFrame.Angles(0, 0.3, 0.15)
		block(Vector3.new(0.32, 1.1, 0.85), bookCf, Color3.fromRGB(90, 200, 120))
		block(Vector3.new(0.26, 1.0, 0.85), bookCf * at(0, 0, -0.04), WHITE)
	elseif style == "Headmaster" then
		local dark = Color3.fromRGB(35, 30, 50)
		cyl(0.5, 2.2, at(0, 1.65, 0.1) * U.AxisY, dark)
		block(Vector3.new(2.9, 0.15, 2.9), at(0, 1.95, 0.1) * CFrame.Angles(0, math.pi / 4, 0), dark)
		block(Vector3.new(0.12, 0.8, 0.12), at(1.98, 1.55, 0.1), glow, NEON) -- tassel
		-- monocle on the right eye + its chain
		local eye = Vector3.new(0.6, 0.35, -1.38)
		cyl(0.08, 1.2, U.DiscFacing(surf(eye, 0.08), eye), GOLD, { Material = Enum.Material.Metal })
		block(Vector3.new(0.06, 0.9, 0.06), CFrame.new(surf(Vector3.new(1.0, -0.2, -1.4), 0.06)) * CFrame.Angles(0, 0, 0.25), GOLD)
		-- handlebar mustache
		for _, s in { -1, 1 } do
			local pos = surf(Vector3.new(0.35 * s, -0.18, -1.65), 0.04)
			wedge(Vector3.new(0.18, 0.35, 0.7), U.Facing(pos, pos) * CFrame.Angles(0, 0, 0.15 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), Color3.fromRGB(70, 55, 80))
		end
		-- pointer stick from the right nub
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.35, 0.75, -0.55).Unit
		local mid = hand + dir * 1.3
		cyl(3.2, 0.14, CFrame.lookAt(mid, mid + dir) * U.AxisZ, WOOD)
		ball(0.3, CFrame.new(hand + dir * 2.95), glow, NEON)
	elseif style == "Giant" then
		-- crown
		cyl(0.6, 1.9, at(0, 1.75, 0.05) * U.AxisY, GOLD, { Material = Enum.Material.Metal })
		for i = 0, 2 do
			wedge(Vector3.new(0.3, 0.75, 0.45), CFrame.Angles(0, i * math.pi * 2 / 3, 0) * at(0, 2.4, -0.78), glow, NEON)
		end
		for _, s in { -1, 1 } do
			brow(s, 1.0, true, Color3.fromRGB(60, 20, 60), 0.85)
		end
		-- sharp teeth hanging from the top of the grin
		for _, s in { -1, 1 } do
			local pos = surf(Vector3.new(0.18 * s, -0.42, -1.7), 0.08)
			wedge(Vector3.new(0.08, 0.22, 0.22), U.Facing(pos, pos) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, WHITE)
		end
		-- orbiting junk
		cyl(0.12, 1.2, CFrame.Angles(0, 0.4, 0) * at(0, 0.5, -3.0) * CFrame.Angles(0.6, 0, 0.2) * U.AxisY, WHITE)
		block(Vector3.new(0.9, 1.0, 0.15), CFrame.Angles(0, 2.0, 0) * at(0, -0.3, -3.0) * CFrame.Angles(0.3, 0, 0.5), WOOD)
		block(Vector3.new(0.75, 0.25, 0.95), CFrame.Angles(0, 3.4, 0) * at(0, 0.9, -3.0) * CFrame.Angles(0.2, 0.5, -0.3), Color3.fromRGB(90, 130, 255))
	else -- Plain: a little wisp curl on top
		ball(0.6, at(0.1, 1.85, 0.1), color, bodyOpts)
		ball(0.35, at(0.35, 2.15, 0.22), color, bodyOpts)
	end

	------------------------------------------------------------------ attachments, glow, light
	local top, bottom = R, -R
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= core then
			top = math.max(top, U.TopY(d))
			bottom = math.min(bottom, U.BottomY(d))
		end
	end
	U.AttachAt(core, "Center", CFrame.identity)
	U.AttachAt(core, "Top", CFrame.new(0, top + 0.3, 0))
	U.AttachAt(core, "Bottom", CFrame.new(0, bottom, 0))

	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Aura"
	pe.Color = ColorSequence.new(glow)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Rate = 4
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Speed = NumberRange.new(0.3, 0.8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-30, 30)
	pe.Parent = core

	if def.Kind == "MiniBoss" or def.Kind == "Boss" or def.Kind == "Event" then
		local light = Instance.new("PointLight")
		light.Name = "BossLight"
		light.Color = glow
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = core
	end

	if def.Scale ~= 1 then
		model:ScaleTo(def.Scale)
	end
	return model
end

return GhostRig
