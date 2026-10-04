--!strict
-- ZONE 6: Ghost Ship Harbor (Z 1560..1920).
--   Cobblestone quay at Y = 0 with a WoodPlanks boardwalk along X = 0 (gate to gate) and
--   plank deck pads painted under every ghost area (flat, <= 0.17 tall).
--   -X side: muted-red brick harbour wall, three open-front warehouses (X -138..-112) and a row
--   of town houses behind the wall.
--   +X side: low quay curb + rope railing; the ocean (Y -1.5) beyond X = 146; a shallow
--   wading inlet (floor Y -0.5, no pit) at X 104..146, Z 1600..1650 with a pier and fishing hut.
--   Landmarks: the haunted ship "The Salty Specter" moored along +X (hull X 130..174,
--   Z 1672..1810, masts to Y ~102) and a red/white striped lighthouse at (116, 1866), ~94 tall.
--   Glow is limited to portholes, stern windows, a few rune lines, the figurehead heart, the
--   lighthouse lamp, lamp globes, a few ghostly windows and floating spectral lanterns.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Harbor = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local COBBLE = Enum.Material.Cobblestone
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local ROCK = Enum.Material.Rock

local Z0, Z1 = 1560, 1920

local SEA = C(28, 72, 128)
local SEA_TEAL = C(45, 135, 150)
local QUAY = C(118, 132, 150)
local PLANK = C(170, 125, 82)
local PLANK_DARK = C(112, 78, 55)
local HULL = C(92, 62, 48)
local MAST = C(110, 80, 58)
local RED = C(175, 72, 66)
local TEAL = C(60, 185, 185)
local SPECTRAL = C(120, 255, 170)
local PURPLE = C(160, 110, 230)
local SAIL = C(238, 232, 212)
local SAIL_TEAL = C(170, 222, 215)
local IRON = C(58, 60, 74)
local GOLD = C(255, 200, 60)
local ROPE = C(205, 178, 130)
local WARM = C(255, 205, 120)
local CRATES = { C(185, 135, 85), C(160, 110, 70), C(200, 150, 95), C(140, 100, 70) }

local SOLID_PLANKS: Kit.Opts = { Mat = PLANKS, Solid = true, Shadow = true }

-- Gable roof, ridge along local X, slopes toward local ±Z, bottom at local y = 0.
local function gable(parent: Instance, base: CFrame, length: number, depth: number, height: number, color: Color3, mat: Enum.Material)
	local half = depth / 2
	local o: Kit.Opts = { Mat = mat, Solid = true, Shadow = true }
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, -half / 2), color, o)
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), color, o)
end

-- Plan-view triangle (Y y0..y1): right angle at (xEdge, zBase), point at (xEdge, zTip) with
-- zTip > zBase, widest at (xOuter, zBase). Two mirrored halves make the ship's bow.
local function bowHalf(parent: Instance, xEdge: number, xOuter: number, zBase: number, zTip: number, y0: number, y1: number, color: Color3, opts: Kit.Opts)
	local s = if xOuter > xEdge then 1 else -1
	local center = V((xEdge + xOuter) / 2, (y0 + y1) / 2, (zBase + zTip) / 2)
	local cf = CFrame.fromMatrix(center, V(0, s, 0), V(s, 0, 0))
	Kit.Wedge(parent, V(y1 - y0, math.abs(xOuter - xEdge), zTip - zBase), cf, color, opts)
end

local function crate(parent: Instance, pos: Vector3, s: number, yaw: number)
	local cf = CFrame.new(pos + V(0, s / 2, 0)) * CFrame.Angles(0, yaw, 0)
	Kit.Part(parent, V(s, s, s), cf, Kit.Pick(CRATES), { Mat = WOOD, Solid = true, Shadow = true })
	Kit.Part(parent, V(s + 0.12, s * 0.18, s + 0.12), cf, PLANK_DARK, { Mat = WOOD })
end

local function barrel(parent: Instance, pos: Vector3, h: number)
	Kit.Cyl(parent, h, 2.8, CFrame.new(pos + V(0, h / 2, 0)), C(150, 100, 62), { Mat = WOOD, Solid = true })
	for _, t in { 0.22, 0.78 } do
		Kit.Cyl(parent, 0.35, 2.95, CFrame.new(pos + V(0, h * t, 0)), IRON, { Mat = METAL })
	end
end

