--!strict
-- ZONE 19: Upside-Down Manor (Z 7720..8080). Gravity got confused: a whole manor house hangs
-- upside-down from a floating lawn high above (roof pointing down, ~Y 78..160), two of its rooms
-- float overhead with their furniture stuck to the "ceiling", and down here on the checkered
-- floor everything grows the wrong way: chandeliers sprout up from the floor, trees stand on
-- their leafy heads with their roots in the air, the furniture is flipped over.
--   Ghost areas are flat plaster ceiling roses lying on the floor ((0,7805) r30, (-82,7840)
--   r24, (75,7900) r26, (-62,7960) r24); the boss area (0,8025) r26 is the grand ceiling
--   medallion. Nothing below Y 40 stands inside a circle (the manor and rooms are far above).
--   Plum striped wallpaper walls with the skirting board at the TOP and the crown molding at
--   the bottom, upside-down portraits and windows (curtains hang up), a staircase to nowhere.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local UpsideManor = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local MARBLE = Enum.Material.Marble
local GLASS = Enum.Material.Glass

local Z0, Z1 = 7720, 8080
local WALL_H = 40

local FLOOR_L = C(236, 228, 214)
local FLOOR_D = C(52, 44, 62)
local PLUM = C(98, 52, 98)
local PLUM_D = C(70, 36, 72)
local MINT = C(150, 225, 195)
local PEACH = C(250, 188, 160)
local CREAM = C(246, 238, 222)
local DARKWOOD = C(74, 46, 40)
local BRASS = C(222, 182, 104)
local LILAC = C(200, 160, 255)
local LEAF = C(130, 200, 170)
local LEAF2 = C(190, 150, 230)
local BARK = C(96, 68, 58)
local WARM = C(255, 214, 150)
local STONE = C(140, 120, 150)
local GRASS = C(110, 170, 120)
local DIRT = C(110, 80, 70)

local BRASS_M: Kit.Opts = { Mat = METAL, Refl = 0.15 }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
-- Chandelier growing up out of the floor: a ceiling rose on the floor, the chain going up, and
-- the chandelier on top with its candles hanging DOWN and crystal drops pointing UP.
local function floorChandelier(parent: Instance, x: number, z: number, h: number, lit: boolean)
	local m = Kit.Model(parent, "FloorChandelier")
	local brass = Kit.Vivid(BRASS)
	Kit.Disc(m, x, z, 0.5, 5, 0.5, CREAM, { Mat = MARBLE })
	Kit.Cyl(m, h, 0.45, CFrame.new(x, h / 2, z), brass, BRASS_M)
	Kit.Cyl(m, 0.8, 9, CFrame.new(x, h, z), brass, BRASS_M)
	Kit.Ball(m, 2.2, V(x, h + 0.2, z), brass, BRASS_M)
	for i = 0, 5 do
		local a = i * math.pi / 3
		local cx, cz = x + math.cos(a) * 4.2, z + math.sin(a) * 4.2
		Kit.Cyl(m, 1.8, 0.6, CFrame.new(cx, h - 1.3, cz), CREAM)
		Kit.Ball(m, 0.7, V(cx, h - 2.5, cz), WARM, if lit and i % 2 == 0 then { Mat = NEON } else nil)
		Kit.Part(m, V(0.5, 1.4, 0.5), CFrame.new(x + math.cos(a + 0.5) * 2.6, h + 1.5, z + math.sin(a + 0.5) * 2.6) * CFrame.Angles(0, a, math.pi / 4), Kit.Vivid(LILAC), { Mat = GLASS, Transp = 0.2, Refl = 0.3 })
	end
	Kit.AddCircle(x, z, 5.5)
end

