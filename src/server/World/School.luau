--!strict
-- ZONE 3: Haunted School (Z 540..880).
--   Courtyard Z 540..600: path, Elite crate station (built by Stations), ghost bus, flagpole.
--   Building X -100..100, Z 600..860, walls 16 tall, NO roof over the interior (only rim
--   ledges and a few thin beams) so the camera and ghost taps work from above.
--     Front wall Z=600 with a 20-wide entrance under the clock tower (top ~Y 104).
--     Central hallway X -16..16, Z 601..761 (ghost areas at Z 640 and 700).
--     Library   X -99..-18, Z 601..648   | Cafeteria X 18..99, Z 601..648
--     Class 1-A X -99..-18, Z 650..761   | Class 1-B X 18..99, Z 650..761 (ghost areas at X ±62, Z 690)
--     Gym       X -99..99,  Z 763..859 (Headmaster area at Z 805), bleachers along the back wall
--               in two halves either side of the back exit.
--   Doorways: hallway→library/cafeteria 14 wide, hallway→classes 20 wide, library/cafeteria→class
--   14 wide, classes→gym 16 wide, hallway→gym 32 wide, gym→back exit 28 wide (X -14..14, Z 860,
--   12 tall under an "EXIT → CARNIVAL" sign), then a flat path to Gate_Carnival at Z 880.
--   The strips X 105..136 beside the building stay walkable from the courtyard to the back.
--   Palette: warm brick exterior, cream inner walls and trims, school-blue roofs/ledges, purple
--   spectral accents, green ectoplasm. Glow is kept to the front windows, sconces, desk lamps,
--   the bell, slime puddles, bus headlights and the jack-o'-lanterns along the path; bands,
--   rings, lines, frames, trims and side windows are painted.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local School = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local H = 16
local EXT = C(190, 98, 76) -- warm brick
local CREAM = C(245, 232, 205)
local BLUE = C(70, 112, 190) -- school blue
local TRIMC = C(70, 105, 185)
local WHITE = C(255, 250, 245)
local SOLID: Kit.Opts = { Solid = true, Shadow = true }
local BRICK: Kit.Opts = { Mat = Enum.Material.Brick, Solid = true, Shadow = true }

type Opening = { c: number, w: number, h: number? }

local function sortOpenings(list: { Opening })
	table.sort(list, function(a: Opening, b: Opening)
		return a.c < b.c
	end)
end

-- Wall along X at fixed z (thickness 2), from x1 to x2, with doorway openings.
local function wallX(parent: Instance, z: number, x1: number, x2: number, color: Color3, openings: { Opening }, opts: Kit.Opts?)
	local wo = opts or SOLID
	sortOpenings(openings)
	local cur = x1
	for _, o in openings do
		local a, b = o.c - o.w / 2, o.c + o.w / 2
		if a > cur then
			Kit.Box(parent, V(cur, 0, z - 1), V(a, H, z + 1), color, wo)
		end
		local oh = o.h
		if oh and oh < H then
			Kit.Box(parent, V(a, oh, z - 1), V(b, H, z + 1), color, wo)
		end
		cur = b
	end
	if x2 > cur then
		Kit.Box(parent, V(cur, 0, z - 1), V(x2, H, z + 1), color, wo)
	end
end

-- Wall along Z at fixed x (thickness 2), from z1 to z2, with doorway openings.
local function wallZ(parent: Instance, x: number, z1: number, z2: number, color: Color3, openings: { Opening }, opts: Kit.Opts?)
	local wo = opts or SOLID
	sortOpenings(openings)
	local cur = z1
	for _, o in openings do
		local a, b = o.c - o.w / 2, o.c + o.w / 2
		if a > cur then
			Kit.Box(parent, V(x - 1, 0, cur), V(x + 1, H, a), color, wo)
		end
		local oh = o.h
		if oh and oh < H then
			Kit.Box(parent, V(x - 1, oh, a), V(x + 1, H, b), color, wo)
		end
		cur = b
	end
	if z2 > cur then
		Kit.Box(parent, V(x - 1, 0, cur), V(x + 1, H, z2), color, wo)
	end
end

local function gable(parent: Instance, base: CFrame, length: number, depth: number, height: number, color: Color3)
	local half = depth / 2
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, -half / 2), color, SOLID)
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), color, SOLID)
end

local function faced(center: Vector3, fx: number, fz: number): CFrame
	return CFrame.new(center) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
end

local function sconce(parent: Instance, pos: Vector3, fx: number, color: Color3)
	-- wall lamp on a wall whose inner face is at pos.X - fx * 0.5
	local lamp = Kit.Part(parent, V(0.8, 1.8, 2.2), CFrame.new(pos), color, { Mat = NEON })
	Kit.Part(parent, V(0.5, 0.4, 2.8), CFrame.new(pos + V(-fx * 0.15, 1.1, 0)), C(60, 40, 90))
	Kit.Light(lamp, color, 24, 1.6, true)
