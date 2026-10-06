--!strict
-- ZONE 19: Haunted Pumpkin Farm (Z 7720..8080). An autumn farm at night under a huge harvest
-- moon: dark tilled earth, a dirt farm road along X = 0 with split-rail fences, golden corn.
--   Ghost areas are flat crop circles pressed into straw ((0,7805) r30, (-82,7840) r24,
--   (75,7900) r26, (-62,7960) r24); the boss area (0,8025) r26 is a giant jack-o'-lantern crop
--   circle. Nothing taller than a flat mark stands inside them.
--   Front left: the big red barn (gable toward the road, hay loft, "OLD MACBOONALD'S"), the
--   silo and a farm windmill. Front right: the pumpkin patch with vines, giant pumpkins and a
--   scarecrow. Two low corn mazes (walls 5.5 high, generated, kept out of the ghost areas):
--   a small one left of the road between the second and fourth areas, a big one at the back
--   left. Back right: a red tractor pulling a hayride wagon, hay bale stacks, scarecrows.
--   A chicken coop and a well on the left, a pumpkin stand by the road, wooden plank side
--   walls with corn rows beyond them and the moon low in the sky to the left.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local PumpkinFarm = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local GRASS = Enum.Material.Grass
local GROUND = Enum.Material.Ground
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local Z0, Z1 = 7720, 8080

local EARTH = C(70, 46, 34)
local EARTH_D = C(52, 34, 26)
local ROAD = C(128, 92, 62)
local STRAW = C(214, 178, 96)
local STRAW_D = C(170, 132, 66)
local CORN = C(118, 128, 52)
local CORN_D = C(86, 96, 40)
local TASSEL = C(232, 196, 92)
local BARN = C(170, 44, 40)
local BARN_D = C(120, 30, 30)
local TRIM = C(240, 232, 214)
local ROOF = C(70, 62, 66)
local FENCE = C(118, 84, 56)
local FENCE_D = C(84, 60, 42)
local VINE = C(60, 110, 50)
local ORANGE = C(255, 140, 40)
local MOON = C(255, 238, 190)
local LAMP = C(255, 190, 110)
local DARK = C(30, 24, 26)
local TRACTOR = C(200, 40, 36)
local TIRE = C(36, 34, 38)
local PLAID = C(190, 60, 50)
local DENIM = C(70, 90, 140)

local WOOD_S: Kit.Opts = { Mat = PLANKS, Solid = true, Shadow = true }
local WOOD_O: Kit.Opts = { Mat = WOOD }
local METAL_O: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
-- Round hay bale lying on its side, axis along X or Z.
local function roundBale(parent: Instance, pos: Vector3, along: string)
	Kit.CylFlat(parent, 4, 5, pos + V(0, 2.5, 0), along, STRAW, { Mat = FABRIC, Solid = true })
	Kit.CylFlat(parent, 4.1, 3.2, pos + V(0, 2.5, 0), along, STRAW_D, { Mat = FABRIC })
end

-- Square hay bale (centre bottom at pos).
local function bale(parent: Instance, pos: Vector3, rot: number)
	local cf = CFrame.new(pos + V(0, 1.2, 0)) * CFrame.Angles(0, rot, 0)
	Kit.Part(parent, V(5, 2.4, 3), cf, STRAW, { Mat = FABRIC, Solid = true })
	Kit.Part(parent, V(0.3, 2.5, 3.05), cf * CFrame.new(-1.2, 0, 0), STRAW_D)
	Kit.Part(parent, V(0.3, 2.5, 3.05), cf * CFrame.new(1.2, 0, 0), STRAW_D)
end

-- Split-rail fence along a straight run (ground points, same Y).
local function railFence(parent: Instance, a: Vector3, b: Vector3)
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 8))
	for i = 0, n do
		local p = a + d * (i / n)
		Kit.Box(parent, p + V(-0.4, 0, -0.4), p + V(0.4, 4.2, 0.4), FENCE_D, WOOD_O)
	end
	for _, y in { 1.6, 3.3 } do
		Props.Beam(parent, a + V(0, y, 0), b + V(0, y - 0.2, 0), 0.5, 0.45, FENCE, WOOD_O)
	end
end

local function scarecrow(parent: Instance, x: number, z: number, face: number, big: number?)
	local s = big or 1
	local m = Kit.Model(parent, "Scarecrow")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, face, 0)
	local function at(px: number, py: number, pz: number): CFrame
		return base * CFrame.new(px * s, py * s, pz * s)
	end
	Kit.Part(m, V(0.6, 10, 0.6) * s, at(0, 5, 0.4), FENCE_D, { Mat = WOOD, Solid = true })
	Kit.Part(m, V(9, 0.5, 0.5) * s, at(0, 7, 0.4), FENCE_D, WOOD_O)
	-- plaid shirt, sleeves, overall bib, straw cuffs
	Kit.Part(m, V(2.8, 3.2, 1.6) * s, at(0, 6.2, 0), PLAID, { Mat = FABRIC })
	Kit.Part(m, V(2.4, 1.6, 1.7) * s, at(0, 5, 0), DENIM, { Mat = FABRIC })
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(3, 1.1, 1.1) * s, at(sx * 2.8, 7, 0.2), PLAID, { Mat = FABRIC })
		Kit.Part(m, V(1, 0.9, 0.9) * s, at(sx * 4.6, 6.9, 0.2) * CFrame.Angles(0, 0, sx * 0.4), STRAW)
		Kit.Part(m, V(1, 2.4, 1) * s, at(sx * 0.6, 3.2, 0), DENIM, { Mat = FABRIC })
		Kit.Ball(m, 0.5 * s, (at(sx * 0.45, 9.6, -1.05)).Position, DARK)
	end
	Kit.Part(m, V(1.4, 1, 0.8) * s, at(0, 2, 0) * CFrame.Angles(0, 0, 0.3), STRAW)
	-- burlap sack head with a stitched smile and a floppy hat
	Kit.Ball(m, 2.4 * s, (at(0, 9.3, 0)).Position, C(200, 170, 120), { Mat = FABRIC })
	Kit.Part(m, V(1.2, 0.2, 0.2) * s, at(0, 8.8, -1.15), DARK)
	Kit.Part(m, V(0.5, 0.5, 0.5) * s, at(0, 9.3, -1.2) * CFrame.Angles(0, 0, math.pi / 4), ORANGE)
	Kit.Cyl(m, 0.2 * s, 4 * s, at(0, 10.3, 0), C(150, 110, 60), { Mat = FABRIC })
	Kit.Cyl(m, 1.4 * s, 2 * s, at(0, 11, 0), C(150, 110, 60), { Mat = FABRIC })
	Kit.Cyl(m, 0.3 * s, 2.05 * s, at(0, 10.55, 0), BARN_D, { Mat = FABRIC })
	Kit.AddCircle(x, z, 5 * s)
