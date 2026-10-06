--!strict
-- ZONE 25: Dino Fossil Museum (Z 9880..10240). A grand natural-history hall after closing time:
-- polished grey-and-cream marble, white columns, dark wood wainscot, crimson and green banners
-- and an iron-ribbed glass roof open to the night sky (moonlit, not sandy: nothing like the Tomb).
--   Ground: cream marble with a darker checker, a red carpet runner along X = 0 with brass edges
--   and a trail of flat dino footprints. Ghost areas get flat inlaid medallions (brass ring,
--   ammonite spiral); the boss area (0, 10185) is a giant three-toed footprint medallion.
--   Exhibits (all outside the areas, each on a plinth inside brass posts and red ropes):
--   T-rex skeleton (right front), woolly mammoth (left front), long-neck skeleton (left back,
--   its neck rising to Y ~58), triceratops skeleton (right back), a volcano diorama (right of
--   the boss), a meteor on a plinth (left of the boss), glass display cases along the lane,
--   a kids' dig site, an info desk and a gift-shop stand by the entrance.
--   Overhead: arched iron ribs (bottoms above Y 40 over the areas) with pterosaur skeletons
--   hanging from them and a "DINO FOSSIL MUSEUM" banner over the entrance.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local DinoMuseum = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local MARBLE = Enum.Material.Marble
local WOOD = Enum.Material.Wood
local WOODP = Enum.Material.WoodPlanks
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local FABRIC = Enum.Material.Fabric

local Z0, Z1 = 9880, 10240

local FLOOR = C(222, 216, 204)
local FLOOR_D = C(150, 156, 160)
local WALL = C(232, 226, 212)
local WALL_D = C(196, 188, 170)
local WAIN = C(92, 58, 40)
local WAIN_D = C(62, 38, 28)
local CARPET = C(150, 30, 40)
local BRASS = C(214, 170, 70)
local IRON = C(56, 70, 66)
local BONE = C(236, 226, 196)
local BONE_D = C(200, 186, 150)
local PLINTH = C(70, 74, 82)
local PLINTH_T = C(110, 115, 124)
local NIGHT = C(40, 60, 110)
local DARK = C(28, 26, 30)
local CRIMSON = C(160, 30, 45)
local GREEN = C(40, 110, 70)
local NAVY = C(35, 50, 100)
local OCHRE = C(190, 130, 40)
local AMBER = C(255, 170, 40)
local FUR = C(120, 78, 50)
local FUR_D = C(88, 56, 36)

local BONE_O: Kit.Opts = { Mat = Enum.Material.Limestone }
local BRASS_O: Kit.Opts = { Mat = METAL }
local IRON_O: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305
local WALL_H = 36

--==================================================================
-- HELPERS
--==================================================================
-- A bone (square rod) from a to b.
local function bone(parent: Instance, a: Vector3, b: Vector3, d: number, col: Color3?)
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.05 then
		return
	end
	local up = if math.abs(dir.Unit.Y) > 0.95 then V(0, 0, 1) else V(0, 1, 0)
	Kit.Part(parent, V(d * 1.3, d * 1.3, len), CFrame.lookAt((a + b) / 2, b, up), col or BONE, BONE_O)
end

-- A chain of bones through points, with knobbly joints.
local function chain(parent: Instance, pts: { Vector3 }, d0: number, d1: number, joints: boolean?)
	local n = #pts
	for i = 1, n - 1 do
		local t = (i - 1) / math.max(1, n - 2)
		local d = d0 + (d1 - d0) * t
		bone(parent, pts[i], pts[i + 1], d)
		if joints and i > 1 then
			Kit.Ball(parent, d * 1.35, pts[i], BONE_D, BONE_O)
		end
	end
end

-- Local-to-world helper for a skeleton standing at (x, y0, z) and facing yaw (0 = head to -Z).
local function frame(x: number, y0: number, z: number, yaw: number, s: number): (number, number, number) -> Vector3
	local cf = CFrame.new(x, y0, z) * CFrame.Angles(0, yaw, 0)
	return function(lx: number, ly: number, lz: number): Vector3
		return cf:PointToWorldSpace(V(lx * s, ly * s, lz * s))
	end
end

