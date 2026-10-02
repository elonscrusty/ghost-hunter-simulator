--!strict
-- Fills the spawn TOP GHOST HUNTERS board: every RefreshSeconds it writes each online player's
-- all-time Ectoplasm to an OrderedDataStore and reads the top rows back. Without DataStore
-- access (Studio with API off) it ranks the players in this server instead.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

type Row = { Name: string, Value: number }

local store: OrderedDataStore? = nil
local names: { [number]: string } = {}
local MAX_VALUE = 2 ^ 53

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = if ok and type(name) == "string" then name else "Hunter"
	names[userId] = n
	return n
end

local function valueOf(player: Player): number?
	local d = DataService.Get(player)
	if not d then
		return nil
	end
	return math.clamp(math.floor(d.TotalEcto), 0, MAX_VALUE)
end

local function localRows(): { Row }
	local rows: { Row } = {}
	for _, pl in Players:GetPlayers() do
		local v = valueOf(pl)
		if v then
			table.insert(rows, { Name = pl.Name, Value = v })
		end
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.Value > b.Value
	end)
	return rows
end

local function globalRows(): { Row }?
	local s = store
	if not s then
		return nil
	end
	for _, pl in Players:GetPlayers() do
		local v = valueOf(pl)
		if v and v > 0 then
			names[pl.UserId] = pl.Name
			pcall(function()
				s:SetAsync(tostring(pl.UserId), v)
			end)
		end
	end
	local ok, pages = pcall(function()
		return s:GetSortedAsync(false, Config.Leaderboard.Rows)
	end)
	if not ok or not pages then
		return nil
	end
	local rows: { Row } = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(entry.key)
		if id then
			table.insert(rows, { Name = nameOf(id), Value = tonumber(entry.value) or 0 })
		end
	end
	return rows
end

local function render(rows: { Row })
	local map = workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild("Board", true)
	local gui = board and board:FindFirstChild("BoardGui")
	if not gui then
		return
	end
	for i = 1, Config.Leaderboard.Rows do
		local row = gui:FindFirstChild("Row" .. i)
		if row then
			local r = rows[i]
			local nameLabel = row:FindFirstChild("PlayerName") :: TextLabel?
			local valueLabel = row:FindFirstChild("Value") :: TextLabel?
			if nameLabel then
				-- VIP pass owners who are in this server show in gold with a crown
				local online = r and Players:FindFirstChild(r.Name)
				local vip = online ~= nil and online:IsA("Player") and online:GetAttribute("VIP") == true
				nameLabel.Text = if r then (if vip then "👑 " else "") .. r.Name else "..."
				nameLabel.TextColor3 = if vip then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(255, 255, 255)
			end
			if valueLabel then
				valueLabel.Text = if r then Format.Short(r.Value) else ""
			end
		end
	end
end

local function refresh()
	local rows = globalRows() or localRows()
	render(rows)
end

function LeaderboardService.Init()
	local ok, ds = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.DataStoreName)
	end)
	store = if ok then ds else nil
end

function LeaderboardService.Start()
	task.spawn(function()
		task.wait(8) -- let the first profiles load
		while true do
			local ok, err = pcall(function()
				refresh()
			end)
			if not ok then
				warn("[Leaderboard] " .. tostring(err))
				-- e.g. no API access in Studio: show this server's players
				pcall(function()
					render(localRows())
				end)
			end
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
