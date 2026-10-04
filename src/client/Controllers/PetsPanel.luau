--!strict
-- GHOST PETS: owned pets, equip up to 3 and rename. Pets come from eggs at the PET HATCHERY
-- near the Boss Tower (Controllers/Hatchery; v1.8 removed direct purchases). Each equipped
-- pet gives a crew-wide bonus; the server validates every equip/rename. Nicknames shown here
-- come back from the server already text-filtered.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local PetPortrait = require(Client.UI.PetPortrait)
local Hud = require(script.Parent.Hud)

local PetsPanel = {}

local SHARD = Color3.fromRGB(200, 160, 255)

local panel: Kit.Panel
local shardLabel: TextLabel
local bonusLabel: TextLabel
local equippedHead: TextLabel
local equippedNames: TextLabel
local equippedLabel: TextLabel
local ownedRow: Frame
local renameRow: Frame
local renameTitle: TextLabel
local renameBox: TextBox
local renameUid: string? = nil
local NICK_MAX = 20
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

-- shared with the egg panel (Controllers/Hatchery)
PetsPanel.BonusText = bonusText

local function rarityName(pet: Config.PetDef): string
	local r = Config.Rarities[pet.Rarity]
	return string.upper(r and r.Name or pet.Rarity)
end

-- "Spooky (Boo Brew · COMMON)" or just "Boo Brew"
local function displayName(pet: Config.PetDef, nick: string?): string
	return if nick and nick ~= "" then nick .. " (" .. pet.Name .. " · " .. rarityName(pet) .. ")" else pet.Name
end