end

-- Low corn wall from (x1, z1) to (x2, z2) (axis aligned), thickness t.
local function cornWall(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local t = 0.9
	local lo = V(math.min(x1, x2) - t, 0, math.min(z1, z2) - t)
	local hi = V(math.max(x1, x2) + t, 5.5, math.max(z1, z2) + t)
	Kit.Box(parent, lo, hi, CORN, { Mat = GRASS, Solid = true, Shadow = true })
	Kit.Box(parent, lo + V(0.2, 5.5, 0.2), hi + V(-0.2, 0.9, -0.2), TASSEL, { Mat = GRASS })
end

-- Generated corn maze: nx x nz cells of size s from corner (x0, z0) (+X / +Z). Openings on the
-- -Z and +Z sides at the given columns. Uses Kit.Rng, so it is the same every build.
local function cornMaze(parent: Instance, x0: number, z0: number, nx: number, nz: number, s: number, inCol: number, outCol: number)
	local m = Kit.Model(parent, "CornMaze")
	-- hw[i][j]: wall along X on grid line j (0..nz) for cell column i; vw[i][j]: wall along Z on
	-- grid line i (0..nx) for cell row j
	local hw: { { boolean } } = {}
	local vw: { { boolean } } = {}
	for i = 0, nx do
		hw[i] = {}
		vw[i] = {}
		for j = 0, nz do
			hw[i][j] = true
			vw[i][j] = true
		end
	end
	local seen: { [number]: boolean } = {}
	local stack = { { 0, 0 } }
	seen[0] = true
	while #stack > 0 do
		local top = stack[#stack]
		local ci, cj = top[1], top[2]
		local opts = {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = ci + d[1], cj + d[2]
			if ni >= 0 and ni < nx and nj >= 0 and nj < nz and not seen[nj * nx + ni] then
				table.insert(opts, d)
			end
		end
		if #opts == 0 then
			table.remove(stack)
		else
			local d = opts[Kit.Rng:NextInteger(1, #opts)]
			local ni, nj = ci + d[1], cj + d[2]
			if d[1] == 1 then
				vw[ci + 1][cj] = false
			elseif d[1] == -1 then
				vw[ci][cj] = false
			elseif d[2] == 1 then
				hw[ci][cj + 1] = false
			else
				hw[ci][cj] = false
			end
			seen[nj * nx + ni] = true
			table.insert(stack, { ni, nj })
		end
	end
	-- a few extra openings so it's a friendly loop maze, not a dead-end trap
	for _ = 1, math.floor(nx * nz / 8) do
		local i, j = Kit.Rng:NextInteger(1, nx - 1), Kit.Rng:NextInteger(0, nz - 1)
		vw[i][j] = false
	end
	hw[inCol][0] = false
	hw[outCol][nz] = false
	-- merge runs and build
	for j = 0, nz do
		local start: number? = nil
		for i = 0, nx do
			local on = i < nx and hw[i][j]
			if on and start == nil then
				start = i
			elseif not on and start ~= nil then
				cornWall(m, x0 + start * s, z0 + j * s, x0 + i * s, z0 + j * s)
				start = nil
			end
		end
	end
	for i = 0, nx do
		local start: number? = nil
		for j = 0, nz do
			local on = j < nz and vw[i][j]
			if on and start == nil then
				start = j
			elseif not on and start ~= nil then
				cornWall(m, x0 + i * s, z0 + start * s, x0 + i * s, z0 + j * s)
				start = nil
			end
		end
	end
	-- packed-straw floor inside the maze (flat)
	Kit.Box(m, V(x0, 0, z0), V(x0 + nx * s, 0.04, z0 + nz * s), C(120, 92, 56), { Mat = GROUND })
	Kit.AddRect(x0 - 2, z0 - 2, x0 + nx * s + 2, z0 + nz * s + 2)
end

--==================================================================
-- GROUND, ROAD, WALLS, SKY
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), EARTH, { Mat = GROUND, Solid = true, Name = "Ground_PumpkinFarm" })
	-- tilled furrows (flat) on both sides of the road
	for x = 16, 136, 12 do
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * x - 1.2, 0, Z0 + 4), V(s * x + 1.2, 0.05, Z1 - 4), EARTH_D, { Mat = GROUND })
		end
	end
	-- straw-strewn patches
	for _, p in { { 40, 30, 30 }, { -110, 100, 24 }, { 115, 230, 36 }, { -40, 260, 18 }, { 30, 160, 20 }, { -100, 210, 22 } } do
		Kit.Disc(f, p[1], Z0 + p[2], 0.07, p[3], 0.02, STRAW_D, { Mat = GRASS })
	end
	-- the dirt farm road with tyre ruts and grass along the middle
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.08, Z1), ROAD, { Mat = GROUND, Solid = true, Name = "Path" })
	for _, x in { -4.5, 4.5 } do
		Kit.Box(f, V(x - 1.1, 0.08, Z0), V(x + 1.1, 0.1, Z1), C(105, 74, 50), { Mat = GROUND })
	end
	Kit.Box(f, V(-1.2, 0.08, Z0), V(1.2, 0.11, Z1), C(96, 112, 54), { Mat = GRASS })
	-- crop circles in the straw
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.12, r * 2 + 4, 0.1, STRAW_D, { Mat = GRASS })
		Kit.Disc(f, x, z, 0.15, r * 2, 0.03, STRAW, { Mat = GRASS })
		Kit.Disc(f, x, z, 0.17, r * 1.5, 0.02, STRAW_D, { Mat = GRASS })
		Kit.Disc(f, x, z, 0.19, r * 1.3, 0.02, STRAW, { Mat = GRASS })
		Kit.Disc(f, x, z, 0.21, r * 0.6, 0.02, STRAW_D, { Mat = GRASS })
		Kit.Disc(f, x, z, 0.23, r * 0.4, 0.02, STRAW, { Mat = GRASS })
		-- little satellite circles on the ring
		local n = if i == 1 then 6 else 4
		for k = 0, n - 1 do
			local ang = k * 2 * math.pi / n + i
			local rx, rz = x + math.cos(ang) * r * 0.7, z + math.sin(ang) * r * 0.7
			Kit.Disc(f, rx, rz, 0.21, r * 0.22, 0.02, STRAW_D, { Mat = GRASS })
			Props.Beam(f, V(x + math.cos(ang) * r * 0.3, 0.2, z + math.sin(ang) * r * 0.3), V(x + math.cos(ang) * r * 0.59, 0.2, z + math.sin(ang) * r * 0.59), 0.8, 0.02, STRAW_D, { Mat = GRASS })
		end
	end
	-- boss: a giant jack-o'-lantern crop circle
	local bz = BOSS_Z
	Kit.Disc(f, 0, bz, 0.12, 58, 0.1, STRAW_D, { Mat = GRASS })
	Kit.Disc(f, 0, bz, 0.15, 52, 0.03, Kit.Vivid(C(230, 120, 40)), { Mat = GRASS })
	for k = -2, 2 do
		Kit.Part(f, V(4, 0.02, 44 - math.abs(k) * 6), CFrame.new(k * 9, 0.17, bz), C(200, 100, 34), { Mat = GRASS })
	end
	for _, sx in { -1, 1 } do
		Kit.Part(f, V(8, 0.03, 8), CFrame.new(sx * 9, 0.2, bz + 7) * CFrame.Angles(0, math.pi / 4, 0), DARK, { Mat = GROUND })
	end
	Kit.Part(f, V(5, 0.03, 5), CFrame.new(0, 0.2, bz) * CFrame.Angles(0, math.pi / 4, 0), DARK, { Mat = GROUND })
	for k = -2, 2 do
		Kit.Box(f, V(k * 5.5 - 2, 0.17, bz - 13 + (if k % 2 == 0 then 0 else 2)), V(k * 5.5 + 2, 0.21, bz - 8 + (if k % 2 == 0 then 0 else 2)), DARK, { Mat = GROUND })
	end
	Kit.Box(f, V(-3, 0.17, bz + 25), V(3, 0.21, bz + 30), C(80, 120, 50), { Mat = GRASS })