-- Tree standing on its canopy with the roots up in the air.
local function headstandTree(parent: Instance, x: number, z: number, h: number, leaf: Color3)
	local m = Kit.Model(parent, "UpsideDownTree")
	local rng = Kit.Rng
	Kit.Ball(m, h * 0.55, V(x, h * 0.2, z), leaf, { Mat = Enum.Material.LeafyGrass })
	Kit.Ball(m, h * 0.4, V(x + h * 0.25, h * 0.14, z - h * 0.12), leaf:Lerp(C(255, 255, 255), 0.12), { Mat = Enum.Material.LeafyGrass })
	Kit.Ball(m, h * 0.38, V(x - h * 0.22, h * 0.12, z + h * 0.14), leaf:Lerp(C(0, 0, 0), 0.1), { Mat = Enum.Material.LeafyGrass })
	Kit.Cyl(m, h * 0.6, h * 0.1, CFrame.new(x, h * 0.6, z), BARK, { Mat = WOOD, Solid = true })
	local top = V(x, h * 0.9, z)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5 + rng:NextNumber(-0.3, 0.3)
		local tip = top + V(math.cos(a) * h * 0.3, h * rng:NextNumber(0.12, 0.25), math.sin(a) * h * 0.3)
		Props.Beam(m, top, tip, h * 0.05, h * 0.05, BARK, { Mat = WOOD })
	end
	Kit.Ball(m, h * 0.16, top + V(0, h * 0.04, 0), DIRT, { Mat = Enum.Material.Ground })
	Kit.AddCircle(x, z, h * 0.3)
end

-- Flipped-over furniture lying on the floor (kind 1..4).
local function flipped(parent: Instance, x: number, z: number, kind: number, yaw: number)
	local m = Kit.Model(parent, "FlippedFurniture")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	if kind == 1 then -- armchair on its back... upside down, legs in the air
		Kit.Part(m, V(5, 2.4, 5), cf * CFrame.new(0, 1.2, 0), PEACH, { Mat = FABRIC, Solid = true })
		Kit.Part(m, V(5, 1.2, 5), cf * CFrame.new(0, 3, 0), PLUM, { Mat = FABRIC })
		Kit.Part(m, V(5, 4, 1.2), cf * CFrame.new(0, 2, 2.2), PEACH, { Mat = FABRIC })
		for _, sx in { -2, 2 } do
			for _, sz in { -2, 2 } do
				Kit.Part(m, V(0.5, 1.6, 0.5), cf * CFrame.new(sx, 4.4, sz), DARKWOOD, { Mat = WOOD })
			end
		end
	elseif kind == 2 then -- dining table with its cloth, plates and teapot stuck underneath
		Kit.Part(m, V(10, 0.6, 6), cf * CFrame.new(0, 0.3, 0), DARKWOOD, { Mat = WOOD, Solid = true })
		Kit.Part(m, V(10.4, 0.1, 6.4), cf * CFrame.new(0, 0.62, 0), CREAM, { Mat = FABRIC })
		for _, sx in { -4.4, 4.4 } do
			for _, sz in { -2.4, 2.4 } do
				Kit.Part(m, V(0.7, 4.5, 0.7), cf * CFrame.new(sx, 2.9, sz), DARKWOOD, { Mat = WOOD })
			end
		end
		Kit.Ball(m, 1.8, (cf * CFrame.new(-2, 7.2, 0)).Position, MINT)
		Kit.Disc(m, (cf * CFrame.new(2, 0, 0)).X, (cf * CFrame.new(2, 0, 0)).Z, 5.6, 2.2, 0.2, CREAM)
	elseif kind == 3 then -- floor lamp standing on its shade
		Kit.Cyl(m, 3, 4, cf * CFrame.new(0, 1.5, 0), PEACH, { Mat = FABRIC, Solid = true })
		Kit.Cyl(m, 9, 0.4, cf * CFrame.new(0, 7.5, 0), Kit.Vivid(BRASS), BRASS_M)
		Kit.Cyl(m, 0.5, 2.6, cf * CFrame.new(0, 12.2, 0), Kit.Vivid(BRASS), BRASS_M)
	else -- clawfoot bathtub upside down, feet up
		Kit.Part(m, V(9, 3.4, 4.6), cf * CFrame.new(0, 1.7, 0), CREAM, { Solid = true })
		Kit.Part(m, V(8, 0.6, 3.6), cf * CFrame.new(0, 3.6, 0), CREAM)
		for _, sx in { -3.4, 3.4 } do
			for _, sz in { -1.6, 1.6 } do
				Kit.Ball(m, 1, (cf * CFrame.new(sx, 4.4, sz)).Position, Kit.Vivid(BRASS), BRASS_M)
			end
		end
		Kit.Ball(m, 1.6, (cf * CFrame.new(-4.4, 0.9, 0)).Position, C(160, 220, 255), { Transp = 0.3 })
	end
	Kit.AddCircle(x, z, 6)