-- Brass posts with red velvet ropes round a rectangle (posts every ~10 studs).
local function ropes(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local corners = { V(x1, 0, z1), V(x2, 0, z1), V(x2, 0, z2), V(x1, 0, z2) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local n = math.max(1, math.floor((b - a).Magnitude / 13 + 0.5))
		for k = 0, n - 1 do
			local p = a:Lerp(b, k / n)
			local q = a:Lerp(b, (k + 1) / n)
			Kit.Cyl(parent, 3.2, 0.5, CFrame.new(p.X, 1.6, p.Z), BRASS, BRASS_O)
			local mid = (p + q) / 2
			local len = (q - p).Magnitude
			Kit.Part(parent, V(0.3, 0.3, len), CFrame.lookAt(V(mid.X, 2.5, mid.Z), V(q.X, 2.5, q.Z)), CRIMSON, { Mat = FABRIC })
		end
	end
end

-- Info plaque on a slanted brass stand, facing (fx, fz).
local function plaque(parent: Instance, x: number, z: number, fx: number, fz: number, text: string)
	local yaw = Kit.FaceYaw(fx, fz)
	Kit.Cyl(parent, 3, 0.35, CFrame.new(x, 1.5, z), BRASS, BRASS_O)
	local board = Kit.Part(parent, V(5, 2.4, 0.3), CFrame.new(x, 3.4, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-0.5, 0, 0), C(40, 32, 30), { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, text, C(255, 225, 150))
end

-- Plinth (marble block with a darker top), returns its top Y.
local function plinth(parent: Instance, x1: number, z1: number, x2: number, z2: number, h: number): number
	Kit.Box(parent, V(x1, 0, z1), V(x2, h - 0.3, z2), PLINTH, { Mat = MARBLE, Solid = true })
	Kit.Box(parent, V(x1 - 0.3, h - 0.3, z1 - 0.3), V(x2 + 0.3, h, z2 + 0.3), PLINTH_T, { Mat = MARBLE, Solid = true })
	Kit.AddRect(x1 - 4, z1 - 4, x2 + 4, z2 + 4)
	return h
end

-- Ribs: a pair of curved ribs at local z hanging from the spine.
local function ribs(parent: Instance, P: (number, number, number) -> Vector3, z: number, top: number, w: number, drop: number, d: number)
	for _, s in { -1, 1 } do
		chain(parent, { P(s * 0.4, top, z), P(s * w, top - drop * 0.35, z + 0.3), P(s * w * 0.85, top - drop * 0.8, z + 0.8), P(s * w * 0.4, top - drop, z + 1.2) }, d, d * 0.7)
	end
end

--==================================================================
-- SKELETONS
--==================================================================
local function trex(parent: Instance, x: number, z: number, yaw: number)
	local m = Kit.Model(parent, "TRexSkeleton")
	local s = 1.7
	local P = frame(x, 2, z, yaw, s)
	-- spine: tail tip -> hips -> neck -> skull
	local spine = { P(0, 4, 34), P(0, 7, 28), P(0, 11, 21), P(0, 15, 13), P(0, 17, 5), P(0, 18, -2), P(0, 19, -8), P(0, 21.5, -12), P(0, 22.5, -15) }
	chain(m, spine, 0.6 * s, 1.4 * s, true)
	-- back spikes
	for i = 2, 7 do
		local p = spine[i]
		Kit.Part(m, V(0.4, 1.6, 0.6) * s, CFrame.new(p + V(0, 1.2 * s, 0)), BONE_D, BONE_O)
	end
	-- ribcage
	for k = 0, 5 do
		ribs(m, P, -7 + k * 1.9, 18.3 - k * 0.15, 3.2 - math.abs(k - 2.5) * 0.25, 7 - math.abs(k - 2) * 0.6, 0.45 * s)
	end
	-- pelvis
	Kit.Part(m, V(3.6, 3, 4) * s, CFrame.new(P(0, 15.5, 5)) * CFrame.Angles(0, yaw, 0.0), BONE_D, BONE_O)
	-- legs: thigh -> knee -> ankle -> toes
	for _, sx in { -1, 1 } do
		chain(m, { P(sx * 2.6, 15, 5), P(sx * 3.2, 9.5, 0.5), P(sx * 3.2, 4, 5), P(sx * 3.2, 0.8, 2) }, 1.5 * s, 0.9 * s, true)
		for _, tx in { -0.9, 0, 0.9 } do
			bone(m, P(sx * 3.2, 0.8, 2), P(sx * 3.2 + tx, 0.5, -1.2), 0.5 * s)
		end
		-- tiny arms
		chain(m, { P(sx * 1.6, 16.5, -7), P(sx * 2.2, 14.6, -8.6), P(sx * 2, 14.8, -10.2) }, 0.4 * s, 0.3 * s)
	end
	-- skull: cranium, snout, open lower jaw, teeth, eye sockets
	local head = CFrame.new(P(0, 22.5, -18)) * CFrame.Angles(0, yaw, 0)
	Kit.Part(m, V(4.2, 4.2, 4.6) * s, head * CFrame.new(0, 0.6 * s, 1.4 * s), BONE, BONE_O)
	Kit.Part(m, V(3.4, 2.6, 5.6) * s, head * CFrame.new(0, 0.2 * s, -3.2 * s), BONE, BONE_O)
	Kit.Part(m, V(3.2, 1, 7.4) * s, head * CFrame.new(0, -2.4 * s, -1.6 * s) * CFrame.Angles(0.28, 0, 0), BONE_D, BONE_O)
	for i = 0, 5 do
		for _, sx in { -1.3, 1.3 } do
			Kit.Wedge(m, V(0.35, 0.9, 0.5) * s, head * CFrame.new(sx * s, -1.3 * s, (-5.4 + i * 0.9) * s) * CFrame.Angles(math.pi, 0, 0), C(250, 245, 230))
		end
	end
	for _, sx in { -1, 1 } do
		Kit.Ball(m, 1.3 * s, (head * CFrame.new(sx * 1.85 * s, 1.4 * s, 0.4 * s)).Position, DARK)
		Kit.Ball(m, 0.6 * s, (head * CFrame.new(sx * 1.4 * s, 0.6 * s, -5.6 * s)).Position, DARK)
	end
end

local function longneck(parent: Instance, x: number, z: number, yaw: number)
	local m = Kit.Model(parent, "LongNeckSkeleton")
	local s = 1.15
	local P = frame(x, 2, z, yaw, s)
	local spine = {
		P(5, 2.5, 38), P(3, 6, 33), P(0, 11, 27), P(0, 16, 18), P(0, 19.5, 10), P(0, 22, 2), P(0, 23.5, -5),
		P(0, 27, -10), P(0, 33, -14), P(0, 40, -17), P(0, 47, -19), P(0, 53, -20),
	}
	chain(m, spine, 0.7 * s, 1.6 * s, true)
	for k = 0, 7 do
		local zz = -5 + k * 2
		ribs(m, P, zz, 23.2 - k * 0.35, 4.4 - math.abs(k - 3.5) * 0.25, 8.5 - math.abs(k - 3.5) * 0.5, 0.55 * s)
	end
	Kit.Part(m, V(5, 3.4, 5) * s, CFrame.new(P(0, 18.5, 10)) * CFrame.Angles(0, yaw, 0), BONE_D, BONE_O)
	Kit.Part(m, V(6, 2, 3) * s, CFrame.new(P(0, 21.5, -4)) * CFrame.Angles(0, yaw, 0), BONE_D, BONE_O)
	for _, sx in { -1, 1 } do
		-- front legs (tall), back legs
		chain(m, { P(sx * 3.4, 21.5, -4), P(sx * 4, 11.5, -5), P(sx * 4, 2.5, -4), P(sx * 4, 0.6, -5.2) }, 1.6 * s, 1.1 * s, true)
		chain(m, { P(sx * 3.2, 18, 10), P(sx * 3.8, 10, 12), P(sx * 3.8, 2.5, 10), P(sx * 3.8, 0.6, 8.6) }, 1.7 * s, 1.1 * s, true)
	end
	-- small head
	local head = CFrame.new(P(0, 54, -22.5)) * CFrame.Angles(0, yaw, 0)
	Kit.Part(m, V(2.4, 2.4, 3) * s, head * CFrame.new(0, 0.4 * s, 0.6 * s), BONE, BONE_O)
	Kit.Part(m, V(1.9, 1.3, 2.8) * s, head * CFrame.new(0, -0.3 * s, -1.9 * s), BONE, BONE_O)
	Kit.Part(m, V(1.7, 0.5, 3.2) * s, head * CFrame.new(0, -1.2 * s, -1.2 * s), BONE_D, BONE_O)
	for _, sx in { -1, 1 } do
		Kit.Ball(m, 0.8 * s, (head * CFrame.new(sx * 1.1 * s, 0.9 * s, 0.5 * s)).Position, DARK)
	end
end

local function triceratops(parent: Instance, x: number, z: number, yaw: number)
	local m = Kit.Model(parent, "TriceratopsSkeleton")
	local s = 1.5
	local P = frame(x, 2, z, yaw, s)
	local spine = { P(0, 3, 20), P(0, 6, 15), P(0, 9.5, 9), P(0, 11, 3), P(0, 10.5, -3), P(0, 9.5, -7) }
	chain(m, spine, 0.6 * s, 1.3 * s, true)
	for k = 0, 4 do
		ribs(m, P, -5 + k * 2, 10.6 + (if k > 2 then 0.2 else 0), 4 - math.abs(k - 2) * 0.3, 6.5 - math.abs(k - 2) * 0.5, 0.5 * s)
	end
	Kit.Part(m, V(5, 2.6, 4) * s, CFrame.new(P(0, 9.5, 8)) * CFrame.Angles(0, yaw, 0), BONE_D, BONE_O)
	for _, sx in { -1, 1 } do
		chain(m, { P(sx * 3.2, 9, 8), P(sx * 3.8, 5, 10), P(sx * 3.8, 1, 8.5), P(sx * 3.8, 0.5, 7) }, 1.4 * s, 1 * s, true)
		chain(m, { P(sx * 3.2, 8.5, -4), P(sx * 4.2, 5, -5), P(sx * 3.8, 1, -4), P(sx * 3.8, 0.5, -5.4) }, 1.3 * s, 1 * s, true)
	end
	-- skull: big frill, head block, beak, two brow horns, nose horn
	local head = CFrame.new(P(0, 8.5, -11)) * CFrame.Angles(0, yaw, 0)
	Kit.Part(m, V(10, 8, 0.8) * s, head * CFrame.new(0, 3.2 * s, 2.4 * s) * CFrame.Angles(-0.45, 0, 0), BONE_D, BONE_O)
	for k = -2, 2 do
		Kit.Ball(m, 1.2 * s, (head * CFrame.new(k * 2.1 * s, (6.4 - math.abs(k) * 0.9) * s, (3.9 + math.abs(k) * 0.1) * s)).Position, BONE, BONE_O)
	end
	Kit.Part(m, V(4, 4, 5.5) * s, head * CFrame.new(0, 0, -1.4 * s), BONE, BONE_O)
	Kit.Wedge(m, V(3, 2.6, 2.6) * s, head * CFrame.new(0, -0.6 * s, -5.3 * s) * CFrame.Angles(0, math.pi, 0), BONE, BONE_O)
	for _, sx in { -1, 1 } do
		bone(m, (head * CFrame.new(sx * 1.2 * s, 1.8 * s, -1.5 * s)).Position, (head * CFrame.new(sx * 1.9 * s, 4.6 * s, -8 * s)).Position, 0.7 * s, C(245, 238, 215))
		Kit.Ball(m, 1.1 * s, (head * CFrame.new(sx * 1.6 * s, 1.2 * s, -1 * s)).Position, DARK)
	end
	bone(m, (head * CFrame.new(0, 1.4 * s, -4.6 * s)).Position, (head * CFrame.new(0, 3 * s, -6 * s)).Position, 0.6 * s, C(245, 238, 215))
end

-- Pterosaur skeleton hanging on wires (wings spread), facing yaw.
local function pterosaur(parent: Instance, pos: Vector3, yaw: number, wireTop: number)
	local m = Kit.Model(parent, "PterosaurSkeleton")
	local k = 1.6
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local function W(lx: number, ly: number, lz: number): Vector3
		return cf:PointToWorldSpace(V(lx * k, ly * k, lz * k))
	end
	chain(m, { W(0, 0, 3), W(0, 0.3, 0), W(0, 0.8, -2.5), W(0, 1.2, -4) }, 0.5, 0.8)
	-- head with a long crest and beak
	Kit.Part(m, V(1, 1, 2) * k, CFrame.new(W(0, 1.3, -5)) * CFrame.Angles(0, yaw, 0), BONE, BONE_O)
	bone(m, W(0, 1.2, -6), W(0, 0.9, -9), 0.5)
	bone(m, W(0, 1.6, -4.4), W(0, 2.4, -1.4), 0.35)
	for _, sx in { -1, 1 } do
		-- arm bone, long finger and a thin bony wing panel
		chain(m, { W(sx * 0.4, 0.5, -1), W(sx * 5, 1.6, -1.5), W(sx * 13, 0.8, -0.5) }, 0.45, 0.3)
		Kit.Part(m, V(12 * k, 0.1, 3.6 * k), CFrame.new(W(sx * 7, 0.9, 0.6)) * CFrame.Angles(0, yaw, sx * 0.05), BONE_D, { Mat = Enum.Material.Limestone, Transp = 0.35 })
		bone(m, W(sx * 0.4, -0.2, 2), W(sx * 1.4, -1.5, 3.4), 0.3)
	end
	for _, w in { W(-5, 1.6, -1.5), W(5, 1.6, -1.5), W(0, 0.8, -2.5) } do
		Kit.Box(m, V(w.X - 0.06, w.Y, w.Z - 0.06), V(w.X + 0.06, wireTop, w.Z + 0.06), DARK)
	end
end

--==================================================================
-- OTHER EXHIBITS
--==================================================================
local function mammoth(parent: Instance, x: number, z: number, yaw: number)
	local m = Kit.Model(parent, "WoollyMammoth")
	local top = plinth(m, x - 13, z - 12, x + 13, z + 12, 2)
	local cf = CFrame.new(x, top, z) * CFrame.Angles(0, yaw, 0)
	local function L(lx: number, ly: number, lz: number): CFrame
		return cf * CFrame.new(lx, ly, lz)
	end
	local fur: Kit.Opts = { Mat = FABRIC }
	-- shaggy body, hump, legs
	Kit.Part(m, V(9, 9, 15), L(0, 10, 1), FUR, { Mat = FABRIC, Shape = Enum.PartType.Ball })
	Kit.Part(m, V(10, 8.5, 13), L(0, 9.5, 2), FUR, fur)
	Kit.Part(m, V(7, 6, 6), L(0, 15, -2), FUR_D, { Mat = FABRIC, Shape = Enum.PartType.Ball })
	for _, p in { { -3, -3.5 }, { 3, -3.5 }, { -3, 6.5 }, { 3, 6.5 } } do
		Kit.Part(m, V(3.2, 7, 3.2), L(p[1], 3.5, p[2]), FUR_D, fur)
		Kit.Part(m, V(3.4, 0.8, 3.4), L(p[1], 0.4, p[2]), C(70, 60, 55))
		-- shaggy fringe at the knees
		Kit.Part(m, V(3.8, 1.6, 3.8), L(p[1], 6.4, p[2]), FUR, fur)
	end
	-- head, ears, eyes, trunk, tusks, tail
	Kit.Part(m, V(6, 6.5, 5), L(0, 13, -8.5), FUR, fur)
	Kit.Part(m, V(5, 3, 4), L(0, 16.5, -8), FUR_D, { Mat = FABRIC, Shape = Enum.PartType.Ball })
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.6, 2.4, 2), L(sx * 3.2, 13.5, -7.5), FUR_D, fur)
		Kit.Ball(m, 0.8, L(sx * 2.1, 14.2, -11).Position, DARK)
	end
	local tr = { L(0, 11.5, -11).Position, L(0, 8, -12.4).Position, L(0, 4.5, -12.8).Position, L(0, 2.6, -11.8).Position }
	for i = 1, #tr - 1 do
		local a, b = tr[i], tr[i + 1]
		Kit.Part(m, V(1.8 - i * 0.3, 1.8 - i * 0.3, (b - a).Magnitude + 0.6), CFrame.lookAt((a + b) / 2, b), FUR_D, fur)
	end
	for _, sx in { -1, 1 } do
		chain(m, { L(sx * 1.8, 10, -10.6).Position, L(sx * 2.6, 6.5, -13.5).Position, L(sx * 3.4, 6.2, -17).Position, L(sx * 2.4, 8.4, -19).Position }, 1, 0.55)
	end
	bone(m, L(0, 11, 8.5).Position, L(0, 8.5, 9.8).Position, 0.6, FUR_D)
	Kit.AddRect(x - 15, z - 15, x + 15, z + 15)
end

local function volcano(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "VolcanoDiorama")
	-- table with wooden skirt and a low glass fence
	Kit.Box(m, V(x - 15, 0, z - 15), V(x + 15, 3.2, z + 15), WAIN, { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 15.3, 3.2, z - 15.3), V(x + 15.3, 3.6, z + 15.3), BRASS, BRASS_O)
	Kit.Box(m, V(x - 14.8, 3.6, z - 14.8), V(x + 14.8, 3.8, z + 14.8), C(110, 140, 70), { Mat = Enum.Material.Grass })
	for _, sd in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
		local cx, cz = x + sd[1] * 15.1, z + sd[2] * 15.1
		local hx, hz = if sd[1] ~= 0 then 0.15 else 15, if sd[2] ~= 0 then 0.15 else 15
		Kit.Box(m, V(cx - hx, 3.6, cz - hz), V(cx + hx, 6, cz + hz), C(200, 230, 255), { Mat = GLASS, Transp = 0.6 })
	end
	-- the volcano: stacked cones of rock, a crater and lava runs
	local rock = C(92, 70, 60)
	for i = 0, 6 do
		local d = 20 - i * 2.6
		Kit.Disc(m, x + 1, z + 1, 3.8 + (i + 1) * 2, d, 2, rock:Lerp(C(60, 45, 40), i / 7), { Mat = Enum.Material.Basalt })
	end
	Kit.Disc(m, x + 1, z + 1, 17.85, 4.6, 0.3, C(255, 120, 40), { Mat = NEON })
	local lava = { { 0.4, 0.8 }, { -0.9, 0.2 }, { 0.2, -1 } }
	for _, l in lava do
		local dx, dz = l[1], l[2]
		local len = math.sqrt(dx * dx + dz * dz)
		for k = 0, 2 do
			local r = 2.6 + k * 2.5
			Kit.Part(m, V(1, 0.4, 2.6), CFrame.lookAt(V(x + 1 + dx / len * r, 16.8 - k * 4.2, z + 1 + dz / len * r), V(x + 1 + dx / len * (r + 3), 12.6 - k * 4.2, z + 1 + dz / len * (r + 3))), C(255, 130, 40), { Mat = if k == 0 then NEON else Enum.Material.SmoothPlastic })
		end
	end
	local glow = Kit.Ball(m, 1.2, V(x + 1, 18.4, z + 1), C(255, 150, 60), { Mat = NEON, Transp = 0.3 })
	Kit.Light(glow, C(255, 140, 60), 26, 0.9)
	local smoke = Kit.Part(m, V(3, 1, 3), CFrame.new(x + 1, 19.5, z + 1), C(255, 255, 255), { Transp = 1, Name = "VolcanoSmoke" })
	Kit.Emitter(smoke, C(120, 110, 110), 3, 4, 1.2)
	-- little palm trees and tiny dinosaurs on the diorama
	for _, t in { { -10, -9 }, { -11, 8 }, { 10, -10 }, { 9, 10 }, { -4, 11 } } do
		local tx, tz = x + t[1], z + t[2]
		Kit.Cyl(m, 3, 0.4, CFrame.new(tx, 5.3, tz), C(120, 90, 60))
		for k = 0, 3 do
			Kit.Part(m, V(2.4, 0.15, 0.7), CFrame.new(tx, 6.8, tz) * CFrame.Angles(0, k * math.pi / 2, -0.3) * CFrame.new(1, 0, 0), C(60, 150, 70))
		end
	end
	local minis: { { x: number, z: number, col: Color3 } } = { { x = -7, z = 2, col = C(90, 160, 80) }, { x = 6, z = -6, col = C(200, 120, 60) }, { x = 6, z = 7, col = C(110, 130, 200) } }
	for i, d in minis do
		local dx, dz, col = d.x, d.z, d.col
		local dcf = CFrame.new(x + dx, 4.6, z + dz) * CFrame.Angles(0, i * 1.7, 0)
		Kit.Part(m, V(1, 1, 2), dcf, col)
		Kit.Part(m, V(0.5, 1.6, 0.5), dcf * CFrame.new(0, 0.9, -1), col)
		Kit.Part(m, V(0.4, 0.4, 1.4), dcf * CFrame.new(0, -0.1, 1.5), col)
	end
	plaque(m, x - 18, z - 12, -1, 0, "VOLCANO TIME!")
	Kit.AddRect(x - 19, z - 18, x + 18, z + 18)
end

local function meteor(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "Meteor")
	Kit.Disc(m, x, z, 2, 16, 2, PLINTH, { Mat = MARBLE, Solid = true })
	Kit.Disc(m, x, z, 2.3, 16.6, 0.3, BRASS, BRASS_O)
	local rock: Kit.Opts = { Mat = Enum.Material.Basalt, Solid = true }
	Kit.Ball(m, 9, V(x, 6.5, z), C(55, 52, 58), rock)
	Kit.Ball(m, 6, V(x + 2.6, 8.6, z - 1.5), C(70, 64, 70), rock)
	Kit.Ball(m, 5, V(x - 2.8, 5.4, z + 2), C(48, 45, 52), rock)
	Kit.Ball(m, 4, V(x + 1, 10, z + 2), C(62, 58, 64), rock)
	-- glowing cracks (small, the accent green)
	for i, c in { V(-3.6, 7, -2.4), V(3.4, 6, 2.4), V(0.4, 10.6, -2.6), V(-1.4, 4.4, 4) } do
		Kit.Part(m, V(0.3, 2.4, 0.3), CFrame.new(x + c.X, c.Y, z + c.Z) * CFrame.Angles(0.4 * i, i, 0.6), C(160, 255, 140), { Mat = NEON })
	end
	local core = Kit.Part(m, V(1, 1, 1), CFrame.new(x, 7, z), C(160, 255, 140), { Transp = 1, Name = "MeteorGlow" })
	Kit.Light(core, C(150, 255, 140), 18, 0.7)
	-- a little rock chip floating off it
	local chip = Kit.Ball(m, 1.4, V(x + 4, 13, z + 3), C(70, 64, 70), { Mat = Enum.Material.Basalt, Name = "FloatingRock" })
	Kit.Float(chip, 0.8)
	plaque(m, x + 10, z - 6, 1, 0, "THE BIG METEOR")
	Kit.AddRect(x - 10, z - 10, x + 12, z + 10)
end

-- A glass display case on a wooden stand with a small exhibit inside.
local function displayCase(parent: Instance, x: number, z: number, kind: number)
	local m = Kit.Model(parent, "DisplayCase")
	Kit.Box(m, V(x - 3, 0, z - 2), V(x + 3, 3, z + 2), WAIN, { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 3.1, 3, z - 2.1), V(x + 3.1, 3.3, z + 2.1), BRASS, BRASS_O)
	Kit.Box(m, V(x - 2.9, 3.3, z - 1.9), V(x + 2.9, 6.6, z + 1.9), C(200, 230, 255), { Mat = GLASS, Transp = 0.55 })
	Kit.Box(m, V(x - 3.1, 6.6, z - 2.1), V(x + 3.1, 6.9, z + 2.1), BRASS, BRASS_O)
	Kit.Box(m, V(x - 2.6, 3.3, z - 1.6), V(x + 2.6, 3.5, z + 1.6), C(90, 30, 40), { Mat = FABRIC })
	if kind == 1 then
		-- dino egg nest
		for i = 0, 2 do
			Kit.Part(m, V(1.1, 1.5, 1.1), CFrame.new(x - 1.3 + i * 1.3, 4.3, z + (i % 2) * 0.4), C(225, 215, 180), { Shape = Enum.PartType.Ball })
		end
	elseif kind == 2 then
		-- amber with a bug inside
		Kit.Part(m, V(1.8, 1.4, 1.4), CFrame.new(x, 4.3, z) * CFrame.Angles(0.3, 0.5, 0.2), AMBER, { Mat = GLASS, Transp = 0.15 })
		Kit.Ball(m, 0.4, V(x, 4.3, z), DARK)
	elseif kind == 3 then
		-- ammonite shell
		Kit.CylFlat(m, 0.6, 2.6, V(x, 4.9, z), "X", C(190, 150, 110))
		Kit.CylFlat(m, 0.7, 1.6, V(x, 4.9, z), "X", C(150, 110, 80))
		Kit.CylFlat(m, 0.8, 0.7, V(x, 4.9, z), "X", C(120, 90, 60))
	else
		-- raptor claw + a little skull
		Kit.Part(m, V(0.5, 1.6, 0.5), CFrame.new(x - 1, 4.3, z) * CFrame.Angles(0, 0, 0.5), BONE, BONE_O)
		Kit.Part(m, V(1.6, 1.1, 2), CFrame.new(x + 1, 4.1, z), BONE, BONE_O)
		Kit.Ball(m, 0.5, V(x + 1.5, 4.3, z - 0.5), DARK)
	end
	Kit.AddCircle(x, z, 4)
end

local function digSite(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local m = Kit.Model(parent, "DigSite")
	Kit.Box(m, V(x1, 0, z1), V(x2, 0.6, z2), C(214, 186, 130), { Mat = Enum.Material.Sand, Solid = true })
	for _, e in { { x1, z1, x2, z1 + 1 }, { x1, z2 - 1, x2, z2 }, { x1, z1, x1 + 1, z2 }, { x2 - 1, z1, x2, z2 } } do
		Kit.Box(m, V(e[1], 0, e[2]), V(e[3], 1.4, e[4]), C(140, 100, 60), { Mat = WOODP, Solid = true })
	end
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	-- half-buried bones and a skull poking out
	for i, b in { { -6, -3, -2, -5 }, { 4, 2, 9, 4 }, { -2, 4, 2, 6 }, { 6, -5, 8, -1 } } do
		bone(m, V(cx + b[1], 0.7, cz + b[2]), V(cx + b[3], 0.9 + (i % 2) * 0.4, cz + b[4]), 0.8)
	end
	Kit.Part(m, V(3, 2, 3.6), CFrame.new(cx - 8, 0.9, cz + 3) * CFrame.Angles(0.2, 0.6, 0), BONE, BONE_O)
	-- string grid, a bucket, a spade
	for k = 1, 3 do
		local xx = x1 + (x2 - x1) * k / 4
		Kit.Box(m, V(xx - 0.05, 1.3, z1 + 1), V(xx + 0.05, 1.4, z2 - 1), C(245, 240, 220))
	end
	Kit.Cyl(m, 2, 2, CFrame.new(x2 - 4, 1.6, z1 + 4), C(220, 70, 60))
	Kit.Part(m, V(0.4, 4, 0.4), CFrame.new(x2 - 7, 2.6, z1 + 3) * CFrame.Angles(0, 0, 0.4), C(150, 110, 70))
	Kit.Part(m, V(1.6, 0.2, 2), CFrame.new(x2 - 7.8, 0.8, z1 + 3) * CFrame.Angles(0, 0, 0.4), C(150, 155, 165), BRASS_O)
	Props.SignBoard(m, V(cx, 5, z1 - 0.6), 10, 2.4, 0, -1, "LITTLE DIGGERS", C(40, 90, 60), C(255, 240, 200), BRASS)
	for _, sx in { -4.4, 4.4 } do
		Kit.Box(m, V(cx + sx - 0.2, 0, z1 - 0.8), V(cx + sx + 0.2, 4, z1 - 0.4), C(140, 100, 60), { Mat = WOOD })
	end
	Kit.AddRect(x1 - 2, z1 - 2, x2 + 2, z2 + 2)
end

--==================================================================
-- GROUND, WALLS, ROOF
--==================================================================
-- Flat three-toed footprint at (x, z) pointing along yaw, size s.
local function footprint(parent: Instance, x: number, z: number, yaw: number, s: number, y: number, col: Color3)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(parent, V(1.6 * s, 0.03, 1.8 * s), cf, col)
	for _, a in { -0.5, 0, 0.5 } do
		Kit.Part(parent, V(0.55 * s, 0.03, 2.2 * s), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.005, -1.8 * s), col)
	end
end

local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), FLOOR, { Mat = MARBLE, Solid = true, Name = "Ground_DinoMuseum" })
	-- darker checker tiles (flat) and thin grout lines
	local T = 28
	for ix = 0, 9 do
		for iz = 0, 12 do
			if (ix + iz) % 2 == 0 then
				local x = -140 + ix * T
				local z = Z0 + 4 + iz * T
				Kit.Box(f, V(x + 0.3, 0, z + 0.3), V(x + T - 0.3, 0.03, math.min(z + T, Z1 - 4) - 0.3), FLOOR_D, { Mat = MARBLE })
			end
		end
	end
	-- red carpet runner with brass edges
	Kit.Box(f, V(-7, 0, Z0), V(7, 0.08, Z1), CARPET, { Mat = FABRIC, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 7, 0, Z0), V(s * 8.2, 0.1, Z1), Kit.Vivid(BRASS), BRASS_O)
		Kit.Box(f, V(s * 5.6, 0.08, Z0), V(s * 6, 0.1, Z1), C(220, 180, 90))
	end
	-- inlaid medallions on the ghost areas: brass ring, slate disc, ammonite spiral
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.1, r * 2 + 2, 0.1, Kit.Vivid(BRASS), BRASS_O)
		Kit.Disc(f, x, z, 0.13, r * 2 - 1, 0.13, if i % 2 == 0 then C(96, 104, 112) else C(118, 112, 104), { Mat = MARBLE })
		Kit.Disc(f, x, z, 0.16, r * 1.5, 0.03, FLOOR, { Mat = MARBLE })
		Kit.Disc(f, x, z, 0.18, r * 1.4, 0.03, if i % 2 == 0 then C(96, 104, 112) else C(118, 112, 104), { Mat = MARBLE })
		-- spiral of brass segments
		local n = 14
		for k = 0, n - 1 do
			local t = k / n
			local ang = t * math.pi * 3.2
			local rr = r * (0.08 + 0.55 * t)
			Kit.Part(f, V(r * 0.09 + 0.6, 0.03, r * 0.16), CFrame.new(x + math.cos(ang) * rr, 0.2, z + math.sin(ang) * rr) * CFrame.Angles(0, -ang, 0), BRASS, BRASS_O)
		end
	end
	-- boss: giant fossil footprint medallion
	Kit.Disc(f, 0, BOSS_Z, 0.1, 56, 0.1, Kit.Vivid(BRASS), BRASS_O)
	Kit.Disc(f, 0, BOSS_Z, 0.13, 53, 0.13, C(84, 78, 74), { Mat = MARBLE })
	Kit.Disc(f, 0, BOSS_Z, 0.16, 46, 0.03, C(214, 186, 130), { Mat = Enum.Material.Sandstone })
	footprint(f, 0, BOSS_Z + 4, 0, 6.5, 0.18, C(120, 98, 76))
	for k = 0, 11 do
		local ang = k * math.pi / 6
		Kit.Part(f, V(3, 0.03, 0.7), CFrame.new(math.cos(ang) * 24.6, 0.17, BOSS_Z + math.sin(ang) * 24.6) * CFrame.Angles(0, -ang, 0), C(60, 55, 52))
	end
	-- a trail of little dino footprints across the floor (flat)
	local trail = { { -50, Z0 + 46 }, { -44, Z0 + 52 }, { -40, Z0 + 60 }, { -34, Z0 + 64 }, { -30, Z0 + 72 } }
	for i, t in trail do
		footprint(f, t[1] + (if i % 2 == 0 then 1.6 else -1.6), t[2], -0.6, 1, 0.05, C(150, 120, 90))
	end
