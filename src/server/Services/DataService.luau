--!strict
-- Player profiles: load/save with retries, a session lock (prevents duplication when a player
-- hops servers quickly), autosave, BindToClose and schema migration. Every other service reads
-- and writes data ONLY through DataService.Get(player) on the server.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)

local DataService = {}

export type HunterRecord = { Id: string, Locked: boolean?, T: number? }
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
	Settings: { Music: boolean, Sfx: boolean, FastReveal: boolean, AutoTarget: boolean },
	Tutorial: number,
	Stats: { Ghosts: number, Crates: number, Events: number, Seconds: number },
	Purchases: { string }, -- recent receipt ids (ring buffer)
}

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
		Settings = { Music = true, Sfx = true, FastReveal = false, AutoTarget = true },
		Tutorial = 1,
		Stats = { Ghosts = 0, Crates = 0, Events = 0, Seconds = 0 },
		Purchases = {},
	}
	for id in Config.Upgrades do
		d.Upgrades[id] = 1
	end
	return d
end

-- Fills missing fields (new features) and upgrades old schemas. Never drops player progress.
local function migrate(raw: any): Data
	local d = defaults()
	if type(raw) ~= "table" then
		return d
	end
	for k, v in raw do
		if (d :: any)[k] ~= nil and type(v) == type((d :: any)[k]) then
			(d :: any)[k] = v
		end
	end
	-- nested defaults
	local base = defaults()
	for k, v in base.Settings do
		if type((d.Settings :: any)[k]) ~= type(v) then
			(d.Settings :: any)[k] = v
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
		d.Upgrades[id] = if type(lv) == "number" then math.clamp(math.floor(lv), 1, #Config.Upgrades[id].Levels) else 1
	end
	d.Zones[Config.Zones[1].Id] = true
	-- drop hunters whose definition was removed, and equipped uids that no longer exist
	for uid, h in d.Hunters do
		if type(h) ~= "table" or not Config.Hunters[h.Id] then
			d.Hunters[uid] = nil
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
	-- (future) if d.Version < 2 then ... end
	d.Version = Config.DataSchemaVersion
	return d
end

type Profile = {
	Data: Data,
	Key: string,
	Loaded: boolean,
	Dirty: boolean,
	Saving: boolean,
	SyncQueued: boolean,
	JoinedAt: number,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local storeOk = false
local loadedSignal = Instance.new("BindableEvent")
DataService.Loaded = loadedSignal.Event -- (player, data)

local syncRemote: RemoteEvent
local ectoRemote: RemoteEvent
-- Extra values other services add to the client snapshot (crew power, slots, ...).
local decorators: { (Player, any) -> () } = {}

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

-- Loads with a session lock. Returns data, or nil if the player should be kicked.
local function loadProfile(player: Player): Data?
	if not storeOk or not store then
		return migrate(nil)
	end
	local ds = store :: DataStore
	local key = keyFor(player)
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	for attempt = 1, 6 do
		local locked = false
		local ok, result = retry("load " .. key, function()
			return ds:UpdateAsync(key, function(old: any)
				old = if type(old) == "table" then old else {}
				local lock = old._lock
				if type(lock) == "table" and lock.job ~= jobId and os.time() - (lock.t or 0) < Config.Data.SessionLockSeconds then
					locked = true
					return nil -- don't write
				end
				old._lock = { job = jobId, t = os.time() }
				return old
			end)
		end)
		if not ok then
			return nil
		end
		if not locked then
			return migrate(result)
		end
		-- Another server still holds the lock (player just hopped). Wait for it to save.
		task.wait(math.min(2 + attempt * 2, 8))
		if not player.Parent then
			return nil
		end
	end
	warn("[Data] session lock never released for " .. key .. "; taking over")
	local ok, result = retry("steal " .. key, function()
		return ds:UpdateAsync(key, function(old: any)
			old = if type(old) == "table" then old else {}
			old._lock = { job = jobId, t = os.time() }
			return old
		end)
	end)
	return if ok then migrate(result) else nil
end

local function saveProfile(player: Player, release: boolean): boolean
	local p = profiles[player]
	if not p or not p.Loaded or not storeOk or not store then
		return true
	end
	if p.Saving then
		-- wait for the in-flight save, then save again so the latest state is written
		local t0 = os.clock()
		while p.Saving and os.clock() - t0 < 20 do
			task.wait(0.2)
		end
	end
	p.Saving = true
	local ds = store :: DataStore
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	p.Data.Stats.Seconds += math.floor(os.clock() - p.JoinedAt)
	p.JoinedAt = os.clock()
	local snapshot = table.clone(p.Data) :: any
	local ok = retry("save " .. p.Key, function()
		return ds:UpdateAsync(p.Key, function(old: any)
			if type(old) == "table" and type(old._lock) == "table" and old._lock.job ~= jobId then
				-- another server took the session over: never overwrite its newer data
				return nil
			end
			snapshot._lock = if release then nil else { job = jobId, t = os.time() }
			return snapshot
		end)
	end)
	p.Saving = false
	if ok then
		p.Dirty = false
	end
	return ok
end

function DataService.Get(player: Player): Data?
	local p = profiles[player]
	return if p and p.Loaded then p.Data else nil
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
		Settings = d.Settings,
		Tutorial = d.Tutorial,
		Stats = d.Stats,
		ServerTime = os.time(),
	}
	for _, fn in decorators do
		fn(player, s)
	end
	return s
end

-- Marks data changed and sends the client a fresh snapshot (batched per frame).
function DataService.Changed(player: Player)
	local p = profiles[player]
	if not p or not p.Loaded then
		return
	end
	p.Dirty = true
	if p.SyncQueued then
		return
	end
	p.SyncQueued = true
	task.defer(function()
		p.SyncQueued = false
		if player.Parent and profiles[player] == p then
			syncRemote:FireClient(player, snapshot(player, p.Data))
		end
	end)
end

-- Currency changes are frequent: send only the number.
function DataService.AddEcto(player: Player, amount: number)
	local p = profiles[player]
	if not p or not p.Loaded or amount ~= amount then
		return
	end
	amount = math.floor(amount)
	p.Data.Ecto = math.max(0, p.Data.Ecto + amount)
	if amount > 0 then
		p.Data.TotalEcto += amount
	end
	p.Dirty = true
	ectoRemote:FireClient(player, p.Data.Ecto)
	player:SetAttribute("Ecto", p.Data.Ecto)
end

-- Atomically spends Ectoplasm. Returns false if the player can't afford it.
function DataService.Spend(player: Player, amount: number): boolean
	local d = DataService.Get(player)
	if not d or amount < 0 or d.Ecto < amount then
		return false
	end
	DataService.AddEcto(player, -amount)
	return true
end

function DataService.NewUid(d: Data): string
	local uid = tostring(d.NextUid)
	d.NextUid += 1
	return uid
end

function DataService.Save(player: Player)
	task.spawn(saveProfile, player, false)
end

function DataService.Init()
	syncRemote = Net.Event("Sync")
	ectoRemote = Net.Event("Ecto")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok and result then
		store = result
		-- In Studio without "Enable Studio Access to API Services" this read errors.
		local probe = pcall(function()
			(result :: DataStore):GetAsync("__probe")
		end)
		storeOk = probe
	end
	if not storeOk then
		warn("[Data] DataStores unavailable (Studio without API access?). Progress will NOT be saved this session.")
	end
end

local function onPlayerAdded(player: Player)
	local p: Profile = {
		Data = defaults(),
		Key = keyFor(player),
		Loaded = false,
		Dirty = false,
		Saving = false,
		SyncQueued = false,
		JoinedAt = os.clock(),
	}
	profiles[player] = p
	local data = loadProfile(player)
	if not player.Parent then
		-- left while loading: release our lock without overwriting data
		if data and storeOk and store then
			local ds = store :: DataStore
			pcall(function()
				ds:UpdateAsync(p.Key, function(old: any)
					if type(old) == "table" then
						old._lock = nil
					end
					return old
				end)
			end)
		end
		profiles[player] = nil
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
	if p.Loaded then
		saveProfile(player, true)
	end
	profiles[player] = nil
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
				if p.Loaded then
					task.spawn(saveProfile, player, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not storeOk then
			return
		end
		local pending = 0
		for player, p in profiles do
			if p.Loaded then
				pending += 1
				task.spawn(function()
					saveProfile(player, true)
					pending -= 1
				end)
			end
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
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

-- Saves now and waits; used by ProcessReceipt.
function DataService.SaveNow(player: Player): boolean
	return saveProfile(player, false)
end

DataService._GenerateId = function(): string
	return HttpService:GenerateGUID(false)
end

return DataService