-- One pet card (nick: owned pet's filtered nickname); the caller adds the button.
local function card(parent: Instance, order: number, pet: Config.PetDef, nick: string?): Frame
	local r = Config.Rarities[pet.Rarity]
	local f: Frame = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 62, Parent = parent })
	Kit.Corner(f, UDim.new(0, 14))
	Kit.Stroke(f, 3, if r then Theme.RarityText(r) else Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(f, Theme.Panel3, Theme.Panel, 90)
	local orb: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = pet.Color:Lerp(Color3.new(0, 0, 0), 0.5), ZIndex = 63, Parent = f })
	Kit.Corner(orb, UDim.new(1, 0))
	Kit.Stroke(orb, 2.5, pet.Glow, Enum.ApplyStrokeMode.Border)
	PetPortrait.New(orb, pet.Id)
	local named = nick ~= nil and nick ~= ""
	Kit.Label(f, if named then nick :: string else string.upper(pet.Name), { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 56), Style = "Body", Fit = true, ZIndex = 63 })
	Kit.Label(f, if named then pet.Name .. " · " .. rarityName(pet) else (r and r.Name or pet.Rarity), { Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 78), Color = if r then Theme.RarityText(r) else Theme.Text, Style = "Tiny", Fit = true, ZIndex = 63 })
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
	bonusLabel.Text = if #parts > 0 then "TO ALL HUNTERS: " .. table.concat(parts, "  •  ") else "No pet bonuses yet: equip a pet!"
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
	equippedHead.Text = "EQUIPPED " .. nEquipped .. "/" .. Config.PetRules.MaxEquipped
	local names = {}
	for _, uid in d.EquippedPets or {} do
		local rec = d.Pets and d.Pets[uid]
		local pet = rec and Config.Pets[rec.Id]
		if rec and pet then
			table.insert(names, pet.Icon .. " " .. displayName(pet, rec.Nick))
		end
	end
	equippedNames.Text = if #names > 0 then table.concat(names, "   ") else "None: equip pets below"
	if renameUid and not (d.Pets and d.Pets[renameUid]) then
		renameUid = nil
	end
	renameRow.Visible = renameUid ~= nil
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
		local rec = d.Pets[uid]
		local pet = Config.Pets[rec.Id]
		if pet then
			local on = equipped[uid] == true
			local f = card(ownedRow, i, pet, rec.Nick)
			cardButton(f, if on then "UNEQUIP" else "EQUIP", if on then "Orange" else "Green", function()
				request("EquipPet", uid, not on)
			end)
			Kit.Button(f, {
				Text = "✏️",
				Color = "Purple",
				Size = UDim2.fromOffset(36, 36),
				Position = UDim2.new(1, -4, 0, 4),
				AnchorPoint = Vector2.new(1, 0),
				ZIndex = 64,
				OnClick = function()
					renameUid = uid
					renameTitle.Text = "RENAME " .. displayName(pet, rec.Nick)
					renameBox.Text = rec.Nick or ""
					renameRow.Visible = true
					renameBox:CaptureFocus()
				end,
			})
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
	equippedHead = Kit.Label(scroll, "", { Size = UDim2.new(1, 0, 0, 24), Style = "Heading", ZIndex = 62 })
	equippedHead.LayoutOrder = 3
	equippedNames = Kit.Label(scroll, "", { Size = UDim2.new(1, -6, 0, 20), Font = Theme.Body, Style = "Small", Fit = true, ZIndex = 62 })
	equippedNames.LayoutOrder = 4
	bonusLabel = Kit.Label(scroll, "", { Size = UDim2.new(1, -6, 0, 20), Color = Theme.Ecto, Style = "Small", Fit = true, ZIndex = 62 })
	bonusLabel.LayoutOrder = 5
	local function section(order: number, title: string): (TextLabel, Frame)
		local l = Kit.Label(scroll, title, { Size = UDim2.new(1, 0, 0, 24), Style = "Heading", ZIndex = 62 })
		l.LayoutOrder = order
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 61, Parent = scroll })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 176), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		return l, row
	end
	local hint = Kit.Label(scroll, "🥚 Get pets from eggs at the PET HATCHERY near the Boss Tower", { Size = UDim2.new(1, -6, 0, 36), Color = SHARD, Font = Theme.Body, Style = "Small", Wrap = true, ZIndex = 62 })
	hint.LayoutOrder = 10
	equippedLabel, ownedRow = section(20, "OWNED")
	ownedRow.LayoutOrder = 22
	-- rename bar (opened by a card's pencil button): text box + SAVE / DEFAULT / X
	renameRow = Kit.new("Frame", { Size = UDim2.new(1, -6, 0, 76), BackgroundColor3 = Theme.Bg, LayoutOrder = 21, Visible = false, ZIndex = 61, Parent = scroll })
	Kit.Corner(renameRow, UDim.new(0, 12))
	Kit.Stroke(renameRow, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	renameTitle = Kit.Label(renameRow, "", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 4), Align = Enum.TextXAlignment.Left, Style = "Small", Fit = true, ZIndex = 62 })
	local boxBg: Frame = Kit.new("Frame", { Size = UDim2.new(1, -290, 0, 38), Position = UDim2.fromOffset(10, 30), BackgroundColor3 = Theme.Panel, ZIndex = 62, Parent = renameRow })
	Kit.Corner(boxBg, UDim.new(0, 10))
	renameBox = Kit.new("TextBox", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Body,
		TextSize = Theme.Type.Body,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		PlaceholderText = "Pet name (up to " .. NICK_MAX .. " letters)",
		Text = "",
		ZIndex = 63,
		Parent = boxBg,
	})
	renameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local n = utf8.len(renameBox.Text)
		if not n or n > NICK_MAX then
			renameBox.Text = string.sub(renameBox.Text, 1, (utf8.offset(renameBox.Text, NICK_MAX + 1) or 1) - 1)
		end
	end)
	local function rename(text: string)
		local uid = renameUid
		if not uid then
			return
		end
		local res = request("RenamePet", uid, text)
		if res and res.ok then
			renameUid = nil
			renameRow.Visible = false
			Kit.Toast(if res.Nick then "Renamed to " .. res.Nick else "Name reset", "Good")
		end
	end
	local function barButton(text: string, color: string, x: number, w: number, onClick: () -> ())
		Kit.Button(renameRow, { Text = text, Color = color, Size = UDim2.fromOffset(w, 38), Position = UDim2.new(1, x, 0, 30), AnchorPoint = Vector2.new(1, 0), TextStyle = "Body", ZIndex = 63, OnClick = onClick })
	end
	barButton("SAVE", "Green", -184, 90, function()
		rename(renameBox.Text)
	end)
	barButton("DEFAULT", "Gray", -58, 120, function()
		rename("")
	end)
	barButton("X", "Red", -8, 44, function()
		renameUid = nil
		renameRow.Visible = false
	end)
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