end

local function walls(f: Instance)
	local z0, z1 = Z0 + 4, Z1 - 4
	for _, s in { -1, 1 } do
		local xi = s * 140 -- inner face
		Kit.Box(f, V(xi, -0.5, z0), V(s * 146, WALL_H, z1), WALL, { Mat = Enum.Material.Plaster, Solid = true, Shadow = true })
		-- dark wood wainscot, cornice, frieze band
		Kit.Box(f, V(xi - s * 0.6, 0, z0), V(xi, 6, z1), WAIN, { Mat = WOOD })
		Kit.Box(f, V(xi - s * 0.9, 6, z0), V(xi, 6.6, z1), WAIN_D, { Mat = WOOD })
		Kit.Box(f, V(xi - s * 0.3, 29, z0), V(xi, 30.5, z1), GREEN, { Mat = MARBLE })
		Kit.Box(f, V(xi - s * 1.6, WALL_H - 1.4, z0), V(s * 146.5, WALL_H + 0.6, z1), WALL_D, { Mat = MARBLE })
		-- tall arched night windows with moonlit glass, between pilasters
		local wz = Z0 + 26
		while wz < Z1 - 20 do
			Kit.Box(f, V(xi - s * 0.2, 11, wz - 5), V(xi + s * 0.3, 24, wz + 5), NIGHT, { Mat = GLASS, Refl = 0.2 })
			Kit.CylFlat(f, 0.5, 10, V(xi + s * 0.05, 24, wz), "X", NIGHT, { Mat = GLASS, Refl = 0.2 })
			Kit.Box(f, V(xi - s * 0.4, 10.4, wz - 5.6), V(xi, 11, wz + 5.6), WALL_D, { Mat = MARBLE })
			Kit.Box(f, V(xi - s * 0.35, 11, wz - 0.25), V(xi, 28.6, wz + 0.25), IRON, IRON_O)
			wz += 40
		end
		-- pilasters with capitals
		local pz = Z0 + 46
		while pz < Z1 - 10 do
			Kit.Box(f, V(xi - s * 1.6, 0, pz - 2), V(xi, WALL_H - 1.4, pz + 2), WALL, { Mat = MARBLE, Solid = true })
			Kit.Box(f, V(xi - s * 2.2, 0, pz - 2.6), V(xi, 2, pz + 2.6), WALL_D, { Mat = MARBLE, Solid = true })
			Kit.Box(f, V(xi - s * 2.2, WALL_H - 4, pz - 2.6), V(xi, WALL_H - 2.6, pz + 2.6), WALL_D, { Mat = MARBLE })
			pz += 40
		end
	end
