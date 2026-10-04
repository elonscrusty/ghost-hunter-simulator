--!strict
-- FREE RARE PET launch event (Config.RarePetEvent). ONE global 48-hour window, started only by
-- an admin (Config.RarePetEvent.AdminUserIds) from the DEV panel. Never starts by itself.
--   * state { Id, Start, End } lives in a DataStore under "<Key>_<Id>". Activation is a single
--     UpdateAsync that writes ONLY when nothing is saved yet, so double taps, retries or two
--     servers at once can never create a second event or move the deadline. An Id that was ever
--     started can never start again (a future event needs a new Id in Config).
--   * after activation the server publishes on Config.RarePetEvent.Topic; every server also reads
--     the state at start and every RefreshSeconds (a missed message heals)
--   * clients see workspace attributes RarePetEventId / RarePetStart / RarePetEnd (+ RarePetChecked
--     once this server has read the saved state)
--   * Studio: state is kept in memory only (the production DataStore is never touched), so a
--     Studio test can never start the live event or grant live rewards
-- Players earn active play time (d.EventPlay[Id].S) only inside [Start, End) and only while not
-- idle. Reaching RequiredSeconds grants the pet once per account (G), also on a later join.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local RarePetEventService = {}

export type EventState = { Id: string, Start: number, End: number }
export type Status = { State: string, Start: number?, End: number? } -- Checking | NotStarted | Active | Ended
export type ActivateResult = { ok: boolean, err: string?, Created: boolean, Event: Status }

local E = Config.RarePetEvent
local IS_STUDIO = RunService:IsStudio()
local KEY = E.Key .. "_" .. E.Id
local MOVE_STUDS = 3

local store: DataStore? = nil
local current: EventState? = nil
local checked = false -- this server has read the saved state at least once
local activating = false

type Track = { Pos: Vector3?, Moved: number? } -- last root position, os.clock() of last movement
local track: { [Player]: Track } = {}

local function sanitize(v: any): EventState?
	if type(v) == "table" and v.Id == E.Id and type(v.Start) == "number" and type(v.End) == "number" and v.End > v.Start then
		return { Id = E.Id, Start = math.floor(v.Start), End = math.floor(v.End) }
	end
	return nil
end

function RarePetEventService.IsAdmin(player: Player): boolean
	if IS_STUDIO then
		return true -- the local tester (memory-only state, see above)
	end
	return table.find(E.AdminUserIds, player.UserId) ~= nil
end

function RarePetEventService.Status(): Status
	local st = current
	if not st then
		return { State = if checked then "NotStarted" else "Checking" }
	end
	local now = os.time()
	return { State = if now < st.End then "Active" else "Ended", Start = st.Start, End = st.End }
end

function RarePetEventService.Active(): boolean
	local st = current
	local now = os.time()
	return st ~= nil and now >= st.Start and now < st.End
end

-- Applies a state in this server. Saved state (fromStore) is the truth; a message is only used
-- while nothing is known yet (the periodic re-read corrects anything else).
local function apply(st: EventState?, fromStore: boolean)
	if fromStore then
		checked = true
		workspace:SetAttribute("RarePetChecked", true)
	end
	if not st then
		return
	end
	if current and not fromStore then
		return
	end
	local old = current
	current = st
	workspace:SetAttribute("RarePetEventId", st.Id)
	workspace:SetAttribute("RarePetStart", st.Start)
	workspace:SetAttribute("RarePetEnd", st.End)
	if not old and os.time() < st.End then
		Fx.All("RarePetEventStarted", { Start = st.Start, End = st.End })
	end
end

-- Reads the saved state. ok = false when the read failed (state unknown).
local function load(): (boolean, EventState?)
	local s = store
	if not s then
		return IS_STUDIO, if IS_STUDIO then current else nil
	end
	for attempt = 1, 3 do
		local ok, v = pcall(function()
			return s:GetAsync(KEY)
		end)
		if ok then
			return true, sanitize(v)
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false, nil
end

