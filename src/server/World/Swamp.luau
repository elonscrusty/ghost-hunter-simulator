--!strict
-- ZONE 9: Phantom Swamp (Z 2680..3040). A misty, moss-green bayou: cute-spooky, not dark.
--   Ground: grass slab (top Y = 0) with flat mud patches and shallow water: translucent teal
--   sheets lying on the solid ground (no pits anywhere).
--   Main path: a plank boardwalk along X = 0 (X -8..8, top 0.05) from gate to gate.
--   Ghost areas hold flat paint only: lily-pad ponds either side of the boardwalk, moss clearings,
--   a wide lily pond and the boss bog ring around (0, 2985) with lime ectoplasm runes.
--   Landmark: the SWAMP KING, a giant gnarled cypress wearing a golden crown at (100, 2970),
--   ~90 tall, seen through the Spirit Realm portal arch.
--   Also: an old stranded paddle boat "Swamp Queen" (100, 2775), three crooked stilt shacks
--   (two with raised side boardwalks), cypress trees with hanging moss, reeds, glowing
--   mushrooms, fireflies, frogs and lanterns. Side walls: mossy plank palisade at X +-140..146.
--   Outside: open bayou water with cypress silhouettes and low fog banks.
-- Glow is limited to fireflies, a few mushroom caps, shack windows, lanterns, the boss runes,
-- the paddle boat's bow lamp and the Swamp King's eyes.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Swamp = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local GRASS = Enum.Material.Grass
local MUD = Enum.Material.Mud
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local Z0, Z1 = 2680, 3040

local GROUND = C(88, 128, 66)
local MUDC = C(104, 84, 58)
local WATER = C(64, 140, 120)
local WATER_DEEP = C(48, 112, 104)
local BARK = C(92, 70, 52)
local BARK_DARK = C(70, 54, 42)
local PLANK = C(150, 112, 74)
local PLANK_DARK = C(104, 76, 52)
local MOSS = C(96, 150, 70)
local MOSS_LIGHT = C(140, 180, 96)
local HANGMOSS = C(160, 182, 132)
local LIME = C(170, 255, 110)
local WARM = C(255, 220, 130)
local LILY = C(90, 170, 80)
local GOLD = C(255, 200, 60)
local CANOPY = { C(70, 125, 62), C(86, 140, 70), C(62, 112, 70), C(98, 150, 78) }
local SHACKS = { C(110, 150, 140), C(150, 120, 160), C(160, 130, 90) }

local function rz(n: number): number
	return Z0 + n
end

-- Plan-view triangle (local Y y0..y1): right angle at (xEdge, zBase), point at (xEdge, zTip > zBase).
local function bowHalf(parent: Instance, base: CFrame, xEdge: number, xOuter: number, zBase: number, zTip: number, y0: number, y1: number, color: Color3, opts: Kit.Opts)
	local s = if xOuter > xEdge then 1 else -1
	local center = V((xEdge + xOuter) / 2, (y0 + y1) / 2, (zBase + zTip) / 2)
	local cf = base * CFrame.fromMatrix(center, V(0, s, 0), V(s, 0, 0))
	Kit.Wedge(parent, V(y1 - y0, math.abs(xOuter - xEdge), zTip - zBase), cf, color, opts)
end

-- Gable roof, ridge along local X, bottom at local y = 0.
local function gable(parent: Instance, base: CFrame, length: number, depth: number, height: number, color: Color3, mat: Enum.Material)
	local half = depth / 2
	local o: Kit.Opts = { Mat = mat, Solid = true, Shadow = true }
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, -half / 2), color, o)
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), color, o)
end

-- Shallow water sheet (non-solid) with a mud rim, lying on the solid ground; top at Y 0.1.
local function pond(parent: Instance, x: number, z: number, d: number)
	Kit.Disc(parent, x, z, 0.04, d + 4, 0.03, MUDC, { Mat = MUD })
	Kit.Disc(parent, x, z, 0.1, d, 0.06, WATER, { Transp = 0.2, Refl = 0.15, Name = "Water" })
end

