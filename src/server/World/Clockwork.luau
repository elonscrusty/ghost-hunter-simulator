--!strict
-- ZONE 14: Clockwork Tower (Z 4480..4840). A steampunk town square in brass, copper and wood.
--   Ground: cobblestone slab + brick lane along X = 0 with brass edging.
--   Ghost areas get flat gear-shaped plazas ((0,4565) r30, (-82,4600) r24, (75,4660) r26,
--   (-62,4720) r24); the boss area (0,4785) r26 is a giant clock face painted on the square.
--   Cogwheel bridges over the lane at Z 4625 and Z 4745 (deck bottom Y 30).
--   Landmark seen from the Sunken City: the clock tower at (64, 4808), spire tip ~Y 150.
--   Shops along the sides, brass lamp posts, a gear monument, a grandfather clock, giant
--   gears and steam pipes on the side walls (brick, X +-140..146), a chimney skyline and an
--   airship outside.
-- Glow: lamp globes, a couple of shop windows, the tower clock and the monument gem.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Clockwork = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local BRICK = Enum.Material.Brick
local COBBLE = Enum.Material.Cobblestone
local WOOD = Enum.Material.WoodPlanks

local Z0, Z1 = 4480, 4840

local BRASS = C(215, 170, 85)
local BRASS_D = C(170, 130, 70)
local COPPER = C(190, 110, 70)
local VERDI = C(90, 175, 160) -- teal verdigris accents
local BROWN = C(120, 80, 55)
local BRICKC = C(160, 95, 70)
local CREAM = C(240, 225, 190)
local COBBLEC = C(150, 132, 118)
local DARK = C(55, 40, 35)
local WARM = C(255, 210, 130)
local IRON = C(70, 62, 60)

local SOLID_BRICK: Kit.Opts = { Mat = BRICK, Solid = true, Shadow = true }
local BRASS_M: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
-- Gear standing upright: axis "X" (faces +-X) or "Z" (faces +-Z). pos = centre.
local function gear(parent: Instance, pos: Vector3, d: number, axis: string, color: Color3, teeth: number, thick: number?)
	local t = thick or 1.2
	local R = d / 2
	local tooth = math.max(1, d * 0.12)
	Kit.CylFlat(parent, t, d, pos, axis, color, BRASS_M)
	Kit.CylFlat(parent, t + 0.3, d * 0.62, pos, axis, color:Lerp(Color3.new(0, 0, 0), 0.18), BRASS_M)
	Kit.CylFlat(parent, t + 0.8, d * 0.22, pos, axis, Kit.Vivid(COPPER), BRASS_M)
	for i = 0, teeth - 1 do
		local a = i * math.pi * 2 / teeth
		if axis == "X" then
			Kit.Part(parent, V(t, tooth, tooth * 1.1), CFrame.new(pos + V(0, math.sin(a), math.cos(a)) * (R + tooth * 0.35)) * CFrame.Angles(math.pi / 2 - a, 0, 0), color, BRASS_M)
		else
			Kit.Part(parent, V(tooth * 1.1, tooth, t), CFrame.new(pos + V(math.cos(a), math.sin(a), 0) * (R + tooth * 0.35)) * CFrame.Angles(0, 0, a - math.pi / 2), color, BRASS_M)
		end
	end
end

