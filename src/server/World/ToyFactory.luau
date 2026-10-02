--!strict
-- ZONE 12: Haunted Toy Factory (Z 3760..4120). A bright, open-topped factory hall.
--   Floor: pale lilac plastic (top Y = 0) inside the walls, grass outside. Main path along X = 0:
--   a sky-blue lane (X -8..8, top 0.05) with yellow edges and white dashes.
--   Walls: pink, 16 tall at X +-140..146 with a yellow rim ledge, purple skirting, sky-blue
--   windows, big gears and a candy-striped pipe on the inner faces. No roof anywhere.
--   Ghost areas hold flat paint only: a giant play mat (0, 3845), rugs, a pinwheel (75, 3940)
--   and the Puppet Master's striped stage floor (0, 4065).
--   Landmarks: a giant sitting TEDDY BEAR with a wind-up key (95, 4050, ~61 tall) and a huge
--   JACK-IN-THE-BOX (-100, 4060, ~62 tall), plus striped factory chimneys outside the walls.
--   Also: an entrance gantry sign, a toy train on an oval track, conveyor belts carrying toys,
--   giant lettered building blocks, a wind-up mouse, toy soldiers, gift boxes, lamp posts and
--   balloons.
-- Glow: lamp globes, the train headlamp, the jack's nose and four star glints on the stage.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local ToyFactory = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GRASS = Enum.Material.Grass
local FABRIC = Enum.Material.Fabric

local Z0, Z1 = 3760, 4120

local FLOOR = C(246, 238, 252)
local PINK = C(255, 150, 195)
local SKY = C(110, 190, 255)
local YELLOW = C(255, 215, 80)
local PURPLE = C(160, 110, 230)
local WHITE = C(255, 255, 255)
local RED = C(240, 80, 90)
local MINT = C(120, 225, 170)
local FUR = C(200, 140, 90)
local FUR_LIGHT = C(240, 205, 160)
local DARK = C(45, 35, 50)
local TOYS = { PINK, SKY, YELLOW, PURPLE, MINT, C(255, 150, 80) }

local function rz(n: number): number
	return Z0 + n
end

-- Cylinder whose axis runs along the local Z of `cf`.
local function cylZ(parent: Instance, cf: CFrame, len: number, d: number, color: Color3, opts: Kit.Opts?): Part
	local o: Kit.Opts = opts or {}
	local p = Kit.Part(parent, V(len, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), color, o)
	p.Shape = Enum.PartType.Cylinder
	return p
end

--==================================================================
-- PROPS
--==================================================================
local function gift(parent: Instance, x: number, z: number, s: number, yaw: number, y: number?)
	local cf = CFrame.new(x, (y or 0) + s / 2, z) * CFrame.Angles(0, yaw, 0)
	local col = Kit.Pick(TOYS)
	local rib = if col == YELLOW then PINK else YELLOW
	Kit.Part(parent, V(s, s, s), cf, Kit.Vivid(col), { Solid = true })
	Kit.Part(parent, V(s + 0.1, s + 0.1, s * 0.18), cf, Kit.Vivid(rib))
	Kit.Part(parent, V(s * 0.18, s + 0.1, s + 0.1), cf, Kit.Vivid(rib))
	for _, sx in { -1, 1 } do
		Kit.Ball(parent, s * 0.3, (cf * CFrame.new(sx * s * 0.16, s * 0.6, 0)).Position, Kit.Vivid(rib))
	end
end

local function block(parent: Instance, cf: CFrame, s: number, col: Color3, letter: string)
	local b = Kit.Part(parent, V(s, s, s), cf, Kit.Vivid(col), { Solid = true, Shadow = true })
	Kit.Sign(b, Enum.NormalId.Front, letter, WHITE, { Stroke = DARK })
	Kit.Sign(b, Enum.NormalId.Right, letter, WHITE, { Stroke = DARK })
end