local function lilyPad(parent: Instance, x: number, z: number, d: number, flower: boolean)
	Kit.Disc(parent, x, z, 0.14, d, 0.03, Kit.Vivid(LILY))
	if flower then
		Kit.Disc(parent, x + d * 0.15, z, 0.2, d * 0.35, 0.06, Kit.Vivid(C(255, 150, 200)))
	end
end

--==================================================================
-- PROPS
--==================================================================
local function cypress(parent: Instance, pos: Vector3, h: number)
	local rng = Kit.Rng
	local wood: Kit.Opts = { Mat = WOOD, Solid = true, Shadow = true }
	Kit.Cyl(parent, 3, 5.5, CFrame.new(pos + V(0, 1.5, 0)), BARK_DARK, wood)
	local trunkCf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	Kit.Cyl(parent, h, 2.4, trunkCf * CFrame.new(0, h / 2, 0), BARK, wood)
	-- cypress knees poking out of the mud
	for k = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		local kh = rng:NextNumber(1.2, 2.4)
		Kit.Cyl(parent, kh, 0.9, CFrame.new(pos + V(math.cos(a) * (3.5 + k), kh / 2, math.sin(a) * (3.5 + k))), BARK)
	end
	-- flat-topped canopy layers
	local top = (trunkCf * CFrame.new(0, h, 0)).Position
	local col = Kit.Pick(CANOPY)
	local d = h * 0.75
	Kit.Cyl(parent, 2.6, d, CFrame.new(top + V(0, -1, 0)), col, { Mat = GRASS, Shadow = true })
	Kit.Cyl(parent, 2.4, d * 0.65, CFrame.new(top + V(rng:NextNumber(-1.5, 1.5), 1.2, rng:NextNumber(-1.5, 1.5))), col:Lerp(Color3.new(1, 1, 1), 0.12), { Mat = GRASS })
	Kit.Ball(parent, d * 0.4, top + V(rng:NextNumber(-2, 2), -2.2, rng:NextNumber(-2, 2)), col:Lerp(Color3.new(0, 0, 0), 0.1), { Mat = GRASS })
	-- hanging moss strands under the canopy edge
	for k = 0, 2 do
		local a = k * 2.1 + rng:NextNumber(-0.4, 0.4)
		local len = rng:NextNumber(4, 7)
		local p = top + V(math.cos(a) * d * 0.38, -2.3 - len / 2, math.sin(a) * d * 0.38)
		Kit.Part(parent, V(0.6, len, 1.6), CFrame.new(p) * CFrame.Angles(0, a, 0), HANGMOSS, { Mat = FABRIC, Transp = 0.1 })
	end
	Kit.AddCircle(pos.X, pos.Z, d / 2)
end

local function reeds(parent: Instance, x: number, z: number)
	local rng = Kit.Rng
	for k = 0, 2 do
		local h = rng:NextNumber(4, 6.5)
		local p = V(x + rng:NextNumber(-1.2, 1.2), 0, z + rng:NextNumber(-1.2, 1.2))
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		Kit.Cyl(parent, h, 0.3, cf * CFrame.new(0, h / 2, 0), C(110, 160, 80))
		if k < 2 then
			Kit.Cyl(parent, 1.6, 0.75, cf * CFrame.new(0, h - 1.2, 0), C(120, 80, 50), { Mat = FABRIC })
		end
	end
	Kit.AddCircle(x, z, 2)
end

local function mushrooms(parent: Instance, x: number, z: number, glow: boolean)
	local rng = Kit.Rng
	local caps = { C(170, 255, 110), C(110, 240, 210), C(200, 150, 255) }
	for _ = 1, 3 do
		local p = V(x + rng:NextNumber(-1.8, 1.8), 0, z + rng:NextNumber(-1.8, 1.8))
		local h = rng:NextNumber(1, 2.6)
		Kit.Cyl(parent, h, 0.6, CFrame.new(p + V(0, h / 2, 0)), C(240, 236, 220))
		local cap = Kit.Pick(caps)
		Kit.Cyl(parent, 0.8, rng:NextNumber(1.8, 2.8), CFrame.new(p + V(0, h + 0.3, 0)), if glow then cap else Kit.Vivid(cap), if glow then { Mat = NEON } else {})
	end
	Kit.AddCircle(x, z, 2.5)
