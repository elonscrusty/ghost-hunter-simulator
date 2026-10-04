--!strict
-- ZONE 11: Pharaoh's Tomb (Z 3400..3760). A sunny desert temple: sand, gold and turquoise.
--   Ground: sand slab (top Y = 0). Main path along X = 0: sandstone paving (X -8..8, top 0.05)
--   with turquoise edges and terracotta seams.
--   Ghost areas hold flat paint only: a sun mosaic on the path (0, 3485), tiled circles, the
--   OASIS (flat turquoise water on solid sand) at (75, 3580) and the Pharaoh's seal with a big
--   painted eye around the boss (0, 3705).
--   Landmark: a huge step pyramid outside the +X wall (centre X 226, Z 3650, ~105 tall) with
--   its entrance facing the valley, and a smaller one outside the -X wall; both read from the
--   Frost zone.
--   Also: a colonnade of painted sandstone columns with lintels over the path (Z 3530..3600),
--   two pairs of obelisks, a cute sphinx-cat statue (-100, 3700) facing the path, palm trees
--   around the oasis, golden treasure piles, urns, broken columns and torches.
--   Side walls: sandstone with a terracotta cap and a painted hieroglyph band.
--   Outside: dunes and palms on open sand.
-- Glow: torch flames, the eye above the pyramid entrance and a few turquoise glints in the seal.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Tomb = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SAND = Enum.Material.Sand
local SANDSTONE = Enum.Material.Sandstone
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local GRASS = Enum.Material.Grass

local Z0, Z1 = 3400, 3760

local SANDC = C(238, 208, 150)
local SAND_DARK = C(222, 188, 128)
local STONE = C(224, 190, 132)
local STONE_DARK = C(196, 160, 106)
local PAVE = C(214, 178, 122)
local GOLD = C(255, 200, 60)
local TURQ = C(60, 200, 210)
local TERRA = C(206, 104, 70)
local LAPIS = C(50, 90, 190)
local FLAME = C(255, 160, 60)
local WATER = C(70, 200, 205)
local PALM = { C(70, 160, 70), C(90, 180, 80), C(60, 145, 85) }
local TRUNK = C(150, 110, 70)

local function rz(n: number): number
	return Z0 + n
end

--==================================================================
-- PROPS
--==================================================================
local function palm(parent: Instance, pos: Vector3, h: number)
	local rng = Kit.Rng
	local lean = rng:NextNumber(-1, 1)
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = V(math.cos(a), 0, math.sin(a))
	local pts = { pos, pos + V(0, h * 0.4, 0) + dir * lean * 0.6, pos + V(0, h * 0.75, 0) + dir * lean * 1.8, pos + V(0, h, 0) + dir * lean * 3.2 }
	for i = 1, 3 do
		Props.Beam(parent, pts[i], pts[i + 1], 1.9 - i * 0.2, 1.9 - i * 0.2, if i % 2 == 0 then TRUNK else TRUNK:Lerp(Color3.new(1, 1, 1), 0.12), { Mat = WOOD, Solid = i == 1, Shadow = true })
	end
	local top = pts[4]
	local col = Kit.Pick(PALM)
	for k = 0, 4 do
		local fa = k * math.pi * 2 / 5 + rng:NextNumber(-0.2, 0.2)
		local len = h * 0.42
		local tip = top + V(math.cos(fa) * len, -h * 0.14, math.sin(fa) * len)
		local mid = (top + tip) / 2 + V(0, 0.8, 0)
		Kit.Part(parent, V(2.6, 0.3, len + 1), CFrame.lookAt(mid, tip) * CFrame.Angles(0, 0, 0), col, { Mat = GRASS })
	end
	Kit.Ball(parent, 1.3, top + V(0.6, -0.9, 0.3), C(120, 80, 45))
	Kit.Ball(parent, 1.3, top + V(-0.5, -1, -0.4), C(120, 80, 45))
	Kit.AddCircle(pos.X, pos.Z, h * 0.42 + 3)