end

-- Portrait hung upside-down on a side wall (s = -1 left wall, 1 right wall).
local function portrait(parent: Instance, s: number, z: number, y: number, face: Color3)
	local x = s * 139.6
	Kit.Box(parent, V(x - 0.3, y - 5, z - 4), V(x + 0.3, y + 5, z + 4), Kit.Vivid(BRASS), BRASS_M)
	Kit.Box(parent, V(x - s * 0.4 - 0.2, y - 4.2, z - 3.2), V(x - s * 0.4 + 0.2, y + 4.2, z + 3.2), C(60, 70, 90))
	-- a friendly ghost face, upside-down (eyes below the mouth)
	local px = x - s * 0.7
	Kit.Box(parent, V(px - 0.1, y - 3, z - 2.2), V(px + 0.1, y + 2.6, z + 2.2), face)
	for _, dz in { -1, 1 } do
		Kit.Box(parent, V(px - s * 0.15 - 0.1, y - 1.6, z + dz - 0.4), V(px - s * 0.15 + 0.1, y - 0.6, z + dz + 0.4), C(40, 30, 50))
	end
	Kit.Box(parent, V(px - s * 0.15 - 0.1, y + 0.6, z - 0.9), V(px - s * 0.15 + 0.1, y + 1, z + 0.9), C(40, 30, 50))
end

--==================================================================
-- GROUND AND WALLS
--==================================================================
local function ground(f: Instance)
	local brass = Kit.Vivid(BRASS)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), FLOOR_L, { Mat = MARBLE, Solid = true, Name = "Ground_UpsideManor" })
	-- big checker tiles (dark squares only)
	for ix = -6, 5 do
		for iz = 0, 11 do
			if (ix + iz) % 2 == 0 then
				local x, z = ix * 30 + 15, Z0 + iz * 30 + 15
				Kit.Part(f, V(30, 0.04, 30), CFrame.new(x, 0.02, z), FLOOR_D, { Mat = MARBLE })
			end
		end
	end
	-- long hall runner
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.1, Z1), PEACH, { Mat = FABRIC, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.6, 0.12, Z1), Kit.Vivid(MINT), { Mat = FABRIC })
		Kit.Box(f, V(s * 5.8, 0, Z0), V(s * 6.3, 0.12, Z1), PLUM, { Mat = FABRIC })
	end
	-- ceiling roses lying on the floor (ghost areas)
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.08, r * 2 + 2, 0.08, CREAM, { Mat = MARBLE })
		Kit.Disc(f, x, z, 0.11, r * 2 - 2, 0.03, if i % 2 == 0 then MINT else LILAC, { Mat = MARBLE })
		Kit.Disc(f, x, z, 0.13, r * 2 - 4, 0.05, CREAM, { Mat = MARBLE })
		for k = 0, 11 do
			local ang = k * math.pi / 6
			Kit.Part(f, V(r * 0.28, 0.05, r * 0.7), CFrame.new(x + math.cos(ang) * r * 0.5, 0.15, z + math.sin(ang) * r * 0.5) * CFrame.Angles(0, -ang + math.pi / 2, 0), if k % 2 == 0 then PEACH else (if i % 2 == 0 then MINT else LILAC), { Mat = MARBLE })
		end
		Kit.Disc(f, x, z, 0.19, 7, 0.05, brass, BRASS_M)
	end
	-- boss: grand medallion with a flat chandelier mount and petals
	Kit.Disc(f, 0, BOSS_Z, 0.08, 58, 0.08, brass, BRASS_M)
	Kit.Disc(f, 0, BOSS_Z, 0.11, 55, 0.11, CREAM, { Mat = MARBLE })
	Kit.Disc(f, 0, BOSS_Z, 0.13, 48, 0.03, PLUM, { Mat = MARBLE })
	Kit.Disc(f, 0, BOSS_Z, 0.15, 46, 0.05, CREAM, { Mat = MARBLE })
	for k = 0, 15 do
		local ang = k * math.pi / 8
		Kit.Part(f, V(4, 0.05, 11), CFrame.new(math.cos(ang) * 16, 0.17, BOSS_Z + math.sin(ang) * 16) * CFrame.Angles(0, -ang + math.pi / 2, 0), if k % 2 == 0 then LILAC else PEACH, { Mat = MARBLE })
	end
	Kit.Disc(f, 0, BOSS_Z, 0.2, 14, 0.05, brass, BRASS_M)
	Kit.Disc(f, 0, BOSS_Z, 0.22, 8, 0.05, PLUM_D, { Mat = MARBLE })