local function blockStack(parent: Instance, x: number, z: number, s: number, letters: string)
	local rng = Kit.Rng
	local n = #letters
	for i = 1, n do
		local cf = CFrame.new(x + rng:NextNumber(-0.6, 0.6), s * (i - 0.5), z + rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0)
		block(parent, cf, s, TOYS[(i % #TOYS) + 1], string.sub(letters, i, i))
	end
	Kit.AddCircle(x, z, s * 0.8 + 1)
end

local function soldier(parent: Instance, x: number, z: number, fx: number, fz: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local blue = Kit.Vivid(C(60, 90, 200))
	for _, s in { -1, 1 } do
		Kit.Part(parent, V(1.1, 3.4, 1.3), base * CFrame.new(s * 0.7, 1.7, 0), blue)
		Kit.Part(parent, V(0.9, 3.2, 0.9), base * CFrame.new(s * 2, 5.4, 0), Kit.Vivid(RED))
	end
	Kit.Part(parent, V(3.2, 3.6, 2), base * CFrame.new(0, 5.2, 0), Kit.Vivid(RED), { Solid = true })
	Kit.Part(parent, V(3.3, 0.6, 2.1), base * CFrame.new(0, 4, 0), WHITE)
	Kit.Ball(parent, 2.4, (base * CFrame.new(0, 8, 0)).Position, C(255, 220, 190))
	for _, s in { -1, 1 } do
		Kit.Ball(parent, 0.4, (base * CFrame.new(s * 0.45, 8.2, -1.1)).Position, DARK)
	end
	Kit.Cyl(parent, 2.8, 2.2, base * CFrame.new(0, 10.3, 0), DARK)
	Kit.Ball(parent, 0.9, (base * CFrame.new(0, 11.9, 0)).Position, Kit.Vivid(YELLOW))
	Kit.AddCircle(x, z, 3)
end

local function conveyor(parent: Instance, x: number, z1: number, z2: number, col: Color3)
	local m = Kit.Model(parent, "Conveyor")
	Kit.Box(m, V(x - 3, 0, z1), V(x + 3, 3, z2), Kit.Vivid(col), { Solid = true, Shadow = true })
	Kit.Box(m, V(x - 2.6, 3, z1), V(x + 2.6, 3.3, z2), C(70, 70, 90), { Mat = Enum.Material.Rubber })
	for _, s in { -1, 1 } do
		Kit.Box(m, V(x + s * 3 - 0.05, 1.2, z1), V(x + s * 3 + 0.05, 1.8, z2), Kit.Vivid(YELLOW))
	end
	for _, z in { z1, z2 } do
		Kit.CylFlat(m, 6.4, 3.4, V(x, 1.7, z), "X", Kit.Vivid(YELLOW), { Mat = METAL })
	end
	local rng = Kit.Rng
	local n = math.floor((z2 - z1) / 14)
	for i = 1, n do
		local z = z1 + i * (z2 - z1) / (n + 1)
		if i % 2 == 0 then
			Kit.Ball(m, 2.6, V(x, 4.6, z), Kit.Vivid(Kit.Pick(TOYS)))
		else
			local s = rng:NextNumber(2, 2.8)
			Kit.Part(m, V(s, s, s), CFrame.new(x, 3.3 + s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Kit.Vivid(Kit.Pick(TOYS)))
		end
	end
	Kit.AddRect(x - 4.5, z1 - 2, x + 4.5, z2 + 2)
end

local function windupMouse(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "WindupMouse")
	local grey = C(185, 185, 205)
	Kit.Part(m, V(5, 4, 8), CFrame.new(x, 2.2, z), grey, { Solid = true })
	Kit.Ball(m, 5, V(x, 2.6, z - 3.6), grey)
	Kit.Ball(m, 1, V(x, 2.6, z - 6.2), Kit.Vivid(PINK))
	for _, s in { -1, 1 } do
		cylZ(m, CFrame.new(x + s * 1.6, 5.2, z - 3), 0.4, 3, Kit.Vivid(PINK))
		Kit.Ball(m, 0.6, V(x + s * 1, 3.4, z - 5.6), DARK)
	end
	Props.Beam(m, V(x, 1, z + 4), V(x + 2, 2.6, z + 9), 0.4, 0.4, Kit.Vivid(PINK))
	-- wind-up key on its back
	Kit.Cyl(m, 2.4, 0.5, CFrame.new(x, 5.3, z + 1), Kit.Vivid(YELLOW), { Mat = METAL })
	for _, s in { -1, 1 } do
		cylZ(m, CFrame.new(x + s * 1.3, 7, z + 1) * CFrame.Angles(0, math.pi / 2, 0), 0.5, 2.6, Kit.Vivid(YELLOW), { Mat = METAL })
	end
	Kit.AddCircle(x, z, 7)
end

local function gear(parent: Instance, x: number, y: number, z: number, d: number, col: Color3)
	-- a gear flat against a wall that faces X (x is the wall's inner face)
	local s = if x > 0 then -1 else 1 -- direction into the hall
	Kit.CylFlat(parent, 0.8, d, V(x + s * 0.4, y, z), "X", col, { Mat = METAL })
	for k = 0, 5 do
		local a = k * math.pi / 3
		Kit.Part(parent, V(0.8, d * 0.2, d * 0.2), CFrame.new(x + s * 0.4, y + math.cos(a) * d / 2, z + math.sin(a) * d / 2) * CFrame.Angles(a, 0, 0), col, { Mat = METAL })
	end
	Kit.CylFlat(parent, 1, d * 0.32, V(x + s * 0.6, y, z), "X", Kit.Vivid(YELLOW), { Mat = METAL })
end

--==================================================================
-- GROUND, PATH, WALLS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-140, -4, Z0), V(140, 0, Z1), FLOOR, { Solid = true, Name = "Ground_ToyFactory" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -4, Z0), V(s * 190, 0, Z1), C(120, 205, 110), { Mat = GRASS, Solid = true })
	end
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), SKY, { Solid = true, Name = "FactoryLane" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8 - 0.6, 0.05, Z0), V(s * 8 + 0.6, 0.1, Z1), Kit.Vivid(YELLOW))
	end
	for z = Z0 + 10, Z1 - 10, 18 do
		Kit.Box(f, V(-0.4, 0.05, z), V(0.4, 0.08, z + 7), WHITE)
	end
	-- coloured work zones painted on the floor
	Kit.Box(f, V(58, 0, rz(12)), V(120, 0.02, rz(142)), C(255, 225, 238))
	Kit.Box(f, V(-136, 0, rz(8)), V(-48, 0.02, rz(90)), C(225, 240, 255))
	Kit.Box(f, V(20, 0, rz(120)), V(44, 0.02, rz(212)), C(255, 246, 210))
	Kit.Box(f, V(-44, 0, rz(124)), V(-20, 0.02, rz(206)), C(232, 250, 238))
end

local function sideWalls(f: Instance)
	local zA, zB = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, 0, zA), V(s * 146, 16, zB), PINK, { Solid = true, Shadow = true })
		Kit.Box(f, V(s * 138.5, 16, zA), V(s * 146.5, 17.5, zB), Kit.Vivid(YELLOW))
		Kit.Box(f, V(s * 139.6, 0, zA), V(s * 140, 1.6, zB), Kit.Vivid(PURPLE))
		-- candy-striped pipe along the wall
		Kit.CylFlat(f, zB - zA - 10, 2.6, V(s * 137.5, 12.5, (zA + zB) / 2), "Z", WHITE, { Mat = METAL })
		for z = zA + 12, zB - 10, 24 do
			Kit.CylFlat(f, 3, 2.9, V(s * 137.5, 12.5, z), "Z", Kit.Vivid(RED), { Mat = METAL })
		end
		for _, z in { zA + 6, zB - 6 } do
			Kit.Cyl(f, 12.5, 2.6, CFrame.new(s * 137.5, 6.25, z), WHITE, { Mat = METAL })
			Kit.Cyl(f, 2, 2.9, CFrame.new(s * 137.5, 4, z), Kit.Vivid(RED), { Mat = METAL })
		end
		-- windows and gears on the inner face
		for i, z in { rz(40), rz(100), rz(160), rz(220), rz(280), rz(330) } do
			if i % 2 == 1 then
				Kit.Box(f, V(s * 139.9, 3.5, z - 8), V(s * 139.65, 10, z + 8), Kit.Vivid(SKY), { Refl = 0.2 })
				Kit.Box(f, V(s * 139.95, 6.6, z - 8), V(s * 139.6, 6.9, z + 8), WHITE)
			else
				gear(f, s * 140, 7, z, 9, if i % 4 == 0 then Kit.Vivid(PURPLE) else Kit.Vivid(MINT))
			end
		end
	end
