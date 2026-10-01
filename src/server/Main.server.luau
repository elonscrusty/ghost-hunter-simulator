--!strict
-- GHOST HUNTER SIMULATOR server entry. Builds the world, then initialises services in order.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Net = require(GH.Net)

Net.Init()

-- Players pass through each other (busy crate stations), hunters are client-side and non-colliding.
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
end)

require(script.Parent.World.Builder).Build()

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
local loaded: { any } = {}
for _, name in order do
	local mod = require(Services:FindFirstChild(name) :: ModuleScript) :: any
	table.insert(loaded, mod)
	if mod.Init then
		mod.Init()
	end
end
for _, mod in loaded do
	if mod.Start then
		mod.Start()
	end
end

-- Studio-only test commands (chat): /ecto <n>, /event, /reset-daily
if RunService:IsStudio() then
	local DataService = require(Services.DataService) :: any
	local EventService = require(Services.EventService) :: any
	local function hook(player: Player)
		player.Chatted:Connect(function(msg)
			local d = DataService.Get(player)
			if not d then
				return
			end
			local n = msg:match("^/ecto%s+(%d+)")
			if n then
				DataService.AddEcto(player, tonumber(n) :: number)
			elseif msg == "/event" then
				EventService.TriggerNow()
			elseif msg == "/reset-daily" then
				d.Daily.Last = 0
				DataService.Changed(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
end
