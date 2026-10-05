--!strict
-- ZONE 32: The Void Throne (Z 12400..12880), the last area of World 2. Black-violet nothingness
-- under a dense star field: a starry obsidian floor, a path of floating stone slabs, broken
-- stone shards drifting in the air, a shattered ringed planet, nebula veils, small void rifts,
-- and a colossal black throne with a white star halo beyond the end of the play area.
--   Ghost areas are flat "orbit" medallions ((0,12485) r30, (-82,12520) r24, (75,12580) r26,
--   (-62,12640) r24); the Void Herald's area (0,12705) r26 is a flat violet star seal.
--   VOID EMPEROR ARENA: an open floor circle centred at (0, 12760), radius 60, with no props
--   (only flat floor parts, top <= 0.2). Folder Map.VoidThrone.VoidArena holds named flat
--   markers for the fight: VoidArenaCenter, VoidPylonSpot1..4 (radius 45 on the diagonals) and
--   VoidLightSpot1..4 (radius 28 at +-30 deg off the X axis). NOTE: the arena circle overlaps the
--   back half of the Herald's ghost area (Z 12700..12731); the markers stay clear of it.
--   Obelisks ring the arena just outside it (r 68), skipping the lane and the Herald's area.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local VoidThrone = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SLATE = Enum.Material.Slate
local ROCK = Enum.Material.Rock

local Z0, Z1 = 12400, 12880
local BACK = Z1 - 3 -- the throne backdrop starts here (route check ends at Z1 - 5)

local ARENA_Z = Z0 + 360 -- = Config.VoidEmperor.Center.Z
local ARENA_R = 60
local PYLON_R = 45
local LIGHT_R = 28

local VOID = C(20, 15, 32)
local VOID_L = C(34, 26, 54)
local STONE = C(62, 50, 88)
local STONE_D = C(44, 36, 66)
local STONE_L = C(86, 72, 118)
local VIOLET = C(150, 100, 230)
local LAVENDER = C(200, 175, 255)
local STARW = C(255, 255, 255)
local STARGOLD = C(255, 235, 170)

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 }, { 0, Z0 + 305, 26 } }

local function clearOfAreas(x: number, z: number, pad: number): boolean
	for _, a in AREAS do
		local dx, dz = x - a[1], z - a[2]
		if dx * dx + dz * dz < (a[3] + pad) * (a[3] + pad) then
			return false
		end
	end
	return true
end

local function clearOfArena(x: number, z: number, pad: number): boolean
	local dx, dz = x, z - ARENA_Z
	return dx * dx + dz * dz >= (ARENA_R + pad) * (ARENA_R + pad)
end

--==================================================================
-- HELPERS
--==================================================================
-- A thin flat ring outline: a coloured disc with a dark disc on top.
local function ringLine(parent: Instance, x: number, z: number, top: number, d: number, w: number, color: Color3, inner: Color3)
	Kit.Disc(parent, x, z, top, d, 0.02, color)
	Kit.Disc(parent, x, z, top + 0.02, d - w * 2, 0.02, inner)
end

-- Floating stone shard: a tilted slab with a small crystal.
local function shard(parent: Instance, pos: Vector3, s: number, float: boolean)
	local rng = Kit.Rng
	local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5))
	local body = Kit.Part(parent, V(s * 1.2, s * 2.6, s), cf, Kit.Pick({ STONE, STONE_D, STONE_L }), { Mat = SLATE, Name = "VoidShard" })
	Kit.Wedge(parent, V(s * 1.2, s * 1.2, s), cf * CFrame.new(0, -s * 1.9, 0) * CFrame.Angles(math.pi, 0, 0), STONE_D, { Mat = SLATE })
	Kit.Part(parent, V(s * 0.35, s * 0.9, s * 0.35), cf * CFrame.new(s * 0.2, s * 1.6, 0) * CFrame.Angles(0, 0, 0.3), Kit.Vivid(VIOLET), { Refl = 0.2 })
	if float then
		Kit.Float(body, rng:NextNumber(1.2, 2))
	end
end

