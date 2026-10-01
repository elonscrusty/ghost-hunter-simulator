--!strict
-- Crate stations (workspace.Map.Stations.CrateStation_<id>) and the upgrade booth
-- (workspace.Map.Stations.UpgradeStation). Stations sit beside the main path (X = 0);
-- their PromptAnchor and the OddsBoard's Front face point toward the path.
-- Pads, frames and trims are solid candy colours; the glow is kept to the arch lamps, the
-- corner jack-o'-lanterns and a couple of gadget lights.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Stations = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WHITE = C(255, 255, 255)

local function anchors(m: Model, x: number, z: number, dir: number)
	Kit.Part(m, V(1, 1, 1), CFrame.new(x, 4, z), WHITE, { Name = "DisplaySlot", Transp = 1 })
	Kit.Part(m, V(1, 1, 1), CFrame.new(x + dir * 7, 3, z), WHITE, { Name = "PromptAnchor", Transp = 1 })
end

local function pad(m: Model, x: number, z: number, color: Color3, trim: Color3): Part
	local ring = Kit.Vivid(trim)
	Kit.Disc(m, x, z, 0.6, 16.5, 0.6, ring)
	local p = Kit.Disc(m, x, z, 1, 14, 1, color, { Name = "Pad", Solid = true })
	Kit.Disc(m, x, z, 1.12, 9, 0.2, ring)
	Kit.Disc(m, x, z, 1.18, 6, 0.2, color:Lerp(WHITE, 0.3))
	return p
end

local function crateStation(folder: Instance, crate: Config.CrateDef, pos: Vector3)
	local x, z = pos.X, pos.Z
	local dir = if x < 0 then 1 else -1 -- toward the path
	local m = Kit.Model(folder, "CrateStation_" .. crate.Id)
	local padPart = pad(m, x, z, crate.Color, crate.Trim)
	anchors(m, x, z, dir)
	local trim = Kit.Vivid(crate.Trim)

	-- Odds board behind the pad, Front face toward the path.
	local yaw = Kit.FaceYaw(dir, 0)
	local boardCF = CFrame.new(x - dir * 9.5, 7, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(m, V(12, 9, 0.6), boardCF, C(35, 22, 60), { Name = "OddsBoard", Solid = true })
	Kit.Part(m, V(13.4, 10.4, 0.5), boardCF * CFrame.new(0, 0, 0.45), trim)
	Kit.Part(m, V(14.2, 1.8, 1.2), boardCF * CFrame.new(0, 5.6, 0.3), crate.Color)
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(1, 2.6, 1), boardCF * CFrame.new(sx * 5, -5.8, 0.4), crate.Color:Lerp(C(0, 0, 0), 0.3), { Solid = true })
		Kit.Ball(m, 1.6, (boardCF * CFrame.new(sx * 7.1, 5.6, 0.3)).Position, trim)
	end

	-- Arch over the back half of the pad with the crate's name facing the path; the two
	-- orbs on top are its lamps (the beam carries the light).
	local ax = x - dir * 3
	for _, sz in { -1, 1 } do
		Kit.Box(m, V(ax - 1.3, 0, z + sz * 9.5 - 1.3), V(ax + 1.3, 15, z + sz * 9.5 + 1.3), crate.Color, { Solid = true })
		Kit.Box(m, V(ax - 1.6, 0, z + sz * 9.5 - 1.6), V(ax + 1.6, 1.4, z + sz * 9.5 + 1.6), trim)
		Kit.Ball(m, 3, V(ax, 18.4, z + sz * 10.5), crate.Trim, { Mat = NEON })
	end
	local beam = Kit.Box(m, V(ax - 1.5, 15, z - 11.5), V(ax + 1.5, 17, z + 11.5), crate.Color:Lerp(WHITE, 0.15))
	Kit.Light(beam, crate.Trim, 18, 1.8)
	local signCF = CFrame.new(ax, 19, z) * CFrame.Angles(0, yaw, 0)
	local sign = Kit.Part(m, V(20, 4, 0.6), signCF, C(35, 22, 60))
	Kit.Part(m, V(21, 5, 0.4), signCF * CFrame.new(0, 0, 0.4), trim)
	Kit.Sign(sign, Enum.NormalId.Front, crate.Name, crate.Trim)

	-- glowing corner jack-o'-lanterns
	Props.Pumpkin(m, V(x + dir * 6, 0, z + 9), 2.8, dir, 0, true)
	Props.Pumpkin(m, V(x + dir * 6, 0, z - 9), 2.8, dir, 0, true)

	Kit.AddCircle(ax, z, 13)
	m.PrimaryPart = padPart
	return m
end

local function beginnerExtras(m: Model, x: number, z: number, crate: Config.CrateDef)
	-- Tall shimmering beacon so the first crate is obvious from spawn (ForceField: reads as a
	-- light pillar without a 70-stud neon tube blooming over everything).
	local beacon = Kit.Cyl(m, 70, 5, CFrame.new(x, 57, z), Kit.Vivid(crate.Trim), { Mat = Enum.Material.ForceField, Transp = 0.5, Name = "Beacon" })
	Kit.Emitter(beacon, crate.Trim, 3, 3, 2)
	Kit.Ball(m, 6, V(x, 22.5, z), Kit.Vivid(crate.Color), { Refl = 0.15 })
	-- World-space label sized in studs (BillboardGui scale = studs), so it shrinks with
	-- distance like the station instead of filling a phone screen; text capped for readability.
	local bb: BillboardGui = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10, 2.5)
	bb.StudsOffsetWorldSpace = V(0, -24, 0)
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Parent = beacon
	local label = Kit.Label(bb, "🎁 OPEN CRATES! 🎁", C(255, 230, 90), { Stroke = C(120, 50, 10) })
	label.TextScaled = true
	local limit: UITextSizeConstraint = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 10
	limit.MaxTextSize = 36
	limit.Parent = label
