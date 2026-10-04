--!strict
-- Player profiles: load/save with retries, a per-session lock (prevents duplication when a
-- player hops or rejoins quickly), autosave, BindToClose and schema migration. Every other
-- service reads and writes data ONLY through DataService.Get(player) on the server.
--
-- Safety rules:
--  * a save only writes while OUR session holds the lock; otherwise it reports failure
--  * the save snapshot is a deep copy taken at save time (consistent even if the write retries)
--  * once a player is leaving, only the final releasing save runs
--  * a join waits for this server's in-flight leave-save of the same user
--  * the no-saving fallback exists only in Studio; live servers kick instead of using a blank profile
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Signal = require(GH.Signal)

local DataService = {}

export type HunterRecord = { Id: string, Locked: boolean?, T: number?, Tier: number? } -- Tier nil = Normal
export type PetRecord = { Id: string, T: number }
export type EventPlay = { S: number, G: boolean } -- active seconds counted, reward granted
export type Data = {
	Version: number,
	Ecto: number,
	TotalEcto: number,
	Hunters: { [string]: HunterRecord },
	NextUid: number,
	Equipped: { string },
	Discovered: { [string]: boolean },
	Zones: { [string]: boolean },
	Upgrades: { [string]: number },
	Daily: { Last: number, Streak: number },
	Boosts: { [string]: number }, -- boost id -> os.time expiry
	FreeCrates: { [string]: number },
	Settings: { Music: boolean, Sfx: boolean, FastReveal: boolean },
	Tutorial: number,
	Stats: { Ghosts: number, Crates: number, Events: number, Seconds: number },
	Purchases: { string }, -- recent receipt ids (ring buffer)
	SkipTokens: number, -- bought Single Crate Skips not used yet (added in 1.4; old saves get 0)
	LuckyOpens: { [string]: number }, -- crate id -> lucky opens left (added in 1.5; old saves get {})
	-- v1.6 (all optional for old saves: missing fields get these defaults, nothing else changes)
	Knocked: { [string]: number }, -- hunter uid -> os.time when it recovers (real time, counts offline)
	Shards: number, -- Spirit Shards (Boss Tower only)
	Pets: { [string]: PetRecord }, -- pet uid ("p1", "p2", ...) -> pet
	PetNextUid: number,
	EquippedPets: { string },
	TowerBest: number, -- personal best room cleared
	TowerRuns: number,
	TowerRooms: number, -- rooms cleared in total
	TowerShards: number, -- shards earned from the tower in total (reward record)
	EventPlay: { [string]: EventPlay }, -- event id -> progress
	TradesApplied: { string }, -- recent trade ids applied to this profile (exactly-once)
	Orphans: { [string]: any }, -- hunters whose id no longer exists in Config (kept, not used)
	Extra: { [string]: any }, -- unknown top-level keys from a newer/older version (kept as-is)
}

local IS_STUDIO = RunService:IsStudio()

