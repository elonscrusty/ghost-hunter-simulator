--!strict
-- ZONE 22: Ghost Subway (Z 8800..9160). A big underground station hall: grey concrete, cream
-- wall tiles with teal bands, green riveted steel columns, a girder roof and safety-yellow lines.
--   Ground: concrete slab; a light-tiled platform across the middle (|X| < 104) with a yellow
--   safety line and tactile strip at each edge; the lane along X = 0 is a tiled walkway with
--   yellow edge lines. Track beds with flat rails run along both sides (|X| 108..136).
--   Ghost areas get flat platform roundels ((0,8885) r30, (-82,8920) r24, (75,8980) r26,
--   (-62,9040) r24); the boss area (0,9105) r26 is a flat railway turntable.
--   Phantom trains: two ghostly see-through trains parked on the side tracks (left Z ~8860..8990,
--   right Z ~9000..9130), tunnel mouths in front of both gate walls over the tracks.
--   Roof: steel girders across the hall at Y 40..42 (bottoms at Y 40, so they clear the ghost
--   areas), a tiled ceiling over the track beds, hanging station signs outside the areas.
--   Turnstiles across the entrance (Z ~8852, the lane, crate station and Fast Travel pad
--   stay open), benches, ticket machines, a subway map, clocks, bins and a steam vent.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local GhostSubway = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local CONCRETE = Enum.Material.Concrete
local TILES = Enum.Material.Pavement
local WOOD = Enum.Material.WoodPlanks
local GLASS = Enum.Material.Glass

local Z0, Z1 = 8800, 9160

local CONC = C(105, 108, 122)
local CONC_D = C(70, 72, 86)
local PLATFORM = C(178, 180, 192)
local TILE = C(236, 230, 210)
local TEAL = C(40, 150, 140)
local TEAL_D = C(25, 95, 95)
local YELLOW = C(255, 215, 60)
local STEEL = C(60, 125, 100) -- the classic green-painted station steel
local STEEL_D = C(40, 85, 70)
local GIRDER = C(75, 80, 98)
local RAIL = C(170, 170, 185)
local SLEEPER = C(85, 65, 55)
local BALLAST = C(60, 58, 66)
local GHOST = C(170, 235, 225)
local GHOST_D = C(110, 190, 185)
local WINDOW = C(255, 240, 170)
local DARK = C(25, 25, 35)
local WOODC = C(150, 100, 60)
local RED = C(220, 70, 70)
local BLUE = C(70, 130, 230)

local SOLID_STEEL: Kit.Opts = { Mat = METAL, Solid = true, Shadow = true }
local STEEL_O: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305
local ROOF = 40 -- girder bottoms

--==================================================================
-- HELPERS
--==================================================================
-- Flat pair of rails with sleepers along Z at x (tops below Y 0.3).
local function track(parent: Instance, x: number, z0: number, z1: number)
	Kit.Box(parent, V(x - 4.5, 0, z0), V(x + 4.5, 0.04, z1), BALLAST, { Mat = Enum.Material.Pebble })
	for z = z0 + 3, z1 - 3, 10 do
		Kit.Box(parent, V(x - 3.6, 0.04, z - 0.6), V(x + 3.6, 0.1, z + 0.6), SLEEPER, { Mat = WOOD })
	end
	for _, s in { -1, 1 } do
		Kit.Box(parent, V(x + s * 2.5 - 0.3, 0.1, z0), V(x + s * 2.5 + 0.3, 0.28, z1), RAIL, STEEL_O)
	end
end

-- Flat rails along X (across the hall) at z.
local function crossTrack(parent: Instance, z: number, x0: number, x1: number)
	Kit.Box(parent, V(x0, 0, z - 4), V(x1, 0.035, z + 4), BALLAST, { Mat = Enum.Material.Pebble })
	for _, s in { -1, 1 } do
		Kit.Box(parent, V(x0, 0.035, z + s * 2.5 - 0.3), V(x1, 0.2, z + s * 2.5 + 0.3), RAIL, STEEL_O)
	end
end

