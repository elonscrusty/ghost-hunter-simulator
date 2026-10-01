--!strict
-- World-space labels (BillboardGuis) that behave the same on phones and desktops:
--  * size is in screen pixels (constant on-screen size, never balloons when the camera is
--    close) multiplied by the same device scale as the HUD (Kit.UIScale), and re-applied when
--    the screen size changes
--  * text sizes are fixed (no TextScaled), also device-scaled
--  * every label has a MaxDistance, so far-away labels disappear instead of cluttering
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

local function applyGui(g: BillboardGui, base: Vector2)
	local s = Kit.UIScale()
	g.Size = UDim2.fromOffset(math.floor(base.X * s + 0.5), math.floor(base.Y * s + 0.5))
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
	l.TextSize = math.max(8, math.floor(base * Kit.UIScale() + 0.5))
	local stroke = o.Stroke or 1.5
	if stroke > 0 then
		Kit.new("UIStroke", { Thickness = stroke, Color = Theme.Outline, Parent = l })
	end
	return l
end

function WorldLabel.SetTextStyle(l: TextLabel, style: string)
	local base = Theme.Type[style] or Theme.Type.Small
	texts[l] = base
	l.TextSize = math.max(8, math.floor(base * Kit.UIScale() + 0.5))
end

Kit.ScaleChanged:Connect(function(s: number)
	for g, base in guis do
		applyGui(g, base)
	end
	for l, base in texts do
		l.TextSize = math.max(8, math.floor(base * s + 0.5))
	end
end)

return WorldLabel