end

local function walls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		-- tall plank fence wall with white trim and a dark plinth
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 12, z1), BARN, { Mat = PLANKS, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.8, 0, z0), V(s * 140, 1.6, z1), BARN_D, WOOD_O)
		Kit.Box(f, V(s * 139.6, 12, z0), V(s * 146.4, 12.8, z1), TRIM, WOOD_O)
		for z = z0 + 10, z1 - 10, 30 do
			Kit.Box(f, V(s * 139.5 - 0.4, 0, z - 0.6), V(s * 139.5 + 0.4, 12, z + 0.6), TRIM, WOOD_O)
		end
		-- corn rows outside the wall (backdrop)
		for k = 0, 4 do
			local x = s * (152 + k * 8)
			Kit.Box(f, V(x - 2, 0, Z0), V(x + 2, 9 + k, Z1), if k % 2 == 0 then CORN else CORN_D, { Mat = GRASS })
			Kit.Box(f, V(x - 1.6, 9 + k, Z0), V(x + 1.6, 10 + k, Z1), TASSEL, { Mat = GRASS })
		end
		-- jack-o'-lanterns on the wall top
		for _, z in { Z0 + 60, Z0 + 200, Z0 + 330 } do
			Props.Pumpkin(f, V(s * 143, 12.8, z), 2.6, -s, 0, false)
		end
	end
end

local function sky(f: Instance)
	-- the big harvest moon low on the left with soft craters, and a few dark clouds
	local mx, my, mz = -320, 150, Z0 + 230
	Kit.Ball(f, 70, V(mx, my, mz), MOON, { Name = "HarvestMoon" })
	for _, c in { { 10, 12, -8, 14 }, { -14, -6, 12, 10 }, { 4, -16, -18, 8 }, { -8, 18, 16, 6 } } do
		Kit.Ball(f, c[4], V(mx + 30, my + c[1], mz + c[2] + c[3] * 0.2), C(235, 215, 170))
	end
	for _, c in { { -260, 140, Z0 + 170, 40 }, { -280, 175, Z0 + 290, 50 }, { 260, 160, Z0 + 120, 46 } } do
		for k = 0, 2 do
			Kit.Ball(f, c[4] * (0.6 + k * 0.2), V(c[1] + k * 6, c[2] + (k % 2) * 5, c[3] + k * c[4] * 0.45), C(60, 50, 72), { Transp = 0.2 })
		end
	end
	-- bats circling the moon (floating)
	for i = 0, 3 do
		local p = V(-200 + i * 12, 120 + (i % 2) * 14, Z0 + 200 + i * 20)
		local b = Kit.Part(f, V(4, 0.3, 1.4), CFrame.new(p) * CFrame.Angles(0, i, 0.2), DARK, { Name = "Bat" })
		Kit.Float(b, 2)
	end
