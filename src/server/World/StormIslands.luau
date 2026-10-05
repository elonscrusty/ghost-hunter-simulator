--!strict
-- ZONE 30: Storm Sky Islands (Z 11680..12040). High above the world on a sea of storm clouds:
-- slate-blue cloud tops, little grassy islands, rope bridges strung between floating islands,
-- copper lightning rods and dark thunderheads.
--   Ground: the cloud sea (a solid slab, top Y = 0) with grassy island patches and a wooden
--   sky-boardwalk along X = 0 with rope rails. The "gaps" in the clouds are flat painted
--   holes (you see tiny fields far below); there are no real holes.
--   Ghost areas are flat grassy islands ((0,11765) r30, (-82,11800) r24, (75,11860) r26,
--   (-62,11920) r24); the boss area (0,11985) r26 is a flat navy wind-rose.
--   Five floating islands (Y 44..58, |X| >= 105) carry windmills, a cottage and trees; rope
--   bridges hang between them, two of them span high over the boardwalk (bottom Y > 40).
--   Landmark: the Thunder Spire at (100, 12000), copper ball ~Y 84, struck by a frozen bolt.
--   Lightning rods with kites, cloud puffs, hot-air balloons outside the walls, thunderheads
--   at Y ~80-100.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local StormIslands = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.WoodPlanks
local GRASS = Enum.Material.Grass
local ROCK = Enum.Material.Rock

local Z0, Z1 = 11680, 12040

local CLOUD_SEA = C(146, 158, 194)
local CLOUD_L = C(222, 228, 242)
local CLOUD_M = C(196, 204, 226)
local STORM = C(92, 100, 128)
local STORM_D = C(68, 74, 100)
local GRASSC = C(110, 190, 105)
local GRASS_L = C(140, 210, 120)
local DIRT = C(125, 95, 70)
local ROCKC = C(110, 112, 128)
local PLANK = C(165, 120, 80)
local PLANK_D = C(130, 92, 62)
local ROPE = C(210, 185, 135)
local COPPER = C(205, 125, 75)
local BOLT = C(255, 240, 120)
local NAVY = C(40, 55, 105)

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 }, { 0, Z0 + 305, 26 } }

-- True when (x, z) is at least `pad` studs outside every ghost-area circle.
local function clearOfAreas(x: number, z: number, pad: number): boolean
	for _, a in AREAS do
		local dx, dz = x - a[1], z - a[2]
		if dx * dx + dz * dz < (a[3] + pad) * (a[3] + pad) then
			return false
		end
	end
	return true
end

--==================================================================
-- HELPERS
--==================================================================
local function puff(parent: Instance, pos: Vector3, d: number, dark: boolean)
	local rng = Kit.Rng
	local a = if dark then STORM else CLOUD_L
	local b = if dark then STORM_D else CLOUD_M
	Kit.Ball(parent, d, pos, a)
	Kit.Ball(parent, d * 0.72, pos + V(d * 0.48, -d * 0.1, rng:NextNumber(-0.25, 0.25) * d), b)
	Kit.Ball(parent, d * 0.62, pos + V(-d * 0.46, -d * 0.14, rng:NextNumber(-0.25, 0.25) * d), a)
end

-- Dark thunderhead: a flat-bottomed cluster of balls.
local function thunderhead(parent: Instance, pos: Vector3, d: number)
	local rng = Kit.Rng
	Kit.Ball(parent, d, pos, STORM)
	for i = 0, 3 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
		Kit.Ball(parent, d * rng:NextNumber(0.55, 0.75), pos + V(math.cos(a) * d * 0.5, -d * 0.12, math.sin(a) * d * 0.4), if i % 2 == 0 then STORM_D else C(110, 118, 145))
	end
	Kit.Ball(parent, d * 0.6, pos + V(0, d * 0.35, 0), C(125, 132, 158))
end