-- One ghostly carriage centred at (x, z), long along Z. front = -1/1 marks a cab end (or 0).
local function carriage(parent: Instance, x: number, z: number, len: number, front: number)
	local m = Kit.Model(parent, "PhantomCar")
	local ghost: Kit.Opts = { Transp = 0.2, Refl = 0.1 }
	local hw = 4.5
	local y0 = 1.6
	Kit.Box(m, V(x - hw, y0, z - len / 2), V(x + hw, y0 + 9, z + len / 2), GHOST, ghost)
	Kit.Box(m, V(x - hw + 0.4, y0 + 9, z - len / 2 + 0.4), V(x + hw - 0.4, y0 + 10.2, z + len / 2 - 0.4), GHOST_D, ghost)
	-- window bands and door frames on both sides
	for _, s in { -1, 1 } do
		Kit.Box(m, V(x + s * hw - 0.1, y0 + 4.6, z - len / 2 + 2), V(x + s * (hw + 0.15), y0 + 7.4, z + len / 2 - 2), WINDOW, { Transp = 0.25 })
		for _, dz in { -len / 4, len / 4 } do
			Kit.Box(m, V(x + s * hw - 0.1, y0 + 0.4, z + dz - 2), V(x + s * (hw + 0.2), y0 + 8, z + dz + 2), GHOST_D, { Transp = 0.2 })
		end
		Kit.Box(m, V(x + s * hw - 0.1, y0 + 2.2, z - len / 2), V(x + s * (hw + 0.2), y0 + 2.8, z + len / 2), Kit.Vivid(YELLOW))
	end
	-- wheels
	for _, dz in { -len / 2 + 4, -len / 2 + 7, len / 2 - 7, len / 2 - 4 } do
		Kit.CylFlat(m, 7, 2.6, V(x, 1.3, z + dz), "X", DARK, STEEL_O)
	end
	if front ~= 0 then
		local fz = z + front * len / 2
		Kit.Box(m, V(x - hw + 0.6, y0 + 4.4, fz + front * 0.05), V(x + hw - 0.6, y0 + 7.6, fz + front * 0.25), WINDOW, { Transp = 0.2 })
		local lamp = Kit.Ball(m, 1.6, V(x, y0 + 2.2, fz + front * 0.3), C(255, 245, 200), { Mat = NEON })
		Kit.Light(lamp, C(255, 240, 190), 30, 1.2)
		Kit.Box(m, V(x - hw, 0.6, fz), V(x + hw, y0, fz + front * 1.6), Kit.Vivid(YELLOW))
		-- a friendly ghost face on the cab
		for _, sx in { -1.4, 1.4 } do
			Kit.Ball(m, 1, V(x + sx, y0 + 6, fz + front * 0.35), DARK)
		end
	end
end

local function train(parent: Instance, x: number, zStart: number, cars: number, dir: number)
	local len = 40
	for i = 0, cars - 1 do
		local z = zStart + i * (len + 2) + len / 2
		local front = 0
		if i == 0 and dir < 0 then
			front = -1
		elseif i == cars - 1 and dir > 0 then
			front = 1
		end
		carriage(parent, x, z, len, front)
		if i > 0 then
			Kit.Box(parent, V(x - 1, 3, z - len / 2 - 2), V(x + 1, 5, z - len / 2), DARK, STEEL_O)
		end
	end
end

local function column(parent: Instance, x: number, z: number)
	Kit.Box(parent, V(x - 1.6, 0, z - 1.6), V(x + 1.6, 1.2, z + 1.6), STEEL_D, SOLID_STEEL)
	-- I-beam: web + two flanges
	Kit.Box(parent, V(x - 0.4, 1.2, z - 1.2), V(x + 0.4, ROOF, z + 1.2), STEEL, SOLID_STEEL)
	for _, s in { -1, 1 } do
		Kit.Box(parent, V(x + s * 1.2 - 0.25, 1.2, z - 1.2), V(x + s * 1.2 + 0.25, ROOF, z + 1.2), STEEL, STEEL_O)
	end
	Kit.Box(parent, V(x - 1.8, ROOF - 3, z - 1.8), V(x + 1.8, ROOF, z + 1.8), STEEL_D, STEEL_O)
	Kit.AddCircle(x, z, 2.5)
end

local function bench(parent: Instance, x: number, z: number, alongZ: boolean)
	local hx, hz = if alongZ then 1 else 4, if alongZ then 4 else 1
	Kit.Box(parent, V(x - hx, 1.6, z - hz), V(x + hx, 2.1, z + hz), WOODC, { Mat = WOOD, Solid = true })
	for _, s in { -1, 1 } do
		local ox, oz = if alongZ then 0 else s * 3.2, if alongZ then s * 3.2 else 0
		Kit.Box(parent, V(x + ox - 0.3, 0, z + oz - 0.3), V(x + ox + 0.3, 1.6, z + oz + 0.3), STEEL_D, STEEL_O)
	end
	Kit.AddCircle(x, z, 4.5)
