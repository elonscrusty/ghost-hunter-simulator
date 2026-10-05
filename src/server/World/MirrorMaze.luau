--!strict
-- ZONE 22: Mirror Maze (Z 8800..9160). A cool, calm labyrinth of glass and mirror panels on a
-- polished ice-blue tiled floor: silver frames, frosted glass, pale lilac tints and a few small
-- prism rainbows. No carnival bits: this is a crystal palace, not a funhouse.
--   Ground: pale polished floor with a silver tile grid; frosted-white lane along X = 0 with
--   ice-blue edging. Ghost areas get flat kaleidoscope rosettes ((0,8885) r30, (-82,8920) r24,
--   (75,8980) r26, (-62,9040) r24); the boss area (0,9105) r26 is a big mirror disc with a
--   12-point star, ringed (outside the circle) by a broken circle of tall mirror panels.
--   The maze: a 16-stud grid (X -136..136, Z 8828..9148) carved as a perfect maze with a third
--   of the walls knocked out (braided), so every spot stays reachable. A wall is only built
--   where its whole length is clear of the keep-outs (lane, ghost areas, crate station, Fast
--   Travel pad, gate), so those always stay open.
--   Landmark: the Crystal Spire at (112, 9100), stacked glass diamonds up to Y ~72.
--   Also: round looking-glass mirrors on stands along the lane, crystal-globe lamps, glass
--   prisms casting flat rainbow fans, floating mirror shards, crystal clusters outside the walls.

local Kit = require(script.Parent.Kit)

local MirrorMaze = {}

local C = Color3.fromRGB
local V = Vector3.new
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local MARBLE = Enum.Material.Marble

local Z0, Z1 = 8800, 9160

local FLOOR = C(200, 212, 232)
local FLOOR_L = C(225, 233, 246)
local GRID = C(160, 178, 210)
local SILVER = C(200, 208, 222)
local SILVER_D = C(140, 152, 178)
local ICE = C(185, 222, 255)
local MIRROR = C(222, 236, 250)
local LILAC = C(205, 195, 245)
local FROST = C(242, 247, 255)

local SILVER_M: Kit.Opts = { Mat = METAL, Refl = 0.25 }
local SOLID_SILVER: Kit.Opts = { Mat = METAL, Refl = 0.25, Solid = true }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

-- own RNG so the maze never shifts when other zones add or remove random props
local rng = Random.new(2121)

--==================================================================
-- HELPERS
--==================================================================
-- A framed panel standing on the ground between (x1, z1) and (x2, z2). Mirror panels are
-- silver and reflective; glass panels are frosted ice blue / lilac.
local function panel(parent: Instance, x1: number, z1: number, x2: number, z2: number, h: number, kind: number, solid: boolean)
	local a, b = V(x1, 0, z1), V(x2, 0, z2)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid + V(0, h / 2, 0), b + V(0, h / 2, 0))
	local col, opts: Kit.Opts
	if kind == 1 then
		col, opts = MIRROR, { Refl = 0.5, Solid = solid }
	elseif kind == 2 then
		col, opts = ICE, { Mat = GLASS, Transp = 0.25, Refl = 0.2, Solid = solid }
	else
		col, opts = LILAC, { Mat = GLASS, Transp = 0.25, Refl = 0.2, Solid = solid }
	end
	Kit.Part(parent, V(0.6, h - 0.6, len - 0.6), cf * CFrame.new(0, -0.3, 0), col, opts)
	Kit.Part(parent, V(0.9, 0.6, len), cf * CFrame.new(0, h / 2 - 0.3, 0), SILVER, SILVER_M)
end

local function post(parent: Instance, x: number, z: number, h: number)
	Kit.Box(parent, V(x - 0.7, 0, z - 0.7), V(x + 0.7, h + 0.4, z + 0.7), SILVER, SOLID_SILVER)
	Kit.Part(parent, V(1.3, 1.3, 1.3), CFrame.new(x, h + 1.3, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), ICE, { Mat = GLASS, Transp = 0.1, Refl = 0.3 })
end

