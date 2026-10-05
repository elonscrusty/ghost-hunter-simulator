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
local World2 = require(script.Parent.GhostStyles.World2)

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
local GLOW_EYES = { HauntedArmor = true, GraveColossus = true, VoidLeviathan = true, CrystalTitan = true, Student = true, Ancient = true, Void = true, Overlord = true, Shadow = true, Titan = true, GhostKing = true,
	Rift = true, Herald = true, VoidEmperor = true, Locomotive = true,
}
-- styles with the open "▽" grin instead of the round "O" mouth
local GRIN = { CrystalTitan = true, Jester = true, PumpkinKnight = true, SwampHag = true, CandleLich = true, BoneCaptain = true, MummyPharaoh = true, PuppetMaster = true, VampireCount = true, PhantomEmperor = true, GraveColossus = true, VoidLeviathan = true, EclipseOverlord = true,
	Mischief = true, Hallway = true, Headmaster = true, Carnival = true, Ringmaster = true,
	Pirate = true, Captain = true, King = true, Overlord = true,
	SwampLord = true, Blizzard = true, Pharaoh = true, JackBox = true, Puppet = true,
	Leviathan = true, TimeKeeper = true, Titan = true, GhostKing = true,
	DragonDance = true, Grimoire = true, Topsy = true, Mycelium = true, MirrorQueen = true, Locomotive = true,
	Saucer = true, Herald = true, Copycat = true, Graffiti = true, Rift = true,
}
-- spooky styles that don't blush
local NO_BLUSH = { CrystalTitan = true, Banshee = true, FrostWraith = true, CandleLich = true, HauntedArmor = true, GraveColossus = true, VoidLeviathan = true, EclipseOverlord = true, Giant = true, Void = true, Overlord = true, Shadow = true, Titan = true,
	Mote = true, Rift = true, Herald = true, VoidEmperor = true, Billboard = true, Locomotive = true, Glint = true, Commuter = true, StormRoc = true,
}
-- World 2: the Billboard's screen is its face; the Storm Roc's beak replaces the mouth; the Void
-- Emperor draws his own wide grin
local NO_FACE = { Billboard = true }
local NO_MOUTH = { StormRoc = true, VoidEmperor = true }

local BRASS = Color3.fromRGB(205, 160, 75)
local ICE = Color3.fromRGB(195, 235, 255)
local ROCK = Color3.fromRGB(85, 58, 55)
local PURPLE = Color3.fromRGB(110, 40, 160)

-- point on the body sphere in direction `dir`, pushed `out` studs off the surface
local function surf(dir: Vector3, out: number): Vector3
	return dir.Unit * (R + out)
end

