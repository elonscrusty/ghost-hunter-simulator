--!strict
-- ZONE 23: Neon Ghost City (Z 9160..9520). A night-time city rooftop: dark purple tar roofs,
-- pink and cyan signs, warm windows in the skyline all around. Glow stays modest: signs are
-- vivid solid colours with only thin neon tubes and small bulbs, so nothing blooms.
--   Ground: rooftop deck (top Y 0) split into roof sections by flat metal seams; the lane along
--   X = 0 is a steel grate walkway with pink edge strips and string lights on poles beside it.
--   Ghost areas get flat rooftop markings ((0,9245) r30 and (75,9340) r26 are helipads,
--   (-82,9280) r24 and (-62,9400) r24 are painted cyan/pink rings); the boss area (0,9465) r26
--   is a flat light-up dance floor (concentric coloured rings).
--   Edges: low parapets with railings at |X| 140; past them the skyline: tall buildings rising
--   from the dark street far below, window rows, antenna lights and a few rooftop signs.
--   Landmarks: the radio tower at (-118, 9480) (top ~Y 92) and the big "NEON GHOST CITY" sign
--   on a lattice frame beyond the east parapet.
--   Props: water towers, AC units, billboards on steel frames, stair huts with graffiti,
--   skylights, satellite dishes, vent pipes, little neon signs on poles.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local NeonCity = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local CONCRETE = Enum.Material.Concrete
local WOOD = Enum.Material.WoodPlanks
local GLASS = Enum.Material.Glass
local BRICK = Enum.Material.Brick

local Z0, Z1 = 9160, 9520

local TAR = C(72, 64, 98)
local TAR_L = C(92, 82, 122)
local TAR_D = C(55, 48, 78)
local SEAM = C(130, 125, 150)
local PARAPET = C(120, 100, 150)
local PINK = C(255, 90, 200)
local CYAN = C(80, 225, 255)
local PURPLE = C(150, 85, 230)
local LIME = C(160, 255, 120)
local WARM = C(255, 215, 130)
local STEEL = C(85, 85, 105)
local STEEL_L = C(150, 150, 170)
local WOODC = C(140, 95, 65)
local DARK = C(28, 24, 42)
local RED = C(255, 80, 80)

local STEEL_O: Kit.Opts = { Mat = METAL }
local SOLID_STEEL: Kit.Opts = { Mat = METAL, Solid = true, Shadow = true }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

local rng = Random.new(2323)

--==================================================================
-- HELPERS
--==================================================================
local function waterTower(parent: Instance, x: number, z: number, light: boolean)
	local m = Kit.Model(parent, "WaterTower")
	for _, d in { { -3.4, -3.4 }, { 3.4, -3.4 }, { -3.4, 3.4 }, { 3.4, 3.4 } } do
		Kit.Box(m, V(x + d[1] - 0.35, 0, z + d[2] - 0.35), V(x + d[1] + 0.35, 12, z + d[2] + 0.35), STEEL, SOLID_STEEL)
	end
	Props.Beam(m, V(x - 3.4, 2, z - 3.4), V(x + 3.4, 10, z + 3.4), 0.3, 0.3, STEEL, STEEL_O)
	Props.Beam(m, V(x + 3.4, 2, z - 3.4), V(x - 3.4, 10, z + 3.4), 0.3, 0.3, STEEL, STEEL_O)
	Kit.Box(m, V(x - 4.6, 12, z - 4.6), V(x + 4.6, 12.6, z + 4.6), STEEL, STEEL_O)
	Kit.Cyl(m, 10, 10, CFrame.new(x, 17.6, z), WOODC, { Mat = WOOD, Shadow = true })
	for _, y in { 14.4, 20.8 } do
		Kit.Cyl(m, 0.5, 10.3, CFrame.new(x, y, z), STEEL, STEEL_O)
	end
	-- cone roof (stacked discs) with a finial
	for i = 0, 3 do
		Kit.Cyl(m, 1, 10.6 - i * 2.8, CFrame.new(x, 23 + i, z), TAR_D)
	end
	local tip = Kit.Ball(m, 0.9, V(x, 27, z), RED, { Mat = NEON })
	if light then
		Kit.Light(tip, RED, 14, 0.8)
	end
	Kit.AddCircle(x, z, 6)