end

local function ticketMachine(parent: Instance, x: number, z: number, fx: number)
	Kit.Box(parent, V(x - 1.6, 0, z - 1.8), V(x + 1.6, 6, z + 1.8), C(70, 90, 140), { Mat = METAL, Solid = true })
	Kit.Box(parent, V(x + fx * 1.6, 3.6, z - 1.2), V(x + fx * 1.7, 5.2, z + 1.2), C(150, 220, 255), { Mat = GLASS, Refl = 0.2 })
	Kit.Box(parent, V(x + fx * 1.6, 2, z - 0.8), V(x + fx * 1.75, 2.6, z + 0.8), Kit.Vivid(YELLOW))
	Kit.Box(parent, V(x - 1.7, 6, z - 1.9), V(x + 1.7, 6.6, z + 1.9), TEAL, STEEL_O)
	Kit.AddCircle(x, z, 2.6)
end

local function turnstile(parent: Instance, x: number, z: number)
	Kit.Box(parent, V(x - 0.7, 0, z - 1.6), V(x + 0.7, 3.4, z + 1.6), C(150, 155, 170), { Mat = METAL })
	Kit.Box(parent, V(x - 0.75, 3.4, z - 1.65), V(x + 0.75, 3.6, z + 1.65), CONC_D, STEEL_O)
	Kit.Ball(parent, 0.6, V(x, 3.9, z - 1), C(120, 255, 150), { Mat = NEON })
	-- three-arm rotor sticking out toward +X
	for i = 0, 2 do
		local a = i * 2 * math.pi / 3
		Kit.Part(parent, V(2.4, 0.25, 0.25), CFrame.new(x + 0.7, 2.6, z) * CFrame.Angles(a, 0, 0) * CFrame.new(1.2, 0, 0), RAIL, STEEL_O)
	end
end