-- Clock face facing (nx, nz); pos = centre of the face.
local function clockFace(parent: Instance, pos: Vector3, d: number, nx: number, nz: number, glow: boolean)
	local cf = CFrame.new(pos) * CFrame.Angles(0, Kit.FaceYaw(nx, nz), 0)
	local axisZ = CFrame.Angles(0, math.pi / 2, 0)
	Kit.Part(parent, V(1, d + 2, d + 2), cf * axisZ, Kit.Vivid(BRASS), { Mat = METAL, Shape = Enum.PartType.Cylinder })
	local faceOpts: Kit.Opts = if glow then { Mat = NEON, Shape = Enum.PartType.Cylinder } else { Shape = Enum.PartType.Cylinder }
	local face = Kit.Part(parent, V(0.4, d, d), cf * CFrame.new(0, 0, -0.6) * axisZ, if glow then C(255, 240, 200) else CREAM, faceOpts)
	if d >= 8 then
		local panel = Kit.Part(parent, V(d * 0.9, d * 0.9, 0.05), cf * CFrame.new(0, 0, -0.85), CREAM, { Transp = 1, Name = "ClockNumerals" })
		local gui = Kit.Gui(panel, Enum.NormalId.Front, 20)
		local ink = C(70, 45, 30)
		local st = CREAM
		Kit.Label(gui, "XII", ink, { Pos = UDim2.fromScale(0.38, 0.02), Size = UDim2.fromScale(0.24, 0.15), Stroke = st })
		Kit.Label(gui, "III", ink, { Pos = UDim2.fromScale(0.8, 0.43), Size = UDim2.fromScale(0.18, 0.14), Stroke = st })
		Kit.Label(gui, "VI", ink, { Pos = UDim2.fromScale(0.4, 0.84), Size = UDim2.fromScale(0.2, 0.14), Stroke = st })
		Kit.Label(gui, "IX", ink, { Pos = UDim2.fromScale(0.02, 0.43), Size = UDim2.fromScale(0.18, 0.14), Stroke = st })
	end
	Kit.Part(parent, V(d * 0.05, d * 0.4, 0.15), cf * CFrame.new(0, d * 0.18, -1), DARK)
	Kit.Part(parent, V(d * 0.07, d * 0.28, 0.15), cf * CFrame.new(0, 0, -1.1) * CFrame.Angles(0, 0, 1.0) * CFrame.new(0, d * 0.12, 0), DARK)
	Kit.Ball(parent, d * 0.09, (cf * CFrame.new(0, 0, -1.1)).Position, Kit.Vivid(BRASS), BRASS_M)
	return face
end

local function lamp(parent: Instance, x: number, z: number, light: boolean)
	local m = Kit.Model(parent, "BrassLamp")
	Kit.Disc(m, x, z, 1, 2.6, 1, BRASS_D, BRASS_M)
	Kit.Cyl(m, 12, 0.7, CFrame.new(x, 7, z), IRON, BRASS_M)
	Kit.Cyl(m, 0.6, 2.8, CFrame.new(x, 13.2, z), Kit.Vivid(BRASS), BRASS_M)
	local globe = Kit.Ball(m, 2.4, V(x, 14.6, z), WARM, { Mat = NEON })
	Kit.Cyl(m, 0.8, 3, CFrame.new(x, 16.1, z), Kit.Vivid(COPPER), BRASS_M)
	Kit.Ball(m, 0.8, V(x, 16.9, z), Kit.Vivid(BRASS), BRASS_M)
	if light then
		Kit.Light(globe, WARM, 24, 1.5)
	end
	Kit.AddCircle(x, z, 2)
end

