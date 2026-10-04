--!strict
-- TOWER PLAZA (workspace.Map.EventArena) on the old event-arena plot at the end of the cross
-- street. Two parts:
--   * an open courtyard around Config.Layout.EventArena.Center where the Giant Poltergeist event
--     still spawns: flat rune paint only, nothing taller than 0.35 studs within CLEAR_R studs of
--     the centre (so nothing solid there up to Y = 30 or higher);
--   * the ENDLESS BOSS TOWER on the east side of the plot (backed against the east hedge) with
--     the party pad (part "TowerPad", radius Config.Tower.PadRadius) in front of its door.
--     TowerService finds TowerPad and adds the "Enter Boss Tower" ProximityPrompt at runtime.
-- The keep-out reservations of the old arena (the plot circle and the two bleacher strips) stay
-- registered, so Neighborhood props still keep off the whole plot.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Arena = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local STONE = C(92, 66, 138)
local STONE_DARK = C(62, 44, 96)
local STONE_LIGHT = C(128, 98, 178)
local ROOF = C(70, 40, 110)
local ECTO = C(110, 255, 160)
local CLEAR_R = 22 -- courtyard: only flat paint inside this radius
local PAD_OFFSET = 19 -- pad centre is this far east of the courtyard centre

local function ring(parent: Instance, cx: number, cz: number, r: number, n: number, w: number, color: Color3, topY: number)
	local segLen = 2 * math.pi * r / n + 0.4
	local paint = Kit.Vivid(color)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = V(cx + math.cos(a) * r, topY - 0.1, cz + math.sin(a) * r)
		local tangent = V(-math.sin(a), 0, math.cos(a))
		Kit.Part(parent, V(w, 0.2, segLen), CFrame.lookAt(p, p + tangent), paint)
	end
end

-- A stone post with a small glowing ghost lantern on top (optionally lit).
local function lantern(parent: Instance, x: number, z: number, h: number, light: boolean)
	Kit.Box(parent, V(x - 0.8, 0, z - 0.8), V(x + 0.8, h, z + 0.8), STONE_DARK, { Mat = Enum.Material.Slate, Solid = true })
	Kit.Box(parent, V(x - 1.2, h, z - 1.2), V(x + 1.2, h + 0.5, z + 1.2), STONE_LIGHT, { Mat = Enum.Material.Slate })
	Kit.Box(parent, V(x - 0.9, h + 0.5, z - 0.9), V(x + 0.9, h + 3.1, z + 0.9), C(40, 30, 60), { Mat = Enum.Material.Glass, Transp = 0.55 })
	local glow = Kit.Ball(parent, 1.3, V(x, h + 1.8, z), ECTO, { Mat = NEON })
	Kit.Box(parent, V(x - 1.2, h + 3.1, z - 1.2), V(x + 1.2, h + 3.5, z + 1.2), STONE_DARK, { Mat = Enum.Material.Metal })
	if light then
		Kit.Light(glow, ECTO, 18, 1.2, true)
	end
end

-- Crenellations along the top edge of a box footprint.
local function battlements(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number)
	local step = 3
	for x = x1, x2 - 1.5, step do
		Kit.Box(parent, V(x, y, z1), V(x + 1.5, y + 2, z1 + 1.2), STONE_LIGHT, { Mat = Enum.Material.Slate })
		Kit.Box(parent, V(x, y, z2 - 1.2), V(x + 1.5, y + 2, z2), STONE_LIGHT, { Mat = Enum.Material.Slate })
	end
	for z = z1 + step, z2 - step, step do
		Kit.Box(parent, V(x1, y, z), V(x1 + 1.2, y + 2, z + 1.5), STONE_LIGHT, { Mat = Enum.Material.Slate })
		Kit.Box(parent, V(x2 - 1.2, y, z), V(x2, y + 2, z + 1.5), STONE_LIGHT, { Mat = Enum.Material.Slate })
	end
end

