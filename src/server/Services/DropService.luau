--!strict
-- Physical Ectoplasm orbs. The SERVER decides where each orb lands, what it is worth and
-- when it is picked up (player's root within their pickup radius). Clients only draw orbs
-- (bounce, glow, magnet flight). Orbs are per player, so nobody can steal another's loot.
-- One loop checks every player's orbs on a short interval; no per-orb connections.
-- v1.6: an orb is an EARNED payout, so it is never lost: orbs that time out or are pushed out
-- by the per-player cap are credited automatically, and when a player leaves (or the server
-- closes) every orb still on the ground is credited before the final save.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Signal = require(GH.Signal)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local Remotes = require(script.Parent.Remotes)

local DropService = {}

type Drop = { Id: number, Pos: Vector3, Value: number, Expires: number }
type Bag = { List: { Drop }, NextId: number }

local bags: { [Player]: Bag } = {}
local dropsRemote: RemoteEvent
local collectRemote: RemoteEvent
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local collectedSignal = Signal.new()
DropService.Collected = collectedSignal -- (player, amount)

-- Ground raycasts ignore ghosts and characters (filter built once per Spawn call).
local function refreshFilter()
	local filter: { Instance } = {}
	local ghosts = workspace:FindFirstChild("Ghosts")
	if ghosts then
		table.insert(filter, ghosts)
	end
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(filter, pl.Character)
		end
	end
	rayParams.FilterDescendantsInstances = filter
end

local function groundAt(x: number, y: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, y + 4, z), Vector3.new(0, -80, 0), rayParams)
	return if hit then hit.Position.Y else 0
end

-- Spawns `total` Ectoplasm split into `count` orbs around `origin` for `player`.
-- scatter = {min, max} studs (defaults from Config.Drops).
function DropService.Spawn(player: Player, origin: Vector3, total: number, count: number, scatter: { number }?)
	local bag = bags[player]
	if not bag then
		return
	end
	local values = Rules.Split(total, math.max(1, count))
	local sMin = if scatter then scatter[1] else Config.Drops.ScatterMin
	local sMax = if scatter then scatter[2] else Config.Drops.ScatterMax
	local expires = os.clock() + Config.Drops.Lifetime
	local out: { { any } } = {}
	local removed: { number } = {}
	local autoCredit = 0
	refreshFilter()
	for _, v in values do
		-- over the cap (nobody is collecting): the oldest orb is auto-collected to make room
		if #bag.List >= Config.Drops.MaxPerPlayer then
			local oldest = 1
			for i, d in bag.List do
				if d.Expires < bag.List[oldest].Expires then
					oldest = i
				end
			end
			table.insert(removed, bag.List[oldest].Id)
			autoCredit += bag.List[oldest].Value
			bag.List[oldest] = bag.List[#bag.List]
			bag.List[#bag.List] = nil
		end
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(sMin, sMax)
		local x = origin.X + math.cos(a) * r
		local z = origin.Z + math.sin(a) * r
		-- keep orbs inside the playable area
		x = math.clamp(x, -Config.Layout.HalfWidth + 4, Config.Layout.HalfWidth - 4)
		local y = groundAt(x, origin.Y, z) + 1.1
		local drop: Drop = { Id = bag.NextId, Pos = Vector3.new(x, y, z), Value = v, Expires = expires }
		bag.NextId += 1
		table.insert(bag.List, drop)
		table.insert(out, { drop.Id, drop.Pos, drop.Value } :: { any })
	end
	if #out > 0 then
		dropsRemote:FireClient(player, origin, out, removed)
	end
	if autoCredit > 0 then
		DataService.AddEcto(player, autoCredit)
	end
end

local function pickupTick()
	local t = os.clock()
	for player, bag in bags do
		if #bag.List == 0 then
			continue
		end
		local root = Remotes.Root(player)
		local radius = PlayerInfo.PickupRadius(player) + 1.5 -- latency slack
		local r2 = radius * radius
		local got = 0
		local ids = {}
		local i = 1
		while i <= #bag.List do
			local d = bag.List[i]
			local take = false
			if root then
				local dx = d.Pos.X - root.Position.X
				local dz = d.Pos.Z - root.Position.Z
				take = dx * dx + dz * dz <= r2 and math.abs(d.Pos.Y - root.Position.Y) < 14
			end
			if take then
				got += d.Value
				table.insert(ids, d.Id)
				bag.List[i] = bag.List[#bag.List]
				bag.List[#bag.List] = nil
			elseif t >= d.Expires then
				got += d.Value -- timed out: still paid (it was earned)
				table.insert(ids, d.Id)
				bag.List[i] = bag.List[#bag.List]
				bag.List[#bag.List] = nil
			else
				i += 1
			end
		end
		if got > 0 then
			DataService.AddEcto(player, got)
			collectRemote:FireClient(player, ids, got)
			collectedSignal:Fire(player, got)
		end
	end
end

function DropService.Init()
	dropsRemote = Net.Event("Drops")
	collectRemote = Net.Event("Collect")
	-- leaving / server closing: credit every orb still on the ground before the final save
	DataService.AddLeaveHook(function(player, data)
		local bag = bags[player]
		if not bag then
			return
		end
		local total = 0
		for _, d in bag.List do
			total += d.Value
		end
		table.clear(bag.List)
		if total > 0 then
			data.Ecto += total
			data.TotalEcto += total
		end
	end)
end

function DropService.Start()
	local function add(player: Player)
		bags[player] = { List = {}, NextId = 1 }
	end
	Players.PlayerAdded:Connect(add)
	for _, pl in Players:GetPlayers() do
		add(pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- DataService's leave hook credits the orbs; drop the bag a little later so the hook
		-- never finds it already gone (PlayerRemoving handlers run in any order)
		task.delay(30, function()
			if not player.Parent then
				bags[player] = nil
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Drops.PickupTick)
			local ok, err = pcall(function()
				pickupTick()
			end)
			if not ok then
				warn("[Drops] tick error: " .. tostring(err))
			end
		end
	end)
end

return DropService
