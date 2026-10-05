--!strict
-- HUNTER INDEX: discovery tracking per zone ("HAUNTED NEIGHBORHOOD 3/4 DISCOVERED"),
-- overall completion %, silhouettes for unknown hunters, a 3D preview for known ones and a
-- NEW! indicator (menu badge + card sticker) for discoveries you haven't looked at yet.
-- Each hunter has three variants (NORMAL / ✨ SHINY / 💎 MEGA), discovered separately:
-- Normal = Data.Discovered[id], Shiny/Mega = Data.Variants["id:1"/"id:2"]. Cards show a chip per
-- variant; the detail pane has a tier toggle. Completion % still counts Normal discoveries only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Icons = require(GH.Icons)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)

-- max HP of a hunter with this power (incl. the equipped pets' HP bonus), as the server counts it
local function hpFor(power: number): number
	local d = State.Data
	local bonus = if d and d.PetBonuses then tonumber(d.PetBonuses.HP) or 0 else 0
	return Rules.HunterMaxHP(power, Config.Retaliation.HPPerPower, bonus)
end

local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local PetPortrait = require(Client.UI.PetPortrait)
local Hud = require(script.Parent.Hud)
local CratePanel = require(script.Parent.CratePanel)
local PetsPanel = require(script.Parent.PetsPanel)

local IndexPanel = {}

local panel: Kit.Panel
local scroll: ScrollingFrame
local totalLabel: TextLabel
local totalFill: Frame
local bar: Frame
local side: Frame
local detail: ScrollingFrame
local detailView: Frame
local detailName: TextLabel
local detailInfo: TextLabel
local detailBlurb: TextLabel
local menuBadge: Frame
local tierButtons: { [number]: TextButton } = {}
local detailHunter: Config.HunterDef? = nil
local detailTier = 0
local newIds: { [string]: boolean } = {}
local spinConn: RBXScriptConnection? = nil
local lastKey = ""
-- HUNTERS / PETS tabs
local tab = "Hunters"
local tabButtons: { [string]: TextButton } = {}
local petScroll: ScrollingFrame
local petTotal: TextLabel
local petKey = ""

local function hunterList(zoneId: string): { Config.HunterDef }
	local out = {}
	local crate = Config.Crates[(Config.ZoneById[zoneId] :: Config.ZoneDef).Crate]
	local pos: { [string]: number } = {}
	for i, e in crate.Pool do
		table.insert(out, Config.Hunters[e.Hunter])
		pos[e.Hunter] = i
	end
	-- weakest → strongest rarity (Ultra after Secret); pool order breaks ties
	table.sort(out, function(a, b)
		local ra, rb = Config.Rarities[a.Rarity].Order, Config.Rarities[b.Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return pos[a.Id] < pos[b.Id]
	end)
	return out
end

type Section = { Id: string, Name: string, Accent: Color3, List: { Config.HunterDef }, Unlocked: boolean }

-- One section per area, then the Robux-only EXCLUSIVE hunters.
local function sections(d: any): { Section }
	local out: { Section } = {}
	for _, z in Config.Zones do
		table.insert(out, { Id = z.Id, Name = z.Name, Accent = z.Accent, List = hunterList(z.Id), Unlocked = d.Zones[z.Id] == true })
	end
	local ex = {}
	for _, z in Config.Zones do
		local id = Config.Exclusives[z.Id]
		if id and Config.Hunters[id] then
			table.insert(ex, Config.Hunters[id])
		end
	end
	if #ex > 0 then
		table.insert(out, { Id = "Exclusive", Name = "EXCLUSIVE (ROBUX CRATE)", Accent = Config.Rarities.Exclusive.Color, List = ex, Unlocked = true })
	end
	return out
end

-- Has this player discovered `id` in `tier` (0 Normal, 1 Shiny, 2 Mega)?
local function has(d: any, id: string, tier: number): boolean
	if tier == 0 then
		return d.Discovered[id] == true
	end
	return d.Variants ~= nil and d.Variants[id .. ":" .. tier] == true
end

-- "  ·  SHINY 3  ·  MEGA 1" in the tier colours (labels with RichText on)
local function tierCounts(shiny: number, mega: number): string
	local function part(t: number, n: number): string
		local c = Config.Tiers[t].Color
		return string.format('  ·  <font color="#%02X%02X%02X">%s %d</font>', math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), Config.Tiers[t].Name, n)
	end
	return part(1, shiny) .. part(2, mega)
end

local function tierLabel(tier: number): string
	local t = Config.Tiers[tier]
	return if tier > 0 then t.Icon .. " " .. t.Name else t.Name
end

local function oddsOf(h: Config.HunterDef): number
	local zone = Config.ZoneById[h.Zone]
	local crate = Config.Crates[zone.Crate]
	local odds = Rules.Odds(crate.Pool :: any, function(id)
		return Config.Rarities[Config.Hunters[id].Rarity].Order
	end, 1, Config.LuckAffectsFromOrder)
	return odds[h.Id] or 0
end

local function showDetail(h: Config.HunterDef)
	local d = State.Data
	if not d then
		return
	end
	detailHunter = h
	local tier = detailTier
	local found = has(d, h.Id, tier)
	for t, b in tierButtons do
		local on = t == tier
		b.BackgroundColor3 = if on then Config.Tiers[t].Color else Theme.Bg
		b.TextColor3 = if on then Theme.Bg else (if has(d, h.Id, t) then Config.Tiers[t].Color else Theme.Muted)
	end
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	for _, c in detailView:GetChildren() do
		c:Destroy()
	end
	detail.Visible = true
	local rar = Config.Rarities[h.Rarity]
	local crate = if h.Rarity == "Exclusive" then Config.Crates.Exclusive else Config.Crates[(Config.ZoneById[h.Zone] :: Config.ZoneDef).Crate]
	if found then
		local _, model = Portrait.Viewport(detailView, h.Id, false, tier)
		if model then
			local t0 = os.clock()
			spinConn = RunService.RenderStepped:Connect(function()
				model:PivotTo(CFrame.Angles(0, (os.clock() - t0) * 0.9, 0))
			end)
		end
		detailName.Text = (if tier > 0 then Config.Tiers[tier].Icon .. " " .. Config.Tiers[tier].Name .. " " else "") .. string.upper(h.Name)
		detailBlurb.Text = h.Blurb
	else
		Portrait.Viewport(detailView, h.Id, true, tier)
		detailName.Text = if tier > 0 then Config.Tiers[tier].Icon .. " ???" else "???"
		detailBlurb.Text = if tier == 0
			then "Not discovered yet. Keep opening crates!"
			else tierLabel(tier) .. " not discovered yet. Merge " .. Config.Merge.Count .. " " .. (if tier == 1 then "NORMAL" else "SHINY") .. " copies to make one!"
	end
	detailName.TextColor3 = if tier > 0 then Config.Tiers[tier].Color else Theme.RarityText(rar)
	-- one short fact per line (top aligned) so the power icon sits on a line that never wraps
	Kit.IconText(detailInfo, tierLabel(tier) .. "  ·  " .. rar.Name .. "\n⚡ " .. (if found then Format.Short(h.Power * Config.Tiers[tier].Mult) .. "  ·  ❤️ " .. Format.Short(hpFor(h.Power * Config.Tiers[tier].Mult)) .. " HP" else "?") .. "\n" .. (if h.Rarity == "Exclusive" then "EXCLUSIVE CRATE (ROBUX) · best unlocked area" else crate.Name .. "  ·  " .. Format.Percent(oddsOf(h))))
end

local function rebuild()
	local d = State.Data
	if not d then
		return
	end
	local key = ""
	local secs = sections(d)
	for _, z in secs do
		key ..= if z.Unlocked then "u" else "l"
		for _, h in z.List do
			for t = 0, 2 do
				key ..= if has(d, h.Id, t) then "1" else "0"
			end
			key ..= if newIds[h.Id] then "n" else ""
		end
	end
	if key == lastKey then
		return
	end
	lastKey = key
	for _, c in scroll:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local total, found, shiny, mega = 0, 0, 0, 0
	for zi, z in secs do
		local list = z.List
		local zf, zs, zm = 0, 0, 0
		for _, h in list do
			if d.Discovered[h.Id] then
				zf += 1
			end
			zs += if has(d, h.Id, 1) then 1 else 0
			zm += if has(d, h.Id, 2) then 1 else 0
		end
		shiny += zs
		mega += zm
		if z.Id ~= "Exclusive" then -- paid hunters don't count toward completion
			total += #list
			found += zf
		end
		-- WORLD 1 / WORLD 2 divider above each world's first area
		local zdef = Config.ZoneById[z.Id]
		if zdef and #Config.Worlds > 1 then
			for _, w in Config.Worlds do
				if w.First == zdef.Order then
					local div: Frame = Kit.new("Frame", { Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, LayoutOrder = zi * 2 - 1, ZIndex = 62, Parent = scroll })
					Kit.Label(div, w.Name .. ": " .. w.Title, { Size = UDim2.fromScale(1, 1), Color = w.Accent, Style = "Heading", Fit = true, ZIndex = 63 })
				end
			end
		end
		local section: Frame = Kit.new("Frame", {
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Bg,
			BackgroundTransparency = 0.45,
			LayoutOrder = zi * 2,
			ZIndex = 62,
			Parent = scroll,
		})
		Kit.Corner(section, UDim.new(0, 12))
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = section })
		Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = section })
		local unlocked = z.Unlocked
		local complete = zf == #list
		local header: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 62, Parent = section })
		-- area icon (or the Exclusive crate) left of the name; a locked area adds the lock icon
		Kit.Icon(header, if z.Id == "Exclusive" then "crate_exclusive" else Icons.ForZone(z.Id), "", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Style = "Icon", ZIndex = 63 })
		local zoneName = Kit.Label(header, "", { Size = UDim2.new(0.6, -30, 1, 0), Position = UDim2.fromOffset(30, 0), Align = Enum.TextXAlignment.Left, Color = z.Accent, Style = "Heading", Fit = true, ZIndex = 63 })
		Kit.IconText(zoneName, (if unlocked then "" else "🔒 ") .. z.Name)
		-- Shiny / Mega counts as coloured words (no tier icons uploaded yet)
		local counts = Kit.Label(header, "", { Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = if complete then Theme.Gold else Theme.Text, Style = "Small", Fit = true, ZIndex = 63 })
		counts.RichText = true
		counts.Text = (if complete then "⭐ " else "") .. zf .. "/" .. #list .. tierCounts(zs, zm)
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 62, Parent = section })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 142), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for _, h in list do
			local rar = Config.Rarities[h.Rarity]
			local known = has(d, h.Id, 0) or has(d, h.Id, 1) or has(d, h.Id, 2)
			local card: TextButton = Kit.new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 63,
				Parent = row,
			})
			Kit.Corner(card, UDim.new(0, 12))
			Kit.Stroke(card, 2.5, Theme.Outline, Enum.ApplyStrokeMode.Border)
			if known then
				Kit.Gradient(card, rar.Color, rar.Color2, 90)
			else
				Kit.Gradient(card, Color3.fromRGB(70, 60, 100), Color3.fromRGB(40, 32, 66), 90)
			end
			local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(30, 18, 55), BackgroundTransparency = 0.35, ZIndex = 64, Parent = card })
			Kit.Corner(pic, UDim.new(1, 0))
			Portrait.Face(pic, h.Id, not has(d, h.Id, 0))
			Kit.Label(card, if known then string.upper(h.Name) else "???", { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 80), ZIndex = 66, Style = "Small", Fit = true })
			Kit.Label(card, rar.Name, { Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 100), ZIndex = 66, Color = if known then Color3.new(1, 1, 1) else Theme.RarityText(rar), Style = "Tiny", Fit = true })
			-- one chip per variant: lit in the tier colour when discovered, "?" when not
			for t = 0, 2 do
				local on = has(d, h.Id, t)
				local tc = Config.Tiers[t].Color
				local chip: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(28, 18), Position = UDim2.fromOffset(6 + t * 30, 118), BackgroundColor3 = if on then Theme.Bg else Color3.fromRGB(40, 32, 66), BackgroundTransparency = if on then 0.1 else 0.4, ZIndex = 66, Parent = card })
				Kit.Corner(chip, UDim.new(1, 0))
				Kit.Stroke(chip, 1.5, if on then tc else Theme.Outline, Enum.ApplyStrokeMode.Border)
				Kit.Label(chip, if not on then "?" else string.sub(Config.Tiers[t].Name, 1, 1), { Color = if on then tc else Theme.Muted, Style = "Tiny", Fit = true, ZIndex = 67, Stroke = 0 })
			end
			if newIds[h.Id] then
				local stamp = Kit.Label(card, "NEW!", { Size = UDim2.fromOffset(46, 18), Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), Color = Theme.Ecto, Style = "Body", ZIndex = 70, Stroke = 2 })
				stamp.Rotation = 12
			end
			card.Activated:Connect(function()
				Kit.Play("Click")
				if newIds[h.Id] then
					newIds[h.Id] = nil
					menuBadge.Visible = next(newIds) ~= nil
				end
				detailTier = 0
				showDetail(h)
			end)
		end
	end
	local pct = if total > 0 then found / total else 0
	totalLabel.Text = found .. " / " .. total .. " DISCOVERED  ·  " .. math.floor(pct * 100 + 0.5) .. "%" .. tierCounts(shiny, mega)
	Kit.Tween(totalFill, 0.4, { Size = UDim2.fromScale(math.max(pct, 0.02), 1) })
