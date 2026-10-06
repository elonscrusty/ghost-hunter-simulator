--!strict
-- ZONE 29: Cyber Arcade Dimension (Z 11320..11680). Inside a retro video game: everything is
-- built from flat-coloured blocks and voxels on a dark grid floor. Glow is kept to small neon
-- accents (marquee strips, coin slots); screens and signs are solid colours.
--   Ground: navy floor (top Y 0) with a 16-stud grid and some coloured "lit" tiles; the lane
--   along X = 0 is a road of orange/brown blocks (top Y 0.2) that stops at the square arenas.
--   Ghost areas get flat pixel art: nested squares at (0,11405) r30, a checkerboard at
--   (-82,11440) r24, a pixel ring at (75,11500) r26 and a diamond at (-62,11560) r24; the boss
--   area (0,11625) r26 is a black "GAME OVER" square with a red border and a big voxel heart
--   floating high above it (bottom Y 52).
--   Edges: block walls at |X| 140..146 (top Y 12, coloured battlements). Beyond them stand giant
--   arcade cabinets (7, ~84 tall, pixel sprites on the screens, joystick and buttons on the
--   deck) and the HIGH SCORES board (X 150, Z 11540).
--   Props: floating coin blocks (one row over the lane at Z 11470, Y 14), spinning coins, pipes,
--   8-bit trees and bushes, power-up boxes, a block staircase, a giant joystick with two big
--   buttons, cube clouds and a square pixel sun.

local Kit = require(script.Parent.Kit)

local CyberArcade = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

local Z0, Z1 = 11320, 11680

local FLOOR = C(26, 22, 62)
local GRID = C(70, 95, 185)
local ROAD1 = C(232, 128, 60)
local ROAD2 = C(186, 88, 44)
local BRICK = C(196, 92, 52)
local BRICK_D = C(120, 52, 30)
local GOLD = C(255, 200, 40)
local GOLD_D = C(205, 140, 20)
local CYAN = C(70, 230, 230)
local PINK = C(255, 80, 190)
local PURPLE = C(140, 80, 240)
local YELLOW = C(255, 225, 60)
local GREEN = C(70, 200, 80)
local GREEN_D = C(40, 140, 60)
local GREEN_L = C(140, 240, 110)
local RED = C(240, 60, 60)
local WHITE = C(250, 250, 255)
local BLACK = C(16, 14, 22)
local TRUNK = C(140, 85, 45)

local SOLID: Kit.Opts = { Mat = SMOOTH, Solid = true, Shadow = true }
local FLAT: Kit.Opts = { Mat = SMOOTH }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

local rng = Random.new(2929)

--==================================================================
-- HELPERS
--==================================================================
-- Draws a bitmap (rows of characters, top row first) as flat boxes on a vertical plane.
-- origin = centre of the picture; along = the horizontal axis on the plane (unit X or Z);
-- normal = the direction the picture faces. Runs of the same character merge into one box.
local function sprite(parent: Instance, origin: Vector3, along: Vector3, normal: Vector3, cell: number, rows: { string }, cols: { [string]: Color3 }, depth: number?, opts: Kit.Opts?)
	local h = #rows
	local w = #rows[1]
	local d = depth or 0.2
	for r = 1, h do
		local row = rows[r]
		local c = 1
		while c <= w do
			local ch = string.sub(row, c, c)
			local e = c
			while e < w and string.sub(row, e + 1, e + 1) == ch do
				e += 1
			end
			local col = cols[ch]
			if col then
				local u0 = (c - 1 - w / 2) * cell
				local u1 = (e - w / 2) * cell
				local y = (h / 2 - r + 0.5) * cell
				local mid = origin + along * ((u0 + u1) / 2) + V(0, y, 0) + normal * (d / 2)
				local len = u1 - u0
				local size = V(math.abs(along.X) * len + math.abs(normal.X) * d, cell, math.abs(along.Z) * len + math.abs(normal.Z) * d)
				Kit.Part(parent, size, CFrame.new(mid), col, opts or FLAT)
			end
			c = e + 1
		end
	end
end