end

-- Arched iron ribs across the hall (bottom > 46 at |X| < 110), purlins between them.
local RIB_ZS = { Z0 + 46, Z0 + 86, Z0 + 126, Z0 + 166, Z0 + 206, Z0 + 246, Z0 + 286, Z0 + 326 }
local function ribY(x: number): number
	local t = math.clamp(math.abs(x) / 140, 0, 1)
	return WALL_H + 36 * math.sqrt(1 - t * t)
end

local function roof(f: Instance)
	local N = 10
	for _, z in RIB_ZS do
		for i = 0, N - 1 do
			local xa = -140 + 280 * i / N
			local xb = -140 + 280 * (i + 1) / N
			local a, b = V(xa, ribY(xa), z), V(xb, ribY(xb), z)
			local len = (b - a).Magnitude
			Kit.Part(f, V(1.4, 2.2, len + 0.6), CFrame.lookAt((a + b) / 2, b), IRON, IRON_O)
		end
		-- brass boss at the crown
		Kit.Ball(f, 2.4, V(0, ribY(0) - 0.6, z), BRASS, BRASS_O)
	end
	-- purlins along Z at a few heights
	for _, x in { -100, -60, -20, 20, 60, 100 } do
		local y = ribY(x)
		Kit.Box(f, V(x - 0.4, y - 0.4, Z0 + 4), V(x + 0.4, y + 0.4, Z1 - 4), IRON, IRON_O)
	end