end

-- "Haunted Egg 40%" lines for every egg that can hatch this pet.
local function petSource(id: string): string
	local lines = {}
	for _, eggId in Config.EggOrder do
		local egg = Config.Eggs[eggId]
		for _, o in egg.Odds do
			if o.Pet == id then
				table.insert(lines, egg.Name .. " " .. o.Chance .. "%")
			end
		end
	end
	if #lines == 0 then
		return if id == Config.RarePetEvent.Pet then "Launch event reward" else "Special reward"
	end
	return table.concat(lines, "\n")
end

local function rebuildPets()
	local d = State.Data
	if not d then
		return
	end
	local owned: { [string]: boolean } = {}
	for _, p in d.Pets or {} do
		owned[p.Id] = true
	end
	local key = ""
	for _, id in Config.PetOrder do
		key ..= if owned[id] then "1" else "0"
	end
	if key == petKey then
		return
	end
	petKey = key
	for _, c in petScroll:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	local found = 0
	for i, id in Config.PetOrder do
		local pet = Config.Pets[id]
		local rar = Config.Rarities[pet.Rarity]
		local known = owned[id] == true
		found += if known then 1 else 0
		local card: TextButton = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 63, Parent = petScroll })
		Kit.Corner(card, UDim.new(0, 12))
		Kit.Stroke(card, 2.5, Theme.Outline, Enum.ApplyStrokeMode.Border)
		if known then
			Kit.Gradient(card, rar.Color, rar.Color2, 90)
		else
			Kit.Gradient(card, Color3.fromRGB(70, 60, 100), Color3.fromRGB(40, 32, 66), 90)
		end
		local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = if known then pet.Glow else Color3.fromRGB(30, 18, 55), BackgroundTransparency = 0.35, ZIndex = 64, Parent = card })
		Kit.Corner(pic, UDim.new(1, 0))
		PetPortrait.New(pic, id, not known) -- undiscovered: dark silhouette
		Kit.Label(card, if known then string.upper(pet.Name) else "???", { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 72), ZIndex = 66, Style = "Small", Fit = true })
		Kit.Label(card, rar.Name, { Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 90), ZIndex = 66, Color = if known then Color3.new(1, 1, 1) else Theme.RarityText(rar), Style = "Tiny", Fit = true })
		if known then
			Kit.Label(card, (string.gsub(PetsPanel.BonusText(pet.Bonus.Kind, pet.Bonus.Value), " for all hunters", "")), { Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 106), ZIndex = 66, Color = Theme.Ecto, Style = "Tiny", Fit = true })
		end
		Kit.Label(card, petSource(id), { Size = UDim2.new(1, -8, 0, 38), Position = UDim2.fromOffset(4, 134), ZIndex = 66, Color = Theme.Text, Font = Theme.Body, Style = "Tiny", Fit = true, Stroke = 0 })
	end
	petTotal.Text = (if found == #Config.PetOrder then "⭐ " else "") .. "PETS FOUND " .. found .. "/" .. #Config.PetOrder
end

local function setTab(t: string)
	tab = t
	for name, b in tabButtons do
		local on = name == t
		b.BackgroundColor3 = if on then Theme.Ecto else Theme.Bg
		b.TextColor3 = if on then Theme.Bg else Theme.Text
	end
	local hunters = t == "Hunters"
	bar.Visible = hunters
	scroll.Visible = hunters
	side.Visible = hunters
	petScroll.Visible = not hunters
	if hunters then
		rebuild()
	else
		rebuildPets()
	end
end

function IndexPanel.Init()
	panel = Kit.Panel("Index", "HUNTER INDEX", Vector2.new(860, 500), "Blue")
	local body = panel.Body
	-- HUNTERS / PETS tab row
	local tabRow: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 6), BackgroundTransparency = 1, ZIndex = 62, Parent = body })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabRow })
	for i, t in { "Hunters", "Pets" } do
		local b: TextButton = Kit.new("TextButton", {
			Text = if t == "Hunters" then "HUNTERS" else "PETS",
			Size = UDim2.fromOffset(130, 28),
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Bg,
			Font = Theme.Body,
			TextColor3 = Theme.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = i,
			ZIndex = 63,
			Parent = tabRow,
		})
		-- fixed size from the type scale (TextScaled made odd sizes that broke text on phones)
		Kit.FitText(b :: any, Theme.Type.Small, 0, true)
		Kit.Corner(b, UDim.new(1, 0))
		Kit.Stroke(b, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
		-- menu icon left of the tab name (text keeps clear of it)
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 26), Parent = b })
		Kit.Icon(b, if t == "Hunters" then "menu_hunters" else "menu_pets", "", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, -20, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Style = "Icon", ZIndex = 64 })
		b.Activated:Connect(function()
			Kit.Play("Click")
			setTab(t)
		end)
		tabButtons[t] = b
	end
	petScroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -42),
		Position = UDim2.fromOffset(0, 42),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Panel3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 62,
		Parent = body,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = petScroll })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 176), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = petScroll })
	petTotal = Kit.Label(tabRow, "PETS FOUND 0/" .. #Config.PetOrder, { Size = UDim2.new(1, -276, 1, 0), Align = Enum.TextXAlignment.Right, Color = Theme.Gold, Style = "Small", Fit = true, ZIndex = 63 })
	petTotal.LayoutOrder = 3
	bar = Kit.new("Frame", { Size = UDim2.new(1, -270, 0, 28), Position = UDim2.fromOffset(0, 42), BackgroundColor3 = Theme.Bg, ZIndex = 62, Parent = body })
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	totalFill = Kit.new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = bar })
	Kit.Corner(totalFill, UDim.new(1, 0))
	Kit.Gradient(totalFill, Theme.Ecto, Theme.Ecto2, 0)
	totalLabel = Kit.Label(bar, "COLLECTION", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Style = "Body", Fit = true, ZIndex = 64 })
	totalLabel.RichText = true
	scroll = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 80),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Panel3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 62,
		Parent = body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	side = Kit.new("Frame", { Position = UDim2.new(1, 0, 0, 42), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.5, ZIndex = 62, Parent = body })
	Kit.Corner(side, UDim.new(0, 12))
	Kit.Label(side, "Tap a card to take a closer look!", { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 63, Stroke = 0 })
	detail = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		ZIndex = 64,
		Parent = side,
	})
	Kit.Corner(detail, UDim.new(0, 12))
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = detail })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = detail })
	detailView = Kit.new("Frame", { Size = UDim2.fromOffset(160, 160), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 65, Parent = detail })
	-- NORMAL / ✨ SHINY / 💎 MEGA toggle
	local tierRow: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 65, Parent = detail })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tierRow })
	for t = 0, 2 do
		local b: TextButton = Kit.new("TextButton", {
			Text = tierLabel(t),
			Size = UDim2.new(1 / 3, -3, 1, 0),
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Bg,
			Font = Theme.Body,
			TextColor3 = Theme.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = t,
			ZIndex = 66,
			Parent = tierRow,
		})
		Kit.FitText(b :: any, Theme.Type.Tiny, 0, true)
		Kit.Corner(b, UDim.new(1, 0))
		Kit.Stroke(b, 1.5, Config.Tiers[t].Color, Enum.ApplyStrokeMode.Border)
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), Parent = b })
		b.Activated:Connect(function()
			Kit.Play("Click")
			detailTier = t
			if detailHunter then
				showDetail(detailHunter)
			end
		end)
		tierButtons[t] = b
	end
	detailName = Kit.Label(detail, "", { Size = UDim2.new(1, 0, 0, 22), Style = "Heading", Fit = true, ZIndex = 66 })
	detailName.LayoutOrder = 3
	detailInfo = Kit.Label(detail, "", { Size = UDim2.new(1, 0, 0, 0), ZIndex = 66, Color = Theme.Text, Font = Theme.Body, Style = "Small", Stroke = 0 })
	detailInfo.AutomaticSize = Enum.AutomaticSize.Y
	detailInfo.TextYAlignment = Enum.TextYAlignment.Top
	detailInfo.LayoutOrder = 4
	detailBlurb = Kit.Label(detail, "", { Size = UDim2.new(1, 0, 0, 0), ZIndex = 66, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0 })
	detailBlurb.AutomaticSize = Enum.AutomaticSize.Y
	detailBlurb.LayoutOrder = 5
	-- NEW badge on the INDEX menu button
	menuBadge = Kit.new("Frame", {
		Size = UDim2.fromOffset(36, 18),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Ecto,
		Visible = false,
		ZIndex = 10,
		Parent = Hud.Buttons.Index,
	})
	Kit.Corner(menuBadge, UDim.new(1, 0))
	Kit.Stroke(menuBadge, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Label(menuBadge, "NEW", { Style = "Tiny", ZIndex = 11 })
	Hud.RegisterPanel("Index", function()
		panel:Toggle()
	end)
end

-- Side pane takes ~30% of the panel's actual width; sections wrap their cards.
local function layout()
	local w = panel.Root.Size.X.Offset - 28
	local sideW = math.clamp(math.floor(w * 0.3), 190, 250)
	bar.Size = UDim2.new(1, -(sideW + 10), 0, 28)
	scroll.Size = UDim2.new(1, -(sideW + 10), 1, -80)
	side.Size = UDim2.new(0, sideW, 1, -42)
end

function IndexPanel.Start()
	panel.OnOpen:Connect(function()
		layout()
		lastKey = ""
		petKey = ""
		detail.Visible = false
		setTab(tab)
	end)
	Kit.ScaleChanged:Connect(function()
		if panel.IsOpen then
			layout()
		end
	end)
	panel.OnClose:Connect(function()
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		-- looked at the index: discoveries are no longer "new"
		table.clear(newIds)
		menuBadge.Visible = false
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			if tab == "Hunters" then
				rebuild()
			else
				rebuildPets()
			end
		end
	end)
	CratePanel.Opened:Connect(function(res: any)
		if res.IsNew then
			newIds[res.Hunter] = true
			menuBadge.Visible = true
		end
	end)
end

return IndexPanel
