--!strict
-- GHOST HUNTER SIMULATOR server entry. Builds the world, then initialises services in order.
-- Every step is protected: one failing system logs a warning instead of stopping the others.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	"Remotes",
	"DataService",
	"PlayerInfo",
	"HunterService",
	"DropService",
	"GhostService",
	"ProgressService",
	"EventService",
	"ShopService",
	"StationService",
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

-- Studio-only test commands (chat): /ecto <n>, /event, /reset-daily, /autoattack
-- /autoattack grants the Auto Attack pass for this Studio test only (never in a live game).
if RunService:IsStudio() then
	local DataService = loaded.DataService
	local EventService = loaded.EventService
	local PlayerInfo = loaded.PlayerInfo
	local HunterService = loaded.HunterService
	local function hook(player: Player)
		player.Chatted:Connect(function(msg)
			local d = DataService and DataService.Get(player)
			if not d then
				return
			end
			local n = msg:match("^/ecto%s+(%d+)")
			if n then
				DataService.AddEcto(player, tonumber(n) :: number)
			elseif msg == "/event" and EventService then
				EventService.TriggerNow()
			elseif msg == "/reset-daily" then
				d.Daily.Last = 0
				DataService.Changed(player)
			elseif msg == "/autoattack" and PlayerInfo and HunterService then
				PlayerInfo.SetPass(player, "AutoAttack", true)
				HunterService.Refresh(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
end