end

local function gantry(f: Instance)
	local z = rz(44)
	for _, s in { -1, 1 } do
		Kit.Cyl(f, 26, 2.4, CFrame.new(s * 14, 13, z), Kit.Vivid(PINK), { Solid = true })
		for _, y in { 8, 18 } do
			Kit.Cyl(f, 1.6, 2.7, CFrame.new(s * 14, y, z), WHITE)
		end
		Kit.AddCircle(s * 14, z, 2)
	end
	local beam = Kit.Box(f, V(-17, 22, z - 1.6), V(17, 27, z + 1.6), Kit.Vivid(YELLOW), { Shadow = true })
	Kit.Sign(beam, Enum.NormalId.Front, "🧸 HAUNTED TOY FACTORY 🧸", Kit.Vivid(PURPLE), { Stroke = WHITE })
	for _, s in { -1, 1 } do
		Kit.CylFlat(f, 1, 6, V(s * 17.5, 24.5, z - 0.4), "Z", Kit.Vivid(SKY), { Mat = METAL })
	end
end

--==================================================================
-- GHOST AREA PAINT (flat only)
--==================================================================
local function ghostPaint(f: Instance)
	-- toy soldiers: giant play mat
	local cz = rz(85)
	local sizes = { 64, 58, 44, 30, 12 }
	local cols = { PINK, YELLOW, SKY, WHITE, PINK }
	for i, d in sizes do
		Kit.Disc(f, 0, cz, 0.02 + i * 0.025, d, 0.02, Kit.Vivid(cols[i]))
	end
	-- rugs with polka dots
	for k, a in { { -82, rz(120) }, { -62, rz(240) } } do
		Kit.Disc(f, a[1], a[2], 0.04, 51, 0.03, Kit.Vivid(if k == 1 then SKY else PURPLE))
		Kit.Disc(f, a[1], a[2], 0.07, 44, 0.03, Kit.Vivid(if k == 1 then C(190, 225, 255) else C(215, 190, 250)))
		for i = 0, 3 do
			local ang = i * math.pi / 2 + 0.4
			Kit.Disc(f, a[1] + math.cos(ang) * 12, a[2] + math.sin(ang) * 12, 0.1, 6, 0.03, WHITE)
		end
	end
	-- jack-in-the-box phantoms: pinwheel
	local px, pz = 75, rz(180)
	Kit.Disc(f, px, pz, 0.04, 54, 0.03, Kit.Vivid(YELLOW))
	for i = 0, 5 do
		local a = i * math.pi / 3
		Props.Beam(f, V(px, 0.08, pz), V(px + math.cos(a) * 24, 0.08, pz + math.sin(a) * 24), 5, 0.04, Kit.Vivid(TOYS[i + 1]))
	end
	Kit.Disc(f, px, pz, 0.12, 6, 0.03, WHITE)
	-- boss: the Puppet Master's striped stage floor
	local bz = rz(305)
	Kit.Disc(f, 0, bz, 0.04, 58, 0.03, Kit.Vivid(PURPLE))
	Kit.Disc(f, 0, bz, 0.06, 52, 0.03, Kit.Vivid(YELLOW))
	Kit.Disc(f, 0, bz, 0.08, 48, 0.03, Kit.Vivid(C(240, 70, 100)))
	for i = 0, 7 do
		local a = i * math.pi / 4
		Props.Beam(f, V(0, 0.11, bz), V(math.cos(a) * 23, 0.11, bz + math.sin(a) * 23), 4, 0.04, WHITE)
	end
	Kit.Disc(f, 0, bz, 0.14, 8, 0.03, Kit.Vivid(YELLOW))
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		Kit.Part(f, V(1.8, 0.05, 1.8), CFrame.new(math.cos(a) * 25.5, 0.12, bz + math.sin(a) * 25.5) * CFrame.Angles(0, math.pi / 4, 0), YELLOW, { Mat = NEON })
	end