local function hangingSign(parent: Instance, x: number, z: number, text: string, bg: Color3)
	-- hangs from a girder at Y = ROOF; the board reads along the lane both ways
	for _, sx in { -5, 5 } do
		Kit.Box(parent, V(x + sx - 0.15, 24, z - 0.15), V(x + sx + 0.15, ROOF, z + 0.15), GIRDER, STEEL_O)
	end
	local board = Kit.Part(parent, V(14, 3, 0.6), CFrame.new(x, 22.5, z), bg, { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, text, C(255, 255, 255))
	Kit.Sign(board, Enum.NormalId.Back, text, C(255, 255, 255))
end

local function clock(parent: Instance, pos: Vector3)
	Kit.CylFlat(parent, 1, 4.4, pos, "Z", C(30, 30, 40), STEEL_O)
	Kit.CylFlat(parent, 1.1, 3.8, pos, "Z", C(250, 248, 235))
	Kit.Part(parent, V(0.3, 1.5, 1.2), CFrame.new(pos + V(0, 0.6, 0)), DARK)
	Kit.Part(parent, V(1.1, 0.3, 1.2), CFrame.new(pos + V(0.5, 0, 0)), DARK)
end

local function kiosk(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "Newsstand")
	Kit.Box(m, V(x - 5, 0, z - 3.5), V(x + 5, 4, z + 3.5), C(90, 70, 60), { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 5.2, 4, z - 3.7), V(x + 5.2, 4.4, z + 3.7), STEEL_D, STEEL_O)
	for i = -2, 2 do
		local col = Props.Colors.Book[(i + 3)]
		Kit.Part(m, V(1.5, 2, 0.2), CFrame.new(x + i * 1.9, 3, z - 3.6) * CFrame.Angles(0.2, 0, 0), Kit.Vivid(col))
	end
	for _, dx in { -4.7, 4.7 } do
		Kit.Box(m, V(x + dx - 0.25, 4.4, z - 3.4), V(x + dx + 0.25, 9, z + 3.4), STEEL_D, STEEL_O)
	end
	-- striped awning
	for i = 0, 5 do
		Kit.Wedge(m, V(10.6 / 6, 1.6, 4), CFrame.new(x - 5.3 + (i + 0.5) * 10.6 / 6, 9.8, z - 2), if i % 2 == 0 then TEAL else TILE)
	end
	Kit.Box(m, V(x - 5.3, 9, z), V(x + 5.3, 10.6, z + 3.6), STEEL_D, STEEL_O)
	Props.SignBoard(m, V(x, 7.4, z - 3.5), 8, 1.6, 0, -1, "SPOOKY NEWS", C(40, 50, 80), C(255, 235, 150))
	Kit.AddCircle(x, z, 6.5)
end

local function vending(parent: Instance, x: number, z: number, fx: number, col: Color3)
	Kit.Box(parent, V(x - 1.8, 0, z - 2), V(x + 1.8, 8, z + 2), col, { Solid = true })
	Kit.Box(parent, V(x + fx * 1.8, 2.6, z - 1.6), V(x + fx * 1.9, 7.4, z + 0.6), C(200, 235, 255), { Mat = GLASS, Transp = 0.2 })
	for r = 0, 2 do
		for c = 0, 2 do
			Kit.Box(parent, V(x + fx * 1.75 - 0.15, 3 + r * 1.5, z - 1.4 + c * 0.7), V(x + fx * 1.75 + 0.15, 3.8 + r * 1.5, z - 0.9 + c * 0.7), Kit.Pick(Props.Colors.Car))
		end
	end
	Kit.Box(parent, V(x + fx * 1.8, 1, z - 1.4), V(x + fx * 1.9, 1.8, z + 1.4), DARK)
	Kit.AddCircle(x, z, 3)
end

--==================================================================
-- GROUND, WALLS, ROOF
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), CONC, { Mat = CONCRETE, Solid = true, Name = "Ground_GhostSubway" })
	-- platform tiles across the middle, with yellow safety lines + tactile strips at the edges
	Kit.Box(f, V(-104, 0, Z0 + 4), V(104, 0.03, Z1 - 4), PLATFORM, { Mat = TILES })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 101, 0.03, Z0 + 4), V(s * 103, 0.06, Z1 - 4), Kit.Vivid(YELLOW))
		Kit.Box(f, V(s * 103, 0.03, Z0 + 4), V(s * 104, 0.045, Z1 - 4), C(230, 230, 235))
		track(f, s * 122, Z0 + 4, if s < 0 then Z0 + 186 else Z1 - 4)
	end
	-- platform floor over the end of the left track bed (the escalator stands there)
	Kit.Box(f, V(-140, 0, Z0 + 186), V(-104, 0.03, Z1 - 4), PLATFORM, { Mat = TILES })
	Kit.Box(f, V(-127, 0, Z0 + 183), V(-117, 3, Z0 + 186), Kit.Vivid(YELLOW), { Solid = true }) -- buffer stop
	-- tile grid on the platform (flat)
	for x = -96, 96, 24 do
		if x ~= 0 then
			Kit.Box(f, V(x - 0.15, 0.03, Z0 + 4), V(x + 0.15, 0.04, Z1 - 4), C(150, 152, 165))
		end
	end
	for z = Z0 + 16, Z1 - 8, 24 do
		Kit.Box(f, V(-101, 0.03, z - 0.15), V(101, 0.04, z + 0.15), C(150, 152, 165))
	end
	-- the lane: tiled walkway with yellow edge lines
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.08, Z1), C(205, 205, 215), { Mat = TILES, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.2, 0.1, Z1), Kit.Vivid(YELLOW))
	end
	-- floor arrows down the lane
	for z = Z0 + 30, Z1 - 30, 50 do
		Kit.Part(f, V(3, 0.03, 3), CFrame.new(0, 0.1, z) * CFrame.Angles(0, math.pi / 4, 0), Kit.Vivid(YELLOW))
		Kit.Box(f, V(-0.6, 0.08, z - 4.5), V(0.6, 0.11, z), Kit.Vivid(YELLOW))
	end
	-- a flat cross track between the second and third ghost areas
	crossTrack(f, Z0 + 150, -104, -10)
	crossTrack(f, Z0 + 150, 10, 104)
	-- platform roundels (red ring, white disc, blue bar: an original subway roundel)
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.08, r * 2 + 3, 0.08, CONC_D, { Mat = CONCRETE })
		Kit.Disc(f, x, z, 0.11, r * 2, 0.11, if i % 2 == 0 then C(220, 215, 200) else TILE, { Mat = TILES })
		-- yellow "wait here" ring with teal ticks and a dark centre tile
		Kit.Disc(f, x, z, 0.14, r * 1.3, 0.03, Kit.Vivid(YELLOW))
		Kit.Disc(f, x, z, 0.16, r * 1.1, 0.03, if i % 2 == 0 then C(220, 215, 200) else TILE, { Mat = TILES })
		for k = 0, 3 do
			local ang = k * math.pi / 2 + math.pi / 4
			Kit.Part(f, V(r * 0.3, 0.03, 1.4), CFrame.new(x + math.cos(ang) * r * 0.78, 0.15, z + math.sin(ang) * r * 0.78) * CFrame.Angles(0, -ang, 0), Kit.Vivid(TEAL))
		end
		Kit.Part(f, V(r * 0.5, 0.03, r * 0.5), CFrame.new(x, 0.18, z) * CFrame.Angles(0, math.pi / 4, 0), CONC_D)
	end
	-- boss: railway turntable (flat): pit ring, deck, a track across, radial lines
	Kit.Disc(f, 0, BOSS_Z, 0.08, 58, 0.08, CONC_D, { Mat = CONCRETE })
	Kit.Disc(f, 0, BOSS_Z, 0.11, 54, 0.11, BALLAST, { Mat = Enum.Material.Pebble })
	Kit.Disc(f, 0, BOSS_Z, 0.14, 46, 0.03, Kit.Vivid(YELLOW))
	Kit.Disc(f, 0, BOSS_Z, 0.16, 44, 0.05, C(120, 100, 85), { Mat = WOOD })
	for k = 0, 11 do
		local ang = k * math.pi / 6
		Kit.Part(f, V(20, 0.03, 0.6), CFrame.new(math.cos(ang) * 13, 0.18, BOSS_Z + math.sin(ang) * 13) * CFrame.Angles(0, -ang, 0), C(90, 75, 65), { Mat = WOOD })
	end
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 2.5 - 0.3, 0.16, BOSS_Z - 22), V(s * 2.5 + 0.3, 0.26, BOSS_Z + 22), RAIL, STEEL_O)
	end
	Kit.Disc(f, 0, BOSS_Z, 0.22, 5, 0.05, Kit.Vivid(YELLOW), STEEL_O)
