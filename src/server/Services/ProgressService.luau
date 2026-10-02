--!strict
-- Zone unlocks (+ keeping players out of locked zones), upgrades, daily reward,
-- settings and tutorial progress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local ProgressService = {}

local GATE_RANGE = 40
local TRAVEL_COOLDOWN = 3 -- seconds between Fast Travel jumps
local lastTravel: { [Player]: number } = {}

local zoneRanges: { { number } } = {}
for _, z in Config.Zones do
	table.insert(zoneRanges, { z.MinZ, z.MaxZ })
end

local function applyWalkSpeed(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = PlayerInfo.WalkSpeed(player)
	end
end

-- Daily reward grant (also used by Day 7 crate token).
local function grantReward(player: Player, d: DataService.Data, reward: Config.RewardDef): string
	local mult = PlayerInfo.ZoneMultiplier(player)
	if reward.Amount and reward.Amount > 0 then
		DataService.AddEcto(player, reward.Amount * mult)
	end
	if reward.Boost and reward.Seconds then
		PlayerInfo.AddBoost(d, reward.Boost, reward.Seconds)
	end
	if reward.Crate then
		d.FreeCrates[reward.Crate] = (d.FreeCrates[reward.Crate] or 0) + 1
	end
	if reward.Amount and mult > 1 then
		return (reward.Label:gsub(Format.Commas(reward.Amount), Format.Commas(reward.Amount * mult)))
	end
	return reward.Label
end
ProgressService.GrantReward = grantReward

function ProgressService.Init()
	DataService.AddDecorator(function(_player, s)
		local d = s :: any
		local info = Rules.Daily(os.time(), d.Daily.Last, d.Daily.Streak, Config.Daily.Cooldown, Config.Daily.StreakReset, #Config.Daily.Rewards)
		s.DailyInfo = info
	end)

	Remotes.Register("UnlockZone", "Default", function(player, zoneId)
		local d = DataService.Get(player)
		local zone = type(zoneId) == "string" and Config.ZoneById[zoneId] or nil
		if not d or not zone then
			return Remotes.Fail("Unknown area")
		end
		if d.Zones[zone.Id] then
			return { ok = true }
		end
		local prev = Config.Zones[zone.Order - 1]
		if prev and not d.Zones[prev.Id] then
			return Remotes.Fail("Unlock " .. prev.Name .. " first!")
		end
		local gate = Config.Layout.Gates[zone.Id]
		if gate and not Remotes.Near(player, Vector3.new(0, 3, gate.Z), GATE_RANGE) then
			return Remotes.Fail("Walk to the gate first!")
		end
		if not DataService.Spend(player, zone.Cost) then
			return Remotes.Fail("Not enough Ectoplasm!")
		end
		d.Zones[zone.Id] = true
		DataService.Changed(player)
		Fx.To(player, "ZoneUnlocked", { Zone = zone.Id })
		return { ok = true }
	end)

	-- Fast Travel (WORLDS menu): only to zones this profile owns, onto the zone's arrival pad.
	Remotes.Register("Travel", "Default", function(player, zoneId)
		local d = DataService.Get(player)
		local zone = type(zoneId) == "string" and Config.ZoneById[zoneId] or nil
		if not d or not zone then
			return Remotes.Fail("Unknown area")
		end
		if not d.Zones[zone.Id] then
			return Remotes.Fail("Unlock " .. zone.Name .. " first!")
		end
		local now = os.clock()
		if now - (lastTravel[player] or -math.huge) < TRAVEL_COOLDOWN then
			return Remotes.Fail("Wait a moment...")
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = Remotes.Root(player)
		if not char or not hum or hum.Health <= 0 or not root then
			return Remotes.Fail("Can't travel right now")
		end
		local spawnPos = (Config.Layout.ZoneSpawns :: any)[zone.Id] :: Vector3?
		if not spawnPos then
			return Remotes.Fail("Unknown area")
		end
		lastTravel[player] = now
		-- small random offset so a group travelling together doesn't stack
		local a = math.random() * math.pi * 2
		local r = math.random() * 3
		local pos = spawnPos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		root.AssemblyLinearVelocity = Vector3.zero
		char:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
		return { ok = true }
	end)

	Remotes.Register("BuyUpgrade", "Default", function(player, upgradeId)
		local d = DataService.Get(player)
		local up = type(upgradeId) == "string" and Config.Upgrades[upgradeId] or nil
		if not d or not up then
			return Remotes.Fail("Unknown upgrade")
		end
		local level = d.Upgrades[up.Id] or 1
		local cost = Rules.UpgradeCost(up.Costs, level)
		if not cost then
			return Remotes.Fail("Already maxed!")
		end
		if not DataService.Spend(player, cost) then
			return Remotes.Fail("Not enough Ectoplasm!")
		end
		d.Upgrades[up.Id] = level + 1
		if up.Id == "MoveSpeed" then
			applyWalkSpeed(player)
		end
		DataService.Changed(player)
		return { ok = true, Level = level + 1 }
	end)

	Remotes.Register("ClaimDaily", "Default", function(player)
		local d = DataService.Get(player)
		if not d then
			return Remotes.Fail("Loading...")
		end
		local now = os.time()
		local info = Rules.Daily(now, d.Daily.Last, d.Daily.Streak, Config.Daily.Cooldown, Config.Daily.StreakReset, #Config.Daily.Rewards)
		if not info.CanClaim then
			return Remotes.Fail("Come back in " .. Format.Time(info.Wait))
		end
		local reward = Config.Daily.Rewards[info.Day]
		local streak = if info.Day == 1 then 1 else d.Daily.Streak + 1
		d.Daily.Last = now
		d.Daily.Streak = streak
		local label = grantReward(player, d, reward)
		DataService.Changed(player)
		DataService.Save(player)
		return { ok = true, Day = info.Day, Label = label }
	end)

	Remotes.Register("Setting", "Default", function(player, key, value)
		local d = DataService.Get(player)
		if not d or type(key) ~= "string" or type(value) ~= "boolean" then
			return Remotes.Fail("Bad setting")
		end
		if type((d.Settings :: any)[key]) ~= "boolean" then
			return Remotes.Fail("Bad setting")
		end
		(d.Settings :: any)[key] = value
		DataService.Changed(player)
		return { ok = true }
	end)

	-- Tutorial progress is cosmetic (client-driven guidance); only allow moving forward.
	Remotes.Register("Tutorial", "Default", function(player, step)
		local d = DataService.Get(player)
		if not d or type(step) ~= "number" or step ~= step then
			return Remotes.Fail("Bad step")
		end
		step = math.clamp(math.floor(step), 1, #Config.Tutorial.Steps + 1)
		if step > d.Tutorial then
			d.Tutorial = step
			DataService.Changed(player)
		end
		return { ok = true }
	end)
end

-- Server-side guard: anyone standing in a zone they don't own is moved back to the gate.
local function zoneGuardTick()
	for _, player in Players:GetPlayers() do
		local d = DataService.Get(player)
		local root = Remotes.Root(player)
		if not d or not root then
			continue
		end
		local idx = Rules.ZoneIndexAt(root.Position.Z, zoneRanges)
		local zone = Config.Zones[idx]
		if zone and not d.Zones[zone.Id] then
			-- find the furthest owned zone and drop them in front of its exit gate
			local safeZ = Config.Layout.Spawn.Z
			for i = idx - 1, 1, -1 do
				local z = Config.Zones[i]
				if d.Zones[z.Id] then
					local nextZone = Config.Zones[i + 1]
					local gate = nextZone and Config.Layout.Gates[nextZone.Id]
					safeZ = if gate then gate.Z - 12 else z.MinZ + 20
					break
				end
			end
			local char = player.Character
			if char then
				char:PivotTo(CFrame.new(math.clamp(root.Position.X, -10, 10), 4, safeZ))
			end
		end
	end
end

function ProgressService.Start()
	local function setup(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			applyWalkSpeed(player)
			-- players pass through each other: characters go in their own collision group
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") then
					part.CollisionGroup = "Players"
				end
			end
			char.DescendantAdded:Connect(function(part)
				if part:IsA("BasePart") then
					part.CollisionGroup = "Players"
				end
			end)
		end
	end
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			setup(player, char)
		end)
		-- a character that spawned while the world was still building
		if player.Character then
			task.spawn(setup, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
	for _, pl in Players:GetPlayers() do
		hook(pl)
	end
	DataService.Loaded:Connect(function(player)
		applyWalkSpeed(player)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				zoneGuardTick()
			end)
			if not ok then
				warn("[Zones] guard error: " .. tostring(err))
			end
		end
	end)
end

return ProgressService