-- A vertical void rift: black core with a jagged violet edge.
local function rift(parent: Instance, x: number, z: number, h: number)
	local m = Kit.Model(parent, "VoidRift")
	local rng = Kit.Rng
	local prev = V(x, 4, z)
	for i = 1, 5 do
		local p = V(x + rng:NextNumber(-1.6, 1.6), 4 + h * i / 5, z)
		Props.Beam(m, prev, p, 0.5, 0.5, LAVENDER, { Mat = if i % 2 == 1 then NEON else Enum.Material.SmoothPlastic })
		Props.Beam(m, prev + V(0, 0, 0.3), p + V(0, 0, 0.3), 2.2, 0.2, C(5, 2, 12))
		prev = p
	end
end

local function obelisk(parent: Instance, x: number, z: number, h: number)
	local m = Kit.Model(parent, "VoidObelisk")
	Kit.Box(m, V(x - 2.6, 0, z - 2.6), V(x + 2.6, 1.2, z + 2.6), STONE_D, { Mat = SLATE, Solid = true })
	Kit.Box(m, V(x - 1.6, 1.2, z - 1.6), V(x + 1.6, h, z + 1.6), C(28, 22, 44), { Mat = SLATE, Solid = true, Shadow = true })
	Kit.Wedge(m, V(3.2, 2.4, 1.6), CFrame.new(x, h + 1.2, z - 0.8) * CFrame.Angles(0, math.pi, 0), C(28, 22, 44), { Mat = SLATE })
	Kit.Wedge(m, V(3.2, 2.4, 1.6), CFrame.new(x, h + 1.2, z + 0.8), C(28, 22, 44), { Mat = SLATE })
	Kit.Box(m, V(x - 1.7, h * 0.6, z - 1.7), V(x + 1.7, h * 0.6 + 0.4, z + 1.7), Kit.Vivid(LAVENDER))
	Kit.Ball(m, 1.3, V(x, h + 3.2, z), STARW, { Mat = NEON })
	Kit.AddCircle(x, z, 3)
end

--==================================================================
-- GROUND, PATH, AREAS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), VOID, { Solid = true, Refl = 0.06, Name = "Ground_VoidThrone" })
	-- stepping slabs along X = 0 (a gap every slab shows the starry floor)
	local z = Z0
	local k = 0
	while z < Z1 do
		local z2 = math.min(z + 10, Z1)
		k += 1
		local dx = if k % 2 == 0 then 0.6 else -0.6
		-- (no slabs on the arena floor: it is the path there)
		if z2 < ARENA_Z - ARENA_R - 1 or z > ARENA_Z + ARENA_R + 1 then
			Kit.Box(f, V(-8 + dx, 0, z), V(8 + dx, 0.1, z2 - 1.6), if k % 3 == 0 then STONE_L else STONE, { Mat = SLATE, Solid = true, Name = "Path" })
			for _, s in { -1, 1 } do
				Kit.Box(f, V(s * 8 + dx - 0.25, 0, z), V(s * 8 + dx + 0.25, 0.11, z2 - 1.6), Kit.Vivid(LAVENDER))
			end
		end
		z += 12
	end
	-- star specks and a few constellations on the floor
	local rng = Kit.Rng
	local specks = {}
	for _ = 1, 140 do
		local x = rng:NextNumber(-138, 138)
		local zz = rng:NextNumber(Z0 + 2, Z1 - 2)
		if math.abs(x) > 9.5 then
			local s = rng:NextNumber(0.4, 1)
			Kit.Part(f, V(s, 0.03, s), CFrame.new(x, 0.015, zz) * CFrame.Angles(0, math.pi / 4, 0), if rng:NextNumber() < 0.75 then STARW else LAVENDER)
			table.insert(specks, V(x, 0.02, zz))
		end
	end
	for i = 1, 30, 3 do
		local a, b = specks[i], specks[i + 1]
		if a and b and (a - b).Magnitude < 60 and math.sign(a.X) == math.sign(b.X) then
			Props.Beam(f, a, b, 0.18, 0.02, C(110, 90, 170))
		end
	end
	-- ghost areas: flat orbit medallions
	for i = 1, 4 do
		local a = AREAS[i]
		local x, zz, r = a[1], a[2], a[3]
		Kit.Disc(f, x, zz, 0.06, r * 2 + 3, 0.06, Kit.Vivid(LAVENDER))
		Kit.Disc(f, x, zz, 0.08, r * 2, 0.02, VOID_L)
		ringLine(f, x, zz, 0.1, r * 1.45, 0.35, C(130, 110, 200), VOID_L)
		ringLine(f, x, zz, 0.14, r * 0.85, 0.35, C(130, 110, 200), VOID_L)
		Kit.Disc(f, x, zz, 0.2, 5, 0.04, STARGOLD)
		for j = 0, 2 do
			local ang = j * 2.1 + i
			local rr = if j == 1 then r * 0.425 else r * 0.725
			Kit.Disc(f, x + math.cos(ang) * rr, zz + math.sin(ang) * rr, 0.22, if j == 0 then 3.2 else 2.2, 0.04, if j == 2 then C(150, 200, 255) else LAVENDER)
		end
	end
	-- the Herald's star seal
	local hz = AREAS[5][2]
	Kit.Disc(f, 0, hz, 0.13, 58, 0.03, STARW)
	Kit.Disc(f, 0, hz, 0.15, 56, 0.02, C(48, 30, 86))
	ringLine(f, 0, hz, 0.17, 42, 0.4, LAVENDER, C(48, 30, 86))
	for i = 0, 3 do
		local long = i % 2 == 0
		Kit.Part(f, V(if long then 3 else 2, 0.03, if long then 38 else 24), CFrame.new(0, 0.225, hz) * CFrame.Angles(0, i * math.pi / 4, 0), STARW)
	end
	Kit.Disc(f, 0, hz, 0.26, 7, 0.04, STARGOLD)