-- Admin action (DevService checks too). Never errors; always reports the state it ended with.
function RarePetEventService.Activate(player: Player): ActivateResult
	if not RarePetEventService.IsAdmin(player) then
		return { ok = false, err = "Not allowed", Created = false, Event = RarePetEventService.Status() }
	end
	if current then
		return { ok = false, err = "This event was already started (it can't be restarted)", Created = false, Event = RarePetEventService.Status() }
	end
	if activating then
		return { ok = false, err = "Already starting, please wait...", Created = false, Event = RarePetEventService.Status() }
	end
	if IS_STUDIO then
		-- memory only: never the production DataStore
		local now = os.time()
		apply({ Id = E.Id, Start = now, End = now + E.Seconds }, true)
		return { ok = true, Created = true, Event = RarePetEventService.Status() }
	end
	local s = store
	if not s then
		return { ok = false, err = "Event storage unavailable on this server", Created = false, Event = RarePetEventService.Status() }
	end
	activating = true
	local now = os.time()
	local new: EventState = { Id = E.Id, Start = now, End = now + E.Seconds }
	local decision = "none" -- decided by the LAST transform call (the one that committed)
	local existing: EventState? = nil
	local ok, err = pcall(function()
		s:UpdateAsync(KEY, function(old: any)
			if old ~= nil then
				-- anything already saved for this Id (even an ended or unreadable state) = no write
				existing = sanitize(old)
				decision = if existing then "exists" else "bad"
				return nil
			end
			decision = "wrote"
			existing = nil
			return { Id = new.Id, Start = new.Start, End = new.End }
		end)
	end)
	local result: ActivateResult
	if ok and decision == "wrote" then
		apply(new, true)
		pcall(function()
			MessagingService:PublishAsync(E.Topic, new)
		end)
		result = { ok = true, Created = true, Event = RarePetEventService.Status() }
	elseif ok and decision == "exists" then
		apply(existing, true)
		result = { ok = false, err = "This event was already started (it can't be restarted)", Created = false, Event = RarePetEventService.Status() }
	else
		-- error or uncertain result: report what is really saved
		local readOk, st = load()
		if readOk then
			apply(st, true)
		end
		local why = if ok then "the saved event data is invalid" else tostring(err)
		if readOk and st then
			result = { ok = false, err = "Couldn't confirm the start (" .. why .. "). Saved state:", Created = false, Event = RarePetEventService.Status() }
			-- our write may have gone through before the error: tell the other servers anyway
			if st.Start == new.Start then
				pcall(function()
					MessagingService:PublishAsync(E.Topic, st)
				end)
			end
		elseif readOk then
			result = { ok = false, err = "Not started (" .. why .. "). Nothing was saved; try again.", Created = false, Event = RarePetEventService.Status() }
		else
			result = { ok = false, err = "Couldn't reach the event storage (" .. why .. "). State unknown; check again in a minute.", Created = false, Event = { State = "Checking" } }
		end
	end
	activating = false
	return result
end

--------------------------------------------------------------------------------
-- Rewards
--------------------------------------------------------------------------------
local function record(d: DataService.Data): DataService.EventPlay
	local ev = d.EventPlay[E.Id]
	if not ev then
		ev = { S = 0, G = false }
		d.EventPlay[E.Id] = ev
	end
	return ev
end

local function publishProgress(player: Player, ev: DataService.EventPlay)
	player:SetAttribute("RarePetPlay", ev.S)
	player:SetAttribute("RarePetGot", ev.G)
end

