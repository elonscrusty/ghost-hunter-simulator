--!strict
-- BOSS TOWER ENTRANCE (workspace.Map.TowerEntrance) in the lobby's wider left side, just
-- outside the Pet Hatchery, turned to face the spawn plaza so it is visible from spawn.
-- Built in a local frame `base` (origin = the party pad centre Config.Layout.TowerEntrance.Pad,
-- local -Z = front, toward the spawn):
--   * the party pad (part "TowerPad", radius Config.Tower.PadRadius) at the origin;
--     TowerService finds Map.TowerEntrance.TowerPad and adds the "Enter Boss Tower" prompt;
--   * the ENDLESS BOSS TOWER behind it (local Z 11..21, X -9..9, spire orb at Y ~52: taller
--     than the hatchery and HQ, smaller than the old plaza tower), door facing the pad;
--   * the "BOSS TOWER" arch in front of the pad (local Z -13), facing the plaza.
-- The whole lobby is a keep-out (Builder), so no random props land here.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Icons = require(game:GetService("ReplicatedStorage").GH.Icons)

local TowerEntrance = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local STONE = C(92, 66, 138)
local STONE_DARK = C(62, 44, 96)
local STONE_LIGHT = C(128, 98, 178)
local ROOF = C(70, 40, 110)
local ECTO = C(110, 255, 160)

-- tower footprint (local): X -TW..TW, Z TZ1..TZ2 (door face at TZ1)
local TW, TZ1, TZ2 = 9, 11, 21
local HALL_H = 18
local ARCH_Z = -13

