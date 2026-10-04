--!strict
-- TRADE: hunters-only trading between two players in the same server. With no trade open the
-- panel lists the other players with a TRADE button. An incoming request shows a small
-- ACCEPT / DECLINE popup with a countdown. While a trade is open: your hunters (tap to offer),
-- YOU GIVE (tap to take back), THEY GIVE, both confirmation marks, CONFIRM and CANCEL.
-- The server is the authority; this only sends requests and draws the "Trade" Fx state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local Hud = require(script.Parent.Hud)

local TradePanel = {}

local panel: Kit.Panel
local lobbyView: ScrollingFrame
local tradeView: Frame
local pickGrid: ScrollingFrame
local giveGrid: ScrollingFrame
local getGrid: ScrollingFrame
local giveTitle: TextLabel
local getTitle: TextLabel
local statusLabel: TextLabel
local confirmButton: TextButton
local cancelButton: TextButton
-- incoming request popup
local invite: Kit.Panel
local inviteText: TextLabel
local inviteTimer: TextLabel
local inviteFrom = 0
local inviteEnds = 0

local trade: any = nil -- latest "Trade" Fx while Open / Committing
local lastSig = ""
local lastChange = 0

local function request(action: string, ...: any): any
	local res = State.Request(action, ...)
	if not res.ok then
		Kit.Toast(res.err or "Couldn't do that", "Bad")
	end
	return res
end

local function clear(grid: Instance)
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function makeGrid(parent: Instance): ScrollingFrame
	local g: ScrollingFrame = Kit.new("ScrollingFrame", {
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.5,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		ZIndex = 62,
		Parent = parent,
	})
	Kit.Corner(g, UDim.new(0, 12))
	Kit.Padding(g, 6)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 92), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
	return g
end

-- small hunter card: portrait, tier, tiered power
local function miniCard(parent: Instance, id: string, tierN: number, order: number, onClick: (() -> ())?)
	local def = Config.Hunters[id]
	if not def then
		return
	end
	local rar = Config.Rarities[def.Rarity]
	local tier = Config.Tiers[tierN] or Config.Tiers[0]
	local f: TextButton = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 63, Parent = parent })
	Kit.Corner(f, UDim.new(0, 12))
	Kit.Stroke(f, if tierN > 0 then 4 else 2, if tierN > 0 then tier.Color else Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(f, rar.Color, rar.Color2, 90)
	local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(30, 18, 55), BackgroundTransparency = 0.35, ZIndex = 64, Parent = f })
	Kit.Corner(pic, UDim.new(1, 0))
	Portrait.Face(pic, id, false)
	if tierN > 0 then
		Kit.Label(f, tier.Icon .. " " .. tier.Name, { Size = UDim2.new(1, -6, 0, 12), Position = UDim2.fromOffset(3, 44), Color = tier.Color, Style = "Small", Fit = true, ZIndex = 66 })
	end
	Kit.Label(f, string.upper(def.Name), { Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 57), Style = "Small", Fit = true, ZIndex = 66 })
	Kit.Label(f, "⚡" .. Format.Short(def.Power * tier.Mult), { Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 72), Color = Theme.Gold, Style = "Small", Fit = true, ZIndex = 66 })
	if onClick then
		f.Activated:Connect(function()
			Kit.Play("Click")
			onClick()
		end)
	end
end

local function setOffer(list: { string })
	if trade then
		request("TradeOffer", list)
	end
end

-- only players standing at the TRADING booth can be asked (the server checks again)
local function atBooth(p: Player): boolean
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - Config.Layout.TradeBooth).Magnitude <= Config.Trade.BoothRadius
end

local lobbyKey = "" -- who was listed last time (the 2 s refresh only redraws when it changes)
local function boothKey(): string
	local ids = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer and atBooth(p) then
			table.insert(ids, tostring(p.UserId))
		end
	end
	return table.concat(ids, ",")
end

local function renderLobby()
	lobbyKey = boothKey()
	clear(lobbyView)
	local n = 0
	for _, p in Players:GetPlayers() do
		if p == Players.LocalPlayer or not atBooth(p) then
			continue
		end
		n += 1
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.5, LayoutOrder = n, ZIndex = 62, Parent = lobbyView })
		Kit.Corner(row, UDim.new(0, 10))
		Kit.Label(row, p.DisplayName, { Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(12, 0), Align = Enum.TextXAlignment.Left, Style = "Body", Fit = true, ZIndex = 63 })
		local userId = p.UserId
		local name = p.DisplayName
		Kit.Button(row, {
			Text = "TRADE",
			Color = "Teal",
			Size = UDim2.fromOffset(110, 38),
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextStyle = "Small",
			ZIndex = 63,
			OnClick = function()
				if request("TradeRequest", userId).ok then
					Kit.Toast("Trade request sent to " .. name, "Good")
				end
			end,
		})
	end
	if n == 0 then
		Kit.Label(lobbyView, "Nobody else is at the TRADING booth yet. Invite a friend over!", { Size = UDim2.new(1, 0, 0, 40), Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, ZIndex = 62 })
	end
