--!strict
-- ZONE 15: Inferno Caverns (Z 4840..5200). A cosy-hot volcanic cavern: dark basalt, warm glow.
--   Ground: basalt slab + slate lane along X = 0 with ember-orange edging.
--   Ghost areas get flat scorched rings ((0,4925) r30, (-82,4960) r24, (75,5020) r26,
--   (-62,5080) r24); the boss area (0,5145) r26 is an obsidian disc with ember runes.
--   Lava (flat neon, a few big pieces, all outside the lane and the ghost areas): a river at
--   Z 4988..4998 from the west wall to a pool at (36, 4993), crossed by a solid glass bridge on
--   the lane; pools in the front corners; cracks in the west back corner.
--   Rock arches over the lane at Z 4970 and Z 5100 (span bottom Y 32).
--   Landmark seen from the Clockwork Tower: the volcano at (98, 5152), crater ~Y 108.
--   Crystal clusters, obsidian spikes, cute fire-salamander statues, braziers, cliffs outside.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Inferno = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local BASALT = Enum.Material.Basalt
local SLATE = Enum.Material.Slate
local METAL = Enum.Material.Metal
local ROCK = Enum.Material.Rock

local Z0, Z1 = 4840, 5200
local RIVER_Z1, RIVER_Z2 = Z0 + 148, Z0 + 158

local GROUND = C(58, 48, 52)
local ROCKC = C(78, 60, 58)
local ROCK_D = C(48, 40, 44)
local ROCK_R = C(105, 55, 45)
local LAVA = C(255, 120, 35)
local LAVA_Y = C(255, 175, 60)
local EMBER = C(255, 150, 60)
local GOLD = C(255, 200, 80)
local DEEP_RED = C(150, 45, 40)
local OBSIDIAN = C(35, 28, 45)
local SAL = C(255, 110, 60)
local SAL_SPOT = C(255, 215, 80)

local SOLID_ROCK: Kit.Opts = { Mat = BASALT, Solid = true, Shadow = true }
local LAVA_O: Kit.Opts = { Mat = NEON }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
local function crack(parent: Instance, p: Vector3, segs: number, w: number)
	local rng = Kit.Rng
	local a = rng:NextNumber(0, math.pi * 2)
	for _ = 1, segs do
		a += rng:NextNumber(-0.8, 0.8)
		local q = p + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(4, 7)
		Props.Beam(parent, p, q, w, 0.06, LAVA, LAVA_O)
		p = q
	end
end

-- Flat lava pool: dark rim discs under glowing discs (tops below Y 0.1).
local function pool(parent: Instance, pieces: { { number } }, light: boolean)
	for i, d in pieces do
		Kit.Disc(parent, d[1], d[2], 0.04, d[3] + 5, 0.04, ROCK_D, { Mat = SLATE })
		local p = Kit.Disc(parent, d[1], d[2], 0.06 + i * 0.005, d[3], 0.05, if i == 1 then LAVA else LAVA_Y, LAVA_O)
		if light and i == 1 then
			Kit.Light(p, EMBER, 40, 1.8)
		end
	end
end

local function crystals(parent: Instance, x: number, z: number, color: Color3, glow: boolean, light: boolean)
	local rng = Kit.Rng
	local m = Kit.Model(parent, "Crystals")
	for i = 1, 4 do
		local h = rng:NextNumber(4, 9) * (if i == 1 then 1.3 else 1)
		local w = rng:NextNumber(1.4, 2.4)
		local p = V(x + rng:NextNumber(-2, 2), h / 2 - 0.5, z + rng:NextNumber(-2, 2))
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 1.5), rng:NextNumber(-0.35, 0.35)) * CFrame.Angles(0, math.pi / 4, 0)
		local opts: Kit.Opts = if glow and i == 1 then { Mat = NEON } else { Refl = 0.25, Transp = 0.1 }
		local c = Kit.Part(m, V(w, h, w), cf, if i % 2 == 0 then Kit.Vivid(color) else color:Lerp(Color3.new(1, 1, 1), 0.2), opts)
		if light and i == 1 then
			Kit.Light(c, color, 26, 1.4)
		end
	end
	Kit.Ball(m, 4, V(x, -0.8, z), ROCK_D, { Mat = BASALT })
	Kit.AddCircle(x, z, 4)
end

