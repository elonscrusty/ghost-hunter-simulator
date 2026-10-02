--!strict
-- Developer-controlled GLOBAL events (currently: 2X ECTOPLASM). Never automatic: the state is
-- OFF unless a developer turns it on from the DEV panel, and it stays whatever was last set.
--   * state is stored in a DataStore (Config.GlobalEvents) so NEW servers read it at start
--   * a change is broadcast with MessagingService so RUNNING servers update within seconds
--   * every server also re-reads the DataStore every RefreshSeconds (a missed message heals)
--   * clients see workspace attribute "Ecto2x" (indicator) and get an "Ecto2xEvent" message
--   * an event can have an end time (Ends, unix seconds; 0 = until turned off). Every server
--     switches itself OFF when it passes, so a timed event needs no further action
-- Only DevService (server-checked developer UserIds) can change it. In Studio changes stay in
-- the test server, so a Studio test can never switch the event on for live players.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local Fx = require(script.Parent.Fx)

local GlobalEventService = {}

type State = { Ecto2x: boolean, T: number, Ends: number }

local G = Config.GlobalEvents
local IS_STUDIO = RunService:IsStudio()
local store: DataStore? = nil
local current: State = { Ecto2x = false, T = 0, Ends = 0 }

local function sanitize(v: any): State
	if type(v) == "table" then
		return {
			Ecto2x = v.Ecto2x == true,
			T = if type(v.T) == "number" then v.T else 0,
			Ends = if type(v.Ends) == "number" then v.Ends else 0,
		}
	end
	return { Ecto2x = false, T = 0, Ends = 0 }
end

local function active(st: State): boolean
	return st.Ecto2x and (st.Ends <= 0 or os.time() < st.Ends)
end

local shownOn = false -- what this server currently applies (saved state + end time)

-- Applies a state in this server (idempotent; older states are ignored).
local function apply(new: State, announce: boolean)
	if new.T < current.T then
		return
	end
	current = new
	local on = active(new)
	local was = shownOn
	shownOn = on
	PlayerInfo.SetGlobalEctoMultiplier(if on then G.Ecto2xMultiplier else 1)
	workspace:SetAttribute("Ecto2x", on)
	workspace:SetAttribute("Ecto2xEnds", if on then new.Ends else 0)
	if was ~= on then
		for _, p in Players:GetPlayers() do
			DataService.Changed(p) -- refresh the multiplier shown in their HUD
		end
		if announce then
			Fx.All("Ecto2xEvent", { On = on })
		end
	end
end

local function load(): State?
	local s = store
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:GetAsync(G.Key)
	end)
	return if ok then sanitize(v) else nil
end

function GlobalEventService.Ecto2x(): boolean
	return shownOn
end

-- Developer action (DevService checks the player first). `seconds` > 0 makes a timed event
-- that ends by itself on every server. Returns an error text or nil.
function GlobalEventService.SetEcto2x(on: boolean, seconds: number?): string?
	local now = os.time()
	local ends = if on and seconds and seconds > 0 then now + math.floor(seconds) else 0
	local new: State = { Ecto2x = on, T = now, Ends = ends }
	if IS_STUDIO or not store then
		apply(new, true)
		return nil
	end
	local s = store :: DataStore
	local ok, err = pcall(function()
		-- the stamp always grows past the saved one (and this server's), so servers whose clocks
		-- differ by a few seconds never ignore a quick ON -> OFF as "older"
		s:UpdateAsync(G.Key, function(old: any)
			new.T = math.max(new.T, sanitize(old).T + 1, current.T + 1)
			return new
		end)
	end)
	if not ok then
		return "Couldn't save the event state: " .. tostring(err)
	end
	apply(new, true)
	pcall(function()
		MessagingService:PublishAsync(G.Topic, new)
	end)
	return nil
end

function GlobalEventService.Init()
	if not IS_STUDIO then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(G.DataStoreName)
		end)
		store = if ok then ds else nil
	end
	workspace:SetAttribute("Ecto2x", false)
end

function GlobalEventService.Start()
	-- new server: read the saved state (missing = OFF; nothing ever turns it on by itself)
	task.spawn(function()
		local s = load()
		if s then
			apply(s, false)
		end
	end)
	-- timed events: switch OFF locally once the end time passes (the saved state stays as is;
	-- every server and every new server reaches the same answer from Ends)
	task.spawn(function()
		while true do
			task.wait(5)
			if shownOn and not active(current) then
				apply(current, true)
			end
		end
	end)
	if not IS_STUDIO then
		pcall(function()
			MessagingService:SubscribeAsync(G.Topic, function(msg)
				apply(sanitize(msg.Data), true)
			end)
		end)
		task.spawn(function()
			while true do
				task.wait(G.RefreshSeconds)
				local s = load()
				if s then
					apply(s, true)
				end
			end
		end)
	end
end

return GlobalEventService
