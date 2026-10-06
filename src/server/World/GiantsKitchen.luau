--!strict
-- ZONE 28: Giant's Kitchen (Z 10960..11320). The player is a few centimetres tall on a giant's
-- kitchen countertop. Scale is about 5 studs per real inch, kept the same for every prop.
--   Ground: cream marble counter tiles (24-stud checker with grout lines, top Y 0); the lane
--   along X = 0 is a row of wooden cutting boards (top Y 0.25).
--   Ghost areas get flat tableware: a dinner plate (0,11045) r30, a woven placemat (-82,11080)
--   r24, a lace doily (75,11140) r26 and a spilled-milk puddle (-62,11200) r24; the boss area
--   (0,11265) r26 is a red-and-white checkered tablecloth.
--   Left edge (X -150..-140): the tiled backsplash wall up to Y 96 with a mouse hole, a power
--   outlet and a utensil rail; the upper cabinets overhang it (Y 96..200).
--   Right edge (X 140..146): the counter's wooden lip. Beyond it, standing on the kitchen floor
--   far below (Y -180): the giant fridge (Z 10966..11096, top Y 170) and the stove (hob level
--   with the counter) with a soup pot, a kettle and the range hood.
--   Props: chocolate-chip cookie, teacup on a saucer, a spoon bridge on sugar-cube stacks across
--   the lane (Y 12, climbable from the left), cereal boxes with spilled cereal, a milk carton,
--   a cheese wedge, a donut, a strawberry, salt and pepper shakers, a butter dish, a rolling
--   pin, sugar cubes and crumbs, and soap bubbles drifting above.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local GiantsKitchen = {}

local C = Color3.fromRGB
local V = Vector3.new
local MARBLE = Enum.Material.Marble
local WOOD = Enum.Material.Wood
local METAL = Enum.Material.Metal
local TILES = Enum.Material.CeramicTiles
local CARD = Enum.Material.Cardboard
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local Z0, Z1 = 10960, 11320

local COUNTER = C(238, 230, 216)
local TILE2 = C(222, 210, 192)
local GROUT = C(196, 184, 166)
local WOODC = C(200, 152, 100)
local WOOD_L = C(214, 170, 118)
local WOOD_D = C(140, 96, 60)
local SPLASH = C(120, 196, 200)
local SPLASH_G = C(225, 235, 232)
local CHROME = C(205, 210, 218)
local WHITE = C(250, 249, 245)
local BLUE = C(70, 125, 205)
local RED = C(220, 60, 60)
local COOKIE = C(212, 158, 92)
local COOKIE_L = C(226, 178, 112)
local CHOC = C(82, 48, 28)
local CHEESE = C(255, 208, 72)
local CHEESE_D = C(222, 168, 46)
local TEA = C(150, 85, 40)
local CRUMB = C(190, 135, 75)
local DARK = C(40, 34, 32)
local CAB = C(170, 205, 185)

local CHROME_O: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

local rng = Random.new(2828)

--==================================================================
-- GROUND
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-146, -4, Z0), V(146, 0, Z1), COUNTER, { Mat = MARBLE, Solid = true, Name = "Ground_GiantsKitchen" })
	-- 24-stud marble tiles: every other tile a shade darker, grout lines between them
	local T = 24
	for ix = 0, 11 do
		local x0 = -144 + ix * T
		for iz = 0, 14 do
			local z0 = Z0 + iz * T
			if (ix + iz) % 2 == 0 then
				Kit.Box(f, V(x0 + 0.3, 0, z0 + 0.3), V(x0 + T - 0.3, 0.02, z0 + T - 0.3), TILE2, { Mat = MARBLE })
			end
		end
	end
	for ix = 0, 12 do
		local x = -144 + ix * T
		Kit.Box(f, V(x - 0.2, 0, Z0), V(x + 0.2, 0.015, Z1), GROUT)
	end
	for iz = 1, 14 do
		local z = Z0 + iz * T
		Kit.Box(f, V(-146, 0, z - 0.2), V(146, 0.015, z + 0.2), GROUT)
	end
	-- the lane: wooden cutting boards end to end (they stop at the plate and the tablecloth)
	local boards = { { Z0, Z0 + 53 }, { Z0 + 117, Z0 + 196 }, { Z0 + 198, Z0 + 272 }, { Z0 + 338, Z1 } }
	for i, b in boards do
		Kit.Box(f, V(-8, 0, b[1]), V(8, 0.25, b[2]), if i % 2 == 0 then WOOD_L else WOODC, { Mat = WOOD, Solid = true, Name = "Path" })
		for _, gx in { -5.5, -1.5, 2.5, 5.8 } do
			Kit.Box(f, V(gx - 0.12, 0.25, b[1] + 1), V(gx + 0.12, 0.27, b[2] - 1), WOOD_D, { Mat = WOOD })
		end
		-- hanging hole near one end of each board
		if b[2] - b[1] > 60 then
			Kit.Disc(f, 0, b[1] + 4, 0.28, 3, 0.04, WOOD_D)
		end
	end
end

