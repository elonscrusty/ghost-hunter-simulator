--!strict
-- ENDLESS BOSS TOWER: parties of up to Config.Tower.MaxParty fight one boss per room in their
-- own room space far outside the main map. A run starts at Room 1 or, if the starter picks it,
-- just after the party's lowest common CHECKPOINT (clearing room 5, 10, ... saves one; skipped
-- rooms pay nothing). Each room's boss is scaled to the party's power at room start; rewards
-- (Ectoplasm + Spirit Shards) are credited the moment a boss is beaten and are never taken back.
-- DEV runs (TowerService.DevStart) are solo, start at any room and give no rewards at all.
--
-- Flow (all decided here; clients only ask to start, vote CONTINUE or LEAVE):
--   pad (prompt or "TowerStart"(startRoom)) -> countdown -> party = players on the pad -> room built ->
--   teleport -> FIGHT (RoomSeconds) -> boss killed: rewards + chest -> BETWEEN (vote window)
--   -> next room ... until a timeout, a wipe, no votes, or everyone left.
--
-- Client messages:
--   Fx "Tower" { State = "Pad", EndsAt, Count, Max, StartRoom } / { State = "PadCancel" }
--              { State = "Fight", Room, Uid, Boss, EndsAt, Party, Dev, Earned = { Ecto, Shards } }
--              { State = "Votes", Votes, Party }
--              { State = "Ended", Reason, Best, Earned }
--   Fx "TowerRoomCleared" { Room, EndsAt, Ecto, Shards, Pct, Earned, Party, Pos, Dev, Checkpoint? } (chest visual)
--   Fx "Payout" (the usual share popup, plus Shards)
-- Player attributes while in a run: InTower = true, TowerRoom = n.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local CrewService = require(script.Parent.CrewService)
local GhostService = require(script.Parent.GhostService)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)
local TowerRoom = require(script.Parent.Parent.World.TowerRoom)

local TowerService = {}

local TC = Config.Tower
local TICK = 0.25
local SLOT_X, SLOT_Z, SLOT_STEP, SLOTS_PER_ROW = 1400, -600, 300, 4

type Earned = { Ecto: number, Shards: number }
export type Run = {
	Id: number,
	Slot: number,
	Origin: Vector3,
	Members: { [Player]: boolean }, -- GhostService only lets these players target the boss
	Room: number,
	Phase: string, -- "Fight" | "Between" | "Starting" | "Ended"
	Boss: GhostService.Ghost?,
	Claimed: { [number]: boolean }, -- room -> rewards paid (exactly once)
	Votes: { [Player]: boolean },
	Earned: { [Player]: Earned },
	Best: number, -- highest room cleared in this run
	Model: Model?,
	EndsAt: number,
	Dev: boolean, -- developer test run: no rewards, no checkpoint, no stats
}

local runs: { [number]: Run } = {}
local slots: { [number]: Run } = {}
local memberOf: { [Player]: Run } = {}
local nextId = 1
local roomsFolder: Folder
local padPart: BasePart? = nil

type Lobby = { EndsAt: number, Seen: { [Player]: boolean }, Joined: { [Player]: boolean }, StartRoom: number }
local lobby: Lobby? = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function slotOrigin(slot: number): Vector3
	local i = slot - 1
	return Vector3.new(SLOT_X + (i % SLOTS_PER_ROW) * SLOT_STEP, 0, SLOT_Z - math.floor(i / SLOTS_PER_ROW) * SLOT_STEP)
end

local function freeSlot(): number?
	for i = 1, TC.Slots do
		if not slots[i] then
			return i
		end
	end
	return nil
end

local function memberList(run: Run): { Player }
	local list = {}
	for p in run.Members do
		table.insert(list, p)
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function voteCount(run: Run): number
	local n = 0
	for p in run.Votes do
		if run.Members[p] then
			n += 1
		end
	end
	return n
end

local function earnedOf(run: Run, p: Player): Earned
	local e = run.Earned[p]
	if not e then
		e = { Ecto = 0, Shards = 0 }
		run.Earned[p] = e
	end
	return e
end

-- Zeroes velocity and pivots the character; false if there is no live character or it failed.
local function teleport(player: Player, pos: Vector3, facing: Vector3): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = Remotes.Root(player)
	if not char or not hum or hum.Health <= 0 or not root then
		return false
	end
	local ok = pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		char:PivotTo(CFrame.lookAt(pos, pos + facing))
	end)
	-- fall rescue inside the tower returns here, never to the main map
	player:SetAttribute("TowerSafe", if ok and player:GetAttribute("InTower") then pos else nil)
	return ok