end

local function obelisk(parent: Instance, x: number, z: number, h: number)
	local m = Kit.Model(parent, "Obelisk")
	Kit.Box(m, V(x - 3.5, 0, z - 3.5), V(x + 3.5, 1.6, z + 3.5), STONE_DARK, { Mat = SANDSTONE, Solid = true })
	Kit.Box(m, V(x - 2.2, 1.6, z - 2.2), V(x + 2.2, h * 0.55, z + 2.2), STONE, { Mat = SANDSTONE, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 1.8, h * 0.55, z - 1.8), V(x + 1.8, h, z + 1.8), STONE, { Mat = SANDSTONE, Shadow = true })
	Kit.Part(m, V(2.6, 2.6, 2.6), CFrame.new(x, h + 0.3, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), Kit.Vivid(GOLD), { Mat = METAL, Refl = 0.2 })
	-- painted hieroglyph band
	Kit.Box(m, V(x - 2.3, h * 0.3, z - 2.3), V(x + 2.3, h * 0.3 + 1, z + 2.3), Kit.Vivid(TURQ))
	local panel = Kit.Box(m, V(x - 1.6, h * 0.36, z - 2.35), V(x + 1.6, h * 0.5, z - 2.25), Kit.Vivid(TERRA))
	Kit.Sign(panel, Enum.NormalId.Front, "☥\n👁\n☀", C(255, 245, 210), { Stroke = C(90, 40, 20) })
	Kit.AddCircle(x, z, 4.5)
end

local function column(parent: Instance, x: number, z: number, h: number)
	Kit.Box(parent, V(x - 2.6, 0, z - 2.6), V(x + 2.6, 1.4, z + 2.6), STONE_DARK, { Mat = SANDSTONE, Solid = true })
	Kit.Cyl(parent, h - 3.4, 3.6, CFrame.new(x, 1.4 + (h - 3.4) / 2, z), STONE, { Mat = SANDSTONE, Solid = true, Shadow = true })
	Kit.Cyl(parent, 1.2, 3.9, CFrame.new(x, h * 0.62, z), Kit.Vivid(TURQ))
	Kit.Cyl(parent, 0.6, 3.9, CFrame.new(x, h * 0.62 + 1.2, z), Kit.Vivid(TERRA))
	Kit.Box(parent, V(x - 2.8, h - 2, z - 2.8), V(x + 2.8, h, z + 2.8), STONE_DARK, { Mat = SANDSTONE })
end

local function torch(parent: Instance, x: number, z: number, lit: boolean, flicker: boolean)
	Kit.Box(parent, V(x - 0.5, 0, z - 0.5), V(x + 0.5, 6, z + 0.5), STONE_DARK, { Mat = SANDSTONE })
	Kit.Cyl(parent, 1.2, 2.4, CFrame.new(x, 6.6, z), Kit.Vivid(GOLD), { Mat = METAL })
	local flame = Kit.Part(parent, V(1.3, 1.3, 1.3), CFrame.new(x, 7.6, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), FLAME, { Mat = NEON })
	if lit then
		Kit.Light(flame, C(255, 180, 90), 22, 1.5, flicker)
	end
end

local function urn(parent: Instance, x: number, z: number, s: number)
	local col = if Kit.Rng:NextNumber() < 0.5 then TERRA else C(190, 120, 70)
	Kit.Ball(parent, 2.4 * s, V(x, 1.2 * s, z), col, { Solid = true }).CanCollide = false -- small prop: tappable/queryable but walk-through (solid ones snag players)
	Kit.Cyl(parent, 1.1 * s, 1.1 * s, CFrame.new(x, 2.6 * s, z), col)
	Kit.Cyl(parent, 0.3 * s, 1.5 * s, CFrame.new(x, 3.2 * s, z), Kit.Vivid(TURQ))