local function defaults(): Data
	local d: Data = {
		Version = Config.DataSchemaVersion,
		Ecto = 0,
		TotalEcto = 0,
		Hunters = {},
		NextUid = 1,
		Equipped = {},
		Discovered = {},
		Zones = { [Config.Zones[1].Id] = true },
		Upgrades = {},
		Daily = { Last = 0, Streak = 0 },
		Boosts = {},
		FreeCrates = {},
		Settings = { Music = true, Sfx = true, FastReveal = false },
		Tutorial = 1,
		Stats = { Ghosts = 0, Crates = 0, Events = 0, Seconds = 0 },
		Purchases = {},
		SkipTokens = 0,
		LuckyOpens = {},
		Knocked = {},
		Shards = 0,
		Pets = {},
		PetNextUid = 1,
		EquippedPets = {},
		TowerBest = 0,
		TowerRuns = 0,
		TowerRooms = 0,
		TowerShards = 0,
		EventPlay = {},
		TradesApplied = {},
		Orphans = {},
		Extra = {},
	}
	for id in Config.Upgrades do
		d.Upgrades[id] = 1
	end
	return d
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- Fills missing fields (new features) and upgrades old schemas. Never deletes player data:
-- unknown keys go to Extra, hunters that no longer exist go to Orphans.
local function migrate(raw: any): Data
	local d = defaults()
	if type(raw) ~= "table" then
		return d
	end
	for k, v in raw do
		if k == "_lock" or k == "_seq" or k == "_sess" then
			continue
		end
		local cur = (d :: any)[k]
		if cur ~= nil then
			if type(v) == type(cur) and k ~= "Extra" then
				(d :: any)[k] = v
			end
		elseif type(k) == "string" then
			d.Extra[k] = v
		end
	end
	if type(raw.Extra) == "table" then
		for k, v in raw.Extra do
			if d.Extra[k] == nil and (d :: any)[k] == nil then
				d.Extra[k] = v
			elseif raw[k] == nil and k ~= "Extra" and type(v) == type((d :: any)[k]) then
				-- a field this version knows was parked in Extra by an older server (e.g. a
				-- player hopped to a not-yet-updated server): restore it instead of dropping it
				(d :: any)[k] = v
			end
		end
	end
	-- nested defaults
	local base = defaults()
	local settings = d.Settings :: any
	for k, v in base.Settings :: any do
		if type(settings[k]) ~= type(v) then
			settings[k] = v
		end
	end
	for k in settings do
		if (base.Settings :: any)[k] == nil then
			settings[k] = nil -- retired setting (e.g. the old free auto-target)
		end
	end
	for k, v in base.Stats do
		if type((d.Stats :: any)[k]) ~= "number" then
			(d.Stats :: any)[k] = v
		end
	end
	for k, v in base.Daily do
		if type((d.Daily :: any)[k]) ~= "number" then
			(d.Daily :: any)[k] = v
		end
	end
	for id in Config.Upgrades do
		local lv = d.Upgrades[id]
		d.Upgrades[id] = if type(lv) == "number" and lv == lv then math.clamp(math.floor(lv), 1, #Config.Upgrades[id].Levels) else 1
	end
	if type(d.Ecto) ~= "number" or d.Ecto ~= d.Ecto then
		d.Ecto = 0
	end
	if d.SkipTokens ~= d.SkipTokens or d.SkipTokens < 0 then
		d.SkipTokens = 0
	end
	d.SkipTokens = math.floor(d.SkipTokens)
	for id, n in d.LuckyOpens do
		if type(id) ~= "string" or type(n) ~= "number" or n ~= n or n < 1 then
			d.LuckyOpens[id] = nil
		else
			d.LuckyOpens[id] = math.min(math.floor(n), Config.LuckyOpens.MaxStack)
		end
	end
	local function num(v: any, lo: number): number
		return if type(v) == "number" and v == v and v < math.huge then math.max(lo, math.floor(v)) else lo
	end
	d.Shards = num(d.Shards, 0)
	d.TowerBest = num(d.TowerBest, 0)
	d.TowerRuns = num(d.TowerRuns, 0)
	d.TowerRooms = num(d.TowerRooms, 0)
	d.TowerShards = num(d.TowerShards, 0)
	if type(d.TotalEcto) ~= "number" or d.TotalEcto ~= d.TotalEcto then
		d.TotalEcto = 0
	end
	-- pets: unknown pet ids are kept (never deleted) but not equippable
	local maxPet = 0
	for uid, pet in d.Pets do
		if type(uid) ~= "string" or type(pet) ~= "table" or type(pet.Id) ~= "string" then
			d.Pets[uid] = nil
		else
			pet.T = num(pet.T, 0)
			local n = tonumber(string.match(uid, "^p(%d+)$"))
			if n and n > maxPet then
				maxPet = n
			end
		end
	end
	d.PetNextUid = math.max(num(d.PetNextUid, 1), maxPet + 1)
	local eqPets, seenPet = {}, {}
	for _, uid in d.EquippedPets do
		local pet = if type(uid) == "string" then d.Pets[uid] else nil
		if pet and Config.Pets[pet.Id] and not seenPet[uid] and #eqPets < Config.PetRules.MaxEquipped then
			seenPet[uid] = true
			table.insert(eqPets, uid)
		end
	end
	d.EquippedPets = eqPets
	for id, ev in d.EventPlay do
		if type(id) ~= "string" or type(ev) ~= "table" then
			d.EventPlay[id] = nil
		else
			ev.S = num(ev.S, 0)
			ev.G = ev.G == true
		end
	end
	local applied = {}
	for _, id in d.TradesApplied do
		if type(id) == "string" then
			table.insert(applied, id)
		end
	end
	while #applied > Config.Trade.AppliedMemory do
		table.remove(applied, 1)
	end
	d.TradesApplied = applied
	d.Zones[Config.Zones[1].Id] = true
	-- hunters whose definition was removed are parked in Orphans (restored if the id returns)
	for uid, h in d.Orphans do
		if type(h) == "table" and Config.Hunters[h.Id] and d.Hunters[uid] == nil then
			d.Hunters[uid] = h
			d.Orphans[uid] = nil
		end
	end
	for uid, h in d.Hunters do
		if type(h) ~= "table" or not Config.Hunters[h.Id] then
			d.Orphans[uid] = h
			d.Hunters[uid] = nil
		end
	end
	for _, h in d.Hunters do
		local t = h.Tier
		h.Tier = if type(t) == "number" and t == t then math.clamp(math.floor(t), 0, Config.Merge.MaxTier) else nil
		if h.Tier == 0 then
			h.Tier = nil
		end
		if h.Locked ~= nil and type(h.Locked) ~= "boolean" then
			h.Locked = false
		end
	end
	for uid, t in d.Knocked do
		if type(uid) ~= "string" or d.Hunters[uid] == nil or type(t) ~= "number" or t ~= t then
			d.Knocked[uid] = nil
		end
	end
	local eq = {}
	local seen = {}
	for _, uid in d.Equipped do
		if d.Hunters[uid] and not seen[uid] then
			seen[uid] = true
			table.insert(eq, uid)
		end
	end
	d.Equipped = eq
	-- uids must never be reused: NextUid stays above every existing numeric uid
	local maxUid = 0
	for _, list in { d.Hunters :: any, d.Orphans } do
		for uid in list do
			local n = tonumber(uid)
			if n and n > maxUid then
				maxUid = n
			end
		end
	end
	d.NextUid = math.max(math.floor(tonumber(d.NextUid) or 1), maxUid + 1)
	-- (future) if d.Version < 2 then ... end
	d.Version = Config.DataSchemaVersion
	return d
end

type Profile = {
	Data: Data,
	Key: string,
	Session: string,
	Loaded: boolean,
	Leaving: boolean,
	Saving: boolean,
	SyncQueued: boolean,
	JoinedAt: number,
	Seq: number, -- save counter: an older snapshot can never overwrite a newer one
}

local profiles: { [Player]: Profile } = {}
local leavingSaves: { [number]: boolean } = {} -- userId -> final save in flight on this server
local inflight = 0
local store: DataStore? = nil
local storeOk = false
local loadedSignal = Signal.new()
DataService.Loaded = loadedSignal -- (player, data) by reference

local syncRemote: RemoteEvent
local ectoRemote: RemoteEvent
-- Extra values other services add to the client snapshot (crew power, slots, ...).
local decorators: { (Player, any) -> () } = {}
-- run after a profile loads but BEFORE the player can act (may yield; e.g. trade recovery)
local loadHooks: { (Player, any) -> () } = {}
-- run just before the final save when a player leaves or the server closes (e.g. unpicked orbs)
local leaveHooks: { (Player, any) -> () } = {}

function DataService.AddLoadHook(fn: (Player, any) -> ())
	table.insert(loadHooks, fn)
end

function DataService.AddLeaveHook(fn: (Player, any) -> ())
	table.insert(leaveHooks, fn)
end

local function runHooks(list: { (Player, any) -> () }, player: Player, data: any)
	for _, fn in list do
		local ok, err = pcall(function()
			fn(player, data)
		end)
		if not ok then
			warn("[Data] hook failed: " .. tostring(err))
		end
	end
end

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local delayS = 1
	for attempt = 1, Config.Data.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[Data] %s failed (attempt %d): %s", label, attempt, tostring(result)))
		if attempt < Config.Data.Retries then
			task.wait(delayS)
			delayS = math.min(delayS * 2, 8)
		end
	end
	return false, nil
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function lockFresh(lock: any, session: string): boolean
	return type(lock) == "table" and lock.session ~= session and os.time() - (tonumber(lock.t) or 0) < Config.Data.SessionLockSeconds
end

-- Loads with a session lock. Returns data, or nil if the player should be kicked.
local function loadProfile(player: Player, p: Profile): Data?
	if not storeOk or not store then
		return if IS_STUDIO then migrate(nil) else nil
	end
	local ds = store :: DataStore
	local key = p.Key
	local corrupt = false
	for attempt = 1, 6 do
		local locked = false
		local ok, result = retry("load " .. key, function()
			return ds:UpdateAsync(key, function(old: any)
				if old ~= nil and type(old) ~= "table" then
					corrupt = true -- never overwrite a stored value we can't read
					return nil
				end
				old = if type(old) == "table" then old else {}
				if lockFresh(old._lock, p.Session) then
					locked = true
					return nil -- don't write
				end
				old._lock = { job = jobId(), session = p.Session, t = os.time() }
				return old
			end)
		end)
		if not ok or corrupt then
			if corrupt then
				warn("[Data] stored profile for " .. key .. " is not a table; refusing to load over it")
			end
			return nil
		end
		if not locked then
			return migrate(result)
		end
		-- Another session still holds the lock (player just hopped). Wait for it to save.
		task.wait(math.min(2 + attempt * 2, 8))
		if not player.Parent then
			return nil
		end
	end
	warn("[Data] session lock never released for " .. key .. "; taking over")
	local ok, result = retry("steal " .. key, function()
		return ds:UpdateAsync(key, function(old: any)
			if old ~= nil and type(old) ~= "table" then
				corrupt = true
				return nil
			end
			old = if type(old) == "table" then old else {}
			old._lock = { job = jobId(), session = p.Session, t = os.time() }
			return old
		end)
	end)
	return if ok and not corrupt then migrate(result) else nil
end

-- Writes the profile. Returns true only if the data really reached the DataStore.
local function saveP(p: Profile, release: boolean): boolean
	if not p.Loaded then
		return false
	end
	if not storeOk or not store then
		return IS_STUDIO -- Studio without API access: nothing to save
	end
	if p.Leaving and not release then
		return false -- only the final, releasing save runs for a leaving player
	end
	if p.Saving then
		-- wait for the running write; after that go ahead anyway: the save counter (_seq) makes
		-- sure an older snapshot can never land on top of a newer one, so the final save of a
		-- leaving player is never skipped just because an autosave was slow
		local t0 = os.clock()
		while p.Saving and os.clock() - t0 < 20 do
			task.wait(0.2)
		end
	end
	p.Saving = true
	inflight += 1
	local ds = store :: DataStore
	p.Data.Stats.Seconds += math.floor(os.clock() - p.JoinedAt)
	p.JoinedAt = os.clock()
	local snapshot = deepCopy(p.Data)
	p.Seq += 1
	local seq = p.Seq
	snapshot._seq = seq
	snapshot._sess = p.Session -- with _seq: our older snapshot never lands on our newer one,
	-- even after the final save released the lock
	local aborted = false
	local stale = false
	local ok = retry("save " .. p.Key, function()
		aborted = false
		stale = false
		return ds:UpdateAsync(p.Key, function(old: any)
			if type(old) == "table" and lockFresh(old._lock, p.Session) then
				-- another session owns this profile now: never overwrite its newer data
				aborted = true
				return nil
			end
			if type(old) == "table" and old._sess == p.Session and (tonumber(old._seq) or 0) > seq then
				stale = true -- our own NEWER snapshot is already stored
				return nil
			end
			snapshot._lock = if release then nil else { job = jobId(), session = p.Session, t = os.time() }
			return snapshot
		end)
	end)
	if ok and stale and release then
		-- the newer snapshot still holds our lock; release it without touching the data
		pcall(function()
			ds:UpdateAsync(p.Key, function(old: any)
				if type(old) == "table" and type(old._lock) == "table" and old._lock.session == p.Session then
					old._lock = nil
					return old
				end
				return nil
			end)
		end)
	end
	p.Saving = false
	inflight -= 1
	if ok and aborted then
		warn("[Data] save skipped for " .. p.Key .. ": another session owns the profile")
	end
	return ok and not aborted
end

local function saveProfile(player: Player, release: boolean): boolean
	local p = profiles[player]
	return if p then saveP(p, release) else false
end

function DataService.Get(player: Player): Data?
	local p = profiles[player]
	return if p and p.Loaded and not p.Leaving then p.Data else nil
end

-- DEV ONLY (DevService checks): wipes this player's progress back to a new profile, in place
-- (other services keep the same table). Keeps purchase receipts (so Robux products are never
-- granted twice), bought Crate Skips and settings. Game passes live on Roblox, not in the save.
function DataService.ResetProgress(player: Player): boolean
	local d = DataService.Get(player)
	if not d then
		return false
	end
	local keep = { Purchases = d.Purchases, Settings = d.Settings, SkipTokens = d.SkipTokens, TradesApplied = d.TradesApplied }
	local fresh = defaults()
	table.clear(d :: any)
	for k, v in fresh :: any do
		(d :: any)[k] = v
	end
	d.Purchases = keep.Purchases
	d.Settings = keep.Settings
	d.SkipTokens = keep.SkipTokens
	d.TradesApplied = keep.TradesApplied
	DataService.Changed(player)
	return true
end

-- Waits (up to timeout) for the player's data.
function DataService.WaitFor(player: Player, timeout: number?): Data?
	local t0 = os.clock()
	while player.Parent and os.clock() - t0 < (timeout or 30) do
		local d = DataService.Get(player)
		if d then
			return d
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.AddDecorator(fn: (Player, any) -> ())
	table.insert(decorators, fn)
end

local function snapshot(player: Player, d: Data): any
	local s = {
		Ecto = d.Ecto,
		Hunters = d.Hunters,
		Equipped = d.Equipped,
		Discovered = d.Discovered,
		Zones = d.Zones,
		Upgrades = d.Upgrades,
		Daily = d.Daily,
		Boosts = d.Boosts,
		FreeCrates = d.FreeCrates,
		LuckyOpens = d.LuckyOpens,
		SkipTokens = d.SkipTokens,
		TowerRuns = d.TowerRuns,
		TowerBest = d.TowerBest,
		Settings = d.Settings,
		Tutorial = d.Tutorial,
		Stats = d.Stats,
		ServerTime = os.time(),
	}
	for _, fn in decorators do
		local ok, err = pcall(function()
			fn(player, s)
		end)
		if not ok then
			warn("[Data] snapshot decorator failed: " .. tostring(err))
		end
	end
	return s
end

-- Sends the client a fresh snapshot (batched: many changes in one frame = one message).
function DataService.Changed(player: Player)
	local p = profiles[player]
	if not p or not p.Loaded or p.SyncQueued then
		return
	end
	p.SyncQueued = true
	task.defer(function()
		p.SyncQueued = false
		if player.Parent and profiles[player] == p and not p.Leaving then
			syncRemote:FireClient(player, snapshot(player, p.Data))
		end
	end)
end

-- Currency changes are frequent: send only the number.
function DataService.AddEcto(player: Player, amount: number)
	local p = profiles[player]
	if not p or not p.Loaded or p.Leaving or amount ~= amount or math.abs(amount) == math.huge then
		return
	end
	amount = math.floor(amount)
	p.Data.Ecto = math.max(0, p.Data.Ecto + amount)
	if amount > 0 then
		p.Data.TotalEcto += amount
	end
	ectoRemote:FireClient(player, p.Data.Ecto)
	player:SetAttribute("Ecto", p.Data.Ecto)
end

-- Spends Ectoplasm. Returns false if the player can't afford it.
function DataService.Spend(player: Player, amount: number): boolean
	local d = DataService.Get(player)
	if not d or amount ~= amount or amount < 0 or d.Ecto < amount then
		return false
	end
	DataService.AddEcto(player, -amount)
	return true
end

-- Next unique hunter id (never reuses an id that is already owned).
function DataService.NewUid(d: Data): string
	local uid = tostring(d.NextUid)
	while d.Hunters[uid] ~= nil or d.Orphans[uid] ~= nil do
		d.NextUid += 1
		uid = tostring(d.NextUid)
	end
	d.NextUid += 1
	return uid
end

function DataService.Save(player: Player)
	task.spawn(saveProfile, player, false)
end

-- Saves now and waits; used by ProcessReceipt. True only if the write really happened.
function DataService.SaveNow(player: Player): boolean
	return saveProfile(player, false)
end

function DataService.Init()
	syncRemote = Net.Event("Sync")
	ectoRemote = Net.Event("Ecto")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok and result then
		store = result
		if IS_STUDIO then
			-- Studio without "Enable Studio Access to API Services" errors on any request
			storeOk = pcall(function()
				(result :: DataStore):GetAsync("__probe")
			end)
		else
			storeOk = true -- live: per-player loads retry and kick on failure
		end
	end
	if not storeOk then
		warn(if IS_STUDIO
			then "[Data] DataStores unavailable in Studio (turn on API access). Progress will NOT be saved this test."
			else "[Data] DataStore unavailable: players will be asked to rejoin.")
	end
end

local function onPlayerAdded(player: Player)
	local p: Profile = {
		Data = defaults(),
		Key = keyFor(player),
		Session = HttpService:GenerateGUID(false),
		Loaded = false,
		Leaving = false,
		Saving = false,
		SyncQueued = false,
		JoinedAt = os.clock(),
		Seq = 0,
	}
	profiles[player] = p
	-- rejoined this same server while the previous session was still saving: wait for it
	local t0 = os.clock()
	while leavingSaves[player.UserId] and os.clock() - t0 < 30 do
		task.wait(0.2)
	end
	local data = loadProfile(player, p)
	if data and player.Parent and profiles[player] == p then
		runHooks(loadHooks, player, data) -- e.g. finish a trade that a crash interrupted
	end
	if not player.Parent or profiles[player] ~= p then
		-- left while loading: release OUR lock (only if it is still ours) without writing data
		if data and storeOk and store then
			local ds = store :: DataStore
			pcall(function()
				ds:UpdateAsync(p.Key, function(old: any)
					if type(old) == "table" and type(old._lock) == "table" and old._lock.session == p.Session then
						old._lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		if profiles[player] == p then
			profiles[player] = nil
		end
		return
	end
	if not data then
		profiles[player] = nil
		player:Kick("Couldn't load your Ghost Hunter data. Please rejoin in a moment - your progress is safe.")
		return
	end
	p.Data = data
	p.Loaded = true
	player:SetAttribute("Ecto", data.Ecto)
	loadedSignal:Fire(player, data)
	DataService.Changed(player)
end

local function onPlayerRemoving(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	if p.Loaded and not p.Leaving then
		runHooks(leaveHooks, player, p.Data) -- e.g. pay out orbs that weren't picked up
	end
	p.Leaving = true
	if p.Loaded then
		leavingSaves[player.UserId] = true
		local saved = saveP(p, true)
		if not saved and storeOk then
			-- keep trying in the background (the data is still in memory; the lock is still ours)
			task.spawn(function()
				for i = 1, 3 do
					task.wait(8 * i)
					if saveP(p, true) then
						break
					end
				end
				leavingSaves[player.UserId] = nil
			end)
		else
			leavingSaves[player.UserId] = nil
		end
	end
	if profiles[player] == p then
		profiles[player] = nil
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, pl in Players:GetPlayers() do
		task.spawn(onPlayerAdded, pl)
	end
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for player, p in profiles do
				if p.Loaded and not p.Leaving then
					task.spawn(saveProfile, player, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		if not storeOk then
			return
		end
		for player, p in profiles do
			if p.Loaded and not p.Leaving then
				runHooks(leaveHooks, player, p.Data)
				p.Leaving = true
				task.spawn(saveP, p, true)
			end
		end
		task.wait() -- let the saves start
		local t0 = os.clock()
		while inflight > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

-- Records a processed receipt id so a purchase is never granted twice.
function DataService.HasPurchase(d: Data, receipt: string): boolean
	return table.find(d.Purchases, receipt) ~= nil
end

function DataService.AddPurchase(d: Data, receipt: string)
	table.insert(d.Purchases, receipt)
	while #d.Purchases > 100 do
		table.remove(d.Purchases, 1)
	end
end

-- exposed for the save-compatibility test (tools/datacompat.sh); not used by the game
DataService._Migrate = migrate

return DataService
