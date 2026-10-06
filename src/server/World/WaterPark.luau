--!strict
-- ZONE 21: Haunted Water Park (Z 8440..8800). A summer water park after closing time: cream pool
-- deck tiles, bright pool-blue water, striped cabanas, palm trees and tall twisting slides.
--   Water is always flat: translucent blue parts on the ground (top <= 0.12) over the solid deck,
--   so every pool can be walked across; the rubber-mat lane along X = 0 stays dry.
--   Ghost areas are flat splash pads ((0,8525) r30, (-82,8560) r24, (75,8620) r26,
--   (-62,8680) r24); the boss area (0,8745) r26 is a round, flat "cannonball" pool.
--   Front left: the wave pool (beach entry toward the lane, wave machine house at the far end,
--   inflatable rings). Front right: the lazy river loop round a palm island. Back left: the
--   spiral slide tower (helix tube + a long snaking tube into a splash pool). Back right: the
--   speed-slide tower (two open flumes and a twisting tube). An entrance arch over the lane,
--   lifeguard towers, cabanas, loungers and umbrellas, a snack shack, floating beach balls.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local WaterPark = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local TILES = Enum.Material.CeramicTiles
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local WOOD = Enum.Material.Wood

local Z0, Z1 = 8440, 8800

local DECK = C(214, 208, 192)
local DECK_D = C(176, 170, 156)
local COPING = C(245, 245, 240)
local POOL = C(60, 170, 235)
local POOL_D = C(36, 120, 205)
local MAT = C(50, 160, 170)
local WHITE = C(250, 250, 248)
local ORANGE = C(255, 140, 50)
local YELLOW = C(255, 215, 70)
local PURPLE = C(150, 90, 220)
local LIME = C(130, 210, 70)
local PINK = C(255, 110, 160)
local RED = C(225, 60, 60)
local STEEL = C(200, 205, 215)
local TEAL = C(40, 170, 190)
local SAND = C(230, 205, 150)
local TRUNK = C(130, 95, 65)
local FROND = C(60, 150, 80)
local DARK = C(30, 34, 44)
local LAMP = C(190, 240, 255)

local WATER: Kit.Opts = { Transp = 0.3, Refl = 0.15, Name = "Water" }
local METAL_O: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
-- Cylinder between two points.
local function rod(parent: Instance, a: Vector3, b: Vector3, d: number, color: Color3, opts: Kit.Opts?): Part
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local o: Kit.Opts = { Shape = Enum.PartType.Cylinder, Mat = if opts then opts.Mat else nil, Transp = if opts then opts.Transp else nil }
	return Kit.Part(parent, V(len + d * 0.3, d, d), cf, color, o)
end

-- Flat pool: water box with a low coping rim (all tops <= 0.25).
local function pool(parent: Instance, x1: number, z1: number, x2: number, z2: number, col: Color3)
	Kit.Box(parent, V(x1, 0, z1), V(x2, 0.1, z2), col, WATER)
	local r = 1.4
	Kit.Box(parent, V(x1 - r, 0, z1 - r), V(x2 + r, 0.22, z1), COPING)
	Kit.Box(parent, V(x1 - r, 0, z2), V(x2 + r, 0.22, z2 + r), COPING)
	Kit.Box(parent, V(x1 - r, 0, z1), V(x1, 0.22, z2), COPING)
	Kit.Box(parent, V(x2, 0, z1), V(x2 + r, 0.22, z2), COPING)
end

-- Inflatable swim ring lying on the water (6 segments).
local function ring(parent: Instance, x: number, z: number, d: number, a: Color3, b: Color3)
	local n = 6
	local r = d / 2
	local seg = 2 * math.pi * r / n * 1.05
	for k = 0, n - 1 do
		local ang = (k + 0.5) * 2 * math.pi / n
		Kit.Part(parent, V(seg, d * 0.28, d * 0.28), CFrame.new(x + math.cos(ang) * r, 0.25 + d * 0.1, z + math.sin(ang) * r) * CFrame.Angles(0, -ang + math.pi / 2, 0), if k % 2 == 0 then a else b, { Mat = Enum.Material.Rubber })
	end
end

local function palm(parent: Instance, x: number, z: number, h: number, lean: number)
	local m = Kit.Model(parent, "Palm")
	local pts = { V(x, 0, z) }
	for i = 1, 3 do
		local t = i / 3
		table.insert(pts, V(x + lean * t * t * 4, h * t, z + lean * t * t * 1.5))
	end
	for i = 1, 3 do
		Props.Beam(m, pts[i], pts[i + 1], 1.5 - i * 0.15, 1.5 - i * 0.15, TRUNK, { Mat = WOOD, Solid = i == 1 })
	end
	local top = pts[4]
	for k = 0, 4 do
		local a = k * math.pi * 0.4 + lean * 0.3
		local tip = top + V(math.cos(a) * 7, -2.5, math.sin(a) * 7)
		Props.Beam(m, top, tip, 2.6, 0.25, if k % 2 == 0 then FROND else Kit.Vivid(FROND), { Mat = Enum.Material.LeafyGrass })
	end
	Kit.Ball(m, 1.4, top + V(0.6, -0.8, 0), C(110, 80, 50))
	Kit.AddCircle(x, z, 2.5)
