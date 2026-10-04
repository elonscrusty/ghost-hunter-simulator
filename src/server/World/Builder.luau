--!strict
--[[
	GHOST HUNTER SIMULATOR: procedural world builder. Call Builder.Build() once at server start.

	Layout (studs, +Z forward; ground top is Y = 0 everywhere walkable; play area |X| <= 140):

	  Z -60 ........ hedge wall behind spawn
	  Z -60..-36     Ghost Hunter HQ building (behind spawn)
	  Z   0          Spawn plaza (SpawnLocation at Config.Layout.Spawn, faces +Z)
	  Z  28          Beginner crate station (X -28, beacon) | Upgrade booth (X +28)
	  Z -36..260     ZONE 1 NEIGHBORHOOD: main road X -10..10 up to the gate, cross street
	                 Z 110..124 east to the Event Arena (95, 110, r32); houses on a 30-stud grid
	                 wherever ghost areas / roads / stations leave room.
	  Z 260          Stone wall + Gate_Cemetery (34-wide opening at X = 0)
	  Z 260..540     ZONE 2 CEMETERY: cobble path X -8..8, Haunted station (X -28, Z 292),
	                 giant mausoleum (X -122..-78, Z 477..513, spire to Y ~66), crypts, graves.
	  Z 540          Brick wall + Gate_School
	  Z 540..600     School courtyard: Elite station (X -28, Z 572), ghost bus, flagpole.
	  Z 600..860     ZONE 3 SCHOOL building (open-topped, see School.luau), clock tower to Y ~104.
	  Z 880          Gate_Carnival
	  Z 880..1220    ZONE 4 ABANDONED CARNIVAL (Carnival.luau)
	  Z 1220..1560   ZONE 5 HAUNTED HOSPITAL (Hospital.luau)
	  Z 1560..1920   ZONE 6 GHOST SHIP HARBOR (Harbor.luau)
	  Z 1920..2280   ZONE 7 CURSED CASTLE (Castle.luau)
	  Z 2280..2680   ZONE 8 SPIRIT REALM (SpiritRealm.luau)
	  Z 2680..5560   ZONES 9-16, 360 each: Swamp, Frost, Tomb, ToyFactory, Sunken, Clockwork,
	                 Inferno, Throne (one file each); far wall at the last zone's MaxZ.
	  Every zone from the Cemetery on: gate wall at its MinZ (Boundary + Gates), crate station at
	  (-28, MinZ + 32), Fast Travel arrival pad at Config.Layout.ZoneSpawns (kept free), main path
	  along X = 0 to the next gate.

	Every ghost area circle from Config.Layout.GhostAreas is registered as a keep-out, so no
	prop taller than ~0.3 studs is placed inside one (flat road paint / cracks / rune lines only).
	Instance tree:
	  workspace.Map.{Boundary, Gates, Stations, EventArena, Neighborhood, Cemetery, School, Carnival,
	                 Hospital, Harbor, Castle, SpiritRealm}
]]

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local LightingSetup = require(script.Parent.Lighting)
local Boundary = require(script.Parent.Boundary)
local Gates = require(script.Parent.Gates)
local Stations = require(script.Parent.Stations)
local Leaderboard = require(script.Parent.Leaderboard)
local Arena = require(script.Parent.Arena)
local Neighborhood = require(script.Parent.Neighborhood)
local Cemetery = require(script.Parent.Cemetery)
local School = require(script.Parent.School)
local Carnival = require(script.Parent.Carnival)
local Hospital = require(script.Parent.Hospital)
local Harbor = require(script.Parent.Harbor)
local Castle = require(script.Parent.Castle)
local SpiritRealm = require(script.Parent.SpiritRealm)
local Swamp = require(script.Parent.Swamp)
local Frost = require(script.Parent.Frost)
local Tomb = require(script.Parent.Tomb)
local ToyFactory = require(script.Parent.ToyFactory)
local Sunken = require(script.Parent.Sunken)
local Clockwork = require(script.Parent.Clockwork)
local Inferno = require(script.Parent.Inferno)
local Throne = require(script.Parent.Throne)

local Builder = {}