local function spikes(parent: Instance, x: number, z: number)
	local rng = Kit.Rng
	local m = Kit.Model(parent, "ObsidianSpikes")
	for i = 1, 3 do
		local h = rng:NextNumber(8, 18) * (if i == 1 then 1.2 else 0.8)
		local w = rng:NextNumber(2.4, 3.6)
		local p = V(x + rng:NextNumber(-2.5, 2.5), h / 2 - 1, z + rng:NextNumber(-2.5, 2.5))
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 1.5), rng:NextNumber(-0.25, 0.25))
		Kit.Part(m, V(w, h, w * 0.7), cf, OBSIDIAN, { Refl = 0.3, Solid = i == 1, Shadow = true })
		Kit.Wedge(m, V(w, w * 1.2, w * 0.7), cf * CFrame.new(0, h / 2 + w * 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0), OBSIDIAN, { Refl = 0.3 })
	end
	Kit.AddCircle(x, z, 4.5)
end

-- Cute fire salamander statue facing (fx, fz); s = scale.
local function salamander(parent: Instance, x: number, z: number, s: number, fx: number, fz: number)
	local m = Kit.Model(parent, "SalamanderStatue")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local ph = 2.5 * math.min(s, 1.6)
	local body = Kit.Vivid(SAL)
	Kit.Part(m, V(6 * s, ph, 9 * s), base * CFrame.new(0, ph / 2, 0.8 * s), ROCK_R, { Mat = SLATE, Solid = true, Shadow = true })
	Kit.Part(m, V(6.4 * s, 0.5, 9.4 * s), base * CFrame.new(0, ph, 0.8 * s), Kit.Vivid(GOLD), { Mat = METAL })
	local y = ph + 0.25
	Kit.Ball(m, 3.6 * s, (base * CFrame.new(0, y + 1.6 * s, 0.4 * s)).Position, body, { Shadow = true })
	Kit.Ball(m, 3.2 * s, (base * CFrame.new(0, y + 1.5 * s, 2.6 * s)).Position, body)
	Kit.Ball(m, 3.8 * s, (base * CFrame.new(0, y + 2.8 * s, -2 * s)).Position, body, { Shadow = true })
	for _, sx in { -1, 1 } do
		Kit.Ball(m, 1.4 * s, (base * CFrame.new(sx * 0.85 * s, y + 3.7 * s, -3.4 * s)).Position, C(255, 255, 250))
		Kit.Ball(m, 0.75 * s, (base * CFrame.new(sx * 0.85 * s, y + 3.75 * s, -3.95 * s)).Position, C(30, 20, 30))
		Kit.Ball(m, 0.8 * s, (base * CFrame.new(sx * 1.4 * s, y + 2.6 * s, -3.4 * s)).Position, C(255, 150, 170))
		for _, lz in { -0.6, 2.8 } do
			Kit.Part(m, V(1 * s, 1.4 * s, 1 * s), base * CFrame.new(sx * 1.5 * s, y + 0.7 * s, lz * s), body)
		end
	end
	-- curly tail with an ember tip
	local t0 = (base * CFrame.new(0, y + 1.3 * s, 4 * s)).Position
	local t1 = (base * CFrame.new(1.6 * s, y + 0.8 * s, 6.4 * s)).Position
	Props.Beam(m, t0, t1, 1.3 * s, 1.3 * s, body)
	Kit.Ball(m, 1.6 * s, t1 + V(0, 0.5 * s, 0), LAVA_Y, if s > 1.5 then LAVA_O else nil)
	for i = 0, 2 do
		Kit.Ball(m, 0.9 * s, (base * CFrame.new((i - 1) * 0.7 * s, y + 3.3 * s, (0.2 + i * 1.1) * s)).Position, Kit.Vivid(SAL_SPOT))
	end
	Kit.AddCircle(x, z, 5.5 * s)
end

local function brazier(parent: Instance, x: number, z: number, light: boolean)
	local m = Kit.Model(parent, "Brazier")
	Kit.Cyl(m, 4, 2.4, CFrame.new(x, 2, z), ROCKC, SOLID_ROCK)
	Kit.Cyl(m, 1.6, 4.4, CFrame.new(x, 4.8, z), C(60, 50, 55), { Mat = METAL })
	Kit.Cyl(m, 0.4, 4.6, CFrame.new(x, 5.4, z), Kit.Vivid(GOLD), { Mat = METAL })
	local flame = Kit.Ball(m, 2.6, V(x, 6, z), EMBER, { Mat = NEON, Transp = 0.1 })
	if light then
		Kit.Light(flame, EMBER, 26, 1.6, true)
	end
	Kit.AddCircle(x, z, 3)
