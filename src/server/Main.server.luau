--!strict
-- GHOST HUNTER SIMULATOR server entry. Builds the world, then initialises services in order.
-- Every step is protected: one failing system logs a warning instead of stopping the others.
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Net = require(GH.Net)

Net.Init()

-- Players pass through each other (busy crate stations); hunters are client-side and non-colliding.
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
end)

local okWorld, errWorld = pcall(function()
	require(script.Parent.World.Builder).Build()
end)
if not okWorld then
	warn("[Main] world build failed: " .. tostring(errWorld))
end

local Services = script.Parent.Services
local order = {
	"Fx",
	"SafetyService",
	"Remotes",
	"DataService",
	"PlayerInfo",
	"HunterService",
	"CrewService",
	"PetService",
	"DropService",
	"GhostService",
	"ProgressService",
	"EventService",
	"TowerService",
	"ShopService",
	"TradeService",
	"StationService",
	"GlobalEventService",
	"RarePetEventService",
	"DevService",
	"FeedbackService",
	"LeaderboardService",
}
local loaded: { [string]: any } = {}
for _, name in order do
	local ok, mod = pcall(require, Services:FindFirstChild(name) :: ModuleScript)
	if not ok then
		warn("[Main] couldn't load " .. name .. ": " .. tostring(mod))
		continue
	end
	loaded[name] = mod
	if (mod :: any).Init then
		local okInit, err = pcall((mod :: any).Init)
		if not okInit then
			warn("[Main] " .. name .. ".Init failed: " .. tostring(err))
		end
	end
end
for _, name in order do
	local mod = loaded[name]
	if mod and mod.Start then
		local okStart, err = pcall(mod.Start)
		if not okStart then
			warn("[Main] " .. name .. ".Start failed: " .. tostring(err))
		end
	end
end

-- Developer tools (DEV button + chat commands) live in Services/DevService.

-- One fixed text size per world sign (see World/TextFit): run after every service has built
-- its signs and boards.
pcall(function()
	local n = require(script.Parent.World.TextFit).Apply(workspace)
	print(string.format("[Main] fixed text sizes on %d world labels", n))
end)