-- Round looking-glass on a silver stand, facing (fx, 0).
local function lookingGlass(parent: Instance, x: number, z: number, fx: number)
	local m = Kit.Model(parent, "LookingGlass")
	Kit.Box(m, V(x - 1.6, 0, z - 1.6), V(x + 1.6, 0.6, z + 1.6), SILVER_D, SOLID_SILVER)
	Kit.Box(m, V(x - 0.3, 0.6, z - 0.3), V(x + 0.3, 4, z + 0.3), SILVER, SILVER_M)
	local c = V(x, 8, z)
	Kit.CylFlat(m, 0.5, 8.4, c, "X", SILVER, SILVER_M)
	Kit.CylFlat(m, 0.6, 7.4, c + V(fx * 0.06, 0, 0), "X", MIRROR, { Refl = 0.6 })
	for i = 0, 5 do
		local a = i * math.pi / 3
		Kit.Ball(m, 0.8, c + V(fx * 0.3, math.sin(a) * 4.2, math.cos(a) * 4.2), if i % 2 == 0 then ICE else LILAC, { Refl = 0.2 })
	end
	Kit.Part(m, V(0.6, 1.6, 1.6), CFrame.new(c + V(fx * 0.3, 4.9, 0)) * CFrame.Angles(math.pi / 4, 0, 0), ICE, { Mat = GLASS, Refl = 0.3 })
	Kit.AddCircle(x, z, 2.5)
end

local function crystalLamp(parent: Instance, x: number, z: number, light: boolean)
	Kit.Cyl(parent, 0.8, 2, CFrame.new(x, 0.4, z), SILVER_D, SILVER_M)
	Kit.Cyl(parent, 11, 0.6, CFrame.new(x, 6, z), SILVER, SILVER_M)
	local globe = Kit.Part(parent, V(2, 2, 2), CFrame.new(x, 12.4, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C(225, 240, 255), { Mat = GLASS, Transp = 0.05, Refl = 0.2 })
	Kit.Cyl(parent, 0.3, 1.6, CFrame.new(x, 11.4, z), SILVER, SILVER_M)
	if light then
		Kit.Light(globe, C(200, 230, 255), 22, 0.9)
	end
	Kit.AddCircle(x, z, 1.5)
end

-- Crystal cluster: a few tilted glass shards.
local function crystals(parent: Instance, x: number, z: number, scale: number)
	local m = Kit.Model(parent, "Crystals")
	for i = 1, 4 do
		local h = rng:NextNumber(4, 8) * scale * (if i == 1 then 1.4 else 1)
		local w = rng:NextNumber(1.4, 2.4) * scale
		local p = V(x + rng:NextNumber(-2, 2) * scale, h / 2 - 0.5, z + rng:NextNumber(-2, 2) * scale)
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 1.5), rng:NextNumber(-0.35, 0.35)) * CFrame.Angles(0, math.pi / 4, 0)
		Kit.Part(m, V(w, h, w), cf, if i % 2 == 0 then LILAC else ICE, { Mat = GLASS, Transp = 0.15, Refl = 0.25 })
		Kit.Part(m, V(w * 0.7, w * 0.7, w * 0.7), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), FROST, { Mat = GLASS, Transp = 0.1, Refl = 0.25 })
	end
	Kit.AddCircle(x, z, 4 * scale)
end

-- A glass prism on a pedestal casting a flat rainbow fan toward (fx, fz) (flat floor bars).
local RAINBOW = { C(255, 150, 160), C(255, 195, 140), C(255, 235, 150), C(160, 235, 170), C(150, 200, 255), C(195, 165, 255) }
local function prism(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "Prism")
	local yaw = Kit.FaceYaw(fx, fz)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(m, V(4, 2.4, 4), base * CFrame.new(0, 1.2, 0), FLOOR_L, { Mat = MARBLE, Solid = true })
	Kit.Part(m, V(4.4, 0.4, 4.4), base * CFrame.new(0, 2.6, 0), SILVER, SILVER_M)
	-- triangular glass prism: two wedges back to back
	for _, s in { -1, 1 } do
		Kit.Wedge(m, V(3.2, 4, 1.5), base * CFrame.new(0, 4.8, s * 0.75) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0), C(235, 245, 255), { Mat = GLASS, Transp = 0.2, Refl = 0.3 })
	end
	for i, col in RAINBOW do
		local a = (i - 3.5) * 0.09
		local cf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.03 + i * 0.004, -11)
		Kit.Part(m, V(1.3, 0.04, 16), cf, col)
	end
	Kit.AddCircle(x, z, 3.5)