local function shop(f: Instance, x: number, z: number, w: number, d: number, h: number, wall: Color3, roof: Color3, name: string, glow: boolean)
	local m = Kit.Model(f, "Shop")
	local fx = if x > 0 then -1 else 1
	local front = x + fx * w / 2
	Kit.Box(m, V(x - w / 2, 0, z - d / 2), V(x + w / 2, h, z + d / 2), wall, SOLID_BRICK)
	Kit.Box(m, V(x - w / 2 - 0.4, 0, z - d / 2 - 0.4), V(x + w / 2 + 0.4, 1.6, z + d / 2 + 0.4), DARK, { Mat = Enum.Material.Slate })
	Kit.Box(m, V(x - w / 2 - 1, h, z - d / 2 - 1), V(x + w / 2 + 1, h + 1.2, z + d / 2 + 1), CREAM, { Mat = WOOD })
	-- gable roof (ridge along Z)
	local rh = w * 0.35
	for _, s in { -1, 1 } do
		local cf = CFrame.new(x + s * (w / 2 + 1) / 2, h + 1.2 + rh / 2, z) * CFrame.Angles(0, Kit.FaceYaw(s, 0), 0)
		Kit.Wedge(m, V(d + 2, rh, w / 2 + 1), cf, roof, { Mat = METAL, Shadow = true })
	end
	-- front: door, round window, two square windows, sign, gear
	local fcf = CFrame.new(front, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, 0), 0)
	Kit.Part(m, V(5, 8, 0.4), fcf * CFrame.new(0, 4, -0.2), BROWN, { Mat = WOOD })
	Kit.Part(m, V(6, 0.8, 0.6), fcf * CFrame.new(0, 8.4, -0.3), Kit.Vivid(BRASS), BRASS_M)
	local winOpts: Kit.Opts = if glow then { Mat = NEON } else { Refl = 0.2 }
	local winC = if glow then WARM else C(150, 205, 200)
	for _, s in { -1, 1 } do
		Kit.Part(m, V(4.6, 5.6, 0.5), fcf * CFrame.new(s * d / 4, h * 0.42, -0.1), Kit.Vivid(BRASS), BRASS_M)
		Kit.Part(m, V(3.8, 4.8, 0.3), fcf * CFrame.new(s * d / 4, h * 0.42, -0.3), winC, winOpts)
	end
	Kit.Part(m, V(0.5, 6.6, 6.6), fcf * CFrame.new(0, h * 0.75, -0.1) * CFrame.Angles(0, math.pi / 2, 0), Kit.Vivid(BRASS), { Mat = METAL, Shape = Enum.PartType.Cylinder })
	Kit.Part(m, V(0.5, 5.4, 5.4), fcf * CFrame.new(0, h * 0.75, -0.3) * CFrame.Angles(0, math.pi / 2, 0), Kit.Vivid(VERDI), { Refl = 0.2, Shape = Enum.PartType.Cylinder })
	Props.SignBoard(m, (fcf * CFrame.new(0, 10.4, -0.5)).Position, math.min(d - 4, 16), 2.4, fx, 0, name, DARK, Kit.Vivid(BRASS))
	gear(m, V(front + fx * 0.4, h - 3.5, z - d / 2 + 4), 5, "X", Kit.Vivid(COPPER), 8, 0.6)
	-- chimney
	local cx, cz = x - fx * w / 4, z + d / 4
	Kit.Cyl(m, 12, 2.8, CFrame.new(cx, h + rh * 0.5 + 6, cz), BRICKC, { Mat = BRICK })
	local cap = Kit.Cyl(m, 1, 3.6, CFrame.new(cx, h + rh * 0.5 + 12.5, cz), Kit.Vivid(COPPER), BRASS_M)
	Kit.AddRect(x - w / 2 - 1, z - d / 2 - 1, x + w / 2 + 1, z + d / 2 + 1)
	return cap
end

--==================================================================
-- GROUND, PLAZAS, WALLS, OUTSIDE
--==================================================================
local function gearPlaza(f: Instance, x: number, z: number, r: number, rim: Color3)
	local n = math.floor(r * 0.5)
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		Kit.Part(f, V(5, 0.06, 6), CFrame.new(x + math.cos(a) * (r + 3.5), 0.03, z + math.sin(a) * (r + 3.5)) * CFrame.Angles(0, -a, 0), rim, BRASS_M)
	end
	Kit.Disc(f, x, z, 0.07, r * 2 + 4, 0.07, rim, BRASS_M)
	Kit.Disc(f, x, z, 0.1, r * 2 - 4, 0.1, CREAM, { Mat = COBBLE })
	Kit.Disc(f, x, z, 0.13, 14, 0.13, Kit.Vivid(COPPER), BRASS_M)
	Kit.Disc(f, x, z, 0.16, 6, 0.16, Kit.Vivid(VERDI), BRASS_M)
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		Props.Beam(f, V(x + math.cos(a) * 7, 0.12, z + math.sin(a) * 7), V(x + math.cos(a) * (r - 2.5), 0.12, z + math.sin(a) * (r - 2.5)), 1.6, 0.04, rim, BRASS_M)
	end
