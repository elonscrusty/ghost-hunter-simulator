--!strict
-- World portals (Config.Layout.Portals), in workspace.Map.Portals:
--   Gate_<Zone> (ToWorld2): a big stone ring with a shimmering force-field disc at the far end of
--     the Ghost King's Throne, "TO WORLD 2: THE OTHER SIDE" sign with the same CostLabel /
--     CostIcon / PromptAnchor children as a zone gate, so StationService (Unlock prompt) and
--     Ambience (price -> "UNLOCKED") treat it exactly like the gate of Lantern Market.
--   Portal_World1 (ToWorld1): a smaller ring at the start of Lantern Market, "BACK TO WORLD 1".
-- Each ring's disc is the part named "PortalSurface" (solid, CanTouch): ProgressService teleports
-- whoever touches it (World 2 only once Lantern Market is owned). Nothing here glows hard: the
-- disc is ForceField material, the ring is painted stone with a few small neon studs.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Format = require(game:GetService("ReplicatedStorage").GH.Logic.Format)
local Icons = require(game:GetService("ReplicatedStorage").GH.Icons)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Portals = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local STONE = Enum.Material.Slate

-- Ring of `n` blocks (radius r, centre `c`) standing upright across X, facing +-Z.
local function ring(parent: Instance, c: Vector3, r: number, thick: number, depth: number, n: number, color: Color3, stud: Color3?)
	local seg = 2 * math.pi * r / n + 0.6
	for i = 0, n - 1 do
		local a = (i + 0.5) * 2 * math.pi / n
		local cf = CFrame.new(c) * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0)
		Kit.Part(parent, V(seg, thick, depth), cf, color, { Mat = STONE, Solid = true })
		if stud and i % 3 == 0 then
			-- small glowing studs on both faces (the only neon on the portal)
			for _, fz in { -1, 1 } do
				Kit.Part(parent, V(0.9, 0.9, 0.3), cf * CFrame.new(0, 0, fz * (depth / 2 + 0.1)), stud, { Mat = NEON })
			end
		end
	end
end

local function surface(parent: Instance, c: Vector3, d: number, color: Color3): Part
	-- a cylinder's axis is its X: turn it so the flat faces look along Z
	local disc = Kit.Part(parent, V(1, d, d), CFrame.new(c) * CFrame.Angles(0, math.pi / 2, 0), color, {
		Name = "PortalSurface",
		Mat = Enum.Material.ForceField,
		Transp = 0.15,
		Solid = true,
		Shape = Enum.PartType.Cylinder,
		Shadow = false,
	})
	disc.CanQuery = false -- never blocks taps or ground raycasts
	disc.CanTouch = true
	-- dark backing so the swirl reads against the bright marble behind it
	Kit.Part(parent, V(0.4, d - 0.4, d - 0.4), CFrame.new(c) * CFrame.Angles(0, math.pi / 2, 0), C(30, 15, 55), { Shape = Enum.PartType.Cylinder })
	return disc
end