end

--==================================================================
-- BUILDINGS
--==================================================================
local function barn(f: Instance)
	local m = Kit.Model(f, "RedBarn")
	local x0, x1 = -125, -79 -- ridge along X; the gable faces the road (+X)
	local z0, z1 = Z0 + 22, Z0 + 66
	local zc = (z0 + z1) / 2
	local wallH, kneeY, ridgeY = 20, 31, 38
	Kit.Box(m, V(x0, 0, z0), V(x1, wallH, z1), BARN, WOOD_S)
	-- gambrel gable ends (both)
	for _, gx in { x0, x1 } do
		local cx = gx + (if gx == x1 then -1 else 1) * 0.5
		Kit.Box(m, V(cx - 0.5, wallH, z0 + 8), V(cx + 0.5, kneeY, z1 - 8), BARN, WOOD_S)
		Kit.Wedge(m, V(1, kneeY - wallH, 8), CFrame.new(cx, (wallH + kneeY) / 2, z0 + 4), BARN, { Mat = PLANKS })
		Kit.Wedge(m, V(1, kneeY - wallH, 8), CFrame.new(cx, (wallH + kneeY) / 2, z1 - 4) * CFrame.Angles(0, math.pi, 0), BARN, { Mat = PLANKS })
		Kit.Wedge(m, V(1, ridgeY - kneeY, zc - z0 - 8), CFrame.new(cx, (kneeY + ridgeY) / 2, (z0 + 8 + zc) / 2), BARN, { Mat = PLANKS })
		Kit.Wedge(m, V(1, ridgeY - kneeY, zc - z0 - 8), CFrame.new(cx, (kneeY + ridgeY) / 2, (zc + z1 - 8) / 2) * CFrame.Angles(0, math.pi, 0), BARN, { Mat = PLANKS })
	end
	-- roof panels (dark shingles) with a small overhang
	local L, Lx = x1 - x0 + 2, (x0 + x1) / 2
	local pts = { { z0 - 1.5, wallH - 1 }, { z0 + 8, kneeY }, { zc, ridgeY + 0.6 }, { z1 - 8, kneeY }, { z1 + 1.5, wallH - 1 } }
	for i = 1, 4 do
		Props.Beam(m, V(Lx, pts[i][2], pts[i][1]), V(Lx, pts[i + 1][2], pts[i + 1][1]), L, 1, ROOF, { Mat = Enum.Material.RoofShingles, Solid = true, Shadow = true })
	end
	Kit.Box(m, V(x0 - 1, ridgeY, zc - 0.6), V(x1 + 1, ridgeY + 1.2, zc + 0.6), TRIM, WOOD_O)
	-- white corner trim
	for _, cz in { z0, z1 } do
		for _, cx in { x0, x1 } do
			Kit.Box(m, V(cx - 0.6, 0, cz - 0.6), V(cx + 0.6, wallH, cz + 0.6), TRIM, WOOD_O)
		end
	end
	-- front: big double doors with white X braces, hay loft door with hay, sign and lamp
	local fx = x1 + 0.1
	Kit.Box(m, V(fx, 0, zc - 9), V(fx + 0.4, 15, zc + 9), BARN_D, WOOD_O)
	for _, dz in { -4.5, 4.5 } do
		local a, b = zc + dz - 4.2, zc + dz + 4.2
		Kit.Box(m, V(fx + 0.3, 0, a), V(fx + 0.7, 15, a + 0.6), TRIM, WOOD_O)
		Kit.Box(m, V(fx + 0.3, 0, b - 0.6), V(fx + 0.7, 15, b), TRIM, WOOD_O)
		Kit.Box(m, V(fx + 0.3, 14.4, a), V(fx + 0.7, 15, b), TRIM, WOOD_O)
		Kit.Box(m, V(fx + 0.3, 0, a), V(fx + 0.7, 0.6, b), TRIM, WOOD_O)
		Props.Beam(m, V(fx + 0.55, 0.6, a + 0.4), V(fx + 0.55, 14.4, b - 0.4), 0.5, 0.6, TRIM, WOOD_O)
		Props.Beam(m, V(fx + 0.55, 0.6, b - 0.4), V(fx + 0.55, 14.4, a + 0.4), 0.5, 0.6, TRIM, WOOD_O)
	end
	Kit.Box(m, V(fx, 23, zc - 4), V(fx + 0.3, 30, zc + 4), DARK)
	Kit.Box(m, V(fx + 0.2, 23, zc - 4.6), V(fx + 0.6, 23.6, zc + 4.6), TRIM, WOOD_O)
	Kit.Box(m, V(fx + 0.2, 30, zc - 4.6), V(fx + 0.6, 30.6, zc + 4.6), TRIM, WOOD_O)
	bale(m, V(fx - 1.6, 23, zc - 1.2), 0)
	Kit.Box(m, V(fx, 30.6, zc - 0.3), V(fx + 4, 31.2, zc + 0.3), FENCE_D, WOOD_O) -- hay hoist beam
	Props.SignBoard(m, V(fx + 0.5, 18, zc), 22, 3.2, 1, 0, "OLD MACBOONALD'S", TRIM, BARN_D)
	local lamp = Kit.Ball(m, 1.4, V(fx + 1.2, 16.4, zc - 10.5), LAMP, { Mat = NEON })
	Kit.Light(lamp, LAMP, 26, 1.1, true)
	-- side windows
	for _, sz in { z0 - 0.1, z1 + 0.1 } do
		for wx = x0 + 8, x1 - 8, 10 do
			Kit.Box(m, V(wx - 1.5, 9, sz - 0.2), V(wx + 1.5, 13, sz + 0.2), C(255, 200, 120))
			Kit.Box(m, V(wx - 2, 8.6, sz - 0.3), V(wx + 2, 9, sz + 0.3), TRIM, WOOD_O)
		end
	end
	-- weathervane: a little rooster
	local vx = (x0 + x1) / 2
	Kit.Box(m, V(vx - 0.15, ridgeY + 1, zc - 0.15), V(vx + 0.15, ridgeY + 7, zc + 0.15), DARK, METAL_O)
	Kit.Box(m, V(vx - 1.6, ridgeY + 5, zc - 0.1), V(vx + 1.6, ridgeY + 5.2, zc + 0.1), DARK, METAL_O)
	Kit.Part(m, V(2.4, 1.6, 0.2), CFrame.new(vx, ridgeY + 7.6, zc), DARK, METAL_O)
	Kit.Wedge(m, V(0.2, 1.6, 1.4), CFrame.new(vx - 1.6, ridgeY + 8, zc) * CFrame.Angles(0, -math.pi / 2, 0), DARK, METAL_O)
	Kit.AddRect(x0 - 2, z0 - 2, x1 + 3, z1 + 2)
