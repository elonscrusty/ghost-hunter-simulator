--!strict
-- Player-to-player HUNTER trading (v1.6). Both players must be in the same server.
--
-- Flow: request -> accept -> both sides edit their offer (any change clears BOTH confirmations)
-- -> both CONFIRM -> commit. Either player can cancel before the commit starts. Offered hunters
-- are marked busy (HunterService.SetBusy) so they can't be merged, released or offered elsewhere.
--
-- Durability (separate player saves can't be written together, so we never pretend they are):
--   1. the trade id is added to BOTH players' pending lists (Trades store, key "p_<userId>")
--   2. the full trade record is written once, State = "committed" (key "t_<tradeId>")
--   3. both profiles are changed in memory (one step, no yield) and the id is added to each
--      profile's TradesApplied list, then both are saved
--   4. after both saves, the pending ids are removed
-- If the server crashes or a save fails anywhere after step 2, each player's next join (on any
-- server) finds the id in their pending list, reads the committed record and applies THEIR side
-- unless TradesApplied already has it (DataService load hook). A trade whose record never got
-- written is simply dropped: nothing moved. So a trade is applied exactly once on each side and
-- can never leave only one side transferred.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local DataService = require(script.Parent.DataService)
local PlayerInfo = require(script.Parent.PlayerInfo)
local HunterService = require(script.Parent.HunterService)
local Remotes = require(script.Parent.Remotes)
local Fx = require(script.Parent.Fx)

local TradeService = {}

type Session = {
	Id: string,
	A: Player,
	B: Player,
	Offer: { [Player]: { string } },
	Confirmed: { [Player]: boolean },
	LastChange: number,
	Committing: boolean,
	Done: boolean,
}
type Record = { Id: string, State: string, A: number, B: number, GiveA: { [string]: any }, GiveB: { [string]: any }, T: number }

local T = Config.Trade
local IS_STUDIO = RunService:IsStudio()
local store: DataStore? = nil
local sessions: { [Player]: Session } = {}
local requests: { [Player]: { From: Player, Expires: number } } = {} -- target -> pending request

local function other(s: Session, p: Player): Player
	return if s.A == p then s.B else s.A
end