end

--==================================================================
-- SHELL
--==================================================================
local function shell(f: Instance)
	-- floors (top Y 0.15)
	Kit.Box(f, V(-101, -0.5, 599), V(101, 0.1, 861), C(110, 90, 150), { Solid = true, Name = "SchoolFloor" })
	local tiles = { C(240, 230, 210), C(95, 135, 205) }
	for i = 0, 3 do
		for j = 0, 19 do
			local x0, z0 = -16 + i * 8, 601 + j * 8
			Kit.Box(f, V(x0, 0.05, z0), V(x0 + 8, 0.15, z0 + 8), tiles[((i + j) % 2) + 1], { Solid = true })
		end
	end
	Kit.Box(f, V(-99, 0.05, 601), V(-18, 0.15, 648), C(190, 130, 90), { Mat = Enum.Material.WoodPlanks, Solid = true })
	Kit.Box(f, V(18, 0.05, 601), V(99, 0.15, 648), C(255, 225, 175), { Solid = true })
	Kit.Box(f, V(-99, 0.05, 650), V(-18, 0.15, 761), C(215, 170, 120), { Mat = Enum.Material.WoodPlanks, Solid = true })
	Kit.Box(f, V(18, 0.05, 650), V(99, 0.15, 761), C(215, 170, 120), { Mat = Enum.Material.WoodPlanks, Solid = true })
	Kit.Box(f, V(-99, 0.05, 763), V(99, 0.15, 859), C(235, 160, 90), { Mat = Enum.Material.WoodPlanks, Solid = true, Name = "GymFloor" })

	-- exterior walls
	wallX(f, 600, -101, 101, EXT, { { c = 0, w = 20 } }, BRICK)
	-- back exit out of the gym toward Gate_Carnival (X -14..14, 12 tall)
	wallX(f, 860, -101, 101, EXT, { { c = 0, w = 28, h = 12 } }, BRICK)
	wallZ(f, -100, 601, 859, EXT, {}, BRICK)
	wallZ(f, 100, 601, 859, EXT, {}, BRICK)
	-- hallway walls
	local hall = CREAM
	wallZ(f, -17, 601, 761, hall, { { c = 624, w = 14, h = 12 }, { c = 690, w = 20, h = 13 } })
	wallZ(f, 17, 601, 761, hall, { { c = 624, w = 14, h = 12 }, { c = 690, w = 20, h = 13 } })
	-- front rooms / classrooms divider and the gym wall
	local inner = C(120, 160, 215)
	wallX(f, 649, -99, -18, inner, { { c = -60, w = 14, h = 12 } })
	wallX(f, 649, 18, 99, inner, { { c = 60, w = 14, h = 12 } })
	wallX(f, 762, -99, 99, C(235, 215, 180), { { c = 0, w = 32 }, { c = -60, w = 16, h = 13 }, { c = 60, w = 16, h = 13 } })

	-- parapet on the exterior walls + partial roof ledges (no roof over the interior)
	local rim: Kit.Opts = { Mat = Enum.Material.Concrete, Solid = true, Shadow = true }
	Kit.Box(f, V(-102, H, 598), V(102, H + 2, 602), CREAM, rim)
	Kit.Box(f, V(-102, H, 858), V(102, H + 2, 862), CREAM, rim)
	Kit.Box(f, V(-102, H, 598), V(-98, H + 2, 862), CREAM, rim)
	Kit.Box(f, V(98, H, 598), V(102, H + 2, 862), CREAM, rim)
	local ledge = BLUE
	Kit.Box(f, V(-98, H + 0.5, 602), V(98, H + 1.5, 607), ledge)
	Kit.Box(f, V(-98, H + 0.5, 853), V(98, H + 1.5, 858), ledge)
	Kit.Box(f, V(-98, H + 0.5, 602), V(-93, H + 1.5, 858), ledge)
	Kit.Box(f, V(93, H + 0.5, 602), V(98, H + 1.5, 858), ledge)
	-- sloped eaves on the outside
	local eave = C(55, 85, 150)
	local eaveOpts: Kit.Opts = { Mat = Enum.Material.Slate, Shadow = true }
	Kit.Wedge(f, V(208, 3, 4), faced(V(0, H + 0.5, 596), 0, -1), eave, eaveOpts)
	Kit.Wedge(f, V(208, 3, 4), faced(V(0, H + 0.5, 864), 0, 1), eave, eaveOpts)
	Kit.Wedge(f, V(268, 3, 4), faced(V(-104, H + 0.5, 730), -1, 0), eave, eaveOpts)
	Kit.Wedge(f, V(268, 3, 4), faced(V(104, H + 0.5, 730), 1, 0), eave, eaveOpts)
	-- painted band along the front
	Kit.Box(f, V(-101.2, 14, 598.7), V(101.2, 14.6, 598.9), Kit.Vivid(C(150, 255, 140)))

	-- corner turrets
	local turretRing, turretTop = Kit.Vivid(C(200, 130, 255)), Kit.Vivid(C(150, 255, 140))
	for _, x in { -100, 100 } do
		for _, z in { 600, 860 } do
			Kit.Cyl(f, 24, 10, CFrame.new(x, 12, z), EXT:Lerp(C(255, 255, 255), 0.08), BRICK)
			Kit.Cyl(f, 1, 10.6, CFrame.new(x, 14.3, z), turretRing)
			Kit.Cyl(f, 2, 11.5, CFrame.new(x, 25, z), CREAM, { Mat = Enum.Material.Concrete })
			Kit.Cyl(f, 3, 8, CFrame.new(x, 27.5, z), TRIMC, { Mat = Enum.Material.Slate })
			Kit.Cyl(f, 3, 4.5, CFrame.new(x, 30.5, z), TRIMC, { Mat = Enum.Material.Slate })
			Kit.Ball(f, 2.6, V(x, 33, z), turretTop)
		end
	end

	-- facade windows glow (ghostly); side windows are warm painted glass
	for _, x in { -88, -70, -50, -30, 30, 50, 70, 88 } do
		Kit.Box(f, V(x - 3, 4.5, 598.75), V(x + 3, 12.5, 599), WHITE)
		Kit.Box(f, V(x - 2.4, 5, 598.6), V(x + 2.4, 12, 598.85), Kit.Pick({ C(255, 230, 120), C(150, 255, 140), C(210, 150, 255) }), { Mat = NEON })
	end
	for _, s in { -1, 1 } do
		for _, z in { 625, 690, 735, 790, 830 } do
			Kit.Box(f, V(s * 101, 4.5, z - 3), V(s * 101.25, 12.5, z + 3), WHITE)
			Kit.Box(f, V(s * 101.15, 5, z - 2.4), V(s * 101.4, 12, z + 2.4), Kit.Vivid(Kit.Pick({ C(255, 225, 130), C(160, 235, 150), C(200, 160, 245) })), { Refl = 0.2 })
		end
	end
	-- entrance steps
	Kit.Box(f, V(-12, 0, 592), V(12, 0.5, 599), C(200, 190, 220), { Mat = Enum.Material.Slate, Solid = true })