end

local function frog(parent: Instance, x: number, z: number, fx: number, fz: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Disc(parent, x, z, 0.14, 4.4, 0.03, Kit.Vivid(LILY))
	Kit.Part(parent, V(2.4, 1.4, 2.2), base * CFrame.new(0, 0.9, 0), Kit.Vivid(C(110, 200, 90)))
	for _, s in { -1, 1 } do
		Kit.Ball(parent, 0.9, (base * CFrame.new(s * 0.65, 1.75, -0.5)).Position, C(250, 250, 240))
		Kit.Ball(parent, 0.45, (base * CFrame.new(s * 0.65, 1.8, -0.88)).Position, C(30, 30, 40))
	end
	Kit.Part(parent, V(1.4, 0.15, 0.2), base * CFrame.new(0, 0.85, -1.12), Kit.Vivid(C(255, 120, 150)))
	Kit.AddCircle(x, z, 3)
end

local function fallenLog(parent: Instance, x: number, z: number, yaw: number, len: number)
	local cf = CFrame.new(x, 1.1, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(parent, V(len, 2.2, 2.2), cf, BARK, { Mat = WOOD, Shape = Enum.PartType.Cylinder, Solid = true })
	Kit.Part(parent, V(len * 0.5, 0.4, 1.6), cf * CFrame.new(len * 0.1, 1.05, 0), MOSS, { Mat = GRASS })
	Kit.AddCircle(x, z, len / 2)
end

-- Crooked stilt shack whose front (door, ramp) faces (fx, 0); a little pond under it.
local function shack(parent: Instance, x: number, z: number, fx: number, col: Color3, lit: boolean, flicker: boolean)
	local m = Kit.Model(parent, "StiltShack")
	pond(m, x, z, 20)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, 0), 0)
	local tilt = base * CFrame.Angles(0, 0, 0.04)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.Cyl(m, 5.2, 1.1, base * CFrame.new(sx * 6, 2.6, sz * 5), BARK_DARK, { Mat = WOOD, Solid = true })
		end
	end
	Kit.Part(m, V(14, 1, 12), base * CFrame.new(0, 4.6, 0), PLANK, { Mat = PLANKS, Solid = true, Shadow = true })
	Kit.Part(m, V(10, 8, 8), tilt * CFrame.new(0, 9.1, 1), col, { Mat = PLANKS, Solid = true, Shadow = true })
	gable(m, tilt * CFrame.new(0, 13.1, 1), 12, 10.5, 4.5, C(150, 96, 70), Enum.Material.CorrodedMetal)
	-- door + window on the front (local -Z)
	Kit.Part(m, V(2.6, 5, 0.3), tilt * CFrame.new(-2, 7.6, -3.1), PLANK_DARK, { Mat = WOOD })
	local win = Kit.Part(m, V(2.6, 2.2, 0.3), tilt * CFrame.new(2.4, 9.4, -3.1), WARM, if lit then { Mat = NEON } else {})
	Kit.Part(m, V(3.2, 0.4, 0.4), tilt * CFrame.new(2.4, 8.2, -3.2), PLANK_DARK)
	if lit then
		Kit.Light(win, WARM, 20, 1.3, flicker)
	end
	-- crooked stovepipe, porch rail and a ramp down to the mud
	Kit.Cyl(m, 5, 1, tilt * CFrame.new(3.5, 15, 3) * CFrame.Angles(0, 0, 0.15), C(70, 70, 80), { Mat = METAL })
	Kit.Part(m, V(14, 0.3, 0.3), base * CFrame.new(0, 7, -5.8), PLANK_DARK, { Mat = WOOD })
	Kit.Wedge(m, V(3.4, 4.6, 7), base * CFrame.new(-2, 2.3, -9.5), PLANK, { Mat = PLANKS, Solid = true })
	Kit.AddCircle(x, z, 12)
end