end

local function walls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	local H = 34
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, H, z1), TILE, { Mat = TILES, Solid = true, Shadow = true })
		-- teal bands and a dark skirting
		Kit.Box(f, V(s * 139.8, 0, z0), V(s * 140, 2, z1), TEAL_D)
		Kit.Box(f, V(s * 139.8, 7, z0), V(s * 140, 8.4, z1), TEAL)
		Kit.Box(f, V(s * 139.8, 26, z0), V(s * 140, 27.4, z1), TEAL)
		Kit.Box(f, V(s * 139.5, H, z0), V(s * 146.5, H + 1, z1), CONC_D, { Mat = CONCRETE })
		-- mosaic name plaques
		for i, z in { Z0 + 60, Z0 + 170, Z0 + 280 } do
			Props.SignBoard(f, V(s * 139.5, 17, z), 26, 5, -s, 0, if i == 2 then "PHANTOM LINE" else "GHOST SUBWAY", TEAL_D, C(255, 245, 220), TILE)
		end
		for _, z in { Z0 + 115, Z0 + 225 } do
			clock(f, V(s * 139, 17, z) + V(0, 0, 0))
		end
	end
	-- tunnel mouths in front of both gate walls, over the side tracks
	for _, ez in { { Z0 + 3, 1 }, { Z1 - 3, -1 } } do
		local z, d = ez[1], ez[2]
		for _, s in { -1, 1 } do
			local x = s * 122
			Kit.Box(f, V(x - 14, 0, z), V(x + 14, H, z + d * 2), TILE, { Mat = TILES, Solid = true })
			Kit.Box(f, V(x - 8, 0, z + d * 2), V(x + 8, 14, z + d * 2.1), DARK)
			Kit.CylFlat(f, 0.1, 16, V(x, 14, z + d * 2.05), "Z", DARK)
			Kit.Box(f, V(x - 9.5, 0, z + d * 2), V(x - 8, 14, z + d * 2.6), TEAL, STEEL_O)
			Kit.Box(f, V(x + 8, 0, z + d * 2), V(x + 9.5, 14, z + d * 2.6), TEAL, STEEL_O)
			-- warning lamp over the tunnel
			Kit.Ball(f, 1.2, V(x, 24, z + d * 2.4), C(255, 120, 90), { Mat = NEON })
		end
	end