end

--==================================================================
-- TOY TRAIN
--==================================================================
local function track(f: Instance, cx: number, z1: number, z2: number, r: number)
	local bed = C(150, 110, 200)
	local rail = C(120, 125, 145)
	local function seg(a: Vector3, b: Vector3)
		Props.Beam(f, a + V(0, 0.05, 0), b + V(0, 0.05, 0), 5, 0.06, bed)
		local d = (b - a).Unit
		local side = V(-d.Z, 0, d.X) * 1.7
		for _, s in { -1, 1 } do
			Props.Beam(f, a + side * s + V(0, 0.15, 0), b + side * s + V(0, 0.15, 0), 0.5, 0.14, rail, { Mat = METAL })
		end
	end
	for _, s in { -1, 1 } do
		seg(V(cx + s * r, 0, z1), V(cx + s * r, 0, z2))
	end
	for k = 0, 3 do
		local a1, a2 = k * math.pi / 4, (k + 1) * math.pi / 4
		seg(V(cx + math.cos(a1) * r, 0, z2 + math.sin(a1) * r), V(cx + math.cos(a2) * r, 0, z2 + math.sin(a2) * r))
		seg(V(cx + math.cos(a1) * r, 0, z1 - math.sin(a1) * r), V(cx + math.cos(a2) * r, 0, z1 - math.sin(a2) * r))
	end
