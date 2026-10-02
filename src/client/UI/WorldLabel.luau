--!strict
-- World-space labels (BillboardGuis) that behave the same on phones and desktops:
--  * size is in screen pixels (constant on-screen size, never balloons when the camera is
--    close) multiplied by the same device scale as the HUD (Kit.UIScale), and re-applied when
--    the screen size changes
--  * text sizes are fixed (no TextScaled), also device-scaled
--  * every label has a MaxDistance, so far-away labels disappear instead of cluttering
--  * optional distance factor (SetDistance): a label never grows as you walk away; it eases
--    down a little with distance (like the world does) until MaxDistance hides it
-- Inside a label, lay elements out with Scale-based sizes (fractions of the label).
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local WorldLabel = {}

export type Props = {
	Adornee: Instance?,
	Parent: Instance?,
	Size: Vector2, -- logical px
	Offset: Vector3?, -- StudsOffsetWorldSpace
	MaxDistance: number,
	AlwaysOnTop: boolean?,
	Name: string?,
}

local guis: { [BillboardGui]: Vector2 } = setmetatable({} :: any, { __mode = "k" })
local texts: { [TextLabel]: number } = setmetatable({} :: any, { __mode = "k" })
-- weak values too: guiTexts holds the labels strongly, so a strong gui value here would form a
-- cycle that keeps every destroyed ghost label alive
local textGui: { [TextLabel]: BillboardGui } = setmetatable({} :: any, { __mode = "kv" })
local factors: { [BillboardGui]: number } = setmetatable({} :: any, { __mode = "k" })
local guiTexts: { [BillboardGui]: { TextLabel } } = setmetatable({} :: any, { __mode = "k" })

local function applyGui(g: BillboardGui, base: Vector2)
	local s = Kit.UIScale() * (factors[g] or 1)
	g.Size = UDim2.fromOffset(math.floor(base.X * s + 0.5), math.floor(base.Y * s + 0.5))
end

local function applyText(l: TextLabel, base: number)
	local g = textGui[l]
	local f = if g then factors[g] or 1 else 1
	local size = math.max(9, math.floor(base * Kit.UIScale() * f + 0.5))
	l.TextSize = size
	-- keep the outline thin relative to the letters (a fixed 1.5 px outline smeared small text)
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		st.Thickness = if size >= 20 then 2 else 1 -- whole pixels (fractional outlines shimmer)
	end
end

-- Distance factor: full size up to Theme.World.FullSizeDistance studs from the camera, then
-- (ref / d) ^ 0.6 down to Theme.World.MinFactor. Cheap to call every frame: it only touches the
-- instance when the factor moves by more than 4%.
function WorldLabel.SetDistance(g: BillboardGui, dist: number)
	local W = Theme.World
	local f = if dist <= W.FullSizeDistance then 1 else math.max(W.MinFactor, (W.FullSizeDistance / dist) ^ 0.6)
	local old = factors[g] or 1
	if math.abs(f - old) < 0.04 and not (f == 1 and old ~= 1) then
		return
	end
	factors[g] = f
	local base = guis[g]
	if base then
		applyGui(g, base)
	end
	local list = guiTexts[g]
	if list then
		for _, l in list do
			local tb = texts[l]
			if tb then
				applyText(l, tb)
			end
		end
	end
end

function WorldLabel.New(p: Props): BillboardGui
	local g: BillboardGui = Kit.new("BillboardGui", {
		Name = p.Name or "WorldLabel",
		StudsOffsetWorldSpace = p.Offset or Vector3.zero,
		MaxDistance = p.MaxDistance,
		AlwaysOnTop = p.AlwaysOnTop == true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ClipsDescendants = false,
		Adornee = p.Adornee,
		Parent = p.Parent,
	})
	guis[g] = p.Size
	applyGui(g, p.Size)
	return g
end

function WorldLabel.Resize(g: BillboardGui, base: Vector2)
	guis[g] = base
	applyGui(g, base)
end

export type TextProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Style: string?, -- Theme.Type key (default Small)
	Stroke: number?,
	Font: Enum.Font?,
	ZIndex: number?,
}

-- Single-line text inside a world label (truncates instead of overflowing).
function WorldLabel.Text(parent: Instance, text: string, p: TextProps?): TextLabel
	local o: TextProps = p or {}
	local base = Theme.Type[o.Style or "Small"] or Theme.Type.Small
	local l: TextLabel = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		Text = text,
		TextColor3 = o.Color or Theme.Text,
		Font = o.Font or Theme.Title,
		TextScaled = false,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = o.ZIndex or 1,
		Parent = parent,
	})
	texts[l] = base
	local g = parent:FindFirstAncestorOfClass("BillboardGui") or (if parent:IsA("BillboardGui") then parent else nil)
	if g then
		textGui[l] = g
		local list = guiTexts[g]
		if not list then
			list = {}
			guiTexts[g] = list
		end
		table.insert(list, l)
	end
	applyText(l, base)
	local stroke = o.Stroke or 1.5
	if stroke > 0 then
		Kit.new("UIStroke", { Thickness = stroke, Color = Theme.Outline, Parent = l })
		applyText(l, base) -- size the new outline too
	end
	return l
end

function WorldLabel.SetTextStyle(l: TextLabel, style: string)
	local base = Theme.Type[style] or Theme.Type.Small
	texts[l] = base
	applyText(l, base)
end

Kit.ScaleChanged:Connect(function(s: number)
	for g, base in guis do
		applyGui(g, base)
	end
	for l, base in texts do
		applyText(l, base)
	end
end)

return WorldLabel