end

local function treasure(parent: Instance, x: number, z: number, sparkle: boolean)
	local m = Kit.Model(parent, "Treasure")
	local gold = Kit.Vivid(GOLD)
	local mo: Kit.Opts = { Mat = METAL, Refl = 0.25 }
	Kit.Ball(m, 9, V(x, -2.2, z), gold, mo)
	Kit.Ball(m, 6, V(x + 4, -1.6, z - 3.5), gold, mo)
	Kit.Ball(m, 5, V(x - 4, -1.4, z + 3), gold, mo)
	-- chest
	local wood = C(150, 90, 50)
	Kit.Box(m, V(x - 2.7, 0, z + 2), V(x + 2.7, 3, z + 5.4), wood, { Mat = WOOD, Solid = true })
	Kit.CylFlat(m, 5.4, 3.4, V(x, 3, z + 3.7), "X", wood, { Mat = WOOD })
	Kit.Box(m, V(x - 2.9, 1.4, z + 1.9), V(x + 2.9, 2, z + 5.5), gold, { Mat = METAL })
	-- gems, a golden mask and coins
	for i, g in { C(230, 60, 90), TURQ, C(170, 90, 240) } do
		Kit.Part(m, V(1.2, 1.2, 1.2), CFrame.new(x - 2.5 + i * 1.3, 2.3 - i * 0.3, z - 1 + i * 0.5) * CFrame.Angles(0.6, 0.4, 0.6), Kit.Vivid(g), { Refl = 0.3 })
	end
	Kit.Part(m, V(2.6, 3.2, 0.8), CFrame.new(x + 1.5, 3, z - 1.2) * CFrame.Angles(-0.4, 0.3, 0), gold, mo)
	for i = 0, 2 do
		local a = i * 2.1
		Kit.Disc(m, x + math.cos(a) * 6, z + math.sin(a) * 6, 0.2, 1.8, 0.2, gold, mo)
	end
	if sparkle then
		local src = Kit.Part(m, V(8, 1, 8), CFrame.new(x, 3, z), gold, { Transp = 1, Name = "SparkleSource" })
		local e = Kit.Emitter(src, C(255, 230, 120), 3, 0.6, 1.2)
		if e then
			e.Size = NumberSequence.new(0.5)
			e.Lifetime = NumberRange.new(1.5, 3)
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		end
		Kit.Light(src, C(255, 210, 120), 18, 1)
	end
	Kit.AddCircle(x, z, 7.5)
end