end

local function train(f: Instance, x: number, zc: number)
	local m = Kit.Model(f, "ToyTrain")
	local sol: Kit.Opts = { Solid = true, Shadow = true }
	-- engine (front at +Z)
	Kit.Box(m, V(x - 3, 1.6, zc - 7), V(x + 3, 3, zc + 7), Kit.Vivid(RED), sol)
	Kit.CylFlat(m, 9, 5, V(x, 5.5, zc + 2), "Z", Kit.Vivid(SKY))
	Kit.CylFlat(m, 0.6, 5.4, V(x, 5.5, zc + 6.8), "Z", Kit.Vivid(YELLOW))
	Kit.Box(m, V(x - 3, 3, zc - 7), V(x + 3, 10.5, zc - 2), Kit.Vivid(YELLOW), sol)
	for _, s in { -1, 1 } do
		Kit.Box(m, V(x + s * 3.05, 6.5, zc - 6), V(x + s * 3.1, 9, zc - 3), Kit.Vivid(SKY), { Refl = 0.2 })
	end
	Kit.Box(m, V(x - 3.6, 10.5, zc - 7.6), V(x + 3.6, 11.3, zc - 1.4), Kit.Vivid(PURPLE))
	Kit.Cyl(m, 4, 1.8, CFrame.new(x, 10, zc + 4.5), DARK)
	Kit.Cyl(m, 1, 2.8, CFrame.new(x, 12.4, zc + 4.5), Kit.Vivid(RED))
	Kit.Wedge(m, V(6, 2.2, 2.4), CFrame.new(x, 2.2, zc + 8.2) * CFrame.Angles(0, math.pi, 0), Kit.Vivid(YELLOW))
	for _, z in { zc - 4.5, zc + 0.5, zc + 5 } do
		Kit.CylFlat(m, 6.6, 3.2, V(x, 1.6, z), "X", Kit.Vivid(PINK))
	end
	-- wind-up key on the boiler
	Kit.Cyl(m, 2, 0.6, CFrame.new(x, 9, zc + 1), Kit.Vivid(YELLOW), { Mat = METAL })
	for _, s in { -1, 1 } do
		Kit.CylFlat(m, 0.5, 2.4, V(x, 10.6, zc + 1 + s * 1.3), "X", Kit.Vivid(YELLOW), { Mat = METAL })
	end
	local lamp = Kit.Part(m, V(1.6, 1.6, 0.4), CFrame.new(x, 5.5, zc + 7.2), C(255, 245, 190), { Mat = NEON })
	Kit.Light(lamp, C(255, 240, 190), 20, 1.2)
	-- two wagons
	for i, cargo in { "blocks", "balls" } do
		local zw = zc - 7 - i * 12 + 4
		Kit.Box(m, V(x - 2.5, 1.6, zw - 5), V(x + 2.5, 5, zw + 5), Kit.Vivid(if i == 1 then MINT else PURPLE), sol)
		for _, z in { zw - 3, zw + 3 } do
			Kit.CylFlat(m, 5.6, 3, V(x, 1.5, z), "X", Kit.Vivid(YELLOW))
		end
		Kit.Box(m, V(x - 0.5, 2.2, zw + 5), V(x + 0.5, 2.8, zw + 7), DARK)
		if cargo == "blocks" then
			block(m, CFrame.new(x, 6.6, zw - 2) * CFrame.Angles(0, 0.3, 0), 3.2, YELLOW, "A")
			block(m, CFrame.new(x, 6.6, zw + 2) * CFrame.Angles(0, -0.2, 0), 3.2, SKY, "B")
		else
			Kit.Ball(m, 3.4, V(x, 6.6, zw - 2), Kit.Vivid(RED))
			Kit.Ball(m, 3.4, V(x, 6.6, zw + 2), Kit.Vivid(YELLOW))
		end
	end