end

local function umbrella(parent: Instance, x: number, z: number, col: Color3)
	Kit.Box(parent, V(x - 0.15, 0, z - 0.15), V(x + 0.15, 7.5, z + 0.15), WHITE, METAL_O)
	for k = 0, 5 do
		local a = k * math.pi / 3
		Kit.Wedge(parent, V(3.4, 1.2, 3.2), CFrame.new(x + math.cos(a) * 1.6, 7.4, z + math.sin(a) * 1.6) * CFrame.Angles(0, -a - math.pi / 2, 0), if k % 2 == 0 then col else WHITE, { Mat = FABRIC })
	end
	Kit.Ball(parent, 0.5, V(x, 8.1, z), WHITE)
end

local function lounger(parent: Instance, x: number, z: number, yaw: number, col: Color3)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(parent, V(2.2, 0.4, 5), cf * CFrame.new(0, 1.2, 0.6), col, { Mat = FABRIC, Solid = true })
	Kit.Part(parent, V(2.2, 0.4, 2.4), cf * CFrame.new(0, 2, -2.6) * CFrame.Angles(-0.7, 0, 0), col, { Mat = FABRIC })
	for _, sx in { -0.9, 0.9 } do
		Kit.Part(parent, V(0.2, 1, 5.6), cf * CFrame.new(sx, 0.6, 0), WHITE, METAL_O)
	end
end

local function lifeguard(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "LifeguardTower")
	local yaw = Kit.FaceYaw(fx, fz)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	for _, c in { { -1.6, -1.6 }, { 1.6, -1.6 }, { 1.6, 1.6 }, { -1.6, 1.6 } } do
		Kit.Part(m, V(0.4, 8, 0.4), base * CFrame.new(c[1], 4, c[2]), WHITE, { Mat = WOOD, Solid = true })
	end
	Kit.Part(m, V(4.4, 0.5, 4.4), base * CFrame.new(0, 8, 0), RED, { Mat = WOOD })
	Kit.Part(m, V(3, 2.2, 0.4), base * CFrame.new(0, 9.4, 1.4), RED, { Mat = WOOD })
	Kit.Part(m, V(3, 0.5, 1.6), base * CFrame.new(0, 9, 0.6), WHITE, { Mat = WOOD })
	-- ladder at the back, red-white umbrella, rescue float
	for _, sx in { -0.7, 0.7 } do
		Kit.Part(m, V(0.25, 9, 0.25), base * CFrame.new(sx, 4, 3.2) * CFrame.Angles(-0.3, 0, 0), WHITE, { Mat = WOOD })
	end
	for k = 1, 5 do
		Kit.Part(m, V(1.6, 0.2, 0.3), base * CFrame.new(0, k * 1.5, 3.2 - (k * 1.5 - 4) * 0.3), WHITE, { Mat = WOOD })
	end
	Kit.Part(m, V(0.2, 6, 0.2), base * CFrame.new(1.4, 11, 1.2), WHITE, METAL_O)
	for k = 0, 3 do
		local a = k * math.pi / 2
		Kit.Wedge(m, V(3, 1, 2.6), base * CFrame.new(1.4 + math.cos(a) * 1.3, 14, 1.2 + math.sin(a) * 1.3) * CFrame.Angles(0, -a - math.pi / 2, 0), if k % 2 == 0 then RED else WHITE, { Mat = FABRIC })
	end
	Kit.Part(m, V(1.8, 0.6, 0.4), base * CFrame.new(-1.6, 6, -2.2), Kit.Vivid(ORANGE))
	Kit.AddCircle(x, z, 4)
end