-- Painted ectoplasm band (solid material + vivid colour, not Neon) on the three visible sides
-- of a box footprint (the east side is against the hedge).
local function band(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number)
	local paint = Kit.Vivid(ECTO)
	Kit.Box(parent, V(x1 - 0.3, y, z1 - 0.3), V(x2, y + 0.8, z1 + 0.2), paint)
	Kit.Box(parent, V(x1 - 0.3, y, z2 - 0.2), V(x2, y + 0.8, z2 + 0.3), paint)
	Kit.Box(parent, V(x1 - 0.3, y, z1), V(x1 + 0.2, y + 0.8, z2), paint)
end

-- Gable roof from two wedges whose tall faces meet over cz.
local function gable(parent: Instance, x: number, y: number, cz: number, width: number, height: number, depth: number)
	local half = depth / 2
	Kit.Wedge(parent, V(width, height, half), CFrame.new(x, y + height / 2, cz - half / 2), ROOF, { Mat = Enum.Material.Slate })
	Kit.Wedge(parent, V(width, height, half), CFrame.new(x, y + height / 2, cz + half / 2) * CFrame.Angles(0, math.pi, 0), ROOF, { Mat = Enum.Material.Slate })
end

-- Returns the X of the door face.
local function buildTower(m: Instance, cx: number, cz: number): number
	-- Footprint X 125..139 against the east hedge (X 140); the door faces -X (the courtyard).
	local x1, x2 = cx + 30, cx + 44
	local z1, z2 = cz - 15, cz + 15
	local stone: Kit.Opts = { Mat = Enum.Material.Slate, Solid = true }
	-- base hall
	Kit.Box(m, V(x1, 0, z1), V(x2, 30, z2), STONE, stone)
	Kit.Box(m, V(x1 - 0.6, 0, z1 - 0.6), V(x2, 2, z2 + 0.6), STONE_DARK, stone) -- plinth
	band(m, x1, z1, x2, z2, 29.2)
	battlements(m, x1, z1, x2, z2, 30)
	-- front corner turrets with pointed roofs
	for _, sz in { -1, 1 } do
		local tz = if sz < 0 then z1 + 2 else z2 - 2
		Kit.Cyl(m, 38, 6, CFrame.new(x1 + 2, 19, tz), STONE_DARK, stone)
		Kit.Cyl(m, 0.8, 6.8, CFrame.new(x1 + 2, 37.6, tz), Kit.Vivid(ECTO))
		gable(m, x1 + 2, 38, tz, 7, 6, 7)
	end
	-- upper tower
	local ux1, ux2, uz1, uz2 = x1 + 3, x2 - 1, cz - 9, cz + 9
	Kit.Box(m, V(ux1, 30, uz1), V(ux2, 62, uz2), STONE_LIGHT, stone)
	band(m, ux1, uz1, ux2, uz2, 45)
	band(m, ux1, uz1, ux2, uz2, 61.2)
	battlements(m, ux1, uz1, ux2, uz2, 62)
	-- spire with a floating ectoplasm orb
	Kit.Box(m, V(ux1 + 3, 62, uz1 + 3), V(ux2 - 3, 70, uz2 - 3), STONE_DARK, stone)
	local sx = (ux1 + ux2) / 2
	gable(m, sx, 70, cz, ux2 - ux1 - 4, 12, uz2 - uz1 - 6)
	local orb = Kit.Ball(m, 3.4, V(sx, 85, cz), ECTO, { Mat = NEON })
	Kit.Float(orb, 1.2)
	Kit.Light(orb, ECTO, 30, 1.5)
	-- glowing windows on the courtyard face (small neon accents)
	for _, wz in { -5, 0, 5 } do
		Kit.Box(m, V(ux1 - 0.25, 48, cz + wz - 1), V(ux1 + 0.1, 53, cz + wz + 1), ECTO, { Mat = NEON })
		Kit.Box(m, V(ux1 - 0.25, 35, cz + wz - 1), V(ux1 + 0.1, 40, cz + wz + 1), C(25, 15, 40))
	end
	for _, wz in { -10, 10 } do
		Kit.Box(m, V(x1 - 0.25, 18, cz + wz - 1.2), V(x1 + 0.1, 23, cz + wz + 1.2), C(255, 200, 90), { Mat = NEON })
	end
	-- carved ghost eyes high on the upper tower front
	for _, s in { -1, 1 } do
		local fz = cz + s * 4.5
		Kit.Ball(m, 1.2, V(ux1 - 0.2, 57, fz - 0.8), C(25, 15, 40))
		Kit.Ball(m, 1.2, V(ux1 - 0.2, 57, fz + 0.8), C(25, 15, 40))
	end

	-- the door: dark arch with an ectoplasm portal glow and a stone frame
	local dz1, dz2 = cz - 6, cz + 6
	Kit.Box(m, V(x1 - 0.4, 0, dz1), V(x1 + 0.2, 15, dz2), C(25, 15, 40), { Name = "TowerDoor" })
	local portal = Kit.Box(m, V(x1 - 0.55, 0.3, dz1 + 1), V(x1 - 0.45, 13.5, dz2 - 1), ECTO, { Mat = NEON, Transp = 0.45, Name = "Portal" })
	Kit.Emitter(portal, ECTO, 3, 3, 0.5)
	for _, s in { -1, 1 } do
		local pz = if s < 0 then dz1 - 1.5 else dz2 + 1.5
		Kit.Box(m, V(x1 - 2, 0, pz - 1.5), V(x1, 17, pz + 1.5), STONE_LIGHT, stone)
	end
	Kit.Box(m, V(x1 - 2, 15, dz1 - 3), V(x1, 18, dz2 + 3), STONE_LIGHT, stone)
	-- sign over the door
	local signCF = CFrame.new(x1 - 2.2, 22.5, cz) * CFrame.Angles(0, Kit.FaceYaw(-1, 0), 0)
	local sign = Kit.Part(m, V(24, 5, 0.6), signCF, C(45, 25, 80))
	Kit.Part(m, V(25, 6, 0.3), signCF * CFrame.new(0, 0, 0.45), Kit.Vivid(ECTO))
	Kit.Sign(sign, Enum.NormalId.Front, "ENDLESS BOSS TOWER", C(150, 255, 170))
	return x1