local function areaMarks(f: Instance)
	-- 1: dinner plate with a blue band and a few flat crumbs
	do
		local a = AREAS[1]
		local x, z = a[1], a[2]
		Kit.Disc(f, x, z, 0.2, 64, 0.2, WHITE, { Mat = SMOOTH, Solid = true, Name = "Plate" })
		Kit.Disc(f, x, z, 0.23, 60, 0.03, BLUE, { Mat = SMOOTH })
		Kit.Disc(f, x, z, 0.26, 56, 0.03, WHITE, { Mat = SMOOTH })
		Kit.Disc(f, x, z, 0.28, 42, 0.02, C(240, 240, 238), { Mat = SMOOTH, Refl = 0.05 })
		for k = 1, 9 do
			local ang = k * 0.9
			local r = 8 + (k % 3) * 5
			Kit.Disc(f, x + math.cos(ang) * r, z + math.sin(ang) * r, 0.29, rng:NextNumber(0.8, 1.8), 0.01, CRUMB)
		end
	end
	-- 2: woven straw placemat (concentric rings)
	do
		local a = AREAS[2]
		for k = 0, 5 do
			Kit.Disc(f, a[1], a[2], 0.08 + k * 0.03, 50 - k * 8, 0.04, if k % 2 == 0 then C(214, 178, 118) else C(190, 150, 92), { Mat = FABRIC })
		end
	end
	-- 3: lace doily: scalloped edge, ring of holes, pink centre rose
	do
		local a = AREAS[3]
		local x, z = a[1], a[2]
		Kit.Disc(f, x, z, 0.1, 52, 0.1, WHITE, { Mat = FABRIC })
		for k = 0, 17 do
			local ang = k * math.pi * 2 / 18
			Kit.Disc(f, x + math.cos(ang) * 26, z + math.sin(ang) * 26, 0.1, 7, 0.1, WHITE, { Mat = FABRIC })
		end
		for k = 0, 11 do
			local ang = k * math.pi * 2 / 12 + 0.2
			Kit.Disc(f, x + math.cos(ang) * 18, z + math.sin(ang) * 18, 0.13, 4, 0.03, TILE2)
		end
		Kit.Disc(f, x, z, 0.14, 14, 0.04, C(245, 170, 190), { Mat = FABRIC })
		Kit.Disc(f, x, z, 0.17, 7, 0.03, C(230, 120, 150), { Mat = FABRIC })
	end
	-- 4: spilled milk puddle (overlapping glossy blobs)
	do
		local a = AREAS[4]
		local blobs = { { 0, 0, 30 }, { -10, 8, 18 }, { 9, -9, 20 }, { 14, 7, 12 }, { -12, -11, 14 }, { 4, 14, 12 }, { 20, -2, 9 } }
		for i, b in blobs do
			Kit.Disc(f, a[1] + b[1], a[2] + b[2], 0.06 + i * 0.01, b[3], 0.06, C(252, 252, 250), { Mat = SMOOTH, Refl = 0.08 })
		end
	end
	-- boss: red-and-white checkered tablecloth (64 x 64, 8-stud squares)
	do
		local s = 64
		local x0, z0 = -s / 2, BOSS_Z - s / 2
		Kit.Box(f, V(x0, 0, z0), V(x0 + s, 0.2, z0 + s), WHITE, { Mat = FABRIC, Solid = true, Name = "Tablecloth" })
		for i = 0, 7 do
			for j = 0, 7 do
				if (i + j) % 2 == 0 then
					Kit.Box(f, V(x0 + i * 8, 0.2, z0 + j * 8), V(x0 + i * 8 + 8, 0.24, z0 + j * 8 + 8), RED, { Mat = FABRIC })
				end
			end
		end
		-- fringe along the two long sides
		for _, sx in { -1, 1 } do
			for k = 0, 15 do
				local zz = z0 + 2 + k * 4
				Kit.Box(f, V(sx * (s / 2) + (if sx > 0 then 0 else -1.6), 0, zz - 0.4), V(sx * (s / 2) + (if sx > 0 then 1.6 else 0), 0.1, zz + 0.4), WHITE, { Mat = FABRIC })
			end
		end
	end
end