end

--==================================================================
-- GROUND, WALLS, OUTSIDE
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-146, -4, Z0), V(146, 0, Z1), FLOOR, { Mat = MARBLE, Solid = true, Refl = 0.1, Name = "Ground_MirrorMaze" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 146, -4.5, Z0), V(s * 200, -0.5, Z1), C(120, 140, 190), { Mat = GLASS, Solid = true, Refl = 0.2 })
	end
	-- silver tile grid (flat lines)
	for x = -128, 128, 16 do
		if math.abs(x) > 12 then
			Kit.Box(f, V(x - 0.25, 0, Z0 + 4), V(x + 0.25, 0.03, Z1 - 4), GRID, SILVER_M)
		end
	end
	for z = Z0 + 12, Z1 - 8, 16 do
		Kit.Box(f, V(-138, 0, z - 0.25), V(138, 0.03, z + 0.25), GRID, SILVER_M)
	end
	-- lane
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), FROST, { Mat = MARBLE, Solid = true, Refl = 0.15, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.6, 0.07, Z1), Kit.Vivid(ICE), { Refl = 0.2 })
	end
	-- little diamond inlays down the lane
	for z = Z0 + 20, Z1 - 20, 40 do
		Kit.Part(f, V(3, 0.03, 3), CFrame.new(0, 0.06, z) * CFrame.Angles(0, math.pi / 4, 0), ICE, { Refl = 0.3 })
	end
	-- kaleidoscope rosettes on the ghost areas
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.08, r * 2 + 3, 0.08, SILVER, SILVER_M)
		Kit.Disc(f, x, z, 0.11, r * 2, 0.11, if i % 2 == 0 then C(215, 225, 245) else FLOOR_L, { Mat = MARBLE, Refl = 0.15 })
		local petals = if i % 2 == 0 then 6 else 8
		for k = 0, petals - 1 do
			local ang = k * 2 * math.pi / petals
			local px, pz = x + math.cos(ang) * r * 0.5, z + math.sin(ang) * r * 0.5
			Kit.Part(f, V(r * 0.32, 0.03, r * 0.32), CFrame.new(px, 0.13, pz) * CFrame.Angles(0, -ang + math.pi / 4, 0), if k % 2 == 0 then Kit.Vivid(ICE) else Kit.Vivid(LILAC), { Refl = 0.2 })
		end
		Kit.Disc(f, x, z, 0.15, r * 0.5, 0.03, SILVER, SILVER_M)
		Kit.Disc(f, x, z, 0.17, r * 0.3, 0.03, MIRROR, { Refl = 0.5 })
	end
	-- boss: the great mirror with a 12-point star
	Kit.Disc(f, 0, BOSS_Z, 0.08, 58, 0.08, SILVER, SILVER_M)
	Kit.Disc(f, 0, BOSS_Z, 0.11, 54, 0.11, MIRROR, { Refl = 0.45 })
	Kit.Disc(f, 0, BOSS_Z, 0.14, 40, 0.03, Kit.Vivid(ICE), { Refl = 0.2 })
	Kit.Disc(f, 0, BOSS_Z, 0.16, 38, 0.05, C(230, 238, 252), { Refl = 0.4 })
	for k = 0, 11 do
		local ang = k * math.pi / 6
		local len = if k % 2 == 0 then 18 else 12
		local cf = CFrame.new(math.cos(ang) * len / 2, 0.18, BOSS_Z + math.sin(ang) * len / 2) * CFrame.Angles(0, -ang, 0)
		Kit.Part(f, V(len, 0.03, if k % 2 == 0 then 1.6 else 1.1), cf, if k % 2 == 0 then Kit.Vivid(LILAC) else Kit.Vivid(ICE), { Refl = 0.2 })
	end
	Kit.Disc(f, 0, BOSS_Z, 0.2, 6, 0.03, SILVER, SILVER_M)