end

local function sendHome(player: Player)
	local a = math.random() * math.pi * 2
	local r = math.random() * 4
	local pos = Config.Layout.Spawn + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	teleport(player, pos, Vector3.new(0, 0, 1))
end

local function clearPlayer(player: Player)
	player:SetAttribute("InTower", nil)
	player:SetAttribute("TowerRoom", nil)
	player:SetAttribute("TowerSafe", nil)
	if player.Parent then
		HunterService.Refresh(player) -- the Backup Rookie may step in again outside the tower
	end
end

local function sendAll(run: Run, kind: string, make: (Player) -> any)
	for p in run.Members do
		if p.Parent then
			Fx.To(p, kind, make(p))
		end
	end
end

local cleanup: (Run) -> ()

-- Takes one member out of the run (rewards already credited stay). teleportHome=false when the
-- player is gone or already respawned at the spawn.
local function leave(run: Run, player: Player, reason: string, teleportHome: boolean)
	if not run.Members[player] then
		return
	end
	run.Members[player] = nil
	run.Votes[player] = nil
	if memberOf[player] == run then
		memberOf[player] = nil
	end
	if player.Parent then
		clearPlayer(player)
		if teleportHome then
			sendHome(player)
		end
		Fx.To(player, "Tower", { State = "Ended", Reason = reason, Best = run.Best, Earned = earnedOf(run, player) })
	end
	if next(run.Members) == nil then
		cleanup(run)
	elseif run.Phase == "Between" then
		local party = #memberList(run)
		sendAll(run, "Tower", function()
			return { State = "Votes", Votes = voteCount(run), Party = party }
		end)
	end
end

function cleanup(run: Run)
	if run.Phase == "Ended" then
		return
	end
	run.Phase = "Ended"
	for _, p in memberList(run) do
		run.Members[p] = nil
		if memberOf[p] == run then
			memberOf[p] = nil
		end
		if p.Parent then
			clearPlayer(p)
		end
	end
	local g = run.Boss
	run.Boss = nil
	if g and g.Alive then
		GhostService.Remove(g, nil, false)
	end
	if run.Model then
		run.Model:Destroy()
		run.Model = nil
	end
	if slots[run.Slot] == run then
		slots[run.Slot] = nil
	end
	runs[run.Id] = nil
end

-- Ends the run for everyone: each member goes back to the spawn with a message.
local function endRun(run: Run, reason: string)
	if run.Phase == "Ended" then
		return
	end
	for _, p in memberList(run) do
		leave(run, p, reason, true)
	end
	cleanup(run)
end