end

local function upgradeStation(folder: Instance, pos: Vector3)
	local x, z = pos.X, pos.Z
	local dir = if x < 0 then 1 else -1
	local m = Kit.Model(folder, "UpgradeStation")
	local color, trim = C(80, 200, 255), C(255, 220, 80)
	local padPart = pad(m, x, z, color, trim)
	Kit.Part(m, V(1, 1, 1), CFrame.new(x + dir * 7, 3, z), WHITE, { Name = "PromptAnchor", Transp = 1 })

	local bx = x - dir * 9.5 -- workbench centre line
	local back = bx - dir * 3 -- back panel
	local yaw = Kit.FaceYaw(dir, 0)
	-- workbench
	Kit.Box(m, V(bx - 2, 0, z - 8), V(bx + 2, 3.6, z + 8), C(150, 95, 60), { Mat = Enum.Material.WoodPlanks, Solid = true })
	Kit.Box(m, V(bx - 2.4, 3.6, z - 8.4), V(bx + 2.4, 4.2, z + 8.4), C(90, 230, 255), { Solid = true })
	-- back panel + big sign
	Kit.Box(m, V(back - 0.6, 0, z - 10.5), V(back + 0.6, 17, z + 10.5), C(110, 70, 200), { Solid = true })
	local signCF = CFrame.new(back + dir * 0.9, 13.2, z) * CFrame.Angles(0, yaw, 0)
	local sign = Kit.Part(m, V(19, 5, 0.6), signCF, C(35, 22, 60))
	Kit.Part(m, V(20, 6, 0.3), signCF * CFrame.new(0, 0, 0.4), Kit.Vivid(trim))
	Kit.Sign(sign, Enum.NormalId.Front, "⚡ UPGRADES ⚡", trim)
	-- upgrade icons
	for i, upId in Config.UpgradeOrder do
		local up = Config.Upgrades[upId]
		local icf = CFrame.new(back + dir * 0.8, 7.8, z + (i - 2) * 6) * CFrame.Angles(0, yaw, 0)
		local icon = Kit.Part(m, V(4.4, 4.4, 0.4), icf, C(60, 40, 110))
		Kit.Part(m, V(5, 5, 0.3), icf * CFrame.new(0, 0, 0.3), Kit.Vivid(color))
		Kit.Sign(icon, Enum.NormalId.Front, up.Icon, WHITE)
	end
	-- gadgets on the bench (potion vials are solid candy colours; the orange status light glows)
	Kit.CylFlat(m, 4.5, 1.6, V(bx, 5, z - 4.5), "Z", C(255, 120, 200))
	Kit.CylFlat(m, 1.5, 0.8, V(bx, 5, z - 7.4), "Z", Kit.Vivid(C(140, 255, 160)))
	for i = 0, 1 do
		Kit.Cyl(m, 3.2, 1.6, CFrame.new(bx, 5.8, z + 1 + i * 2.2), Kit.Vivid(C(120, 255, 170)), { Transp = 0.15, Refl = 0.15 })
		Kit.Cyl(m, 0.5, 1.8, CFrame.new(bx, 7.6, z + 1 + i * 2.2), C(70, 70, 90))
	end
	Kit.CylFlat(m, 0.6, 3.2, V(bx, 5.9, z + 6), "X", C(255, 210, 70))
	Kit.Ball(m, 1.2, V(bx, 5.9, z + 6), C(255, 120, 60), { Mat = NEON })
	-- striped awning on posts
	local tilt = -dir * 0.22
	local stripes = { C(255, 140, 50), C(160, 90, 255) }
	for i = 0, 3 do
		local sz = z - 8.25 + i * 5.5
		Kit.Part(m, V(9, 0.5, 5.5), CFrame.new(bx - dir * 0.5, 17.2, sz) * CFrame.Angles(0, 0, tilt), stripes[(i % 2) + 1], { Shadow = true })
	end
	for _, sz in { -1, 1 } do
		Kit.Box(m, V(bx + dir * 3.7 - 0.4, 0, z + sz * 10.5 - 0.4), V(bx + dir * 3.7 + 0.4, 16.3, z + sz * 10.5 + 0.4), C(70, 50, 110))
	end
	local bulb = Kit.Ball(m, 1.4, V(bx + dir * 2, 15, z), C(255, 240, 160), { Mat = NEON })
	Kit.Light(bulb, C(255, 220, 150), 18, 1.5)

	Kit.AddCircle(x - dir * 4, z, 14)
	m.PrimaryPart = padPart
end

function Stations.Build(map: Instance)
	local folder = Kit.Folder(map, "Stations")
	for id, pos in Kit.CrateStations(Config.Layout) do
		local crate = Config.Crates[id]
		if crate then
			local m = crateStation(folder, crate, pos)
			if id == "Beginner" then
				beginnerExtras(m, pos.X, pos.Z, crate)
			end
		end
	end
	upgradeStation(folder, Config.Layout.UpgradeStation)
end

return Stations