-- A frozen lightning bolt between two points: 4 zig-zag neon segments.
local function bolt(parent: Instance, top: Vector3, bottom: Vector3, w: number)
	local rng = Kit.Rng
	local prev = top
	for i = 1, 4 do
		local t = i / 4
		local p = top:Lerp(bottom, t)
		if i < 4 then
			p += V(rng:NextNumber(-1, 1) * 3.5, 0, rng:NextNumber(-1, 1) * 2)
		end
		Props.Beam(parent, prev, p, w, w, BOLT, { Mat = NEON })
		prev = p
	end
end

-- Floating island: grass top at y, dirt layer, rocky underside tapering down.
local function island(parent: Instance, x: number, y: number, z: number, r: number): Model
	local m = Kit.Model(parent, "FloatingIsland")
	local rng = Kit.Rng
	Kit.Cyl(m, 1.6, r * 2, CFrame.new(x, y - 0.8, z), GRASSC, { Mat = GRASS })
	Kit.Cyl(m, 3, r * 1.94, CFrame.new(x, y - 3.1, z), DIRT, { Mat = Enum.Material.Ground })
	Kit.Cyl(m, 4, r * 1.6, CFrame.new(x, y - 6.5, z), ROCKC, { Mat = ROCK })
	Kit.Cyl(m, 4, r * 1.1, CFrame.new(x, y - 10.4, z), C(95, 98, 115), { Mat = ROCK })
	Kit.Cyl(m, 4, r * 0.6, CFrame.new(x, y - 14.2, z), C(85, 88, 105), { Mat = ROCK })
	Kit.Ball(m, r * 0.5, V(x + rng:NextNumber(-1, 1), y - 17, z), C(85, 88, 105), { Mat = ROCK })
	for i = 0, 4 do
		local a = i * 1.26 + rng:NextNumber(0, 0.5)
		Kit.Ball(m, r * 0.42, V(x + math.cos(a) * r * 0.62, y - 8.5, z + math.sin(a) * r * 0.62), ROCKC, { Mat = ROCK })
	end
	-- little cloud ring hugging the island
	for i = 0, 2 do
		local a = i * 2.1 + 0.4
		Kit.Ball(m, r * 0.7, V(x + math.cos(a) * r * 1.05, y - 5, z + math.sin(a) * r * 1.05), CLOUD_L)
	end
	-- flowers
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0.3, 0.8) * r
		Kit.Ball(m, 0.9, V(x + math.cos(a) * d, y + 0.3, z + math.sin(a) * d), Kit.Pick({ C(255, 230, 90), C(255, 150, 190), C(255, 255, 255) }))
	end
	return m
end

local function windmill(parent: Instance, x: number, y: number, z: number)
	local m = Kit.Model(parent, "Windmill")
	Kit.Cyl(m, 10, 6, CFrame.new(x, y + 5, z), C(240, 235, 225), { Mat = Enum.Material.Plaster })
	Kit.Cyl(m, 5, 4.6, CFrame.new(x, y + 12.5, z), C(240, 235, 225), { Mat = Enum.Material.Plaster })
	Kit.Ball(m, 5.4, V(x, y + 15, z), C(200, 80, 70))
	Kit.Box(m, V(x - 1, y, z - 3.1), V(x + 1, y + 3, z - 2.8), PLANK_D, { Mat = WOOD })
	local hub = CFrame.new(x, y + 13, z - 3) * CFrame.Angles(0, 0, math.rad(20))
	Kit.CylFlat(m, 1.6, 1.4, (hub * CFrame.new(0, 0, 0.6)).Position, "Z", PLANK_D)
	for i = 0, 3 do
		local cf = hub * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 5, 0)
		Kit.Part(m, V(0.5, 10, 0.3), cf, PLANK_D, { Mat = WOOD })
		Kit.Part(m, V(2.2, 8, 0.15), cf * CFrame.new(1.2, 0.6, 0), C(245, 240, 230), { Mat = Enum.Material.Fabric })
	end