-- Starts room n: heals crews, moves the party to the entry (rooms after the first), spawns the
-- boss scaled to the party's power right now.
local function startRoom(run: Run, n: number)
	local model = run.Model
	if not model then
		endRun(run, "The tower room vanished...")
		return
	end
	run.Room = n
	run.Votes = {}
	run.Phase = "Starting"
	TowerRoom.SetRoom(model, n)
	local chest = model:FindFirstChild("Chest")
	if chest then
		chest:Destroy()
	end
	local members = memberList(run)
	local entry = TowerRoom.Entry(run.Origin)
	for i, p in members do
		CrewService.HealAll(p)
		p:SetAttribute("TowerRoom", n)
		if n > 1 then
			local pos = entry + Vector3.new((i - (#members + 1) / 2) * 5, 3, 0)
			if not teleport(p, pos, Vector3.new(0, 0, 1)) then
				leave(run, p, "You couldn't follow your party to the next room.", true)
			end
		end
	end
	if run.Phase == "Ended" then
		return
	end
	local power = 0
	for p in run.Members do
		power += HunterService.CrewPower(p)
	end
	power = math.max(1, power)
	local bossHP, hitFrac = Rules.TowerScale(n, TC, power)
	local def = Config.Ghosts[TC.Bosses[(n - 1) % #TC.Bosses + 1]]
	local g = GhostService.Spawn(def, TowerRoom.BossCenter(run.Origin), TowerRoom.BossRadius, {
		Spirit = bossHP,
		Tower = run,
		HitFrac = hitFrac,
	})
	run.Boss = g
	run.EndsAt = serverNow() + TC.RoomSeconds
	g.Model:SetAttribute("EndsAt", run.EndsAt)
	run.Phase = "Fight"
	local party = #memberList(run)
	sendAll(run, "Tower", function(p)
		return { State = "Fight", Room = n, Uid = g.Uid, Boss = def.Name, EndsAt = run.EndsAt, Party = party, Dev = run.Dev, Earned = earnedOf(run, p) }
	end)
end

local function startRoomSafe(run: Run, n: number)
	local ok, err = pcall(function()
		startRoom(run, n)
	end)
	if not ok then
		warn("[Tower] room start failed: " .. tostring(err))
		pcall(endRun, run, "Something went wrong in the tower. Your rewards are safe!")
	end
end

-- Boss beaten: pay every contributor once, open the chest, start the vote window.
local function onCleared(run: Run, g: GhostService.Ghost)
	local room = run.Room
	run.Best = math.max(run.Best, room)
	run.Boss = nil
	local members = memberList(run)
	local shardsEach, ectoEach = Rules.TowerReward(room, TC)
	-- SHARED POOLS: (reward per member * party size), split by effective damage among the
	-- members still in the run (no damage = no share).
	local split = GhostService.SplitDamage(g)
	local players, weights, total = {}, {}, 0
	for i, p in split.Players do
		if run.Members[p] and not run.Dev then -- dev runs pay nothing
			table.insert(players, p)
			table.insert(weights, split.Weights[i])
			total += split.Weights[i]
		end
	end
	-- pool size counts members who did at least 10% of the damage (idle alts add nothing)
	local _ = members
	local sized = Rules.PoolMembers(weights, 0.1)
	local shardShares = Rules.SplitPool(shardsEach * sized, weights)
	local ectoShares = Rules.SplitPool(ectoEach * sized, weights)
	local paid: { [Player]: { Ecto: number, Shards: number, Pct: number } } = {}
	for i, p in players do
		local d = DataService.Get(p)
		if not d or weights[i] <= 0 then
			continue
		end
		local shards = shardShares[i]
		local base = ectoShares[i]
		local ecto = if base > 0 then math.max(1, math.floor(base * PlayerInfo.ZoneMultiplier(p) * PlayerInfo.EctoMultiplier(p) + 0.5)) else 0
		if ecto > 0 then
			DataService.AddEcto(p, ecto)
		end
		d.Shards += shards
		d.TowerShards += shards
		d.TowerRooms += 1
		local e = earnedOf(run, p)
		e.Ecto += ecto
		e.Shards += shards
		local pct = if total > 0 then weights[i] / total else 0
		paid[p] = { Ecto = ecto, Shards = shards, Pct = pct }
		Fx.To(p, "Payout", { Name = g.Def.Name, Pct = pct, Ecto = ecto, Shards = shards })
	end
	local cp = Rules.TowerCheckpoint(room, TC.CheckpointEvery)
	local saved: { [Player]: boolean } = {}
	for _, p in members do
		local d = DataService.Get(p)
		if d and not run.Dev then
			d.TowerBest = math.max(d.TowerBest, room)
			if cp > d.TowerCheckpoint then
				d.TowerCheckpoint = cp
				saved[p] = true
			end
			DataService.Changed(p)
			DataService.Save(p)
		end
	end

	run.Phase = "Between"
	run.Votes = {}
	run.EndsAt = serverNow() + TC.BetweenRoomsSeconds
	local chestPos = TowerRoom.BossCenter(run.Origin)
	local model = run.Model
	if model then
		local chest = TowerRoom.Chest(model, run.Origin)
		chestPos = chest:GetPivot().Position
		task.delay(0.8, function()
			if chest.Parent then
				TowerRoom.OpenChest(chest)
			end
		end)
	end
	local party = #members
	sendAll(run, "TowerRoomCleared", function(p)
		local got = paid[p]
		return {
			Room = room,
			EndsAt = run.EndsAt,
			Ecto = if got then got.Ecto else 0,
			Shards = if got then got.Shards else 0,
			Pct = if got then got.Pct else 0,
			Earned = earnedOf(run, p),
			Party = party,
			Pos = chestPos,
			Dev = run.Dev,
			Checkpoint = if saved[p] then cp else nil,
		}
	end)
end

local function nextRoom(run: Run)
	if run.Phase ~= "Between" then
		return
	end
	run.Phase = "Starting"
	startRoomSafe(run, run.Room + 1)
end

--==================================================================
-- PARTY PAD
--==================================================================
local function padCenter(): Vector3?
	local pad = padPart
	return if pad and pad.Parent then pad.Position else nil
end

local function padDistance(player: Player): number
	local c = padCenter()
	local root = Remotes.Root(player)
	if not c or not root then
		return math.huge
	end
	local d = root.Position - c
	if math.abs(d.Y) > 10 then
		return math.huge
	end
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

local function onPad(player: Player): boolean
	return padDistance(player) <= TC.PadRadius + 0.5
end

-- Why this player can't join a run right now (nil = they can).
local function blocked(player: Player): string?
	if not DataService.Get(player) then
		return "Loading..."
	end
	if player:GetAttribute("InTower") == true or memberOf[player] then
		return "You're already in the tower!"
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return "Can't enter right now"
	end
	if #HunterService.ActiveUids(player) == 0 then
		return "Your crew is knocked out! Wait until a hunter recovers."
	end
	return nil
end

-- Builds a room and moves the party in, starting at room `first`. Returns an error text when
-- nobody could enter (each player was already told why).
local function startRun(party: { Player }, first: number, dev: boolean): string?
	local slot = freeSlot()
	if not slot then
		for _, p in party do
			Fx.Toast(p, "The tower is full right now. Try again in a moment!", "Bad")
		end
		return "The tower is full right now"
	end
	local origin = slotOrigin(slot)
	local run: Run = {
		Id = nextId,
		Slot = slot,
		Origin = origin,
		Members = {},
		Room = 0,
		Phase = "Starting",
		Boss = nil,
		Claimed = {},
		Votes = {},
		Earned = {},
		Best = 0,
		Model = nil,
		EndsAt = 0,
		Dev = dev,
	}
	nextId += 1
	slots[slot] = run
	runs[run.Id] = run
	-- the room exists before anyone is moved there
	local okBuild, model = pcall(TowerRoom.Build, roomsFolder, origin, slot)
	if not okBuild then
		warn("[Tower] room build failed: " .. tostring(model))
		cleanup(run)
		for _, p in party do
			Fx.Toast(p, "The tower door is stuck. Try again!", "Bad")
		end
		return "The tower door is stuck"
	end
	run.Model = model
	local entry = TowerRoom.Entry(origin)
	for i, p in party do
		if blocked(p) ~= nil then
			continue
		end
		p:SetAttribute("InTower", true)
		p:SetAttribute("TowerRoom", first)
		local pos = entry + Vector3.new((i - (#party + 1) / 2) * 5, 3, 0)
		if teleport(p, pos, Vector3.new(0, 0, 1)) then
			run.Members[p] = true
			memberOf[p] = run
			earnedOf(run, p)
			HunterService.Refresh(p)
			local d = DataService.Get(p)
			if d and not dev then
				d.TowerRuns += 1
				DataService.Changed(p)
			end
		else
			clearPlayer(p)
			sendHome(p)
			Fx.Toast(p, "Couldn't enter the tower. Try again!", "Bad")
		end
	end
	if next(run.Members) == nil then
		cleanup(run)
		return "Couldn't enter the tower"
	end
	startRoomSafe(run, first)
	return nil
end

-- Lowest checkpoint every player in the list has reached (0 = someone has none).
local function commonCheckpoint(list: { Player }): number
	local cp = math.huge
	for _, p in list do
		local d = DataService.Get(p)
		cp = math.min(cp, if d then d.TowerCheckpoint else 0)
	end
	return if cp == math.huge then 0 else cp
end

local function runLobby(l: Lobby)
	while serverNow() < l.EndsAt do
		local here = {}
		for _, p in Players:GetPlayers() do
			if onPad(p) and not memberOf[p] and l.Joined[p] then -- only players who chose to enter
				table.insert(here, p)
			end
		end
		for _, p in here do
			Fx.To(p, "Tower", { State = "Pad", EndsAt = l.EndsAt, Count = math.min(#here, TC.MaxParty), Max = TC.MaxParty, StartRoom = l.StartRoom })
			l.Seen[p] = true
		end
		for p in l.Seen do
			if not table.find(here, p) then
				l.Seen[p] = nil
				if p.Parent then
					Fx.To(p, "Tower", { State = "PadCancel" })
				end
			end
		end
		task.wait(0.5)
	end
	lobby = nil
	-- party = eligible players on the pad now, nearest first
	local cands = {}
	for _, p in Players:GetPlayers() do
		if onPad(p) and blocked(p) == nil and l.Joined[p] then
			table.insert(cands, { P = p, D = padDistance(p) })
		end
	end
	table.sort(cands, function(a, b)
		return a.D < b.D
	end)
	local party = {}
	for i, c in cands do
		if i <= TC.MaxParty then
			table.insert(party, c.P)
		end
	end
	for p in l.Seen do
		if p.Parent and not table.find(party, p) then
			Fx.To(p, "Tower", { State = "PadCancel" })
			local why = blocked(p)
			if why then
				Fx.Toast(p, why, "Bad")
			elseif onPad(p) then
				Fx.Toast(p, "The party was full! Try the next run.", "Bad")
			end
		end
	end
	if #party > 0 then
		-- a checkpoint start uses the party's lowest common checkpoint (skipped rooms pay nothing)
		local first = 1
		if l.StartRoom > 1 then
			first = commonCheckpoint(party) + 1
			if first ~= l.StartRoom then
				for _, p in party do
					Fx.Toast(p, if first > 1
						then string.format("Party starts at Room %d (the lowest checkpoint in the party)", first)
						else "Someone in the party has no checkpoint yet: starting at Room 1", "Bad")
				end
			end
		end
		startRun(party, first, false)
	end
end

-- Pad prompt / "TowerStart"(startRoom): opens the countdown for everyone on the pad.
-- startRoom is 1 or (the starter's checkpoint + 1); anything else is refused.
local function requestStart(player: Player, startRoom: any): any
	local first = if startRoom == nil then 1 else startRoom
	if type(first) ~= "number" or first ~= math.floor(first) then
		return Remotes.Fail("Bad room")
	end
	local why = blocked(player)
	if why then
		return Remotes.Fail(why)
	end
	if not onPad(player) then
		return Remotes.Fail("Stand on the tower pad first!")
	end
	if lobby then
		-- joins the countdown that is already running (its starter already chose the room)
		(lobby :: Lobby).Joined[player] = true
		return { ok = true, EndsAt = (lobby :: Lobby).EndsAt, StartRoom = (lobby :: Lobby).StartRoom }
	end
	if first ~= 1 then
		local d = DataService.Get(player)
		local cp = if d then d.TowerCheckpoint else 0
		if cp <= 0 or first ~= cp + 1 then
			return Remotes.Fail("You can start at Room 1" .. (if cp > 0 then " or Room " .. (cp + 1) else ""))
		end
	end
	if not freeSlot() then
		return Remotes.Fail("The tower is full right now. Try again in a moment!")
	end
	local l: Lobby = { EndsAt = serverNow() + TC.Countdown, Seen = {}, Joined = { [player] = true }, StartRoom = first }
	lobby = l
	task.spawn(function()
		local ok, err = pcall(function()
			runLobby(l)
		end)
		if not ok then
			warn("[Tower] lobby error: " .. tostring(err))
			if lobby == l then
				lobby = nil
			end
		end
	end)
	return { ok = true, EndsAt = l.EndsAt }
end

local function setupPrompt()
	local map = workspace:FindFirstChild("Map")
	local plaza = map and map:FindFirstChild("EventArena")
	local pad = plaza and plaza:FindFirstChild("TowerPad")
	if not pad or not pad:IsA("BasePart") then
		warn("[Tower] TowerPad not found; the pad prompt is off (TowerStart still works only on a pad)")
		return
	end
	padPart = pad
	local att = Instance.new("Attachment")
	att.Name = "PromptPoint"
	att.Parent = pad
	att.WorldPosition = pad.Position + Vector3.new(0, 3.5, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TowerPrompt"
	prompt.ActionText = "Enter Boss Tower"
	prompt.ObjectText = "Endless Boss Tower"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TC.PadRadius + 4
	prompt.RequiresLineOfSight = false
	prompt.Parent = att
	prompt.Triggered:Connect(function(player)
		if not Remotes.Allow(player, "Default") then
			return
		end
		local d = DataService.Get(player)
		if not lobby and d and d.TowerCheckpoint > 0 then
			-- they have a checkpoint: let them pick the start room with the pad buttons
			Fx.Toast(player, "Pick Room 1 or your checkpoint with the buttons below!", "Good")
			return
		end
		local res = requestStart(player, 1)
		if not res.ok and res.err then
			Fx.Toast(player, res.err, "Bad")
		end
	end)
end

--==================================================================
-- LOOP (one for all runs)
--==================================================================
local function tickRun(run: Run, t: number)
	for _, p in memberList(run) do
		if not p.Parent then
			leave(run, p, "", false)
		end
	end
	if run.Phase == "Fight" then
		-- wipe: nobody has a hunter that can fight
		local anyActive = false
		for p in run.Members do
			if #HunterService.ActiveUids(p) > 0 then
				anyActive = true
				break
			end
		end
		local g = run.Boss
		if not anyActive then
			endRun(run, "Your whole crew was knocked out! The run is over (rewards kept).")
		elseif t >= run.EndsAt and g and g.Alive then
			endRun(run, "Time's up! The boss held its room (rewards kept).")
		elseif (not g or not g.Alive) and t >= run.EndsAt + 5 then
			endRun(run, "The run ended.") -- safety: a boss gone without a kill message
		end
	elseif run.Phase == "Between" then
		local party = 0
		for _ in run.Members do
			party += 1
		end
		local votes = voteCount(run)
		if party > 0 and votes >= party then
			nextRoom(run)
		elseif t >= run.EndsAt then
			if votes > 0 then
				nextRoom(run)
			else
				endRun(run, "Nobody chose CONTINUE. Run over: great job!")
			end
		end
	end
end

function TowerService.Init()
	roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "TowerRooms"
	roomsFolder.Parent = workspace

	Remotes.Register("TowerStart", "Default", function(player, startRoom)
		return requestStart(player, startRoom)
	end)

	Remotes.Register("TowerContinue", "Default", function(player)
		local run = memberOf[player]
		if not run or not run.Members[player] then
			return Remotes.Fail("You're not in the tower")
		end
		if run.Phase ~= "Between" then
			return Remotes.Fail("Beat the boss first!")
		end
		run.Votes[player] = true
		local party = #memberList(run)
		local votes = voteCount(run)
		sendAll(run, "Tower", function()
			return { State = "Votes", Votes = votes, Party = party }
		end)
		if votes >= party then
			nextRoom(run)
		end
		return { ok = true }
	end)

	Remotes.Register("TowerLeave", "Default", function(player)
		local run = memberOf[player]
		if not run or not run.Members[player] then
			return Remotes.Fail("You're not in the tower")
		end
		leave(run, player, "You left the tower. Rewards kept!", true)
		return { ok = true }
	end)
end

function TowerService.Start()
	setupPrompt()

	GhostService.Killed:Connect(function(g: GhostService.Ghost, _killer: Player?)
		local tower = g.Tower
		if type(tower) ~= "table" then
			return
		end
		local run = tower :: Run
		if runs[run.Id] ~= run or run.Phase ~= "Fight" or run.Boss ~= g or run.Claimed[run.Room] then
			return
		end
		run.Claimed[run.Room] = true
		local ok, err = pcall(function()
			onCleared(run, g)
		end)
		if not ok then
			warn("[Tower] reward error: " .. tostring(err))
			pcall(endRun, run, "Something went wrong in the tower. Your rewards are safe!")
		end
	end)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			-- a respawned character appears at the spawn: that member's run is over
			local run = memberOf[player]
			if run then
				leave(run, player, "You respawned outside the tower. Rewards kept!", false)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = memberOf[player]
		if run then
			leave(run, player, "", false)
		end
		memberOf[player] = nil
		if lobby then
			(lobby :: Lobby).Seen[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local t = serverNow()
			for _, run in runs do
				local ok, err = pcall(function()
					tickRun(run, t)
				end)
				if not ok then
					warn("[Tower] tick error: " .. tostring(err))
					pcall(endRun, run, "Something went wrong in the tower. Your rewards are safe!")
				end
			end
		end
	end)
end

-- DEV: starts a SOLO test run at `room` (1..MaxScaledRoom) right away. The caller (DevService)
-- already checked dev auth. Dev runs give no Ectoplasm/Shards, no checkpoint and no tower stats.
-- Returns an error text, or nil when the run started.
function TowerService.DevStart(player: Player, room: number): string?
	if type(room) ~= "number" or room ~= room or room ~= math.floor(room) or room < 1 or room > TC.MaxScaledRoom then
		return "Room must be 1-" .. TC.MaxScaledRoom
	end
	local why = blocked(player)
	if why then
		return why
	end
	if lobby then
		(lobby :: Lobby).Joined[player] = nil -- don't also join a pad countdown
	end
	return startRun({ player }, room, true)
end

-- Players in a run (for other systems / debugging).
function TowerService.RunOf(player: Player): Run?
	return memberOf[player]
end

return TowerService
