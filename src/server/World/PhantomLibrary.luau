--!strict
-- ZONE 18: Phantom Library (Z 7360..7720). An enormous haunted reading hall: dark walnut
-- parquet, a teal carpet runner, bookshelves towering 64 studs up both side walls under huge
-- carved wooden ribs, books flying in a slow ribbon through the air.
--   Ghost areas get flat round reading rugs with an open-book emblem ((0,7445) r30,
--   (-82,7480) r24, (75,7540) r26, (-62,7600) r24); the boss area (0,7665) r26 is a brass
--   astrolabe rosette, with the giant open Grand Grimoire floating above it (bottom ~Y 48).
--   Freestanding double-sided shelf islands, reading tables with green banker's lamps, brass
--   floor lamps, two spiral staircases up to little reading balconies, a giant stack of books,
--   an ink bottle with a quill, a globe. Flying books stay above Y 42 over the ghost areas.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local PhantomLibrary = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local GLASS = Enum.Material.Glass

local Z0, Z1 = 7360, 7720
local WALL_H = 64

local FLOOR = C(92, 60, 44)
local WALNUT = C(78, 48, 34)
local WALNUT_D = C(56, 34, 26)
local TEAL = C(30, 105, 105)
local TEAL_D = C(22, 70, 75)
local BURGUNDY = C(125, 38, 52)
local CREAM = C(246, 236, 210)
local BRASS = C(214, 172, 92)
local MINT = C(120, 255, 220)
local LAMP_GREEN = C(40, 150, 90)
local WARM = C(255, 220, 160)
local INK = C(40, 40, 95)

local BOOKS = { C(140, 40, 55), C(40, 60, 120), C(40, 110, 70), C(210, 160, 60), C(30, 120, 120), C(100, 50, 110), C(225, 210, 180), C(160, 100, 60), C(190, 70, 50) }

local SOLID_WOOD: Kit.Opts = { Mat = WOOD, Solid = true, Shadow = true }
local BRASS_M: Kit.Opts = { Mat = METAL, Refl = 0.15 }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
-- True when (x, z) is at least `pad` studs outside every ghost circle.
local function clearOfAreas(x: number, z: number, pad: number): boolean
	for _, a in { AREAS[1], AREAS[2], AREAS[3], AREAS[4], { 0, BOSS_Z, 26 } } do
		local dx, dz = x - a[1], z - a[2]
		if dx * dx + dz * dz < (a[3] + pad) ^ 2 then
			return false
		end
	end
	return true
end

-- A row of books filling a shelf slot: `n` blocks of random width/height along local X.
-- cf: centre of the slot's bottom; w: slot width; d: depth; h: slot height.
local function bookRow(parent: Instance, cf: CFrame, w: number, d: number, h: number, n: number)
	local rng = Kit.Rng
	local x = -w / 2
	for i = 1, n do
		local bw = if i == n then w / 2 - x else (w / n) * rng:NextNumber(0.7, 1.3)
		local bh = h * rng:NextNumber(0.62, 0.9)
		local lean = if i == n and rng:NextNumber() < 0.4 then 0.12 else 0
		Kit.Part(parent, V(bw - 0.15, bh, d), cf * CFrame.new(x + bw / 2, bh / 2, 0) * CFrame.Angles(0, 0, lean), Kit.Pick(BOOKS), { Mat = FABRIC })
		x += bw
	end
end

-- Open book in flight (two covers in a V with a cream page block). pos = spine centre.
local function flyingBook(parent: Instance, pos: Vector3, yaw: number, size: number, color: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, Kit.Rng:NextNumber(-0.25, 0.25))
	for _, s in { -1, 1 } do
		Kit.Part(parent, V(size, 0.2, size * 1.3), cf * CFrame.Angles(0, 0, s * 0.45) * CFrame.new(s * size / 2, 0, 0), color, { Mat = FABRIC })
	end
	Kit.Part(parent, V(size * 1.6, 0.4, size * 1.15), cf * CFrame.new(0, 0.35, 0), CREAM)
end