end

local function cottage(parent: Instance, x: number, y: number, z: number)
	local m = Kit.Model(parent, "SkyCottage")
	Kit.Box(m, V(x - 4, y, z - 3.5), V(x + 4, y + 6, z + 3.5), C(250, 225, 170), { Mat = Enum.Material.Plaster })
	for _, s in { -1, 1 } do
		Kit.Wedge(m, V(9, 4, 4.2), CFrame.new(x, y + 8, z + s * 2) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0), C(80, 130, 200), { Mat = Enum.Material.Slate })
	end
	Kit.Box(m, V(x + 1.5, y + 7, z + 0.5), V(x + 2.7, y + 11, z + 1.7), C(150, 90, 70), { Mat = Enum.Material.Brick })
	Kit.Box(m, V(x - 1, y, z - 3.6), V(x + 1, y + 3.6, z - 3.5), C(140, 90, 60), { Mat = WOOD })
	for _, dx in { -2.8, 2.8 } do
		Kit.Box(m, V(x + dx - 0.8, y + 2.8, z - 3.6), V(x + dx + 0.8, y + 4.4, z - 3.5), C(255, 220, 140))
	end
end

-- A sagging rope bridge between two points (planks + two rope rails).
local function ropeBridge(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local m = Kit.Model(parent, "RopeBridge")
	local flat = V(b.X - a.X, 0, b.Z - a.Z).Unit
	local right = flat:Cross(V(0, 1, 0)).Unit
	local len = (b - a).Magnitude
	local n = math.max(6, math.floor(len / 8.5))
	local function at(t: number): Vector3
		return a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0)
	end
	local prev = at(0)
	for i = 1, n do
		local p = at(i / n)
		local mid = (prev + p) / 2
		local cf = CFrame.lookAt(mid, p)
		Kit.Part(m, V(5, 0.5, (p - prev).Magnitude * 0.9), cf, if i % 2 == 0 then PLANK else PLANK_D, { Mat = WOOD })
		for _, s in { -1, 1 } do
			Props.Beam(m, prev + right * (s * 2.6) + V(0, 2.6, 0), p + right * (s * 2.6) + V(0, 2.6, 0), 0.4, 0.4, ROPE)
		end
		prev = p
	end
	for _, s in { -1, 1 } do
		for _, e in { a, b } do
			Kit.Cyl(m, 3.4, 0.6, CFrame.new(e + right * (s * 2.6) + V(0, 1.4, 0)), PLANK_D, { Mat = WOOD })
		end
	end
end

local function lightningRod(parent: Instance, x: number, y0: number, z: number, h: number): Vector3
	local m = Kit.Model(parent, "LightningRod")
	Kit.Box(m, V(x - 1.6, y0, z - 1.6), V(x + 1.6, y0 + 1.4, z + 1.6), ROCKC, { Mat = ROCK, Solid = y0 == 0 })
	Kit.Cyl(m, h, 0.7, CFrame.new(x, y0 + h / 2 + 1.4, z), COPPER, { Mat = METAL, Refl = 0.1 })
	for _, y in { h * 0.45, h * 0.7 } do
		Kit.Cyl(m, 0.4, 2, CFrame.new(x, y0 + y, z), Kit.Vivid(COPPER), { Mat = METAL })
	end
	local tip = V(x, y0 + h + 2.4, z)
	Kit.Ball(m, 2, tip, Kit.Vivid(COPPER), { Mat = METAL, Refl = 0.2 })
	Kit.Cyl(m, 2, 0.3, CFrame.new(x, y0 + h + 4.2, z), C(230, 230, 240), { Mat = METAL })
	if y0 == 0 then
		Kit.AddCircle(x, z, 2.5)
	end
	return tip
end