end

local function sideWalls(f: Instance)
	local brass = Kit.Vivid(BRASS)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, WALL_H, z1), PLUM, { Mat = FABRIC, Solid = true, Shadow = true })
		-- skirting board on top, crown molding at the bottom (the room is upside-down)
		Kit.Box(f, V(s * 139, WALL_H - 7, z0), V(s * 140, WALL_H, z1), DARKWOOD, { Mat = WOOD })
		Kit.Box(f, V(s * 138.8, WALL_H - 7.6, z0), V(s * 139.4, WALL_H - 7, z1), brass, BRASS_M)
		Kit.Box(f, V(s * 138.6, 0, z0), V(s * 140, 2.4, z1), CREAM, { Mat = MARBLE })
		Kit.Wedge(f, V(z1 - z0, 1.6, 1.6), CFrame.new(s * 138.8, 3.2, (z0 + z1) / 2) * CFrame.Angles(math.pi, Kit.FaceYaw(s, 0), 0), CREAM, { Mat = MARBLE })
		Kit.Box(f, V(s * 139, WALL_H, z0), V(s * 147, WALL_H + 1.2, z1), CREAM, { Mat = MARBLE })
		-- mint wallpaper stripes
		for z = z0 + 6, z1 - 3, 12 do
			Kit.Box(f, V(s * 139.85, 4, z - 1), V(s * 140, WALL_H - 7.6, z + 1), MINT, { Mat = FABRIC })
		end
		-- upside-down windows: the sill on top, curtains hanging UP
		local i = 0
		for z = z0 + 30, z1 - 20, 64 do
			i += 1
			Kit.Box(f, V(s * 139.5, 9, z - 6), V(s * 139.9, 27, z + 6), C(60, 50, 110), { Mat = GLASS, Refl = 0.2 })
			Kit.Box(f, V(s * 139.2, 8.4, z - 6.6), V(s * 139.6, 9, z + 6.6), CREAM)
			Kit.Box(f, V(s * 138.8, 27, z - 7.4), V(s * 139.6, 28, z + 7.4), CREAM)
			Kit.Box(f, V(s * 139.3, 17.7, z - 6), V(s * 139.5, 18.3, z + 6), CREAM)
			for _, dz in { -1, 1 } do
				Kit.Box(f, V(s * 138.6, 4, z + dz * 7 - 1.6), V(s * 139.2, 22, z + dz * 7 + 1.6), if i % 2 == 0 then PEACH else C(120, 190, 160), { Mat = FABRIC })
			end
			-- a little moon outside one window
			if i == 2 then
				Kit.Ball(f, 3, V(s * 140.6, 14, z + 2), C(255, 245, 210), { Mat = NEON })
			end
		end
		-- upside-down portraits between the windows
		for z = z0 + 62, z1 - 30, 64 do
			portrait(f, s, z, 20, Kit.Pick({ CREAM, C(225, 235, 255), C(255, 230, 240) }))
		end
	end
end