end

--==================================================================
-- LANDMARKS
--==================================================================
local function teddy(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GiantTeddy")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(-1, 0), 0)
	local sol: Kit.Opts = { Mat = FABRIC, Solid = true, Shadow = true }
	local soft: Kit.Opts = { Mat = FABRIC, Shadow = true }
	local function at(lx: number, ly: number, lz: number): Vector3
		return (base * CFrame.new(lx, ly, lz)).Position
	end
	Kit.Ball(m, 34, at(0, 17, 2), FUR, sol)
	cylZ(m, base * CFrame.new(0, 15, -14.6), 0.6, 19, FUR_LIGHT, { Mat = FABRIC })
	-- legs and paw pads
	for _, s in { -1, 1 } do
		cylZ(m, base * CFrame.new(s * 8.5, 6, -10), 16, 12, FUR, sol)
		cylZ(m, base * CFrame.new(s * 8.5, 6, -18.1), 0.4, 9, Kit.Vivid(PINK), { Mat = FABRIC })
	end
	-- arms resting on the knees
	for _, s in { -1, 1 } do
		local a, b = at(s * 14, 26, -2), at(s * 15, 14, -13)
		local mid = (a + b) / 2
		local arm = Kit.Part(m, V((b - a).Magnitude, 9, 9), CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0), FUR, soft)
		arm.Shape = Enum.PartType.Cylinder
		Kit.Ball(m, 9.5, b, FUR, soft)
	end
	-- head
	Kit.Ball(m, 28, at(0, 44, 0), FUR, sol)
	Kit.Ball(m, 11, at(0, 40, -11.5), FUR_LIGHT, soft)
	Kit.Ball(m, 4, at(0, 42.5, -16.6), DARK)
	for _, s in { -1, 1 } do
		Kit.Ball(m, 3.6, at(s * 5.5, 47, -12.3), DARK)
		Kit.Ball(m, 1.2, at(s * 5.1, 47.8, -13.8), WHITE)
		Kit.Ball(m, 10, at(s * 11, 56, 0), FUR, soft)
		Kit.Ball(m, 6, at(s * 11, 56, -2.6), Kit.Vivid(PINK), { Mat = FABRIC })
		Kit.Part(m, V(5, 4, 1.4), base * CFrame.new(s * 3.4, 31.5, -14.2) * CFrame.Angles(0, 0, s * 0.35), Kit.Vivid(SKY), { Mat = FABRIC })
	end
	Kit.Ball(m, 2.8, at(0, 31.5, -14.6), Kit.Vivid(SKY), { Mat = FABRIC })
	-- wind-up key in the back
	cylZ(m, base * CFrame.new(0, 20, 21), 6, 1.4, Kit.Vivid(YELLOW), { Mat = METAL })
	for _, s in { -1, 1 } do
		local lobe = Kit.Part(m, V(0.8, 5.5, 5.5), base * CFrame.new(s * 2.6, 20, 24.2), Kit.Vivid(YELLOW), { Mat = METAL })
		lobe.Shape = Enum.PartType.Cylinder
	end
	Kit.AddCircle(x, z, 24)
end