end

--==================================================================
-- THE VOID EMPEROR ARENA (flat markers only)
--==================================================================
local function arena(f: Instance)
	local a = Kit.Folder(f, "VoidArena")
	a:SetAttribute("Center", V(0, 0, ARENA_Z))
	a:SetAttribute("Radius", ARENA_R)
	Kit.Disc(a, 0, ARENA_Z, 0.05, ARENA_R * 2 + 4, 0.05, Kit.Vivid(LAVENDER), { Name = "ArenaRim" })
	Kit.Disc(a, 0, ARENA_Z, 0.07, ARENA_R * 2, 0.02, C(26, 19, 42), { Name = "ArenaFloor" })
	ringLine(a, 0, ARENA_Z, 0.09, PYLON_R * 2 + 1, 0.3, C(120, 100, 190), C(26, 19, 42))
	ringLine(a, 0, ARENA_Z, 0.09, LIGHT_R * 2 - 4, 0.25, C(90, 75, 150), C(26, 19, 42))
	-- centre (the final merged light circle)
	local center = Kit.Disc(a, 0, ARENA_Z, 0.14, 14, 0.03, STARGOLD, { Name = "VoidArenaCenter" })
	center:SetAttribute("Radius", 7)
	Kit.Disc(a, 0, ARENA_Z, 0.16, 10, 0.02, C(40, 30, 64))
	-- spokes from the centre toward the pylons
	for i = 0, 3 do
		local ang = math.rad(45 + i * 90)
		local mid = (PYLON_R + 7) / 2
		Kit.Part(a, V(0.5, 0.02, PYLON_R - 13), CFrame.new(math.cos(ang) * mid, 0.13, ARENA_Z + math.sin(ang) * mid) * CFrame.Angles(0, -ang + math.pi / 2, 0), C(110, 90, 175))
	end
	for i = 1, 4 do
		local ang = math.rad(45 + (i - 1) * 90)
		local x, z = math.cos(ang) * PYLON_R, ARENA_Z + math.sin(ang) * PYLON_R
		local spot = Kit.Disc(a, x, z, 0.14, 11, 0.03, Kit.Vivid(VIOLET), { Name = "VoidPylonSpot" .. i })
		spot:SetAttribute("Radius", 5.5)
		Kit.Disc(a, x, z, 0.16, 8, 0.02, C(30, 22, 50))
		for j = 0, 3 do
			local t = j * math.pi / 2
			Kit.Part(a, V(1, 0.02, 1), CFrame.new(x + math.cos(t) * 2.2, 0.17, z + math.sin(t) * 2.2) * CFrame.Angles(0, math.pi / 4, 0), LAVENDER)
		end
	end
	for i, deg in { 30, 150, 210, 330 } do
		local ang = math.rad(deg)
		local x, z = math.cos(ang) * LIGHT_R, ARENA_Z + math.sin(ang) * LIGHT_R
		local spot = Kit.Disc(a, x, z, 0.14, 12, 0.03, STARGOLD, { Name = "VoidLightSpot" .. i })
		spot:SetAttribute("Radius", 6)
		Kit.Disc(a, x, z, 0.16, 9.4, 0.02, C(60, 48, 40))
		Kit.Disc(a, x, z, 0.18, 2.4, 0.02, STARGOLD)
	end
	-- obelisks ringing the arena just outside it
	for _, deg in { 0, 30, 60, 120, 150, 180, 210, 330 } do
		local ang = math.rad(deg)
		local x, z = math.cos(ang) * (ARENA_R + 8), ARENA_Z + math.sin(ang) * (ARENA_R + 8)
		if math.abs(x) > 12 and clearOfAreas(x, z, 4) and Kit.IsFree(x, z, 3) then
			obelisk(f, x, z, 14)
		end
	end
	Kit.AddCircle(0, ARENA_Z, ARENA_R + 2)