end

local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), COBBLEC, { Mat = COBBLE, Solid = true, Name = "Ground_Clockwork" })
	Kit.Box(f, V(-9, 0, Z0), V(9, 0.05, Z1), C(176, 110, 82), { Mat = BRICK, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 9, 0, Z0), V(s * 10, 0.08, Z1), Kit.Vivid(BRASS), BRASS_M)
	end
	for i, a in AREAS do
		gearPlaza(f, a[1], a[2], a[3], Kit.Vivid(if i % 2 == 0 then COPPER else BRASS))
	end
	-- boss: a giant clock face painted on the square
	local gold = Kit.Vivid(BRASS)
	Kit.Disc(f, 0, BOSS_Z, 0.07, 58, 0.07, gold, BRASS_M)
	Kit.Disc(f, 0, BOSS_Z, 0.1, 54, 0.1, CREAM, { Mat = Enum.Material.Marble })
	for i = 0, 11 do
		local a = i * math.pi / 6
		local big = i % 3 == 0
		Kit.Part(f, V(if big then 2 else 1.2, 0.04, if big then 5 else 3), CFrame.new(math.cos(a) * 23, 0.12, BOSS_Z + math.sin(a) * 23) * CFrame.Angles(0, -a + math.pi / 2, 0), DARK)
	end
	Props.Beam(f, V(0, 0.14, BOSS_Z), V(0, 0.14, BOSS_Z - 20), 1.6, 0.04, DARK)
	Props.Beam(f, V(0, 0.15, BOSS_Z), V(-11, 0.15, BOSS_Z - 6), 2.2, 0.04, DARK)
	Kit.Disc(f, 0, BOSS_Z, 0.18, 5, 0.06, gold, BRASS_M)
end

local function sideWalls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 30, z1), BRICKC, SOLID_BRICK)
		Kit.Box(f, V(s * 139.5, 30, z0), V(s * 146.5, 31.4, z1), Kit.Vivid(COPPER), BRASS_M)
		Kit.Box(f, V(s * 139.6, 0, z0), V(s * 140.05, 2.4, z1), DARK, { Mat = Enum.Material.Slate }) -- sunk into the wall (z-fighting with the pilasters)
		for z = Z0 + 40, Z1 - 20, 40 do
			Kit.Box(f, V(s * 137.6, 0, z - 2), V(s * 140, 32, z + 2), CREAM, { Mat = Enum.Material.Concrete, Solid = true })
		end
		-- steam pipe along the wall with flanges and a valve
		Kit.CylFlat(f, z1 - z0, 2.4, V(s * 138.4, 5, (z0 + z1) / 2), "Z", Kit.Vivid(COPPER), BRASS_M)
		for z = Z0 + 20, Z1 - 20, 40 do
			Kit.CylFlat(f, 0.8, 3.2, V(s * 138.4, 5, z), "Z", Kit.Vivid(BRASS), BRASS_M)
		end
		-- giant gears on the inner face
		for i, g in { { Z0 + 100, 26, 21 }, { Z0 + 220, 30, 19 }, { Z0 + 320, 24, 22 } } do
			gear(f, V(s * 139.2, g[3], g[1]), g[2], "X", Kit.Vivid(if (i + (if s > 0 then 1 else 0)) % 2 == 0 then COPPER else BRASS), 9)
		end
	end
	-- steam vent stack on the west wall
	Kit.Cyl(f, 26, 1.8, CFrame.new(-137.8, 18, Z0 + 170), Kit.Vivid(COPPER), BRASS_M)
	Kit.CylFlat(f, 0.5, 3.4, V(-136.6, 7, Z0 + 170), "X", Kit.Vivid(VERDI), BRASS_M)
	local vent = Kit.Cyl(f, 1, 2.6, CFrame.new(-137.8, 31.5, Z0 + 170), Kit.Vivid(BRASS), BRASS_M)
	local e = Kit.Emitter(vent, C(240, 240, 245), 4, 5, 2.5)
	if e then
		e.Acceleration = V(0, 2, 0)
	end