end

local function sideWalls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 18, z1), SILVER_D, { Mat = METAL, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.5, 18, z0), V(s * 146.5, 19, z1), SILVER, SILVER_M)
		local n = 0
		for z = z0 + 4, z1 - 36, 36 do
			n += 1
			-- inset mirror / glass panels facing the maze
			Kit.Box(f, V(s * 139.6, 2, z + 1), V(s * 140, 16, z + 35), if n % 2 == 0 then MIRROR else ICE, if n % 2 == 0 then { Refl = 0.5 } else { Mat = GLASS, Refl = 0.25 })
			Kit.Box(f, V(s * 139, 0, z - 1), V(s * 141, 20, z + 1), SILVER, SOLID_SILVER)
			Kit.Part(f, V(2.2, 2.2, 2.2), CFrame.new(s * 140, 21.6, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), ICE, { Mat = GLASS, Transp = 0.1, Refl = 0.3 })
		end
	end
end

local function outside(f: Instance)
	-- icy crystal ridges beyond the walls (seen over the wall tops)
	for i = 0, 7 do
		local z = Z0 + 25 + i * 46
		for _, s in { -1, 1 } do
			local x = s * rng:NextNumber(158, 182)
			local h = rng:NextNumber(26, 50)
			local w = rng:NextNumber(8, 14)
			local cf = CFrame.new(x, h / 2 - 4, z + s * 8) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 1.5), s * 0.2) * CFrame.Angles(0, math.pi / 4, 0)
			Kit.Part(f, V(w, h, w), cf, if i % 2 == 0 then ICE else LILAC, { Mat = GLASS, Transp = 0.1, Refl = 0.3 })
			Kit.Part(f, V(w * 0.7, w * 0.7, w * 0.7), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), FROST, { Mat = GLASS, Refl = 0.3 })
			Kit.Part(f, V(w * 0.6, h * 0.6, w * 0.6), CFrame.new(x + s * 9, h * 0.3 - 4, z - s * 6) * CFrame.Angles(0.2, 0.7, -s * 0.3), MIRROR, { Mat = GLASS, Transp = 0.15, Refl = 0.3 })
		end
	end
end

--==================================================================
-- LANDMARKS AND DECOR
--==================================================================
local function bossRing(f: Instance)
	-- broken circle of tall mirror panels just outside the boss circle, facing in
	local R = 34
	for k = 0, 15 do
		local ang = (k + 0.5) * math.pi / 8
		local x, z = math.cos(ang) * R, BOSS_Z + math.sin(ang) * R
		if Kit.IsFree(x, z, 2.5) then
			local t = V(-math.sin(ang), 0, math.cos(ang)) * 4.5
			panel(f, x - t.X, z - t.Z, x + t.X, z + t.Z, 16, if k % 3 == 0 then 1 else (if k % 3 == 1 then 2 else 3), true)
			post(f, x - t.X, z - t.Z, 16)
			post(f, x + t.X, z + t.Z, 16)
			Kit.AddCircle(x, z, 5)
		end
	end
end