local SPRITES: { { string } } = {
	{ ".XXXXX.", "XXXXXXX", "XOXXXOX", "XXXXXXX", "XXXXXXX", "X.X.X.X" }, -- ghost
	{ "..X.X..", "..XXX..", ".XOXOX.", "XXXXXXX", "X.XXX.X", "..X.X.." }, -- bug alien
	{ "...X...", "..XXX..", "..XOX..", ".XXXXX.", "XXXXXXX", "X.X.X.X" }, -- rocket ship
	{ ".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..." }, -- heart
}

local function coinBlock(parent: Instance, x: number, y: number, z: number, gold: boolean)
	local s = 6
	if gold then
		Kit.Box(parent, V(x - s / 2, y, z - s / 2), V(x + s / 2, y + s, z + s / 2), GOLD, { Mat = SMOOTH, Solid = true, Name = "CoinBlock" })
		for _, dz in { -1, 1 } do
			Kit.CylFlat(parent, 0.3, 3.6, V(x, y + s / 2, z + dz * (s / 2 + 0.1)), "Z", GOLD_D)
			Kit.Box(parent, V(x - 0.4, y + s / 2 - 1.1, z + dz * (s / 2 + 0.2) - 0.1), V(x + 0.4, y + s / 2 + 1.1, z + dz * (s / 2 + 0.2) + 0.1), WHITE)
		end
		-- dark rivets in the corners (front and back)
		for _, dz in { -1, 1 } do
			for _, dx in { -2.2, 2.2 } do
				for _, dy in { 0.8, s - 0.8 } do
					Kit.Box(parent, V(x + dx - 0.35, y + dy - 0.35, z + dz * (s / 2) - 0.05), V(x + dx + 0.35, y + dy + 0.35, z + dz * (s / 2) + 0.05), GOLD_D)
				end
			end
		end
	else
		Kit.Box(parent, V(x - s / 2, y, z - s / 2), V(x + s / 2, y + s, z + s / 2), BRICK, { Mat = SMOOTH, Solid = true, Name = "BrickBlock" })
		for _, dz in { -1, 1 } do
			Kit.Box(parent, V(x - s / 2, y + s / 2 - 0.2, z + dz * (s / 2) - 0.05), V(x + s / 2, y + s / 2 + 0.2, z + dz * (s / 2) + 0.05), BRICK_D)
			Kit.Box(parent, V(x - 0.2, y + s / 2, z + dz * (s / 2) - 0.05), V(x + 0.2, y + s, z + dz * (s / 2) + 0.05), BRICK_D)
		end
	end
end

local function pixelTree(parent: Instance, x: number, z: number, h: number)
	local m = Kit.Model(parent, "PixelTree")
	Kit.Box(m, V(x - 1.5, 0, z - 1.5), V(x + 1.5, h, z + 1.5), TRUNK, SOLID)
	Kit.Box(m, V(x - 6.5, h, z - 6.5), V(x + 6.5, h + 5, z + 6.5), GREEN_D, FLAT)
	Kit.Box(m, V(x - 5, h + 5, z - 5), V(x + 5, h + 9, z + 5), GREEN, FLAT)
	Kit.Box(m, V(x - 3, h + 9, z - 3), V(x + 3, h + 12, z + 3), GREEN_L, FLAT)
	for _, d in { { -4, -4 }, { 4, 4 } } do
		Kit.Box(m, V(x + d[1] - 1, h + 9, z + d[2] - 1), V(x + d[1] + 1, h + 11, z + d[2] + 1), GREEN_L, FLAT)
	end
	Kit.Box(m, V(x - 7, h + 1, z + 2), V(x - 6.5, h + 3, z + 4), RED, FLAT) -- a pixel apple
	Kit.AddCircle(x, z, 7)
end

local function bush(parent: Instance, x: number, z: number)
	Kit.Box(parent, V(x - 5, 0, z - 3), V(x + 5, 3, z + 3), GREEN, FLAT)
	Kit.Box(parent, V(x - 3, 3, z - 2.5), V(x + 3, 5, z + 2.5), GREEN_L, FLAT)
	Kit.Box(parent, V(x + 2, 3, z - 2), V(x + 4, 4, z + 2), GREEN_D, FLAT)
	Kit.AddCircle(x, z, 5.5)