--==================================================================
-- GROUND, WATER, PATH, WALLS
--==================================================================
local function ground(f: Instance)
	local quay: Kit.Opts = { Mat = COBBLE, Solid = true }
	Kit.Box(f, V(-190, -4, Z0), V(104, 0, Z1), QUAY, { Mat = COBBLE, Solid = true, Name = "Ground_Harbor" })
	Kit.Box(f, V(104, -4, Z0), V(146, 0, 1600), QUAY, quay)
	Kit.Box(f, V(104, -4, 1650), V(146, 0, Z1), QUAY, quay)
	-- shallow wading inlet: solid floor at Y -0.5 (half-stud step, no pit) under clear water
	Kit.Box(f, V(104, -4, 1600), V(146, -0.5, 1650), C(80, 120, 125), { Mat = Enum.Material.Sand, Solid = true, Name = "InletFloor" })
	Kit.Box(f, V(104, -0.5, 1600), V(146, -0.15, 1650), SEA_TEAL, { Transp = 0.45, Refl = 0.2, Name = "InletWater" })
	-- timber edging around the inlet and a sea-gate beam hiding the step down to the ocean
	Kit.Box(f, V(102.8, -0.5, 1600), V(104, 0.3, 1650), PLANK_DARK, { Mat = WOOD, Solid = true })
	Kit.Box(f, V(102.8, -0.5, 1598.8), V(140, 0.3, 1600), PLANK_DARK, { Mat = WOOD, Solid = true })
	Kit.Box(f, V(102.8, -0.5, 1650), V(140, 0.3, 1651.2), PLANK_DARK, { Mat = WOOD, Solid = true })
	Kit.Box(f, V(144, -2, 1598.8), V(146, 0.4, 1651.2), PLANK_DARK, { Mat = WOOD })
	Kit.AddRect(102, 1598, 140, 1652)

	-- the ocean (outside the play area), moonlit streaks and a few rocks
	Kit.Box(f, V(146, -3, Z0), V(190, -1.5, Z1), SEA, { Refl = 0.2, Name = "Ocean" })
	Kit.Box(f, V(190, -3, 1520), V(560, -1.5, 1960), SEA, { Refl = 0.2, Name = "Ocean" })
	Kit.Box(f, V(170, -1.5, 1700), V(540, -1.44, 1712), C(170, 225, 235), { Transp = 0.45 })
	Kit.Box(f, V(200, -1.5, 1726), V(540, -1.44, 1732), C(170, 225, 235), { Transp = 0.55 })
	Kit.Disc(f, 420, 1716, -1.42, 46, 0.06, C(250, 245, 215), { Transp = 0.35, Name = "MoonGlow" })
	for _, r in { { 232, 1612, 18 }, { 262, 1846, 24 }, { 205, 1900, 14 }, { 300, 1760, 12 } } do
		Kit.Ball(f, r[3], V(r[1], -4, r[2]), C(85, 95, 115), { Mat = ROCK })
	end

	-- boardwalk path along X = 0 with painted teal edges
	Kit.Box(f, V(-9, 0, Z0), V(9, 0.05, Z1), PLANK, { Mat = PLANKS, Solid = true, Name = "Boardwalk" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 9 - 0.4, 0.05, Z0), V(s * 9 + 0.4, 0.12, Z1), Kit.Vivid(TEAL))
	end
	-- plank dock patches on the quay (flat)
	for _, d in { { 30, 1598, 102, 1660 }, { -110, 1576, -40, 1610 }, { 30, 1790, 100, 1840 }, { -108, 1830, -30, 1890 } } do
		Kit.Box(f, V(d[1], 0, d[2]), V(d[3], 0.04, d[4]), PLANK, { Mat = PLANKS })
	end
end