end

local function silo(f: Instance)
	local m = Kit.Model(f, "Silo")
	local x, z = -128, Z0 + 84
	Kit.Cyl(m, 40, 12, CFrame.new(x, 20, z), C(200, 205, 210), { Mat = METAL, Solid = true, Shadow = true })
	for y = 6, 36, 8 do
		Kit.Cyl(m, 0.6, 12.4, CFrame.new(x, y, z), C(150, 155, 165), METAL_O)
	end
	Kit.Ball(m, 12, V(x, 40, z), C(160, 60, 50), { Mat = METAL })
	Kit.Cyl(m, 1.2, 1.6, CFrame.new(x, 46.2, z), DARK, METAL_O)
	-- ladder
	for _, dz in { -0.8, 0.8 } do
		Kit.Box(m, V(x + 6.1, 0, z + dz - 0.1), V(x + 6.3, 38, z + dz + 0.1), DARK, METAL_O)
	end
	for y = 2, 36, 3 do
		Kit.Box(m, V(x + 6.1, y, z - 0.8), V(x + 6.3, y + 0.2, z + 0.8), DARK, METAL_O)
	end
	Kit.AddCircle(x, z, 7.5)
end

local function windmill(f: Instance)
	local m = Kit.Model(f, "Windmill")
	local x, z = -58, Z0 + 76
	local top = 30
	for _, c in { { -3, -3 }, { 3, -3 }, { 3, 3 }, { -3, 3 } } do
		Props.Beam(m, V(x + c[1], 0, z + c[2]), V(x + c[1] * 0.25, top, z + c[2] * 0.25), 0.5, 0.5, C(150, 150, 160), METAL_O)
	end
	for y = 6, 24, 9 do
		local k = 3 * (1 - y / top * 0.75)
		for _, e in { { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } } do
			Props.Beam(m, V(x + e[1] * k, y, z + e[2] * k), V(x + e[3] * k, y, z + e[4] * k), 0.25, 0.25, C(150, 150, 160), METAL_O)
		end
	end
	Kit.Box(m, V(x - 1, top - 1, z - 1), V(x + 1, top + 1, z + 1), C(120, 120, 130), METAL_O)
	-- fan facing +X (the road)
	local hub = V(x + 1.6, top, z)
	Kit.CylFlat(m, 1, 2, hub, "X", C(120, 120, 130), METAL_O)
	for k = 0, 11 do
		local a = k * math.pi / 6 + 0.2
		Kit.Part(m, V(0.15, 6.5, 1.3), CFrame.new(hub + V(0.4, math.cos(a) * 4.2, math.sin(a) * 4.2)) * CFrame.Angles(-a, 0, 0) * CFrame.Angles(0, 0.3, 0), TRIM, METAL_O)
	end
	-- tail vane
	Kit.Box(m, V(x - 7, top - 0.2, z - 0.2), V(x - 1, top + 0.2, z + 0.2), C(120, 120, 130), METAL_O)
	Kit.Box(m, V(x - 9, top - 2, z - 0.1), V(x - 6, top + 2.5, z + 0.1), BARN, METAL_O)
	-- water trough at its feet
	Kit.Box(m, V(x - 2, 0, z + 5), V(x + 6, 2, z + 8), C(130, 135, 145), { Mat = METAL, Solid = true })
	Kit.Box(m, V(x - 1.6, 1.7, z + 5.4), V(x + 5.6, 1.8, z + 7.6), C(60, 110, 150), { Transp = 0.3 })
	Kit.AddCircle(x, z + 2, 6)
end

