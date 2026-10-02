--!strict
-- Developer-controlled GLOBAL events (currently: 2X ECTOPLASM). Never automatic: the state is
-- OFF unless a developer turns it on from the DEV panel, and it stays whatever was last set.
--   * state is stored in a DataStore (Config.GlobalEvents) so NEW servers read it at start
--   * a change is broadcast with MessagingService so RUNNING servers update within seconds
--   * every server also re-reads the DataStore every RefreshSeconds (a missed message heals)
--   * clients see workspace attribute "Ecto2x" (indicator) and get an "Ecto2xEvent" message
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

type State = { Ecto2x: boolean, T: number }

local G = Config.GlobalEvents
local IS_STUDIO = RunService:IsStudio()
local store: DataStore? = nil
local current: State = { Ecto2x = false, T = 0 }

local function sanitize(v: any): State
	if type(v) == "table" then
		return { Ecto2x = v.Ecto2x == true, T = if type(v.T) == "number" then v.T else 0 }
	end
	return { Ecto2x = false, T = 0 }
end

-- Applies a state in this server (idempotent; older states are ignored).
local function apply(new: State, announce: boolean)
	if new.T < current.T then
		return
	end
	local was = current.Ecto2x
	current = new
	PlayerInfo.SetGlobalEctoMultiplier(if new.Ecto2x then G.Ecto2xMultiplier else 1)
	workspace:SetAttribute("Ecto2x", new.Ecto2x)
	if was ~= new.Ecto2x then
		for _, p in Players:GetPlayers() do
			DataService.Changed(p) -- refresh the multiplier shown in their HUD
		end
		if announce then
			Fx.All("Ecto2xEvent", { On = new.Ecto2x })
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
	return current.Ecto2x
end

-- Developer action (DevService checks the player first). Returns an error text or nil.
function GlobalEventService.SetEcto2x(on: boolean): string?
	local new: State = { Ecto2x = on, T = os.time() }
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