--==================================================================
-- TO WORLD 2 (end of the Throne)
--==================================================================
local function buildToWorld2(folder: Instance)
	local cfg = Config.Layout.Portals.ToWorld2
	local zone = Config.ZoneById[cfg.Zone]
	local m = Kit.Model(folder, "Gate_" .. cfg.Zone)
	local base = cfg.Position
	local R = 15 -- ring radius (inner opening ~ 27 studs across)
	-- the ring's lowest blocks sink into the dais, so you walk straight into the disc
	local centre = base + V(0, R - 1, 0)
	local gold = Kit.Vivid(C(255, 210, 90))
	local violet = C(200, 150, 255)

	-- low dais (walkable step) with a gold edge, and two stone feet either side of the ring
	Kit.Box(m, base + V(-20, 0, -8), base + V(20, 0.3, 8), C(225, 215, 245), { Mat = Enum.Material.Marble, Solid = true })
	Kit.Box(m, base + V(-20.2, 0.3, -8.2), base + V(20.2, 0.36, -7.8), gold, { Mat = Enum.Material.Metal })
	for _, s in { -1, 1 } do
		Kit.Box(m, base + V(s * (R + 1) - 3, 0.3, -3), base + V(s * (R + 1) + 3, 5, 3), C(70, 50, 110), { Mat = STONE, Solid = true })
	end
	ring(m, centre, R, 2.6, 3, 28, C(90, 65, 140), violet)
	ring(m, centre, R + 1.6, 0.8, 3.4, 28, gold, nil)
	local disc = surface(m, centre, R * 2 - 1, C(170, 120, 255))
	-- a few floating motes around the ring (client-animated, budgeted)
	for i, off in { V(-19, 6, 0), V(19, -3, 0), V(-11, 18, -1), V(13, 16, 1) } do
		local mote = Kit.Ball(m, if i % 2 == 0 then 1.6 else 2.2, centre + off, C(235, 220, 255), { Name = "PortalMote" })
		Kit.Float(mote, 1.2)
	end
	local glowPart = Kit.Part(m, V(1, 1, 1), CFrame.new(centre - V(0, 0, 3)), violet, { Transp = 1, Name = "PortalGlow" })
	Kit.Light(glowPart, violet, 26, 1.1)
	Kit.Emitter(disc, C(220, 190, 255), 3, 2.5, 0.8)

	-- sign above the ring (Front face toward the hall at -Z), laid out like a gate sign
	local signY = centre.Y + R + 7
	local sign = Kit.Part(m, V(44, 10, 1), CFrame.new(base.X, signY, base.Z - 1), C(45, 25, 80), { Name = "Sign" })
	Kit.Part(m, V(46, 12, 0.6), CFrame.new(base.X, signY, base.Z - 0.3), gold)
	for _, s in { -1, 1 } do
		Kit.Box(m, V(base.X + s * 18 - 0.4, centre.Y + R - 1, base.Z - 0.6), V(base.X + s * 18 + 0.4, signY - 5, base.Z + 0.2), gold, { Mat = Enum.Material.Metal })
	end
	local gui = Kit.Gui(sign, Enum.NormalId.Front, 30)
	Kit.Label(gui, "TO WORLD 2: THE OTHER SIDE", zone.Accent, {
		Name = "ZoneLabel",
		Pos = UDim2.fromScale(0.03, 0.04),
		Size = UDim2.fromScale(0.94, 0.5),
	})
	local lockImage = Icons.Get("lock")
	if lockImage then
		local img = Kit.IconImage(gui, lockImage, 0.1, 0.56, 0.086, 0.38)
		img.Name = "CostIcon"
	end
	Kit.Label(gui, (if lockImage then "" else "🔒 ") .. Format.Short(zone.Cost) .. " ECTOPLASM", C(150, 255, 140), {
		Name = "CostLabel",
		Pos = if lockImage then UDim2.fromScale(0.2, 0.56) else UDim2.fromScale(0.08, 0.56),
		Size = if lockImage then UDim2.fromScale(0.7, 0.38) else UDim2.fromScale(0.84, 0.38),
	})
	-- small plaque on the dais front with the first area's name
	Props.SignBoard(m, base + V(0, 1.6, -8.6), 22, 2.4, 0, -1, zone.Name, C(45, 25, 80), zone.Accent, gold)

	-- carpet runner from the hall's main carpet to the dais (flat, walkable)
	Kit.Box(m, V(9.6, 0, base.Z - 16), V(base.X + 6, 0.05, base.Z - 8), Kit.Vivid(C(120, 65, 185)), { Mat = Enum.Material.Fabric, Solid = true })

	Kit.Part(m, V(1, 1, 1), CFrame.new(base.X, 4, base.Z - 10), C(255, 255, 255), { Name = "PromptAnchor", Transp = 1 })
	m.PrimaryPart = disc
end

--==================================================================
-- BACK TO WORLD 1 (start of Lantern Market)
--==================================================================
local function buildToWorld1(folder: Instance)
	local cfg = Config.Layout.Portals.ToWorld1
	local m = Kit.Model(folder, "Portal_World1")
	local base = cfg.Position
	local R = 9
	local centre = base + V(0, R - 1, 0)
	local gold = Kit.Vivid(C(255, 210, 90))
	local mint = C(150, 255, 170)
	Kit.Box(m, base + V(-12, 0, -6), base + V(12, 0.3, 6), C(70, 55, 90), { Mat = STONE, Solid = true })
	for _, s in { -1, 1 } do
		Kit.Box(m, base + V(s * (R + 1) - 2, 0.3, -2), base + V(s * (R + 1) + 2, 4, 2), C(70, 50, 110), { Mat = STONE, Solid = true })
	end
	ring(m, centre, R, 2, 2.6, 20, C(90, 65, 140), mint)
	ring(m, centre, R + 1.3, 0.7, 3, 20, gold, nil)
	surface(m, centre, R * 2 - 1, C(120, 230, 170))
	local glowPart = Kit.Part(m, V(1, 1, 1), CFrame.new(centre + V(0, 0, 3)), mint, { Transp = 1, Name = "PortalGlow" })
	Kit.Light(glowPart, mint, 18, 0.9)
	-- sign faces +Z (toward players coming from inside Lantern Market)
	local signY = centre.Y + R + 4.5
	local sign = Kit.Part(m, V(26, 5, 1), CFrame.new(base.X, signY, base.Z + 0.6) * CFrame.Angles(0, math.pi, 0), C(45, 25, 80), { Name = "Sign" })
	Kit.Part(m, V(27.4, 6.2, 0.5), CFrame.new(base.X, signY, base.Z + 0.1), gold)
	Kit.Sign(sign, Enum.NormalId.Front, "BACK TO WORLD 1", mint, { Name = "PortalLabel" })
end

function Portals.Build(map: Instance)
	local folder = Kit.Folder(map, "Portals")
	buildToWorld2(folder)
	buildToWorld1(folder)
end

-- Keep-out rectangles so scattered props never land on a portal or its approach.
function Portals.RegisterKeepOuts()
	local p2 = Config.Layout.Portals.ToWorld2.Position
	Kit.AddRect(p2.X - 22, p2.Z - 16, p2.X + 22, p2.Z + 10)
	Kit.AddRect(9.6, p2.Z - 16, p2.X, p2.Z - 8, true) -- carpet runner
	local p1 = Config.Layout.Portals.ToWorld1.Position
	Kit.AddRect(p1.X - 14, p1.Z - 8, p1.X + 14, p1.Z + 16)
end

return Portals