--==================================================================
-- EDGES: BACKSPLASH (LEFT), COUNTER LIP + FRIDGE + STOVE (RIGHT)
--==================================================================
local function backsplash(f: Instance)
	local m = Kit.Model(f, "Backsplash")
	Kit.Box(m, V(-152, -0.5, Z0 + 1), V(-140, 96, Z1 - 1), SPLASH, { Mat = TILES, Solid = true, Shadow = true })
	-- big tile grout lines on the face
	for y = 12, 84, 12 do
		Kit.Box(m, V(-140.1, y - 0.25, Z0 + 1), V(-139.9, y + 0.25, Z1 - 1), SPLASH_G)
	end
	for z = Z0 + 24, Z1 - 12, 24 do
		Kit.Box(m, V(-140.1, 0, z - 0.25), V(-139.9, 96, z + 0.25), SPLASH_G)
	end
	-- upper cabinets with doors, knobs and a warm strip light underneath
	Kit.Box(m, V(-152, 96, Z0 + 1), V(-112, 200, Z1 - 1), CAB, { Mat = WOOD, Shadow = true })
	local doorW = (Z1 - Z0 - 2) / 6
	for k = 0, 5 do
		local za = Z0 + 1 + k * doorW
		Kit.Box(m, V(-112, 100, za + 1.5), V(-111.2, 196, za + doorW - 1.5), C(190, 222, 202), { Mat = WOOD })
		local kz = if k % 2 == 0 then za + doorW - 6 else za + 6
		Kit.Ball(m, 3, V(-110.6, 104, kz), CHROME, CHROME_O)
	end
	Kit.Box(m, V(-150, 95.2, Z0 + 4), V(-114, 96, Z1 - 4), C(130, 160, 145), { Mat = WOOD })
	for _, z in { Z0 + 100, Z0 + 260 } do
		local strip = Kit.Box(m, V(-136, 94.8, z - 30), V(-130, 95.2, z + 30), C(255, 236, 190), { Mat = SMOOTH })
		Kit.Light(strip, C(255, 225, 170), 60, 0.7)
	end
	-- mouse hole at the foot of the wall: a dark arch in a wooden frame, a doormat and a sign
	local hz = Z0 + 62
	Kit.CylFlat(m, 0.2, 20, V(-139.9, 0, hz), "X", WOOD_D, { Mat = WOOD })
	Kit.CylFlat(m, 0.4, 16, V(-139.8, 0, hz), "X", C(25, 18, 16))
	Kit.Box(m, V(-139, 0, hz - 3.5), V(-134, 0.08, hz + 3.5), C(200, 70, 60), { Mat = FABRIC })
	local sign = Kit.Part(m, V(0.3, 2.4, 9), CFrame.new(-139.7, 12.5, hz), WOOD_L, { Mat = WOOD, Name = "SignBoard" })
	Kit.Sign(sign, Enum.NormalId.Right, "HOME SWEET HOLE", C(120, 70, 40), { Stroke = C(255, 240, 210) })
	Kit.Box(m, V(-137, 0, hz + 5), V(-135.6, 1.2, hz + 6.6), CHEESE)
	Kit.AddRect(-140, hz - 10, -132, hz + 10)
	-- power outlet
	local oz = Z0 + 118
	Kit.Box(m, V(-140.4, 26, oz - 8), V(-139.4, 50, oz + 8), WHITE, { Mat = SMOOTH })
	for _, y in { 32, 44 } do
		for _, dz in { -2.2, 2.2 } do
			Kit.Box(m, V(-139.5, y - 0.6, oz + dz - 0.35), V(-139.2, y + 2.2, oz + dz + 0.35), DARK)
		end
		Kit.CylFlat(m, 0.3, 1.4, V(-139.35, y - 2, oz), "X", DARK)
	end
	-- utensil rail with a ladle, spatula, fork and slotted spoon hanging from it
	local railY = 66
	Kit.CylFlat(m, 140, 1.4, V(-137.4, railY, Z0 + 230), "Z", CHROME, CHROME_O)
	for _, z in { Z0 + 162, Z0 + 298 } do
		Kit.Box(m, V(-140, railY - 0.6, z - 0.6), V(-137.4, railY + 0.6, z + 0.6), CHROME, CHROME_O)
	end
	local utensils: { { z: number, kind: string, col: Color3 } } = {
		{ z = Z0 + 185, kind = "ladle", col = C(230, 90, 70) },
		{ z = Z0 + 215, kind = "spatula", col = C(80, 160, 210) },
		{ z = Z0 + 245, kind = "fork", col = CHROME },
		{ z = Z0 + 275, kind = "spoon", col = C(250, 200, 70) },
	}
	for _, u in utensils do
		local x, z = -136.6, u.z
		Kit.CylFlat(m, 1.6, 2.4, V(x, railY - 1.6, z), "Z", CHROME, CHROME_O) -- hook ring
		Kit.Box(m, V(x - 0.5, railY - 22, z - 1), V(x + 0.5, railY - 2.4, z + 1), u.col, if u.col == CHROME then CHROME_O else nil)
		if u.kind == "ladle" then
			Kit.Ball(m, 9, V(x + 2.5, railY - 26, z), u.col)
		elseif u.kind == "spatula" then
			Kit.Box(m, V(x - 0.3, railY - 34, z - 4), V(x + 0.3, railY - 22, z + 4), u.col)
			for dz = -2, 2, 2 do
				Kit.Box(m, V(x + 0.3, railY - 32, z + dz - 0.4), V(x + 0.45, railY - 24, z + dz + 0.4), DARK)
			end
		elseif u.kind == "fork" then
			Kit.Box(m, V(x - 0.4, railY - 25, z - 3), V(x + 0.4, railY - 22, z + 3), u.col, CHROME_O)
			for dz = -2.5, 2.5, 1.66 do
				Kit.Box(m, V(x - 0.3, railY - 34, z + dz - 0.35), V(x + 0.3, railY - 25, z + dz + 0.35), u.col, CHROME_O)
			end
		else
			Kit.Part(m, V(1, 10, 6), CFrame.new(x + 0.4, railY - 26, z), u.col, { Shape = Enum.PartType.Cylinder })
		end
	end
end

local function counterLip(f: Instance)
	Kit.Box(f, V(140, -0.5, Z0 + 1), V(146, 10, Z1 - 1), WOOD_D, { Mat = WOOD, Solid = true, Shadow = true })
	Kit.Box(f, V(139.6, 10, Z0 + 1), V(146.4, 10.6, Z1 - 1), CHROME, CHROME_O)
	Kit.Box(f, V(139.8, 3, Z0 + 1), V(140, 3.6, Z1 - 1), CHROME, CHROME_O)
	-- front of the counter cabinets dropping to the kitchen floor
	Kit.Box(f, V(146, -180, Z0 - 20), V(150, -0.5, Z1 + 20), C(185, 150, 110), { Mat = WOOD })
	for z = Z0 + 40, Z1 - 20, 90 do
		Kit.Box(f, V(150, -30, z - 10), V(151.5, -26, z + 10), CHROME, CHROME_O)
	end
	-- kitchen floor far below: big black-and-white tiles
	Kit.Box(f, V(150, -184, Z0 - 40), V(330, -180, Z1 + 40), C(235, 232, 225), { Mat = MARBLE })
	for i = 0, 5 do
		for j = 0, 9 do
			if (i + j) % 2 == 0 then
				local x, z = 150 + i * 30, Z0 - 40 + j * 44
				Kit.Box(f, V(x, -180, z), V(x + 30, -179.9, z + 44), C(45, 45, 52), { Mat = MARBLE })
			end
		end
	end