end

--==================================================================
-- GROUND, LAVA, WALLS, OUTSIDE
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), GROUND, { Mat = BASALT, Solid = true, Name = "Ground_Inferno" })
	-- slate lane with ember edging, interrupted by the glass bridge over the lava river
	local edge = Kit.Vivid(C(220, 120, 60))
	for _, seg in { { Z0, RIVER_Z1 - 2 }, { RIVER_Z2 + 2, Z1 } } do
		Kit.Box(f, V(-9, 0, seg[1]), V(9, 0.05, seg[2]), C(105, 80, 72), { Mat = SLATE, Solid = true, Name = "Path" })
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * 9, 0, seg[1]), V(s * 10, 0.08, seg[2]), edge, { Mat = SLATE })
		end
	end
	-- scorched rings on the ghost areas
	for i, a in AREAS do
		Kit.Disc(f, a[1], a[2], 0.07, a[3] * 2 + 4, 0.07, if i % 2 == 0 then DEEP_RED else ROCK_R, { Mat = SLATE })
		Kit.Disc(f, a[1], a[2], 0.1, a[3] * 2, 0.1, C(82, 66, 66), { Mat = SLATE })
		Kit.Disc(f, a[1], a[2], 0.13, 8, 0.13, Kit.Vivid(GOLD), { Mat = METAL })
		crack(f, V(a[1] + 9, 0.15, a[2] - 6), 1, 0.5)
	end
	-- boss: obsidian disc, gold ring, ember runes
	Kit.Disc(f, 0, BOSS_Z, 0.07, 58, 0.07, Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Disc(f, 0, BOSS_Z, 0.1, 54, 0.1, OBSIDIAN, { Mat = SLATE, Refl = 0.15 })
	for i = 0, 3 do
		local a1 = i * math.pi / 2 + 0.2
		local a2 = a1 + math.pi / 2 - 0.4
		Props.Beam(f, V(math.cos(a1) * 20, 0.14, BOSS_Z + math.sin(a1) * 20), V(math.cos(a2) * 20, 0.14, BOSS_Z + math.sin(a2) * 20), 0.7, 0.05, LAVA, LAVA_O)
	end
	Kit.Disc(f, 0, BOSS_Z, 0.17, 6, 0.06, EMBER, LAVA_O)
end

local function lava(f: Instance)
	local m = Kit.Model(f, "Lava")
	-- river from the west wall to a pool east of the lane
	local river = Kit.Box(m, V(-136, 0, RIVER_Z1), V(30, 0.06, RIVER_Z2), LAVA, { Mat = NEON, Name = "LavaRiver" })
	Kit.Light(river, EMBER, 30, 1.2) -- centre of the river (by the glass bridge)
	for _, zz in { RIVER_Z1 - 1.2, RIVER_Z2 } do
		Kit.Box(m, V(-136, 0, zz), V(-12.5, 0.12, zz + 1.2), ROCK_D, { Mat = BASALT })
		Kit.Box(m, V(12.5, 0, zz), V(30, 0.12, zz + 1.2), ROCK_D, { Mat = BASALT })
	end
	pool(m, { { 36, (RIVER_Z1 + RIVER_Z2) / 2, 18 } }, false)
	-- glass bridge on the lane (solid, top Y 0.25)
	Kit.Box(m, V(-12, 0, RIVER_Z1 - 2), V(12, 0.25, RIVER_Z2 + 2), C(255, 200, 160), { Mat = Enum.Material.Glass, Transp = 0.45, Refl = 0.1, Solid = true, Name = "GlassBridge" })
	local gold = Kit.Vivid(GOLD)
	for _, s in { -1, 1 } do
		for _, zz in { RIVER_Z1 - 2, RIVER_Z2 + 2 } do
			Kit.Box(m, V(s * 12.6 - 0.4, 0, zz - 0.4), V(s * 12.6 + 0.4, 2.6, zz + 0.4), gold, { Mat = METAL })
			Kit.Ball(m, 1.2, V(s * 12.6, 3, zz), gold, { Mat = METAL })
		end
		Kit.Box(m, V(s * 12.6 - 0.2, 2, RIVER_Z1 - 2), V(s * 12.6 + 0.2, 2.4, RIVER_Z2 + 2), gold, { Mat = METAL })
	end
	-- corner pools
	pool(m, { { -102, Z0 + 52, 34 }, { -122, Z0 + 70, 20 }, { -80, Z0 + 44, 14 } }, true)
	local embers = Kit.Part(m, V(24, 0.4, 24), CFrame.new(-104, 1, Z0 + 56), EMBER, { Transp = 1, Name = "EmberSource" })
	local e = Kit.Emitter(embers, C(255, 170, 70), 3, 0.8, 2)
	if e then
		e.LightEmission = 1
		e.Acceleration = V(0, 3, 0)
	end
	pool(m, { { 112, Z0 + 58, 30 }, { 126, Z0 + 84, 16 } }, true)
	-- cracks in the west back corner
	crack(m, V(-112, 0.1, Z0 + 330), 3, 2.2)
	Props.SignBoard(m, V(-70, 4, Z0 + 76), 10, 3, 1, -1, "HOT! DO NOT LICK", C(60, 30, 30), Kit.Vivid(LAVA_Y), GOLD)
	Kit.Box(m, V(-70.4, 0, Z0 + 76.4), V(-69.6, 2.5, Z0 + 77.2), ROCKC, { Mat = BASALT })
	Kit.AddCircle(-70, Z0 + 76, 6)
end

local function sideWalls(f: Instance)
	local rng = Kit.Rng
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 34, z1), ROCKC, SOLID_ROCK)
		Kit.Box(f, V(s * 139.7, 0, z0), V(s * 140, 3, z1), ROCK_R, { Mat = SLATE })
		for z = z0 + 10, z1 - 10, 32 do
			local w = rng:NextNumber(8, 14)
			local cf = CFrame.new(s * 143, 34 + rng:NextNumber(1, 4), z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 1), rng:NextNumber(-0.3, 0.3))
			Kit.Part(f, V(w, rng:NextNumber(6, 12), w), cf, Kit.Pick({ ROCKC, ROCK_D, ROCK_R }), { Mat = BASALT })
		end
		-- glowing magma veins on the inner face
		local x = s * 139.75
		local zv = if s < 0 then Z0 + 210 else Z0 + 120
		Props.Beam(f, V(x, 1, zv), V(x, 12, zv + 6), 0.6, 0.6, LAVA, LAVA_O)
		Props.Beam(f, V(x, 12, zv + 6), V(x, 22, zv + 1), 0.5, 0.5, LAVA, LAVA_O)
	end