end

local function outside(f: Instance)
	local rng = Kit.Rng
	local walls = { C(150, 95, 70), C(130, 100, 80), C(170, 120, 85), C(120, 85, 70) }
	for i = 0, 4 do
		local z = Z0 + 30 + i * 75
		for _, s in { -1, 1 } do
			local w, h = rng:NextNumber(18, 26), rng:NextNumber(28, 48)
			local x = s * (150 + w / 2 + rng:NextNumber(0, 10))
			local col = Kit.Pick(walls)
			Kit.Box(f, V(x - w / 2, 0, z - 12), V(x + w / 2, h, z + 12), col, { Mat = BRICK })
			Kit.Wedge(f, V(w, 8, 12), CFrame.new(x, h + 4, z - 6), Kit.Vivid(if i % 2 == 0 then COPPER else VERDI), BRASS_M)
			Kit.Wedge(f, V(w, 8, 12), CFrame.new(x, h + 4, z + 6) * CFrame.Angles(0, math.pi, 0), Kit.Vivid(if i % 2 == 0 then COPPER else VERDI), BRASS_M)
			local ch = rng:NextNumber(14, 24)
			Kit.Cyl(f, ch, 3, CFrame.new(x + s * 4, h + ch / 2, z + 6), BRICKC, { Mat = BRICK })
		end
	end
	-- airship drifting over the east rooftops
	local a = V(196, 82, Z0 + 170)
	Kit.CylFlat(f, 44, 18, a, "Z", C(205, 90, 75), { Mat = Enum.Material.Fabric })
	Kit.Ball(f, 18, a + V(0, 0, -22), C(205, 90, 75), { Mat = Enum.Material.Fabric })
	Kit.Ball(f, 18, a + V(0, 0, 22), C(205, 90, 75), { Mat = Enum.Material.Fabric })
	for _, dz in { -12, 0, 12 } do
		Kit.CylFlat(f, 18.6, 1, a + V(0, 0, dz), "X", Kit.Vivid(BRASS), BRASS_M)
	end
	Kit.Box(f, a + V(-4, -15, -9), a + V(4, -10, 9), BROWN, { Mat = WOOD })
	Kit.Wedge(f, V(0.6, 10, 8), CFrame.new(a + V(0, 4, 30)), Kit.Vivid(VERDI))
	gear(f, a + V(0, -12.5, 10.5), 6, "Z", Kit.Vivid(BRASS), 8, 0.6)
end