end

local function roof(f: Instance)
	for z = Z0 + 20, Z1 - 14, 45 do
		Kit.Box(f, V(-140, ROOF, z - 1.2), V(140, ROOF + 2.4, z + 1.2), GIRDER, STEEL_O)
		Kit.Box(f, V(-140, ROOF + 2.4, z - 0.4), V(140, ROOF + 5, z + 0.4), GIRDER, STEEL_O)
	end
	for _, s in { -1, 1 } do
		-- longitudinal beams and a tiled ceiling over the track beds
		Kit.Box(f, V(s * 104 - 1, ROOF + 2.4, Z0 + 4), V(s * 104 + 1, ROOF + 5, Z1 - 4), GIRDER, STEEL_O)
		Kit.Box(f, V(s * 50 - 0.6, ROOF + 2.4, Z0 + 4), V(s * 50 + 0.6, ROOF + 4.4, Z1 - 4), GIRDER, STEEL_O)
	end
end

--==================================================================
-- STATION FURNITURE
--==================================================================
local function columns(f: Instance)
	for z = Z0 + 65, Z1 - 20, 45 do
		for _, s in { -1, 1 } do
			if Kit.IsFree(s * 50, z, 2.5) then
				column(f, s * 50, z)
			end
		end
	end
	for z = Z0 + 30, Z1 - 20, 30 do
		for _, s in { -1, 1 } do
			if Kit.IsFree(s * 106, z, 2.5) then
				column(f, s * 106, z)
			end
		end
	end
end