-- Raised boardwalk (top 0.6, a walkable step) along X at z.
local function sideWalk(parent: Instance, x1: number, x2: number, z: number)
	local lo, hi = math.min(x1, x2), math.max(x1, x2)
	Kit.Box(parent, V(lo, 0, z - 2.2), V(hi, 0.6, z + 2.2), PLANK, { Mat = PLANKS, Solid = true, Name = "SideBoardwalk" })
	local x = lo + 4
	while x < hi - 2 do
		for _, s in { -1, 1 } do
			Kit.Cyl(parent, 2.4, 0.7, CFrame.new(x, 1.2, z + s * 2.3), PLANK_DARK, { Mat = WOOD })
		end
		x += 16
	end
	Kit.AddRect(lo, z - 3, hi, z + 3)
end

--==================================================================
-- GROUND, PATH, WALLS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), GROUND, { Mat = GRASS, Solid = true, Name = "Ground_Swamp" })
	-- boardwalk along X = 0 with dark edge boards and cross seams
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), PLANK, { Mat = PLANKS, Solid = true, Name = "Boardwalk" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8 - 0.5, 0.05, Z0), V(s * 8 + 0.5, 0.11, Z1), PLANK_DARK, { Mat = WOOD })
	end
	for z = Z0 + 10, Z1 - 10, 22 do
		Kit.Box(f, V(-7.5, 0.05, z), V(7.5, 0.08, z + 0.6), PLANK_DARK, { Mat = WOOD })
	end
	-- flat mud patches
	local rng = Kit.Rng
	for _ = 1, 9 do
		local x = rng:NextNumber(-125, 125)
		local z = rng:NextNumber(Z0 + 30, Z1 - 30)
		if math.abs(x) > 22 then
			Kit.Part(f, V(rng:NextNumber(14, 26), 0.03, rng:NextNumber(10, 22)), CFrame.new(x, 0.015, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), MUDC, { Mat = MUD })
		end
	end
	-- winding water channels along both sides (flat sheets on solid ground)
	local channels = {
		{ V(-122, 0, rz(70)), V(-128, 0, rz(130)), V(-116, 0, rz(190)), V(-124, 0, rz(250)), V(-112, 0, rz(320)) },
		{ V(124, 0, rz(150)), V(116, 0, rz(210)), V(124, 0, rz(250)) },
	}
	for _, ch in channels do
		for i = 1, #ch - 1 do
			local a, b = ch[i], ch[i + 1]
			local d = b - a
			local mid = (a + b) / 2
			local rot = CFrame.Angles(0, math.atan2(-d.X, -d.Z), 0)
			Kit.Part(f, V(13, 0.03, d.Magnitude + 8), CFrame.new(mid.X, 0.025, mid.Z) * rot, MUDC, { Mat = MUD })
			Kit.Part(f, V(9, 0.06, d.Magnitude + 6), CFrame.new(mid.X, 0.07, mid.Z) * rot, WATER_DEEP, { Transp = 0.2, Refl = 0.15, Name = "Water" })
		end
	end
end

local function sideWalls(f: Instance)
	local zA, zB = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, 0, zA), V(s * 146, 11, zB), PLANK_DARK, { Mat = PLANKS, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.6, 11, zA), V(s * 146.4, 12.2, zB), MOSS, { Mat = GRASS })
		Kit.Box(f, V(s * 139.85, 2.5, zA), V(s * 139.65, 3.1, zB), Kit.Vivid(C(150, 230, 90)))
		for z = zA + 12, zB - 6, 36 do
			Kit.Cyl(f, 15, 3.2, CFrame.new(s * 143, 7.5, z), BARK, { Mat = WOOD, Solid = true })
			Kit.Ball(f, 4, V(s * 143, 15.4, z), Kit.Pick(CANOPY), { Mat = GRASS })
		end
	end
end

