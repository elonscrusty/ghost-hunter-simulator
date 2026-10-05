--!strict
-- Ground slabs (top at Y=0), lobby + themed outer walls, the zone-separation walls and the
-- invisible collision walls up to Y=80 that keep players inside and in front of locked gates.
-- Each world (Config.Worlds) is its own walled track: World 1 from the lobby to the end of the
-- Throne, World 2 from Lantern Market's MinZ to the Void Throne's MaxZ, with an end wall at both
-- ends of every track and nothing in the gap between them.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Boundary = {}

local C = Color3.fromRGB
local V = Vector3.new
local INVIS_TOP = 80
local HW = Config.Layout.HalfWidth -- 140
local LOBBY = Config.Layout.Lobby

-- Zone-separation wall look per gate (wall / cap stone / cap ball / painted band).
-- Mat: wall material (default Cobblestone); Glow: the band is a thin neon tube (Neon City, Cyber Arcade)
type WallLook = { Wall: Color3, Cap: Color3, Ball: Color3, Band: Color3, Pumpkins: boolean, Mat: Enum.Material?, Glow: boolean? }
local WALLS: { [string]: WallLook } = {
	Cemetery = { Wall = C(135, 115, 175), Cap = C(185, 170, 220), Ball = C(255, 160, 60), Band = C(150, 255, 120), Pumpkins = true },
	School = { Wall = C(215, 110, 95), Cap = C(250, 230, 210), Ball = C(200, 130, 255), Band = C(200, 120, 255), Pumpkins = true },
	Carnival = { Wall = C(230, 70, 80), Cap = C(255, 240, 215), Ball = C(255, 205, 60), Band = C(70, 140, 255), Pumpkins = false },
	Hospital = { Wall = C(225, 230, 238), Cap = C(150, 200, 235), Ball = C(140, 220, 180), Band = C(110, 190, 255), Pumpkins = false },
	Harbor = { Wall = C(120, 85, 55), Cap = C(70, 110, 150), Ball = C(220, 80, 70), Band = C(60, 200, 200), Pumpkins = false },
	Castle = { Wall = C(140, 140, 155), Cap = C(95, 95, 115), Ball = C(255, 200, 70), Band = C(150, 40, 70), Pumpkins = false },
	SpiritRealm = { Wall = C(60, 50, 95), Cap = C(90, 80, 140), Ball = C(110, 230, 255), Band = C(170, 100, 255), Pumpkins = false },
	Swamp = { Wall = C(90, 110, 70), Cap = C(120, 95, 65), Ball = C(170, 255, 120), Band = C(150, 230, 90), Pumpkins = false },
	Frost = { Wall = C(200, 225, 245), Cap = C(150, 190, 230), Ball = C(170, 240, 255), Band = C(110, 190, 255), Pumpkins = false },
	Tomb = { Wall = C(220, 185, 120), Cap = C(190, 150, 90), Ball = C(70, 200, 220), Band = C(255, 210, 90), Pumpkins = false },
	ToyFactory = { Wall = C(255, 150, 190), Cap = C(255, 225, 90), Ball = C(90, 180, 255), Band = C(150, 90, 230), Pumpkins = false },
	Sunken = { Wall = C(80, 140, 160), Cap = C(200, 190, 150), Ball = C(255, 220, 120), Band = C(90, 255, 230), Pumpkins = false },
	Clockwork = { Wall = C(150, 110, 75), Cap = C(200, 170, 110), Ball = C(230, 200, 120), Band = C(120, 90, 60), Pumpkins = false },
	Inferno = { Wall = C(80, 50, 50), Cap = C(110, 70, 60), Ball = C(255, 150, 60), Band = C(255, 110, 50), Pumpkins = false },
	Throne = { Wall = C(240, 235, 255), Cap = C(200, 180, 240), Ball = C(255, 215, 90), Band = C(150, 100, 230), Pumpkins = false },
	-- World 2 (walls at the gates of zones 18-32, in the style of the zone each gate opens)
	PhantomLibrary = { Wall = C(95, 60, 40), Cap = C(60, 38, 28), Ball = C(120, 255, 220), Band = C(170, 40, 50), Pumpkins = false, Mat = Enum.Material.Wood }, -- dark wood, red spine band
	PumpkinFarm = { Wall = C(170, 60, 50), Cap = C(235, 225, 205), Ball = C(255, 150, 50), Band = C(235, 200, 110), Pumpkins = true, Mat = Enum.Material.WoodPlanks }, -- red barn wall, white trim
	Glowshroom = { Wall = C(80, 110, 85), Cap = C(60, 85, 65), Ball = C(230, 80, 90), Band = C(120, 255, 230), Pumpkins = false, Mat = Enum.Material.Slate }, -- mossy stone, mushroom-cap balls
	WaterPark = { Wall = C(230, 235, 240), Cap = C(40, 170, 220), Ball = C(255, 230, 90), Band = C(90, 230, 255), Pumpkins = false, Mat = Enum.Material.SmoothPlastic }, -- pool tiles
	MirrorMaze = { Wall = C(205, 215, 230), Cap = C(170, 180, 200), Ball = C(230, 245, 255), Band = C(150, 200, 255), Pumpkins = false, Mat = Enum.Material.Foil },
	ShoppingMall = { Wall = C(235, 225, 230), Cap = C(200, 185, 200), Ball = C(130, 230, 255), Band = C(255, 140, 210), Pumpkins = false, Mat = Enum.Material.Marble },
	GhostSubway = { Wall = C(235, 225, 195), Cap = C(70, 80, 90), Ball = C(255, 220, 80), Band = C(40, 160, 160), Pumpkins = false, Mat = Enum.Material.SmoothPlastic }, -- cream tile, teal band
	DinoMuseum = { Wall = C(210, 195, 160), Cap = C(170, 150, 115), Ball = C(240, 230, 205), Band = C(150, 230, 120), Pumpkins = false, Mat = Enum.Material.Sandstone }, -- museum stone, bone-white balls
	Stadium = { Wall = C(70, 80, 110), Cap = C(200, 205, 215), Ball = C(255, 220, 80), Band = C(120, 255, 140), Pumpkins = false, Mat = Enum.Material.Concrete },
	NeonCity = { Wall = C(60, 45, 70), Cap = C(40, 30, 50), Ball = C(255, 80, 220), Band = C(255, 90, 210), Pumpkins = false, Mat = Enum.Material.Brick, Glow = true },
	GiantsKitchen = { Wall = C(240, 225, 200), Cap = C(200, 150, 100), Ball = C(255, 110, 90), Band = C(120, 190, 230), Pumpkins = false, Mat = Enum.Material.SmoothPlastic },
	CyberArcade = { Wall = C(45, 30, 80), Cap = C(30, 20, 55), Ball = C(80, 255, 220), Band = C(255, 80, 200), Pumpkins = false, Mat = Enum.Material.SmoothPlastic, Glow = true },
	StormIslands = { Wall = C(110, 120, 145), Cap = C(185, 195, 215), Ball = C(255, 240, 120), Band = C(255, 230, 110), Pumpkins = false, Mat = Enum.Material.Slate },
	MoonBase = { Wall = C(225, 228, 235), Cap = C(150, 155, 170), Ball = C(255, 150, 80), Band = C(255, 140, 60), Pumpkins = false, Mat = Enum.Material.DiamondPlate }, -- white panels, orange stripe
	VoidThrone = { Wall = C(25, 20, 35), Cap = C(45, 35, 60), Ball = C(200, 150, 255), Band = C(170, 110, 255), Pumpkins = false, Mat = Enum.Material.Basalt }, -- obsidian, violet trim
}

