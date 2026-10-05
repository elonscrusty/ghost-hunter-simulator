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
-- Stored numbers use Rules.BoardEncode (OrderedDataStore values must stay below 2^53, World 2
-- totals go far past that): below 1e15 a value is stored as it is, bigger values in an
-- order-keeping log form. Same DataStore names as before; an old raw entry of 1e15 or more is
-- re-written in the new form the first time it shows up in a board's top rows.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Rules = require(GH.Logic.Rules)
local DataService = require(script.Parent.DataService)
local HunterService = require(script.Parent.HunterService)

local LeaderboardService = {}

type Row = { Name: string, Value: number }

local store: OrderedDataStore? = nil
local powerStore: OrderedDataStore? = nil
local names: { [number]: string } = {}
local written: { [number]: number } = {} -- userId -> stored (encoded) number this server last wrote
local bestPower: { [number]: number } = {} -- userId -> best power (real value) known to be stored
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
	local v = math.floor(d.TotalEcto)
	return if v == v and v > 0 then v else 0
end

local function powerOf(player: Player): number?
	if not DataService.Get(player) then
		return nil
	end
	local p = HunterService.CrewPower(player)
	if p ~= p then
		return 0
	end
	return math.max(0, math.floor(p))
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
		local real = valueOf(pl)
		local v = if real then Rules.BoardEncode(real) else nil
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
			-- compare real values (an old raw entry decodes as itself)
			local keep: any = function(old: any): number?
				local prev = Rules.BoardDecode(tonumber(old) or 0)
				return if v > prev then Rules.BoardEncode(v) else nil
			end
			local ok, stored = pcall(function(): any
				return s:UpdateAsync(tostring(id), keep)
			end)
			if ok then
				bestPower[id] = math.max(v, Rules.BoardDecode(tonumber(stored) or 0))
			end
		end
	end
	return readTop(s)
end

-- An entry written by an older server as a raw value >= 1e15 (they clamped at 2^53): rewrite it
-- in the new form so it sorts correctly against new entries. Only if it is unchanged meanwhile.
local migrated: { [OrderedDataStore]: { [string]: boolean } } = {}
local function migrate(s: OrderedDataStore, key: string, stored: number)
	local done = migrated[s] or {}
	migrated[s] = done
	if done[key] then
		return
	end
	done[key] = true
	task.spawn(function()
		pcall(function()
			s:UpdateAsync(key, function(old: any): any
				local cur = tonumber(old)
				return if cur == stored then Rules.BoardEncode(stored) else nil
			end)
		end)
	end)
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
		local stored = tonumber(entry.value) or 0
		if id and Rules.BoardIsLegacy(stored) and canWrite(id) then
			migrate(s, entry.key, stored)
		end
		if id and not isDev(id) and #rows < Config.Leaderboard.Rows then
			table.insert(rows, { Name = nameOf(id), Value = Rules.BoardDecode(stored) })
		end
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.Value > b.Value
	end)
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