end

local function fridge(f: Instance)
	local m = Kit.Model(f, "GiantFridge")
	local x0, x1 = 158, 240
	local za, zb = Z0 + 6, Z0 + 136
	Kit.Box(m, V(x0, -180, za), V(x1, 170, zb), WHITE, { Mat = SMOOTH, Shadow = true })
	-- door split, handles, base grille
	Kit.Box(m, V(x0 - 0.3, 78, za + 2), V(x0, 80, zb - 2), C(190, 192, 196))
	for _, h in { { 92, 150 }, { -60, 66 } } do
		Kit.Box(m, V(x0 - 4, h[1], zb - 12), V(x0 - 1.6, h[2], zb - 8), CHROME, CHROME_O)
		for _, y in { h[1] + 2, h[2] - 2 } do
			Kit.Box(m, V(x0 - 2, y - 1, zb - 11), V(x0, y + 1, zb - 9), CHROME, CHROME_O)
		end
	end
	Kit.Box(m, V(x0 - 0.3, -178, za + 6), V(x0, -168, zb - 6), DARK)
	-- magnets and notes on the fridge door
	local mags: { { y: number, z: number, col: Color3 } } = {
		{ y = 40, z = 30, col = RED }, { y = 12, z = 60, col = C(255, 200, 60) }, { y = 58, z = 90, col = C(90, 200, 120) },
		{ y = 110, z = 40, col = C(120, 140, 255) }, { y = 100, z = 100, col = C(255, 140, 200) },
	}
	for _, g in mags do
		Kit.CylFlat(m, 1.4, 7, V(x0 - 0.6, g.y, za + g.z), "X", g.col)
	end
	local note = Kit.Part(m, V(0.2, 22, 26), CFrame.new(x0 - 0.2, 34, za + 32), C(255, 250, 200), { Name = "SignBoard" })
	Kit.Sign(note, Enum.NormalId.Left, "BUY MILK!", C(60, 90, 200), { Stroke = C(255, 255, 255) })
	local drawing = Kit.Part(m, V(0.2, 26, 30), CFrame.new(x0 - 0.2, 26, za + 82), WHITE, { Name = "SignBoard" })
	Kit.Sign(drawing, Enum.NormalId.Left, "BEST\nGIANT\nEVER", C(230, 80, 80), { Stroke = C(255, 255, 255) })
	Kit.CylFlat(m, 0.5, 8, V(x0 - 0.5, 18, za + 82), "X", C(255, 220, 60)) -- crayon sun
end

local function stove(f: Instance)
	local m = Kit.Model(f, "GiantStove")
	local x0, x1 = 154, 246
	local za, zb = Z0 + 164, Z1 - 4
	Kit.Box(m, V(x0, -180, za), V(x1, 0, zb), C(230, 232, 236), { Mat = METAL })
	Kit.Box(m, V(x0, 0, za), V(x1, 1, zb), C(30, 30, 36), { Mat = Enum.Material.Glass, Refl = 0.15 })
	-- oven door window (seen from the far side)
	Kit.Box(m, V(x0 - 0.3, -120, za + 30), V(x0, -40, zb - 30), C(40, 40, 46), { Mat = Enum.Material.Glass })
	Kit.Box(m, V(x0 - 3, -30, za + 26), V(x0 - 1, -27, zb - 26), CHROME, CHROME_O)
	-- burners (coil rings); the one under the pot glows a little
	local burners = { { 180, za + 36 }, { 222, za + 36 }, { 180, zb - 40 }, { 222, zb - 40 } }
	for i, b in burners do
		Kit.Disc(m, b[1], b[2], 1.2, 36, 0.2, C(55, 55, 60), CHROME_O)
		for _, d in { 30, 20, 10 } do
			Kit.Disc(m, b[1], b[2], 1.35, d, 0.15, if i == 3 then C(255, 120, 50) else C(90, 90, 96), if i == 3 then { Mat = NEON } else CHROME_O)
			Kit.Disc(m, b[1], b[2], 1.4, d - 4, 0.15, C(40, 40, 44), CHROME_O)
		end
	end
	-- soup pot on the back burner
	local px, pz = burners[3][1], burners[3][2]
	Kit.Cyl(m, 50, 62, CFrame.new(px, 26.5, pz), C(200, 205, 212), { Mat = METAL, Shadow = true })
	Kit.Cyl(m, 2, 65, CFrame.new(px, 51.5, pz), CHROME, CHROME_O)
	local soup = Kit.Disc(m, px, pz, 51.2, 59, 0.3, C(235, 140, 60))
	for _, s in { -1, 1 } do
		Kit.Box(m, V(px - 5, 40, pz + s * 31), V(px + 5, 44, pz + s * 37), DARK)
	end
	Kit.Emitter(soup, C(255, 245, 235), 4, 10, 3)
	Kit.Light(soup, C(255, 160, 80), 40, 0.6)
	-- red kettle on the front burner
	local kx, kz = burners[2][1], burners[2][2]
	local kc = C(225, 70, 60)
	Kit.Cyl(m, 26, 34, CFrame.new(kx, 14.5, kz), kc, { Mat = SMOOTH, Shadow = true })
	Kit.Ball(m, 34, V(kx, 27.5, kz), kc, { Mat = SMOOTH })
	Kit.Cyl(m, 3, 8, CFrame.new(kx, 45, kz), DARK)
	Props.Beam(m, V(kx - 14, 14, kz), V(kx - 30, 30, kz), 5, 5, kc, { Mat = SMOOTH }) -- spout toward the counter
	Props.Beam(m, V(kx + 10, 40, kz), V(kx - 10, 40, kz), 3, 3, DARK)
	for _, sx in { -1, 1 } do
		Props.Beam(m, V(kx + sx * 10, 40, kz), V(kx + sx * 12, 30, kz), 3, 3, DARK)
	end
	-- knob panel at the back of the hob, facing the counter
	Kit.Box(m, V(x1 - 6, 1, za), V(x1, 22, zb), C(220, 222, 228), { Mat = METAL })
	for k = 0, 3 do
		local z = za + 30 + k * ((zb - za - 60) / 3)
		Kit.CylFlat(m, 3, 9, V(x1 - 7.5, 12, z), "X", DARK)
		Kit.Box(m, V(x1 - 9.2, 11.5, z - 0.4), V(x1 - 8.9, 15.5, z + 0.4), WHITE)
	end
	-- range hood high above
	Kit.Box(m, V(170, 130, za + 12), V(246, 146, zb - 12), C(190, 195, 202), { Mat = METAL })
	Kit.Box(m, V(196, 146, za + 60), V(240, 300, zb - 60), C(190, 195, 202), { Mat = METAL })
	local hoodLamp = Kit.Box(m, V(185, 129.6, za + 60), V(200, 130, za + 75), C(255, 240, 200))
	Kit.Light(hoodLamp, C(255, 230, 180), 50, 0.6)