end

--==================================================================
-- CLOCK TOWER (over the entrance)
--==================================================================
local function clockTower(f: Instance)
	local body = EXT:Lerp(C(0, 0, 0), 0.05)
	local mint, orange = Kit.Vivid(C(150, 255, 140)), Kit.Vivid(C(255, 160, 60))
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 10, 0, 594), V(s * 14, 22, 606), body, BRICK)
		Kit.Box(f, V(s * 9.8, 0, 593.8), V(s * 10.3, 22, 594.3), mint)
	end
	Kit.Box(f, V(-14, 22, 594), V(14, 62, 606), body, { Mat = Enum.Material.Brick, Solid = true, Shadow = true, Name = "ClockTower" })
	Kit.Box(f, V(-14.3, 22, 593.7), V(14.3, 23, 606.3), mint)
	Kit.Box(f, V(-14.3, 61, 593.7), V(14.3, 62, 606.3), orange)
	-- SPOOKY HIGH sign
	local sign = Kit.Part(f, V(26, 6, 0.6), CFrame.new(0, 26.5, 593.6), C(45, 25, 80))
	Kit.Part(f, V(27.5, 7.5, 0.3), CFrame.new(0, 26.5, 593.85), orange)
	Kit.Sign(sign, Enum.NormalId.Front, "SPOOKY HIGH", C(255, 200, 80))
	-- clock (11:55, almost midnight)
	Kit.CylFlat(f, 0.5, 17.5, V(0, 44, 593.75), "Z", Kit.Vivid(C(200, 120, 255)))
	Kit.CylFlat(f, 0.6, 16, V(0, 44, 593.4), "Z", C(255, 245, 225))
	local function hand(len: number, w: number, angle: number, z: number, color: Color3)
		Kit.Part(f, V(w, len, 0.25), CFrame.new(0, 44, z) * CFrame.Angles(0, 0, angle) * CFrame.new(0, len / 2, 0), color)
	end
	hand(5, 1, -0.05, 593.0, C(60, 30, 90))
	hand(7, 0.7, -0.52, 592.9, C(130, 60, 200))
	Kit.Ball(f, 1.2, V(0, 44, 592.9), orange)
	for i = 0, 3 do
		local a = i * math.pi / 2
		Kit.Part(f, V(0.8, 1.6, 0.3), CFrame.new(math.sin(a) * 6.5, 44 + math.cos(a) * 6.5, 593.0) * CFrame.Angles(0, 0, -a), C(130, 60, 200))
	end
	-- bell loft
	for _, x in { -12.5, 12.5 } do
		for _, z in { 595.5, 604.5 } do
			Kit.Box(f, V(x - 1.5, 62, z - 1.5), V(x + 1.5, 74, z + 1.5), CREAM, { Mat = Enum.Material.Concrete, Solid = true, Shadow = true })
		end
	end
	local bell = Kit.Ball(f, 7, V(0, 68, 600), C(255, 200, 70))
	Kit.Ball(f, 3, V(0, 64.8, 600), C(150, 255, 140), { Mat = NEON })
	Kit.Light(bell, C(170, 255, 160), 30, 1.4)
	Kit.Box(f, V(-15.5, 74, 592.5), V(15.5, 76, 607.5), TRIMC, SOLID)
	gable(f, CFrame.new(0, 76, 600), 31, 15, 14, C(55, 85, 150))
	Kit.Cyl(f, 12, 1.2, CFrame.new(0, 96, 600), C(240, 220, 120))
	Kit.Ball(f, 3.2, V(0, 103, 600), Kit.Vivid(C(200, 120, 255)))