end

local function outside(f: Instance)
	local rng = Kit.Rng
	local cols = { ROCKC, ROCK_D, C(70, 50, 50) }
	for _, s in { -1, 1 } do
		for i = 0, 7 do
			local z = Z0 + 14 + i * 46
			local w = rng:NextNumber(26, 44)
			local h = rng:NextNumber(46, 74)
			local cf = CFrame.new(s * (149 + w / 2), h / 2 - 3, z) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), s * rng:NextNumber(0.02, 0.1))
			Kit.Part(f, V(w, h, rng:NextNumber(38, 52)), cf, Kit.Pick(cols), { Mat = ROCK })
			if i % 2 == 0 then
				Kit.Ball(f, rng:NextNumber(40, 60), V(s * rng:NextNumber(185, 205), rng:NextNumber(4, 18), z + 20), Kit.Pick(cols), { Mat = BASALT })
			end
		end
	end
end

--==================================================================
-- LANDMARKS
--==================================================================
local function rockArch(f: Instance, z: number, title: string?)
	local m = Kit.Model(f, "RockArch")
	local rng = Kit.Rng
	for _, s in { -1, 1 } do
		local y = 0
		for i = 1, 3 do
			local h = if i == 3 then 36 - y else rng:NextNumber(10, 14)
			local w = 10 - i * 0.8
			local cf = CFrame.new(s * 23, y + h / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
			Kit.Part(m, V(w, h, 8 - i * 0.6), cf, if i % 2 == 0 then ROCK_D else ROCKC, SOLID_ROCK)
			y += h
		end
		local c = Kit.Part(m, V(1.6, 4, 1.6), CFrame.new(s * 18.6, 14, z - 3) * CFrame.Angles(0.3, 0.6, s * 0.4), Kit.Vivid(C(255, 120, 200)), if s < 0 then LAVA_O else { Refl = 0.25 })
		c.Name = "ArchCrystal"
		Kit.AddRect(s * 17, z - 5, s * 29, z + 5)
	end
	-- span (bottom Y 32) and rough top boulders
	Kit.Box(m, V(-28, 32, z - 4), V(28, 40, z + 4), ROCKC, SOLID_ROCK)
	Kit.Part(m, V(20, 8, 9), CFrame.new(-10, 42, z) * CFrame.Angles(0, 0.1, 0.12), ROCK_D, { Mat = BASALT })
	Kit.Part(m, V(18, 7, 8), CFrame.new(12, 42, z) * CFrame.Angles(0, -0.12, -0.1), ROCK_R, { Mat = BASALT })
	if title then
		Props.SignBoard(m, V(0, 35.8, z - 4.4), 30, 4, 0, -1, title, C(50, 25, 25), Kit.Vivid(LAVA_Y), GOLD)
	end
end

local function volcano(f: Instance)
	local m = Kit.Model(f, "Volcano")
	local x, z = 98, Z0 + 312
	local ds = { 76, 64, 52, 42, 32, 24 }
	local H = 18
	for i, d in ds do
		local t = (i - 1) / (#ds - 1)
		Kit.Cyl(m, H, d, CFrame.new(x, H * (i - 0.5), z), ROCK_D:Lerp(ROCK_R, t * 0.8), { Mat = BASALT, Solid = i <= 2, Shadow = true })
	end
	local top = H * #ds
	local crater = Kit.Disc(m, x, z, top + 0.15, 16, 0.3, LAVA, LAVA_O)
	Kit.Light(crater, EMBER, 60, 2)
	for i = 0, 2 do
		local a = i * 2.1 + 0.4
		Kit.Part(m, V(7, 5, 6), CFrame.new(x + math.cos(a) * 10, top + 1.5, z + math.sin(a) * 10) * CFrame.Angles(0.2, a, -0.15), ROCK_D, { Mat = BASALT })
	end
	-- two lava streams down the tiers (toward the lane and toward the approach)
	for _, ang in { math.pi, -math.pi / 2 - 0.35 } do
		local dir = V(math.cos(ang), 0, math.sin(ang))
		local function pt(r: number, y: number): Vector3
			return V(x, y, z) + dir * r
		end
		local pts = { pt(12.6, top), pt(21.6, H * 4), pt(32.6, H * 2), pt(38.6, H), pt(39.6, 0.2) }
		for i = 1, #pts - 1 do
			Props.Beam(m, pts[i], pts[i + 1], 3, 1, if i % 2 == 0 then LAVA_Y else LAVA, LAVA_O)
		end
	end
	local smoke = Kit.Part(m, V(12, 1, 12), CFrame.new(x, top + 3, z), C(90, 80, 80), { Transp = 1, Name = "SmokeSource" })
	local e = Kit.Emitter(smoke, C(110, 95, 95), 2, 14, 4)
	if e then
		e.Acceleration = V(0, 3, 0)
	end
	Kit.AddCircle(x, z, 40)
end

local function floaters(f: Instance)
	for _, p in { V(-36, 24, Z0 + 150), V(40, 28, Z0 + 110), V(-112, 26, Z0 + 180), V(118, 30, Z0 + 230), V(-30, 22, Z0 + 340) } do
		local r = Kit.Ball(f, Kit.Rng:NextNumber(2.4, 3.6), p, Kit.Vivid(C(200, 90, 50)), { Mat = BASALT, Name = "FloatingEmberRock" })
		Kit.Float(r, 1.6)
	end
end

local function decor(f: Instance)
	local rng = Kit.Rng
	-- salamander statues welcoming hunters and one big one in the back corner
	for _, p in { { -18, Z0 + 52 }, { 18, Z0 + 52 }, { 20, Z0 + 205 }, { -20, Z0 + 200 }, { -40, Z0 + 330 } } do
		if Kit.IsFree(p[1], p[2], 5.5) then
			salamander(f, p[1], p[2], 1, if p[1] < 0 then 1 else -1, 0)
		end
	end
	if Kit.IsFree(-100, Z0 + 322, 12) then
		salamander(f, -100, Z0 + 322, 2.2, 1, -1)
	end
	for i, p in { { -14, Z0 + 232 }, { 14, Z0 + 232 } } do
		if Kit.IsFree(p[1], p[2], 3) then
			brazier(f, p[1], p[2], i == 1)
		end
	end
	-- basalt column clusters (hexagonal causeway look) and rock buttresses on the walls
	for _, p in { { -118, Z0 + 120 }, { 120, Z0 + 140 }, { -40, Z0 + 290 }, { 124, Z0 + 250 }, { -126, Z0 + 230 } } do
		if Kit.IsFree(p[1], p[2], 7) then
			for i = 0, 5 do
				local a = i * math.pi / 3
				local r = if i == 0 then 0 else 3.6
				local h = rng:NextNumber(3, 12) + (if i == 0 then 6 else 0)
				local cx, cz = p[1] + math.cos(a) * r, p[2] + math.sin(a) * r
				Kit.Cyl(f, h, 3.8, CFrame.new(cx, h / 2, cz), Kit.Pick({ ROCKC, ROCK_D, C(68, 56, 60) }), { Mat = BASALT, Solid = i == 0, Shadow = true })
			end
			Kit.AddCircle(p[1], p[2], 7)
		end
	end
	for _, s in { -1, 1 } do
		for z = Z0 + 30, Z1 - 30, 50 do
			if Kit.IsFree(s * 134, z, 2) then
				local w = rng:NextNumber(5, 8)
				Kit.Part(f, V(w, rng:NextNumber(30, 40), w * 1.4), CFrame.new(s * (140 - w / 2 + 1), 15, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), s * 0.06), Kit.Pick({ ROCKC, ROCK_D }), SOLID_ROCK)
			end
		end
	end
	-- stalagmites
	local nst = 0
	for _ = 1, 300 do
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 10)
		if nst < 12 and Kit.IsFree(x, z, 3.5) then
			nst += 1
			local h = rng:NextNumber(6, 14)
			local col = Kit.Pick({ ROCKC, ROCK_R, C(92, 70, 64) })
			Kit.Cyl(f, h * 0.45, 4.4, CFrame.new(x, h * 0.225, z), col, { Mat = BASALT, Solid = true, Shadow = true })
			Kit.Cyl(f, h * 0.35, 3, CFrame.new(x, h * 0.45 + h * 0.175, z), col, { Mat = BASALT })
			Kit.Cyl(f, h * 0.25, 1.6, CFrame.new(x, h * 0.8 + h * 0.125, z), col:Lerp(Color3.new(1, 0.6, 0.3), 0.15), { Mat = BASALT })
			if nst % 3 == 0 then
				local x2, z2 = x + 3, z + 2
				Kit.Cyl(f, h * 0.5, 2.4, CFrame.new(x2, h * 0.25, z2), col, { Mat = BASALT })
			end
			Kit.AddCircle(x, z, 3.5)
		end
	end
	-- crystals and obsidian spikes
	local cols = { C(255, 90, 170), C(255, 170, 60), C(255, 220, 100), C(200, 100, 255) }
	local nc, ns, nb = 0, 0, 0
	for _ = 1, 500 do
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 30, Z1 - 10)
		if nc < 10 and Kit.IsFree(x, z, 4) then
			nc += 1
			crystals(f, x, z, cols[(nc - 1) % #cols + 1], nc <= 3, nc == 1)
		elseif ns < 11 and Kit.IsFree(x, z, 4.5) then
			ns += 1
			spikes(f, x, z)
		elseif nb < 10 and Kit.IsFree(x, z, 3.5) then
			nb += 1
			Kit.Ball(f, rng:NextNumber(4, 7), V(x, -0.6, z), Kit.Pick({ ROCKC, ROCK_D, ROCK_R }), { Mat = BASALT, Solid = true })
			Kit.AddCircle(x, z, 3.5)
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function Inferno.Build(map: Instance)
	local f = Kit.Folder(map, "Inferno")
	ground(f)
	lava(f)
	sideWalls(f)
	outside(f)
	rockArch(f, Z0 + 130, "INFERNO CAVERNS")
	rockArch(f, Z0 + 260, nil)
	volcano(f)
	floaters(f)
	decor(f)
end

return Inferno