local function kite(parent: Instance, px: number, pz: number, kx: number, ky: number, kz: number, color: Color3)
	local m = Kit.Model(parent, "Kite")
	Kit.Cyl(m, 1.2, 0.5, CFrame.new(px, 0.6, pz), PLANK_D, { Mat = WOOD })
	local kp = V(kx, ky, kz)
	local cf = CFrame.lookAt(kp, V(0, ky, kz - 40)) * CFrame.Angles(0, 0, math.pi / 4)
	Kit.Part(m, V(3.4, 3.4, 0.15), cf, color, { Mat = Enum.Material.Fabric })
	Kit.Part(m, V(4.6, 0.2, 0.2), cf * CFrame.Angles(0, 0, math.pi / 4), PLANK_D)
	Props.Beam(m, V(px, 1.2, pz), kp, 0.12, 0.12, C(240, 240, 240))
	-- bow tail
	local prev = kp - V(0, 2.4, 0)
	for i = 1, 3 do
		local p = prev + V(0.6 * (if i % 2 == 0 then 1 else -1), -1.8, 0.4)
		Kit.Part(m, V(0.9, 0.9, 0.12), CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 4), if i % 2 == 0 then C(255, 255, 255) else BOLT)
		prev = p
	end
	Kit.AddCircle(px, pz, 2)
end

local function balloon(parent: Instance, pos: Vector3, color: Color3, stripe: Color3)
	local m = Kit.Model(parent, "HotAirBalloon")
	Kit.Ball(m, 18, pos, color)
	Kit.Cyl(m, 3, 16.6, CFrame.new(pos + V(0, 1.5, 0)), stripe)
	Kit.Ball(m, 9, pos + V(0, -6.5, 0), color)
	Kit.Box(m, pos + V(-2.2, -16, -2.2), pos + V(2.2, -12.6, 2.2), C(160, 110, 70), { Mat = Enum.Material.Wood })
	for _, o in { V(-2, 0, -2), V(2, 0, -2), V(-2, 0, 2), V(2, 0, 2) } do
		Props.Beam(m, pos + V(0, -9, 0) + o * 0.9, pos + V(0, -12.6, 0) + o, 0.15, 0.15, ROPE)
	end
end

