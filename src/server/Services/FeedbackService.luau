--!strict
-- Player feedback (bug reports + ideas). Players send short text from the FEEDBACK panel; it is
-- run through Roblox's text filter and kept in a DataStore inbox (one key per day, newest first,
-- capped) that only developers can read from the DEV panel. Cooldown + per-server cap + a
-- durable per-day cap (counted in that day's inbox) stop spam. Studio keeps feedback in memory.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)
local DevService = require(script.Parent.DevService)
local Remotes = require(script.Parent.Remotes)

local FeedbackService = {}

export type Entry = { T: number, UserId: number, Name: string, Kind: string, Text: string, Zone: string, Version: string }

local KEY = "Inbox" -- day shards are "Inbox_<day>"; "Inbox" itself is the old single inbox
local DAY = 86400
local store: DataStore? = nil
local memory: { Entry } = {} -- Studio without API access: keep this session's feedback here
local lastSent: { [Player]: number } = {}
local sentCount: { [Player]: number } = {}

local zoneRanges: { { number } } = {}
for _, z in Config.Zones do
	table.insert(zoneRanges, { z.MinZ, z.MaxZ })
end

local function zoneOf(player: Player): string
	local root = Remotes.Root(player)
	if not root then
		return "?"
	end
	local z = Config.Zones[Rules.ZoneIndexAt(root.Position.Z, zoneRanges)]
	return if z then z.Id else "?"
end

local function filter(player: Player, text: string): string?
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(text, player.UserId)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return result
	end
	-- the filter is unavailable in some Studio setups; never store unfiltered text live
	return if RunService:IsStudio() then text else nil
end

local function day(t: number): number
	return math.floor(t / DAY)
end

-- messages this user already sent on the entry's day
local function countToday(list: { any }, entry: Entry): number
	local n = 0
	for _, e in list do
		if type(e) == "table" and e.UserId == entry.UserId and type(e.T) == "number" and day(e.T) == day(entry.T) then
			n += 1
		end
	end
	return n
end

-- Returns (saved, over the daily cap).
local function save(entry: Entry): (boolean, boolean)
	local s = store
	if not s then
		if countToday(memory, entry) >= Config.Feedback.PerServer then
			return false, true
		end
		table.insert(memory, 1, entry)
		return true, false
	end
	local full = false
	local ok = pcall(function()
		s:UpdateAsync(KEY .. "_" .. day(entry.T), function(old: any)
			local list = if type(old) == "table" then old else {}
			full = countToday(list, entry) >= Config.Feedback.PerServer
			if full then
				return nil -- don't write
			end
			table.insert(list, 1, entry)
			while #list > Config.Feedback.InboxSize do
				table.remove(list)
			end
			return list
		end)
	end)
	return ok and not full, ok and full
end

-- Newest first: today's shard, the days before, then the old single inbox.
local function load(): { Entry }
	local s = store
	if not s then
		return memory
	end
	local out: { Entry } = {}
	local today = day(os.time())
	for i = 0, 7 do
		local key = if i < 7 then KEY .. "_" .. (today - i) else KEY
		local ok, list = pcall(function()
			return s:GetAsync(key)
		end)
		if ok and type(list) == "table" then
			for _, e in list do
				table.insert(out, e)
			end
		end
		if #out >= 60 then
			break
		end
	end
	return out
end

function FeedbackService.Init()
	if not RunService:IsStudio() then -- Studio: memory only, never the live inbox
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(Config.Feedback.DataStoreName)
		end)
		store = if ok then ds else nil
	end

	Remotes.Register("Feedback", "Default", function(player, kind, text)
		local fb = Config.Feedback
		if kind ~= "Bug" and kind ~= "Idea" then
			return Remotes.Fail("Pick BUG or IDEA")
		end
		if type(text) ~= "string" then
			return Remotes.Fail("Write something first")
		end
		if #text > fb.MaxLength * 4 then
			return Remotes.Fail("That's too long") -- don't run pattern work on huge strings
		end
		local clean = text:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
		if #clean < fb.MinLength then
			return Remotes.Fail("Tell us a bit more (" .. fb.MinLength .. "+ letters)")
		end
		if #clean > fb.MaxLength then
			clean = clean:sub(1, fb.MaxLength)
		end
		local now = os.clock()
		if now - (lastSent[player] or -math.huge) < fb.Cooldown then
			return Remotes.Fail("Thanks! Wait a minute before sending more.")
		end
		if (sentCount[player] or 0) >= fb.PerServer then
			return Remotes.Fail("Thanks! You've sent a lot already today.")
		end
		lastSent[player] = now
		local filtered = filter(player, clean)
		if not filtered then
			return Remotes.Fail("Couldn't send right now, try again later")
		end
		local entry: Entry = {
			T = os.time(),
			UserId = player.UserId,
			Name = player.Name,
			Kind = kind,
			Text = filtered,
			Zone = zoneOf(player),
			Version = Config.Version,
		}
		local saved, full = save(entry)
		if not player.Parent then
			lastSent[player] = nil -- left while the filter/save yielded: don't keep their entries
			return { ok = saved }
		end
		if full then
			sentCount[player] = fb.PerServer
			return Remotes.Fail("Thanks! You've sent a lot already today.")
		end
		if not saved then
			lastSent[player] = nil
			return Remotes.Fail("Couldn't send right now, try again later")
		end
		sentCount[player] = (sentCount[player] or 0) + 1
		return { ok = true }
	end)

	-- developers read the inbox from the DEV panel
	Remotes.Register("FeedbackInbox", "Default", function(player)
		if not DevService.IsDev(player) then
			return Remotes.Fail("Not allowed")
		end
		local list = load()
		local out = {}
		for i = 1, math.min(#list, 60) do
			table.insert(out, list[i])
		end
		return { ok = true, Entries = out }
	end)
end

function FeedbackService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
		sentCount[player] = nil
	end)
	local _ = DataService
end

return FeedbackService
