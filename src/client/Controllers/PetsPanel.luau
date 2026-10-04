--!strict
-- GHOST PETS: buy pets with Spirit Shards (Boss Tower only) and equip up to 3. Each equipped
-- pet gives a crew-wide bonus; the server validates every buy/equip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local PetsPanel = {}

local SHAPE_ICON: { [string]: string } = {
	Wisp = "✨", Bat = "🦇", Blob = "👻", Cat = "🐱", Owl = "🦉", Fox = "🦊", Drake = "🐉", Phoenix = "🔥", Lantern = "🏮",
}
local SHARD = Color3.fromRGB(200, 160, 255)

local panel: Kit.Panel
local shardLabel: TextLabel
local bonusLabel: TextLabel
local equippedLabel: TextLabel
local ownedRow: Frame
local buyButtons: { [string]: TextButton } = {}
local busy = false

local function bonusText(kind: string, value: number): string
	local pct = math.floor(value * 100 + 0.5) .. "%"
	if kind == "Power" then
		return "+" .. pct .. " POWER for all hunters"
	elseif kind == "Ecto" then
		return "+" .. pct .. " ECTOPLASM"
	elseif kind == "HP" then
		return "+" .. pct .. " HUNTER HP"
	end
	return pct .. " FASTER RECOVERY"
end

-- One pet card; the caller adds the button.
local function card(parent: Instance, order: number, pet: Config.PetDef): Frame
	local r = Config.Rarities[pet.Rarity]
	local f: Frame = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 62, Parent = parent })
	Kit.Corner(f, UDim.new(0, 14))
	Kit.Stroke(f, 3, r and r.Color or Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(f, Theme.Panel3, Theme.Panel, 90)
	local orb: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = pet.Color, ZIndex = 63, Parent = f })
	Kit.Corner(orb, UDim.new(1, 0))
	Kit.Stroke(orb, 2.5, pet.Glow, Enum.ApplyStrokeMode.Border)
	Kit.Icon(orb, "pet_" .. pet.Id, SHAPE_ICON[pet.Shape] or "👻", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Style = "Icon", TextSize = 26, Stroke = 0, ZIndex = 64 })
	Kit.Label(f, string.upper(pet.Name), { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 56), Style = "Body", Fit = true, ZIndex = 63 })
	Kit.Label(f, r and r.Name or pet.Rarity, { Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 78), Color = r and r.Color or Theme.Text, Style = "Tiny", Fit = true, ZIndex = 63 })
	Kit.Label(f, bonusText(pet.Bonus.Kind, pet.Bonus.Value), { Size = UDim2.new(1, -10, 0, 32), Position = UDim2.fromOffset(5, 96), Color = Theme.Ecto, Font = Theme.Body, Style = "Tiny", Wrap = true, ZIndex = 63 })
	return f
end

local function cardButton(f: Frame, text: string, color: string, onClick: () -> ()): TextButton
	return Kit.Button(f, {
		Text = text,
		Color = color,
		Size = UDim2.new(1, -16, 0, 38),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 64,
		OnClick = onClick,
	})
end

local function request(action: string, ...: any): any
	if busy then
		return nil
	end
	busy = true
	local res = State.Request(action, ...)
	busy = false
	if not res.ok then
		Kit.Toast(res.err or "Can't do that right now", "Bad")
	end
	return res
end

local function refresh()
	local d = State.Data
	if not d then
		return
	end
	local shards = d.Shards or 0
	shardLabel.Text = "🔮 " .. Format.Short(shards) .. " SPIRIT SHARDS"
	local parts = {}
	for _, kind in { "Power", "Ecto", "HP", "Recovery" } do
		local v = d.PetBonuses and d.PetBonuses[kind]
		if v and v > 0 then
			table.insert(parts, bonusText(kind, v))
		end
	end
	bonusLabel.Text = if #parts > 0 then "ACTIVE: " .. table.concat(parts, "  •  ") else "No pet bonuses yet: equip a pet!"
	for id, b in buyButtons do
		b:SetAttribute("Color", if shards >= (Config.Pets[id].Price or math.huge) then "Green" else "Gray")
	end
	-- owned: rebuilt each refresh (at most MaxOwned small cards), equipped first
	local equipped: { [string]: boolean } = {}
	for _, uid in d.EquippedPets or {} do
		equipped[uid] = true
	end
	local nEquipped = 0
	for _ in equipped do
		nEquipped += 1
	end
	equippedLabel.Text = "OWNED  •  EQUIPPED " .. nEquipped .. "/" .. Config.PetRules.MaxEquipped
	for _, c in ownedRow:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local uids = {}
	for uid in d.Pets or {} do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		local ta, tb = d.Pets[a].T or 0, d.Pets[b].T or 0
		if equipped[a] ~= equipped[b] then
			return equipped[a] == true
		end
		return if ta ~= tb then ta < tb else a < b
	end)
	for i, uid in uids do
		local pet = Config.Pets[d.Pets[uid].Id]
		if pet then
			local on = equipped[uid] == true
			local f = card(ownedRow, i, pet)
			cardButton(f, if on then "UNEQUIP" else "EQUIP", if on then "Orange" else "Green", function()
				request("EquipPet", uid, not on)
			end)
		end
	end
	if #uids == 0 then
		local f: Frame = Kit.new("Frame", { BackgroundTransparency = 1, ZIndex = 62, Parent = ownedRow })
		Kit.Label(f, "No pets yet", { Color = Theme.Muted, Style = "Small", ZIndex = 63 })
	end
end

function PetsPanel.Init()
	panel = Kit.Panel("Pets", "GHOST PETS", Vector2.new(780, 500), "Purple")
	local scroll: ScrollingFrame = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.fromOffset(0, 10),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	shardLabel = Kit.Label(scroll, "", { Size = UDim2.new(1, -6, 0, 30), Color = SHARD, Style = "Currency", Fit = true, ZIndex = 62 })
	shardLabel.LayoutOrder = 1
	Kit.Label(scroll, "Earn shards in the Boss Tower", { Size = UDim2.new(1, -6, 0, 18), Color = Theme.Muted, Font = Theme.Body, Style = "Small", Fit = true, Stroke = 0, ZIndex = 62 }).LayoutOrder = 2
	bonusLabel = Kit.Label(scroll, "", { Size = UDim2.new(1, -6, 0, 20), Color = Theme.Ecto, Style = "Small", Fit = true, ZIndex = 62 })
	bonusLabel.LayoutOrder = 3
	local function section(order: number, title: string): (TextLabel, Frame)
		local l = Kit.Label(scroll, title, { Size = UDim2.new(1, 0, 0, 24), Style = "Heading", ZIndex = 62 })
		l.LayoutOrder = order
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 61, Parent = scroll })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 176), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		return l, row
	end
	local _, shopRow = section(4, "SHOP")
	for i, id in Config.PetOrder do
		local pet = Config.Pets[id]
		if pet and pet.Price then
			local f = card(shopRow, i, pet)
			buyButtons[id] = cardButton(f, "🔮 " .. Format.Short(pet.Price), "Gray", function()
				local res = request("BuyPet", id)
				if res and res.ok then
					Sound.Play("Upgrade")
					Kit.Toast("You got " .. pet.Name .. "! Equip it below.", "Good")
				end
			end)
		end
	end
	equippedLabel, ownedRow = section(6, "OWNED")
	Hud.RegisterPanel("Pets", function()
		panel:Toggle()
	end)
end

function PetsPanel.Start()
	panel.OnOpen:Connect(refresh)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return PetsPanel