local function furniture(f: Instance)
	-- turnstile row across the entrance, leaving the lane, station and pad free
	for x = 12, 44, 4 do
		for _, s in { -1, 1 } do
			if Kit.IsFree(s * x, Z0 + 53, 2) then
				turnstile(f, s * x, Z0 + 53)
			end
		end
	end
	for x = 12, 44, 4 do
		for _, s in { -1, 1 } do
			Kit.AddCircle(s * x, Z0 + 53, 2)
		end
	end
	local benches: { { x: number, z: number, alongZ: boolean } } = {
		{ x = -96, z = Z0 + 70, alongZ = true }, { x = 96, z = Z0 + 100, alongZ = true }, { x = -96, z = Z0 + 180, alongZ = true },
		{ x = 96, z = Z0 + 250, alongZ = true }, { x = -40, z = Z0 + 300, alongZ = false }, { x = 40, z = Z0 + 300, alongZ = false },
		{ x = 96, z = Z0 + 320, alongZ = true }, { x = -30, z = Z0 + 175, alongZ = false },
	}
	for _, b in benches do
		if Kit.IsFree(b.x, b.z, 4.5) then
			bench(f, b.x, b.z, b.alongZ)
		end
	end
	for _, p in { { -60, Z0 + 52, 1 }, { 60, Z0 + 52, -1 }, { 100, Z0 + 140, -1 }, { -100, Z0 + 290, 1 } } do
		if Kit.IsFree(p[1], p[2], 2.6) then
			ticketMachine(f, p[1], p[2], p[3])
		end
	end
	for _, p in { { 34, Z0 + 230 }, { -34, Z0 + 140 } } do
		if Kit.IsFree(p[1], p[2], 6.5) then
			kiosk(f, p[1], p[2])
		end
	end
	for i, p in { { 98, Z0 + 60, -1 }, { 98, Z0 + 66, -1 }, { -98, Z0 + 230, 1 }, { 30, Z0 + 330, -1 }, { -98, Z0 + 330, 1 } } do
		if Kit.IsFree(p[1], p[2], 3) then
			vending(f, p[1], p[2], p[3], if i % 2 == 0 then C(220, 70, 80) else C(60, 120, 210))
		end
	end
	-- bins
	for _, p in { { -14, Z0 + 140 }, { 14, Z0 + 210 }, { -14, Z0 + 330 }, { 14, Z0 + 60 }, { 92, Z0 + 205 } } do
		if Kit.IsFree(p[1], p[2], 1.6) then
			Kit.Cyl(f, 3.4, 2.4, CFrame.new(p[1], 1.7, p[2]), C(60, 70, 85), { Mat = METAL, Solid = true })
			Kit.Cyl(f, 0.4, 2.6, CFrame.new(p[1], 3.6, p[2]), TEAL, STEEL_O)
			Kit.AddCircle(p[1], p[2], 1.6)
		end
	end
	-- subway map board on legs (coloured lines on cream)
	local mx, mz = 36, Z0 + 130
	if Kit.IsFree(mx, mz, 5) then
		local m = Kit.Model(f, "SubwayMap")
		for _, dx in { -5, 5 } do
			Kit.Box(m, V(mx + dx - 0.25, 0, mz - 0.25), V(mx + dx + 0.25, 4, mz + 0.25), STEEL_D, STEEL_O)
		end
		Kit.Box(m, V(mx - 6, 4, mz - 0.3), V(mx + 6, 11, mz + 0.3), TILE, { Solid = true })
		Kit.Box(m, V(mx - 6.4, 11, mz - 0.4), V(mx + 6.4, 11.6, mz + 0.4), TEAL, STEEL_O)
		local lines: { { col: Color3, y: number, tilt: number } } = {
			{ col = RED, y = 5.5, tilt = 0 }, { col = BLUE, y = 7.5, tilt = 0.5 }, { col = C(60, 180, 90), y = 9, tilt = -0.4 }, { col = YELLOW, y = 6.5, tilt = 0.9 },
		}
		for _, l in lines do
			Kit.Part(m, V(10, 0.35, 0.1), CFrame.new(mx, l.y, mz - 0.35) * CFrame.Angles(0, 0, l.tilt * 0.3), Kit.Vivid(l.col))
		end
		for i = -2, 2 do
			Kit.Ball(m, 0.6, V(mx + i * 2.2, 7.2 + (i % 2) * 0.8, mz - 0.4), C(255, 255, 255))
		end
		Kit.AddCircle(mx, mz, 6)
	end
	-- hanging station signs over the lane (outside the ghost areas)
	local signs: { { z: number, text: string, bg: Color3 } } = {
		{ z = Z0 + 40, text = "PLATFORM 13", bg = TEAL_D },
		{ z = Z0 + 150, text = "<  UPTOWN     DOWNTOWN  >", bg = C(40, 50, 80) },
		{ z = Z0 + 212, text = "MIND THE GAP", bg = C(200, 60, 60) },
		{ z = Z0 + 272, text = "LAST TRAIN: MIDNIGHT", bg = C(40, 50, 80) },
	}
	for _, sg in signs do
		hangingSign(f, 0, sg.z, sg.text, sg.bg)
	end
	-- steam vent grate with a soft mist
	local vx, vz = -120, Z0 + 200
	Kit.Box(f, V(vx - 3, 0, vz - 3), V(vx + 3, 0.1, vz + 3), C(50, 50, 60), STEEL_O)
	for k = -2, 2 do
		Kit.Box(f, V(vx - 2.6, 0.1, vz + k * 1.1 - 0.2), V(vx + 2.6, 0.16, vz + k * 1.1 + 0.2), C(90, 95, 110), STEEL_O)
	end
	local steam = Kit.Part(f, V(5, 1, 5), CFrame.new(vx, 1, vz), C(255, 255, 255), { Transp = 1, Name = "SteamVent" })
	Kit.Emitter(steam, C(220, 235, 240), 4, 5, 1.5)
	-- warm platform lamps under the side ceilings
	for i, p in { { -104, Z0 + 95 }, { 104, Z0 + 215 } } do
		local lamp = Kit.Box(f, V(p[1] - 0.5, ROOF - 0.6, p[2] - 4), V(p[1] + 0.5, ROOF, p[2] + 4), C(255, 245, 210), { Mat = NEON })
		if i <= 2 then
			Kit.Light(lamp, C(255, 240, 200), 36, 0.9)
		end
	end
end