--==================================================================
-- LANDMARKS
--==================================================================
local function clockTower(f: Instance)
	local m = Kit.Model(f, "ClockTower")
	local x, z = 64, Z0 + 328
	local gold = Kit.Vivid(BRASS)
	Kit.Box(m, V(x - 13, 0, z - 13), V(x + 13, 10, z + 13), C(130, 110, 100), { Mat = Enum.Material.Slate, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 11, 10, z - 11), V(x + 11, 80, z + 11), BRICKC, SOLID_BRICK)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.Box(m, V(x + sx * 11 - 1.6, 10, z + sz * 11 - 1.6), V(x + sx * 11 + 1.6, 80, z + sz * 11 + 1.6), CREAM, { Mat = Enum.Material.Concrete })
		end
	end
	for _, y in { 40, 79 } do
		Kit.Box(m, V(x - 12, y, z - 12), V(x + 12, y + 1.6, z + 12), Kit.Vivid(COPPER), BRASS_M)
	end
	-- clock stage with four faces
	Kit.Box(m, V(x - 13, 80.6, z - 13), V(x + 13, 102, z + 13), CREAM, { Mat = Enum.Material.Concrete, Shadow = true })
	local front = clockFace(m, V(x, 91, z - 13.6), 18, 0, -1, true)
	Kit.Light(front, WARM, 40, 1.5)
	clockFace(m, V(x - 13.6, 91, z), 18, -1, 0, false)
	clockFace(m, V(x + 13.6, 91, z), 18, 1, 0, false)
	clockFace(m, V(x, 91, z + 13.6), 18, 0, 1, false)
	-- belfry with a big brass bell
	Kit.Box(m, V(x - 13, 102, z - 13), V(x + 13, 103, z + 13), Kit.Vivid(COPPER), BRASS_M)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.Box(m, V(x + sx * 11.5 - 1.5, 103, z + sz * 11.5 - 1.5), V(x + sx * 11.5 + 1.5, 115, z + sz * 11.5 + 1.5), CREAM, { Mat = Enum.Material.Concrete })
		end
	end
	Kit.Ball(m, 9, V(x, 108, z), gold, BRASS_M)
	Kit.Cyl(m, 1.2, 10, CFrame.new(x, 104.4, z), gold, BRASS_M)
	-- stepped copper roof, spire and a gear weathervane
	local sizes = { 28, 22, 16, 10, 5 }
	for i, s in sizes do
		local y = 115 + (i - 1) * 4
		Kit.Box(m, V(x - s / 2, y, z - s / 2), V(x + s / 2, y + 4, z + s / 2), Kit.Vivid(if i % 2 == 1 then VERDI else COPPER), { Mat = METAL, Shadow = true })
	end
	Kit.Cyl(m, 12, 1, CFrame.new(x, 141, z), gold, BRASS_M)
	gear(m, V(x, 149, z), 6, "Z", gold, 8, 0.6)
	-- big gear on the front of the shaft, door and sign toward the lane
	gear(m, V(x, 58, z - 11.8), 16, "Z", Kit.Vivid(BRASS), 12)
	Kit.Box(m, V(x - 13.4, 0, z - 5), V(x - 13, 9, z + 5), BROWN, { Mat = WOOD })
	Kit.Box(m, V(x - 13.6, 9, z - 6), V(x - 13, 10, z + 6), gold, BRASS_M)
	Props.SignBoard(m, V(x - 13.7, 13, z), 18, 3, -1, 0, "TICK-TOCK TOWER", DARK, gold)
	Kit.AddRect(x - 14, z - 14, x + 14, z + 14)
end

local function cogBridge(f: Instance, z: number, title: string)
	local m = Kit.Model(f, "CogBridge")
	local gold = Kit.Vivid(BRASS)
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 16, 0, z - 4.5), V(s * 26, 34, z + 4.5), BRICKC, SOLID_BRICK)
		Kit.Box(m, V(s * 15.6, 0, z - 4.9), V(s * 26.4, 3, z + 4.9), DARK, { Mat = Enum.Material.Slate, Solid = true })
		Kit.Box(m, V(s * 15.6, 34, z - 4.9), V(s * 26.4, 35.4, z + 4.9), Kit.Vivid(COPPER), BRASS_M)
		gear(m, V(s * 21, 18, z - 4.9), 8, "Z", gold, 8, 0.6)
		Kit.AddRect(s * 15.5, z - 5, s * 26.5, z + 5)
	end
	-- deck (bottom Y 30) with brass railings and a big cog standing on it
	Kit.Box(m, V(-16, 30, z - 3), V(16, 32.4, z + 3), BROWN, { Mat = WOOD, Solid = true, Shadow = true })
	Kit.Box(m, V(-16, 29.6, z - 3.3), V(16, 30.2, z + 3.3), gold, BRASS_M)
	for _, sz in { -1, 1 } do
		Kit.Box(m, V(-16, 34.6, z + sz * 2.8 - 0.25), V(16, 35.1, z + sz * 2.8 + 0.25), gold, BRASS_M)
		for x = -14, 14, 7 do
			Kit.Box(m, V(x - 0.2, 32.4, z + sz * 2.8 - 0.2), V(x + 0.2, 34.6, z + sz * 2.8 + 0.2), gold, BRASS_M)
		end
	end
	gear(m, V(0, 39, z), 12, "Z", Kit.Vivid(COPPER), 10, 1)
	Props.SignBoard(m, V(0, 31.2, z - 3.4), 18, 2.2, 0, -1, title, DARK, gold)