local function jackInTheBox(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "JackInTheBox")
	local sol: Kit.Opts = { Solid = true, Shadow = true }
	-- the box (front faces +X toward the lane)
	Kit.Box(m, V(x - 11, 0, z - 11), V(x + 11, 22, z + 11), Kit.Vivid(PINK), sol)
	Kit.Box(m, V(x - 11.5, 21, z - 11.5), V(x + 11.5, 22.5, z + 11.5), Kit.Vivid(PURPLE))
	local front = Kit.Box(m, V(x + 11, 3, z - 8), V(x + 11.3, 19, z + 8), Kit.Vivid(YELLOW))
	Kit.Sign(front, Enum.NormalId.Right, "★", Kit.Vivid(RED), { Stroke = WHITE })
	local side = Kit.Box(m, V(x - 8, 3, z - 11.3), V(x + 8, 19, z - 11), Kit.Vivid(SKY))
	Kit.Sign(side, Enum.NormalId.Front, "JACK", WHITE, { Stroke = Kit.Vivid(PURPLE) })
	-- lid flipped open at the back
	Kit.Part(m, V(1, 22, 22), CFrame.new(x - 11, 22.5, z) * CFrame.Angles(0, 0, 0.3) * CFrame.new(-0.5, 11, 0), Kit.Vivid(PURPLE), { Shadow = true })
	-- crank handle on the +Z side
	Kit.CylFlat(m, 3, 1.2, V(x, 12, z + 12.5), "Z", Kit.Vivid(YELLOW), { Mat = METAL })
	Props.Beam(m, V(x, 12, z + 14), V(x + 4, 15, z + 14), 0.8, 0.8, Kit.Vivid(YELLOW), { Mat = METAL })
	Kit.Ball(m, 2, V(x + 4, 15, z + 14.8), Kit.Vivid(RED))
	-- spring
	for i = 0, 6 do
		Kit.Cyl(m, 2.2, 7, CFrame.new(x + (if i % 2 == 0 then 0.8 else -0.8), 23.6 + i * 2.6, z), C(200, 205, 220), { Mat = METAL })
	end
	-- ruff, head, face, jester hat
	Kit.Cyl(m, 2, 15, CFrame.new(x, 41.5, z), Kit.Vivid(YELLOW), { Mat = FABRIC })
	Kit.Ball(m, 14, V(x, 49, z), C(255, 236, 222))
	local nose = Kit.Ball(m, 2.6, V(x + 6.9, 49, z), RED, { Mat = NEON })
	Kit.Light(nose, C(255, 120, 130), 22, 1.2)
	for _, s in { -1, 1 } do
		Kit.Ball(m, 1.8, V(x + 6, 51.4, z + s * 2.6), DARK)
		Kit.Ball(m, 2.2, V(x + 5.6, 47.6, z + s * 4.3), Kit.Vivid(C(255, 170, 190)))
		Props.Beam(m, V(x, 55, z + s * 1.5), V(x - 1, 62, z + s * 8), 3.4, 3.4, Kit.Vivid(if s < 0 then PURPLE else SKY), { Mat = FABRIC })
		Kit.Ball(m, 2.6, V(x - 1, 62.8, z + s * 8.6), Kit.Vivid(YELLOW))
	end
	Kit.Part(m, V(0.5, 0.9, 5), CFrame.new(x + 6.7, 45.6, z), Kit.Vivid(RED))
	Kit.Cyl(m, 2.4, 12, CFrame.new(x, 55, z), Kit.Vivid(PURPLE), { Mat = FABRIC })
	-- confetti puffing out of the box
	local src = Kit.Part(m, V(10, 1, 10), CFrame.new(x, 24, z), WHITE, { Transp = 1, Name = "ConfettiSource" })
	local e = Kit.Emitter(src, PINK, 4, 0.6, 3)
	if e then
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PINK),
			ColorSequenceKeypoint.new(0.33, SKY),
			ColorSequenceKeypoint.new(0.66, YELLOW),
			ColorSequenceKeypoint.new(1, PURPLE),
		})
		e.LightEmission = 0.2
		e.Size = NumberSequence.new(0.5)
		e.Transparency = NumberSequence.new(0)
		e.Lifetime = NumberRange.new(2, 3.5)
		e.Acceleration = V(0, -4, 0)
		e.EmissionDirection = Enum.NormalId.Top
	end
	Kit.AddCircle(x, z, 17)
end