local function spire(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "CrystalSpire")
	Kit.Cyl(m, 3, 22, CFrame.new(x, 1.5, z), FLOOR_L, { Mat = MARBLE, Solid = true, Shadow = true })
	Kit.Cyl(m, 0.6, 23, CFrame.new(x, 3.2, z), SILVER, SILVER_M)
	Kit.Cyl(m, 6, 14, CFrame.new(x, 6.5, z), SILVER_D, { Mat = METAL, Refl = 0.25, Solid = true })
	local y = 9.5
	local sizes = { 13, 11, 9, 7.5, 6, 4.5 }
	for i, s in sizes do
		local cy = y + s * 0.7
		Kit.Part(m, V(s, s, s), CFrame.new(x, cy, z) * CFrame.Angles(math.pi / 4, i * 0.4, math.pi / 4), if i % 2 == 0 then LILAC else ICE, { Mat = GLASS, Transp = 0.12, Refl = 0.3, Shadow = true })
		y = cy + s * 0.7 - 1
		if i < #sizes then
			Kit.Cyl(m, 2, s * 0.35, CFrame.new(x, y, z), SILVER, SILVER_M)
		end
	end
	local top = Kit.Part(m, V(2.4, 6, 2.4), CFrame.new(x, y + 3.6, z) * CFrame.Angles(0, math.pi / 4, 0), FROST, { Mat = GLASS, Refl = 0.4 })
	Kit.Light(top, C(200, 230, 255), 40, 1.1)
	local sparkle = Kit.Part(m, V(14, 30, 14), CFrame.new(x, 40, z), FROST, { Transp = 1, Name = "SparkleSource" })
	Kit.Emitter(sparkle, C(220, 240, 255), 3, 1.6, 0.8)
	-- orbiting floating shards
	for i = 0, 3 do
		local a = i * math.pi / 2
		local shard = Kit.Part(m, V(0.4, 5, 3), CFrame.new(x + math.cos(a) * 12, 24 + i * 9, z + math.sin(a) * 12) * CFrame.Angles(0, -a, 0.3), MIRROR, { Refl = 0.6, Name = "FloatingShard" })
		Kit.Float(shard, 1.4)
	end
	Kit.AddCircle(x, z, 13)
end

local function decor(f: Instance)
	-- looking-glass mirrors and crystal lamps along the lane
	for i, z in { Z0 + 40, Z0 + 140, Z0 + 200, Z0 + 270, Z0 + 340 } do
		for _, s in { -1, 1 } do
			if Kit.IsFree(s * 16, z, 2.5) then
				lookingGlass(f, s * 16, z, -s)
			end
			if Kit.IsFree(s * 14, z + 18, 1.5) then
				crystalLamp(f, s * 14, z + 18, i % 2 == 1 and s > 0)
			end
		end
	end
	for _, p in { { -120, Z0 + 60, 1, 0.2 }, { 118, Z0 + 110, -1, 0.3 }, { -112, Z0 + 300, 1, -0.4 }, { 40, Z0 + 250, 1, 0.6 } } do
		if Kit.IsFree(p[1], p[2], 3.5) then
			prism(f, p[1], p[2], p[3], p[4])
		end
	end
	for _, p in { { -126, Z0 + 180 }, { 126, Z0 + 230 }, { -40, Z0 + 330 }, { 128, Z0 + 40 }, { -128, Z0 + 340 }, { 60, Z0 + 120 } } do
		if Kit.IsFree(p[1], p[2], 4) then
			crystals(f, p[1], p[2], 1)
		end
	end
	-- floating mirror shards drifting above the maze (single tagged parts, high over ghost areas)
	for i, p in { V(-40, 26, Z0 + 110), V(46, 30, Z0 + 150), V(-100, 24, Z0 + 210), V(104, 28, Z0 + 280), V(-30, 32, Z0 + 280), V(90, 22, Z0 + 60) } do
		local shard = Kit.Part(f, V(0.4, 6, 3.6), CFrame.new(p) * CFrame.Angles(0, i * 0.9, 0.35), if i % 2 == 0 then MIRROR else ICE, { Refl = 0.55, Name = "FloatingShard" })
		Kit.Float(shard, 1.6)
	end
end

--==================================================================
-- THE MAZE
--==================================================================
local GX0, GZ0, CELL = -136, Z0 + 28, 16
local NX, NZ = 17, 20

local function segFree(x1: number, z1: number, x2: number, z2: number): boolean
	local n = 8
	for i = 0, n do
		local t = i / n
		local x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
		-- the outer edge of the grid is the side wall: test those points a little inward
		local cx = math.clamp(x, -134, 134)
		if not Kit.IsFree(cx, z, 1.6) then
			return false
		end
	end
	return true
end