--==================================================================
-- THE HANGING MANOR (all of it above Y 70)
--==================================================================
local function hangingManor(f: Instance)
	local m = Kit.Model(f, "HangingManor")
	local brass = Kit.Vivid(BRASS)
	local zc = Z0 + 195
	local LAWN = 132 -- underside of the floating lawn
	local wallTop = LAWN -- house "floor" is at the lawn
	local wallBot = LAWN - 30
	-- floating lawn island: grass face pointing down, rocky cone rising into the sky
	Kit.Cyl(m, 2, 150, CFrame.new(0, LAWN + 1, zc), GRASS, { Mat = Enum.Material.Grass })
	Kit.Cyl(m, 6, 146, CFrame.new(0, LAWN + 5, zc), DIRT, { Mat = Enum.Material.Ground })
	for k = 0, 3 do
		Kit.Cyl(m, 9, 130 - k * 32, CFrame.new(k * 3, LAWN + 12.5 + k * 9, zc - k * 2), STONE:Lerp(DIRT, k * 0.2), { Mat = Enum.Material.Rock })
	end
	-- house walls (cream) with windows
	local hx, hz = 40, 26
	Kit.Box(m, V(-hx, wallBot, zc - hz), V(hx, wallTop, zc + hz), CREAM, { Mat = PLANKS })
	Kit.Box(m, V(-hx - 1, wallBot - 1.2, zc - hz - 1), V(hx + 1, wallBot, zc + hz + 1), PLUM_D, { Mat = WOOD })
	for _, wz in { zc - hz - 0.2, zc + hz + 0.2 } do
		for k = -3, 3 do
			if k ~= 0 then
				local lit = (k + 3) % 3 == 0
				Kit.Box(m, V(k * 11 - 3, wallBot + 5, wz - 0.3), V(k * 11 + 3, wallBot + 13, wz + 0.3), if lit then WARM else C(80, 70, 120), { Mat = GLASS })
				Kit.Box(m, V(k * 11 - 3, wallBot + 16, wz - 0.3), V(k * 11 + 3, wallBot + 24, wz + 0.3), if not lit then WARM else C(80, 70, 120), { Mat = GLASS })
			end
		end
	end
	-- front door near the lawn (upside-down), with steps hanging off the lawn
	local fz = zc - hz - 0.4
	Kit.Box(m, V(-5, wallTop - 14, fz - 0.4), V(5, wallTop, fz), PLUM, { Mat = WOOD })
	Kit.Ball(m, 1, V(3, wallTop - 9, fz - 0.6), brass, BRASS_M)
	for k = 0, 2 do
		Kit.Box(m, V(-8 + k, wallTop - 0.1 - k * 1.2, fz - 4 - k * 2.4), V(8 - k, wallTop - 1.2 - k * 1.2, fz), STONE, { Mat = Enum.Material.Cobblestone })
	end
	-- roof pointing down: two slopes meeting in an upside-down ridge
	local rH = 22
	for _, s in { -1, 1 } do
		local cf = CFrame.new(0, wallBot - 1.2 - rH / 2, zc + s * (hz + 2) / 2) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0) * CFrame.Angles(0, 0, math.pi)
		Kit.Wedge(m, V(hx * 2 + 4, rH, hz + 2), cf, PLUM_D, { Mat = Enum.Material.RoofShingles })
	end
	Kit.Box(m, V(-hx - 2, wallBot - rH - 2.2, zc - 0.8), V(hx + 2, wallBot - rH - 1, zc + 0.8), brass, BRASS_M)
	-- chimneys pointing down, one puffing smoke downwards... sideways
	for _, cx in { -26, 24 } do
		Kit.Box(m, V(cx - 3, wallBot - 30, zc + 6), V(cx + 3, wallBot - 6, zc + 12), C(150, 80, 70), { Mat = Enum.Material.Brick })
		Kit.Box(m, V(cx - 3.6, wallBot - 31.4, zc + 5.4), V(cx + 3.6, wallBot - 30, zc + 12.6), STONE)
	end
	-- trees hanging from the lawn around the house
	for _, p in { { -58, zc - 20 }, { 60, zc - 14 }, { -55, zc + 26 }, { 58, zc + 30 }, { 0, zc + 50 }, { -20, zc - 52 } } do
		local x, z = p[1], p[2]
		Kit.Cyl(m, 12, 2, CFrame.new(x, LAWN - 6, z), BARK, { Mat = WOOD })
		Kit.Ball(m, 14, V(x, LAWN - 16, z), Kit.Pick({ LEAF, LEAF2 }), { Mat = Enum.Material.LeafyGrass })
		Kit.Ball(m, 9, V(x + 4, LAWN - 22, z + 2), Kit.Pick({ LEAF, LEAF2 }), { Mat = Enum.Material.LeafyGrass })
	end
	-- a picket fence hanging along the front edge
	for k = -6, 6 do
		Kit.Box(m, V(k * 9 - 0.5, LAWN - 6, zc - 70), V(k * 9 + 0.5, LAWN, zc - 69), CREAM)
	end
	Kit.Box(m, V(-55, LAWN - 3.6, zc - 70), V(55, LAWN - 2.8, zc - 69), CREAM)
	-- a garden path of stepping stones on the lawn underside
	for k = 1, 4 do
		Kit.Disc(m, 0, zc - hz - 6 - k * 9, LAWN - 0.1, 5, 0.3, STONE)
	end
	local sparkle = Kit.Part(m, V(90, 4, 60), CFrame.new(0, wallBot - 10, zc), LILAC, { Transp = 1, Name = "TopsySparkles" })
	Kit.Emitter(sparkle, C(230, 210, 255), 3, 2, 0.8)
	local window = Kit.Part(m, V(1, 1, 1), CFrame.new(0, wallBot - 2, zc), WARM, { Transp = 1, Name = "ManorGlow" })
	Kit.Light(window, WARM, 60, 1)