-- Grants the pet once per account when the play time is reached (also after the event ended).
local function tryGrant(player: Player, d: DataService.Data)
	local ev = d.EventPlay[E.Id]
	if not ev or ev.G or ev.S < E.RequiredSeconds then
		return
	end
	-- add + mark happen in one step (no yield), so the reward can never be given twice
	local uid = PetService.Add(d, E.Pet)
	if not uid then
		warn("[RarePetEvent] unknown reward pet " .. tostring(E.Pet))
		return
	end
	ev.G = true
	PetService.Refresh(player)
	DataService.Save(player)
	DataService.Changed(player)
	publishProgress(player, ev)
	local def = Config.Pets[E.Pet]
	Fx.To(player, "RarePetGranted", { Pet = E.Pet, Name = def and def.Name or E.Pet, Uid = uid })
end

local function isActive(player: Player, nowClock: number): boolean
	local t = track[player]
	if not t then
		t = {}
		track[player] = t
	end
	local root = Remotes.Root(player)
	if root then
		local pos = root.Position
		if t.Pos and (pos - (t.Pos :: Vector3)).Magnitude > MOVE_STUDS then
			t.Moved = nowClock
		end
		t.Pos = pos
	end
	local moved = t.Moved
	if moved and nowClock - moved <= E.IdleSeconds then
		return true
	end
	local acted = Remotes.LastAction(player)
	return acted ~= nil and nowClock - acted <= E.IdleSeconds
end

local function tick()
	local st = current
	local now = os.time()
	local nowClock = os.clock()
	for _, player in Players:GetPlayers() do
		local active = isActive(player, nowClock) -- keeps the movement tracker fresh
		local d = DataService.Get(player)
		if st and d and active then
			local credit = Rules.EventCredit(now, st.Start, st.End, E.TickSeconds)
			if credit > 0 then
				local ev = record(d)
				if not ev.G then
					ev.S += credit
					publishProgress(player, ev)
					tryGrant(player, d)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Studio test helper (DevService "RarePetAddMinutes"): adds play time, Studio only
--------------------------------------------------------------------------------
function RarePetEventService.StudioAddMinutes(player: Player, minutes: number): string?
	if not IS_STUDIO then
		return "Studio only"
	end
	if not RarePetEventService.Active() then
		return "Start the event first"
	end
	local d = DataService.Get(player)
	if not d then
		return "Loading..."
	end
	local ev = record(d)
	if ev.G then
		return "Already earned"
	end
	ev.S += math.clamp(math.floor(minutes), 1, 60) * 60
	publishProgress(player, ev)
	tryGrant(player, d)
	return nil
end

function RarePetEventService.Init()
	if not IS_STUDIO then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(E.DataStoreName)
		end)
		store = if ok then ds else nil
	end
	workspace:SetAttribute("RarePetChecked", false)
	DataService.AddDecorator(function(player, s)
		local d = DataService.Get(player)
		if d then
			s.EventPlay = d.EventPlay
		end
	end)
end

function RarePetEventService.Start()
	local function onLoaded(player: Player)
		local d = DataService.Get(player)
		if not d then
			return
		end
		local ev = d.EventPlay[E.Id]
		if ev then
			publishProgress(player, ev)
		end
		-- entitlement is kept even after the event ended
		tryGrant(player, d)
	end
	DataService.Loaded:Connect(function(player: Player, _data: any)
		onLoaded(player)
	end)
	local function added(player: Player)
		player:SetAttribute("RarePetAdmin", RarePetEventService.IsAdmin(player))
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
		onLoaded(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		track[player] = nil
	end)

	-- read the saved state (never starts anything by itself); keep retrying until known
	task.spawn(function()
		while true do
			local ok, st = load()
			if ok then
				apply(st, true)
			end
			task.wait(if ok then E.RefreshSeconds else 15)
		end
	end)
	if not IS_STUDIO then
		task.spawn(function()
			pcall(function()
				MessagingService:SubscribeAsync(E.Topic, function(msg)
					apply(sanitize(msg.Data), false)
				end)
			end)
		end)
	end
	task.spawn(function()
		while true do
			task.wait(E.TickSeconds)
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				warn("[RarePetEvent] tick failed: " .. tostring(err))
			end
		end
	end)
end

return RarePetEventService