--==================================================================
-- GROUND
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), CLOUD_SEA, { Solid = true, Name = "Ground_StormIslands" })
	-- sky boardwalk with plank seams
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), PLANK, { Mat = WOOD, Solid = true, Name = "Path" })
	for z = Z0 + 3, Z1 - 3, 6 do
		Kit.Box(f, V(-8, 0.05, z - 0.25), V(8, 0.07, z + 0.25), PLANK_D, { Mat = WOOD })
	end
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9, 0.08, Z1), PLANK_D, { Mat = WOOD })
	end
	-- rope rails beside the boardwalk (posts skip the ghost areas and the gates)
	for _, s in { -1, 1 } do
		local last: Vector3? = nil
		for z = Z0 + 28, Z1 - 28, 14 do
			local x = s * 9.6
			if clearOfAreas(x, z, 3) then
				Kit.Cyl(f, 3.6, 0.6, CFrame.new(x, 1.8, z), PLANK_D, { Mat = WOOD })
				local here = V(x, 3.1, z)
				if last and (here - last).Magnitude < 15 then
					Props.Beam(f, last, here, 0.25, 0.25, ROPE)
				end
				last = here
			else
				last = nil
			end
		end
	end
	-- ghost areas: flat grassy islands with a rocky rim and flowers
	local rng = Kit.Rng
	for i = 1, 4 do
		local a = AREAS[i]
		Kit.Disc(f, a[1], a[2], 0.08, a[3] * 2 + 5, 0.08, C(150, 150, 160), { Mat = ROCK })
		Kit.Disc(f, a[1], a[2], 0.11, a[3] * 2, 0.11, GRASSC, { Mat = GRASS })
		Kit.Disc(f, a[1] + a[3] * 0.25, a[2] - a[3] * 0.2, 0.13, a[3] * 0.9, 0.02, GRASS_L, { Mat = GRASS })
		for _ = 1, 8 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0.25, 0.9) * a[3]
			Kit.Disc(f, a[1] + math.cos(ang) * d, a[2] + math.sin(ang) * d, 0.15, 1.4, 0.04, Kit.Pick({ C(255, 230, 90), C(255, 150, 190), C(255, 255, 255), C(180, 160, 255) }))
		end
	end
	-- boss: navy wind-rose with gold points and a bolt
	local bz = AREAS[5][2]
	local gold = Kit.Vivid(BOLT)
	Kit.Disc(f, 0, bz, 0.08, 60, 0.08, CLOUD_L)
	Kit.Disc(f, 0, bz, 0.11, 56, 0.11, NAVY, { Mat = Enum.Material.Slate })
	Kit.Disc(f, 0, bz, 0.13, 46, 0.02, gold, { Mat = METAL })
	Kit.Disc(f, 0, bz, 0.15, 44, 0.04, C(55, 72, 130), { Mat = Enum.Material.Slate })
	for i = 0, 3 do
		local long = i % 2 == 0
		Kit.Part(f, V(if long then 4 else 3, 0.04, if long then 42 else 28), CFrame.new(0, if long then 0.19 else 0.17, bz) * CFrame.Angles(0, i * math.pi / 4, 0), if long then gold else CLOUD_L, { Mat = METAL })
	end
	Kit.Disc(f, 0, bz, 0.21, 8, 0.04, gold, { Mat = METAL })
	-- flat bolt glyph in the middle
	Kit.Part(f, V(2, 0.04, 6), CFrame.new(1, 0.23, bz + 2) * CFrame.Angles(0, 0.5, 0), NAVY)
	Kit.Part(f, V(2, 0.04, 6), CFrame.new(-1, 0.23, bz - 2) * CFrame.Angles(0, 0.5, 0), NAVY)
	-- grassy island patches on the cloud sea
	for _, p in { { -46, Z0 + 62, 9 }, { 50, Z0 + 120, 11 }, { -118, Z0 + 175, 10 }, { 32, Z0 + 255, 8 }, { 118, Z0 + 300, 10 }, { -100, Z0 + 330, 9 }, { 116, Z0 + 40, 8 } } do
		if Kit.IsFree(p[1], p[2], p[3] + 2) then
			-- a low grassy island (top 1.2, steppable) with a rocky skirt and cloud puffs round it
			Kit.Disc(f, p[1], p[2], 0.7, p[3] * 2 + 2, 1.2, C(120, 118, 130), { Mat = ROCK, Solid = true })
			Kit.Disc(f, p[1], p[2], 1.2, p[3] * 2, 0.5, GRASSC, { Mat = GRASS, Solid = true })
			Props.Tree(f, V(p[1] + 2, 1.2, p[2]), 9, Kit.Pick({ C(120, 200, 110), C(255, 200, 90), C(150, 220, 255) }))
			for i = 0, 4 do
				local a = i * 1.25 + 0.3
				Kit.Ball(f, 5, V(p[1] + math.cos(a) * (p[3] + 1.5), 0.3, p[2] + math.sin(a) * (p[3] + 1.5)), CLOUD_L)
			end
			Kit.AddCircle(p[1], p[2], p[3] + 3)
		end
	end
	-- painted "gaps" in the clouds: a deep-blue hole with tiny fields far below
	for _, p in { { -40, Z0 + 175, 11 }, { 40, Z0 + 52, 9 }, { 110, Z0 + 230, 12 }, { -112, Z0 + 270, 10 }, { 46, Z0 + 330, 9 } } do
		local x, z, r = p[1], p[2], p[3]
		if Kit.IsFree(x, z, r + 3) then
			Kit.Disc(f, x, z, 0.03, r * 2 + 3, 0.03, CLOUD_L)
			Kit.Disc(f, x, z, 0.06, r * 2, 0.03, C(70, 105, 170))
			Kit.Disc(f, x, z, 0.08, r * 1.4, 0.02, C(90, 135, 195))
			Kit.Part(f, V(r * 0.5, 0.02, r * 0.35), CFrame.new(x - r * 0.2, 0.1, z + r * 0.1) * CFrame.Angles(0, 0.4, 0), C(110, 170, 90))
			Kit.Part(f, V(r * 0.35, 0.02, r * 0.3), CFrame.new(x + r * 0.25, 0.1, z - r * 0.2) * CFrame.Angles(0, -0.3, 0), C(150, 190, 90))
			Kit.Disc(f, x + r * 0.15, z + r * 0.35, 0.11, r * 0.3, 0.02, C(80, 160, 230))
			for i = 0, 5 do
				local a = i * math.pi / 3 + 0.3
				Kit.Ball(f, 3.2, V(x + math.cos(a) * (r + 1), 0.2, z + math.sin(a) * (r + 1)), CLOUD_L)
			end
			Kit.AddCircle(x, z, r + 2)
		end
	end