local function count(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- What the client shows: both offers (the other side's hunters as {Id, Tier}).
local function push(s: Session)
	for _, p in { s.A, s.B } do
		local o = other(s, p)
		local dOther = DataService.Get(o)
		local theirs = {}
		for _, uid in s.Offer[o] do
			local h = dOther and dOther.Hunters[uid]
			if h then
				table.insert(theirs, { Uid = uid, Id = h.Id, Tier = h.Tier or 0 })
			end
		end
		if p.Parent then
			Fx.To(p, "Trade", {
				State = if s.Done then "Done" elseif s.Committing then "Committing" else "Open",
				Id = s.Id,
				Other = o.DisplayName,
				Mine = s.Offer[p],
				Theirs = theirs,
				MeOk = s.Confirmed[p] == true,
				ThemOk = s.Confirmed[o] == true,
			})
		end
	end
end

local function releaseBusy(s: Session)
	for _, p in { s.A, s.B } do
		for _, uid in s.Offer[p] do
			if HunterService.BusyReason(p, uid) == "In a trade" then
				HunterService.SetBusy(p, uid, nil)
			end
		end
	end
end

local function close(s: Session, reason: string?)
	if sessions[s.A] == s then
		sessions[s.A] = nil
	end
	if sessions[s.B] == s then
		sessions[s.B] = nil
	end
	releaseBusy(s)
	for _, p in { s.A, s.B } do
		if p.Parent then
			Fx.To(p, "Trade", { State = if s.Done then "Done" else "Cancelled", Id = s.Id, Reason = reason })
		end
	end
end

-- Validates one side's offer against the live profile. Returns an error text or nil.
local function checkSide(p: Player, uids: { string }, receive: number): string?
	local d = DataService.Get(p)
	if not d then
		return p.DisplayName .. " is still loading"
	end
	if p:GetAttribute("InTower") then
		return "Can't trade inside the Boss Tower"
	end
	for _, uid in uids do
		local h = d.Hunters[uid]
		if not h then
			return "A hunter in the offer is gone"
		end
		if h.Locked then
			return "Locked hunters can't be traded"
		end
		if HunterService.IsKnocked(d, uid) then
			return "Knocked-out hunters can't be traded"
		end
	end
	local total = count(d.Hunters)
	if total - #uids + receive < 1 then
		return p.DisplayName .. " must keep at least one hunter"
	end
	if total - #uids + receive > PlayerInfo.MaxHunters(p) then
		return p.DisplayName .. "'s hunter storage is full"
	end
	return nil
end

-- Applies one side of a committed record to a profile (idempotent via TradesApplied).
local function applySide(d: DataService.Data, rec: Record, userId: number): boolean
	if table.find(d.TradesApplied, rec.Id) then
		return false
	end
	local give: { [string]: any } = if rec.A == userId then rec.GiveA else rec.GiveB
	local get: { [string]: any } = if rec.A == userId then rec.GiveB else rec.GiveA
	for uid in give do
		d.Hunters[uid] = nil
		d.Knocked[uid] = nil
		local i = table.find(d.Equipped, uid)
		if i then
			table.remove(d.Equipped, i)
		end
	end
	for _, h in get do
		if type(h) == "table" and Config.Hunters[h.Id] then
			local uid = DataService.NewUid(d)
			d.Hunters[uid] = { Id = h.Id, Tier = h.Tier, Locked = false, T = os.time() }
			d.Discovered[h.Id] = true
			if type(h.Tier) == "number" and h.Tier > 0 then
				d.Variants[h.Id .. ":" .. h.Tier] = true
			end
		end
	end
	table.insert(d.TradesApplied, rec.Id)
	while #d.TradesApplied > T.AppliedMemory do
		table.remove(d.TradesApplied, 1)
	end
	return true
end

local function editPending(userId: number, id: string, add: boolean): boolean
	local s = store
	if not s then
		return true
	end
	local ok = pcall(function()
		(s :: DataStore):UpdateAsync("p_" .. userId, function(old: any)
			local list = if type(old) == "table" then old else {}
			local i = table.find(list, id)
			if add and not i then
				table.insert(list, id)
			elseif not add and i then
				table.remove(list, i)
			end
			return list
		end)
	end)
	return ok
end

-- Clears this player's pending trade ids once a save that contains them has really landed
-- (while the pending id exists, a later join could re-apply the trade after TradesApplied has
-- forgotten it, so never leave it behind longer than needed). Only for the given live profile;
-- if the player leaves first, the next join's recovery settles the ids.
local function clearWhenSaved(player: Player, data: any, ids: { string })
	if #ids == 0 then
		return
	end
	task.spawn(function()
		DataService.WaitFor(player, 60)
		for _ = 1, 10 do
			if DataService.Get(player) ~= data then
				return
			end
			if DataService.SaveNow(player) then
				-- the trade is in the saved profile now: keep retrying the cleanup (even after
				-- the player leaves) so a stale pending id can't outlive TradesApplied's memory
				local userId = player.UserId
				for _, id in ids do
					local wait = 5
					while not editPending(userId, id, false) do
						task.wait(wait)
						wait = math.min(wait * 2, 300)
					end
				end
				return
			end
			task.wait(30)
		end
	end)
end

-- Writes the committed record once. Returns true if the record is committed in the store
-- (also when an uncertain write is confirmed by reading it back).
local function writeRecord(rec: Record): boolean
	local s = store
	if not s then
		return true -- Studio without the store: nothing is saved anyway
	end
	local ds = s :: DataStore
	local key = "t_" .. rec.Id
	local ok = pcall(function()
		ds:UpdateAsync(key, function(old: any)
			if old ~= nil then
				return nil -- never overwrite (an "aborted" marker stays aborted)
			end
			return rec
		end)
	end)
	local okRead, cur = pcall(function()
		return ds:GetAsync(key)
	end)
	if okRead and type(cur) == "table" then
		return cur.State == "committed"
	end
	if not ok or not okRead then
		-- outcome unknown: make sure it can never become committed later
		pcall(function()
			ds:UpdateAsync(key, function(old: any)
				return if old == nil then { Id = rec.Id, State = "aborted" } else nil
			end)
		end)
		local ok2, cur2 = pcall(function()
			return ds:GetAsync(key)
		end)
		return ok2 and type(cur2) == "table" and cur2.State == "committed"
	end
	return false
end

local function commit(s: Session)
	s.Committing = true
	push(s)
	local a, b = s.A, s.B
	local errA = checkSide(a, s.Offer[a], #s.Offer[b])
	local errB = checkSide(b, s.Offer[b], #s.Offer[a])
	if errA or errB then
		s.Committing = false
		s.Confirmed = {}
		push(s)
		for _, p in { a, b } do
			Fx.Toast(p, errA or errB or "Trade failed", "Bad")
		end
		return
	end
	local dA = DataService.Get(a) :: DataService.Data
	local dB = DataService.Get(b) :: DataService.Data
	local function copyGive(d: DataService.Data, uids: { string }): { [string]: any }
		local out = {}
		for _, uid in uids do
			local h = d.Hunters[uid]
			out[uid] = { Id = h.Id, Tier = h.Tier }
		end
		return out
	end
	local rec: Record = {
		Id = s.Id,
		State = "committed",
		A = a.UserId,
		B = b.UserId,
		GiveA = copyGive(dA, s.Offer[a]),
		GiveB = copyGive(dB, s.Offer[b]),
		T = os.time(),
	}
	-- 1 + 2: durable intent, then the committed record
	if not editPending(a.UserId, s.Id, true) or not editPending(b.UserId, s.Id, true) then
		task.spawn(editPending, a.UserId, s.Id, false)
		task.spawn(editPending, b.UserId, s.Id, false)
		s.Committing = false
		close(s, "Couldn't reach the trade server. Nothing was traded.")
		return
	end
	-- someone left (or started leaving) while the pending ids were written: their next join may
	-- already have read a pending list WITHOUT this id, so the trade must never commit now
	if DataService.Get(a) ~= dA or DataService.Get(b) ~= dB then
		local st = store
		if st then
			pcall(function()
				(st :: DataStore):UpdateAsync("t_" .. rec.Id, function(old: any)
					return if old == nil then { Id = rec.Id, State = "aborted" } else nil
				end)
			end)
		end
		task.spawn(editPending, a.UserId, s.Id, false)
		task.spawn(editPending, b.UserId, s.Id, false)
		s.Committing = false
		close(s, "A player left. Nothing was traded.")
		return
	end
	if not writeRecord(rec) then
		task.spawn(editPending, a.UserId, s.Id, false)
		task.spawn(editPending, b.UserId, s.Id, false)
		s.Committing = false
		close(s, "Couldn't save the trade. Nothing was traded.")
		return
	end
	-- 3: both sides in one step (no yield between them)
	applySide(dA, rec, a.UserId)
	applySide(dB, rec, b.UserId)
	s.Done = true
	releaseBusy(s)
	for _, p in { a, b } do
		if p.Parent then
			HunterService.EnsureEquipped(p) -- traded away the whole crew: equip the best left
			HunterService.Refresh(p)
		end
	end
	close(s, nil)
	-- 4: save each side; clear a side's pending id as soon as THAT side's save really landed
	-- (each side recovers on its own, so one failed save must not leave the other id behind)
	clearWhenSaved(a, dA, { s.Id })
	clearWhenSaved(b, dB, { s.Id })
end

-- Join-time recovery: finish this player's side of any committed trade a crash interrupted.
local function recover(player: Player, d: any)
	local st = store
	if not st then
		return
	end
	local ds = st :: DataStore
	-- reads retry; if a trade's state stays unknown the player is sent back (no data is written):
	-- playing on with hunters they may already have traded away would let them be traded twice
	local function get(key: string): (boolean, any)
		for attempt = 1, 3 do
			local ok, v = pcall(function()
				return ds:GetAsync(key)
			end)
			if ok then
				return true, v
			end
			if attempt < 3 then
				task.wait(attempt)
			end
		end
		return false, nil
	end
	local unsettled = false
	local recovered: { string } = {}
	local ok, list = get("p_" .. player.UserId)
	if not ok then
		unsettled = true
		list = nil
	end
	for _, id in if type(list) == "table" then list else {} do
		if type(id) ~= "string" then
			continue
		end
		if table.find(d.TradesApplied, id) then
			task.spawn(editPending, player.UserId, id, false) -- already applied and saved
			continue
		end
		local okRec, rec = get("t_" .. id)
		if not okRec then
			unsettled = true
		elseif type(rec) == "table" and rec.State == "committed" and (rec.A == player.UserId or rec.B == player.UserId) then
			applySide(d, rec :: any, player.UserId)
			table.insert(recovered, id)
			warn("[Trade] recovered trade " .. id .. " for " .. player.UserId)
		elseif rec == nil then
			-- the record may still be on its way: settle it first. An "aborted" marker is only
			-- written into an EMPTY key, so the trade either committed (apply it) or never will.
			pcall(function()
				ds:UpdateAsync("t_" .. id, function(old: any)
					return if old == nil then { Id = id, State = "aborted" } else nil
				end)
			end)
			local ok2, cur = pcall(function()
				return ds:GetAsync("t_" .. id)
			end)
			if ok2 and type(cur) == "table" and cur.State == "committed" and (cur.A == player.UserId or cur.B == player.UserId) then
				applySide(d, cur :: any, player.UserId)
				table.insert(recovered, id)
			elseif ok2 and type(cur) == "table" and cur.State == "aborted" then
				task.spawn(editPending, player.UserId, id, false)
			else
				unsettled = true -- could still commit on the other server
			end
		elseif type(rec) == "table" and rec.State == "aborted" then
			task.spawn(editPending, player.UserId, id, false) -- never committed: nothing to do
		end
	end
	if unsettled then
		warn("[Trade] couldn't settle pending trades for " .. player.UserId .. "; asking the player to rejoin")
		player:Kick("Couldn't finish loading your trades. Please rejoin in a moment - your progress is safe.")
		return
	end
	-- the recovered ids stay pending until a save that contains them lands
	clearWhenSaved(player, d, recovered)
end

function TradeService.InTrade(player: Player): boolean
	return sessions[player] ~= nil
end

function TradeService.Init()
	if not IS_STUDIO then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(T.DataStoreName)
		end)
		store = if ok then ds else nil
	end
	DataService.AddLoadHook(recover)

	Remotes.Register("TradeRequest", "Default", function(player, targetId)
		local target = if type(targetId) == "number" then Players:GetPlayerByUserId(targetId) else nil
		if not target or target == player then
			return Remotes.Fail("That player isn't here")
		end
		if sessions[player] or sessions[target] then
			return Remotes.Fail("Already trading")
		end
		if not DataService.Get(player) or not DataService.Get(target) then
			return Remotes.Fail("Still loading...")
		end
		if player:GetAttribute("InTower") or target:GetAttribute("InTower") then
			return Remotes.Fail("Can't trade inside the Boss Tower")
		end
		local pending = requests[target]
		if pending and pending.From.Parent and os.clock() < pending.Expires then
			return Remotes.Fail("They already have a trade request")
		end
		requests[target] = { From = player, Expires = os.clock() + T.RequestSeconds }
		Fx.To(target, "TradeRequest", { From = player.DisplayName, FromId = player.UserId, Seconds = T.RequestSeconds })
		return { ok = true }
	end)

	Remotes.Register("TradeRespond", "Default", function(player, fromId, accept)
		local req = requests[player]
		requests[player] = nil
		if not req or type(fromId) ~= "number" or req.From.UserId ~= fromId or os.clock() > req.Expires or not req.From.Parent then
			return Remotes.Fail("That request expired")
		end
		if accept ~= true then
			Fx.Toast(req.From, player.DisplayName .. " declined the trade", "Bad")
			return { ok = true }
		end
		if sessions[player] or sessions[req.From] then
			return Remotes.Fail("Already trading")
		end
		local s: Session = {
			Id = HttpService:GenerateGUID(false),
			A = req.From,
			B = player,
			Offer = { [req.From] = {}, [player] = {} },
			Confirmed = {},
			LastChange = os.clock(),
			Committing = false,
			Done = false,
		}
		sessions[req.From] = s
		sessions[player] = s
		push(s)
		return { ok = true }
	end)

	Remotes.Register("TradeOffer", "Inventory", function(player, uids)
		local s = sessions[player]
		if not s or s.Committing then
			return Remotes.Fail("No open trade")
		end
		local d = DataService.Get(player)
		if not d or type(uids) ~= "table" or #uids > T.MaxOffer then
			return Remotes.Fail(string.format("Up to %d hunters per side", T.MaxOffer))
		end
		local clean, seen = {}, {}
		for _, uid in uids do
			if type(uid) ~= "string" or seen[uid] then
				return Remotes.Fail("Bad offer")
			end
			seen[uid] = true
			local h = d.Hunters[uid]
			if not h then
				return Remotes.Fail("You don't own that hunter")
			end
			if h.Locked then
				return Remotes.Fail("Locked hunters can't be traded")
			end
			if HunterService.IsKnocked(d, uid) then
				return Remotes.Fail("That hunter is recovering")
			end
			local why = HunterService.BusyReason(player, uid)
			if why and not table.find(s.Offer[player], uid) then
				return Remotes.Fail(why)
			end
			table.insert(clean, uid)
		end
		if #clean > T.MaxOffer then
			return Remotes.Fail(string.format("Up to %d hunters per side", T.MaxOffer))
		end
		for _, uid in s.Offer[player] do
			HunterService.SetBusy(player, uid, nil)
		end
		for _, uid in clean do
			HunterService.SetBusy(player, uid, "In a trade")
		end
		s.Offer[player] = clean
		s.Confirmed = {} -- any change resets BOTH confirmations
		s.LastChange = os.clock()
		push(s)
		return { ok = true }
	end)

	Remotes.Register("TradeConfirm", "Default", function(player, tradeId)
		local s = sessions[player]
		if not s or s.Committing or s.Id ~= tradeId then
			return Remotes.Fail("No open trade")
		end
		if os.clock() - s.LastChange < T.ConfirmCooldown then
			return Remotes.Fail("The offer just changed - check it again")
		end
		if #s.Offer[s.A] == 0 and #s.Offer[s.B] == 0 then
			return Remotes.Fail("Add a hunter first")
		end
		s.Confirmed[player] = true
		push(s)
		if s.Confirmed[s.A] and s.Confirmed[s.B] then
			task.spawn(commit, s)
		end
		return { ok = true }
	end)

	Remotes.Register("TradeCancel", "Default", function(player)
		local s = sessions[player]
		if not s then
			return { ok = true }
		end
		if s.Committing then
			return Remotes.Fail("The trade is already finishing")
		end
		close(s, player.DisplayName .. " cancelled the trade")
		return { ok = true }
	end)
end

function TradeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
		local s = sessions[player]
		if s and not s.Committing then
			close(s, player.DisplayName .. " left the game")
		end
	end)
end

return TradeService