end

--==================================================================
-- WALLS, SKY
--==================================================================
local function sideWalls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 11, z1), C(16, 12, 26), { Solid = true, Shadow = true, Refl = 0.12, Name = "ObsidianWall" })
		Kit.Box(f, V(s * 139.6, 11, z0), V(s * 146.4, 11.6, z1), Kit.Vivid(LAVENDER))
		local k = 0
		for z = z0 + 14, z1 - 8, 38 do
			k += 1
			Kit.Box(f, V(s * 139, 0, z - 2.4), V(s * 147, 24, z + 2.4), C(30, 22, 48), { Mat = SLATE, Solid = true })
			Kit.Wedge(f, V(8, 4, 2.4), CFrame.new(s * 143, 26, z - 1.2) * CFrame.Angles(0, math.pi, 0), C(30, 22, 48), { Mat = SLATE })
			Kit.Wedge(f, V(8, 4, 2.4), CFrame.new(s * 143, 26, z + 1.2), C(30, 22, 48), { Mat = SLATE })
			Kit.Ball(f, 1.4, V(s * 143, 28.6, z), if k % 2 == 0 then STARW else LAVENDER, { Mat = NEON })
		end
	end
	-- rifts hanging just inside the walls
	for _, p in { { -132, Z0 + 70 }, { 132, Z0 + 140 }, { -132, Z0 + 300 }, { 132, Z0 + 390 } } do
		if Kit.IsFree(p[1], p[2], 3) then
			rift(f, p[1], p[2], 20)
			Kit.AddCircle(p[1], p[2], 3)
		end
	end
end

local function sky(f: Instance)
	local rng = Kit.Rng
	-- dense star field (small neon dots, a few tinted)
	for _ = 1, 95 do
		local p = V(rng:NextNumber(-360, 360), rng:NextNumber(70, 320), rng:NextNumber(Z0 - 60, Z1 + 260))
		if math.abs(p.X) > 150 or p.Y > 110 then
			local tint = rng:NextNumber()
			Kit.Ball(f, rng:NextNumber(1.2, 3), p, if tint < 0.7 then STARW elseif tint < 0.85 then LAVENDER else C(170, 210, 255), { Mat = NEON, Name = "Star" })
		end
	end
	-- nebula veils, high and far
	local veils: { { P: Vector3, D: number, Col: Color3 } } = {
		{ P = V(-160, 230, Z1 + 160), D = 260, Col = C(120, 70, 200) },
		{ P = V(150, 260, Z1 + 120), D = 220, Col = C(70, 90, 210) },
		{ P = V(0, 300, Z1 + 220), D = 300, Col = C(170, 80, 190) },
		{ P = V(-260, 180, Z0 + 150), D = 200, Col = C(90, 60, 180) },
	}
	for _, n in veils do
		local cf = CFrame.new(n.P) * CFrame.Angles(math.rad(70), rng:NextNumber(-0.4, 0.4), math.rad(rng:NextNumber(-20, 20)))
		Kit.Part(f, V(3, n.D, n.D), cf * CFrame.Angles(0, 0, math.pi / 2), n.Col, { Shape = Enum.PartType.Cylinder, Transp = 0.9, Name = "Nebula" })
		Kit.Part(f, V(3, n.D * 0.55, n.D * 0.55), cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), n.Col:Lerp(STARW, 0.3), { Shape = Enum.PartType.Cylinder, Transp = 0.88, Name = "Nebula" })
	end
	-- the shattered ringed planet off to the +X side
	local m = Kit.Model(f, "ShatteredPlanet")
	local c = V(250, 130, Z0 + 170)
	Kit.Ball(m, 100, c, C(70, 45, 110))
	Kit.Ball(m, 60, c + V(-30, 22, -18), C(95, 60, 140))
	Kit.Part(m, V(1.5, 200, 200), CFrame.new(c) * CFrame.Angles(math.rad(12), 0, math.rad(78)), C(190, 170, 240), { Shape = Enum.PartType.Cylinder, Transp = 0.35 })
	for i = 1, 6 do
		local p = c + V(-60 - i * 9, rng:NextNumber(-30, 40), rng:NextNumber(-60, 60))
		Kit.Ball(m, rng:NextNumber(5, 12), p, Kit.Pick({ C(70, 45, 110), C(95, 60, 140) }), { Mat = ROCK })
	end
	-- giant floating rocks outside the walls
	for _, s in { -1, 1 } do
		for z = Z0 + 40, Z1 - 20, 95 do
			shard(f, V(s * rng:NextNumber(175, 220), rng:NextNumber(25, 70), z + rng:NextNumber(-20, 20)), rng:NextNumber(9, 15), false)
		end
	end
