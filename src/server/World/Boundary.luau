--!strict
-- Ground slabs (top at Y=0), themed outer walls, the two zone-separation walls and the
-- invisible collision walls up to Y=80 that keep players inside and in front of locked gates.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Boundary = {}

local C = Color3.fromRGB
local V = Vector3.new
local INVIS_TOP = 80
local HW = Config.Layout.HalfWidth -- 140

local function invisible(parent: Instance, a: Vector3, b: Vector3)
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

local function stoneRun(f: Instance, a: Vector3, b: Vector3, wall: Color3, cap: Color3, topBall: Color3, spacing: number)
	Kit.Box(f, a, b, wall, { Mat = Enum.Material.Cobblestone, Solid = true })
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
	Kit.Box(f, V(-190, -4, -100), V(190, 0, 260), C(105, 195, 100), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_Neighborhood" })
	Kit.Box(f, V(-190, -4, 260), V(190, 0, 540), C(80, 160, 120), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_Cemetery" })
	Kit.Box(f, V(-190, -4, 540), V(190, 0, 920), C(115, 195, 110), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_School" })

	-- Neighborhood: hedges (sides + behind spawn)
	hedgeRun(f, V(-W, 0, -66), V(-HW, 14, 260))
	hedgeRun(f, V(HW, 0, -66), V(W, 14, 260))
	hedgeRun(f, V(-W, 0, -66), V(W, 14, -60))
	-- Cemetery: mossy stone with mint cap balls
	stoneRun(f, V(-W, 0, 263), V(-HW, 12, 537), C(120, 110, 150), C(170, 160, 200), C(110, 255, 170), 28)
	stoneRun(f, V(HW, 0, 263), V(W, 12, 537), C(120, 110, 150), C(170, 160, 200), C(110, 255, 170), 28)
	-- School: brick with purple tops (sides + far end)
	brickRun(f, V(-W, 0, 543), V(-HW, 14, 886), 30)
	brickRun(f, V(HW, 0, 543), V(W, 14, 886), 30)
	brickRun(f, V(-W, 0, 880), V(W, 14, 886), 30)

	-- Zone separation walls with the gate opening centred on X = 0.
	for id, gate in Kit.Gates(Config.Layout) do
		local z = gate.Z
		local half = gate.Width / 2
		local h = 18
		if id == "Cemetery" then
			for _, s in { -1, 1 } do
				stoneRun(f, V(s * (half + 8), 0, z - 3), V(s * W, h, z + 3), C(135, 115, 175), C(185, 170, 220), C(255, 160, 60), 24)
			end
		else
			for _, s in { -1, 1 } do
				stoneRun(f, V(s * (half + 8), 0, z - 3), V(s * W, h, z + 3), C(215, 110, 95), C(250, 230, 210), C(200, 130, 255), 24)
			end
		end
		-- painted band along the wall faces
		local band = Kit.Vivid(if id == "Cemetery" then C(150, 255, 120) else C(200, 120, 255))
		for _, s in { -1, 1 } do
			for _, fz in { -1, 1 } do
				Kit.Box(f, V(s * (half + 6), 3, z + fz * 3.05), V(s * (W - 1), 3.6, z + fz * 3.25), band)
			end
			invisible(f, V(s * half, 0, z - 3), V(s * W, INVIS_TOP, z + 3))
		end
		-- above the arch beam (beam fills Y 30..36 of the opening)
		invisible(f, V(-half, 36, z - 3), V(half, INVIS_TOP, z + 3))
		-- pumpkins along the wall top on the approach side
		for i = 1, 4 do
			for _, s in { -1, 1 } do
				local x = s * (half + 12 + i * 26)
				Props.Pumpkin(f, V(x, h + 1.2, z - 1.5), 3.6, 0, -1)
			end
		end
	end

	-- Invisible outer walls (play area is |X| <= 140, Z -60..880)
	invisible(f, V(-W, 0, -66), V(-HW, INVIS_TOP, 886))
	invisible(f, V(HW, 0, -66), V(W, INVIS_TOP, 886))
	invisible(f, V(-W, 0, -66), V(W, INVIS_TOP, -60))
	invisible(f, V(-W, 0, 880), V(W, INVIS_TOP, 886))

	-- Outer scenery: soft purple hills and big trees just beyond the walls.
	local hill = { C(120, 90, 190), C(100, 150, 120), C(150, 100, 200) }
	for i = 0, 9 do
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
end

return Boundary