end

--==================================================================
-- WALLS, CLOUD SEA, SKY
--==================================================================
local function sideWalls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 11, z1), C(150, 160, 190), { Solid = true, Shadow = true, Name = "CloudBank" })
		Kit.Box(f, V(s * 139.8, 6, z0), V(s * 140, 7, z1), Kit.Vivid(BOLT), { Mat = METAL })
		local i = 0
		for z = z0 + 4, z1 - 2, 11 do
			i += 1
			Kit.Ball(f, if i % 2 == 0 then 12 else 10, V(s * 143, 11.5, z), if i % 3 == 0 then CLOUD_M else CLOUD_L)
		end
		-- cloud sea outside the wall
		for z = Z0 + 30, Z1 - 20, 48 do
			puff(f, V(s * Kit.Rng:NextNumber(158, 180), -2, z + Kit.Rng:NextNumber(-10, 10)), Kit.Rng:NextNumber(18, 26), false)
		end
	end
end

local function sky(f: Instance)
	local rng = Kit.Rng
	-- thunderheads across the zone, high above everything
	for i = 0, 8 do
		local z = Z0 + 20 + i * 40
		thunderhead(f, V(rng:NextNumber(-120, 120), rng:NextNumber(84, 100), z), rng:NextNumber(18, 26))
	end
	for _, s in { -1, 1 } do
		for z = Z0 + 40, Z1, 110 do
			thunderhead(f, V(s * rng:NextNumber(170, 210), rng:NextNumber(55, 75), z), rng:NextNumber(28, 36))
		end
	end
	balloon(f, V(-176, 52, Z0 + 130), C(255, 120, 110), C(255, 230, 120))
	balloon(f, V(182, 64, Z0 + 270), C(110, 170, 255), C(255, 255, 255))
	-- distant sky islands beyond the walls
	island(f, -205, 30, Z0 + 230, 16)
	island(f, 215, 26, Z0 + 90, 14)
end