local function coop(f: Instance)
	local m = Kit.Model(f, "ChickenCoop")
	local x, z = -118, Z0 + 176
	Kit.Box(m, V(x - 7, 2, z - 5), V(x + 7, 9, z + 5), C(225, 205, 160), { Mat = PLANKS, Solid = true })
	for _, c in { { -6.5, -4.5 }, { 6.5, -4.5 }, { 6.5, 4.5 }, { -6.5, 4.5 } } do
		Kit.Box(m, V(x + c[1] - 0.3, 0, z + c[2] - 0.3), V(x + c[1] + 0.3, 2, z + c[2] + 0.3), FENCE_D, WOOD_O)
	end
	Kit.Wedge(m, V(15, 3, 5.5), CFrame.new(x, 10.5, z - 2.75), BARN_D, { Mat = Enum.Material.RoofShingles })
	Kit.Wedge(m, V(15, 3, 5.5), CFrame.new(x, 10.5, z + 2.75) * CFrame.Angles(0, math.pi, 0), BARN_D, { Mat = Enum.Material.RoofShingles })
	Kit.Box(m, V(x + 6.9, 3, z - 1.5), V(x + 7.1, 6, z + 1.5), DARK)
	Props.Beam(m, V(x + 7, 3, z), V(x + 11, 0, z), 2.4, 0.3, FENCE, WOOD_O)
	-- three chickens (white blobs with red combs)
	for i, p in { { 13, -4 }, { 15, 3 }, { 11, 6 } } do
		local cx, cz = x + p[1], z + p[2]
		Kit.Ball(m, 1.6, V(cx, 0.8, cz), C(250, 248, 240))
		Kit.Ball(m, 0.9, V(cx + 0.7, 1.7, cz), C(250, 248, 240))
		Kit.Box(m, V(cx + 0.6, 2.1, cz - 0.1), V(cx + 0.9, 2.4, cz + 0.1), C(220, 50, 50))
		Kit.Part(m, V(0.4, 0.2, 0.2), CFrame.new(cx + 1.2, 1.7, cz), C(255, 190, 60))
		if i == 1 then
			Kit.Ball(m, 0.7, V(cx - 0.8, 1.2, cz), C(230, 225, 215))
		end
	end
	Kit.AddCircle(x + 3, z, 11)
end