end

-- A room floating overhead: floor slab with its furniture stuck to the underside.
local function floatingRoom(f: Instance, x: number, z: number, y: number, kind: number)
	local m = Kit.Model(f, "FloatingRoom")
	local brass = Kit.Vivid(BRASS)
	Kit.Box(m, V(x - 18, y, z - 15), V(x + 18, y + 2, z + 15), DARKWOOD, { Mat = PLANKS })
	Kit.Box(m, V(x - 12, y - 0.1, z - 9), V(x + 12, y, z + 9), if kind == 1 then PLUM else C(70, 120, 110), { Mat = FABRIC })
	-- one wall stub with a painting
	Kit.Box(m, V(x - 18, y - 16, z + 14), V(x + 18, y, z + 15), if kind == 1 then MINT else PEACH, { Mat = FABRIC })
	Kit.Box(m, V(x - 5, y - 12, z + 13.6), V(x + 5, y - 4, z + 14), brass, BRASS_M)
	Kit.Box(m, V(x - 4.2, y - 11.2, z + 13.4), V(x + 4.2, y - 4.8, z + 13.8), C(90, 140, 200))
	if kind == 1 then
		-- dining table + chairs + candelabra hanging down
		Kit.Box(m, V(x - 7, y - 5.2, z - 3.6), V(x + 7, y - 4.6, z + 3.6), DARKWOOD, { Mat = WOOD })
		for _, sx in { -6, 6 } do
			for _, sz in { -3, 3 } do
				Kit.Box(m, V(x + sx - 0.35, y - 4.6, z + sz - 0.35), V(x + sx + 0.35, y, z + sz + 0.35), DARKWOOD, { Mat = WOOD })
			end
		end
		for _, sx in { -4, 0, 4 } do
			for _, sz in { -1, 1 } do
				local cz = z + sz * 6
				Kit.Box(m, V(x + sx - 1.4, y - 3, cz - 1.4), V(x + sx + 1.4, y - 2.4, cz + 1.4), PEACH, { Mat = FABRIC })
				Kit.Box(m, V(x + sx - 1.4, y - 7, cz + sz * 1.2 - 0.3), V(x + sx + 1.4, y - 2.4, cz + sz * 1.2 + 0.3), DARKWOOD, { Mat = WOOD })
			end
		end
		Kit.Cyl(m, 2.6, 0.4, CFrame.new(x, y - 6.5, z), brass, BRASS_M)
		Kit.Ball(m, 0.8, V(x, y - 8.2, z), WARM, { Mat = NEON })
		Kit.Disc(m, x + 3, z, y - 5.2, 2.4, 0.2, CREAM)
	else
		-- sofa, side table with a lamp, and a rug
		Kit.Box(m, V(x - 9, y - 3.4, z + 4), V(x + 9, y, z + 10), PEACH, { Mat = FABRIC })
		Kit.Box(m, V(x - 9, y - 8, z + 9), V(x + 9, y - 3.4, z + 11), PEACH, { Mat = FABRIC })
		for _, sx in { -1, 1 } do
			Kit.Box(m, V(x + sx * 9 - 1, y - 6, z + 4), V(x + sx * 9 + 1, y - 3.4, z + 11), C(225, 160, 135), { Mat = FABRIC })
		end
		Kit.Box(m, V(x - 2.5, y - 4, z - 6), V(x + 2.5, y - 3.4, z - 1), DARKWOOD, { Mat = WOOD })
		Kit.Cyl(m, 3.4, 0.6, CFrame.new(x, y - 1.7, z - 3.5), DARKWOOD)
		Kit.Cyl(m, 3, 0.3, CFrame.new(x, y - 5.5, z - 3.5), brass, BRASS_M)
		Kit.Cyl(m, 2.2, 3, CFrame.new(x, y - 8, z - 3.5), MINT, { Mat = FABRIC })
	end
