--!strict
-- Colours, fonts and sizes for every UI element. Mobile-first: everything is designed for a
-- 620-pt-tall reference screen and scaled with one UIScale (see Kit.Screen).
local C = Color3.fromRGB
local Theme = {
	Bg = C(28, 16, 50),
	Panel = C(46, 28, 82),
	Panel2 = C(64, 40, 112),
	Panel3 = C(86, 56, 146),
	Outline = C(18, 8, 36),
	Text = C(255, 255, 255),
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
	} :: { [string]: { Color3 } },
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
	ReferenceHeight = 620,
}
return Theme