local function sideWalls(f: Instance)
	-- -X: brick harbour wall with slate cap and wooden posts topped with buoys
	local brick = C(160, 86, 74)
	Kit.Box(f, V(-146, 0, Z0 + 3), V(-140, 14, Z1 - 3), brick, { Mat = Enum.Material.Brick, Solid = true })
	Kit.Box(f, V(-146.6, 14, Z0 + 3), V(-139.4, 15.2, Z1 - 3), C(70, 110, 150), { Mat = Enum.Material.Slate })
	Kit.Box(f, V(-139.95, 3, Z0 + 3), V(-139.7, 3.8, Z1 - 3), Kit.Vivid(TEAL))
	local n = 0
	for z = Z0 + 20, Z1 - 15, 30 do
		n += 1
		Kit.Box(f, V(-147, 0, z - 2), V(-139, 17, z + 2), PLANK_DARK, { Mat = WOOD, Solid = true })
		Kit.Ball(f, 3, V(-143, 18.2, z), Kit.Vivid(if n % 2 == 0 then RED else TEAL))
	end
	-- life rings on the wall facing the docks
	for _, z in { 1650, 1770, 1890 } do
		Kit.CylFlat(f, 0.5, 3.4, V(-139.5, 8, z), "X", Kit.Vivid(RED))
		Kit.CylFlat(f, 0.6, 1.6, V(-139.45, 8, z), "X", C(240, 240, 235))
	end
	-- town houses behind the wall (backdrop)
	local houses = { C(120, 80, 110), C(70, 110, 140), C(150, 90, 75), C(80, 125, 120), C(120, 95, 70), C(95, 85, 140) }
	for i, z in { 1584, 1640, 1700, 1760, 1820, 1882 } do
		local h = 22 + (i % 3) * 6
		Kit.Box(f, V(-186, 0, z - 13), V(-152, h, z + 13), houses[i], { Mat = if i % 2 == 0 then PLANKS else Enum.Material.Brick })
		gable(f, CFrame.new(-169, h, z) * CFrame.Angles(0, math.pi / 2, 0), 28, 38, 10, C(55, 70, 105), Enum.Material.Slate)
		local ghostly = i % 2 == 1
		Kit.Box(f, V(-152.3, h - 9, z - 3), V(-151.9, h - 4, z + 3), if ghostly then SPECTRAL else WARM, { Mat = if ghostly then NEON else Enum.Material.SmoothPlastic })
	end

	-- +X: low quay curb, rope railing on posts (gaps at the inlet and where the ship's hull is)
	local curb = C(100, 112, 130)
	Kit.Box(f, V(140, 0, Z0 + 3), V(146, 1, 1600), curb, { Mat = COBBLE, Solid = true })
	Kit.Box(f, V(140, 0, 1650), V(146, 1, Z1 - 3), curb, { Mat = COBBLE, Solid = true })
	for _, seg in { { 1566, 1598 }, { 1652, 1664 }, { 1818, 1914 } } do
		local a, b = seg[1], seg[2]
		local z = a
		while z <= b do
			Kit.Cyl(f, 5, 1.2, CFrame.new(143, 3, z), PLANK_DARK, { Mat = WOOD })
			z += 16
		end
		Kit.CylFlat(f, b - a, 0.4, V(143, 4, (a + b) / 2), "Z", ROPE, { Mat = FABRIC })
	end
	-- decorative pier out into the ocean (beyond the wall)
	Kit.Box(f, V(146, -0.8, 1578), V(190, -0.2, 1590), PLANK, { Mat = PLANKS })
	for x = 152, 186, 11 do
		for _, z in { 1577.5, 1590.5 } do
			Kit.Cyl(f, 5, 1.3, CFrame.new(x, -1.5, z), PLANK_DARK, { Mat = WOOD })
		end
	end
end

--==================================================================
-- LANDMARKS
--==================================================================
local function ship(f: Instance)
	local m = Kit.Model(f, "GhostShip")
	local cx = 152
	local x0, x1 = 130, 174
	local zs, ze, zt = 1672, 1778, 1810 -- stern, start of bow, bow tip
	local deckOpts: Kit.Opts = { Mat = PLANKS }

	-- hull + bow + deck
	Kit.Box(m, V(x0, -6, zs), V(x1, 17, ze), HULL, SOLID_PLANKS)
	bowHalf(m, cx, x0, ze, zt, -6, 17, HULL, SOLID_PLANKS)
	bowHalf(m, cx, x1, ze, zt, -6, 17, HULL, SOLID_PLANKS)
	Kit.Box(m, V(x0 + 1, 17, zs), V(x1 - 1, 18, ze), PLANK, deckOpts)
	bowHalf(m, cx, x0 + 1.5, ze, zt - 3, 17, 18, PLANK, deckOpts)
	bowHalf(m, cx, x1 - 1.5, ze, zt - 3, 17, 18, PLANK, deckOpts)
	-- bulwarks
	Kit.Box(m, V(x0, 17, zs), V(x0 + 1.2, 21, ze), HULL, deckOpts)
	Kit.Box(m, V(x1 - 1.2, 17, zs), V(x1, 21, ze), HULL, deckOpts)
	Props.Beam(m, V(x0 + 0.6, 19, ze), V(cx, 19, zt), 1.2, 4, HULL, deckOpts)
	Props.Beam(m, V(x1 - 0.6, 19, ze), V(cx, 19, zt), 1.2, 4, HULL, deckOpts)
	-- muted red wale, teal waterline and gold rail on the side players see (-X), plus the bow
	Kit.Box(m, V(x0 - 0.3, 9, zs), V(x0 + 0.2, 11.5, ze), Kit.Vivid(RED), { Mat = WOOD })
	Props.Beam(m, V(x0 - 0.2, 10.25, ze), V(cx, 10.25, zt + 0.3), 0.6, 2.5, Kit.Vivid(RED), { Mat = WOOD })
	Kit.Box(m, V(x0 - 0.25, -1.5, zs), V(x0 + 0.2, 0.3, ze), Kit.Vivid(TEAL))
	Kit.Box(m, V(x0 - 0.35, 20.6, zs), V(x0 + 1.3, 21.3, ze), Kit.Vivid(GOLD), { Mat = METAL })

	-- stern castle (faces players arriving from the gate)
	Kit.Box(m, V(x0, 17, zs), V(x1, 30, 1700), HULL, SOLID_PLANKS)
	Kit.Box(m, V(x0 + 1, 30, zs), V(x1 - 1, 31, 1700), PLANK, deckOpts)
	Kit.Box(m, V(x0, 30, zs), V(x0 + 1, 33.5, 1700), HULL, deckOpts)
	Kit.Box(m, V(x1 - 1, 30, zs), V(x1, 33.5, 1700), HULL, deckOpts)
	Kit.Box(m, V(x0, 30, zs), V(x1, 33.5, zs + 1), HULL, deckOpts)
	Kit.Box(m, V(x0 - 0.3, 29, zs - 0.3), V(x1 + 0.3, 30, 1700), Kit.Vivid(RED), { Mat = WOOD })
	for i = -1, 1 do
		local x = cx + i * 12
		local win = Kit.Box(m, V(x - 2.6, 20, zs - 0.35), V(x + 2.6, 26.5, zs + 0.1), SPECTRAL, { Mat = NEON, Transp = 0.1 })
		Kit.Box(m, V(x - 3.2, 19.4, zs - 0.2), V(x + 3.2, 27.1, zs + 0.1), Kit.Vivid(GOLD), { Mat = METAL })
		if i == 0 then
			Kit.Light(win, SPECTRAL, 30, 1.4)
		end
		Kit.Box(m, V(x - 2.4, 6, zs - 0.25), V(x + 2.4, 10.5, zs + 0.1), C(40, 60, 85))
	end
	-- forecastle
	Kit.Box(m, V(x0, 17, 1758), V(x1, 23, ze), HULL, SOLID_PLANKS)
	Kit.Box(m, V(x0 + 1, 23, 1758), V(x1 - 1, 23.6, ze), PLANK, deckOpts)

	-- masts, yards, tattered sails, crow's nest, ropes
	local masts = { { 1712, 80 }, { 1738, 102 }, { 1764, 88 } }
	local tops: { Vector3 } = {}
	for i, mst in masts do
		local z, top = mst[1], mst[2]
		Kit.Cyl(m, top - 17, 3, CFrame.new(cx, (17 + top) / 2, z), MAST, { Mat = WOOD, Shadow = true })
		local span = top - 17
		local yA = 17 + span * 0.55
		local yB = 17 + span * 0.88
		local lowW = 34 + i * 2
		Kit.CylFlat(m, lowW + 4, 1.2, V(cx, yA, z), "X", MAST, { Mat = WOOD })
		Kit.CylFlat(m, lowW - 4, 1.1, V(cx, yB, z), "X", MAST, { Mat = WOOD })
		local col = if i == 2 then SAIL_TEAL else SAIL
		local sailOpts: Kit.Opts = { Mat = FABRIC, Transp = 0.06 }
		-- lower sail torn into two ragged halves plus a dangling strip
		local h1 = (yA - 22) * 0.95
		local h2 = (yA - 22) * 0.7
		Kit.Part(m, V(lowW / 2 - 1, h1, 0.5), CFrame.new(cx - lowW / 4, yA - h1 / 2 - 0.6, z + 1.3) * CFrame.Angles(-0.08, 0, 0), col, sailOpts)
		Kit.Part(m, V(lowW / 2 - 1, h2, 0.5), CFrame.new(cx + lowW / 4, yA - h2 / 2 - 0.6, z + 1.3) * CFrame.Angles(-0.08, 0, 0.04), col, sailOpts)
		Kit.Part(m, V(3, h1 - h2 + 2, 0.4), CFrame.new(cx + lowW / 4 + 3, yA - h2 - (h1 - h2) / 2, z + 1.1) * CFrame.Angles(0, 0, 0.18), col, sailOpts)
		local hU = (yB - yA) - 3
		Kit.Part(m, V(lowW - 8, hU, 0.5), CFrame.new(cx, yB - hU / 2 - 0.6, z + 1.3) * CFrame.Angles(-0.06, 0, 0), if i == 2 then SAIL else SAIL_TEAL, sailOpts)
		table.insert(tops, V(cx, top - 3, z))
		-- shrouds: two to the -X bulwark (visible side), one to +X
		Props.Beam(m, V(cx, top - 4, z), V(x0 + 0.6, 21, z - 9), 0.35, 0.35, ROPE)
		Props.Beam(m, V(cx, top - 4, z), V(x0 + 0.6, 21, z + 9), 0.35, 0.35, ROPE)
		Props.Beam(m, V(cx, top - 4, z), V(x1 - 0.6, 21, z), 0.35, 0.35, ROPE)
	end
	Props.Beam(m, tops[1], tops[2], 0.35, 0.35, ROPE)
	Props.Beam(m, tops[2], tops[3], 0.35, 0.35, ROPE)
	Kit.Cyl(m, 3, 8, CFrame.new(cx, 86.5, 1738), PLANK_DARK, { Mat = WOOD })
	-- ghostly flag on the main mast
	local flag = Kit.Part(m, V(0.4, 7, 11), CFrame.new(cx, 97, 1738 - 6.5), C(40, 34, 55), { Mat = FABRIC })
	Kit.Sign(flag, Enum.NormalId.Left, "👻", C(240, 240, 240))
	-- bowsprit + forestay
	local sprTip = V(cx, 31, zt + 22)
	Props.Beam(m, V(cx, 20, zt - 6), sprTip, 1.6, 1.6, MAST, { Mat = WOOD })
	Props.Beam(m, tops[3], sprTip, 0.35, 0.35, ROPE)

	-- spectral figurehead
	Props.Beam(m, V(cx, 7, zt - 1), V(cx, 13.5, zt + 1.6), 3, 2.4, C(200, 240, 235), { Transp = 0.15 })
	Kit.Ball(m, 3.6, V(cx, 15.4, zt + 2), C(210, 245, 240), { Transp = 0.15 })
	Kit.Wedge(m, V(3.4, 4, 2), CFrame.new(cx, 14.5, zt + 0.6), C(150, 225, 220), { Transp = 0.15 })
	local heart = Kit.Ball(m, 1.6, V(cx, 11.6, zt + 2.2), SPECTRAL, { Mat = NEON })
	Kit.Light(heart, SPECTRAL, 28, 1.8)

	-- cannons and gun ports on the -X side
	for i = 0, 5 do
		local z = 1708 + i * 12
		Kit.Box(m, V(x0 - 0.25, 12.3, z - 1.6), V(x0 + 0.1, 15.3, z + 1.6), C(30, 25, 32))
		Kit.CylFlat(m, 6, 1.8, V(x0 - 2.6, 13.8, z), "X", IRON, { Mat = METAL })
	end
	-- glowing portholes with brass rims
	for i = 0, 7 do
		local z = 1680 + i * 12
		Kit.CylFlat(m, 0.3, 3.2, V(x0 - 0.15, 4.5, z), "X", Kit.Vivid(GOLD), { Mat = METAL })
		Kit.CylFlat(m, 0.2, 2.3, V(x0 - 0.38, 4.5, z), "X", SPECTRAL, { Mat = NEON })
	end
	-- spectral rune zigzag on the hull
	local runes = { V(x0 - 0.3, 0.8, 1690), V(x0 - 0.3, 7.6, 1700), V(x0 - 0.3, 1.2, 1712), V(x0 - 0.3, 7.2, 1724) }
	for i = 1, #runes - 1 do
		Props.Beam(m, runes[i], runes[i + 1], 0.35, 0.35, PURPLE, { Mat = NEON })
	end
	-- name board
	Props.SignBoard(m, V(x0 - 0.5, 13.8, 1690), 16, 3.2, -1, 0, "THE SALTY SPECTER", C(40, 30, 45), Kit.Vivid(GOLD), GOLD)

	-- green deck fog
	local fog = Kit.Part(m, V(30, 0.2, 70), CFrame.new(cx, 19, 1735), SPECTRAL, { Transp = 1, Name = "FogSource" })
	Kit.Emitter(fog, SPECTRAL, 2, 10, 0.3)

	-- mooring bollards with ropes up to the hull
	for _, z in { 1690, 1770 } do
		Kit.Cyl(m, 2.4, 2, CFrame.new(121, 1.2, z), IRON, { Mat = METAL, Solid = true }).CanCollide = false -- small prop: tappable/queryable but walk-through (solid ones snag players)
		Kit.Cyl(m, 0.6, 2.8, CFrame.new(121, 2.5, z), IRON, { Mat = METAL })
		Props.Beam(m, V(121, 2.2, z), V(x0 - 0.2, 16, z + 4), 0.4, 0.4, ROPE)
		Kit.AddCircle(121, z, 2)
	end
	Kit.AddRect(124, zs - 6, 140, zt + 4)
end

local function lighthouse(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Lighthouse")
	local white, red = C(248, 245, 238), Kit.Vivid(C(205, 60, 60))
	local rock = C(105, 112, 125)
	Kit.Disc(m, x, z, 1.5, 24, 2, rock, { Mat = ROCK, Solid = true })
	Kit.Ball(m, 9, V(x + 9, 0, z - 7), rock, { Mat = ROCK, Solid = true })
	Kit.Ball(m, 7, V(x - 7, 0, z + 9), rock, { Mat = ROCK, Solid = true })
	Kit.Ball(m, 6, V(x + 6, 0, z + 9), C(90, 100, 115), { Mat = ROCK })
	local seg = 12
	for i = 0, 5 do
		local d = 16 - i * 0.8
		Kit.Cyl(m, seg, d, CFrame.new(x, 1.5 + seg * i + seg / 2, z), if i % 2 == 0 then red else white, { Mat = Enum.Material.Plastic, Solid = true, Shadow = true })
	end
	-- door and windows on the side facing the boardwalk (-X)
	Kit.Box(m, V(x - 8.1, 1.5, z - 2.4), V(x - 7.4, 9, z + 2.4), PLANK_DARK, { Mat = WOOD })
	Kit.Box(m, V(x - 8.25, 8.6, z - 2.9), V(x - 7.4, 9.4, z + 2.9), Kit.Vivid(TEAL))
	for _, w in { { 1, 26 }, { 3, 50 } } do
		local r = (16 - w[1] * 0.8) / 2
		Kit.Box(m, V(x - r - 0.2, w[2] - 2, z - 1.2), V(x - r + 0.6, w[2] + 2, z + 1.2), C(55, 85, 120))
	end
	-- gallery + railing
	Kit.Disc(m, x, z, 75.5, 19, 1.5, IRON, { Mat = METAL })
	local posts: { Vector3 } = {}
	for i = 0, 5 do
		local a = i * math.pi / 3
		local p = V(x + math.cos(a) * 9, 75.5, z + math.sin(a) * 9)
		Kit.Box(m, p + V(-0.2, 0, -0.2), p + V(0.2, 3, 0.2), IRON, { Mat = METAL })
		table.insert(posts, p + V(0, 3, 0))
	end
	for i = 1, 6 do
		Props.Beam(m, posts[i], posts[(i % 6) + 1], 0.3, 0.3, red, { Mat = METAL })
	end
	-- lamp room: glass drum, warm lamp, frame
	Kit.Cyl(m, 8, 10, CFrame.new(x, 79.5, z), C(175, 230, 235), { Mat = Enum.Material.Glass, Transp = 0.5, Refl = 0.2 })
	local lamp = Kit.Ball(m, 4.5, V(x, 79.5, z), C(255, 225, 140), { Mat = NEON })
	Kit.Light(lamp, C(255, 215, 140), 60, 2.4)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local px, pz = x + math.cos(a) * 5, z + math.sin(a) * 5
		Kit.Box(m, V(px - 0.25, 75.5, pz - 0.25), V(px + 0.25, 83.6, pz + 0.25), IRON, { Mat = METAL })
	end
	-- roof
	Kit.Disc(m, x, z, 84.5, 12.5, 1, red)
	Kit.Cyl(m, 2, 9, CFrame.new(x, 85.5, z), red)
	Kit.Cyl(m, 2, 6, CFrame.new(x, 87.5, z), red)
	Kit.Cyl(m, 2, 3, CFrame.new(x, 89.5, z), red)
	Kit.Ball(m, 1.8, V(x, 91.2, z), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Cyl(m, 3, 0.3, CFrame.new(x, 93.5, z), IRON, { Mat = METAL })
	Kit.AddCircle(x, z, 14)
end

local function warehouse(f: Instance, z1: number, z2: number, wall: Color3, roof: Color3, text: string, flicker: boolean)
	local m = Kit.Model(f, "Warehouse")
	local xb, xf = -138, -112
	local h = 18
	local sol: Kit.Opts = { Mat = Enum.Material.Brick, Solid = true, Shadow = true }
	Kit.Box(m, V(xb, 0, z1), V(xb + 2, h, z2), wall, sol)
	Kit.Box(m, V(xb, 0, z1), V(xf, h, z1 + 2), wall, sol)
	Kit.Box(m, V(xb, 0, z2 - 2), V(xf, h, z2), wall, sol)
	for _, zz in { z1, z2 - 2 } do
		Kit.Box(m, V(xf - 0.6, 0, zz - 0.3), V(xf + 0.8, h + 0.4, zz + 2.3), PLANK_DARK, { Mat = WOOD, Solid = true })
	end
	local fascia = Kit.Box(m, V(xf - 1, h - 4, z1), V(xf + 0.6, h, z2), PLANK_DARK, { Mat = WOOD, Solid = true })
	Kit.Sign(fascia, Enum.NormalId.Right, text, Kit.Vivid(C(255, 225, 120)), { Stroke = C(30, 40, 60) })
	gable(m, CFrame.new((xb + xf) / 2, h, (z1 + z2) / 2) * CFrame.Angles(0, math.pi / 2, 0), z2 - z1 + 2, xf - xb + 4, 9, roof, Enum.Material.Slate)
	Kit.Box(m, V(xb + 2, 0, z1 + 2), V(xf, 0.06, z2 - 2), PLANK, { Mat = PLANKS })
	-- one ghostly window on the side wall that faces the gate
	Kit.Box(m, V(-130, 8, z1 - 0.25), V(-122, 12.5, z1 + 0.1), SPECTRAL, { Mat = NEON, Transp = 0.1 })
	-- stacked cargo inside
	local rng = Kit.Rng
	for zz = z1 + 6, z2 - 6, 7 do
		crate(m, V(-133.5, 0, zz), 5, rng:NextNumber(-0.1, 0.1))
		if rng:NextNumber() < 0.6 then
			crate(m, V(-133.5, 5, zz), 4.2, rng:NextNumber(-0.25, 0.25))
		end
	end
	barrel(m, V(-124, 0, z1 + 6), 4)
	barrel(m, V(-121, 0, z1 + 8.5), 4)
	-- hanging lantern at the front
	local lx, lz = xf + 1.6, (z1 + z2) / 2
	Kit.Box(m, V(lx - 0.15, h - 6, lz - 0.15), V(lx + 0.15, h - 4, lz + 0.15), IRON)
	local lamp = Kit.Box(m, V(lx - 0.8, h - 8, lz - 0.8), V(lx + 0.8, h - 6, lz + 0.8), WARM, if flicker then { Mat = NEON } else {})
	if flicker then
		Kit.Light(lamp, WARM, 22, 1.4, true)
	end
	Kit.AddRect(xb - 2, z1 - 1, xf + 3, z2 + 1)
end

local function hut(f: Instance, x: number, z: number, fx: number, col: Color3)
	local m = Kit.Model(f, "FishingHut")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, 0), 0)
	Kit.Part(m, V(10, 9, 9), base * CFrame.new(0, 4.5, 0), col, { Mat = PLANKS, Solid = true, Shadow = true })
	Kit.Wedge(m, V(12, 3, 11), base * CFrame.new(0, 10.5, 0), C(60, 80, 115), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Part(m, V(3, 6, 0.3), base * CFrame.new(-2, 3, -4.6), PLANK_DARK, { Mat = WOOD })
	Kit.Part(m, V(2.6, 2.2, 0.3), base * CFrame.new(2.4, 5.2, -4.6), C(255, 215, 120))
	Kit.Part(m, V(0.2, 5, 6), base * CFrame.new(5.1, 4.8, 0), C(200, 190, 160), { Mat = FABRIC, Transp = 0.45 })
	Kit.CylFlat(m, 0.5, 2.6, (base * CFrame.new(2.4, 2.4, -4.8)).Position, "X", Kit.Vivid(RED))
	Props.Beam(m, (base * CFrame.new(-4.5, 1, -4.8)).Position, (base * CFrame.new(-6, 9, -9)).Position, 0.25, 0.25, PLANK_DARK)
	Kit.AddCircle(x, z, 8)
end

local function treasure(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "TreasurePile")
	local gold = Kit.Vivid(GOLD)
	local mo: Kit.Opts = { Mat = METAL, Refl = 0.2 }
	Kit.Ball(m, 9, V(x, -2.2, z), gold, mo)
	Kit.Ball(m, 6, V(x + 4, -1.6, z - 3.5), gold, mo)
	-- chest
	local wood = C(135, 82, 48)
	Kit.Box(m, V(x - 3, 0, z + 2), V(x + 2.4, 3.2, z + 5.6), wood, { Mat = WOOD, Solid = true })
	Kit.CylFlat(m, 5.4, 3.6, V(x - 0.3, 3.2, z + 3.8), "X", wood, { Mat = WOOD })
	for _, bx in { -2.2, 1.6 } do
		Kit.Box(m, V(x + bx - 0.3, 0, z + 1.9), V(x + bx + 0.3, 5.1, z + 5.7), gold, { Mat = METAL })
	end
	Kit.Box(m, V(x - 0.8, 2.2, z + 1.8), V(x + 0.2, 3.4, z + 2), gold, { Mat = METAL })
	-- spilled coins, gems, a crown
	for i = 0, 3 do
		local a = i * 1.7
		Kit.Disc(m, x + math.cos(a) * 6, z + math.sin(a) * 6, 0.25, 1.8, 0.2, gold, mo)
	end
	for i, g in { C(230, 60, 90), C(60, 200, 210), C(170, 90, 240) } do
		Kit.Ball(m, 1.3, V(x - 2 + i * 1.4, 2.3 - i * 0.3, z - 1 + i * 0.6), Kit.Vivid(g), { Refl = 0.3 })
	end
	Kit.Cyl(m, 1.2, 2.6, CFrame.new(x + 0.4, 2.6, z - 0.4) * CFrame.Angles(0.2, 0, 0.15), gold, mo)
	Props.SignBoard(m, V(x - 6.5, 3, z - 4), 6, 2.4, -1, 0, "DO NOT TOUCH\n(CURSED)", C(245, 238, 220), Kit.Vivid(RED))
	Kit.Box(m, V(x - 6.65, 0, z - 4.2), V(x - 6.35, 1.8, z - 3.8), PLANK_DARK)
	Kit.AddCircle(x, z, 8)
end

local function anchor(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Anchor")
	local col = C(70, 95, 110)
	Kit.Disc(m, x, z, 0.6, 9, 0.6, C(90, 100, 115), { Mat = COBBLE, Solid = true })
	Kit.Box(m, V(x - 1, 0, z - 1), V(x + 1, 15, z + 1), col, { Mat = METAL, Solid = true })
	Kit.Box(m, V(x - 5, 12, z - 0.8), V(x + 5, 13.6, z + 0.8), col, { Mat = METAL })
	Kit.Ball(m, 2.6, V(x, 16.4, z), Kit.Vivid(TEAL), { Mat = METAL })
	for _, s in { -1, 1 } do
		Props.Beam(m, V(x, 1.2, z), V(x + s * 6, 5.5, z), 1.6, 1.6, col, { Mat = METAL })
		Kit.Ball(m, 2.8, V(x + s * 6.2, 5.8, z), col, { Mat = METAL })
	end
	Kit.AddCircle(x, z, 7)
end

--==================================================================
-- GHOST AREA PAINT (flat only)
--==================================================================
local function deckPads(f: Instance)
	local pads = { { 0, 1645, 30 }, { -82, 1680, 24 }, { 75, 1740, 26 }, { -62, 1800, 24 }, { 0, 1860, 24 } }
	for i, p in pads do
		local ring = if i % 2 == 0 then Kit.Vivid(TEAL) else Kit.Vivid(C(110, 90, 170))
		Kit.Disc(f, p[1], p[2], 0.07, p[3] * 2 + 4, 0.07, ring)
		Kit.Disc(f, p[1], p[2], 0.1, p[3] * 2, 0.1, if i % 2 == 0 then PLANK else C(150, 108, 72), { Mat = PLANKS })
	end
	-- boss: compass rose + spectral rune ring
	local bx, bz = 0, 1860
	local gold = Kit.Vivid(GOLD)
	for i = 0, 3 do
		local a = i * math.pi / 2
		Props.Beam(f, V(bx, 0.13, bz), V(bx + math.cos(a) * 18, 0.13, bz + math.sin(a) * 18), 2.6, 0.06, gold)
		local b = a + math.pi / 4
		Props.Beam(f, V(bx, 0.12, bz), V(bx + math.cos(b) * 11, 0.12, bz + math.sin(b) * 11), 1.8, 0.05, Kit.Vivid(TEAL))
	end
	Kit.Disc(f, bx, bz, 0.17, 5, 0.1, gold, { Mat = METAL })
	for i = 0, 7 do
		local a1 = i * math.pi / 4 + 0.12
		local a2 = a1 + math.pi / 4 - 0.24
		Props.Beam(f, V(bx + math.cos(a1) * 21, 0.14, bz + math.sin(a1) * 21), V(bx + math.cos(a2) * 21, 0.14, bz + math.sin(a2) * 21), 0.45, 0.06, SPECTRAL, { Mat = NEON })
	end
end

--==================================================================
-- BUILD
--==================================================================
function Harbor.Build(map: Instance)
	local f = Kit.Folder(map, "Harbor")
	local rng = Kit.Rng

	ground(f)
	sideWalls(f)
	deckPads(f)
	ship(f)
	lighthouse(f, 116, 1866)
	warehouse(f, 1596, 1636, C(160, 82, 70), C(55, 95, 130), "FISH & SHIPS", false)
	warehouse(f, 1716, 1764, C(90, 110, 140), C(140, 60, 60), "CARGO", true)
	warehouse(f, 1836, 1880, C(130, 95, 75), C(60, 110, 120), "DOCK 13", false)

	-- pier across the inlet with a fishing hut at its end
	Kit.Box(f, V(104, -0.5, 1617), V(140, 0.06, 1631), PLANK, { Mat = PLANKS, Solid = true, Name = "Pier" })
	for _, x in { 107, 117, 127 } do
		for _, z in { 1616.6, 1631.4 } do
			Kit.Cyl(f, 3.5, 1.2, CFrame.new(x, 1.25, z), PLANK_DARK, { Mat = WOOD })
		end
	end
	hut(f, 133, 1624, -1, C(110, 140, 160))
	if Kit.IsFree(122, 1578, 7) then
		hut(f, 122, 1578, -1, C(170, 110, 90))
	end
	if Kit.IsFree(-64, 1600, 7) then
		hut(f, -64, 1600, 1, C(120, 150, 125))
	end
	if Kit.IsFree(70, 1830, 7) then
		hut(f, 70, 1830, -1, C(150, 120, 170))
	end

	-- floating spectral lanterns over the inlet and drifting bottles by the treasure
	for _, p in { V(110, 3.6, 1606), V(122, 4.2, 1644), V(136, 3.8, 1608), V(112, 4.4, 1641) } do
		local l = Kit.Part(f, V(1.2, 1.7, 1.2), CFrame.new(p), C(170, 255, 200), { Mat = NEON, Name = "FloatingLantern" })
		Kit.Float(l, rng:NextNumber(0.5, 1))
	end
	for _, p in { V(108, 3.5, 1712), V(124, 3.2, 1736) } do
		local b = Kit.Cyl(f, 1.8, 0.9, CFrame.new(p) * CFrame.Angles(0.5, 0, 0.3), C(120, 200, 170), { Mat = Enum.Material.Glass, Transp = 0.3, Name = "FloatingBottle" })
		Kit.Float(b, rng:NextNumber(0.5, 0.9))
	end
	-- pale fog rolling off the inlet
	local fog = Kit.Part(f, V(30, 0.2, 40), CFrame.new(122, 0.6, 1625), C(200, 235, 240), { Transp = 1, Name = "FogSource" })
	Kit.Emitter(fog, C(200, 235, 240), 1.5, 9, 0.3)

	treasure(f, 114, 1722)
	for _, s in { -1, 1 } do
		if Kit.IsFree(s * 40, 1872, 6) then
			anchor(f, s * 40, 1872)
		end
	end

	-- signs
	do
		local x, z = -60, 1578
		for _, s in { -1, 1 } do
			Kit.Cyl(f, 15, 1.4, CFrame.new(x + s * 11, 7.5, z), PLANK_DARK, { Mat = WOOD, Solid = true })
		end
		Props.SignBoard(f, V(x, 12, z), 22, 6, 0, -1, "⚓ HARBOR ⚓", C(40, 70, 110), C(255, 235, 170), TEAL)
		Kit.AddCircle(x, z, 13)
	end
	if Kit.IsFree(18, 1698, 4) then
		Kit.Box(f, V(17.6, 0, 1698.2), V(18.4, 5, 1698.8), PLANK_DARK, { Mat = WOOD })
		Props.SignBoard(f, V(18, 6.5, 1698), 12, 5, 0, -1, "NO GHOSTS ALLOWED\n...OOPS", C(245, 240, 225), Kit.Vivid(RED), RED)
		Kit.AddCircle(18, 1698, 6)
	end

	-- harbour lamps along the boardwalk
	local lit = 0
	for z = 1590, 1900, 34 do
		for _, s in { -1, 1 } do
			local zz = z + (if s > 0 then 17 else 0)
			local x = s * 12.5
			if Kit.IsFree(x, zz, 1.2, true) then
				lit += 1
				Props.StreetLamp(f, V(x, 0, zz), WARM, lit == 1 or lit == 4 or lit == 7)
				Kit.AddCircle(x, zz, 1.5)
			end
		end
	end

	-- cargo: crate stacks, barrel groups, rope coils, scattered on free quay
	local stacks, barrels, coils = 0, 0, 0
	for _ = 1, 500 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(1572, 1908)
		if stacks < 16 and Kit.IsFree(x + 2.3, z, 5.5) then
			stacks += 1
			local yaw = rng:NextNumber(-0.3, 0.3)
			crate(f, V(x, 0, z), 4.5, yaw)
			crate(f, V(x + 4.6, 0, z + rng:NextNumber(-0.5, 0.5)), 4.5, yaw)
			if rng:NextNumber() < 0.6 then
				crate(f, V(x + 2.3, 4.5, z), 4, yaw + 0.2)
			end
			Kit.AddCircle(x + 2.3, z, 5.5)
		elseif barrels < 12 and Kit.IsFree(x + 1.4, z, 4) then
			barrels += 1
			barrel(f, V(x, 0, z), 4.2)
			barrel(f, V(x + 2.9, 0, z + 1), 4.2)
			if rng:NextNumber() < 0.5 then
				Kit.CylFlat(f, 4.2, 2.8, V(x + 1.4, 1.4, z - 2.6), "X", C(150, 100, 62), { Mat = WOOD })
			end
			Kit.AddCircle(x + 1.4, z, 4)
		elseif coils < 6 and Kit.IsFree(x, z, 2) then
			coils += 1
			Kit.Disc(f, x, z, 0.6, 3.6, 0.6, ROPE, { Mat = FABRIC })
			Kit.Disc(f, x, z, 0.65, 1.4, 0.1, PLANK_DARK)
			Kit.AddCircle(x, z, 2)
		end
	end

	-- a few spectral cracks in the quay
	for _ = 1, 4 do
		local p = V(rng:NextNumber(-120, 95), 0.13, rng:NextNumber(1600, 1890))
		local a = rng:NextNumber(0, math.pi * 2)
		Props.Beam(f, p, p + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(5, 9), 0.45, 0.06, SPECTRAL, { Mat = NEON })
	end
end

return Harbor