local function bankerLamp(parent: Instance, pos: Vector3, lit: boolean)
	Kit.Cyl(parent, 0.3, 1.4, CFrame.new(pos + V(0, 0.15, 0)), BRASS, BRASS_M)
	Kit.Cyl(parent, 1.8, 0.25, CFrame.new(pos + V(0, 1.1, 0)), BRASS, BRASS_M)
	Kit.CylFlat(parent, 2.4, 1.3, pos + V(0, 2.2, 0), "X", LAMP_GREEN, { Mat = GLASS, Refl = 0.2 })
	Kit.CylFlat(parent, 2, 0.6, pos + V(0, 1.85, 0), "X", WARM, if lit then { Mat = NEON } else nil)
end

--==================================================================
-- GROUND
--==================================================================
local function ground(f: Instance)
	local brass = Kit.Vivid(BRASS)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), FLOOR, { Mat = PLANKS, Solid = true, Name = "Ground_PhantomLibrary" })
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), TEAL, { Mat = FABRIC, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.4, 0.07, Z1), CREAM, { Mat = FABRIC })
		Kit.Box(f, V(s * 6.4, 0, Z0), V(s * 6.9, 0.07, Z1), Kit.Vivid(BRASS), { Mat = FABRIC })
	end
	-- darker walnut floor bands across the hall
	for z = Z0 + 30, Z1 - 20, 45 do
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * 10, 0, z - 1.5), V(s * 132, 0.03, z + 1.5), WALNUT_D, { Mat = WOOD })
		end
	end
	-- reading rugs on the ghost areas: brass rim, teal / burgundy, cream ring, flat open book
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		local main = if i % 2 == 0 then BURGUNDY else TEAL_D
		Kit.Disc(f, x, z, 0.08, r * 2 + 3, 0.08, brass, { Mat = FABRIC })
		Kit.Disc(f, x, z, 0.11, r * 2, 0.11, main, { Mat = FABRIC })
		Kit.Disc(f, x, z, 0.14, r * 1.5, 0.03, CREAM, { Mat = FABRIC })
		Kit.Disc(f, x, z, 0.16, r * 1.4, 0.05, main, { Mat = FABRIC })
		-- open book emblem
		for _, s in { -1, 1 } do
			Kit.Part(f, V(r * 0.42, 0.04, r * 0.55), CFrame.new(x + s * r * 0.23, 0.17, z) * CFrame.Angles(0, s * 0.12, 0), CREAM, { Mat = FABRIC })
		end
		Kit.Part(f, V(0.6, 0.05, r * 0.6), CFrame.new(x, 0.19, z), brass)
		for k = 0, 5 do
			local ang = k * math.pi / 3 + 0.3
			Kit.Part(f, V(1.6, 0.04, 1.6), CFrame.new(x + math.cos(ang) * r * 0.85, 0.17, z + math.sin(ang) * r * 0.85) * CFrame.Angles(0, ang, 0), Kit.Vivid(MINT), { Mat = FABRIC })
		end
	end
	-- boss: brass astrolabe rosette
	Kit.Disc(f, 0, BOSS_Z, 0.08, 58, 0.08, brass, BRASS_M)
	Kit.Disc(f, 0, BOSS_Z, 0.11, 55, 0.11, INK, { Mat = Enum.Material.Marble })
	Kit.Disc(f, 0, BOSS_Z, 0.14, 44, 0.03, brass, BRASS_M)
	Kit.Disc(f, 0, BOSS_Z, 0.16, 42, 0.05, TEAL_D, { Mat = Enum.Material.Marble })
	Kit.Disc(f, 0, BOSS_Z, 0.18, 16, 0.03, brass, BRASS_M)
	Kit.Disc(f, 0, BOSS_Z, 0.2, 14, 0.05, INK, { Mat = Enum.Material.Marble })
	for k = 0, 7 do
		local ang = k * math.pi / 4
		local long = k % 2 == 0
		local len = if long then 18 else 11
		local cf = CFrame.new(math.cos(ang) * (7 + len / 2), 0.19, BOSS_Z + math.sin(ang) * (7 + len / 2)) * CFrame.Angles(0, -ang + math.pi / 2, 0)
		Kit.Part(f, V(2.6, 0.04, len), cf, if long then brass else CREAM, BRASS_M)
	end
	for k = 0, 11 do
		local ang = k * math.pi / 6
		Kit.Part(f, V(1.4, 0.04, 1.4), CFrame.new(math.cos(ang) * 24.5, 0.2, BOSS_Z + math.sin(ang) * 24.5) * CFrame.Angles(0, ang, 0), Kit.Vivid(MINT), { Mat = FABRIC })
	end