end

-- Grand staircase that climbs into the air and stops at a lonely door.
local function stairsToNowhere(f: Instance, x: number, z0: number)
	local m = Kit.Model(f, "StairsToNowhere")
	local brass = Kit.Vivid(BRASS)
	local steps = 16
	local rise, run = 2.2, 3
	for i = 0, steps - 1 do
		local z = z0 + i * run
		Kit.Box(m, V(x - 5, i * rise, z), V(x + 5, (i + 1) * rise, z + run), if i % 2 == 0 then CREAM else PEACH, { Mat = MARBLE, Solid = true, Shadow = true })
	end
	local topY = steps * rise
	local zTop = z0 + steps * run
	for _, s in { -1, 1 } do
		Props.Beam(m, V(x + s * 5, 3.4, z0), V(x + s * 5, topY + 3.4, zTop), 0.6, 0.6, brass, BRASS_M)
	end
	Kit.Box(m, V(x - 6, topY - 1, zTop), V(x + 6, topY, zTop + 8), PLUM_D, { Mat = WOOD, Solid = true })
	-- the door to nowhere, slightly crooked
	local dcf = CFrame.new(x, topY + 5, zTop + 6) * CFrame.Angles(0, 0, 0.12)
	Kit.Part(m, V(7, 10.6, 0.8), dcf, CREAM, { Mat = WOOD })
	Kit.Part(m, V(5.4, 9.4, 1), dcf * CFrame.new(0, -0.4, 0), PLUM, { Mat = WOOD })
	Kit.Ball(m, 0.7, (dcf * CFrame.new(1.8, -0.6, -0.6)).Position, brass, BRASS_M)
	Props.SignBoard(m, V(x, 3.2, z0 - 1.5), 8, 1.6, 0, -1, "THIS WAY UP?", PLUM_D, CREAM)
	Kit.AddRect(x - 6, z0 - 2, x + 6, zTop + 9)
end

