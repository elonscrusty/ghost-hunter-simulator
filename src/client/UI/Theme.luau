--!strict
-- Central UI configuration: colours, fonts, the typography scale, screen-scaling rules and
-- world-label (BillboardGui) sizes. All sizes are LOGICAL pixels: one UIScale per ScreenGui
-- converts them for the device (see Kit.Screen), so desktop, tablet and phone share one layout.
local C = Color3.fromRGB

local Theme = {
	Bg = C(28, 16, 50),
	Panel = C(46, 28, 82),
	Panel2 = C(64, 40, 112),
	Panel3 = C(86, 56, 146),
	Outline = C(18, 8, 36),
	Text = C(255, 255, 255), -- default text colour
	Muted = C(205, 190, 240),
	Ecto = C(90, 255, 160),
	Ecto2 = C(40, 220, 210),
	Good = C(90, 230, 120),
	Bad = C(255, 85, 110),
	Gold = C(255, 200, 60),
	Buttons = {
		Green = { C(110, 240, 120), C(40, 185, 95) },
		Purple = { C(175, 110, 255), C(115, 60, 220) },
		Orange = { C(255, 180, 60), C(245, 110, 40) },
		Blue = { C(90, 200, 255), C(50, 120, 240) },
		Red = { C(255, 110, 120), C(215, 50, 80) },
		Gray = { C(150, 145, 170), C(105, 100, 130) },
		Pink = { C(255, 130, 220), C(220, 70, 170) },
		Teal = { C(90, 235, 215), C(30, 160, 170) },
	} :: { [string]: { Color3 } },
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,

	-- Typography hierarchy (logical px). LARGE = major screen titles only.
	Type = {
		Banner = 36, -- centre-screen moments (NEW AREA UNLOCKED!)
		Title = 26, -- panel titles
		Currency = 24, -- the Ectoplasm counter
		Heading = 19, -- section headings, important values
		Button = 16, -- button labels
		Body = 15, -- names, prices, stats
		Small = 13, -- secondary info, descriptions
		Tiny = 11, -- captions under icons, badges
		Icon = 24, -- emoji icons on menu buttons
	} :: { [string]: number },

	-- Screen scaling: UIScale = clamp(viewport height / LandscapeRef) in landscape and
	-- clamp(viewport width / PortraitRef) in portrait. Desktop/laptop/tablet land at 1.0;
	-- a landscape phone (375-430 pt tall) lands at ~0.72-0.83: menu buttons ~42-48 pt,
	-- panel buttons ~32-36 pt, body text ~11-12 pt.
	Scale = {
		LandscapeRef = 520,
		PortraitRef = 600,
		Min = 0.55,
		Max = 1,
		CompactHeight = 650, -- logical height below which the HUD uses its compact layout
	},

	-- World labels (BillboardGui) in logical px; multiplied by the same device scale.
	World = {
		GhostLabel = Vector2.new(150, 38), -- name + Spirit bar with the Spirit value
		GhostLabelSelected = Vector2.new(190, 48), -- selected: bigger bar + numbers
		BossLabel = Vector2.new(190, 44), -- zone bosses: a more prominent bar
		BossLabelSelected = Vector2.new(240, 58),
		FullSizeDistance = 24, -- world labels are full size up to this distance from the camera...
		MinFactor = 0.62, -- ...then ease down to this fraction (never bigger) until MaxDistance hides them
		GhostMaxDistance = 55, -- unselected labels vanish beyond this (studs)
		BossMaxDistance = 90,
		SelectedMaxDistance = 160,
		CrewTag = Vector2.new(120, 16),
		CrewMaxDistance = 24,
		Marker = 56, -- tutorial arrow
	},
}

-- Text colour for a rarity: the brighter of its two colours, so dark rarities (Secret) stay
-- readable on the dark panels.
function Theme.RarityText(r: { Color: Color3, Color2: Color3 }): Color3
	local a, b = r.Color, r.Color2
	return if a.R + a.G + a.B >= b.R + b.G + b.B then a else b
end

return Theme