end

--==================================================================
-- WALL SHELVES, RIBS, OUTSIDE
--==================================================================
local function wallShelves(f: Instance)
	local brass = Kit.Vivid(BRASS)
	local z0, z1 = Z0 + 3, Z1 - 3
	local bay = 30
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, WALL_H, z1), WALNUT_D, SOLID_WOOD)
		-- closed cabinets at the bottom, then five shelf boards
		Kit.Box(f, V(s * 134, 0, z0), V(s * 140, 8, z1), WALNUT, { Mat = WOOD, Solid = true })
		Kit.Box(f, V(s * 133.6, 8, z0), V(s * 140, 8.8, z1), brass, BRASS_M)
		for k = 1, 5 do
			Kit.Box(f, V(s * 134, 8 + k * 10.6, z0), V(s * 140, 8.8 + k * 10.6, z1), WALNUT, { Mat = WOOD })
		end
		Kit.Box(f, V(s * 132.6, WALL_H - 2.4, z0), V(s * 140, WALL_H + 1, z1), WALNUT_D, { Mat = WOOD })
		Kit.Box(f, V(s * 132.4, WALL_H - 1.2, z0), V(s * 133, WALL_H - 0.4, z1), brass, BRASS_M)
		-- uprights and books per bay
		local n = 0
		for z = z0, z1 - 1, bay do
			n += 1
			Kit.Box(f, V(s * 133, 0, z - 1), V(s * 140, WALL_H - 2.4, z + 1), WALNUT_D, { Mat = WOOD, Solid = true })
			local zc = z + bay / 2
			if zc < z1 then
				for k = 0, 4 do
					local cf = CFrame.new(s * 137, 8.8 + k * 10.6, zc) * CFrame.Angles(0, math.pi / 2, 0)
					bookRow(f, cf, bay - 2.4, 5, 9.8, if k <= 1 then 3 else 1)
				end
			end
		end
		Kit.Box(f, V(s * 140, WALL_H + 1, z0), V(s * 146, WALL_H + 3, z1), WALNUT_D, { Mat = WOOD })
	end
	-- rolling ladders leaning on the shelves
	for _, p in { { -1, Z0 + 52 }, { 1, Z0 + 118 }, { -1, Z0 + 196 }, { 1, Z0 + 286 }, { -1, Z0 + 330 } } do
		local s, z = p[1], p[2]
		if Kit.IsFree(s * 130, z, 2.5) then
			for _, dz in { -1.6, 1.6 } do
				Props.Beam(f, V(s * 128, 0, z + dz), V(s * 133, 40, z + dz), 0.4, 0.4, brass, BRASS_M)
			end
			for k = 1, 6 do
				local t = k / 7
				Kit.Box(f, V(s * (128 + 5 * t) - 0.15, 40 * t - 0.15, z - 1.6), V(s * (128 + 5 * t) + 0.15, 40 * t + 0.15, z + 1.6), brass)
			end
			Kit.AddCircle(s * 130, z, 2.5)
		end
	end
end