end

--==================================================================
-- FURNITURE AND DECOR
--==================================================================
local function column(f: Instance, x: number, z: number)
	Kit.Box(f, V(x - 2.6, 0, z - 2.6), V(x + 2.6, 1.6, z + 2.6), WALL_D, { Mat = MARBLE, Solid = true })
	Kit.Cyl(f, WALL_H - 4.6, 3.6, CFrame.new(x, 1.6 + (WALL_H - 4.6) / 2, z), WALL, { Mat = MARBLE, Solid = true })
	Kit.Box(f, V(x - 2.8, WALL_H - 3, z - 2.8), V(x + 2.8, WALL_H - 1.4, z + 2.8), WALL_D, { Mat = MARBLE })
	Kit.AddCircle(x, z, 3.2)
end

local function banner(f: Instance, x: number, z: number, s: number, text: string, col: Color3)
	-- a tall fabric banner hanging in front of the wall from a brass rod
	local xi = s * 137.9
	Kit.Box(f, V(xi - 0.2, 27.4, z - 4.6), V(xi + 0.2, 27.8, z + 4.6), BRASS, BRASS_O)
	local cf = CFrame.new(xi, 19, z) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0)
	local p = Kit.Part(f, V(8, 16, 0.25), cf, col, { Mat = FABRIC, Name = "SignBoard" })
	Kit.Sign(p, Enum.NormalId.Front, text, C(255, 240, 200))
	-- notched bottom
	for _, dx in { -2.7, 0, 2.7 } do
		Kit.Wedge(f, V(2.6, 1.6, 0.25), cf * CFrame.new(dx, -8.8, 0) * CFrame.Angles(math.pi, 0, 0), col, { Mat = FABRIC })
	end
