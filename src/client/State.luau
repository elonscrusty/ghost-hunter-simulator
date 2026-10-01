--!strict
-- Client mirror of the server snapshot (read-only; the server is the authority).
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
State.EctoChanged = ectoChanged -- (new, old)

-- os.time() on the server minus the client's, so countdowns use server time.
State.ClockOffset = 0

local request: RemoteFunction? = nil

function State.Init()
	request = Net.Function("Request")
	Net.Event("Sync").OnClientEvent:Connect(function(data: any)
		State.ClockOffset = (data.ServerTime or os.time()) - os.time()
		State.Data = data
		local old = State.Ecto
		State.Ecto = data.Ecto
		changed:Fire(data)
		if old ~= data.Ecto then
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