-- Huge carved ribs across the hall (from the shelf tops up to Y ~92) with hanging lamps.
local function ribs(f: Instance)
	local brass = Kit.Vivid(BRASS)
	for i, z in { Z0 + 40, Z0 + 150, Z0 + 260 } do
		local pts = { V(-140, WALL_H, z), V(-110, 80, z), V(-60, 90, z), V(0, 93, z), V(60, 90, z), V(110, 80, z), V(140, WALL_H, z) }
		for k = 1, #pts - 1 do
			Props.Beam(f, pts[k], pts[k + 1], 4, 5, WALNUT_D, { Mat = WOOD })
		end
		Kit.Ball(f, 5, V(0, 92, z), brass, BRASS_M)
		if i == 1 then
			local sign = Props.SignBoard(f, V(0, 74, z), 40, 6, 0, -1, "PHANTOM LIBRARY", WALNUT_D, Kit.Vivid(MINT), BRASS)
			Props.SignBoard(f, V(0, 74, z + 0.8), 40, 6, 0, 1, "SHHH! GHOSTS ARE READING", WALNUT_D, CREAM)
			Kit.Light(sign, MINT, 40, 0.8)
			Props.Beam(f, V(-18, 77, z), V(-30, 88.5, z), 0.3, 0.3, brass)
			Props.Beam(f, V(18, 77, z), V(30, 88.5, z), 0.3, 0.3, brass)
		end
	end
	-- the ribs rest on brass corbels
	for _, z in { Z0 + 40, Z0 + 150, Z0 + 260 } do
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * 131, WALL_H - 6, z - 3), V(s * 140, WALL_H, z + 3), brass, BRASS_M)
		end
	end
end

local function outside(f: Instance)
	-- stone corner towers with slate cones behind the shelf walls (seen from afar)
	for _, p in { { -158, Z0 + 20 }, { 158, Z0 + 20 }, { -160, Z1 - 60 }, { 160, Z1 - 60 } } do
		Kit.Cyl(f, 96, 22, CFrame.new(p[1], 48, p[2]), C(110, 100, 115), { Mat = Enum.Material.Cobblestone })
		Kit.Cyl(f, 3, 25, CFrame.new(p[1], 97.5, p[2]), WALNUT_D, { Mat = WOOD })
		for k = 0, 3 do
			Kit.Cyl(f, 7, 22 - k * 6, CFrame.new(p[1], 102.5 + k * 7, p[2]), TEAL_D, { Mat = Enum.Material.Slate })
		end
		Kit.Part(f, V(3, 10, 0.4), CFrame.new(p[1] - math.sign(p[1]) * 11.3, 70, p[2]) * CFrame.Angles(0, math.pi / 2, 0), WARM, { Mat = GLASS })
	end
	-- long roof ridges over the side walls
	for _, s in { -1, 1 } do
		Kit.Wedge(f, V(Z1 - Z0, 10, 18), CFrame.new(s * 155, WALL_H + 8, (Z0 + Z1) / 2) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0), TEAL_D, { Mat = Enum.Material.Slate })
	end
end

--==================================================================
-- FURNITURE
--==================================================================
-- Double-sided shelf island along Z (length 18).
local function island(parent: Instance, x: number, z: number, h: number)
	local m = Kit.Model(parent, "ShelfIsland")
	local brass = Kit.Vivid(BRASS)
	Kit.Box(m, V(x - 0.6, 0, z - 10), V(x + 0.6, h, z + 10), WALNUT_D, SOLID_WOOD)
	for _, sz in { -1, 1 } do
		Kit.Box(m, V(x - 3.2, 0, z + sz * 10 - 0.8), V(x + 3.2, h, z + sz * 10 + 0.8), WALNUT, SOLID_WOOD)
	end
	Kit.Box(m, V(x - 3.6, h, z - 11), V(x + 3.6, h + 1.4, z + 11), WALNUT, { Mat = WOOD })
	Kit.Box(m, V(x - 3.7, h + 0.4, z - 11.1), V(x + 3.7, h + 0.9, z + 11.1), brass, BRASS_M)
	Kit.Ball(m, 2.4, V(x, h + 2.6, z), brass, BRASS_M)
	local rows = math.floor((h - 1) / 6.5)
	for k = 0, rows - 1 do
		local y = 0.6 + k * 6.5
		Kit.Box(m, V(x - 3, y - 0.4, z - 9.2), V(x + 3, y, z + 9.2), WALNUT, { Mat = WOOD })
		for _, s in { -1, 1 } do
			local cf = CFrame.new(x + s * 1.9, y, z) * CFrame.Angles(0, math.pi / 2, 0)
			bookRow(m, cf, 18, 2.2, 6, if k == 0 then 3 else 2)
		end
	end
	Kit.AddCircle(x, z, 11)
