--!strict
-- ZONE 5: Haunted Hospital (Z 1220..1560). Playful, pastel and a little supernatural (no gore).
--   Courtyard Z 1220..1268: path, Medical crate station (built by Stations), ambulance, sign,
--   planters, entrance canopy with the HOSPITAL facade and a red cross on a blue/white emblem.
--   Building X -113..113, Z 1269..1535, two-tone walls 16 tall, NO roof (parapet only) so the
--   camera and ghost taps work from above. Rooms (ghost areas in brackets):
--     Lobby / waiting room  X -51..49,  Z 1271..1351  [ (0,1305) r30 ]   reception desk, chairs
--     Ward B                X -111..-53, Z 1271..1397  [ (-82,1340) r24 ] beds in the corners
--     Patient rooms         X 51..111,   Z 1271..1351                    beds, curtains, monitors
--     X-Ray                 X 41..111,   Z 1353..1443  [ (75,1395) r26 ]  machine, lightbox
--     Atrium (hallway)      X -51..39,   Z 1353..1443                    elevators, carts
--     Paranormal lab        X -111..-33, Z 1399..1533  [ (-62,1455) r24 ] ecto tanks, spirit coil
--     Director's office     X -31..31,   Z 1445..1533  [ (0,1505) r22 boss ]
--     Pharmacy              X 33..111,   Z 1445..1533                    counter, shelves
--   Main path: front door (X -14..14) -> lobby -> atrium -> director's office -> back door
--   (X -14..14) -> back yard -> Harbor gate. Every doorway is a full-height opening >= 16 wide.
--   Landmark: the west wing tower (X -111..-85, Z 1507..1533, roof Y 72, antenna to ~Y 83).
-- Glow is kept to a few ghostly windows, ecto tanks, puddles, sconces and small lamps.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Hospital = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local CONCRETE = Enum.Material.Concrete
local WOOD = Enum.Material.WoodPlanks

local MIN_Z, MAX_Z = 1220, 1560
local H = 16
local FLOOR_Y = 0.13 -- top of the room floor paint
local WHITE = C(242, 244, 248)
local LBLUE = C(150, 205, 240)
local MGREEN = C(150, 200, 170)
local PURPLE = C(170, 120, 230)
local SPECT = C(130, 255, 190)
local DARK = C(45, 55, 85)
local REDX = C(235, 70, 80)
local GREY = C(190, 195, 210)
local SOLID: Kit.Opts = { Solid = true, Shadow = true }

local function faced(center: Vector3, fx: number, fz: number): CFrame
	return CFrame.new(center) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
end

--==================================================================
-- WALL HELPERS (two-tone: mint wainscot below, off-white above)
--==================================================================
type Opening = { c: number, w: number }

local LOWER = C(170, 215, 195)
local UPPER = C(236, 240, 244)

local function seg(parent: Instance, lo: Vector3, hi: Vector3)
	Kit.Box(parent, V(lo.X, 0, lo.Z), V(hi.X, 4.5, hi.Z), LOWER, SOLID)
	Kit.Box(parent, V(lo.X, 4.5, lo.Z), V(hi.X, H, hi.Z), UPPER, SOLID)
end

local function byCentre(a: Opening, b: Opening): boolean
	return a.c < b.c
end

-- Wall along X at fixed z (thickness 2) with full-height openings.
local function wallX(parent: Instance, z: number, x1: number, x2: number, openings: { Opening })
	table.sort(openings, byCentre)
	local cur = x1
	for _, o in openings do
		local a = o.c - o.w / 2
		if a > cur then
			seg(parent, V(cur, 0, z - 1), V(a, 0, z + 1))
		end
		cur = o.c + o.w / 2
	end
	if x2 > cur then
		seg(parent, V(cur, 0, z - 1), V(x2, 0, z + 1))
	end
end

-- Wall along Z at fixed x (thickness 2) with full-height openings.
local function wallZ(parent: Instance, x: number, z1: number, z2: number, openings: { Opening })
	table.sort(openings, byCentre)
	local cur = z1
	for _, o in openings do
		local a = o.c - o.w / 2
		if a > cur then
			seg(parent, V(x - 1, 0, cur), V(x + 1, 0, a))
		end
		cur = o.c + o.w / 2
	end
	if z2 > cur then
		seg(parent, V(x - 1, 0, cur), V(x + 1, 0, z2))
	end
end

-- Wall lamp; fx = direction the lamp faces (wall face is behind it).
local function sconce(parent: Instance, pos: Vector3, fx: number, color: Color3)
	local lamp = Kit.Part(parent, V(0.8, 1.8, 2.2), CFrame.new(pos), color, { Mat = NEON })
	Kit.Part(parent, V(0.5, 0.4, 2.8), CFrame.new(pos + V(-fx * 0.15, 1.1, 0)), DARK)
	Kit.Light(lamp, color, 24, 1.5, true)
end

local function puddle(parent: Instance, x: number, z: number, d: number)
	Kit.Disc(parent, x, z, 0.22, d, 0.08, SPECT, { Mat = NEON, Transp = 0.25 })
end

--==================================================================
-- FURNITURE
--==================================================================
-- Hospital bed; (hx, hz) points toward the head end.
local function bed(f: Instance, x: number, z: number, hx: number, hz: number)
	local m = Kit.Model(f, "Bed")
	local base = faced(V(x, FLOOR_Y, z), hx, hz)
	Kit.Part(m, V(5, 2.2, 9), base * CFrame.new(0, 1.1, 0), WHITE, { Solid = true })
	Kit.Part(m, V(4.6, 1, 8.6), base * CFrame.new(0, 2.7, 0), Kit.Vivid(LBLUE), { Mat = FABRIC })
	Kit.Part(m, V(3.6, 0.8, 1.8), base * CFrame.new(0, 3.5, -3.2), WHITE, { Mat = FABRIC })
	Kit.Part(m, V(5.4, 5, 0.6), base * CFrame.new(0, 2.5, -4.7), Kit.Vivid(MGREEN))
	Kit.Part(m, V(4.8, 0.4, 4.6), base * CFrame.new(0, 3.3, 1.9), PURPLE:Lerp(WHITE, 0.35), { Mat = FABRIC })
	Kit.AddCircle(x, z, 5)
