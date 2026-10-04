--!strict
-- Pets floating beside every player (read from the player's "Pets" attribute, e.g.
-- "GlowWisp,BooBat", plus "PetNames": the server-filtered nicknames, one per line).
-- v2 lineup (23 pets): each pet id has its own look builder in LOOKS (haunted objects and a
-- few cute creatures; rarer pets are more elaborate). Every look is <= 30 anchored parts
-- with no collisions/queries/touch/shadows, built around the body centre (front = -Z) and
-- kept within the old ghost pets' bounds (~2 studs wide, ~2.4 tall), all moved by one
-- RenderStepped loop with a single BulkMoveTo. The original nine ids, rarities and bonuses are
-- unchanged (save data); only their looks and display names changed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local PetFollowers = {}

type Piece = { Part: Part, Offset: CFrame }
type Pet = { Pieces: { Piece }, Cur: CFrame?, Slot: number }
type Entry = { Pets: { Pet }, Conns: { RBXScriptConnection } }

-- beside/behind the shoulders (root space: +X right, +Z behind)
local SLOTS = { Vector3.new(-2.6, 1.4, 1.6), Vector3.new(2.6, 1.4, 1.6), Vector3.new(0, 2.6, 2.8) }
local FAR = 200 -- don't bother moving pets this far from the camera

local folder: Folder
local entries: { [Player]: Entry } = {}