end

--==================================================================
-- HALLWAY
--==================================================================
local function hallway(f: Instance)
	local lockerCols = { C(255, 120, 170), C(90, 210, 230), C(255, 210, 90), C(170, 120, 255) }
	local runs = { { 606, 616 }, { 632, 679 }, { 701, 760 } }
	local slimed = Kit.Vivid(C(140, 255, 150))
	local n = 0
	for _, s in { -1, 1 } do
		for _, r in runs do
			local z0 = r[1]
			while z0 + 3 <= r[2] do
				n += 1
				Kit.Box(f, V(s * 16, 0.15, z0), V(s * 14.5, 8.5, z0 + 3), lockerCols[(n % #lockerCols) + 1], { Mat = Enum.Material.Metal, Solid = true })
				if n % 7 == 0 then
					Kit.Box(f, V(s * 14.5, 1, z0 + 0.4), V(s * 14.35, 8, z0 + 2.6), slimed) -- slimed locker door
				end
				z0 += 3.2
			end
			Kit.Box(f, V(s * 16, 8.5, r[1]), V(s * 14.3, 9, r[2]), C(120, 70, 190))
		end
	end
	-- painted guide lines on the floor (flat)
	local guide = Kit.Vivid(C(200, 130, 255))
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 7 - 0.25, 0.15, 603), V(s * 7 + 0.25, 0.2, 760), guide)
	end
	-- thin beams overhead (Y 16..17.5), clear of the ghost areas' height
	for _, z in { 615, 670, 732, 758 } do
		Kit.Box(f, V(-18, H, z - 0.75), V(18, H + 1.5, z + 0.75), C(120, 80, 60), { Mat = Enum.Material.WoodPlanks })
	end
	local gymSign = Kit.Part(f, V(14, 3, 0.4), CFrame.new(0, 13.6, 758), C(45, 25, 80))
	Kit.Sign(gymSign, Enum.NormalId.Front, "🏀 GYM 🏀", C(255, 190, 80))
	for _, x in { -5, 5 } do
		Kit.Box(f, V(x - 0.1, 15.1, 757.9), V(x + 0.1, H, 758.1), C(60, 50, 70))
	end
	-- flickering sconces
	for _, z in { 612, 668, 722 } do
		sconce(f, V(-15.6, 12.4, z), 1, C(255, 230, 140))
	end
	for _, z in { 640, 712, 750 } do
		sconce(f, V(15.6, 12.4, z), -1, C(200, 150, 255))
	end
	-- door signs
	Props.SignBoard(f, V(-15.6, 14, 624), 12, 2.8, 1, 0, "📚 LIBRARY", C(45, 25, 80), C(255, 220, 120))
	Props.SignBoard(f, V(15.6, 14, 624), 12, 2.8, -1, 0, "🍕 CAFETERIA", C(45, 25, 80), C(150, 255, 140))
	Props.SignBoard(f, V(-15.6, 14.5, 690), 14, 2.6, 1, 0, "CLASS 1-A", C(45, 25, 80), C(255, 170, 220))
	Props.SignBoard(f, V(15.6, 14.5, 690), 14, 2.6, -1, 0, "CLASS 1-B", C(45, 25, 80), C(120, 220, 255))
	-- ghostly graffiti
	Props.Graffiti(f, V(-15.9, 12.3, 650), 10, 5, 1, 0, "BOO!", C(150, 255, 140), -6)
	Props.Graffiti(f, V(15.9, 12.3, 655), 14, 5, -1, 0, "NO RUNNING\n(FLOATING OK)", C(255, 150, 220), 4)
	Props.Graffiti(f, V(-15.9, 12.3, 740), 14, 5, 1, 0, "GHOSTS RULE", C(200, 140, 255), -3)
	Props.Graffiti(f, V(15.9, 12.3, 728), 12, 5, -1, 0, "HALL PASS?\nNAH.", C(120, 230, 255), 5)
	-- slime puddles (flat)
	local slime = Kit.Disc(f, -4, 662, 0.22, 6, 0.08, C(130, 255, 140), { Mat = NEON, Transp = 0.2 })
	Kit.Emitter(slime, C(150, 255, 160), 1.5, 3, 0.4)
	Kit.Disc(f, 6, 721, 0.22, 4, 0.08, C(130, 255, 140), { Mat = NEON, Transp = 0.2 })
end

--==================================================================
-- LIBRARY + CAFETERIA
--==================================================================
local function shelf(f: Instance, a: Vector3, b: Vector3, faceAxis: string, faceSign: number)
	Kit.Box(f, a, b, C(120, 75, 55), { Mat = Enum.Material.WoodPlanks, Solid = true })
	local lo, hi = a:Min(b), a:Max(b)
	for i = 0, 2 do
		local y = 1.4 + i * 3.1
		local col = Kit.Pick(Props.Colors.Book)
		if faceAxis == "X" then
			local x = if faceSign > 0 then hi.X else lo.X
			Kit.Box(f, V(x, y, lo.Z + 0.4), V(x + faceSign * 0.3, y + 2.3, hi.Z - 0.4), col)
		else
			local z = if faceSign > 0 then hi.Z else lo.Z
			Kit.Box(f, V(lo.X + 0.4, y, z), V(hi.X - 0.4, y + 2.3, z + faceSign * 0.3), col)
		end
	end
end

local function library(f: Instance)
	for z = 607, 638, 8.5 do
		shelf(f, V(-99, 0.15, z), V(-96, 11, z + 8), "X", 1)
	end
	for x = -93, -30, 9 do
		shelf(f, V(x, 0.15, 601), V(x + 8, 11, 604), "Z", 1)
	end
	for _, x in { -70, -45 } do
		Kit.Box(f, V(x - 6, 3, 621), V(x + 6, 3.6, 631), C(150, 95, 60), { Mat = Enum.Material.WoodPlanks, Solid = true })
		Kit.Box(f, V(x - 1, 0.15, 624), V(x + 1, 3, 628), C(110, 70, 50))
		Kit.Cyl(f, 1.6, 0.3, CFrame.new(x + 3, 4.4, 626), C(70, 60, 80))
		Kit.Ball(f, 1.3, V(x + 3, 5.4, 626), C(150, 255, 140), { Mat = NEON })
	end
	local rng = Kit.Rng
	for _ = 1, 7 do
		Props.FloatingBook(f, V(rng:NextNumber(-90, -26), rng:NextNumber(6, 11), rng:NextNumber(608, 644)))
	end
	Props.Graffiti(f, V(-82, 11, 647.9), 16, 5, 0, -1, "SHHH!\nGHOSTS READING", C(150, 255, 140), -3)
end

local function cafeteria(f: Instance)
	-- counter + sneeze guard + menu
	Kit.Box(f, V(90, 0.15, 607), V(96, 4, 643), C(205, 205, 225), { Solid = true })
	local pans = { C(130, 255, 140), C(255, 160, 60), C(200, 120, 255), C(255, 110, 140) }
	for i = 0, 3 do
		Kit.Box(f, V(91, 4, 609 + i * 8.5), V(95, 4.5, 615 + i * 8.5), Kit.Vivid(pans[i + 1]))
	end
	Kit.Box(f, V(89.8, 4, 607), V(90.2, 7, 643), C(200, 240, 255), { Transp = 0.6 })
	local menuCF = faced(V(98.7, 11, 625), -1, 0)
	local menu = Kit.Part(f, V(26, 6, 0.4), menuCF, C(40, 30, 60))
	Kit.Part(f, V(27, 7, 0.2), menuCF * CFrame.new(0, 0, 0.3), Kit.Vivid(C(255, 160, 60)))
	Kit.Sign(menu, Enum.NormalId.Front, "TODAY: ECTO-LOAF\n& SCREAM PIE", C(150, 255, 140))
	-- long tables with benches and trays
	local trays = { C(255, 120, 170), C(90, 210, 230), C(255, 210, 90), C(170, 120, 255) }
	for _, x in { 35, 55, 75 } do
		Kit.Box(f, V(x - 2.5, 3, 610), V(x + 2.5, 3.6, 640), C(240, 240, 250), { Solid = true })
		Kit.Box(f, V(x - 0.5, 0.15, 612), V(x + 0.5, 3, 638), C(130, 130, 160))
		for _, s in { -1, 1 } do
			Kit.Box(f, V(x + s * 3.6, 0.15, 611), V(x + s * 5, 2, 639), C(170, 110, 230), { Solid = true })
		end
		for i = 0, 3 do
			local s = if i % 2 == 0 then -1 else 1
			local tz = 614 + i * 7
			Kit.Box(f, V(x + s * 0.3, 3.6, tz - 0.8), V(x + s * 2.2, 3.85, tz + 0.8), trays[i + 1])
			Kit.Ball(f, 0.9, V(x + s * 1.25, 4.2, tz), Kit.Vivid(Kit.Pick(pans)))
		end
	end
	Props.Graffiti(f, V(35, 11, 647.9), 16, 5, 0, -1, "FOOD FIGHT\nAT MIDNIGHT", C(255, 170, 220), 4)
	Props.FloatingPumpkin(f, V(45, 10, 628))
end

--==================================================================
-- CLASSROOMS
--==================================================================
local function classroom(f: Instance, side: number, title: string, graffiti: string)
	-- side = -1 (west, Class 1-A) or +1 (east, Class 1-B); board on the outer wall
	local gx, gz, gr = side * 62, 690, 20
	local boardCF = faced(V(side * 98.7, 8.5, 705), -side, 0)
	local board = Kit.Part(f, V(30, 8, 0.4), boardCF, C(40, 95, 75))
	Kit.Part(f, V(31.6, 9.6, 0.3), boardCF * CFrame.new(0, 0, 0.3), C(150, 100, 60), { Mat = Enum.Material.WoodPlanks })
	Kit.Sign(board, Enum.NormalId.Front, title, C(235, 255, 235), { Stroke = C(30, 70, 55), Font = Enum.Font.FredokaOne })
	-- teacher's desk + apple
	local tx = side * 90.5
	Kit.Box(f, V(tx - 2.5, 0.15, 698), V(tx + 2.5, 3.6, 710), C(150, 95, 60), { Mat = Enum.Material.WoodPlanks, Solid = true })
	Kit.Ball(f, 1.2, V(tx, 4.2, 702), C(255, 70, 80))
	-- student desks (facing the board), kept out of the ghost circle and doorways
	local desk, chair = C(255, 210, 120), C(130, 90, 220)
	for ax = 91, 31, -12 do
		local x = side * ax
		for z = 656, 752, 12 do
			local dx, dz = x - gx, z - gz
			local inCircle = dx * dx + dz * dz < (gr + 4) * (gr + 4)
			local teacher = ax >= 85 and z >= 690 and z <= 716
			local gymDoor = z >= 736 and math.abs(ax - 60) < 9
			local divDoor = z <= 660 and math.abs(ax - 60) < 9
			local hallDoor = ax <= 31 and z >= 672 and z <= 708
			if not (inCircle or teacher or gymDoor or divDoor or hallDoor) then
				local back = side -- chairs sit on the side away from the board
				Kit.Box(f, V(x - 1.5, 3, z - 1.4), V(x + 1.5, 3.4, z + 1.4), desk, { Solid = true })
				Kit.Box(f, V(x + side * 1.5, 0.15, z - 1.2), V(x + side * 1.1, 3, z + 1.2), desk:Lerp(C(0, 0, 0), 0.2))
				Kit.Box(f, V(x - back * 2, 1.8, z - 1.1), V(x - back * 4.2, 2.1, z + 1.1), chair)
				Kit.Box(f, V(x - back * 4, 0.15, z - 1.1), V(x - back * 4.3, 4.4, z + 1.1), chair)
			end
		end
	end
	-- floating books near the back of the room
	local rng = Kit.Rng
	for i = 0, 3 do
		Props.FloatingBook(f, V(side * (36 + i * 14), rng:NextNumber(9, 12), 745 + rng:NextNumber(-4, 6)))
	end
	sconce(f, V(side * 98.4, 12.4, 740), -side, C(150, 255, 160))
	Props.Graffiti(f, V(side * 85, 11, 760.9), 18, 5, 0, -1, graffiti, C(200, 140, 255), side * 4)
	Kit.Disc(f, side * 40, 735, 0.22, 5, 0.08, C(200, 130, 255), { Mat = NEON, Transp = 0.2 })
end

--==================================================================
-- GYM
--==================================================================
local function gym(f: Instance)
	-- court lines (white paint) and the purple centre circle
	local line = C(255, 250, 240)
	Kit.Box(f, V(-0.3, 0.15, 765), V(0.3, 0.2, 857), line)
	for _, x in { -92, 92 } do
		Kit.Box(f, V(x - 0.3, 0.15, 768), V(x + 0.3, 0.2, 840), line)
	end
	for _, z in { 768, 840 } do
		Kit.Box(f, V(-92, 0.15, z - 0.3), V(92, 0.2, z + 0.3), line)
	end
	local circle = Kit.Vivid(C(200, 130, 255))
	for i = 0, 15 do
		local a = (i + 0.5) / 16 * math.pi * 2
		local p = V(math.cos(a) * 10, 0.17, 805 + math.sin(a) * 10)
		Kit.Part(f, V(0.6, 0.06, 4.4), CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), circle)
	end
	-- hoops on the side walls
	local hoop = Kit.Vivid(C(255, 120, 60))
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 97.4, 9.5, 800.5), V(s * 97.9, 14.5, 809.5), WHITE)
		Kit.Box(f, V(s * 97.3, 10.6, 803.5), V(s * 97.4, 13, 806.5), hoop)
		Kit.Box(f, V(s * 97.9, 11.4, 804.6), V(s * 99, 12.2, 805.4), C(80, 80, 100))
		Kit.Disc(f, s * 95.4, 805, 10.3, 3.6, 0.3, hoop)
		Kit.Cyl(f, 2, 3.2, CFrame.new(s * 95.4, 9.1, 805), WHITE, { Transp = 0.5 })
	end
	-- bleachers along the back wall, split either side of the back exit (X -15..15 open)
	local cols = { C(95, 135, 205), C(235, 150, 70), C(240, 225, 195), C(150, 100, 220) }
	for i = 0, 3 do
		for _, s in { -1, 1 } do
			-- rows overlap (each reaches the back): inset hidden faces per row against z-fighting
			local d = i * 0.03
			Kit.Box(f, V(s * (15 + d), 0.15 + d, 842 + i * 4), V(s * (60 - d), 1.6 * (i + 1) + 0.15, 859 - d), cols[i + 1], { Mat = Enum.Material.WoodPlanks, Solid = true, Shadow = true })
		end
	end
	for k, px in { -50, -36, -22, 22, 36, 50 } do
		local i = (k - 1) % 4
		Props.Pumpkin(f, V(px, 1.6 * (i + 1) + 0.15, 844 + i * 4), 2.6, 0, -1)
	end
	-- back exit: cream door frame, EXIT sign on the lintel, path to Gate_Carnival
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 14 - 0.6, 0, 858.6), V(s * 14 + 0.6, 12.6, 861.4), CREAM, { Mat = Enum.Material.Concrete })
	end
	Kit.Box(f, V(-14.6, 12, 858.6), V(14.6, 12.6, 861.4), CREAM, { Mat = Enum.Material.Concrete })
	local exitSign = Kit.Part(f, V(24, 3, 0.4), CFrame.new(0, 14.2, 858.7), C(30, 60, 45))
	Kit.Part(f, V(25, 3.6, 0.2), CFrame.new(0, 14.2, 858.95), Kit.Vivid(C(150, 255, 140)))
	Kit.Sign(exitSign, Enum.NormalId.Front, "EXIT → CARNIVAL 🎡", C(170, 255, 160), { Stroke = C(20, 50, 30) })
	local backSign = Kit.Part(f, V(24, 3, 0.4), CFrame.new(0, 14.2, 861.3) * CFrame.Angles(0, math.pi, 0), C(30, 60, 45))
	Kit.Sign(backSign, Enum.NormalId.Front, "SPOOKY HIGH 🏫", C(255, 220, 120), { Stroke = C(20, 50, 30) })
	Kit.Box(f, V(-12, 0, 861), V(12, 0.05, 877), C(175, 165, 190), { Mat = Enum.Material.Cobblestone, Solid = true, Name = "ExitPath" })
	local guide = Kit.Vivid(C(150, 255, 140))
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 12 - 0.3, 0.05, 862), V(s * 12 + 0.3, 0.1, 876), guide)
	end
	Props.Pumpkin(f, V(-15.5, 0, 865), 2.6, 1, 0)
	Props.Pumpkin(f, V(15.5, 0, 865), 2.6, -1, 0)
	-- scoreboard (on the back wall over the west bleachers)
	local sbCF = CFrame.new(-40, 12.5, 858.5)
	local sb = Kit.Part(f, V(26, 6, 0.6), sbCF, C(30, 20, 50))
	Kit.Part(f, V(27.4, 7.4, 0.3), sbCF * CFrame.new(0, 0, 0.35), Kit.Vivid(C(150, 255, 140)))
	Kit.Sign(sb, Enum.NormalId.Front, "HOME 0  •  GHOSTS 999", C(255, 210, 80), { Font = Enum.Font.GothamBlack })
	-- banners
	Props.SignBoard(f, V(-98.6, 10, 780), 14, 5, 1, 0, "GO GHOULS!", C(130, 70, 220), C(255, 220, 90))
	Props.SignBoard(f, V(-98.6, 10, 830), 14, 5, 1, 0, "TEAM SPIRIT\n(LITERALLY)", C(255, 120, 60), WHITE)
	Props.SignBoard(f, V(98.6, 10, 780), 14, 5, -1, 0, "SPIRIT WEEK", C(60, 170, 150), WHITE)
	Props.SignBoard(f, V(98.6, 10, 830), 14, 5, -1, 0, "BOO CREW", C(220, 70, 140), C(255, 230, 120))
	Props.Graffiti(f, V(-80, 11, 763.1), 18, 5, 0, 1, "DETENTION\nFOREVER", C(150, 255, 140), -4)
	sconce(f, V(-98.4, 13.5, 792), 1, C(255, 200, 120))
	sconce(f, V(98.4, 13.5, 818), -1, C(255, 200, 120))
	Props.FloatingPumpkin(f, V(-30, 13, 850))
	Props.FloatingPumpkin(f, V(30, 13, 850))