local function well(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Well")
	Kit.Cyl(m, 3, 6, CFrame.new(x, 1.5, z), C(120, 115, 120), { Mat = Enum.Material.Cobblestone, Solid = true })
	Kit.Disc(m, x, z, 2.9, 4.6, 0.2, C(30, 50, 70))
	for _, dz in { -2.6, 2.6 } do
		Kit.Box(m, V(x - 0.3, 3, z + dz - 0.3), V(x + 0.3, 8, z + dz + 0.3), FENCE_D, WOOD_O)
	end
	Kit.CylFlat(m, 5.6, 0.6, V(x, 7, z), "Z", FENCE, WOOD_O)
	Kit.Wedge(m, V(5, 1.6, 3.4), CFrame.new(x - 1.2, 8.8, z), BARN_D, WOOD_O)
	Kit.Wedge(m, V(5, 1.6, 3.4), CFrame.new(x - 1.2, 8.8, z) * CFrame.Angles(0, math.pi, 0), BARN_D, WOOD_O)
	Kit.Box(m, V(x - 0.6, 4.2, z - 0.6), V(x + 0.6, 5.4, z + 0.6), FENCE, WOOD_O)
	Kit.AddCircle(x, z, 4)
end

--==================================================================
-- PUMPKIN PATCH, STAND, TRACTOR, HAY
--==================================================================
local function patch(f: Instance)
	local x0, x1, z0, z1 = 46, 130, Z0 + 54, Z0 + 144
	-- vine rows (flat)
	for z = z0 + 4, z1 - 4, 14 do
		Kit.Box(f, V(x0, 0.05, z - 1.2), V(x1, 0.14, z + 1.2), VINE, { Mat = GRASS })
		for x = x0 + 4, x1 - 4, 18 do
			Kit.Part(f, V(2.2, 0.15, 1.4), CFrame.new(x, 0.12, z + (if (x // 18) % 2 == 0 then 1.6 else -1.6)) * CFrame.Angles(0, 0.5, 0), C(80, 140, 60), { Mat = GRASS })
		end
	end
	local rng = Kit.Rng
	for z = z0 + 4, z1 - 4, 14 do
		for x = x0 + 6, x1 - 4, 16 do
			local px, pz = x + rng:NextNumber(-2, 2), z + rng:NextNumber(-1, 1)
			if Kit.IsFree(px, pz, 2) then
				Props.Pumpkin(f, V(px, 0.05, pz), rng:NextNumber(2.2, 3.6), -1, rng:NextNumber(-0.6, 0.6), false)
			end
		end
	end
	-- giant prize pumpkins
	for i, p in { { 60, 130 }, { 118, 66 }, { 124, 128 } } do
		local x, z = p[1], Z0 + p[2]
		if Kit.IsFree(x, z, 4) then
			Props.Pumpkin(f, V(x, 0, z), 8, -1, 0, i == 1)
			Kit.AddCircle(x, z, 4.5)
		end
	end
	scarecrow(f, 88, Z0 + 100, -math.pi / 2)
	Props.SignBoard(f, V(42, 5, Z0 + 62), 12, 2.6, -1, 0, "PICK YOUR OWN!", C(240, 230, 210), BARN_D, FENCE_D)
	for _, dz in { -5, 5 } do
		Kit.Box(f, V(42.5, 0, Z0 + 62 + dz - 0.3), V(43.1, 6.3, Z0 + 62 + dz + 0.3), FENCE_D, WOOD_O)
	end
	-- wheelbarrow full of little pumpkins
	local wx, wz = 46, Z0 + 108
	Kit.Box(f, V(wx - 1.8, 1.4, wz - 3), V(wx + 1.8, 3, wz + 1.6), C(60, 120, 90), { Mat = METAL })
	Kit.CylFlat(f, 0.6, 2.2, V(wx, 1.1, wz - 3.6), "X", TIRE)
	for _, sx in { -1.4, 1.4 } do
		Kit.Box(f, V(wx + sx - 0.15, 0, wz + 1), V(wx + sx + 0.15, 1.4, wz + 1.3), DARK, METAL_O)
		Props.Beam(f, V(wx + sx, 2, wz + 1.6), V(wx + sx, 2.6, wz + 4.6), 0.3, 0.3, FENCE, WOOD_O)
	end
	for k = 0, 2 do
		Kit.Ball(f, 1.4, V(wx - 0.8 + k * 0.8, 3.3, wz - 1.6 + (k % 2) * 1.6), Kit.Pick(Props.Colors.PumpkinBody))
	end
	Kit.AddRect(x0, z0, x1, z1)
end

local function stand(f: Instance)
	local m = Kit.Model(f, "PumpkinStand")
	local x, z = 24, Z0 + 136
	Kit.Box(m, V(x - 2, 0, z - 6), V(x + 2, 3.4, z + 6), FENCE, WOOD_S)
	Kit.Box(m, V(x - 2.4, 3.4, z - 6.4), V(x + 2.4, 3.7, z + 6.4), FENCE_D, WOOD_O)
	for _, dz in { -5.6, 5.6 } do
		Kit.Box(m, V(x + 1.4, 0, z + dz - 0.3), V(x + 2, 10, z + dz + 0.3), FENCE_D, WOOD_O)
	end
	for i = 0, 5 do
		Kit.Wedge(m, V(4.5, 1.6, 13 / 6), CFrame.new(x - 0.2, 10.6, z - 6.5 + (i + 0.5) * 13 / 6) * CFrame.Angles(0, -math.pi / 2, 0), if i % 2 == 0 then ORANGE else TRIM, { Mat = FABRIC })
	end
	for k = -2, 2 do
		Props.Pumpkin(m, V(x - 0.4, 3.7, z + k * 2.2), 1.8, -1, 0, false)
	end
	Props.SignBoard(m, V(x - 2.5, 7.4, z), 9, 2, -1, 0, "PUMPKINS 5 COINS", C(250, 240, 220), BARN_D)
	bale(m, V(x - 5, 0, z + 9), 0.3)
	bale(m, V(x - 5, 0, z - 9), -0.2)
	Kit.AddCircle(x - 2, z, 9)
end

local function tractor(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Tractor")
	-- faces -Z (toward the farm road entrance)
	Kit.Box(m, V(x - 2.2, 2.4, z - 7), V(x + 2.2, 6, z + 1), TRACTOR, { Mat = METAL, Solid = true })
	Kit.Box(m, V(x - 2.4, 2.6, z - 7.3), V(x + 2.4, 5.6, z - 6.9), DARK, METAL_O) -- grille
	for _, sx in { -1.4, 1.4 } do
		Kit.Ball(m, 0.8, V(x + sx, 5, z - 7.3), C(255, 240, 200), { Mat = NEON })
	end
	Kit.Box(m, V(x - 2.6, 2, z), V(x + 2.6, 4, z + 5), TRACTOR, { Mat = METAL, Solid = true })
	Kit.Box(m, V(x - 1.2, 4, z + 1.5), V(x + 1.2, 5, z + 3.5), DARK) -- seat
	Kit.Box(m, V(x - 1.2, 5, z + 3.2), V(x + 1.2, 7.2, z + 3.6), DARK)
	Props.Beam(m, V(x, 4.5, z), V(x, 6.6, z + 1.2), 0.3, 0.3, DARK)
	Kit.CylFlat(m, 0.3, 2, V(x, 6.7, z + 1.3), "Z", DARK)
	Kit.Cyl(m, 4, 0.8, CFrame.new(x + 1.4, 8, z - 4), DARK, METAL_O) -- exhaust
	Kit.Cyl(m, 0.5, 1.1, CFrame.new(x + 1.4, 10, z - 4), C(150, 150, 160), METAL_O)
	-- roll cage canopy
	for _, sx in { -2.4, 2.4 } do
		Kit.Box(m, V(x + sx - 0.2, 4, z + 4.4), V(x + sx + 0.2, 11, z + 4.8), DARK, METAL_O)
	end
	Kit.Box(m, V(x - 2.8, 11, z + 0.5), V(x + 2.8, 11.4, z + 5.2), TRACTOR, METAL_O)
	-- big rear wheels, small front wheels (tyres + yellow hubs)
	for _, sx in { -1, 1 } do
		Kit.CylFlat(m, 1.6, 7, V(x + sx * 3.6, 3.5, z + 2.5), "X", TIRE, { Mat = Enum.Material.Rubber, Solid = true })
		Kit.CylFlat(m, 1.7, 3.6, V(x + sx * 3.6, 3.5, z + 2.5), "X", Kit.Vivid(C(255, 200, 50)), METAL_O)
		Kit.CylFlat(m, 1.2, 3.6, V(x + sx * 3, 1.8, z - 5), "X", TIRE, { Mat = Enum.Material.Rubber })
		Kit.CylFlat(m, 1.3, 1.6, V(x + sx * 3, 1.8, z - 5), "X", Kit.Vivid(C(255, 200, 50)), METAL_O)
	end
	-- hayride wagon behind
	local wz = z + 9
	Kit.Box(m, V(x - 0.3, 1.6, z + 5), V(x + 0.3, 2, wz), DARK, METAL_O)
	Kit.Box(m, V(x - 5, 2.4, wz), V(x + 5, 3.2, wz + 18), FENCE, { Mat = PLANKS, Solid = true })
	for _, sx in { -1, 1 } do
		Kit.Box(m, V(x + sx * 5 - 0.2, 3.2, wz), V(x + sx * 5 + 0.2, 6, wz + 18), FENCE_D, WOOD_O)
		for _, dz in { 3, 15 } do
			Kit.CylFlat(m, 1, 3.2, V(x + sx * 4.2, 1.6, wz + dz), "X", TIRE, { Mat = Enum.Material.Rubber })
		end
	end
	for k = 0, 2 do
		bale(m, V(x - 2.4, 3.2, wz + 3 + k * 6), math.pi / 2)
		bale(m, V(x + 2.4, 3.2, wz + 3 + k * 6), math.pi / 2)
	end
	bale(m, V(x, 5.6, wz + 9), 0)
	Props.Pumpkin(m, V(x, 8, wz + 9), 2.4, 0, -1, false)
	Kit.AddRect(x - 6, z - 8, x + 6, wz + 19)
end

local function hay(f: Instance)
	-- bale stacks (pyramids) and round bales
	for _, p in { { 118, 230 }, { 122, 300 }, { -126, 140 }, { 118, 176 } } do
		local x, z = p[1], Z0 + p[2]
		if Kit.IsFree(x, z, 7) then
			for k = -1, 1 do
				bale(f, V(x, 0, z + k * 3.2), 0)
				bale(f, V(x + 5.2, 0, z + k * 3.2), 0)
			end
			bale(f, V(x + 2.6, 2.4, z - 1.6), 0)
			bale(f, V(x + 2.6, 2.4, z + 1.6), 0)
			bale(f, V(x + 2.6, 4.8, z), 0)
			Props.Pumpkin(f, V(x + 2.6, 7.2, z), 2.2, -1, 0, false)
			Kit.AddCircle(x + 2.6, z, 7)
		end
	end
	for _, p in { { 44, 320 }, { 52, 226 }, { 100, 334 }, { 132, 260 }, { -20, 168 }, { 22, 230 }, { -112, 260 }, { 36, 40 } } do
		local x, z = p[1], Z0 + p[2]
		if Kit.IsFree(x, z, 3.5) then
			roundBale(f, V(x, 0, z), if (p[1] // 4) % 2 == 0 then "X" else "Z")
			Kit.AddCircle(x, z, 3.5)
		end
	end
end

local function fences(f: Instance)
	-- split-rail fences along both sides of the road where no ghost area or station is near
	for _, s in { -1, 1 } do
		railFence(f, V(s * 11, 0, Z0 + 122), V(s * 11, 0, Z0 + 160))
		railFence(f, V(s * 11, 0, Z0 + 172), V(s * 11, 0, Z0 + 210))
		railFence(f, V(s * 11, 0, Z0 + 222), V(s * 11, 0, Z0 + 272))
		Kit.AddRect(s * 11 - 1, Z0 + 120, s * 11 + 1, Z0 + 274)
	end
	-- paddock fence round the pumpkin patch's back edge
	railFence(f, V(44, 0, Z0 + 148), V(134, 0, Z0 + 148))
	-- lantern posts by the road
	for i, z in { Z0 + 46, Z0 + 166, Z0 + 216, Z0 + 344 } do
		for _, s in { -1, 1 } do
			local x = s * 13
			if Kit.IsFree(x, z, 1) then
				Props.Lantern(f, V(x, 0, z), LAMP, (i + (s + 1) / 2) % 2 == 0, i == 2 and s == 1)
				Kit.AddCircle(x, z, 1.2)
			end
		end
	end
end

local function decor(f: Instance)
	-- scarecrows watching over the fields
	for _, p in { { 70, 300, math.pi }, { 116, 205, -math.pi / 2 }, { -26, 140, math.pi / 2 }, { -110, 230, math.pi / 2 } } do
		if Kit.IsFree(p[1], Z0 + p[2], 5) then
			scarecrow(f, p[1], Z0 + p[2], p[3])
		end
	end
	-- the big Scarecrow King statue at the back right, facing the boss circle
	if Kit.IsFree(110, Z0 + 330, 8) then
		scarecrow(f, 110, Z0 + 330, -math.pi / 2 - 0.4, 1.8)
	end
	-- pumpkin piles along the road
	for _, p in { { 16, 24 }, { -16, 24 }, { 15, 290 }, { -15, 222 }, { 16, 180 }, { -15, 330 } } do
		local x, z = p[1], Z0 + p[2]
		if Kit.IsFree(x, z, 2.5) then
			Props.Pumpkin(f, V(x, 0, z), 3, -p[1], 0, p[2] == 24)
			Props.Pumpkin(f, V(x + (if x > 0 then 2 else -2), 0, z + 2.4), 2, -p[1], 0, false)
			Kit.AddCircle(x, z, 2.5)
		end
	end
	well(f, -122, Z0 + 208)
	coop(f)
	-- floating pumpkins and ground fog
	for _, p in { V(-70, 22, Z0 + 175), V(40, 26, Z0 + 260), V(-90, 18, Z0 + 300), V(100, 20, Z0 + 40), V(-30, 30, Z0 + 40), V(60, 24, Z0 + 150) } do
		Props.FloatingPumpkin(f, p)
	end
	Props.Wisp(f, V(-34, 0, Z0 + 160), C(220, 200, 150), 10, true)
	Props.Wisp(f, V(-90, 0, Z0 + 300), C(220, 200, 150), 10, true)
	-- warm glows: the stand and the coop
	local glow = Kit.Part(f, V(1, 1, 1), CFrame.new(22, 9, Z0 + 136), LAMP, { Transp = 1, Name = "StandGlow" })
	Kit.Light(glow, LAMP, 24, 1)
	local cg = Kit.Part(f, V(1, 1, 1), CFrame.new(-110, 9, Z0 + 176), LAMP, { Transp = 1, Name = "CoopGlow" })
	Kit.Light(cg, LAMP, 20, 0.8)
end

--==================================================================
-- BUILD
--==================================================================
function PumpkinFarm.Build(map: Instance)
	local f = Kit.Folder(map, "PumpkinFarm")
	ground(f)
	walls(f)
	sky(f)
	barn(f)
	silo(f)
	windmill(f)
	-- the small maze left of the road, the big one at the back left
	cornMaze(f, -52, Z0 + 124, 4, 10, 8.5, 1, 2)
	cornMaze(f, -130, Z0 + 272, 11, 7, 8.6, 9, 5)
	fences(f)
	patch(f)
	stand(f)
	tractor(f, 72, Z0 + 228)
	hay(f)
	decor(f)
end

return PumpkinFarm