function GhostRig.Build(ghostId: string): Model
	local def = Config.Ghosts[ghostId]
	assert(def, "GhostRig: unknown ghost " .. tostring(ghostId))
	local style = def.Style
	local color = if style == "Shadow" then U.Shade(def.Color, 0.7) else def.Color
	local glow = def.Glow
	local accent = U.Vivid(glow) -- solid accessories in the glow colour

	local w2Style = World2.Styles[style]
	-- upside-down styles: every part is turned 180 degrees about Z (round the body centre) before welding
	local flip: CFrame? = if World2.Flipped[style] then CFrame.Angles(0, 0, math.pi) else nil

	local model = Instance.new("Model")
	model.Name = ghostId

	local core = U.Ball(CORE_D, CFrame.identity, glow, model, { Transparency = 1, Name = "Core", Shadow = false })
	core.Anchored = true
	core.CanQuery = true
	core.Massless = false
	model.PrimaryPart = core

	local function add(p: BasePart): BasePart
		if flip then
			p.CFrame = flip * p.CFrame
		end
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
	-- band hugging any ball (centre `c`, radius `r`) at height `h` above its centre
	local function bandOn(c: Vector3, r: number, h: number, thick: number, col: Color3, opts: U.Opts?, tilt: number?)
		local rr = math.sqrt(math.max(r * r - h * h, 0.05))
		cyl(thick, rr * 2 + 0.1, CFrame.new(c) * CFrame.Angles(0, 0, tilt or 0) * at(0, h, 0) * U.AxisY, col, opts)
	end
	-- frame on the body surface in direction `d` (its -Z looks outward, its Y runs "up" the surface)
	local function onSurf(d: Vector3, out: number): CFrame
		local p = surf(d, out)
		return U.Facing(p, d)
	end
	local function gear(cf: CFrame, d: number, thick: number, teeth: number, c: Color3, opts: U.Opts?)
		for _, p in U.Gear(d, thick, teeth, cf, c, model, opts) do
			add(p)
		end
	end
	-- swept-back fin standing out of the midline (x = 0) at `p` along the normal `n` (n.X must be 0)
	local function fin(p: Vector3, n: Vector3, h: number, len: number, c: Color3, opts: U.Opts?)
		local up = n.Unit
		wedge(Vector3.new(0.12, h, len), CFrame.fromMatrix(p + up * (h / 2 - 0.15), Vector3.xAxis, up), c, opts)
	end
	-- n rock plates on the body (dirs) with glowing cracks between them (crackDirs)
	local function rockPlates(dirs: { Vector3 }, crackDirs: { Vector3 }, rock: Color3)
		for i, d in dirs do
			block(Vector3.new(1.05, 0.85, 0.22), onSurf(d, 0.0) * CFrame.Angles(0, 0, i * 0.7), rock)
		end
		for i, d in crackDirs do
			local f = onSurf(d, -0.02) * CFrame.Angles(0, 0, i * 1.1)
			block(Vector3.new(0.11, 0.62, 0.1), f, glow, NEON)
		end
	end
	-- straight blade/spike along `dir` from `base`: two back-to-back wedges forming a point
	local function point(base: Vector3, dir: Vector3, w: number, len: number, thick: number, c: Color3, opts: U.Opts?)
		local f = CFrame.lookAt(base, base + dir) * at(0, 0, -len / 2)
		wedge(Vector3.new(thick, w / 2, len), f * at(0, w / 4, 0), c, opts)
		wedge(Vector3.new(thick, w / 2, len), f * at(0, -w / 4, 0) * CFrame.Angles(0, 0, math.pi), c, opts)
	end
	-- frame at `p` whose +Y runs along `dir` (for crystals and gems on poles)
	local function along(p: Vector3, dir: Vector3): CFrame
		return CFrame.lookAt(p, p + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	-- two little fangs hanging from the top of the grin
	local function fangs(c: Color3)
		for _, s in { -1, 1 } do
			local pos = surf(Vector3.new(0.18 * s, -0.42, -1.7), 0.08)
			wedge(Vector3.new(0.08, 0.22, 0.22), U.Facing(pos, pos) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, c)
		end
	end
	-- mermaid-style tail flukes spreading from the tail tip
	local function flukes(c: Color3, w: number, len: number)
		local tip = Vector3.new(0.2, -2.7, 1.9)
		local base = CFrame.lookAt(tip, tip + Vector3.new(0, -0.5, 0.85))
		for _, s in { -1, 1 } do
			block(Vector3.new(w, 0.1, len), base * CFrame.Angles(0, -0.6 * s, 0) * at(0, 0, -len / 2 - 0.05), c)
		end
	end

	-- Opaque body: see-through layered parts (body over a glowing inner core, overlapping tail
	-- balls) flicker on moving models because the engine re-sorts transparent parts every frame.
	local bodyOpts = { Shadow = false }

	------------------------------------------------------------------ body + tail
	ball(BODY_D, CFrame.identity, color, { Shadow = true, Reflectance = if style == "Glint" then 0.3 else nil })
	ball(2.7, at(0, -0.95, 0.45), color, bodyOpts)
	ball(2.0, at(0.15, -1.75, 0.95), color, bodyOpts)
	ball(1.35, at(-0.05, -2.35, 1.45), color, bodyOpts)
	ball(0.8, at(0.2, -2.7, 1.9), color, bodyOpts)

	------------------------------------------------------------------ face
	local glowEyes = GLOW_EYES[style] == true
	local eyeColor = if glowEyes then glow elseif style == "Mote" then WHITE else EYE
	local eyeOpts: U.Opts? = if glowEyes then NEON else nil
	if NO_FACE[style] then
		-- face drawn by the style
	elseif style == "Dizzy" then
		-- spiral eyes: dark disc, white ring, dark centre
		for _, s in { -1, 1 } do
			local p = Vector3.new(0.6 * s, 0.35, -1.38)
			cyl(0.1, 0.95, U.DiscFacing(surf(p, 0.04), p), EYE)
			cyl(0.1, 0.62, U.DiscFacing(surf(p, 0.07), p), WHITE)
			cyl(0.1, 0.36, U.DiscFacing(surf(p, 0.1), p), EYE)
		end
	elseif style == "Crypt" then
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
			ball(0.32, CFrame.new(p + Vector3.new(0.16, 0.18, -0.3)), if style == "Mote" then EYE else WHITE)
		end
	end
	local mouthPos = surf(Vector3.new(0, -0.45, -1.65), -0.02)
	if style == "Doctor" or NO_FACE[style] or NO_MOUTH[style] then
		-- the surgical mask / screen / beak covers the mouth, or the style draws its own
	elseif style == "Mote" then
		cyl(0.25, 0.5, U.DiscFacing(mouthPos, mouthPos), WHITE)
	elseif style == "Herald" then
		grin(mouthPos, 0.6, WHITE)
	elseif style == "Rift" or style == "Locomotive" then
		grin(mouthPos, if def.Kind == "Boss" then 0.6 else 0.5, accent)
	elseif style == "Void" or style == "Shadow" then
		grin(mouthPos, 0.55, glow, NEON)
	elseif style == "Clown" then
		grin(mouthPos, 0.75, MOUTH)
	elseif style == "Giant" then
		grin(mouthPos, 0.85, MOUTH)
	elseif GRIN[style] then
		grin(mouthPos, if def.Kind == "Boss" or def.Kind == "WorldBoss" then 0.6 else 0.5, MOUTH)
	else
		oMouth(mouthPos, if style == "Poltergeist" then 0.75 else 0.6)
	end
	-- nub arms
	for _, s in { -1, 1 } do
		ball(0.95, at(1.7 * s, -0.35, -0.2), color, bodyOpts)
	end
	-- blush (the Giant and the void spirits are too spooky to blush)
	if not NO_BLUSH[style] and not NO_FACE[style] then
		for _, s in { -1, 1 } do
			ball(0.4, at(1.0 * s, -0.12, -1.45), BLUSH)
		end
	end

	------------------------------------------------------------------ styles
	if w2Style then
		w2Style({
			color = color,
			glow = glow,
			accent = accent,
			R = R,
			ball = ball,
			block = block,
			cyl = cyl,
			wedge = wedge,
			rod = rod,
			ring = ring,
			ruff = ruff,
			cone = cone,
			brow = brow,
			surf = surf,
			point = point,
		})
	elseif style == "Mischief" then
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
	------------------------------------------------------------------ zones 9-16
	elseif style == "Bog" then
		-- lily pad hat with a little flower; mud dripping down from under it
		local pad = Color3.fromRGB(85, 175, 80)
		local pcf = at(0.2, 1.7, 0.05) * CFrame.Angles(0.08, 0, -0.12)
		cyl(0.14, 2.3, pcf * U.AxisY, pad)
		block(Vector3.new(1.15, 0.16, 0.1), pcf * CFrame.Angles(0, 0.7, 0) * at(0.575, 0.01, 0), U.Shade(pad, 0.7)) -- notch
		ball(0.5, pcf * at(-0.45, 0.2, 0.35), Color3.fromRGB(255, 150, 200))
		ball(0.24, pcf * at(-0.45, 0.42, 0.35), GOLD)
		local mud = Color3.fromRGB(105, 75, 45)
		for _, d in { Vector3.new(-1.15, 0.95, -0.35), Vector3.new(1.2, 0.85, 0.2), Vector3.new(0.3, 1.0, 0.9), Vector3.new(-0.6, 0.9, 0.95) } do
			local f = onSurf(d, 0)
			block(Vector3.new(0.34, 0.7, 0.16), f * at(0, -0.15, 0), mud)
			ball(0.46, f * at(0, -0.5, 0), mud)
		end
	elseif style == "Marsh" then
		-- cattails sprouting from the head, moss patches and a firefly friend
		local stem = Color3.fromRGB(90, 150, 70)
		local cat = Color3.fromRGB(125, 80, 45)
		local tails = {
			{ Vector3.new(-0.55, 1.6, 0.25), Vector3.new(-1.0, 2.9, 0.35) },
			{ Vector3.new(0.1, 1.7, 0.15), Vector3.new(0.15, 3.25, 0.1) },
			{ Vector3.new(0.6, 1.6, 0.3), Vector3.new(1.1, 2.7, 0.45) },
		}
		for _, pr in tails do
			local a, b = pr[1], pr[2]
			local dir = (b - a).Unit
			rod(a, b, 0.1, stem)
			rod(b - dir * 0.75, b - dir * 0.1, 0.3, cat)
		end
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.1, 0.9, 0.35), at(0.35 * s, 2.0, 0.4) * CFrame.Angles(0, 0, -0.35 * s), stem) -- reed blade
		end
		for _, d in { Vector3.new(-1, 0.2, 0.8), Vector3.new(1.1, -0.5, 0.5), Vector3.new(0.2, -0.6, 1) } do
			ball(0.75, CFrame.new(surf(d, -0.2)), Color3.fromRGB(70, 125, 60)) -- moss
		end
		ball(0.3, at(-2.3, 1.25, -0.5), DARK) -- firefly
		ball(0.28, at(-2.42, 1.05, -0.38), glow, NEON)
		block(Vector3.new(0.34, 0.05, 0.18), at(-2.25, 1.42, -0.45) * CFrame.Angles(0, 0.4, 0.3), WHITE)
	elseif style == "SwampLord" then
		local bark = Color3.fromRGB(95, 65, 40)
		local leaf = Color3.fromRGB(75, 155, 65)
		local moss = Color3.fromRGB(70, 115, 55)
		-- crown of twisted roots with leaves and a glowing swamp gem
		ring(1.3, 0.4, bark)
		for i = 0, 5 do
			local rot = CFrame.Angles(0, math.pi / 6 + i * math.pi / 3, 0)
			local p0 = (rot * at(0, 1.4, -1.0)).Position
			local p1 = (rot * at(0, 2.15, -1.6)).Position
			local p2 = (rot * at(0, 2.7, -2.0)).Position
			rod(p0, p1, 0.34, bark)
			rod(p1, p2, 0.24, bark)
			ball(0.55, CFrame.new(p2), leaf)
		end
		ball(0.45, CFrame.new(surf(Vector3.new(0, 1.3, -1.17), 0.14)), glow, NEON)
		for _, s in { -1, 1 } do
			cyl(0.14, 1.7, at(1.75 * s, 0.25, -0.15) * CFrame.Angles(0, 0, -0.35 * s) * U.AxisY, leaf) -- lily pad pauldron
			brow(s, 0.95, true, U.Shade(color, 0.45), 0.75)
		end
		-- moss belt with hanging drapes (sides and back, the face stays clear)
		ring(-1.0, 0.3, moss)
		for i = 0, 5 do
			local a = math.rad(70 + i * 44)
			block(Vector3.new(0.45, 0.75, 0.12), onSurf(Vector3.new(math.sin(a), -0.85, -math.cos(a)), 0.03) * at(0, -0.15, 0), moss)
		end
		-- gnarled root staff with a glowing orb
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.2, 1, -0.3).Unit
		local top = hand + dir * 2.5
		rod(hand - dir * 0.7, hand + dir * 2.3, 0.22, bark)
		rod(hand + dir * 2.0, top + Vector3.new(0.3, 0.2, 0), 0.12, bark)
		rod(hand + dir * 2.0, top + Vector3.new(-0.25, 0.25, 0.1), 0.12, bark)
		ball(0.6, CFrame.new(top + Vector3.new(0, 0.15, 0)), glow, NEON)
	elseif style == "FrostWisp" then
		-- little ice tiara, knitted scarf and a floating snowflake
		local glass = { Reflectance = 0.25 }
		crystal(at(0, 1.55, -0.55) * CFrame.Angles(-0.3, 0, 0) * at(0, 0.45, 0), 0.34, 0.9, ICE, glass, glow, NEON, false)
		for _, s in { -1, 1 } do
			crystal(at(0.55 * s, 1.5, -0.45) * CFrame.Angles(-0.3, 0, -0.35 * s) * at(0, 0.3, 0), 0.26, 0.6, ICE, glass, U.Vivid(glow), nil, false)
		end
		ring(-1.0, 0.36, RED)
		ball(0.45, CFrame.new(surf(Vector3.new(-0.6, -1.0, -1.2), 0.12)), RED)
		local tf = onSurf(Vector3.new(-0.75, -1.35, -1.0), 0.08) * CFrame.Angles(0, 0, 0.15)
		block(Vector3.new(0.42, 0.95, 0.12), tf, RED)
		for _, y in { 0.15, -0.2 } do
			block(Vector3.new(0.44, 0.1, 0.14), tf * at(0, y, 0), WHITE)
		end
		local sc = at(2.5, 0.9, -0.4) * CFrame.Angles(0, -0.4, 0.2)
		for k = 0, 2 do
			block(Vector3.new(0.12, 1.2, 0.08), sc * CFrame.Angles(0, 0, k * math.pi / 3), WHITE)
		end
		ball(0.25, sc, glow, NEON)
	elseif style == "Yeti" then
		-- fluffy fur tufts and curled horns
		local fur = U.Shade(color, 0.96)
		local horn = Color3.fromRGB(205, 190, 165)
		for _, p in { Vector3.new(0, 1.75, 0.25), Vector3.new(-0.55, 1.6, 0.45), Vector3.new(0.55, 1.62, 0.4), Vector3.new(0.05, 1.5, 0.95), Vector3.new(-0.3, 1.85, -0.2) } do
			ball(0.85, CFrame.new(p), fur)
		end
		for _, s in { -1, 1 } do
			ball(0.8, at(1.45 * s, 0.6, -0.35), fur) -- cheek fluff
			ball(0.75, at(1.62 * s, 0.05, 0.2), fur)
			ball(1.15, at(1.75 * s, -0.4, -0.15), fur) -- furry arm
			local h0 = Vector3.new(0.9 * s, 1.3, 0.1)
			local h1 = Vector3.new(1.45 * s, 1.85, 0.2)
			local h2 = Vector3.new(1.75 * s, 2.45, 0.0)
			local h3 = Vector3.new(1.6 * s, 2.95, -0.3)
			rod(h0, h1, 0.5, horn)
			rod(h1, h2, 0.4, horn)
			rod(h2, h3, 0.28, horn)
			ball(0.3, CFrame.new(h3), horn)
			block(Vector3.new(0.12, 0.16, 0.08), onSurf(Vector3.new(0.17 * s, -0.62, -1.6), 0.02), WHITE) -- little fang
		end
		ball(0.95, at(0.2, -2.7, 1.95), fur) -- fluffy tail tip
	elseif style == "Blizzard" then
		local glass = { Reflectance = 0.3 }
		-- tall ice crown on a silver circlet
		cyl(0.36, 2.4, at(0, 1.28, 0.05) * U.AxisY, Color3.fromRGB(220, 235, 250), METAL_MAT)
		crystal(at(0, 1.5, -0.45) * at(0, 0.85, 0), 0.5, 1.7, ICE, glass, glow, NEON, false)
		for _, s in { -1, 1 } do
			crystal(at(0.75 * s, 1.45, -0.1) * CFrame.Angles(0, 0, -0.45 * s) * at(0, 0.65, 0), 0.42, 1.3, ICE, glass, glow, NEON, false)
			crystal(at(0.5 * s, 1.4, -0.75) * CFrame.Angles(-0.2, 0, -0.25 * s) * at(0, 0.35, 0), 0.3, 0.7, ICE, glass, U.Vivid(glow), nil, false)
			brow(s, 0.95, false, U.Shade(glow, 0.55), 0.6)
		end
		-- high collar of ice shards
		for i = -2, 2 do
			local cf = CFrame.Angles(0, i * 0.45, 0) * at(0, -0.1, 1.75) * CFrame.Angles(0.35, 0, 0)
			block(Vector3.new(0.55, 1.5, 0.14), cf, ICE, glass)
			block(Vector3.new(0.39, 0.39, 0.39), cf * at(0, 0.75, 0) * U.VertexUp, WHITE)
		end
		ruff(-1.0, 10, 0.6, WHITE, ICE)
		-- three snowflakes orbiting
		for i = 0, 2 do
			local sc = CFrame.Angles(0, i * 2 * math.pi / 3 + 0.9, 0) * at(0, 0.4 + 0.5 * math.sin(i * 2.3), -3.0) * CFrame.Angles(0.2, 0, i)
			for k = 0, 2 do
				block(Vector3.new(0.14, 1.1, 0.08), sc * CFrame.Angles(0, 0, k * math.pi / 3), WHITE)
			end
		end
		-- ice scepter
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.2, 1, -0.3).Unit
		rod(hand - dir * 0.5, hand + dir * 1.9, 0.16, ICE, glass)
		crystal(along(hand + dir * 2.3, dir), 0.4, 0.7, ICE, glass, glow, NEON, true)
	elseif style == "Mummy" then
		-- bandage bands round the head, body and tail, with a loose end
		local wrap = Color3.fromRGB(200, 180, 140)
		ring(1.25, 0.28, wrap, nil, 0.18)
		ring(0.95, 0.2, wrap, nil, -0.1)
		ring(-0.95, 0.28, wrap, nil, 0.12)
		ring(-1.38, 0.24, wrap, nil, -0.15)
		bandOn(Vector3.new(0.15, -1.75, 0.95), 1.0, -0.15, 0.24, wrap, nil, 0.25)
		bandOn(Vector3.new(-0.05, -2.35, 1.45), 0.675, 0.0, 0.2, wrap, nil, -0.3)
		ball(0.4, at(1.35, 1.25, 0.35), wrap) -- knot
		block(Vector3.new(0.26, 0.75, 0.06), at(1.55, 0.95, 0.45) * CFrame.Angles(0.2, 0, 0.45), wrap)
		block(Vector3.new(0.26, 0.6, 0.06), at(1.62, 0.5, 0.62) * CFrame.Angles(0.1, 0, 0.15), wrap)
		cyl(0.3, 0.9, at(-1.95, -0.38, -0.2), wrap) -- wrapped nub
	elseif style == "Scarab" then
		-- shiny beetle shell on the back, antennae and little legs
		local shell = U.Shade(color, 0.6)
		local shellOpts = { Reflectance = 0.3 }
		for _, s in { -1, 1 } do
			ball(2.45, at(0.55 * s, 0.3, 1.0), shell, shellOpts)
			ball(0.5, at(1.16 * s, 0.91, 1.86), accent) -- shell spot
			local a0 = Vector3.new(0.35 * s, 1.6, -0.35)
			local a1 = Vector3.new(0.75 * s, 2.45, -0.85)
			local a2 = Vector3.new(1.15 * s, 2.65, -0.7)
			rod(a0, a1, 0.1, DARK)
			rod(a1, a2, 0.1, DARK)
			ball(0.3, CFrame.new(a2), accent)
			for _, y in { -0.45, -0.95 } do
				local p = surf(Vector3.new(s, y, 0.35), -0.05)
				rod(p, p + Vector3.new(0.45 * s, -0.4, -0.1), 0.1, DARK)
			end
		end
		cyl(0.12, 2.55, at(0, 0.3, 1.0), DARK) -- seam between the wing cases
	elseif style == "Pharaoh" then
		local blue = Color3.fromRGB(40, 80, 170)
		-- striped nemes headdress with side lappets, back tail and a cobra on the brow
		local capC = Vector3.new(0, 0.75, 0.3)
		ball(3.3, CFrame.new(capC), GOLD)
		for _, h in { 0.45, 0.95 } do
			bandOn(capC, 1.65, h, 0.16, blue)
		end
		for _, s in { -1, 1 } do
			local lp = at(1.38 * s, -0.15, -0.9) * CFrame.Angles(0, -0.35 * s, 0)
			block(Vector3.new(0.45, 1.8, 0.5), lp, GOLD)
			for _, y in { 0.3, -0.3 } do
				block(Vector3.new(0.48, 0.12, 0.53), lp * at(0, y, 0), blue)
			end
			brow(s, 0.95, false, DARK, 0.6)
			block(Vector3.new(0.35, 0.1, 0.08), onSurf(Vector3.new(1.0 * s, 0.4, -1.2), 0.03) * CFrame.Angles(0, 0, 0.3 * s), DARK) -- eyeliner wing
		end
		local tb = at(0, -0.1, 1.75) * CFrame.Angles(-0.15, 0, 0)
		block(Vector3.new(1.1, 1.2, 0.35), tb, GOLD)
		block(Vector3.new(1.13, 0.14, 0.38), tb * at(0, 0.1, 0), blue)
		local up = surf(Vector3.new(0, 1.05, -1.3), 0.02)
		block(Vector3.new(0.18, 0.45, 0.14), CFrame.new(up), GOLD, METAL_MAT)
		ball(0.28, CFrame.new(up + Vector3.new(0, 0.3, -0.05)), GOLD, METAL_MAT)
		ball(0.14, CFrame.new(up + Vector3.new(0, 0.32, -0.17)), glow, NEON)
		ruff(-0.95, 12, 0.5, blue, GOLD) -- broad jewelled collar
		-- striped crook
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.15, 1, -0.25).Unit
		for k = 0, 3 do
			rod(hand + dir * (-0.5 + k * 0.6), hand + dir * (0.1 + k * 0.6), 0.17, if k % 2 == 0 then GOLD else blue)
		end
		local top = hand + dir * 1.9
		local c1 = top + Vector3.new(0.15, 0.4, 0)
		local c2 = top + Vector3.new(0.55, 0.45, 0)
		rod(top, c1, 0.17, GOLD)
		rod(c1, c2, 0.17, blue)
		rod(c2, top + Vector3.new(0.7, 0.15, 0), 0.17, GOLD)
		-- floating ankh with a glowing eye
		local ac = at(-2.5, 0.6, -0.3) * CFrame.Angles(0, 0.4, 0.1)
		block(Vector3.new(0.2, 0.9, 0.16), ac, GOLD, METAL_MAT)
		block(Vector3.new(0.7, 0.18, 0.16), ac * at(0, 0.25, 0), GOLD, METAL_MAT)
		cyl(0.16, 0.55, ac * at(0, 0.68, 0) * U.AxisZ, GOLD, METAL_MAT)
		cyl(0.18, 0.24, ac * at(0, 0.68, 0) * U.AxisZ, glow, NEON)
	elseif style == "ToySoldier" then
		-- tall bearskin hat with a gold plate, cross-belts and a drum
		local hatC = Color3.fromRGB(35, 35, 50)
		local jacket = Color3.fromRGB(215, 45, 60)
		local hcf = at(0, 2.15, 0.1)
		cyl(1.6, 1.7, hcf * U.AxisY, hatC)
		cyl(0.25, 1.76, hcf * at(0, -0.62, 0) * U.AxisY, jacket)
		block(Vector3.new(0.55, 0.6, 0.1), hcf * at(0, -0.05, -0.85), GOLD, METAL_MAT)
		ball(0.6, hcf * at(0, 0.95, 0), jacket) -- pompom
		local belt = Vector3.new(0, -1.25, -1.2)
		for _, s in { -1, 1 } do
			rod((hcf * at(0.8 * s, -0.75, 0)).Position, surf(Vector3.new(1.2 * s, -0.4, -0.9), 0.02), 0.07, GOLD) -- chin strap
			block(Vector3.new(0.2, 1.15, 0.08), onSurf(belt, 0.03) * CFrame.Angles(0, 0, 0.55 * s), WHITE)
			cyl(0.2, 0.9, at(1.62 * s, 0.15, -0.2) * U.AxisY, GOLD, METAL_MAT) -- epaulette
		end
		ball(0.28, onSurf(belt, 0.06), GOLD, METAL_MAT)
		local dc = at(-2.05, -1.1, -0.55)
		cyl(0.75, 1.15, dc * U.AxisY, WHITE)
		for _, y in { 0.38, -0.38 } do
			cyl(0.12, 1.22, dc * at(0, y, 0) * U.AxisY, jacket)
		end
		block(Vector3.new(0.5, 0.4, 0.06), dc * at(0, 0, -0.58), GOLD) -- drum badge
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.3, 0.8, -0.5).Unit
		rod(hand - dir * 0.2, hand + dir * 1.3, 0.12, WOOD) -- drumstick
		ball(0.26, CFrame.new(hand + dir * 1.35), CREAM)
	elseif style == "JackBox" then
		-- popping out of a toy box on a spring, with a jester collar and hat
		local boxC = Color3.fromRGB(80, 120, 230)
		local bc = Vector3.new(0.05, -3.55, 0.75)
		block(Vector3.new(2.8, 1.6, 2.8), CFrame.new(bc), boxC)
		block(Vector3.new(2.95, 0.2, 2.95), CFrame.new(bc + Vector3.new(0, 0.82, 0)), GOLD)
		block(Vector3.new(2.95, 0.2, 2.95), CFrame.new(bc + Vector3.new(0, -0.82, 0)), GOLD)
		local panels = { RED, Color3.fromRGB(255, 215, 70), Color3.fromRGB(90, 200, 120), Color3.fromRGB(255, 140, 220) }
		for k, c in panels do
			block(Vector3.new(2.0, 1.0, 0.06), CFrame.new(bc) * CFrame.Angles(0, k * math.pi / 2, 0) * at(0, 0, -1.42), c)
		end
		local star = CFrame.new(bc + Vector3.new(0, 0, -1.47))
		block(Vector3.new(0.5, 0.5, 0.06), star, WHITE)
		block(Vector3.new(0.5, 0.5, 0.06), star * CFrame.Angles(0, 0, math.pi / 4), WHITE)
		local hinge = bc + Vector3.new(0, 0.8, 1.4)
		block(Vector3.new(2.8, 0.14, 2.8), CFrame.new(hinge) * CFrame.Angles(1.95, 0, 0) * at(0, 0, -1.4), boxC) -- open lid
		rod(bc + Vector3.new(1.4, 0.1, 0), bc + Vector3.new(1.85, 0.1, 0), 0.14, METAL, METAL_MAT) -- crank
		block(Vector3.new(0.12, 0.6, 0.14), CFrame.new(bc + Vector3.new(1.9, -0.15, 0)), METAL, METAL_MAT)
		ball(0.3, CFrame.new(bc + Vector3.new(1.9, -0.45, -0.12)), RED)
		for k = 0, 4 do
			local function zig(i: number): Vector3
				return Vector3.new(if i % 2 == 0 then -0.35 else 0.35, -1.6 - i * 0.2, -0.5 + (i % 2) * 0.1)
			end
			rod(zig(k), zig(k + 1), 0.14, METAL, METAL_MAT) -- spring
		end
		ruff(-1.0, 8, 0.6, accent, GOLD)
		for _, s in { -1, 1 } do
			local tip = cone(at(0.5 * s, 1.45, 0.1) * CFrame.Angles(0, 0, -0.6 * s), 0.9, 1.2, 3, if s < 0 then RED else GOLD)
			ball(0.35, tip, if s < 0 then GOLD else RED)
		end
	elseif style == "Puppet" then
		-- marionette control bar floating above, strings to the head, arms and back
		local cord = Color3.fromRGB(235, 235, 245)
		local C = Vector3.new(0, 4.3, -0.1)
		block(Vector3.new(3.6, 0.26, 0.26), CFrame.new(C), WOOD)
		block(Vector3.new(0.26, 0.26, 2.3), CFrame.new(C), WOOD)
		cyl(0.7, 0.22, CFrame.new(C + Vector3.new(0, 0.45, 0)) * U.AxisY, U.Shade(WOOD, 0.8))
		ball(0.4, CFrame.new(C + Vector3.new(0, 0.85, 0)), GOLD, METAL_MAT)
		local pins = {
			{ C + Vector3.new(-1.75, 0, 0), Vector3.new(-1.8, 0.1, -0.2) },
			{ C + Vector3.new(1.75, 0, 0), Vector3.new(1.8, 0.1, -0.2) },
			{ C + Vector3.new(0, 0, -1.1), Vector3.new(0, 1.55, -0.85) },
			{ C + Vector3.new(0, 0, 1.1), Vector3.new(0, 1.3, 1.15) },
		}
		for _, pr in pins do
			rod(pr[1], pr[2], 0.05, cord)
			ball(0.2, CFrame.new(pr[2]), GOLD, METAL_MAT)
		end
		for _, s in { -1, 1 } do
			ball(0.32, CFrame.new(C + Vector3.new(1.85 * s, 0, 0)), GOLD, METAL_MAT)
			block(Vector3.new(0.07, 0.5, 0.06), onSurf(Vector3.new(0.32 * s, -0.75, -1.55), 0.02), DARK) -- marionette jaw line
			ball(0.3, at(1.85 * s, -0.4, -0.6), GOLD, METAL_MAT) -- joint pin
			brow(s, 1.0, false, U.Shade(color, 0.45), 0.6)
		end
		ruff(-1.0, 8, 0.65, accent, CREAM)
		-- a tiny ghost marionette dangling from the left nub
		block(Vector3.new(1.0, 0.14, 0.14), at(-2.45, -0.15, -0.65), WOOD)
		for _, x in { -2.85, -2.05 } do
			rod(Vector3.new(x, -0.15, -0.65), Vector3.new(x + (if x < -2.4 then 0.15 else -0.15), -1.55, -0.65), 0.04, cord)
		end
		ball(0.9, at(-2.45, -1.9, -0.65), CREAM)
		for _, s in { -1, 1 } do
			ball(0.16, at(-2.45 + 0.16 * s, -1.8, -1.07), EYE)
		end
		ball(0.45, at(-2.4, -2.4, -0.5), CREAM)
	elseif style == "Bubble" then
		-- solid, shiny bubbles floating round (no see-through parts: they flicker)
		local bub = Color3.fromRGB(205, 240, 255)
		local bubOpts = { Reflectance = 0.3 }
		local spots = { Vector3.new(-2.45, 1.2, -0.3), Vector3.new(-2.8, 0.1, 0.5), Vector3.new(2.5, 1.45, 0.2), Vector3.new(2.3, 0.35, -1.0), Vector3.new(0.95, 2.65, 0.3), Vector3.new(-0.9, 2.45, -0.15) }
		local sizes = { 0.95, 0.55, 0.75, 0.45, 0.6, 0.45 }
		for i, p in spots do
			local d = sizes[i]
			ball(d, CFrame.new(p), bub, bubOpts)
			ball(d * 0.3, CFrame.new(p + Vector3.new(d * 0.18, d * 0.2, -d * 0.36)), WHITE)
		end
		-- starfish hair clip + a wave curl on top
		local coral = Color3.fromRGB(255, 140, 110)
		local sf = onSurf(Vector3.new(-0.75, 1.15, -0.45), 0.05)
		for k = 0, 4 do
			block(Vector3.new(0.2, 0.5, 0.12), sf * CFrame.Angles(0, 0, k * 2 * math.pi / 5) * at(0, 0.22, 0), coral)
		end
		ball(0.26, sf, coral)
		ball(0.6, at(0.1, 1.85, 0.1), color, bodyOpts)
		ball(0.35, at(0.35, 2.15, 0.22), color, bodyOpts)
	elseif style == "Siren" then
		-- flowing sea-green hair, fin ears, a scallop shell clip, pearls and a fish tail
		local hair = Color3.fromRGB(60, 150, 150)
		ball(2.9, at(0, 0.85, 0.45), hair)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.6, 1.7, 0.4), at(0.95 * s, -0.35, 1.3) * CFrame.Angles(0.25, 0, 0.15 * s), hair)
			wedge(Vector3.new(0.12, 0.75, 0.9), at(1.62 * s, 0.6, 0.15) * CFrame.Angles(0, 0, -0.45 * s), accent)
		end
		local shellC = Color3.fromRGB(255, 190, 200)
		local sc = onSurf(Vector3.new(0.95, 1.05, -0.65), 0.04)
		for k = -2, 2 do
			block(Vector3.new(0.17, 0.6, 0.08), sc * CFrame.Angles(0, 0, k * 0.33) * at(0, 0.28, 0), shellC)
		end
		ball(0.24, sc, U.Shade(shellC, 0.9))
		ruff(-0.95, 12, 0.3, WHITE, CREAM) -- pearl necklace
		flukes(accent, 0.55, 1.15)
	elseif style == "Leviathan" then
		local finC = U.Vivid(glow)
		-- dorsal fins from the crown down the back and tail
		fin(Vector3.new(0, 1, -0.15).Unit * R, Vector3.new(0, 1, -0.15), 1.4, 1.1, finC)
		fin(Vector3.new(0, 0.8, 0.6).Unit * R, Vector3.new(0, 0.8, 0.6), 1.15, 0.95, finC)
		fin(Vector3.new(0, 0.3, 1).Unit * R, Vector3.new(0, 0.3, 1), 0.95, 0.8, finC)
		fin(Vector3.new(0.15, -1.75, 0.95) + Vector3.new(0, -0.1, 1).Unit, Vector3.new(0, -0.1, 1), 0.7, 0.6, finC)
		fin(Vector3.new(-0.05, -2.35, 1.45) + Vector3.new(0, -0.4, 1).Unit * 0.675, Vector3.new(0, -0.4, 1), 0.5, 0.45, finC)
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.12, 0.95, 1.2), at(2.0 * s, -0.25, 0.2) * CFrame.Angles(0, 0, -0.6 * s), finC) -- side fin
			for k = 0, 1 do
				wedge(Vector3.new(0.1, 0.85 - k * 0.2, 0.6), at(1.45 * s, 0.95 - k * 0.45, 0.35) * CFrame.Angles(0.2, 0, -(0.7 + k * 0.3) * s), finC) -- ear frill
			end
			for _, d in { Vector3.new(1, 0.1, 0.5), Vector3.new(0.95, -0.45, 0.65), Vector3.new(0.8, -0.85, 0.75) } do
				ball(0.26, CFrame.new(surf(Vector3.new(d.X * s, d.Y, d.Z), -0.05)), glow, NEON) -- glowing spots
			end
			local w0 = surf(Vector3.new(0.45 * s, -0.2, -1.6), 0)
			local w1 = w0 + Vector3.new(0.9 * s, -0.55, -0.35)
			rod(w0, w1, 0.08, finC) -- whisker
			ball(0.18, CFrame.new(w1), finC)
			local hornC = Color3.fromRGB(230, 240, 235)
			local h0 = Vector3.new(0.55 * s, 1.5, 0.45)
			local h1 = Vector3.new(0.95 * s, 2.15, 0.95)
			rod(h0, h1, 0.32, hornC)
			rod(h1, Vector3.new(1.05 * s, 2.45, 1.55), 0.22, hornC)
			brow(s, 1.0, false, U.Shade(color, 0.5), 0.6)
		end
		fangs(WHITE)
		flukes(finC, 0.6, 1.2)
	elseif style == "Cog" then
		-- big brass gear halo behind the head, a small cog on the temple and an antenna
		local hcf = at(0, 1.35, 1.3)
		gear(hcf, 2.6, 0.24, 10, BRASS, METAL_MAT)
		cyl(0.3, 1.5, hcf * at(0, 0, 0.08) * U.AxisZ, U.Shade(BRASS, 0.75), METAL_MAT)
		cyl(0.4, 0.5, hcf * at(0, 0, 0.15) * U.AxisZ, METAL, METAL_MAT)
		local sg = onSurf(Vector3.new(-1.0, 1.0, -0.55), 0.05)
		gear(sg, 0.85, 0.16, 7, METAL, METAL_MAT)
		ball(0.26, sg, BRASS, METAL_MAT)
		rod(Vector3.new(0.45, 1.65, -0.2), Vector3.new(0.7, 2.5, -0.3), 0.08, METAL, METAL_MAT)
		ball(0.3, at(0.7, 2.55, -0.3), accent)
	elseif style == "Clockwork" then
		-- wind-up key on the back
		local k0 = Vector3.new(0, -0.15, 1.6)
		rod(k0, Vector3.new(0, -0.15, 2.6), 0.22, BRASS, METAL_MAT)
		cyl(0.2, 0.5, CFrame.new(k0 + Vector3.new(0, 0, 0.18)) * U.AxisZ, U.Shade(BRASS, 0.75), METAL_MAT)
		for _, s in { -1, 1 } do
			cyl(0.16, 0.85, at(0, -0.15 + 0.42 * s, 2.75), BRASS, METAL_MAT) -- key bow lobes
		end
		block(Vector3.new(0.18, 0.4, 0.35), at(0, -0.15, 2.7), BRASS, METAL_MAT)
		-- monocle + chain on the right eye
		local eye = Vector3.new(0.6, 0.35, -1.38)
		cyl(0.08, 1.2, U.DiscFacing(surf(eye, 0.08), eye), BRASS, METAL_MAT)
		block(Vector3.new(0.06, 0.9, 0.06), CFrame.new(surf(Vector3.new(1.0, -0.2, -1.4), 0.06)) * CFrame.Angles(0, 0, 0.25), BRASS)
		-- brass cap with a bolt, a riveted belt and a side gear
		cyl(0.3, 1.0, at(0, 1.72, 0.05) * U.AxisY, BRASS, METAL_MAT)
		ball(0.3, at(0, 1.95, 0.05), METAL, METAL_MAT)
		ring(-0.95, 0.16, BRASS, METAL_MAT)
		for _, a in { -0.9, -0.3, 0.3, 0.9 } do
			ball(0.18, CFrame.new(Vector3.new(math.sin(a) * 1.47, -0.95, -math.cos(a) * 1.47)), METAL, METAL_MAT)
		end
		gear(onSurf(Vector3.new(-1, 0.3, 0.55), 0.05), 1.0, 0.16, 8, U.Shade(BRASS, 0.85), METAL_MAT)
	elseif style == "TimeKeeper" then
		-- clock face on the belly
		local cd = Vector3.new(0, -0.9, -1)
		cyl(0.16, 1.25, U.DiscFacing(surf(cd, 0.0), cd), BRASS, METAL_MAT)
		cyl(0.16, 1.05, U.DiscFacing(surf(cd, 0.06), cd), CREAM)
		local cf = onSurf(cd, 0.15)
		for k = 0, 3 do
			block(Vector3.new(0.08, 0.2, 0.05), cf * CFrame.Angles(0, 0, k * math.pi / 2) * at(0, 0.4, 0), DARK)
		end
		block(Vector3.new(0.08, 0.32, 0.05), cf * CFrame.Angles(0, 0, -2.1) * at(0, 0.14, 0), DARK)
		block(Vector3.new(0.06, 0.44, 0.05), cf * CFrame.Angles(0, 0, 0.5) * at(0, 0.2, 0), DARK)
		ball(0.14, cf, GOLD, METAL_MAT)
		-- hourglass in the left nub
		local H = Vector3.new(-2.3, -0.6, -0.55)
		local sand = Color3.fromRGB(235, 200, 120)
		for _, y in { 0.75, -0.75 } do
			cyl(0.14, 0.85, CFrame.new(H + Vector3.new(0, y, 0)) * U.AxisY, WOOD)
		end
		for k = 0, 2 do
			local a = k * 2 * math.pi / 3
			local off = Vector3.new(math.cos(a) * 0.36, 0, math.sin(a) * 0.36)
			rod(H + off + Vector3.new(0, -0.7, 0), H + off + Vector3.new(0, 0.7, 0), 0.08, GOLD, METAL_MAT)
		end
		ball(0.62, CFrame.new(H + Vector3.new(0, 0.33, 0)), ICE, { Reflectance = 0.3 })
		ball(0.62, CFrame.new(H + Vector3.new(0, -0.33, 0)), sand)
		cyl(0.2, 0.2, CFrame.new(H) * U.AxisY, sand)
		-- gear halo with a glowing hub, and two clock hands as a crown
		local hcf = at(0, 1.4, 1.3)
		gear(hcf, 2.9, 0.26, 12, BRASS, METAL_MAT)
		cyl(0.3, 1.7, hcf * at(0, 0, 0.1) * U.AxisZ, U.Shade(BRASS, 0.7), METAL_MAT)
		ball(0.45, hcf * at(0, 0, 0.28), glow, NEON)
		local b0 = Vector3.new(0, 1.8, 0)
		ball(0.5, CFrame.new(b0), BRASS, METAL_MAT)
		for _, hand in { { a = 0.45, len = 1.0, w = 0.3 }, { a = -0.3, len = 1.5, w = 0.24 } } do
			local hf = CFrame.new(b0) * CFrame.Angles(0, 0, hand.a)
			block(Vector3.new(hand.w, hand.len, 0.12), hf * at(0, hand.len / 2, 0), DARK)
			point((hf * at(0, hand.len, 0)).Position, hf.UpVector, hand.w * 2.2, hand.w * 2.4, 0.12, DARK)
		end
		-- pendulum swinging under the tail
		rod(Vector3.new(0.2, -3.0, 1.9), Vector3.new(0.2, -4.3, 1.9), 0.1, BRASS, METAL_MAT)
		cyl(0.14, 0.8, at(0.2, -4.5, 1.9) * U.AxisZ, BRASS, METAL_MAT)
		-- Father Time's bushy brows and moustache
		for _, s in { -1, 1 } do
			local pos = surf(Vector3.new(0.36 * s, -0.2, -1.65), 0.05)
			wedge(Vector3.new(0.18, 0.32, 0.65), U.Facing(pos, pos) * CFrame.Angles(0, 0, 0.15 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), WHITE)
			brow(s, 0.98, false, WHITE, 0.65)
		end
	elseif style == "Ember" then
		-- flame tuft, floating sparks, a sooty tail tip and a marshmallow on a stick
		local hot = Color3.fromRGB(255, 230, 120)
		ball(0.95, at(0.05, 1.7, 0.1), glow, NEON)
		wedge(Vector3.new(0.4, 1.15, 0.65), at(0.05, 2.35, 0.2) * CFrame.Angles(-0.25, 0, 0), hot, NEON)
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.32, 0.8, 0.5), at(0.4 * s, 2.1, 0.15) * CFrame.Angles(-0.2, 0, -0.35 * s), glow, NEON)
		end
		for _, p in { Vector3.new(-1.95, 1.35, 0.3), Vector3.new(2.0, 1.75, -0.2), Vector3.new(1.1, 2.65, 0.5) } do
			ball(0.22, CFrame.new(p), glow, NEON)
		end
		ball(0.9, at(0.2, -2.72, 1.92), U.Shade(color, 0.45))
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.4, 0.7, -0.6).Unit
		rod(hand - dir * 0.15, hand + dir * 1.5, 0.08, WOOD)
		cyl(0.42, 0.38, U.Between(hand + dir * 1.35, hand + dir * 1.77), Color3.fromRGB(240, 215, 170))
	elseif style == "Magma" then
		-- basalt plates with glowing lava cracks between them, rocky fists and crest
		rockPlates(
			{ Vector3.new(0, 1, 0.15), Vector3.new(-0.9, 0.7, 0.25), Vector3.new(0.9, 0.65, 0.35), Vector3.new(-1, -0.2, 0.6), Vector3.new(1, -0.3, 0.55), Vector3.new(0, 0.3, 1), Vector3.new(-0.45, -0.75, 0.75), Vector3.new(0.5, -0.8, 0.6) },
			{ Vector3.new(-0.45, 0.95, 0.1), Vector3.new(0.5, 0.9, 0.3), Vector3.new(-1, 0.25, 0.4), Vector3.new(1, 0.2, 0.5), Vector3.new(0.25, -0.2, 1), Vector3.new(-0.2, -0.5, 0.95) },
			ROCK
		)
		for _, s in { -1, 1 } do
			ball(1.05, at(1.75 * s, -0.4, -0.2), ROCK)
		end
		block(Vector3.new(0.7, 0.6, 0.7), at(0.15, 1.95, 0.1) * CFrame.Angles(0.3, 0.5, 0.2), ROCK)
	elseif style == "Titan" then
		local hornC = Color3.fromRGB(55, 40, 40)
		-- huge curved horns
		for _, s in { -1, 1 } do
			local h0 = Vector3.new(0.95 * s, 1.25, 0.0)
			local h1 = Vector3.new(1.8 * s, 1.85, 0.15)
			local h2 = Vector3.new(2.25 * s, 2.65, 0.05)
			local h3 = Vector3.new(2.1 * s, 3.4, -0.3)
			rod(h0, h1, 0.6, hornC)
			ball(0.55, CFrame.new(h1), hornC)
			rod(h1, h2, 0.46, hornC)
			rod(h2, h3, 0.32, hornC)
			block(Vector3.new(0.3, 0.3, 0.3), CFrame.new(h3 + (h3 - h2).Unit * 0.1) * U.VertexUp, accent)
			brow(s, 0.98, true, DARK, 0.8)
			-- rocky pauldron with a lava crack
			local c = Vector3.new(1.8 * s, -0.3, -0.15)
			ball(1.3, CFrame.new(c), ROCK)
			local n = Vector3.new(0.5 * s, 0.4, -0.55).Unit
			block(Vector3.new(0.1, 0.55, 0.1), U.Facing(c + n * 0.63, n), glow, NEON)
		end
		-- molten crown: rock ring and spikes, lava drips and a glowing gem
		ring(1.3, 0.4, ROCK)
		for _, a in { 0, 0.85, -0.85, 2.3, -2.3, math.pi } do
			wedge(Vector3.new(0.42, 0.95, 0.5), CFrame.Angles(0, a, 0) * at(0, 1.97, -0.95), ROCK)
		end
		for _, a in { 1.2, -1.2, 2.4, -2.4 } do
			block(Vector3.new(0.14, 0.45, 0.1), onSurf(Vector3.new(math.sin(a), 0.65, -math.cos(a)), 0) * at(0, -0.1, 0), glow, NEON)
		end
		block(Vector3.new(0.42, 0.42, 0.42), CFrame.new(surf(Vector3.new(0, 1.3, -1.17), 0.12)) * U.VertexUp, glow, NEON)
		rockPlates(
			{ Vector3.new(0, 0.3, 1), Vector3.new(-1, -0.25, 0.55), Vector3.new(1, -0.3, 0.5), Vector3.new(0, -0.85, 0.7) },
			{ Vector3.new(0.5, 0.2, 1), Vector3.new(-0.5, -0.6, 0.9), Vector3.new(-0.95, 0.4, 0.6), Vector3.new(0.95, 0.35, 0.6) },
			ROCK
		)
		fangs(WHITE)
		-- three orbiting rock chunks with lava cores
		for i = 0, 2 do
			local cf = CFrame.Angles(0, i * 2 * math.pi / 3 + 0.3, 0) * at(0, 0.2 + 0.5 * math.sin(i * 2.1), -3.1) * CFrame.Angles(0.4, i, 0.3)
			block(Vector3.new(0.9, 0.75, 0.8), cf, ROCK)
			block(Vector3.new(0.12, 0.79, 0.84), cf * CFrame.Angles(0, 0, 0.5), glow, NEON)
		end
	elseif style == "Guard" then
		-- polished royal helmet with a gold crest, star badge and red plume
		local steel = Color3.fromRGB(200, 205, 222)
		local hc = Vector3.new(0, 1.0, 0.2)
		ball(3.2, CFrame.new(hc), steel, METAL_MAT)
		cyl(0.24, 3.3, at(0, 0.95, 0.2) * U.AxisY, GOLD, METAL_MAT)
		cyl(0.22, 3.28, CFrame.new(hc), GOLD, METAL_MAT)
		local bd = Vector3.new(0, 0.35, -1).Unit
		local bf = U.Facing(hc + bd * 1.62, bd)
		block(Vector3.new(0.5, 0.5, 0.12), bf, GOLD, METAL_MAT)
		block(Vector3.new(0.5, 0.5, 0.12), bf * CFrame.Angles(0, 0, math.pi / 4), GOLD, METAL_MAT)
		ball(0.22, bf * at(0, 0, -0.08), RED)
		ball(0.65, at(0, 2.75, 0.1), RED)
		ball(0.6, at(0, 2.6, 0.65), RED)
		ball(0.5, at(0, 2.25, 1.1), RED)
		-- spear
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.12, 1, -0.12).Unit
		local a = hand - dir * 1.2
		local b = hand + dir * 2.8
		rod(a, b, 0.16, WOOD)
		cyl(0.22, 0.26, U.Between(b - dir * 0.11, b + dir * 0.11), GOLD, METAL_MAT)
		point(b + dir * 0.05, dir, 0.42, 0.85, 0.1, steel, METAL_MAT)
		ball(0.3, CFrame.new(b - dir * 0.25 + Vector3.new(0.15, 0, 0)), RED) -- tassel
		ball(0.24, CFrame.new(a), GOLD, METAL_MAT)
		-- tabard shield with a little crown
		local sp = onSurf(Vector3.new(0, -1.2, -1.25), 0.04)
		block(Vector3.new(0.75, 0.6, 0.1), sp * at(0, 0.1, 0), RED)
		block(Vector3.new(0.53, 0.53, 0.1), sp * at(0, -0.15, 0) * CFrame.Angles(0, 0, math.pi / 4), RED)
		block(Vector3.new(0.35, 0.15, 0.12), sp * at(0, 0.2, -0.04), GOLD)
		for _, s in { -1, 1 } do
			cyl(0.2, 0.85, at(1.62 * s, 0.15, -0.2) * U.AxisY, GOLD, METAL_MAT)
		end
	elseif style == "Shadow" then
		-- dark wisps for hair, smoky trails behind the nubs and the tail (glowing eyes + grin above)
		local dark = U.Shade(color, 0.6)
		for i = -1, 1 do
			wedge(Vector3.new(0.35, 1.0 - math.abs(i) * 0.25, 0.65), at(i * 0.55, 1.95 - math.abs(i) * 0.2, 0.15) * CFrame.Angles(-0.35, 0, -0.35 * i), dark)
		end
		for _, s in { -1, 1 } do
			ball(0.7, at(2.1 * s, -0.6, 0.15), color, bodyOpts)
			ball(0.48, at(2.35 * s, -0.95, 0.5), color, bodyOpts)
			ball(0.3, at(2.5 * s, -1.25, 0.8), color, bodyOpts)
			brow(s, 1.0, true, dark, 0.6)
		end
		ball(0.5, at(0.35, -3.0, 2.3), color, bodyOpts)
		ball(0.3, at(0.5, -3.25, 2.6), color, bodyOpts)
	elseif style == "GhostKing" then
		local gems = { RED, Color3.fromRGB(60, 120, 255), Color3.fromRGB(60, 200, 110), Color3.fromRGB(190, 90, 255) }
		local glass = { Reflectance = 0.25 }
		-- huge jewelled crown over a velvet cap, topped by an orb and cross
		local ccf = at(0, 1.35, 0.05)
		cyl(0.85, 2.65, ccf * U.AxisY, GOLD, METAL_MAT)
		ball(2.35, ccf * at(0, 0.45, 0), PURPLE)
		for i = 0, 7 do
			local rot = ccf * CFrame.Angles(0, i * math.pi / 4 + math.pi / 8, 0)
			wedge(Vector3.new(0.5, 1.2, 0.42), rot * at(0, 1.0, -1.12), GOLD, METAL_MAT)
			ball(0.32, rot * at(0, 1.66, -0.97), WHITE, glass) -- pearl
			ball(0.3, rot * at(0, 0.02, -1.33), gems[i % 4 + 1], glass) -- band jewel
		end
		block(Vector3.new(0.55, 0.55, 0.55), ccf * at(0, 0.1, -1.4) * U.VertexUp, glow, NEON) -- great front jewel
		ball(0.62, ccf * at(0, 1.75, 0), GOLD, METAL_MAT)
		block(Vector3.new(0.18, 0.75, 0.18), ccf * at(0, 2.3, 0), GOLD, METAL_MAT)
		block(Vector3.new(0.5, 0.18, 0.18), ccf * at(0, 2.38, 0), GOLD, METAL_MAT)
		-- tall cape collar, ermine ruff and a long cape with a gold hem
		for i = -2, 2 do
			local cf = CFrame.Angles(0, i * 0.42, 0) * at(0, 0.0, 1.8) * CFrame.Angles(0.4, 0, 0)
			block(Vector3.new(0.65, 1.9, 0.14), cf, PURPLE)
			block(Vector3.new(0.68, 0.16, 0.2), cf * at(0, 0.95, 0), GOLD, METAL_MAT)
		end
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
		local capeCf = at(0, -1.1, 2.0) * CFrame.Angles(-0.25, 0, 0)
		block(Vector3.new(3.2, 2.9, 0.2), capeCf, PURPLE)
		block(Vector3.new(3.2, 0.2, 0.24), capeCf * at(0, -1.4, 0), GOLD, METAL_MAT)
		-- royal moustache and gold epaulettes
		for _, s in { -1, 1 } do
			local pos = surf(Vector3.new(0.36 * s, -0.2, -1.65), 0.05)
			wedge(Vector3.new(0.18, 0.32, 0.65), U.Facing(pos, pos) * CFrame.Angles(0, 0, 0.15 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), BEARD)
			ball(0.3, CFrame.new(surf(Vector3.new(0.75 * s, -0.05, -1.5), 0.08)), BEARD)
			cyl(0.22, 0.95, at(1.62 * s, 0.15, -0.2) * U.AxisY, GOLD, METAL_MAT)
		end
		-- winged scepter with a great glowing gem
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.2, 1, -0.3).Unit
		rod(hand - dir * 0.7, hand + dir * 2.3, 0.2, GOLD, METAL_MAT)
		ball(0.42, CFrame.new(hand + dir * 2.35), GOLD, METAL_MAT)
		ball(0.3, CFrame.new(hand - dir * 0.75), GOLD, METAL_MAT)
		local gp = hand + dir * 2.85
		block(Vector3.new(0.7, 0.7, 0.7), CFrame.new(gp) * U.VertexUp, glow, NEON)
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.1, 0.6, 0.6), CFrame.new(gp + Vector3.new(0.5 * s, -0.15, 0)) * CFrame.Angles(0, -math.pi / 2 * s, 0), GOLD, METAL_MAT)
		end
		-- six royal gems orbiting
		for i = 0, 5 do
			local a = math.rad(60 + i * 48) -- 60..300 degrees: the face stays clear
			local y = if i % 2 == 0 then 0.9 else -0.4
			local gc = gems[i % 4 + 1]
			crystal(CFrame.Angles(0, a, 0) * at(0, y, -3.4) * CFrame.Angles(0.15, 0, 0.3), 0.45, 1.2, gc, glass, gc, NEON, false)
		end
	------------------------------------------------------------------ boss tower (regular)
	elseif style == "Jester" then
		-- three-pointed two-colour jester cap with gold bells, harlequin ruff, juggling balls
		local capA = Color3.fromRGB(140, 70, 215)
		local capB = Color3.fromRGB(255, 205, 60)
		ball(2.75, at(0, 0.95, 0.2), capA)
		ring(1.1, 0.3, capB)
		local horns = {
			{ a = Vector3.new(-0.75, 2.0, 0.2), b = Vector3.new(-1.65, 2.6, 0.3), c = Vector3.new(-2.05, 1.95, 0.35), col = capB },
			{ a = Vector3.new(0, 2.25, 0.45), b = Vector3.new(0, 2.95, 0.95), c = Vector3.new(0, 2.45, 1.6), col = capA },
			{ a = Vector3.new(0.75, 2.0, 0.2), b = Vector3.new(1.65, 2.6, 0.3), c = Vector3.new(2.05, 1.95, 0.35), col = capB },
		}
		for _, h in horns do
			local a, b, c, col = h.a, h.b, h.c, h.col
			rod(a, b, 0.6, col)
			rod(b, c, 0.42, col)
			ball(0.5, CFrame.new(c + (c - b).Unit * 0.22), GOLD, METAL_MAT) -- bell
		end
		ruff(-1.05, 8, 0.62, capA, capB)
		ball(0.55, at(-2.35, 0.75, -0.85), Color3.fromRGB(80, 170, 255))
		ball(0.5, at(-2.05, 1.55, -0.65), glow, NEON)
	elseif style == "PumpkinKnight" then
		-- jack-o'-lantern helmet with stem and leaf, steel collar and pauldrons, striped lance, leafy cape
		local pumpkin = Color3.fromRGB(255, 140, 40)
		local leaf = Color3.fromRGB(80, 170, 75)
		local steel = Color3.fromRGB(200, 205, 222)
		local hc = Vector3.new(0, 1.05, 0.15)
		ball(3.0, CFrame.new(hc), pumpkin)
		for _, s in { -1, 1 } do
			ball(2.5, CFrame.new(hc + Vector3.new(0.62 * s, -0.05, 0.08)), U.Shade(pumpkin, 0.9))
			ball(1.15, at(1.85 * s, -0.15, -0.1), steel, METAL_MAT) -- pauldron
		end
		cyl(0.65, 0.38, at(0.05, 2.75, 0.2) * CFrame.Angles(0, 0, -0.2) * U.AxisY, Color3.fromRGB(110, 150, 60))
		wedge(Vector3.new(0.1, 0.45, 0.95), at(0.45, 2.62, 0.35) * CFrame.Angles(0.2, 0.5, 0.45), leaf)
		ring(-0.72, 0.32, steel, METAL_MAT)
		-- jousting lance in the right nub
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.45, 1, -0.45).Unit
		rod(hand - dir * 0.7, hand + dir * 0.2, 0.2, WOOD)
		cyl(0.18, 0.95, U.Between(hand + dir * 0.2, hand + dir * 0.38), GOLD, METAL_MAT) -- vamplate
		cone(along(hand + dir * 0.35, dir), 0.62, 2.7, 4, pumpkin, CREAM)
		-- round shield on the left nub
		local sc = at(-2.1, -0.5, -0.5) * CFrame.Angles(0, 0.55, 0)
		cyl(0.14, 1.4, sc * U.AxisZ, WOOD)
		cyl(0.16, 0.75, sc * at(0, 0, -0.04) * U.AxisZ, U.Shade(glow, 0.8))
		block(Vector3.new(2.8, 2.4, 0.18), at(0, -1.0, 1.95) * CFrame.Angles(-0.2, 0, 0), leaf) -- cape
	elseif style == "SwampHag" then
		-- crooked witch hat, long warty nose, stringy hair, bubbling cauldron and a broom
		local hatC = Color3.fromRGB(85, 55, 125)
		local hcf = at(0.1, 1.5, 0.15) * CFrame.Angles(0.05, 0, -0.12)
		cyl(0.14, 3.1, hcf * U.AxisY, hatC)
		local tip = cone(hcf, 1.65, 1.55, 3, hatC)
		cyl(0.24, 1.66, hcf * at(0, 0.16, 0) * U.AxisY, Color3.fromRGB(255, 140, 40)) -- band
		local tp = tip.Position
		rod(tp - Vector3.new(0, 0.1, 0), tp + Vector3.new(0.65, 0.2, 0.15), 0.32, hatC) -- bent tip
		point(Vector3.new(0, 0.02, -1.6), Vector3.new(0, -0.25, -1), 0.45, 0.75, 0.4, U.Shade(color, 0.85))
		ball(0.2, at(0.1, -0.08, -2.12), Color3.fromRGB(90, 140, 60)) -- wart
		local hair = Color3.fromRGB(195, 200, 210)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.25, 1.35, 0.5), at(1.38 * s, 0.75, 0.15) * CFrame.Angles(0, 0, 0.15 * s), hair)
			block(Vector3.new(0.25, 1.15, 0.5), at(1.15 * s, 0.7, 0.85) * CFrame.Angles(0.2, 0, 0.2 * s), hair)
		end
		local mouthTooth = surf(Vector3.new(0.12, -0.42, -1.7), 0.08)
		wedge(Vector3.new(0.08, 0.22, 0.22), U.Facing(mouthTooth, mouthTooth) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, WHITE)
		-- cauldron by the left nub
		local pot = Vector3.new(-2.55, -0.95, -0.6)
		ball(1.15, CFrame.new(pot), DARK)
		cyl(0.16, 1.05, CFrame.new(pot + Vector3.new(0, 0.42, 0)) * U.AxisY, METAL, METAL_MAT)
		cyl(0.06, 0.9, CFrame.new(pot + Vector3.new(0, 0.5, 0)) * U.AxisY, U.Shade(glow, 0.8), { Reflectance = 0.2 })
		ball(0.3, CFrame.new(pot + Vector3.new(0.15, 0.75, -0.1)), accent)
		ball(0.2, CFrame.new(pot + Vector3.new(-0.2, 1.05, 0.05)), accent)
		-- broom in the right nub
		local b0 = Vector3.new(2.05, 1.5, -0.05)
		local b1 = Vector3.new(1.7, -1.9, -0.45)
		rod(b0, b1, 0.16, WOOD)
		local bd = (b1 - b0).Unit
		cone(along(b1 + bd * 0.75, -bd), 0.75, 0.85, 2, Color3.fromRGB(230, 190, 90), Color3.fromRGB(210, 165, 70))
	elseif style == "ClockSpecter" then
		-- cog crown, clock face on the belly, monocle, side gear and a wind-up key in the back
		local fc = onSurf(Vector3.new(0, -1.0, -1.15), 0.02)
		cyl(0.14, 1.2, fc * U.AxisZ, BRASS, METAL_MAT)
		cyl(0.16, 1.0, fc * at(0, 0, -0.02) * U.AxisZ, CREAM)
		block(Vector3.new(0.08, 0.38, 0.06), fc * at(0, 0.16, -0.11), DARK)
		block(Vector3.new(0.3, 0.08, 0.06), fc * at(0.13, 0, -0.11), DARK)
		ball(0.16, fc * at(0, 0, -0.12), glow, NEON)
		gear(at(0, 2.15, 0.25), 1.5, 0.25, 7, BRASS, METAL_MAT)
		gear(at(-1.45, 1.2, 0.35) * CFrame.Angles(0, math.pi / 2, 0.3), 0.95, 0.2, 5, U.Shade(BRASS, 0.8), METAL_MAT)
		local eye = Vector3.new(0.6, 0.35, -1.38)
		cyl(0.08, 1.2, U.DiscFacing(surf(eye, 0.08), eye), GOLD, METAL_MAT)
		rod(Vector3.new(0, 0.1, 1.5), Vector3.new(0, 0.1, 2.45), 0.2, BRASS, METAL_MAT)
		for _, s in { -1, 1 } do
			cyl(0.12, 0.65, at(0, 0.1 + 0.3 * s, 2.6), BRASS, METAL_MAT) -- key bow
		end
	elseif style == "Banshee" then
		-- long flowing hair, diamond tiara, wailing mouth, sad brows and wispy trailing arms
		local hair = Color3.fromRGB(95, 70, 170)
		local silver = Color3.fromRGB(225, 230, 245)
		ball(3.25, at(0, 0.6, 0.45), hair)
		for i = -2, 2 do
			local x = i * 0.55
			block(Vector3.new(0.55, 2.5 - math.abs(i) * 0.2, 0.3), at(x, -0.55 - (i % 2) * 0.2, 2.02 - math.abs(i) * 0.18) * CFrame.Angles(-0.12, 0, i * 0.08), hair)
		end
		ring(1.15, 0.2, silver, METAL_MAT)
		for _, a in { -0.5, 0.5 } do
			block(Vector3.new(0.28, 0.28, 0.28), CFrame.Angles(0, a, 0) * at(0, 1.42, -1.12) * U.VertexUp, silver, METAL_MAT)
		end
		block(Vector3.new(0.4, 0.4, 0.4), at(0, 1.5, -1.12) * U.VertexUp, glow, NEON)
		cyl(0.25, 0.85, U.DiscFacing(mouthPos, mouthPos), MOUTH) -- wide wail
		for _, s in { -1, 1 } do
			brow(s, 0.98, false, hair, 0.55)
			ball(0.72, at(2.1 * s, -0.6, 0.15), color, bodyOpts)
			ball(0.5, at(2.35 * s, -0.95, 0.5), color, bodyOpts)
			ball(0.3, at(2.5 * s, -1.25, 0.8), color, bodyOpts)
		end
	elseif style == "BoneCaptain" then
		-- skull-and-crossbones tricorn with a red feather, ribcage, hook hand and a cutlass
		local hatC = Color3.fromRGB(45, 35, 60)
		local bone = Color3.fromRGB(245, 240, 225)
		local steel = Color3.fromRGB(200, 205, 222)
		local hcf = at(0, 1.5, 0.15) * CFrame.Angles(-0.05, 0, 0.05)
		cyl(0.16, 3.0, hcf * U.AxisY, hatC)
		ball(2.3, hcf * at(0, 0.3, 0), hatC)
		for k = 0, 2 do
			local rot = hcf * CFrame.Angles(0, k * 2 * math.pi / 3, 0)
			wedge(Vector3.new(1.75, 0.75, 0.4), rot * at(0, 0.36, -1.22) * CFrame.Angles(0, math.pi, 0), hatC)
		end
		local sk = hcf * at(0, 0.62, -1.38)
		ball(0.45, sk, bone)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.75, 0.1, 0.08), sk * at(0, -0.05, 0.12) * CFrame.Angles(0, 0, 0.6 * s), bone)
		end
		wedge(Vector3.new(0.12, 0.45, 1.5), hcf * at(0.95, 0.75, 0.55) * CFrame.Angles(0.55, 0.3, 0), RED)
		-- ribcage on the chest
		block(Vector3.new(0.14, 0.75, 0.08), onSurf(Vector3.new(0, -1.15, -1.25), 0.02), bone)
		for k = 0, 2 do
			block(Vector3.new(1.25 - k * 0.2, 0.12, 0.1), onSurf(Vector3.new(0, -0.9 - k * 0.27, -1.3), 0.02), bone)
		end
		-- hook hand on the left nub
		cyl(0.3, 0.62, at(-2.0, -0.38, -0.25), hatC)
		rod(Vector3.new(-2.15, -0.38, -0.25), Vector3.new(-2.6, -0.38, -0.3), 0.12, steel, METAL_MAT)
		rod(Vector3.new(-2.6, -0.38, -0.3), Vector3.new(-2.82, -0.05, -0.38), 0.12, steel, METAL_MAT)
		rod(Vector3.new(-2.82, -0.05, -0.38), Vector3.new(-2.6, 0.2, -0.45), 0.12, steel, METAL_MAT)
		-- cutlass in the right nub
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.3, 0.9, -0.4).Unit
		rod(hand - dir * 0.45, hand + dir * 0.3, 0.16, hatC)
		cyl(0.2, 0.55, U.Between(hand + dir * 0.3, hand + dir * 0.5), GOLD, METAL_MAT)
		block(Vector3.new(0.08, 1.7, 0.32), along(hand + dir * 1.35, dir), steel, METAL_MAT)
		point(hand + dir * 2.15, dir, 0.32, 0.45, 0.08, steel, METAL_MAT)
	elseif style == "MummyPharaoh" then
		-- striped nemes headdress with a cobra, broad collar, bandage wraps, false beard and a glowing ankh
		local blue = Color3.fromRGB(60, 105, 225)
		local wrap = U.Shade(color, 0.88)
		local hc = Vector3.new(0, 0.95, 0.3)
		ball(2.95, CFrame.new(hc), blue)
		bandOn(hc, 1.47, 0.25, 0.16, GOLD, METAL_MAT)
		bandOn(hc, 1.47, 0.7, 0.16, GOLD, METAL_MAT)
		ring(1.0, 0.3, GOLD, METAL_MAT)
		for _, s in { -1, 1 } do
			local lf = onSurf(Vector3.new(0.9 * s, -0.1, -0.45), 0.1)
			block(Vector3.new(0.62, 1.85, 0.25), lf * at(0, -0.2, 0), blue)
			block(Vector3.new(0.64, 0.16, 0.27), lf * at(0, -0.45, 0), GOLD, METAL_MAT)
		end
		local up = surf(Vector3.new(0, 1.15, -1.2), 0.12)
		ball(0.4, CFrame.new(up), GOLD, METAL_MAT)
		block(Vector3.new(0.14, 0.14, 0.14), CFrame.new(up + Vector3.new(0, 0.05, -0.2)), glow, NEON)
		ring(-0.62, 0.2, blue)
		ring(-0.82, 0.2, GOLD, METAL_MAT)
		ring(-1.25, 0.22, wrap, nil, 0.22)
		bandOn(Vector3.new(0.15, -1.75, 0.95), 1.0, 0, 0.22, wrap, nil, -0.3)
		block(Vector3.new(0.3, 0.6, 0.3), at(0, -1.0, -1.55) * CFrame.Angles(-0.3, 0, 0), GOLD, METAL_MAT)
		-- ankh staff in the right nub
		local ax = Vector3.new(1.95, 0, -0.45)
		rod(ax + Vector3.new(0, -1.5, 0), ax + Vector3.new(0, 1.3, 0), 0.2, GOLD, METAL_MAT)
		block(Vector3.new(0.95, 0.2, 0.2), CFrame.new(ax + Vector3.new(0, 1.25, 0)), GOLD, METAL_MAT)
		cyl(0.18, 0.8, CFrame.new(ax + Vector3.new(0, 1.78, 0)) * U.AxisZ, GOLD, METAL_MAT)
		cyl(0.22, 0.42, CFrame.new(ax + Vector3.new(0, 1.78, 0)) * U.AxisZ, glow, NEON)
	elseif style == "FrostWraith" then
		-- deep hood with an icicle crown, icicle beard, snowy shoulders and a frost staff
		local hood = Color3.fromRGB(70, 95, 185)
		local glass = { Reflectance = 0.25 }
		ball(3.2, at(0, 0.65, 0.45), hood)
		wedge(Vector3.new(0.6, 1.1, 1.0), at(0, 2.1, 0.95) * CFrame.Angles(-0.4, 0, 0), hood)
		for i, a in { -0.95, -0.48, 0, 0.48, 0.95 } do
			local h = if i == 3 then 1.25 elseif i % 2 == 0 then 0.95 else 0.7
			crystal(CFrame.Angles(0, a, 0) * at(0, 1.75, -0.6) * CFrame.Angles(-0.3, 0, 0) * at(0, h / 2, 0), 0.32, h, ICE, glass, WHITE, nil, false)
		end
		for i = -1, 1 do
			local base = surf(Vector3.new(i * 0.35, -0.85, -1.4), -0.05)
			point(base, Vector3.new(i * 0.15, -1, -0.2), 0.26, 0.75 - math.abs(i) * 0.2, 0.26, ICE, glass)
		end
		for _, s in { -1, 1 } do
			ball(1.05, at(1.62 * s, 0.1, 0.1), WHITE)
		end
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.12, 1, -0.2).Unit
		rod(hand - dir * 1.3, hand + dir * 2.0, 0.16, Color3.fromRGB(150, 170, 210))
		crystal(along(hand + dir * 2.45, dir), 0.42, 0.75, ICE, glass, glow, NEON, true)
	elseif style == "PuppetMaster" then
		-- floating control cross on glowing strings, two mini ghost puppets, beret and harlequin ruff
		local cc = Vector3.new(0, 3.15, -0.35)
		block(Vector3.new(2.9, 0.22, 0.22), CFrame.new(cc), WOOD)
		block(Vector3.new(0.22, 0.22, 1.3), CFrame.new(cc), WOOD)
		rod(Vector3.new(1.75, -0.35, -0.2), cc + Vector3.new(0.3, -0.1, 0), 0.07, U.Shade(glow, 0.8)) -- ecto tether
		local puppets = {
			{ s = -1, body = Color3.fromRGB(255, 245, 235), bow = RED },
			{ s = 1, body = Color3.fromRGB(255, 220, 240), bow = Color3.fromRGB(80, 170, 255) },
		}
		for _, pp in puppets do
			local s, body, bow = pp.s, pp.body, pp.bow
			local pc = Vector3.new(2.6 * s, 0.1, -0.75)
			rod(cc + Vector3.new(1.4 * s, 0, 0), pc + Vector3.new(0, 0.45, 0), 0.05, WHITE)
			ball(0.95, CFrame.new(pc), body)
			for _, e in { -1, 1 } do
				ball(0.18, CFrame.new(pc + Vector3.new(0.17 * e, 0.08, -0.42)), EYE)
			end
			ball(0.3, CFrame.new(pc + Vector3.new(0.25, 0.42, -0.1)), bow)
		end
		ruff(-1.0, 8, 0.58, RED, CREAM)
		local bcf = at(0.35, 1.68, 0.1) * CFrame.Angles(0, 0, -0.3)
		cyl(0.28, 1.7, bcf * U.AxisY, Color3.fromRGB(60, 40, 90))
		ball(0.28, bcf * at(0, 0.2, 0), Color3.fromRGB(60, 40, 90))
	elseif style == "StormPhantom" then
		-- thunder-cloud crown, two lightning bolts, wind bands and angry brows
		local cloud = Color3.fromRGB(230, 235, 250)
		local cloudD = Color3.fromRGB(175, 185, 215)
		ball(1.4, at(0, 2.05, 0.2), cloud)
		ball(1.05, at(0.78, 1.85, 0.1), cloudD)
		ball(1.1, at(-0.78, 1.9, 0.25), cloud)
		ball(1.0, at(0.35, 1.8, 0.9), cloudD)
		ball(0.9, at(-0.3, 1.75, -0.45), cloud)
		ball(0.85, at(0.55, 2.3, 0.55), cloud)
		local function bolt(pts: { Vector3 })
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				block(Vector3.new(0.24, (b - a).Magnitude + 0.12, 0.12), along((a + b) / 2, (b - a).Unit), accent)
			end
		end
		bolt({ Vector3.new(-1.25, 1.5, -0.2), Vector3.new(-1.85, 0.85, -0.45), Vector3.new(-1.5, 0.65, -0.45), Vector3.new(-2.15, -0.15, -0.7) })
		bolt({ Vector3.new(1.85, -0.75, -0.45), Vector3.new(2.25, 0.45, -0.55), Vector3.new(1.9, 0.65, -0.55), Vector3.new(2.35, 1.95, -0.7) })
		local wind = Color3.fromRGB(205, 240, 255)
		ring(-0.9, 0.16, wind, nil, 0.3)
		ring(-1.3, 0.16, wind, nil, -0.25)
		for _, s in { -1, 1 } do
			brow(s, 1.0, true, Color3.fromRGB(70, 75, 130), 0.6)
		end
		ball(0.55, at(0.4, -3.0, 2.3), cloud)
		ball(0.4, at(0.6, -3.25, 2.65), cloudD)
	elseif style == "HauntedArmor" then
		-- horned great helm with a plume, nasal guard, spiked pauldrons, breastplate and a greatsword
		local steel = Color3.fromRGB(195, 202, 222)
		local horn = Color3.fromRGB(245, 235, 210)
		ball(3.35, at(0, 1.0, 0.2), steel, METAL_MAT)
		cyl(0.26, 3.45, at(0, 0.98, 0.2) * U.AxisY, U.Shade(steel, 0.8), METAL_MAT)
		block(Vector3.new(0.2, 0.7, 0.18), U.Facing(surf(Vector3.new(0, 0.55, -1.6), 0.1), Vector3.new(0, 0.3, -1)), steel, METAL_MAT)
		fin(Vector3.new(0, 2.5, 0.25), Vector3.new(0, 1, 0.15), 0.75, 1.3, RED)
		for _, s in { -1, 1 } do
			rod(Vector3.new(0.95 * s, 1.95, 0.3), Vector3.new(1.65 * s, 2.45, 0.25), 0.42, horn)
			rod(Vector3.new(1.65 * s, 2.45, 0.25), Vector3.new(1.8 * s, 3.15, 0.0), 0.28, horn)
			local pc = Vector3.new(1.85 * s, -0.05, -0.05)
			ball(1.35, CFrame.new(pc), steel, METAL_MAT)
			point(pc + Vector3.new(0.3 * s, 0.45, 0), Vector3.new(0.45 * s, 1, 0), 0.32, 0.6, 0.32, U.Shade(steel, 0.7), METAL_MAT)
		end
		ring(-1.0, 0.55, steel, METAL_MAT)
		block(Vector3.new(0.32, 0.32, 0.32), CFrame.new(surf(Vector3.new(0, -1.0, -1.42), 0.04)) * U.VertexUp, glow, NEON)
		-- greatsword in the right nub
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.1, 1, -0.2).Unit
		rod(hand - dir * 0.6, hand + dir * 0.3, 0.2, DARK)
		ball(0.32, CFrame.new(hand - dir * 0.65), GOLD, METAL_MAT)
		block(Vector3.new(0.18, 0.2, 1.3), along(hand + dir * 0.38, dir), GOLD, METAL_MAT)
		block(Vector3.new(0.12, 2.8, 0.45), along(hand + dir * 1.9, dir), steel, METAL_MAT)
		block(Vector3.new(0.14, 2.0, 0.1), along(hand + dir * 1.8, dir), U.Shade(glow, 0.75))
		point(hand + dir * 3.28, dir, 0.45, 0.6, 0.12, steel, METAL_MAT)
	elseif style == "CandleLich" then
		-- crown of melting candles with ecto flames, wax drips, high collar, skull staff and a spellbook
		local wax = Color3.fromRGB(255, 244, 220)
		local robe = Color3.fromRGB(80, 45, 125)
		for i, a in { 0, 1.2, -1.2, 2.4, -2.4 } do
			local h = if i == 1 then 1.0 elseif i <= 3 then 0.8 else 0.6
			local x, z = math.sin(a) * 0.85, -math.cos(a) * 0.85 + 0.1
			cyl(h, 0.36, at(x, 1.45 + h / 2, z) * U.AxisY, wax)
			local flameOpts: U.Opts? = if i == 1 then NEON else nil
			block(Vector3.new(0.26, 0.26, 0.26), at(x, 1.47 + h + 0.18, z) * U.VertexUp, if i == 1 then glow else U.Shade(glow, 0.8), flameOpts)
		end
		for _, s in { -1, 1 } do
			ball(0.3, CFrame.new(surf(Vector3.new(0.4 * s, 1.15, -1.1), -0.05)), wax)
		end
		for i = -1, 1 do
			block(Vector3.new(0.7, 1.6, 0.14), CFrame.Angles(0, i * 0.5, 0) * at(0, -0.1, 1.75) * CFrame.Angles(0.35, 0, 0), robe)
		end
		fangs(WHITE)
		local hand = Vector3.new(1.75, -0.35, -0.2)
		local dir = Vector3.new(0.15, 1, -0.2).Unit
		rod(hand - dir * 1.3, hand + dir * 2.0, 0.18, Color3.fromRGB(70, 50, 60))
		local sp = hand + dir * 2.35
		ball(0.65, CFrame.new(sp), WHITE)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.14, 0.14, 0.1), CFrame.new(sp + Vector3.new(0.13 * s, 0.03, -0.29)), DARK)
		end
		block(Vector3.new(0.35, 0.35, 0.35), CFrame.new(sp + Vector3.new(0, 0.55, 0)) * U.VertexUp, glow, NEON)
		local bcf = at(-2.5, 0.5, -0.35) * CFrame.Angles(0.15, 0.6, 0.2)
		block(Vector3.new(0.95, 1.15, 0.28), bcf, robe)
		block(Vector3.new(0.85, 1.05, 0.3), bcf * at(0.06, 0, 0), wax)
	elseif style == "VampireCount" then
		-- slicked hair with a widow's peak, bat-wing collar, cape, cravat, medallion, fangs and a pet bat
		local hairC = Color3.fromRGB(45, 35, 75)
		local cape = Color3.fromRGB(40, 30, 60)
		local lining = Color3.fromRGB(200, 30, 60)
		ball(2.95, at(0, 1.0, 0.35), hairC)
		block(Vector3.new(0.5, 0.5, 0.25), onSurf(Vector3.new(0, 1.05, -1.3), -0.05) * CFrame.Angles(0, 0, math.pi / 4), hairC)
		for _, s in { -1, 1 } do
			local cf = at(1.05 * s, 0.75, 1.0) * CFrame.Angles(0, 0.55 * s, 0) * CFrame.Angles(0.2, 0, -0.35 * s)
			block(Vector3.new(1.35, 2.1, 0.14), cf, cape)
			block(Vector3.new(1.15, 1.9, 0.1), cf * at(0, 0, -0.08), lining)
			brow(s, 0.98, true, hairC, 0.6)
		end
		block(Vector3.new(3.4, 3.0, 0.2), at(0, -1.0, 2.0) * CFrame.Angles(-0.2, 0, 0), cape)
		ball(0.55, CFrame.new(surf(Vector3.new(0, -0.95, -1.3), 0.0)), WHITE) -- cravat
		local mp = surf(Vector3.new(0, -1.35, -1.05), 0.05)
		cyl(0.12, 0.55, U.DiscFacing(mp, mp), GOLD, METAL_MAT)
		ball(0.28, CFrame.new(mp + mp.Unit * 0.06), glow, NEON)
		fangs(WHITE)
		-- pet bat by the left side
		local bat = Vector3.new(-2.45, 1.25, -0.6)
		local batC = Color3.fromRGB(85, 55, 120)
		ball(0.6, CFrame.new(bat), batC)
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.06, 0.45, 0.75), CFrame.new(bat + Vector3.new(0.5 * s, 0.1, 0)) * CFrame.Angles(0, -math.pi / 2 * s, 0) * CFrame.Angles(0, 0, 0), batC)
			ball(0.12, CFrame.new(bat + Vector3.new(0.12 * s, 0.07, -0.26)), glow, NEON)
		end
	elseif style == "CrystalTitan" then
		-- tower take on the Overlord crown: same crystals, but glassy tips; only the circlet jewel glows
		local gem = U.Vivid(glow)
		local tip = U.Shade(glow, 0.85)
		local glass = { Reflectance = 0.25 }
		cyl(0.42, 2.55, at(0, 1.25, 0.05) * U.AxisY, GOLD, METAL_MAT)
		crystal(at(0, 1.6, -0.3) * at(0, 0.8, 0), 0.52, 1.6, gem, glass, tip, glass, false)
		for _, s in { -1, 1 } do
			crystal(at(0.8 * s, 1.5, 0.1) * CFrame.Angles(0, 0, -0.55 * s) * at(0, 0.7, 0), 0.45, 1.4, gem, glass, tip, glass, false)
			crystal(at(0.45 * s, 1.45, -0.62) * CFrame.Angles(-0.25, 0, -0.3 * s) * at(0, 0.35, 0), 0.3, 0.7, gem, glass, tip, glass, false)
			brow(s, 0.98, true, DARK, 0.7)
		end
		block(Vector3.new(0.4, 0.4, 0.4), at(0, 1.25, -1.33) * U.VertexUp, glow, NEON) -- circlet jewel
		ring(-0.75, 0.22, GOLD, METAL_MAT)
		for i = -2, 2 do
			block(Vector3.new(0.6, 1.3, 0.14), CFrame.Angles(0, i * 0.42, 0) * at(0, -0.15, 1.75) * CFrame.Angles(0.35, 0, 0), Color3.fromRGB(70, 50, 120))
		end
		for i = 0, 4 do
			local a = math.pi / 5 + i * 2 * math.pi / 5
			local y = if i % 2 == 0 then 0.7 else -0.5
			crystal(CFrame.Angles(0, a, 0) * at(0, y, -3.1) * CFrame.Angles(0.15, 0, 0.3), 0.45, 1.3, gem, glass, tip, glass, true)
		end
	------------------------------------------------------------------ boss tower (BIG milestone bosses)
	elseif style == "GraveColossus" then
		-- tombstone crown, tombstone pauldrons with glowing cracks, iron-fence back, rock plates,
		-- tombstone hammer, grave lantern and a floating skull
		local moss = Color3.fromRGB(95, 195, 95)
		local iron = Color3.fromRGB(55, 50, 70)
		for i, t in { { -0.8, 0.35, 0.9 }, { 0, 0, 1.25 }, { 0.8, -0.35, 0.9 } } :: { { number } } do
			local x, tilt, h = t[1], t[2], t[3]
			local cf = at(x, 1.4, 0.15) * CFrame.Angles(0, 0, tilt) * at(0, h / 2, 0)
			block(Vector3.new(0.85, h, 0.32), cf, STONE)
			cyl(0.32, 0.85, cf * at(0, h / 2, 0) * U.AxisZ, STONE)
			if i == 2 then
				block(Vector3.new(0.1, 0.55, 0.06), cf * at(0, h / 2 - 0.05, -0.17), U.Shade(glow, 0.7))
				block(Vector3.new(0.36, 0.1, 0.06), cf * at(0, h / 2 + 0.05, -0.17), U.Shade(glow, 0.7))
			end
		end
		ball(0.6, at(-0.95, 1.45, -0.3), moss)
		ball(0.5, at(0.55, 1.6, 0.6), moss)
		for _, s in { -1, 1 } do
			local pc = Vector3.new(1.95 * s, -0.1, 0)
			ball(1.65, CFrame.new(pc), ROCK)
			local sc = CFrame.new(pc + Vector3.new(0.15 * s, 0.85, 0.15)) * CFrame.Angles(0, 0.35 * s, -0.28 * s)
			block(Vector3.new(0.9, 1.1, 0.3), sc, STONE)
			cyl(0.3, 0.9, sc * at(0, 0.55, 0) * U.AxisZ, STONE)
			brow(s, 1.0, true, DARK, 0.8)
		end
		-- iron fence rising behind the shoulders
		ring(-0.75, 0.24, iron, METAL_MAT)
		for i = -2, 2 do
			local a = math.pi + i * 0.42
			local p = Vector3.new(math.sin(a) * 1.85, 0.0, -math.cos(a) * 1.85)
			block(Vector3.new(0.14, 1.9, 0.14), CFrame.new(p), iron, METAL_MAT)
			block(Vector3.new(0.26, 0.26, 0.26), CFrame.new(p + Vector3.new(0, 1.05, 0)) * U.VertexUp, iron, METAL_MAT)
		end
		rockPlates(
			{ Vector3.new(-1, -0.25, -0.55), Vector3.new(0.9, -0.8, -0.6), Vector3.new(-0.3, -1, -0.5) },
			{ Vector3.new(0.55, -0.35, -1), Vector3.new(-0.95, 0.15, -0.55) },
			ROCK
		)
		fangs(WHITE)
		-- tombstone hammer in the right nub
		local hand = Vector3.new(2.0, -0.45, -0.3)
		local dir = Vector3.new(0.55, 1, 0.1).Unit
		rod(hand - dir * 0.9, hand + dir * 2.1, 0.24, WOOD)
		local hh = along(hand + dir * 2.35, dir)
		block(Vector3.new(1.35, 0.8, 0.8), hh, STONE)
		for _, s in { -1, 1 } do
			cyl(0.16, 0.92, hh * at(0.48 * s, 0, 0), iron, METAL_MAT)
		end
		block(Vector3.new(0.4, 0.1, 0.06), hh * at(0, 0, -0.42), U.Shade(glow, 0.7))
		-- grave lantern on the left nub
		cyl(0.6, 0.12, at(-2.1, -0.85, -0.35) * U.AxisY, iron, METAL_MAT)
		block(Vector3.new(0.75, 0.85, 0.75), at(-2.1, -1.55, -0.35), iron, METAL_MAT)
		ball(0.45, at(-2.1, -1.55, -0.35), glow, NEON)
		-- floating skull
		local sk = Vector3.new(-1.3, 2.3, -1.4)
		ball(0.85, CFrame.new(sk), BEARD)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.18, 0.2, 0.1), CFrame.new(sk + Vector3.new(0.16 * s, 0.03, -0.37)), DARK)
		end
	elseif style == "VoidLeviathan" then
		-- serpent: long curling tail with flukes, dorsal + ear fins, horns, tentacles,
		-- glowing spots and orbiting void shards
		local finC = accent
		local horn = Color3.fromRGB(35, 35, 80)
		local tail = {
			{ p = Vector3.new(0.55, -3.05, 2.4), d = 0.72 },
			{ p = Vector3.new(1.0, -3.28, 2.85), d = 0.64 },
			{ p = Vector3.new(1.6, -3.32, 3.1), d = 0.56 },
			{ p = Vector3.new(2.2, -3.12, 3.15), d = 0.48 },
			{ p = Vector3.new(2.7, -2.75, 2.95), d = 0.4 },
		}
		for _, t in tail do
			ball(t.d, CFrame.new(t.p), color, bodyOpts)
		end
		local tip = Vector3.new(2.95, -2.5, 2.8)
		for _, s in { -1, 1 } do
			block(Vector3.new(0.75, 0.1, 0.4), CFrame.lookAt(tip, tip + Vector3.new(0.6, 0.5, -0.3)) * CFrame.Angles(0, 0, 0.6 * s) * at(0.38 * s, 0, -0.1), finC)
		end
		fin(Vector3.new(0, 1.45, 0.9), Vector3.new(0, 0.85, 0.5), 0.9, 1.1, finC)
		fin(Vector3.new(0, 0.75, 1.55), Vector3.new(0, 0.45, 0.9), 0.85, 1.0, finC)
		fin(Vector3.new(0, -0.15, 1.75), Vector3.new(0, 0.1, 1), 0.75, 0.9, finC)
		fin(Vector3.new(0, -1.3, 1.95), Vector3.new(0, -0.2, 1), 0.6, 0.8, finC)
		for _, s in { -1, 1 } do
			-- swept-back horns
			rod(Vector3.new(0.6 * s, 1.45, 0.1), Vector3.new(0.95 * s, 2.1, 0.75), 0.42, horn)
			rod(Vector3.new(0.95 * s, 2.1, 0.75), Vector3.new(1.0 * s, 2.35, 1.6), 0.3, horn)
			block(Vector3.new(0.26, 0.26, 0.26), CFrame.new(Vector3.new(1.0 * s, 2.4, 1.78)) * U.VertexUp, finC)
			-- three gill-fins fanning out of each side of the head
			for k, f in { 0.65, 0.05, -0.55 } do
				local u = Vector3.new(s * math.cos(f), math.sin(f), 0)
				local len = 1.7 - k * 0.2
				local up = Vector3.new(-u.Y * s, u.X * s, 0)
				local base = Vector3.new(1.4 * s, 0.75 - k * 0.12, 0.25)
				wedge(Vector3.new(0.12, 0.8, len), CFrame.fromMatrix(base + u * (len / 2), up:Cross(-u), up), finC)
			end
			-- dragon whiskers from the cheeks
			local w0 = Vector3.new(1.05 * s, -0.45, -1.4)
			local w1 = Vector3.new(1.55 * s, -0.8, -1.65)
			local w2 = Vector3.new(1.85 * s, -1.35, -1.6)
			rod(w0, w1, 0.18, finC)
			rod(w1, w2, 0.13, finC)
			ball(0.24, CFrame.new(w2), glow, NEON)
			brow(s, 1.0, true, DARK, 0.7)
		end
		for _, d in { Vector3.new(1, 0.1, -0.35), Vector3.new(-1, 0.1, -0.35), Vector3.new(0.85, -0.6, 0.4), Vector3.new(-0.85, -0.6, 0.4) } do
			ball(0.24, CFrame.new(surf(d, -0.04)), U.Shade(glow, 0.8))
		end
		fangs(WHITE)
		for i = 0, 2 do
			local a = i * 2 * math.pi / 3 + 0.6
			crystal(CFrame.Angles(0, a, 0) * at(0, 0.6 + 0.5 * math.sin(i * 2.1), -3.3) * CFrame.Angles(0.35, 0, 0.5), 0.34, 0.8, U.Shade(color, 0.55), nil, U.Shade(glow, 0.75), { Reflectance = 0.25 }, true)
		end
	elseif style == "PhantomEmperor" then
		-- floats in front of its phantom throne; three-tier pagoda crown, gold pauldrons and
		-- breastplate, ecto-flame scepter, imperial orb and two tiny ghost attendants
		local throne = Color3.fromRGB(95, 45, 155)
		local velvet = Color3.fromRGB(150, 75, 205)
		local glass = { Reflectance = 0.25 }
		block(Vector3.new(4.3, 4.6, 0.45), at(0, 0.1, 2.65), throne)
		block(Vector3.new(3.3, 3.8, 0.2), at(0, 0.2, 2.35), velvet)
		for _, s in { -1, 1 } do
			cyl(4.8, 0.48, at(2.2 * s, 0.1, 2.55) * U.AxisY, GOLD, METAL_MAT)
			ball(0.65, at(2.2 * s, 2.6, 2.55), GOLD, METAL_MAT)
			block(Vector3.new(0.36, 0.36, 0.36), at(2.2 * s, 3.05, 2.55) * U.VertexUp, U.Shade(glow, 0.75), glass)
		end
		cyl(4.4, 0.4, at(0, 2.45, 2.55), GOLD, METAL_MAT)
		cyl(0.2, 1.4, at(0, 2.95, 2.45) * U.AxisZ, GOLD, METAL_MAT)
		block(Vector3.new(0.5, 0.5, 0.5), at(0, 2.95, 2.3) * U.VertexUp, glow, NEON)
		-- three-tier crown
		local ccf = at(0, 1.4, 0.05)
		cyl(0.75, 2.65, ccf * U.AxisY, GOLD, METAL_MAT)
		cyl(0.6, 2.0, ccf * at(0, 0.65, 0) * U.AxisY, velvet)
		cyl(0.5, 1.35, ccf * at(0, 1.15, 0) * U.AxisY, GOLD, METAL_MAT)
		for i = 0, 5 do
			local rot = ccf * CFrame.Angles(0, i * math.pi / 3, 0)
			wedge(Vector3.new(0.42, 0.65, 0.36), rot * at(0, 0.62, -1.1), GOLD, METAL_MAT)
		end
		local gems = { RED, Color3.fromRGB(60, 120, 255), Color3.fromRGB(60, 200, 110) }
		for i, a in { -0.7, 0, 0.7 } do
			ball(0.34, ccf * CFrame.Angles(0, a, 0) * at(0, 0, -1.33), gems[i], glass)
		end
		for i = 0, 3 do
			wedge(Vector3.new(0.32, 0.5, 0.28), ccf * CFrame.Angles(0, i * math.pi / 2 + math.pi / 4, 0) * at(0, 1.18, -0.82), GOLD, METAL_MAT)
		end
		ball(0.55, ccf * at(0, 1.6, 0), GOLD, METAL_MAT)
		block(Vector3.new(0.16, 0.6, 0.16), ccf * at(0, 2.05, 0), GOLD, METAL_MAT)
		block(Vector3.new(0.42, 0.16, 0.16), ccf * at(0, 2.1, 0), GOLD, METAL_MAT)
		-- pauldrons, breastplate, moustache
		for _, s in { -1, 1 } do
			ball(1.4, at(1.85 * s, 0.0, -0.05), GOLD, METAL_MAT)
			point(Vector3.new(2.1 * s, 0.5, -0.05), Vector3.new(0.5 * s, 1, 0), 0.32, 0.55, 0.32, GOLD, METAL_MAT)
			local pos = surf(Vector3.new(0.36 * s, -0.2, -1.65), 0.05)
			wedge(Vector3.new(0.18, 0.32, 0.65), U.Facing(pos, pos) * CFrame.Angles(0, 0, 0.15 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), BEARD)
		end
		ring(-0.9, 0.38, GOLD, METAL_MAT)
		block(Vector3.new(0.4, 0.4, 0.4), CFrame.new(surf(Vector3.new(0, -0.95, -1.45), 0.08)) * U.VertexUp, glow, NEON)
		-- ecto-flame scepter in the right nub
		local hand = Vector3.new(1.85, -0.35, -0.25)
		local dir = Vector3.new(0.3, 1, -0.05).Unit
		rod(hand - dir * 0.8, hand + dir * 2.2, 0.2, GOLD, METAL_MAT)
		cyl(0.4, 0.6, U.Between(hand + dir * 2.2, hand + dir * 2.6), GOLD, METAL_MAT)
		wedge(Vector3.new(0.35, 0.8, 0.5), along(hand + dir * 3.0, dir), glow, NEON)
		wedge(Vector3.new(0.3, 0.55, 0.4), along(hand + dir * 2.9, dir) * CFrame.Angles(0, math.pi, 0) * at(0, 0, 0.15), U.Shade(glow, 0.75))
		-- imperial orb on the left nub
		local orb = Vector3.new(-2.3, -0.3, -0.6)
		ball(0.95, CFrame.new(orb), GOLD, METAL_MAT)
		cyl(0.18, 1.0, CFrame.new(orb) * U.AxisY, velvet)
		block(Vector3.new(0.14, 0.5, 0.14), CFrame.new(orb + Vector3.new(0, 0.65, 0)), GOLD, METAL_MAT)
		block(Vector3.new(0.36, 0.14, 0.14), CFrame.new(orb + Vector3.new(0, 0.7, 0)), GOLD, METAL_MAT)
		-- two tiny ghost attendants
		for _, s in { -1, 1 } do
			local gp = Vector3.new(2.9 * s, 1.6, -0.9)
			ball(0.8, CFrame.new(gp), WHITE)
			for _, e in { -1, 1 } do
				ball(0.16, CFrame.new(gp + Vector3.new(0.15 * e, 0.07, -0.35)), EYE)
			end
		end
	elseif style == "EclipseOverlord" then
		-- black sun with a glowing corona and gold sawtooth rays behind, crescent-moon crown,
		-- crescent-bladed pauldrons, sun emblem, ecto cracks, orbiting moons and an eclipse staff
		local ecto = Color3.fromRGB(95, 200, 140)
		local moonC = Color3.fromRGB(235, 235, 255)
		local voidC = Color3.fromRGB(30, 20, 55)
		local glass = { Reflectance = 0.25 }
		local sun = Vector3.new(0, 0.4, 2.25)
		cyl(0.1, 4.8, CFrame.new(sun) * U.AxisZ, U.Shade(glow, 0.8), METAL_MAT)
		cyl(0.14, 4.6, CFrame.new(sun - Vector3.new(0, 0, 0.07)) * U.AxisZ, voidC)
		for i = 0, 11 do
			local a = i * math.pi / 6
			local d = Vector3.new(math.sin(a), math.cos(a), 0)
			local len = if i % 2 == 0 then 1.05 else 0.7
			local pos = sun + d * (2.35 + len / 2) + Vector3.new(0, 0, 0.02)
			wedge(Vector3.new(0.14, len, 0.55), CFrame.fromMatrix(pos, Vector3.zAxis, d), GOLD, METAL_MAT)
		end
		-- crescent-moon crown
		ring(1.25, 0.35, GOLD, METAL_MAT)
		local mc = Vector3.new(0, 2.65, 0.15)
		for _, t in { -1.5, -0.75, 0, 0.75, 1.5 } do
			local p = mc + Vector3.new(math.sin(t), -math.cos(t), 0) * 0.78
			local th = 0.46 - math.abs(t) * 0.17
			block(Vector3.new(0.62, th, 0.3), CFrame.fromMatrix(p, Vector3.new(math.cos(t), math.sin(t), 0), Vector3.new(-math.sin(t), math.cos(t), 0)), moonC, glass)
		end
		block(Vector3.new(0.38, 0.38, 0.38), CFrame.new(surf(Vector3.new(0, 1.25, -1.17), 0.14)) * U.VertexUp, glow, NEON)
		for _, s in { -1, 1 } do
			local pc = Vector3.new(1.85 * s, -0.05, -0.05)
			ball(1.35, CFrame.new(pc), GOLD, METAL_MAT)
			point(pc + Vector3.new(0.35 * s, 0.4, 0), Vector3.new(0.6 * s, 1, 0.1), 0.42, 0.85, 0.12, moonC, glass)
			point(pc + Vector3.new(0.5 * s, 0.05, 0), Vector3.new(1, 0.15, 0.1) * s, 0.36, 0.6, 0.12, moonC, glass)
			brow(s, 0.98, true, voidC, 0.7)
		end
		-- sun emblem, ecto cracks
		ring(-0.95, 0.3, GOLD, METAL_MAT)
		local ep = surf(Vector3.new(0, -1.2, -1.2), 0.05)
		cyl(0.12, 0.7, U.DiscFacing(ep, ep), GOLD, METAL_MAT)
		ball(0.36, CFrame.new(ep + ep.Unit * 0.05), voidC)
		for _, c in { { d = Vector3.new(1.0, 0.55, -0.55), t = 0.4 }, { d = Vector3.new(-0.9, -0.4, -0.75), t = -0.5 } } do
			block(Vector3.new(0.11, 0.7, 0.1), onSurf(c.d, -0.02) * CFrame.Angles(0, 0, c.t), ecto, NEON)
		end
		-- orbiting moons: full, eclipsed (dark ball on a glowing ring), small
		ball(0.9, at(-2.9, 1.5, -0.7), moonC, glass)
		ball(0.8, at(2.9, 1.9, -0.5), voidC)
		cyl(0.06, 0.95, at(2.9, 1.9, -0.42) * U.AxisZ, U.Shade(glow, 0.8), METAL_MAT)
		ball(0.5, at(-2.4, -1.7, -1.0), moonC, glass)
		-- eclipse staff in the right nub
		local hand = Vector3.new(1.85, -0.4, -0.3)
		local dir = Vector3.new(0.4, 1, 0.12).Unit
		rod(hand - dir * 1.3, hand + dir * 2.4, 0.18, DARK)
		local top = hand + dir * 2.85
		cyl(0.08, 0.95, CFrame.new(top + Vector3.new(0, 0, 0.06)) * U.AxisZ, U.Shade(glow, 0.8), METAL_MAT)
		cyl(0.14, 0.82, CFrame.new(top) * U.AxisZ, voidC)
		for _, s in { -1, 1 } do
			wedge(Vector3.new(0.1, 0.55, 0.3), CFrame.new(top + Vector3.new(0.48 * s, 0.1, 0)) * CFrame.Angles(0, -math.pi / 2 * s, 0), GOLD, METAL_MAT)
		end
	else -- Plain: a little wisp curl on top
		-- every other style must be handled above: worldsim (tools/check.sh) builds every Config
		-- ghost, so a misspelt or unbuilt style fails the checks instead of silently going Plain
		assert(style == "Plain", "GhostRig: no look for ghost style " .. style .. " (" .. ghostId .. ")")
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
	local isBoss = def.Kind == "Boss" or def.Kind == "Event" or def.Kind == "WorldBoss"
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
