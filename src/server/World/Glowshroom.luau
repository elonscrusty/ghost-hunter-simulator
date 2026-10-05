--!strict
-- ZONE 20: Glowshroom Forest (Z 8080..8440). A deep blue night forest where the trees are giant
-- mushrooms: teal, blue and violet caps with pale spots, softly lit gills, spores drifting.
--   Ground: dark blue-green moss with a slate trail along X = 0 dotted with mushroom-slice
--   stepping stones. An arch of two leaning mushroom stems with one shared cap (underside Y 44)
--   spans the trail at Z 8120 above the "GLOWSHROOM FOREST" sign.
--   Ghost areas are mossy clearings, each ringed by a fairy ring of little glowing toadstools
--   just OUTSIDE the circle ((0,8165) r30, (-82,8200) r24, (75,8260) r26, (-62,8320) r24); the
--   boss area (0,8385) r26 is a flat glowing mycelium web. Giant mushrooms only overhang a
--   ghost area with caps above Y 41.
--   The Mother Mushroom (landmark, cap ~Y 96) stands at the back left, a mushroom cottage at
--   the front right, a glowing pond with lily pads, blue grass tufts, fallen logs, tiny spores.
--   Glow is kept modest: neon only on small caps, spots and spores; big caps are solid colour.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Glowshroom = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass
local SLATE = Enum.Material.Slate
local WOOD = Enum.Material.Wood

local Z0, Z1 = 8080, 8440

local MOSS = C(26, 58, 66)
local MOSS_L = C(40, 88, 92)
local TRAIL = C(52, 68, 84)
local STEM = C(218, 232, 228)
local STEM_B = C(170, 200, 205)
local TEAL = C(40, 170, 170)
local BLUE = C(60, 110, 210)
local VIOLET = C(130, 80, 200)
local PINK = C(210, 100, 190)
local GLOW_T = C(120, 255, 230) -- zone accent
local GLOW_B = C(140, 200, 255)
local SPOT = C(235, 250, 255)
local ROCK = C(32, 44, 62)
local BARK = C(60, 50, 60)
local WATER = C(30, 80, 120)

local CAPS = { TEAL, BLUE, VIOLET, C(50, 140, 200), PINK }
local GLOWS = { GLOW_T, GLOW_B, C(200, 160, 255) }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
local function clearOfAreas(x: number, z: number, pad: number): boolean
	for _, a in { AREAS[1], AREAS[2], AREAS[3], AREAS[4], { 0, BOSS_Z, 26 } } do
		local dx, dz = x - a[1], z - a[2]
		if dx * dx + dz * dz < (a[3] + pad) ^ 2 then
			return false
		end
	end
	return true
end

-- Mushroom: stem with a flared foot, a lighter gill disc, a domed cap of stacked discs and
-- pale spots. capY = height of the cap's underside.
local function shroom(parent: Instance, x: number, z: number, capY: number, capD: number, stemD: number, cap: Color3, spots: boolean, glowGills: boolean)
	local m = Kit.Model(parent, "Mushroom")
	local big = capD > 14
	Kit.Cyl(m, capY, stemD, CFrame.new(x, capY / 2, z), STEM, { Mat = Enum.Material.SmoothPlastic, Solid = big, Shadow = big })
	Kit.Disc(m, x, z, 1.2, stemD * 1.6, 1.2, STEM_B, { Solid = big })
	-- a little skirt ring on taller stems
	if capY > 14 then
		Kit.Cyl(m, 0.8, stemD * 1.5, CFrame.new(x, capY * 0.72, z), STEM_B)
	end
	local gill = cap:Lerp(C(255, 255, 255), 0.45)
	Kit.Disc(m, x, z, capY + 0.4, capD * 0.92, 0.4, gill, if glowGills then { Mat = NEON, Transp = 0.15 } else nil)
	local h = capD * 0.12
	Kit.Disc(m, x, z, capY + 0.4 + h, capD, h, cap)
	Kit.Disc(m, x, z, capY + 0.4 + h * 2, capD * 0.78, h, cap)
	Kit.Disc(m, x, z, capY + 0.4 + h * 2.8, capD * 0.48, h * 0.8, cap:Lerp(C(255, 255, 255), 0.08))
	if spots then
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.6
			local r = capD * 0.3
			Kit.Ball(m, capD * 0.11, V(x + math.cos(a) * r, capY + 0.4 + h * 2.1, z + math.sin(a) * r), SPOT)
		end
	end
	return m
end