end

local function updateConfirm()
	local t = trade
	if not t then
		return
	end
	local wait = Config.Trade.ConfirmCooldown - (os.clock() - lastChange)
	cancelButton.Visible = t.State == "Open"
	if t.State ~= "Open" then
		Kit.SetButtonText(confirmButton, "TRADING...")
		confirmButton:SetAttribute("Color", "Gray")
	elseif t.MeOk then
		Kit.SetButtonText(confirmButton, "CONFIRMED ✅")
		confirmButton:SetAttribute("Color", "Gray")
	elseif wait > 0 then
		Kit.SetButtonText(confirmButton, "CONFIRM (" .. math.ceil(wait) .. ")")
		confirmButton:SetAttribute("Color", "Gray")
	else
		Kit.SetButtonText(confirmButton, "CONFIRM")
		confirmButton:SetAttribute("Color", "Green")
	end
end

local function render()
	local t = trade
	lobbyView.Visible = t == nil
	tradeView.Visible = t ~= nil
	if not t then
		renderLobby()
		return
	end
	local d = State.Data
	local mine: { string } = t.Mine or {}
	local inOffer: { [string]: boolean } = {}
	clear(giveGrid)
	for i, uid in mine do
		inOffer[uid] = true
		local h = d and d.Hunters[uid]
		if h then
			miniCard(giveGrid, h.Id, h.Tier or 0, i, function()
				local list = table.clone(mine)
				table.remove(list, table.find(list, uid) :: number)
				setOffer(list)
			end)
		end
	end
	clear(getGrid)
	for i, h in t.Theirs or {} do
		miniCard(getGrid, h.Id, h.Tier or 0, i, nil)
	end
	clear(pickGrid)
	if d then
		local now = State.Now()
		local uids = {}
		for uid, h in d.Hunters do
			if not inOffer[uid] and not h.Locked and ((d.Knocked and d.Knocked[uid]) or 0) <= now then
				table.insert(uids, uid)
			end
		end
		local function power(uid: string): number
			local h = d.Hunters[uid]
			local def = Config.Hunters[h.Id]
			return (if def then def.Power else 0) * (Config.Tiers[h.Tier or 0] or Config.Tiers[0]).Mult
		end
		table.sort(uids, function(a, b)
			return power(a) > power(b)
		end)
		for i, uid in uids do
			local h = d.Hunters[uid]
			miniCard(pickGrid, h.Id, h.Tier or 0, i, function()
				if #mine >= Config.Trade.MaxOffer then
					Kit.Toast("You can offer up to " .. Config.Trade.MaxOffer .. " hunters", "Bad")
					return
				end
				local list = table.clone(mine)
				table.insert(list, uid)
				setOffer(list)
			end)
		end
	end
	local other = string.upper(tostring(t.Other or "THEY"))
	giveTitle.Text = "YOU GIVE (" .. #mine .. "/" .. Config.Trade.MaxOffer .. ")"
	getTitle.Text = other .. " GIVES"
	statusLabel.Text = "You: " .. (if t.MeOk then "✅" else "⏳ waiting") .. "    " .. other .. ": " .. (if t.ThemOk then "✅" else "⏳ waiting")
	updateConfirm()
end

local function onTrade(data: any)
	if type(data) ~= "table" then
		return
	end
	if data.State == "Done" or data.State == "Cancelled" then
		trade = nil
		if data.State == "Done" then
			Kit.Toast("Trade complete! 🤝", "Good")
		else
			Kit.Toast("Trade cancelled" .. (if data.Reason then ": " .. tostring(data.Reason) else ""), "Bad")
		end
		render()
		return
	end
	-- any change to either offer resets confirmations and restarts the CONFIRM cooldown
	local theirs = {}
	for _, h in data.Theirs or {} do
		table.insert(theirs, tostring(h.Uid))
	end
	local sig = tostring(data.Id) .. "|" .. table.concat(data.Mine or {}, ",") .. "|" .. table.concat(theirs, ",")
	if sig ~= lastSig then
		lastSig = sig
		lastChange = os.clock()
	end
	trade = data
	if invite.IsOpen then
		invite:Close()
	end
	if not panel.IsOpen then
		panel:Open()
	end
	render()
end

local function respond(accept: boolean)
	local from = inviteFrom
	invite:Close()
	request("TradeRespond", from, accept)
end