--==================================================================
-- OUTSIDE
--==================================================================
local function outside(f: Instance)
	local o = Kit.Folder(f, "Outside")
	for _, s in { -1, 1 } do
		Kit.Box(o, V(s * 190, -3, Z0), V(s * 420, -0.2, Z1), C(120, 205, 110), { Mat = GRASS })
		for i, h in { { 60, 92 }, { 250, 80 } } do
			local cx, cz, ht = s * (180 + i * 14), rz(h[1]), h[2]
			Kit.Cyl(o, ht, 11, CFrame.new(cx, ht / 2, cz), WHITE, { Shadow = true })
			for k = 1, 4 do
				Kit.Cyl(o, 5, 11.4, CFrame.new(cx, ht * k / 5, cz), Kit.Vivid(if (k + i) % 2 == 0 then PINK else SKY))
			end
			Kit.Cyl(o, 3, 13, CFrame.new(cx, ht + 1.5, cz), Kit.Vivid(PURPLE))
			Kit.Ball(o, 12, V(cx + 2, ht + 9, cz), WHITE, { Transp = 0.35 })
			Kit.Ball(o, 8, V(cx + 6, ht + 16, cz + 3), WHITE, { Transp = 0.5 })
			if s > 0 and i == 1 then
				local top = Kit.Part(o, V(8, 1, 8), CFrame.new(cx, ht + 4, cz), WHITE, { Transp = 1, Name = "SteamSource" })
				Kit.Emitter(top, C(250, 250, 255), 2, 8, 2)
			end
		end
		-- pastel hills and lollipop trees
		for i = 0, 2 do
			Kit.Ball(o, 90, V(s * (290 + i * 20), -30, Z0 + 60 + i * 120), Kit.Vivid(if i % 2 == 0 then C(170, 230, 150) else C(255, 200, 220)), { Mat = GRASS })
		end
		for i = 0, 3 do
			Props.Tree(o, V(s * (158 + (i % 2) * 14), 0, Z0 + 30 + i * 90 + 25), 18 + (i % 3) * 4)
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function ToyFactory.Build(map: Instance)
	local f = Kit.Folder(map, "ToyFactory")
	local rng = Kit.Rng

	ground(f)
	sideWalls(f)
	ghostPaint(f)
	gantry(f)
	teddy(f, 95, rz(290))
	jackInTheBox(f, -100, rz(300))

	-- toy train on an oval track in the east work zone
	track(f, 88, rz(42), rz(110), 22)
	train(f, 110, rz(88))
	Kit.AddRect(60, rz(14), 120, rz(138))
	gift(f, 84, rz(60), 4, 0.3)
	gift(f, 92, rz(72), 3, -0.4)
	blockStack(f, 86, rz(96), 5, "TOY")

	conveyor(f, 31, rz(124), rz(206), PURPLE)
	conveyor(f, -31, rz(128), rz(202), MINT)
	conveyor(f, -48, rz(276), rz(330), SKY)
	conveyor(f, 48, rz(226), rz(264), PINK)

	type Stack = { x: number, z: number, s: number, text: string }
	local stacks: { Stack } = {
		{ x = -72, z = rz(30), s = 6, text = "BOO" },
		{ x = -104, z = rz(64), s = 5, text = "ABC" },
		{ x = -124, z = rz(24), s = 6, text = "GH" },
	}
	for _, b in stacks do
		if Kit.IsFree(b.x, b.z, b.s + 1) then
			blockStack(f, b.x, b.z, b.s, b.text)
		end
	end
	windupMouse(f, -46, rz(166))

	-- lamp posts along the lane (three lit)
	local cols = { PINK, SKY, YELLOW }
	local n = 0
	for z = Z0 + 50, Z1 - 30, 44 do
		for _, s in { -1, 1 } do
			local zz = z + (if s > 0 then 22 else 0)
			local x = s * 13
			if zz < Z1 - 26 and Kit.IsFree(x, zz, 1.4, true) then
				n += 1
				Props.StreetLamp(f, V(x, 0, zz), Kit.Vivid(cols[(n % 3) + 1]), n == 2 or n == 6)
				Kit.AddCircle(x, zz, 1.6)
			end
		end
	end

	-- toy soldiers and gift boxes
	local soldiers, gifts = 0, 0
	for _ = 1, 600 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(Z0 + 30, Z1 - 28)
		if soldiers < 4 and math.abs(x) < 40 and Kit.IsFree(x, z, 3.5) then
			soldiers += 1
			soldier(f, x, z, -x, 0)
		elseif gifts < 12 and Kit.IsFree(x, z, 3.5) then
			gifts += 1
			local s = rng:NextNumber(3, 5.5)
			gift(f, x, z, s, rng:NextNumber(0, 1.5))
			if rng:NextNumber() < 0.4 then
				gift(f, x + rng:NextNumber(-0.4, 0.4), z, 2.4, rng:NextNumber(0, 1.5), s)
			end
			Kit.AddCircle(x, z, 3.5)
		end
	end
	-- balloons drifting over the hall
	for i, p in { V(118, 18, rz(240)), V(60, 16, rz(132)), V(-120, 14, rz(84)), V(-50, 18, rz(300)), V(122, 15, rz(166)) } do
		local b = Kit.Ball(f, 3.2, p, Kit.Vivid(TOYS[i]), { Name = "Balloon" })
		Kit.Float(b, rng:NextNumber(0.8, 1.4))
	end

	outside(f)
end

return ToyFactory