--==================================================================
-- FLOATING ISLANDS AND BRIDGES (inside the play area, high up)
--==================================================================
local function islands(f: Instance)
	local I1 = V(-112, 50, Z0 + 55)
	local I2 = V(112, 54, Z0 + 100)
	local I3 = V(-118, 58, Z0 + 185)
	local I4 = V(118, 48, Z0 + 250)
	local I5 = V(-108, 52, Z0 + 318)
	island(f, I1.X, I1.Y, I1.Z, 11)
	windmill(f, I1.X - 2, I1.Y, I1.Z + 2)
	island(f, I2.X, I2.Y, I2.Z, 13)
	cottage(f, I2.X + 2, I2.Y, I2.Z + 3)
	Props.Tree(f, V(I2.X - 7, I2.Y, I2.Z - 4), 7, C(255, 190, 220))
	island(f, I3.X, I3.Y, I3.Z, 10)
	Props.Tree(f, V(I3.X, I3.Y, I3.Z), 9, C(120, 200, 110))
	island(f, I4.X, I4.Y, I4.Z, 12)
	windmill(f, I4.X + 2, I4.Y, I4.Z)
	island(f, I5.X, I5.Y, I5.Z, 9)
	local rodTip = lightningRod(f, I5.X, I5.Y, I5.Z, 10)
	-- bridges: along each side, and two high spans over the boardwalk
	ropeBridge(f, I1 + V(0, 0, 10), I3 - V(0, 0, 9), 7)
	ropeBridge(f, I3 + V(0, 0, 9), I5 - V(0, 0, 8), 6)
	ropeBridge(f, I2 + V(0, 0, 12), I4 - V(0, 0, 11), 7)
	ropeBridge(f, I1 + V(10, 0, 2), I2 - V(12, 0, 2), 6)
	ropeBridge(f, I3 + V(9, 0, 3), I4 - V(11, 0, 3), 7)
	-- a thunderhead above the island rod and its bolt
	thunderhead(f, rodTip + V(4, 30, 0), 16)
	bolt(f, rodTip + V(4, 26, 0), rodTip, 0.7)
end

--==================================================================
-- GROUND DECOR
--==================================================================
local function thunderSpire(f: Instance)
	local x, z = 100, Z1 - 40
	if not Kit.IsFree(x, z, 11) then
		return
	end
	local m = Kit.Model(f, "ThunderSpire")
	Kit.Cyl(m, 6, 22, CFrame.new(x, 3, z), C(120, 125, 145), { Mat = ROCK, Solid = true, Shadow = true })
	Kit.Cyl(m, 1, 23, CFrame.new(x, 6.2, z), Kit.Vivid(BOLT), { Mat = METAL })
	Kit.Cyl(m, 38, 11, CFrame.new(x, 25, z), C(140, 148, 175), { Mat = Enum.Material.Cobblestone, Solid = true, Shadow = true })
	Kit.Cyl(m, 3, 13, CFrame.new(x, 45, z), STORM_D, { Mat = ROCK })
	for i = 0, 3 do
		local a = i * math.pi / 2
		Kit.Box(m, V(x + math.cos(a) * 5.6 - 0.9, 18, z + math.sin(a) * 5.6 - 0.9), V(x + math.cos(a) * 5.6 + 0.9, 22, z + math.sin(a) * 5.6 + 0.9), C(255, 225, 130))
	end
	Kit.Cyl(m, 32, 2.4, CFrame.new(x, 62, z), COPPER, { Mat = METAL, Refl = 0.1 })
	for i, y in { 52, 62, 72 } do
		Kit.Cyl(m, 0.8, 10 - i * 2, CFrame.new(x, y, z), Kit.Vivid(BOLT), { Mat = METAL })
	end
	local ball = Kit.Ball(m, 6, V(x, 80, z), Kit.Vivid(COPPER), { Mat = METAL, Refl = 0.25 })
	Kit.Light(ball, C(255, 240, 170), 45, 1.4)
	Kit.Cyl(m, 5, 0.5, CFrame.new(x, 85, z), C(230, 230, 240), { Mat = METAL })
	thunderhead(m, V(x - 6, 122, z + 4), 30)
	bolt(m, V(x - 4, 114, z + 2), V(x, 87.5, z), 1)
	local mist = Kit.Part(m, V(40, 1, 30), CFrame.new(x - 6, 112, z + 4), STORM, { Transp = 1, Name = "StormMist" })
	Kit.Emitter(mist, C(200, 205, 225), 3, 12, 0.4)
	Kit.AddCircle(x, z, 12)
end