-- Zones without a hand-picked look (World 2) get one from their own colours.
local function derivedLook(id: string): WallLook
	local z = Config.ZoneById[id]
	if not z then
		return WALLS.School
	end
	local black = Color3.new(0, 0, 0)
	return { Wall = z.FogColor:Lerp(z.Ambient, 0.45), Cap = z.FogColor:Lerp(black, 0.2), Ball = z.Accent, Band = z.Accent:Lerp(black, 0.15), Pumpkins = false }
end

local invisible: (Instance, Vector3, Vector3) -> ()
function invisible(parent: Instance, a: Vector3, b: Vector3)
	-- Roblox caps a part at 2048 studs per axis: split long walls along Z into pieces
	local lo, hi = a:Min(b), a:Max(b)
	if hi.Z - lo.Z > 1000 then
		local n = math.ceil((hi.Z - lo.Z) / 1000)
		local step = (hi.Z - lo.Z) / n
		for i = 0, n - 1 do
			invisible(parent, Vector3.new(lo.X, lo.Y, lo.Z + i * step), Vector3.new(hi.X, hi.Y, lo.Z + (i + 1) * step))
		end
		return
	end
	local p = Kit.Box(parent, a, b, C(255, 255, 255), { Transp = 1, Solid = true, Name = "InvisibleWall", Shadow = false })
	p.CanQuery = false -- never block taps / ground raycasts
end