end

local function ivStand(f: Instance, x: number, z: number)
	Kit.Cyl(f, 7, 0.3, CFrame.new(x, FLOOR_Y + 3.5, z), GREY, { Mat = METAL })
	Kit.Box(f, V(x - 0.4, 5.6, z - 0.2), V(x + 0.4, 7, z + 0.2), Kit.Vivid(MGREEN), { Transp = 0.3 })
end

local function wheelchair(f: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(f, "Wheelchair")
	local base = faced(V(x, FLOOR_Y, z), fx, fz)
	local frame = Kit.Vivid(PURPLE)
	Kit.Part(m, V(2.6, 0.5, 2.4), base * CFrame.new(0, 2.2, 0), Kit.Vivid(LBLUE))
	Kit.Part(m, V(2.6, 3, 0.4), base * CFrame.new(0, 3.6, 1.2), Kit.Vivid(LBLUE))
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.3, 3.4, 3.4), base * CFrame.new(sx * 1.55, 1.7, 0.3), frame, { Shape = Enum.PartType.Cylinder })
	end
	Kit.Part(m, V(2.2, 0.3, 1), base * CFrame.new(0, 0.8, -1.8), frame)
	Kit.AddCircle(x, z, 2.5)
end

local function medCart(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "MedCart")
	Kit.Box(m, V(x - 2, 3.2, z - 1.3), V(x + 2, 3.6, z + 1.3), WHITE)
	Kit.Box(m, V(x - 2, 1, z - 1.3), V(x + 2, 1.3, z + 1.3), WHITE)
	for _, s in { -1, 1 } do
		Kit.Box(m, V(x + s * 1.85, FLOOR_Y, z - 1.3), V(x + s * 2.05, 3.2, z + 1.3), Kit.Vivid(LBLUE))
	end
	Kit.Box(m, V(x - 1.4, 3.6, z - 0.6), V(x - 0.2, 4.4, z + 0.6), Kit.Vivid(C(255, 150, 190)))
	Kit.Cyl(m, 1.2, 0.7, CFrame.new(x + 1, 4.2, z), Kit.Vivid(MGREEN))
	Kit.AddCircle(x, z, 3)
end

-- Bedside monitor with a SurfaceGui screen facing fx (-1 = -X, 1 = +X).
local function monitor(f: Instance, x: number, z: number, fx: number)
	Kit.Box(f, V(x - 0.25, FLOOR_Y, z - 0.25), V(x + 0.25, 5, z + 0.25), GREY, { Mat = METAL })
	local scr = Kit.Part(f, V(0.4, 2.2, 3), CFrame.new(x, 6, z), DARK)
	Kit.Sign(scr, if fx < 0 then Enum.NormalId.Left else Enum.NormalId.Right, "♥ BOO ♥", SPECT)
end

-- Row of joined waiting-room chairs along Z (facing +X when fx = 1).
local function chairRow(f: Instance, x: number, z1: number, z2: number, fx: number, color: Color3)
	Kit.Box(f, V(x - 1.5, 1.8, z1), V(x + 1.5, 2.4, z2), color, { Solid = true })
	Kit.Box(f, V(x - fx * 1.5, 2.4, z1), V(x - fx * 1, 5, z2), color)
	for _, z in { z1 + 0.8, z2 - 0.8 } do
		Kit.Box(f, V(x - 1.2, FLOOR_Y, z - 0.35), V(x + 1.2, 1.8, z + 0.35), GREY, { Mat = METAL })
	end
	Kit.AddRect(x - 2, z1, x + 2, z2)
end

local function chair(f: Instance, x: number, z: number, fx: number, fz: number, color: Color3)
	local base = faced(V(x, FLOOR_Y, z), fx, fz)
	Kit.Part(f, V(2.4, 2, 2.4), base * CFrame.new(0, 1, 0), color, { Solid = true })
	Kit.Part(f, V(2.4, 2.6, 0.5), base * CFrame.new(0, 3.3, 0.95), color)
end

local function plant(f: Instance, x: number, z: number)
	Kit.Cyl(f, 2.4, 2.4, CFrame.new(x, FLOOR_Y + 1.2, z), WHITE)
	Kit.Ball(f, 3.6, V(x, 4, z), C(110, 180, 120), { Mat = Enum.Material.Grass })
	Kit.AddCircle(x, z, 2)
end

local function bench(f: Instance, x: number, z: number, fx: number, fz: number)
	local base = faced(V(x, 0, z), fx, fz)
	Kit.Part(f, V(6, 0.6, 2.2), base * CFrame.new(0, 2, 0), C(190, 140, 100), { Mat = WOOD, Solid = true })
	Kit.Part(f, V(6, 2.4, 0.5), base * CFrame.new(0, 3.6, 1), C(190, 140, 100), { Mat = WOOD })
	for _, sx in { -1, 1 } do
		Kit.Part(f, V(0.5, 2, 2), base * CFrame.new(sx * 2.6, 1, 0), Kit.Vivid(LBLUE))
	end
	Kit.AddCircle(x, z, 3.5)
end

local function floater(f: Instance, size: Vector3, pos: Vector3, color: Color3, name: string, shape: Enum.PartType?)
	local rng = Kit.Rng
	local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
	local p = Kit.Part(f, size, cf, color, { Name = name, Shape = shape })
	Kit.Float(p, rng:NextNumber(0.6, 1.1))
end