end

--==================================================================
-- FLOATING SHARDS IN THE PLAY AREA
--==================================================================
local function shards(f: Instance)
	local rng = Kit.Rng
	local placed, floated = 0, 0
	for _ = 1, 120 do
		if placed >= 22 then
			break
		end
		local x = rng:NextNumber(-128, 128)
		local z = rng:NextNumber(Z0 + 30, Z1 - 10)
		local s = rng:NextNumber(2, 4.5)
		if math.abs(x) > 16 and clearOfAreas(x, z, 8) and clearOfArena(x, z, 12) and Kit.IsFree(x, z, 4, true) then
			placed += 1
			local float = floated < 3 and placed % 4 == 0
			if float then
				floated += 1
			end
			shard(f, V(x, rng:NextNumber(14, 38), z), s, float)
		end
	end
	-- half-sunk broken slabs on the floor (low, beside the path)
	for _, p in { { -30, Z0 + 40 }, { 34, Z0 + 130 }, { -36, Z0 + 205 }, { 112, Z0 + 270 }, { -118, Z0 + 170 }, { 118, Z0 + 60 } } do
		if Kit.IsFree(p[1], p[2], 5) then
			local cf = CFrame.new(p[1], 1.5, p[2]) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(0.3, 0.7))
			Kit.Part(f, V(8, 3, 6), cf, STONE_D, { Mat = SLATE, Solid = true })
			Kit.Part(f, V(1.2, 3, 1.2), CFrame.new(p[1] + 2, 2.4, p[2] - 1) * CFrame.Angles(0, 0.4, 0.35), Kit.Vivid(VIOLET), { Refl = 0.2 })
			Kit.AddCircle(p[1], p[2], 5)
		end
	end
end