local function registerKeepOuts()
	for _, area in Config.Layout.GhostAreas do
		Kit.AddCircle(area.Center.X, area.Center.Z, area.Radius + 1)
	end
	local spawnPos = Config.Layout.Spawn
	Kit.AddCircle(spawnPos.X, spawnPos.Z, 27)
	for _, gate in Kit.Gates(Config.Layout) do
		Kit.AddRect(-30, gate.Z - 24, 30, gate.Z + 24)
	end
	-- Fast Travel arrival pads
	for _, p in Kit.ZoneSpawns(Config.Layout) do
		Kit.AddCircle(p.X, p.Z, 9)
	end
	-- main path along X = 0 through zones 4-8 (zones 1-3 register their own roads)
	Kit.AddRect(-10, 880, 10, Config.Zones[#Config.Zones].MaxZ, true)
	-- spawn kiosk pockets behind the plaza (Trading | Merge + Pets, see Neighborhood.luau)
	Kit.AddRect(-36, -36, -14, -12)
	Kit.AddRect(14, -36, 36, -12)
end

-- Last resort when the build throws: a plain anchored floor under the whole main strip and a
-- SpawnLocation at Config.Layout.Spawn, so players never spawn into (or fall through) nothing.
local function emergencyGround()
	if Workspace:FindFirstChild("EmergencyGround") then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "EmergencyGround"
	local maxZ = 5600
	local okZones, lastZone = pcall(function()
		return Config.Zones[#Config.Zones].MaxZ
	end)
	if okZones and type(lastZone) == "number" then
		maxZ = lastZone + 40
	end
	-- parts are capped at 2048 studs per axis, so tile the strip along Z
	local z = -120
	while z < maxZ do
		local len = math.min(2000, maxZ - z)
		local plate = Instance.new("Part")
		plate.Name = "EmergencyFloor"
		plate.Anchored = true
		plate.CanCollide = true
		plate.Size = Vector3.new(320, 4, len)
		-- top at Y = -0.05: just under the normal ground top (no z-fighting if part of the map exists)
		plate.CFrame = CFrame.new(0, -2.05, z + len / 2)
		plate.Color = Color3.fromRGB(90, 140, 80)
		plate.Material = Enum.Material.Grass
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.BottomSurface = Enum.SurfaceType.Smooth
		plate.Parent = f
		z += len
	end
	local spawnPos = Config.Layout.Spawn
	local sp = Instance.new("SpawnLocation")
	sp.Name = "EmergencySpawn"
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Size = Vector3.new(14, 1, 14)
	sp.CFrame = CFrame.new(spawnPos.X, 0.5, spawnPos.Z) * CFrame.Angles(0, math.pi, 0)
	sp.Color = Color3.fromRGB(130, 70, 220)
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = f
	f.Parent = Workspace
	warn("[GH World] build failed: emergency ground + spawn created")
end

local function buildAll(map: Folder)
	Kit.Reset()
	registerKeepOuts()

	LightingSetup.Apply()
	Boundary.Build(map)
	Gates.Build(map)
	Stations.Build(map)
	Leaderboard.Build(map)
	Arena.Build(map)
	Neighborhood.Build(map)
	Cemetery.Build(map)
	School.Build(map)
	Carnival.Build(map)
	Hospital.Build(map)
	Harbor.Build(map)
	Castle.Build(map)
	SpiritRealm.Build(map)
	Swamp.Build(map)
	Frost.Build(map)
	Tomb.Build(map)
	ToyFactory.Build(map)
	Sunken.Build(map)
	Clockwork.Build(map)
	Inferno.Build(map)
	Throne.Build(map)

	map.Parent = Workspace
	local s = Kit.Stats
	print(string.format("[GH World] built %d parts (%d neon), %d lights, %d emitters, %d floating, %d flicker", s.Parts, s.Neon, s.Lights, s.Emitters, s.Floating, s.Flicker))
end

function Builder.Build()
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local map: Folder = Instance.new("Folder")
	map.Name = "Map"
	local ok, err = pcall(function()
		buildAll(map)
	end)
	if not ok then
		-- keep whatever did get built, add a safety floor, then let Main log the error
		map.Parent = Workspace
		emergencyGround()
		error(err, 0)
	end
end

return Builder