function TowerEntrance.Build(map: Instance)
	local m = Kit.Model(map, "TowerEntrance")
	local P = Config.Layout.TowerEntrance.Pad
	local spawnPos = Config.Layout.Spawn
	local base = CFrame.new(P.X, 0, P.Z) * CFrame.Angles(0, Kit.FaceYaw(spawnPos.X - P.X, spawnPos.Z - P.Z), 0)
	local function L(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	-- local box from corner (x1, y1, z1) to (x2, y2, z2)
	local function box(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, color: Color3, opts: Kit.Opts?): Part
		local size = V(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
		return Kit.Part(m, size, L((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), color, opts)
	end
	local stone: Kit.Opts = { Mat = Enum.Material.Slate, Solid = true }

	local function battlements(x1: number, z1: number, x2: number, z2: number, y: number)
		for x = x1, x2 - 1.2, 2.5 do
			box(x, y, z1, x + 1.2, y + 1.6, z1 + 1, STONE_LIGHT, { Mat = Enum.Material.Slate })
			box(x, y, z2 - 1, x + 1.2, y + 1.6, z2, STONE_LIGHT, { Mat = Enum.Material.Slate })
		end
		for z = z1 + 2.5, z2 - 2.5, 2.5 do
			box(x1, y, z, x1 + 1, y + 1.6, z + 1.2, STONE_LIGHT, { Mat = Enum.Material.Slate })
			box(x2 - 1, y, z, x2, y + 1.6, z + 1.2, STONE_LIGHT, { Mat = Enum.Material.Slate })
		end
	end
	-- painted ectoplasm band (solid, not Neon) around a footprint
	local function band(x1: number, z1: number, x2: number, z2: number, y: number)
		local paint = Kit.Vivid(ECTO)
		box(x1 - 0.3, y, z1 - 0.3, x2 + 0.3, y + 0.7, z1 + 0.2, paint)
		box(x1 - 0.3, y, z2 - 0.2, x2 + 0.3, y + 0.7, z2 + 0.3, paint)
		box(x1 - 0.3, y, z1, x1 + 0.2, y + 0.7, z2, paint)
		box(x2 - 0.2, y, z1, x2 + 0.3, y + 0.7, z2, paint)
	end
	-- gable roof (ridge along local X) over (x, cz) from y up by height
	local function gable(x: number, y: number, cz: number, width: number, height: number, depth: number)
		local half = depth / 2
		Kit.Wedge(m, V(width, height, half), L(x, y + height / 2, cz - half / 2), ROOF, { Mat = Enum.Material.Slate })
		Kit.Wedge(m, V(width, height, half), L(x, y + height / 2, cz + half / 2) * CFrame.Angles(0, math.pi, 0), ROOF, { Mat = Enum.Material.Slate })
	end
	-- stone post with a glowing ghost lantern on top
	local function lantern(x: number, z: number, h: number, light: boolean)
		local p = L(x, 0, z).Position
		local px, pz = p.X, p.Z
		Kit.Box(m, V(px - 0.7, 0, pz - 0.7), V(px + 0.7, h, pz + 0.7), STONE_DARK, stone)
		Kit.Box(m, V(px - 1.1, h, pz - 1.1), V(px + 1.1, h + 0.45, pz + 1.1), STONE_LIGHT, { Mat = Enum.Material.Slate })
		Kit.Box(m, V(px - 0.8, h + 0.45, pz - 0.8), V(px + 0.8, h + 2.8, pz + 0.8), C(40, 30, 60), { Mat = Enum.Material.Glass, Transp = 0.55 })
		local glow = Kit.Ball(m, 1.2, V(px, h + 1.6, pz), ECTO, { Mat = NEON })
		Kit.Box(m, V(px - 1.1, h + 2.8, pz - 1.1), V(px + 1.1, h + 3.2, pz + 1.1), STONE_DARK, { Mat = Enum.Material.Metal })
		if light then
			Kit.Light(glow, ECTO, 16, 1.1, true)
		end
	end

	--------------------------------------------------------------- TOWER
	box(-TW, 0, TZ1, TW, HALL_H, TZ2, STONE, stone) -- base hall
	box(-TW - 0.5, 0, TZ1 - 0.5, TW + 0.5, 1.6, TZ2 + 0.5, STONE_DARK, stone) -- plinth
	band(-TW, TZ1, TW, TZ2, HALL_H - 0.7)
	battlements(-TW, TZ1, TW, TZ2, HALL_H)
	-- front corner turrets with pointed roofs
	for _, sx in { -1, 1 } do
		local tx = sx * (TW - 1.5)
		Kit.Cyl(m, 24, 4.6, L(tx, 12, TZ1 + 1.5), STONE_DARK, stone)
		Kit.Cyl(m, 0.7, 5.2, L(tx, 23.9, TZ1 + 1.5), Kit.Vivid(ECTO))
		gable(tx, 24.2, TZ1 + 1.5, 5.4, 4.5, 5.4)
	end
	-- upper tower
	local ux, uz1, uz2, uy = 6, TZ1 + 1.5, TZ2 - 1, 37
	box(-ux, HALL_H, uz1, ux, uy, uz2, STONE_LIGHT, stone)
	band(-ux, uz1, ux, uz2, 27)
	band(-ux, uz1, ux, uz2, uy - 0.7)
	battlements(-ux, uz1, ux, uz2, uy)
	-- spire with a floating ectoplasm orb
	local ucz = (uz1 + uz2) / 2
	box(-ux + 2, uy, uz1 + 2, ux - 2, uy + 4, uz2 - 2, STONE_DARK, stone)
	gable(0, uy + 4, ucz, ux * 2 - 3, 8, uz2 - uz1 - 3)
	local orb = Kit.Ball(m, 2.6, L(0, uy + 15, ucz).Position, ECTO, { Mat = NEON })
	Kit.Float(orb, 1)
	Kit.Light(orb, ECTO, 26, 1.4)
	-- windows on the front of the upper tower, carved ghost eyes above them
	for _, wx in { -3.2, 0, 3.2 } do
		box(wx - 0.8, 29, uz1 - 0.25, wx + 0.8, 32.5, uz1 + 0.05, ECTO, { Mat = NEON })
		box(wx - 0.8, 21, uz1 - 0.25, wx + 0.8, 24.5, uz1 + 0.05, C(25, 15, 40))
	end
	for _, s in { -1, 1 } do
		local fx = s * 2.8
		Kit.Ball(m, 1, L(fx - 0.6, 34.6, uz1 - 0.15).Position, C(25, 15, 40))
		Kit.Ball(m, 1, L(fx + 0.6, 34.6, uz1 - 0.15).Position, C(25, 15, 40))
	end
	-- the door: dark arch with an ectoplasm portal glow and a stone frame
	local dw = 4
	box(-dw, 0, TZ1 - 0.4, dw, 10, TZ1 + 0.2, C(25, 15, 40), { Name = "TowerDoor" })
	local portal = box(-dw + 0.8, 0.3, TZ1 - 0.55, dw - 0.8, 9, TZ1 - 0.45, ECTO, { Mat = NEON, Transp = 0.45, Name = "Portal" })
	Kit.Emitter(portal, ECTO, 3, 2.4, 0.5)
	for _, s in { -1, 1 } do
		local fx = s * (dw + 1.1)
		box(fx - 1.1, 0, TZ1 - 1.6, fx + 1.1, 11.5, TZ1, STONE_LIGHT, stone)
	end
	box(-dw - 2.2, 10, TZ1 - 1.6, dw + 2.2, 12, TZ1, STONE_LIGHT, stone)
	-- sign over the door
	local signCF = L(0, 14.6, TZ1 - 1.2)
	local sign = Kit.Part(m, V(15, 3.2, 0.5), signCF, C(45, 25, 80))
	Kit.Part(m, V(15.8, 3.9, 0.3), signCF * CFrame.new(0, 0, 0.4), Kit.Vivid(ECTO))
	Kit.Sign(sign, Enum.NormalId.Front, "ENDLESS BOSS TOWER", C(150, 255, 170))
	lantern(-TW + 1, TZ1 - 3, 5, true)
	lantern(TW - 1, TZ1 - 3, 5, false)

	--------------------------------------------------------------- PAD
	-- flat party pad (top at 0.34): the TowerPad part carries the prompt (added by TowerService)
	local r = Config.Tower.PadRadius
	Kit.Disc(m, P.X, P.Z, 0.24, r * 2 + 1.4, 0.3, Kit.Vivid(ECTO), { Solid = true })
	Kit.Disc(m, P.X, P.Z, 0.3, r * 2 - 1, 0.3, C(70, 45, 120), { Mat = Enum.Material.Slate, Solid = true, Name = "TowerPad" })
	Kit.Disc(m, P.X, P.Z, 0.34, 5, 0.08, Kit.Vivid(C(190, 120, 255)))
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local d = L(math.cos(a) * (r - 2.4), 0, math.sin(a) * (r - 2.4)).Position
		Kit.Disc(m, d.X, d.Z, 0.34, 1.6, 0.08, Kit.Vivid(ECTO))
	end
	-- flat cobble apron joining the pad to the door and out through the arch (top 0.14)
	box(-4, -0.4, r - 0.5, 4, 0.14, TZ1 - 1.6, C(110, 90, 150), { Mat = Enum.Material.Cobblestone, Solid = true, Name = "TowerPath" })
	box(-5, -0.4, ARCH_Z - 5, 5, 0.14, -r + 0.5, C(110, 90, 150), { Mat = Enum.Material.Cobblestone, Solid = true, Name = "TowerPath" })

	--------------------------------------------------------------- ARCH
	local ah = 16
	for _, s in { -1, 1 } do
		local ax = s * 11
		box(ax - 1, 0, ARCH_Z - 1, ax + 1, ah, ARCH_Z + 1, STONE, stone)
		Kit.Ball(m, 2.6, L(ax, ah + 1, ARCH_Z).Position, Kit.Vivid(ECTO))
	end
	local archCF = L(0, ah - 2.6, ARCH_Z)
	local arch = Kit.Part(m, V(20, 4.2, 0.8), archCF, C(45, 25, 80), { Name = "TowerArchSign" })
	Kit.Part(m, V(21, 5, 0.4), archCF * CFrame.new(0, 0, 0.5), Kit.Vivid(C(190, 120, 255)))
	-- title between two icon images: the tower icon once uploaded, else the Spirit Shards icon
	-- (shards are what the tower pays); plain text if neither image exists
	local icon = Icons.Get("tower") or Icons.Get("shards")
	if icon then
		local g = Kit.Gui(arch, Enum.NormalId.Front)
		for _, x in { 0.02, 0.8 } do
			local img = Instance.new("ImageLabel")
			img.Name = "TowerIcon"
			img.BackgroundTransparency = 1
			img.Image = icon
			img.ScaleType = Enum.ScaleType.Fit
			img.Position = UDim2.fromScale(x, 0.07)
			img.Size = UDim2.fromScale(0.18, 0.86) -- about square on the 20 x 4.2 board
			img.Parent = g
		end
		Kit.Label(g, "BOSS TOWER", C(150, 255, 170), { Size = UDim2.fromScale(0.58, 0.8), Pos = UDim2.fromScale(0.21, 0.1) })
	else
		Kit.Sign(arch, Enum.NormalId.Front, "BOSS TOWER", C(150, 255, 170))
	end
	lantern(-8, ARCH_Z - 3, 4, false)
	lantern(8, ARCH_Z - 3, 4, true)

	Kit.AddCircle(P.X, P.Z, 30)
end

return TowerEntrance