end

local function pipe(parent: Instance, x: number, z: number, h: number, col: Color3)
	local m = Kit.Model(parent, "Pipe")
	local dark = col:Lerp(BLACK, 0.35)
	Kit.Cyl(m, h, 10, CFrame.new(x, h / 2, z), col, SOLID)
	Kit.Cyl(m, 3, 13, CFrame.new(x, h + 1.5, z), col, SOLID)
	Kit.Disc(m, x, z, h + 3.05, 9, 0.1, BLACK)
	-- highlight and shade stripes
	Kit.Box(m, V(x - 3.6, 0, z - 4.8), V(x - 2.4, h, z - 4.6), col:Lerp(WHITE, 0.4), FLAT)
	Kit.Box(m, V(x + 2.4, 0, z - 4.8), V(x + 3.6, h, z - 4.6), dark, FLAT)
	Kit.AddCircle(x, z, 7.5)
end

local function powerBox(parent: Instance, x: number, z: number, yaw: number)
	local m = Kit.Model(parent, "PowerUpBox")
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local cols = { PINK, YELLOW, CYAN }
	for i, col in cols do
		Kit.Part(m, V(6, 2, 6), cf * CFrame.new(0, i * 2 - 1, 0), col, if i == 1 then SOLID else FLAT)
	end
	local face = Kit.Part(m, V(5.4, 4, 0.1), cf * CFrame.new(0, 3, -3.06), WHITE, { Transp = 1, Name = "SignBoard" })
	Kit.Sign(face, Enum.NormalId.Front, "UP!", WHITE, { Stroke = PURPLE })
	Kit.Part(m, V(6.4, 0.6, 6.4), cf * CFrame.new(0, 6.3, 0), WHITE, FLAT)
	Kit.AddCircle(x, z, 5)
end

--==================================================================
-- GROUND
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-146, -4, Z0), V(146, 0, Z1), FLOOR, { Mat = SMOOTH, Solid = true, Name = "Ground_CyberArcade" })
	for x = -144, 144, 16 do
		Kit.Box(f, V(x - 0.3, 0, Z0), V(x + 0.3, 0.02, Z1), GRID, FLAT)
	end
	for z = Z0 + 8, Z1, 16 do
		Kit.Box(f, V(-146, 0, z - 0.3), V(146, 0.02, z + 0.3), GRID, FLAT)
	end
	-- coloured "lit" floor tiles in some grid cells (away from the lane and the arenas)
	local tileCols = { C(110, 50, 150), C(40, 110, 140), C(150, 60, 110), C(60, 70, 160) }
	local n = 0
	for _ = 1, 160 do
		if n >= 30 then
			break
		end
		local cx = -144 + 8 + rng:NextInteger(0, 17) * 16
		local cz = Z0 + 16 + rng:NextInteger(0, 20) * 16
		if math.abs(cx) > 20 and Kit.IsFree(cx, cz, 8, true) then
			n += 1
			Kit.Box(f, V(cx - 7.6, 0, cz - 7.6), V(cx + 7.6, 0.03, cz + 7.6), tileCols[n % #tileCols + 1], FLAT)
		end
	end
	-- the lane: blocky road, broken by the square arenas
	local a1z, bz = AREAS[1][2], BOSS_Z
	local i = 0
	for z = Z0, Z1 - 8, 8 do
		i += 1
		local inA1 = z + 8 > a1z - 30 and z < a1z + 30
		local inBoss = z + 8 > bz - 30 and z < bz + 30
		if not inA1 and not inBoss then
			Kit.Box(f, V(-8, 0, z), V(8, 0.2, z + 8), if i % 2 == 0 then ROAD1 else ROAD2, { Mat = SMOOTH, Solid = true, Name = "Path" })
			Kit.Box(f, V(-8, 0.2, z + 3.8), V(-0.4, 0.23, z + 4.2), BRICK_D, FLAT)
			Kit.Box(f, V(0.4, 0.2, z + 3.8), V(8, 0.23, z + 4.2), BRICK_D, FLAT)
		end
	end
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.2, 0.22, Z1), WHITE, FLAT)
	end
