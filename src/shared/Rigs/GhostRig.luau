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
-- The spooky glow comes from the body colour, glowing eyes/flames
-- where a style has them and the "Aura" ParticleEmitter; horns, stripes, tassels and crown
-- spikes are solid (vivid glow colour) so big ghosts don't turn into neon blobs.
-- Neon accessories are limited to small meaningful bits: glowing eyes of the spooky styles,
-- flames, gems, crystal tips, runes and cracks. Bosses get a stronger Aura than normal ghosts.

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
local RED = Color3.fromRGB(235, 55, 70)
local CREAM = Color3.fromRGB(255, 244, 220)
local DARK = Color3.fromRGB(38, 32, 55)
local NAVY = Color3.fromRGB(40, 55, 125)
local STONE = Color3.fromRGB(150, 150, 168)
local BEARD = Color3.fromRGB(242, 242, 236)

local NEON = { Material = Enum.Material.Neon }
local METAL_MAT = { Material = Enum.Material.Metal }

-- styles whose eyes glow (Neon in the glow colour) instead of the usual dark cartoon eyes
local GLOW_EYES = { Student = true, Ancient = true, Void = true, Overlord = true }
-- styles with the open "▽" grin instead of the round "O" mouth
local GRIN = {
	Mischief = true, Hallway = true, Headmaster = true, Carnival = true, Ringmaster = true,
	Pirate = true, Captain = true, King = true, Overlord = true,
}
-- spooky styles that don't blush
local NO_BLUSH = { Giant = true, Void = true, Overlord = true }

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
	local accent = U.Vivid(glow) -- solid accessories in the glow colour

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
	local function grin(pos: Vector3, w: number, c: Color3, opts: U.Opts?)
		wedge(Vector3.new(0.2, w, w), U.Facing(pos, pos) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, c, opts)
	end
	-- straight rod between two points
	local function rod(a: Vector3, b: Vector3, d: number, c: Color3, opts: U.Opts?): BasePart
		return cyl((b - a).Magnitude, d, U.Between(a, b), c, opts)
	end
	-- band hugging the body sphere at height y (tilt rolls it around Z)
	local function ring(y: number, thick: number, c: Color3, opts: U.Opts?, tilt: number?)
		local r = math.sqrt(math.max(R * R - y * y, 0.05))
		cyl(thick, r * 2 + 0.12, CFrame.Angles(0, 0, tilt or 0) * at(0, y, 0) * U.AxisY, c, opts)
	end
	-- ruffled collar: n balls round the body at height y, alternating two colours
	local function ruff(y: number, n: number, d: number, c1: Color3, c2: Color3)
		local r = math.sqrt(R * R - y * y) + 0.05
		for i = 0, n - 1 do
			local a = (i + 0.5) * 2 * math.pi / n
			ball(d, at(math.sin(a) * r, y, -math.cos(a) * r), if i % 2 == 0 then c1 else c2)
		end
	end
	-- stepped cone standing on `base` (along its +Y); returns the frame at the tip
	local function cone(base: CFrame, d: number, h: number, tiers: number, c1: Color3, c2: Color3?): CFrame
		local th = h / tiers
		for i = 0, tiers - 1 do
			local c = if c2 and i % 2 == 1 then c2 else c1
			cyl(th * 1.05, d * (tiers - i) / tiers, base * at(0, th * (i + 0.5), 0) * U.AxisY, c)
		end
		return base * at(0, h, 0)
	end
	-- crystal: diamond prism along the frame's Y with pointed tip (and optional pointed bottom)
	local function crystal(cf: CFrame, w: number, h: number, c: Color3, opts: U.Opts?, tipC: Color3, tipOpts: U.Opts?, both: boolean)
		block(Vector3.new(w, h, w), cf * CFrame.Angles(0, math.pi / 4, 0), c, opts)
		block(Vector3.new(w, w, w), cf * at(0, h / 2, 0) * U.VertexUp, tipC, tipOpts)
		if both then
			block(Vector3.new(w, w, w), cf * at(0, -h / 2, 0) * U.VertexUp, tipC, tipOpts)
		end
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

	-- Opaque body: see-through layered parts (body over a glowing inner core, overlapping tail
	-- balls) flicker on moving models because the engine re-sorts transparent parts every frame.
	local bodyOpts = { Shadow = false }

	------------------------------------------------------------------ body + tail
	ball(BODY_D, CFrame.identity, color, { Shadow = true })
	ball(2.7, at(0, -0.95, 0.45), color, bodyOpts)
	ball(2.0, at(0.15, -1.75, 0.95), color, bodyOpts)
	ball(1.35, at(-0.05, -2.35, 1.45), color, bodyOpts)
	ball(0.8, at(0.2, -2.7, 1.9), color, bodyOpts)

	------------------------------------------------------------------ face
	local glowEyes = GLOW_EYES[style] == true
	local eyeColor = if glowEyes then glow else EYE
	local eyeOpts: U.Opts? = if glowEyes then NEON else nil
	if style == "Crypt" then
		-- one big eye peeking out between the bandages
		local p = Vector3.new(0, 0.38, -1.45)
		ball(1.15, CFrame.new(p), EYE)
		ball(0.4, CFrame.new(p + Vector3.new(0.2, 0.22, -0.4)), WHITE)
	else
		for _, s in { -1, 1 } do
			if style == "Pirate" and s < 0 then
				continue -- the eyepatch goes here
			end
			local p = Vector3.new(0.6 * s, 0.35, -1.38)
			ball(0.9, CFrame.new(p), eyeColor, eyeOpts)
			ball(0.32, CFrame.new(p + Vector3.new(0.16, 0.18, -0.3)), WHITE)
		end
	end
	local mouthPos = surf(Vector3.new(0, -0.45, -1.65), -0.02)
	if style == "Doctor" then
		-- the surgical mask covers the mouth
	elseif style == "Void" then
		grin(mouthPos, 0.55, glow, NEON)
	elseif style == "Clown" then
		grin(mouthPos, 0.75, MOUTH)
	elseif style == "Giant" then
		grin(mouthPos, 0.85, MOUTH)
	elseif GRIN[style] then
		grin(mouthPos, if def.Kind == "Boss" then 0.6 else 0.5, MOUTH)
	else
		oMouth(mouthPos, if style == "Poltergeist" then 0.75 else 0.6)
	end
	-- nub arms
	for _, s in { -1, 1 } do
		ball(0.95, at(1.7 * s, -0.35, -0.2), color, bodyOpts)
	end
	-- blush (the Giant and the void spirits are too spooky to blush)
	if not NO_BLUSH[style] then
		for _, s in { -1, 1 } do
			ball(0.4, at(1.0 * s, -0.12, -1.45), BLUSH)
		end
	end

	------------------------------------------------------------------ styles
	if style == "Mischief" then
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.3, 0.85, 0.5), at(0.8 * s, 1.6, -0.1) * CFrame.Angles(0, 0, -0.35 * s), accent) -- devil horns
			brow(s, 0.98, false, U.Shade(color, 0.45), 0.6)
		end
		local tongue = mouthPos + Vector3.new(0.12, -0.3, -0.05)
		ball(0.42, CFrame.new(tongue), Color3.fromRGB(255, 90, 130))
		wedge(Vector3.new(0.15, 0.5, 0.45), at(0.25, -2.95, 2.25) * CFrame.Angles(-0.6, 0, 0), accent) -- spade tail tip
	elseif style == "Poltergeist" then
		-- crown of green flames
		for i = 0, 3 do
			local a = math.pi / 4 + i * math.pi / 2
			wedge(Vector3.new(0.35, 1.0, 0.6), CFrame.Angles(0, a, 0) * at(0, 1.95, -0.7) * CFrame.Angles(-0.35, 0, 0), glow, { Material = Enum.Material.Neon })
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
		block(Vector3.new(0.65, 0.75, 0.65), at(1.95, -1.25, -0.45), Color3.fromRGB(210, 220, 230))
		ball(0.8, at(1.95, -1.25, -0.45), glow, NEON) -- flame (no PointLight: moving lights flicker)
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
		block(Vector3.new(0.75, 0.28, 0.1), f * at(0, 0.3, 0), accent)
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
		block(Vector3.new(0.12, 0.8, 0.12), at(1.98, 1.55, 0.1), accent) -- tassel
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
			wedge(Vector3.new(0.3, 0.75, 0.45), CFrame.Angles(0, i * math.pi * 2 / 3, 0) * at(0, 2.4, -0.78), accent)
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
	elseif style == "Carnival" then
		-- striped party hat with a pompom
		local tip = cone(at(0.3, 1.4, 0.1) * CFrame.Angles(0, 0, -0.28), 1.35, 1.55, 4, accent, CREAM)
		ball(0.5, tip, Color3.fromRGB(255, 110, 190))
		-- balloon on a string from the left nub
		local hand = Vector3.new(-1.95, -0.35, -0.25)
		local knot = Vector3.new(-2.45, 1.45, 0.05)
		rod(hand, knot, 0.06, WHITE)
		ball(0.22, CFrame.new(knot), RED)
		local bc = knot + Vector3.new(-0.08, 0.68, 0)
		ball(1.2, CFrame.new(bc), RED)
		ball(0.28, CFrame.new(bc + Vector3.new(0.2, 0.25, -0.45)), WHITE) -- shine
	elseif style == "Clown" then
		ball(0.62, CFrame.new(surf(Vector3.new(0, -0.02, -1), 0.14)), RED, { Reflectance = 0.1 }) -- round nose
		local tuft = Color3.fromRGB(255, 140, 40)
		for _, s in { -1, 1 } do
			ball(0.95, at(1.35 * s, 0.95, 0.35), accent)
			ball(0.8, at(1.62 * s, 0.4, 0.5), tuft)
			ball(0.7, at(1.05 * s, 1.4, 0.6), tuft)
		end
		ruff(-1.05, 10, 0.6, accent, GOLD)
	elseif style == "Ringmaster" then
		-- tall top hat
		local hatC = Color3.fromRGB(40, 30, 55)
		local hcf = at(0, 1.5, 0.1) * CFrame.Angles(-0.08, 0, 0.08)
		cyl(0.16, 2.7, hcf * U.AxisY, hatC) -- brim
		cyl(1.5, 1.75, hcf * at(0, 0.8, 0) * U.AxisY, hatC)
		cyl(0.36, 1.8, hcf * at(0, 0.28, 0) * U.AxisY, GOLD, METAL_MAT) -- band
		ball(0.42, hcf * at(0, 0.3, -0.86), RED) -- rosette
		-- red tailcoat flaps behind
		local coat = Color3.fromRGB(140, 25, 45)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.7, 1.7, 0.18), at(0.5 * s, -1.6, 2.02) * CFrame.Angles(-0.3, 0, 0.12 * s), coat)
		end
		ball(0.28, CFrame.new(surf(Vector3.new(0, -1.4, -1.05), 0.02)), GOLD, METAL_MAT) -- coat button
		-- bow tie
		local bp = surf(Vector3.new(0, -0.95, -1.45), 0.06)
		local bf = U.Facing(bp, bp)
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.12, 0.38, 0.32), bf * at(0.17 * s, 0, 0) * CFrame.Angles(0, math.pi / 2 * s, 0), DARK)
		end
		ball(0.2, bf, DARK)
		-- curly mustache + raised brows
		local stache = Color3.fromRGB(55, 30, 40)
		for _, s in { -1, 1 } do
			local pos = surf(Vector3.new(0.36 * s, -0.2, -1.65), 0.05)
			wedge(Vector3.new(0.18, 0.32, 0.65), U.Facing(pos, pos) * CFrame.Angles(0, 0, 0.15 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), stache)
			ball(0.3, CFrame.new(surf(Vector3.new(0.75 * s, -0.05, -1.5), 0.08)), stache) -- curl
			brow(s, 0.98, false, stache, 0.6)
		end
		-- ringmaster's baton in the right nub
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.35, 0.65, -0.65).Unit
		rod(hand - dir * 0.2, hand + dir * 2.0, 0.16, DARK)
		ball(0.3, CFrame.new(hand + dir * 2.05), GOLD, METAL_MAT)
		ball(0.26, CFrame.new(hand - dir * 0.25), GOLD, METAL_MAT)
	elseif style == "Patient" then
		-- bandage wrapped round the head, knotted at the side
		local wrap = Color3.fromRGB(250, 248, 240)
		ring(1.12, 0.4, wrap, nil, 0.15)
		ball(0.45, at(1.3, 1.32, 0.1), wrap)
		block(Vector3.new(0.2, 0.5, 0.08), at(1.55, 1.05, 0.05) * CFrame.Angles(0, 0, 0.5), wrap)
		block(Vector3.new(0.2, 0.45, 0.08), at(1.5, 1.02, 0.3) * CFrame.Angles(0, 0, 0.2), wrap)
		-- hospital wristband on the left nub
		cyl(0.22, 0.86, at(-1.98, -0.38, -0.2), WHITE)
		block(Vector3.new(0.24, 0.1, 0.3), at(-1.98, 0.06, -0.2), Color3.fromRGB(120, 200, 255))
		-- tiny teddy bear hugged in the right nub
		local bear = Color3.fromRGB(195, 135, 85)
		local tb = Vector3.new(2.0, -0.85, -0.7)
		ball(0.75, CFrame.new(tb), bear)
		ball(0.62, CFrame.new(tb + Vector3.new(0, 0.6, 0)), bear)
		for _, s in { -1, 1 } do
			ball(0.24, CFrame.new(tb + Vector3.new(0.24 * s, 0.88, 0.02)), bear)
			ball(0.1, CFrame.new(tb + Vector3.new(0.11 * s, 0.68, -0.28)), EYE)
		end
		ball(0.24, CFrame.new(tb + Vector3.new(0, 0.53, -0.28)), CREAM) -- snout
	elseif style == "Doctor" then
		-- head mirror on a band
		ring(1.05, 0.18, Color3.fromRGB(70, 75, 95))
		local md = Vector3.new(0.4, 1.05, -1.33)
		cyl(0.1, 0.95, U.DiscFacing(surf(md, 0.08), md), Color3.fromRGB(225, 230, 240), { Material = Enum.Material.Metal, Reflectance = 0.35 })
		cyl(0.14, 0.22, U.DiscFacing(surf(md, 0.1), md), DARK)
		-- surgical mask over the mouth
		local mp = surf(Vector3.new(0, -0.5, -1.62), -0.06)
		local mf = U.Facing(mp, mp)
		local maskC = Color3.fromRGB(150, 215, 235)
		block(Vector3.new(1.45, 0.8, 0.14), mf, maskC)
		for _, y in { 0.15, -0.12 } do
			block(Vector3.new(1.3, 0.05, 0.16), mf * at(0, y, 0), U.Shade(maskC, 0.85)) -- pleats
		end
		for _, s in { -1, 1 } do
			rod((mf * at(0.7 * s, 0.25, 0)).Position, surf(Vector3.new(1.0 * s, 0.15, -0.9), 0.03), 0.06, WHITE) -- ear loops
		end
		-- clipboard in the left nub
		local cb = at(-2.05, -0.6, -0.6) * CFrame.Angles(0.15, 0.55, 0.1)
		block(Vector3.new(0.95, 1.25, 0.1), cb, WOOD)
		block(Vector3.new(0.8, 0.95, 0.04), cb * at(0, -0.08, -0.06), WHITE)
		block(Vector3.new(0.42, 0.14, 0.1), cb * at(0, 0.58, -0.07), METAL, METAL_MAT)
		for i = 0, 1 do
			block(Vector3.new(0.55, 0.05, 0.03), cb * at(-0.05, 0.12 - i * 0.22, -0.09), accent)
		end
	elseif style == "Director" then
		-- glasses + stern brows
		local frameC = Color3.fromRGB(45, 40, 60)
		for _, s in { -1, 1 } do
			local eye = Vector3.new(0.6 * s, 0.35, -1.38)
			cyl(0.08, 1.15, U.DiscFacing(surf(eye, 0.07), eye), frameC)
			brow(s, 1.02, true, frameC, 0.55)
		end
		block(Vector3.new(0.35, 0.09, 0.09), CFrame.new(0, 0.42, -1.78), frameC)
		-- white coat: collar + lapels
		ring(-0.85, 0.26, WHITE)
		for _, s in { -1, 1 } do
			local lp = surf(Vector3.new(0.5 * s, -1.15, -1.25), 0.02)
			block(Vector3.new(0.55, 1.2, 0.12), U.Facing(lp, lp) * CFrame.Angles(0, 0, -0.4 * s), WHITE)
		end
		-- necktie
		local tieC = Color3.fromRGB(175, 35, 60)
		local tp = surf(Vector3.new(0, -0.95, -1.45), 0.06)
		block(Vector3.new(0.3, 0.26, 0.12), U.Facing(tp, tp), tieC)
		local tbp = surf(Vector3.new(0, -1.35, -1.12), 0.04)
		local tbf = U.Facing(tbp, tbp)
		block(Vector3.new(0.34, 0.7, 0.1), tbf, tieC)
		block(Vector3.new(0.25, 0.25, 0.1), tbf * at(0, -0.36, 0) * CFrame.Angles(0, 0, math.pi / 4), tieC)
		-- stethoscope round the neck
		local tube = Color3.fromRGB(60, 60, 75)
		local chest = surf(Vector3.new(0.75, -1.4, -0.85), 0.08)
		rod(surf(Vector3.new(-1.3, -0.6, -1.0), 0.04), surf(Vector3.new(-0.8, -1.35, -0.95), 0.06), 0.1, tube)
		rod(surf(Vector3.new(1.3, -0.6, -1.0), 0.04), chest, 0.1, tube)
		cyl(0.14, 0.42, U.DiscFacing(chest, chest), METAL, METAL_MAT)
		-- gold name badge
		local nb = surf(Vector3.new(-0.95, -0.85, -1.2), 0.02)
		block(Vector3.new(0.45, 0.22, 0.06), U.Facing(nb, nb), GOLD, METAL_MAT)
		-- big clipboard in the right nub
		local cb = at(2.15, -0.55, -0.6) * CFrame.Angles(0.12, -0.55, -0.1)
		block(Vector3.new(1.2, 1.6, 0.12), cb, WOOD)
		block(Vector3.new(1.02, 1.25, 0.04), cb * at(0, -0.1, -0.07), WHITE)
		block(Vector3.new(0.5, 0.16, 0.12), cb * at(0, 0.75, -0.08), GOLD, METAL_MAT)
		for i = 0, 2 do
			block(Vector3.new(0.7, 0.06, 0.03), cb * at(-0.05, 0.25 - i * 0.25, -0.1), accent)
		end
	elseif style == "Sailor" then
		-- white sailor cap with a navy stripe
		local hcf = at(0.2, 1.55, 0.1) * CFrame.Angles(0.1, 0, -0.18)
		cyl(0.6, 1.75, hcf * at(0, 0.3, 0) * U.AxisY, WHITE)
		cyl(0.28, 2.15, hcf * U.AxisY, WHITE) -- turned-up brim
		cyl(0.08, 2.19, hcf * at(0, 0.06, 0) * U.AxisY, NAVY)
		-- navy sailor collar behind, red neckerchief in front
		block(Vector3.new(1.9, 0.95, 0.12), at(0, -0.7, 1.86), NAVY)
		block(Vector3.new(1.9, 0.1, 0.14), at(0, -1.0, 1.86), WHITE)
		local np = surf(Vector3.new(0, -0.95, -1.45), 0.02)
		block(Vector3.new(0.55, 0.55, 0.08), U.Facing(np, np) * at(0, -0.22, 0) * CFrame.Angles(0, 0, math.pi / 4), RED)
		ball(0.36, CFrame.new(np + np.Unit * 0.08), RED)
		-- small anchor in the left nub
		local ac = at(-2.1, -0.85, -0.5) * CFrame.Angles(0, 0.4, 0.15)
		local anc = Color3.fromRGB(70, 85, 115)
		block(Vector3.new(0.16, 1.1, 0.14), ac, anc, METAL_MAT)
		cyl(0.12, 0.38, ac * at(0, 0.66, 0) * U.AxisZ, anc, METAL_MAT)
		block(Vector3.new(0.7, 0.13, 0.13), ac * at(0, 0.3, 0), anc, METAL_MAT)
		block(Vector3.new(0.9, 0.14, 0.14), ac * at(0, -0.5, 0), anc, METAL_MAT)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.14, 0.36, 0.14), ac * at(0.45 * s, -0.38, 0) * CFrame.Angles(0, 0, -0.45 * s), anc, METAL_MAT)
		end
	elseif style == "Pirate" then
		-- polka-dot bandana knotted at the back
		local band = Color3.fromRGB(220, 50, 60)
		local bc = Vector3.new(0, 1.0, 0.2)
		ball(2.9, CFrame.new(bc), band)
		for _, d in { Vector3.new(-0.55, 0.55, -0.65), Vector3.new(0.5, 0.75, -0.45), Vector3.new(0.05, 0.95, 0.3), Vector3.new(-0.8, 0.6, 0.35) } do
			ball(0.3, CFrame.new(bc + d.Unit * 1.42), WHITE)
		end
		ball(0.5, at(0.3, 1.05, 1.6), band)
		block(Vector3.new(0.26, 0.7, 0.1), at(0.15, 0.6, 1.72) * CFrame.Angles(0.25, 0, 0.3), band)
		block(Vector3.new(0.26, 0.6, 0.1), at(0.5, 0.65, 1.68) * CFrame.Angles(0.25, 0, -0.35), band)
		-- eyepatch over the left eye (no eye is built there)
		local le = Vector3.new(-0.6, 0.35, -1.38)
		local pc = surf(le, 0.04)
		cyl(0.12, 0.85, U.DiscFacing(pc, le), DARK)
		rod(surf(Vector3.new(0.1, 1.0, -1.4), 0.03), pc, 0.07, DARK)
		rod(pc, surf(Vector3.new(-1.45, -0.1, -0.95), 0.03), 0.07, DARK)
		-- hook hand on the right nub
		local hook = Color3.fromRGB(190, 195, 210)
		cyl(0.3, 0.55, at(1.98, -0.38, -0.2), DARK) -- cuff
		local pts = {
			Vector3.new(2.1, -0.38, -0.2),
			Vector3.new(2.5, -0.38, -0.3),
			Vector3.new(2.72, -0.62, -0.35),
			Vector3.new(2.62, -0.9, -0.35),
			Vector3.new(2.38, -0.88, -0.33),
		}
		for i = 1, #pts - 1 do
			rod(pts[i], pts[i + 1], 0.12, hook, METAL_MAT)
		end
		-- gold earring
		local ep = surf(Vector3.new(1.0, -0.05, -0.2), 0.0)
		rod(ep, ep + Vector3.new(0.06, -0.2, 0), 0.06, GOLD, METAL_MAT)
		ball(0.3, CFrame.new(ep + Vector3.new(0.08, -0.32, 0)), GOLD, METAL_MAT)
	elseif style == "Captain" then
		-- big tricorn with a gold trim and a skull emblem
		local hatC = Color3.fromRGB(30, 35, 62)
		local hcf = at(0, 1.5, 0.1)
		cyl(0.9, 2.0, hcf * at(0, 0.4, 0) * U.AxisY, hatC)
		for i = 0, 2 do
			local side = hcf * CFrame.Angles(0, i * 2 * math.pi / 3, 0) * at(0, 0.3, -0.95) * CFrame.Angles(-0.45, 0, 0)
			block(Vector3.new(3.3, 0.75, 0.16), side, hatC)
			block(Vector3.new(3.3, 0.12, 0.22), side * at(0, 0.38, 0), GOLD, METAL_MAT)
		end
		local front = hcf * at(0, 0.3, -0.95) * CFrame.Angles(-0.45, 0, 0)
		ball(0.55, front * at(0, 0.02, -0.15), WHITE)
		for _, s in { -1, 1 } do
			ball(0.14, front * at(0.11 * s, 0.05, -0.4), EYE)
			block(Vector3.new(0.75, 0.1, 0.06), front * at(0, -0.02, -0.1) * CFrame.Angles(0, 0, 0.6 * s), WHITE) -- crossbones
			brow(s, 1.0, false, Color3.fromRGB(60, 55, 80), 0.55)
		end
		-- bushy beard
		ball(1.6, at(0, -1.25, -1.1), BEARD)
		for _, s in { -1, 1 } do
			ball(1.15, at(0.6 * s, -1.05, -1.15), BEARD)
		end
		-- captain's coat collar + gold epaulettes
		for _, s in { -1, 1 } do
			local cp = surf(Vector3.new(0.55 * s, -0.25, 0.85), 0.08)
			block(Vector3.new(1.1, 1.0, 0.14), U.Facing(cp, cp), hatC)
			cyl(0.2, 0.85, at(1.62 * s, 0.15, -0.2) * U.AxisY, GOLD, METAL_MAT)
		end
		-- ship's wheel on the back
		local wc = at(0, -0.15, 2.4)
		for i = 0, 7 do
			block(Vector3.new(0.2, 0.86, 0.2), wc * CFrame.Angles(0, 0, i * math.pi / 4) * at(1.05, 0, 0), WOOD)
		end
		for i = 0, 3 do
			block(Vector3.new(3.0, 0.14, 0.14), wc * CFrame.Angles(0, 0, i * math.pi / 4 + math.pi / 8), U.Shade(WOOD, 0.8))
		end
		cyl(0.32, 0.55, wc * U.AxisZ, GOLD, METAL_MAT)
	elseif style == "Knight" then
		-- steel helmet: dome, rim, crest, raised visor with its slit, plume
		local steel = Color3.fromRGB(195, 202, 220)
		local hc = Vector3.new(0, 1.0, 0.2)
		ball(3.3, CFrame.new(hc), steel, METAL_MAT)
		cyl(0.24, 3.4, at(0, 0.98, 0.2) * U.AxisY, U.Shade(steel, 0.8), METAL_MAT)
		cyl(0.2, 3.36, CFrame.new(hc), U.Shade(steel, 0.85), METAL_MAT) -- crest ridge front to back
		local vd = Vector3.new(0, 0.25, -1).Unit
		local vp = hc + vd * 1.68
		local vf = U.Facing(vp, vd)
		block(Vector3.new(1.7, 0.5, 0.16), vf, steel, METAL_MAT)
		block(Vector3.new(1.25, 0.09, 0.06), vf * at(0, -0.02, -0.09), DARK)
		local plume = Color3.fromRGB(235, 60, 80)
		ball(0.6, at(0, 2.7, 0.05), plume)
		wedge(Vector3.new(0.32, 1.0, 1.3), at(0, 2.9, 0.75) * CFrame.Angles(0.35, 0, 0), plume)
		-- small round shield on the left nub
		local sc = at(-2.1, -0.5, -0.5) * CFrame.Angles(0, 0.55, 0)
		cyl(0.12, 1.32, sc * U.AxisZ, GOLD, METAL_MAT)
		cyl(0.16, 1.15, sc * at(0, 0, -0.03) * U.AxisZ, accent)
		block(Vector3.new(0.16, 0.8, 0.05), sc * at(0, 0, -0.12), WHITE)
		block(Vector3.new(0.6, 0.16, 0.05), sc * at(0, 0.1, -0.12), WHITE)
	elseif style == "Royal" then
		-- small tilted crown with a gem
		local ccf = at(0.15, 1.62, 0.05) * CFrame.Angles(0, 0, -0.15)
		cyl(0.4, 1.3, ccf * U.AxisY, GOLD, METAL_MAT)
		for i = 0, 4 do
			wedge(Vector3.new(0.3, 0.42, 0.24), ccf * CFrame.Angles(0, i * 2 * math.pi / 5, 0) * at(0, 0.4, -0.52), GOLD, METAL_MAT)
		end
		ball(0.22, ccf * at(0, 0, -0.66), accent, NEON)
		ruff(-1.0, 8, 0.6, WHITE, CREAM)
		-- cape with a gold hem
		local capeCf = at(0, -1.0, 1.95) * CFrame.Angles(-0.2, 0, 0)
		block(Vector3.new(2.9, 2.6, 0.18), capeCf, Color3.fromRGB(120, 40, 170))
		block(Vector3.new(2.9, 0.16, 0.22), capeCf * at(0, -1.25, 0), GOLD, METAL_MAT)
	elseif style == "King" then
		-- big jewelled crown over a velvet cap
		local ccf = at(0, 1.3, 0.05)
		cyl(0.75, 2.45, ccf * U.AxisY, GOLD, METAL_MAT)
		ball(2.2, ccf * at(0, 0.32, 0), Color3.fromRGB(200, 35, 70))
		for i = 0, 5 do
			wedge(Vector3.new(0.42, 0.7, 0.36), ccf * CFrame.Angles(0, i * math.pi / 3, 0) * at(0, 0.7, -1.05), GOLD, METAL_MAT)
		end
		ball(0.42, ccf * at(0, 0, -1.25), glow, NEON) -- centre jewel
		for _, s in { -1, 1 } do
			local gemC = if s < 0 then Color3.fromRGB(220, 40, 70) else Color3.fromRGB(60, 120, 255)
			ball(0.3, ccf * CFrame.Angles(0, 0.75 * s, 0) * at(0, 0, -1.24), gemC, { Reflectance = 0.25 })
		end
		block(Vector3.new(0.14, 0.5, 0.14), ccf * at(0, 1.6, 0), GOLD, METAL_MAT)
		block(Vector3.new(0.4, 0.13, 0.13), ccf * at(0, 1.65, 0), GOLD, METAL_MAT)
		-- long white beard
		ball(1.6, at(0, -1.2, -1.1), BEARD)
		ball(1.2, at(0, -1.85, -1.0), BEARD)
		ball(0.8, at(0, -2.4, -0.82), BEARD)
		for _, s in { -1, 1 } do
			ball(1.0, at(0.6 * s, -1.0, -1.2), BEARD)
		end
		-- ermine collar (white puffs with black tips) and a red cape
		local cy = -0.95
		local cr = math.sqrt(R * R - cy * cy) + 0.05
		for i = 0, 7 do
			local a = (i + 0.5) * math.pi / 4
			local p = Vector3.new(math.sin(a) * cr, cy, -math.cos(a) * cr)
			ball(0.65, CFrame.new(p), WHITE)
			if i % 2 == 0 then
				local n = Vector3.new(p.X, 0, p.Z).Unit
				block(Vector3.new(0.09, 0.2, 0.06), U.Facing(p + n * 0.31, n), DARK)
			end
		end
		block(Vector3.new(3.3, 2.9, 0.2), at(0, -1.1, 2.0) * CFrame.Angles(-0.2, 0, 0), Color3.fromRGB(190, 30, 60))
		-- scepter with a glowing gem
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.2, 1, -0.3).Unit
		rod(hand - dir * 0.5, hand + dir * 1.9, 0.16, GOLD, METAL_MAT)
		ball(0.34, CFrame.new(hand + dir * 1.95), GOLD, METAL_MAT)
		block(Vector3.new(0.5, 0.5, 0.5), CFrame.new(hand + dir * 2.35) * U.VertexUp, glow, NEON)
	elseif style == "Ancient" then
		-- carved stone circlet with a glowing rune stone on the forehead
		ring(1.12, 0.5, STONE)
		local fp = surf(Vector3.new(0, 1.12, -1.4), 0.08)
		local ff = U.Facing(fp, fp)
		block(Vector3.new(0.75, 0.75, 0.2), ff * CFrame.Angles(0, 0, math.pi / 4), U.Shade(STONE, 0.85))
		cyl(0.06, 0.3, ff * at(0, 0, -0.12) * U.AxisZ, glow, NEON)
		-- rune stripes round the body
		local runeC = U.Shade(accent, 0.75)
		ring(-0.75, 0.16, runeC)
		ring(-1.2, 0.16, runeC)
		for _, a in { -1.0, -0.35, 0.35, 1.0 } do
			local d = Vector3.new(math.sin(a), -0.7, -math.cos(a))
			local p = surf(d, 0)
			block(Vector3.new(0.1, 0.3, 0.06), U.Facing(p, d), glow, NEON)
		end
		-- floating stone tablet
		local tcf = at(-2.6, 0.55, 0) * CFrame.Angles(0.1, 0.55, 0.12)
		block(Vector3.new(1.1, 1.3, 0.24), tcf, STONE)
		cyl(0.24, 1.1, tcf * at(0, 0.65, 0) * U.AxisZ, STONE)
		for i = 0, 2 do
			block(Vector3.new(0.65 - i * 0.12, 0.08, 0.04), tcf * at(0, 0.45 - i * 0.32, -0.13), glow, NEON)
		end
	elseif style == "Void" then
		-- glowing cracks in the dark body
		local cracks = {
			{ d = Vector3.new(1.0, 0.55, -0.45), t = 0.4 },
			{ d = Vector3.new(-0.95, 0.75, -0.2), t = -0.5 },
			{ d = Vector3.new(0.85, -0.45, -0.75), t = 2.6 },
			{ d = Vector3.new(-0.7, -0.35, -0.9), t = 0.3 },
			{ d = Vector3.new(0.15, 0.95, 0.35), t = 1.2 },
		}
		for _, c in cracks do
			local p = surf(c.d, -0.02)
			local f = U.Facing(p, c.d) * CFrame.Angles(0, 0, c.t)
			block(Vector3.new(0.11, 0.75, 0.1), f, glow, NEON)
			block(Vector3.new(0.09, 0.42, 0.1), f * at(0.12, 0.42, 0) * CFrame.Angles(0, 0, -0.7), glow, NEON)
		end
		-- three orbiting shards
		for i = 0, 2 do
			local a = i * 2 * math.pi / 3 + 0.5
			local y = 0.3 + 0.45 * math.sin(i * 2.1)
			crystal(CFrame.Angles(0, a, 0) * at(0, y, -2.65) * CFrame.Angles(0.35, 0, 0.5), 0.34, 0.75, U.Shade(color, 0.7), nil, glow, NEON, true)
		end
	elseif style == "Overlord" then
		-- massive crystal crown: gold circlet, centre spike, horns and side spikes
		local gem = U.Vivid(glow)
		local glass = { Reflectance = 0.25 }
		cyl(0.42, 2.55, at(0, 1.25, 0.05) * U.AxisY, GOLD, METAL_MAT)
		crystal(at(0, 1.6, -0.3) * at(0, 0.8, 0), 0.52, 1.6, gem, glass, glow, NEON, false)
		for _, s in { -1, 1 } do
			crystal(at(0.8 * s, 1.5, 0.1) * CFrame.Angles(0, 0, -0.55 * s) * at(0, 0.7, 0), 0.45, 1.4, gem, glass, glow, NEON, false)
			crystal(at(0.45 * s, 1.45, -0.62) * CFrame.Angles(-0.25, 0, -0.3 * s) * at(0, 0.35, 0), 0.3, 0.7, gem, glass, glow, NEON, false)
			brow(s, 0.98, true, DARK, 0.7)
		end
		block(Vector3.new(0.4, 0.4, 0.4), at(0, 1.25, -1.33) * U.VertexUp, glow, NEON) -- circlet jewel
		-- ornate high collar
		ring(-0.75, 0.22, GOLD, METAL_MAT)
		for i = -2, 2 do
			block(Vector3.new(0.6, 1.3, 0.14), CFrame.Angles(0, i * 0.42, 0) * at(0, -0.15, 1.75) * CFrame.Angles(0.35, 0, 0), Color3.fromRGB(70, 50, 120))
		end
		-- five big crystals floating around
		for i = 0, 4 do
			local a = math.pi / 5 + i * 2 * math.pi / 5
			local y = if i % 2 == 0 then 0.7 else -0.5
			crystal(CFrame.Angles(0, a, 0) * at(0, y, -3.1) * CFrame.Angles(0.15, 0, 0.3), 0.45, 1.3, gem, glass, glow, NEON, true)
		end
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

	-- aura: subtle on normal ghosts, stronger on mini-bosses, strongest on bosses/event ghosts
	local isBoss = def.Kind == "Boss" or def.Kind == "Event"
	local isMini = def.Kind == "MiniBoss"
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Aura"
	pe.Color = ColorSequence.new(glow)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Rate = if isBoss then 8 elseif isMini then 4 else 2
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Speed = NumberRange.new(0.3, if isBoss then 1.1 else 0.8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	local peak = if isBoss then 1.6 elseif isMini then 1.2 else 0.8
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, peak / 3),
		NumberSequenceKeypoint.new(0.5, peak),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if isBoss then 0.45 elseif isMini then 0.6 else 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-30, 30)
	pe.Parent = core

	-- No PointLights on ghosts: lights on moving, bobbing (and spawn-scaling) models flicker as
	-- the engine re-sorts nearby lights every frame. The glow comes from the neon core, eyes and
	-- the Aura emitter (stronger on bosses).

	if def.Scale ~= 1 then
		model:ScaleTo(def.Scale)
	end
	return model
end

return GhostRig