-- Little glowing toadstool (2 parts). lit = neon cap.
local function toadstool(parent: Instance, x: number, z: number, h: number, color: Color3, lit: boolean)
	Kit.Cyl(parent, h, h * 0.35, CFrame.new(x, h / 2, z), STEM)
	Kit.Disc(parent, x, z, h + h * 0.3, h * 0.95, h * 0.35, color, if lit then { Mat = NEON } else nil)
end

local function grassTuft(parent: Instance, x: number, z: number)
	local rng = Kit.Rng
	for k = 0, 2 do
		local h = rng:NextNumber(3, 6)
		local a = k * 2.1 + rng:NextNumber(-0.4, 0.4)
		Kit.Part(parent, V(0.4, h, 0.9), CFrame.new(x + math.cos(a) * 0.6, h / 2 - 0.2, z + math.sin(a) * 0.6) * CFrame.Angles(math.cos(a) * 0.3, a, math.sin(a) * 0.3), Kit.Pick({ C(70, 150, 200), C(60, 190, 170), C(110, 120, 220) }))
	end
end

--==================================================================
-- GROUND
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), MOSS, { Mat = GRASS, Solid = true, Name = "Ground_Glowshroom" })
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), TRAIL, { Mat = SLATE, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 10, 0.07, Z1), C(60, 140, 130), { Mat = GRASS })
	end
	-- mushroom-slice stepping stones along the trail
	local i = 0
	for z = Z0 + 6, Z1 - 4, 11 do
		i += 1
		local x = if i % 2 == 0 then -2.6 else 2.6
		Kit.Disc(f, x, z, 0.12, 5.4, 0.08, C(225, 220, 200), { Mat = WOOD })
		Kit.Disc(f, x, z, 0.14, 3.4, 0.03, C(200, 190, 165), { Mat = WOOD })
	end
	-- lighter moss patches
	local rng = Kit.Rng
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-125, 125), rng:NextNumber(Z0 + 20, Z1 - 20)
		if math.abs(x) > 16 then
			Kit.Disc(f, x, z, 0.04, rng:NextNumber(10, 22), 0.04, MOSS_L, { Mat = GRASS })
		end
	end
	-- mossy clearings + fairy rings just outside each ghost circle
	for idx, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.08, r * 2 + 2, 0.08, C(70, 150, 140), { Mat = GRASS })
		Kit.Disc(f, x, z, 0.11, r * 2 - 1, 0.11, C(22, 44, 58), { Mat = GRASS })
		Kit.Disc(f, x, z, 0.14, r * 1.1, 0.03, C(50, 120, 130), { Mat = GRASS })
		Kit.Disc(f, x, z, 0.16, r * 1.0, 0.05, C(22, 44, 58), { Mat = GRASS })
		Kit.Disc(f, x, z, 0.18, 4, 0.18, GLOWS[idx % #GLOWS + 1], { Mat = NEON })
		local n = math.floor(r * 0.42)
		for k = 0, n - 1 do
			local ang = k * math.pi * 2 / n + idx
			local rr = r + 3
			local px, pz = x + math.cos(ang) * rr, z + math.sin(ang) * rr
			if Kit.IsFree(px, pz, 0.8) then
				toadstool(f, px, pz, 1.6 + (k % 3) * 0.5, GLOWS[(k + idx) % #GLOWS + 1], k % 3 == 0)
			end
		end
	end
	-- boss: glowing mycelium web (flat strands radiating and branching)
	Kit.Disc(f, 0, BOSS_Z, 0.08, 56, 0.08, C(70, 150, 140), { Mat = GRASS })
	Kit.Disc(f, 0, BOSS_Z, 0.11, 53, 0.11, C(18, 34, 48), { Mat = GRASS })
	for k = 0, 9 do
		local a = k * math.pi / 5 + 0.2
		local mid = V(math.cos(a) * 12, 0.15, BOSS_Z + math.sin(a) * 12)
		local tipA = V(math.cos(a - 0.3) * 24, 0.15, BOSS_Z + math.sin(a - 0.3) * 24)
		local tipB = V(math.cos(a + 0.25) * 23, 0.15, BOSS_Z + math.sin(a + 0.25) * 23)
		local col = if k % 2 == 0 then GLOW_T else C(90, 200, 200)
		Props.Beam(f, V(0, 0.15, BOSS_Z), mid, 0.7, 0.06, col)
		Props.Beam(f, mid, tipA, 0.45, 0.06, col)
		Props.Beam(f, mid, tipB, 0.45, 0.06, col)
	end
	Kit.Disc(f, 0, BOSS_Z, 0.19, 7, 0.06, GLOW_T, { Mat = NEON, Transp = 0.2 })
	local n = 16
	for k = 0, n - 1 do
		local ang = k * math.pi * 2 / n
		local px, pz = math.cos(ang) * 29.5, BOSS_Z + math.sin(ang) * 29.5
		if Kit.IsFree(px, pz, 0.8) then
			toadstool(f, px, pz, 2 + (k % 2) * 0.8, GLOWS[k % #GLOWS + 1], k % 2 == 1)
		end
	end
end

--==================================================================
-- EDGES AND OUTSIDE
--==================================================================
local function sideWalls(f: Instance)
	local rng = Kit.Rng
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 26, z1), ROCK, { Mat = Enum.Material.Rock, Solid = true, Shadow = true })
		-- mossy lumps along the top and foot of the rock wall
		for z = z0 + 10, z1 - 6, 26 do
			Kit.Ball(f, rng:NextNumber(10, 15), V(s * 143, 26 + rng:NextNumber(-2, 1), z), MOSS_L, { Mat = GRASS })
			if Kit.IsFree(s * 136, z + 13, 3) then
				Kit.Ball(f, rng:NextNumber(5, 8), V(s * 139, 0, z + 13), MOSS_L, { Mat = GRASS })
			end
		end
	end
	-- giant mushrooms leaning over the walls (stems outside, caps reaching in)
	for z = Z0 + 30, Z1 - 30, 46 do
		for _, s in { -1, 1 } do
			local x = s * rng:NextNumber(150, 160)
			shroom(f, x, z + s * 10, rng:NextNumber(34, 52), rng:NextNumber(32, 44), rng:NextNumber(5, 7), Kit.Pick(CAPS), true, false)
		end
	end
end

local function outside(f: Instance)
	local rng = Kit.Rng
	-- far mushroom forest silhouettes
	for z = Z0 + 10, Z1 - 10, 60 do
		for _, s in { -1, 1 } do
			local x = s * rng:NextNumber(176, 190)
			shroom(f, x, z + s * 25, rng:NextNumber(55, 85), rng:NextNumber(40, 56), 9, Kit.Pick(CAPS):Lerp(C(20, 30, 50), 0.35), false, false)
		end
	end
	-- the Mother Mushroom (landmark at the back left)
	local mx, mz = -104, Z0 + 330
	if Kit.IsFree(mx, mz, 10) then
		local m = shroom(f, mx, mz, 88, 74, 16, TEAL, true, true)
		m.Name = "MotherMushroom"
		-- roots, a door and windows at her foot (the forest's little library of spores)
		for k = 0, 5 do
			local a = k * math.pi / 3 + 0.3
			Props.Beam(m, V(mx + math.cos(a) * 6, 4, mz + math.sin(a) * 6), V(mx + math.cos(a) * 13, -0.5, mz + math.sin(a) * 13), 2.2, 2.2, STEM_B)
		end
		Kit.Part(m, V(5, 8, 1), CFrame.new(mx + 6, 4, mz - 6.4) * CFrame.Angles(0, Kit.FaceYaw(0.7, -0.7), 0), C(120, 80, 70), { Mat = WOOD })
		local win = Kit.Part(m, V(3, 3, 1), CFrame.new(mx - 3, 30, mz - 7.6), C(255, 220, 150), { Mat = Enum.Material.Glass })
		Kit.Light(win, GLOW_T, 50, 1)
		local spores = Kit.Part(m, V(60, 4, 60), CFrame.new(mx, 84, mz), GLOW_T, { Transp = 1, Name = "SporeCloud" })
		Kit.Emitter(spores, C(170, 255, 235), 4, 1.4, 0.6)
		Kit.AddCircle(mx, mz, 10)
	end
end

--==================================================================
-- FEATURES
--==================================================================
local function entranceArch(f: Instance)
	local m = Kit.Model(f, "ShroomArch")
	local z = Z0 + 40
	local Y = 44 -- cap underside: above Y 41 because the cap overhangs the first ghost clearing
	for _, s in { -1, 1 } do
		local foot = V(s * 15, 0, z)
		Props.Beam(m, foot, V(s * 5, Y + 1, z), 3.2, 3.2, STEM)
		Kit.Disc(m, foot.X, z, 1, 6, 1, STEM_B, { Solid = true })
		Kit.AddCircle(foot.X, z, 3.5)
	end
	Kit.Disc(m, 0, z, Y + 0.6, 34, 0.6, TEAL:Lerp(C(255, 255, 255), 0.45))
	Kit.Disc(m, 0, z, Y + 4, 38, 3.4, BLUE)
	Kit.Disc(m, 0, z, Y + 7, 28, 3, BLUE)
	Kit.Disc(m, 0, z, Y + 9.4, 15, 2.4, BLUE:Lerp(C(255, 255, 255), 0.08))
	for k = 0, 5 do
		local a = k * math.pi / 3
		Kit.Ball(m, 3.2, V(math.cos(a) * 11, Y + 5.5, z + math.sin(a) * 11), SPOT)
	end
	local sign = Props.SignBoard(m, V(0, 30, z - 1), 22, 3.4, 0, -1, "GLOWSHROOM FOREST", C(30, 50, 70), Kit.Vivid(GLOW_T), C(120, 90, 70))
	Props.SignBoard(m, V(0, 30, z + 1), 22, 3.4, 0, 1, "GLOWSHROOM FOREST", C(30, 50, 70), Kit.Vivid(GLOW_T))
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 8 - 0.2, 31.7, z - 0.2), V(s * 8 + 0.2, Y, z + 0.2), C(120, 90, 70))
	end
	Kit.Light(sign, GLOW_T, 26, 0.8)
end

local function cottage(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "MushroomCottage")
	Kit.Cyl(m, 16, 18, CFrame.new(x, 8, z), C(240, 230, 205), { Mat = Enum.Material.Plaster, Solid = true, Shadow = true })
	Kit.Disc(m, x, z, 16.6, 28, 0.6, C(240, 200, 230))
	Kit.Disc(m, x, z, 19, 32, 2.6, PINK)
	Kit.Disc(m, x, z, 21.4, 25, 2.4, PINK)
	Kit.Disc(m, x, z, 23.4, 14, 2, PINK:Lerp(C(255, 255, 255), 0.1))
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		Kit.Ball(m, 3, V(x + math.cos(a) * 10, 21, z + math.sin(a) * 10), SPOT)
	end
	-- door + round windows facing the trail (-X)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(-1, -0.3), 0)
	Kit.Part(m, V(4, 7, 1), cf * CFrame.new(0, 3.5, -8.7), C(110, 75, 60), { Mat = WOOD })
	Kit.Ball(m, 0.6, (cf * CFrame.new(1.2, 3.4, -9.3)).Position, C(230, 190, 90))
	for _, dx in { -5, 5 } do
		Kit.Part(m, V(1, 3, 3), cf * CFrame.new(dx, 10, -8.3) * CFrame.Angles(0, math.pi / 2 - dx * 0.06, 0), C(255, 215, 140), { Mat = Enum.Material.Glass, Shape = Enum.PartType.Cylinder })
	end
	Kit.Box(m, V(x + 4, 18, z + 2), V(x + 7, 27, z + 5), C(150, 110, 90), { Mat = Enum.Material.Brick })
	-- a garden fence of twigs and a mailbox mushroom
	toadstool(m, x - 12, z + 8, 3.4, GLOW_B, true)
	toadstool(m, x - 12, z - 9, 2.6, GLOW_T, false)
	Kit.AddCircle(x, z, 12)
end

local function pond(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GlowPond")
	Kit.Disc(m, x, z, 0.06, 30, 0.06, C(50, 70, 80), { Mat = SLATE })
	Kit.Disc(m, x, z, 0.1, 26, 0.08, WATER, { Mat = Enum.Material.Glass, Refl = 0.3 })
	local rng = Kit.Rng
	for k = 1, 6 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 10)
		Kit.Disc(m, x + math.cos(a) * r, z + math.sin(a) * r, 0.18, rng:NextNumber(2.4, 4), 0.05, C(60, 150, 110))
		if k % 2 == 0 then
			Kit.Ball(m, 0.9, V(x + math.cos(a) * r, 0.5, z + math.sin(a) * r), GLOW_B, { Mat = NEON })
		end
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.2
		local px, pz = x + math.cos(a) * 15, z + math.sin(a) * 15
		if k % 2 == 0 then
			Kit.Cyl(m, 6, 0.4, CFrame.new(px, 3, pz), C(60, 120, 100))
			Kit.Cyl(m, 1.4, 0.8, CFrame.new(px, 5.6, pz), C(90, 70, 60))
		else
			grassTuft(m, px, pz)
		end
	end
	Kit.AddCircle(x, z, 16)
end

local function fallenLog(f: Instance, x: number, z: number, yaw: number)
	local m = Kit.Model(f, "FallenLog")
	local cf = CFrame.new(x, 2, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(m, V(18, 4, 4), cf, BARK, { Mat = WOOD, Solid = true, Shape = Enum.PartType.Cylinder })
	Kit.Part(m, V(0.3, 3.6, 3.6), cf * CFrame.new(9.05, 0, 0), C(180, 150, 120), { Mat = WOOD, Shape = Enum.PartType.Cylinder })
	for k = -1, 1 do
		local p = (cf * CFrame.new(k * 5, 2, 0)).Position
		Kit.Cyl(m, 1.4, 0.5, CFrame.new(p + V(0, 0.6, 0)), STEM)
		Kit.Disc(m, p.X, p.Z, p.Y + 1.7, 1.9, 0.5, GLOWS[k + 2], if k == 0 then { Mat = NEON } else nil)
	end
	Kit.AddCircle(x, z, 9)
end

local function decor(f: Instance)
	local rng = Kit.Rng
	-- giant mushrooms inside the forest (stems clear of everything, caps above Y 41 when
	-- they overhang a ghost area)
	local giants = { { 46, Z0 + 120, 48 }, { -42, Z0 + 175, 54 }, { 40, Z0 + 235, 46 }, { -110, Z0 + 160, 40 }, { 112, Z0 + 140, 50 }, { 118, Z0 + 230, 44 }, { -118, Z0 + 270, 38 }, { 50, Z0 + 330, 52 }, { -48, Z0 + 60, 36 } }
	local ng = 0
	for i, g in giants do
		local x, z, capD = g[1], g[2], g[3]
		if ng < 8 and Kit.IsFree(x, z, 5) then
			ng += 1
			local capY = if clearOfAreas(x, z, capD / 2) then rng:NextNumber(26, 40) else rng:NextNumber(42, 52)
			shroom(f, x, z, capY, capD, rng:NextNumber(4.5, 6.5), CAPS[i % #CAPS + 1], true, i % 3 == 0)
			Kit.AddCircle(x, z, 5)
		end
	end
	-- medium and small mushroom clusters
	local nm, ns, nt, nl = 0, 0, 0, 0
	for _ = 1, 600 do
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 14, Z1 - 12)
		if nm < 12 and Kit.IsFree(x, z, 6) then
			nm += 1
			local capD = rng:NextNumber(8, 12)
			shroom(f, x, z, rng:NextNumber(7, 13), capD, rng:NextNumber(1.6, 2.4), Kit.Pick(CAPS), nm % 2 == 0, nm % 4 == 1)
			Kit.AddCircle(x, z, capD / 2)
		elseif ns < 14 and Kit.IsFree(x, z, 2.5) then
			ns += 1
			for k = 0, 2 do
				toadstool(f, x + math.cos(k * 2.1) * 1.4, z + math.sin(k * 2.1) * 1.4, rng:NextNumber(1.4, 3), Kit.Pick(GLOWS), k == 0 and ns % 2 == 0)
			end
			Kit.AddCircle(x, z, 2.5)
		elseif nt < 16 and Kit.IsFree(x, z, 1.5) then
			nt += 1
			grassTuft(f, x, z)
			Kit.AddCircle(x, z, 1.5)
		elseif nl < 2 and Kit.IsFree(x, z, 9) then
			nl += 1
			fallenLog(f, x, z, rng:NextNumber(0, math.pi))
		end
	end
	-- floating spores (tiny glowing dots; above Y 41 over the ghost areas)
	for i = 1, 22 do
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 10, Z1 - 10)
		local y = if clearOfAreas(x, z, 1) then rng:NextNumber(3, 30) else rng:NextNumber(42, 60)
		local p = Kit.Ball(f, rng:NextNumber(0.5, 1), V(x, y, z), Kit.Pick(GLOWS), { Mat = NEON, Name = "Spore" })
		if i <= 3 then
			Kit.Float(p, rng:NextNumber(1, 2))
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function Glowshroom.Build(map: Instance)
	local f = Kit.Folder(map, "Glowshroom")
	ground(f)
	entranceArch(f)
	sideWalls(f)
	outside(f)
	if Kit.IsFree(108, Z0 + 62, 12) then
		cottage(f, 108, Z0 + 62)
	end
	if Kit.IsFree(-112, Z0 + 60, 16) then
		pond(f, -112, Z0 + 60)
	end
	decor(f)
end

return Glowshroom