end

local function bench(f: Instance, x: number, z: number, alongZ: boolean)
	local hx, hz = if alongZ then 1.4 else 5, if alongZ then 5 else 1.4
	Kit.Box(f, V(x - hx, 1.8, z - hz), V(x + hx, 2.4, z + hz), C(120, 40, 45), { Mat = Enum.Material.Leather, Solid = true })
	Kit.Box(f, V(x - hx + 0.3, 0, z - hz + 0.3), V(x + hx - 0.3, 1.8, z + hz - 0.3), WAIN_D, { Mat = WOOD, Solid = true })
	Kit.AddCircle(x, z, 5.5)
end

local function infoDesk(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "InfoDesk")
	Kit.Box(m, V(x - 8, 0, z - 2), V(x + 8, 4, z + 2), WAIN, { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 8.3, 4, z - 2.3), V(x + 8.3, 4.5, z + 2.3), WALL, { Mat = MARBLE })
	for _, dx in { -5, 0, 5 } do
		Kit.Box(m, V(x + dx - 1.6, 0.8, z + 2), V(x + dx + 1.6, 3.4, z + 2.1), WAIN_D, { Mat = WOOD })
	end
	-- brochure rack, little bell, a green banker's lamp
	Kit.Box(m, V(x - 6.5, 4.5, z - 1), V(x - 4.5, 5.6, z + 1), C(240, 235, 220))
	Kit.Ball(m, 0.8, V(x + 1, 4.9, z + 1), BRASS, BRASS_O)
	Kit.Cyl(m, 1.4, 0.3, CFrame.new(x + 5, 5.2, z), BRASS, BRASS_O)
	Kit.Part(m, V(2.4, 0.8, 1.2), CFrame.new(x + 5, 6.1, z), C(40, 140, 80), { Mat = GLASS, Transp = 0.15 })
	Kit.Part(m, V(0.4, 0.4, 0.4), CFrame.new(x + 5, 5.6, z), C(255, 230, 170), { Mat = NEON })
	Props.SignBoard(m, V(x, 9.6, z - 0.2), 10, 2.4, 0, 1, "INFORMATION", GREEN, C(255, 240, 200), BRASS)
	for _, dx in { -4.6, 4.6 } do
		Kit.Box(m, V(x + dx - 0.15, 4.5, z - 0.6), V(x + dx + 0.15, 8.4, z - 0.3), BRASS, BRASS_O)
	end
	Kit.AddRect(x - 10, z - 4, x + 10, z + 5)