--==================================================================
-- GHOST AREA PAINT (flat only)
--==================================================================
local function ghostPaint(f: Instance)
	-- bog wisps: lily ponds either side of the boardwalk on a moss clearing
	local cz = rz(85)
	Kit.Disc(f, 0, cz, 0.03, 64, 0.02, MOSS_LIGHT, { Mat = GRASS })
	for _, s in { -1, 1 } do
		pond(f, s * 19.5, cz, 18)
		pond(f, s * 21, cz - 18, 9)
		pond(f, s * 20, cz + 18, 10)
		lilyPad(f, s * 16, cz - 3, 4, s > 0)
		lilyPad(f, s * 23, cz + 4, 3.2, s < 0)
		lilyPad(f, s * 20, cz + 18, 3, false)
	end
	-- moss clearings with mud rims
	for _, a in { { -82, rz(120), 24 }, { -62, rz(240), 24 } } do
		Kit.Disc(f, a[1], a[2], 0.04, a[3] * 2 + 4, 0.03, MUDC, { Mat = MUD })
		Kit.Disc(f, a[1], a[2], 0.07, a[3] * 2, 0.03, MOSS_LIGHT, { Mat = GRASS })
		pond(f, a[1] + 6, a[2] - 4, 12)
		lilyPad(f, a[1] + 8, a[2] - 3, 3.4, true)
	end
	-- marsh phantoms: a wide lily pond
	pond(f, 75, rz(180), 44)
	for _, l in { { 66, rz(172), 4.5 }, { 84, rz(186), 3.6 }, { 72, rz(194), 3 }, { 88, rz(170), 4.2 } } do
		lilyPad(f, l[1], l[2], l[3], l[3] > 4)
	end
	-- boss bog: mud ring, two murky pools and lime ectoplasm runes
	local bz = rz(305)
	Kit.Disc(f, 0, bz, 0.04, 58, 0.03, MUDC, { Mat = MUD })
	for _, s in { -1, 1 } do
		pond(f, s * 17, bz, 15)
		lilyPad(f, s * 16, bz + 3, 3.6, s > 0)
	end
	for i = 0, 7 do
		local a1 = i * math.pi / 4 + 0.14
		local a2 = a1 + math.pi / 4 - 0.28
		Props.Beam(f, V(math.cos(a1) * 25, 0.13, bz + math.sin(a1) * 25), V(math.cos(a2) * 25, 0.13, bz + math.sin(a2) * 25), 0.5, 0.06, LIME, { Mat = NEON })
	end
	local core = Kit.Disc(f, 0, bz, 0.12, 6, 0.05, Kit.Vivid(LIME), { Transp = 0.3 })
	Kit.Light(core, LIME, 30, 1.2)
	local fog = Kit.Part(f, V(40, 0.2, 40), CFrame.new(0, 1, bz), C(200, 240, 200), { Transp = 1, Name = "FogSource" })
	Kit.Emitter(fog, C(200, 240, 200), 1.6, 9, 0.3)
end

