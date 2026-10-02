--!strict
-- Client mirror of the server snapshot (read-only; the server is the authority), the request
-- helper, and the single Fx dispatcher.
--
-- Why one dispatcher: a RemoteEvent that arrives before anything listens is queued and then
-- delivered only to the FIRST connection. State connects to every remote as the very first
-- client code, and buffers Fx messages per kind until a controller subscribes (e.g. a player
-- joining mid-event still gets the boss UI).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GH = ReplicatedStorage:WaitForChild("GH")
local Net = require(GH.Net)
local Signal = require(GH.Signal)

local State = {}

State.Data = nil :: any -- latest snapshot (see DataService.snapshot on the server)
State.Ecto = 0
local changed = Signal.new()
local ectoChanged = Signal.new()
State.Changed = changed -- (data)
State.EctoChanged = ectoChanged -- (new, old); not fired for the first snapshot

-- os.time() on the server minus the client's, so countdowns use server time.
State.ClockOffset = 0

local request: RemoteFunction? = nil

type FxHandler = (any) -> ()
local fxHandlers: { [string]: { FxHandler } } = {}
local fxBuffer: { [string]: { any } } = {}

local function dispatchFx(kind: string, data: any)
	local list = fxHandlers[kind]
	if list and #list > 0 then
		for _, fn in list do
			task.spawn(fn, data)
		end
	else
		-- nobody listening yet: keep the latest few for the first subscriber
		local buf = fxBuffer[kind]
		if not buf then
			buf = {}
			fxBuffer[kind] = buf
		end
		table.insert(buf, data)
		if #buf > 8 then
			table.remove(buf, 1)
		end
	end
end

-- Subscribe to one Fx kind ("Poof", "Toast", "Announce", "ZoneUnlocked", "Boss", ...).
function State.OnFx(kind: string, fn: FxHandler)
	local list = fxHandlers[kind]
	if not list then
		list = {}
		fxHandlers[kind] = list
	end
	table.insert(list, fn)
	local buf = fxBuffer[kind]
	if buf then
		fxBuffer[kind] = nil
		for _, data in buf do
			task.spawn(fn, data)
		end
	end
end

-- Like State.Changed:Connect, but also runs right away if a snapshot already arrived.
function State.OnData(fn: (any) -> ())
	changed:Connect(fn)
	if State.Data then
		task.spawn(fn, State.Data)
	end
end

function State.Init()
	request = Net.Function("Request")
	Net.Event("Sync").OnClientEvent:Connect(function(data: any)
		State.ClockOffset = (data.ServerTime or os.time()) - os.time()
		local first = State.Data == nil
		State.Data = data
		local old = State.Ecto
		State.Ecto = data.Ecto
		changed:Fire(data)
		if not first and old ~= data.Ecto then
			ectoChanged:Fire(data.Ecto, old)
		end
	end)
	Net.Event("Ecto").OnClientEvent:Connect(function(value: number)
		local old = State.Ecto
		State.Ecto = value
		if State.Data then
			State.Data.Ecto = value
		end
		ectoChanged:Fire(value, old)
	end)
	Net.Event("Fx").OnClientEvent:Connect(function(kind: any, data: any)
		if type(kind) == "string" then
			dispatchFx(kind, data)
		end
	end)
end

function State.Now(): number
	return os.time() + State.ClockOffset
end

-- Calls a server action; returns the response table (never errors).
function State.Request(action: string, ...: any): any
	local rf = request
	if not rf then
		return { ok = false, err = "Loading..." }
	end
	local args = table.pack(...)
	local ok, res = pcall(function()
		return rf:InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	if not ok or type(res) ~= "table" then
		return { ok = false, err = "Connection hiccup, try again" }
	end
	return res
end

function State.WaitForData(): any
	while not State.Data do
		changed:Wait()
	end
	return State.Data
end

function State.CountOwned(): number
	local n = 0
	if State.Data then
		for _ in State.Data.Hunters do
			n += 1
		end
	end
	return n
end

return State