-- Escalator up to a street exit, against the west wall at the back of the hall.
local function escalator(parent: Instance)
	local m = Kit.Model(parent, "Escalator")
	local x0, x1 = -134, -114
	local zb, zt, top = Z0 + 270, Z0 + 330, 30
	local len = math.sqrt((zt - zb) ^ 2 + top ^ 2)
	local ang = math.atan2(top, zt - zb)
	local cf = CFrame.new((x0 + x1) / 2, top / 2, (zb + zt) / 2) * CFrame.Angles(-ang, 0, 0)
	Kit.Part(m, V(x1 - x0 - 2, 1.6, len), cf, C(90, 95, 110), { Mat = METAL, Solid = true })
	-- step stripes
	for i = 1, 14 do
		Kit.Part(m, V(x1 - x0 - 3, 0.1, 0.4), cf * CFrame.new(0, 0.85, -len / 2 + i * len / 15), Kit.Vivid(YELLOW))
	end
	Kit.Part(m, V(0.4, 1.6, len), cf * CFrame.new(0, 0.85, 0), CONC_D, STEEL_O)
	for _, sx in { x0, x1 } do
		-- glass balustrades + black handrails
		Kit.Part(m, V(0.4, 3.6, len), CFrame.new(sx, top / 2 + 2.4, (zb + zt) / 2) * CFrame.Angles(-ang, 0, 0), C(200, 235, 255), { Mat = GLASS, Transp = 0.35 })
		Kit.Part(m, V(0.8, 0.5, len), CFrame.new(sx, top / 2 + 4.4, (zb + zt) / 2) * CFrame.Angles(-ang, 0, 0), DARK)
	end
	-- landing and the street exit in the wall
	Kit.Box(m, V(x0 - 6, top - 1.6, zt - 1), V(x1 + 2, top, Z1 - 4), CONC, { Mat = CONCRETE, Solid = true })
	Kit.Box(m, V(x0 - 6, 0, zt - 1), V(x1 + 2, top - 1.6, zt), TILE, { Mat = TILES, Solid = true })
	Kit.Box(m, V(-139.9, top, zt + 2), V(-139.5, top + 4, Z1 - 8), C(30, 25, 50))
	Props.SignBoard(m, V((x0 + x1) / 2, top + 7, zt + 1), 16, 3, 0, -1, "EXIT TO STREET", TEAL_D, C(255, 245, 220), TILE)
	Kit.AddRect(x0 - 6, zb - 3, x1 + 3, Z1 - 4)
end

-- Big departures board high over the far gate (bottom Y 44: clear of the gate arch).
local function departures(parent: Instance)
	local m = Kit.Model(parent, "DeparturesBoard")
	local z = Z1 - 8
	Kit.Box(m, V(-36, 44, z - 1), V(36, 60, z + 1), C(30, 32, 44), { Mat = METAL })
	Kit.Box(m, V(-37, 59.6, z - 1.3), V(37, 61, z + 1.3), TEAL, STEEL_O)
	local title = Kit.Part(m, V(40, 3, 0.2), CFrame.new(0, 57.4, z - 1.1), C(30, 32, 44), { Name = "SignBoard" })
	Kit.Sign(title, Enum.NormalId.Front, "DEPARTURES", Kit.Vivid(YELLOW))
	for i, txt in { "MIDNIGHT  .  PHANTOM LINE  .  ON TIME", "00:13  .  NEON CITY  .  BOARDING", "??:??  .  NOWHERE  .  BOO!" } do
		local row = Kit.Part(m, V(66, 2.6, 0.2), CFrame.new(0, 54 - i * 3.2, z - 1.1), C(20, 22, 30), { Name = "SignBoard" })
		Kit.Sign(row, Enum.NormalId.Front, txt, if i == 3 then C(255, 150, 120) else C(255, 225, 120))
	end
	for _, sx in { -30, 30 } do
		Kit.Box(m, V(sx - 0.4, 61, z - 0.4), V(sx + 0.4, 70, z + 0.4), GIRDER, STEEL_O)
	end
end

local function trains(f: Instance)
	train(f, -122, Z0 + 52, 3, -1)
	train(f, 122, Z0 + 196, 3, 1)
	-- a ghostly floating ticket or two drifting over the platforms
	for i, p in { V(-50, 18, Z0 + 140), V(52, 22, Z0 + 260), V(-20, 26, Z0 + 60), V(88, 16, Z0 + 120) } do
		local t = Kit.Part(f, V(2.6, 0.15, 1.4), CFrame.new(p) * CFrame.Angles(0.3, i, 0.2), C(255, 235, 170), { Name = "FloatingTicket" })
		Kit.Float(t, 1.2)
	end
end

--==================================================================
-- BUILD
--==================================================================
function GhostSubway.Build(map: Instance)
	local f = Kit.Folder(map, "GhostSubway")
	ground(f)
	walls(f)
	roof(f)
	trains(f)
	escalator(f)
	departures(f)
	columns(f)
	furniture(f)
end

return GhostSubway