end

local function giftShop(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GiftShop")
	Kit.Box(m, V(x - 7, 0, z - 3), V(x + 7, 3.6, z + 3), C(40, 100, 70), { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 7.3, 3.6, z - 3.3), V(x + 7.3, 4, z + 3.3), BRASS, BRASS_O)
	-- plush dinos on the counter
	for i, col in { C(110, 200, 110), C(250, 160, 200), C(130, 170, 250), C(250, 210, 90), C(180, 130, 230) } do
		local px = x - 6 + i * 2
		Kit.Ball(m, 1.6, V(px, 4.8, z), col, { Mat = FABRIC })
		Kit.Ball(m, 1, V(px, 6, z - 0.5), col, { Mat = FABRIC })
		Kit.Ball(m, 0.25, V(px - 0.25, 6.2, z - 1), DARK)
	end
	for _, dx in { -6.6, 6.6 } do
		Kit.Box(m, V(x + dx - 0.25, 4, z + 2.4), V(x + dx + 0.25, 11, z + 2.9), WAIN_D, { Mat = WOOD })
	end
	for i = 0, 6 do
		Kit.Wedge(m, V(14.6 / 7, 1.4, 3.6), CFrame.new(x - 7.3 + (i + 0.5) * 14.6 / 7, 11.6, z + 1.2), if i % 2 == 0 then GREEN else C(240, 230, 200), { Mat = FABRIC })
	end
	Props.SignBoard(m, V(x, 9.4, z + 2.4), 11, 2, 0, -1, "DINO GIFTS", C(40, 100, 70), C(255, 240, 200))
	Kit.AddRect(x - 9, z - 5, x + 9, z + 5)
end

local function skeletons(f: Instance)
	-- T-rex: right front, roaring toward the entrance
	local tx, tz = 104, Z0 + 100
	plinth(f, tx - 15, tz - 36, tx + 15, tz + 46, 2)
	ropes(f, tx - 18, tz - 39, tx + 18, tz + 49)
	trex(f, tx, tz, 0.12)
	plaque(f, tx - 21, tz - 34, -1, -1, "T-REX: KING OF BONES")
	-- long-neck: left back, its neck rising high toward the hall
	local lx, lz = -96, Z0 + 306
	plinth(f, -136, lz - 11, -84, lz + 11, 2)
	ropes(f, -138, lz - 14, -81, lz + 14)
	longneck(f, lx, lz, -math.pi / 2)
	plaque(f, -78, lz - 12, 1, -1, "LONG-NECK: TALLEST TALE")
	-- triceratops: right back, facing the lane
	local cx, cz = 106, Z0 + 248
	plinth(f, cx - 26, cz - 10, cx + 30, cz + 10, 2)
	ropes(f, cx - 29, cz - 13, cx + 32, cz + 13)
	triceratops(f, cx, cz, math.pi / 2)
	plaque(f, cx - 31, cz - 12, -1, -1, "THREE-HORN FACE")
	-- the woolly mammoth: left front
	mammoth(f, -104, Z0 + 56, -math.pi / 2)
	ropes(f, -120, Z0 + 41, -88, Z0 + 71)
	plaque(f, -84, Z0 + 40, 1, -1, "ICE AGE GIANT")
	-- pterosaurs hanging from the roof ribs, high over the hall
	pterosaur(f, V(-14, 50, Z0 + 46), 0.6, ribY(-14))
	pterosaur(f, V(48, 52, Z0 + 166), -0.9, ribY(48))
	pterosaur(f, V(-40, 48, Z0 + 286), 2.4, ribY(-40))
end

local function decor(f: Instance)
	-- free-standing marble columns lining the hall
	for z = Z0 + 26, Z1 - 20, 40 do
		for _, s in { -1, 1 } do
			if Kit.IsFree(s * 128, z, 3.2) then
				column(f, s * 128, z)
			end
		end
	end
	-- banners on the walls
	type Banner = { s: number, z: number, text: string, col: Color3 }
	local bl: { Banner } = {
		{ s = -1, z = Z0 + 46, text = "WELCOME", col = OCHRE }, { s = -1, z = Z0 + 126, text = "AGE OF DINOS", col = CRIMSON },
		{ s = -1, z = Z0 + 206, text = "BIG BONES", col = NAVY }, { s = -1, z = Z0 + 326, text = "SPACE ROCKS", col = GREEN },
		{ s = 1, z = Z0 + 46, text = "DINO HALL", col = GREEN }, { s = 1, z = Z0 + 166, text = "FOSSILS!", col = CRIMSON },
		{ s = 1, z = Z0 + 246, text = "NIGHT TOURS", col = NAVY }, { s = 1, z = Z0 + 326, text = "ROAR!", col = OCHRE },
	}
	for _, b in bl do
		banner(f, 0, b.z, b.s, b.text, b.col)
	end
	-- welcome banner hung over the entrance from the first rib
	local bz = Z0 + 46
	for _, sx in { -10, 10 } do
		Kit.Box(f, V(sx - 0.1, 33, bz - 0.1), V(sx + 0.1, ribY(sx), bz + 0.1), DARK)
	end
	local wb = Kit.Part(f, V(26, 5, 0.4), CFrame.new(0, 30.5, bz), CRIMSON, { Mat = FABRIC, Name = "SignBoard" })
	Kit.Sign(wb, Enum.NormalId.Front, "DINO FOSSIL MUSEUM", C(255, 230, 150))
	Kit.Sign(wb, Enum.NormalId.Back, "DINO FOSSIL MUSEUM", C(255, 230, 150))
	Kit.Box(f, V(-13.5, 33, bz - 0.35), V(13.5, 33.6, bz + 0.35), BRASS, BRASS_O)
	-- display cases along the lane
	local cases = { { -20, Z0 + 132 }, { 20, Z0 + 140 }, { 20, Z0 + 196 }, { -20, Z0 + 196 }, { 22, Z0 + 260 }, { -24, Z0 + 264 } }
	for i, c in cases do
		if Kit.IsFree(c[1], c[2], 4) then
			displayCase(f, c[1], c[2], (i - 1) % 4 + 1)
		end
	end
	infoDesk(f, -66, Z0 + 18)
	giftShop(f, 60, Z0 + 20)
	digSite(f, -124, Z0 + 162, -96, Z0 + 196)
	volcano(f, 74, Z0 + 312)
	meteor(f, -112, Z0 + 236)
	-- benches for tired explorers
	type Bench = { x: number, z: number, alongZ: boolean }
	local benches: { Bench } = { { x = -40, z = Z0 + 170, alongZ = true }, { x = 42, z = Z0 + 230, alongZ = true }, { x = 46, z = Z0 + 108, alongZ = false }, { x = -30, z = Z0 + 216, alongZ = false } }
	for _, b in benches do
		if Kit.IsFree(b.x, b.z, 5.5) then
			bench(f, b.x, b.z, b.alongZ)
		end
	end
	-- potted ferns by the columns
	for _, p in { { -120, Z0 + 110 }, { 120, Z0 + 150 }, { -120, Z0 + 220 }, { 120, Z0 + 330 }, { -48, Z0 + 30 }, { 46, Z0 + 46 } } do
		if Kit.IsFree(p[1], p[2], 2.5) then
			Kit.Cyl(f, 2.4, 3, CFrame.new(p[1], 1.2, p[2]), C(160, 90, 60), { Mat = Enum.Material.Slate, Solid = true })
			for k = 0, 4 do
				Kit.Part(f, V(0.5, 0.2, 4), CFrame.new(p[1], 3, p[2]) * CFrame.Angles(0, k * 1.26, 0) * CFrame.Angles(0.6, 0, 0) * CFrame.new(0, 0, -1.8), C(60, 140, 70), { Mat = Enum.Material.Grass })
			end
			Kit.AddCircle(p[1], p[2], 2.5)
		end
	end
	-- soft exhibit lights (modest): over the T-rex, long-neck, trike, mammoth and two wall lamps
	for _, l in { V(96, 30, Z0 + 80), V(-112, 36, Z0 + 250), V(104, 20, Z0 + 250), V(-96, 24, Z0 + 60) } do
		local lamp = Kit.Part(f, V(1, 1, 1), CFrame.new(l), C(255, 240, 210), { Transp = 1, Name = "ExhibitLight" })
		Kit.Light(lamp, C(255, 236, 200), 40, 0.8)
	end
	for _, w in { { -1, Z0 + 166 }, { 1, Z0 + 206 } } do
		local sx = w[1] * 137.8
		Kit.Box(f, V(sx - 0.4, 12, w[2] - 0.4), V(sx + 0.4, 14, w[2] + 0.4), BRASS, BRASS_O)
		Kit.Ball(f, 1.6, V(sx, 14.8, w[2]), C(255, 238, 200), { Mat = NEON })
	end
	-- a couple of friendly glowing ghost bones drifting over the hall
	for i, p in { V(-30, 22, Z0 + 116), V(36, 26, Z0 + 286), V(-10, 30, Z0 + 230) } do
		local b = Kit.Part(f, V(0.7, 0.7, 3.4), CFrame.new(p) * CFrame.Angles(0.3, i * 1.3, 0.4), C(200, 255, 190), { Transp = 0.3, Name = "GhostBone" })
		Kit.Float(b, 1.2)
	end
end

--==================================================================
-- BUILD
--==================================================================
function DinoMuseum.Build(map: Instance)
	local f = Kit.Folder(map, "DinoMuseum")
	ground(f)
	walls(f)
	roof(f)
	skeletons(f)
	decor(f)
end

return DinoMuseum