end

--==================================================================
-- COURTYARD
--==================================================================
local function courtyard(f: Instance)
	Kit.Box(f, V(-10, -0.4, 540), V(10, 0.1, 592), C(190, 175, 215), { Mat = Enum.Material.Cobblestone, Solid = true })
	Kit.AddRect(-12, 540, 12, 600, true)
	Kit.AddRect(-104, 592, 104, 864)
	Kit.AddRect(-18, 860, 18, 880, true) -- back exit path to Gate_Carnival
	-- ghost bus
	local yellow = C(255, 205, 50)
	Kit.Box(f, V(55, 1.5, 566), V(85, 10.5, 578), yellow, SOLID)
	Kit.Box(f, V(55.5, 10.5, 566.5), V(84.5, 11.3, 577.5), C(255, 225, 120))
	Kit.Box(f, V(54.9, 5.5, 565.9), V(85.1, 6.1, 578.1), C(40, 30, 50))
	-- windows: warm pale yellow sides, glassy windshield (solid; too long to glow nicely)
	for _, z in { 565.8, 578.0 } do
		Kit.Box(f, V(58, 6.8, z), V(82, 9.6, z + 0.2), C(255, 240, 160), { Refl = 0.15 })
	end
	Kit.Box(f, V(54.8, 6.5, 567), V(55, 9.8, 577), Kit.Vivid(C(170, 230, 255)), { Transp = 0.2, Refl = 0.25 })
	for _, x in { 60, 80 } do
		for _, z in { 565.6, 578.4 } do
			Kit.CylFlat(f, 1.4, 4, V(x, 2, z), "Z", C(40, 35, 55))
		end
	end
	for _, z in { 568, 576 } do
		Kit.Box(f, V(54.7, 3, z - 0.8), V(54.9, 4.2, z + 0.8), C(255, 250, 200), { Mat = NEON })
	end
	local busSign = Kit.Box(f, V(62, 2.2, 565.6), V(78, 5.2, 565.9), yellow)
	Kit.Sign(busSign, Enum.NormalId.Front, "SPOOKY HIGH 👻", C(60, 30, 90), { Stroke = C(255, 255, 255) })
	Kit.AddCircle(70, 572, 17)
	-- flagpole
	Kit.Cyl(f, 26, 0.6, CFrame.new(28, 13, 590), C(220, 220, 235))
	Kit.Ball(f, 1.2, V(28, 26.4, 590), C(255, 210, 80), { Refl = 0.3 })
	local flag = Kit.Box(f, V(28.3, 20, 589.9), V(37, 25, 590.1), C(150, 80, 230))
	Kit.Sign(flag, Enum.NormalId.Front, "👻", WHITE)
	Kit.AddCircle(28, 590, 2)
	-- jack-o'-lanterns lining the path
	for z = 548, 590, 14 do
		for _, s in { -1, 1 } do
			Props.Pumpkin(f, V(s * 12.5, 0, z), 2.8, -s, 0, true)
		end
	end
	-- trees (courtyard and the strips around the building)
	local rng = Kit.Rng
	local trees = 0
	for _ = 1, 200 do
		if trees >= 14 then
			break
		end
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(546, 874)
		if Kit.IsFree(x, z, 5) then
			trees += 1
			Props.Tree(f, V(x, 0, z), rng:NextNumber(11, 16), Kit.Pick({ C(255, 140, 50), C(170, 90, 230), C(255, 110, 90) }))
		end
	end
	local lampGlobe = C(210, 150, 255)
	Props.StreetLamp(f, V(-15, 0, 594), lampGlobe, true)
	Props.StreetLamp(f, V(15, 0, 594), lampGlobe, false)
end

function School.Build(map: Instance)
	local f = Kit.Folder(map, "School")
	courtyard(f)
	shell(f)
	clockTower(f)
	hallway(f)
	library(f)
	cafeteria(f)
	classroom(f, -1, "GHOST 101\nBOO = HELLO 👋", "NO HOMEWORK\nONLY HAUNTWORK")
	classroom(f, 1, "BOO-OLOGY\nCHAPTER 13 🕸️", "A+ IN\nSCARING")
	gym(f)
end

return School
