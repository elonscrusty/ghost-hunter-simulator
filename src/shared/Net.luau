--!strict
-- Remote registry. The server creates every remote in Init(); clients wait for them.
-- Client → server: SelectTarget (RemoteEvent), Request (RemoteFunction, action dispatcher).
-- Server → client: Sync (profile snapshot), Ecto (currency only), Drops (orbs spawned),
-- Collect (orbs picked up), Fx (effects/announcements, see Fx kinds in docs/ARCHITECTURE.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = { "SelectTarget", "Sync", "Ecto", "Drops", "Collect", "Fx" }
local FUNCTIONS = { "Request" }
local FOLDER = "GHRemotes"

function Net.Init()
	assert(RunService:IsServer(), "Net.Init is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER) or Instance.new("Folder")
	folder.Name = FOLDER
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

local function folder(): Instance
	return ReplicatedStorage:WaitForChild(FOLDER)
end

function Net.Event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Net
