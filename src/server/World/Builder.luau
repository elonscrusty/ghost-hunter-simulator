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
	  Z 880 ........ brick wall at the far end.

	Every ghost area circle from Config.Layout.GhostAreas is registered as a keep-out, so no
	prop taller than ~0.3 studs is placed inside one (flat road paint / cracks / rune lines only).
	Instance tree:
	  workspace.Map.{Boundary, Gates, Stations, EventArena, Neighborhood, Cemetery, School}
]]

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local LightingSetup = require(script.Parent.Lighting)
local Boundary = require(script.Parent.Boundary)
local Gates = require(script.Parent.Gates)
local Stations = require(script.Parent.Stations)
local Arena = require(script.Parent.Arena)
local Neighborhood = require(script.Parent.Neighborhood)
local Cemetery = require(script.Parent.Cemetery)
local School = require(script.Parent.School)

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
end

function Builder.Build()
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	Kit.Reset()
	registerKeepOuts()

	local map: Folder = Instance.new("Folder")
	map.Name = "Map"

	LightingSetup.Apply()
	Boundary.Build(map)
	Gates.Build(map)
	Stations.Build(map)
	Arena.Build(map)
	Neighborhood.Build(map)
	Cemetery.Build(map)
	School.Build(map)

	map.Parent = Workspace
	local s = Kit.Stats
	print(string.format("[GH World] built %d parts (%d neon), %d lights, %d emitters, %d floating, %d flicker", s.Parts, s.Neon, s.Lights, s.Emitters, s.Floating, s.Flicker))
end

return Builder