local function decor(f: Instance)
	local rng = Kit.Rng
	-- welcome sign on posts that hang DOWN from the board
	local signZ = Z0 + 28
	if Kit.IsFree(-14, signZ, 1) then
		local sign = Props.SignBoard(f, V(0, 30, signZ), 28, 4.6, 0, -1, "UPSIDE-DOWN MANOR", PLUM_D, Kit.Vivid(LILAC), BRASS)
		Props.SignBoard(f, V(0, 30, signZ + 0.8), 28, 4.6, 0, 1, "MIND YOUR HEAD!", PLUM_D, CREAM)
		Kit.Light(sign, LILAC, 30, 0.8)
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * 12 - 0.5, 0, signZ - 0.5), V(s * 12 + 0.5, 27.7, signZ + 0.5), Kit.Vivid(BRASS), { Mat = METAL, Solid = true })
			Kit.Ball(f, 1.6, V(s * 12, 0.5, signZ), Kit.Vivid(BRASS), BRASS_M)
		end
		Kit.AddCircle(-12, signZ, 1)
		Kit.AddCircle(12, signZ, 1)
	end
	local nc = 0
	for _, p in { { 16, Z0 + 140 }, { -16, Z0 + 160 }, { 16, Z0 + 215 }, { -16, Z0 + 268 }, { 18, Z0 + 262 }, { 44, Z0 + 50 }, { -110, Z0 + 40 }, { 112, Z0 + 120 }, { -112, Z0 + 200 }, { 112, Z0 + 250 }, { -115, Z0 + 300 }, { 60, Z0 + 330 } } do
		if nc < 10 and Kit.IsFree(p[1], p[2], 5.5) then
			nc += 1
			floorChandelier(f, p[1], p[2], rng:NextNumber(9, 15), nc % 3 == 1)
		end
	end
	local nt = 0
	for _, p in { { -40, Z0 + 50 }, { 52, Z0 + 92 }, { -32, Z0 + 186 }, { 40, Z0 + 240 }, { -118, Z0 + 150 }, { 118, Z0 + 300 }, { -40, Z0 + 320 }, { 118, Z0 + 60 }, { -122, Z0 + 260 } } do
		if nt < 7 and Kit.IsFree(p[1], p[2], 6) then
			nt += 1
			headstandTree(f, p[1], p[2], rng:NextNumber(18, 26), if nt % 2 == 0 then LEAF else LEAF2)
		end
	end
	local nf = 0
	for _, p in { { 40, Z0 + 140 }, { -36, Z0 + 120 }, { 100, Z0 + 215 }, { -100, Z0 + 330 }, { 46, Z0 + 280 }, { -95, Z0 + 70 } } do
		if nf < 6 and Kit.IsFree(p[1], p[2], 6) then
			nf += 1
			flipped(f, p[1], p[2], (nf - 1) % 4 + 1, rng:NextNumber(0, math.pi * 2))
		end
	end
	if Kit.IsFree(110, Z0 + 150, 7) then
		stairsToNowhere(f, 110, Z0 + 140)
	end
	-- tumbling things in the air: teacups, picture frames, books (high up over ghost areas)
	for i = 1, 22 do
		local x, z = rng:NextNumber(-125, 125), rng:NextNumber(Z0 + 20, Z1 - 20)
		local y = rng:NextNumber(42, 70)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		local k = i % 3
		local p: BasePart
		if k == 0 then
			p = Kit.Cyl(f, 1.4, 1.6, cf, Kit.Pick({ MINT, PEACH, CREAM }), { Name = "TumblingCup" })
		elseif k == 1 then
			p = Kit.Part(f, V(4, 3, 0.4), cf, Kit.Vivid(BRASS), { Mat = METAL, Name = "TumblingFrame" })
		else
			p = Kit.Part(f, V(2, 0.6, 2.6), cf, Kit.Pick({ PLUM, C(90, 140, 200), PEACH }), { Name = "TumblingBook" })
		end
		if i <= 3 then
			Kit.Float(p, 1.5)
		end
	end
	floatingRoom(f, -78, Z0 + 95, 60, 1)
	floatingRoom(f, 80, Z0 + 290, 64, 2)
end

--==================================================================
-- BUILD
--==================================================================
function UpsideManor.Build(map: Instance)
	local f = Kit.Folder(map, "UpsideManor")
	ground(f)
	sideWalls(f)
	hangingManor(f)
	decor(f)
end

return UpsideManor