local function hedgeRun(f: Instance, a: Vector3, b: Vector3)
	-- a/b: opposite corners of the hedge box (Y 0..14)
	Kit.Box(f, a, b, C(70, 160, 85), { Mat = Enum.Material.Grass, Solid = true })
	local lo, hi = a:Min(b), a:Max(b)
	local alongX = (hi.X - lo.X) > (hi.Z - lo.Z)
	local len = if alongX then hi.X - lo.X else hi.Z - lo.Z
	local n = math.floor(len / 16)
	local greens = { C(80, 175, 90), C(95, 190, 100), C(70, 150, 95) }
	for i = 0, n do
		local t = (i + 0.5) / (n + 1)
		local pos = if alongX
			then V(lo.X + (hi.X - lo.X) * t, hi.Y, (lo.Z + hi.Z) / 2)
			else V((lo.X + hi.X) / 2, hi.Y, lo.Z + (hi.Z - lo.Z) * t)
		Kit.Ball(f, 7.5, pos, Kit.Pick(greens), { Mat = Enum.Material.Grass })
	end
end

local function stoneRun(f: Instance, a: Vector3, b: Vector3, wall: Color3, cap: Color3, topBall: Color3, spacing: number, mat: Enum.Material?)
	Kit.Box(f, a, b, wall, { Mat = mat or Enum.Material.Cobblestone, Solid = true })
	local lo, hi = a:Min(b), a:Max(b)
	Kit.Box(f, V(lo.X - 0.5, hi.Y, lo.Z - 0.5), V(hi.X + 0.5, hi.Y + 1.2, hi.Z + 0.5), cap, { Mat = Enum.Material.Slate })
	local alongX = (hi.X - lo.X) > (hi.Z - lo.Z)
	local len = if alongX then hi.X - lo.X else hi.Z - lo.Z
	local n = math.floor(len / spacing)
	local ball = Kit.Vivid(topBall)
	for i = 0, n do
		local t = i / math.max(n, 1)
		local cx = if alongX then lo.X + (hi.X - lo.X) * t else (lo.X + hi.X) / 2
		local cz = if alongX then (lo.Z + hi.Z) / 2 else lo.Z + (hi.Z - lo.Z) * t
		local half = if alongX then V(2.5, 0, (hi.Z - lo.Z) / 2 + 1) else V((hi.X - lo.X) / 2 + 1, 0, 2.5)
		Kit.Box(f, V(cx, 0, cz) - half, V(cx, hi.Y + 3, cz) + half, cap, { Mat = Enum.Material.Slate, Solid = true })
		Kit.Ball(f, 2.6, V(cx, hi.Y + 4.3, cz), ball) -- candy-coloured cap ball (solid, not glowing)
	end
end

local function brickRun(f: Instance, a: Vector3, b: Vector3, spacing: number)
	stoneRun(f, a, b, C(215, 110, 95), C(250, 230, 210), C(200, 130, 255), spacing)
end