--==================================================================
-- GROUND, SIDE WALLS, OUTSIDE
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, MIN_Z), V(190, 0, MAX_Z), C(125, 190, 135), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_Hospital" })
	-- paved path to the front door and from the back door to the Harbor gate (flat)
	local pave = C(210, 215, 225)
	Kit.Box(f, V(-10, 0, MIN_Z), V(10, 0.05, 1269), pave, { Mat = CONCRETE, Name = "Path" })
	Kit.Box(f, V(-10, 0, 1535), V(10, 0.05, MAX_Z), pave, { Mat = CONCRETE, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 10, 0, MIN_Z), V(s * 10.8, 0.06, 1269), Kit.Vivid(LBLUE))
		Kit.Box(f, V(s * 10, 0, 1535), V(s * 10.8, 0.06, MAX_Z), Kit.Vivid(LBLUE))
	end
end

local function sideWalls(f: Instance)
	local z0, z1 = MIN_Z + 3, MAX_Z - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, 0, z0), V(s * 146, 12, z1), WHITE, { Mat = CONCRETE, Solid = true })
		Kit.Box(f, V(s * 139.5, 12, z0), V(s * 146.5, 13.2, z1), Kit.Vivid(LBLUE), { Mat = Enum.Material.Slate })
		Kit.Box(f, V(s * 139.8, 3, z0), V(s * 140, 4.2, z1), Kit.Vivid(MGREEN))
		for i = 1, 7 do
			local z = z0 + i * (z1 - z0) / 8
			Kit.Box(f, V(s * 139, 0, z - 2.5), V(s * 147, 15, z + 2.5), C(215, 225, 235), SOLID)
			Kit.Ball(f, 3.4, V(s * 143, 16.6, z), Kit.Vivid(C(140, 220, 180)))
		end
	end
end