end

-- Flat party pad (top at 0.34): the TowerPad part carries the prompt (added by TowerService).
local function buildPad(m: Instance, px: number, pz: number): Part
	local r = Config.Tower.PadRadius
	Kit.Disc(m, px, pz, 0.24, r * 2 + 1.4, 0.3, Kit.Vivid(ECTO), { Solid = true })
	local pad = Kit.Disc(m, px, pz, 0.3, r * 2 - 1, 0.3, C(70, 45, 120), { Mat = Enum.Material.Slate, Solid = true, Name = "TowerPad" })
	Kit.Disc(m, px, pz, 0.34, 5, 0.08, Kit.Vivid(C(190, 120, 255)))
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		Kit.Disc(m, px + math.cos(a) * (r - 2.4), pz + math.sin(a) * (r - 2.4), 0.34, 1.6, 0.08, Kit.Vivid(ECTO))
	end
	return pad
end

function Arena.Build(map: Instance)
	local ea = Config.Layout.EventArena
	local cx, cz, r = ea.Center.X, ea.Center.Z, ea.Radius
	local m = Kit.Model(map, "EventArena")

	-- COURTYARD (flat, top 0.12): the Giant Poltergeist event spawns over its centre
	local field = Kit.Disc(m, cx, cz, 0.12, CLEAR_R * 2 + 6, 0.4, C(90, 60, 140), { Mat = Enum.Material.Slate, Solid = true, Name = "Field" })
	Kit.Disc(m, cx, cz, 0.16, CLEAR_R * 2 - 2, 0.1, C(115, 80, 180), { Solid = true })
	ring(m, cx, cz, CLEAR_R - 1, 30, 1.2, ECTO, 0.32)
	ring(m, cx, cz, CLEAR_R * 0.55, 20, 0.8, C(255, 110, 220), 0.3)
	Kit.Disc(m, cx, cz, 0.3, 8, 0.12, Kit.Vivid(C(150, 255, 160)))
	local spoke, dot = Kit.Vivid(C(190, 120, 255)), Kit.Vivid(C(255, 230, 90))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local rr = CLEAR_R * 0.55
		local p1 = V(cx + math.cos(a) * rr, 0.25, cz + math.sin(a) * rr)
		local a2 = a + math.pi * 2 / 6 * 2
		local p2 = V(cx + math.cos(a2) * rr, 0.25, cz + math.sin(a2) * rr)
		Props.Beam(m, p1, p2, 0.5, 0.12, spoke)
		Kit.Disc(m, cx + math.cos(a) * (CLEAR_R - 4), cz + math.sin(a) * (CLEAR_R - 4), 0.3, 2.6, 0.12, dot)
	end
	-- cobble path from the cross street, across the courtyard, to the pad (flat)
	local px = cx + PAD_OFFSET
	Kit.Box(m, V(cx - r - 2, -0.4, cz - 3), V(px - Config.Tower.PadRadius, 0.14, cz + 3), C(110, 90, 150), { Mat = Enum.Material.Cobblestone, Solid = true, Name = "TowerPath" })

	-- TOWER + PAD
	local doorX = buildTower(m, cx, cz)
	buildPad(m, px, cz)
	-- ghost lanterns flanking the tower door and the pad (all outside the clear courtyard)
	lantern(m, doorX - 3, cz - 11, 6, true)
	lantern(m, doorX - 3, cz + 11, 6, false)
	lantern(m, px + 2, cz - Config.Tower.PadRadius - 3.5, 5, false)
	lantern(m, px + 2, cz + Config.Tower.PadRadius + 3.5, 5, true)

	-- courtyard edge: pumpkins and lanterns on a ring outside the clear radius, leaving the
	-- west side open for the cross street and the east side for the tower
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local ex, ez = cx + math.cos(a) * (r + 1), cz + math.sin(a) * (r + 1)
		local west = ex < cx and ez > cz - 12 and ez < cz + 26
		local east = ex > cx + 14 and math.abs(ez - cz) < 26
		if math.abs(ex) < 134 and not west and not east then
			if i % 2 == 0 then
				Props.Pumpkin(m, V(ex, 0, ez), 3.4, cx - ex, cz - ez, true)
			else
				lantern(m, ex, ez, 4, false)
			end
		end
	end

	-- entrance arch over the cross street on the west side, sign facing -X (toward the road)
	local ax = cx - r - 5
	for _, sz in { -1, 1 } do
		local pz = cz + 7 + sz * 13
		Kit.Box(m, V(ax - 1.2, 0, pz - 1.2), V(ax + 1.2, 22, pz + 1.2), STONE, { Mat = Enum.Material.Slate, Solid = true })
		Kit.Ball(m, 3, V(ax, 23, pz), Kit.Vivid(ECTO))
	end
	local archCF = CFrame.new(ax, 19, cz + 7) * CFrame.Angles(0, Kit.FaceYaw(-1, 0), 0)
	local arch = Kit.Part(m, V(24, 5, 0.8), archCF, C(45, 25, 80))
	Kit.Part(m, V(25, 6, 0.4), archCF * CFrame.new(0, 0, 0.5), Kit.Vivid(C(190, 120, 255)))
	Kit.Sign(arch, Enum.NormalId.Front, "👻 BOSS TOWER 👻", C(150, 255, 170))

	-- low, faint haze over the courtyard
	local haze = Kit.Emitter(field, C(200, 140, 255), 1.2, 6, 0.3)
	if haze then
		haze.LightEmission = 0.25
	end

	-- keep-out reservations of the old arena plot (circle + the two former bleacher strips)
	Kit.AddCircle(cx, cz, r + 6)
	Kit.AddRect(cx - 15, cz + r + 4, cx + 15, cz + r + 16)
	Kit.AddRect(cx - 15, cz - r - 4, cx + 15, cz - r - 16)
	m.PrimaryPart = field
end

return Arena
