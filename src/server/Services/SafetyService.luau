--!strict
-- Fall-through-map safety net. Remembers where each character last stood on solid ground and,
-- if a character ever drops below Config.FallSafety.MinY (well under every floor), puts it
-- back there with a friendly toast. Never kills, never removes anything, no penalty.
-- workspace.FallenPartsDestroyHeight is lowered so this rescue always fires before Roblox
-- deletes a falling character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Fx = require(script.Parent.Fx)

local SafetyService = {}

local cfg = Config.FallSafety
local MIN_Y: number = cfg.MinY
local CHECK_SECONDS: number = cfg.CheckSeconds
local SAFE_EVERY: number = cfg.SafeEvery
local SAFE_MAX_Y = -2 -- root must be above this (lowest walkable floor top is ~ -0.5)
local RESCUE_COOLDOWN = 2 -- seconds; lets the teleport replicate before checking again
local TOAST = "Whoops! You fell out of the world - put you back safely."

type Track = { LastSafe: CFrame?, SafeInTower: boolean, SafeAt: number, RescuedAt: number }
local tracks: { [Player]: Track } = {}

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = { LastSafe = nil, SafeInTower = false, SafeAt = 0, RescuedAt = 0 }
		tracks[player] = t
	end
	return t
end

-- True when there is solid ground within a few studs below `pos`.
local function groundBelow(pos: Vector3, character: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), params) ~= nil
end

-- Fast Travel arrival pad nearest to `pos` (falls back to the main spawn).
local function nearestZoneSpawn(pos: Vector3): Vector3
	local best: Vector3 = Config.Layout.Spawn
	local bestD = math.huge
	local spawns: { [string]: Vector3 } = (Config.Layout :: any).ZoneSpawns or {}
	for _, p in spawns do
		local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	return Vector3.new(best.X, 3, best.Z)
end

local function rescue(player: Player, character: Model, root: BasePart, t: Track)
	local fellAt = root.Position
	local target: CFrame? = nil
	local source = "zone spawn"

	if player:GetAttribute("InTower") == true then
		local towerSafe = player:GetAttribute("TowerSafe")
		if typeof(towerSafe) == "Vector3" then
			target = CFrame.new(towerSafe + Vector3.new(0, 3, 0))
			source = "TowerSafe"
		end
	end
	-- a spot saved inside a tower room never counts on the main map (and vice versa)
	if not target and t.LastSafe and t.SafeInTower == (player:GetAttribute("InTower") == true) then
		local cf = (t.LastSafe :: CFrame) + Vector3.new(0, 3, 0)
		if groundBelow(cf.Position, character) then
			target = cf
			source = "last safe spot"
		end
	end
	if not target then
		target = CFrame.new(nearestZoneSpawn(fellAt))
	end
	local dest = target :: CFrame

	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
	character:PivotTo(dest)
	t.RescuedAt = os.clock()

	warn(string.format(
		"[Safety] %s fell out of the world at (%.1f, %.1f, %.1f) -> back to %s (%.1f, %.1f, %.1f)%s",
		player.Name,
		fellAt.X,
		fellAt.Y,
		fellAt.Z,
		source,
		dest.Position.X,
		dest.Position.Y,
		dest.Position.Z,
		if player:GetAttribute("InTower") == true then " [in tower]" else ""
	))
	pcall(Fx.Toast, player, TOAST)
end

local function check(player: Player, now: number)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local t = track(player)
	local y = root.Position.Y
	if y < MIN_Y then
		if now - t.RescuedAt >= RESCUE_COOLDOWN then
			rescue(player, character, root, t)
		end
	elseif y > SAFE_MAX_Y and humanoid.FloorMaterial ~= Enum.Material.Air and now - t.SafeAt >= SAFE_EVERY then
		-- keep only position + facing (no tilt)
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local pos = root.Position
		t.LastSafe = if flat.Magnitude > 0.01 then CFrame.lookAt(pos, pos + flat.Unit) else CFrame.new(pos)
		t.SafeInTower = player:GetAttribute("InTower") == true
		t.SafeAt = now
	end
end

function SafetyService.Init()
	-- (scripts may not set Workspace.FallenPartsDestroyHeight; the default -500 is far below the
	-- MinY -40 rescue line, so the rescue always fires first)
end

function SafetyService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			local t = track(player)
			t.LastSafe = nil
			t.SafeAt = 0
		end)
	end
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					check(player, now)
				end)
				if not ok then
					warn("[Safety] check failed for " .. player.Name .. ": " .. tostring(err))
				end
			end
		end
	end)
end

return SafetyService
