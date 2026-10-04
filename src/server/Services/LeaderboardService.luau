--!strict
-- Fills the two lobby boards every RefreshSeconds:
--   TOP GHOST HUNTERS: each online player's all-time Ectoplasm (current value) in
--     Config.Leaderboard.DataStoreName.
--   TOP POWER: each player's best-ever crew power (HunterService.CrewPower) in
--     Config.Leaderboard.PowerDataStoreName; written with UpdateAsync only when it rises above
--     the stored best, so the entry never goes down.
-- Then the top rows are read back. Without DataStore access (Studio with API off) a board ranks
-- the players in this server instead. Studio never writes, and developer accounts stay off the
-- public boards.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local DataService = require(script.Parent.DataService)
local HunterService = require(script.Parent.HunterService)

local LeaderboardService = {}

type Row = { Name: string, Value: number }

local store: OrderedDataStore? = nil
local powerStore: OrderedDataStore? = nil
local names: { [number]: string } = {}
local written: { [number]: number } = {} -- userId -> value this server last wrote
local bestPower: { [number]: number } = {} -- userId -> best power known to be stored
local MAX_VALUE = 2 ^ 53
local IS_STUDIO = RunService:IsStudio()

local function isDev(userId: number): boolean
	return table.find(Config.DevUserIds, userId) ~= nil
end

local function canWrite(userId: number): boolean
	return not IS_STUDIO and userId > 0 and not isDev(userId)
end

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

local function powerOf(player: Player): number?
	if not DataService.Get(player) then
		return nil
	end
	local p = HunterService.CrewPower(player)
	if p ~= p then
		return 0
	end
	return math.clamp(math.floor(p), 0, MAX_VALUE)
end

local function localRows(get: (Player) -> number?): { Row }
	local rows: { Row } = {}
	for _, pl in Players:GetPlayers() do
		local v = get(pl)
		if v then
			table.insert(rows, { Name = pl.Name, Value = v })
		end
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.Value > b.Value
	end)
	return rows
end

local readTop: (OrderedDataStore) -> { Row }?

local function globalRows(): { Row }?
	local s = store
	if not s then
		return nil
	end
	for _, pl in Players:GetPlayers() do
		local id = pl.UserId
		local v = valueOf(pl)
		-- the current value (not the best): after a progress reset the entry goes down too
		if v and canWrite(id) and v ~= written[id] and (v > 0 or written[id] ~= nil) then
			names[id] = pl.Name
			if pcall(function()
				s:SetAsync(tostring(id), v)
			end) then
				written[id] = v
			end
		end
	end
	return readTop(s)
end

-- Best-ever power: UpdateAsync keeps the larger of the stored and current values, and is only
-- called when the current power beats the best this server knows about.
local function globalPowerRows(): { Row }?
	local s = powerStore
	if not s then
		return nil
	end
	for _, pl in Players:GetPlayers() do
		local id = pl.UserId
		local v = powerOf(pl)
		if v and v > 0 and canWrite(id) and v > (bestPower[id] or 0) then
			names[id] = pl.Name
			-- returning nil cancels the write, so the stored best never goes down
			local keep: any = function(old: any): number?
				local prev = tonumber(old) or 0
				return if v > prev then v else nil
			end
			local ok, stored = pcall(function(): any
				return s:UpdateAsync(tostring(id), keep)
			end)
			if ok then
				bestPower[id] = math.max(v, tonumber(stored) or 0)
			end
		end
	end
	return readTop(s)
end

function readTop(s: OrderedDataStore): { Row }?
	local ok, pages = pcall(function()
		return s:GetSortedAsync(false, Config.Leaderboard.Rows + #Config.DevUserIds)
	end)
	if not ok or not pages then
		return nil
	end
	local rows: { Row } = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(entry.key)
		if id and not isDev(id) and #rows < Config.Leaderboard.Rows then
			table.insert(rows, { Name = nameOf(id), Value = tonumber(entry.value) or 0 })
		end
	end
	return rows
end

local function render(modelName: string, rows: { Row })
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Leaderboard")
	local model = folder and folder:FindFirstChild(modelName)
	local board = model and model:FindFirstChild("Board")
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

-- One board per pcall, so a DataStore error on one never blanks the other.
local function refreshBoard(modelName: string, global: () -> { Row }?, get: (Player) -> number?)
	local ok, err = pcall(function()
		render(modelName, global() or localRows(get))
	end)
	if not ok then
		warn("[Leaderboard] " .. modelName .. ": " .. tostring(err))
		-- e.g. no API access in Studio: show this server's players
		pcall(function()
			render(modelName, localRows(get))
		end)
	end
end

function LeaderboardService.Init()
	local ok, ds = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.DataStoreName)
	end)
	store = if ok then ds else nil
	local okP, dsP = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.PowerDataStoreName)
	end)
	powerStore = if okP then dsP else nil
	-- a progress reset removes the entry right away (the next refresh writes the new value)
	DataService.ProgressReset:Connect(function(player: Player)
		local s = store
		local id = player.UserId
		if s and canWrite(id) then
			written[id] = nil
			pcall(function()
				s:RemoveAsync(tostring(id))
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		written[player.UserId] = nil
		bestPower[player.UserId] = nil
	end)
end

function LeaderboardService.Start()
	task.spawn(function()
		task.wait(8) -- let the first profiles load
		while true do
			refreshBoard("TopHunters", globalRows, valueOf)
			refreshBoard("TopPower", globalPowerRows, powerOf)
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