end

-- Stone fireplace against the left shelves with two armchairs (the cosy corner).
local function fireplace(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "Fireplace")
	local stone = C(150, 135, 130)
	Kit.Box(m, V(x - 4, 0, z - 9), V(x + 1, 16, z + 9), stone, { Mat = Enum.Material.Cobblestone, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 2, 30, z - 4), V(x + 0.5, 16, z + 4), stone, { Mat = Enum.Material.Cobblestone })
	Kit.Box(m, V(x + 1, 0, z - 5), V(x + 1.2, 8, z + 5), C(35, 25, 25))
	Kit.Box(m, V(x + 1, 8, z - 10), V(x + 3, 9, z + 10), WALNUT, { Mat = WOOD })
	local fire = Kit.Ball(m, 3.2, V(x + 0.6, 1.6, z), C(255, 170, 80), { Mat = NEON })
	Kit.Light(fire, C(255, 170, 90), 26, 1.2, true)
	for _, dz in { -2, 0, 2 } do
		Kit.Part(m, V(0.6, 3.2, 0.6), CFrame.new(x + 1.6, 10.6, z + dz), Kit.Pick(BOOKS), { Mat = FABRIC })
	end
	Kit.Part(m, V(0.4, 6, 5), CFrame.new(x + 1.3, 22, z), C(60, 90, 120), { Mat = FABRIC })
	for _, sz in { -1, 1 } do
		local cf = CFrame.new(x + 10, 0, z + sz * 8) * CFrame.Angles(0, Kit.FaceYaw(-1, -sz * 0.6), 0)
		Kit.Part(m, V(5, 2.6, 5), cf * CFrame.new(0, 1.3, 0), BURGUNDY, { Mat = FABRIC, Solid = true })
		Kit.Part(m, V(5, 5, 1.4), cf * CFrame.new(0, 4.6, 2), BURGUNDY, { Mat = FABRIC })
		for _, sx in { -1, 1 } do
			Kit.Part(m, V(1.2, 2, 5), cf * CFrame.new(sx * 2.5, 3.4, 0), C(100, 30, 45), { Mat = FABRIC })
		end
	end
	Kit.Box(m, V(x + 4, 0, z - 9), V(x + 14, 0.08, z + 9), TEAL_D, { Mat = FABRIC })
	Kit.AddCircle(x + 6, z, 11)
end

local function readingTable(parent: Instance, x: number, z: number, lit: boolean)
	local m = Kit.Model(parent, "ReadingTable")
	Kit.Box(m, V(x - 3, 3.2, z - 6), V(x + 3, 3.8, z + 6), WALNUT, { Mat = WOOD, Solid = true, Shadow = true })
	for _, sz in { -1, 1 } do
		Kit.Box(m, V(x - 2.6, 0, z + sz * 5 - 0.5), V(x + 2.6, 3.2, z + sz * 5 + 0.5), WALNUT_D, { Mat = WOOD, Solid = true })
	end
	bankerLamp(m, V(x, 3.8, z - 3), lit)
	flyingBook(m, V(x, 4, z + 2.5), 0, 1.6, Kit.Pick(BOOKS))
	Kit.Part(m, V(1.6, 1.2, 2.2), CFrame.new(x + 1.6, 4.4, z + 4.4), Kit.Pick(BOOKS), { Mat = FABRIC })
	for _, sx in { -1, 1 } do
		Kit.Box(m, V(x + sx * 4.6 - 1.2, 0, z - 1.2), V(x + sx * 4.6 + 1.2, 2.4, z + 1.2), BURGUNDY, { Mat = FABRIC })
		Kit.Box(m, V(x + sx * 5.6 - 0.25, 2.4, z - 1.2), V(x + sx * 5.6 + 0.25, 5.4, z + 1.2), WALNUT_D, { Mat = WOOD })
	end
	Kit.AddCircle(x, z, 7)
end