function TradePanel.Init()
	panel = Kit.Panel("Trade", "TRADE", Vector2.new(780, 480), "Teal")
	local body = panel.Body
	-- no trade: other players
	lobbyView = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.fromOffset(0, 10),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lobbyView })
	-- open trade
	tradeView = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 61, Parent = body })
	Kit.Label(tradeView, "⚠️ Both players must confirm. Any change resets confirmations.", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 10), Color = Theme.Gold, Style = "Small", Fit = true, ZIndex = 62 })
	local cols = { "YOUR HUNTERS (tap to offer)", "YOU GIVE", "THEY GIVE" }
	local titles: { TextLabel } = {}
	local grids: { ScrollingFrame } = {}
	for i, text in cols do
		local x = (i - 1) / 3
		titles[i] = Kit.Label(tradeView, text, { Size = UDim2.new(1 / 3, -8, 0, 18), Position = UDim2.new(x, 4, 0, 36), Style = "Small", Fit = true, ZIndex = 62 })
		local g = makeGrid(tradeView)
		g.Size = UDim2.new(1 / 3, -8, 1, -118)
		g.Position = UDim2.new(x, 4, 0, 58)
		grids[i] = g
	end
	pickGrid, giveGrid, getGrid = grids[1], grids[2], grids[3]
	giveTitle, getTitle = titles[2], titles[3]
	statusLabel = Kit.Label(tradeView, "", { Size = UDim2.new(1, -300, 0, 44), Position = UDim2.new(0, 4, 1, -2), AnchorPoint = Vector2.new(0, 1), Align = Enum.TextXAlignment.Left, Style = "Small", Fit = true, ZIndex = 62 })
	cancelButton = Kit.Button(tradeView, {
		Text = "CANCEL",
		Color = "Red",
		Size = UDim2.fromOffset(120, 44),
		Position = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 62,
		OnClick = function()
			request("TradeCancel")
		end,
	})
	confirmButton = Kit.Button(tradeView, {
		Text = "CONFIRM",
		Color = "Gray",
		Size = UDim2.fromOffset(160, 44),
		Position = UDim2.new(1, -128, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 62,
		OnClick = function()
			local t = trade
			if t and t.State == "Open" and not t.MeOk then
				request("TradeConfirm", t.Id)
			end
		end,
	})
	panel.Primary = confirmButton
	-- incoming request popup
	invite = Kit.Panel("TradeInvite", "TRADE REQUEST", Vector2.new(420, 230), "Teal")
	inviteText = Kit.Label(invite.Body, "", { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 14), Style = "Body", ZIndex = 62 })
	inviteTimer = Kit.Label(invite.Body, "", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 68), Color = Theme.Muted, Style = "Small", ZIndex = 62 })
	invite.Primary = Kit.Button(invite.Body, {
		Text = "ACCEPT",
		Color = "Green",
		Size = UDim2.new(0.5, -10, 0, 46),
		Position = UDim2.new(0, 4, 1, -4),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 63,
		OnClick = function()
			respond(true)
		end,
	})
	Kit.Button(invite.Body, {
		Text = "DECLINE",
		Color = "Red",
		Size = UDim2.new(0.5, -10, 0, 46),
		Position = UDim2.new(1, -4, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 63,
		OnClick = function()
			respond(false)
		end,
	})
	Hud.RegisterPanel("Trade", function()
		panel:Toggle()
	end)
end

function TradePanel.Start()
	panel.OnOpen:Connect(render)
	-- players walk up to / away from the booth: refresh the list while it's showing
	task.spawn(function()
		while true do
			task.wait(2)
			if panel.IsOpen and not trade and boothKey() ~= lobbyKey then
				renderLobby()
			end
		end
	end)
	Players.PlayerAdded:Connect(function()
		if panel.IsOpen and not trade then
			renderLobby()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if panel.IsOpen and not trade then
				renderLobby()
			end
		end)
	end)
	State.Changed:Connect(function()
		if panel.IsOpen and trade then
			render()
		end
	end)
	State.OnFx("Trade", onTrade)
	State.OnFx("TradeRequest", function(data: any)
		if type(data) ~= "table" or trade then
			return
		end
		inviteFrom = tonumber(data.FromId) or 0
		inviteEnds = os.clock() + (tonumber(data.Seconds) or Config.Trade.RequestSeconds)
		local from = tostring(data.From or "Someone")
		local fromId = inviteFrom
		local ends = inviteEnds
		-- never close a menu the player is using: wait until it's free (a toast says who asked)
		if not Kit.IsFree() then
			Kit.Toast("🤝 " .. from .. " wants to trade! Close this menu to answer.", "Gold")
		end
		Kit.WhenFree(function()
			if trade or invite.IsOpen or inviteFrom ~= fromId or os.clock() >= ends then
				return -- expired, replaced or already trading
			end
			inviteText.Text = from .. " wants to trade hunters with you!"
			invite:Open()
		end)
	end)
	-- countdowns: CONFIRM cooldown and the request popup
	while true do
		task.wait(0.25)
		if trade and panel.IsOpen then
			updateConfirm()
		end
		if invite.IsOpen then
			local left = inviteEnds - os.clock()
			if left <= 0 then
				invite:Close()
			else
				inviteTimer.Text = "Expires in " .. math.ceil(left) .. "s"
			end
		end
	end
end

return TradePanel