local function maze(f: Instance)
	local m = Kit.Model(f, "Maze")
	-- walls: v[i][j] = wall on the west side of cell (i, j) (i = 1..NX+1), h[i][j] = wall on
	-- the south side of cell (i, j) (j = 1..NZ+1). Start with every wall, carve a perfect maze.
	local v: { { boolean } } = {}
	local hz: { { boolean } } = {}
	for i = 1, NX + 1 do
		v[i] = {}
		hz[i] = {}
		for j = 1, NZ + 1 do
			v[i][j] = true
			hz[i][j] = true
		end
	end
	local seen: { [number]: boolean } = {}
	local stack = { { 9, 1 } }
	seen[9 * 100 + 1] = true
	while #stack > 0 do
		local top = stack[#stack]
		local i, j = top[1], top[2]
		local opts = {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = i + d[1], j + d[2]
			if ni >= 1 and ni <= NX and nj >= 1 and nj <= NZ and not seen[ni * 100 + nj] then
				table.insert(opts, d)
			end
		end
		if #opts == 0 then
			table.remove(stack)
		else
			local d = opts[rng:NextInteger(1, #opts)]
			local ni, nj = i + d[1], j + d[2]
			if d[1] == 1 then
				v[i + 1][j] = false
			elseif d[1] == -1 then
				v[i][j] = false
			elseif d[2] == 1 then
				hz[i][j + 1] = false
			else
				hz[i][j] = false
			end
			seen[ni * 100 + nj] = true
			table.insert(stack, { ni, nj })
		end
	end
	-- build interior walls (skip the outer border: side walls / gates frame the maze). A few
	-- walls are knocked out so the maze stays easy to cross on a phone; collinear walls merge
	-- into one long panel (fewer parts), with a slim post at every grid node.
	local posts: { [number]: boolean } = {}
	local runs = 0
	local function addPost(x: number, z: number, cap: boolean)
		local k = math.floor(x + 1000) * 100000 + math.floor(z)
		if not posts[k] then
			posts[k] = true
			Kit.Box(m, V(x - 0.6, 0, z - 0.6), V(x + 0.6, 10.4, z + 0.6), SILVER, SOLID_SILVER)
			if cap then
				Kit.Part(m, V(1.2, 1.2, 1.2), CFrame.new(x, 11.2, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), ICE, { Mat = GLASS, Transp = 0.1, Refl = 0.3 })
			end
		end
	end
	local function flush(pts: { Vector3 })
		if #pts < 2 then
			return
		end
		runs += 1
		local a, b = pts[1], pts[#pts]
		panel(m, a.X, a.Z, b.X, b.Z, 10, (runs % 3) + 1, true)
		addPost(a.X, a.Z, runs % 2 == 0)
		addPost(b.X, b.Z, runs % 2 == 1)
		Kit.AddRect(math.min(a.X, b.X) - 1, math.min(a.Z, b.Z) - 1, math.max(a.X, b.X) + 1, math.max(a.Z, b.Z) + 1)
	end
	local function line(points: { Vector3 }, has: { boolean })
		-- points[k]..points[k+1] is wall k when has[k]
		local cur: { Vector3 } = {}
		for k = 1, #has do
			local a, b = points[k], points[k + 1]
			if has[k] and rng:NextNumber() >= 0.15 and segFree(a.X, a.Z, b.X, b.Z) and #cur < 4 then
				if #cur == 0 then
					table.insert(cur, a)
				end
				table.insert(cur, b)
			else
				flush(cur)
				cur = {}
			end
		end
		flush(cur)
	end
	for i = 2, NX do
		local x = GX0 + (i - 1) * CELL
		local pts, has = {}, {}
		for j = 1, NZ + 1 do
			table.insert(pts, V(x, 0, GZ0 + (j - 1) * CELL))
		end
		for j = 1, NZ do
			has[j] = v[i][j]
		end
		line(pts, has)
	end
	for j = 2, NZ do
		local z = GZ0 + (j - 1) * CELL
		local pts, has = {}, {}
		for i = 1, NX + 1 do
			table.insert(pts, V(GX0 + (i - 1) * CELL, 0, z))
		end
		for i = 1, NX do
			has[i] = hz[i][j]
		end
		line(pts, has)
	end
end

--==================================================================
-- BUILD
--==================================================================
function MirrorMaze.Build(map: Instance)
	local f = Kit.Folder(map, "MirrorMaze")
	ground(f)
	sideWalls(f)
	outside(f)
	bossRing(f)
	spire(f, 112, Z0 + 300)
	decor(f)
	maze(f)
end

return MirrorMaze