local function floorLamp(parent: Instance, x: number, z: number, lit: boolean)
	local brass = Kit.Vivid(BRASS)
	Kit.Cyl(parent, 0.5, 2.4, CFrame.new(x, 0.25, z), brass, BRASS_M)
	Kit.Cyl(parent, 12, 0.4, CFrame.new(x, 6, z), brass, BRASS_M)
	Kit.Cyl(parent, 2.2, 3.4, CFrame.new(x, 12.4, z), LAMP_GREEN, { Mat = GLASS, Refl = 0.2 })
	local bulb = Kit.Ball(parent, 1.4, V(x, 11.4, z), WARM, if lit then { Mat = NEON } else nil)
	if lit then
		Kit.Light(bulb, WARM, 22, 1)
	end
	Kit.AddCircle(x, z, 2)
end

-- Spiral staircase around a brass column up to a round reading balcony at Y ~30.
local function spiral(parent: Instance, x: number, z: number, turnDir: number)
	local m = Kit.Model(parent, "SpiralStairs")
	local brass = Kit.Vivid(BRASS)
	local top = 30
	local steps = 22
	Kit.Cyl(m, top + 6, 2.4, CFrame.new(x, (top + 6) / 2, z), brass, BRASS_M)
	for i = 0, steps - 1 do
		local a = turnDir * i * (math.pi * 2.2 / steps)
		local y = (i + 1) * top / steps
		local cf = CFrame.new(x, y - 0.35, z) * CFrame.Angles(0, a, 0) * CFrame.new(3.6, 0, 0)
		Kit.Part(m, V(6, 0.7, 2.4), cf, if i % 2 == 0 then WALNUT else WALNUT_D, { Mat = WOOD, Solid = true })
		if i % 2 == 1 then
			Kit.Part(m, V(0.3, 3.4, 0.3), cf * CFrame.new(2.8, 2, 0), brass, BRASS_M)
		end
	end
	-- balcony with a railing ring and a little reading lamp
	Kit.Disc(m, x, z, top + 0.4, 15, 0.8, WALNUT, { Mat = WOOD, Solid = true })
	Kit.Cyl(m, 0.4, 15.6, CFrame.new(x, top + 3.6, z), brass, BRASS_M)
	Kit.Cyl(m, 0.3, 14.8, CFrame.new(x, top + 3.6, z), WALNUT_D)
	for k = 0, 5 do
		local a = k * math.pi / 3
		Kit.Part(m, V(0.3, 3.2, 0.3), CFrame.new(x + math.cos(a) * 7.4, top + 2, z + math.sin(a) * 7.4), brass, BRASS_M)
	end
	floorLamp(m, x + 4, z + 3, false)
	Kit.AddCircle(x, z, 8)
end