local function cabana(parent: Instance, x: number, z: number, fx: number, col: Color3)
	local m = Kit.Model(parent, "Cabana")
	Kit.Box(m, V(x - 5, 0, z - 5), V(x + 5, 0.3, z + 5), C(150, 110, 75), { Mat = WOOD, Solid = true })
	for _, c in { { -4.6, -4.6 }, { 4.6, -4.6 }, { 4.6, 4.6 }, { -4.6, 4.6 } } do
		Kit.Box(m, V(x + c[1] - 0.25, 0.3, z + c[2] - 0.25), V(x + c[1] + 0.25, 8, z + c[2] + 0.25), WHITE, { Mat = WOOD })
	end
	-- striped canopy: two sloped halves, back curtain
	for i = 0, 4 do
		local zz = z - 5.2 + (i + 0.5) * 10.4 / 5
		local c2 = if i % 2 == 0 then col else WHITE
		Kit.Wedge(m, V(10.4 / 5, 2, 5.4), CFrame.new(x, 9, zz) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -2.7), c2, { Mat = FABRIC })
		Kit.Wedge(m, V(10.4 / 5, 2, 5.4), CFrame.new(x, 9, zz) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, 0, -2.7), c2, { Mat = FABRIC })
	end
	Kit.Box(m, V(x - fx * 4.8 - 0.1, 0.3, z - 4.6), V(x - fx * 4.8 + 0.1, 8, z + 4.6), col, { Mat = FABRIC })
	lounger(m, x - fx * 1, z - 2.2, Kit.FaceYaw(fx, 0), WHITE)
	lounger(m, x - fx * 1, z + 2.2, Kit.FaceYaw(fx, 0), WHITE)
	Kit.Cyl(m, 0.3, 1.6, CFrame.new(x + fx * 3, 1.8, z), WHITE)
	Kit.Box(m, V(x + fx * 3 - 0.1, 0, z - 0.1), V(x + fx * 3 + 0.1, 1.7, z + 0.1), WHITE)
	Kit.AddCircle(x, z, 7.5)
end