function Boundary.Build(map: Instance)
	local f = Kit.Folder(map, "Boundary")
	local W = HW + 6 -- outer face of the visible walls

	-- Ground (top surface Y = 0), wider than the play area so the walls sit on grass.
	Kit.Box(f, V(-190, -4, -190), V(190, 0, 260), C(105, 195, 100), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_Neighborhood" }) -- lobby too
	Kit.Box(f, V(-190, -4, 260), V(190, 0, 540), C(80, 160, 120), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_Cemetery" })
	Kit.Box(f, V(-190, -4, 540), V(190, 0, 880), C(115, 195, 110), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_School" })

	-- Neighborhood: side hedges + the lobby's front hedge (open arch at X = 0, built in
	-- Neighborhood.luau, whose pillars fill |X| half..half+8)
	local front = LOBBY.FrontZ
	local eh = LOBBY.EntranceWidth / 2
	hedgeRun(f, V(-W, 0, front - 3), V(-HW, 14, 260))
	hedgeRun(f, V(HW, 0, front - 3), V(W, 14, 260))
	for _, s in { -1, 1 } do
		hedgeRun(f, V(s * (eh + 8), 0, front - 3), V(s * (HW - 0.01), 14, front + 3))
	end
	-- Lobby: hedges on both sides and behind HQ
	local LX1, LX2 = LOBBY.MinX, LOBBY.MaxX -- the left side is wider (Boss Tower entrance)
	hedgeRun(f, V(LX1 - 6, 0, LOBBY.BackZ - 6), V(LX1, 14, front - 3))
	hedgeRun(f, V(LX2, 0, LOBBY.BackZ - 6), V(LX2 + 6, 14, front - 3))
	hedgeRun(f, V(LX1 - 6, 0, LOBBY.BackZ - 6), V(LX2 + 6, 14, LOBBY.BackZ))
	-- Cemetery: mossy stone with mint cap balls
	stoneRun(f, V(-W, 0, 263), V(-HW, 12, 537), C(120, 110, 150), C(170, 160, 200), C(110, 255, 170), 28)
	stoneRun(f, V(HW, 0, 263), V(W, 12, 537), C(120, 110, 150), C(170, 160, 200), C(110, 255, 170), 28)
	-- School: brick with purple tops (sides + far end)
	brickRun(f, V(-W, 0, 543), V(-HW, 14, 877), 30)
	brickRun(f, V(HW, 0, 543), V(W, 14, 877), 30)
	-- Zones 4-8 build their own ground, side walls and outside scenery (see their builders).

	-- Zone separation walls with the gate opening centred on X = 0.
	for id, gate in Kit.Gates(Config.Layout) do
		local z = gate.Z
		local half = gate.Width / 2
		local h = 18
		local look = WALLS[id] or derivedLook(id)
		for _, s in { -1, 1 } do
			stoneRun(f, V(s * (half + 8), 0, z - 3), V(s * W, h, z + 3), look.Wall, look.Cap, look.Ball, 24, look.Mat)
		end
		-- painted band along the wall faces
		local band = Kit.Vivid(look.Band)
		for _, s in { -1, 1 } do
			for _, fz in { -1, 1 } do
				if look.Glow then
					-- a thin neon tube (0.25 tall) instead of the painted band: modest glow
					Kit.Box(f, V(s * (half + 6), 3.2, z + fz * 3.05), V(s * (W - 1), 3.45, z + fz * 3.3), look.Band, { Mat = Enum.Material.Neon })
				else
					Kit.Box(f, V(s * (half + 6), 3, z + fz * 3.05), V(s * (W - 1), 3.6, z + fz * 3.25), band)
				end
			end
			invisible(f, V(s * half, 0, z - 3), V(s * W, INVIS_TOP, z + 3))
		end
		-- above the arch beam (beam fills Y 30..36 of the opening)
		invisible(f, V(-half, 36, z - 3), V(half, INVIS_TOP, z + 3))
		-- pumpkins along the wall top on the approach side (the spooky-town zones only)
		for i = 1, if look.Pumpkins then 4 else 0 do
			for _, s in { -1, 1 } do
				local x = s * (half + 12 + i * 26)
				Props.Pumpkin(f, V(x, h + 1.2, z - 1.5), 3.6, 0, -1)
			end
		end
	end

	-- Invisible outer walls (play area is |X| <= 140) along each world's track, plus the lobby.
	-- World 1 starts at the lobby's front hedge; later worlds start at their first zone's MinZ.
	for wi, world in Config.Worlds do
		local first, last = Config.Zones[world.First], Config.Zones[world.Last]
		if not first or not last then
			continue
		end
		local z0 = if wi == 1 then front - 3 else first.MinZ - 6
		local z1 = last.MaxZ
		invisible(f, V(-W, 0, z0), V(-HW, INVIS_TOP, z1 + 6))
		invisible(f, V(HW, 0, z0), V(W, INVIS_TOP, z1 + 6))
		invisible(f, V(-W, 0, z1), V(W, INVIS_TOP, z1 + 6)) -- far end
		if wi > 1 then
			invisible(f, V(-W, 0, z0), V(W, INVIS_TOP, first.MinZ)) -- back end
		end
	end
	for _, s in { -1, 1 } do
		invisible(f, V(s * eh, 0, front - 3), V(s * W, INVIS_TOP, front + 3))
		local lx = if s < 0 then LX1 else LX2
		invisible(f, V(lx, 0, LOBBY.BackZ - 6), V(lx + s * 6, INVIS_TOP, front - 3))
	end
	invisible(f, V(-eh, 30, front - 3), V(eh, INVIS_TOP, front + 3)) -- above the arch beam
	invisible(f, V(LX1 - 6, 0, LOBBY.BackZ - 6), V(LX2 + 6, INVIS_TOP, LOBBY.BackZ))

	-- Outer scenery: soft purple hills and big trees just beyond the walls.
	local hill = { C(120, 90, 190), C(100, 150, 120), C(150, 100, 200) }
	for i = 0, 9 do -- zones 1-3 (Z < 880)
		local z = -40 + i * 95
		for _, s in { -1, 1 } do
			Kit.Ball(f, 70, V(s * 185, -12, z + s * 20), Kit.Pick(hill), { Mat = Enum.Material.Grass })
		end
	end
	for i = 0, 6 do
		local z = -30 + i * 140
		for _, s in { -1, 1 } do
			Props.Tree(f, V(s * 156, 0, z), 22 + Kit.Rng:NextNumber(0, 10))
		end
	end
	-- outside the lobby hedges: a few big trees on the grass either side
	-- (fixed sizes: no Kit.Rng here, so the other zones' random props don't shift)
	-- (offsets are measured from each side's hedge, so the wider left side keeps them outside)
	for i, p in { { 28, -70 }, { 58, -112 }, { 20, -122 }, { 64, -62 } } do
		Props.Tree(f, V(LX2 + p[1], 0, p[2]), 18 + (i % 3) * 3)
		Props.Tree(f, V(LX1 - math.min(p[1], 40), 0, p[2]), 18 + (i % 3) * 3)
	end
end

return Boundary