local function bookStack(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "GiantBookStack")
	local y = 0
	local rng = Kit.Rng
	for i = 1, 6 do
		local w, d, h = 20 - i * 1.6, 15 - i * 1.1, rng:NextNumber(3.6, 5.2)
		local cf = CFrame.new(x + rng:NextNumber(-1.2, 1.2), y + h / 2, z + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		Kit.Part(m, V(w, h, d), cf, BOOKS[(i * 2) % #BOOKS + 1], { Mat = FABRIC, Solid = true, Shadow = true })
		Kit.Part(m, V(w - 1, h - 0.8, d + 0.1), cf * CFrame.new(0.6, 0, 0), CREAM)
		y += h
	end
	-- a candle on top
	Kit.Cyl(m, 5, 2.2, CFrame.new(x, y + 2.5, z), C(250, 245, 230))
	Kit.Ball(m, 1.2, V(x, y + 5.7, z), C(255, 210, 120), { Mat = NEON })
	Kit.AddCircle(x, z, 11)
end

local function inkAndQuill(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "InkAndQuill")
	Kit.Cyl(m, 7, 9, CFrame.new(x, 3.5, z), INK, { Mat = GLASS, Refl = 0.25, Solid = true })
	Kit.Cyl(m, 2, 5, CFrame.new(x, 8, z), INK, { Mat = GLASS, Refl = 0.25 })
	Kit.Cyl(m, 1, 5.6, CFrame.new(x, 9.3, z), Kit.Vivid(BRASS), BRASS_M)
	Kit.Disc(m, x, z, 7.1, 7.8, 0.1, C(30, 30, 70))
	local base = V(x + 0.6, 7, z)
	Props.Beam(m, base, base + V(5, 24, 3), 0.4, 0.4, CREAM)
	for k = 1, 4 do
		local t = k / 5
		local p = base + V(5, 24, 3) * (0.35 + t * 0.6)
		Kit.Part(m, V(5 - k * 0.7, 0.2, 2.6), CFrame.lookAt(p, p + V(5, 24, 3)) * CFrame.Angles(0, 0, 0.3), C(240, 240, 250))
	end
	Kit.AddCircle(x, z, 6)
end

local function globe(parent: Instance, x: number, z: number)
	local brass = Kit.Vivid(BRASS)
	Kit.Cyl(parent, 1, 5, CFrame.new(x, 0.5, z), WALNUT_D, { Mat = WOOD, Solid = true })
	Kit.Cyl(parent, 6, 0.8, CFrame.new(x, 4, z), brass, BRASS_M)
	Kit.Ball(parent, 8, V(x, 11, z), C(60, 130, 160))
	Kit.Ball(parent, 4.2, V(x + 2.4, 12.4, z - 1.6), C(110, 170, 90))
	Kit.Part(parent, V(0.5, 10, 10), CFrame.new(x, 11, z) * CFrame.Angles(0.4, 0, 0), brass, { Mat = METAL, Transp = 0.1 })
	Kit.AddCircle(x, z, 4)
end

-- The Grand Grimoire floating open above the boss rosette (all parts above Y 46).
local function grimoire(parent: Instance)
	local m = Kit.Model(parent, "FloatingGrimoire")
	local brass = Kit.Vivid(BRASS)
	local c = V(0, 58, BOSS_Z + 6)
	local base = CFrame.new(c) * CFrame.Angles(-0.5, 0, 0)
	for _, s in { -1, 1 } do
		local half = base * CFrame.Angles(0, 0, s * 0.18) * CFrame.new(s * 11, 0, 0)
		Kit.Part(m, V(22, 1, 30), half, C(110, 60, 45), { Mat = Enum.Material.Leather })
		Kit.Part(m, V(20.5, 1.6, 28), half * CFrame.new(-s * 0.2, 1.2, 0), CREAM)
		for _, sz in { -1, 1 } do
			Kit.Part(m, V(3, 1.2, 3), half * CFrame.new(s * 9.8, 0, sz * 13.8), brass, BRASS_M)
		end
		-- text lines (flat strips) on each page
		for k = 0, 4 do
			Kit.Part(m, V(15, 0.1, 0.6), half * CFrame.new(-s * 0.5, 2.05, -9 + k * 4.4), C(70, 60, 80))
		end
	end
	Kit.Part(m, V(2.4, 2.4, 30), base * CFrame.new(0, -0.2, 0), C(90, 45, 35), { Mat = Enum.Material.Leather })
	Kit.Part(m, V(1.2, 0.1, 18), base * CFrame.new(0, 2.2, 6) * CFrame.Angles(0.6, 0, 0), BURGUNDY, { Mat = FABRIC })
	local eye = Kit.Ball(m, 3, (base * CFrame.new(0, -1.4, 0)).Position, Kit.Vivid(MINT), { Mat = NEON })
	Kit.Light(eye, MINT, 50, 1)
	-- loose glowing letters drifting up out of the pages
	for k = 1, 10 do
		local p = c + V(Kit.Rng:NextNumber(-18, 18), Kit.Rng:NextNumber(6, 22), Kit.Rng:NextNumber(-10, 10))
		Kit.Part(m, V(1.2, 1.6, 0.2), CFrame.new(p) * CFrame.Angles(0, Kit.Rng:NextNumber(0, 6), Kit.Rng:NextNumber(-0.5, 0.5)), if k % 3 == 0 then MINT else C(210, 255, 240), if k % 3 == 0 then { Mat = NEON } else nil)
	end
	local dust = Kit.Part(m, V(40, 2, 30), CFrame.new(c + V(0, 4, 0)), MINT, { Transp = 1, Name = "PageDust" })
	Kit.Emitter(dust, C(190, 255, 235), 3, 1.6, 0.8)
end

-- A slow ribbon of open books flying through the hall (above Y 42 over any ghost area).
local function flyingBooks(f: Instance)
	local rng = Kit.Rng
	for i = 1, 32 do
		local t = i / 32
		local z = Z0 + 20 + t * (Z1 - Z0 - 50)
		local x = math.sin(t * math.pi * 5) * 70 + rng:NextNumber(-12, 12)
		local y = 22 + math.cos(t * math.pi * 3) * 9 + rng:NextNumber(-2, 8)
		if not clearOfAreas(x, z, 4) then
			y = rng:NextNumber(44, 60)
		end
		if math.abs(x) < 12 and y < 14 then
			y = 16
		end
		local yaw = math.atan2(math.cos(t * math.pi * 5), 1) + rng:NextNumber(-0.4, 0.4)
		flyingBook(f, V(x, y, z), yaw, rng:NextNumber(2.8, 4.4), Kit.Pick(BOOKS))
	end
	-- a few tagged (bobbing) single books and loose pages
	for _, p in { V(-40, 18, Z0 + 60), V(46, 24, Z0 + 120), V(-30, 28, Z0 + 200) } do
		Props.FloatingBook(f, p)
	end
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-125, 125), rng:NextNumber(Z0 + 20, Z1 - 30)
		local y = if clearOfAreas(x, z, 3) then rng:NextNumber(8, 36) else rng:NextNumber(43, 56)
		Kit.Part(f, V(1.4, 0.06, 1.9), CFrame.new(x, y, z) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)), CREAM, { Name = "LoosePage" })
	end