--==================================================================
-- LANDMARKS
--==================================================================
local function swampKing(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "SwampKing")
	local wood: Kit.Opts = { Mat = WOOD, Solid = true, Shadow = true }
	pond(m, x, z, 34)
	-- roots
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		Props.Beam(m, V(x + math.cos(a) * 17, 0.3, z + math.sin(a) * 17), V(x + math.cos(a) * 6, 9, z + math.sin(a) * 6), 3.2, 3.2, BARK_DARK, { Mat = WOOD })
	end
	Kit.Cyl(m, 14, 18, CFrame.new(x, 7, z), BARK, wood)
	-- gnarled trunk
	local pts = { V(x, 12, z), V(x + 3, 26, z - 2), V(x - 2, 40, z + 2), V(x + 1, 54, z) }
	for i = 1, #pts - 1 do
		local w = 14 - i * 2.5
		Props.Beam(m, pts[i], pts[i + 1], w, w, if i % 2 == 0 then BARK_DARK else BARK, wood)
	end
	-- sleepy face on the side looking at the boardwalk (-X)
	Kit.Box(m, V(x - 9.4, 3.5, z - 3.5), V(x - 8.4, 6.5, z + 3.5), C(40, 30, 28))
	local eye: Part? = nil
	for _, s in { -1, 1 } do
		Kit.Ball(m, 4.2, V(x - 8.4, 10.5, z + s * 3.6), C(40, 30, 28))
		local e = Kit.Ball(m, 2.6, V(x - 9.6, 10.5, z + s * 3.6), LIME, { Mat = NEON })
		eye = eye or e
	end
	if eye then
		Kit.Light(eye, LIME, 26, 1.4)
	end
	-- branches
	for i = 0, 4 do
		local a = i * 1.26 + 0.5
		local from = pts[2 + (i % 3)]
		local tip = from + V(math.cos(a) * 18, 10 + i * 2, math.sin(a) * 18)
		Props.Beam(m, from, tip, 2.4, 2.4, BARK, { Mat = WOOD })
	end
	-- mossy crown
	local crown = { V(0, 62, 0), V(14, 58, 6), V(-12, 60, -8), V(6, 60, -14), V(-6, 58, 14), V(-2, 72, 2) }
	for i, c in crown do
		Kit.Ball(m, if i == 1 then 30 else 20, V(x, 0, z) + c, CANOPY[(i % #CANOPY) + 1], { Mat = GRASS, Shadow = true })
	end
	for i = 0, 5 do
		local a = i * 1.05
		local len = 10 + (i % 3) * 3
		Kit.Part(m, V(0.8, len, 2.4), CFrame.new(x + math.cos(a) * 16, 52 - len / 2, z + math.sin(a) * 16) * CFrame.Angles(0, a, 0), HANGMOSS, { Mat = FABRIC, Transp = 0.1 })
	end
	-- the golden crown
	local gold = Kit.Vivid(GOLD)
	Kit.Cyl(m, 5, 13, CFrame.new(x - 2, 85, z + 2), gold, { Mat = METAL, Refl = 0.2 })
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local p = V(x - 2 + math.cos(a) * 5.5, 88.5, z + 2 + math.sin(a) * 5.5)
		Kit.Part(m, V(2.4, 3.6, 2.4), CFrame.new(p) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.pi / 4), gold, { Mat = METAL })
		Kit.Ball(m, 1.3, p + V(0, 2.4, 0), Kit.Vivid(if i % 2 == 0 then C(230, 60, 90) else C(70, 200, 220)))
	end
	Kit.AddCircle(x, z, 22)
end

local function paddleBoat(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "PaddleBoat")
	pond(m, x, z, 56)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, 0, 0.05) -- listing a little in the mud
	local hull = C(222, 212, 182)
	local teal = Kit.Vivid(C(60, 160, 150))
	local red = Kit.Vivid(C(200, 80, 70))
	local sol: Kit.Opts = { Mat = PLANKS, Solid = true, Shadow = true }
	-- hull (along Z, stern at -Z), pointed bow
	Kit.Part(m, V(16, 6, 30), base * CFrame.new(0, 2, -4), hull, sol)
	bowHalf(m, base, 0, -8, 11, 21, -1, 5, hull, sol)
	bowHalf(m, base, 0, 8, 11, 21, -1, 5, hull, sol)
	Kit.Part(m, V(16.3, 0.8, 30.2), base * CFrame.new(0, 3.6, -4), teal, { Mat = WOOD })
	Kit.Part(m, V(15, 0.5, 29), base * CFrame.new(0, 5.25, -4), PLANK, { Mat = PLANKS })
	Kit.Part(m, V(16.4, 1.4, 8), base * CFrame.new(0, 0.4, 2), MOSS, { Mat = GRASS })
	-- cabins
	Kit.Part(m, V(11, 5.5, 20), base * CFrame.new(0, 8.25, -4), hull, sol)
	Kit.Part(m, V(11.3, 1.6, 20.3), base * CFrame.new(0, 9.4, -4), C(60, 90, 110))
	Kit.Part(m, V(14, 0.6, 24), base * CFrame.new(0, 11.3, -4), red, { Mat = WOOD })
	Kit.Part(m, V(7, 4, 7), base * CFrame.new(0, 13.6, 0), hull, { Mat = PLANKS })
	Kit.Part(m, V(7.3, 1.3, 7.3), base * CFrame.new(0, 14.2, 0), C(60, 90, 110))
	Kit.Part(m, V(8.5, 0.5, 8.5), base * CFrame.new(0, 15.85, 0), red, { Mat = WOOD })
	-- smokestacks with gold crowns
	for _, s in { -1, 1 } do
		Kit.Cyl(m, 13, 2, base * CFrame.new(s * 3.5, 17.5, 6.5), C(50, 48, 58), { Mat = METAL })
		Kit.Cyl(m, 0.8, 3, base * CFrame.new(s * 3.5, 24.2, 6.5), Kit.Vivid(GOLD), { Mat = METAL })
	end
	-- stern paddle wheel
	local hub = base * CFrame.new(0, 5, -24)
	Kit.CylFlat(m, 10, 13, hub.Position, "X", red, { Mat = WOOD })
	for i = 0, 3 do
		Kit.Part(m, V(10.6, 1, 14), hub * CFrame.Angles(i * math.pi / 4, 0, 0), PLANK_DARK, { Mat = WOOD })
	end
	Kit.CylFlat(m, 18, 1.4, hub.Position, "X", C(60, 60, 70), { Mat = METAL })
	-- name board and a bow lantern
	local board = Kit.Part(m, V(0.4, 1.8, 12), base * CFrame.new(-8.25, 2.2, -4), C(40, 60, 60))
	Kit.Sign(board, Enum.NormalId.Left, "SWAMP QUEEN", Kit.Vivid(C(255, 220, 120)), { Stroke = C(20, 40, 30) })
	Kit.Cyl(m, 4, 0.4, base * CFrame.new(0, 7.5, 16), C(50, 45, 60), { Mat = METAL })
	local lamp = Kit.Part(m, V(1.4, 1.8, 1.4), base * CFrame.new(0, 10, 16), LIME, { Mat = NEON })
	Kit.Light(lamp, LIME, 24, 1.2)
	-- mist over the stranded boat's pond
	local fog = Kit.Part(m, V(40, 0.2, 50), CFrame.new(x, 1, z), C(210, 240, 220), { Transp = 1, Name = "FogSource" })
	Kit.Emitter(fog, C(210, 240, 220), 1.5, 9, 0.3)
	Kit.AddRect(x - 14, z - 32, x + 14, z + 24)
end

--==================================================================
-- OUTSIDE THE WALLS
--==================================================================
local function outside(f: Instance)
	local rng = Kit.Rng
	local o = Kit.Folder(f, "Bayou")
	for _, s in { -1, 1 } do
		-- shallow bayou water over the outer ground, then open water beyond the slab
		Kit.Box(o, V(s * 146, 0, Z0), V(s * 190, 0.1, Z1), WATER, { Transp = 0.15, Refl = 0.15 })
		Kit.Box(o, V(s * 190, -3, Z0), V(s * 420, -0.4, Z1), WATER_DEEP, { Refl = 0.15 })
		-- cypress silhouettes standing in the water
		for i = 0, 7 do
			local x = s * rng:NextNumber(160, 330)
			local z = Z0 + 20 + i * 45 + rng:NextNumber(-10, 10)
			local h = rng:NextNumber(24, 40)
			local y0 = if math.abs(x) > 190 then -0.4 else 0
			Kit.Cyl(o, h, 2.6, CFrame.new(x, y0 + h / 2, z), BARK_DARK, { Mat = WOOD })
			local col = Kit.Pick(CANOPY)
			Kit.Cyl(o, 3, h * 0.8, CFrame.new(x, y0 + h, z), col, { Mat = GRASS })
			Kit.Ball(o, h * 0.4, V(x + 2, y0 + h + 1.5, z - 1), col:Lerp(Color3.new(1, 1, 1), 0.1), { Mat = GRASS })
			Kit.Part(o, V(0.8, 8, 2.4), CFrame.new(x + h * 0.25, y0 + h - 5, z), HANGMOSS, { Mat = FABRIC, Transp = 0.1 })
		end
		-- low fog banks
		for i = 0, 2 do
			Kit.Cyl(o, 5, rng:NextNumber(70, 110), CFrame.new(s * rng:NextNumber(225, 320), 3, Z0 + 60 + i * 120), C(215, 235, 225), { Transp = 0.7 })
		end
	end
	-- a broken jetty on the -X side
	for k = 0, 4 do
		if k ~= 2 then
			Kit.Box(o, V(-152 - k * 7, 0.2, rz(150)), V(-146 - k * 7, 0.7, rz(156)), PLANK, { Mat = PLANKS })
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function Swamp.Build(map: Instance)
	local f = Kit.Folder(map, "Swamp")
	local rng = Kit.Rng

	ground(f)
	sideWalls(f)
	ghostPaint(f)
	swampKing(f, 100, rz(290))
	paddleBoat(f, 100, rz(95))
	shack(f, 64, rz(34), -1, SHACKS[1], true, true)
	shack(f, -100, rz(50), 1, SHACKS[2], true, false)
	shack(f, -118, rz(192), 1, SHACKS[3], false, false)
	sideWalk(f, -88, -10, rz(50))
	sideWalk(f, -106, -10, rz(192))

	-- welcome sign
	do
		local x, z = -62, rz(14)
		for _, s in { -1, 1 } do
			Props.Beam(f, V(x + s * 10, 0, z), V(x + s * 10.6, 13, z + 0.3), 1.4, 1.4, BARK, { Mat = WOOD, Solid = true })
		end
		Props.SignBoard(f, V(x, 10, z), 20, 5.5, 0, -1, "🐸 PHANTOM SWAMP 🐸", C(70, 95, 60), C(220, 255, 170), C(150, 110, 70))
		Kit.AddCircle(x, z, 12)
	end
	do
		local x, z = 22, rz(150)
		if Kit.IsFree(x, z, 4) then
			Kit.Box(f, V(x - 0.3, 0, z - 0.3), V(x + 0.3, 5.5, z + 0.3), BARK, { Mat = WOOD })
			Props.SignBoard(f, V(x, 6.5, z), 11, 4.4, 0, -1, "DON'T FEED\nTHE GATORS", C(240, 230, 200), Kit.Vivid(C(60, 130, 60)), C(120, 90, 60))
			Kit.AddCircle(x, z, 6)
		end
	end

	-- lanterns along the boardwalk (one lit)
	local lit = 0
	for z = Z0 + 46, Z1 - 30, 46 do
		for _, s in { -1, 1 } do
			local zz = z + (if s > 0 then 23 else 0)
			local x = s * 12.5
			if zz < Z1 - 26 and Kit.IsFree(x, zz, 1.2, true) then
				lit += 1
				Props.Lantern(f, V(x, 0, zz), C(220, 255, 150), lit == 3, false)
				Kit.AddCircle(x, zz, 1.5)
			end
		end
	end

	-- cypress trees
	local trees = 0
	for _ = 1, 400 do
		if trees >= 17 then
			break
		end
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 30, Z1 - 30)
		local h = rng:NextNumber(18, 28)
		if Kit.IsFree(x, z, h * 0.375 + 1) then
			trees += 1
			cypress(f, V(x, 0, z), h)
		end
	end

	-- logs, reeds, mushrooms, frogs
	local logs, clumps, shrooms, frogs = 0, 0, 0, 0
	for _ = 1, 600 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(Z0 + 28, Z1 - 28)
		if logs < 5 and Kit.IsFree(x, z, 6) then
			logs += 1
			fallenLog(f, x, z, rng:NextNumber(0, math.pi), rng:NextNumber(8, 12))
		elseif clumps < 13 and Kit.IsFree(x, z, 2) then
			clumps += 1
			reeds(f, x, z)
		elseif shrooms < 6 and Kit.IsFree(x, z, 3) then
			shrooms += 1
			mushrooms(f, x, z, shrooms <= 2)
		elseif frogs < 3 and Kit.IsFree(x, z, 3) then
			frogs += 1
			frog(f, x, z, -x, 0)
		end
	end

	-- fireflies: small glowing dots, a few of them bobbing
	local flies = 0
	for _ = 1, 300 do
		if flies >= 10 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 30)
		if math.abs(x) > 12 and Kit.IsFree(x, z, 2, true) then
			flies += 1
			local p = Kit.Ball(f, 0.6, V(x, rng:NextNumber(2.5, 6), z), Kit.Pick({ LIME, C(255, 240, 140) }), { Mat = NEON, Name = "Firefly" })
			if flies <= 5 then
				Kit.Float(p, rng:NextNumber(0.8, 1.4))
			end
		end
	end

	outside(f)
end

return Swamp