end

local function gearMonument(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GearMonument")
	Kit.Box(m, V(x - 7, 0, z - 3.5), V(x + 7, 3, z + 3.5), C(130, 110, 100), { Mat = Enum.Material.Slate, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 1, 3, z - 1), V(x + 1, 11, z + 1), IRON, BRASS_M)
	gear(m, V(x - 1.5, 13, z), 16, "Z", Kit.Vivid(BRASS), 12)
	gear(m, V(x + 9.2, 6.8, z + 0.4), 8, "Z", Kit.Vivid(COPPER), 8)
	local gem = Kit.Ball(m, 2.2, V(x - 1.5, 13, z - 1.2), Kit.Vivid(VERDI), { Mat = NEON })
	Kit.Light(gem, C(150, 255, 230), 24, 1.2)
	Props.SignBoard(m, V(x, 1.6, z - 3.7), 9, 1.8, 0, -1, "THE GREAT COG", DARK, Kit.Vivid(BRASS))
	Kit.AddCircle(x, z, 10)
end

local function grandfatherClock(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GrandfatherClock")
	Kit.Box(m, V(x - 3.4, 0, z - 2.4), V(x + 3.4, 2, z + 2.4), BROWN, { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 2.6, 2, z - 1.8), V(x + 2.6, 17, z + 1.8), C(140, 90, 60), { Mat = WOOD, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 1.6, 4, z - 1.95), V(x + 1.6, 14, z - 1.8), C(150, 205, 200), { Transp = 0.4, Refl = 0.2 })
	Kit.Box(m, V(x - 0.15, 8, z - 1.4), V(x + 0.15, 14, z - 1.2), Kit.Vivid(BRASS), BRASS_M)
	Kit.CylFlat(m, 0.3, 2.4, V(x, 7.6, z - 1.3), "Z", Kit.Vivid(BRASS), BRASS_M)
	Kit.Box(m, V(x - 3.4, 17, z - 2.4), V(x + 3.4, 24, z + 2.4), C(140, 90, 60), { Mat = WOOD, Shadow = true })
	clockFace(m, V(x, 20.5, z - 2.9), 5, 0, -1, false)
	Kit.Wedge(m, V(7.4, 2.6, 2.6), CFrame.new(x, 25.3, z - 1.3), BROWN, { Mat = WOOD })
	Kit.Wedge(m, V(7.4, 2.6, 2.6), CFrame.new(x, 25.3, z + 1.3) * CFrame.Angles(0, math.pi, 0), BROWN, { Mat = WOOD })
	Kit.Ball(m, 1.4, V(x, 27, z), Kit.Vivid(BRASS), BRASS_M)
	Kit.AddCircle(x, z, 4.5)
end

local function floaters(f: Instance)
	for _, p in { V(40, 22, Z0 + 120), V(-40, 26, Z0 + 200), V(110, 24, Z0 + 120), V(-112, 28, Z0 + 280), V(-22, 20, Z0 + 340), V(96, 30, Z0 + 296) } do
		local g = Kit.CylFlat(f, 0.6, 3.4, p, "Z", Kit.Vivid(Kit.Pick({ BRASS, COPPER, VERDI })), { Mat = METAL, Name = "FloatingCog" })
		Kit.Float(g, 1.4)
	end
end

local function decor(f: Instance)
	local rng = Kit.Rng
	local wallCols = { C(160, 95, 70), C(190, 150, 110), C(140, 110, 90), C(175, 120, 85) }
	local roofs = { Kit.Vivid(VERDI), Kit.Vivid(COPPER), C(110, 70, 60) }
	type ShopDef = { X: number, Z: number, W: number, D: number, H: number, Name: string, Glow: boolean }
	local shops: { ShopDef } = {
		{ X = 92, Z = Z0 + 60, W = 34, D = 28, H = 18, Name = "GEARS & CO.", Glow = false },
		{ X = -100, Z = Z0 + 55, W = 32, D = 26, H = 16, Name = "TEA & TICKS", Glow = true },
		{ X = 112, Z = Z0 + 250, W = 28, D = 32, H = 20, Name = "CHRONO CURIOS", Glow = false },
		{ X = -110, Z = Z0 + 180, W = 26, D = 30, H = 17, Name = "BOLT BAKERY", Glow = false },
		{ X = -104, Z = Z0 + 318, W = 32, D = 28, H = 19, Name = "STEAM WORKS", Glow = false },
	}
	local smokeCap: Part? = nil
	for i, s in shops do
		if Kit.IsFree(s.X, s.Z, math.max(s.W, s.D) / 2 + 1) then
			local cap = shop(f, s.X, s.Z, s.W, s.D, s.H, wallCols[(i - 1) % #wallCols + 1], roofs[(i - 1) % #roofs + 1], s.Name, s.Glow)
			if i == 5 then
				smokeCap = cap
			end
			if s.Glow then
				-- the glowing tea shop gets a cosy flickering light just inside its front
				local fx = if s.X > 0 then -1 else 1
				local win = Kit.Part(f, V(1, 1, 1), CFrame.new(s.X + fx * (s.W / 2 - 1), 7, s.Z), WARM, { Transp = 1, Name = "ShopGlow" })
				Kit.Light(win, WARM, 22, 1.3, true)
			end
		end
	end
	if smokeCap then
		local e = Kit.Emitter(smokeCap, C(230, 225, 220), 3, 5, 2)
		if e then
			e.Acceleration = V(0, 1.5, 0)
		end
	end
	-- lamp posts along the lane
	local lit = 0
	for _, z in { Z0 + 40, Z0 + 125, Z0 + 175, Z0 + 225 } do
		for _, sx in { -1, 1 } do
			local x = sx * 13.5
			if Kit.IsFree(x, z, 2.5) then
				local light = lit < 3 and ((z == Z0 + 40 and sx > 0) or (z == Z0 + 175 and sx < 0) or (z == Z0 + 225 and sx > 0))
				if light then
					lit += 1
				end
				lamp(f, x, z, light)
			end
		end
	end
	if Kit.IsFree(-30, Z0 + 180, 10) then
		gearMonument(f, -30, Z0 + 180)
	end
	if Kit.IsFree(32, Z0 + 225, 5) then
		grandfatherClock(f, 32, Z0 + 225)
	end
	-- crates, barrels and loose cogs
	local crates, barrels = 0, 0
	for _ = 1, 300 do
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 10)
		if crates < 8 and Kit.IsFree(x, z, 3) then
			crates += 1
			local s = rng:NextNumber(3, 4.5)
			Kit.Part(f, V(s, s, s), CFrame.new(x, s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), C(170, 125, 80), { Mat = WOOD, Solid = true })
			Kit.Part(f, V(s + 0.1, 0.4, s + 0.1), CFrame.new(x, s * 0.75, z), IRON, BRASS_M)
			Kit.AddCircle(x, z, 3)
		elseif barrels < 6 and Kit.IsFree(x, z, 2.5) then
			barrels += 1
			Kit.Cyl(f, 4, 3, CFrame.new(x, 2, z), Kit.Vivid(COPPER), { Mat = METAL, Solid = true })
			Kit.Cyl(f, 0.4, 3.15, CFrame.new(x, 2.8, z), Kit.Vivid(BRASS), BRASS_M)
			Kit.AddCircle(x, z, 2.5)
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function Clockwork.Build(map: Instance)
	local f = Kit.Folder(map, "Clockwork")
	ground(f)
	sideWalls(f)
	outside(f)
	clockTower(f)
	cogBridge(f, Z0 + 145, "TICK TOCK LANE")
	cogBridge(f, Z0 + 265, "COGWHEEL CROSSING")
	floaters(f)
	decor(f)
end

return Clockwork