-- Cute sphinx-cat lying on a plinth, facing (fx, 0).
local function sphinxCat(parent: Instance, x: number, z: number, fx: number)
	local m = Kit.Model(parent, "SphinxCat")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, 0), 0)
	local stone: Kit.Opts = { Mat = SANDSTONE, Solid = true, Shadow = true }
	local fur = C(232, 198, 140)
	Kit.Part(m, V(18, 4, 36), base * CFrame.new(0, 2, 0), STONE_DARK, stone)
	Kit.Part(m, V(18.4, 1, 36.4), base * CFrame.new(0, 3.2, 0), Kit.Vivid(TURQ), { Mat = SANDSTONE })
	-- body, haunch, paws
	Kit.Part(m, V(12, 9, 22), base * CFrame.new(0, 8.5, 3), fur, stone)
	Kit.Ball(m, 12, (base * CFrame.new(0, 9, 12)).Position, fur, stone)
	for _, s in { -1, 1 } do
		Kit.Part(m, V(3.6, 3, 11), base * CFrame.new(s * 3.6, 5.5, -11), fur, stone)
		Kit.Ball(m, 3.8, (base * CFrame.new(s * 3.6, 5.6, -16.4)).Position, fur, { Mat = SANDSTONE })
	end
	-- head with nemes headdress
	local head = base * CFrame.new(0, 17, -8)
	Kit.Part(m, V(10, 9, 9), head, fur, stone)
	for _, s in { -1, 1 } do
		Kit.Wedge(m, V(1.6, 4, 3.4), head * CFrame.new(s * 3.2, 6.4, 0.5) * CFrame.Angles(0, math.pi, 0), fur, { Mat = SANDSTONE })
		-- striped headdress flaps
		Kit.Part(m, V(1.6, 10, 5), head * CFrame.new(s * 5.6, -1.5, 1.5), Kit.Vivid(LAPIS), { Mat = SANDSTONE })
		Kit.Part(m, V(1.8, 1.4, 5.2), head * CFrame.new(s * 5.6, 0.5, 1.5), Kit.Vivid(GOLD), { Mat = METAL })
		Kit.Part(m, V(1.8, 1.4, 5.2), head * CFrame.new(s * 5.6, -3.5, 1.5), Kit.Vivid(GOLD), { Mat = METAL })
		-- big friendly eyes
		Kit.Part(m, V(2.2, 2.6, 0.4), head * CFrame.new(s * 2.4, 1, -4.6), Kit.Vivid(TURQ))
		Kit.Part(m, V(0.9, 1.6, 0.3), head * CFrame.new(s * 2.4, 1, -4.85), C(30, 30, 45))
	end
	Kit.Part(m, V(10.4, 1.4, 9.4), head * CFrame.new(0, 3.6, 0), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Part(m, V(1.4, 0.9, 0.4), head * CFrame.new(0, -1.2, -4.6), Kit.Vivid(C(255, 140, 170)))
	-- gold collar and a curled tail
	Kit.Part(m, V(12.4, 1.6, 2), base * CFrame.new(0, 12.5, -6.4), Kit.Vivid(GOLD), { Mat = METAL })
	Props.Beam(m, (base * CFrame.new(5, 4.5, 16)).Position, (base * CFrame.new(8, 4.5, 6)).Position, 1.6, 1.6, fur, { Mat = SANDSTONE })
	Props.Beam(m, (base * CFrame.new(8, 4.5, 6)).Position, (base * CFrame.new(7.5, 6.5, 1)).Position, 1.6, 1.6, fur, { Mat = SANDSTONE })
	Kit.AddCircle(x, z, 20)
end

-- Step pyramid centred at (x, z); entrance on the face toward (ex, 0).
local function pyramid(parent: Instance, x: number, z: number, base: number, tiers: number, tierH: number, ex: number, entrance: boolean)
	local m = Kit.Model(parent, "Pyramid")
	for i = 0, tiers - 1 do
		local s = base * (1 - i / tiers)
		Kit.Box(m, V(x - s / 2, i * tierH - (if i == 0 then 2 else 0), z - s / 2), V(x + s / 2, (i + 1) * tierH, z + s / 2), if i % 2 == 0 then STONE else SAND_DARK, { Mat = SANDSTONE, Shadow = true })
	end
	local topY = tiers * tierH
	local cap = base / tiers
	Kit.Part(m, V(cap * 0.9, cap * 0.9, cap * 0.9), CFrame.new(x, topY + cap * 0.1, z) * CFrame.Angles(0, math.pi / 4, 0) * CFrame.Angles(math.pi / 4, 0, 0), Kit.Vivid(GOLD), { Mat = METAL, Refl = 0.3 })
	-- a painted band around the second tier
	local s2 = base * (1 - 1 / tiers)
	Kit.Box(m, V(x - s2 / 2 - 0.2, tierH * 1.4, z - s2 / 2 - 0.2), V(x + s2 / 2 + 0.2, tierH * 1.4 + 1.5, z + s2 / 2 + 0.2), Kit.Vivid(TURQ))
	if entrance then
		-- pylon facade on the face toward the valley: posts, tall lintel with a painted band and
		-- a glowing eye, a dark doorway, torches either side
		local back = x + ex * base / 2 -- the pyramid face
		local front = back + ex * 3 -- the facade's outer face
		local function slab(x1: number, x2: number, y1: number, y2: number, z1: number, z2: number, col: Color3, opts: Kit.Opts?): Part
			return Kit.Box(m, V(x1, y1, z1), V(x2, y2, z2), col, opts)
		end
		local sand: Kit.Opts = { Mat = SANDSTONE }
		slab(front, back, 0, 30, z - 13, z - 9, STONE_DARK, sand)
		slab(front, back, 0, 30, z + 9, z + 13, STONE_DARK, sand)
		slab(front, back, 30, 42, z - 15, z + 15, Kit.Vivid(TERRA), sand)
		slab(back - ex * 0.2, back + ex * 0.3, 0, 30, z - 9, z + 9, C(45, 35, 40))
		local band = slab(front + ex * 0.1, front, 30.8, 34.4, z - 13, z + 13, Kit.Vivid(LAPIS))
		Kit.Sign(band, if ex < 0 then Enum.NormalId.Left else Enum.NormalId.Right, "☥ 👁 ☀ 🐍 ☥", C(255, 240, 200), { Stroke = C(30, 30, 60) })
		local eye = slab(front + ex * 0.3, front, 35.4, 40.4, z - 5, z + 5, Kit.Vivid(TURQ), { Mat = NEON })
		slab(front + ex * 0.4, front, 36.6, 39.2, z - 1.5, z + 1.5, C(30, 30, 50))
		Kit.Light(eye, TURQ, 45, 1.6)
		for _, sz in { -1, 1 } do
			Kit.Cyl(m, 14, 2.6, CFrame.new(front + ex * 1.6, 7, z + sz * 17), STONE, sand)
			Kit.Part(m, V(1.6, 1.6, 1.6), CFrame.new(front + ex * 1.6, 14.8, z + sz * 17) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), FLAME, { Mat = NEON })
		end
		local dust = Kit.Part(m, V(4, 20, 18), CFrame.new(front + ex * 2, 12, z), C(255, 220, 160), { Transp = 1, Name = "DustSource" })
		Kit.Emitter(dust, C(255, 225, 170), 1.2, 6, 0.4)
	end