local function outside(f: Instance)
	local hill = { C(110, 160, 140), C(140, 120, 200), C(120, 175, 150) }
	for i, z in { 1265, 1400, 1525 } do
		for _, s in { -1, 1 } do
			Kit.Ball(f, 70, V(s * 190, -14, z - s * 15), hill[(i + (if s > 0 then 1 else 0)) % #hill + 1], { Mat = Enum.Material.Grass })
		end
	end
	-- annex blocks beyond the walls
	for _, a in { V(-1, 0, 1330), V(1, 0, 1440) } do
		local s, z = a.X, a.Z
		Kit.Box(f, V(s * 156, 0, z - 22), V(s * 186, 30, z + 22), C(232, 236, 240), { Mat = CONCRETE })
		Kit.Box(f, V(s * 155.7, 18, z - 20), V(s * 155.9, 23, z + 20), Kit.Vivid(LBLUE))
		Kit.Box(f, V(s * 155.5, 30, z - 22.5), V(s * 186.5, 31.5, z + 22.5), Kit.Vivid(MGREEN))
	end
	for _, z in { 1240, 1545 } do
		for _, s in { -1, 1 } do
			Props.Tree(f, V(s * 158, 0, z), 20 + Kit.Rng:NextNumber(0, 8), Kit.Pick({ C(120, 190, 130), C(170, 120, 220), C(100, 170, 150) }))
		end
	end
end

--==================================================================
-- COURTYARD
--==================================================================
local function ambulance(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Ambulance")
	local base = faced(V(x, 0, z), -1, 0) -- front toward the path (-X)
	local cargo = Kit.Part(m, V(8, 7.5, 11), base * CFrame.new(0, 5.25, 2.5), WHITE, SOLID)
	cargo.Name = "Cargo"
	Kit.Part(m, V(7.6, 5.5, 5), base * CFrame.new(0, 4.25, -5.5), WHITE, SOLID)
	local glass = Kit.Vivid(C(170, 225, 255))
	Kit.Part(m, V(6.6, 2.4, 0.3), base * CFrame.new(0, 5.6, -8.05), glass, { Refl = 0.2 })
	Kit.Part(m, V(7.7, 2.2, 3), base * CFrame.new(0, 5.6, -5.4), glass, { Refl = 0.2 })
	Kit.Part(m, V(8.1, 1.2, 11.1), base * CFrame.new(0, 4.5, 2.5), REDX)
	Kit.Part(m, V(7.7, 0.8, 5.1), base * CFrame.new(0, 3.2, -5.5), Kit.Vivid(LBLUE))
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.2, 3, 1), base * CFrame.new(sx * 4.05, 7, 3), REDX)
		Kit.Part(m, V(0.2, 1, 3), base * CFrame.new(sx * 4.05, 7, 3), REDX)
		for _, sz in { -5, 5.5 } do
			Kit.Part(m, V(1.2, 3.4, 3.4), base * CFrame.new(sx * 3.8, 1.7, sz), DARK, { Shape = Enum.PartType.Cylinder })
		end
		Kit.Part(m, V(0.9, 0.8, 0.2), base * CFrame.new(sx * 2.7, 3, -8.05), C(255, 240, 170))
		Kit.Part(m, V(2.2, 0.9, 1.2), base * CFrame.new(sx * 1.2, 9.45, -1.5), if sx < 0 then REDX else C(90, 160, 255), { Mat = NEON })
	end
	Kit.Part(m, V(7.8, 0.8, 0.6), base * CFrame.new(0, 1.8, -8.3), GREY)
	local tag = Kit.Part(m, V(6, 1, 0.2), base * CFrame.new(0, 7.6, -8.1), WHITE)
	Kit.Sign(tag, Enum.NormalId.Front, "AMBULANCE 👻", REDX, { Stroke = WHITE })
	Kit.AddCircle(x, z, 11)
end

local function courtyard(f: Instance)
	ambulance(f, 72, 1250)
	for _, z in { 1242, 1258 } do
		Kit.Box(f, V(60, 0, z - 0.3), V(86, 0.05, z + 0.3), WHITE)
	end
	-- welcome sign
	Kit.Box(f, V(-74, 0, 1256.5), V(-50, 3, 1259.5), WHITE, { Mat = CONCRETE, Solid = true })
	Props.SignBoard(f, V(-62, 6.4, 1258), 22, 6, 0, -1, "HAUNTED HOSPITAL\nvisiting hours: forever", C(60, 110, 170), WHITE, MGREEN)
	Kit.AddRect(-75, 1255, -49, 1261)
	-- planters
	for _, x in { -96, -44, 44, 96 } do
		if Kit.IsFree(x, 1263, 3) then
			Kit.Box(f, V(x - 2.5, 0, 1260.5), V(x + 2.5, 2, 1265.5), WHITE, { Mat = CONCRETE, Solid = true })
			Kit.Ball(f, 5, V(x, 3, 1263), C(110, 180, 120), { Mat = Enum.Material.Grass })
			Kit.AddCircle(x, 1263, 3)
		end
	end
	Props.StreetLamp(f, V(-104, 0, 1245), C(190, 235, 255), true)
	Props.StreetLamp(f, V(108, 0, 1240), C(190, 235, 255), false)
	Kit.AddCircle(-104, 1245, 1.5)
	Kit.AddCircle(108, 1240, 1.5)
	bench(f, -88, 1232, 0, 1)
	bench(f, 100, 1228, 0, 1)
end

local function entrance(f: Instance)
	-- canopy over the front door
	Kit.Box(f, V(-16.5, 12, 1254), V(16.5, 13.2, 1268.9), Kit.Vivid(LBLUE))
	Kit.Box(f, V(-16.7, 12.2, 1253.8), V(16.7, 13, 1254.1), WHITE)
	for _, s in { -1, 1 } do
		Kit.Cyl(f, 12, 1.4, CFrame.new(s * 14.5, 6, 1258), WHITE, SOLID)
	end
	local lamp = Kit.Box(f, V(-3, 11.6, 1258), V(3, 12, 1262), C(225, 255, 240), { Mat = NEON })
	Kit.Light(lamp, C(210, 255, 235), 24, 1.3)
	Kit.AddRect(-17, 1253, 17, 1269)
	-- facade block over the door (bottom Y 16) with the big sign and the cross emblem
	Kit.Box(f, V(-20, 16, 1266.5), V(20, 30, 1271.5), WHITE, SOLID)
	Kit.Box(f, V(-20.3, 16, 1266.2), V(20.3, 17, 1266.5), Kit.Vivid(LBLUE))
	Kit.Box(f, V(-20.5, 29.5, 1266), V(20.5, 31, 1272), Kit.Vivid(LBLUE))
	local sign = Kit.Part(f, V(30, 6.5, 0.4), CFrame.new(0, 23.4, 1266.2), C(60, 110, 170))
	Kit.Sign(sign, Enum.NormalId.Front, "HOSPITAL", WHITE, { Stroke = C(20, 40, 90) })
	Kit.CylFlat(f, 1, 13, V(0, 37.5, 1269.4), "Z", Kit.Vivid(LBLUE))
	Kit.CylFlat(f, 1, 11.4, V(0, 37.5, 1268.8), "Z", WHITE)
	Kit.Box(f, V(-1.3, 33.5, 1268), V(1.3, 41.5, 1268.4), REDX)
	Kit.Box(f, V(-4, 36.2, 1268), V(4, 38.8, 1268.4), REDX)
end

--==================================================================
-- BUILDING SHELL
--==================================================================
local function shell(f: Instance)
	Kit.Box(f, V(-113, -0.5, 1269), V(113, 0.1, 1535), C(215, 222, 230), { Solid = true, Name = "HospitalFloor" })
	-- room floors (flat paint, top Y 0.13)
	local function floor(x1: number, z1: number, x2: number, z2: number, color: Color3, mat: Enum.Material?)
		Kit.Box(f, V(x1, 0.1, z1), V(x2, FLOOR_Y, z2), color, { Mat = mat })
	end
	local tiles = { C(236, 241, 246), C(190, 222, 238) }
	for i = 0, 3 do
		for j = 0, 2 do
			local x0, z0 = -51 + i * 25, 1271 + j * (80 / 3)
			floor(x0, z0, x0 + 25, z0 + 80 / 3, tiles[((i + j) % 2) + 1])
		end
	end
	floor(-111, 1271, -53, 1397, C(205, 232, 214))
	floor(51, 1271, 111, 1351, C(228, 218, 242))
	floor(41, 1353, 111, 1443, C(205, 220, 242))
	floor(-51, 1353, 39, 1397, C(230, 236, 242))
	floor(-31, 1397, 39, 1443, C(230, 236, 242))
	floor(-111, 1399, -33, 1533, C(212, 236, 226))
	floor(-31, 1445, 31, 1533, C(185, 160, 215), FABRIC)
	floor(33, 1445, 111, 1533, C(242, 232, 214))
	-- light-blue runner along the main path + "follow the line" guides (flat)
	Kit.Box(f, V(-9, FLOOR_Y, 1271), V(9, 0.16, 1533), C(200, 228, 245), { Name = "Runner" })
	Kit.Box(f, V(-4.4, 0.16, 1271), V(-3.6, 0.19, 1533), Kit.Vivid(MGREEN))
	Kit.Box(f, V(3.6, 0.16, 1271), V(4.4, 0.19, 1533), Kit.Vivid(LBLUE))

	-- exterior walls (doors: front + back on the path, one side door each way)
	wallX(f, 1270, -113, 113, { { c = 0, w = 28 } })
	wallX(f, 1534, -113, 113, { { c = 0, w = 28 } })
	wallZ(f, -112, 1271, 1533, { { c = 1470, w = 16 } })
	wallZ(f, 112, 1271, 1533, { { c = 1460, w = 16 } })
	-- interior walls (all outside the ghost circles)
	wallZ(f, -52, 1271, 1398, { { c = 1310, w = 20 } }) -- lobby | ward
	wallZ(f, 50, 1271, 1351, { { c = 1315, w = 20 } }) -- lobby | patient rooms
	wallX(f, 1352, 39, 111, { { c = 80, w = 18 } }) -- patient rooms | x-ray
	wallX(f, 1352, -51, 39, { { c = -6, w = 60 } }) -- lobby | atrium (stubs)
	wallX(f, 1398, -111, -31, { { c = -80, w = 20 } }) -- ward | lab
	wallZ(f, 40, 1353, 1443, { { c = 1398, w = 24 } }) -- atrium | x-ray
	wallX(f, 1444, 31, 111, { { c = 75, w = 20 } }) -- x-ray | pharmacy
	wallZ(f, -32, 1399, 1533, { { c = 1422, w = 18 }, { c = 1505, w = 18 } }) -- lab | atrium, office
	wallZ(f, 32, 1445, 1533, { { c = 1490, w = 20 } }) -- office | pharmacy
	wallX(f, 1444, -31, 31, { { c = 0, w = 40 } }) -- atrium | office (stubs)

	-- parapet on the exterior walls (no roof over the rooms)
	local rim = Kit.Vivid(LBLUE)
	Kit.Box(f, V(-114, H, 1268), V(114, H + 1.6, 1272), rim, SOLID)
	Kit.Box(f, V(-114, H, 1532), V(114, H + 1.6, 1536), rim, SOLID)
	Kit.Box(f, V(-114, H, 1268), V(-110, H + 1.6, 1536), rim, SOLID)
	Kit.Box(f, V(110, H, 1268), V(114, H + 1.6, 1536), rim, SOLID)
	-- corner columns
	for _, x in { -113, 113 } do
		for _, z in { 1270, 1534 } do
			Kit.Cyl(f, 20, 6, CFrame.new(x, 10, z), WHITE, SOLID)
			Kit.Cyl(f, 1.4, 7, CFrame.new(x, 20.7, z), Kit.Vivid(MGREEN))
		end
	end

	-- windows: light-blue glass, a few ghostly ones glow
	local function window(lo: Vector3, hi: Vector3, glow: boolean)
		Kit.Box(f, lo, hi, if glow then SPECT else Kit.Vivid(C(175, 220, 245)), if glow then { Mat = NEON, Transp = 0.1 } else { Refl = 0.15 })
	end
	for _, x in { -100, -80, -55, -32, 32, 55, 80, 100 } do
		Kit.Box(f, V(x - 3.5, 5.5, 1268.7), V(x + 3.5, 12.5, 1268.95), WHITE)
		window(V(x - 2.8, 6, 1268.55), V(x + 2.8, 12, 1268.8), x == -55 or x == 80)
	end
	for _, s in { -1, 1 } do
		for _, z in { 1300, 1340, 1380, 1420, 1495 } do
			if not (s < 0 and z == 1495) then
				Kit.Box(f, V(s * 113, 5.5, z - 3.5), V(s * 113.25, 12.5, z + 3.5), WHITE)
				window(V(s * 113.15, 6, z - 2.8), V(s * 113.4, 12, z + 2.8), (s < 0 and z == 1340) or (s > 0 and z == 1420))
			end
		end
	end
	Kit.Box(f, V(-113.2, 14, 1268.7), V(113.2, 14.6, 1268.9), Kit.Vivid(MGREEN))
	Kit.AddRect(-116, 1266, 116, 1538)
end

--==================================================================
-- TOWER (landmark, back-west corner of the lab)
--==================================================================
local function tower(f: Instance)
	local m = Kit.Model(f, "HospitalTower")
	local x1, x2, z1, z2 = -111, -85, 1507, 1533
	Kit.Box(m, V(x1, 0, z1), V(x2, 64, z2), WHITE, { Solid = true, Shadow = true, Name = "Tower" })
	for _, y in { 16, 32, 48 } do
		Kit.Box(m, V(x1 - 0.3, y, z1 - 0.3), V(x2 + 0.3, y + 1, z2 + 0.3), Kit.Vivid(LBLUE))
	end
	Kit.Box(m, V(x1 - 0.5, 63.5, z1 - 0.5), V(x2 + 0.5, 65, z2 + 0.5), Kit.Vivid(PURPLE))
	Kit.Box(m, V(x1 + 3, 65, z1 + 3), V(x2 - 3, 72, z2 - 3), C(228, 236, 245), SOLID)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	Kit.Disc(m, cx, cz, 72.4, 16, 0.4, Kit.Vivid(MGREEN))
	local pad = Kit.Box(m, V(cx - 4, 72.4, cz - 4), V(cx + 4, 72.5, cz + 4), WHITE, { Transp = 1 })
	Kit.Sign(pad, Enum.NormalId.Top, "H", WHITE, { Stroke = C(60, 110, 170) })
	Kit.Cyl(m, 10, 0.6, CFrame.new(x2 - 5, 77, z2 - 5), GREY, { Mat = METAL })
	local beacon = Kit.Ball(m, 1.8, V(x2 - 5, 82.5, z2 - 5), C(255, 100, 120), { Mat = NEON })
	Kit.Light(beacon, C(255, 130, 140), 30, 1.2)
	-- windows on the -Z face (toward the Carnival) and the +X face (toward the lab)
	local glass = Kit.Vivid(C(175, 220, 245))
	for row = 0, 1 do
		local y = 24 + row * 16
		for col = 0, 2 do
			local x = x1 + 5 + col * 8
			local glow = (row + col) % 3 == 1
			Kit.Box(m, V(x - 2.5, y - 3, z1 - 0.3), V(x + 2.5, y + 3, z1), if glow then SPECT else glass, if glow then { Mat = NEON } else { Refl = 0.15 })
		end
	end
	for row = 0, 2 do
		local y = 24 + row * 16
		for col = 0, 2 do
			local z = z1 + 5 + col * 8
			local glow = (row + col) % 4 == 2
			Kit.Box(m, V(x2, y - 3, z - 2.5), V(x2 + 0.3, y + 3, z + 2.5), if glow then SPECT else glass, if glow then { Mat = NEON } else { Refl = 0.15 })
		end
	end
	-- red cross emblem near the top of the front face
	Kit.Box(m, V(-104, 51.5, z1 - 0.5), V(-92, 62.5, z1 - 0.1), Kit.Vivid(LBLUE))
	Kit.Box(m, V(-99.3, 53, z1 - 0.8), V(-96.7, 61, z1 - 0.4), REDX)
	Kit.Box(m, V(-102, 55.7, z1 - 0.8), V(-94, 58.3, z1 - 0.4), REDX)
	Kit.AddRect(x1 - 1, z1 - 1, x2 + 1, z2 + 1)
end

--==================================================================
-- ROOMS
--==================================================================
local function lobby(f: Instance)
	-- reception desk (east front corner, outside the ghost circle)
	Kit.Box(f, V(36, FLOOR_Y, 1276), V(39, 4, 1298), WHITE, { Solid = true })
	Kit.Box(f, V(35.8, 1.5, 1276), V(36, 2.5, 1298), Kit.Vivid(LBLUE))
	Kit.Box(f, V(35.5, 4, 1275.5), V(39.5, 4.5, 1298.5), Kit.Vivid(MGREEN))
	local mon = Kit.Box(f, V(37.2, 4.5, 1285), V(37.6, 7, 1289), DARK)
	Kit.Sign(mon, Enum.NormalId.Left, "👻 ON CALL", SPECT)
	Kit.Light(mon, C(190, 255, 220), 18, 1)
	Kit.Ball(f, 0.9, V(36.2, 4.9, 1293), Kit.Vivid(C(255, 210, 80)), { Refl = 0.3 })
	chair(f, 43, 1287, -1, 0, Kit.Vivid(PURPLE))
	Props.SignBoard(f, V(48.6, 11, 1287), 14, 3, -1, 0, "RECEPTION", C(60, 110, 170), WHITE)
	Kit.AddRect(35, 1275, 46, 1299)
	-- waiting chairs (west corners)
	chairRow(f, -46, 1275, 1296, 1, Kit.Vivid(LBLUE))
	chairRow(f, -39, 1275, 1296, 1, Kit.Vivid(MGREEN))
	chairRow(f, -46, 1326, 1348, 1, Kit.Vivid(MGREEN))
	chairRow(f, -39, 1328, 1348, 1, Kit.Vivid(LBLUE))
	Props.SignBoard(f, V(-42, 11, 1271.6), 18, 3, 0, 1, "WAITING ROOM", C(60, 110, 170), WHITE)
	-- vending machine against the east wall
	Kit.Box(f, V(45, FLOOR_Y, 1336), V(48.8, 9, 1342), Kit.Vivid(PURPLE), { Solid = true })
	local front = Kit.Box(f, V(44.8, 2, 1336.6), V(45, 8.4, 1341.4), C(215, 240, 255))
	Kit.Sign(front, Enum.NormalId.Left, "BOO-\nSNACKS", Kit.Vivid(PURPLE), { Stroke = WHITE })
	Kit.AddRect(44, 1335, 49, 1343)
	plant(f, 45, 1276)
	plant(f, -30, 1349)
	-- big painted cross on the floor under the ghosts (flat, a hair above the guide lines so they
	-- don't z-fight) + a puddle
	Kit.Box(f, V(-5, 0.16, 1285), V(5, 0.22, 1325), C(255, 205, 210))
	Kit.Box(f, V(-20, 0.16, 1300), V(20, 0.22, 1310), C(255, 205, 210))
	puddle(f, 12, 1318, 6)
	floater(f, V(1.6, 2.2, 0.2), V(-44, 9, 1311), C(205, 170, 120), "FloatingClipboard")
	floater(f, V(1.6, 2.2, 0.2), V(42, 9, 1316), C(205, 170, 120), "FloatingClipboard")
end

local function ward(f: Instance)
	bed(f, -106, 1280, -1, 0)
	bed(f, -106, 1296, -1, 0)
	bed(f, -106, 1382, -1, 0)
	bed(f, -106, 1392, -1, 0)
	bed(f, -80, 1276.5, 0, -1)
	bed(f, -66, 1276.5, 0, -1)
	ivStand(f, -99.5, 1292)
	ivStand(f, -99.5, 1378)
	local curtain = C(200, 232, 214)
	Kit.Box(f, V(-111, FLOOR_Y, 1287.8), V(-102, 8, 1288.2), curtain, { Mat = FABRIC })
	Kit.Box(f, V(-111, FLOOR_Y, 1386.8), V(-102, 8, 1387.2), curtain, { Mat = FABRIC })
	Props.SignBoard(f, V(-53.4, 12, 1365), 14, 3, -1, 0, "WARD B", C(60, 110, 170), WHITE)
	sconce(f, V(-110.4, 12, 1340), 1, C(200, 255, 225))
	puddle(f, -88, 1348, 5)
	wheelchair(f, -60, 1388, 1, 0)
end

local function patientRooms(f: Instance)
	for _, z in { 1283, 1311, 1340 } do
		bed(f, 106, z, 1, 0)
		monitor(f, 108.5, z - 5.2, -1)
		chair(f, 96, z - 4, -1, 0, Kit.Vivid(PURPLE))
	end
	local curtain = C(225, 212, 242)
	for _, z in { 1297, 1326 } do
		Kit.Box(f, V(86, FLOOR_Y, z - 0.2), V(111, 8, z + 0.2), curtain, { Mat = FABRIC })
		Kit.AddRect(86, z - 1, 111, z + 1)
	end
	Props.SignBoard(f, V(51.4, 11, 1290), 14, 3, 1, 0, "PATIENT ROOMS", C(60, 110, 170), WHITE)
	Props.SignBoard(f, V(65, 11, 1350.6), 18, 3, 0, -1, "VISITING HOURS:\nMIDNIGHT ONLY", C(120, 80, 190), WHITE)
	medCart(f, 70, 1276)
end

local function xray(f: Instance)
	-- x-ray machine in the north-east corner
	Kit.Box(f, V(100, FLOOR_Y, 1355), V(110, 1.5, 1365), GREY, { Solid = true })
	Kit.Box(f, V(99.5, 1.5, 1356), V(105.5, 3.4, 1364), WHITE, { Solid = true })
	Kit.Box(f, V(108, 1.5, 1358), V(110, 13, 1362), WHITE, { Solid = true })
	Kit.Box(f, V(100, 10, 1359), V(108, 11.5, 1361), WHITE)
	Kit.Box(f, V(98, 7.6, 1357.5), V(102, 10, 1362.5), Kit.Vivid(LBLUE))
	Kit.AddRect(98, 1354, 111, 1366)
	-- lightbox on the north wall
	local panel = Kit.Part(f, V(16, 8, 0.4), faced(V(96, 9, 1442.6), 0, -1), C(225, 245, 255))
	Kit.Sign(panel, Enum.NormalId.Front, "X-RAY RESULTS:\n100% GHOST 👻", C(40, 80, 140), { Stroke = WHITE })
	Kit.Light(panel, C(200, 240, 255), 20, 1)
	Props.SignBoard(f, V(39.4, 11, 1418), 10, 3, -1, 0, "X-RAY", C(60, 110, 170), WHITE)
	puddle(f, 68, 1402, 6)
	floater(f, V(1.6, 2.2, 0.2), V(60, 9, 1362), C(205, 170, 120), "FloatingClipboard")
end

local function elevator(f: Instance, z: number)
	Kit.Box(f, V(-51, FLOOR_Y, z - 5), V(-50.2, 12, z + 5), C(180, 190, 205), { Mat = METAL, Solid = true })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(-50.2, FLOOR_Y, z + s * 0.1), V(-49.9, 10, z + s * 4), C(220, 225, 235), { Mat = METAL })
	end
	local disp = Kit.Box(f, V(-50.2, 10.4, z - 2), V(-49.9, 11.6, z + 2), DARK)
	Kit.Sign(disp, Enum.NormalId.Right, "▲ 13 ▼", C(255, 200, 90))
	Kit.AddRect(-52, z - 5, -48, z + 5)
end

local function atrium(f: Instance)
	elevator(f, 1362)
	elevator(f, 1386)
	Props.SignBoard(f, V(-50.4, 14, 1374), 18, 2.4, 1, 0, "ELEVATORS (GHOSTS ONLY)", C(60, 110, 170), WHITE)
	medCart(f, -20, 1380)
	medCart(f, 28, 1432)
	wheelchair(f, 20, 1368, -1, 0)
	wheelchair(f, -22, 1432, 0, 1)
	bench(f, 35, 1366, -1, 0)
	plant(f, 35, 1356)
	plant(f, -27, 1440)
	Props.SignBoard(f, V(39.4, 11, 1434), 14, 3.2, -1, 0, "QUIET PLEASE...\nBOO!", C(120, 80, 190), WHITE)
	sconce(f, V(38.4, 12, 1374), -1, C(255, 230, 170))
	-- overhead sign at the director's wing (Y 11..16, over the path, before the boss room)
	Kit.Box(f, V(-20, 14, 1443.5), V(20, 16, 1444.5), WHITE)
	local s = Kit.Part(f, V(24, 2.8, 0.4), CFrame.new(0, 12.4, 1443.3), C(60, 110, 170))
	Kit.Sign(s, Enum.NormalId.Front, "⬆ DIRECTOR'S OFFICE ⬆", WHITE)
	Props.Wisp(f, V(-10, 0, 1414), SPECT, 9, true)
	floater(f, V(1.6, 0.8, 0.8), V(4, 10, 1400), Kit.Vivid(C(255, 150, 200)), "FloatingPill", Enum.PartType.Cylinder)
end

local function lab(f: Instance)
	-- ecto tanks along the west wall
	for i, z in { 1415, 1455, 1492 } do
		Kit.Cyl(f, 1.5, 6, CFrame.new(-105, FLOOR_Y + 0.75, z), GREY, { Mat = METAL, Solid = true })
		Kit.Cyl(f, 8, 5, CFrame.new(-105, 5.9, z), C(200, 245, 225), { Transp = 0.55, Refl = 0.1 })
		local liquid = Kit.Cyl(f, 6, 4, CFrame.new(-105, 5, z), SPECT, { Mat = NEON, Transp = 0.3 })
		Kit.Cyl(f, 1, 5.6, CFrame.new(-105, 10.4, z), GREY, { Mat = METAL })
		if i == 2 then
			Kit.Light(liquid, SPECT, 24, 1.2)
			Kit.Emitter(liquid, SPECT, 2, 2, 0.6)
		end
		Kit.AddCircle(-105, z, 4)
	end
	-- lab bench with bubbling beakers
	Kit.Box(f, V(-66, 3.4, 1400), V(-40, 4, 1405.5), WHITE)
	Kit.Box(f, V(-65, FLOOR_Y, 1400.5), V(-41, 3.4, 1405), Kit.Vivid(MGREEN), { Solid = true })
	for i, col in { C(255, 150, 200), C(200, 140, 255), C(140, 230, 255) } do
		Kit.Cyl(f, 1.6, 1, CFrame.new(-60 + i * 5, 4.8, 1402.5), Kit.Vivid(col), { Transp = 0.2 })
	end
	Kit.AddRect(-67, 1399, -39, 1407)
	-- spirit coil "ghost-o-meter"
	local x, z = -60, 1515
	Kit.Cyl(f, 1, 6, CFrame.new(x, FLOOR_Y + 0.5, z), GREY, { Mat = METAL, Solid = true })
	Kit.Cyl(f, 10, 1.6, CFrame.new(x, 6, z), GREY, { Mat = METAL, Solid = true })
	for i, d in { 5, 4, 3 } do
		Kit.Cyl(f, 0.5, d, CFrame.new(x, 3 + i * 2.5, z), Kit.Vivid(PURPLE))
	end
	Kit.Ball(f, 2.2, V(x, 12, z), C(200, 150, 255), { Mat = NEON })
	Props.SignBoard(f, V(x, 3, z - 4), 7, 1.6, 0, -1, "GHOST-O-METER", DARK, SPECT)
	Kit.AddCircle(x, z, 5)
	Props.SignBoard(f, V(-100, 11, 1399.4), 14, 3, 0, 1, "PARANORMAL LAB", C(120, 80, 190), WHITE)
	puddle(f, -70, 1462, 6)
	floater(f, V(1, 1.8, 1), V(-45, 9, 1420), Kit.Vivid(C(200, 140, 255)), "FloatingBeaker", Enum.PartType.Cylinder)
end

local function office(f: Instance)
	-- director's desk (front-east corner, outside the boss circle)
	Kit.Box(f, V(16.5, FLOOR_Y, 1454.5), V(27.5, 3.6, 1461.5), C(140, 95, 65), { Mat = WOOD, Solid = true })
	Kit.Box(f, V(16, 3.6, 1454), V(28, 4.2, 1462), C(165, 115, 80), { Mat = WOOD })
	local plate = Kit.Part(f, V(4.5, 1, 0.4), faced(V(22, 4.7, 1454.5), 0, -1), DARK)
	Kit.Sign(plate, Enum.NormalId.Front, "DIRECTOR 👻", C(255, 215, 120))
	chair(f, 22, 1465, 0, -1, Kit.Vivid(PURPLE))
	Kit.AddRect(15, 1453, 29, 1467)
	-- boss ring painted on the carpet (flat)
	Kit.Disc(f, 0, 1505, 0.18, 46, 0.04, Kit.Vivid(PURPLE))
	Kit.Disc(f, 0, 1505, 0.2, 42, 0.04, C(215, 195, 235))
	puddle(f, -6, 1500, 6)
	Props.SignBoard(f, V(-22, 10, 1532.6), 11, 6, 0, -1, "EMPLOYEE\nOF THE\nCENTURY 👻", C(120, 80, 190), C(255, 225, 130), C(255, 200, 80))
	plant(f, -27, 1449)
	plant(f, 27, 1530)
end

local function pharmacy(f: Instance)
	Kit.Box(f, V(50, FLOOR_Y, 1468), V(82, 4, 1471), WHITE, { Solid = true })
	Kit.Box(f, V(49.5, 4, 1467.5), V(82.5, 4.5, 1471.5), Kit.Vivid(MGREEN))
	Kit.AddRect(49, 1467, 83, 1472)
	local rows = { C(255, 150, 190), C(140, 220, 255), C(255, 210, 110) }
	for _, x in { 50, 70, 90 } do
		Kit.Box(f, V(x - 6, FLOOR_Y, 1529), V(x + 6, 10, 1533), WHITE, { Solid = true })
		for i, col in rows do
			local y = 1.2 + (i - 1) * 2.9
			Kit.Box(f, V(x - 5.6, y, 1528.7), V(x + 5.6, y + 1.8, 1529), Kit.Vivid(col))
		end
		Kit.AddRect(x - 7, 1527, x + 7, 1533)
	end
	Props.SignBoard(f, V(70, 13, 1532.6), 20, 3, 0, -1, "PHARMACY", C(60, 110, 170), WHITE)
	-- get-well balloons by the counter
	local top = V(80, 4.5, 1469.5)
	for i, col in { C(255, 140, 190), C(150, 205, 240), C(170, 120, 230) } do
		local p = top + V((i - 2) * 1.6, 7 + (i % 2) * 1.2, 0)
		Props.Beam(f, top, p - V(0, 1.3, 0), 0.1, 0.1, WHITE)
		Kit.Ball(f, 2.6, p, Kit.Vivid(col))
	end
	wheelchair(f, 100, 1480, -1, 0)
	Props.SignBoard(f, V(60, 11, 1445.4), 14, 3, 0, 1, "GET WELL BOO-N!", C(255, 140, 190), WHITE)
end

local function grounds(f: Instance)
	-- back yard
	bench(f, -42, 1546, 0, -1)
	bench(f, 42, 1546, 0, -1)
	-- trees in the garden strips and corners
	local rng = Kit.Rng
	local trees = 0
	for _ = 1, 200 do
		if trees >= 10 then
			break
		end
		local x = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(60, 131)
		local z = rng:NextNumber(1226, 1555)
		if Kit.IsFree(x, z, 5) then
			trees += 1
			Props.Tree(f, V(x, 0, z), rng:NextNumber(11, 16), Kit.Pick({ C(120, 190, 130), C(170, 120, 220), C(100, 170, 150) }))
		end
	end
end

function Hospital.Build(map: Instance)
	local f = Kit.Folder(map, "Hospital")
	ground(f)
	sideWalls(f)
	outside(f)
	courtyard(f)
	entrance(f)
	shell(f)
	tower(f)
	lobby(f)
	ward(f)
	patientRooms(f)
	xray(f)
	atrium(f)
	lab(f)
	office(f)
	pharmacy(f)
	grounds(f)
end

return Hospital