end

local function acUnit(parent: Instance, x: number, z: number)
	Kit.Box(parent, V(x - 3, 0, z - 2.4), V(x + 3, 3.6, z + 2.4), STEEL_L, { Mat = METAL, Solid = true })
	Kit.Cyl(parent, 0.3, 3.4, CFrame.new(x - 1.2, 3.7, z), DARK, STEEL_O)
	Kit.Part(parent, V(3, 0.1, 0.5), CFrame.new(x - 1.2, 3.85, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), STEEL, STEEL_O)
	for k = -1, 1 do
		Kit.Box(parent, V(x + 0.8, 0.6 + k * 0.8 + 1.2, z - 2.45), V(x + 2.6, 1.0 + k * 0.8 + 1.2, z - 2.4), STEEL, STEEL_O)
	end
	Kit.AddCircle(x, z, 4)
end

-- Billboard on a steel frame facing (fx, fz).
local ADS = { "GHOST COLA", "BOO-BURGER", "NIGHT BUS 24/7", "SPECTRE-FLIX" }
local function billboard(parent: Instance, x: number, z: number, fx: number, fz: number, idx: number, light: boolean)
	local m = Kit.Model(parent, "Billboard")
	local yaw = Kit.FaceYaw(fx, fz)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	for _, sx in { -8, 8 } do
		Kit.Part(m, V(0.8, 14, 0.8), base * CFrame.new(sx, 7, 1), STEEL, SOLID_STEEL)
		Props.Beam(m, (base * CFrame.new(sx, 0, 4)).Position, (base * CFrame.new(sx, 13, 1)).Position, 0.5, 0.5, STEEL, STEEL_O)
	end
	Kit.Part(m, V(22, 0.4, 2), base * CFrame.new(0, 13.2, -0.4), STEEL, STEEL_O)
	local cols = { PINK, CYAN, LIME, PURPLE }
	local col = cols[(idx - 1) % #cols + 1]
	Kit.Part(m, V(22.6, 10.6, 0.5), base * CFrame.new(0, 19, 0.5), DARK)
	local board = Kit.Part(m, V(21.4, 9.4, 0.3), base * CFrame.new(0, 19, 0.2), Kit.Vivid(col), { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, ADS[(idx - 1) % #ADS + 1], C(255, 255, 255), { Stroke = DARK })
	-- little lamps on arms over the board
	for _, sx in { -7, 0, 7 } do
		Kit.Part(m, V(0.3, 0.3, 2.2), base * CFrame.new(sx, 24.8, -0.6), STEEL, STEEL_O)
		local lamp = Kit.Part(m, V(1.2, 0.5, 0.8), base * CFrame.new(sx, 24.6, -1.6), WARM, { Mat = NEON })
		if light and sx == 0 then
			Kit.Light(lamp, WARM, 22, 0.8)
		end
	end
	Kit.AddCircle(x, z, 10)
end

local function stairHut(parent: Instance, x: number, z: number, fx: number, tag: string, tagCol: Color3)
	local m = Kit.Model(parent, "StairHut")
	Kit.Box(m, V(x - 5, 0, z - 4), V(x + 5, 9, z + 4), C(150, 95, 85), { Mat = BRICK, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 5.4, 9, z - 4.4), V(x + 5.4, 9.8, z + 4.4), TAR_D, { Mat = CONCRETE })
	-- door facing fx
	Kit.Box(m, V(x + fx * 5, 0, z - 1.6), V(x + fx * 5.15, 6.4, z + 1.6), C(60, 70, 110), STEEL_O)
	Kit.Box(m, V(x + fx * 5.1, 3, z + 0.9), V(x + fx * 5.3, 3.4, z + 1.3), STEEL_L, STEEL_O)
	Kit.Ball(m, 0.8, V(x + fx * 5.4, 7.4, z), WARM, { Mat = NEON })
	-- graffiti tag on the side facing the lane
	Props.Graffiti(m, V(x, 4.5, z - 4.1), 8, 3.5, 0, -1, tag, tagCol, -6)
	Props.Graffiti(m, V(x, 4.5, z + 4.1), 8, 3.5, 0, 1, tag, tagCol, 5)
	Kit.AddCircle(x, z, 7)
end

local function skylight(parent: Instance, x: number, z: number)
	Kit.Box(parent, V(x - 4, 0, z - 3), V(x + 4, 1.2, z + 3), STEEL_L, { Mat = METAL, Solid = true })
	for _, s in { -1, 1 } do
		Kit.Wedge(parent, V(8, 2.2, 3), CFrame.new(x, 2.3, z + s * 1.5) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0), C(150, 200, 255), { Mat = GLASS, Transp = 0.25, Refl = 0.2 })
	end
	Kit.AddCircle(x, z, 5)
end

local function dish(parent: Instance, x: number, z: number, fx: number)
	Kit.Box(parent, V(x - 1, 0, z - 1), V(x + 1, 1, z + 1), STEEL, STEEL_O)
	Kit.Cyl(parent, 3, 0.4, CFrame.new(x, 2.5, z), STEEL, STEEL_O)
	Kit.Part(parent, V(0.4, 4.4, 4.4), CFrame.new(x, 4.6, z) * CFrame.Angles(0, Kit.FaceYaw(fx, 0.4), 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.5), C(225, 225, 235), { Shape = Enum.PartType.Cylinder })
	Kit.AddCircle(x, z, 2.6)
end

-- Small neon sign on a pole: a vivid board with a thin neon tube border at the top.
local function poleSign(parent: Instance, x: number, z: number, text: string, col: Color3, fx: number, fz: number)
	Kit.Cyl(parent, 9, 0.5, CFrame.new(x, 4.5, z), STEEL, STEEL_O)
	local cf = CFrame.new(x, 10.6, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Part(parent, V(7.4, 3.4, 0.4), cf * CFrame.new(0, 0, 0.1), DARK)
	local board = Kit.Part(parent, V(7, 3, 0.3), cf, DARK, { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, text, Kit.Vivid(col), { Stroke = DARK })
	Kit.Sign(board, Enum.NormalId.Back, text, Kit.Vivid(col), { Stroke = DARK })
	Kit.Part(parent, V(7.4, 0.2, 0.2), cf * CFrame.new(0, 1.8, 0), col, { Mat = NEON })
	Kit.AddCircle(x, z, 1.5)
end

local function ventPipe(parent: Instance, x: number, z: number, emit: boolean)
	Kit.Cyl(parent, 6, 1.6, CFrame.new(x, 3, z), STEEL_L, STEEL_O)
	Kit.Cyl(parent, 0.6, 2.4, CFrame.new(x, 6.2, z), STEEL, STEEL_O)
	if emit then
		local p = Kit.Part(parent, V(1.5, 0.5, 1.5), CFrame.new(x, 7, z), C(255, 255, 255), { Transp = 1, Name = "SteamVent" })
		Kit.Emitter(p, C(210, 200, 240), 3, 4, 1.4)
	end
	Kit.AddCircle(x, z, 1.5)
end

--==================================================================
-- GROUND, PARAPETS, SKYLINE
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-146, -4, Z0), V(146, 0, Z1), TAR, { Mat = CONCRETE, Solid = true, Name = "Ground_NeonCity" })
	-- roof sections (flat panels in two tones) split by metal seams
	local sections = {
		{ -138, Z0 + 4, -60, Z0 + 150 }, { -60, Z0 + 4, -10, Z0 + 200 }, { 10, Z0 + 4, 60, Z0 + 120 }, { 60, Z0 + 4, 138, Z0 + 140 },
		{ -138, Z0 + 150, -60, Z0 + 270 }, { 10, Z0 + 120, 138, Z0 + 260 }, { -60, Z0 + 200, -10, Z1 - 4 }, { -138, Z0 + 270, -60, Z1 - 4 }, { 10, Z0 + 260, 138, Z1 - 4 },
	}
	for i, s in sections do
		Kit.Box(f, V(s[1] + 0.6, 0, s[2] + 0.6), V(s[3] - 0.6, 0.03, s[4] - 0.6), if i % 2 == 0 then TAR_L else TAR, { Mat = CONCRETE })
		Kit.Box(f, V(s[1], 0, s[2] - 0.6), V(s[3], 0.05, s[2] + 0.6), SEAM, STEEL_O)
		Kit.Box(f, V(s[1] - 0.6, 0, s[2]), V(s[1] + 0.6, 0.05, s[4]), SEAM, STEEL_O)
	end
	-- the lane: steel grate walkway with pink edge strips and cyan arrows
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.08, Z1), C(70, 85, 110), { Mat = Enum.Material.DiamondPlate, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.4, 0.1, Z1), Kit.Vivid(PINK))
	end
	for z = Z0 + 30, Z1 - 30, 40 do
		for _, s in { -1, 1 } do
			Kit.Part(f, V(2.4, 0.03, 2.4), CFrame.new(s * 1.6, 0.1, z) * CFrame.Angles(0, math.pi / 4, 0), Kit.Vivid(CYAN))
		end
	end
	-- rooftop markings on the ghost areas
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		if i == 1 or i == 3 then
			-- helipad: yellow ring on dark disc with a big flat H
			Kit.Disc(f, x, z, 0.08, r * 2 + 2, 0.08, TAR_D, { Mat = CONCRETE })
			Kit.Disc(f, x, z, 0.11, r * 1.7, 0.03, Kit.Vivid(C(255, 215, 70)))
			Kit.Disc(f, x, z, 0.13, r * 1.5, 0.03, TAR_D, { Mat = CONCRETE })
			local h = r * 0.6
			for _, sx in { -1, 1 } do
				Kit.Box(f, V(x + sx * h * 0.5 - 1.2, 0.13, z - h * 0.6), V(x + sx * h * 0.5 + 1.2, 0.16, z + h * 0.6), C(245, 245, 250))
			end
			Kit.Box(f, V(x - h * 0.5, 0.13, z - 1.1), V(x + h * 0.5, 0.16, z + 1.1), C(245, 245, 250))
		else
			local col = if i == 2 then CYAN else PINK
			Kit.Disc(f, x, z, 0.08, r * 2 + 2, 0.08, TAR_D, { Mat = CONCRETE })
			Kit.Disc(f, x, z, 0.11, r * 2 - 2, 0.03, Kit.Vivid(col))
			Kit.Disc(f, x, z, 0.13, r * 2 - 6, 0.03, TAR_L, { Mat = CONCRETE })
			Kit.Disc(f, x, z, 0.15, r * 0.9, 0.03, Kit.Vivid(PURPLE))
			-- paint splats
			for k = 0, 4 do
				local ang = k * 1.3 + i
				Kit.Disc(f, x + math.cos(ang) * r * 0.6, z + math.sin(ang) * r * 0.6, 0.15, rng:NextNumber(2, 4), 0.02, Kit.Vivid(if k % 2 == 0 then LIME else col))
			end
		end
	end
	-- boss: light-up dance floor (flat rings)
	local rings = { DARK, PINK, PURPLE, CYAN, LIME, PINK, DARK }
	for k, col in rings do
		local d = 58 - (k - 1) * 8
		Kit.Disc(f, 0, BOSS_Z, 0.08 + k * 0.02, d, 0.05, if k == 1 or k == #rings then col else Kit.Vivid(col))
	end
end

local function parapets(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 3.5, z1), PARAPET, { Mat = BRICK, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.6, 3.5, z0), V(s * 146.4, 4.1, z1), TAR_D, { Mat = CONCRETE })
		-- railing on top
		Kit.Box(f, V(s * 142.8, 7.6, z0), V(s * 143.2, 8, z1), STEEL_L, STEEL_O)
		for z = z0 + 6, z1 - 2, 18 do
			Kit.Box(f, V(s * 142.85, 4.1, z - 0.2), V(s * 143.15, 7.6, z + 0.2), STEEL_L, STEEL_O)
		end
		-- a dark drop beyond the parapet down to the street
		Kit.Box(f, V(s * 146, -120, Z0), V(s * 150, 0, Z1), C(60, 50, 80), { Mat = BRICK })
		Kit.Box(f, V(s * 150, -124, Z0 - 40), V(s * 300, -120, Z1 + 40), C(30, 28, 45), { Mat = CONCRETE })
	end
end

local function building(f: Instance, x: number, z: number, w: number, d: number, h: number, face: number, col: Color3)
	-- x/z = centre of the footprint; face = -1/1: the side that faces the play area (toward X = 0)
	local base = -120
	Kit.Box(f, V(x - w / 2, base, z - d / 2), V(x + w / 2, h, z + d / 2), col, { Mat = CONCRETE })
	Kit.Box(f, V(x - w / 2 - 0.6, h, z - d / 2 - 0.6), V(x + w / 2 + 0.6, h + 1.2, z + d / 2 + 0.6), TAR_D, { Mat = CONCRETE })
	-- window rows on the inward face (one strip per floor), warm or cool
	local fxw = x + face * w / 2
	local floor = 0
	for y = h - 6, h - 6 - 8 * 7, -8 do
		floor += 1
		if y > -60 then
			local lit = (floor + math.floor(z)) % 3 ~= 0
			Kit.Box(f, V(fxw - face * 0.1, y, z - d / 2 + 2), V(fxw + face * 0.2, y + 3.2, z + d / 2 - 2), if lit then WARM else C(80, 90, 140), { Transp = if lit then 0 else 0.2 })
		end
	end
	-- rooftop antenna with a red bulb on the tall ones
	if h > 60 then
		Kit.Cyl(f, 12, 0.5, CFrame.new(x, h + 7, z), STEEL, STEEL_O)
		Kit.Ball(f, 1, V(x, h + 13.4, z), RED, { Mat = NEON })
	end
end

local function skyline(f: Instance)
	local cols = { C(60, 55, 95), C(80, 65, 120), C(50, 60, 100), C(95, 70, 115) }
	for _, s in { -1, 1 } do
		local z = Z0 - 10
		local i = 0
		while z < Z1 + 10 do
			i += 1
			local d = rng:NextNumber(30, 48)
			local w = rng:NextNumber(26, 40)
			local h = rng:NextNumber(14, 90)
			local x = s * (158 + w / 2 + rng:NextNumber(0, 12))
			building(f, x, z + d / 2, w, d, h, -s, cols[(i - 1) % #cols + 1])
			-- a rooftop sign on some of them, facing the play area
			if i % 3 == 1 then
				local col = if s < 0 then PINK else CYAN
				local sx = x - s * w / 2 - s * 0.4
				local cf = CFrame.new(sx, h - 14, z + d / 2) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0)
				local b = Kit.Part(f, V(d - 8, 6, 0.4), cf, DARK, { Name = "SignBoard" })
				Kit.Sign(b, Enum.NormalId.Front, if i % 2 == 1 then "HOTEL" else "OPEN LATE", Kit.Vivid(col), { Stroke = DARK })
				Kit.Part(f, V(d - 7, 0.25, 0.25), cf * CFrame.new(0, 3.2, -0.1), col, { Mat = NEON })
			end
			z += d + rng:NextNumber(4, 10)
		end
	end
end

--==================================================================
-- LANDMARKS AND ROOFTOP PROPS
--==================================================================
local function radioTower(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "RadioTower")
	Kit.Box(m, V(x - 6, 0, z - 6), V(x + 6, 2, z + 6), C(110, 105, 130), { Mat = CONCRETE, Solid = true })
	local top = 90
	for _, d in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		Props.Beam(m, V(x + d[1], 2, z + d[2]), V(x + d[1] * 0.15, top, z + d[2] * 0.15), 0.6, 0.6, C(220, 70, 90), STEEL_O)
	end
	for y = 12, top - 10, 14 do
		local t = (y - 2) / (top - 2)
		local r = 4 * (1 - t) + 0.6 * t
		Kit.Box(m, V(x - r, y, z - r), V(x + r, y + 0.5, z + r), C(240, 240, 250), STEEL_O)
	end
	-- small cyan rings (thin tubes) high up
	for _, y in { 50, 70 } do
		local t = (y - 2) / (top - 2)
		local r = 4 * (1 - t) + 0.6 * t + 0.6
		for _, s in { -1, 1 } do
			Kit.Box(m, V(x - r, y, z + s * r - 0.12), V(x + r, y + 0.25, z + s * r + 0.12), CYAN, { Mat = NEON })
		end
	end
	Kit.Cyl(m, 10, 0.4, CFrame.new(x, top + 5, z), STEEL_L, STEEL_O)
	local bulb = Kit.Ball(m, 1.8, V(x, top + 10.6, z), RED, { Mat = NEON })
	Kit.Light(bulb, RED, 30, 1)
	Kit.AddCircle(x, z, 8)
end

local function citySign(f: Instance)
	-- giant rooftop sign on a lattice beyond the east parapet, facing the lane
	local m = Kit.Model(f, "CitySign")
	local x, z = 162, Z0 + 200
	for _, dz in { -30, -10, 10, 30 } do
		Kit.Box(m, V(x - 0.6, -2, z + dz - 0.6), V(x + 0.6, 40, z + dz + 0.6), STEEL, STEEL_O)
		Props.Beam(m, V(x, 0, z + dz - 9), V(x, 38, z + dz + 9), 0.4, 0.4, STEEL, STEEL_O)
	end
	Kit.Box(m, V(x - 1, 39, z - 36), V(x + 1, 40, z + 36), STEEL, STEEL_O)
	local board = Kit.Part(m, V(1, 16, 70), CFrame.new(x - 0.6, 48, z), C(40, 25, 70), { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Left, "NEON GHOST CITY", Kit.Vivid(PINK), { Stroke = C(255, 255, 255) })
	-- thin neon tube frame
	Kit.Box(m, V(x - 1.3, 56.2, z - 35.4), V(x - 1, 56.6, z + 35.4), CYAN, { Mat = NEON })
	Kit.Box(m, V(x - 1.3, 39.6, z - 35.4), V(x - 1, 40, z + 35.4), CYAN, { Mat = NEON })
	Kit.Light(board, PINK, 50, 0.8)
end

local function stringLights(f: Instance)
	-- poles beside the lane with sagging strings of coloured bulbs (only a few glow); a string
	-- is hung only where both of its poles fit
	local cols = { PINK, CYAN, WARM, LIME, PURPLE }
	local n = 0
	for z = Z0 + 30, Z1 - 20, 30 do
		if Kit.IsFree(-12, z, 1) and Kit.IsFree(12, z, 1) then
			n += 1
			for _, s in { -1, 1 } do
				Kit.Cyl(f, 14, 0.5, CFrame.new(s * 12, 7, z), STEEL, STEEL_O)
				Kit.AddCircle(s * 12, z, 1)
			end
			local a, b = V(-12, 13.6, z), V(12, 13.6, z)
			Props.Beam(f, a, b, 0.12, 0.12, DARK)
			for k = 1, 5 do
				local t = k / 6
				local p = a:Lerp(b, t) - V(0, math.sin(t * math.pi) * 1.6, 0)
				Kit.Ball(f, 0.8, p, cols[(k + n) % #cols + 1], if (k + n) % 4 == 0 then { Mat = NEON } else nil)
			end
		end
	end
end

local function props(f: Instance)
	radioTower(f, -118, Z0 + 320)
	citySign(f)
	for i, p in { { -120, Z0 + 40 }, { 118, Z0 + 100 }, { -30, Z0 + 175 }, { 120, Z0 + 300 } } do
		if Kit.IsFree(p[1], p[2], 6) then
			waterTower(f, p[1], p[2], i == 2)
		end
	end
	for i, p in { { 70, Z0 + 60, 0, -1 }, { -112, Z0 + 200, 1, 0 }, { 40, Z0 + 250, 0, -1 } } do
		if Kit.IsFree(p[1], p[2], 10) then
			billboard(f, p[1], p[2], p[3], p[4], i, i == 1)
		end
	end
	local huts: { { x: number, z: number, fx: number, tag: string } } = {
		{ x = -40, z = Z0 + 50, fx = 1, tag = "BOO!" }, { x = 112, z = Z0 + 228, fx = -1, tag = "GHOST CREW" }, { x = 40, z = Z0 + 330, fx = -1, tag = "NEON 4 EVER" },
	}
	for i, h in huts do
		if Kit.IsFree(h.x, h.z, 7) then
			stairHut(f, h.x, h.z, h.fx, h.tag, if i % 2 == 0 then CYAN else PINK)
		end
	end
	for _ = 1, 22 do
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 30, Z1 - 15)
		if Kit.IsFree(x, z, 4) then
			acUnit(f, x, z)
		end
	end
	for _, p in { { -100, Z0 + 95 }, { 100, Z0 + 265 }, { -20, Z0 + 230 }, { 35, Z0 + 140 } } do
		if Kit.IsFree(p[1], p[2], 5) then
			skylight(f, p[1], p[2])
		end
	end
	for _, p in { { -132, Z0 + 120, 1 }, { 132, Z0 + 170, -1 }, { 55, Z0 + 40, -1 } } do
		if Kit.IsFree(p[1], p[2], 2.6) then
			dish(f, p[1], p[2], p[3])
		end
	end
	local poles: { { x: number, z: number, text: string, col: Color3 } } = {
		{ x = -16, z = Z0 + 140, text = "24 HR", col = PINK }, { x = 16, z = Z0 + 205, text = "BOO BAR", col = CYAN },
		{ x = -16, z = Z0 + 268, text = "ARCADE", col = LIME }, { x = 16, z = Z0 + 40, text = "TACOS", col = WARM },
	}
	for i, ps in poles do
		if Kit.IsFree(ps.x, ps.z, 1.5) then
			poleSign(f, ps.x, ps.z, ps.text, ps.col, if i % 2 == 0 then -1 else 1, 0)
		end
	end
	for i, p in { { 96, Z0 + 30 }, { -90, Z0 + 330 }, { 128, Z0 + 330 } } do
		if Kit.IsFree(p[1], p[2], 1.5) then
			ventPipe(f, p[1], p[2], i == 1)
		end
	end
	-- floating holo-cubes (ad drones) drifting over the roofs
	for i, p in { V(-50, 22, Z0 + 110), V(48, 26, Z0 + 230), V(-100, 20, Z0 + 260), V(100, 24, Z0 + 140) } do
		local c = Kit.Part(f, V(2.4, 2.4, 2.4), CFrame.new(p) * CFrame.Angles(0.6, i, 0.6), if i % 2 == 0 then PINK else CYAN, { Transp = 0.2, Name = "FloatingHoloCube" })
		Kit.Float(c, 1.4)
	end
end

--==================================================================
-- BUILD
--==================================================================
function NeonCity.Build(map: Instance)
	local f = Kit.Folder(map, "NeonCity")
	ground(f)
	parapets(f)
	skyline(f)
	props(f)
	stringLights(f)
end

return NeonCity