end

--==================================================================
-- GROUND, PATH, WALLS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), SANDC, { Mat = SAND, Solid = true, Name = "Ground_Tomb" })
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), PAVE, { Mat = SANDSTONE, Solid = true, Name = "TempleRoad" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8 - 0.6, 0.05, Z0), V(s * 8 + 0.6, 0.1, Z1), Kit.Vivid(TURQ))
	end
	for z = Z0 + 12, Z1 - 10, 16 do
		Kit.Box(f, V(-7.4, 0.05, z), V(7.4, 0.07, z + 0.5), Kit.Vivid(TERRA))
	end
	-- wind ripples in the sand (flat shading)
	local rng = Kit.Rng
	for _ = 1, 8 do
		local x = rng:NextNumber(-125, 125)
		local z = rng:NextNumber(Z0 + 30, Z1 - 30)
		if math.abs(x) > 22 then
			Kit.Part(f, V(rng:NextNumber(16, 28), 0.03, rng:NextNumber(8, 16)), CFrame.new(x, 0.015, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), SAND_DARK, { Mat = SAND })
		end
	end
end

local function sideWalls(f: Instance)
	local zA, zB = Z0 + 3, Z1 - 3
	local glyphs = { "☥  👁  ☀", "🐍  ☥  🐈", "☀  🪲  ☥", "👁  ☥  🐍", "🐈  ☀  ☥" }
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, 0, zA), V(s * 146, 12, zB), STONE, { Mat = SANDSTONE, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.5, 12, zA), V(s * 146.5, 13.2, zB), Kit.Vivid(TERRA), { Mat = SANDSTONE })
		Kit.Box(f, V(s * 139.9, 7.6, zA), V(s * 139.7, 9.6, zB), Kit.Vivid(TURQ))
		Kit.Box(f, V(s * 139.9, 9.6, zA), V(s * 139.7, 10.2, zB), Kit.Vivid(GOLD))
		for i, z in { rz(40), rz(110), rz(180), rz(250), rz(320) } do
			local p = Kit.Box(f, V(s * 139.95, 2.5, z - 9), V(s * 139.65, 7, z + 9), Kit.Vivid(if i % 2 == 0 then TERRA else LAPIS))
			Kit.Sign(p, if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left, glyphs[i], C(255, 240, 200), { Stroke = C(70, 40, 20) })
		end
		for z = zA + 20, zB - 10, 48 do
			Kit.Box(f, V(s * 139, 0, z - 2.5), V(s * 147, 15, z + 2.5), STONE_DARK, { Mat = SANDSTONE, Solid = true })
			Kit.Ball(f, 3, V(s * 143, 16.4, z), Kit.Vivid(TURQ))
		end
	end
