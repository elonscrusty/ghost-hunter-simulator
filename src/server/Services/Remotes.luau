--!strict
-- Validated, rate-limited request dispatcher. Clients call
--   Request:InvokeServer(action, ...) -> { ok: boolean, err: string?, ... }
-- Handlers never trust arguments: they type-check everything they receive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Rules = require(GH.Logic.Rules)

local Remotes = {}

type Handler = (Player, ...any) -> any
local handlers: { [string]: { fn: Handler, bucket: string } } = {}
local limiters: { [string]: Rules.Limiter } = {}

local function limiter(bucket: string): Rules.Limiter
	local l = limiters[bucket]
	if not l then
		local def = (Config.RateLimits :: any)[bucket] or Config.RateLimits.Default
		l = Rules.NewLimiter(def.Count, def.Window)
		limiters[bucket] = l
	end
	return l
end

function Remotes.Allow(player: Player, bucket: string): boolean
	return Rules.Allow(limiter(bucket), tostring(player.UserId), os.clock())
end

function Remotes.Register(action: string, bucket: string, fn: Handler)
	assert(not handlers[action], "duplicate action " .. action)
	handlers[action] = { fn = fn, bucket = bucket }
end

function Remotes.Init()
	local rf = Net.Function("Request")
	rf.OnServerInvoke = function(player: Player, action: any, ...: any): any
		if type(action) ~= "string" then
			return { ok = false, err = "Bad request" }
		end
		local h = handlers[action]
		if not h then
			return { ok = false, err = "Unknown action" }
		end
		if not Remotes.Allow(player, h.bucket) then
			return { ok = false, err = "Slow down!" }
		end
		local ok, result = pcall(h.fn, player, ...)
		if not ok then
			warn(string.format("[Remotes] %s from %s errored: %s", action, player.Name, tostring(result)))
			return { ok = false, err = "Something went wrong" }
		end
		if type(result) ~= "table" then
			return { ok = result == true }
		end
		return result
	end
	Players.PlayerRemoving:Connect(function(player)
		local key = tostring(player.UserId)
		for _, l in limiters do
			l.hits[key] = nil
		end
	end)
end

-- Helpers for handlers
function Remotes.Fail(err: string): any
	return { ok = false, err = err }
end

function Remotes.Root(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Remotes.Near(player: Player, pos: Vector3, maxDist: number): boolean
	local root = Remotes.Root(player)
	return root ~= nil and (root.Position - pos).Magnitude <= maxDist
end

return Remotes