end

local function decor(f: Instance)
	local ni = 0
	for _, p in { { 42, Z0 + 140 }, { -40, Z0 + 165 }, { 42, Z0 + 228 }, { -110, Z0 + 60 }, { 112, Z0 + 95 }, { 118, Z0 + 250 }, { -122, Z0 + 180 }, { 40, Z0 + 290 }, { -40, Z0 + 300 } } do
		if ni < 8 and Kit.IsFree(p[1], p[2], 11) then
			ni += 1
			island(f, p[1], p[2], if ni % 3 == 0 then 33 else 26.6)
		end
	end
	local nt = 0
	for _, p in { { 60, Z0 + 58 }, { -62, Z0 + 64 }, { 118, Z0 + 175 }, { -112, Z0 + 255 }, { 70, Z0 + 320 }, { -66, Z0 + 330 }, { 24, Z0 + 190 }, { -24, Z0 + 215 } } do
		if nt < 6 and Kit.IsFree(p[1], p[2], 7) then
			nt += 1
			readingTable(f, p[1], p[2], nt % 2 == 1)
		end
	end
	local nl = 0
	for z = Z0 + 50, Z1 - 30, 36 do
		for _, s in { -1, 1 } do
			if Kit.IsFree(s * 14, z, 2) then
				nl += 1
				floorLamp(f, s * 14, z, nl % 4 == 1)
			end
		end
	end
	if Kit.IsFree(100, Z0 + 30, 8) then
		spiral(f, 100, Z0 + 30, 1)
	end
	if Kit.IsFree(-104, Z0 + 312, 8) then
		spiral(f, -104, Z0 + 312, -1)
	end
	if Kit.IsFree(110, Z0 + 330, 11) then
		bookStack(f, 110, Z0 + 330)
	end
	if Kit.IsFree(-118, Z0 + 125 + 30, 6) then
		inkAndQuill(f, -118, Z0 + 155)
	end
	if Kit.IsFree(-60, Z0 + 32 + 2, 4) then
		globe(f, -60, Z0 + 34)
	end
	if Kit.IsFree(-124, Z0 + 70, 9) then
		fireplace(f, -133, Z0 + 70)
	end
	grimoire(f)
end

--==================================================================
-- BUILD
--==================================================================
function PhantomLibrary.Build(map: Instance)
	local f = Kit.Folder(map, "PhantomLibrary")
	ground(f)
	wallShelves(f)
	ribs(f)
	outside(f)
	decor(f)
	flyingBooks(f)
end

return PhantomLibrary