end

--==================================================================
-- GHOST AREA PAINT (flat only)
--==================================================================
local function ghostPaint(f: Instance)
	-- mummy spirits: sun mosaic across the road
	local cz = rz(85)
	Kit.Disc(f, 0, cz, 0.04, 64, 0.03, Kit.Vivid(TERRA), { Mat = SANDSTONE })
	Kit.Disc(f, 0, cz, 0.07, 60, 0.03, PAVE, { Mat = SANDSTONE })
	Kit.Disc(f, 0, cz, 0.1, 14, 0.03, Kit.Vivid(GOLD))
	for i = 0, 7 do
		local a = i * math.pi / 4
		Props.Beam(f, V(math.cos(a) * 7, 0.1, cz + math.sin(a) * 7), V(math.cos(a) * 17, 0.1, cz + math.sin(a) * 17), 2.2, 0.04, Kit.Vivid(GOLD))
		local b = a + math.pi / 8
		Kit.Part(f, V(2.4, 0.04, 2.4), CFrame.new(math.cos(b) * 23, 0.1, cz + math.sin(b) * 23) * CFrame.Angles(0, b + math.pi / 4, 0), Kit.Vivid(TURQ))
	end
	-- tiled circles
	for _, a in { { -82, rz(120), 24 }, { -62, rz(240), 24 } } do
		Kit.Disc(f, a[1], a[2], 0.04, a[3] * 2 + 3, 0.03, Kit.Vivid(TURQ))
		Kit.Disc(f, a[1], a[2], 0.07, a[3] * 2, 0.03, PAVE, { Mat = SANDSTONE })
		Kit.Disc(f, a[1], a[2], 0.1, 10, 0.03, Kit.Vivid(TERRA))
	end
	-- the oasis: turquoise water lying flat on the sand, grass rim
	local ox, oz = 75, rz(180)
	Kit.Disc(f, ox, oz, 0.04, 54, 0.03, C(120, 190, 90), { Mat = GRASS })
	Kit.Disc(f, ox, oz, 0.1, 42, 0.06, WATER, { Transp = 0.2, Refl = 0.2, Name = "Oasis" })
	for _, l in { { 68, rz(174), 4 }, { 84, rz(186), 3.4 }, { 78, rz(166), 3 } } do
		Kit.Disc(f, l[1], l[2], 0.14, l[3], 0.03, Kit.Vivid(C(90, 180, 80)))
	end
	-- boss: the Pharaoh's seal with a big painted eye
	local bz = rz(305)
	Kit.Disc(f, 0, bz, 0.04, 58, 0.03, Kit.Vivid(TERRA), { Mat = SANDSTONE })
	Kit.Disc(f, 0, bz, 0.06, 54, 0.03, Kit.Vivid(GOLD))
	Kit.Disc(f, 0, bz, 0.08, 50, 0.03, PAVE, { Mat = SANDSTONE })
	Kit.Part(f, V(26, 0.04, 12), CFrame.new(0, 0.1, bz), C(250, 245, 230))
	Kit.Disc(f, 0, bz, 0.13, 9, 0.04, Kit.Vivid(TURQ))
	Kit.Disc(f, 0, bz, 0.15, 4, 0.04, C(30, 30, 50))
	Props.Beam(f, V(-13, 0.13, bz - 8), V(13, 0.13, bz - 8), 1.6, 0.04, Kit.Vivid(LAPIS))
	Props.Beam(f, V(-2, 0.13, bz + 6), V(-5, 0.13, bz + 15), 1.4, 0.04, Kit.Vivid(LAPIS))
	Props.Beam(f, V(6, 0.13, bz + 6), V(12, 0.13, bz + 13), 1.4, 0.04, Kit.Vivid(LAPIS))
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		Kit.Part(f, V(1.8, 0.05, 1.8), CFrame.new(math.cos(a) * 22, 0.12, bz + math.sin(a) * 22) * CFrame.Angles(0, math.pi / 4, 0), TURQ, { Mat = NEON })
	end