--==================================================================
-- THE THRONE (behind the end of the play area)
--==================================================================
local function throne(f: Instance)
	local m = Kit.Model(f, "VoidThroneBackdrop")
	local black = C(18, 13, 30)
	local blackL = C(34, 26, 52)
	Kit.Box(m, V(-190, -4, Z1), V(190, 0, Z1 + 120), VOID, { Solid = true })
	-- dais: three tiers rising away from the arena
	for i = 0, 2 do
		local z = BACK + i * 5
		Kit.Box(m, V(-44 + i * 5, i * 3, z), V(44 - i * 5, (i + 1) * 3, Z1 + 60), if i % 2 == 0 then STONE_D else STONE, { Mat = SLATE, Shadow = true })
		Kit.Box(m, V(-44 + i * 5, (i + 1) * 3 - 0.4, z - 0.2), V(44 - i * 5, (i + 1) * 3, z), Kit.Vivid(LAVENDER))
	end
	local seatZ = BACK + 20
	-- seat and cushion
	Kit.Box(m, V(-24, 9, seatZ), V(24, 22, seatZ + 20), black, { Mat = SLATE, Shadow = true })
	Kit.Box(m, V(-21, 22, seatZ - 0.5), V(21, 26, seatZ + 17), C(80, 45, 140), { Mat = Enum.Material.Fabric })
	-- arms ending in clawed points
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 24, 9, seatZ - 4), V(s * 32, 36, seatZ + 24), blackL, { Mat = SLATE, Shadow = true })
		Kit.Wedge(m, V(8, 8, 6), CFrame.new(s * 28, 40, seatZ - 1) * CFrame.Angles(0, math.pi, 0), blackL, { Mat = SLATE })
		Kit.Ball(m, 3, V(s * 28, 37.5, seatZ - 5), STARW, { Mat = NEON })
	end
	-- the tall jagged backrest
	Kit.Box(m, V(-26, 22, seatZ + 18), V(26, 120, seatZ + 26), black, { Mat = SLATE, Shadow = true })
	Kit.Box(m, V(-18, 28, seatZ + 17.6), V(18, 112, seatZ + 18), C(48, 30, 86), { Mat = Enum.Material.Fabric })
	for i, h in { 128, 142, 156, 142, 128 } do
		local x = -24 + (i - 1) * 12
		Kit.Box(m, V(x - 4, 116, seatZ + 19), V(x + 4, h - 6, seatZ + 25), black, { Mat = SLATE })
		Kit.Wedge(m, V(8, 10, 3), CFrame.new(x, h - 1, seatZ + 20.5) * CFrame.Angles(0, math.pi, 0), black, { Mat = SLATE })
		Kit.Wedge(m, V(8, 10, 3), CFrame.new(x, h - 1, seatZ + 23.5), black, { Mat = SLATE })
		Kit.Ball(m, if i == 3 then 4 else 2.6, V(x, h + 5, seatZ + 22), STARW, { Mat = NEON })
	end
	-- white star emblem on the backrest
	local emblem = V(0, 78, seatZ + 17.4)
	for i = 0, 3 do
		Kit.Part(m, V(if i % 2 == 0 then 3 else 2, if i % 2 == 0 then 30 else 18, 0.4), CFrame.new(emblem) * CFrame.Angles(0, 0, i * math.pi / 4), STARW)
	end
	local gem = Kit.Ball(m, 7, emblem - V(0, 0, 0.6), STARGOLD, { Mat = NEON })
	Kit.Light(gem, C(230, 210, 255), 60, 1.6)
	-- halo ring behind the throne: 16 alternating black and white blocks
	local hc = V(0, 92, seatZ + 34)
	for i = 0, 15 do
		local a = i * math.pi / 8
		Kit.Part(m, V(12, 5, 3), CFrame.new(hc + V(math.cos(a) * 52, math.sin(a) * 52, 0)) * CFrame.Angles(0, 0, a + math.pi / 2), if i % 2 == 0 then STARW else black)
	end
	-- braziers on the dais with pale violet flames
	for _, s in { -1, 1 } do
		local x = s * 38
		Kit.Cyl(m, 8, 4, CFrame.new(x, 13, BACK + 12), blackL, { Mat = SLATE })
		Kit.Cyl(m, 2, 7, CFrame.new(x, 18, BACK + 12), STONE_L, { Mat = SLATE })
		local flame = Kit.Ball(m, 4.6, V(x, 20.5, BACK + 12), LAVENDER, { Mat = NEON, Transp = 0.15 })
		if s < 0 then
			Kit.Light(flame, LAVENDER, 40, 1.2)
		end
	end
	-- floating slabs around the throne
	for _, p in { V(-70, 40, seatZ + 10), V(72, 52, seatZ + 4), V(-96, 78, seatZ + 30), V(100, 92, seatZ + 26) } do
		shard(m, p, 6, false)
	end
	Props.SignBoard(m, V(0, 1.5, BACK - 0.4), 32, 2.6, 0, -1, "THE VOID THRONE", C(30, 20, 50), STARW)
	local motes = Kit.Part(m, V(60, 4, 10), CFrame.new(0, 40, seatZ + 8), STARW, { Transp = 1, Name = "VoidMotes" })
	Kit.Emitter(motes, LAVENDER, 4, 2, 1)
end

--==================================================================
-- BUILD
--==================================================================
function VoidThrone.Build(map: Instance)
	local f = Kit.Folder(map, "VoidThrone")
	ground(f)
	arena(f)
	sideWalls(f)
	shards(f)
	sky(f)
	throne(f)
end

return VoidThrone