-- Catmull-Rom points through control points (n samples per span).
local function spline(ctrl: { Vector3 }, n: number): { Vector3 }
	local out = {}
	for i = 1, #ctrl - 1 do
		local p0 = ctrl[math.max(1, i - 1)]
		local p1, p2 = ctrl[i], ctrl[i + 1]
		local p3 = ctrl[math.min(#ctrl, i + 2)]
		for k = 0, n - 1 do
			local t = k / n
			local t2, t3 = t * t, t * t * t
			table.insert(out, (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5)
		end
	end
	table.insert(out, ctrl[#ctrl])
	return out
end

-- Closed tube slide along points, two alternating colours, a support pole every `every` points.
local function tube(parent: Instance, pts: { Vector3 }, d: number, a: Color3, b: Color3, every: number)
	local m = Kit.Model(parent, "TubeSlide")
	for i = 1, #pts - 1 do
		rod(m, pts[i], pts[i + 1], d, if (i // 2) % 2 == 0 then a else b, { Mat = Enum.Material.SmoothPlastic })
		if i % every == 0 and pts[i].Y > d then
			local p = pts[i]
			Kit.Box(m, V(p.X - 0.35, 0, p.Z - 0.35), V(p.X + 0.35, p.Y - d / 2, p.Z + 0.35), STEEL, METAL_O)
		end
	end
	return m
end

-- Open flume (U trough) between two points in a Y-Z plane at x.
local function flume(parent: Instance, a: Vector3, b: Vector3, col: Color3)
	Props.Beam(parent, a, b, 4.4, 0.5, col)
	for _, s in { -1, 1 } do
		Props.Beam(parent, a + V(s * 2.1, 0.8, 0), b + V(s * 2.1, 0.8, 0), 0.4, 1.6, Kit.Vivid(col))
	end
end

--==================================================================
-- GROUND, LANE, WALLS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), DECK, { Mat = TILES, Solid = true, Name = "Ground_WaterPark" })
	-- deck tile seams
	for x = -132, 132, 16 do
		if math.abs(x) > 12 then
			Kit.Box(f, V(x - 0.15, 0, Z0 + 4), V(x + 0.15, 0.03, Z1 - 4), DECK_D)
		end
	end
	for z = Z0 + 12, Z1 - 8, 16 do
		Kit.Box(f, V(-138, 0, z - 0.15), V(138, 0.03, z + 0.15), DECK_D)
	end
	-- the dry lane: teal rubber mat with white edge stripes
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.08, Z1), MAT, { Mat = Enum.Material.Rubber, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.2, 0.1, Z1), WHITE)
	end
	for z = Z0 + 30, Z1 - 20, 30 do
		Kit.Disc(f, 0, z, 0.11, 3, 0.03, Kit.Vivid(YELLOW))
	end
	-- splash pads: painted rings with flat sprinkler dots
	local padCols = { { POOL, YELLOW }, { PINK, TEAL }, { ORANGE, POOL }, { LIME, PURPLE } }
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		local c1, c2 = padCols[i][1], padCols[i][2]
		Kit.Disc(f, x, z, 0.1, r * 2 + 3, 0.1, WHITE)
		Kit.Disc(f, x, z, 0.13, r * 2, 0.03, Kit.Vivid(c1))
		Kit.Disc(f, x, z, 0.15, r * 1.5, 0.02, WHITE)
		Kit.Disc(f, x, z, 0.17, r * 1.3, 0.02, Kit.Vivid(c2))
		Kit.Disc(f, x, z, 0.19, r * 0.7, 0.02, WHITE)
		Kit.Disc(f, x, z, 0.21, r * 0.5, 0.02, Kit.Vivid(c1))
		for k = 0, 5 do
			local ang = k * math.pi / 3 + i
			Kit.Disc(f, x + math.cos(ang) * r * 0.7, z + math.sin(ang) * r * 0.7, 0.23, 2.4, 0.02, DARK, METAL_O)
		end
	end
	-- boss: the round cannonball pool (flat) with lane ropes painted on the bottom
	Kit.Disc(f, 0, BOSS_Z, 0.12, 58, 0.12, COPING)
	Kit.Disc(f, 0, BOSS_Z, 0.14, 52, 0.02, POOL_D)
	Kit.Disc(f, 0, BOSS_Z, 0.18, 50, 0.04, POOL, WATER)
	for k = -2, 2 do
		Kit.Box(f, V(k * 8 - 0.6, 0.14, BOSS_Z - 22 + math.abs(k) * 2), V(k * 8 + 0.6, 0.16, BOSS_Z + 22 - math.abs(k) * 2), C(20, 70, 150))
	end
	Kit.Disc(f, 0, BOSS_Z, 0.2, 10, 0.02, Kit.Vivid(YELLOW))
	Kit.Disc(f, 0, BOSS_Z, 0.22, 6, 0.02, Kit.Vivid(RED))
end

local function walls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 12, z1), WHITE, { Mat = TILES, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.8, 0, z0), V(s * 140, 1.5, z1), POOL_D)
		Kit.Box(f, V(s * 139.8, 6, z0), V(s * 140, 7.2, z1), Kit.Vivid(TEAL))
		Kit.Box(f, V(s * 139.5, 12, z0), V(s * 146.5, 13, z1), Kit.Vivid(POOL_D))
		-- painted wave pattern
		for z = z0 + 8, z1 - 8, 24 do
			Kit.Part(f, V(0.2, 2.2, 2.2), CFrame.new(s * 139.8, 3.4, z) * CFrame.Angles(math.pi / 4, 0, 0), Kit.Vivid(POOL))
		end
		-- palms outside the wall
		for _, z in { Z0 + 60, Z0 + 170, Z0 + 280 } do
			palm(f, s * 152, z, 22, -s * 2)
		end
	end
end

--==================================================================
-- POOLS
--==================================================================
local function wavePool(f: Instance)
	local x1, x2, z1, z2 = -130, -50, Z0 + 10, Z0 + 86
	pool(f, x1, z1, x2, z2, POOL_D)
	-- beach entry toward the lane: lighter shallow water, sand edge
	Kit.Box(f, V(x2 - 14, 0, z1), V(x2, 0.11, z2), POOL, { Transp = 0.35 })
	Kit.Box(f, V(x2 - 3, 0, z1), V(x2, 0.12, z2), SAND, { Mat = Enum.Material.Sand })
	-- white wave crests (flat)
	for k = 0, 4 do
		local x = x1 + 14 + k * 13
		for j = 0, 2 do
			Kit.Part(f, V(1.2, 0.03, 20), CFrame.new(x + (j % 2) * 3, 0.12, z1 + 13 + j * 25) * CFrame.Angles(0, 0.25 * (if j % 2 == 0 then 1 else -1), 0), WHITE, { Transp = 0.35 })
		end
	end
	-- wave machine house at the far end
	local m = Kit.Model(f, "WaveMachine")
	Kit.Box(m, V(-138, 0, z1 + 8), V(-128, 14, z2 - 8), WHITE, { Mat = TILES, Solid = true })
	for z = z1 + 10, z2 - 10, 6 do
		Kit.Box(m, V(-128.2, 1, z - 1.6), V(-127.8, 6, z + 1.6), DARK)
	end
	Kit.Box(m, V(-138.5, 14, z1 + 7), V(-127, 15.2, z2 - 7), Kit.Vivid(POOL_D))
	Props.SignBoard(m, V(-127.5, 10, (z1 + z2) / 2), 26, 4, 1, 0, "WAVE POOL", Kit.Vivid(POOL_D), WHITE, YELLOW)
	-- swim rings and beach balls on the waves
	local cols = { { ORANGE, WHITE }, { PINK, YELLOW }, { LIME, WHITE }, { PURPLE, YELLOW }, { RED, WHITE } }
	for i, p in { { -110, 30 }, { -92, 58 }, { -76, 24 }, { -104, 74 }, { -66, 66 } } do
		ring(f, p[1], Z0 + p[2], 4.4, cols[i][1], cols[i][2])
	end
	for i, p in { V(-84, 2.2, Z0 + 44), V(-118, 2.6, Z0 + 52), V(-70, 2.4, Z0 + 80) } do
		local ball = Kit.Ball(f, 2.4, p, if i == 2 then PINK else Kit.Vivid(YELLOW), { Name = "BeachBall" })
		Kit.Float(ball, 0.6)
	end
	-- underwater lights along the long sides (small)
	for x = x1 + 10, x2 - 18, 16 do
		for _, z in { z1 + 0.6, z2 - 0.6 } do
			Kit.Disc(f, x, z, 0.12, 1.2, 0.02, LAMP, { Mat = NEON })
		end
	end
	local mist = Kit.Part(f, V(40, 1, 40), CFrame.new(-90, 1.5, (z1 + z2) / 2), WHITE, { Transp = 1, Name = "PoolMist" })
	Kit.Emitter(mist, C(190, 235, 255), 3, 8, 0.4)
	Kit.AddRect(x1 - 10, z1 - 2, x2 + 2, z2 + 2)
end

local function lazyRiver(f: Instance)
	local ox1, ox2, oz1, oz2 = 42, 134, Z0 + 40, Z0 + 148
	local ix1, ix2, iz1, iz2 = 56, 120, Z0 + 54, Z0 + 134
	pool(f, ox1, oz1, ox2, oz2, POOL)
	-- the island: deck tiles with sand and rounded corners, a little higher than the water
	Kit.Box(f, V(ix1 + 3, 0, iz1), V(ix2 - 3, 0.2, iz2), COPING, { Solid = true })
	Kit.Box(f, V(ix1, 0, iz1 + 3), V(ix2, 0.2, iz2 - 3), COPING, { Solid = true })
	for _, c in { { ix1 + 3, iz1 + 3 }, { ix2 - 3, iz1 + 3 }, { ix2 - 3, iz2 - 3 }, { ix1 + 3, iz2 - 3 } } do
		Kit.Disc(f, c[1], c[2], 0.2, 6, 0.2, COPING)
	end
	Kit.Box(f, V(ix1 + 2, 0.2, iz1 + 2), V(ix2 - 2, 0.24, iz2 - 2), SAND, { Mat = Enum.Material.Sand, Solid = true })
	-- current arrows painted in the river
	for _, p in { { 49, 70, 0 }, { 49, 120, 0 }, { 127, 80, math.pi }, { 127, 125, math.pi }, { 90, 44, math.pi / 2 }, { 88, 144, -math.pi / 2 } } do
		Kit.Part(f, V(2.2, 0.02, 2.2), CFrame.new(p[1], 0.11, Z0 + p[2]) * CFrame.Angles(0, p[3] + math.pi / 4, 0), WHITE, { Transp = 0.4 })
	end
	-- tubes drifting round
	local cols = { { YELLOW, POOL_D }, { ORANGE, WHITE }, { PINK, WHITE }, { LIME, YELLOW }, { PURPLE, WHITE }, { TEAL, YELLOW } }
	for i, p in { { 49, 62 }, { 49, 104 }, { 72, 141 }, { 108, 141 }, { 127, 100 }, { 98, 47 } } do
		ring(f, p[1], Z0 + p[2], 5, cols[i][1], cols[i][2])
	end
	-- island: palms, a hut, a sign, a little waterfall rock
	palm(f, 68, Z0 + 66, 20, 2)
	palm(f, 108, Z0 + 122, 18, -2)
	palm(f, 110, Z0 + 64, 22, -1.5)
	cabana(f, 74, Z0 + 116, -1, Kit.Vivid(TEAL))
	Props.SignBoard(f, V(ix1 + 1, 4.6, Z0 + 94), 16, 2.8, -1, 0, "LAZY RIVER", Kit.Vivid(TEAL), WHITE, YELLOW)
	for _, dz in { -6, 6 } do
		Kit.Box(f, V(ix1 + 1.2, 0, Z0 + 94 + dz - 0.3), V(ix1 + 1.8, 6.4, Z0 + 94 + dz + 0.3), WHITE, { Mat = WOOD })
	end
	local rx, rz = 96, Z0 + 92
	Kit.Ball(f, 12, V(rx, 2, rz), C(120, 115, 110), { Mat = Enum.Material.Rock, Solid = true })
	Kit.Ball(f, 8, V(rx + 3, 6, rz - 2), C(105, 100, 98), { Mat = Enum.Material.Rock })
	Kit.Box(f, V(rx - 2, 1, rz - 6.2), V(rx + 2, 8, rz - 5.6), POOL, { Transp = 0.4 })
	lifeguard(f, 86, Z0 + 70, 0, -1)
	Kit.AddRect(ox1 - 2, oz1 - 2, ox2 + 2, oz2 + 2)
end

--==================================================================
-- SLIDES
--==================================================================
local function tower(parent: Instance, cx: number, cz: number, half: number, top: number, col: Color3, name: string)
	local m = Kit.Model(parent, name)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		Kit.Box(m, V(cx + c[1] * half - 0.6, 0, cz + c[2] * half - 0.6), V(cx + c[1] * half + 0.6, top + 8, cz + c[2] * half + 0.6), col, { Mat = METAL, Solid = true })
	end
	-- landings every 12 studs, stairs between them, rails, a pointed roof
	local y = 12
	local flip = 1
	while y <= top do
		Kit.Box(m, V(cx - half, y - 0.6, cz - half), V(cx + half, y, cz + half), C(90, 150, 200), { Mat = Enum.Material.DiamondPlate })
		for _, s in { -1, 1 } do
			Kit.Box(m, V(cx - half, y + 2.6, cz + s * half - 0.15), V(cx + half, y + 3, cz + s * half + 0.15), WHITE, METAL_O)
		end
		Props.Beam(m, V(cx + flip * (half - 2), y - 12, cz - half + 1), V(cx + flip * (half - 2), y - 0.6, cz + half - 1), 3, 0.5, STEEL, METAL_O)
		flip = -flip
		y += 12
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		Kit.Wedge(m, V(half * 2 + 2, 5, half + 1), CFrame.new(cx + math.cos(a) * (half + 1) / 2, top + 10.5, cz + math.sin(a) * (half + 1) / 2) * CFrame.Angles(0, -a - math.pi / 2, 0), if k % 2 == 0 then Kit.Vivid(col) else WHITE, { Mat = FABRIC })
	end
	Kit.Box(m, V(cx - half - 1, top + 7.6, cz - half - 1), V(cx + half + 1, top + 8, cz + half + 1), WHITE, METAL_O)
	Kit.Ball(m, 1.6, V(cx, top + 13.6, cz), LAMP, { Mat = NEON })
	Kit.AddCircle(cx, cz, half * 1.5)
	return m
end

local function leftSlides(f: Instance)
	local cx, cz, top = -118, Z0 + 301, 44
	local m = tower(f, cx, cz, 7, top, PURPLE, "SpiralTower")
	-- helix tube: 2.5 turns from the top landing down to a splash pool
	local pts = {}
	local n = 40
	for i = 0, n do
		local t = i / n
		local a = -math.pi / 2 + t * 2.5 * 2 * math.pi
		table.insert(pts, V(cx + math.cos(a) * 14, top - 1 - t * (top - 3), cz + math.sin(a) * 14))
	end
	tube(m, pts, 4.4, Kit.Vivid(ORANGE), Kit.Vivid(YELLOW), 4)
	local e = pts[#pts]
	Kit.Disc(f, e.X + 2, e.Z, 0.12, 12, 0.12, COPING)
	Kit.Disc(f, e.X + 2, e.Z, 0.14, 10, 0.04, POOL, WATER)
	-- long snaking tube to its own splash pool near the boss pool
	local ctrl = { V(-111, 40, Z0 + 296), V(-98, 34, Z0 + 282), V(-82, 28, Z0 + 290), V(-80, 22, Z0 + 310), V(-66, 16, Z0 + 320), V(-62, 11, Z0 + 302), V(-50, 6, Z0 + 312), V(-46, 2.4, Z0 + 330) }
	tube(f, spline(ctrl, 4), 4.2, Kit.Vivid(LIME), Kit.Vivid(TEAL), 3)
	pool(f, -58, Z0 + 326, -36, Z0 + 346, POOL)
	Props.SignBoard(m, V(cx + 7.4, 9, cz), 12, 2.6, 1, 0, "THE SPOOKY SPIRAL", Kit.Vivid(PURPLE), WHITE, YELLOW)
	local lamp = Kit.Part(f, V(1, 1, 1), CFrame.new(cx + 10, 30, cz), LAMP, { Transp = 1, Name = "TowerGlow" })
	Kit.Light(lamp, C(200, 170, 255), 40, 0.9)
	Kit.AddRect(-136, Z0 + 278, -40, Z0 + 348)
end

local function rightSlides(f: Instance)
	local cx, cz, top = 122, Z0 + 252, 36
	local m = tower(f, cx, cz, 7, top, Kit.Vivid(TEAL), "SpeedTower")
	-- two open speed flumes straight down toward the back
	for i, x in { 117, 127 } do
		local col = if i == 1 then PINK else Kit.Vivid(POOL_D)
		local a, b, c = V(x, top, cz + 7), V(x, 6, cz + 42), V(x, 1.2, cz + 66)
		flume(m, a, b, col)
		flume(m, b, c, col)
		for _, t in { 0.25, 0.55, 0.85 } do
			local p = a:Lerp(b, t)
			Kit.Box(m, V(x - 0.3, 0, p.Z - 0.3), V(x + 0.3, p.Y - 0.3, p.Z + 0.3), STEEL, METAL_O)
		end
	end
	pool(f, 108, Z0 + 316, 136, Z0 + 344, POOL)
	-- a twisting tube from the other side of the top, into a pool by the boss area
	local ctrl = { V(115, 34, Z0 + 248), V(100, 28, Z0 + 260), V(104, 22, Z0 + 280), V(86, 16, Z0 + 290), V(90, 10, Z0 + 306), V(68, 6, Z0 + 312), V(54, 2.4, Z0 + 326) }
	tube(f, spline(ctrl, 4), 4.2, Kit.Vivid(RED), WHITE, 3)
	pool(f, 40, Z0 + 320, 64, Z0 + 344, POOL)
	Props.SignBoard(m, V(cx - 7.4, 9, cz), 12, 2.6, -1, 0, "FRIGHT DROP", Kit.Vivid(TEAL), WHITE, PINK)
	local lamp = Kit.Part(f, V(1, 1, 1), CFrame.new(cx - 10, 26, cz), LAMP, { Transp = 1, Name = "TowerGlow" })
	Kit.Light(lamp, C(170, 240, 255), 40, 0.9)
	Kit.AddRect(38, Z0 + 238, 136, Z0 + 346)
end

--==================================================================
-- DECK FURNITURE
--==================================================================
local function arch(f: Instance)
	local z = Z0 + 140
	local m = Kit.Model(f, "EntranceArch")
	for _, s in { -1, 1 } do
		Kit.Cyl(m, 22, 2.4, CFrame.new(s * 14, 11, z), WHITE, { Mat = METAL, Solid = true })
		for y = 3, 19, 4 do
			Kit.Cyl(m, 1, 2.6, CFrame.new(s * 14, y, z), if (y // 4) % 2 == 0 then Kit.Vivid(POOL) else Kit.Vivid(ORANGE), METAL_O)
		end
		Kit.Ball(m, 3.4, V(s * 14, 23, z), Kit.Vivid(YELLOW))
	end
	Kit.Box(m, V(-16, 20, z - 0.8), V(16, 26, z + 0.8), Kit.Vivid(POOL_D), METAL_O)
	local board = Kit.Part(m, V(28, 4.4, 0.4), CFrame.new(0, 23, z - 1), Kit.Vivid(POOL_D), { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, "SPOOKY SPLASH", WHITE)
	local back = Kit.Part(m, V(28, 4.4, 0.4), CFrame.new(0, 23, z + 1), Kit.Vivid(POOL_D), { Name = "SignBoard" })
	Kit.Sign(back, Enum.NormalId.Back, "SEE YOU NEXT SUMMER!", WHITE)
	-- a wave-shaped crest on top
	for k = -3, 3 do
		Kit.Ball(m, 3.2, V(k * 4.2, 26.4 + (k % 2) * 0.8, z), if k % 2 == 0 then WHITE else Kit.Vivid(POOL))
	end
	Kit.AddCircle(14, z, 2)
	Kit.AddCircle(-14, z, 2)
end

local function snackShack(f: Instance)
	local m = Kit.Model(f, "SnackShack")
	local x, z = -36, Z0 + 172
	Kit.Box(m, V(x - 8, 0, z - 6), V(x + 2, 9, z + 6), C(250, 225, 170), { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x + 2, 3.4, z - 5), V(x + 2.2, 7.4, z + 5), DARK)
	Kit.Box(m, V(x + 2, 3, z - 5.4), V(x + 3.4, 3.4, z + 5.4), Kit.Vivid(ORANGE), { Mat = WOOD })
	for i = 0, 5 do
		Kit.Wedge(m, V(13 / 6, 1.6, 4), CFrame.new(x + 3.4, 9, z - 6.5 + (i + 0.5) * 13 / 6) * CFrame.Angles(0, -math.pi / 2, 0), if i % 2 == 0 then PINK else WHITE, { Mat = FABRIC })
	end
	Kit.Box(m, V(x - 8.4, 9, z - 6.4), V(x + 2.4, 10, z + 6.4), WHITE, { Mat = WOOD })
	Props.SignBoard(m, V(x - 3, 12, z), 12, 2.6, 1, 0, "FROZEN FRIGHTS", C(255, 120, 170), WHITE)
	-- giant ice-cream cone on the roof
	Kit.Part(m, V(3, 4, 3), CFrame.new(x - 3, 12, z) * CFrame.Angles(math.pi, 0, 0), C(210, 160, 90))
	Kit.Ball(m, 3.6, V(x - 3, 15, z), C(255, 200, 220))
	Kit.Ball(m, 1, V(x - 3, 17, z), Kit.Vivid(RED))
	local lamp = Kit.Ball(m, 1, V(x + 2.6, 7.8, z - 4.8), LAMP, { Mat = NEON })
	Kit.Light(lamp, C(255, 220, 190), 22, 0.9)
	-- tables with umbrellas
	for i, p in { { -24, 160 }, { -24, 186 }, { -44, 196 } } do
		local tx, tz = p[1], Z0 + p[2]
		Kit.Cyl(m, 0.3, 3.4, CFrame.new(tx, 2.6, tz), WHITE, { Solid = true })
		Kit.Box(m, V(tx - 0.2, 0, tz - 0.2), V(tx + 0.2, 2.5, tz + 0.2), WHITE)
		for _, d in { { 2.6, 0 }, { -2.6, 0 } } do
			Kit.Cyl(m, 1.6, 1.4, CFrame.new(tx + d[1], 0.8, tz + d[2]), Kit.Vivid(POOL))
		end
		umbrella(m, tx, tz, if i % 2 == 0 then ORANGE else PINK)
	end
	Kit.AddRect(x - 10, z - 20, x + 15, z + 28)
end

local function deck(f: Instance)
	-- cabanas along the left and right middle edges
	for i, p in { { -128, 158 }, { -128, 176 }, { -128, 194 }, { 126, 166 }, { 126, 184 }, { 126, 202 } } do
		local x, z = p[1], Z0 + p[2]
		if Kit.IsFree(x, z, 7) then
			cabana(f, x, z, if x < 0 then 1 else -1, if i % 3 == 0 then Kit.Vivid(ORANGE) elseif i % 3 == 1 then Kit.Vivid(POOL_D) else Kit.Vivid(PINK))
		end
	end
	-- loungers with umbrellas in pairs
	local cols = { ORANGE, POOL_D, PINK, LIME, PURPLE, YELLOW }
	local spots = { { -40, 100 }, { -112, 212 }, { 30, 220 }, { 112, 222 }, { 38, 150 }, { -104, 246 }, { -24, 228 }, { 30, 258 } }
	for i, p in spots do
		local x, z = p[1], Z0 + p[2]
		if Kit.IsFree(x, z, 4) then
			umbrella(f, x, z, Kit.Vivid(cols[(i - 1) % #cols + 1]))
			lounger(f, x - 2, z + 1, 0, WHITE)
			lounger(f, x + 2, z + 1, 0, Kit.Vivid(cols[i % #cols + 1]))
			Kit.AddCircle(x, z, 4)
		end
	end
	-- lifeguard towers
	for _, p in { { -46, 94, -1, 0 }, { -32, 324, 0, -1 }, { 34, 300, 0, -1 } } do
		if Kit.IsFree(p[1], Z0 + p[2], 4) then
			lifeguard(f, p[1], Z0 + p[2], p[3], p[4])
		end
	end
	-- palms around the deck
	for i, p in { { 22, 40 }, { -20, 140 }, { 22, 196 }, { -20, 270 }, { 22, 270 }, { -40, 212 }, { 104, 214 }, { -128, 116 }, { 40, 30 } } do
		if Kit.IsFree(p[1], Z0 + p[2], 3) then
			palm(f, p[1], Z0 + p[2], 16 + (i % 3) * 3, if p[1] > 0 then 1.5 else -1.5)
		end
	end
	-- "NO RUNNING" sign, towel rack, lane lamps
	Props.SignBoard(f, V(14, 5, Z0 + 52), 8, 2, -1, 0, "NO RUNNING!", WHITE, RED, RED)
	Kit.Box(f, V(14.3, 0, Z0 + 51.7), V(14.9, 4, Z0 + 52.3), WHITE, METAL_O)
	Kit.AddCircle(14, Z0 + 52, 2)
	for i, z in { Z0 + 40, Z0 + 160, Z0 + 220, Z0 + 344 } do
		for _, s in { -1, 1 } do
			local x = s * 12
			if Kit.IsFree(x, z, 1.2) then
				Kit.Cyl(f, 10, 0.5, CFrame.new(x, 5, z), WHITE, METAL_O)
				local g = Kit.Ball(f, 1.6, V(x, 10.4, z), LAMP, { Mat = Enum.Material.Glass })
				if (i + s) % 3 == 0 then
					Kit.Light(g, LAMP, 20, 0.8)
				end
				Kit.AddCircle(x, z, 1.2)
			end
		end
	end
	-- floating beach balls and a ghostly inflatable duck over the splash pads
	for i, p in { V(-60, 16, Z0 + 140), V(40, 20, Z0 + 110), V(-100, 22, Z0 + 230), V(90, 24, Z0 + 230) } do
		local ball = Kit.Ball(f, 2.4, p, if i % 2 == 0 then Kit.Vivid(ORANGE) else Kit.Vivid(LIME), { Name = "BeachBall" })
		Kit.Float(ball, 1)
	end
	local duck = Kit.Ball(f, 4, V(0, 24, Z0 + 200), C(255, 240, 150), { Transp = 0.35, Name = "GhostDuck" })
	Kit.Float(duck, 1.5)
	Props.Wisp(f, V(-62, 0, Z0 + 270), C(170, 240, 255), 10, true)
end

--==================================================================
-- BUILD
--==================================================================
function WaterPark.Build(map: Instance)
	local f = Kit.Folder(map, "WaterPark")
	ground(f)
	walls(f)
	wavePool(f)
	lazyRiver(f)
	leftSlides(f)
	rightSlides(f)
	arch(f)
	snackShack(f)
	deck(f)
end

return WaterPark