end

--==================================================================
-- PROPS
--==================================================================
local function cookie(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GiantCookie")
	Kit.Disc(m, x, z, 2.4, 26, 2.4, COOKIE, { Solid = true, Shadow = true })
	Kit.Disc(m, x, z, 2.7, 23, 0.4, COOKIE_L, { Solid = true })
	for k = 1, 11 do
		local ang = k * 2.4
		local r = 2 + (k % 4) * 2.4
		Kit.Part(m, V(2, 1.4, 2), CFrame.new(x + math.cos(ang) * r, 2.9, z + math.sin(ang) * r) * CFrame.Angles(0.3, ang, 0.2), CHOC)
	end
	-- a broken-off piece and crumbs beside it
	Kit.Wedge(m, V(7, 2.4, 6), CFrame.new(x + 16, 1.2, z + 6) * CFrame.Angles(0, 0.8, 0), COOKIE, { Solid = true })
	Kit.Part(m, V(1.6, 1.2, 1.6), CFrame.new(x + 16, 2.6, z + 6) * CFrame.Angles(0.2, 0.5, 0), CHOC)
	Kit.AddCircle(x, z, 14)
	Kit.AddCircle(x + 16, z + 6, 5)
end

local function teacup(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Teacup")
	Kit.Disc(m, x, z, 1, 34, 1, WHITE, { Mat = SMOOTH, Solid = true })
	Kit.Disc(m, x, z, 1.15, 31, 0.15, BLUE, { Mat = SMOOTH })
	Kit.Disc(m, x, z, 1.3, 27, 0.15, WHITE, { Mat = SMOOTH })
	Kit.Cyl(m, 1.5, 13, CFrame.new(x, 2.05, z), WHITE, { Mat = SMOOTH })
	Kit.Cyl(m, 14, 20, CFrame.new(x, 9.8, z), WHITE, { Mat = SMOOTH, Solid = true, Shadow = true })
	Kit.Cyl(m, 2, 20.4, CFrame.new(x, 13.4, z), BLUE, { Mat = SMOOTH })
	Kit.Cyl(m, 0.8, 20.3, CFrame.new(x, 6, z), C(240, 190, 80), { Mat = SMOOTH })
	local tea = Kit.Disc(m, x, z, 16.85, 18, 0.1, TEA, { Mat = SMOOTH, Refl = 0.1 })
	Kit.Emitter(tea, C(255, 250, 245), 3, 5, 2)
	-- handle toward the lane
	local pts = { V(x - 9.6, 13.5, z), V(x - 14, 13, z), V(x - 15.4, 9.5, z), V(x - 14, 6, z), V(x - 9.6, 5.5, z) }
	for i = 1, #pts - 1 do
		Props.Beam(m, pts[i], pts[i + 1], 1.6, 2.2, WHITE, { Mat = SMOOTH })
	end
	Kit.AddCircle(x, z, 18)
end

local function sugarCube(parent: Instance, x: number, y: number, z: number, s: number, yaw: number, solid: boolean)
	local col = if rng:NextNumber() < 0.5 then C(252, 252, 252) else C(244, 244, 248)
	Kit.Part(parent, V(s, s, s), CFrame.new(x, y + s / 2, z) * CFrame.Angles(0, yaw, 0), col, { Mat = Enum.Material.Sand, Solid = solid, Shadow = solid })
end

-- Spoon lying across the lane at Y 12 on two sugar-cube stacks; cube steps on the left lead up.
local function spoonBridge(f: Instance)
	local m = Kit.Model(f, "SpoonBridge")
	local z = Z0 + 150
	local S = 4
	-- left stack 1 x 2 cubes, 3 high (X -32..-28); right stack 2 x 2, 3 high (X 22..30)
	for lv = 0, 2 do
		for _, dz in { -2, 2 } do
			sugarCube(m, -30, lv * S, z + dz, S, 0, true)
			for _, xx in { 24, 28 } do
				sugarCube(m, xx, lv * S, z + dz, S, 0, true)
			end
		end
	end
	-- steps: 2 high at X -36..-32, 1 high at X -40..-36
	for _, dz in { -2, 2 } do
		sugarCube(m, -34, 0, z + dz, S, 0, true)
		sugarCube(m, -34, S, z + dz, S, 0, true)
		sugarCube(m, -38, 0, z + dz, S, 0, true)
	end
	-- the spoon: wide handle end, long handle, neck, bowl
	Kit.Box(m, V(-33, 12, z - 3.4), V(-22, 13, z + 3.4), CHROME, { Mat = METAL, Solid = true })
	Kit.Box(m, V(-22, 12, z - 2), V(14, 13, z + 2), CHROME, { Mat = METAL, Solid = true, Shadow = true })
	Kit.Box(m, V(14, 12, z - 1.4), V(19, 12.9, z + 1.4), CHROME, { Mat = METAL, Solid = true })
	Kit.Disc(m, 26, z, 13, 17, 1, CHROME, { Mat = METAL, Solid = true, Shadow = true })
	Kit.Disc(m, 26, z, 13.05, 13, 0.05, C(225, 230, 238), { Mat = METAL, Refl = 0.2 })
	Kit.AddRect(-41, z - 9, -12, z + 9)
	Kit.AddRect(12, z - 9, 36, z + 9)
end

local function cerealBox(f: Instance, x: number, z: number, sx: number, sy: number, sz: number, face: number, col: Color3, name: string, flake: Color3)
	-- face = +1: the label faces +X; -1: faces -X
	local m = Kit.Model(f, "CerealBox")
	Kit.Box(m, V(x - sx / 2, 0, z - sz / 2), V(x + sx / 2, sy, z + sz / 2), col, { Mat = CARD, Solid = true, Shadow = true })
	local fx = x + face * (sx / 2 + 0.1)
	local label = Kit.Part(m, V(0.2, sy * 0.22, sz - 4), CFrame.new(fx, sy * 0.82, z), C(255, 236, 120), { Name = "SignBoard" })
	Kit.Sign(label, if face > 0 then Enum.NormalId.Right else Enum.NormalId.Left, name, col, { Stroke = C(255, 255, 255) })
	-- bowl picture: white bowl with cereal pieces
	Kit.CylFlat(m, 0.2, sz * 0.62, V(fx, sy * 0.4, z), "X", C(250, 250, 250))
	Kit.CylFlat(m, 0.3, sz * 0.5, V(fx + face * 0.05, sy * 0.44, z), "X", C(120, 180, 240))
	for k = -2, 2 do
		Kit.CylFlat(m, 0.4, 4, V(fx + face * 0.1, sy * 0.47 + (k % 2) * 2, z + k * 3.6), "X", flake)
	end
	-- open top flaps
	for _, s in { -1, 1 } do
		Kit.Part(m, V(sx, 0.3, 8), CFrame.new(x, sy + 2.6, z + s * (sz / 2 + 2.6)) * CFrame.Angles(s * -0.8, 0, 0), col, { Mat = CARD })
	end
	Kit.AddRect(x - sx / 2 - 2, z - sz / 2 - 6, x + sx / 2 + 2, z + sz / 2 + 6)
end

local function spilledCereal(f: Instance, x0: number, x1: number, z0: number, z1: number, n: number, col: Color3)
	for _ = 1, n do
		local x, z = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
		if Kit.IsFree(x, z, 2.2) then
			local cf = CFrame.new(x, 0.7, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3))
			Kit.Part(f, V(1.4, 4, 4), cf * CFrame.Angles(0, 0, math.pi / 2), col, { Shape = Enum.PartType.Cylinder })
			Kit.Part(f, V(1.5, 1.6, 1.6), cf * CFrame.Angles(0, 0, math.pi / 2), C(150, 95, 50), { Shape = Enum.PartType.Cylinder })
			Kit.AddCircle(x, z, 2.2)
		end
	end
end

local function milkCarton(f: Instance, x: number, z: number)
	-- lying on its side along X, the open spout toward the spilled milk (-> +X)
	local m = Kit.Model(f, "MilkCarton")
	Kit.Box(m, V(x - 14, 0, z - 7), V(x + 10, 14, z + 7), WHITE, { Mat = CARD, Solid = true, Shadow = true })
	Kit.Box(m, V(x - 14.1, 0.5, z - 7.1), V(x + 10.1, 5, z + 7.1), C(70, 140, 220), { Mat = CARD })
	-- gable top (ridge pointing +X): two wedges, the lower one upside down
	local gable = CFrame.Angles(0, -math.pi / 2, 0)
	Kit.Wedge(m, V(14, 7, 7), CFrame.new(x + 13.5, 10.5, z) * gable, WHITE, { Mat = CARD })
	Kit.Wedge(m, V(14, 7, 7), CFrame.new(x + 13.5, 3.5, z) * gable * CFrame.Angles(0, 0, math.pi), WHITE, { Mat = CARD })
	Kit.Box(m, V(x + 16.5, 6.4, z - 1.5), V(x + 18, 7.6, z + 1.5), C(230, 230, 235))
	local lbl = Kit.Part(m, V(18, 6, 0.2), CFrame.new(x - 2, 9.5, z - 7.1), C(250, 250, 250), { Name = "SignBoard" })
	Kit.Sign(lbl, Enum.NormalId.Front, "MOO MILK", C(60, 120, 210), { Stroke = C(255, 255, 255) })
	Kit.Box(m, V(x + 2, 1.5, z + 7), V(x + 8, 7, z + 7.1), C(250, 250, 250))
	Kit.AddRect(x - 16, z - 9, x + 18, z + 9)
end

local function cheese(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "CheeseWedge")
	local cf = CFrame.new(x, 9, z) * CFrame.Angles(0, 0.35, 0)
	Kit.Wedge(m, V(24, 18, 32), cf, CHEESE, { Solid = true, Shadow = true })
	-- holes on both sides (below the slope) and on the tall back face
	local holes = { { -10, 3, 3.6 }, { -4, 6, 5 }, { 3, 4, 4 }, { 8, 10, 3 }, { 10, 4, 5.4 }, { -1, 1.5, 2.6 } }
	for _, sx in { -1, 1 } do
		for _, h in holes do
			local lz, y, d = h[1], h[2], h[3]
			if y + d / 2 < 18 * (lz + 16) / 32 - 1 then
				Kit.Part(m, V(0.3, d, d), cf * CFrame.new(sx * 12.05, y - 9 + d / 2 + 0.6, lz), CHEESE_D, { Shape = Enum.PartType.Cylinder })
			end
		end
	end
	for _, h in { { -6, 5, 4 }, { 4, 12, 5 }, { 7, 3, 3 }, { -5, 13, 3 } } do
		Kit.Part(m, V(0.3, h[3], h[3]), cf * CFrame.new(h[1], h[2] - 9, 16.05) * CFrame.Angles(0, math.pi / 2, 0), CHEESE_D, { Shape = Enum.PartType.Cylinder })
	end
	Kit.Part(m, V(24.2, 2.4, 0.4), cf * CFrame.new(0, -7.6, 16.1), C(210, 60, 50)) -- wax rind strip
	Kit.AddCircle(x, z, 19)
end

local function donut(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Donut")
	local n = 10
	for k = 0, n - 1 do
		local ang = k * math.pi * 2 / n
		local px, pz = x + math.cos(ang) * 6.5, z + math.sin(ang) * 6.5
		Kit.Ball(m, 6.4, V(px, 3, pz), C(215, 160, 95), { Solid = true })
		Kit.Ball(m, 5.6, V(px, 4.2, pz), C(250, 150, 190))
	end
	local cols = { C(255, 255, 255), C(90, 190, 255), C(255, 230, 80), C(120, 220, 120), C(200, 120, 255) }
	for k = 0, 13 do
		local ang = k * 0.9
		local r = 4.8 + (k % 3) * 1.4
		Kit.Part(m, V(0.4, 0.4, 1.6), CFrame.new(x + math.cos(ang) * r, 6.9 - (k % 3) * 0.35, z + math.sin(ang) * r) * CFrame.Angles(0, k * 1.7, 0), cols[k % #cols + 1])
	end
	Kit.AddCircle(x, z, 11)
end

local function strawberry(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Strawberry")
	Kit.Ball(m, 11, V(x, 6.5, z), C(225, 45, 60), { Solid = true, Shadow = true })
	Kit.Ball(m, 8, V(x + 0.6, 3.6, z + 0.4), C(225, 45, 60))
	Kit.Ball(m, 4.5, V(x + 1, 1.5, z + 0.6), C(220, 40, 55))
	for k = 0, 9 do
		local ang = k * 2.2
		local y = 3 + (k % 4) * 1.6
		local r = if y > 6 then 5.4 else 4.2
		Kit.Part(m, V(0.4, 0.7, 0.4), CFrame.new(x + math.cos(ang) * r, y, z + math.sin(ang) * r), C(255, 225, 110))
	end
	for k = 0, 4 do
		local ang = k * math.pi * 2 / 5
		Kit.Part(m, V(5, 0.3, 1.8), CFrame.new(x + math.cos(ang) * 2.4, 11.6, z + math.sin(ang) * 2.4) * CFrame.Angles(0, -ang, 0.25), C(70, 165, 70))
	end
	Kit.Cyl(m, 2.4, 0.8, CFrame.new(x, 12.6, z), C(80, 140, 60))
	Kit.AddCircle(x, z, 7)
end

local function shaker(f: Instance, x: number, z: number, body: Color3, label: string)
	local m = Kit.Model(f, "Shaker")
	Kit.Cyl(m, 15, 9, CFrame.new(x, 7.5, z), body, { Mat = SMOOTH, Solid = true, Shadow = true })
	Kit.Cyl(m, 4, 9.6, CFrame.new(x, 17, z), CHROME, CHROME_O)
	Kit.Ball(m, 9.2, V(x, 18.6, z), CHROME, CHROME_O)
	for k = 0, 2 do
		local ang = k * 2.1
		Kit.Part(m, V(1, 0.3, 1), CFrame.new(x + math.cos(ang) * 1.6, 23.15, z + math.sin(ang) * 1.6), DARK)
	end
	local tag = Kit.Part(m, V(0.2, 5, 5), CFrame.new(x + 4.6, 8, z), WHITE, { Name = "SignBoard" })
	Kit.Sign(tag, Enum.NormalId.Right, label, C(60, 60, 70), { Stroke = C(255, 255, 255) })
	Kit.AddCircle(x, z, 6)
end

local function butterDish(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "ButterDish")
	Kit.Disc(m, x, z, 0.9, 28, 0.9, WHITE, { Mat = SMOOTH, Solid = true })
	Kit.Box(m, V(x - 8, 0.9, z - 5), V(x + 5, 7.5, z + 5), C(255, 232, 140), { Solid = true, Shadow = true })
	Kit.Part(m, V(1.4, 6.4, 9.6), CFrame.new(x + 7.5, 4.2, z) * CFrame.Angles(0, 0, -0.25), C(255, 232, 140))
	Kit.AddCircle(x, z, 15)
end

local function rollingPin(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "RollingPin")
	Kit.CylFlat(m, 34, 9, V(x, 4.5, z), "X", WOOD_L, { Mat = WOOD, Solid = true, Shadow = true })
	for _, s in { -1, 1 } do
		Kit.CylFlat(m, 7, 3.4, V(x + s * 20.5, 4.5, z), "X", WOODC, { Mat = WOOD })
		Kit.CylFlat(m, 1.4, 4.6, V(x + s * 24.5, 4.5, z), "X", WOOD_D, { Mat = WOOD })
	end
	Kit.AddRect(x - 26, z - 6, x + 26, z + 6)
end

local function oatCanister(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "OatCanister")
	Kit.Cyl(m, 40, 24, CFrame.new(x, 20, z), C(235, 210, 160), { Mat = CARD, Solid = true, Shadow = true })
	Kit.Cyl(m, 3, 25, CFrame.new(x, 41.5, z), C(200, 60, 50), { Mat = CARD })
	Kit.Cyl(m, 10, 24.3, CFrame.new(x, 22, z), C(90, 150, 90), { Mat = CARD })
	local lbl = Kit.Part(m, V(0.2, 8, 14), CFrame.new(x - 12.3, 22, z), C(90, 150, 90), { Name = "SignBoard" })
	Kit.Sign(lbl, Enum.NormalId.Left, "OATS", C(255, 245, 220), { Stroke = C(60, 90, 50) })
	Kit.AddCircle(x, z, 13)
end

local function scatter(f: Instance)
	-- loose sugar cubes
	local placed = 0
	for _ = 1, 40 do
		if placed >= 9 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 10)
		if Kit.IsFree(x, z, 3.5) then
			placed += 1
			sugarCube(f, x, 0, z, 4, rng:NextNumber(0, 1.5), true)
			if placed % 3 == 0 then
				sugarCube(f, x + 0.4, 4, z - 0.3, 4, rng:NextNumber(0, 1.5), false)
			end
			Kit.AddCircle(x, z, 3.5)
		end
	end
	-- crumbs
	local cols = { CRUMB, COOKIE, C(160, 110, 60), COOKIE_L }
	local n = 0
	for _ = 1, 120 do
		if n >= 40 then
			break
		end
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(Z0 + 26, Z1 - 6)
		if Kit.IsFree(x, z, 1.2) then
			n += 1
			local s = rng:NextNumber(0.6, 1.8)
			Kit.Part(f, V(s, s * 0.7, s * 1.2), CFrame.new(x, s * 0.3, z) * CFrame.Angles(rng:NextNumber(0, 0.5), rng:NextNumber(0, 3), rng:NextNumber(0, 0.5)), cols[n % #cols + 1])
		end
	end
	-- soap bubbles drifting over the counter
	local bubbles = { V(-40, 16, Z0 + 60), V(52, 20, Z0 + 110), V(-100, 24, Z0 + 180), V(30, 26, Z0 + 250), V(-30, 30, Z0 + 330), V(110, 18, Z0 + 200), V(-118, 28, Z0 + 300) }
	for i, p in bubbles do
		local b = Kit.Ball(f, 3 + (i % 3) * 1.4, p, C(200, 230, 255), { Mat = Enum.Material.Glass, Transp = 0.55, Refl = 0.3, Name = "FloatingBubble" })
		Kit.Float(b, 1.6)
	end
end

local function props(f: Instance)
	cookie(f, -100, Z0 + 40)
	teacup(f, 105, Z0 + 75)
	spoonBridge(f)
	cerealBox(f, -118, Z0 + 160, 12, 62, 40, 1, C(235, 95, 55), "CRUNCHY O'S", C(240, 190, 90))
	cerealBox(f, 120, Z0 + 242, 12, 54, 36, -1, C(120, 70, 45), "CHOCO PUFFS", C(110, 60, 35))
	milkCarton(f, -114, Z0 + 205)
	cheese(f, 80, Z0 + 300)
	oatCanister(f, 122, Z0 + 290)
	donut(f, 40, Z0 + 205)
	strawberry(f, 46, Z0 + 50)
	shaker(f, -120, Z0 + 262, WHITE, "SALT")
	shaker(f, -106, Z0 + 276, C(70, 70, 78), "PEPPER")
	butterDish(f, -112, Z0 + 330)
	rollingPin(f, 108, Z0 + 340)
	spilledCereal(f, -110, -94, Z0 + 135, Z0 + 185, 16, C(240, 190, 90))
	scatter(f)
end

--==================================================================
-- BUILD
--==================================================================
function GiantsKitchen.Build(map: Instance)
	local f = Kit.Folder(map, "GiantsKitchen")
	ground(f)
	areaMarks(f)
	backsplash(f)
	counterLip(f)
	fridge(f)
	stove(f)
	props(f)
end

return GiantsKitchen