end

--==================================================================
-- OUTSIDE
--==================================================================
local function outside(f: Instance)
	local rng = Kit.Rng
	local o = Kit.Folder(f, "Desert")
	for _, s in { -1, 1 } do
		Kit.Box(o, V(s * 190, -3, Z0), V(s * 420, -0.2, Z1), SANDC, { Mat = SAND })
		-- dunes
		for i = 0, 4 do
			local x = s * rng:NextNumber(165, 330)
			local z = Z0 + 30 + i * 75 + rng:NextNumber(-15, 15)
			local d = rng:NextNumber(50, 90)
			if not (s > 0 and z > rz(160) and z < rz(340) and math.abs(x) < 310) then
				Kit.Ball(o, d, V(x, -d * 0.36, z), if i % 2 == 0 then SANDC else SAND_DARK, { Mat = SAND })
			end
		end
		-- palms just beyond the wall
		for i = 0, 3 do
			local z = Z0 + 30 + i * 95 + rng:NextNumber(-10, 10)
			if not (s > 0 and z > rz(150) and z < rz(345)) then
				palm(o, V(s * rng:NextNumber(152, 175), 0, z), rng:NextNumber(18, 26))
			end
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function Tomb.Build(map: Instance)
	local f = Kit.Folder(map, "Tomb")
	local rng = Kit.Rng

	ground(f)
	sideWalls(f)
	ghostPaint(f)
	pyramid(f, 226, rz(250), 150, 9, 11.5, -1, true)
	pyramid(f, -222, rz(110), 110, 7, 10, 1, false)
	sphinxCat(f, -100, rz(300), 1)
	treasure(f, 118, rz(262), true)
	treasure(f, 112, rz(56), false)
	treasure(f, -120, rz(232), false)

	-- obelisks: entrance pair and boss pair
	for _, s in { -1, 1 } do
		obelisk(f, s * 16, rz(48), 38)
		obelisk(f, s * 36, rz(268), 44)
	end

	-- colonnade along the road with painted lintels
	local glyphs = { "☥ 👁 ☀ 🐍 ☥", "🐈 ☀ ☥ 👁 🐈", "☀ ☥ 🪲 ☥ ☀", "👁 🐍 ☥ 🐈 👁" }
	for i, z in { rz(130), rz(152), rz(174), rz(196) } do
		for _, s in { -1, 1 } do
			column(f, s * 16, z, 20)
			Kit.AddCircle(s * 16, z, 3.5)
		end
		local lintel = Kit.Box(f, V(-19, 20, z - 2.4), V(19, 23, z + 2.4), STONE, { Mat = SANDSTONE, Shadow = true })
		Kit.Box(f, V(-19.1, 20.6, z - 2.5), V(19.1, 22.4, z - 2.42), Kit.Vivid(LAPIS))
		Kit.Sign(lintel, Enum.NormalId.Front, glyphs[i], C(255, 230, 150), { Stroke = C(60, 30, 20) })
	end

	-- welcome sign
	do
		local x, z = -62, rz(14)
		for _, s in { -1, 1 } do
			Kit.Box(f, V(x + s * 10 - 0.8, 0, z - 0.8), V(x + s * 10 + 0.8, 13, z + 0.8), STONE_DARK, { Mat = SANDSTONE, Solid = true })
		end
		Props.SignBoard(f, V(x, 10, z), 20, 5.5, 0, -1, "☥ PHARAOH'S TOMB ☥", Kit.Vivid(LAPIS), C(255, 220, 110), GOLD)
		Kit.AddCircle(x, z, 12)
	end

	-- torches along the road (three lit, one flickers)
	local n = 0
	for z = Z0 + 40, Z1 - 30, 40 do
		for _, s in { -1, 1 } do
			local zz = z + (if s > 0 then 20 else 0)
			local x = s * 12.5
			if zz < Z1 - 26 and Kit.IsFree(x, zz, 1.2, true) then
				n += 1
				torch(f, x, zz, n == 2 or n == 6 or n == 9, n == 6)
				Kit.AddCircle(x, zz, 1.5)
			end
		end
	end

	-- palms around the oasis, then elsewhere
	local palms = 0
	for k = 0, 11 do
		local a = k * math.pi / 6
		local x, z = 75 + math.cos(a) * 40, rz(180) + math.sin(a) * 40
		if palms < 6 and Kit.IsFree(x, z, 12) then
			palms += 1
			palm(f, V(x, 0, z), rng:NextNumber(18, 20))
		end
	end
	for _ = 1, 400 do
		if palms >= 13 then
			break
		end
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 30, Z1 - 30)
		local h = rng:NextNumber(18, 26)
		if Kit.IsFree(x, z, h * 0.42 + 3.5) then
			palms += 1
			palm(f, V(x, 0, z), h)
		end
	end

	-- urns and broken columns
	local urns, stumps = 0, 0
	for _ = 1, 600 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(Z0 + 28, Z1 - 28)
		if urns < 9 and Kit.IsFree(x, z, 2.5) then
			urns += 1
			urn(f, x, z, rng:NextNumber(1, 1.5))
			if rng:NextNumber() < 0.5 then
				urn(f, x + 2.4, z + 1, 0.8)
			end
			Kit.AddCircle(x, z, 3)
		elseif stumps < 6 and Kit.IsFree(x, z, 4) then
			stumps += 1
			local h = rng:NextNumber(3, 8)
			Kit.Cyl(f, h, 3.6, CFrame.new(x, h / 2, z), STONE, { Mat = SANDSTONE, Solid = true })
			Kit.Part(f, V(7, 3.4, 3.4), CFrame.new(x + 3.5, 1.7, z + 1) * CFrame.Angles(0, 0.6, 0), STONE_DARK, { Mat = SANDSTONE, Shape = Enum.PartType.Cylinder })
			Kit.AddCircle(x, z, 5)
		end
	end

	-- floating gems near the treasure and the pyramid entrance
	for _, p in { V(108, 8, rz(250)), V(126, 10, rz(274)), V(124, 7, rz(46)), V(-128, 9, rz(222)), V(130, 12, rz(300)) } do
		local g = Kit.Part(f, V(1.4, 1.4, 1.4), CFrame.new(p) * CFrame.Angles(0.6, 0.3, 0.6), Kit.Vivid(Kit.Pick({ TURQ, C(230, 60, 90), C(170, 90, 240), GOLD })), { Refl = 0.3, Name = "FloatingGem" })
		Kit.Float(g, rng:NextNumber(0.6, 1.2))
	end

	outside(f)
end

return Tomb