local function part(pieces: { Piece }, shape: Enum.PartType, size: Vector3, color: Color3, offset: CFrame, neon: boolean?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	table.insert(pieces, { Part = p, Offset = offset })
	return p
end

local BALL, BLOCK, WEDGE, CYL = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Wedge, Enum.PartType.Cylinder

-- all look coordinates are in "pet units" (the old ghost body had diameter 3.5), shrunk by S
local S = 0.4
local EYE = Color3.fromRGB(25, 15, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local MOUTH = Color3.fromRGB(70, 20, 50)
local BLUSH = Color3.fromRGB(255, 150, 190)
local GOLD = Color3.fromRGB(255, 205, 60)
local CREAM = Color3.fromRGB(255, 244, 220)
local PINK = Color3.fromRGB(255, 170, 200)
local ECTO = Color3.fromRGB(120, 255, 150)
local IRON = Color3.fromRGB(62, 52, 82)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x * S, y * S, z * S)
end
local function rot(x: number, y: number, z: number): CFrame -- degrees
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

type FaceOpts = { Blush: boolean?, Mouth: boolean?, Eye: Color3? }
-- Builder kit handed to every look. Sizes are in pet units; cf comes from at()/rot().
type Kit = {
	ball: (d: number, cf: CFrame, col: Color3, neon: boolean?, tr: number?) -> Part,
	block: (x: number, y: number, z: number, cf: CFrame, col: Color3, neon: boolean?, tr: number?) -> Part,
	cyl: (h: number, d: number, cf: CFrame, col: Color3, neon: boolean?, tr: number?) -> Part, -- upright
	disc: (h: number, d: number, cf: CFrame, col: Color3, neon: boolean?, tr: number?) -> Part, -- faces the front
	wedge: (x: number, y: number, z: number, cf: CFrame, col: Color3, neon: boolean?) -> Part,
	-- triangle seen from the front (ears, horns, eyes); side = -1 tall edge on the right, 1 on the left
	spike: (cf: CFrame, w: number, h: number, side: number, col: Color3, neon: boolean?) -> Part,
	-- cute face on a front surface at depth z: eyes (+shine), blush, round mouth (scale k)
	face: (x: number, y: number, z: number, k: number, opts: FaceOpts?) -> (),
}
-- A look returns the light colour and the top of the model (pet units, for the name tag).
type Look = (K: Kit) -> (Color3, number)

local LOOKS: { [string]: Look } = {}

-- COMMON: a cute little candle with a ghost-green flame
LOOKS.GlowWisp = function(K)
	local WAX = Color3.fromRGB(236, 226, 255)
	K.cyl(3.4, 3.0, at(0, -0.2, 0), WAX) -- body (PrimaryPart)
	K.cyl(0.22, 2.5, at(0, 1.52, 0), Color3.fromRGB(214, 198, 248)) -- melted pool
	K.cyl(0.9, 0.5, at(-1.05, 1.0, -0.95), WAX) -- wax drips
	K.ball(0.62, at(-1.05, 0.5, -0.95), WAX)
	K.cyl(1.4, 0.5, at(1.2, 0.8, -0.65), WAX)
	K.ball(0.62, at(1.2, 0.1, -0.65), WAX)
	K.block(0.16, 0.5, 0.16, at(0, 1.85, 0), Color3.fromRGB(60, 50, 40)) -- wick
	K.ball(1.15, at(0, 2.55, 0), ECTO, true) -- flame
	K.ball(0.6, at(0.08, 3.2, 0.05), ECTO, true, 0.25)
	K.cyl(0.35, 4.1, at(0, -2.05, 0), Color3.fromRGB(235, 175, 80)) -- brass dish
	K.ball(0.75, at(2.2, -1.9, 0.2), Color3.fromRGB(235, 175, 80)) -- dish handle
	K.face(0, 0.1, -1.5, 1)
	return ECTO, 3.5
end

-- COMMON: a teacup with a little ghost peeking out of the tea
LOOKS.BooBat = function(K)
	local CUP = Color3.fromRGB(255, 160, 200)
	local CHINA = Color3.fromRGB(232, 222, 250)
	local GHOST = Color3.fromRGB(246, 242, 255)
	local STEAM = Color3.fromRGB(205, 160, 255)
	K.cyl(2.3, 3.4, at(0, -0.6, 0), CUP) -- cup (PrimaryPart)
	K.cyl(0.32, 3.6, at(0, 0.6, 0), CHINA) -- rim
	K.cyl(0.08, 3.1, at(0, 0.62, 0), Color3.fromRGB(190, 120, 90)) -- tea
	K.cyl(0.45, 2.2, at(0, -1.95, 0), CUP) -- foot
	K.cyl(0.25, 4.7, at(0, -2.25, 0), CHINA) -- saucer
	K.block(0.75, 0.28, 0.3, at(1.95, 0.05, 0), CHINA) -- handle loop
	K.block(0.28, 1.15, 0.3, at(2.3, -0.5, 0), CHINA)
	K.block(0.75, 0.28, 0.3, at(1.95, -1.05, 0), CHINA)
	K.ball(0.55, at(-0.9, -0.6, -1.62), WHITE) -- polka dots
	K.ball(0.45, at(0.7, -1.2, -1.6), WHITE)
	K.ball(2.4, at(0, 1.3, 0), GHOST) -- the ghost
	K.ball(0.75, at(-1.2, 0.85, -0.6), GHOST) -- arms on the rim
	K.ball(0.75, at(1.2, 0.85, -0.6), GHOST)
	K.face(0, 1.45, -1.12, 0.7)
	K.ball(0.55, at(0.9, 2.85, 0.4), STEAM, true, 0.3) -- steam puffs
	K.ball(0.38, at(1.25, 3.4, 0.55), STEAM, true, 0.4)
	return STEAM, 3.6
end

-- UNCOMMON: a grinning jack-o'-lantern sprite with a curly vine
LOOKS.JellyGhost = function(K)
	local ORANGE = Color3.fromRGB(255, 145, 45)
	local DEEP = Color3.fromRGB(235, 115, 30)
	local GLOW = Color3.fromRGB(255, 225, 90)
	K.ball(3.6, CFrame.identity, ORANGE) -- body (PrimaryPart)
	K.ball(3.0, at(-1.0, -0.15, 0.15), DEEP) -- ribs
	K.ball(3.0, at(1.0, -0.15, 0.15), DEEP)
	for _, s in { -1, 1 } do -- carved triangle eyes, lit from inside
		K.spike(at(0.62 * s - 0.2, 0.4, -1.72), 0.42, 0.75, -1, GLOW, true)
		K.spike(at(0.62 * s + 0.2, 0.4, -1.72), 0.42, 0.75, 1, GLOW, true)
		K.ball(0.5, at(1.25 * s, -0.3, -1.3), BLUSH)
	end
	K.block(1.5, 0.4, 0.3, at(0, -0.55, -1.68), GLOW, true) -- grin
	K.block(0.3, 0.22, 0.32, at(-0.3, -0.42, -1.74), DEEP) -- teeth
	K.block(0.3, 0.22, 0.32, at(0.35, -0.68, -1.74), DEEP)
	K.cyl(0.9, 0.6, at(0.1, 1.95, 0.1) * rot(0, 0, -12), Color3.fromRGB(110, 150, 60)) -- stem
	K.wedge(0.12, 0.6, 1.1, at(0.75, 1.95, 0.1) * rot(0, 90, -20), Color3.fromRGB(120, 205, 90)) -- leaf
	K.ball(0.32, at(-0.45, 2.15, 0.15), Color3.fromRGB(120, 205, 90)) -- curly vine
	K.ball(0.28, at(-0.8, 2.45, 0.15), Color3.fromRGB(120, 205, 90))
	K.ball(0.24, at(-0.6, 2.8, 0.15), Color3.fromRGB(120, 205, 90))
	return Color3.fromRGB(255, 170, 60), 3.0
end

-- UNCOMMON: a black kitty in a witch hat with a little ghost tail
LOOKS.PhantomKitty = function(K)
	local FUR = Color3.fromRGB(78, 62, 112)
	local HAT = Color3.fromRGB(125, 65, 200)
	K.ball(3.4, CFrame.identity, FUR) -- body (PrimaryPart)
	for _, s in { -1, 1 } do
		K.spike(at(1.15 * s, 1.5, -0.1) * rot(0, 0, -24 * s), 0.95, 1.3, s, FUR) -- ears
		K.spike(at(1.13 * s, 1.42, -0.22) * rot(0, 0, -24 * s), 0.5, 0.7, s, PINK)
		K.ball(0.8, at(0.7 * s, -1.4, -0.85), FUR) -- paws
	end
	K.face(0, 0.1, -1.6, 1.05, { Eye = Color3.fromRGB(110, 230, 140), Mouth = false })
	K.wedge(0.3, 0.22, 0.25, at(0, -0.25, -1.68) * rot(180, 0, 0), PINK) -- nose
	-- witch hat, tipped to one side
	local hat = at(-0.15, 1.75, 0.35) * rot(-14, 0, 10)
	K.cyl(0.18, 2.5, hat, HAT) -- brim
	K.cyl(0.3, 1.65, hat * at(0, 0.25, 0), ECTO) -- band
	K.cyl(0.6, 1.5, hat * at(0, 0.65, 0), HAT)
	K.cyl(0.7, 1.2, hat * at(0.05, 1.25, 0) * rot(0, 0, 8), HAT)
	K.cyl(0.6, 0.7, hat * at(0.2, 1.85, 0) * rot(0, 0, 22), HAT)
	K.ball(0.45, hat * at(0.42, 2.2, 0), GOLD) -- star tip
	K.ball(0.75, at(1.1, -0.9, 1.4), FUR) -- curly tail ending in a ghost wisp
	K.ball(0.6, at(1.5, -0.3, 1.7), FUR)
	K.ball(0.55, at(1.5, 0.35, 1.8), ECTO, true, 0.2)
	return Color3.fromRGB(150, 230, 170), 3.9
end

-- RARE: a living spellbook with a moon emblem and floating runes
LOOKS.MoonOwl = function(K)
	local COVER = Color3.fromRGB(105, 70, 190)
	local SPINE = Color3.fromRGB(80, 50, 150)
	local PAGE = Color3.fromRGB(255, 246, 225)
	local RUNE = Color3.fromRGB(120, 210, 255)
	local tilt = rot(4, 0, 6)
	K.block(2.9, 3.6, 1.0, tilt, PAGE) -- pages (PrimaryPart)
	K.block(3.2, 3.9, 0.28, tilt * at(-0.12, 0, -0.62), COVER) -- front cover
	K.block(3.2, 3.9, 0.28, tilt * at(-0.12, 0, 0.62), COVER) -- back cover
	K.cyl(3.9, 1.5, tilt * at(-1.6, 0, 0), SPINE) -- rounded spine
	K.block(0.55, 0.55, 0.3, tilt * at(1.25, 1.7, -0.7), GOLD) -- corner guards
	K.block(0.55, 0.55, 0.3, tilt * at(1.25, -1.7, -0.7), GOLD)
	K.block(0.4, 0.7, 1.6, tilt * at(1.55, 0, 0), GOLD) -- clasp
	K.ball(0.5, tilt * at(1.55, 0, -0.82), ECTO, true) -- clasp gem
	K.ball(0.75, tilt * at(-0.1, 1.15, -0.8), GOLD, true) -- moon emblem
	K.ball(0.6, tilt * at(0.08, 1.25, -0.88), COVER) -- carves the crescent
	K.block(0.3, 1.0, 0.06, tilt * at(0.6, -2.3, 0.1) * rot(0, 0, 8), Color3.fromRGB(255, 90, 130)) -- bookmark
	-- the face sits on the tilted cover
	local f = tilt * at(-0.1, -0.15, -0.78)
	for _, s in { -1, 1 } do
		K.ball(0.8, f * at(0.55 * s, 0, 0), EYE)
		K.ball(0.3, f * at(0.55 * s + 0.15, 0.15, -0.3), WHITE)
		K.ball(0.4, f * at(0.95 * s, -0.42, -0.05), BLUSH)
	end
	K.disc(0.2, 0.45, f * at(0, -0.55, 0), MOUTH)
	K.ball(0.42, at(2.5, 1.5, 0.2), RUNE, true, 0.1) -- floating runes
	K.ball(0.32, at(-2.7, 0.9, 0.3), RUNE, true, 0.15)
	K.ball(0.36, at(2.3, -1.4, 0.4), ECTO, true, 0.1)
	return Color3.fromRGB(140, 140, 255), 2.4
end

-- RARE: a bubbling cauldron with a cheeky imp swimming in the ecto
LOOKS.SpiritFox = function(K)
	local IMP = Color3.fromRGB(255, 120, 140)
	local HORN = Color3.fromRGB(255, 236, 170)
	K.ball(3.5, at(0, -0.75, 0), IRON) -- pot (PrimaryPart)
	K.cyl(0.42, 3.1, at(0, 0.85, 0), Color3.fromRGB(85, 72, 110)) -- rim
	K.cyl(0.1, 2.7, at(0, 1.07, 0), ECTO, true) -- brew
	for i = 0, 2 do -- legs
		local a = math.rad(90 + i * 120)
		K.ball(0.75, at(math.cos(a) * 1.1, -2.45, math.sin(a) * 1.1), IRON)
	end
	K.ball(0.55, at(-1.85, -0.2, 0), Color3.fromRGB(85, 72, 110)) -- side lugs
	K.ball(0.55, at(1.85, -0.2, 0), Color3.fromRGB(85, 72, 110))
	K.ball(2.1, at(0, 1.55, 0.1), IMP) -- the imp
	for _, s in { -1, 1 } do
		K.spike(at(0.6 * s, 2.65, 0.1), 0.45, 0.75, s, HORN)
		K.ball(0.6, at(1.1 * s, 1.15, -0.85), IMP) -- hands on the rim
	end
	K.face(0, 1.6, -0.92, 0.62)
	K.ball(0.5, at(-1.0, 2.2, 0.5), ECTO, true, 0.2) -- bubbles
	K.ball(0.32, at(-1.3, 2.75, 0.55), ECTO, true, 0.3)
	K.ball(0.5, at(0.7, 0.55, -1.52), Color3.fromRGB(150, 245, 160)) -- spill
	K.ball(0.45, at(1.45, 1.75, 0.8), IMP) -- pointy tail
	K.spike(at(1.75, 2.15, 0.8), 0.45, 0.5, 1, IMP)
	return ECTO, 3.1
end

-- EPIC: a mini flying saucer with a ghost pilot under a glass dome
LOOKS.SpookyDrake = function(K)
	local HULL = Color3.fromRGB(200, 196, 230)
	local TRIM = Color3.fromRGB(150, 90, 235)
	K.cyl(0.65, 5.0, at(0, -0.45, 0), HULL) -- saucer (PrimaryPart)
	K.ball(3.0, at(0, -0.85, 0), Color3.fromRGB(165, 160, 205)) -- belly
	K.cyl(0.3, 4.1, at(0, -0.02, 0), TRIM) -- trim ring
	K.ball(1.9, at(0, 0.55, 0), WHITE) -- ghost pilot
	K.face(0, 0.65, -0.92, 0.55, { Blush = true })
	K.ball(0.55, at(1.0, 1.15, -0.25), WHITE) -- waving arm
	K.ball(2.9, at(0, 0.45, 0), Color3.fromRGB(170, 235, 255), false, 0.6) -- glass dome
	K.cyl(0.9, 0.15, at(0, 2.15, 0), Color3.fromRGB(120, 115, 150)) -- antenna
	K.ball(0.42, at(0, 2.65, 0), ECTO, true)
	for i = 0, 5 do -- rim lights, ecto green / candy pink
		local a = math.rad(i * 60 + 15)
		K.ball(0.45, at(math.cos(a) * 2.45, -0.45, math.sin(a) * 2.45), if i % 2 == 0 then ECTO else Color3.fromRGB(255, 120, 210), true)
	end
	K.cyl(1.5, 1.6, at(0, -2.2, 0), ECTO, true, 0.75) -- tractor beam
	return Color3.fromRGB(180, 130, 255), 2.9
end

-- LEGENDARY: a tiny crowned reaper with a glowing scythe and orbiting souls
LOOKS.GhostPhoenix = function(K)
	local ROBE = Color3.fromRGB(92, 70, 150)
	local VOID = Color3.fromRGB(18, 10, 32)
	local SOUL = Color3.fromRGB(140, 255, 190)
	K.ball(3.0, at(0, 0.75, 0), ROBE) -- hood (PrimaryPart)
	K.ball(3.2, at(0, -0.8, 0.1), ROBE) -- robe
	K.ball(1.2, at(-0.55, -2.15, 0.3), ROBE) -- wispy hem
	K.ball(1.0, at(0.55, -2.3, 0.25), ROBE)
	K.ball(0.8, at(0, -2.6, 0.55), ROBE)
	K.ball(1.0, at(0.2, 2.05, 0.75), ROBE) -- hood point
	K.ball(2.15, at(0, 0.65, -0.62), VOID) -- dark face
	for _, s in { -1, 1 } do
		K.ball(0.5, at(0.4 * s, 0.75, -1.6), SOUL, true) -- glowing eyes
		K.ball(0.3, at(0.72 * s, 0.35, -1.55), BLUSH)
		K.spike(at(0.42 * s, 2.5, -0.1), 0.4, 0.7, s, GOLD) -- crown points
	end
	K.ball(0.4, at(0, 2.75, -0.2), Color3.fromRGB(255, 90, 140), true) -- crown gem
	K.cyl(0.32, 1.45, at(0, 2.2, -0.05), GOLD) -- crown band
	K.ball(0.5, at(0, -0.05, -1.55), GOLD) -- cloak clasp
	-- scythe in the right hand
	local sc = at(2.0, -0.3, -0.6) * rot(0, 0, -6)
	K.cyl(5.2, 0.28, sc, Color3.fromRGB(125, 85, 60))
	K.ball(0.75, at(1.7, -0.5, -0.95), CREAM) -- hand
	local top = sc * at(0, 2.55, 0)
	K.ball(0.4, top, GOLD) -- scythe cap
	K.block(1.9, 0.55, 0.16, top * at(-0.85, 0.05, 0) * rot(0, 0, -8), SOUL, true) -- curved blade
	K.block(1.2, 0.45, 0.16, top * at(-2.15, -0.35, 0) * rot(0, 0, -32), SOUL, true)
	K.ball(0.4, at(-2.3, 1.4, 0.4), Color3.fromRGB(120, 220, 255), true, 0.1) -- orbiting souls
	K.ball(0.34, at(-2.0, -1.2, -0.6), Color3.fromRGB(255, 140, 220), true, 0.1)
	return Color3.fromRGB(255, 200, 90), 3.3
end

-- LEGENDARY (event): a haunted lantern with a little flame spirit inside
LOOKS.LanternSpirit = function(K)
	local FLAME = Color3.fromRGB(255, 210, 90)
	local BOW = Color3.fromRGB(170, 90, 255)
	K.cyl(2.9, 2.3, at(0, -0.1, 0), Color3.fromRGB(255, 240, 200), false, 0.82) -- glass (PrimaryPart)
	K.ball(1.7, at(0, -0.35, 0), FLAME) -- flame spirit
	K.ball(0.95, at(0.05, 0.6, 0.05), Color3.fromRGB(255, 170, 60), true)
	for _, s in { -1, 1 } do
		K.ball(0.42, at(0.33 * s, -0.25, -0.72), EYE)
		K.ball(0.3, at(0.62 * s, -0.55, -0.6), BLUSH)
	end
	K.disc(0.15, 0.3, at(0, -0.62, -0.8), MOUTH)
	for _, x in { -1, 1 } do -- cage bars
		for _, z in { -1, 1 } do
			K.block(0.22, 2.9, 0.22, at(0.82 * x, -0.1, 0.82 * z), IRON)
		end
	end
	K.cyl(0.42, 2.7, at(0, 1.55, 0), IRON) -- roof
	K.cyl(0.42, 1.7, at(0, 1.95, 0), IRON)
	K.block(0.8, 0.22, 0.22, at(0, 2.95, 0), IRON) -- handle arch
	K.block(0.22, 0.8, 0.22, at(-0.5, 2.55, 0) * rot(0, 0, -25), IRON)
	K.block(0.22, 0.8, 0.22, at(0.5, 2.55, 0) * rot(0, 0, 25), IRON)
	K.cyl(0.42, 2.7, at(0, -1.75, 0), IRON) -- base
	K.cyl(0.3, 1.8, at(0, -2.1, 0), IRON)
	K.ball(0.55, at(0, 2.05, -0.95), BOW) -- event bow
	K.wedge(0.15, 0.55, 0.6, at(-0.45, 2.05, -0.95) * rot(0, 90, 0), BOW)
	K.wedge(0.15, 0.55, 0.6, at(0.45, 2.05, -0.95) * rot(0, -90, 0), BOW)
	return Color3.fromRGB(255, 200, 80), 3.1
end

-- COMMON: a wobbly ecto slime with bubbles inside and a puddle
LOOKS.EctoSlime = function(K)
	local SLIME = Color3.fromRGB(120, 235, 140)
	local DEEP = Color3.fromRGB(80, 200, 110)
	K.ball(3.6, at(0, -0.5, 0), SLIME) -- body (PrimaryPart)
	K.ball(2.6, at(0, 0.7, 0.1), SLIME)
	K.ball(1.2, at(0, 1.85, 0.2), SLIME) -- the little top curl
	K.ball(0.7, at(0.3, 2.5, 0.25), SLIME)
	K.cyl(0.3, 4.6, at(0, -2.15, 0), DEEP) -- puddle
	K.ball(0.9, at(-1.6, -1.6, -0.6), SLIME) -- drips
	K.ball(0.7, at(1.7, -1.75, -0.3), SLIME)
	K.ball(0.7, at(-0.8, 1.15, -0.9), WHITE, false, 0.35) -- shine
	K.ball(0.45, at(1.15, 0.25, -1.15), ECTO, true, 0.2) -- bubbles inside
	K.ball(0.32, at(0.95, -1.15, -1.45), ECTO, true, 0.2)
	K.face(0, -0.15, -1.7, 1)
	return ECTO, 2.9
end

-- COMMON: a ghost-shaped balloon with little bat wings, on a string
LOOKS.BooBalloon = function(K)
	local SKY = Color3.fromRGB(150, 210, 255)
	local KNOT = Color3.fromRGB(110, 170, 235)
	K.ball(3.4, at(0, 0.9, 0), SKY) -- balloon (PrimaryPart)
	for i, x in { -0.9, 0, 0.9 } do -- scalloped ghost hem
		K.ball(1.1, at(x, if i == 2 then -0.65 else -0.45, 0.1), SKY)
	end
	K.ball(0.5, at(0, -1.15, 0.1), KNOT) -- knot
	K.block(0.1, 1.6, 0.1, at(0.08, -2.0, 0.1) * rot(0, 0, 5), Color3.fromRGB(240, 240, 250)) -- string
	K.ball(0.45, at(0.15, -2.85, 0.1), GOLD, true) -- star charm
	K.ball(0.8, at(-0.8, 1.6, -1.05), WHITE, false, 0.3) -- shine
	for _, s in { -1, 1 } do
		K.spike(at(1.95 * s, 1.45, 0.2) * rot(0, 0, -15 * s), 1.1, 0.95, s, Color3.fromRGB(120, 95, 185)) -- bat wings
		K.spike(at(2.0 * s, 1.0, 0.2) * rot(0, 0, 10 * s), 0.8, 0.6, s, Color3.fromRGB(120, 95, 185))
	end
	K.face(0, 0.75, -1.65, 1)
	return Color3.fromRGB(170, 220, 255), 2.6
end

-- UNCOMMON: a patchwork teddy with one button eye and a ghost wisp escaping a seam
LOOKS.CursedTeddy = function(K)
	local FUR = Color3.fromRGB(160, 120, 200)
	local INNER = Color3.fromRGB(255, 190, 215)
	local MUZZLE = Color3.fromRGB(245, 225, 235)
	local STITCH = Color3.fromRGB(45, 30, 60)
	K.ball(2.7, at(0, 0.7, 0), FUR) -- head (PrimaryPart)
	K.ball(2.6, at(0, -1.1, 0.15), FUR) -- tummy
	for _, s in { -1, 1 } do
		K.ball(1.0, at(1.05 * s, 1.85, 0.1), FUR) -- ears
		K.ball(0.55, at(1.05 * s, 1.85, -0.25), INNER)
		K.ball(0.9, at(1.3 * s, -0.8, -0.35), FUR) -- arms
		K.ball(1.0, at(0.65 * s, -2.15, -0.35), FUR) -- feet
		K.ball(0.35, at(0.95 * s, 0.4, -1.0), BLUSH)
	end
	K.ball(1.1, at(0, 0.3, -1.05), MUZZLE) -- muzzle
	K.ball(0.38, at(0, 0.55, -1.55), STITCH) -- nose
	K.block(0.42, 0.08, 0.1, at(0, 0.05, -1.55), STITCH) -- stitched smile
	K.disc(0.18, 0.62, at(0.55, 1.0, -1.18), Color3.fromRGB(110, 220, 210)) -- button eye
	K.block(0.6, 0.13, 0.1, at(-0.55, 1.0, -1.22) * rot(0, 0, 45), STITCH) -- stitched X eye
	K.block(0.6, 0.13, 0.1, at(-0.55, 1.0, -1.22) * rot(0, 0, -45), STITCH)
	K.block(0.75, 0.75, 0.1, at(0.55, -0.8, -1.33) * rot(0, 0, 15), Color3.fromRGB(150, 220, 140)) -- patch
	K.ball(0.5, at(-0.85, 2.3, 0.35), ECTO, true, 0.15) -- ghost wisp
	return Color3.fromRGB(190, 150, 255), 2.6
end

-- UNCOMMON: a round little mummy with glowing eyes peeking out of its wraps
LOOKS.MiniMummy = function(K)
	local WRAP = Color3.fromRGB(235, 225, 195)
	local WRAP2 = Color3.fromRGB(212, 198, 162)
	local GAP = Color3.fromRGB(55, 40, 45)
	local EYEGLOW = Color3.fromRGB(200, 255, 120)
	K.ball(3.4, CFrame.identity, WRAP) -- body (PrimaryPart)
	K.cyl(0.35, 3.4, at(0, -0.4, 0) * rot(0, 0, 8), WRAP2) -- bandage bands
	K.cyl(0.35, 2.95, at(0, 0.95, 0) * rot(0, 0, -7), WRAP2)
	K.cyl(0.35, 2.85, at(0, -1.1, 0) * rot(0, 0, 5), WRAP2)
	K.cyl(0.7, 3.44, at(0, 0.35, 0), GAP) -- the gap the eyes peek through
	for _, s in { -1, 1 } do
		K.ball(0.6, at(0.5 * s, 0.35, -1.72), EYEGLOW, true)
		K.ball(0.2, at(0.5 * s + 0.12, 0.47, -1.98), WHITE)
		K.ball(0.4, at(1.0 * s, -0.25, -1.4), BLUSH)
		K.ball(0.9, at(1.45 * s, -0.4, -1.0), WRAP) -- arms reaching for a hug
		K.ball(0.8, at(0.6 * s, -1.65, -0.5), WRAP) -- feet
	end
	K.disc(0.2, 0.42, at(0, -0.45, -1.66), MOUTH)
	K.block(0.45, 0.12, 1.3, at(0.9, 1.35, 1.3) * rot(25, 0, 0), WRAP2) -- trailing wrap
	K.ball(0.45, at(-0.95, 2.0, 0.3), EYEGLOW, true, 0.2) -- ghost wisps
	K.ball(0.3, at(-1.25, 2.45, 0.35), EYEGLOW, true, 0.35)
	return EYEGLOW, 2.7
end

-- RARE: an ornate hand mirror with a ghost looking back from the glass
LOOKS.HauntedMirror = function(K)
	local GLASS = Color3.fromRGB(200, 190, 255)
	local LILAC = Color3.fromRGB(215, 160, 255)
	K.disc(0.3, 3.5, at(0, 0.8, 0.08), GOLD) -- frame (PrimaryPart)
	K.disc(0.2, 3.0, at(0, 0.8, 0), GLASS) -- glass
	K.disc(0.1, 1.9, at(0, 1.0, -0.13), WHITE, false, 0.15) -- the ghost in the glass
	K.disc(0.1, 1.1, at(0.35, -0.05, -0.12), WHITE, false, 0.15)
	K.face(0, 0.95, -0.35, 0.7)
	K.ball(0.7, at(0, 2.75, 0), Color3.fromRGB(255, 90, 170), true) -- crest gem
	K.spike(at(-0.5, 2.6, 0.05), 0.45, 0.7, -1, GOLD)
	K.spike(at(0.5, 2.6, 0.05), 0.45, 0.7, 1, GOLD)
	K.ball(0.55, at(-1.85, 0.8, 0.05), GOLD) -- side knobs
	K.ball(0.55, at(1.85, 0.8, 0.05), GOLD)
	K.ball(0.6, at(0, -0.95, 0.05), GOLD) -- neck
	K.cyl(1.4, 0.5, at(0, -1.65, 0.05), GOLD) -- handle
	K.ball(0.7, at(0, -2.45, 0.05), Color3.fromRGB(150, 90, 235)) -- handle knob
	K.ball(0.35, at(2.15, 2.1, -0.2), LILAC, true, 0.1) -- sparkles
	K.ball(0.3, at(-2.2, -0.5, -0.1), LILAC, true, 0.1)
	return Color3.fromRGB(200, 150, 255), 3.1
end

-- RARE: a treasure chest mimic, lid open, tongue out, ecto gems spilling
LOOKS.TreasureMimic = function(K)
	local WOOD = Color3.fromRGB(150, 90, 50)
	local DARKWOOD = Color3.fromRGB(110, 62, 36)
	local TONGUE = Color3.fromRGB(255, 120, 160)
	K.block(3.6, 1.9, 2.6, at(0, -0.9, 0), WOOD) -- chest (PrimaryPart)
	local lid = at(0, 0.05, 1.3) * rot(40, 0, 0) -- hinge at the back top edge
	K.block(3.6, 0.6, 2.6, lid * at(0, 0.3, -1.3), WOOD)
	K.block(0.4, 0.66, 2.66, lid * at(-1.2, 0.3, -1.3), GOLD) -- lid trims
	K.block(0.4, 0.66, 2.66, lid * at(1.2, 0.3, -1.3), GOLD)
	K.block(0.4, 1.95, 2.65, at(-1.2, -0.9, 0), GOLD) -- chest trims
	K.block(0.4, 1.95, 2.65, at(1.2, -0.9, 0), GOLD)
	K.block(3.2, 0.12, 2.2, at(0, 0.02, 0), MOUTH) -- dark inside
	for i, x in { -0.75, 0.75 } do
		K.spike(at(x, 0.3, -1.15), 0.45, 0.5, if i == 1 then -1 else 1, WHITE) -- bottom teeth
		K.spike(lid * at(x, -0.2, -2.35) * rot(0, 0, 180), 0.45, 0.45, if i == 1 then 1 else -1, WHITE) -- top teeth
		K.ball(0.75, lid * at(x * 0.85, 0.35, -2.7), EYE) -- eyes on the lid
		K.ball(0.28, lid * at(x * 0.85 + 0.15, 0.5, -2.98), WHITE)
		K.ball(0.7, at(x * 1.7, -1.95, -0.8), DARKWOOD) -- stubby feet
	end
	K.ball(1.1, at(0.35, 0.05, -1.2), TONGUE) -- tongue
	K.ball(0.8, at(0.45, -0.45, -1.5), TONGUE)
	K.ball(0.7, at(-1.0, 0.3, -0.4), ECTO, true) -- gem inside
	K.ball(0.45, at(2.2, 1.4, 0.2), ECTO, true, 0.1) -- floating ecto gems
	K.ball(0.35, at(-2.1, 1.8, 0.4), ECTO, true, 0.1)
	return ECTO, 2.2
end

-- EPIC: a haunted alarm clock with bat wings, a ghost face and glowing hands
LOOKS.HauntedClock = function(K)
	local CASE = Color3.fromRGB(120, 70, 200)
	local HAND = Color3.fromRGB(255, 120, 210)
	local WING = Color3.fromRGB(80, 50, 140)
	K.disc(1.4, 3.6, at(0, 0.1, 0), CASE) -- case (PrimaryPart)
	K.disc(0.12, 3.25, at(0, 0.1, -0.66), ECTO, true) -- glowing rim
	K.disc(0.2, 3.0, at(0, 0.1, -0.68), CREAM) -- dial
	for _, s in { -1, 1 } do
		K.ball(1.2, at(1.15 * s, 1.95, 0.1), GOLD) -- bells
		K.block(0.3, 0.9, 0.3, at(1.0 * s, -1.8, 0) * rot(0, 0, 25 * s), GOLD) -- legs
		K.spike(at(2.0 * s, 0.85, 0.2) * rot(0, 0, -15 * s), 1.1, 1.0, s, WING) -- bat wings
	end
	local hub = at(0, 0.1, -0.84)
	K.block(0.15, 1.1, 0.08, hub * rot(0, 0, -30) * at(0, 0.55, 0), HAND, true) -- minute hand
	K.block(0.18, 0.7, 0.08, hub * rot(0, 0, 75) * at(0, 0.35, 0), HAND, true) -- hour hand
	K.ball(0.3, hub, GOLD)
	for _, p in { Vector2.new(0, 1.3), Vector2.new(1.25, 0.1), Vector2.new(-1.25, 0.1), Vector2.new(0, -1.15) } do
		K.block(0.16, 0.36, 0.08, at(p.X, p.Y, -0.8), Color3.fromRGB(90, 60, 130)) -- 12 / 3 / 9 / 6
	end
	K.face(0, -0.4, -0.95, 0.65)
	K.ball(0.4, at(-2.2, 2.2, -0.2), HAND, true, 0.15) -- time sparkle
	return Color3.fromRGB(255, 120, 210), 2.6
end

-- EPIC: a little ghost steam engine puffing ecto smoke, with a ghost driver
LOOKS.GhostTrain = function(K)
	local CAB = Color3.fromRGB(130, 60, 190)
	local BOILER = Color3.fromRGB(70, 60, 95)
	local WHEEL = Color3.fromRGB(255, 120, 210)
	K.disc(3.0, 2.4, at(0, -0.2, -0.4), BOILER) -- boiler (PrimaryPart)
	K.disc(0.2, 2.3, at(0, -0.2, -1.95), CREAM) -- ghost face plate
	K.face(0, -0.15, -2.1, 0.8)
	K.block(2.6, 2.4, 1.6, at(0, 0.3, 1.6), CAB) -- cab
	K.block(3.0, 0.3, 2.0, at(0, 1.6, 1.6), GOLD) -- cab roof
	K.ball(1.2, at(0.55, 0.95, 0.75), WHITE) -- ghost driver peeking out
	K.cyl(1.0, 0.7, at(0, 1.35, -1.2), BOILER) -- chimney
	K.cyl(0.3, 1.05, at(0, 1.9, -1.2), GOLD)
	K.ball(0.8, at(0.2, 2.55, -1.0), ECTO, true, 0.3) -- ecto smoke
	K.ball(0.6, at(0.7, 3.1, -0.6), ECTO, true, 0.4)
	K.ball(0.45, at(1.15, 3.5, -0.3), ECTO, true, 0.5)
	K.ball(0.8, at(0, 1.0, 0.1), GOLD) -- steam dome
	for _, x in { -1.25, 1.25 } do -- wheels
		for _, z in { -1.0, 1.4 } do
			K.cyl(0.3, 1.2, at(x, -1.55, z) * rot(0, 0, -90), WHEEL)
		end
	end
	K.wedge(2.2, 0.7, 0.9, at(0, -1.55, -2.1), GOLD) -- cowcatcher
	K.ball(0.5, at(0, 1.05, -1.75), Color3.fromRGB(255, 230, 120), true) -- headlamp
	return Color3.fromRGB(120, 255, 150), 3.7
end

-- LEGENDARY: a glowing crystal skull with a crystal crown and orbiting gems
LOOKS.CrystalSkull = function(K)
	local CRYSTAL = Color3.fromRGB(150, 230, 255)
	local CORE = Color3.fromRGB(120, 220, 255)
	local VOID = Color3.fromRGB(30, 20, 60)
	local GEM = Color3.fromRGB(255, 110, 200)
	K.ball(3.4, at(0, 0.4, 0), CRYSTAL, false, 0.25) -- skull (PrimaryPart)
	K.ball(1.6, at(0, 0.5, 0.25), CORE, true) -- glowing core
	K.block(2.0, 0.9, 1.6, at(0, -1.35, -0.35), CRYSTAL, false, 0.25) -- jaw
	for _, s in { -1, 1 } do
		K.ball(1.2, at(0.85 * s, -0.75, -0.45), CRYSTAL, false, 0.25) -- cheeks
		K.ball(1.0, at(0.62 * s, 0.25, -1.3), VOID) -- big eye sockets
		K.ball(0.45, at(0.62 * s, 0.22, -1.72), GEM, true) -- glowing pupils
		K.ball(0.22, at(0.62 * s + 0.15, 0.42, -1.85), WHITE)
		K.ball(0.35, at(1.15 * s, -0.4, -1.15), BLUSH)
	end
	K.wedge(0.3, 0.35, 0.3, at(0, -0.4, -1.62) * rot(180, 0, 0), VOID) -- nose
	for _, x in { -0.45, 0, 0.45 } do
		K.block(0.38, 0.34, 0.15, at(x, -1.05, -1.17), WHITE) -- teeth
	end
	K.cyl(0.35, 1.9, at(0, 1.95, 0.05), GOLD) -- crown band
	K.spike(at(0, 2.75, 0.05), 0.7, 1.3, 1, CORE, true) -- crystal crown
	K.spike(at(-0.65, 2.5, 0.1) * rot(0, 0, 18), 0.5, 1.0, -1, CORE, true)
	K.spike(at(0.65, 2.5, 0.1) * rot(0, 0, -18), 0.5, 1.0, 1, CORE, true)
	K.ball(0.45, at(2.3, 1.2, 0.2), GEM, true, 0.1) -- orbiting gems
	K.ball(0.4, at(-2.3, 0.3, -0.3), ECTO, true, 0.1)
	K.ball(0.38, at(1.9, -1.6, 0.4), GOLD, true, 0.1)
	return CORE, 3.3
end

-- Cursed Egg top tier (unlocked at Boss Tower checkpoint 50): 2 Mythic, 2 Secret, 1 Ultra
-- MYTHIC: a tiny ghost king sitting on a floating crimson-and-gold throne, holding a scepter
LOOKS.PhantomKing = function(K)
	local GHOST = Color3.fromRGB(246, 242, 255)
	local VELVET = Color3.fromRGB(205, 45, 90)
	local RUBY = Color3.fromRGB(255, 70, 120)
	K.ball(2.5, at(0, 0.55, -0.35), GHOST) -- ghost king (PrimaryPart)
	K.ball(1.9, at(0, -0.4, -0.6), GHOST) -- ghost lap
	K.face(0, 0.5, -1.52, 0.8)
	K.cyl(0.4, 1.35, at(0, 1.85, -0.35), GOLD) -- crown band
	K.spike(at(0, 2.45, -0.35), 0.5, 0.9, 1, GOLD) -- crown points
	for _, s in { -1, 1 } do
		K.spike(at(0.48 * s, 2.3, -0.35), 0.4, 0.65, s, GOLD)
	end
	K.ball(0.38, at(0, 1.85, -1.05), RUBY, true) -- crown gem
	-- throne
	K.block(3.2, 3.4, 0.5, at(0, 0.75, 1.0), VELVET) -- back
	K.block(3.6, 0.45, 0.75, at(0, 2.55, 1.0), GOLD) -- top rail
	for _, s in { -1, 1 } do
		K.ball(0.7, at(1.8 * s, 2.85, 1.0), GOLD) -- finials
		K.block(0.55, 1.0, 2.5, at(1.65 * s, -0.55, 0.05), GOLD) -- armrests
	end
	K.ball(0.7, at(0, 3.0, 0.85), RUBY, true) -- throne jewel
	K.block(3.4, 0.8, 2.7, at(0, -1.3, 0.05), GOLD) -- seat base
	K.block(3.0, 0.35, 2.3, at(0, -0.8, -0.05), VELVET) -- cushion
	K.cyl(0.15, 3.2, at(0, -2.2, 0.05), RUBY, true, 0.35) -- floating glow under the throne
	-- scepter in the right hand
	K.ball(0.62, at(1.05, -0.2, -1.3), GHOST) -- hand
	K.cyl(2.4, 0.2, at(1.25, 0.45, -1.35) * rot(0, 0, -12), GOLD)
	K.ball(0.6, at(1.52, 1.75, -1.35), Color3.fromRGB(255, 120, 200), true) -- scepter orb
	K.ball(0.45, at(-2.45, 1.6, -0.3), GOLD, true, 0.05) -- orbiting coin-sparks
	K.ball(0.4, at(2.55, -1.0, 0.2), RUBY, true, 0.1)
	return Color3.fromRGB(255, 90, 130), 3.35
end

-- MYTHIC: a mini merry-go-round: tiny ghosts ride a pumpkin, a bat and a teacup under a striped
-- canopy ringed with warm bulbs
LOOKS.GhostCarousel = function(K)
	local GHOST = Color3.fromRGB(246, 242, 255)
	local CANDY = Color3.fromRGB(255, 120, 170)
	local PLUM = Color3.fromRGB(120, 60, 170)
	local ORANGE = Color3.fromRGB(255, 145, 45)
	local BAT = Color3.fromRGB(85, 60, 125)
	local BULB = Color3.fromRGB(255, 225, 140)
	K.cyl(4.2, 0.45, CFrame.identity, GOLD) -- centre pole (PrimaryPart)
	K.cyl(0.45, 4.4, at(0, -1.85, 0), PLUM) -- platform
	K.cyl(0.2, 4.6, at(0, -2.1, 0), GOLD) -- gold trim
	K.cyl(0.4, 4.6, at(0, 1.9, 0), CANDY) -- striped canopy
	K.cyl(0.35, 3.4, at(0, 2.25, 0), CREAM)
	K.cyl(0.3, 2.2, at(0, 2.55, 0), CANDY)
	K.ball(0.6, at(0, 2.95, 0), GOLD) -- top finial
	for i = 0, 3 do -- warm bulbs around the canopy rim
		local a = math.rad(i * 90 + 45)
		K.ball(0.35, at(math.cos(a) * 2.3, 1.62, math.sin(a) * 2.3), BULB, true, 0.2)
	end
	-- front rider: a ghost on a pumpkin
	K.cyl(3.5, 0.15, at(0, 0, -1.5), GOLD)
	K.ball(1.1, at(0, -0.95, -1.5), ORANGE)
	K.ball(1.2, at(0, -0.1, -1.5), GHOST)
	K.face(0, -0.05, -2.08, 0.38)
	-- left rider: a ghost on a little bat
	K.cyl(3.5, 0.15, at(-1.3, 0, 0.75), GOLD)
	K.ball(0.95, at(-1.3, -0.55, 0.75), BAT)
	K.spike(at(-1.85, -0.45, 0.75), 0.6, 0.5, -1, BAT)
	K.spike(at(-0.75, -0.45, 0.75), 0.6, 0.5, 1, BAT)
	K.ball(1.0, at(-1.3, 0.25, 0.75), GHOST)
	-- right rider: a ghost in a teacup
	K.cyl(3.5, 0.15, at(1.3, 0, 0.75), GOLD)
	K.cyl(0.7, 1.1, at(1.3, -1.15, 0.75), PINK)
	K.ball(1.0, at(1.3, -0.45, 0.75), GHOST)
	return Color3.fromRGB(255, 200, 130), 3.25
end

-- SECRET: an open music box: a tiny ghost ballerina in a pink tutu twirls on a gold stage,
-- with floating music notes and a gold wind-up key
LOOKS.GhostMusicBox = function(K)
	local WOOD = Color3.fromRGB(150, 60, 110)
	local VELVET = Color3.fromRGB(255, 160, 205)
	local GHOST = Color3.fromRGB(246, 242, 255)
	local TUTU = Color3.fromRGB(255, 185, 220)
	local NOTE = Color3.fromRGB(205, 175, 255)
	K.block(4.0, 1.6, 2.8, at(0, -1.3, 0), WOOD) -- box (PrimaryPart)
	K.block(4.0, 2.4, 0.25, at(0, 0.55, 1.5) * rot(15, 0, 0), WOOD) -- open lid
	K.block(3.5, 2.0, 0.08, at(0, 0.55, 1.36) * rot(15, 0, 0), VELVET) -- velvet inside the lid
	K.block(4.15, 0.2, 2.95, at(0, -0.5, 0), GOLD) -- gold trims
	K.block(4.15, 0.25, 2.95, at(0, -2.15, 0), GOLD)
	K.ball(0.5, at(0, -1.3, -1.42), GOLD) -- front medallion
	K.block(3.7, 0.1, 2.5, at(0, -0.42, 0), VELVET) -- velvet top
	K.cyl(0.25, 1.2, at(0, -0.3, -0.2), GOLD) -- little stage
	-- the ghost ballerina, arms up
	K.ball(1.5, at(0, 0.85, -0.2), GHOST)
	K.cyl(0.25, 2.0, at(0, 0.25, -0.2), TUTU) -- tutu
	K.cyl(0.18, 1.6, at(0, 0.1, -0.2), VELVET)
	K.ball(0.55, at(0, -0.05, -0.2), GHOST) -- wispy tail on the stage
	K.ball(0.38, at(-0.55, 1.75, -0.2), GHOST) -- hands over the head
	K.ball(0.38, at(0.55, 1.75, -0.2), GHOST)
	K.ball(0.3, at(0.45, 1.45, -0.6), Color3.fromRGB(255, 110, 170)) -- hair bow
	K.face(0, 0.85, -0.92, 0.5)
	-- floating music notes
	K.ball(0.45, at(-2.3, 1.0, -0.3), NOTE, true, 0.2)
	K.block(0.1, 0.8, 0.1, at(-2.12, 1.4, -0.3), NOTE, true, 0.2)
	K.ball(0.4, at(2.2, 1.9, 0), NOTE, true, 0.2)
	K.block(0.1, 0.7, 0.1, at(2.36, 2.25, 0), NOTE, true, 0.2)
	-- gold wind-up key on the side
	K.block(0.4, 0.15, 0.15, at(2.2, -1.3, 0), GOLD)
	K.block(0.1, 0.6, 0.6, at(2.45, -1.3, 0), GOLD)
	return Color3.fromRGB(255, 175, 220), 2.7
end

-- SECRET: a ghost galleon with glowing sails sailing tiny waves inside a corked glass bottle
LOOKS.GhostShipBottle = function(K)
	local GLASS = Color3.fromRGB(190, 240, 255)
	local SEA = Color3.fromRGB(60, 200, 230)
	local HULL = Color3.fromRGB(125, 70, 185)
	local MAST = Color3.fromRGB(120, 85, 70)
	local CORK = Color3.fromRGB(190, 140, 90)
	local GHOST = Color3.fromRGB(246, 242, 255)
	local B = at(-0.45, 0, 0) * rot(0, 0, 10) -- the bottle lies on its side, neck up-right
	local X = rot(0, 0, -90) -- turns an upright K.cyl to lie along the bottle
	K.cyl(3.0, 2.5, B * X, GLASS, false, 0.8) -- glass (PrimaryPart)
	K.ball(2.5, B * at(-1.5, 0, 0), GLASS, false, 0.8) -- rounded bottom
	K.ball(2.5, B * at(1.5, 0, 0), GLASS, false, 0.8) -- shoulder
	K.cyl(0.9, 1.1, B * at(2.95, 0, 0) * X, GLASS, false, 0.6) -- neck
	K.cyl(0.75, 0.95, B * at(3.6, 0, 0) * X, CORK) -- cork
	K.cyl(0.22, 1.25, B * at(3.05, 0, 0) * X, GOLD) -- gold seal band
	K.block(3.3, 0.35, 1.6, B * at(-0.1, -0.95, 0), Color3.fromRGB(30, 90, 190), false, 0.1) -- tiny sea
	K.ball(0.55, B * at(-1.35, -0.78, -0.55), SEA, false, 0.1) -- waves
	K.ball(0.5, B * at(0.45, -0.8, -0.6), SEA, false, 0.1)
	K.block(2.1, 0.75, 0.95, B * at(-0.15, -0.3, 0), HULL) -- hull
	K.block(2.15, 0.16, 1.0, B * at(-0.15, -0.05, 0), GOLD) -- gold rail
	K.wedge(0.95, 0.65, 0.7, B * at(1.25, -0.35, 0) * rot(0, -90, 0), HULL) -- bow
	K.block(0.65, 0.4, 0.95, B * at(-0.9, 0.15, 0), Color3.fromRGB(150, 95, 210)) -- stern deck
	K.block(0.1, 1.35, 0.1, B * at(-0.1, 0.4, 0.1), MAST) -- masts
	K.block(0.1, 1.0, 0.1, B * at(0.7, 0.2, 0.1), MAST)
	K.block(0.95, 0.6, 0.08, B * at(-0.1, 0.3, 0.02), Color3.fromRGB(205, 255, 225), false, 0.15) -- ghostly sails (top one glows)
	K.block(0.7, 0.4, 0.08, B * at(-0.1, 0.85, 0.02), ECTO, true, 0.25)
	K.block(0.65, 0.5, 0.08, B * at(0.7, 0.25, 0.02), Color3.fromRGB(205, 255, 225), false, 0.15)
	K.spike(B * at(0.05, 1.0, 0.1), 0.3, 0.22, 1, Color3.fromRGB(255, 110, 200), true) -- flag
	K.ball(0.3, B * at(1.55, -0.1, -0.2), Color3.fromRGB(255, 220, 110), true) -- bow lantern
	local cap = B * at(-1.0, 0.72, -0.1)
	K.ball(0.85, cap, GHOST) -- ghost captain
	local f = cap.Position / S
	K.face(f.X, f.Y, f.Z - 0.36, 0.38)
	K.ball(0.42, at(-2.9, 1.35, -0.3), ECTO, true, 0.1) -- floating sparkles
	K.ball(0.34, at(2.3, -1.45, 0.2), Color3.fromRGB(255, 110, 200), true, 0.1)
	return Color3.fromRGB(170, 140, 255), 1.9
end

-- ULTRA: a tiny ghost waving from the wicker basket of a mini hot-air balloon with a pastel
-- purple/gold/mint striped envelope, a crescent moon emblem, little lanterns and orbiting stars
LOOKS.GhostBalloonRide = function(K)
	local LILAC = Color3.fromRGB(190, 160, 255)
	local SOFTGOLD = Color3.fromRGB(255, 215, 120)
	local MINT = Color3.fromRGB(150, 240, 205)
	local WICKER = Color3.fromRGB(190, 135, 80)
	local WICKER2 = Color3.fromRGB(150, 100, 60)
	local GHOST = Color3.fromRGB(246, 242, 255)
	local LANTERN = Color3.fromRGB(255, 205, 120)
	K.ball(3.6, at(0, 1.2, 0), LILAC) -- envelope (PrimaryPart)
	K.ball(2.2, at(0, -0.1, 0), LILAC) -- tapered bottom
	K.cyl(0.4, 1.3, at(0, -0.85, 0), SOFTGOLD) -- throat
	K.cyl(0.4, 3.32, at(0, 0.45, 0), SOFTGOLD) -- stripes
	K.cyl(0.4, 3.32, at(0, 1.95, 0), MINT)
	K.cyl(0.25, 2.42, at(0, 2.55, 0), SOFTGOLD)
	K.disc(0.12, 0.9, at(0, 1.2, -1.8), SOFTGOLD) -- crescent moon emblem...
	K.disc(0.14, 0.75, at(0.22, 1.3, -1.83), LILAC) -- ...cut by a lilac disc
	for _, x in { -0.65, 0.65 } do -- ropes
		for _, z in { -0.55, 0.55 } do
			K.block(0.08, 0.8, 0.08, at(x, -1.42, z), WICKER2)
		end
	end
	K.block(1.6, 0.9, 1.4, at(0, -2.3, 0), WICKER) -- basket
	K.block(1.7, 0.18, 1.5, at(0, -1.82, 0), WICKER2) -- basket rim
	K.ball(1.2, at(0, -1.45, -0.15), GHOST) -- the little ghost
	K.face(0, -1.4, -0.72, 0.38)
	K.ball(0.4, at(-0.85, -1.0, -0.4), GHOST) -- waving hand
	for _, s in { -1, 1 } do -- tiny lanterns hanging from the basket
		K.block(0.05, 0.4, 0.05, at(0.95 * s, -2.55, -0.6), WICKER2)
		K.ball(0.35, at(0.95 * s, -2.85, -0.6), LANTERN, true, 0.2)
	end
	K.ball(0.35, at(-2.4, 1.9, -0.2), SOFTGOLD, true, 0.15) -- orbiting stars
	K.ball(0.3, at(2.35, 0.6, 0.2), MINT, true, 0.15)
	K.ball(0.28, at(2.0, 2.8, -0.1), Color3.fromRGB(255, 180, 220), true, 0.15)
	return Color3.fromRGB(220, 200, 255), 3.1
end

-- unknown id (a pet added to Config before it has a look): a plain ghost blob
local function fallback(K: Kit, def: Config.PetDef): (Color3, number)
	K.ball(3.5, CFrame.identity, def.Color)
	K.ball(1.6, at(0.15, -1.6, 0.8), def.Color)
	K.face(0, 0.3, -1.55, 1)
	return def.Glow, 2.0
end

local function buildPet(def: Config.PetDef, slot: number, label: string): Pet
	local pieces: { Piece } = {}
	local K = {} :: Kit
	function K.ball(d, cf, col, neon, tr)
		return part(pieces, BALL, Vector3.one * (d * S), col, cf, neon, tr)
	end
	function K.block(x, y, z, cf, col, neon, tr)
		return part(pieces, BLOCK, Vector3.new(x, y, z) * S, col, cf, neon, tr)
	end
	function K.cyl(h, d, cf, col, neon, tr)
		return part(pieces, CYL, Vector3.new(h, d, d) * S, col, cf * CFrame.Angles(0, 0, math.pi / 2), neon, tr)
	end
	function K.disc(h, d, cf, col, neon, tr)
		return part(pieces, CYL, Vector3.new(h, d, d) * S, col, cf * CFrame.Angles(0, math.pi / 2, 0), neon, tr)
	end
	function K.wedge(x, y, z, cf, col, neon)
		return part(pieces, WEDGE, Vector3.new(x, y, z) * S, col, cf, neon)
	end
	function K.spike(cf, w, h, side, col, neon)
		return part(pieces, WEDGE, Vector3.new(0.3, h, w) * S, col, cf * CFrame.Angles(0, -side * math.pi / 2, 0), neon)
	end
	function K.face(x, y, z, k, opts)
		local o: FaceOpts = opts or {}
		for _, s in { -1, 1 } do
			K.ball(0.85 * k, at(x + 0.6 * k * s, y + 0.1 * k, z + 0.1), o.Eye or EYE)
			K.ball(0.3 * k, at(x + (0.6 * s + 0.16) * k, y + 0.28 * k, z - 0.22 * k), WHITE)
			if o.Blush ~= false then
				K.ball(0.4 * k, at(x + 1.05 * k * s, y - 0.35 * k, z + 0.1), BLUSH)
			end
		end
		if o.Mouth ~= false then
			K.disc(0.25 * k, 0.5 * k, at(x, y - 0.5 * k, z + 0.02), MOUTH)
		end
	end

	local look = LOOKS[def.Id]
	local glow: Color3, top: number
	if look then
		glow, top = look(K)
	else
		glow, top = fallback(K, def)
	end
	local body = pieces[1].Part

	-- rarity glow: a little wider for rarer pets, capped so Mythic/Secret/Ultra pets don't wash
	-- out (pale pets turned white under the old Secret/Ultra light)
	local r = Config.Rarities[def.Rarity]
	local order = if r then r.Order else 1
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = math.min(4 + order, 8)
	light.Brightness = math.min(0.5 + order * 0.15, 1.1)
	light.Shadows = false
	light.Parent = body

	-- name tag (the nickname is filtered by the server before it is published)
	local gui = WorldLabel.New({
		Name = "PetTag",
		Adornee = body,
		Parent = body,
		Size = Vector2.new(140, 20),
		Offset = Vector3.new(0, top * S + 0.3, 0) - pieces[1].Offset.Position,
		MaxDistance = 60,
	})
	gui.Enabled = game:GetService("Players").LocalPlayer:GetAttribute("ShowNames") ~= false -- Settings: NAMES
	WorldLabel.Text(gui, label, { Style = "Small", Color = if r then (if r.Color.R + r.Color.G + r.Color.B >= r.Color2.R + r.Color2.G + r.Color2.B then r.Color else r.Color2) else nil })
	return { Pieces = pieces, Slot = slot }
end

-- A standalone pet Model (no name tag), pivot = the pet's centre. Used by the egg hatch reveal.
function PetFollowers.BuildPet(petId: string): Model?
	local def = Config.Pets[petId]
	if not def then
		return nil
	end
	local pet = buildPet(def, 1, def.Name)
	local m = Instance.new("Model")
	m.Name = "Pet_" .. petId
	for _, pc in pet.Pieces do
		local tag = pc.Part:FindFirstChild("PetTag")
		if tag then
			tag:Destroy()
		end
		pc.Part.CFrame = pc.Offset
		pc.Part.Parent = m
	end
	-- the body part may be offset or turned (e.g. an upright cylinder): keep the pivot at the
	-- pet's centre, facing the front, like the old ghost pets
	local body = pet.Pieces[1].Part
	body.PivotOffset = body.CFrame:Inverse()
	m.PrimaryPart = body
	return m
end
local function clear(e: Entry)
	for _, pet in e.Pets do
		for _, pc in pet.Pieces do
			pc.Part:Destroy()
		end
	end
	e.Pets = {}
end

local function rebuild(plr: Player)
	local e = entries[plr]
	if not e then
		return
	end
	clear(e)
	if not plr.Character then
		return
	end
	local list = plr:GetAttribute("Pets")
	if type(list) ~= "string" or list == "" then
		return
	end
	local rawNames = plr:GetAttribute("PetNames")
	local names = if type(rawNames) == "string" then string.split(rawNames, "\n") else {}
	for i, id in string.split(list, ",") do
		local def = Config.Pets[id]
		if def and #e.Pets < #SLOTS then
			local nick = names[i]
			table.insert(e.Pets, buildPet(def, #e.Pets + 1, if nick and nick ~= "" then nick else def.Name))
		end
	end
end

local function track(plr: Player)
	local e: Entry = { Pets = {}, Conns = {} }
	entries[plr] = e
	local function re()
		rebuild(plr)
	end
	table.insert(e.Conns, plr:GetAttributeChangedSignal("Pets"):Connect(re))
	table.insert(e.Conns, plr:GetAttributeChangedSignal("PetNames"):Connect(re))
	table.insert(e.Conns, plr.CharacterAdded:Connect(re))
	table.insert(e.Conns, plr.CharacterRemoving:Connect(function()
		clear(e)
	end))
	re()
end

local function untrack(plr: Player)
	local e = entries[plr]
	if e then
		clear(e)
		for _, c in e.Conns do
			c:Disconnect()
		end
		entries[plr] = nil
	end
end

function PetFollowers.Start()
	folder = Instance.new("Folder")
	folder.Name = "PetFollowers"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, plr in Players:GetPlayers() do
		track(plr)
	end
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt: number)
		table.clear(parts)
		table.clear(cfs)
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local t = os.clock()
		local alpha = math.min(1, dt * 8)
		for plr, e in entries do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or #e.Pets == 0 or (root.Position - camPos).Magnitude > FAR then
				continue
			end
			local base = root.CFrame
			for _, pet in e.Pets do
				local bob = math.sin(t * 2.2 + pet.Slot * 1.7) * 0.25
				local target = base * CFrame.new(SLOTS[pet.Slot] + Vector3.new(0, bob, 0))
				-- snap after a teleport / respawn instead of streaking across the map
				local prev = pet.Cur
				local cur = if prev and (prev.Position - target.Position).Magnitude < 40 then prev:Lerp(target, alpha) else target
				pet.Cur = cur
				for _, pc in pet.Pieces do
					table.insert(parts, pc.Part)
					table.insert(cfs, cur * pc.Offset)
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return PetFollowers