end

local function areaMarks(f: Instance)
	-- 1: nested squares (pixel target), lane runs into it
	do
		local x, z = AREAS[1][1], AREAS[1][2]
		local cols = { C(40, 30, 90), CYAN, PURPLE, CYAN, PINK, YELLOW }
		for k, col in cols do
			local h = 30 - (k - 1) * 5
			Kit.Box(f, V(x - h, 0, z - h), V(x + h, 0.04 + k * 0.04, z + h), col, if k == 1 then { Mat = SMOOTH, Solid = true } else FLAT)
		end
	end
	-- 2: checkerboard
	do
		local x, z = AREAS[2][1], AREAS[2][2]
		Kit.Box(f, V(x - 24, 0, z - 24), V(x + 24, 0.06, z + 24), C(30, 30, 50), FLAT)
		for i = 0, 3 do
			for j = 0, 3 do
				if (i + j) % 2 == 0 then
					Kit.Box(f, V(x - 24 + i * 12, 0.06, z - 24 + j * 12), V(x - 12 + i * 12, 0.1, z - 12 + j * 12), PINK, FLAT)
				end
			end
		end
	end
	-- 3: blocky pixel ring (4-stud cells)
	do
		local x, z = AREAS[3][1], AREAS[3][2]
		for i = -6, 5 do
			for j = -6, 5 do
				local cx, cz = (i + 0.5) * 4, (j + 0.5) * 4
				local d = math.sqrt(cx * cx + cz * cz)
				if d >= 14 and d <= 22 then
					Kit.Box(f, V(x + cx - 2, 0, z + cz - 2), V(x + cx + 2, 0.08, z + cz + 2), if d > 18 then YELLOW else C(255, 150, 40), FLAT)
				end
			end
		end
		-- flat pixel ghost in the middle (top row toward +Z)
		local rows = SPRITES[1]
		local cell = 2.4
		for r, row in rows do
			for c = 1, #row do
				local ch = string.sub(row, c, c)
				if ch ~= "." then
					local cx = x + (c - 4) * cell
					local cz = z + (#rows / 2 - r + 0.5) * cell
					Kit.Box(f, V(cx - cell / 2, 0.02, cz - cell / 2), V(cx + cell / 2, 0.1, cz + cell / 2), if ch == "O" then BLACK else WHITE, FLAT)
				end
			end
		end
	end
	-- 4: concentric diamonds
	do
		local x, z = AREAS[4][1], AREAS[4][2]
		local cols = { C(40, 140, 120), GREEN_L, C(40, 140, 120), CYAN }
		for k, col in cols do
			local s = 32 - (k - 1) * 7
			Kit.Part(f, V(s, 0.04, s), CFrame.new(x, 0.02 + k * 0.04, z) * CFrame.Angles(0, math.pi / 4, 0), col, FLAT)
		end
	end
	-- boss: GAME OVER square with a red pixel border
	do
		local h = 30
		Kit.Box(f, V(-h, 0, BOSS_Z - h), V(h, 0.12, BOSS_Z + h), BLACK, { Mat = SMOOTH, Solid = true, Name = "GameOverFloor" })
		for k = 0, 14 do
			local t = -h + k * 4
			local col = if k % 2 == 0 then RED else C(255, 140, 140)
			Kit.Box(f, V(t, 0.12, BOSS_Z - h), V(t + 4, 0.16, BOSS_Z - h + 4), col, FLAT)
			Kit.Box(f, V(t, 0.12, BOSS_Z + h - 4), V(t + 4, 0.16, BOSS_Z + h), col, FLAT)
			if k > 0 and k < 14 then
				Kit.Box(f, V(-h, 0.12, BOSS_Z + t), V(-h + 4, 0.16, BOSS_Z + t + 4), col, FLAT)
				Kit.Box(f, V(h - 4, 0.12, BOSS_Z + t), V(h, 0.16, BOSS_Z + t + 4), col, FLAT)
			end
		end
		local word = Kit.Part(f, V(42, 0.04, 12), CFrame.new(0, 0.14, BOSS_Z + 4), BLACK, { Name = "SignBoard" })
		Kit.Sign(word, Enum.NormalId.Top, "GAME OVER", RED, { Stroke = WHITE, Font = Enum.Font.Arcade })
		local sub = Kit.Part(f, V(26, 0.04, 5), CFrame.new(0, 0.14, BOSS_Z - 9), BLACK, { Name = "SignBoard" })
		Kit.Sign(sub, Enum.NormalId.Top, "INSERT COIN", YELLOW, { Stroke = BLACK, Font = Enum.Font.Arcade })
	end
end

--==================================================================
-- EDGES: BLOCK WALLS, ARCADE CABINETS, HIGH SCORE BOARD
--==================================================================
local function walls(f: Instance)
	local cols = { CYAN, PINK, YELLOW, GREEN_L }
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, Z0 + 1), V(s * 146, 12, Z1 - 1), C(70, 50, 140), { Mat = SMOOTH, Solid = true, Shadow = true })
		for _, y in { 4, 8 } do
			Kit.Box(f, V(s * 139.9, y - 0.25, Z0 + 1), V(s * 140, y + 0.25, Z1 - 1), C(45, 30, 100), FLAT)
		end
		local k = 0
		for z = Z0 + 4, Z1 - 16, 24 do
			k += 1
			Kit.Box(f, V(s * 140, 12, z), V(s * 146, 15, z + 12), cols[k % #cols + 1], FLAT)
		end
		-- dark platform beyond the wall that the cabinets stand on
		Kit.Box(f, V(s * 146, -4, Z0 - 10), V(s * 200, 0, Z1 + 10), C(18, 14, 40), FLAT)
	end
end

local GAMES = { "GHOST BLASTER", "PIXEL RACER", "BLOCK DROP", "STAR PATROL", "BOO MAZE", "SKY JUMPER", "BUG BASH" }
local CAB_COLS = { C(200, 50, 70), C(50, 110, 220), C(240, 160, 30), C(120, 60, 200), C(30, 160, 120), C(220, 80, 170), C(60, 60, 80) }

local function cabinet(f: Instance, s: number, z: number, idx: number, light: boolean)
	-- s = -1 left side (faces +X), 1 right side (faces -X)
	local m = Kit.Model(f, "ArcadeCabinet")
	local col = CAB_COLS[(idx - 1) % #CAB_COLS + 1]
	local inner, outer = s * 148, s * 186
	local w = 19
	Kit.Box(m, V(inner, 0, z - w), V(outer, 84, z + w), col, { Mat = SMOOTH, Shadow = true })
	-- side art stripes
	for _, dz in { -1, 1 } do
		for k, y in { 20, 30, 40 } do
			Kit.Box(m, V(inner - s * 2, y, z + dz * w - 0.1 * dz), V(outer + s * 2, y + 3, z + dz * (w + 0.2)), if k == 2 then WHITE else col:Lerp(WHITE, 0.4), FLAT)
		end
	end
	local fx = inner - s * 0.1
	local normal = V(-s, 0, 0)
	-- screen: black bezel, coloured screen, a sprite and a pixel score row
	Kit.Box(m, V(fx, 36, z - 15), V(fx - s * 0.3, 66, z + 15), BLACK, FLAT)
	local scrCol = C(20, 30, 70)
	local scr = Kit.Box(m, V(fx - s * 0.3, 38, z - 13), V(fx - s * 0.5, 64, z + 13), scrCol, FLAT)
	local spr = SPRITES[(idx - 1) % #SPRITES + 1]
	local sprCol = ({ WHITE, GREEN_L, CYAN, RED })[(idx - 1) % 4 + 1]
	sprite(m, V(fx - s * 0.5, 51, z), V(0, 0, 1), normal, 2.4, spr, { X = sprCol, O = BLACK })
	for k = -4, 4, 2 do
		Kit.Box(m, V(fx - s * 0.5, 61, z + k * 1.2 - 0.8), V(fx - s * 0.7, 62.4, z + k * 1.2 + 0.8), YELLOW, FLAT)
	end
	Kit.Box(m, V(fx - s * 0.5, 40, z - 12), V(fx - s * 0.7, 40.6, z + 12), C(80, 200, 255), FLAT)
	if light then
		Kit.Light(scr, C(140, 170, 255), 40, 0.6)
	end
	-- marquee with the game's name, a thin neon strip under it
	local mq = Kit.Part(m, V(1, 10, 2 * w - 2), CFrame.new(fx - s * 0.5, 74, z), BLACK, { Name = "SignBoard" })
	Kit.Sign(mq, if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left, GAMES[(idx - 1) % #GAMES + 1], YELLOW, { Stroke = col, Font = Enum.Font.Arcade })
	Kit.Box(m, V(fx - s * 0.2, 68.4, z - w + 1), V(fx - s * 0.9, 68.9, z + w - 1), col:Lerp(WHITE, 0.3), { Mat = NEON })
	-- control deck jutting out over the wall: joystick + three buttons
	local dx0, dx1 = inner, inner - s * 9
	Kit.Box(m, V(dx0, 26, z - w + 1), V(dx1, 31, z + w - 1), C(30, 30, 40), FLAT)
	Kit.Box(m, V(dx0, 31, z - w + 1), V(dx1, 31.4, z + w - 1), col:Lerp(WHITE, 0.2), FLAT)
	local jx = inner - s * 4.5
	Kit.Cyl(m, 0.6, 5, CFrame.new(jx, 31.7, z - 8), BLACK)
	Kit.Cyl(m, 5, 1, CFrame.new(jx, 34, z - 8), C(60, 60, 70), { Mat = METAL })
	Kit.Ball(m, 3, V(jx, 37, z - 8), RED)
	for k, bcol in { RED, YELLOW, C(60, 160, 255) } do
		Kit.Cyl(m, 1, 3, CFrame.new(jx, 31.7, z - 1 + (k - 1) * 4.5), bcol)
	end
	-- coin door above the wall line with two little orange coin slots
	Kit.Box(m, V(fx, 14, z - 7), V(fx - s * 0.3, 23, z + 7), C(40, 40, 50), FLAT)
	for _, dz in { -3, 3 } do
		Kit.Box(m, V(fx - s * 0.3, 18, z + dz - 0.9), V(fx - s * 0.5, 21, z + dz + 0.9), C(255, 150, 50), { Mat = NEON })
	end
end

local function highScoreBoard(f: Instance, z: number)
	local m = Kit.Model(f, "HighScoreBoard")
	local x = 152
	for _, dz in { -24, 24 } do
		Kit.Box(m, V(x, 0, z + dz - 1.5), V(x + 3, 20, z + dz + 1.5), C(60, 60, 80), { Mat = METAL })
	end
	Kit.Box(m, V(x - 0.5, 18, z - 32), V(x + 2, 84, z + 32), C(140, 80, 240), FLAT)
	Kit.Box(m, V(x - 0.8, 20, z - 30), V(x - 0.5, 82, z + 30), BLACK, FLAT)
	local rows = { "HIGH SCORES", "1  ACE  999990", "2  BOO  875400", "3  ZAP  640120", "4  GUS  512000", "5  YOU  ??????" }
	local rowCols = { YELLOW, CYAN, PINK, GREEN_L, C(255, 170, 60), WHITE }
	for i, text in rows do
		local y = 76 - (i - 1) * 10
		local p = Kit.Part(m, V(0.1, if i == 1 then 9 else 7, 56), CFrame.new(x - 0.9, y, z), BLACK, { Transp = 1, Name = "SignBoard" })
		Kit.Sign(p, Enum.NormalId.Left, text, rowCols[i], { Stroke = BLACK, Font = Enum.Font.Arcade })
	end
	Kit.Box(m, V(x - 1, 82, z - 31), V(x - 0.6, 82.5, z + 31), CYAN, { Mat = NEON })
end

local function edges(f: Instance)
	walls(f)
	local idx = 0
	for _, z in { Z0 + 40, Z0 + 130, Z0 + 220, Z0 + 310 } do
		idx += 1
		cabinet(f, -1, z, idx, idx == 2)
	end
	for _, z in { Z0 + 40, Z0 + 130, Z0 + 310 } do
		idx += 1
		cabinet(f, 1, z, idx, idx == 7)
	end
	highScoreBoard(f, Z0 + 220)
end

--==================================================================
-- LANDMARKS AND PROPS
--==================================================================
local function joystick(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GiantJoystick")
	Kit.Box(m, V(x - 9, 0, z - 9), V(x + 9, 6, z + 9), C(30, 30, 40), SOLID)
	Kit.Box(m, V(x - 9.3, 5, z - 9.3), V(x + 9.3, 6.3, z + 9.3), RED, FLAT)
	Kit.Cyl(m, 1.4, 8, CFrame.new(x, 7, z), BLACK)
	local top = V(x + 4, 28, z - 2)
	local base = V(x, 7, z)
	local mid = (top + base) / 2
	Kit.Part(m, V(3, (top - base).Magnitude, 3), CFrame.lookAt(mid, top) * CFrame.Angles(math.pi / 2, 0, 0), C(150, 150, 165), { Mat = METAL, Solid = true })
	Kit.Ball(m, 11, top + V(0, 3, 0), RED, SOLID)
	Kit.Ball(m, 3, top + V(-2.2, 6.4, -2), C(255, 160, 160), FLAT)
	-- two giant buttons you can stand on
	for k, col in { YELLOW, C(60, 160, 255) } do
		local bz = z - 14 + (k - 1) * 28
		Kit.Disc(f, x + 18, bz, 1.2, 12, 1.2, C(40, 40, 50), SOLID)
		Kit.Disc(f, x + 18, bz, 2.6, 9, 1.4, col, SOLID)
		Kit.AddCircle(x + 18, bz, 7)
	end
	Kit.AddCircle(x, z, 13)
end

local function staircase(f: Instance, x0: number, z: number)
	-- 4 block steps rising toward +X (3 studs each), a coin block floating above the top
	for k = 0, 3 do
		local x = x0 + k * 8
		local h = (k + 1) * 3
		Kit.Box(f, V(x, 0, z - 8), V(x + 8, h, z + 8), if k % 2 == 0 then BRICK else C(176, 82, 46), SOLID)
		Kit.Box(f, V(x, h, z - 8), V(x + 8, h + 0.2, z + 8), C(255, 170, 90), FLAT)
	end
	coinBlock(f, x0 + 28, 22, z, true)
	Kit.AddRect(x0 - 2, z - 10, x0 + 34, z + 10)
end

local function heart(f: Instance)
	local m = Kit.Model(f, "BigPixelHeart")
	local rows = {
		".RR...RR.",
		"RWRR.RRRR",
		"RWRRRRRRR",
		"RRRRRRRRR",
		".RRRRRRR.",
		"..RRRRR..",
		"...RRR...",
		"....R....",
	}
	local o = V(0, 52 + 4 * 3, BOSS_Z + 8)
	sprite(m, o, V(1, 0, 0), V(0, 0, -1), 3, rows, { R = RED, W = WHITE }, 3)
	sprite(m, o + V(0, 0, 0.1), V(1, 0, 0), V(0, 0, 1), 3, rows, { R = C(200, 40, 50) }, 0.3)
	local core = Kit.Part(m, V(1, 1, 1), CFrame.new(o + V(0, 0, -1.5)), RED, { Transp = 1, Name = "HeartSparkle" })
	Kit.Emitter(core, C(255, 200, 220), 3, 3, 2)
	Kit.Light(core, C(255, 90, 110), 40, 0.6)
end

local function sky(f: Instance)
	-- cube clouds (high, never in the way)
	local clouds = { V(-90, 58, Z0 + 60), V(60, 66, Z0 + 120), V(-30, 74, Z0 + 200), V(110, 60, Z0 + 260), V(-110, 70, Z0 + 320), V(20, 80, Z0 + 30), V(-60, 62, Z0 + 150), V(80, 76, Z0 + 340) }
	for i, p in clouds do
		local w = 18 + (i % 3) * 6
		Kit.Box(f, p - V(w / 2, 0, 5), p + V(w / 2, 5, 5), WHITE, FLAT)
		Kit.Box(f, p + V(-w / 4, 5, -4), p + V(w / 4, 9, 4), WHITE, FLAT)
		Kit.Box(f, p + V(w / 2 - 6, 0, -4), p + V(w / 2 + 2, 3, 4), C(215, 225, 245), FLAT)
	end
	-- square pixel sun far ahead
	local sp = V(70, 120, Z1 + 30)
	Kit.Box(f, sp - V(12, 12, 1), sp + V(12, 12, 1), YELLOW, FLAT)
	Kit.Box(f, sp - V(8, 8, 1.5), sp + V(8, 8, -1), C(255, 245, 140), FLAT)
	for k = 0, 7 do
		local a = k * math.pi / 4
		local c = sp + V(math.cos(a) * 19, math.sin(a) * 19, 0)
		Kit.Box(f, c - V(2.5, 2.5, 1), c + V(2.5, 2.5, 1), C(255, 190, 40), FLAT)
	end
end

local function props(f: Instance)
	joystick(f, -112, Z0 + 318)
	staircase(f, 96, Z0 + 40)
	heart(f)
	-- coin block row high over the lane, and two side rows
	for k = -2, 2 do
		coinBlock(f, k * 6, 14, Z0 + 150, k % 2 == 0)
	end
	for k = -1, 1 do
		coinBlock(f, 112 + k * 6, 14, Z0 + 100, k == 0)
		coinBlock(f, -116 + k * 6, 16, Z0 + 268, k ~= 0)
	end
	Kit.AddRect(-126, Z0 + 262, -106, Z0 + 274)
	Kit.AddRect(102, Z0 + 94, 122, Z0 + 106)
	-- spinning coins over the lane
	local coins = { Z0 + 124, Z0 + 132, Z0 + 140, Z0 + 255, Z0 + 263, Z0 + 271 }
	for i, z in coins do
		local c = Kit.Part(f, V(0.6, 4, 4), CFrame.new(0, 6, z) * CFrame.Angles(0, i * 0.5, 0), GOLD, { Shape = Enum.PartType.Cylinder, Name = "FloatingCoin" })
		Kit.Float(c, 1)
	end
	-- pipes
	local pipes: { { x: number, z: number, h: number, col: Color3 } } = {
		{ x = -118, z = Z0 + 52, h = 12, col = C(40, 180, 200) }, { x = 120, z = Z0 + 152, h = 16, col = C(240, 130, 40) },
		{ x = -30, z = Z0 + 205, h = 9, col = PURPLE }, { x = 36, z = Z0 + 296, h = 13, col = C(40, 180, 200) },
	}
	for _, p in pipes do
		if Kit.IsFree(p.x, p.z, 7.5) then
			pipe(f, p.x, p.z, p.h, p.col)
		end
	end
	-- 8-bit trees and bushes
	local trees = { { -50, Z0 + 40 }, { -128, Z0 + 100 }, { 125, Z0 + 215 }, { 30, Z0 + 230 }, { -125, Z0 + 205 }, { 125, Z0 + 300 }, { 40, Z0 + 140 }, { -25, Z0 + 330 } }
	for i, t in trees do
		if Kit.IsFree(t[1], t[2], 7) then
			pixelTree(f, t[1], t[2], 7 + (i % 3) * 3)
		end
	end
	for _ = 1, 30 do
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 10)
		if Kit.IsFree(x, z, 5.5) then
			bush(f, x, z)
		end
	end
	-- power-up boxes
	local boxes = { { 60, Z0 + 60 }, { -40, Z0 + 170 }, { 110, Z0 + 340 }, { -100, Z0 + 180 }, { 30, Z0 + 340 } }
	for i, b in boxes do
		if Kit.IsFree(b[1], b[2], 5) then
			powerBox(f, b[1], b[2], i * 0.4)
		end
	end
	sky(f)
end

--==================================================================
-- BUILD
--==================================================================
function CyberArcade.Build(map: Instance)
	local f = Kit.Folder(map, "CyberArcade")
	ground(f)
	areaMarks(f)
	edges(f)
	props(f)
end

return CyberArcade