local function decor(f: Instance)
	local rng = Kit.Rng
	-- lightning rods (two get kites)
	local kiteCols = { C(255, 90, 110), C(90, 200, 255), C(255, 200, 70) }
	local k = 0
	for _, p in { { -40, Z0 + 92 }, { 42, Z0 + 150 }, { -120, Z0 + 95 }, { 122, Z0 + 175 }, { -30, Z0 + 210 }, { 36, Z0 + 285 }, { -122, Z0 + 230 }, { 120, Z0 + 330 } } do
		if Kit.IsFree(p[1], p[2], 6) then
			lightningRod(f, p[1], 0, p[2], rng:NextNumber(18, 26))
		end
	end
	for _, p in { { -26, Z0 + 140 }, { 28, Z0 + 230 }, { -24, Z0 + 280 } } do
		local kx, kz = p[1] + (if p[1] < 0 then -7 else 7), p[2] + 5
		if Kit.IsFree(p[1], p[2], 2) and clearOfAreas(kx, kz, 4) then
			k += 1
			kite(f, p[1], p[2], kx, rng:NextNumber(20, 26), kz, kiteCols[k])
		end
	end
	-- cloud puffs on the cloud sea
	local placed = 0
	for _ = 1, 160 do
		if placed >= 46 then
			break
		end
		local x = rng:NextNumber(-132, 132)
		local z = rng:NextNumber(Z0 + 8, Z1 - 8)
		local d = rng:NextNumber(6, 13)
		if Kit.IsFree(x, z, d * 0.8) then
			placed += 1
			puff(f, V(x, -d * 0.12, z), d, false)
			Kit.AddCircle(x, z, d * 0.8)
		end
	end
	-- wind streaks in the air (thin pale strips)
	for _ = 1, 22 do
		local x = rng:NextNumber(-125, 125)
		local z = rng:NextNumber(Z0 + 20, Z1 - 20)
		local y = rng:NextNumber(14, 34)
		local len = rng:NextNumber(10, 18)
		if math.abs(x) > 14 and clearOfAreas(x, z, len / 2 + 2) then
			Kit.Part(f, V(len, 0.2, 0.6), CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), C(255, 255, 255), { Transp = 0.55, Name = "WindStreak" })
		end
	end
	-- a couple of small rocks drifting in the air
	for _, p in { V(-60, 30, Z0 + 40), V(70, 34, Z0 + 330), V(-40, 44, Z0 + 300) } do
		if clearOfAreas(p.X, p.Z, 3) then
			local r = Kit.Ball(f, 3.4, p, ROCKC, { Mat = ROCK, Name = "DriftRock" })
			Kit.Ball(f, 2.2, p + V(0, 1.4, 0), GRASSC, { Mat = GRASS })
			Kit.Float(r, 1.2)
		end
	end
	-- weather-vane sign by the crate station
	if Kit.IsFree(-46, Z0 + 30, 3) then
		local m = Kit.Model(f, "WeatherVane")
		Kit.Cyl(m, 12, 0.6, CFrame.new(-46, 6, Z0 + 30), C(90, 90, 100), { Mat = METAL })
		Kit.Part(m, V(0.3, 1.8, 6), CFrame.new(-46, 12.4, Z0 + 30), C(90, 90, 100), { Mat = METAL })
		Kit.Wedge(m, V(0.3, 2.4, 2), CFrame.new(-46, 12.4, Z0 + 27.6) * CFrame.Angles(math.pi / 2, 0, 0), Kit.Vivid(BOLT), { Mat = METAL })
		Kit.Ball(m, 1.2, V(-46, 13.6, Z0 + 30), Kit.Vivid(COPPER), { Mat = METAL })
		Props.SignBoard(m, V(-46, 4.5, Z0 + 29.6), 8, 2, 0, -1, "SKY ISLANDS", NAVY, C(255, 245, 200), BOLT)
		Kit.AddCircle(-46, Z0 + 30, 3)
	end
end

--==================================================================
-- BUILD
--==================================================================
function StormIslands.Build(map: Instance)
	local f = Kit.Folder(map, "StormIslands")
	ground(f)
	sideWalls(f)
	thunderSpire(f)
	islands(f)
	decor(f)
	sky(f)
end

return StormIslands
