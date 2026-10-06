--!strict
-- Chibi ghost-hunter rigs built from plain Parts (no asset IDs).
--
--   HunterRig.Build(hunterId) -> Rig        animated rig: anchored Root at the feet, Motor6D limbs
--   HunterRig.Pose(rig, state, t, blend?)   procedural pose ("Idle" | "Run" | "Attack" | "Celebrate")
--   HunterRig.BuildStatic(hunterId) -> Model fully anchored, posed copy for ViewportFrame portraits
--   HunterRig.ApplyTier(model, tier)        Shiny/Mega finish, halo and particles (no scaling)
--
-- Layout (studs, model space, facing -Z): feet at Y=0, hips at Y=0.92, torso 0.9..1.95,
-- head (1.9 ball) centred at Y=2.77. Total height ~3.8-4.4 depending on hair/hat.
-- Joints sit at the waist (Root->Torso), neck, shoulders and hips, so Motor6D.Transform
-- rotates each bone around its joint.
-- Neon is limited to the tool emitter (the part holding the Tip attachment) plus at most one
-- small light (helmet lamp, antenna bulb, a small halo, the Crystal circlet's gems or the
-- small Orbs back); visors, goggles, badges, tanks, wings, hats and screens are solid vivid colours.
-- World 2 hats/backs only use Neon on small bits (lantern cores, crown tips, star motes, jet flames).
--
-- Every Look name (HairStyle / Hat / Back / Tool / Signature) must be listed in HunterRig.Known:
-- building a hunter with an unknown name errors, so a typo in Config is caught by the worldsim
-- check (it builds every hunter) instead of silently falling back to a default part.

local Config = require(script.Parent.Parent.Config)
local U = require(script.Parent.RigUtil)

local HunterRig = {}

export type Rig = {
	Model: Model,
	Root: BasePart,
	Motors: { [string]: Motor6D },
	Tip: Attachment,
	Height: number,
	HunterId: string,
}

type Deco = { Part: BasePart, Offset: CFrame }
type DecoMap = { [BasePart]: { Deco } }

-- body measurements
local HIP_Y = 0.92
local TORSO_SIZE = Vector3.new(1.3, 1.05, 0.85)
local TORSO_HALF_H = 0.5 -- waist joint sits this far below the torso centre
local NECK = Vector3.new(0, 0.525, 0) -- torso-local
local HEAD_UP = 0.82 -- head centre above the neck
local HEAD_D = 1.9
local SHOULDER = Vector3.new(0.86, 0.36, 0) -- torso-local (X mirrored)
local ARM_SIZE = Vector3.new(0.42, 0.78, 0.42)
local ARM_DROP = 0.3 -- arm centre below the shoulder
local HIP = Vector3.new(0.32, -0.5, 0) -- torso-local (X mirrored)
local LEG_SIZE = Vector3.new(0.5, 0.7, 0.55)
local LEG_DROP = 0.33
local GRIP = CFrame.new(0, -0.45, -0.05) * CFrame.Angles(-math.pi / 6, 0, 0) -- arm-local tool frame (-Z = muzzle)

local JOINT_ORDER = { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

local WHITE = Color3.fromRGB(255, 255, 255)
local EYE = Color3.fromRGB(25, 20, 35)
local MOUTH = Color3.fromRGB(110, 35, 50)
local METAL = Color3.fromRGB(90, 95, 115)
local GOLD = Color3.fromRGB(255, 205, 60)
local NAVY = Color3.fromRGB(35, 50, 120)
local RED = Color3.fromRGB(230, 50, 70)

local NEON = { Material = Enum.Material.Neon }
local METAL_MAT = { Material = Enum.Material.Metal }
local CREAM = Color3.fromRGB(250, 240, 215)
local RAINBOW = {
	Color3.fromRGB(255, 90, 100),
	Color3.fromRGB(255, 170, 70),
	Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(110, 230, 120),
	Color3.fromRGB(90, 220, 255),
	Color3.fromRGB(110, 140, 255),
	Color3.fromRGB(200, 120, 255),
}

------------------------------------------------------------------ look vocabulary
local function set(list: { string }): { [string]: boolean }
	local s = {}
	for _, k in list do
		s[k] = true
	end
	return s
end

HunterRig.Known = {
	HairStyle = set({ "Spiky", "Bob", "Puff", "Short", "Long", "None", "RoundEars", "PointyEars", "Buns", "Braids", "Floaty", "Beard", "Owl", "Octo",
		"Piggy", "Tabby", "Moustache", "Pup", "Quills", "LongBraid", "Spirit",
		"Hedgehog", "Raccoon", "ElfHero", "VoxelHair" }), -- CYBERARCADE (world2c): last line
	Hat = set({
		"Cap", "Beanie", "Fedora", "Hood", "Helmet", "Mortarboard", "Visor", "Goggles", "Halo", "TopHat", "Jester",
		"NurseCap", "HeadMirror", "SailorCap", "Bandana", "Tricorn", "KnightHelm", "Wizard", "Crown", "Crystal", "Pith",
		"Earmuffs", "Nemes", "Propeller", "DivingHelmet", "Gears", "Bow", "WitchHat", "PumpkinHelm", "FlowerHead",
		"HeroMask", "Tiara", "MoonHood",
		-- World 2
		"ChefHat", "LanternRing", "Specs", "BookHat", "Roof", "ShroomCap", "ShroomCrown", "PrismCrown", "ConductorCap",
		"Headphones", "TVHead", "StormCloud", "SpaceHelmet", "EarHood", "StarCrown",
		-- EXCLUSIVES (world2c)
		"ExDragonCrown", "ExArcaneHat", "ExJackHelm", "ExShroomQueen", "ExCaptainHat", "ExMirrorHelm", "ExVIPHat", "ExPhantomCap", "ExRexSkull", "ExTrophyCrown", "ExDJHeadset", "ExRoyalToque", "ExBossHelm", "ExWingedHelm", "ExAstroHelm", "ExCosmicCrown",
		"Nightcap", "BookHead", "WeatherVane", "HardHat", "SkyTricorn", "BirdMask", "TempestCrown",
		-- World 2 areas 19-29
		"StrawHat", "SharkHood", "ElfHat", "DinoHood", "Thimble", "ChompHead",
		"ScarecrowHat", "FishHood", "Mannequin", "DuckHelmet", "DinoSkull", "GingerIcing", "TulipHat", "Bulb", "Shades", "Bonnet",
		-- CYBERARCADE (world2c)
		"CubeHead", "ChompBall", "PlumberCap", "HeroCap", "Puffball", "BlockCrown",
	}),
	Back = set({
		"Backpack", "Tank", "Cape", "Wings", "Antenna", "Balloons", "MedKit", "LifeRing", "Shield", "Orbs", "HeroCape",
		"BatWings", "HeartWings",
		-- World 2
		"LanternPole", "FireworkRack", "BookWings", "Rings", "MirrorShards", "Shell", "Smokestack", "Boombox", "Glider",
		"StormWings", "Jetpack", "CometTail", "StretchyDog", "VoidRing",
		-- EXCLUSIVES (world2c)
		"ExLanternDragon", "ExLivingGrimoire", "ExPumpkinShield", "ExFairyWings", "ExSharkBoard", "ExMirrorShield", "ExVIPBags", "ExGhostTrain", "ExFossilDragon", "ExChampCape", "ExDJDeck", "ExRoyalCake", "ExHoloScreens", "ExThunderbird", "ExRocketPack", "ExStarCloak",
		"BookStack", "BookCart", "PopUpCastle", "Tentacles", "Pages", "RuneBooks", "CloudSheep", "HotAirBalloon",
		"RainbowScarf", "Battery", "ShipWheel", "Cyclone", "FeatherWings",
		-- World 2 areas 19-29
		"Surfboard", "Blocks",
		"HayBale", "CornBasket", "GiantPumpkin", "SpiderWeb", "Chicken", "Monkey", "Parasol", "Tailfin", "Wave",
		"ShoppingCart", "Scooter", "Stand", "ShoppingBags", "Bone", "DinoEgg", "DinoTail", "Stripes", "SugarCube",
		"ThreadSpool", "ButtonShield", "Sailboat", "FridgeDoor", "Cake", "Overalls", "PelletTrail", "PixelWings",
		"Caterpillar", "BigBelly", "MagicMirror", "TankEngine", "TrenchCoat", "SpaceWings", "TimeBox",
		-- CYBERARCADE (world2c)
		"DirtBlock", "PixelGhostPal", "PipeOveralls", "SpeedLines", "RaccoonTail", "HeroShield", "WarpStar", "BlockStorm",
	}),
	Tool = set({
		"Flashlight", "Vacuum", "Scanner", "Blaster", "Cannon", "Lantern", "Staff", "Projector", "Megaphone", "Wand", "Orb",
		"Spyglass", "Sword", "Trident", "Wrench", "HeartWand", "MoonStaff", "PumpkinLance",
		-- World 2
		"FryingPan", "SteamBasket", "Spellbook", "Quill", "Umbrella", "Magnet", "Teapot", "HandMirror", "Kaleidoscope",
		"Guitar", "Hammer", "Thunderbolt", "RayGun", "StarBlade",
		-- EXCLUSIVES (world2c)
		"ExDragonLantern", "ExRuneStaff", "ExHarvestBlade", "ExSporeScepter", "ExTideBlaster", "ExPrismSword", "ExDiamondCard", "ExGoldWatch", "ExAmberScepter", "ExChampionCup", "ExNeonMic", "ExIcingScepter", "ExHoloController", "ExStormSpear", "ExPlanetOrb", "ExGalaxyScepter",
		"Candle", "Stamp", "Magnifier", "BookStaff", "Anemometer", "Crook", "Pinwheel",
		-- World 2 areas 19-29
		"Pitchfork", "Whip", "BoxingGlove", "Trophy", "SewingPin", "RollingPin", "Whisk", "Joystick",
		"Diploma", "WateringCan", "BubbleWand", "Fork", "Pretzel", "CandyCane", "Lasagna", "Brush", "TourFlag",
		"AmberStaff", "Popcorn", "RedCard", "BiscuitBox", "Basketball", "HockeyStick", "FoamFinger", "Coin",
		"Gamepad", "GoldRing", "PixelSword", "Screwdriver",
		-- CYBERARCADE (world2c)
		"PixelPickaxe", "PowerPellet", "PipeWrench", "TokenSack", "HeroSword", "StarRod", "BossScepter",
	}),
	Signature = set({ "Supernova" }),
}
-- WATERPARK/STADIUM (world2c)
local waterparkStadiumParts: { [string]: { string } } = {
	Hat = { "GuardHat", "Snorkel", "ShellTiara", "SpongeHead", "Hibiscus", "AnglerHood", "CoralCrown", "Sweatband", "FanHat" },
	Back = { "DuckFloat", "MerTail", "Jellyfish", "SeaTurtle", "CanoeSail", "SeaSerpent", "BoxerRobe", "FanDrum" },
	Tool = { "RescueCan", "SquirtGun", "Conch", "Spatula", "Longboard", "Paddle", "GhostNet", "CoralStaff", "BoxerGlove" },
}
for field, names in waterparkStadiumParts do
	for _, n in names do
		HunterRig.Known[field][n] = true
	end
end

-- Names in a Look that HunterRig cannot build ("Hat=Foo"); empty when every part is known.
function HunterRig.UnknownParts(look: Config.HunterLook): { string }
	local bad = {}
	local l = look :: any
	local function check(field: string, value: any, optional: boolean)
		if value == nil and optional then
			return
		end
		if type(value) ~= "string" or not HunterRig.Known[field][value] then
			table.insert(bad, field .. "=" .. tostring(value))
		end
	end
	check("HairStyle", l.HairStyle, false)
	check("Hat", l.Hat, true)
	check("Back", l.Back, true)
	check("Tool", l.Tool, false)
	check("Signature", l.Signature, true)
	if l.Chrome ~= nil and type(l.Chrome) ~= "boolean" then
		table.insert(bad, "Chrome=" .. tostring(l.Chrome))
	end
	return bad
end

local function buildInternal(hunterId: string): (Rig, DecoMap)
	local def = Config.Hunters[hunterId]
	assert(def, "HunterRig: unknown hunter " .. tostring(hunterId))
	local look = def.Look
	local bad = HunterRig.UnknownParts(look)
	assert(#bad == 0, "HunterRig: " .. hunterId .. " uses unknown look parts: " .. table.concat(bad, ", "))
	local lookX = look :: any -- World 2 flags (Chrome, Signature) may not be in the Config type yet
	local rarity = Config.Rarities[def.Rarity]
	local rarityColor = if rarity then rarity.Color else look.Beam

	local model = Instance.new("Model")
	model.Name = hunterId

	local root = U.Block(Vector3.new(1, 1, 1), CFrame.identity, WHITE, model, { Transparency = 1, Name = "Root", Shadow = false })
	root.Anchored = true
	model.PrimaryPart = root

	local decos: DecoMap = {}
	local motors: { [string]: Motor6D } = {}

	local function bone(name: string, p: BasePart): BasePart
		p.Name = name
		decos[p] = {}
		return p
	end

	local function add(b: BasePart, p: BasePart): BasePart
		U.FixedWeld(b, p)
		table.insert(decos[b], { Part = p, Offset = b.CFrame:ToObjectSpace(p.CFrame) })
		return p
	end
	local function ball(b: BasePart, d: number, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Ball(d, b.CFrame * lcf, color, model, opts))
	end
	local function block(b: BasePart, size: Vector3, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Block(size, b.CFrame * lcf, color, model, opts))
	end
	local function cyl(b: BasePart, len: number, d: number, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Cyl(len, d, b.CFrame * lcf, color, model, opts))
	end
	local function wedge(b: BasePart, size: Vector3, lcf: CFrame, color: Color3, opts: U.Opts?): BasePart
		return add(b, U.Wedge(size, b.CFrame * lcf, color, model, opts))
	end
	-- straight rod between two bone-local points
	local function rod(b: BasePart, p0: Vector3, p1: Vector3, d: number, color: Color3, opts: U.Opts?): BasePart
		return cyl(b, (p1 - p0).Magnitude, d, U.Between(p0, p1), color, opts)
	end
	-- stepped cone standing on bone-local `base` (along its +Y); returns the tip frame
	local function cone(b: BasePart, base: CFrame, d: number, h: number, tiers: number, c1: Color3, c2: Color3?): CFrame
		local th = h / tiers
		for i = 0, tiers - 1 do
			local c = if c2 and i % 2 == 1 then c2 else c1
			cyl(b, th * 1.05, d * (tiers - i) / tiers, base * CFrame.new(0, th * (i + 0.5), 0) * U.AxisY, c)
		end
		return base * CFrame.new(0, h, 0)
	end
	-- flat bar (block w x t) between two bone-local points
	local function bar(b: BasePart, p0: Vector3, p1: Vector3, w: number, t: number, color: Color3, opts: U.Opts?): BasePart
		local dir = (p1 - p0).Unit
		local up = if math.abs(dir.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
		return block(b, Vector3.new(w, t, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1, up), color, opts)
	end
	-- flat isosceles point in the frame's XY plane: base width w centred on the frame, apex h up (+Y)
	local function spike(b: BasePart, cf: CFrame, w: number, h: number, t: number, color: Color3, opts: U.Opts?)
		for _, s in { -1, 1 } do
			wedge(b, Vector3.new(t, h, w / 2), cf * CFrame.new(s * w / 4, h / 2, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), color, opts)
		end
	end
	-- red paper lantern hanging from `top` (bone-local), gold caps; returns its centre
	local function paperLantern(b: BasePart, top: Vector3, d: number, color: Color3, core: boolean, rib: boolean): Vector3
		local c = top - Vector3.new(0, d * 0.58, 0)
		ball(b, d, CFrame.new(c), color, if core then { Transparency = 0.3 } else nil)
		if rib then
			cyl(b, d * 0.07, d * 1.01, CFrame.new(c) * U.AxisY, U.Shade(color, 0.7))
		end
		cyl(b, d * 0.16, d * 0.56, CFrame.new(c + Vector3.new(0, d * 0.45, 0)) * U.AxisY, GOLD, METAL_MAT)
		cyl(b, d * 0.16, d * 0.56, CFrame.new(c - Vector3.new(0, d * 0.45, 0)) * U.AxisY, GOLD, METAL_MAT)
		if core then
			ball(b, d * 0.42, CFrame.new(c), Color3.fromRGB(255, 210, 120), NEON)
		end
		return c
	end

	------------------------------------------------------------------ skeleton
	local torsoC0 = CFrame.new(0, HIP_Y, 0)
	local torsoC1 = CFrame.new(0, -TORSO_HALF_H, 0)
	local torso = bone("Torso", U.Block(TORSO_SIZE, torsoC0 * torsoC1:Inverse(), look.Shirt, model, { Shadow = true }))
	motors.Torso = U.Motor("Torso", root, torso, torsoC0, torsoC1)

	local headC0 = CFrame.new(NECK)
	local headC1 = CFrame.new(0, -HEAD_UP, 0)
	local head = bone("Head", U.Ball(HEAD_D, torso.CFrame * headC0 * headC1:Inverse(), look.Skin, model, { Shadow = true }))
	motors.Head = U.Motor("Head", torso, head, headC0, headC1)

	local arms: { [number]: BasePart } = {}
	local legs: { [number]: BasePart } = {}
	local hands: { [number]: BasePart } = {}
	for _, s in { -1, 1 } do
		local side = if s < 0 then "Left" else "Right"
		local aC0 = CFrame.new(SHOULDER.X * s, SHOULDER.Y, SHOULDER.Z)
		local aC1 = CFrame.new(0, ARM_DROP, 0)
		local arm = bone(side .. "Arm", U.Block(ARM_SIZE, torso.CFrame * aC0 * aC1:Inverse(), look.Shirt, model))
		motors[side .. "Arm"] = U.Motor(side .. "Arm", torso, arm, aC0, aC1)
		hands[s] = ball(arm, 0.5, CFrame.new(0, -0.42, 0), look.Skin) -- hand
		arms[s] = arm

		local lC0 = CFrame.new(HIP.X * s, HIP.Y, HIP.Z)
		local lC1 = CFrame.new(0, LEG_DROP, 0)
		local leg = bone(side .. "Leg", U.Block(LEG_SIZE, torso.CFrame * lC0 * lC1:Inverse(), look.Pants, model))
		motors[side .. "Leg"] = U.Motor(side .. "Leg", torso, leg, lC0, lC1)
		-- shoe: bottom exactly at Y=0 (leg centre is at Y=0.59)
		block(leg, Vector3.new(0.6, 0.3, 0.78), CFrame.new(0, 0.15 - (HIP_Y - LEG_DROP), -0.08), look.Shoes)
		legs[s] = leg
	end
	local rArm = arms[1]

	------------------------------------------------------------------ face
	local hat = look.Hat
	local hatColor = look.HatColor or look.Shirt
	local style = look.HairStyle
	-- panda: dark round ears on a pale face get dark eye patches too
	local function lum(c: Color3): number
		return c.R * 0.3 + c.G * 0.59 + c.B * 0.11
	end
	local panda = style == "RoundEars" and lum(look.Hair) < 0.3 and lum(look.Skin) > 0.75
	if hat ~= "TVHead" and hat ~= "BookHead" and hat ~= "Mannequin" then -- the TV and the book draw their own faces; the dummy has none
		for _, s in { -1, 1 } do
			local eyePos = Vector3.new(0.34 * s, 0.0, -0.8)
			ball(head, 0.5, CFrame.new(eyePos), EYE, { Shadow = false })
			ball(head, 0.17, CFrame.new(eyePos + Vector3.new(0.07, 0.1, -0.19)), WHITE)
			if hat ~= "Goggles" then
				block(head, Vector3.new(0.34, 0.08, 0.14), CFrame.new(0.34 * s, 0.37, -0.86) * CFrame.Angles(0.35, 0, -0.14 * s), U.Shade(look.Hair, 0.8))
			end
			if panda then
				local n = Vector3.new(0.36 * s, -0.04, -0.8).Unit
				cyl(head, 0.08, 0.72, U.DiscFacing(n * 0.9, n), look.Hair)
			end
		end
		-- little open smile: a WedgePart turned into a "▽" (FlowerHead draws its own toothy grin)
		-- (muzzles, snouts and moustaches cover it)
		local ownMouth = style == "Beard" or style == "Owl" or style == "Moustache" or style == "Tabby" or style == "Pup" or style == "Piggy" or style == "Spirit"
		if hat ~= "FlowerHead" and not ownMouth then
			wedge(head, Vector3.new(0.1, 0.26, 0.26), CFrame.new(0, -0.34, -0.88) * CFrame.Angles(-0.35, 0, 0) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, MOUTH)
		end
		if style == "RoundEars" then
			ball(head, 0.22, CFrame.new(0, -0.16, -0.95), if panda then look.Hair else Color3.fromRGB(255, 140, 170)) -- animal nose
		end
	end

	------------------------------------------------------------------ hair
	local covered = hat == "Hood"
		or hat == "Helmet"
		or hat == "Beanie"
		or hat == "KnightHelm"
		or hat == "Bandana"
		or hat == "Jester"
		or hat == "SailorCap"
		or hat == "Nemes"
		or hat == "Propeller"
		or hat == "DivingHelmet"
		or hat == "PumpkinHelm"
		or hat == "MoonHood"
		or hat == "FlowerHead"
		or hat == "ChefHat"
		or hat == "Roof"
		or hat == "ShroomCap"
		or hat == "TVHead"
		or hat == "EarHood"
		or hat == "BookHead"
		or hat == "BirdMask"
		or hat == "SharkHood"
		or hat == "DinoHood"
		or hat == "ChompHead"
		or hat == "FishHood"
		or hat == "DuckHelmet"
		or hat == "DinoSkull"
		or hat == "Mannequin"
	-- the glass space helmet shows the hair inside it, so only styles that fit stay as they are
	local glass = hat == "SpaceHelmet"
	local hairTop = 1.25
	local hairColor = look.Hair
	local function cap()
		ball(head, 2.0, CFrame.new(0, 0.25, 0.2), hairColor)
	end
	if style == "None" then
		hairTop = HEAD_D / 2
	elseif style == "RoundEars" then
		-- mouse / panda / bear ears: drawn even under hats (lower and further out when a hat covers the top)
		hairTop = HEAD_D / 2
		local inner = if lum(hairColor) > 0.45 then U.Mix(hairColor, Color3.fromRGB(255, 150, 175), 0.55) else U.Shade(hairColor, 1.6)
		for _, s in { -1, 1 } do
			local ecf = if covered or glass
				then CFrame.new(0.93 * s, 0.5, 0.12) * CFrame.Angles(0, 0, -0.75 * s)
				else CFrame.new(0.7 * s, 0.8, 0.12) * CFrame.Angles(0, 0, -0.5 * s)
			cyl(head, 0.3, 0.82, ecf * U.AxisZ, hairColor)
			if not panda then
				cyl(head, 0.06, 0.52, ecf * CFrame.new(0, 0, -0.16) * U.AxisZ, inner)
			end
		end
	elseif style == "Beard" then
		-- bald top, big round beard with a point, bushy moustache (drawn even under hats)
		hairTop = HEAD_D / 2
		ball(head, 1.25, CFrame.new(0, -0.68, -0.42), hairColor)
		spike(head, CFrame.new(0, -1.05, -0.62) * CFrame.Angles(0.35, 0, math.pi), 0.7, 0.55, 0.35, hairColor)
		for _, s in { -1, 1 } do
			ball(head, 0.44, CFrame.new(0.2 * s, -0.27, -0.9), U.Shade(hairColor, 0.92))
		end
	elseif glass then
		cap()
		if style == "Buns" then
			for _, s in { -1, 1 } do
				ball(head, 0.6, CFrame.new(0.52 * s, 0.85, 0.18), hairColor)
			end
		end
	elseif style == "Puff" and not covered then
		ball(head, 2.3, CFrame.new(0, 0.5, 0.32), hairColor)
		hairTop = 1.65
	elseif style == "Spiky" and not covered then
		cap()
		wedge(head, Vector3.new(0.45, 1.0, 0.8), CFrame.new(-0.3, 1.05, 0.35) * CFrame.Angles(0.5, 0, 0.25), hairColor)
		wedge(head, Vector3.new(0.45, 1.0, 0.8), CFrame.new(0.3, 1.0, 0.45) * CFrame.Angles(0.55, 0, -0.25), hairColor)
		hairTop = 1.35
	elseif style == "Bob" then
		cap()
		ball(head, 2.06, CFrame.new(0, -0.12, 0.32), hairColor)
	elseif style == "Long" then
		cap()
		block(head, Vector3.new(1.75, 1.6, 0.55), CFrame.new(0, -0.5, 0.72), hairColor)
	elseif style == "PointyEars" then
		-- upright cat / owl-tuft ears with a lighter inside, drawn even under hats and masks
		if not covered then
			cap()
		end
		hairTop = 1.3
		for _, s in { -1, 1 } do
			local ecf = CFrame.new(0.52 * s, 0.88, 0.12) * CFrame.Angles(0, 0, -0.18 * s)
			spike(head, ecf, 0.62, 0.85, 0.24, hairColor)
			spike(head, ecf * CFrame.new(0, 0.06, -0.1), 0.34, 0.5, 0.08, U.Mix(hairColor, WHITE, 0.4))
		end
	elseif style == "Buns" then
		cap()
		if not covered then
			for _, s in { -1, 1 } do
				ball(head, 0.82, CFrame.new(0.68 * s, 0.95, 0.15), hairColor)
			end
		end
	elseif style == "Braids" then
		cap()
		for _, s in { -1, 1 } do
			for i, d in { 0.42, 0.38, 0.34, 0.3 } do
				ball(head, d, CFrame.new((0.84 - i * 0.02) * s, -0.05 - i * 0.24, 0.3 - i * 0.02), hairColor)
			end
			block(head, Vector3.new(0.24, 0.1, 0.24), CFrame.new(0.76 * s, -1.06, 0.22), U.Vivid(look.Shirt)) -- hair band
		end
	elseif style == "Floaty" and not covered then
		-- long hair floating UP (underwater / upside-down): soft wisps of overlapping balls rising from
		-- the head and curling outward; under a brimmed hat only wisps that clear the brim
		cap()
		local brimmed = hat == "TopHat" or hat == "Fedora" or hat == "Wizard" or hat == "WitchHat" or hat == "Pith" or hat == "Tricorn" or hat == "SailorCap" or hat == "ConductorCap"
		local function wisp(p0: Vector3, up: Vector3, out: Vector3, sizes: { number })
			local step = sizes[1] * 0.47
			for k, d in sizes do
				local t = k - 1
				ball(head, d, CFrame.new(p0 + up.Unit * step * t + out * t * t), hairColor)
			end
		end
		if brimmed then
			wisp(Vector3.new(0, 0.2, 0.95), Vector3.new(0, 1, 0.75), Vector3.new(0, 0, 0.06), { 0.8, 0.7, 0.6, 0.5 })
		else
			wisp(Vector3.new(0, 0.75, 0.7), Vector3.new(0, 1, 0.45), Vector3.new(0, 0, 0.05), { 0.85, 0.75, 0.62, 0.5 })
		end
		for _, sd in { -1, 1 } do
			if not brimmed then
				wisp(Vector3.new(0.6 * sd, 0.85, 0.3), Vector3.new(0.35 * sd, 1, 0.15), Vector3.new(0.07 * sd, 0, 0), { 0.65, 0.55, 0.45 })
			end
			wisp(Vector3.new(0.9 * sd, 0.2, 0.3), Vector3.new(0.75 * sd, 0.7, 0.1), Vector3.new(0.04 * sd, 0.05, 0), { 0.58, 0.46 })
		end
		hairTop = 1.35
	elseif style == "Owl" then
		-- owl: feathered cap over the top and back, upright ear tufts, pale feather discs round the
		-- eyes and a little hooked beak (drawn even under hats)
		if not covered then
			cap()
		end
		hairTop = 1.3
		local pale = U.Mix(look.Skin, WHITE, 0.55)
		for _, s in { -1, 1 } do
			spike(head, CFrame.new(0.58 * s, 0.82, 0.12) * CFrame.Angles(0, 0, -0.4 * s), 0.55, 0.8, 0.24, hairColor)
			local n = Vector3.new(0.34 * s, 0.0, -0.8).Unit
			cyl(head, 0.06, 0.88, U.DiscFacing(n * 0.9, n), pale)
		end
		block(head, Vector3.new(0.26, 0.26, 0.34), CFrame.new(0, -0.26, -0.9) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(245, 165, 45)) -- beak
	elseif style == "Octo" then
		-- octopus: a tall soft mantle swept up and back over the head, with a few pale spots
		hairTop = 2.0
		local spot = U.Mix(hairColor, WHITE, 0.45)
		for _, q in { { 0, 0.85, 0.55, 2.45 } } do
			ball(head, q[4], CFrame.new(q[1], q[2], q[3]), hairColor)
		end
		for _, q in { { 0, 0.85, 0.55, -0.55, 0.45, -0.7, 1.24 }, { 0, 0.85, 0.55, 0.75, 0.5, -0.45, 1.24 }, { 0, 0.85, 0.55, 0.15, 0.95, -0.3, 1.24 } } do
			local d = Vector3.new(q[4], q[5], q[6]).Unit
			ball(head, 0.32, CFrame.new(Vector3.new(q[1], q[2], q[3]) + d * q[7] * 0.95), spot)
		end
	elseif style == "Piggy" then
		-- pig: floppy ears flopping forward and a round snout with nostrils (drawn even under hats)
		if not covered then
			cap()
		end
		for _, s in { -1, 1 } do
			spike(head, CFrame.new(0.58 * s, 0.78, 0.0) * CFrame.Angles(-0.75, 0, -0.55 * s), 0.6, 0.62, 0.1, hairColor)
		end
		local sn = CFrame.new(0, -0.22, -0.95) * U.AxisZ
		cyl(head, 0.26, 0.56, sn, U.Mix(look.Skin, Color3.fromRGB(255, 120, 150), 0.25))
		for _, s in { -1, 1 } do
			cyl(head, 0.28, 0.12, CFrame.new(0.11 * s, -0.22, -0.97) * U.AxisZ, Color3.fromRGB(150, 60, 80)) -- nostrils
		end
		wedge(head, Vector3.new(0.08, 0.14, 0.2), CFrame.new(0, -0.6, -0.78) * CFrame.Angles(-0.6, 0, 0) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, MOUTH)
	elseif style == "Tabby" then
		-- lazy tabby cat: short ears, dark forehead stripes, sleepy half-shut eyelids, puffy cheeks, pink nose
		if not covered then
			cap()
		end
		hairTop = 1.2
		local stripe = U.Shade(hairColor, 0.45)
		for _, s in { -1, 1 } do
			local ecf = CFrame.new(0.56 * s, 0.82, 0.12) * CFrame.Angles(0, 0, -0.3 * s)
			spike(head, ecf, 0.6, 0.6, 0.22, hairColor)
			spike(head, ecf * CFrame.new(0, 0.05, -0.1), 0.32, 0.36, 0.08, Color3.fromRGB(255, 170, 160))
			block(head, Vector3.new(0.54, 0.27, 0.3), CFrame.new(0.34 * s, 0.13, -0.84) * CFrame.Angles(-0.25, 0, 0), look.Skin) -- eyelid
			ball(head, 0.46, CFrame.new(0.19 * s, -0.3, -0.84), U.Mix(look.Skin, WHITE, 0.6)) -- cheeks
		end
		for _, x in { -0.25, 0, 0.25 } do
			local d = Vector3.new(x, 0.85, -0.5).Unit
			block(head, Vector3.new(0.1, 0.42, 0.06), U.Facing(Vector3.new(0, 0.25, 0.2) + d * 1.0, d), stripe)
		end
		ball(head, 0.2, CFrame.new(0, -0.14, -0.98), Color3.fromRGB(255, 130, 150)) -- nose
	elseif style == "Moustache" then
		-- neat hair and a big bushy moustache
		cap()
		local m = U.Shade(hairColor, 0.92)
		for _, s in { -1, 1 } do
			ball(head, 0.44, CFrame.new(0.21 * s, -0.27, -0.9), m)
			ball(head, 0.3, CFrame.new(0.43 * s, -0.33, -0.8), m)
		end
		ball(head, 0.2, CFrame.new(0, -0.08, -0.98), U.Shade(look.Skin, 0.9)) -- nose
	elseif style == "Pup" then
		-- puppy: long floppy ears hanging at the sides, pale muzzle, big dark nose and a little tongue
		if not covered then
			cap()
		end
		local ear = U.Shade(hairColor, 0.75)
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.24, 0.9, 0.55), CFrame.new(0.98 * s, 0.1, 0.12) * CFrame.Angles(0, 0, 0.22 * s), ear)
			ball(head, 0.5, CFrame.new(1.08 * s, -0.33, 0.12), ear)
		end
		ball(head, 0.72, CFrame.new(0, -0.3, -0.72), U.Mix(look.Skin, WHITE, 0.5)) -- muzzle
		ball(head, 0.28, CFrame.new(0, -0.12, -1.06), Color3.fromRGB(40, 30, 35)) -- nose
		block(head, Vector3.new(0.18, 0.06, 0.24), CFrame.new(0.06, -0.62, -0.92) * CFrame.Angles(0.5, 0, 0), Color3.fromRGB(255, 120, 140)) -- tongue
	elseif style == "Quills" then
		-- speedy hedgehog: big quills swept back from the head
		cap()
		for _, q in { { 0, 0.9, 0.35, 0, 0.45, 1 }, { -0.55, 0.5, 0.45, -0.35, 0.1, 1 }, { 0.55, 0.5, 0.45, 0.35, 0.1, 1 }, { -0.4, -0.05, 0.6, -0.25, -0.35, 1 }, { 0.4, -0.05, 0.6, 0.25, -0.35, 1 } } do
			local p = Vector3.new(q[1], q[2], q[3])
			local d = Vector3.new(q[4], q[5], q[6]).Unit
			cone(head, CFrame.lookAt(p, p + d) * CFrame.Angles(-math.pi / 2, 0, 0), 0.75, 1.25, 3, hairColor)
		end
	-- CYBERARCADE (world2c) ---------------------------------------- hair
	elseif style == "Hedgehog" then
		-- speedy hedgehog: hair-coloured head with big quills swept back, little ears, a pale muzzle and
		-- tummy, white gloves and a white strap on each sneaker
		cap()
		hairTop = 1.3
		local pale = look.Skin
		for _, q in { { 0, 0.72, 0.45, 0, 0.5, 1, 1.55 }, { -0.55, 0.28, 0.6, -0.5, 0.12, 1, 1.4 }, { 0.55, 0.28, 0.6, 0.5, 0.12, 1, 1.4 }, { 0, -0.22, 0.7, 0, -0.4, 1, 1.3 } } do
			local p = Vector3.new(q[1], q[2], q[3])
			local d = Vector3.new(q[4], q[5], q[6]).Unit
			cone(head, CFrame.lookAt(p, p + d) * CFrame.Angles(-math.pi / 2, 0, 0), 0.95, q[7], 3, hairColor)
		end
		for _, s in { -1, 1 } do
			local ecf = CFrame.new(0.5 * s, 0.8, 0.0) * CFrame.Angles(0, 0, -0.35 * s)
			spike(head, ecf, 0.5, 0.55, 0.2, hairColor)
			spike(head, ecf * CFrame.new(0, 0.05, -0.11), 0.26, 0.32, 0.06, pale)
			hands[s].Color = WHITE
			block(legs[s], Vector3.new(0.64, 0.12, 0.3), CFrame.new(0, -0.3, -0.2), WHITE) -- sneaker strap
		end
		ball(head, 0.86, CFrame.new(0, -0.44, -0.6), pale) -- muzzle
		ball(head, 0.22, CFrame.new(0, -0.17, -1.0), EYE) -- nose
		block(head, Vector3.new(0.34, 0.07, 0.08), CFrame.new(0.06, -0.62, -0.95) * CFrame.Angles(0.5, 0, -0.25), MOUTH) -- grin
		cyl(torso, 0.05, 0.74, CFrame.new(0, -0.18, -0.43) * U.AxisZ, pale) -- tummy
	elseif style == "Raccoon" then
		-- masked raccoon: furry ears with dark insides, a black eye mask, a white muzzle and cheek fluff
		cap()
		hairTop = 1.3
		local dark = Color3.fromRGB(35, 32, 40)
		local pale = Color3.fromRGB(245, 245, 240)
		for _, s in { -1, 1 } do
			local ecf = CFrame.new(0.58 * s, 0.8, 0.12) * CFrame.Angles(0, 0, -0.3 * s)
			spike(head, ecf, 0.62, 0.62, 0.22, hairColor)
			spike(head, ecf * CFrame.new(0, 0.04, -0.1), 0.34, 0.36, 0.06, dark)
			local n = Vector3.new(0.36 * s, 0.0, -0.8).Unit
			cyl(head, 0.08, 0.82, U.DiscFacing(n * 0.9, n), dark) -- mask
			spike(head, CFrame.new(0.8 * s, -0.42, -0.25) * CFrame.Angles(0, 0, -1.9 * s), 0.42, 0.45, 0.12, pale) -- cheek fluff
		end
		block(head, Vector3.new(0.5, 0.3, 0.1), CFrame.new(0, 0.02, -0.95), dark) -- mask bridge
		ball(head, 0.78, CFrame.new(0, -0.44, -0.64), pale) -- muzzle
		ball(head, 0.24, CFrame.new(0, -0.22, -1.0), dark) -- nose
	elseif style == "ElfHero" then
		-- sword hero: fair hair with locks down the sides and long pointed ears sticking out sideways
		cap()
		for _, s in { -1, 1 } do
			spike(head, CFrame.new(0.86 * s, 0.02, 0.12) * CFrame.Angles(0, 0, -1.2 * s), 0.42, 0.78, 0.14, look.Skin) -- pointed ear
			block(head, Vector3.new(0.26, 0.8, 0.3), CFrame.new(0.74 * s, -0.08, -0.55) * CFrame.Angles(0, 0.45 * s, 0.1 * s), hairColor) -- side lock
		end
		spike(head, CFrame.new(-0.2, 0.62, -0.84) * CFrame.Angles(-0.35, 0, 2.7), 0.55, 0.5, 0.16, hairColor) -- fringe tuft
	elseif style == "VoxelHair" then
		-- 8-bit hair built from big blocks: flat top, stepped fringe, long side locks and a back panel
		hairTop = 1.12
		local dk = U.Shade(hairColor, 0.82)
		block(head, Vector3.new(1.9, 0.5, 1.9), CFrame.new(0, 0.82, 0.14), hairColor)
		block(head, Vector3.new(2.0, 2.5, 0.55), CFrame.new(0, -0.5, 0.78), hairColor)
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.34, 1.7, 0.9), CFrame.new(0.88 * s, -0.4, 0.3), dk)
		end
		block(head, Vector3.new(1.3, 0.4, 0.36), CFrame.new(0.2, 0.58, -0.78) * CFrame.Angles(0, 0, -0.12), hairColor) -- fringe
	-- end CYBERARCADE (world2c) hair
	elseif style == "LongBraid" then
		-- magic-long golden braid: down the back, across the floor, with little flowers tucked in
		cap()
		block(head, Vector3.new(1.75, 1.2, 0.5), CFrame.new(0, -0.35, 0.72), hairColor)
		local pts = { Vector3.new(0.7, -0.35, 0.55), Vector3.new(1.25, -1.15, 0.5), Vector3.new(1.35, -2.05, 0.35), Vector3.new(1.3, -2.55, -0.3), Vector3.new(0.95, -2.58, -1.0), Vector3.new(0.25, -2.58, -1.35) }
		local k = 0
		local dark = U.Shade(hairColor, 0.88)
		for i = 1, #pts - 1 do
			local n = math.max(1, math.floor((pts[i + 1] - pts[i]).Magnitude / 0.34))
			for j = 0, n - 1 do
				k += 1
				local p = pts[i]:Lerp(pts[i + 1], j / n)
				ball(head, 0.48 - k * 0.006, CFrame.new(p + Vector3.new(if k % 2 == 0 then 0.07 else -0.07, 0, 0)), if k % 2 == 0 then hairColor else dark)
				if k % 6 == 3 then
					ball(head, 0.2, CFrame.new(p + Vector3.new(0.2, 0.08, -0.05)), if k % 12 == 3 then Color3.fromRGB(255, 150, 190) else Color3.fromRGB(190, 150, 255)) -- flowers
				end
			end
		end
		hairTop = 1.25
	elseif style == "Spirit" then
		-- big forest spirit: tall pointy ears, whiskers, a tiny nose and a huge grin
		cap()
		hairTop = 1.7
		for _, s in { -1, 1 } do
			spike(head, CFrame.new(0.42 * s, 0.82, 0.18) * CFrame.Angles(0, 0, -0.1 * s), 0.42, 0.95, 0.2, hairColor)
			for i = -1, 1 do
				rod(head, Vector3.new(0.5 * s, -0.22 + i * 0.1, -0.85), Vector3.new(1.15 * s, -0.18 + i * 0.2, -0.65), 0.035, Color3.fromRGB(50, 50, 60)) -- whiskers
			end
			block(head, Vector3.new(0.22, 0.1, 0.08), CFrame.new(0.42 * s, -0.33, -0.86) * CFrame.Angles(0, 0.35 * s, 0.5 * s), MOUTH) -- grin corners
		end
		ball(head, 0.16, CFrame.new(0, -0.08, -0.97), Color3.fromRGB(50, 50, 60)) -- nose
		block(head, Vector3.new(0.66, 0.14, 0.08), CFrame.new(0, -0.4, -0.88) * CFrame.Angles(0.35, 0, 0), MOUTH) -- grin
		block(head, Vector3.new(0.5, 0.06, 0.06), CFrame.new(0, -0.36, -0.92) * CFrame.Angles(0.35, 0, 0), WHITE) -- teeth
	else -- Short (and covered Puff/Spiky/Floaty): a neat hair cap
		cap()
	end
	local lift = hairTop - 1.25

	------------------------------------------------------------------ hat
	if hat == "Cap" then
		ball(head, 2.0, CFrame.new(0, 0.45, 0.12), hatColor)
		cyl(head, 0.1, 1.3, CFrame.new(0, 0.55, -0.95) * CFrame.Angles(-0.12, 0, 0) * U.AxisY, U.Shade(hatColor, 0.85))
	elseif hat == "Beanie" then
		ball(head, 2.06, CFrame.new(0, 0.42, 0.12), hatColor)
		ball(head, 0.6, CFrame.new(0, 1.5, 0.2), U.Mix(hatColor, WHITE, 0.6))
	elseif hat == "Fedora" then
		cyl(head, 0.12, 2.8, CFrame.new(0, 0.78 + lift, 0.08) * CFrame.Angles(-0.06, 0, 0) * U.AxisY, hatColor)
		cyl(head, 0.85, 1.55, CFrame.new(0, 1.2 + lift, 0.08) * U.AxisY, hatColor)
		cyl(head, 0.22, 1.6, CFrame.new(0, 0.92 + lift, 0.08) * U.AxisY, U.Shade(hatColor, 0.45))
	elseif hat == "Hood" then
		ball(head, 2.25, CFrame.new(0, 0.22, 0.3), hatColor)
		wedge(head, Vector3.new(0.55, 0.9, 0.7), CFrame.new(0, 1.2, 0.75) * CFrame.Angles(-0.3, 0, 0), hatColor)
	elseif hat == "Helmet" then
		ball(head, 2.08, CFrame.new(0, 0.48, 0.12), hatColor)
		cyl(head, 0.1, 2.35, CFrame.new(0, 0.5, 0.12) * U.AxisY, U.Shade(hatColor, 0.8))
		local dir = Vector3.new(0, 0.5, -0.87).Unit
		local pos = Vector3.new(0, 0.48, 0.12) + dir * 1.06
		cyl(head, 0.25, 0.45, U.DiscFacing(pos, dir), look.Beam, NEON)
	elseif hat == "Mortarboard" then
		cyl(head, 0.45, 1.5, CFrame.new(0, hairTop - 0.1, 0.1) * U.AxisY, hatColor)
		block(head, Vector3.new(2.1, 0.12, 2.1), CFrame.new(0, hairTop + 0.17, 0.1) * CFrame.Angles(0, math.pi / 4, 0), hatColor)
		block(head, Vector3.new(0.12, 0.6, 0.12), CFrame.new(1.38, hairTop - 0.1, 0.1), Color3.fromRGB(255, 205, 60)) -- tassel
	elseif hat == "Visor" then
		cyl(head, 0.2, 2.02, CFrame.new(0, 0.5, 0.05) * U.AxisY, U.Shade(hatColor, 0.6))
		block(head, Vector3.new(1.5, 0.08, 0.75), CFrame.new(0, 0.6, -1.05) * CFrame.Angles(-0.2, 0, 0), U.Vivid(hatColor), { Transparency = 0.35, Reflectance = 0.2, Shadow = false })
	elseif hat == "Goggles" then
		cyl(head, 0.16, 2.06, CFrame.new(0, 0.52, 0.05) * U.AxisY, U.Shade(hatColor, 0.45))
		for _, s in { -1, 1 } do
			local pos = Vector3.new(0.366 * s, 0.554, -0.817)
			cyl(head, 0.22, 0.5, U.DiscFacing(pos, pos), U.Vivid(hatColor), { Transparency = 0.15, Reflectance = 0.25 }) -- glassy lenses
		end
	elseif hat == "Halo" then
		cyl(head, 0.1, 1.3, CFrame.new(0, hairTop + 0.4, 0.1) * CFrame.Angles(0.15, 0, 0) * U.AxisY, hatColor, { Material = Enum.Material.Neon, Transparency = 0.2 })
	elseif hat == "TopHat" then
		local bandC = if hatColor.R + hatColor.G + hatColor.B > 1.6 then U.Shade(hatColor, 0.35) else GOLD
		local hcf = CFrame.new(0, 0.82 + lift, 0.08) * CFrame.Angles(-0.05, 0, 0.06)
		cyl(head, 0.1, 2.2, hcf * U.AxisY, hatColor) -- brim
		cyl(head, 1.0, 1.4, hcf * CFrame.new(0, 0.52, 0) * U.AxisY, hatColor)
		cyl(head, 0.24, 1.44, hcf * CFrame.new(0, 0.2, 0) * U.AxisY, bandC)
	elseif hat == "Jester" then
		local alt = U.Vivid(GOLD)
		ball(head, 2.06, CFrame.new(0, 0.42, 0.12), hatColor)
		for _, s in { -1, 1 } do
			local base = CFrame.new(0.5 * s, 1.05, 0.15) * CFrame.Angles(0, 0, -0.95 * s)
			local tipCf = cone(head, base, 0.75, 1.0, 3, if s < 0 then hatColor else alt)
			ball(head, 0.3, tipCf, if s < 0 then alt else hatColor) -- bell
		end
	elseif hat == "NurseCap" then
		local ncf = CFrame.new(0, hairTop - 0.12, -0.15) * CFrame.Angles(-0.35, 0, 0)
		block(head, Vector3.new(1.25, 0.45, 0.55), ncf, hatColor)
		block(head, Vector3.new(1.3, 0.12, 0.6), ncf * CFrame.new(0, -0.2, 0), U.Shade(hatColor, 0.9)) -- folded band
		block(head, Vector3.new(0.34, 0.1, 0.04), ncf * CFrame.new(0, 0.02, -0.29), RED)
		block(head, Vector3.new(0.1, 0.34, 0.04), ncf * CFrame.new(0, 0.02, -0.29), RED)
	elseif hat == "HeadMirror" then
		cyl(head, 0.14, 2.08, CFrame.new(0, 0.62, 0.05) * U.AxisY, U.Shade(hatColor, 0.45)) -- head band
		local n = Vector3.new(0.3, 0.3, -1).Unit
		local pos = Vector3.new(0.36, 0.75, -0.98)
		cyl(head, 0.08, 0.75, U.DiscFacing(pos, n), hatColor, { Material = Enum.Material.Metal, Reflectance = 0.4 })
		cyl(head, 0.1, 0.16, U.DiscFacing(pos + n * 0.01, n), EYE)
	elseif hat == "SailorCap" then
		local scf = CFrame.new(0.05, 1.0 + lift, 0.12) * CFrame.Angles(0.1, 0, -0.12)
		cyl(head, 0.5, 1.7, scf * CFrame.new(0, 0.28, 0) * U.AxisY, hatColor)
		cyl(head, 0.24, 2.0, scf * U.AxisY, hatColor) -- turned-up brim
		cyl(head, 0.07, 2.03, scf * CFrame.new(0, 0.05, 0) * U.AxisY, NAVY)
	elseif hat == "Bandana" then
		local c = Vector3.new(0, 0.4, 0.14)
		ball(head, 2.08, CFrame.new(c), hatColor)
		for _, d in { Vector3.new(-0.45, 0.55, -0.7), Vector3.new(0.4, 0.75, -0.5), Vector3.new(0.05, 0.95, 0.3) } do
			ball(head, 0.2, CFrame.new(c + d.Unit * 1.02), WHITE) -- polka dots
		end
		local knotC = U.Shade(hatColor, 0.85)
		ball(head, 0.38, CFrame.new(0.1, 0.35, 1.12), knotC)
		block(head, Vector3.new(0.22, 0.6, 0.08), CFrame.new(-0.05, 0.0, 1.18) * CFrame.Angles(0.2, 0, 0.3), knotC)
		block(head, Vector3.new(0.22, 0.55, 0.08), CFrame.new(0.25, 0.02, 1.16) * CFrame.Angles(0.2, 0, -0.25), knotC)
	elseif hat == "Tricorn" then
		local tcf = CFrame.new(0, 0.95 + lift, 0.1)
		cyl(head, 0.6, 1.55, tcf * CFrame.new(0, 0.25, 0) * U.AxisY, hatColor)
		for i = 0, 2 do
			local side = tcf * CFrame.Angles(0, math.pi / 3 + i * 2 * math.pi / 3, 0) * CFrame.new(0, 0.15, -0.68) * CFrame.Angles(-0.4, 0, 0)
			block(head, Vector3.new(2.3, 0.5, 0.1), side, hatColor)
			block(head, Vector3.new(2.3, 0.08, 0.14), side * CFrame.new(0, 0.26, 0), GOLD, METAL_MAT) -- gold trim
		end
	elseif hat == "KnightHelm" then
		-- open-faced helm: covers the top, back and sides; the face shows through
		local steel = hatColor
		ball(head, 2.2, CFrame.new(0, 0.3, 0.32), steel, METAL_MAT)
		cyl(head, 0.16, 2.26, CFrame.new(0, 0.3, 0.32), U.Shade(steel, 0.8), METAL_MAT) -- crest ridge
		local n = Vector3.new(0, 0.45, -0.9).Unit
		local vcf = U.Facing(Vector3.new(0, 0.3, 0.32) + n * 1.12, n)
		block(head, Vector3.new(1.5, 0.42, 0.12), vcf, steel, METAL_MAT) -- raised visor
		block(head, Vector3.new(1.1, 0.08, 0.05), vcf * CFrame.new(0, 0, -0.07), EYE) -- visor slit
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.14, 0.75, 0.6), CFrame.new(0.9 * s, -0.2, -0.35), steel, METAL_MAT) -- cheek guard
		end
		local plume = U.Vivid(look.Shirt)
		ball(head, 0.42, CFrame.new(0, 1.48, 0.05), plume)
		wedge(head, Vector3.new(0.22, 0.75, 0.9), CFrame.new(0, 1.6, 0.55) * CFrame.Angles(0.3, 0, 0), plume)
	elseif hat == "Wizard" then
		local wcf = CFrame.new(0, 0.85 + lift, 0.12) * CFrame.Angles(-0.12, 0, 0.1)
		cyl(head, 0.1, 2.5, wcf * U.AxisY, hatColor) -- brim
		cyl(head, 0.2, 1.6, wcf * CFrame.new(0, 0.12, 0) * U.AxisY, GOLD) -- band
		local tipCf = cone(head, wcf * CFrame.new(0, 0.05, 0), 1.55, 1.45, 4, hatColor)
		ball(head, 0.24, tipCf, GOLD)
		local star = wcf * CFrame.new(0.1, 0.55, -0.62) * CFrame.Angles(-0.12, 0, 0)
		block(head, Vector3.new(0.24, 0.24, 0.05), star, GOLD)
		block(head, Vector3.new(0.24, 0.24, 0.05), star * CFrame.Angles(0, 0, math.pi / 4), GOLD)
	elseif hat == "Crown" then
		local ccf = CFrame.new(0, hairTop - 0.05, 0.1)
		cyl(head, 0.42, 1.35, ccf * U.AxisY, hatColor, METAL_MAT)
		for i = 0, 4 do
			wedge(head, Vector3.new(0.32, 0.42, 0.22), ccf * CFrame.Angles(0, i * 2 * math.pi / 5, 0) * CFrame.new(0, 0.4, -0.56), hatColor, METAL_MAT)
		end
		ball(head, 0.26, ccf * CFrame.new(0, 0, -0.68), RED, { Reflectance = 0.3 }) -- front gem
	elseif hat == "Crystal" then
		-- floating circlet of small glowing crystals; the centre one is a tall point
		local y = hairTop + 0.15
		local glowOpts = { Material = Enum.Material.Neon, Transparency = 0.1 }
		for i = -2, 2 do
			local p = CFrame.new(0, 0, 0.12) * CFrame.Angles(0, i * 0.55, 0) * CFrame.new(0, y - math.abs(i) * 0.12, -0.72)
			if i == 0 then
				block(head, Vector3.new(0.3, 0.5, 0.3), p * CFrame.Angles(0, math.pi / 4, 0), U.Vivid(hatColor), { Reflectance = 0.3 })
				block(head, Vector3.new(0.3, 0.3, 0.3), p * CFrame.new(0, 0.25, 0) * U.VertexUp, hatColor, glowOpts)
			else
				local sz = 0.28 - math.abs(i) * 0.03
				block(head, Vector3.new(sz, sz, sz), p * U.VertexUp, hatColor, glowOpts)
			end
		end
	elseif hat == "Pith" then
		-- explorer's pith helmet: dome, wide brim, dark band and a top button
		local pcf = CFrame.new(0, 0.55 + lift, 0.08) * CFrame.Angles(-0.06, 0, 0)
		ball(head, 2.12, pcf * CFrame.new(0, 0.1, 0), hatColor)
		cyl(head, 0.1, 2.75, pcf * CFrame.new(0, -0.02, 0) * U.AxisY, U.Shade(hatColor, 0.92)) -- brim
		cyl(head, 0.18, 2.15, pcf * CFrame.new(0, 0.14, 0) * U.AxisY, U.Shade(hatColor, 0.55)) -- band
		ball(head, 0.26, pcf * CFrame.new(0, 1.16, 0), U.Shade(hatColor, 0.8))
	elseif hat == "Earmuffs" then
		-- arched head band and two fluffy muffs
		local bandC = U.Shade(hatColor, 0.55)
		local pts: { Vector3 } = {}
		for i = 0, 4 do
			local a = math.rad(15 + i * 37.5)
			table.insert(pts, Vector3.new(math.cos(a) * 1.08, 0.1 + math.sin(a) * (1.2 + lift), 0.05))
		end
		for i = 1, #pts - 1 do
			rod(head, pts[i], pts[i + 1], 0.14, bandC, METAL_MAT)
		end
		for _, s in { -1, 1 } do
			ball(head, 0.8, CFrame.new(1.0 * s, 0.05, 0.05), hatColor)
			cyl(head, 0.1, 0.55, CFrame.new(1.37 * s, 0.05, 0.05), U.Mix(hatColor, WHITE, 0.5))
		end
	elseif hat == "Nemes" then
		-- striped pharaoh headdress: cap, side lappets, back tail and a little cobra
		local isGold = hatColor.R > 0.8 and hatColor.G > 0.6 and hatColor.B < 0.55
		local stripe = if isGold then Color3.fromRGB(40, 80, 170) else GOLD
		local c = Vector3.new(0, 0.42, 0.14)
		ball(head, 2.1, CFrame.new(c), hatColor)
		for _, h in { 0.3, 0.68 } do
			local rr = math.sqrt(1.05 * 1.05 - h * h)
			cyl(head, 0.1, rr * 2 + 0.06, CFrame.new(c + Vector3.new(0, h, 0)) * U.AxisY, stripe)
		end
		for _, s in { -1, 1 } do
			local lp = CFrame.new(0.88 * s, -0.45, -0.25) * CFrame.Angles(0, 0, 0.08 * s)
			block(head, Vector3.new(0.3, 1.1, 0.55), lp, hatColor)
			for _, y in { 0.2, -0.2 } do
				block(head, Vector3.new(0.33, 0.08, 0.58), lp * CFrame.new(0, y, 0), stripe)
			end
		end
		block(head, Vector3.new(0.7, 0.9, 0.3), CFrame.new(0, -0.35, 0.95), hatColor) -- back tail
		block(head, Vector3.new(0.12, 0.3, 0.1), CFrame.new(0, 0.88, -0.84), GOLD, METAL_MAT) -- cobra
		ball(head, 0.17, CFrame.new(0, 1.05, -0.86), GOLD, METAL_MAT)
	elseif hat == "Propeller" then
		-- beach-ball beanie with a spinning-ready propeller
		local alt = U.Vivid(GOLD)
		ball(head, 2.06, CFrame.new(0, 0.42, 0.12), hatColor)
		cyl(head, 0.12, 2.1, CFrame.new(0, 0.42, 0.12), alt) -- stripe over the top, front to back
		cyl(head, 0.16, 2.1, CFrame.new(0, 0.48, 0.12) * U.AxisY, alt) -- band
		cyl(head, 0.3, 0.1, CFrame.new(0, 1.55, 0.12) * U.AxisY, METAL, METAL_MAT)
		ball(head, 0.2, CFrame.new(0, 1.72, 0.12), alt)
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.7, 0.05, 0.22), CFrame.new(0.38 * s, 1.72, 0.12) * CFrame.Angles(0.25 * s, 0, 0), if s < 0 then RED else Color3.fromRGB(60, 140, 255))
		end
	elseif hat == "DivingHelmet" then
		-- brass dome over the whole head with a round front window (face shows through)
		local dark = U.Shade(hatColor, 0.75)
		ball(head, 2.6, CFrame.new(0, 0.2, 0.4), hatColor, METAL_MAT)
		local wc = CFrame.new(0, -0.1, -0.86)
		for _, p in U.Hoop(0.62, 0.18, 0.3, 10, head.CFrame * wc, dark, model, METAL_MAT) do
			add(head, p)
		end
		cyl(head, 0.04, 1.1, wc * CFrame.new(0, 0, -0.2) * U.AxisZ, U.Vivid(look.Beam), { Transparency = 0.75, Reflectance = 0.3, Shadow = false }) -- glass
		for i = 0, 3 do
			ball(head, 0.14, wc * CFrame.Angles(0, 0, math.pi / 4 + i * math.pi / 2) * CFrame.new(0, 0.62, -0.16), METAL, METAL_MAT) -- bolts
		end
		cyl(head, 0.25, 0.4, CFrame.new(0, 1.52, 0.4) * U.AxisY, dark, METAL_MAT) -- air valve
		for _, s in { -1, 1 } do
			cyl(head, 0.2, 0.5, CFrame.new(1.3 * s, 0.25, 0.4), dark, METAL_MAT) -- side ports
		end
		cyl(head, 0.25, 2.4, CFrame.new(0, -0.95, 0.25) * U.AxisY, dark, METAL_MAT) -- collar
	elseif hat == "Gears" then
		-- brass gear crown with a cog emblem on the front and one on the side
		local ccf = CFrame.new(0, hairTop - 0.05, 0.1)
		cyl(head, 0.36, 1.4, ccf * U.AxisY, hatColor, METAL_MAT)
		for i = 0, 7 do
			block(head, Vector3.new(0.24, 0.26, 0.2), ccf * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0.28, -0.62), hatColor, METAL_MAT)
		end
		local fg = ccf * CFrame.new(0, 0.22, -0.74)
		for _, p in U.Gear(0.6, 0.1, 8, head.CFrame * fg, U.Shade(hatColor, 0.8), model, METAL_MAT) do
			add(head, p)
		end
		ball(head, 0.2, fg * CFrame.new(0, 0, -0.06), U.Vivid(look.Beam))
		for _, p in U.Gear(0.45, 0.08, 6, head.CFrame * ccf * CFrame.new(0.74, 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0), U.Shade(hatColor, 0.9), model, METAL_MAT) do
			add(head, p)
		end
	elseif hat == "Bow" then
		-- big ribbon bow perched on the top-right of the head
		local c = look.HatColor or Color3.fromRGB(255, 110, 170)
		local bcf = CFrame.new(0.45, hairTop - 0.12, 0.05) * CFrame.Angles(0, 0, -0.3)
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.7, 0.55, 0.24), bcf * CFrame.new(0.38 * s, 0.06, 0) * CFrame.Angles(0, 0, 0.3 * s), c) -- loop
			block(head, Vector3.new(0.16, 0.45, 0.1), bcf * CFrame.new(0.16 * s, -0.3, -0.04) * CFrame.Angles(0, 0, 0.35 * s), U.Shade(c, 0.85)) -- tail
		end
		ball(head, 0.34, bcf, U.Shade(c, 0.85)) -- knot
	elseif hat == "WitchHat" then
		-- wide brim, banded cone and a floppy bent tip
		local c = look.HatColor or Color3.fromRGB(70, 40, 110)
		local wcf = CFrame.new(0, 0.85 + lift, 0.12) * CFrame.Angles(-0.1, 0, -0.08)
		cyl(head, 0.1, 2.7, wcf * U.AxisY, c) -- brim
		cyl(head, 0.22, 1.5, wcf * CFrame.new(0, 0.14, 0) * U.AxisY, U.Vivid(look.Beam)) -- band
		block(head, Vector3.new(0.3, 0.26, 0.06), wcf * CFrame.new(0, 0.14, -0.76), GOLD, METAL_MAT) -- buckle
		local tipCf = cone(head, wcf * CFrame.new(0, 0.05, 0), 1.45, 1.1, 3, c)
		local floppy = cone(head, tipCf * CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, -0.8), 0.48, 0.6, 2, c)
		ball(head, 0.16, floppy, c)
	elseif hat == "PumpkinHelm" then
		-- whole-head pumpkin with a carved, warmly lit face, ribs and a curly stem
		local c = look.HatColor or Color3.fromRGB(255, 140, 40)
		local carve = Color3.fromRGB(255, 225, 90)
		local pc = Vector3.new(0, 0.2, 0.05)
		local r = 1.22
		ball(head, r * 2, CFrame.new(pc), c)
		for _, a in { -0.75, 0.75 } do
			cyl(head, 0.08, r * 2 + 0.06, CFrame.new(pc) * CFrame.Angles(0, a, 0), U.Shade(c, 0.8)) -- ribs
		end
		cyl(head, 0.4, 0.22, CFrame.new(pc + Vector3.new(0, r + 0.12, 0)) * CFrame.Angles(0, 0, 0.2) * U.AxisY, Color3.fromRGB(90, 140, 60)) -- stem
		wedge(head, Vector3.new(0.06, 0.2, 0.42), CFrame.new(pc + Vector3.new(0.22, r - 0.02, 0)) * CFrame.Angles(0, math.pi / 2, 0.3), Color3.fromRGB(110, 190, 80)) -- leaf
		local function carved(dir: Vector3, size: Vector3, roll: number)
			local n = dir.Unit
			block(head, size, U.Facing(pc + n * (r - 0.02), n) * CFrame.Angles(0, 0, roll), carve)
		end
		for _, s in { -1, 1 } do
			carved(Vector3.new(0.38 * s, 0.12, -1), Vector3.new(0.32, 0.32, 0.1), math.pi / 4) -- diamond eyes
		end
		carved(Vector3.new(0, -0.38, -1), Vector3.new(0.9, 0.24, 0.14), 0) -- grin
		for _, x in { -0.18, 0.18 } do
			local n = Vector3.new(0, -0.38, -1).Unit
			block(head, Vector3.new(0.16, 0.12, 0.08), U.Facing(pc + n * (r + 0.03), n) * CFrame.new(x, 0.06, 0), c) -- teeth
		end
	elseif hat == "FlowerHead" then
		-- ring of round petals framing the face; the toothy grin is drawn below
		local c = look.HatColor or Color3.fromRGB(255, 120, 190)
		local light = U.Mix(c, WHITE, 0.35)
		for i = 0, 7 do
			local pcf = CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 1.12, 0)
			cyl(head, 0.12, 0.7, pcf * U.AxisZ, if i % 2 == 0 then c else light)
		end
		-- little toothy grin under the eyes (replaces the default smile)
		local n = Vector3.new(0, -0.3, -0.9).Unit
		local g = U.Facing(n * 0.93, n)
		block(head, Vector3.new(0.5, 0.18, 0.08), g, MOUTH)
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.2, 0.13, 0.08), g * CFrame.new(0.3 * s, 0.04, 0.005) * CFrame.Angles(0, 0, 0.45 * s), MOUTH)
		end
		for _, x in { -0.14, 0, 0.14 } do
			wedge(head, Vector3.new(0.04, 0.09, 0.09), g * CFrame.new(x, 0.085, -0.045) * CFrame.Angles(0, 0, -math.pi / 4) * U.AxisZ, WHITE) -- fangs
		end
	elseif hat == "HeroMask" then
		-- domino mask: two curved lenses round the eyes (eyes peek through), bridge and head band
		local c = look.HatColor or Color3.fromRGB(40, 40, 60)
		for _, s in { -1, 1 } do
			local n = Vector3.new(0.36 * s, 0.05, -0.85).Unit
			local mcf = U.Facing(n * 0.97, n)
			block(head, Vector3.new(0.62, 0.42, 0.08), mcf, c)
			wedge(head, Vector3.new(0.08, 0.22, 0.26), mcf * CFrame.new(0.38 * s, 0.1, 0) * CFrame.Angles(0, math.pi / 2 * s, 0), c) -- pointed tip
		end
		block(head, Vector3.new(0.3, 0.16, 0.1), U.Facing(Vector3.new(0, 0.12, -0.95), Vector3.new(0, 0.12, -1).Unit), c) -- bridge
		cyl(head, 0.14, 2.04, CFrame.new(0, 0.08, 0) * U.AxisY, c) -- band
	elseif hat == "Tiara" then
		-- small metal tiara sitting on the front of the hair, with a centre gem
		local c = look.HatColor or Color3.fromRGB(225, 225, 240)
		local rf = CFrame.new(0, hairTop - 1.0, 0.2) * CFrame.Angles(-0.25, 0, 0)
		for _, a in { -0.5, 0, 0.5 } do
			block(head, Vector3.new(0.45, 0.08, 0.06), rf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.6, -0.8), c, METAL_MAT) -- band
		end
		for i = -2, 2 do
			local sz = 0.34 - math.abs(i) * 0.08
			block(head, Vector3.new(sz, sz, 0.05), rf * CFrame.Angles(0, i * 0.38, 0) * CFrame.new(0, 0.6 + sz * 0.45, -0.8) * CFrame.Angles(0, 0, math.pi / 4), c, METAL_MAT) -- points
		end
		ball(head, 0.2, rf * CFrame.new(0, 0.72, -0.84), U.Vivid(look.Beam), { Reflectance = 0.3 }) -- gem
	elseif hat == "MoonHood" then
		-- deep hood with a gold crescent moon (gold disc half-covered by a hood-coloured one)
		local c = look.HatColor or Color3.fromRGB(45, 50, 110)
		local hc = Vector3.new(0, 0.22, 0.3)
		ball(head, 2.25, CFrame.new(hc), c)
		wedge(head, Vector3.new(0.55, 0.9, 0.7), CFrame.new(0, 1.2, 0.75) * CFrame.Angles(-0.3, 0, 0), c)
		local n = Vector3.new(0, 0.6, -0.8).Unit
		local mcf = U.Facing(hc + n * 1.12, n)
		cyl(head, 0.06, 0.52, mcf * U.AxisZ, GOLD)
		cyl(head, 0.06, 0.44, mcf * CFrame.new(0.12, 0.07, -0.03) * U.AxisZ, c)
		block(head, Vector3.new(0.12, 0.12, 0.05), mcf * CFrame.new(0.3, 0.22, -0.01) * CFrame.Angles(0, 0, math.pi / 4), GOLD) -- star
	elseif hat == "ChefHat" then
		-- tall chef's toque: band plus three puffs on top
		local c = look.HatColor or WHITE
		cyl(head, 0.6, 1.9, CFrame.new(0, 0.82, 0.1) * U.AxisY, c)
		cyl(head, 0.06, 1.94, CFrame.new(0, 0.6, 0.1) * U.AxisY, U.Shade(c, 0.88)) -- seam
		for _, p in { Vector3.new(-0.42, 1.35, 0.15), Vector3.new(0.42, 1.35, 0.15), Vector3.new(0, 1.55, 0.05) } do
			ball(head, 1.15, CFrame.new(p), c)
		end
	elseif hat == "LanternRing" then
		-- ring of five little paper lanterns floating round the head (warm cores)
		local c = look.HatColor or RED
		for i = 0, 4 do
			local a = i * 2 * math.pi / 5 + math.pi / 5
			local p = Vector3.new(math.sin(a) * 1.05, hairTop + 0.5 + math.cos(a * 2) * 0.08, 0.15 - math.cos(a) * 1.05)
			paperLantern(head, p, 0.46, c, true, false)
		end
	elseif hat == "Specs" then
		-- round glasses: two rims round the eyes, bridge and arms back to the ears
		local c = look.HatColor or Color3.fromRGB(60, 50, 50)
		for _, s in { -1, 1 } do
			local n = Vector3.new(0.34 * s, 0.02, -0.8).Unit
			for _, p in U.Hoop(0.27, 0.07, 0.07, 10, head.CFrame * U.Facing(n * 1.04, n), c, model, METAL_MAT) do
				add(head, p)
			end
			rod(head, n * 1.04 + Vector3.new(0.3 * s, 0.05, 0.08), Vector3.new(0.9 * s, 0.12, 0.05), 0.06, c, METAL_MAT) -- arm
		end
		block(head, Vector3.new(0.16, 0.06, 0.06), CFrame.new(0, 0.1, -0.99), c, METAL_MAT) -- bridge
	elseif hat == "BookHat" then
		-- open book perched like a tent: two covers sloping down from the spine, pages underneath
		local c = look.HatColor or Color3.fromRGB(150, 60, 60)
		local scf = CFrame.new(0, hairTop + 0.32, 0.12) * CFrame.Angles(0, 0.15, 0)
		cyl(head, 1.25, 0.14, scf * U.AxisZ, U.Shade(c, 0.7)) -- spine
		for _, s in { -1, 1 } do
			local side = scf * CFrame.Angles(0, 0, -0.61 * s)
			block(head, Vector3.new(1.0, 0.07, 1.2), side * CFrame.new(0.5 * s, 0, 0), c)
			block(head, Vector3.new(0.92, 0.12, 1.1), side * CFrame.new(0.48 * s, -0.09, 0), CREAM) -- pages
		end
	elseif hat == "Roof" then
		-- tiny house roof: gable from two wedges, brick chimney with a puff of smoke
		local c = look.HatColor or Color3.fromRGB(150, 60, 50)
		local rcf = CFrame.new(0, 0.62, 0.1)
		spike(head, rcf, 2.5, 1.05, 2.2, c)
		block(head, Vector3.new(2.6, 0.12, 2.3), rcf * CFrame.new(0, 0.02, 0), U.Shade(c, 0.7)) -- eaves
		block(head, Vector3.new(0.36, 0.7, 0.36), rcf * CFrame.new(0.62, 0.75, 0.35), Color3.fromRGB(165, 80, 60)) -- chimney
		ball(head, 0.42, rcf * CFrame.new(0.66, 1.32, 0.38), Color3.fromRGB(215, 215, 225), { Transparency = 0.25 }) -- smoke
	elseif hat == "ShroomCap" then
		-- mushroom cap: rim plus dome, white spots
		local c = look.HatColor or Color3.fromRGB(220, 60, 60)
		local base = CFrame.new(0, 0.82, 0.1)
		cyl(head, 0.3, 2.7, base * U.AxisY, c)
		cyl(head, 0.06, 2.55, base * CFrame.new(0, -0.16, 0) * U.AxisY, CREAM) -- gills
		ball(head, 2.3, base * CFrame.new(0, 0.18, 0), c)
		for _, d in { Vector3.new(0, 1, -0.55), Vector3.new(-0.7, 0.55, -0.45), Vector3.new(0.75, 0.6, -0.35), Vector3.new(-0.45, 0.7, 0.55), Vector3.new(0.5, 0.75, 0.45) } do
			ball(head, 0.4, base * CFrame.new(Vector3.new(0, 0.18, 0) + d.Unit * 1.1), WHITE)
		end
	elseif hat == "ShroomCrown" then
		-- ring of six little glowing toadstools round the crown
		local c = look.HatColor or Color3.fromRGB(255, 120, 200)
		for i = 0, 5 do
			local a = i * math.pi / 3 + math.pi / 6
			-- each toadstool leans outward from the crown: short stem, wide flat cap
			local tcf = CFrame.new(0, hairTop - 0.32, 0.15) * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -0.74) * CFrame.Angles(-0.4, 0, 0)
			cyl(head, 0.3, 0.14, tcf * CFrame.new(0, 0.12, 0) * U.AxisY, CREAM)
			cyl(head, 0.14, 0.48, tcf * CFrame.new(0, 0.3, 0) * U.AxisY, c, NEON)
		end
	elseif hat == "PrismCrown" then
		-- seven reflective crystal shards with small rainbow tips
		local c = look.HatColor or Color3.fromRGB(220, 240, 255)
		for i = -3, 3 do
			local h = 0.75 - math.abs(i) * 0.1
			local p = CFrame.new(0, hairTop - 0.2, 0.15) * CFrame.Angles(0, i * 0.48, 0) * CFrame.new(0, 0, -0.74) * CFrame.Angles(-0.35, 0, 0) * CFrame.new(0, h / 2, 0)
			block(head, Vector3.new(0.2, h, 0.2), p * CFrame.Angles(0, math.pi / 4, 0), U.Mix(c, RAINBOW[i + 4], 0.3), { Reflectance = 0.4 })
			block(head, Vector3.new(0.17, 0.17, 0.17), p * CFrame.new(0, h / 2, 0) * U.VertexUp, RAINBOW[i + 4], NEON)
		end
	elseif hat == "ConductorCap" then
		-- flat-topped round cap with a short brim and a gold badge
		local c = look.HatColor or NAVY
		local ccf = CFrame.new(0, 0.88 + lift, 0.1) * CFrame.Angles(-0.08, 0, 0)
		cyl(head, 0.55, 2.0, ccf * U.AxisY, c)
		cyl(head, 0.1, 2.06, ccf * CFrame.new(0, -0.2, 0) * U.AxisY, U.Shade(c, 0.6)) -- band
		block(head, Vector3.new(1.3, 0.08, 0.55), ccf * CFrame.new(0, -0.26, -1.18) * CFrame.Angles(0.15, 0, 0), U.Shade(c, 0.55)) -- brim
		block(head, Vector3.new(0.38, 0.26, 0.06), ccf * CFrame.new(0, 0.02, -1.0), GOLD, METAL_MAT) -- badge
	elseif hat == "Headphones" then
		-- arched head band and two ear cups with small glowing rims
		local c = look.HatColor or Color3.fromRGB(40, 40, 50)
		local pts: { Vector3 } = {}
		for i = 0, 4 do
			local a = math.rad(15 + i * 37.5)
			table.insert(pts, Vector3.new(math.cos(a) * 1.08, 0.1 + math.sin(a) * (1.22 + lift), 0.05))
		end
		for i = 1, #pts - 1 do
			bar(head, pts[i], pts[i + 1], 0.32, 0.14, c)
		end
		for _, s in { -1, 1 } do
			cyl(head, 0.32, 0.8, CFrame.new(1.0 * s, 0.05, 0.05), c)
			cyl(head, 0.05, 0.5, CFrame.new(1.18 * s, 0.05, 0.05), look.Beam, NEON) -- rim light
		end
	elseif hat == "TVHead" then
		-- an old TV for a head: box, screen with a face, side knobs and V antennas
		local c = look.HatColor or Color3.fromRGB(90, 80, 70)
		local screen = Color3.fromRGB(120, 150, 170)
		local face = Color3.fromRGB(235, 245, 255)
		block(head, Vector3.new(2.3, 1.95, 1.9), CFrame.new(0, 0.18, 0.05), c)
		block(head, Vector3.new(1.55, 1.3, 0.08), CFrame.new(-0.25, 0.2, -0.9), screen, { Reflectance = 0.15 })
		for _, x in { -0.6, 0.1 } do
			block(head, Vector3.new(0.24, 0.3, 0.06), CFrame.new(x, 0.35, -0.95), face) -- eyes
		end
		block(head, Vector3.new(0.6, 0.1, 0.06), CFrame.new(-0.25, -0.12, -0.95), face) -- smile
		for i, y in { 0.45, 0.0 } do
			cyl(head, 0.12, 0.26, CFrame.new(0.8, y, -0.95) * U.AxisZ, if i == 1 then GOLD else U.Shade(c, 0.6)) -- knobs
		end
		for _, s in { -1, 1 } do
			local tip = Vector3.new(0.65 * s, 2.05, 0.1)
			rod(head, Vector3.new(0.05 * s, 1.15, 0.1), tip, 0.07, METAL, METAL_MAT)
			ball(head, 0.16, CFrame.new(tip), METAL, METAL_MAT)
		end
	elseif hat == "StormCloud" then
		-- small cloud floating above the head with a little glowing lightning zig-zag hanging off it
		local c = look.HatColor or Color3.fromRGB(150, 155, 175)
		local y = hairTop + 0.75
		for _, q in { { -0.62, 0, 0.8 }, { -0.15, 0.22, 1.0 }, { 0.35, 0.12, 0.92 }, { 0.75, -0.05, 0.7 }, { 0.1, -0.1, 0.85 } } do
			ball(head, q[3], CFrame.new(q[1], y + q[2], 0.2), c)
		end
		local bolt = U.Vivid(look.Beam)
		local z = -0.05
		local p0, p1, p2, p3 = Vector3.new(0.55, y - 0.3, z), Vector3.new(0.75, y - 0.62, z), Vector3.new(0.6, y - 0.7, z), Vector3.new(0.82, y - 1.05, z)
		bar(head, p0, p1, 0.12, 0.08, bolt, NEON)
		bar(head, p1, p2, 0.12, 0.08, bolt, NEON)
		bar(head, p2, p3, 0.1, 0.08, bolt, NEON)
	elseif hat == "SpaceHelmet" then
		-- glass bubble round the whole head and a white collar ring
		local c = look.HatColor or WHITE
		ball(head, 2.6, CFrame.new(0, 0.15, 0.05), Color3.fromRGB(225, 240, 255), { Transparency = 0.65, Reflectance = 0.2, Shadow = false })
		cyl(head, 0.3, 2.05, CFrame.new(0, -0.95, 0.05) * U.AxisY, c)
		cyl(head, 0.08, 2.15, CFrame.new(0, -0.82, 0.05) * U.AxisY, U.Vivid(look.Beam)) -- trim
	elseif hat == "EarHood" then
		-- snug hood with the face showing and two round bear ears on top
		local c = look.HatColor or WHITE
		ball(head, 2.25, CFrame.new(0, 0.25, 0.25), c)
		for _, s in { -1, 1 } do
			ball(head, 0.52, CFrame.new(0.62 * s, 1.27, 0.25), c)
		end
	elseif hat == "StarCrown" then
		-- floating crown: five glowing star tips on an invisible ring, a gem in the middle
		local c = look.HatColor or GOLD
		if lum(c) < 0.4 then
			c = WHITE -- a dark crown would read as a hole; the stars always shine
		end
		local y = if style == "Floaty" then 2.45 else hairTop + 0.42
		for i = 0, 4 do
			local a = i * 2 * math.pi / 5
			local scf = CFrame.new(0, y + (if i == 0 then 0.12 else 0), 0.12) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.8)
			local sz = if i == 0 then 0.36 else 0.28
			block(head, Vector3.new(sz, sz, 0.06), scf * CFrame.Angles(0, 0, math.pi / 4), c, NEON) -- diamond star
		end
		block(head, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, y + 0.1, 0.12) * U.VertexUp, U.Vivid(look.Beam), { Reflectance = 0.4 })
	-- EXCLUSIVES (world2c): premium hats of the 16 World 2 Exclusive-crate hunters (one each)
	elseif hat == "ExDragonCrown" then
		-- gold dragon headdress: circlet, two branching dragon horns, a ruby over the brow, red tassels
		local c = hatColor
		local red = Color3.fromRGB(215, 40, 50)
		cyl(head, 0.2, 2.02, CFrame.new(0, 0.45, 0.05) * U.AxisY, c, { Material = Enum.Material.Metal, Reflectance = 0.2 })
		for _, s in { -1, 1 } do
			local h0 = Vector3.new(0.5 * s, 0.75, 0.05)
			local h1 = Vector3.new(0.82 * s, 1.45, 0.3)
			rod(head, h0, h1, 0.16, c, METAL_MAT)
			rod(head, h1, Vector3.new(1.1 * s, 1.75, 0.15), 0.11, c, METAL_MAT) -- outer branch
			rod(head, h1, Vector3.new(0.72 * s, 1.95, 0.55), 0.12, c, METAL_MAT) -- tip curls back
			ball(head, 0.3, CFrame.new(1.0 * s, 0.05, -0.05), red) -- tassel
		end
		block(head, Vector3.new(0.28, 0.28, 0.28), CFrame.new(0, 0.62, -0.88) * U.VertexUp, red, { Reflectance = 0.3 }) -- ruby
	elseif hat == "ExArcaneHat" then
		-- tall archmage hat: wide brim, four-step cone flopping back at the tip, gold band, gem and stars
		local c = hatColor
		local alt = U.Mix(c, Color3.fromRGB(120, 80, 220), 0.35)
		local tilt = CFrame.Angles(-0.1, 0, 0)
		cyl(head, 0.1, 2.75, CFrame.new(0, 0.74, 0.12) * tilt * U.AxisY, c)
		local tipCf = cone(head, CFrame.new(0, 0.76, 0.14) * tilt, 1.75, 1.55, 4, c, alt)
		cone(head, tipCf * CFrame.new(0, -0.08, 0) * CFrame.Angles(0.95, 0, 0), 0.5, 0.65, 2, alt, c)
		cyl(head, 0.2, 1.8, CFrame.new(0, 0.92, 0.13) * tilt * U.AxisY, GOLD, METAL_MAT) -- band
		block(head, Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0.94, -0.8) * U.VertexUp, Color3.fromRGB(80, 230, 200), { Reflectance = 0.3 })
		for _, q in { { 0.22, 1.42, -0.52, 0.3 }, { -0.25, 1.78, -0.32, 0.22 } } do
			block(head, Vector3.new(q[4], q[4], 0.06), CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(-0.45, 0, math.pi / 4), GOLD, METAL_MAT) -- stars
		end
	elseif hat == "ExJackHelm" then
		-- jack-o'-lantern knight helm: ribbed pumpkin dome, carved visor flipped up, stem with curly vine and leaves
		local c = hatColor
		local dark = Color3.fromRGB(70, 30, 15)
		local green = Color3.fromRGB(80, 150, 60)
		ball(head, 2.2, CFrame.new(0, 0.5, 0.25), c)
		for _, s in { -1, 1 } do
			ball(head, 1.55, CFrame.new(0.58 * s, 0.5, 0.32), U.Shade(c, 0.88)) -- ribs
		end
		cyl(head, 0.5, 0.34, CFrame.new(0.05, 1.68, 0.3) * CFrame.Angles(0, 0, 0.25) * U.AxisY, Color3.fromRGB(110, 120, 50)) -- stem
		rod(head, Vector3.new(0.1, 1.75, 0.3), Vector3.new(-0.55, 1.95, 0.55), 0.08, green) -- vine
		spike(head, CFrame.new(0.3, 1.55, 0.55) * CFrame.Angles(0.2, 0.5, -0.9), 0.5, 0.7, 0.06, green) -- leaves
		spike(head, CFrame.new(-0.55, 1.95, 0.55) * CFrame.Angles(0.1, -0.4, 0.7), 0.4, 0.55, 0.06, U.Shade(green, 1.2))
		local vcf = CFrame.new(0, 1.25, -0.72) * CFrame.Angles(-0.85, 0, 0)
		block(head, Vector3.new(1.3, 0.55, 0.14), vcf, U.Mix(c, Color3.fromRGB(255, 200, 80), 0.25)) -- visor
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.2, 0.2, 0.05), vcf * CFrame.new(0.3 * s, 0.06, -0.07) * CFrame.Angles(0, 0, math.pi / 4), dark) -- carved eyes
		end
		block(head, Vector3.new(0.62, 0.09, 0.05), vcf * CFrame.new(0, -0.15, -0.07), dark) -- carved grin
	elseif hat == "ExShroomQueen" then
		-- mushroom-queen cap: big spotted dome with a pale gill brim, gold tiara under it, a baby mushroom on top
		local c = hatColor
		local cc = Vector3.new(0, 1.25, 0.15)
		cyl(head, 0.12, 3.0, CFrame.new(0, 0.98, 0.15) * U.AxisY, Color3.fromRGB(255, 225, 235)) -- gills
		ball(head, 2.45, CFrame.new(cc), c)
		for _, q in { { 0.5, 0.55, -0.65, 0.42 }, { -0.62, 0.5, -0.45, 0.36 }, { 0.12, 0.95, 0.2, 0.38 }, { 0.85, 0.45, 0.2, 0.3 } } do
			local n = Vector3.new(q[1], q[2], q[3]).Unit
			ball(head, q[4], CFrame.new(cc + n * 1.15), WHITE) -- spots
		end
		for i = -1, 1 do
			local h = if i == 0 then 0.3 else 0.22
			block(head, Vector3.new(h, h, h), CFrame.new(i * 0.32, 0.78 + (if i == 0 then 0.05 else 0), -0.82 + math.abs(i) * 0.08) * U.VertexUp, GOLD, METAL_MAT) -- tiara
		end
		cyl(head, 0.3, 0.16, CFrame.new(0.35, 2.55, 0.1) * U.AxisY, CREAM) -- baby mushroom
		ball(head, 0.45, CFrame.new(0.35, 2.72, 0.1), Color3.fromRGB(110, 230, 210))
	elseif hat == "ExCaptainHat" then
		-- white captain's cap: navy band, gold braid and anchor badge, black peak and a little shark fin on top
		local c = hatColor
		local navy = Color3.fromRGB(30, 45, 110)
		local tilt = CFrame.Angles(-0.1, 0, 0)
		cyl(head, 0.5, 1.98, CFrame.new(0, 0.74, 0.12) * tilt * U.AxisY, navy)
		cyl(head, 0.34, 2.3, CFrame.new(0, 1.08, 0.18) * tilt * U.AxisY, c)
		block(head, Vector3.new(1.3, 0.09, 0.55), CFrame.new(0, 0.6, -0.98) * CFrame.Angles(0.28, 0, 0), Color3.fromRGB(25, 25, 35), { Reflectance = 0.2 }) -- peak
		block(head, Vector3.new(1.25, 0.09, 0.08), CFrame.new(0, 0.7, -0.92), GOLD, METAL_MAT) -- braid
		local ac = CFrame.new(0, 1.0, -1.06) * CFrame.Angles(-0.1, 0, 0)
		block(head, Vector3.new(0.08, 0.34, 0.06), ac, GOLD, METAL_MAT) -- anchor
		block(head, Vector3.new(0.26, 0.07, 0.06), ac * CFrame.new(0, 0.1, 0), GOLD, METAL_MAT)
		block(head, Vector3.new(0.3, 0.07, 0.06), ac * CFrame.new(0, -0.16, 0), GOLD, METAL_MAT)
		wedge(head, Vector3.new(0.1, 0.55, 0.55), CFrame.new(0, 1.5, 0.35), Color3.fromRGB(95, 140, 185)) -- fin
	elseif hat == "ExMirrorHelm" then
		-- crystal knight helm: polished dome, cheek guards, a crest of three crystal spires, a gem on the brow
		local c = hatColor
		local crystal = Color3.fromRGB(190, 240, 255)
		local glassy = { Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.3 }
		ball(head, 2.1, CFrame.new(0, 0.45, 0.25), c, { Material = Enum.Material.Metal, Reflectance = 0.35 })
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.2, 0.85, 0.75), CFrame.new(0.92 * s, -0.12, -0.15) * CFrame.Angles(0, 0, 0.12 * s), c, { Material = Enum.Material.Metal, Reflectance = 0.35 })
		end
		for i = -1, 1 do
			local h = if i == 0 then 1.15 else 0.8
			local scf = CFrame.new(i * 0.42, 1.25, 0.3) * CFrame.Angles(0, 0, -0.35 * i) * CFrame.new(0, h / 2, 0)
			block(head, Vector3.new(0.3, h, 0.3), scf * CFrame.Angles(0, math.pi / 4, 0), crystal, glassy)
			block(head, Vector3.new(0.3, 0.3, 0.3), scf * CFrame.new(0, h / 2, 0) * U.VertexUp, crystal, glassy) -- tip
		end
		block(head, Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0.72, -0.86) * U.VertexUp, Color3.fromRGB(120, 220, 255), { Reflectance = 0.4 })
	elseif hat == "ExVIPHat" then
		-- glam wide-brim sun hat with a feather and a huge diamond brooch, plus rose-tinted star shades
		local c = hatColor
		local tilt = CFrame.Angles(-0.12, 0, -0.12)
		cyl(head, 0.08, 3.1, CFrame.new(0.08, 0.86, 0.1) * tilt * U.AxisY, c)
		cyl(head, 0.55, 1.8, CFrame.new(0.12, 1.12, 0.12) * tilt * U.AxisY, c)
		cyl(head, 0.2, 1.84, CFrame.new(0.1, 0.98, 0.12) * tilt * U.AxisY, Color3.fromRGB(40, 30, 40)) -- band
		block(head, Vector3.new(0.42, 0.42, 0.42), CFrame.new(-0.05, 1.0, -0.88) * U.VertexUp, Color3.fromRGB(225, 250, 255), { Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.5 }) -- diamond
		spike(head, CFrame.new(-0.55, 1.15, 0.4) * CFrame.Angles(0.3, 0.3, 0.55), 0.35, 1.2, 0.06, WHITE) -- feather
		local lens = Color3.fromRGB(150, 40, 90)
		for _, s in { -1, 1 } do
			local n = Vector3.new(0.34 * s, 0.03, -0.8).Unit
			block(head, Vector3.new(0.5, 0.36, 0.06), U.Facing(n * 1.08, n) * CFrame.Angles(0, 0, 0.1 * s), lens, { Reflectance = 0.35 })
		end
		block(head, Vector3.new(0.18, 0.06, 0.05), CFrame.new(0, 0.1, -1.03), GOLD, METAL_MAT) -- bridge
	elseif hat == "ExPhantomCap" then
		-- tall ghost-line conductor cap: gold band and badge, black peak, a tiny ghost riding on top
		local c = hatColor
		local tilt = CFrame.Angles(-0.08, 0, 0)
		cyl(head, 0.75, 1.96, CFrame.new(0, 0.88, 0.1) * tilt * U.AxisY, c)
		cyl(head, 0.12, 2.06, CFrame.new(0, 1.26, 0.13) * tilt * U.AxisY, U.Shade(c, 0.8))
		cyl(head, 0.13, 1.99, CFrame.new(0, 0.62, 0.08) * tilt * U.AxisY, GOLD, METAL_MAT) -- band
		block(head, Vector3.new(1.25, 0.09, 0.52), CFrame.new(0, 0.55, -0.98) * CFrame.Angles(0.3, 0, 0), Color3.fromRGB(20, 20, 30), { Reflectance = 0.2 }) -- peak
		cyl(head, 0.06, 0.38, U.DiscFacing(Vector3.new(0, 0.95, -0.98), Vector3.new(0, 0.05, -1)), GOLD, METAL_MAT) -- badge
		local g = Vector3.new(0.3, 1.62, 0.15)
		ball(head, 0.7, CFrame.new(g), Color3.fromRGB(235, 255, 250), { Transparency = 0.15 }) -- ghost
		wedge(head, Vector3.new(0.3, 0.35, 0.45), CFrame.new(g + Vector3.new(0.25, -0.15, 0.3)) * CFrame.Angles(0, -0.6, 0.6), Color3.fromRGB(235, 255, 250), { Transparency = 0.15 })
		for _, s in { -1, 1 } do
			ball(head, 0.12, CFrame.new(g + Vector3.new(0.12 * s, 0.05, -0.3)), EYE)
		end
	elseif hat == "ExRexSkull" then
		-- fossil T. rex skull helm: bone dome, snout jutting over the brow with a row of fangs, amber crown
		local c = hatColor
		local amber = Color3.fromRGB(255, 160, 40)
		ball(head, 2.15, CFrame.new(0, 0.5, 0.3), c)
		local sn = CFrame.new(0, 1.05, -0.62) * CFrame.Angles(0.18, 0, 0)
		block(head, Vector3.new(1.3, 0.5, 1.05), sn, c)
		ball(head, 0.6, CFrame.new(0, 1.12, -1.15), c) -- snout tip
		for i = 0, 3 do
			wedge(head, Vector3.new(0.09, 0.26, 0.16), sn * CFrame.new(-0.42 + i * 0.28, -0.32, -0.45) * CFrame.Angles(math.pi, 0, 0), WHITE) -- fangs
		end
		for _, s in { -1, 1 } do
			ball(head, 0.36, CFrame.new(0.52 * s, 1.22, -0.35), Color3.fromRGB(70, 55, 45)) -- eye sockets
		end
		for i = -1, 1 do
			local h = if i == 0 then 0.36 else 0.26
			block(head, Vector3.new(h, h, h), CFrame.new(i * 0.4, 1.62 - math.abs(i) * 0.12, 0.35) * U.VertexUp, amber, { Transparency = 0.15, Reflectance = 0.3 })
		end
	elseif hat == "ExTrophyCrown" then
		-- champion's crown: polished gold band whose five points are tiny trophy cups, a star gem in front
		local c = hatColor
		local mat = { Material = Enum.Material.Metal, Reflectance = 0.25 }
		cyl(head, 0.38, 2.04, CFrame.new(0, 0.82, 0.12) * U.AxisY, c, mat)
		for i = 0, 4 do
			local pcf = CFrame.new(0, 1.0, 0.12) * CFrame.Angles(0, math.rad(-64 + i * 32), 0) * CFrame.new(0, 0, -0.86)
			cyl(head, 0.32, 0.1, pcf * CFrame.new(0, 0.16, 0) * U.AxisY, c, mat) -- stem
			cyl(head, 0.24, 0.34, pcf * CFrame.new(0, 0.42, 0) * U.AxisY, c, mat) -- cup
		end
		block(head, Vector3.new(0.3, 0.3, 0.07), CFrame.new(0, 0.82, -1.03) * CFrame.Angles(0, 0, math.pi / 4), RED, { Reflectance = 0.3 }) -- gem
	elseif hat == "ExDJHeadset" then
		-- big DJ headphones with coloured rims, a mic boom and wraparound tinted shades
		local c = hatColor
		local rim = Color3.fromRGB(255, 80, 200)
		for _, s in { -1, 1 } do
			cyl(head, 0.38, 0.9, CFrame.new(1.0 * s, 0.1, 0.05), c)
			cyl(head, 0.1, 1.0, CFrame.new(1.16 * s, 0.1, 0.05), rim)
			rod(head, Vector3.new(1.0 * s, 0.5, 0.05), Vector3.new(0.6 * s, 1.25, 0.05), 0.16, c)
		end
		rod(head, Vector3.new(-0.62, 1.22, 0.05), Vector3.new(0.62, 1.22, 0.05), 0.16, c) -- headband
		rod(head, Vector3.new(1.0, -0.15, -0.25), Vector3.new(0.4, -0.5, -0.92), 0.06, c) -- mic boom
		ball(head, 0.18, CFrame.new(0.38, -0.5, -0.95), Color3.fromRGB(40, 40, 50))
		block(head, Vector3.new(1.55, 0.32, 0.1), CFrame.new(0, 0.05, -0.93), Color3.fromRGB(90, 240, 255), { Transparency = 0.35, Reflectance = 0.4 }) -- shades
	elseif hat == "ExRoyalToque" then
		-- royal pastry chef's toque: puffy top, gold crown round the band, a cherry on top
		local c = hatColor
		cyl(head, 0.45, 2.0, CFrame.new(0, 0.78, 0.12) * U.AxisY, c)
		for _, q in { { -0.38, 1.35, -0.05 }, { 0.38, 1.35, -0.05 }, { -0.3, 1.38, 0.4 }, { 0.3, 1.38, 0.4 } } do
			ball(head, 1.1, CFrame.new(q[1], q[2], q[3]), c)
		end
		ball(head, 1.2, CFrame.new(0, 1.75, 0.15), c)
		cyl(head, 0.2, 2.06, CFrame.new(0, 0.66, 0.12) * U.AxisY, GOLD, { Material = Enum.Material.Metal, Reflectance = 0.25 })
		for i = -1, 1 do
			block(head, Vector3.new(0.24, 0.24, 0.24), CFrame.new(i * 0.42, 0.88, -0.9 + math.abs(i) * 0.12) * U.VertexUp, GOLD, METAL_MAT) -- crown points
		end
		ball(head, 0.38, CFrame.new(0, 2.45, 0.15), RED) -- cherry
		rod(head, Vector3.new(0, 2.6, 0.15), Vector3.new(0.18, 2.88, 0.2), 0.05, Color3.fromRGB(70, 120, 50))
	elseif hat == "ExBossHelm" then
		-- final-boss helmet: dark dome, see-through holo visor, side fins and a crown of pixel blocks
		local c = hatColor
		local holo = Color3.fromRGB(80, 255, 230)
		local pink = Color3.fromRGB(255, 90, 230)
		ball(head, 2.12, CFrame.new(0, 0.45, 0.22), c)
		block(head, Vector3.new(1.65, 0.4, 0.2), CFrame.new(0, 0.02, -0.9), holo, { Transparency = 0.5 })
		for _, s in { -1, 1 } do
			wedge(head, Vector3.new(0.12, 0.7, 0.8), CFrame.new(1.02 * s, 0.6, 0.35) * CFrame.Angles(-0.4, 0, 0), pink) -- fins
		end
		for i = -2, 2 do
			local h = if i == 0 then 0.42 elseif math.abs(i) == 1 then 0.2 else 0.3
			block(head, Vector3.new(0.26, 0.26 + h, 0.26), CFrame.new(i * 0.3, 1.45 + h / 2 - math.abs(i) * 0.1, 0.1 + math.abs(i) * 0.06), if i % 2 == 0 then pink else holo)
		end
	elseif hat == "ExWingedHelm" then
		-- silver sky-rider helm with feathered wings on both sides and a gold lightning crest
		local c = hatColor
		ball(head, 2.06, CFrame.new(0, 0.55, 0.2), c, { Material = Enum.Material.Metal, Reflectance = 0.3 })
		for _, s in { -1, 1 } do
			local base = CFrame.new(1.0 * s, 0.7, 0.25) * CFrame.Angles(0, math.pi / 2, 0)
			spike(head, base * CFrame.Angles(0, 0, 0.75 * s) * CFrame.Angles(0, 0, 0), 0.45, 1.25, 0.08, WHITE)
			spike(head, base * CFrame.new(0, -0.15, 0.06 * s) * CFrame.Angles(0, 0, 1.15 * s), 0.4, 0.95, 0.08, Color3.fromRGB(200, 225, 255))
		end
		local y = GOLD
		bar(head, Vector3.new(0.1, 1.95, -0.1), Vector3.new(-0.12, 1.5, -0.45), 0.2, 0.1, y, METAL_MAT)
		bar(head, Vector3.new(-0.12, 1.5, -0.45), Vector3.new(0.12, 1.42, -0.5), 0.2, 0.1, y, METAL_MAT)
		bar(head, Vector3.new(0.12, 1.42, -0.5), Vector3.new(-0.05, 0.98, -0.82), 0.2, 0.1, y, METAL_MAT)
	elseif hat == "ExAstroHelm" then
		-- glass astronaut bubble with a chunky collar ring, ear pods and an antenna with a little light
		local c = hatColor
		ball(head, 2.6, CFrame.new(0, 0.28, 0.05), Color3.fromRGB(235, 245, 255), { Transparency = 0.65, Reflectance = 0.2, Shadow = false })
		cyl(head, 0.32, 2.05, CFrame.new(0, -1.0, 0.05) * U.AxisY, c)
		cyl(head, 0.12, 2.12, CFrame.new(0, -0.86, 0.05) * U.AxisY, Color3.fromRGB(255, 150, 70)) -- stripe
		for _, s in { -1, 1 } do
			cyl(head, 0.22, 0.62, CFrame.new(1.22 * s, 0.25, 0.05), c)
		end
		rod(head, Vector3.new(-1.25, 0.4, 0.05), Vector3.new(-1.4, 1.35, 0.15), 0.06, METAL, METAL_MAT)
		ball(head, 0.2, CFrame.new(-1.41, 1.42, 0.15), Color3.fromRGB(255, 90, 90), NEON) -- antenna light
	elseif hat == "ExCosmicCrown" then
		-- cosmic emperor's crown: deep violet band with gold rims, three tall points tipped with stars, a galaxy gem
		local c = hatColor
		cyl(head, 0.45, 2.0, CFrame.new(0, 0.86, 0.12) * U.AxisY, c)
		for _, y in { 0.63, 1.09 } do
			cyl(head, 0.09, 2.08, CFrame.new(0, y, 0.12) * U.AxisY, GOLD, METAL_MAT)
		end
		for i = -1, 1 do
			local h = if i == 0 then 1.15 else 0.8
			local pcf = CFrame.new(0, 1.05, 0.12) * CFrame.Angles(0, -i * 0.75, 0) * CFrame.new(0, 0, -0.9) * CFrame.Angles(-0.12, 0, 0)
			spike(head, pcf, 0.5, h, 0.1, c)
			block(head, Vector3.new(0.22, 0.22, 0.22), pcf * CFrame.new(0, h + 0.08, 0) * U.VertexUp, GOLD, { Reflectance = 0.4 })
		end
		block(head, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.86, -1.02) * U.VertexUp, Color3.fromRGB(200, 120, 255), { Reflectance = 0.4 })
	elseif hat == "Nightcap" then
		-- striped sleeping cap with a fluffy brim that flops over to one side, pompom on the end
		local c = look.HatColor or Color3.fromRGB(90, 120, 220)
		local alt = U.Mix(c, WHITE, 0.5)
		local base = CFrame.new(0, 0.58 + lift, 0.14) * CFrame.Angles(-0.12, 0, 0.1)
		cyl(head, 0.3, 2.12, base * U.AxisY, CREAM) -- fluffy brim
		local tipCf = cone(head, base * CFrame.new(0, 0.12, 0), 1.95, 1.0, 3, c, alt)
		local floppy = cone(head, tipCf * CFrame.new(0, -0.12, 0) * CFrame.Angles(0, 0, -1.35), 0.66, 0.85, 2, alt, c)
		ball(head, 0.52, floppy, CREAM) -- pompom
	elseif hat == "BookHead" then
		-- the whole head is a storybook standing on end: covers front and back, spine on the left, cream
		-- page edges, a goofy face on the front cover and a ribbon bookmark sticking out like a tongue
		local c = look.HatColor or Color3.fromRGB(40, 90, 70)
		local eye = U.Mix(U.Vivid(look.Beam), WHITE, 0.35)
		local bc = Vector3.new(0, 0.15, 0)
		block(head, Vector3.new(2.15, 2.3, 1.9), CFrame.new(bc + Vector3.new(0.08, 0, 0)), CREAM) -- pages
		for _, z in { -1, 1 } do
			block(head, Vector3.new(2.35, 2.45, 0.14), CFrame.new(bc + Vector3.new(0, 0, 1.0 * z)), c) -- covers
		end
		block(head, Vector3.new(0.22, 2.45, 2.14), CFrame.new(bc + Vector3.new(-1.1, 0, 0)), U.Shade(c, 0.7)) -- spine
		for _, y in { 0.8, -0.8 } do
			block(head, Vector3.new(0.26, 0.12, 2.16), CFrame.new(bc + Vector3.new(-1.1, y, 0)), GOLD, METAL_MAT) -- spine bands
		end
		local fz = -1.08
		for _, s in { -1, 1 } do
			cyl(head, 0.06, 0.64, CFrame.new(0.42 * s, 0.32, fz) * U.AxisZ, eye) -- eyes
			cyl(head, 0.08, 0.3, CFrame.new(0.42 * s + 0.06, 0.28, fz - 0.02) * U.AxisZ, EYE) -- pupils
			for _, y in { 1.17, -1.17 } do
				block(head, Vector3.new(0.3, 0.3, 0.18), CFrame.new(1.05, bc.Y + y, 1.0 * s), GOLD, METAL_MAT) -- corner caps
			end
		end
		block(head, Vector3.new(0.9, 0.16, 0.06), CFrame.new(0, -0.32, fz), EYE) -- grin
		block(head, Vector3.new(1.1, 0.14, 0.05), CFrame.new(0, 1.0, fz), GOLD) -- title
		block(head, Vector3.new(0.24, 0.7, 0.05), CFrame.new(0.2, -1.1, fz - 0.02) * CFrame.Angles(0, 0, 0.15), RED) -- bookmark tongue
	elseif hat == "WeatherVane" then
		-- rain cap with a little weather vane on top: compass cross with knobs and a turning arrow
		local c = look.HatColor or RED
		ball(head, 2.04, CFrame.new(0, 0.45, 0.12), c)
		cyl(head, 0.1, 1.3, CFrame.new(0, 0.55, -0.95) * CFrame.Angles(-0.12, 0, 0) * U.AxisY, U.Shade(c, 0.85)) -- peak
		local top = Vector3.new(0, 1.42, 0.12)
		rod(head, top, top + Vector3.new(0, 1.1, 0), 0.08, METAL, METAL_MAT)
		local cy = top + Vector3.new(0, 0.38, 0)
		rod(head, cy - Vector3.new(0.5, 0, 0), cy + Vector3.new(0.5, 0, 0), 0.05, METAL, METAL_MAT)
		rod(head, cy - Vector3.new(0, 0, 0.5), cy + Vector3.new(0, 0, 0.5), 0.05, METAL, METAL_MAT)
		for _, d in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			ball(head, 0.14, CFrame.new(cy + d * 0.5), GOLD, METAL_MAT)
		end
		local acf = CFrame.new(top + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, 0.45, 0)
		block(head, Vector3.new(1.1, 0.08, 0.06), acf, U.Shade(c, 0.45)) -- arrow shaft
		spike(head, acf * CFrame.new(0.55, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2), 0.4, 0.34, 0.07, GOLD) -- point
		block(head, Vector3.new(0.36, 0.36, 0.06), acf * CFrame.new(-0.55, 0, 0) * CFrame.Angles(0, 0, math.pi / 4), c) -- tail fin
	elseif hat == "HardHat" then
		-- builder's hard hat with a copper-coiled lightning rod sticking up and a spark on its tip
		local c = look.HatColor or Color3.fromRGB(255, 200, 40)
		local copper = Color3.fromRGB(205, 120, 60)
		local hcf = CFrame.new(0, 0.5 + lift, 0.1)
		ball(head, 2.14, hcf, c)
		cyl(head, 0.1, 2.6, hcf * CFrame.new(0, -0.02, 0) * U.AxisY, U.Shade(c, 0.85)) -- brim
		cyl(head, 0.22, 2.2, hcf, U.Shade(c, 0.85)) -- ridge
		local n = Vector3.new(0, 0.45, -0.9).Unit
		cyl(head, 0.06, 0.46, U.DiscFacing(hcf.Position + n * 1.06, n), WHITE) -- sticker
		block(head, Vector3.new(0.18, 0.18, 0.04), U.Facing(hcf.Position + n * 1.09, n) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(40, 40, 50))
		local r0 = Vector3.new(0.3, 1.45 + lift, 0.25)
		rod(head, r0, r0 + Vector3.new(0, 1.1, 0), 0.08, copper, METAL_MAT)
		for i = 0, 2 do
			cyl(head, 0.07, 0.3, CFrame.new(r0 + Vector3.new(0, 0.3 + i * 0.16, 0)) * U.AxisY, U.Shade(copper, 0.8), METAL_MAT) -- coil
		end
		ball(head, 0.26, CFrame.new(r0 + Vector3.new(0, 1.18, 0)), U.Vivid(look.Beam), NEON)
	elseif hat == "SkyTricorn" then
		-- sky-pirate tricorn with gold trim and a little propeller spinning on top
		local tcf = CFrame.new(0, 0.95 + lift, 0.1)
		cyl(head, 0.6, 1.55, tcf * CFrame.new(0, 0.25, 0) * U.AxisY, hatColor)
		for i = 0, 2 do
			local side = tcf * CFrame.Angles(0, math.pi / 3 + i * 2 * math.pi / 3, 0) * CFrame.new(0, 0.15, -0.68) * CFrame.Angles(-0.4, 0, 0)
			block(head, Vector3.new(2.3, 0.5, 0.1), side, hatColor)
			block(head, Vector3.new(2.3, 0.08, 0.14), side * CFrame.new(0, 0.26, 0), GOLD, METAL_MAT) -- gold trim
		end
		cyl(head, 0.3, 0.1, tcf * CFrame.new(0, 0.7, 0) * U.AxisY, METAL, METAL_MAT)
		ball(head, 0.2, tcf * CFrame.new(0, 0.86, 0), GOLD, METAL_MAT)
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.95, 0.05, 0.24), tcf * CFrame.new(0.48 * s, 0.86, 0) * CFrame.Angles(0.3 * s, 0, 0), if s < 0 then WHITE else U.Vivid(look.Beam))
		end
		spike(head, tcf * CFrame.new(0.7, 0.35, 0.2) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.9), 0.36, 1.3, 0.1, WHITE) -- feather plume
	elseif hat == "BirdMask" then
		-- storm-bird helmet: feathered hood, a big golden beak over the brow, three crest feathers swept
		-- back and a lightning streak down each side
		local c = look.HatColor or Color3.fromRGB(40, 90, 200)
		local alt = U.Vivid(look.Beam)
		ball(head, 2.16, CFrame.new(0, 0.36, 0.16), c)
		-- hooked beak hanging down in front of the nose from the brow of the hood
		block(head, Vector3.new(0.5, 0.2, 0.4), CFrame.new(0, 0.55, -0.98) * CFrame.Angles(0.3, 0, 0), GOLD) -- brow plate
		wedge(head, Vector3.new(0.36, 0.5, 0.8), CFrame.new(0, 0.12, -1.12) * CFrame.Angles(-math.pi / 2, 0, 0), GOLD) -- beak
		for i = -1, 1 do
			local h = if i == 0 then 1.25 else 0.95
			local fcf = CFrame.new(0.3 * i, 1.15, 0.35) * CFrame.Angles(0, 0, -0.3 * i) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.75)
			spike(head, fcf, 0.42, h, 0.12, if i == 0 then alt else U.Mix(c, WHITE, 0.25))
		end
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.5, 0.12, 0.06), U.Facing(Vector3.new(0.36 * s, 0.32, -0.85).Unit * 1.06, Vector3.new(0.36 * s, 0.32, -0.85).Unit) * CFrame.Angles(0, 0, 0.3 * s), EYE) -- fierce brow
			bar(head, Vector3.new(0.98 * s, 0.6, -0.2), Vector3.new(1.08 * s, 0.25, 0.15), 0.16, 0.06, alt)
			bar(head, Vector3.new(1.05 * s, 0.32, 0.05), Vector3.new(1.0 * s, -0.1, 0.45), 0.12, 0.06, alt)
		end
	elseif hat == "TempestCrown" then
		-- gold band crowned with five tall zig-zag lightning bolts and a ring of storm clouds behind
		local c = look.HatColor or GOLD
		local bolt = U.Vivid(look.Beam)
		local ccf = CFrame.new(0, hairTop - 0.3, 0.15)
		cyl(head, 0.32, 1.6, ccf * U.AxisY, c, METAL_MAT)
		for i = -2, 2 do
			local h = 1.3 - math.abs(i) * 0.25
			local f = ccf * CFrame.Angles(0, i * 0.6, 0) * CFrame.new(0, 0.12, -0.74) * CFrame.Angles(-0.25, 0, 0)
			local p0 = f.Position
			local p1 = (f * CFrame.new(0.14, h * 0.55, 0)).Position
			local p2 = (f * CFrame.new(-0.12, h * 0.5, 0)).Position
			local p3 = (f * CFrame.new(0.05, h, 0)).Position
			bar(head, p0, p1, 0.24, 0.08, bolt)
			bar(head, p1, p2, 0.16, 0.08, bolt)
			bar(head, p2, p3, 0.16, 0.08, bolt, if i == 0 then NEON else nil)
		end
		for i = 0, 2 do
			local a = i * math.pi / 2
			ball(head, 0.7, ccf * CFrame.new(math.cos(a) * 0.95, 0.15, math.sin(a) * 0.8), Color3.fromRGB(205, 210, 235))
		end
		block(head, Vector3.new(0.3, 0.3, 0.3), ccf * CFrame.new(0, 0.02, -0.8) * U.VertexUp, Color3.fromRGB(80, 150, 255), { Reflectance = 0.3 }) -- gem
	elseif hat == "StrawHat" then
		-- wide floppy farmer's straw hat: brim dipping at the front, rounded crown, dark band, loose straws
		local c = hatColor
		local scf = CFrame.new(0, 0.8 + lift, 0.1) * CFrame.Angles(-0.12, 0, 0.05)
		cyl(head, 0.08, 3.0, scf * U.AxisY, c) -- brim
		cyl(head, 0.55, 1.5, scf * CFrame.new(0, 0.3, 0) * U.AxisY, c) -- crown
		ball(head, 1.3, scf * CFrame.new(0, 0.2, 0), c) -- rounded top
		cyl(head, 0.16, 1.54, scf * CFrame.new(0, 0.12, 0) * U.AxisY, U.Shade(c, 0.55)) -- band
		local straw = U.Mix(c, WHITE, 0.25)
		for i, a in { 0.5, 1.6, 2.7, 3.9, 5.1 } do
			local tilt = if i % 2 == 0 then 0.35 else -0.3
			wedge(head, Vector3.new(0.05, 0.08, 0.34), scf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.55) * CFrame.Angles(tilt, 0.4, 0), straw)
		end
	elseif hat == "SharkHood" then
		-- shark onesie hood: the face peeks out of the open mouth, white teeth round it, dorsal fin on top
		local c = hatColor
		local hc = Vector3.new(0, 0.25, 0.3)
		ball(head, 2.3, CFrame.new(hc), c)
		block(head, Vector3.new(1.75, 0.3, 0.9), CFrame.new(0, -0.82, -0.25) * CFrame.Angles(0.35, 0, 0), Color3.fromRGB(240, 242, 248)) -- white jaw
		for i = 0, 8 do
			local a = -2.0 + i * 4.0 / 8
			local x, y = math.sin(a) * 0.86, 0.02 + math.cos(a) * 0.86
			local p = Vector3.new(x, y, hc.Z - math.sqrt(math.max(0, 1.15 * 1.15 - x * x - (y - hc.Y) ^ 2)) - 0.02)
			wedge(head, Vector3.new(0.08, 0.3, 0.2), CFrame.new(p) * CFrame.Angles(0, 0, math.pi - a) * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- teeth
		end
		wedge(head, Vector3.new(0.2, 0.95, 0.95), CFrame.new(0, 1.72, 0.55), c) -- dorsal fin
		for _, s in { -1, 1 } do
			wedge(head, Vector3.new(0.1, 0.5, 0.6), CFrame.new(1.12 * s, -0.35, 0.25) * CFrame.Angles(0, 0, -0.85 * s), U.Shade(c, 0.85)) -- side fins
			ball(head, 0.22, CFrame.new(0.46 * s, 1.18, -0.38), EYE)
			for k = 0, 1 do
				block(head, Vector3.new(0.05, 0.36, 0.06), CFrame.new(1.13 * s, 0.35, 0.35 + k * 0.22) * CFrame.Angles(0, 0, -0.25 * s), U.Shade(c, 0.6)) -- gills
			end
		end
	elseif hat == "ElfHat" then
		-- tall pointy elf hat: white fluffy cuff, long cone flopping to one side, a little feather and a bell
		local c = hatColor
		local base = CFrame.new(0, 0.6 + lift, 0.14) * CFrame.Angles(-0.1, 0, 0.08)
		cyl(head, 0.32, 2.12, base * U.AxisY, WHITE) -- cuff
		local tipCf = cone(head, base * CFrame.new(0, 0.14, 0), 1.95, 1.25, 3, c)
		local floppy = cone(head, tipCf * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, -0.75), 0.62, 0.8, 2, c)
		ball(head, 0.34, floppy, GOLD, METAL_MAT) -- bell
		spike(head, base * CFrame.new(0.78, 0.35, 0.15) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, -0.35), 0.24, 0.85, 0.06, RED) -- feather
	elseif hat == "DinoHood" then
		-- dinosaur hood: snout over the brow (face visible under it) with nostrils, little teeth and eyes,
		-- and a ridge of spikes running from the forehead down the back
		local c = hatColor
		local alt = look.Pants
		local hc = Vector3.new(0, 0.25, 0.3)
		ball(head, 2.3, CFrame.new(hc), c)
		local sn = CFrame.new(0, 0.86, -0.8) * CFrame.Angles(0.12, 0, 0)
		block(head, Vector3.new(1.3, 0.55, 0.95), sn, c) -- snout
		for _, s in { -1, 1 } do
			ball(head, 0.12, sn * CFrame.new(0.25 * s, 0.12, -0.47), U.Shade(c, 0.45)) -- nostrils
			ball(head, 0.3, sn * CFrame.new(0.36 * s, 0.32, 0.1), WHITE) -- eyes
			ball(head, 0.15, sn * CFrame.new(0.36 * s, 0.36, -0.03), EYE)
		end
		for i = -2, 2 do
			wedge(head, Vector3.new(0.05, 0.17, 0.14), sn * CFrame.new(i * 0.25, -0.34, -0.45) * CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- teeth
		end
		for _, phi in { -0.1, 0.45, 1.0, 1.55, 2.1 } do
			local p = hc + Vector3.new(0, math.cos(phi), math.sin(phi)) * 1.08
			wedge(head, Vector3.new(0.12, 0.42, 0.42), CFrame.new(p) * CFrame.Angles(phi, 0, 0) * CFrame.new(0, 0.15, 0), alt) -- back ridge
		end
	elseif hat == "Thimble" then
		-- sewing thimble worn as a helmet: metal cup with rows of dimples and a rolled rim
		local c = hatColor
		local tcf = CFrame.new(0, 0.55 + lift, 0.12) * CFrame.Angles(-0.08, 0, 0.05)
		local dimple = U.Shade(c, 0.6)
		cyl(head, 1.05, 2.02, tcf * CFrame.new(0, 0.38, 0) * U.AxisY, c, METAL_MAT)
		cyl(head, 0.2, 2.16, tcf * CFrame.new(0, -0.08, 0) * U.AxisY, U.Shade(c, 0.85), METAL_MAT) -- rolled rim
		cyl(head, 0.2, 1.75, tcf * CFrame.new(0, 0.95, 0) * U.AxisY, c, METAL_MAT)
		ball(head, 1.6, tcf * CFrame.new(0, 0.5, 0), c, METAL_MAT) -- rounded top
		for row, y in { 0.28, 0.62 } do
			for i = 0, 5 do
				local a = -1.6 + i * 0.64 + (row - 1) * 0.32
				local n = Vector3.new(math.sin(a), 0, -math.cos(a))
				cyl(head, 0.04, 0.17, U.DiscFacing((tcf * CFrame.new(n * 1.01 + Vector3.new(0, y, 0))).Position, (tcf.Rotation * CFrame.new(n)).Position), dimple)
			end
		end
		for _, p in { Vector3.new(0, 1.12, 0), Vector3.new(0.35, 1.06, -0.2), Vector3.new(-0.35, 1.06, -0.2) } do
			ball(head, 0.14, tcf * CFrame.new(p), dimple)
		end
	elseif hat == "ChompHead" then
		-- big round chomper costume round the head: the face peeks out of the front, an open wedge mouth
		-- on the side, one eye and a little antenna with a ball (our own touch)
		local c = hatColor
		local cc = Vector3.new(0, 0.3, 0.45)
		local r = 1.25
		ball(head, r * 2, CFrame.new(cc), c)
		local mf = CFrame.fromMatrix(Vector3.new(1.08, 0.3, -0.42), Vector3.yAxis, Vector3.zAxis) * CFrame.Angles(0, 0.35, 0)
		spike(head, mf, 1.2, 1.15, 0.3, Color3.fromRGB(45, 25, 30)) -- open mouth
		local en = Vector3.new(0.55, 0.7, -0.45).Unit
		ball(head, 0.36, CFrame.new(cc + en * (r - 0.08)), EYE)
		ball(head, 0.12, CFrame.new(cc + en * (r + 0.06) + Vector3.new(0.02, 0.06, -0.04)), WHITE)
		local a0 = cc + Vector3.new(-0.2, r - 0.1, 0)
		rod(head, a0, a0 + Vector3.new(-0.15, 0.6, 0), 0.07, U.Shade(c, 0.6))
		ball(head, 0.26, CFrame.new(a0 + Vector3.new(-0.16, 0.7, 0)), U.Vivid(look.Beam))
	-- CYBERARCADE (world2c) ---------------------------------------- hats
	elseif hat == "CubeHead" then
		-- blocky miner: the round head hides inside a big skin-coloured cube with a flat 8x8 pixel face,
		-- a voxel hair cap over the top two rows and a hair panel down the back
		local s, u, cy = 2.2, 2.2 / 8, 0.1
		local function px(c: number, r: number, w: number, h: number, color: Color3)
			-- face pixels covering columns c..c+w-1 and rows r..r+h-1 (row 0 = top, column 0 = viewer's right)
			block(head, Vector3.new(w * u, h * u, 0.06), CFrame.new(-s / 2 + (c + w / 2) * u, cy + s / 2 - (r + h / 2) * u, -s / 2 - 0.02), color)
		end
		block(head, Vector3.new(s, s, s), CFrame.new(0, cy, 0), look.Skin)
		block(head, Vector3.new(s + 0.06, 2 * u + 0.02, s + 0.06), CFrame.new(0, cy + 3 * u, 0), hairColor) -- hair cap
		block(head, Vector3.new(s + 0.06, 4 * u, 0.1), CFrame.new(0, cy, s / 2), hairColor) -- back of the hair
		px(0, 2, 1, 1, hairColor) -- sideburns
		px(7, 2, 1, 1, hairColor)
		px(1, 3, 1, 2, WHITE) -- eyes
		px(2, 3, 1, 2, EYE)
		px(5, 3, 1, 2, EYE)
		px(6, 3, 1, 2, WHITE)
		px(2, 5, 1, 1, MOUTH) -- pixel smile
		px(5, 5, 1, 1, MOUTH)
		px(3, 6, 2, 1, MOUTH)
	elseif hat == "ChompBall" then
		-- round chomper: the whole head is one big ball with a wide dark mouth wedged open to the front
		-- and two big eyes on top (the face inside is hidden)
		local c = hatColor
		local r = 1.25
		local cc = Vector3.new(0, 0.12, 0)
		ball(head, r * 2, CFrame.new(cc), c)
		local h, d, w = 0.7, 1.24, 1.9
		local cav = Color3.fromRGB(70, 20, 35)
		wedge(head, Vector3.new(w, h, d), CFrame.new(cc + Vector3.new(0, h / 2, -d / 2)) * CFrame.Angles(0, math.pi, 0), cav) -- upper jaw
		wedge(head, Vector3.new(w, h, d), CFrame.new(cc + Vector3.new(0, -h / 2, -d / 2)) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.pi), cav) -- lower jaw
		for _, s in { -1, 1 } do
			local n = Vector3.new(0.36 * s, 0.72, -0.6).Unit
			ball(head, 0.62, CFrame.new(cc + n * (r - 0.12)), WHITE)
			ball(head, 0.32, CFrame.new(cc + n * (r + 0.08) + Vector3.new(0, -0.04, -0.02)), EYE)
		end
	elseif hat == "PlumberCap" then
		-- plumber's round cap with a short peak and a white badge holding a little gold wrench (no letters)
		local c = hatColor
		ball(head, 2.04, CFrame.new(0, 0.46, 0.12), c)
		cyl(head, 0.1, 1.4, CFrame.new(0, 0.5, -0.95) * CFrame.Angles(-0.12, 0, 0) * U.AxisY, U.Shade(c, 0.85)) -- peak
		local n = Vector3.new(0, 0.5, -0.87).Unit
		local bp = Vector3.new(0, 0.46, 0.12) + n * 1.02
		cyl(head, 0.06, 0.66, U.DiscFacing(bp, n), WHITE) -- badge
		local dcf = U.Facing(bp + n * 0.03, n)
		ball(head, 0.26, dcf * CFrame.new(0, -0.06, 0), Color3.fromRGB(60, 150, 235)) -- water-drop emblem
		spike(head, dcf * CFrame.new(0, 0.0, 0), 0.2, 0.2, 0.1, Color3.fromRGB(60, 150, 235))
	elseif hat == "HeroCap" then
		-- long floppy hero cap: snug dome over the hair, a long cone swept back with a drooping tip, a band
		local c = hatColor
		ball(head, 2.08, CFrame.new(0, 0.44, 0.16), c)
		cyl(head, 0.16, 2.1, CFrame.new(0, 0.42, 0.16) * CFrame.Angles(-0.15, 0, 0) * U.AxisY, U.Shade(c, 0.75)) -- band
		local mid = cone(head, CFrame.new(0, 0.95, 0.5) * CFrame.Angles(1.0, 0, 0), 1.5, 1.35, 3, c)
		local tip = cone(head, mid * CFrame.new(0, -0.05, 0) * CFrame.Angles(0.7, 0, 0), 0.5, 0.75, 2, c)
		ball(head, 0.2, tip, c)
	elseif hat == "Puffball" then
		-- round pink puffball: one big ball swallows head and body (the round face hides inside), with its
		-- own tall oval eyes, rosy cheeks, a tiny mouth, stubby arms and big round feet
		local c = hatColor
		local r = 1.55
		local cc = Vector3.new(0, -0.62, 0)
		local function onBall(x: number, y: number, out: number): Vector3
			local p = Vector3.new(x, y, -math.sqrt(math.max(r * r - x * x - y * y, 0)))
			return cc + p.Unit * (r + out)
		end
		ball(head, r * 2, CFrame.new(cc), c)
		for _, s in { -1, 1 } do
			ball(head, 0.32, CFrame.new(onBall(0.3 * s, 0.44, -0.07)), EYE) -- tall oval eye: dark top...
			ball(head, 0.3, CFrame.new(onBall(0.3 * s, 0.25, -0.07)), Color3.fromRGB(40, 70, 170)) -- ...blue bottom
			ball(head, 0.13, CFrame.new(onBall(0.3 * s + 0.03, 0.5, 0.04)), WHITE)
			local bp = onBall(0.68 * s, 0.05, 0)
			cyl(head, 0.04, 0.36, U.DiscFacing(bp, bp - cc), Color3.fromRGB(255, 100, 140)) -- cheek
			ball(arms[s], 0.8, CFrame.new(0.5 * s, -0.08, 0), c) -- stubby arm
			ball(legs[s], 0.84, CFrame.new(0, -0.17, -0.12), look.Shoes) -- round foot
		end
		ball(head, 0.17, CFrame.new(onBall(0, 0.06, -0.04)), MOUTH)
	elseif hat == "BlockCrown" then
		-- final-boss crown: a gold voxel crown with three square points and a glowing gem
		local c = hatColor
		local y = hairTop
		block(head, Vector3.new(1.5, 0.32, 1.5), CFrame.new(0, y, 0.12), c, { Reflectance = 0.2 })
		for i, x in { -0.55, 0, 0.55 } do
			local ph = if i == 2 then 0.62 else 0.42
			block(head, Vector3.new(0.32, ph, 0.32), CFrame.new(x, y + 0.16 + ph / 2, -0.47), c, { Reflectance = 0.2 })
		end
		block(head, Vector3.new(0.24, 0.24, 0.1), CFrame.new(0, y, -0.65), U.Vivid(look.Beam), NEON) -- gem
	-- end CYBERARCADE (world2c) hats
	elseif hat == "ScarecrowHat" then
		-- floppy pointed field hat with a patch, straw tufts poking out under the brim and a crow on the brim
		local c = hatColor
		local straw = look.Hair
		local wcf = CFrame.new(0, 0.85 + lift, 0.12) * CFrame.Angles(-0.12, 0, 0.12)
		cyl(head, 0.1, 2.8, wcf * U.AxisY, c) -- brim
		local tipCf = cone(head, wcf * CFrame.new(0, 0.05, 0), 1.55, 0.7, 3, c)
		local floppy = cone(head, tipCf * CFrame.new(0, -0.06, 0) * CFrame.Angles(0, 0, 1.5), 0.55, 0.6, 2, c)
		ball(head, 0.2, floppy, c)
		for _, sd in { -1, 1 } do
			for k = -1, 1 do
				wedge(arms[sd], Vector3.new(0.06, 0.32, 0.14), CFrame.new(k * 0.13, -0.5, -0.05) * CFrame.Angles(0, 0, math.pi + k * 0.4) * CFrame.Angles(0, math.pi / 2, 0), straw) -- straw at the cuffs
			end
		end
		block(head, Vector3.new(0.42, 0.34, 0.06), wcf * CFrame.new(0.15, 0.32, -0.66) * CFrame.Angles(-0.45, 0, 0.2), Color3.fromRGB(200, 70, 60)) -- patch
		for _, a in { 0.75, 1.3, 1.85, 2.5, 3.14, 3.8, 4.45, 5.0, 5.55 } do
			wedge(head, Vector3.new(0.08, 0.62, 0.22), wcf * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.22, -1.05) * CFrame.Angles(0.45, 0, 0), straw) -- straw
		end
		local cr = wcf * CFrame.new(-1.0, 0.28, 0.3)
		local crow = Color3.fromRGB(35, 30, 40)
		ball(head, 0.42, cr, crow)
		ball(head, 0.28, cr * CFrame.new(0, 0.26, -0.16), crow)
		wedge(head, Vector3.new(0.08, 0.1, 0.22), cr * CFrame.new(0, 0.24, -0.38), Color3.fromRGB(255, 170, 50)) -- beak
		wedge(head, Vector3.new(0.06, 0.25, 0.3), cr * CFrame.new(0, 0.08, 0.3) * CFrame.Angles(-0.3, 0, 0), crow) -- tail
	elseif hat == "FishHood" then
		-- fish hood: dark swoosh band over the top, bright dorsal fin and two side fins (fin colour = hair)
		local c = hatColor
		local fin = U.Vivid(look.Hair)
		local hc = Vector3.new(0, 0.25, 0.3)
		ball(head, 2.3, CFrame.new(hc), c)
		cyl(head, 0.3, 2.34, CFrame.new(hc) * CFrame.Angles(0, 0.25, 0.45), Color3.fromRGB(30, 30, 55)) -- dark marking
		spike(head, CFrame.new(0, 1.25, 0.45) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, -0.5), 1.1, 0.75, 0.1, fin) -- dorsal fin
		for _, s in { -1, 1 } do
			spike(head, CFrame.new(1.05 * s, -0.25, 0.35) * CFrame.Angles(0, 0, -2.2 * s) * CFrame.Angles(0, 0.3 * s, 0), 0.55, 0.6, 0.08, fin) -- side fins
		end
	elseif hat == "Mannequin" then
		-- shop-window dummy: a smooth sculpted face with no eyes (the face isn't drawn), a neat top hat
		local sk = U.Shade(look.Skin, 0.88)
		wedge(head, Vector3.new(0.16, 0.34, 0.16), CFrame.new(0, -0.05, -0.92), sk) -- nose
		block(head, Vector3.new(0.9, 0.08, 0.1), CFrame.new(0, 0.25, -0.87) * CFrame.Angles(0.3, 0, 0), sk) -- brow line
		cyl(head, 0.1, 0.9, CFrame.new(0, -0.95, 0) * U.AxisY, U.Shade(look.Skin, 0.75)) -- neck joint
		local hcf = CFrame.new(0, 0.82, 0.08) * CFrame.Angles(-0.05, 0, 0.12)
		cyl(head, 0.1, 2.2, hcf * U.AxisY, hatColor) -- brim
		cyl(head, 1.0, 1.4, hcf * CFrame.new(0, 0.52, 0) * U.AxisY, hatColor)
		cyl(head, 0.24, 1.44, hcf * CFrame.new(0, 0.2, 0) * U.AxisY, RED)
	elseif hat == "DuckHelmet" then
		-- hockey helmet with a duck-bill peak, two little duck eyes and a team stripe
		local c = hatColor
		ball(head, 2.12, CFrame.new(0, 0.45, 0.12), c)
		cyl(head, 0.2, 2.16, CFrame.new(0, 0.45, 0.12), U.Vivid(look.Shirt)) -- stripe over the top
		local bcf = CFrame.new(0, 0.6, -1.05) * CFrame.Angles(-0.15, 0, 0)
		local bill = Color3.fromRGB(255, 165, 40)
		block(head, Vector3.new(1.0, 0.16, 0.7), bcf, bill)
		cyl(head, 0.16, 1.0, bcf * CFrame.new(0, 0, -0.35) * U.AxisY, bill) -- round bill tip
		for _, s in { -1, 1 } do
			ball(head, 0.32, CFrame.new(0.4 * s, 1.2, -0.62), WHITE)
			ball(head, 0.16, CFrame.new(0.4 * s, 1.23, -0.76), EYE)
			block(head, Vector3.new(0.2, 0.62, 0.55), CFrame.new(0.97 * s, -0.05, 0.05), U.Shade(c, 0.8)) -- ear guards
		end
	elseif hat == "DinoSkull" then
		-- fossil T-rex skull helmet: bony dome, long toothy upper jaw over the brow, dark eye sockets
		local c = hatColor
		local dark = Color3.fromRGB(70, 55, 45)
		ball(head, 2.25, CFrame.new(0, 0.38, 0.32), c)
		local jw = CFrame.new(0, 0.86, -0.95) * CFrame.Angles(0.1, 0, 0)
		block(head, Vector3.new(1.15, 0.5, 1.3), jw, c) -- upper jaw
		wedge(head, Vector3.new(1.15, 0.3, 1.3), jw * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.pi, 0), c) -- sloping snout top
		for i = -2, 2 do
			if i ~= 0 then
				wedge(head, Vector3.new(0.05, 0.22, 0.15), jw * CFrame.new(i * 0.24, -0.34, -0.6) * CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- front teeth
			end
		end
		for _, s in { -1, 1 } do
			for k = 0, 2 do
				wedge(head, Vector3.new(0.05, 0.2, 0.14), jw * CFrame.new(0.55 * s, -0.33, -0.35 + k * 0.32) * CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- side teeth
			end
			local n = Vector3.new(0.75 * s, 0.55, -0.3).Unit
			cyl(head, 0.08, 0.5, U.DiscFacing(Vector3.new(0, 0.38, 0.32) + n * 1.1, n), dark) -- eye socket
			cyl(head, 0.06, 0.24, U.DiscFacing(Vector3.new(0.25 * s, 1.12, -1.6), Vector3.new(0, 0.3, -1)), dark) -- nostril
		end
	elseif hat == "GingerIcing" then
		-- gingerbread icing: a wavy white piped line round the face, icing cuffs and three gumdrop buttons
		local icing = hatColor
		for i = 0, 13 do
			local a = i * 2 * math.pi / 14
			local rr = 0.97 + (i % 2) * 0.04
			ball(head, 0.17, CFrame.new(math.sin(a) * rr, math.cos(a) * rr, -0.12), icing)
		end
		for i, col in { RED, Color3.fromRGB(90, 200, 90), Color3.fromRGB(255, 210, 60) } do
			ball(torso, 0.24, CFrame.new(0, 0.32 - (i - 1) * 0.3, -0.43), col) -- gumdrops
		end
		for _, s in { -1, 1 } do
			cyl(arms[s], 0.08, 0.46, CFrame.new(0, -0.22, 0) * U.AxisY, icing)
			cyl(legs[s], 0.08, 0.56, CFrame.new(0, -0.05, 0) * U.AxisY, icing)
		end
	elseif hat == "TulipHat" then
		-- upside-down tulip bloom worn as a fairy hat: dome, pointed petals hanging round, curly stem and leaf
		local c = hatColor
		local light = U.Mix(c, WHITE, 0.35)
		local tcf = CFrame.new(0, 0.6 + lift, 0.12)
		ball(head, 2.12, tcf, c)
		for i = 0, 4 do
			local a = math.rad(36 + i * 72)
			local pcf = tcf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.25, -1.1) * CFrame.Angles(0, 0, math.pi)
			spike(head, pcf * CFrame.Angles(0.3, 0, 0), 0.95, 0.8, 0.1, if i % 2 == 0 then c else light)
		end
		local green = Color3.fromRGB(90, 170, 80)
		rod(head, tcf.Position + Vector3.new(0, 0.95, 0), tcf.Position + Vector3.new(0.18, 1.55, 0.05), 0.12, green)
		wedge(head, Vector3.new(0.06, 0.25, 0.55), tcf * CFrame.new(0.3, 1.15, 0.05) * CFrame.Angles(0, math.pi / 2, 0.4), green) -- leaf
	elseif hat == "Bulb" then
		-- giant light bulb over the head (screw cap on top) with a softly glowing filament above the hair
		ball(head, 2.55, CFrame.new(0, 0.32, 0.05), Color3.fromRGB(245, 250, 255), { Transparency = 0.6, Reflectance = 0.2, Shadow = false })
		for i = 0, 2 do
			cyl(head, 0.16, 1.05 - i * 0.12, CFrame.new(0, 1.62 + i * 0.15, 0.05) * U.AxisY, if i % 2 == 0 then Color3.fromRGB(200, 205, 215) else Color3.fromRGB(160, 165, 180), METAL_MAT)
		end
		ball(head, 0.24, CFrame.new(0, 2.02, 0.05), Color3.fromRGB(70, 70, 80))
		for _, s in { -1, 1 } do
			rod(head, Vector3.new(0.2 * s, 1.55, 0.05), Vector3.new(0.3 * s, 1.18, 0.05), 0.05, METAL, METAL_MAT)
		end
		block(head, Vector3.new(0.62, 0.07, 0.07), CFrame.new(0, 1.18, 0.05), U.Mix(hatColor, GOLD, 0.4), NEON) -- filament
	elseif hat == "Shades" then
		-- slim dark sunglasses with a bridge and arms back to the ears
		local lens = Color3.fromRGB(20, 22, 28)
		for _, s in { -1, 1 } do
			local n = Vector3.new(0.34 * s, 0.03, -0.8).Unit
			block(head, Vector3.new(0.5, 0.26, 0.06), U.Facing(n * 1.08, n) * CFrame.Angles(0, 0, 0.06 * s), lens, { Reflectance = 0.35 })
			rod(head, n * 1.06 + Vector3.new(0.24 * s, 0.03, 0.08), Vector3.new(0.92 * s, 0.1, 0.1), 0.05, lens)
		end
		block(head, Vector3.new(0.18, 0.05, 0.05), CFrame.new(0, 0.08, -1.02), lens)
	elseif hat == "Bonnet" then
		-- big frilly shepherdess bonnet framing the face, ribbons tied in a bow under the chin
		local c = hatColor
		ball(head, 2.2, CFrame.new(0, 0.38, 0.38), c)
		for _, p in U.Hoop(1.05, 0.26, 0.18, 8, head.CFrame * CFrame.new(0, 0.12, -0.5) * CFrame.Angles(-0.2, 0, 0), WHITE, model) do
			add(head, p) -- frill
		end
		local rib = U.Shade(c, 0.85)
		ball(head, 0.26, CFrame.new(0, -1.02, -0.6), rib) -- bow
	-- WATERPARK/STADIUM (world2c)
	elseif hat == "GuardHat" then
		-- lifeguard: wide floppy sun hat with a red band, a sun-creamed white nose, whistle on a white cord
		local c = hatColor
		local hcf = CFrame.new(0, 0.82 + lift, 0.12) * CFrame.Angles(-0.12, 0, 0.06)
		cyl(head, 0.08, 2.9, hcf * U.AxisY, c) -- brim
		cyl(head, 0.5, 1.75, hcf * CFrame.new(0, 0.25, 0) * U.AxisY, c) -- crown
		ball(head, 1.6, hcf * CFrame.new(0, 0.25, 0), c) -- rounded top
		cyl(head, 0.18, 1.79, hcf * CFrame.new(0, 0.12, 0) * U.AxisY, RED) -- band
		ball(head, 0.3, CFrame.new(0, -0.14, -0.93), WHITE) -- sun cream on the nose
		for _, s in { -1, 1 } do
			bar(torso, Vector3.new(0.3 * s, 0.53, -0.36), Vector3.new(0.04 * s, 0.05, -0.46), 0.05, 0.03, WHITE)
		end
		cyl(torso, 0.24, 0.17, CFrame.new(0, -0.02, -0.5) * U.AxisZ, Color3.fromRGB(255, 215, 60)) -- whistle
		ball(torso, 0.17, CFrame.new(0.07, -0.05, -0.45), Color3.fromRGB(255, 215, 60))
	elseif hat == "Snorkel" then
		-- diving mask over the eyes (see-through lens in a chunky frame), strap round the head, snorkel up the side
		local c = hatColor
		cyl(head, 0.16, 2.02, CFrame.new(0, 0.1, 0.35) * U.AxisY, U.Shade(c, 0.6)) -- strap (front rim hidden in the face)
		block(head, Vector3.new(1.24, 0.6, 0.06), CFrame.new(0, 0.04, -1.08), Color3.fromRGB(175, 230, 255), { Transparency = 0.55, Reflectance = 0.2, Shadow = false }) -- lens
		for _, y in { 0.38, -0.3 } do
			block(head, Vector3.new(1.42, 0.13, 0.34), CFrame.new(0, y, -0.94), c) -- frame top / bottom
		end
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.14, 0.8, 0.42), CFrame.new(0.69 * s, 0.04, -0.86), c) -- frame sides
		end
		local tube = Color3.fromRGB(255, 120, 60)
		local pts = { Vector3.new(0.22, -0.44, -0.92), Vector3.new(0.85, -0.46, -0.52), Vector3.new(1.06, 0.1, -0.22), Vector3.new(1.02, 1.5, -0.05) }
		for i = 1, #pts - 1 do
			rod(head, pts[i], pts[i + 1], 0.15, tube)
		end
		ball(head, 0.28, CFrame.new(pts[4]), c) -- snorkel top
	elseif hat == "ShellTiara" then
		-- a row of pearls across the hair and a starfish clip over the left ear
		local c = hatColor
		for i = -2, 2 do
			local a = i * 0.36
			ball(head, 0.2, CFrame.new(math.sin(a) * 0.96, 0.62, 0.2 - math.cos(a) * 0.96), Color3.fromRGB(250, 245, 255), { Reflectance = 0.25 })
		end
		local pos = Vector3.new(0.86, 0.55, -0.22)
		local n = Vector3.new(0.85, 0.3, -0.45).Unit
		for k = 0, 4 do
			block(head, Vector3.new(0.14, 0.38, 0.08), U.Facing(pos, n) * CFrame.Angles(0, 0, k * 2 * math.pi / 5) * CFrame.new(0, 0.17, 0), c) -- starfish arms
		end
		ball(head, 0.2, U.Facing(pos, n), U.Shade(c, 0.85))
	elseif hat == "SpongeHead" then
		-- square sea-sponge head: a big holey block round the head (the round face pokes out of the front),
		-- a green scrubby top, a long nose and two buck teeth
		local sp = look.Skin
		local pore = U.Shade(sp, 0.72)
		local bc = CFrame.new(0, 0.12, 0.12)
		block(head, Vector3.new(2.1, 2.2, 1.74), bc, sp)
		block(head, Vector3.new(2.14, 0.34, 1.78), bc * CFrame.new(0, 1.25, 0), hatColor) -- scrubby top
		cyl(head, 0.36, 0.24, CFrame.new(0, -0.1, -1.06) * U.AxisZ, sp) -- nose
		for _, s in { -1, 1 } do
			block(head, Vector3.new(0.14, 0.17, 0.05), CFrame.new(0.08 * s, -0.55, -0.8), WHITE) -- buck teeth
		end
		for _, q in { { -0.75, 0.72, 0.24 }, { 0.72, 0.8, 0.18 }, { 0.78, -0.6, 0.26 }, { -0.72, -0.72, 0.2 }, { 0.05, 0.92, 0.16 } } do
			cyl(head, 0.04, q[3], CFrame.new(q[1], q[2], -0.76) * U.AxisZ, pore) -- pores (front)
		end
		for _, q in { { -0.35, 0.55, 0.26 }, { 0.45, -0.35, 0.3 }, { 0.15, 0.85, 0.18 } } do
			for _, s in { -1, 1 } do
				cyl(head, 0.04, q[3], CFrame.new(1.06 * s, q[2], q[1]), pore) -- pores (sides)
			end
		end
	elseif hat == "Hibiscus" then
		-- big hibiscus flower tucked over the left ear, loose curls at the ends of the long hair
		local c = hatColor
		local fcf = U.Facing(Vector3.new(0.86, 0.42, -0.25), Vector3.new(0.8, 0.25, -0.55))
		for i = 0, 4 do
			cyl(head, 0.06, 0.46, fcf * CFrame.Angles(0, 0, i * 2 * math.pi / 5) * CFrame.new(0, 0.21, 0) * U.AxisZ, if i % 2 == 0 then c else U.Shade(c, 0.9)) -- petals
		end
		ball(head, 0.18, fcf, U.Shade(c, 0.55))
		rod(head, fcf.Position, (fcf * CFrame.new(0.05, 0.08, -0.32)).Position, 0.06, Color3.fromRGB(255, 220, 80)) -- stamen
		local curl = U.Shade(hairColor, 1.5)
		for i = 0, 2 do
			ball(head, 0.46, CFrame.new(-0.45 + i * 0.45, -1.3, 0.74), if i % 2 == 0 then hairColor else curl) -- curls at the back
			for _, sd in { -1, 1 } do
				ball(head, 0.44 - i * 0.04, CFrame.new(0.9 * sd, -0.2 - i * 0.38, 0.35 - i * 0.05), if i % 2 == 0 then curl else hairColor) -- curls at the sides
			end
		end
	elseif hat == "AnglerHood" then
		-- deep-sea anglerfish hood: the face peeks out of the gaping mouth (needle fangs above, an underbite
		-- jaw with its own teeth below), little fish eyes and side fins, and a glowing lure on a stalk
		local c = hatColor
		local hc = Vector3.new(0, 0.3, 0.35)
		ball(head, 2.4, CFrame.new(hc), c)
		local jaw = CFrame.new(0, -0.98, -0.42) * CFrame.Angles(-0.25, 0, 0)
		block(head, Vector3.new(1.95, 0.32, 1.25), jaw, U.Shade(c, 0.85))
		for i = -2, 2 do
			local x = i * 0.27
			local z = hc.Z - math.sqrt(math.max(0, 1.44 - x * x - 0.2025))
			wedge(head, Vector3.new(0.06, 0.34 - math.abs(i) * 0.05, 0.16), CFrame.new(x, 0.68, z - 0.03) * CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- fangs
		end
		for _, x in { -0.6, -0.22, 0.22, 0.6 } do
			wedge(head, Vector3.new(0.06, 0.24, 0.16), jaw * CFrame.new(x, 0.27, -0.52) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- lower teeth
		end
		local stalk = { Vector3.new(0, 1.42, 0.05), Vector3.new(0, 2.05, -0.45), Vector3.new(0, 1.98, -1.05), Vector3.new(0, 1.8, -1.12) }
		for i = 1, #stalk - 1 do
			rod(head, stalk[i], stalk[i + 1], 0.08, U.Shade(c, 0.8))
		end
		ball(head, 0.36, CFrame.new(0, 1.62, -1.14), look.Beam, NEON) -- lure
		for _, s in { -1, 1 } do
			ball(head, 0.36, CFrame.new(0.52 * s, 1.1, -0.42), WHITE)
			ball(head, 0.18, CFrame.new(0.55 * s, 1.12, -0.58), EYE)
			spike(head, CFrame.new(1.15 * s, 0.1, 0.45) * CFrame.Angles(0, 0, -1.2 * s) * CFrame.Angles(0, 0.3 * s, 0), 0.65, 0.65, 0.08, U.Mix(c, look.Beam, 0.35)) -- side fins
		end
	elseif hat == "CoralCrown" then
		-- crown of branching pink coral on a gold band, a pearl at the front
		local c = hatColor
		local light = U.Mix(c, WHITE, 0.35)
		local base = CFrame.new(0, 0.62 + lift, 0.12) * CFrame.Angles(-0.12, 0, 0)
		cyl(head, 0.2, 2.1, base * U.AxisY, GOLD, METAL_MAT)
		for _, q in { { 0, 1.0 }, { -0.75, 0.72 }, { 0.75, 0.72 } } do
			local dir = Vector3.new(math.sin(q[1]), 0, -math.cos(q[1]))
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local p0 = (base * CFrame.new(dir * 0.98 + Vector3.new(0, 0.08, 0))).Position
			local p1 = p0 + dir * 0.18 + Vector3.new(0, q[2], 0)
			rod(head, p0, p1, 0.17, c)
			local mid = p0:Lerp(p1, 0.45)
			local p2 = mid + dir * 0.12 + side * 0.32 + Vector3.new(0, q[2] * 0.42, 0)
			rod(head, mid, p2, 0.12, light)
			ball(head, 0.22, CFrame.new(p1), light)
		end
		ball(head, 0.26, base * CFrame.new(0, 0.05, -1.06), Color3.fromRGB(250, 245, 255), { Reflectance = 0.3 }) -- pearl
	elseif hat == "Sweatband" then
		-- boxer's sweatband round the forehead
		cyl(head, 0.26, 2.08, CFrame.new(0, 0.6, 0.15) * CFrame.Angles(-0.1, 0, 0) * U.AxisY, hatColor)
	elseif hat == "FanHat" then
		-- super-fan's giant foam team hat (tall striped top hat with a big "1" badge) and team face paint
		local c = hatColor
		local alt = look.BackColor or GOLD
		local hcf = CFrame.new(0, 0.78 + lift, 0.08) * CFrame.Angles(-0.08, 0, 0.1)
		cyl(head, 0.14, 2.6, hcf * U.AxisY, alt) -- brim
		for i = 0, 3 do
			cyl(head, 0.42, 1.7, hcf * CFrame.new(0, 0.28 + i * 0.4, 0) * U.AxisY, if i % 2 == 0 then c else alt)
		end
		ball(head, 0.6, hcf * CFrame.new(0, 1.62, 0), alt) -- pompom
		cyl(head, 0.08, 0.78, hcf * CFrame.new(0, 0.85, -0.85) * U.AxisZ, WHITE) -- badge
		block(head, Vector3.new(0.13, 0.46, 0.06), hcf * CFrame.new(0, 0.85, -0.9), c) -- "1"
		for _, s in { -1, 1 } do
			local n = Vector3.new(0.5 * s, -0.32, -0.8).Unit
			for k, col in { c, alt } do
				block(head, Vector3.new(0.13, 0.44, 0.06), U.Facing(n * 0.94, n) * CFrame.new((k - 1.5) * 0.15, 0, 0), col) -- face paint
			end
		end
	end

	------------------------------------------------------------------ body accent / aura
	local badgeCf = CFrame.new(-0.3, 0.2, -0.44) * U.AxisZ
	if look.Aura then
		cyl(torso, 0.08, 0.42, badgeCf, U.Vivid(rarityColor), { Reflectance = 0.2 })
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Aura"
		pe.Color = ColorSequence.new(rarityColor)
		pe.LightEmission = 1
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(0.9, 1.6)
		pe.Speed = NumberRange.new(0.4, 1.1)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.4, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Acceleration = Vector3.new(0, 1.2, 0)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Parent = torso
	else
		cyl(torso, 0.08, 0.42, badgeCf, look.Beam)
	end

	------------------------------------------------------------------ back
	local back = look.Back
	local backColor = look.BackColor or look.Shirt
	-- two shoulder straps holding a back item on
	local function strap(color: Color3)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.18, 0.12, 0.9), CFrame.new(0.38 * s, 0.56, 0.1), color)
		end
	end
	if back == "Backpack" then
		block(torso, Vector3.new(1.0, 1.0, 0.5), CFrame.new(0, 0, 0.65), backColor)
		block(torso, Vector3.new(0.7, 0.4, 0.18), CFrame.new(0, -0.2, 0.95), U.Shade(backColor, 0.75))
	elseif back == "Tank" then
		cyl(torso, 1.2, 0.78, CFrame.new(0, 0.1, 0.75) * U.AxisY, backColor, { Transparency = 0.45 })
		cyl(torso, 1.0, 0.5, CFrame.new(0, 0.1, 0.75) * U.AxisY, U.Vivid(backColor)) -- ectoplasm inside the tank
		cyl(torso, 0.18, 0.84, CFrame.new(0, 0.75, 0.75) * U.AxisY, METAL, { Material = Enum.Material.Metal })
	elseif back == "Cape" then
		block(torso, Vector3.new(1.35, 1.55, 0.12), CFrame.new(0, -0.3, 0.52) * CFrame.Angles(-0.15, 0, 0), backColor)
		block(torso, Vector3.new(1.45, 0.3, 0.6), CFrame.new(0, 0.5, 0.25), U.Shade(backColor, 0.75))
	elseif back == "Wings" then
		for _, s in { -1, 1 } do
			-- big wing: tall outer edge, tapering into the spine
			wedge(torso, Vector3.new(0.12, 1.4, 1.2), CFrame.new(0.8 * s, 0.35, 0.58) * CFrame.Angles(0, 0, 0.35 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), backColor, { Transparency = 0.1 })
			-- brighter inner feather layer
			wedge(torso, Vector3.new(0.1, 1.0, 0.9), CFrame.new(0.7 * s, 0.0, 0.64) * CFrame.Angles(0, 0, 0.05 * s) * CFrame.Angles(0, math.pi / 2 * s, 0), U.Vivid(backColor), { Transparency = 0.3 })
		end
	elseif back == "Antenna" then
		block(torso, Vector3.new(0.7, 0.8, 0.4), CFrame.new(0, 0, 0.62), backColor)
		cyl(torso, 1.8, 0.1, CFrame.new(0.25, 1.1, 0.75) * U.AxisY, METAL, { Material = Enum.Material.Metal })
		ball(torso, 0.32, CFrame.new(0.25, 2.0, 0.75), look.Beam, NEON)
	elseif back == "Balloons" then
		local anchor = Vector3.new(0.3, 0.3, 0.7)
		local cols = { backColor, Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 215, 70) }
		local spots = { Vector3.new(-1.1, 2.2, 0.9), Vector3.new(0.2, 2.6, 1.2), Vector3.new(1.15, 2.05, 0.85) }
		for i, p in spots do
			rod(torso, anchor, p - Vector3.new(0, 0.4, 0), 0.05, WHITE)
			ball(torso, 0.85, CFrame.new(p), U.Vivid(cols[i]))
		end
	elseif back == "MedKit" then
		block(torso, Vector3.new(1.05, 0.85, 0.5), CFrame.new(0, 0.05, 0.66), backColor)
		block(torso, Vector3.new(0.5, 0.15, 0.06), CFrame.new(0, 0.05, 0.93), RED)
		block(torso, Vector3.new(0.15, 0.5, 0.06), CFrame.new(0, 0.05, 0.93), RED)
		cyl(torso, 0.5, 0.1, CFrame.new(0, 0.53, 0.66), METAL, METAL_MAT) -- handle
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.18, 0.12, 0.9), CFrame.new(0.38 * s, 0.56, 0.05), U.Shade(backColor, 0.7)) -- shoulder strap
		end
	elseif back == "LifeRing" then
		local c = CFrame.new(0, 0.05, 0.7)
		for i = 0, 7 do
			block(torso, Vector3.new(0.24, 0.44, 0.24), c * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0.5, 0, 0), if i % 2 == 0 then backColor else WHITE)
		end
	elseif back == "Shield" then
		local scf = CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, 0.2)
		cyl(torso, 0.12, 1.45, scf * U.AxisZ, METAL, METAL_MAT) -- rim
		cyl(torso, 0.14, 1.3, scf * CFrame.new(0, 0, 0.03) * U.AxisZ, backColor)
		block(torso, Vector3.new(0.18, 1.05, 0.05), scf * CFrame.new(0, 0, 0.11), GOLD)
		block(torso, Vector3.new(1.05, 0.18, 0.05), scf * CFrame.new(0, 0.1, 0.11), GOLD)
		ball(torso, 0.3, scf * CFrame.new(0, 0, 0.1), GOLD, METAL_MAT) -- boss
	elseif back == "Orbs" then
		-- three small spirit orbs floating behind the shoulders
		for _, p in { Vector3.new(-1.1, 0.8, 0.5), Vector3.new(1.25, 1.25, 0.55), Vector3.new(-1.3, 1.95, 0.5) } do
			ball(torso, 0.55, CFrame.new(p), backColor, { Transparency = 0.65, Shadow = false })
			ball(torso, 0.3, CFrame.new(p), backColor, NEON)
		end
	elseif back == "HeroCape" then
		-- long two-panel cape flaring out at the hem, stand-up collar, gold clasps and a back emblem
		local c = look.BackColor or Color3.fromRGB(220, 40, 60)
		block(torso, Vector3.new(1.45, 1.2, 0.1), CFrame.new(0, -0.1, 0.55) * CFrame.Angles(-0.12, 0, 0), c)
		block(torso, Vector3.new(1.75, 0.72, 0.1), CFrame.new(0, -1.0, 0.8) * CFrame.Angles(-0.3, 0, 0), c)
		block(torso, Vector3.new(1.5, 0.42, 0.12), CFrame.new(0, 0.62, 0.4) * CFrame.Angles(0.3, 0, 0), U.Shade(c, 0.75)) -- collar
		for _, s in { -1, 1 } do
			ball(torso, 0.22, CFrame.new(0.5 * s, 0.42, -0.42), GOLD, METAL_MAT) -- clasps
		end
		cyl(torso, 0.06, 0.6, CFrame.new(0, -0.05, 0.62) * U.AxisZ, GOLD) -- emblem
		block(torso, Vector3.new(0.3, 0.3, 0.06), CFrame.new(0, -0.05, 0.65) * CFrame.Angles(0, 0, math.pi / 4), U.Shade(c, 0.6))
	elseif back == "BatWings" then
		-- leathery wings: a bony top edge with a claw and two stepped membrane panels
		local c = look.BackColor or Color3.fromRGB(70, 45, 90)
		local boneC = U.Shade(c, 0.6)
		for _, s in { -1, 1 } do
			local flip = CFrame.Angles(0, math.pi / 2 * s, 0) * CFrame.Angles(0, 0, math.pi) -- flat top, sloping hem
			wedge(torso, Vector3.new(0.08, 0.9, 0.72), CFrame.new(0.62 * s, 0.3, 0.6) * flip, c)
			wedge(torso, Vector3.new(0.08, 1.0, 0.72), CFrame.new(1.3 * s, 0.55, 0.6) * flip, c)
			rod(torso, Vector3.new(0.25 * s, 0.72, 0.6), Vector3.new(1.7 * s, 1.08, 0.6), 0.1, boneC)
			ball(torso, 0.18, CFrame.new(1.72 * s, 1.12, 0.6), boneC) -- claw
		end
	elseif back == "HeartWings" then
		-- pastel heart wings: each heart is a diamond plus two round lobes, tipped toward the spine
		local c = look.BackColor or Color3.fromRGB(255, 175, 215)
		local light = U.Mix(c, WHITE, 0.5)
		local a = 0.75
		local k = a / (2 * math.sqrt(2))
		for _, s in { -1, 1 } do
			local hcf = CFrame.new(0.95 * s, 0.5, 0.62) * CFrame.Angles(0, 0, -0.6 * s)
			block(torso, Vector3.new(a, a, 0.1), hcf * CFrame.Angles(0, 0, math.pi / 4), c)
			for _, x in { -1, 1 } do
				cyl(torso, 0.1, a, hcf * CFrame.new(k * x, k, 0) * U.AxisZ, c) -- lobes
			end
			cyl(torso, 0.04, 0.26, hcf * CFrame.new(k * s, k + 0.08, 0.07) * U.AxisZ, light) -- shine
		end
		ball(torso, 0.3, CFrame.new(0, 0.2, 0.55), U.Shade(c, 0.85)) -- joint
	elseif back == "LanternPole" then
		-- bamboo pole carried on the back, rising past the right shoulder, three paper lanterns hanging off its end
		local c = look.BackColor or RED
		local p0, p1 = Vector3.new(-0.35, -0.25, 0.55), Vector3.new(1.55, 2.65, 1.3)
		rod(torso, p0, p1, 0.13, Color3.fromRGB(170, 140, 80))
		for _, t in { 0.6, 0.8, 1.0 } do
			local hang = p0:Lerp(p1, t)
			paperLantern(torso, hang - Vector3.new(0, 0.05, 0), 0.5, c, false, true)
		end
	elseif back == "FireworkRack" then
		-- three rockets fanned out in a little frame on the back (clear of long hair), fuse sparks at the top
		local c = look.BackColor or RED
		local base = CFrame.new(0, -0.3, 1.0)
		block(torso, Vector3.new(1.0, 0.14, 0.4), base, Color3.fromRGB(120, 85, 55)) -- frame
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.12, 0.12, 0.6), CFrame.new(0.35 * s, -0.3, 0.7), Color3.fromRGB(120, 85, 55)) -- struts to the back
		end
		for i, a in { 0.32, 0, -0.32 } do
			local h = if i == 2 then 1.6 else 1.35
			local alt = if i == 2 then GOLD else WHITE
			local rcf = base * CFrame.new((i - 2) * 0.3, 0, 0) * CFrame.Angles(0, 0, a)
			cyl(torso, h, 0.34, rcf * CFrame.new(0, h / 2, 0) * U.AxisY, if i == 2 then alt else c)
			cyl(torso, 0.1, 0.36, rcf * CFrame.new(0, h * 0.6, 0) * U.AxisY, if i == 2 then c else alt) -- stripe
			cone(torso, rcf * CFrame.new(0, h, 0), 0.34, 0.4, 2, if i == 2 then c else alt)
		end
		local fx = Instance.new("ParticleEmitter")
		fx.Name = "FuseSparks"
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(GOLD)
		fx.LightEmission = 1
		fx.Rate = 5
		fx.Lifetime = NumberRange.new(0.3, 0.6)
		fx.Speed = NumberRange.new(0.5, 1.5)
		fx.SpreadAngle = Vector2.new(40, 40)
		fx.Size = NumberSequence.new(0.18, 0)
		fx.Parent = torso
	elseif back == "BookWings" then
		-- two open books as wings, angled up and out (far enough out to clear long hair)
		local c = look.BackColor or Color3.fromRGB(120, 60, 50)
		for _, s in { -1, 1 } do
			local wcf = CFrame.new(1.1 * s, 0.6, 0.75) * CFrame.Angles(0, 0.3 * s, -0.5 * s)
			for _, h in { -1, 1 } do
				block(torso, Vector3.new(0.72, 1.0, 0.06), wcf * CFrame.new(0.35 * h, 0, 0.05) * CFrame.Angles(0, -0.2 * h, 0), c) -- covers
			end
			block(torso, Vector3.new(1.3, 0.9, 0.08), wcf * CFrame.new(0, 0, -0.02), CREAM) -- pages
			block(torso, Vector3.new(0.05, 0.92, 0.1), wcf * CFrame.new(0, 0, -0.03), U.Shade(CREAM, 0.75)) -- gutter
		end
	elseif back == "Rings" then
		-- two crossed gyroscope rings floating behind the back
		local c = look.BackColor or GOLD
		local rc = CFrame.new(0, 0.45, 1.05)
		for i, a in { 0.6, -0.6 } do
			for _, p in U.Hoop(0.85, 0.13, 0.1, 8, torso.CFrame * rc * CFrame.Angles(0, a, 0), if i == 1 then c else U.Mix(c, WHITE, 0.45), model, METAL_MAT) do
				add(torso, p)
			end
		end
		ball(torso, 0.3, rc, U.Vivid(look.Beam), NEON) -- core
	elseif back == "MirrorShards" then
		-- five floating mirror diamonds fanned out behind like wings
		local c = look.BackColor or Color3.fromRGB(220, 235, 255)
		for i = -2, 2 do
			local a = i * 0.55
			local p = Vector3.new(math.sin(a) * 1.2, 0.3 + math.cos(a) * 1.05, 1.05 - math.abs(i) * 0.08)
			local sz = 0.62 - math.abs(i) * 0.06
			block(torso, Vector3.new(sz, sz, 0.06), CFrame.new(p) * CFrame.Angles(0, 0, -a + math.pi / 4), c, { Reflectance = 0.6 })
			block(torso, Vector3.new(sz + 0.08, sz + 0.08, 0.04), CFrame.new(p + Vector3.new(0, 0, 0.04)) * CFrame.Angles(0, 0, -a + math.pi / 4), U.Shade(c, 0.6)) -- frame
		end
	elseif back == "Shell" then
		-- turtle shell: dome, plates and a pale rim
		local c = look.BackColor or Color3.fromRGB(110, 140, 60)
		local sc = Vector3.new(0, 0.05, 0.62)
		cyl(torso, 0.14, 1.6, CFrame.new(0, 0.05, 0.5) * U.AxisZ, Color3.fromRGB(225, 205, 130)) -- rim
		ball(torso, 1.45, CFrame.new(sc), c)
		for _, d in { Vector3.new(0, 0, 1), Vector3.new(0, 0.6, 0.8), Vector3.new(0, -0.6, 0.8), Vector3.new(0.6, 0.25, 0.75), Vector3.new(-0.6, 0.25, 0.75), Vector3.new(0.6, -0.3, 0.75), Vector3.new(-0.6, -0.3, 0.75) } do
			local n = d.Unit
			cyl(torso, 0.08, if d.X == 0 and d.Y == 0 then 0.55 else 0.42, U.DiscFacing(sc + n * 0.7, -n), U.Shade(c, 0.72))
		end
	elseif back == "Smokestack" then
		-- little boiler low on the back with two flared stacks angled out past the shoulders, puffing smoke
		local c = look.BackColor or Color3.fromRGB(60, 60, 70)
		block(torso, Vector3.new(1.0, 0.6, 0.5), CFrame.new(0, -0.2, 0.68), c, METAL_MAT)
		block(torso, Vector3.new(1.04, 0.1, 0.54), CFrame.new(0, 0.0, 0.68), GOLD, METAL_MAT) -- band
		for _, s in { -1, 1 } do
			local scf = CFrame.new(0.3 * s, 0.05, 0.8) * CFrame.Angles(0.25, 0, -0.55 * s)
			cyl(torso, 1.1, 0.3, scf * CFrame.new(0, 0.55, 0) * U.AxisY, U.Shade(c, 0.8), METAL_MAT)
			cyl(torso, 0.2, 0.5, scf * CFrame.new(0, 1.15, 0) * U.AxisY, U.Shade(c, 0.8), METAL_MAT) -- flare
			ball(torso, 0.4, scf * CFrame.new(0, 1.55, 0), Color3.fromRGB(225, 225, 240), { Transparency = 0.35 }) -- puff
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "Smoke"
			smoke.Color = ColorSequence.new(Color3.fromRGB(225, 225, 240))
			smoke.Rate = 3
			smoke.Lifetime = NumberRange.new(1, 1.6)
			smoke.Speed = NumberRange.new(0.8, 1.4)
			smoke.SpreadAngle = Vector2.new(15, 15)
			smoke.Size = NumberSequence.new(0.2, 0.5)
			smoke.Transparency = NumberSequence.new(0.4, 1)
			smoke.Parent = torso
		end
	elseif back == "Boombox" then
		-- boombox worn like a backpack: speakers, tiny glowing tweeters, carry handle and straps
		local c = look.BackColor or Color3.fromRGB(60, 60, 75)
		block(torso, Vector3.new(1.4, 0.82, 0.45), CFrame.new(0, 0.0, 0.66), c)
		for _, s in { -1, 1 } do
			cyl(torso, 0.08, 0.52, CFrame.new(0.38 * s, -0.02, 0.9) * U.AxisZ, Color3.fromRGB(30, 30, 40))
			cyl(torso, 0.06, 0.14, CFrame.new(0.38 * s, -0.02, 0.95) * U.AxisZ, look.Beam, NEON)
			block(torso, Vector3.new(0.18, 0.12, 0.9), CFrame.new(0.38 * s, 0.56, 0.05), U.Shade(c, 0.7)) -- strap
			rod(torso, Vector3.new(0.45 * s, 0.4, 0.66), Vector3.new(0.38 * s, 0.62, 0.66), 0.08, METAL, METAL_MAT)
		end
		rod(torso, Vector3.new(-0.4, 0.64, 0.66), Vector3.new(0.4, 0.64, 0.66), 0.09, METAL, METAL_MAT) -- handle
		block(torso, Vector3.new(0.4, 0.12, 0.06), CFrame.new(0, 0.26, 0.9), U.Vivid(look.Beam)) -- display
	elseif back == "Glider" then
		-- hang-glider: delta wing high above the head (tips raised in a V so it reads from any side) on a rod frame
		local c = look.BackColor or Color3.fromRGB(255, 140, 60)
		local wcf = CFrame.new(0, 2.85, 0.75) * CFrame.Angles(0.08, 0, 0) -- nose a touch up, like a real glider
		for _, s in { -1, 1 } do
			wedge(torso, Vector3.new(0.1, 1.75, 2.0), wcf * CFrame.Angles(0, 0, 0.4 * s) * CFrame.new(0.85 * s, 0, 0) * CFrame.Angles(0, 0, -s * math.pi / 2), if s < 0 then c else U.Mix(c, WHITE, 0.4))
			rod(torso, Vector3.new(0.35 * s, 0.45, 0.45), (wcf * CFrame.new(0, -0.05, 0.1)).Position, 0.07, METAL, METAL_MAT) -- A-frame
		end
		rod(torso, (wcf * CFrame.new(0, 0.05, -0.95)).Position, (wcf * CFrame.new(0, 0.05, 0.95)).Position, 0.08, METAL, METAL_MAT) -- keel
		rod(torso, (wcf * CFrame.new(-1.3, 0.45, 0.85)).Position, (wcf * CFrame.new(1.3, 0.45, 0.85)).Position, 0.07, METAL, METAL_MAT) -- cross bar
	elseif back == "StormWings" then
		-- wings of three jagged lightning bolts per side (solid, not neon, so they stay crisp)
		local c = U.Vivid(look.BackColor or Color3.fromRGB(255, 230, 90))
		for _, s in { -1, 1 } do
			for i, a in { 0.35, 0.8, 1.25 } do
				local base = Vector3.new(0.3 * s, 0.35, 0.6)
				local len = 1.35 - i * 0.12
				local dir = Vector3.new(math.sin(a) * s, math.cos(a), 0.15)
				local kink = base + dir * len * 0.55
				local jog = kink - Vector3.new(0.24 * s, 0.08, 0) -- the zig: second half starts back toward the spine
				bar(torso, base, kink, 0.22, 0.08, c)
				bar(torso, jog, jog + dir * len * 0.55, 0.16, 0.08, c)
			end
		end
	elseif back == "Jetpack" then
		-- two tanks with nozzle cones and small flames
		local c = look.BackColor or Color3.fromRGB(230, 230, 240)
		block(torso, Vector3.new(0.9, 0.7, 0.2), CFrame.new(0, 0.05, 0.52), METAL, METAL_MAT) -- mount
		for _, s in { -1, 1 } do
			local x = 0.32 * s
			cyl(torso, 0.95, 0.5, CFrame.new(x, 0.15, 0.78) * U.AxisY, c)
			ball(torso, 0.5, CFrame.new(x, 0.62, 0.78), c)
			cyl(torso, 0.1, 0.52, CFrame.new(x, 0.3, 0.78) * U.AxisY, U.Vivid(look.Beam)) -- stripe
			cone(torso, CFrame.new(x, -0.3, 0.78) * CFrame.Angles(math.pi, 0, 0), 0.42, 0.3, 2, METAL)
			ball(torso, 0.28, CFrame.new(x, -0.72, 0.78), Color3.fromRGB(255, 170, 70), NEON) -- flame
		end
	elseif back == "CometTail" then
		-- comet tail of shrinking glowing balls streaming back from the shoulders
		local c = look.BackColor or Color3.fromRGB(150, 200, 255)
		for i = 0, 6 do
			local p = Vector3.new(0.45 + i * 0.12, 0.65 + i * 0.16, 0.6 + i * 0.36)
			ball(torso, 0.5 - i * 0.05, CFrame.new(p), U.Mix(c, WHITE, 0.35 - i * 0.05), { Material = Enum.Material.Neon, Transparency = 0.1 + i * 0.08 })
		end
	elseif back == "StretchyDog" then
		-- stretchy dog draped over both shoulders: head on the left, paws on the right
		local c = look.BackColor or Color3.fromRGB(235, 160, 70)
		local pts = {
			Vector3.new(0.98, 0.32, -0.2),
			Vector3.new(0.98, 0.45, 0.3),
			Vector3.new(0.55, 0.4, 0.7),
			Vector3.new(0, 0.38, 0.78),
			Vector3.new(-0.55, 0.42, 0.7),
			Vector3.new(-1.0, 0.55, 0.3),
		}
		for i = 1, #pts - 1 do
			rod(torso, pts[i], pts[i + 1], 0.4, c)
		end
		local hc = Vector3.new(-1.12, 0.78, -0.1)
		ball(torso, 0.78, CFrame.new(hc), c)
		ball(torso, 0.36, CFrame.new(hc + Vector3.new(0, -0.12, -0.38)), U.Mix(c, WHITE, 0.3)) -- snout
		ball(torso, 0.14, CFrame.new(hc + Vector3.new(0, -0.05, -0.55)), EYE) -- nose
		for _, s in { -1, 1 } do
			ball(torso, 0.13, CFrame.new(hc + Vector3.new(0.16 * s, 0.13, -0.33)), EYE)
			wedge(torso, Vector3.new(0.08, 0.42, 0.26), CFrame.new(hc + Vector3.new(0.34 * s, 0.05, 0)) * CFrame.Angles(0, 0, math.pi + 0.3 * s), U.Shade(c, 0.8)) -- floppy ears
		end
		for _, z in { -0.32, -0.08 } do
			ball(torso, 0.26, CFrame.new(1.02, 0.18, z), c) -- paws
		end
	elseif back == "VoidRing" then
		-- huge black and white halo ring behind the back with four little stars on it
		local c = look.BackColor or Color3.fromRGB(20, 15, 35)
		local rc = CFrame.new(0, 1.05, 0.95)
		for i, p in U.Hoop(1.6, 0.2, 0.12, 12, torso.CFrame * rc, c, model) do
			if i % 2 == 0 then
				p.Color = WHITE
			end
			add(torso, p)
		end
		for i = 0, 3 do
			block(torso, Vector3.new(0.3, 0.3, 0.3), rc * CFrame.Angles(0, 0, math.pi / 4 + i * math.pi / 2) * CFrame.new(0, 1.6, -0.12) * U.VertexUp, GOLD, { Reflectance = 0.3 })
		end
	-- EXCLUSIVES (world2c): premium backs of the 16 World 2 Exclusive-crate hunters (one each)
	elseif back == "ExLanternDragon" then
		-- riding a golden lantern dragon: its body snakes along under the feet (red lantern beads between gold
		-- coils) and rears up at the front left, head with horns, whiskers and a pearl in its mouth
		local c = backColor
		local red = Color3.fromRGB(215, 40, 50)
		local pts = {
			Vector3.new(0.7, -1.2, 1.9),
			Vector3.new(-0.3, -1.32, 1.1),
			Vector3.new(0.15, -1.38, 0.1),
			Vector3.new(-0.3, -1.25, -0.8),
			Vector3.new(-0.95, -0.65, -1.2),
			Vector3.new(-1.2, 0.05, -1.3),
		}
		for i = 1, #pts - 1 do
			local d = 0.3 + i * 0.05
			rod(torso, pts[i], pts[i + 1], d, c, { Reflectance = 0.15 })
			ball(torso, d + 0.16, CFrame.new(pts[i + 1]), red) -- lantern bead
		end
		spike(torso, CFrame.new(pts[1]) * CFrame.Angles(-1.2, 0.5, 0), 0.5, 0.6, 0.06, red) -- tail tuft
		local hp = Vector3.new(-1.25, 0.45, -1.4)
		ball(torso, 0.85, CFrame.new(hp), c, { Reflectance = 0.15 })
		block(torso, Vector3.new(0.55, 0.38, 0.6), CFrame.new(hp + Vector3.new(0, -0.08, -0.52)), c, { Reflectance = 0.15 }) -- snout
		block(torso, Vector3.new(0.46, 0.12, 0.5), CFrame.new(hp + Vector3.new(0, -0.38, -0.47)) * CFrame.Angles(-0.25, 0, 0), red) -- jaw
		ball(torso, 0.3, CFrame.new(hp + Vector3.new(0, -0.25, -0.88)), Color3.fromRGB(255, 245, 225), { Reflectance = 0.3 }) -- pearl
		for _, s in { -1, 1 } do
			ball(torso, 0.22, CFrame.new(hp + Vector3.new(0.25 * s, 0.15, -0.3)), EYE)
			rod(torso, hp + Vector3.new(0.18 * s, 0.3, 0.05), hp + Vector3.new(0.34 * s, 0.85, 0.42), 0.11, CREAM) -- horns
			rod(torso, hp + Vector3.new(0.22 * s, -0.1, -0.7), hp + Vector3.new(0.75 * s, -0.45, -0.58), 0.05, red) -- whiskers
		end
		spike(torso, CFrame.new(hp + Vector3.new(0, 0.2, 0.4)) * CFrame.Angles(-0.9, 0, 0), 0.65, 0.65, 0.08, red) -- mane
	elseif back == "ExLivingGrimoire" then
		-- a living spellbook floating open beside the left shoulder: googly eyes on its pages, a fanged grin,
		-- a bookmark tongue and two loose pages fluttering round
		local c = backColor
		local bc = CFrame.new(-1.6, 1.35, -0.1) * CFrame.Angles(0, -0.55, 0) * CFrame.Angles(0.15, 0, 0.1)
		for _, s in { -1, 1 } do
			local half = bc * CFrame.Angles(0, -0.35 * s, 0) * CFrame.new(0.5 * s, 0, 0)
			block(torso, Vector3.new(1.0, 1.35, 0.08), half, c)
			block(torso, Vector3.new(0.9, 1.22, 0.12), half * CFrame.new(-0.02 * s, 0, -0.08), CREAM) -- pages
			ball(torso, 0.4, half * CFrame.new(0, 0.22, -0.14), WHITE) -- eye
			ball(torso, 0.2, half * CFrame.new(-0.04 * s, 0.2, -0.3), EYE)
		end
		block(torso, Vector3.new(0.8, 0.14, 0.06), bc * CFrame.new(0, -0.3, -0.2), Color3.fromRGB(60, 25, 45)) -- grin
		for _, s in { -1, 1 } do
			wedge(torso, Vector3.new(0.05, 0.16, 0.1), bc * CFrame.new(0.2 * s, -0.42, -0.22) * CFrame.Angles(math.pi, 0, 0), WHITE) -- fangs
		end
		block(torso, Vector3.new(0.14, 0.75, 0.03), bc * CFrame.new(0.05, -0.9, -0.1) * CFrame.Angles(0, 0, 0.12), RED) -- bookmark
		for _, q in { { 0.75, 1.0, 1.05, 0.4 }, { -0.1, 2.55, 0.85, -0.6 } } do
			block(torso, Vector3.new(0.45, 0.6, 0.03), CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(0.3, q[4], q[4]), CREAM) -- loose pages
		end
	elseif back == "ExPumpkinShield" then
		-- harvest knight kit: autumn cape, pumpkin pauldrons and a round jack-o'-lantern shield on the left side
		local c = backColor
		local dark = Color3.fromRGB(70, 30, 15)
		local green = Color3.fromRGB(90, 130, 50)
		block(torso, Vector3.new(1.4, 1.65, 0.1), CFrame.new(0, -0.35, 0.52) * CFrame.Angles(-0.15, 0, 0), Color3.fromRGB(150, 40, 35))
		for _, s in { -1, 1 } do
			ball(torso, 0.72, CFrame.new(0.8 * s, 0.5, 0), c) -- pauldrons
			cyl(torso, 0.18, 0.12, CFrame.new(0.8 * s, 0.88, 0) * U.AxisY, green)
		end
		local n = Vector3.new(-0.55, 0, -0.85).Unit
		local sp = Vector3.new(-1.15, -0.15, -0.25)
		cyl(torso, 0.24, 1.35, U.DiscFacing(sp, n), c)
		cyl(torso, 0.16, 1.5, U.DiscFacing(sp - n * 0.04, n), U.Shade(c, 0.7)) -- rim
		local fc = U.Facing(sp + n * 0.13, n)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.24, 0.24, 0.04), fc * CFrame.new(0.24 * s, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 4), dark) -- carved eyes
		end
		block(torso, Vector3.new(0.7, 0.12, 0.04), fc * CFrame.new(0, -0.25, 0), dark) -- carved grin
		cyl(torso, 0.2, 0.14, U.Facing(sp + Vector3.new(0, 0.7, 0), n) * U.AxisY, green) -- stem
	elseif back == "ExFairyWings" then
		-- four see-through butterfly wings in two colours with pale spots, and a short royal cape
		local c = backColor
		local inner = Color3.fromRGB(120, 240, 220)
		block(torso, Vector3.new(1.35, 1.2, 0.08), CFrame.new(0, -0.15, 0.5) * CFrame.Angles(-0.12, 0, 0), Color3.fromRGB(120, 60, 170))
		for _, s in { -1, 1 } do
			local up = CFrame.new(0.95 * s, 0.85, 0.75) * CFrame.Angles(0, 0.35 * s, 0.45 * s)
			cyl(torso, 0.05, 1.7, up * U.AxisZ, c, { Transparency = 0.3 })
			cyl(torso, 0.06, 1.0, up * CFrame.new(0.1 * s, 0.1, -0.02) * U.AxisZ, inner, { Transparency = 0.3 })
			ball(torso, 0.24, up * CFrame.new(0.45 * s, 0.4, -0.04), WHITE)
			local lo = CFrame.new(0.75 * s, -0.25, 0.72) * CFrame.Angles(0, 0.3 * s, -0.4 * s)
			cyl(torso, 0.05, 1.15, lo * U.AxisZ, c, { Transparency = 0.3 })
			cyl(torso, 0.06, 0.6, lo * CFrame.new(0.06 * s, -0.05, -0.02) * U.AxisZ, inner, { Transparency = 0.3 })
		end
	elseif back == "ExSharkBoard" then
		-- surfing on a friendly shark: board-shaped shark under the feet pointing forward, dorsal and tail fins,
		-- eyes and a toothy grin at the front, water splashing at the back
		local c = backColor
		local y0 = -1.38
		block(torso, Vector3.new(1.0, 0.3, 2.8), CFrame.new(0, y0, 0.1), c)
		cyl(torso, 0.3, 1.0, CFrame.new(0, y0, -1.3) * U.AxisY, c) -- round nose
		block(torso, Vector3.new(0.9, 0.12, 2.9), CFrame.new(0, y0 - 0.12, -0.15), WHITE) -- belly
		wedge(torso, Vector3.new(0.12, 0.75, 0.7), CFrame.new(0, y0 + 0.5, 0.95), c) -- dorsal fin
		wedge(torso, Vector3.new(0.12, 0.85, 0.5), CFrame.new(0, y0 + 0.45, 1.75), U.Shade(c, 0.9)) -- tail fin
		for _, s in { -1, 1 } do
			ball(torso, 0.3, CFrame.new(0.42 * s, y0 + 0.12, -1.3), EYE)
			wedge(torso, Vector3.new(0.6, 0.08, 0.45), CFrame.new(0.72 * s, y0 - 0.02, -0.55) * CFrame.Angles(0, math.pi, 0), c) -- side fins
			ball(torso, 0.55, CFrame.new(0.6 * s, y0 + 0.1, 1.35), Color3.fromRGB(170, 230, 255), { Transparency = 0.35 }) -- splash
		end
		block(torso, Vector3.new(0.7, 0.13, 0.06), CFrame.new(0, y0 - 0.02, -1.81), Color3.fromRGB(60, 25, 35)) -- mouth
		block(torso, Vector3.new(0.6, 0.06, 0.07), CFrame.new(0, y0 - 0.01, -1.82), WHITE) -- teeth
		ball(torso, 0.7, CFrame.new(0, y0 + 0.25, 2.05), Color3.fromRGB(200, 240, 255), { Transparency = 0.35 })
	elseif back == "ExMirrorShield" then
		-- crystal knight kit: pale cape, crystal pauldrons, a round mirror shield on the left side, mirror shards
		local c = backColor
		local crystal = Color3.fromRGB(190, 240, 255)
		local glassy = { Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.3 }
		block(torso, Vector3.new(1.4, 1.7, 0.1), CFrame.new(0, -0.35, 0.52) * CFrame.Angles(-0.15, 0, 0), c)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.78 * s, 0.6, 0.05) * U.VertexUp, crystal, glassy) -- pauldrons
			block(torso, Vector3.new(0.26, 0.26, 0.26), CFrame.new(0.95 * s, 0.75, 0.3) * U.VertexUp, crystal, glassy)
		end
		local n = Vector3.new(-0.55, 0, -0.85).Unit
		local sp = Vector3.new(-1.15, -0.1, -0.25)
		cyl(torso, 0.14, 1.4, U.DiscFacing(sp, n), Color3.fromRGB(225, 240, 255), { Material = Enum.Material.Metal, Reflectance = 0.55 })
		cyl(torso, 0.1, 1.56, U.DiscFacing(sp - n * 0.03, n), GOLD, METAL_MAT) -- rim
		block(torso, Vector3.new(0.34, 0.34, 0.34), U.Facing(sp + n * 0.1, n) * U.VertexUp, Color3.fromRGB(120, 220, 255), { Reflectance = 0.4 })
		for _, q in { { 1.2, 1.25, 0.6, 0.3 }, { 0.6, 2.1, 0.75, -0.4 }, { -0.9, 1.9, 0.8, 0.6 } } do
			block(torso, Vector3.new(0.32, 0.55, 0.04), CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(0.2, q[4], q[4]), crystal, { Reflectance = 0.5 }) -- shards
		end
	elseif back == "ExVIPBags" then
		-- VIP shopping spree: a fluffy pink boa round the shoulders, three posh bags at the left hand
		-- and a tiny pampered pup peeking out of one
		local c = backColor
		for i = 0, 5 do
			local a = math.rad(-150 + i * 60)
			ball(torso, 0.46, CFrame.new(math.cos(a) * 0.68, 0.56 + (if i == 0 or i == 5 then -0.18 else 0), math.sin(a) * 0.48), c) -- boa
		end
		local bags: { { P: Vector3, C: Color3 } } = {
			{ P = Vector3.new(-1.15, -0.75, -0.2), C = Color3.fromRGB(255, 205, 70) },
			{ P = Vector3.new(-1.35, -0.6, 0.3), C = Color3.fromRGB(35, 30, 40) },
			{ P = Vector3.new(-0.95, -0.85, 0.45), C = c },
		}
		for k, b in bags do
			local p, col = b.P, b.C
			block(torso, Vector3.new(0.55, 0.6, 0.28), CFrame.new(p) * CFrame.Angles(0, 0.4, 0.06 * k), col, if k == 1 then METAL_MAT else nil)
			bar(torso, p + Vector3.new(-0.18, 0.3, 0), p + Vector3.new(0, 0.6, 0), 0.05, 0.05, U.Shade(col, 0.6))
			bar(torso, p + Vector3.new(0, 0.6, 0), p + Vector3.new(0.18, 0.3, 0), 0.05, 0.05, U.Shade(col, 0.6))
		end
		local pup = Vector3.new(-0.95, -0.38, 0.45)
		ball(torso, 0.42, CFrame.new(pup), WHITE)
		ball(torso, 0.26, CFrame.new(pup + Vector3.new(0, 0.22, 0.02)), WHITE) -- fluffy top
		ball(torso, 0.1, CFrame.new(pup + Vector3.new(0.04, 0, -0.2)), EYE)
	elseif back == "ExGhostTrain" then
		-- a little see-through ghost locomotive puffing along behind the right shoulder: boiler, cab, chimney,
		-- cow-catcher, four wheels, a lamp and three rising smoke puffs
		local c = backColor
		local ghost = { Transparency = 0.3 }
		local tc = CFrame.new(1.15, 1.45, 0.9) * CFrame.Angles(0, 0.5, 0.08)
		cyl(torso, 1.1, 0.58, tc * CFrame.new(0, 0, -0.2) * U.AxisZ, c, ghost) -- boiler
		block(torso, Vector3.new(0.7, 0.78, 0.55), tc * CFrame.new(0, 0.12, 0.55), c, ghost) -- cab
		block(torso, Vector3.new(0.82, 0.08, 0.68), tc * CFrame.new(0, 0.55, 0.55), U.Shade(c, 0.6), ghost) -- roof
		cyl(torso, 0.42, 0.2, tc * CFrame.new(0, 0.42, -0.45) * U.AxisY, U.Shade(c, 0.6), ghost) -- chimney
		cyl(torso, 0.1, 0.34, tc * CFrame.new(0, 0.66, -0.45) * U.AxisY, U.Shade(c, 0.6), ghost)
		wedge(torso, Vector3.new(0.6, 0.3, 0.28), tc * CFrame.new(0, -0.25, -0.88) * CFrame.Angles(0, math.pi, 0), U.Shade(c, 0.6), ghost) -- cow-catcher
		for _, x in { -0.31, 0.31 } do
			for _, z in { -0.4, 0.35 } do
				cyl(torso, 0.1, 0.36, tc * CFrame.new(x, -0.3, z), U.Shade(c, 0.5), ghost) -- wheels
			end
		end
		ball(torso, 0.2, tc * CFrame.new(0, 0.05, -0.78), Color3.fromRGB(220, 255, 200), NEON) -- lamp
		for i, d in { 0.3, 0.4, 0.5 } do
			ball(torso, d, tc * CFrame.new(0.05 * i, 0.75 + i * 0.28, -0.45 + i * 0.25), WHITE, { Transparency = 0.45 }) -- smoke
		end
	elseif back == "ExFossilDragon" then
		-- fossil dragon costume: bone wings with amber see-through membranes and a bony tail down to the floor
		local c = backColor
		local amber = Color3.fromRGB(255, 170, 60)
		for _, s in { -1, 1 } do
			local sh = Vector3.new(0.4 * s, 0.4, 0.5)
			local el = Vector3.new(1.3 * s, 1.35, 0.8)
			rod(torso, sh, el, 0.16, c)
			ball(torso, 0.28, CFrame.new(el), c)
			for _, f in { Vector3.new(2.05 * s, 0.95, 0.9), Vector3.new(1.85 * s, 0.25, 0.88), Vector3.new(1.25 * s, -0.15, 0.75) } do
				rod(torso, el, f, 0.1, c) -- finger bones
			end
			block(torso, Vector3.new(1.15, 1.15, 0.04), CFrame.new(1.45 * s, 0.55, 0.85) * CFrame.Angles(0, 0, 0.25 * s), amber, { Transparency = 0.45 }) -- membrane
		end
		for i = 0, 4 do
			ball(torso, 0.42 - i * 0.05, CFrame.new(0, -0.55 - i * 0.2, 0.65 + i * 0.28), c) -- tail bones
		end
		wedge(torso, Vector3.new(0.1, 0.35, 0.45), CFrame.new(0, -1.3, 2.05), c) -- tail tip
	elseif back == "ExChampCape" then
		-- champion's regalia: red cape with gold trim and an ermine collar, a big gold title belt, floating confetti
		local c = backColor
		local cape = CFrame.new(0, -0.35, 0.52) * CFrame.Angles(-0.15, 0, 0)
		block(torso, Vector3.new(1.45, 1.7, 0.1), cape, c)
		block(torso, Vector3.new(1.47, 0.12, 0.12), cape * CFrame.new(0, -0.82, 0), GOLD, METAL_MAT) -- trim
		block(torso, Vector3.new(1.5, 0.3, 0.62), CFrame.new(0, 0.55, 0.22), WHITE) -- ermine collar
		for _, x in { -0.4, 0.4 } do
			block(torso, Vector3.new(0.08, 0.14, 0.04), CFrame.new(x, 0.55, -0.1), EYE)
		end
		block(torso, Vector3.new(1.36, 0.28, 0.9), CFrame.new(0, -0.38, 0), Color3.fromRGB(30, 30, 35)) -- belt strap
		cyl(torso, 0.1, 0.7, CFrame.new(0, -0.36, -0.47) * U.AxisZ, GOLD, { Material = Enum.Material.Metal, Reflectance = 0.25 }) -- title plate
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.24, 0.3, 0.06), CFrame.new(0.48 * s, -0.38, -0.46), GOLD, METAL_MAT)
		end
		ball(torso, 0.22, CFrame.new(0, -0.36, -0.53), RED) -- gem
		for i, q in { { 1.3, 1.6, -0.2 }, { -1.25, 1.9, 0.1 }, { 1.0, 2.5, 0.3 }, { -0.8, 2.6, -0.3 } } do
			block(torso, Vector3.new(0.16, 0.16, 0.03), CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(i, i * 2, i), RAINBOW[i * 2 - 1]) -- confetti
		end
	elseif back == "ExDJDeck" then
		-- hover DJ deck in front (two spinning records, a crossfader) and a fan of equaliser bars behind
		local c = backColor
		local dk = CFrame.new(0, -0.4, -1.0) * CFrame.Angles(0.2, 0, 0)
		block(torso, Vector3.new(1.9, 0.24, 0.85), dk, c)
		for _, s in { -1, 1 } do
			cyl(torso, 0.06, 0.62, dk * CFrame.new(0.5 * s, 0.14, 0) * U.AxisY, Color3.fromRGB(20, 20, 25)) -- record
			cyl(torso, 0.07, 0.22, dk * CFrame.new(0.5 * s, 0.15, 0) * U.AxisY, if s < 0 then Color3.fromRGB(255, 80, 200) else Color3.fromRGB(80, 240, 255)) -- label
		end
		block(torso, Vector3.new(0.3, 0.08, 0.1), dk * CFrame.new(0, 0.15, 0.2), WHITE) -- crossfader
		block(torso, Vector3.new(0.1, 0.1, 0.5), dk * CFrame.new(0, 0.13, -0.1), Color3.fromRGB(255, 220, 80)) -- slider
		for i = -3, 3 do
			local h = 0.6 + 0.9 * math.abs(math.sin(i * 1.3 + 0.6))
			local a = i * 0.28
			block(torso, Vector3.new(0.26, h, 0.12), CFrame.new(0, 0.4, 0.65) * CFrame.Angles(0, 0, -a) * CFrame.new(0, 0.55 + h / 2, 0), RAINBOW[i + 4]) -- equaliser bars
		end
	elseif back == "ExRoyalCake" then
		-- three-tier royal cake carried on a gold platter at the left hand: icing rims, strawberries, a gold crown
		local c = backColor
		local pc = Vector3.new(-1.45, -0.6, -0.15)
		cyl(torso, 0.08, 1.4, CFrame.new(pc) * U.AxisY, GOLD, { Material = Enum.Material.Metal, Reflectance = 0.25 }) -- platter
		local y = pc.Y + 0.04
		for i, d in { 1.15, 0.85, 0.55 } do
			local h = 0.38
			local col = if i % 2 == 1 then c else WHITE
			cyl(torso, h, d, CFrame.new(pc.X, y + h / 2, pc.Z) * U.AxisY, col)
			cyl(torso, 0.08, d + 0.08, CFrame.new(pc.X, y + h - 0.02, pc.Z) * U.AxisY, if i % 2 == 1 then WHITE else c) -- icing rim
			ball(torso, 0.2, CFrame.new(pc.X + d * 0.3, y + h + 0.06, pc.Z - d * 0.3), RED) -- strawberry
			y += h
		end
		for i = -1, 1 do
			block(torso, Vector3.new(0.14, 0.14, 0.14), CFrame.new(pc.X + i * 0.14, y + 0.1, pc.Z - 0.12 + math.abs(i) * 0.05) * U.VertexUp, GOLD, METAL_MAT) -- crown
		end
	elseif back == "ExHoloScreens" then
		-- final-boss HUD: a huge boss health bar floating overhead and two see-through hologram screens
		local c = backColor
		local pink = Color3.fromRGB(255, 90, 230)
		local hb = CFrame.new(0, 3.55, 0.2)
		block(torso, Vector3.new(2.3, 0.3, 0.1), hb, Color3.fromRGB(25, 20, 40))
		block(torso, Vector3.new(1.6, 0.18, 0.12), hb * CFrame.new(-0.3, 0, 0), RED) -- health left
		block(torso, Vector3.new(0.3, 0.3, 0.14), hb * CFrame.new(-1.3, 0, 0) * CFrame.Angles(0, 0, math.pi / 4), GOLD) -- boss icon
		for _, s in { -1, 1 } do
			local sc = CFrame.new(1.45 * s, 1.0, 0.45) * CFrame.Angles(0, -0.45 * s, 0)
			block(torso, Vector3.new(1.0, 0.7, 0.04), sc, c, { Transparency = 0.5 })
			block(torso, Vector3.new(0.5, 0.08, 0.05), sc * CFrame.new(-0.1, 0.15, 0), pink, { Transparency = 0.2 })
			block(torso, Vector3.new(0.3, 0.08, 0.05), sc * CFrame.new(-0.2, -0.05, 0), WHITE, { Transparency = 0.2 })
		end
		for i, q in { { 1.1, 2.3, 0.1 }, { -1.2, 2.5, 0.2 }, { 0.9, -0.3, 0.6 } } do
			block(torso, Vector3.new(0.22, 0.22, 0.22), CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(i, i, 0), if i == 2 then pink else c, { Transparency = 0.25 }) -- pixels
		end
	elseif back == "ExThunderbird" then
		-- riding a thunderbird: big blue bird behind with wings spread wide, gold-tipped feathers, its head
		-- over the left shoulder with a gold beak and a lightning crest, tail feathers below
		local c = backColor
		local light = U.Mix(c, WHITE, 0.35)
		local gold = Color3.fromRGB(255, 215, 60)
		ball(torso, 1.1, CFrame.new(0, 0.35, 0.95), c)
		for _, s in { -1, 1 } do
			local base = CFrame.new(0.55 * s, 0.6, 0.95) * CFrame.Angles(0, 0.45 * s, 0)
			spike(torso, base * CFrame.Angles(0, 0, -0.95 * s), 1.2, 2.5, 0.12, c)
			spike(torso, base * CFrame.new(0, -0.25, -0.05) * CFrame.Angles(0, 0, -1.45 * s), 0.85, 1.9, 0.1, light)
			spike(torso, base * CFrame.Angles(0, 0, -0.95 * s) * CFrame.new(0, 2.3, -0.02), 0.55, 0.65, 0.08, gold) -- gold tip
		end
		spike(torso, CFrame.new(0, -0.15, 1.15) * CFrame.Angles(0.5, 0, math.pi), 0.8, 1.2, 0.1, c) -- tail
		local hp = Vector3.new(-1.3, 1.95, -0.3)
		rod(torso, Vector3.new(-0.35, 0.65, 0.75), hp, 0.5, c) -- neck
		ball(torso, 0.78, CFrame.new(hp), c)
		wedge(torso, Vector3.new(0.3, 0.3, 0.55), CFrame.new(hp + Vector3.new(0, -0.05, -0.55)) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.pi, 0, 0), gold) -- beak
		for _, s in { -1, 1 } do
			ball(torso, 0.17, CFrame.new(hp + Vector3.new(0.24 * s, 0.12, -0.28)), EYE)
		end
		spike(torso, CFrame.new(hp + Vector3.new(0, 0.3, 0.1)) * CFrame.Angles(-0.5, 0, 0.2), 0.35, 0.75, 0.08, gold) -- crest
	elseif back == "ExRocketPack" then
		-- twin-rocket jetpack: white rockets with red nose cones and fins, jet flames, a little moon in orbit
		local c = backColor
		block(torso, Vector3.new(0.95, 0.75, 0.22), CFrame.new(0, 0.05, 0.52), METAL, METAL_MAT)
		for _, s in { -1, 1 } do
			local x = 0.4 * s
			cyl(torso, 1.15, 0.52, CFrame.new(x, 0.1, 0.82) * U.AxisY, c)
			cyl(torso, 0.14, 0.54, CFrame.new(x, 0.25, 0.82) * U.AxisY, Color3.fromRGB(255, 150, 70)) -- stripe
			cone(torso, CFrame.new(x, 0.67, 0.82), 0.52, 0.5, 2, RED)
			wedge(torso, Vector3.new(0.08, 0.45, 0.35), CFrame.new(x + 0.3 * s, -0.35, 0.82) * CFrame.Angles(0, -math.pi / 2 * s, 0), RED) -- fin
			ball(torso, 0.34, CFrame.new(x, -0.62, 0.82), Color3.fromRGB(255, 170, 70), NEON) -- flame
		end
		local mc = Vector3.new(-1.35, 1.5, 0.3)
		ball(torso, 0.6, CFrame.new(mc), Color3.fromRGB(200, 200, 210)) -- moon
		ball(torso, 0.18, CFrame.new(mc + Vector3.new(0.12, 0.12, -0.24)), Color3.fromRGB(150, 150, 165)) -- craters
		ball(torso, 0.13, CFrame.new(mc + Vector3.new(-0.15, -0.1, -0.24)), Color3.fromRGB(150, 150, 165))
	elseif back == "ExStarCloak" then
		-- star-cloaked emperor: a huge night-sky cloak flaring wide, high pointed collar, gold stars and clasps
		local c = backColor
		local lining = Color3.fromRGB(110, 50, 170)
		block(torso, Vector3.new(1.9, 2.4, 0.1), CFrame.new(0, -0.6, 0.62) * CFrame.Angles(-0.12, 0, 0), c)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.1, 2.25, 0.95), CFrame.new(0.92 * s, -0.6, 0.18) * CFrame.Angles(0, 0, 0.16 * s), c)
			block(torso, Vector3.new(0.75, 0.95, 0.08), CFrame.new(0.42 * s, 0.9, 0.42) * CFrame.Angles(-0.2, 0, -0.35 * s), lining) -- collar
			ball(torso, 0.24, CFrame.new(0.48 * s, 0.4, -0.44), GOLD, METAL_MAT) -- clasp
			for k, q in { { 0.3, -0.25 }, { -0.4, 0.05 }, { -1.1, -0.35 }, { -1.5, 0.3 } } do
				local sz = if k % 2 == 0 then 0.14 else 0.2
				block(torso, Vector3.new(sz, sz, sz), CFrame.new(s * (1.0 - 0.16 * (q[1] + 0.6)), q[1], q[2] + 0.15) * U.VertexUp, if k % 2 == 0 then WHITE else GOLD, { Reflectance = 0.3 }) -- stars
			end
		end
		rod(torso, Vector3.new(-0.48, 0.4, -0.46), Vector3.new(0.48, 0.4, -0.46), 0.05, GOLD, METAL_MAT) -- clasp chain
	elseif back == "BookStack" then
		-- leaning tower of books strapped to the back, a little bookworm reading on the top one
		local cols = { backColor, Color3.fromRGB(70, 120, 210), Color3.fromRGB(235, 170, 60), Color3.fromRGB(160, 80, 170), Color3.fromRGB(60, 165, 120), RED }
		local y = -0.3
		local topP = Vector3.zero
		for i = 1, 6 do
			local h = 0.34 + (i % 3) * 0.06
			local w = 1.2 - (i % 2) * 0.18 - i * 0.03
			local cf = CFrame.new(0.08 * math.sin(i * 2.1), y + h / 2, 0.66 + i * 0.17) * CFrame.Angles(0, 0.18 * math.sin(i * 1.7), 0.06 * math.sin(i * 2.6))
			block(torso, Vector3.new(w, h, 0.72), cf, cols[i])
			block(torso, Vector3.new(w - 0.04, h - 0.12, 0.76), cf * CFrame.new(0.04, 0, 0), CREAM) -- pages
			y += h
			topP = cf.Position + Vector3.new(0, h / 2, 0)
		end
		local green = Color3.fromRGB(120, 210, 90)
		ball(torso, 0.3, CFrame.new(topP + Vector3.new(0.3, 0.12, 0.1)), green)
		ball(torso, 0.34, CFrame.new(topP + Vector3.new(0.08, 0.18, -0.02)), green)
		local wh = topP + Vector3.new(-0.12, 0.42, -0.12)
		ball(torso, 0.42, CFrame.new(wh), green) -- worm head
		for _, s in { -1, 1 } do
			ball(torso, 0.1, CFrame.new(wh + Vector3.new(0.09 * s, 0.05, -0.18)), EYE)
			block(torso, Vector3.new(0.18, 0.12, 0.9), CFrame.new(0.38 * s, 0.56, 0.05), Color3.fromRGB(110, 75, 50)) -- strap
		end
	elseif back == "BookCart" then
		-- little library trolley worn on the back: two shelves of books, wheels, a push bar and a
		-- sleepy ghost riding on top waiting to be sorted
		local wood = backColor
		local z = 0.95
		local W = 0.95
		local cols = { Color3.fromRGB(70, 120, 210), RED, Color3.fromRGB(235, 170, 60), Color3.fromRGB(60, 165, 120) }
		for _, s in { -1, 1 } do
			rod(torso, Vector3.new(W * s, -1.0, z), Vector3.new(W * s, 1.05, z), 0.12, U.Shade(wood, 0.8))
			cyl(torso, 0.14, 0.44, CFrame.new(W * s, -1.0, z), Color3.fromRGB(40, 40, 50)) -- wheels
		end
		for k, sy in { -0.55, 0.3 } do
			block(torso, Vector3.new(W * 2 + 0.1, 0.1, 0.64), CFrame.new(0, sy, z), wood) -- shelf
			for i = 0, 4 do
				local h = 0.58 - ((i + k) % 2) * 0.12
				block(torso, Vector3.new(0.27, h, 0.5), CFrame.new(-0.7 + i * 0.33, sy + 0.05 + h / 2, z) * CFrame.Angles(0, 0, if i == 4 then -0.22 else 0), cols[(i + k) % 4 + 1])
			end
		end
		rod(torso, Vector3.new(-W, 1.05, z), Vector3.new(W, 1.05, z), 0.1, METAL, METAL_MAT) -- push bar
		local gc = Vector3.new(0.95, 1.4, z - 0.1)
		ball(torso, 0.72, CFrame.new(gc), WHITE, { Transparency = 0.15 })
		ball(torso, 0.5, CFrame.new(gc + Vector3.new(0, 0.32, 0.05)), WHITE, { Transparency = 0.15 })
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.12, 0.04, 0.04), CFrame.new(gc + Vector3.new(0.12 * s, 0.1, -0.36)), EYE) -- sleepy eyes
		end
	elseif back == "PopUpCastle" then
		-- open pop-up book on the back with a paper castle standing up out of it: two pastel towers with
		-- red cone roofs that peek out past the head, a crenellated wall and a pennant
		local c = backColor
		local paper = Color3.fromRGB(250, 240, 220)
		local roof = RED
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(1.2, 0.1, 0.9), CFrame.new(0.6 * s, 0.5, 1.05) * CFrame.Angles(0, 0, 0.12 * s), c) -- covers
			block(torso, Vector3.new(1.1, 0.08, 0.82), CFrame.new(0.57 * s, 0.57, 1.05) * CFrame.Angles(0, 0, 0.12 * s), CREAM) -- pages
			block(torso, Vector3.new(0.18, 0.12, 0.8), CFrame.new(0.38 * s, 0.56, 0.4), U.Shade(c, 0.7)) -- strap
			local tx = 1.0 * s
			local tc0 = if s < 0 then Color3.fromRGB(255, 200, 215) else Color3.fromRGB(190, 215, 255)
			block(torso, Vector3.new(0.48, 1.55, 0.44), CFrame.new(tx, 1.35, 1.1), tc0) -- tower
			block(torso, Vector3.new(0.18, 0.3, 0.04), CFrame.new(tx, 1.5, 0.87), Color3.fromRGB(70, 60, 90)) -- window
			local top = cone(torso, CFrame.new(tx, 2.12, 1.1), 0.7, 0.75, 3, roof)
			if s > 0 then
				rod(torso, top.Position, top.Position + Vector3.new(0, 0.5, 0), 0.05, METAL)
				block(torso, Vector3.new(0.38, 0.22, 0.03), CFrame.new(top.Position + Vector3.new(0.2, 0.38, 0)), GOLD) -- pennant
			end
		end
		block(torso, Vector3.new(1.6, 0.85, 0.14), CFrame.new(0, 1.0, 1.15), paper) -- wall
		for i = -1, 1 do
			block(torso, Vector3.new(0.26, 0.24, 0.14), CFrame.new(i * 0.5, 1.53, 1.15), paper) -- crenels
		end
	elseif back == "Tentacles" then
		-- six octopus tentacles curling out from behind the waist (eight limbs with the arms); the top
		-- two hold a spare book and an ink pot
		local c = backColor
		local tipC = U.Mix(c, WHITE, 0.3)
		local tips: { [number]: Vector3 } = {}
		for k, spec in { { -1, 0.9 }, { -1, 1.65 }, { -1, 2.35 }, { 1, 0.9 }, { 1, 1.65 }, { 1, 2.35 } } do
			local s, a = spec[1], spec[2]
			local p = Vector3.new(0.3 * s, -0.25, 0.45)
			for i = 1, 4 do
				p += Vector3.new(math.sin(a) * s, -math.cos(a), 0.06) * 0.46
				ball(torso, 0.58 - i * 0.08, CFrame.new(p), if i == 4 then tipC else c)
				a += 0.5
			end
			tips[k] = p
		end
		local bp = tips[3] + Vector3.new(0, 0.25, 0)
		block(torso, Vector3.new(0.5, 0.6, 0.16), CFrame.new(bp) * CFrame.Angles(0, 0.4, 0.3), Color3.fromRGB(200, 70, 60)) -- book
		block(torso, Vector3.new(0.44, 0.54, 0.2), CFrame.new(bp + Vector3.new(0.03, 0, 0)) * CFrame.Angles(0, 0.4, 0.3), CREAM)
		local ip = tips[6] + Vector3.new(0, 0.22, 0)
		cyl(torso, 0.34, 0.36, CFrame.new(ip) * U.AxisY, Color3.fromRGB(40, 40, 70), { Reflectance = 0.2 }) -- ink pot
		cyl(torso, 0.1, 0.2, CFrame.new(ip + Vector3.new(0, 0.22, 0)) * U.AxisY, Color3.fromRGB(150, 100, 60))
	elseif back == "Pages" then
		-- loose pages fluttering round the shoulders, each with a line of writing
		for _, q in { { -1.3, 0.75, 0.45, 0.3 }, { 1.35, 1.2, 0.55, -0.4 }, { -1.1, 2.0, 0.75, 0.55 }, { 1.15, 2.35, 0.85, -0.25 }, { 0.15, 2.85, 1.0, 0.15 }, { -1.5, -0.15, 0.3, -0.5 } } do
			local cf = CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(0.3, q[4] * 1.5, q[4])
			block(torso, Vector3.new(0.5, 0.64, 0.03), cf, CREAM, { Transparency = 0.1 })
			block(torso, Vector3.new(0.34, 0.2, 0.04), cf * CFrame.new(0, 0.08, 0), U.Mix(U.Vivid(look.Beam), EYE, 0.5)) -- writing
		end
	elseif back == "RuneBooks" then
		-- halo of open spell books floating in an arc behind the head, each with a rune on its pages
		local cols = { backColor, Color3.fromRGB(70, 120, 210), Color3.fromRGB(200, 70, 60), Color3.fromRGB(60, 165, 120), Color3.fromRGB(160, 80, 170) }
		local hc = Vector3.new(0, 1.2, 0.95)
		for i = -3, 3 do
			local a = i * 0.5
			local p = hc + Vector3.new(math.sin(a) * 2.0, math.cos(a) * 1.85, 0.1 * math.abs(i))
			local cf = CFrame.new(p) * CFrame.Angles(0, -0.15 * i, -a * 0.5)
			block(torso, Vector3.new(0.86, 0.66, 0.08), cf * CFrame.new(0, 0, 0.04), cols[(i + 3) % #cols + 1]) -- cover
			block(torso, Vector3.new(0.76, 0.56, 0.08), cf, CREAM) -- pages
			block(torso, Vector3.new(0.18, 0.18, 0.03), cf * CFrame.new(0, 0, -0.04) * CFrame.Angles(0, 0, math.pi / 4), U.Vivid(look.Beam), if i == 0 then NEON else nil) -- rune
		end
	elseif back == "CloudSheep" then
		-- a fluffy cloud-sheep floating beside the left shoulder on a ribbon lead
		local c = backColor
		local dark = Color3.fromRGB(70, 75, 100)
		local sc = Vector3.new(-1.75, 0.3, -0.1)
		for _, q in { { 0, 0, 0, 1.0 }, { 0.38, 0.18, 0.2, 0.75 }, { -0.4, 0.12, 0.18, 0.75 }, { 0.05, 0.38, 0.1, 0.72 }, { 0, -0.05, 0.45, 0.72 } } do
			ball(torso, q[4], CFrame.new(sc + Vector3.new(q[1], q[2], q[3])), c)
		end
		local hp = sc + Vector3.new(-0.05, 0.08, -0.55)
		ball(torso, 0.52, CFrame.new(hp), dark)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.3, 0.1, 0.16), CFrame.new(hp + Vector3.new(0.3 * s, 0.08, 0.05)) * CFrame.Angles(0, 0, -0.45 * s), dark) -- ears
			ball(torso, 0.12, CFrame.new(hp + Vector3.new(0.11 * s, 0.06, -0.21)), WHITE) -- eyes
			for _, z in { -0.2, 0.25 } do
				cyl(torso, 0.3, 0.13, CFrame.new(sc + Vector3.new(0.25 * s, -0.55, z)) * U.AxisY, dark) -- legs
			end
		end
		rod(torso, Vector3.new(-0.62, 0.2, -0.3), hp + Vector3.new(0.18, -0.1, 0.12), 0.05, RED) -- lead
	elseif back == "HotAirBalloon" then
		-- wicker basket on the back, ropes up to a little striped hot-air balloon behind the head
		local c = backColor
		local wicker = Color3.fromRGB(175, 125, 70)
		local alt = Color3.fromRGB(255, 215, 70)
		block(torso, Vector3.new(1.05, 0.75, 0.7), CFrame.new(0, -0.05, 0.85), wicker)
		block(torso, Vector3.new(1.15, 0.14, 0.8), CFrame.new(0, 0.35, 0.85), U.Shade(wicker, 0.7)) -- rim
		local bc = Vector3.new(0, 2.85, 1.5)
		ball(torso, 1.7, CFrame.new(bc), c)
		for _, a in { 0, math.pi / 3, -math.pi / 3 } do
			cyl(torso, 0.24, 1.73, CFrame.new(bc) * CFrame.Angles(0, a, 0), alt) -- stripes
		end
		cone(torso, CFrame.new(bc - Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.pi, 0, 0), 1.0, 0.45, 2, c, alt)
		for _, s in { -1, 1 } do
			rod(torso, Vector3.new(0.48 * s, 0.4, 1.15), bc + Vector3.new(0.28 * s, -1.0, 0), 0.04, Color3.fromRGB(120, 90, 60)) -- ropes
		end
		ball(torso, 0.24, CFrame.new(bc - Vector3.new(0, 1.15, 0)), Color3.fromRGB(255, 170, 70), NEON) -- burner flame
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.18, 0.12, 0.8), CFrame.new(0.38 * s, 0.56, 0.1), U.Shade(wicker, 0.6)) -- strap
		end
	elseif back == "RainbowScarf" then
		-- long scarf round the neck streaming out behind in rainbow bands, one end hanging down the front
		cyl(torso, 0.32, 1.42, CFrame.new(0, 0.6, 0) * U.AxisY, RAINBOW[1])
		cyl(torso, 0.1, 1.46, CFrame.new(0, 0.6, 0) * U.AxisY, RAINBOW[3])
		block(torso, Vector3.new(0.34, 0.62, 0.1), CFrame.new(0.32, 0.2, -0.47) * CFrame.Angles(0, 0, 0.1), RAINBOW[6]) -- front end
		local prev = Vector3.new(0.45, 0.6, 0.45)
		for i = 1, 7 do
			local p = Vector3.new(0.45 + i * 0.3, 0.62 + 0.22 * math.sin(i * 1.2) + i * 0.08, 0.45 + i * 0.22)
			block(torso, Vector3.new(0.07, 0.5, (p - prev).Magnitude + 0.04), CFrame.lookAt((p + prev) / 2, p), RAINBOW[i])
			prev = p
		end
	elseif back == "Battery" then
		-- big battery slung across the back, poking out past both shoulders: copper end, terminal,
		-- a lightning badge and three charge lights
		local c = backColor
		local bc = CFrame.new(0, 0.1, 0.82)
		cyl(torso, 1.9, 0.86, bc, c)
		cyl(torso, 0.42, 0.88, bc * CFrame.new(0.76, 0, 0), Color3.fromRGB(205, 120, 60), METAL_MAT) -- copper end
		cyl(torso, 0.2, 0.34, bc * CFrame.new(1.05, 0, 0), METAL, METAL_MAT) -- terminal
		local bolt = U.Vivid(look.Beam)
		bar(torso, Vector3.new(0.12, 0.38, 1.26), Vector3.new(-0.08, 0.06, 1.26), 0.14, 0.04, bolt)
		bar(torso, Vector3.new(0.1, 0.14, 1.26), Vector3.new(-0.1, -0.2, 1.26), 0.14, 0.04, bolt)
		for i = -1, 1 do
			block(torso, Vector3.new(0.18, 0.08, 0.18), bc * CFrame.new(-0.45 + i * 0.22, 0.43, 0), Color3.fromRGB(110, 230, 120)) -- charge lights
		end
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.18, 0.12, 0.8), CFrame.new(0.38 * s, 0.56, 0.1), Color3.fromRGB(60, 60, 70)) -- strap
		end
	elseif back == "ShipWheel" then
		-- sky-ship steering wheel worn on the back: wooden rim, four crossing spokes with handles, gold hub
		local c = backColor
		local wc = CFrame.new(0.45, 0.55, 0.82) * CFrame.Angles(0, 0.35, 0.2)
		for _, p in U.Hoop(0.82, 0.14, 0.14, 8, torso.CFrame * wc, c, model) do
			add(torso, p)
		end
		cyl(torso, 0.22, 0.4, wc * U.AxisZ, GOLD, METAL_MAT) -- hub
		for i = 0, 3 do
			local a = i * math.pi / 4
			local d = Vector3.new(math.cos(a), math.sin(a), 0)
			local p0, p1 = (wc * CFrame.new(-d * 1.22)).Position, (wc * CFrame.new(d * 1.22)).Position
			rod(torso, p0, p1, 0.1, U.Shade(c, 0.85))
			ball(torso, 0.24, CFrame.new(p0), U.Shade(c, 0.7))
			ball(torso, 0.24, CFrame.new(p1), U.Shade(c, 0.7))
		end
	elseif back == "FeatherWings" then
		-- big storm-bird wings: four long feathers fanned out per side, alternating with lightning yellow
		local c = backColor
		local alt = U.Vivid(look.Beam)
		for _, s in { -1, 1 } do
			for i, a in { 0.55, 0.95, 1.35, 1.75 } do
				local cf = CFrame.new(0.35 * s, 0.45, 0.62) * CFrame.Angles(0, 0.2 * s, -s * a)
				spike(torso, cf, 0.55, 2.5 - i * 0.3, 0.08, if i % 2 == 1 then c else alt)
			end
		end
	elseif back == "Cyclone" then
		-- a little tornado swirling up behind her, leaning back and widening at the top, with a spark
		local c = backColor
		local top = Vector3.zero
		for i = 0, 7 do
			local p = Vector3.new(0.3 + 0.02 * i * i, -0.9 + i * 0.4, 0.85 + i * 0.11)
			cyl(torso, 0.54, 0.45 + i * 0.3, CFrame.new(p) * U.AxisY, if i % 2 == 0 then c else U.Mix(c, WHITE, 0.45), { Transparency = 0.15 })
			top = p
		end
		local bolt = U.Vivid(look.Beam)
		local b0 = top + Vector3.new(0.9, -0.6, -0.4)
		bar(torso, b0, b0 + Vector3.new(0.18, -0.4, 0), 0.14, 0.06, bolt)
		bar(torso, b0 + Vector3.new(0.05, -0.35, 0), b0 + Vector3.new(0.25, -0.8, 0), 0.11, 0.06, bolt)
	elseif back == "Surfboard" then
		-- surfboard strapped diagonally on the back: rounded ends, white centre stripe, small fin
		local c = backColor
		local bcf = CFrame.new(0, 0.7, 0.62) * CFrame.Angles(0, 0, 0.55)
		block(torso, Vector3.new(0.9, 3.4, 0.15), bcf, c)
		for _, y in { -1.7, 1.7 } do
			cyl(torso, 0.15, 0.9, bcf * CFrame.new(0, y, 0) * U.AxisZ, c) -- round ends
		end
		block(torso, Vector3.new(0.14, 4.0, 0.17), bcf, WHITE) -- stripe
		wedge(torso, Vector3.new(0.06, 0.32, 0.36), bcf * CFrame.new(0, -1.6, 0.24) * CFrame.Angles(-math.pi / 2, 0, 0), U.Shade(c, 0.7)) -- fin
		strap(Color3.fromRGB(60, 60, 70))
	elseif back == "Blocks" then
		-- little stack of falling-block shapes, the top piece still dropping with a gap below it
		local u = 0.46
		local cols = { backColor, Color3.fromRGB(255, 90, 100), Color3.fromRGB(255, 215, 70) }
		local pieces: { { { number } } } = {
			{ { 0, 0 }, { 1, 0 }, { 2, 0 }, { 2, 1 } }, -- L
			{ { 0, 1 }, { 1, 1 }, { 1, 2 }, { 2, 2 } }, -- Z
			{ { 0, 5 }, { 1, 5 }, { 2, 5 }, { 1, 4 } }, -- T, still falling
		}
		for k, cells in pieces do
			local col = cols[k]
			local dx = if k == 3 then 0.18 else 0
			for _, cell in cells do
				block(torso, Vector3.new(u - 0.03, u - 0.03, u - 0.03), CFrame.new((cell[1] - 1) * u + dx, -0.25 + cell[2] * u, 0.78 + k * 0.02), col)
			end
		end
		strap(Color3.fromRGB(60, 60, 70))
	elseif back == "HayBale" then
		-- hay bale strapped on the back: two twine bands and straw sticking out
		local c = backColor
		block(torso, Vector3.new(1.9, 0.95, 0.85), CFrame.new(0, 0.3, 0.85) * CFrame.Angles(0, 0, 0.12), c)
		for _, x in { -0.5, 0.5 } do
			block(torso, Vector3.new(0.07, 0.98, 0.88), CFrame.new(0, 0.3, 0.85) * CFrame.Angles(0, 0, 0.12) * CFrame.new(x, 0, 0), Color3.fromRGB(150, 90, 50)) -- twine
		end
		local straw = U.Mix(c, WHITE, 0.25)
		for _, q in { { -0.85, 0.85, 0.7, 0.4 }, { 0.15, 0.9, 1.0, -0.5 }, { 1.0, 0.75, 1.0, -0.9 }, { 0.98, 0.0, 0.7, -1.4 } } do
			wedge(torso, Vector3.new(0.06, 0.4, 0.14), CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(0, 0, q[4]), straw)
		end
		strap(Color3.fromRGB(110, 75, 50))
	elseif back == "CornBasket" then
		-- wicker basket on the back with corn cobs and husks sticking out
		local c = backColor
		block(torso, Vector3.new(1.05, 0.75, 0.62), CFrame.new(0, -0.1, 0.75), c)
		block(torso, Vector3.new(1.12, 0.12, 0.68), CFrame.new(0, 0.3, 0.75), U.Shade(c, 0.7)) -- rim
		for i, q in { { -0.32, 0.3 }, { -0.08, 0.1 }, { 0.15, -0.12 }, { 0.38, -0.3 } } do
			local ccf = CFrame.new(q[1] * 1.6, 0.75 + (i % 2) * 0.15, 0.8 + (i % 2) * 0.08) * CFrame.Angles(0.1 * i, 0, q[2] * 1.6)
			cyl(torso, 1.2, 0.32, ccf * U.AxisY, Color3.fromRGB(255, 215, 70))
			ball(torso, 0.32, ccf * CFrame.new(0, 0.6, 0), Color3.fromRGB(255, 225, 100))
			wedge(torso, Vector3.new(0.05, 0.6, 0.2), ccf * CFrame.new(0.14, -0.05, 0) * CFrame.Angles(0, math.pi / 2, -0.2), Color3.fromRGB(120, 190, 80)) -- husk
		end
		strap(U.Shade(c, 0.6))
	elseif back == "GiantPumpkin" then
		-- a prize pumpkin as big as a backpack, with ribs, a curly stem and a leaf
		local c = backColor
		local pc = Vector3.new(0.55, 0.75, 1.05)
		ball(torso, 1.9, CFrame.new(pc), c)
		for _, a in { -0.6, 0, 0.6 } do
			cyl(torso, 0.08, 1.78, CFrame.new(pc) * CFrame.Angles(0, a + math.pi / 2, 0), U.Shade(c, 0.8)) -- ribs
		end
		local green = Color3.fromRGB(90, 140, 60)
		cyl(torso, 0.4, 0.22, CFrame.new(pc + Vector3.new(0.05, 0.95, 0)) * CFrame.Angles(0, 0, 0.3) * U.AxisY, green) -- stem
		wedge(torso, Vector3.new(0.06, 0.3, 0.55), CFrame.new(pc + Vector3.new(-0.3, 0.88, 0)) * CFrame.Angles(0, math.pi / 2, -0.4), Color3.fromRGB(110, 190, 80)) -- leaf
		strap(Color3.fromRGB(110, 75, 50))
	elseif back == "SpiderWeb" then
		-- a dewy spider web stretched behind the head and a friendly little spider sitting in it
		local wc = CFrame.new(0, 1.75, 0.95) * CFrame.Angles(-0.15, 0, 0)
		local thread = Color3.fromRGB(245, 245, 255)
		local topt = { Transparency = 0.15 }
		for i = 0, 3 do
			bar(torso, (wc * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 1.65, 0)).Position, (wc * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, -1.65, 0)).Position, 0.05, 0.04, thread, topt)
		end
		for _, r in { 0.65, 1.3 } do
			for _, p in U.Hoop(r, 0.045, 0.04, 8, torso.CFrame * wc * CFrame.Angles(0, 0, math.pi / 8), thread, model, topt) do
				add(torso, p)
			end
		end
		local sp = wc * CFrame.new(0.95, 0.7, -0.08)
		ball(torso, 0.28, sp, Color3.fromRGB(90, 85, 100))
		ball(torso, 0.18, sp * CFrame.new(0, -0.2, -0.04), Color3.fromRGB(90, 85, 100))
		for _, s in { -1, 1 } do
			ball(torso, 0.07, sp * CFrame.new(0.05 * s, -0.22, -0.12), WHITE)
		end
	elseif back == "Chicken" then
		-- a plump hen perched on the right shoulder
		local c = backColor
		local hc = CFrame.new(1.08, 0.98, 0.12)
		ball(torso, 0.78, hc, c)
		block(torso, Vector3.new(0.12, 0.3, 0.42), hc * CFrame.new(0.27, 0.02, 0.02) * CFrame.Angles(0.2, 0, 0), U.Shade(c, 0.88)) -- wing
		wedge(torso, Vector3.new(0.14, 0.38, 0.3), hc * CFrame.new(0, 0.2, 0.3) * CFrame.Angles(-0.2, 0, 0), U.Shade(c, 0.9)) -- tail
		local h = hc * CFrame.new(0, 0.5, -0.24)
		ball(torso, 0.48, h, c)
		ball(torso, 0.16, h * CFrame.new(0, 0.2, 0.02), RED) -- comb
		ball(torso, 0.13, h * CFrame.new(0, 0.2, 0.14), RED)
		wedge(torso, Vector3.new(0.12, 0.12, 0.2), h * CFrame.new(0, -0.02, -0.25), Color3.fromRGB(255, 175, 50)) -- beak
		ball(torso, 0.1, h * CFrame.new(0, -0.14, -0.16), RED) -- wattle
		for _, s in { -1, 1 } do
			ball(torso, 0.08, h * CFrame.new(0.15 * s, 0.05, -0.13), EYE)
		end
	elseif back == "Monkey" then
		-- a cheeky little monkey riding on the right shoulder, long curly tail hanging down the back
		local c = backColor
		local face = Color3.fromRGB(240, 210, 175)
		local mc = CFrame.new(1.02, 0.88, 0.15)
		ball(torso, 0.6, mc, c)
		local h = mc * CFrame.new(0.05, 0.48, -0.08)
		ball(torso, 0.5, h, c)
		cyl(torso, 0.08, 0.36, h * CFrame.new(0, -0.03, -0.22) * U.AxisZ, face)
		for _, s in { -1, 1 } do
			cyl(torso, 0.08, 0.24, h * CFrame.new(0.27 * s, 0.05, 0) * CFrame.Angles(0, 0, 0), face) -- ears
			ball(torso, 0.09, h * CFrame.new(0.08 * s, 0.03, -0.27), EYE)
		end
		bar(torso, (mc * CFrame.new(-0.2, -0.05, -0.15)).Position, Vector3.new(0.5, 0.62, -0.42), 0.14, 0.14, c) -- arm round the neck
		local prev = (mc * CFrame.new(0, -0.15, 0.25)).Position
		for i = 1, 4 do
			local p = Vector3.new(1.0 + 0.15 * math.sin(i * 1.4), 0.6 - i * 0.3, 0.55 + 0.1 * i)
			rod(torso, prev, p, 0.1, c)
			prev = p
		end
	elseif back == "Parasol" then
		-- beach parasol stuck in a little backpack, tilted over the head
		local c = backColor
		block(torso, Vector3.new(0.85, 0.85, 0.42), CFrame.new(0, -0.05, 0.62), U.Mix(c, WHITE, 0.3))
		local p0, p1 = Vector3.new(-0.2, -0.2, 0.75), Vector3.new(-1.75, 2.35, 0.75)
		rod(torso, p0, p1, 0.1, WHITE)
		local tipCf = cone(torso, CFrame.lookAt(p1, p1 + (p1 - p0)) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, -0.15, 0), 3.0, 0.75, 4, c, WHITE)
		ball(torso, 0.2, tipCf, c)
	elseif back == "Tailfin" then
		-- mermaid tail curling up behind from the waist, ending in a big fluke
		local c = backColor
		local light = U.Mix(c, WHITE, 0.35)
		for i, q in { { 0, -0.4, 0.62, 0.72 }, { 0.3, -0.12, 0.95, 0.64 }, { 0.6, 0.3, 1.15, 0.54 }, { 0.85, 0.75, 1.25, 0.44 }, { 1.0, 1.15, 1.3, 0.34 } } do
			ball(torso, q[4], CFrame.new(q[1], q[2], q[3]), if i % 2 == 0 then light else c)
		end
		local fc = CFrame.new(1.08, 1.3, 1.3) * CFrame.Angles(0.2, 0, -0.35)
		for _, s in { -1, 1 } do
			spike(torso, fc * CFrame.Angles(0, 0, -0.85 * s), 0.6, 0.9, 0.08, c) -- fluke
			spike(torso, fc * CFrame.Angles(0, 0, -0.85 * s) * CFrame.new(0, 0.05, -0.03), 0.32, 0.55, 0.08, light)
		end
	elseif back == "Wave" then
		-- a curling wave rearing up behind, crest of white foam tipping over the head
		local c = backColor
		local light = U.Mix(c, WHITE, 0.4)
		local wc = Vector3.new(0, 1.6, 1.0)
		local prev: Vector3? = nil
		for i, deg in { -70, -40, -10, 20, 50, 80, 105, 125 } do
			local th = math.rad(deg)
			local r = 1.5 - i * 0.07
			local p = wc + Vector3.new(0, math.sin(th) * r, math.cos(th) * r)
			if prev then
				bar(torso, prev, p, 2.5 - i * 0.12, 0.34, if i % 2 == 0 then c else light, { Transparency = 0.1 })
			end
			prev = p
		end
		for k = -2, 2 do
			ball(torso, 0.42 - math.abs(k) * 0.05, CFrame.new((prev :: Vector3) + Vector3.new(k * 0.42, 0.05 - math.abs(k) * 0.06, 0.05)), WHITE)
		end
	elseif back == "ShoppingCart" then
		-- shopping cart parked behind: see-through wire basket, rim, wheels, handle at his back, shopping inside
		local c = backColor
		local bc = CFrame.new(0, -0.35, 1.45)
		block(torso, Vector3.new(1.2, 0.75, 1.1), bc, c, { Transparency = 0.55 })
		block(torso, Vector3.new(1.26, 0.07, 1.16), bc * CFrame.new(0, 0.4, 0), U.Shade(c, 0.7), METAL_MAT) -- rim
		block(torso, Vector3.new(1.0, 0.07, 1.0), bc * CFrame.new(0, -0.62, 0), U.Shade(c, 0.7), METAL_MAT) -- base frame
		for _, s in { -1, 1 } do
			for _, z in { -0.42, 0.42 } do
				cyl(torso, 0.1, 0.24, bc * CFrame.new(0.45 * s, -0.95, z), Color3.fromRGB(40, 40, 50)) -- wheels
				rod(torso, (bc * CFrame.new(0.45 * s, -0.62, z)).Position, (bc * CFrame.new(0.45 * s, -0.85, z)).Position, 0.05, METAL, METAL_MAT)
			end
		end
		rod(torso, Vector3.new(-0.6, 0.15, 0.8), Vector3.new(0.6, 0.15, 0.8), 0.1, RED) -- handle
		block(torso, Vector3.new(0.45, 0.5, 0.35), bc * CFrame.new(-0.25, 0.25, 0.1) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(255, 200, 70)) -- cereal box
		ball(torso, 0.4, bc * CFrame.new(0.3, 0.35, -0.15), Color3.fromRGB(120, 210, 90)) -- melon
	elseif back == "Scooter" then
		-- two-wheeled self-balancing scooter: platform under the feet, big wheels, column and handlebar
		local c = backColor
		block(torso, Vector3.new(1.25, 0.16, 0.85), CFrame.new(0, -1.34, -0.08), c)
		for _, s in { -1, 1 } do
			cyl(torso, 0.24, 0.95, CFrame.new(0.78 * s, -0.95, -0.08), Color3.fromRGB(35, 35, 40)) -- wheel
			cyl(torso, 0.26, 0.45, CFrame.new(0.78 * s, -0.95, -0.08), Color3.fromRGB(200, 205, 215), METAL_MAT) -- hub
		end
		rod(torso, Vector3.new(0, -1.25, -0.45), Vector3.new(0, 0.3, -0.85), 0.14, c)
		rod(torso, Vector3.new(-0.55, 0.32, -0.88), Vector3.new(0.55, 0.32, -0.88), 0.12, METAL, METAL_MAT) -- handlebar
		for _, s in { -1, 1 } do
			cyl(torso, 0.22, 0.17, CFrame.new(0.6 * s, 0.32, -0.88), Color3.fromRGB(35, 35, 40)) -- grips
		end
		block(torso, Vector3.new(0.3, 0.12, 0.05), CFrame.new(0, 0.12, -0.83) * CFrame.Angles(-0.25, 0, 0), U.Vivid(look.Beam)) -- light
	elseif back == "Stand" then
		-- shop-window display stand: round base under the feet and a pole into the back, a price tag on a string
		local c = backColor
		cyl(torso, 0.12, 2.2, CFrame.new(0, -1.36, 0.05) * U.AxisY, c, METAL_MAT)
		rod(torso, Vector3.new(0, -1.3, 0.55), Vector3.new(0, -0.2, 0.5), 0.14, c, METAL_MAT)
		block(torso, Vector3.new(0.3, 0.14, 0.2), CFrame.new(0, -0.2, 0.46), c, METAL_MAT)
		rod(torso, Vector3.new(0.55, -0.45, -0.3), Vector3.new(0.75, -0.8, -0.5), 0.03, WHITE)
		block(torso, Vector3.new(0.38, 0.5, 0.05), CFrame.new(0.82, -1.05, -0.52) * CFrame.Angles(0, -0.4, 0.15), Color3.fromRGB(255, 235, 150)) -- price tag
		ball(torso, 0.08, CFrame.new(0.78, -0.86, -0.55), EYE)
	elseif back == "ShoppingBags" then
		-- paper shopping bags hanging all round the hips, tissue paper peeking out
		local cols = { backColor, Color3.fromRGB(130, 220, 255), Color3.fromRGB(255, 215, 90), Color3.fromRGB(180, 120, 255) }
		for i, q in { { 1.35, -0.4, 0.1, 0.3 }, { 0.75, -0.45, 0.68, -0.2 }, { -0.3, -0.5, 0.7, 0.25 }, { -1.3, -0.35, 0.3, -0.4 } } do
			local bcf = CFrame.new(q[1], q[2], q[3]) * CFrame.Angles(0, q[4], 0.08 * i - 0.2)
			block(torso, Vector3.new(0.6, 0.66, 0.32), bcf, cols[i])
			for _, s in { -1, 1 } do
				bar(torso, (bcf * CFrame.new(0.15 * s, 0.33, 0)).Position, (bcf * CFrame.new(0.03 * s, 0.6, 0)).Position, 0.05, 0.05, U.Shade(cols[i], 0.6)) -- handles
			end
			wedge(torso, Vector3.new(0.05, 0.22, 0.26), bcf * CFrame.new(0.1, 0.42, 0) * CFrame.Angles(0, math.pi / 2, 0), WHITE) -- tissue
		end
	elseif back == "Bone" then
		-- a giant dinosaur bone slung across the back
		local c = backColor
		local bcf = CFrame.new(0, 0.55, 0.65) * CFrame.Angles(0, 0, 0.6)
		cyl(torso, 2.9, 0.42, bcf, c)
		for _, x in { -1.5, 1.5 } do
			for _, y in { -0.2, 0.2 } do
				ball(torso, 0.6, bcf * CFrame.new(x, y, 0), c) -- knobs
			end
		end
		strap(Color3.fromRGB(110, 75, 50))
	elseif back == "DinoEgg" then
		-- a big speckled dinosaur egg in a straw nest on the back, a baby dino peeking out of the crack
		local c = backColor
		local ec = Vector3.new(0.7, 0.35, 0.95)
		cyl(torso, 0.35, 1.3, CFrame.new(ec - Vector3.new(0, 0.45, 0)) * U.AxisY, Color3.fromRGB(200, 165, 90)) -- nest
		ball(torso, 1.15, CFrame.new(ec), c)
		ball(torso, 0.88, CFrame.new(ec + Vector3.new(0, 0.42, 0)), c)
		for _, d in { Vector3.new(0.4, 0.2, -0.3), Vector3.new(-0.5, 0.0, 0.1), Vector3.new(0.3, 0.55, 0.2), Vector3.new(-0.2, 0.7, -0.3), Vector3.new(0.5, -0.1, 0.35) } do
			local n = d.Unit
			cyl(torso, 0.05, 0.16, U.DiscFacing(ec + Vector3.new(0, 0.2, 0) + n * 0.57, n), U.Shade(c, 0.7)) -- speckles
		end
		local bh = ec + Vector3.new(0.1, 1.0, 0)
		ball(torso, 0.42, CFrame.new(bh), Color3.fromRGB(120, 200, 100))
		for _, s in { -1, 1 } do
			ball(torso, 0.1, CFrame.new(bh + Vector3.new(0.1 * s, 0.06, -0.18)), EYE)
		end
		strap(Color3.fromRGB(110, 75, 50))
	elseif back == "DinoTail" then
		-- dinosaur tail from the lower back to the floor; bony vertebrae when the hunter wears a fossil skull
		local c = backColor
		local bony = hat == "DinoSkull"
		for i = 0, 6 do
			local p = Vector3.new(0, -0.45 - i * 0.14 + i * i * 0.008, 0.6 + i * 0.36)
			local d = 0.8 - i * 0.08
			if bony then
				block(torso, Vector3.new(d * 0.55, d * 0.55, 0.26), CFrame.new(p), c)
				wedge(torso, Vector3.new(0.08, d * 0.45, 0.22), CFrame.new(p + Vector3.new(0, d * 0.45, 0)), U.Shade(c, 0.85))
			else
				ball(torso, d, CFrame.new(p), c)
			end
		end
	elseif back == "Stripes" then
		-- referee stripes painted on the shirt (front, back and sides)
		local c = backColor
		for _, x in { -0.47, -0.16, 0.16, 0.47 } do
			for _, z in { -0.43, 0.43 } do
				block(torso, Vector3.new(0.14, 1.06, 0.02), CFrame.new(x, 0, z), c)
			end
		end
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.02, 1.06, 0.14), CFrame.new(0.66 * s, 0, 0), c)
		end
	elseif back == "SugarCube" then
		-- a sparkly sugar cube twice his size, tipped on its corner
		local c = backColor
		local cc = CFrame.new(0.35, 0.75, 1.1) * CFrame.Angles(0.3, 0.6, 0.25)
		block(torso, Vector3.new(1.45, 1.45, 1.45), cc, c)
		for _, q in { { 0.5, 0.73, 0.2 }, { -0.3, 0.73, -0.4 }, { 0.73, 0.1, -0.3 }, { 0.73, -0.4, 0.45 }, { -0.2, -0.3, -0.73 }, { 0.4, 0.35, -0.73 } } do
			block(torso, Vector3.new(0.14, 0.14, 0.14), cc * CFrame.new(q[1], q[2], q[3]) * U.VertexUp, Color3.fromRGB(215, 235, 255), { Reflectance = 0.4 }) -- crystals
		end
		strap(Color3.fromRGB(120, 130, 150))
	elseif back == "ThreadSpool" then
		-- a wooden spool of thread lying across the back, a loose end dangling
		local c = backColor
		local wood = Color3.fromRGB(205, 160, 105)
		local sc = CFrame.new(0.15, 0.75, 0.85) * CFrame.Angles(0, 0, 0.3)
		cyl(torso, 1.5, 1.1, sc, c)
		for _, x in { -0.83, 0.83 } do
			cyl(torso, 0.18, 1.45, sc * CFrame.new(x, 0, 0), wood)
		end
		for _, x in { -0.3, 0.25 } do
			cyl(torso, 0.04, 1.12, sc * CFrame.new(x, 0, 0), U.Shade(c, 0.8)) -- winding lines
		end
		local p0 = (sc * CFrame.new(0.5, -0.55, -0.05)).Position
		rod(torso, p0, p0 + Vector3.new(0.25, -0.5, 0.1), 0.05, c)
		rod(torso, p0 + Vector3.new(0.25, -0.5, 0.1), p0 + Vector3.new(0.05, -0.9, 0.2), 0.05, c)
		strap(Color3.fromRGB(110, 75, 50))
	elseif back == "ButtonShield" then
		-- a giant sewing button carried as a shield, thread criss-crossing its four holes
		local c = backColor
		local bcf = CFrame.new(0.3, 0.6, 0.65) * CFrame.Angles(0, 0.3, 0.25)
		cyl(torso, 0.2, 2.1, bcf * U.AxisZ, U.Shade(c, 0.8))
		cyl(torso, 0.22, 1.65, bcf * CFrame.new(0, 0, 0.02) * U.AxisZ, c)
		local holes = { Vector3.new(-0.24, 0.24, 0.13), Vector3.new(0.24, 0.24, 0.13), Vector3.new(-0.24, -0.24, 0.13), Vector3.new(0.24, -0.24, 0.13) }
		for _, h in holes do
			cyl(torso, 0.04, 0.22, bcf * CFrame.new(h) * U.AxisZ, U.Shade(c, 0.4))
		end
		local th = Color3.fromRGB(250, 240, 220)
		bar(torso, (bcf * CFrame.new(holes[1] + Vector3.new(0, 0, 0.02))).Position, (bcf * CFrame.new(holes[4] + Vector3.new(0, 0, 0.02))).Position, 0.07, 0.04, th)
		bar(torso, (bcf * CFrame.new(holes[2] + Vector3.new(0, 0, 0.02))).Position, (bcf * CFrame.new(holes[3] + Vector3.new(0, 0, 0.02))).Position, 0.07, 0.04, th)
	elseif back == "Sailboat" then
		-- a toy sailboat strapped to the back: red hull, mast, white sail and a little flag
		local c = backColor
		local bc = CFrame.new(0.2, 0.25, 0.85) * CFrame.Angles(0, 0, -0.2)
		block(torso, Vector3.new(1.2, 0.32, 0.5), bc, c)
		for _, s in { -1, 1 } do
			wedge(torso, Vector3.new(0.5, 0.32, 0.35), bc * CFrame.new(0.77 * s, 0, 0) * CFrame.Angles(0, -s * math.pi / 2, 0) * CFrame.Angles(0, math.pi, 0), c) -- bow / stern
		end
		block(torso, Vector3.new(1.22, 0.08, 0.52), bc * CFrame.new(0, 0.12, 0), WHITE) -- deck stripe
		rod(torso, (bc * CFrame.new(0, 0.1, 0)).Position, (bc * CFrame.new(0, 2.2, 0)).Position, 0.08, Color3.fromRGB(150, 105, 60))
		wedge(torso, Vector3.new(0.05, 1.6, 0.95), bc * CFrame.new(0.5, 1.15, 0) * CFrame.Angles(0, -math.pi / 2, 0), WHITE) -- sail
		block(torso, Vector3.new(0.3, 0.18, 0.03), bc * CFrame.new(0.16, 2.1, 0), Color3.fromRGB(255, 215, 70)) -- flag
		strap(Color3.fromRGB(110, 75, 50))
	elseif back == "FridgeDoor" then
		-- an open fridge door standing beside the right shoulder, its shelves full of snacks
		local c = backColor
		local dcf = CFrame.new(1.45, 0.25, 0.45) * CFrame.Angles(0, 0.35, 0)
		block(torso, Vector3.new(1.3, 2.6, 0.22), dcf, c)
		block(torso, Vector3.new(0.1, 0.9, 0.1), dcf * CFrame.new(-0.55, 0.2, 0.16), Color3.fromRGB(190, 200, 215), METAL_MAT) -- handle
		for k, y in { -0.75, 0.0, 0.75 } do
			block(torso, Vector3.new(1.15, 0.08, 0.3), dcf * CFrame.new(0, y - 0.22, -0.2), U.Shade(c, 0.85)) -- shelf
			if k == 1 then
				block(torso, Vector3.new(0.28, 0.5, 0.25), dcf * CFrame.new(-0.3, y + 0.07, -0.2), WHITE) -- milk
				block(torso, Vector3.new(0.29, 0.12, 0.26), dcf * CFrame.new(-0.3, y + 0.36, -0.2), Color3.fromRGB(90, 150, 230))
				cyl(torso, 0.45, 0.2, dcf * CFrame.new(0.2, y + 0.04, -0.2) * U.AxisY, RED) -- ketchup
			elseif k == 2 then
				for i = 0, 2 do
					ball(torso, 0.22, dcf * CFrame.new(-0.3 + i * 0.28, y - 0.07, -0.2), CREAM) -- eggs
				end
			else
				wedge(torso, Vector3.new(0.4, 0.28, 0.25), dcf * CFrame.new(0.15, y - 0.04, -0.2), Color3.fromRGB(255, 210, 80)) -- cheese
			end
		end
	elseif back == "Cake" then
		-- three-tier party cake carried on the left hip: frosting bands, sprinkles and a cherry on top
		local c = backColor
		local cream = Color3.fromRGB(255, 245, 235)
		local y = -0.75
		for i, d in { 1.55, 1.2, 0.85 } do
			local h = 0.48
			cyl(torso, h, d, CFrame.new(-1.3, y + h / 2, 0.45) * U.AxisY, if i % 2 == 1 then c else cream)
			cyl(torso, 0.1, d + 0.05, CFrame.new(-1.3, y + h, 0.45) * U.AxisY, if i % 2 == 1 then cream else c) -- frosting
			y += h
		end
		ball(torso, 0.3, CFrame.new(-1.3, y + 0.18, 0.45), RED) -- cherry
		bar(torso, Vector3.new(-0.6, 0.5, 0.2), Vector3.new(-1.0, -0.6, 0.4), 0.14, 0.08, U.Shade(c, 0.7)) -- sash
		for i = 0, 2 do
			local a = i * 2.1 + 0.3
			block(torso, Vector3.new(0.18, 0.05, 0.05), CFrame.new(-1.3 + math.cos(a) * 0.79, -0.1 + (i % 2) * 0.3, 0.45 + math.sin(a) * 0.79) * CFrame.Angles(0, a, 0.6 * (i % 3)), RAINBOW[i + 1]) -- sprinkles
		end
	elseif back == "Overalls" then
		-- dungaree bib with straps over the shoulders and two gold buttons
		local c = backColor
		block(torso, Vector3.new(0.82, 0.55, 0.04), CFrame.new(0, -0.2, -0.44), c)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.17, 0.5, 0.04), CFrame.new(0.3 * s, 0.3, -0.44), c)
			block(torso, Vector3.new(0.17, 0.06, 0.88), CFrame.new(0.3 * s, 0.54, 0), c)
			block(torso, Vector3.new(0.17, 0.95, 0.04), CFrame.new(0.2 * s, 0.05, 0.44) * CFrame.Angles(0, 0, 0.25 * s), c)
			ball(torso, 0.16, CFrame.new(0.3 * s, 0.08, -0.46), GOLD, METAL_MAT)
		end
	elseif back == "PelletTrail" then
		-- a trail of power pellets floating behind, and a little scared blue ghost following them
		for i = 0, 3 do
			ball(torso, if i == 3 then 0.4 else 0.22, CFrame.new(0.75 + i * 0.25, 0.75 + i * 0.22, 0.55 + i * 0.12), CREAM)
		end
		local c = backColor
		local gc = Vector3.new(1.75, 1.85, 1.1)
		ball(torso, 0.75, CFrame.new(gc), c)
		cyl(torso, 0.35, 0.75, CFrame.new(gc - Vector3.new(0, 0.2, 0)) * U.AxisY, c)
		for k = -1, 1 do
			ball(torso, 0.26, CFrame.new(gc + Vector3.new(k * 0.25, -0.4, 0)), c) -- wavy hem
		end
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.14, 0.14, 0.06), CFrame.new(gc + Vector3.new(0.15 * s, 0.08, -0.37)), WHITE)
		end
	elseif back == "PixelWings" then
		-- stair-stepped 8-bit wings: columns of chunky pixels growing taller toward the tips
		local c = backColor
		local light = U.Mix(c, WHITE, 0.45)
		local u = 0.34
		for _, s in { -1, 1 } do
			for col, span in { { 0, 3 }, { 1, 4 }, { 2, 5 }, { 4, 5 } } do
				local x = (0.45 + col * u) * s
				local y0, y1 = -0.2 + span[1] * u * 0.5, 0.2 + span[2] * u * 0.5
				block(torso, Vector3.new(u, y1 - y0, 0.14), CFrame.new(x, (y0 + y1) / 2 + col * 0.12, 0.62), if col % 2 == 0 then c else light, { Transparency = 0.05 })
			end
			block(torso, Vector3.new(u, u, 0.16), CFrame.new((0.45 + 4 * u) * s, 1.42, 0.62), WHITE)
		end
	-- CYBERARCADE (world2c) ---------------------------------------- backs
	elseif back == "DirtBlock" then
		-- a voxel dirt block worn as a backpack: grassy top layer with green drips down the sides
		local c = backColor
		local green = Color3.fromRGB(95, 180, 70)
		local bcf = CFrame.new(0, 0.05, 0.9)
		block(torso, Vector3.new(1.1, 1.1, 1.1), bcf, c)
		block(torso, Vector3.new(1.14, 0.28, 1.14), bcf * CFrame.new(0, 0.42, 0), green)
		for _, q in { { -0.28, 0.4 }, { 0.42, 0.3 } } do
			block(torso, Vector3.new(0.28, 0.25, 1.16), bcf * CFrame.new(q[1], 0.2, 0), green) -- drip
		end
		for _, q in { { 0.28, -0.1 }, { -0.28, -0.38 } } do
			block(torso, Vector3.new(0.27, 0.27, 1.13), bcf * CFrame.new(q[1], q[2], 0), U.Shade(c, 0.75)) -- darker dirt pixels
		end
		strap(Color3.fromRGB(70, 55, 45))
	elseif back == "PixelGhostPal" then
		-- a scared blue pixel ghost floating behind the shoulder, chasing a short trail of power pellets
		local c = backColor
		local gc = CFrame.new(1.55, 1.7, 0.9) * CFrame.Angles(0, -0.5, 0.12)
		block(torso, Vector3.new(0.95, 0.7, 0.55), gc, c)
		block(torso, Vector3.new(0.62, 0.22, 0.55), gc * CFrame.new(0, 0.45, 0), c) -- round-ish top
		for k = -1, 1 do
			block(torso, Vector3.new(0.22, 0.2, 0.55), gc * CFrame.new(k * 0.36, -0.44, 0), c) -- wavy hem
		end
		local pale = Color3.fromRGB(255, 225, 200)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.16, 0.16, 0.06), gc * CFrame.new(0.2 * s, 0.12, -0.28), pale) -- eyes
		end
		block(torso, Vector3.new(0.5, 0.07, 0.06), gc * CFrame.new(0, -0.14, -0.28), pale) -- wobbly mouth
		for i = 0, 2 do
			block(torso, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.75 + i * 0.25, 0.9 + i * 0.22, 0.75), CREAM) -- pellets
		end
	elseif back == "PipeOveralls" then
		-- plumber dungarees (bib, straps, gold buttons), white gloves and a green warp pipe on the back
		-- poking up over the left shoulder
		local c = backColor
		block(torso, Vector3.new(0.9, 0.6, 0.04), CFrame.new(0, -0.2, -0.44), c)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.18, 0.5, 0.04), CFrame.new(0.32 * s, 0.3, -0.44), c)
			block(torso, Vector3.new(0.18, 0.06, 0.9), CFrame.new(0.32 * s, 0.55, 0), c)
			ball(torso, 0.2, CFrame.new(0.32 * s, 0.08, -0.47), GOLD, METAL_MAT)
			hands[s].Color = WHITE
		end
		local pg = Color3.fromRGB(55, 175, 70)
		local pc = CFrame.new(0.68, 0.5, 1.05)
		cyl(torso, 2.2, 0.85, pc * U.AxisY, pg)
		cyl(torso, 0.42, 1.12, pc * CFrame.new(0, 1.25, 0) * U.AxisY, pg) -- rim
		cyl(torso, 0.05, 0.86, pc * CFrame.new(0, 1.45, 0) * U.AxisY, Color3.fromRGB(20, 50, 25)) -- dark inside
		block(torso, Vector3.new(0.5, 0.14, 0.3), CFrame.new(0.45, 0.2, 0.6), U.Shade(c, 0.8)) -- holder strap
	elseif back == "SpeedLines" then
		-- speed streaks trailing off the back: by the time you see him, he's gone
		local c = backColor
		for i, q in { { 0.55, 1.1, 0.75 }, { 0.1, 1.5, 0.55 }, { -0.35, 1.0, 0.8 } } do
			block(torso, Vector3.new(0.12, 0.12, q[2]), CFrame.new(q[3], q[1], 0.65 + q[2] / 2), U.Mix(c, WHITE, 0.15 * i), { Transparency = 0.25 })
		end
	elseif back == "RaccoonTail" then
		-- bushy ringed raccoon tail curling up behind in chunky voxel rings, plus a striped bandit shirt
		local c = backColor
		local dark = Color3.fromRGB(35, 32, 40)
		local pts = { Vector3.new(0.15, -0.45, 0.6), Vector3.new(0.4, -0.3, 1.05), Vector3.new(0.7, 0.05, 1.35), Vector3.new(0.92, 0.5, 1.45), Vector3.new(1.05, 0.98, 1.38), Vector3.new(1.12, 1.45, 1.2), Vector3.new(1.1, 1.85, 0.98) }
		for i, p in pts do
			local sz = 0.74 - i * 0.03
			block(torso, Vector3.new(sz, sz, sz), CFrame.new(p) * CFrame.Angles(0.25 * i, 0.3, 0.15 * i), if i % 2 == 0 or i == #pts then dark else c)
		end
		for _, y in { 0.24, -0.16 } do
			block(torso, Vector3.new(1.33, 0.15, 0.88), CFrame.new(0, y, 0), WHITE) -- shirt stripes
		end
		for _, s in { -1, 1 } do
			block(arms[s], Vector3.new(0.44, 0.13, 0.44), CFrame.new(0, 0.05, 0), WHITE)
		end
	elseif back == "HeroShield" then
		-- round hero shield on the back (silver rim, coloured face, gold bird emblem), a brown belt with a
		-- gold buckle and a tiny glowing fairy friend hovering by the left shoulder
		local c = backColor
		local scf = CFrame.new(0.3, 0.05, 0.62) * CFrame.Angles(0, 0.55, 0.18)
		cyl(torso, 0.12, 1.55, scf * U.AxisZ, Color3.fromRGB(200, 205, 215), METAL_MAT) -- rim
		cyl(torso, 0.14, 1.32, scf * CFrame.new(0, 0, 0.03) * U.AxisZ, c) -- face
		local ecf = scf * CFrame.new(0, 0, 0.11) * CFrame.Angles(0, math.pi, 0)
		spike(torso, ecf * CFrame.new(0, -0.32, 0), 0.3, 0.62, 0.04, GOLD) -- emblem body
		for _, s in { -1, 1 } do
			spike(torso, ecf * CFrame.new(0.1 * s, 0.05, 0) * CFrame.Angles(0, 0, -1.0 * s), 0.24, 0.48, 0.04, GOLD) -- wings
		end
		local brown = Color3.fromRGB(110, 70, 40)
		block(torso, Vector3.new(1.34, 0.18, 0.89), CFrame.new(0, -0.36, 0), brown) -- belt
		block(torso, Vector3.new(0.26, 0.22, 0.06), CFrame.new(0, -0.36, -0.46), GOLD, METAL_MAT) -- buckle
		bar(torso, Vector3.new(0.5, 0.55, -0.43), Vector3.new(-0.55, -0.32, -0.43), 0.14, 0.04, brown) -- shield strap
		local f = Vector3.new(-1.3, 1.6, -0.25)
		ball(torso, 0.3, CFrame.new(f), Color3.fromRGB(235, 250, 255), NEON) -- fairy
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.36, 0.22, 0.03), CFrame.new(f + Vector3.new(0.17 * s, 0.13, 0.08)) * CFrame.Angles(0, 0, 0.5 * s), Color3.fromRGB(190, 225, 255), { Transparency = 0.35 })
			block(torso, Vector3.new(0.24, 0.15, 0.03), CFrame.new(f + Vector3.new(0.14 * s, -0.08, 0.08)) * CFrame.Angles(0, 0, -0.4 * s), Color3.fromRGB(190, 225, 255), { Transparency = 0.35 })
		end
	elseif back == "WarpStar" then
		-- big yellow star riding behind the back with a short rainbow trail streaming off it
		local c = backColor
		local scf = CFrame.new(0.45, 1.25, 1.75) * CFrame.Angles(0, 0, -0.3)
		cyl(torso, 0.34, 1.05, scf * U.AxisZ, c)
		for i = 0, 4 do
			spike(torso, scf * CFrame.Angles(0, 0, i * 2 * math.pi / 5) * CFrame.new(0, 0.42, 0), 0.66, 0.78, 0.3, c)
		end
		for i = 1, 2 do
			bar(torso, Vector3.new(-0.15, 0.95 + (i - 1.5) * 0.35, 1.85), Vector3.new(-1.65, 0.35 + (i - 1.5) * 0.35, 2.1), 0.22, 0.07, RAINBOW[i * 3 - 2]) -- trail
		end
	elseif back == "BlockStorm" then
		-- final boss: a whirlwind of falling-block pieces spiralling up round her from her feet to above
		-- her crown, plus a short stepped 8-bit cape and tall pointed collar wings
		local c = backColor
		for i, q in { { 1.4, 0.45, -0.1 }, { 2.1, -0.1, -0.65 }, { 2.8, -0.65, -1.25 } } do
			block(torso, Vector3.new(q[1], q[2] - q[3], 0.14), CFrame.new(0, (q[2] + q[3]) / 2, 0.48 + i * 0.07), if i == 2 then U.Shade(c, 0.82) else c)
		end
		for _, s in { -1, 1 } do
			spike(torso, CFrame.new(0.72 * s, 0.5, 0.3) * CFrame.Angles(-0.2, 0, -0.55 * s), 0.7, 1.65, 0.1, c) -- collar
		end
		local u = 0.36
		local shapes: { { { number } } } = { -- each piece as one or two blocks: { width, height, x, y } in cells
			{ { 4, 1, 0, 0 } }, -- I
			{ { 3, 1, 0, 0 }, { 1, 1, 0, 1 } }, -- T
			{ { 2, 2, 0, 0 } }, -- O
			{ { 3, 1, 0, 0 }, { 1, 1, 1, 1 } }, -- L
			{ { 2, 1, -0.5, 0 }, { 2, 1, 0.5, 1 } }, -- S
			{ { 3, 1, 0, 0 }, { 1, 1, -1, 1 } }, -- J
			{ { 4, 1, 0, 0 } }, -- I
		}
		-- the pieces orbit her on a tilted ring: low in front (round her knees, so the face stays clear)
		-- and high behind (over her shoulders)
		for i, cells in shapes do
			local a = 0.35 + (i - 1) * 2 * math.pi / #shapes
			local x, z = 2.1 * math.sin(a), -2.1 * math.cos(a)
			local pcf = CFrame.new(x, 0.35 + 0.42 * z, z) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0.35, 0, 0.5 * math.sin(i * 1.7))
			local col = RAINBOW[(i - 1) % #RAINBOW + 1]
			for _, b in cells do
				block(torso, Vector3.new(b[1] * u - 0.02, b[2] * u - 0.02, u - 0.02), pcf * CFrame.new(b[3] * u, b[4] * u, 0), col)
			end
		end
	-- end CYBERARCADE (world2c) backs
	elseif back == "Caterpillar" then
		-- a very hungry caterpillar draped over the shoulders: green segments, red face, purple feet and
		-- antennae, with a half-eaten apple
		local c = backColor
		local pts = { Vector3.new(-0.95, 0.5, 0.2), Vector3.new(-0.7, 0.62, 0.55), Vector3.new(-0.25, 0.65, 0.7), Vector3.new(0.25, 0.62, 0.7), Vector3.new(0.7, 0.6, 0.55), Vector3.new(1.0, 0.72, 0.18) }
		for i, p in pts do
			ball(torso, 0.5, CFrame.new(p), if i % 2 == 0 then c else U.Shade(c, 0.82))
			if i % 2 == 1 then
				ball(torso, 0.14, CFrame.new(p + Vector3.new(0, -0.25, 0)), Color3.fromRGB(140, 80, 190)) -- feet
			end
		end
		local h = Vector3.new(1.12, 1.08, -0.12)
		ball(torso, 0.7, CFrame.new(h), Color3.fromRGB(220, 50, 60))
		for _, s in { -1, 1 } do
			ball(torso, 0.18, CFrame.new(h + Vector3.new(0.13 * s, 0.08, -0.25)), Color3.fromRGB(200, 230, 60))
			rod(torso, h + Vector3.new(0.12 * s, 0.25, 0), h + Vector3.new(0.25 * s, 0.6, -0.05), 0.05, Color3.fromRGB(140, 80, 190))
		end
		local ap = Vector3.new(-0.35, -0.2, 0.68)
		ball(torso, 0.5, CFrame.new(ap), RED)
		cyl(torso, 0.06, 0.2, U.DiscFacing(ap + Vector3.new(0, 0, 0.24), Vector3.zAxis), Color3.fromRGB(250, 240, 200)) -- bite hole
		rod(torso, ap + Vector3.new(0, 0.2, 0), ap + Vector3.new(0.04, 0.4, 0), 0.05, Color3.fromRGB(110, 75, 50))
	elseif back == "BigBelly" then
		-- big round fluffy spirit body: a pale belly patch with little chevron markings
		local c = backColor
		local pale = look.Pants
		ball(torso, 2.05, CFrame.new(0, -0.12, 0.02), c)
		local n = Vector3.new(0, -0.15, -1).Unit
		cyl(torso, 0.06, 1.35, U.DiscFacing(Vector3.new(0, -0.12, 0.02) + n * 0.98, n), pale)
		for i = -1, 1 do
			local cp = Vector3.new(i * 0.3, 0.12 - math.abs(i) * 0.04, -0.98)
			for _, s in { -1, 1 } do
				block(torso, Vector3.new(0.16, 0.05, 0.04), CFrame.new(cp + Vector3.new(0.06 * s, -0.03, 0)) * CFrame.Angles(0, 0, -0.6 * s), U.Shade(c, 0.6))
			end
		end
	elseif back == "MagicMirror" then
		-- ornate magic mirror carried on the back over the shoulder: gold frame, misty glass, a calm face in it
		local c = backColor
		local mcf = CFrame.new(0.85, 1.05, 0.8) * CFrame.Angles(0, -0.35, -0.15)
		for _, p in U.Hoop(0.82, 0.18, 0.16, 12, torso.CFrame * mcf, c, model, METAL_MAT) do
			add(torso, p)
		end
		cyl(torso, 0.08, 1.55, mcf * CFrame.new(0, 0, 0.02) * U.AxisZ, Color3.fromRGB(170, 230, 210), { Reflectance = 0.35 })
		local fc = mcf * CFrame.new(0, 0, -0.04)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.22, 0.07, 0.04), fc * CFrame.new(0.2 * s, 0.12, 0) * CFrame.Angles(0, 0, 0.15 * s), Color3.fromRGB(60, 110, 100))
		end
		block(torso, Vector3.new(0.3, 0.07, 0.04), fc * CFrame.new(0, -0.22, 0), Color3.fromRGB(60, 110, 100))
		spike(torso, mcf * CFrame.new(0, 0.95, 0), 0.4, 0.35, 0.12, c, METAL_MAT) -- crest
		ball(torso, 0.18, mcf * CFrame.new(0, 1.0, -0.06), U.Vivid(look.Beam))
		strap(U.Shade(c, 0.6))
	elseif back == "TankEngine" then
		-- a wearable little tank-engine costume round the middle: boiler and funnel in front, buffer beam,
		-- wheels on the sides and red lining
		local c = backColor
		local black = Color3.fromRGB(35, 35, 40)
		block(torso, Vector3.new(1.55, 0.85, 1.25), CFrame.new(0, -0.22, 0.05), c)
		cyl(torso, 0.85, 0.9, CFrame.new(0, -0.05, -0.95) * U.AxisZ, c) -- boiler
		cyl(torso, 0.08, 0.92, CFrame.new(0, -0.05, -1.4) * U.AxisZ, U.Shade(c, 0.4)) -- smokebox door
		cyl(torso, 0.55, 0.3, CFrame.new(0, 0.62, -1.15) * U.AxisY, black) -- funnel
		cyl(torso, 0.1, 0.42, CFrame.new(0, 0.9, -1.15) * U.AxisY, black)
		ball(torso, 0.36, CFrame.new(0, 0.42, -0.8), c) -- dome
		block(torso, Vector3.new(1.45, 0.24, 0.12), CFrame.new(0, -0.48, -1.42), RED) -- buffer beam
		for _, s in { -1, 1 } do
			cyl(torso, 0.18, 0.18, CFrame.new(0.5 * s, -0.48, -1.55) * U.AxisZ, black) -- buffers
			block(torso, Vector3.new(0.04, 0.08, 1.27), CFrame.new(0.79 * s, -0.55, 0.05), RED) -- lining
			for _, z in { -0.3, 0.35 } do
				cyl(torso, 0.12, 0.58, CFrame.new(0.82 * s, -0.68, z), black) -- wheels
			end
		end
	elseif back == "TrenchCoat" then
		-- long dark coat: tails down to the ankles at the back and sides, raised collar, open at the front
		local c = backColor
		block(torso, Vector3.new(1.4, 1.5, 0.1), CFrame.new(0, -1.05, 0.5) * CFrame.Angles(-0.12, 0, 0), c)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.1, 1.45, 0.85), CFrame.new(0.72 * s, -1.0, 0.08) * CFrame.Angles(0, 0, 0.1 * s), c)
			wedge(torso, Vector3.new(0.05, 0.5, 0.25), CFrame.new(0.3 * s, 0.25, -0.45) * CFrame.Angles(0, 0, 0.3 * s), U.Shade(c, 1.6)) -- lapels
		end
		block(torso, Vector3.new(1.4, 0.4, 0.12), CFrame.new(0, 0.62, 0.38) * CFrame.Angles(0.25, 0, 0), c) -- collar
	elseif back == "SpaceWings" then
		-- pop-out space-ranger wings with red tips and a green stripe on a little thruster pack
		local c = backColor
		block(torso, Vector3.new(0.85, 0.85, 0.32), CFrame.new(0, 0.05, 0.58), WHITE)
		block(torso, Vector3.new(0.5, 0.15, 0.06), CFrame.new(0, 0.2, 0.76), c)
		for _, s in { -1, 1 } do
			local wcf = CFrame.new(1.05 * s, 0.35, 0.6) * CFrame.Angles(0, 0, 0.35 * s)
			block(torso, Vector3.new(1.4, 0.12, 0.6), wcf, WHITE)
			block(torso, Vector3.new(1.0, 0.13, 0.14), wcf * CFrame.new(-0.1 * s, 0, 0.0), c) -- stripe
			wedge(torso, Vector3.new(0.12, 0.6, 0.45), wcf * CFrame.new(0.88 * s, 0, 0) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), RED) -- tip
		end
	elseif back == "TimeBox" then
		-- a little blue time-travel box on the back: panelled sides, stacked roof and a lamp on top
		local c = backColor
		local bc = CFrame.new(0.55, 0.75, 1.0) * CFrame.Angles(0, 0.2, -0.12)
		block(torso, Vector3.new(0.95, 1.7, 0.95), bc, c)
		for _, f in { CFrame.new(0, 0, 0.48), CFrame.new(0.48, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) } do
			block(torso, Vector3.new(0.8, 0.14, 0.03), bc * f * CFrame.new(0, 0.7, 0.01), Color3.fromRGB(25, 30, 50)) -- sign band
			for _, x in { -0.18, 0.18 } do
				block(torso, Vector3.new(0.26, 0.24, 0.03), bc * f * CFrame.new(x, 0.38, 0.01), Color3.fromRGB(230, 240, 255)) -- windows
				block(torso, Vector3.new(0.26, 0.3, 0.03), bc * f * CFrame.new(x, -0.25, 0.01), U.Shade(c, 0.8)) -- panels
			end
		end
		block(torso, Vector3.new(1.05, 0.1, 1.05), bc * CFrame.new(0, 0.9, 0), U.Shade(c, 0.85))
		block(torso, Vector3.new(0.75, 0.1, 0.75), bc * CFrame.new(0, 1.0, 0), U.Shade(c, 0.85))
		cyl(torso, 0.22, 0.22, bc * CFrame.new(0, 1.15, 0) * U.AxisY, Color3.fromRGB(235, 245, 255), { Transparency = 0.2 })
		ball(torso, 0.14, bc * CFrame.new(0, 1.15, 0), Color3.fromRGB(255, 250, 220), NEON) -- lamp
		strap(Color3.fromRGB(60, 50, 45))
	-- WATERPARK/STADIUM (world2c)
	elseif back == "DuckFloat" then
		-- striped inflatable duck swim ring round the waist (duck head at the front) and puffy arm floaties
		local c = backColor
		local y = -0.62
		for i = 0, 11 do
			local a = i * math.pi * 2 / 12
			ball(torso, 0.56, CFrame.new(math.sin(a) * 0.98, y, -math.cos(a) * 0.84), if i % 2 == 0 then c else WHITE)
		end
		ball(torso, 0.48, CFrame.new(0, y + 0.32, -1.0), c) -- neck
		ball(torso, 0.66, CFrame.new(0, y + 0.74, -1.04), c) -- head
		block(torso, Vector3.new(0.34, 0.14, 0.34), CFrame.new(0, y + 0.66, -1.42), Color3.fromRGB(255, 140, 40)) -- beak
		for _, s in { -1, 1 } do
			ball(torso, 0.14, CFrame.new(0.18 * s, y + 0.86, -1.3), EYE)
			cyl(arms[s], 0.32, 0.68, CFrame.new(0, 0.12, 0) * U.AxisY, Color3.fromRGB(255, 140, 40)) -- floaties
		end
	elseif back == "MerTail" then
		-- mermaid: a scaly tail sweeping out from behind round her right side and curling up into a big fluke
		local c = backColor
		local light = U.Mix(c, WHITE, 0.35)
		local pts = { Vector3.new(0, -0.6, 0.4), Vector3.new(0.55, -1.05, 0.7), Vector3.new(1.15, -1.13, 0.6), Vector3.new(1.55, -0.85, 0.35), Vector3.new(1.7, -0.38, 0.2) }
		for i, p in pts do
			ball(torso, 0.8 - i * 0.07, CFrame.new(p), if i % 2 == 0 then light else c)
			if i < 3 then
				ball(torso, 0.76 - i * 0.07, CFrame.new(p:Lerp(pts[i + 1], 0.5)), if i % 2 == 0 then c else light)
			end
		end
		local fp = Vector3.new(1.68, 0.02, 0.15)
		local fc = CFrame.lookAt(fp, fp + Vector3.new(0.57, 0, -0.82)) * CFrame.Angles(0, 0, -0.15)
		for _, s in { -1, 1 } do
			spike(torso, fc * CFrame.Angles(0, 0, -0.75 * s), 0.62, 1.0, 0.08, if s < 0 then c else light) -- fluke
		end
	elseif back == "Jellyfish" then
		-- a pink jellyfish floating over his shoulder on a string, like a balloon (jellyfishing!)
		local c = backColor
		local light = U.Mix(c, WHITE, 0.45)
		local jc = Vector3.new(-1.45, 2.8, 0.35)
		ball(torso, 1.15, CFrame.new(jc), c, { Transparency = 0.25 })
		ball(torso, 0.6, CFrame.new(jc + Vector3.new(0, 0.05, 0)), light)
		cyl(torso, 0.1, 1.2, CFrame.new(jc - Vector3.new(0, 0.18, 0)) * U.AxisY, U.Shade(c, 0.85)) -- rim
		for i, x in { -0.32, -0.11, 0.11, 0.32 } do
			local z = if i % 2 == 0 then 0.12 else -0.12
			local p0 = jc + Vector3.new(x, -0.2, z)
			local p1 = p0 + Vector3.new(0.1, -0.5, 0)
			rod(torso, p0, p1, 0.07, light)
			rod(torso, p1, p1 + Vector3.new(-0.12, -0.45, 0), 0.06, light) -- tentacles
		end
		rod(torso, Vector3.new(-0.55, 0.5, 0.2), jc - Vector3.new(0, 0.55, 0), 0.03, Color3.fromRGB(60, 60, 70)) -- string
	elseif back == "SeaTurtle" then
		-- sea turtle: a big low shell dome of stacked discs (darker plates, cream rim showing round the sides),
		-- a cream belly plate on the front and a stubby tail
		local c = backColor
		local plate = U.Shade(c, 0.7)
		local cream = Color3.fromRGB(235, 215, 145)
		local sc = CFrame.new(0, -0.05, 0.45)
		cyl(torso, 0.16, 2.3, sc * U.AxisZ, cream) -- rim
		cyl(torso, 0.3, 2.1, sc * CFrame.new(0, 0, 0.2) * U.AxisZ, c)
		cyl(torso, 0.26, 1.55, sc * CFrame.new(0, 0, 0.45) * U.AxisZ, c)
		cyl(torso, 0.2, 0.95, sc * CFrame.new(0, 0, 0.65) * U.AxisZ, c)
		cyl(torso, 0.04, 0.55, sc * CFrame.new(0, 0, 0.76) * U.AxisZ, plate)
		for i = 0, 5 do
			local a = i * math.pi / 3
			cyl(torso, 0.04, 0.38, sc * CFrame.new(math.sin(a) * 0.6, math.cos(a) * 0.6, 0.59) * U.AxisZ, plate)
		end
		block(torso, Vector3.new(0.95, 0.98, 0.06), CFrame.new(0, -0.02, -0.43), cream) -- belly plate
		for _, y in { 0.18, -0.2 } do
			block(torso, Vector3.new(0.95, 0.05, 0.07), CFrame.new(0, y, -0.44), U.Shade(cream, 0.75))
		end
		block(torso, Vector3.new(0.05, 0.98, 0.07), CFrame.new(0, -0.02, -0.44), U.Shade(cream, 0.75))
		wedge(torso, Vector3.new(0.2, 0.3, 0.3), CFrame.new(0, -0.72, 0.55) * CFrame.Angles(math.pi, 0, 0), look.Skin) -- tail
	elseif back == "CanoeSail" then
		-- voyager: a crab-claw canoe sail on a mast rising behind, a flower lei and a glowing spiral-shell pendant
		local c = backColor
		local wood = Color3.fromRGB(140, 95, 60)
		local ap = Vector3.new(-1.05, -0.75, 0.55)
		local apex = CFrame.lookAt(ap, ap + Vector3.new(0.45, 0, -0.9)) * CFrame.Angles(0, 0, 0.12) -- sail faces the front three-quarter view
		local band = Color3.fromRGB(190, 75, 50)
		rod(torso, (apex * CFrame.new(0, -0.3, 0.05)).Position, (apex * CFrame.new(0, 3.3, 0.05)).Position, 0.12, wood) -- mast
		for _, s in { -1, 1 } do
			local half = apex * CFrame.Angles(0, 0, 0.26 * s)
			spike(torso, half * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.pi), 1.6, 3.4, 0.06, c) -- sail
			block(torso, Vector3.new(1.1, 0.18, 0.07), half * CFrame.new(0, 2.8, 0), band) -- woven stripe
			rod(torso, apex.Position, (half * CFrame.new(-0.85 * s, 3.55, 0)).Position, 0.07, wood) -- spar
		end
		local lei = { Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 220, 90), WHITE }
		for i = 0, 8 do
			local a = -2.2 + i * 4.4 / 8
			ball(torso, 0.26, CFrame.new(math.sin(a) * 0.5, 0.48 - 0.16 * math.cos(a), -math.cos(a) * 0.38), lei[i % 3 + 1])
		end
		cyl(torso, 0.06, 0.3, CFrame.new(0, 0.12, -0.45) * U.AxisZ, Color3.fromRGB(240, 230, 210)) -- pendant
		ball(torso, 0.16, CFrame.new(0, 0.12, -0.48), look.Beam, NEON)
	elseif back == "SeaSerpent" then
		-- a friendly sea serpent coiling up behind her, its head over her right shoulder, gold horns and crest
		local c = backColor
		local dark = U.Shade(c, 0.78)
		local P = {
			Vector3.new(-1.0, -1.15, 0.75), Vector3.new(-1.5, -0.6, 1.05), Vector3.new(-1.55, 0.2, 1.3), Vector3.new(-1.0, 0.95, 1.5),
			Vector3.new(0, 1.4, 1.6), Vector3.new(1.0, 1.85, 1.4), Vector3.new(1.55, 2.6, 0.95), Vector3.new(1.45, 3.3, 0.35),
		}
		local k = 0
		for i = 1, #P - 1 do
			for j = 0, 1 do
				if i == 1 and j == 1 then
					continue
				end
				k += 1
				local p = P[i]:Lerp(P[i + 1], j * 0.5)
				ball(torso, 0.7 + 0.32 * math.sin(k / 12 * math.pi), CFrame.new(p), if k % 2 == 0 then dark else c)
			end
		end
		for _, i in { 4, 6 } do
			local p = P[i]:Lerp(P[i + 1], 0.5)
			spike(torso, CFrame.new(p + Vector3.new(0, 0.38, 0.1)) * CFrame.Angles(0, -0.5, 0), 0.4, 0.42, 0.08, GOLD) -- crest
		end
		local hcf = CFrame.lookAt(P[8], P[8] + Vector3.new(-0.25, -0.1, -1)) * CFrame.new(0, 0.1, -0.2)
		ball(torso, 0.95, hcf, c) -- head
		block(torso, Vector3.new(0.6, 0.42, 0.75), hcf * CFrame.new(0, -0.12, -0.55), c) -- snout
		for _, s in { -1, 1 } do
			ball(torso, 0.3, hcf * CFrame.new(0.3 * s, 0.2, -0.28), WHITE)
			ball(torso, 0.15, hcf * CFrame.new(0.33 * s, 0.22, -0.41), EYE)
			spike(torso, hcf * CFrame.new(0.25 * s, 0.38, 0.12) * CFrame.Angles(-0.9, 0, -0.35 * s), 0.18, 0.55, 0.12, GOLD) -- horns
		end
	elseif back == "BoxerRobe" then
		-- boxer's satin robe worn open over a grey sweatshirt: gold-trimmed lapels, belt, towel round the neck,
		-- hood down at the back, and the second boxing glove on the left hand
		local robe = look.Shirt
		local trim = Color3.fromRGB(255, 210, 90)
		local glove = look.ToolColor
		block(torso, Vector3.new(0.5, 1.0, 0.06), CFrame.new(0, -0.02, -0.42), backColor) -- sweatshirt showing at the front
		for _, s in { -1, 1 } do
			bar(torso, Vector3.new(0.17 * s, 0.53, -0.45), Vector3.new(0.28 * s, -0.52, -0.45), 0.13, 0.07, trim) -- lapels
			bar(torso, Vector3.new(0.38 * s, 0.56, 0.12), Vector3.new(0.3 * s, -0.05, -0.49), 0.28, 0.09, WHITE) -- towel ends
		end
		cyl(torso, 0.22, 1.0, CFrame.new(0, 0.56, 0.08) * U.AxisY, WHITE) -- towel round the neck
		block(torso, Vector3.new(1.36, 0.16, 0.9), CFrame.new(0, -0.3, 0), U.Shade(robe, 0.75)) -- belt
		ball(torso, 0.72, CFrame.new(0, 0.42, 0.5), robe) -- hood down
		block(torso, Vector3.new(1.4, 0.62, 0.1), CFrame.new(0, -0.78, 0.46) * CFrame.Angles(-0.12, 0, 0), robe) -- robe skirt (back)
		for _, s in { -1, 1 } do
			block(torso, Vector3.new(0.12, 0.62, 0.92), CFrame.new(0.7 * s, -0.78, 0) * CFrame.Angles(0, 0, 0.1 * s), robe) -- (sides)
			block(torso, Vector3.new(0.34, 0.62, 0.1), CFrame.new(0.52 * s, -0.78, -0.46) * CFrame.Angles(0.12, 0, 0.1 * s), robe) -- (front)
			block(torso, Vector3.new(0.06, 0.62, 0.11), CFrame.new(0.36 * s, -0.78, -0.47) * CFrame.Angles(0.12, 0, 0.1 * s), trim)
		end
		local la = arms[-1]
		ball(la, 0.9, CFrame.new(0, -0.52, -0.05), glove) -- left glove
		ball(la, 0.36, CFrame.new(0.36, -0.42, -0.15), U.Shade(glove, 0.9)) -- thumb
		cyl(la, 0.36, 0.6, CFrame.new(0, -0.1, 0) * U.AxisY, WHITE) -- cuff
	elseif back == "FanDrum" then
		-- super-fan kit: striped team scarf with hanging ends, a big team drum strapped on the front, a drumstick
		local c = backColor
		local alt = look.HatColor or look.Shirt
		cyl(torso, 0.24, 1.12, CFrame.new(0, 0.56, 0) * U.AxisY, c) -- scarf round the neck
		for k = 0, 2 do
			block(torso, Vector3.new(0.3, 0.26, 0.08), CFrame.new(-0.3, 0.32 - k * 0.26, -0.47) * CFrame.Angles(0, 0, 0.08), if k % 2 == 0 then c else alt) -- scarf end
		end
		block(torso, Vector3.new(0.34, 0.08, 0.1), CFrame.new(-0.32, -0.15, -0.48) * CFrame.Angles(0, 0, 0.08), WHITE) -- fringe
		local dc = CFrame.new(0, -0.62, -0.95)
		cyl(torso, 0.7, 1.05, dc, alt) -- drum shell
		cyl(torso, 0.74, 0.96, dc, WHITE) -- drum heads
		for _, s in { -1, 1 } do
			cyl(torso, 0.08, 1.12, dc * CFrame.new(0.36 * s, 0, 0), c) -- rims
			bar(torso, Vector3.new(0.4 * s, 0.52, -0.43), Vector3.new(0.25 * s, -0.12, -0.78), 0.1, 0.05, Color3.fromRGB(45, 45, 55)) -- straps
		end
		rod(arms[-1], Vector3.new(0, -0.42, 0.1), Vector3.new(0.12, -0.55, -0.85), 0.07, Color3.fromRGB(230, 205, 160)) -- drumstick
		ball(arms[-1], 0.2, CFrame.new(0.12, -0.56, -0.9), WHITE)
	end

	------------------------------------------------------------------ tool (right hand)
	local grip = rArm.CFrame * GRIP
	local tool = look.Tool
	local tc = look.ToolColor
	local beam = look.Beam
	local function tpart(p: BasePart): BasePart
		return add(rArm, p)
	end
	local function T(x: number, y: number, z: number): CFrame
		return grip * CFrame.new(x, y, z)
	end
	local muzzle: BasePart
	local tipWorld: CFrame
	if tool == "Vacuum" then
		local body = tpart(U.Block(Vector3.new(0.55, 0.6, 1.1), T(0, 0.1, -0.25), tc, model))
		tpart(U.Cyl(0.9, 0.42, T(0, 0.05, -1.2) * U.AxisZ, METAL, model, { Material = Enum.Material.Metal }))
		muzzle = tpart(U.Cyl(0.18, 0.64, T(0, 0.05, -1.7) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0.05, -1.82)
		-- hose: a Beam from the back of the vacuum to the hip (follows the animation for free)
		local a0 = U.AttachAt(body, "HoseA", T(0, 0.0, 0.3) * CFrame.Angles(0, 0, -math.pi / 2))
		local a1 = U.AttachAt(torso, "HoseB", torso.CFrame * CFrame.new(0.5, -0.35, if back then 0.6 else 0.3))
		local hose = Instance.new("Beam")
		hose.Name = "Hose"
		hose.Attachment0 = a0
		hose.Attachment1 = a1
		hose.Color = ColorSequence.new(U.Shade(tc, 0.55))
		hose.Width0 = 0.22
		hose.Width1 = 0.26
		hose.FaceCamera = true
		hose.Segments = 12
		hose.CurveSize0 = 0.9
		hose.CurveSize1 = 0
		hose.LightInfluence = 1
		hose.Transparency = NumberSequence.new(0)
		hose.Parent = body
	elseif tool == "Scanner" then
		tpart(U.Block(Vector3.new(0.8, 0.45, 1.2), T(0, 0.1, -0.35), U.Shade(tc, 0.45), model))
		tpart(U.Block(Vector3.new(0.6, 0.06, 0.7), T(0, 0.35, -0.35), U.Vivid(tc), model, { Reflectance = 0.2 })) -- screen
		muzzle = tpart(U.Ball(0.32, T(0, 0.15, -1.0), tc, model, NEON))
		tipWorld = T(0, 0.15, -1.05)
	elseif tool == "Blaster" then
		tpart(U.Block(Vector3.new(0.5, 0.62, 1.05), T(0, 0.12, -0.3), tc, model))
		tpart(U.Cyl(0.8, 0.36, T(0, 0.22, -1.1) * U.AxisZ, METAL, model, { Material = Enum.Material.Metal }))
		muzzle = tpart(U.Cyl(0.16, 0.5, T(0, 0.22, -1.5) * U.AxisZ, beam, model, NEON))
		tpart(U.Wedge(Vector3.new(0.12, 0.3, 0.5), T(0, 0.58, -0.2), U.Shade(tc, 0.7), model))
		tipWorld = T(0, 0.22, -1.6)
	elseif tool == "Cannon" then
		tpart(U.Cyl(2.2, 0.95, T(0.15, 0.45, -0.55) * U.AxisZ, tc, model))
		tpart(U.Ball(1.1, T(0.15, 0.45, 0.45), U.Shade(tc, 0.6), model))
		tpart(U.Cyl(0.18, 1.02, T(0.15, 0.45, -0.4) * U.AxisZ, U.Vivid(beam), model)) -- ring
		muzzle = tpart(U.Cyl(0.3, 1.18, T(0.15, 0.45, -1.65) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0.15, 0.45, -1.85)
	elseif tool == "Lantern" then
		tpart(U.Cyl(0.18, 0.6, T(0, 0.05, -0.5) * U.AxisY, METAL, model, { Material = Enum.Material.Metal }))
		tpart(U.Block(Vector3.new(0.55, 0.65, 0.55), T(0, -0.3, -0.5), tc, model, { Transparency = 0.4 }))
		muzzle = tpart(U.Ball(0.38, T(0, -0.3, -0.5), beam, model, NEON))
		tipWorld = T(0, -0.3, -0.5)
		-- no PointLight: a light on every moving crew flickers (the neon flame is enough)
	elseif tool == "Staff" then
		local up = CFrame.Angles(0.05, 0, -0.5) -- pole leans out to the side so its top clears the face in portraits
		tpart(U.Cyl(3.0, 0.18, grip * up * CFrame.new(0, 0.55, 0) * U.AxisY, U.Shade(tc, 0.5), model))
		tpart(U.Cyl(0.16, 0.62, grip * up * CFrame.new(0, 2.0, 0) * U.AxisY, tc, model))
		muzzle = tpart(U.Ball(0.62, grip * up * CFrame.new(0, 2.3, 0), beam, model, NEON))
		tipWorld = grip * up * CFrame.new(0, 2.3, 0)
	elseif tool == "Projector" then
		tpart(U.Block(Vector3.new(0.75, 0.7, 1.0), T(0, 0.15, -0.35), tc, model))
		muzzle = tpart(U.Cyl(0.25, 0.55, T(0, 0.15, -0.95) * U.AxisZ, beam, model, NEON))
		tpart(U.Cyl(0.12, 0.65, T(0, 0.75, -0.1), U.Shade(tc, 0.45), model))
		tpart(U.Cyl(0.12, 0.65, T(0, 0.75, -0.65), U.Shade(tc, 0.45), model))
		tipWorld = T(0, 0.15, -1.1)
	elseif tool == "Megaphone" then
		tpart(U.Block(Vector3.new(0.2, 0.42, 0.26), T(0, -0.05, -0.15), U.Shade(tc, 0.5), model)) -- grip
		tpart(U.Cyl(0.55, 0.36, T(0, 0.22, -0.35) * U.AxisZ, tc, model))
		tpart(U.Cyl(0.35, 0.58, T(0, 0.22, -0.78) * U.AxisZ, WHITE, model))
		tpart(U.Cyl(0.3, 0.82, T(0, 0.22, -1.08) * U.AxisZ, tc, model)) -- bell
		muzzle = tpart(U.Cyl(0.06, 0.74, T(0, 0.22, -1.24) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0.22, -1.3)
	elseif tool == "Wand" then
		tpart(U.Cyl(1.15, 0.13, T(0, 0.05, -0.55) * U.AxisZ, tc, model))
		tpart(U.Cyl(0.22, 0.15, T(0, 0.05, -1.05) * U.AxisZ, WHITE, model)) -- tip cap
		muzzle = tpart(U.Block(Vector3.new(0.24, 0.24, 0.24), T(0, 0.05, -1.28) * U.VertexUp, beam, model, NEON)) -- sparkle
		tipWorld = T(0, 0.05, -1.32)
	elseif tool == "Orb" then
		tpart(U.Cyl(0.2, 0.55, T(0, 0.15, -0.45) * U.AxisY, tc, model, METAL_MAT)) -- stand
		tpart(U.Ball(0.82, T(0, 0.55, -0.45), U.Vivid(beam), model, { Transparency = 0.45, Reflectance = 0.2, Shadow = false })) -- glass
		muzzle = tpart(U.Ball(0.42, T(0, 0.55, -0.45), beam, model, NEON))
		tipWorld = T(0, 0.55, -0.86)
	elseif tool == "Spyglass" then
		tpart(U.Cyl(0.4, 0.24, T(0, 0.08, 0.05) * U.AxisZ, U.Shade(tc, 0.6), model, METAL_MAT)) -- eyepiece
		tpart(U.Cyl(0.5, 0.3, T(0, 0.08, -0.38) * U.AxisZ, tc, model, METAL_MAT))
		tpart(U.Cyl(0.7, 0.38, T(0, 0.08, -0.95) * U.AxisZ, Color3.fromRGB(95, 62, 40), model)) -- leather tube
		tpart(U.Cyl(0.1, 0.46, T(0, 0.08, -1.3) * U.AxisZ, tc, model, METAL_MAT)) -- rim
		muzzle = tpart(U.Cyl(0.04, 0.34, T(0, 0.08, -1.36) * U.AxisZ, beam, model, NEON)) -- lens
		tipWorld = T(0, 0.08, -1.4)
	elseif tool == "Sword" then
		local hilt = Color3.fromRGB(90, 60, 45)
		tpart(U.Cyl(0.45, 0.17, T(0, 0, 0.12) * U.AxisZ, hilt, model))
		tpart(U.Ball(0.24, T(0, 0, 0.38), GOLD, model, METAL_MAT)) -- pommel
		tpart(U.Block(Vector3.new(0.85, 0.14, 0.16), T(0, 0, -0.14), GOLD, model, METAL_MAT)) -- crossguard
		tpart(U.Block(Vector3.new(0.08, 0.3, 1.3), T(0, 0, -0.87), tc, model, METAL_MAT)) -- blade
		tpart(U.Wedge(Vector3.new(0.08, 0.15, 0.35), T(0, 0.075, -1.695), tc, model, METAL_MAT)) -- point (upper half)
		tpart(U.Wedge(Vector3.new(0.08, 0.15, 0.35), T(0, -0.075, -1.695) * CFrame.Angles(0, 0, math.pi), tc, model, METAL_MAT))
		muzzle = tpart(U.Block(Vector3.new(0.1, 0.07, 1.1), T(0, 0, -0.85), beam, model, NEON)) -- glowing fuller
		tipWorld = T(0, 0, -1.85)
	elseif tool == "Trident" then
		local metalOpts = { Material = Enum.Material.Metal }
		tpart(U.Cyl(2.4, 0.16, T(0, 0.05, -0.55) * U.AxisZ, U.Shade(tc, 0.7), model, metalOpts)) -- shaft
		tpart(U.Ball(0.22, T(0, 0.05, 0.66), tc, model, metalOpts)) -- butt cap
		tpart(U.Block(Vector3.new(0.9, 0.14, 0.14), T(0, 0.05, -1.8), tc, model, metalOpts)) -- crossbar
		for _, t in { { x = 0, len = 0.8, w = 0.16 }, { x = -0.4, len = 0.5, w = 0.12 }, { x = 0.4, len = 0.5, w = 0.12 } } do
			local zEnd = -1.8 - t.len
			tpart(U.Block(Vector3.new(t.w, t.w, t.len), T(t.x, 0.05, -1.8 - t.len / 2), tc, model, metalOpts))
			tpart(U.Wedge(Vector3.new(t.w, t.w * 0.75, 0.28), T(t.x, 0.05 + t.w * 0.375, zEnd - 0.14), tc, model, metalOpts)) -- barbed point
			tpart(U.Wedge(Vector3.new(t.w, t.w * 0.75, 0.28), T(t.x, 0.05 - t.w * 0.375, zEnd - 0.14) * CFrame.Angles(0, 0, math.pi), tc, model, metalOpts))
		end
		muzzle = tpart(U.Ball(0.3, T(0, 0.05, -1.8), beam, model, NEON)) -- gem where the tines meet
		tipWorld = T(0, 0.05, -2.9)
	elseif tool == "Wrench" then
		local metalOpts = { Material = Enum.Material.Metal }
		tpart(U.Block(Vector3.new(0.14, 0.24, 1.3), T(0, 0.05, -0.45), tc, model, metalOpts)) -- handle
		tpart(U.Block(Vector3.new(0.2, 0.3, 0.55), T(0, 0.05, 0.05), RED, model)) -- rubber grip
		tpart(U.Block(Vector3.new(0.18, 0.75, 0.26), T(0, 0.05, -1.2), tc, model, metalOpts)) -- jaw base
		for _, y in { -0.26, 0.26 } do
			tpart(U.Block(Vector3.new(0.18, 0.22, 0.45), T(0, 0.05 + y, -1.52), tc, model, metalOpts)) -- jaw prongs
		end
		tpart(U.Cyl(0.2, 0.16, T(0, 0.05, -1.02) * U.AxisZ, U.Shade(tc, 0.6), model, metalOpts)) -- adjusting screw
		muzzle = tpart(U.Ball(0.24, T(0, 0.05, -1.48), beam, model, NEON)) -- glow between the jaws
		tipWorld = T(0, 0.05, -1.65)
	elseif tool == "HeartWand" then
		-- pale wand with a heart on top (heart faces sideways, points back down the shaft)
		tpart(U.Cyl(1.15, 0.13, T(0, 0.05, -0.55) * U.AxisZ, U.Mix(tc, WHITE, 0.6), model))
		local hf = T(0, 0.05, -1.4) * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y = forward along the wand
		local a = 0.4
		local k = a / (2 * math.sqrt(2))
		tpart(U.Block(Vector3.new(0.08, a, a), hf * CFrame.Angles(math.pi / 4, 0, 0), tc, model))
		for _, z in { -k, k } do
			tpart(U.Cyl(0.08, a, hf * CFrame.new(0, k, z), tc, model)) -- lobes
		end
		muzzle = tpart(U.Ball(0.17, hf * CFrame.new(0, 0.04, 0), beam, model, NEON)) -- heart gem
		tipWorld = T(0, 0.05, -1.78)
	elseif tool == "MoonStaff" then
		-- tall staff topped by an upturned crescent cradling a glowing orb
		local up = CFrame.Angles(0.05, 0, -0.5)
		local sf = grip * up
		tpart(U.Cyl(3.0, 0.18, sf * CFrame.new(0, 0.55, 0) * U.AxisY, U.Shade(tc, 0.5), model))
		tpart(U.Cyl(0.16, 0.4, sf * CFrame.new(0, 1.95, 0) * U.AxisY, GOLD, model, METAL_MAT)) -- collar
		local mc = sf * CFrame.new(0, 2.5, 0)
		for i = 0, 4 do
			local phi = math.rad(-160 + i * 35)
			local w = 0.22 - math.abs(i - 2) * 0.05
			tpart(U.Block(Vector3.new(w, 0.34, 0.12), mc * CFrame.Angles(0, 0, phi) * CFrame.new(0.5, 0, 0), tc, model)) -- crescent
		end
		muzzle = tpart(U.Ball(0.42, mc, beam, model, NEON))
		tipWorld = mc
	elseif tool == "PumpkinLance" then
		-- striped jousting lance with a pumpkin hand guard
		local orange = Color3.fromRGB(255, 140, 40)
		tpart(U.Cyl(0.6, 0.2, T(0, 0.05, 0.15) * U.AxisZ, Color3.fromRGB(95, 62, 40), model)) -- handle
		tpart(U.Ball(0.8, T(0, 0.05, -0.42), orange, model))
		tpart(U.Cyl(0.06, 0.84, T(0, 0.05, -0.42), U.Shade(orange, 0.8), model)) -- rib
		tpart(U.Cyl(0.18, 0.12, T(0, 0.5, -0.42) * U.AxisY, Color3.fromRGB(90, 140, 60), model)) -- stem
		local base = rArm.CFrame:ToObjectSpace(T(0, 0.05, -0.75) * CFrame.Angles(-math.pi / 2, 0, 0))
		local tipCf = cone(rArm, base, 0.46, 1.7, 4, tc, U.Mix(tc, WHITE, 0.55))
		muzzle = tpart(U.Ball(0.2, rArm.CFrame * tipCf, beam, model, NEON))
		tipWorld = T(0, 0.05, -2.5)
	elseif tool == "FryingPan" then
		-- frying pan with a glowing fried egg in it
		tpart(U.Block(Vector3.new(0.16, 0.12, 0.85), T(0, 0.05, -0.3), U.Shade(tc, 0.6), model)) -- handle
		tpart(U.Block(Vector3.new(0.2, 0.16, 0.4), T(0, 0.05, 0.02), Color3.fromRGB(95, 62, 40), model)) -- grip
		local pan = T(0, 0.05, -1.25)
		tpart(U.Cyl(0.18, 1.2, pan * U.AxisY, tc, model, METAL_MAT))
		tpart(U.Cyl(0.02, 1.02, pan * CFrame.new(0, 0.09, 0) * U.AxisY, U.Shade(tc, 0.75), model))
		tpart(U.Cyl(0.04, 0.55, pan * CFrame.new(0.05, 0.11, 0.05) * U.AxisY, WHITE, model)) -- egg white
		muzzle = tpart(U.Ball(0.3, pan * CFrame.new(0.05, 0.15, 0.05), beam, model, NEON)) -- yolk
		tipWorld = pan * CFrame.new(0, 0.2, -0.35)
	elseif tool == "SteamBasket" then
		-- stacked bamboo steamer with a lid and a puff of steam
		local bc = T(0, 0.15, -0.6)
		for i = 0, 1 do
			tpart(U.Cyl(0.3, 0.9, bc * CFrame.new(0, i * 0.32, 0) * U.AxisY, tc, model))
			tpart(U.Cyl(0.06, 0.94, bc * CFrame.new(0, i * 0.32 - 0.1, 0) * U.AxisY, U.Shade(tc, 0.7), model)) -- band
		end
		tpart(U.Cyl(0.14, 0.94, bc * CFrame.new(0, 0.53, 0) * U.AxisY, U.Shade(tc, 0.85), model)) -- lid
		tpart(U.Ball(0.18, bc * CFrame.new(0, 0.63, 0), U.Shade(tc, 0.6), model)) -- knob
		muzzle = tpart(U.Ball(0.32, bc * CFrame.new(0.05, 0.92, 0), beam, model, NEON)) -- steam
		tipWorld = bc * CFrame.new(0.05, 0.95, 0)
	elseif tool == "Spellbook" then
		-- open book held flat with a glowing rune floating over the pages
		local bk = T(0, 0.2, -0.65)
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.55, 0.06, 0.75), bk * CFrame.new(0.27 * s, 0, 0) * CFrame.Angles(0, 0, 0.12 * s), tc, model))
		end
		tpart(U.Block(Vector3.new(0.98, 0.1, 0.68), bk * CFrame.new(0, 0.07, 0), CREAM, model)) -- pages
		tpart(U.Block(Vector3.new(0.06, 0.4, 0.02), bk * CFrame.new(0.1, -0.15, -0.3), RED, model)) -- bookmark
		muzzle = tpart(U.Block(Vector3.new(0.24, 0.24, 0.24), bk * CFrame.new(0, 0.5, 0) * U.VertexUp, beam, model, NEON))
		tipWorld = bk * CFrame.new(0, 0.5, -0.1)
	elseif tool == "Quill" then
		-- giant feather pen held a little outside the arm: vane behind the hand, nib in front with glowing ink
		local shaft = Color3.fromRGB(240, 235, 220)
		local function Q(y: number, z: number): CFrame
			return T(0.3, y, z)
		end
		tpart(U.Cyl(2.1, 0.08, Q(0.05, -0.15) * U.AxisZ, shaft, model))
		tpart(U.Wedge(Vector3.new(0.05, 0.42, 1.5), Q(0.26, 0.35) * CFrame.Angles(0, math.pi, 0), tc, model)) -- vane
		tpart(U.Wedge(Vector3.new(0.05, 0.3, 1.3), Q(-0.1, 0.3) * CFrame.Angles(math.pi, 0, 0), U.Shade(tc, 0.9), model))
		tpart(U.Wedge(Vector3.new(0.05, 0.3, 0.35), Q(0.2, -0.57), tc, model)) -- vane front taper
		tpart(U.Wedge(Vector3.new(0.1, 0.1, 0.3), Q(0.1, -1.3), METAL, model, METAL_MAT)) -- nib
		tpart(U.Wedge(Vector3.new(0.1, 0.1, 0.3), Q(0.0, -1.3) * CFrame.Angles(0, 0, math.pi), METAL, model, METAL_MAT))
		muzzle = tpart(U.Ball(0.2, Q(0.05, -1.5), beam, model, NEON)) -- ink
		tipWorld = Q(0.05, -1.55)
	elseif tool == "Umbrella" then
		-- open umbrella held up and leaning out: hook handle, rod, striped stepped canopy
		local sf = grip * CFrame.Angles(0.15, 0, -0.62)
		local alt = U.Mix(tc, WHITE, 0.6)
		tpart(U.Cyl(0.12, 0.3, sf * CFrame.new(0, -0.25, 0.1) * U.AxisZ, Color3.fromRGB(95, 62, 40), model)) -- hook
		tpart(U.Cyl(2.6, 0.1, sf * CFrame.new(0, 1.1, 0) * U.AxisY, METAL, model, METAL_MAT)) -- rod
		local tipCf = cone(rArm, rArm.CFrame:ToObjectSpace(sf * CFrame.new(0, 2.0, 0)), 2.1, 0.62, 4, tc, alt)
		muzzle = tpart(U.Ball(0.16, rArm.CFrame * tipCf * CFrame.new(0, 0.12, 0), beam, model, NEON))
		tipWorld = rArm.CFrame * tipCf * CFrame.new(0, 0.12, 0)
	elseif tool == "Magnet" then
		-- horseshoe magnet: curved back, two arms, silver tips, glow between them
		local mc = T(0, 0.1, -0.5)
		for i, a in { math.pi / 4, math.pi / 2, 3 * math.pi / 4 } do
			local p = Vector3.new(math.cos(a) * 0.32, 0, math.sin(a) * 0.32)
			tpart(U.Block(Vector3.new(if i == 2 then 0.3 else 0.26, 0.24, 0.24), mc * CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), tc, model))
		end
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.24, 0.24, 0.55), mc * CFrame.new(0.32 * s, 0, -0.2), tc, model))
			tpart(U.Block(Vector3.new(0.25, 0.25, 0.2), mc * CFrame.new(0.32 * s, 0, -0.56), Color3.fromRGB(215, 220, 230), model, METAL_MAT))
		end
		muzzle = tpart(U.Ball(0.22, mc * CFrame.new(0, 0, -0.58), beam, model, NEON))
		tipWorld = mc * CFrame.new(0, 0, -0.65)
	elseif tool == "Teapot" then
		-- round teapot: body, lid with knob, curved handle and a spout
		local tcf = T(0, 0.2, -0.6)
		tpart(U.Ball(0.82, tcf, tc, model))
		tpart(U.Cyl(0.1, 0.62, tcf * CFrame.new(0, 0.33, 0) * U.AxisY, U.Shade(tc, 0.85), model)) -- lid
		tpart(U.Ball(0.16, tcf * CFrame.new(0, 0.44, 0), GOLD, model, METAL_MAT))
		tpart(U.Cyl(0.06, 0.84, tcf * CFrame.new(0, -0.02, 0) * U.AxisY, U.Shade(tc, 0.75), model)) -- band
		for _, q in { { 0.15, 0.48, 0.6 }, { -0.1, 0.55, 0 }, { -0.3, 0.45, -0.6 } } do
			tpart(U.Block(Vector3.new(0.08, 0.1, 0.24), tcf * CFrame.new(0, q[1], q[2]) * CFrame.Angles(q[3], 0, 0), tc, model)) -- handle
		end
		local s0, s1 = tcf * CFrame.new(0, -0.05, -0.32), tcf * CFrame.new(0, 0.22, -0.65)
		tpart(U.Cyl((s1.Position - s0.Position).Magnitude, 0.13, U.Between(s0.Position, s1.Position), tc, model)) -- spout
		muzzle = tpart(U.Ball(0.14, s1, beam, model, NEON))
		tipWorld = s1
	elseif tool == "HandMirror" then
		-- round hand mirror in a gold rim, held up facing forward
		local mcf = T(0, 0.72, -0.4)
		tpart(U.Cyl(0.55, 0.12, T(0, 0.18, -0.2) * CFrame.Angles(0.45, 0, 0) * U.AxisY, GOLD, model, METAL_MAT)) -- handle
		tpart(U.Cyl(0.1, 0.86, mcf * U.AxisZ, GOLD, model, METAL_MAT)) -- rim
		muzzle = tpart(U.Cyl(0.04, 0.72, mcf * CFrame.new(0, 0, -0.06) * U.AxisZ, tc, model, { Reflectance = 0.6 }))
		tpart(U.Ball(0.14, mcf * CFrame.new(0, 0.46, 0), beam, model, NEON)) -- gem on top
		tipWorld = mcf * CFrame.new(0, 0, -0.1)
	elseif tool == "Kaleidoscope" then
		-- long striped tube with a ring of coloured prism wedges at the end
		tpart(U.Cyl(1.3, 0.36, T(0, 0.1, -0.55) * U.AxisZ, tc, model))
		for _, z in { -0.2, -0.75 } do
			tpart(U.Cyl(0.1, 0.4, T(0, 0.1, z) * U.AxisZ, GOLD, model, METAL_MAT))
		end
		local pc = T(0, 0.1, -1.24)
		for i = 0, 5 do
			tpart(U.Wedge(Vector3.new(0.08, 0.2, 0.18), pc * CFrame.Angles(0, 0, i * math.pi / 3) * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, math.pi / 2, 0), RAINBOW[i + 1], model))
		end
		muzzle = tpart(U.Ball(0.2, pc * CFrame.new(0, 0, -0.04), beam, model, NEON))
		tipWorld = pc * CFrame.new(0, 0, -0.12)
	elseif tool == "Guitar" then
		-- flat guitar body, neck and head, one glowing string line
		local body = T(0.08, 0.1, 0.05)
		tpart(U.Cyl(0.24, 0.9, body * CFrame.new(0, 0, 0.12), tc, model))
		tpart(U.Cyl(0.24, 0.7, body * CFrame.new(0, 0, -0.42), tc, model))
		tpart(U.Cyl(0.03, 0.26, body * CFrame.new(0.13, 0, -0.18), EYE, model)) -- sound hole
		tpart(U.Block(Vector3.new(0.12, 0.16, 1.0), body * CFrame.new(0, 0, -1.15), Color3.fromRGB(120, 80, 50), model)) -- neck
		tpart(U.Block(Vector3.new(0.14, 0.26, 0.32), body * CFrame.new(0, 0.04, -1.8), U.Shade(tc, 0.6), model)) -- head
		muzzle = tpart(U.Block(Vector3.new(0.03, 0.05, 1.7), body * CFrame.new(0.14, 0, -0.85), beam, model, NEON)) -- string
		tipWorld = body * CFrame.new(0, 0.04, -1.98)
	elseif tool == "Hammer" then
		-- big mallet: wrapped handle, block head with metal bands and a glowing rune on the front
		tpart(U.Cyl(1.25, 0.16, T(0, 0.05, -0.3) * U.AxisZ, Color3.fromRGB(110, 75, 50), model)) -- handle
		tpart(U.Cyl(0.35, 0.2, T(0, 0.05, 0.15) * U.AxisZ, U.Shade(tc, 0.5), model)) -- wrap
		local hcf = T(0, 0.05, -1.15)
		tpart(U.Block(Vector3.new(1.0, 0.7, 0.7), hcf, tc, model, METAL_MAT))
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.1, 0.74, 0.74), hcf * CFrame.new(0.38 * s, 0, 0), U.Shade(tc, 0.7), model, METAL_MAT)) -- bands
		end
		muzzle = tpart(U.Block(Vector3.new(0.26, 0.26, 0.05), hcf * CFrame.new(0, 0, -0.36) * CFrame.Angles(0, 0, math.pi / 4), beam, model, NEON))
		tipWorld = hcf * CFrame.new(0, 0, -0.4)
	elseif tool == "Thunderbolt" then
		-- hand-held lightning bolt: wrapped grip and a glowing zig-zag
		local g = Color3.fromRGB(95, 62, 40)
		tpart(U.Cyl(0.35, 0.18, T(0, 0, 0.05) * U.AxisZ, g, model))
		local pts = { T(0, 0, -0.1).Position, T(0, 0.28, -0.55).Position, T(0, -0.05, -0.85).Position, T(0, 0.25, -1.4).Position }
		local ws = { 0.2, 0.16, 0.12 }
		local last: BasePart? = nil
		for i = 1, 3 do
			local p0, p1 = pts[i], pts[i + 1]
			last = tpart(U.Block(Vector3.new(ws[i], 0.08, (p1 - p0).Magnitude + 0.06), CFrame.lookAt((p0 + p1) / 2, p1, grip.RightVector), U.Vivid(beam), model, NEON))
		end
		muzzle = last :: BasePart
		tipWorld = CFrame.new(pts[4]) * grip.Rotation
	elseif tool == "RayGun" then
		-- retro ray gun: round body, ringed barrel, tail fin, glowing tip
		tpart(U.Block(Vector3.new(0.2, 0.42, 0.26), T(0, -0.08, -0.05), U.Shade(tc, 0.5), model)) -- grip
		tpart(U.Ball(0.62, T(0, 0.25, -0.3), tc, model))
		tpart(U.Cyl(0.85, 0.16, T(0, 0.25, -0.95) * U.AxisZ, METAL, model, METAL_MAT))
		for i = 0, 2 do
			tpart(U.Cyl(0.06, 0.38 - i * 0.05, T(0, 0.25, -0.7 - i * 0.2) * U.AxisZ, U.Vivid(beam), model)) -- rings
		end
		tpart(U.Wedge(Vector3.new(0.08, 0.32, 0.4), T(0, 0.62, -0.18), U.Shade(tc, 0.7), model)) -- fin
		muzzle = tpart(U.Ball(0.24, T(0, 0.25, -1.42), beam, model, NEON))
		tipWorld = T(0, 0.25, -1.5)
	elseif tool == "StarBlade" then
		-- white blade with a glowing four-point star at the tip
		local hilt = Color3.fromRGB(40, 30, 60)
		tpart(U.Cyl(0.45, 0.17, T(0, 0, 0.12) * U.AxisZ, hilt, model))
		tpart(U.Ball(0.24, T(0, 0, 0.38), GOLD, model, METAL_MAT)) -- pommel
		tpart(U.Block(Vector3.new(0.85, 0.14, 0.16), T(0, 0, -0.14), GOLD, model, METAL_MAT)) -- crossguard
		tpart(U.Block(Vector3.new(0.08, 0.28, 1.3), T(0, 0, -0.87), tc, model, { Reflectance = 0.3 })) -- blade
		local sc = T(0, 0, -1.72) * CFrame.Angles(0, math.pi / 2, 0) -- star faces sideways
		for _, a in { 0, math.pi / 2 } do
			tpart(U.Block(Vector3.new(0.1, 0.78, 0.05), sc * CFrame.Angles(0, 0, a), U.Mix(beam, WHITE, 0.5), model, { Reflectance = 0.3 })) -- twinkle
		end
		muzzle = tpart(U.Block(Vector3.new(0.22, 0.22, 0.22), sc * U.VertexUp, beam, model, NEON))
		tipWorld = T(0, 0, -2.05)
	-- EXCLUSIVES (world2c): premium tools of the 16 World 2 Exclusive-crate hunters (one each)
	elseif tool == "ExDragonLantern" then
		-- red lacquer pole with a gold arm, a red paper lantern hanging from it (glowing core) and a tassel
		local up = T(0, 0.05, -0.1) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.3)
		tpart(U.Cyl(2.2, 0.14, up * CFrame.new(0, 0.6, 0) * U.AxisY, Color3.fromRGB(170, 30, 40), model))
		tpart(U.Ball(0.26, up * CFrame.new(0, 1.74, 0), GOLD, model, METAL_MAT)) -- finial
		local hook = up * CFrame.new(0, 1.6, 0)
		tpart(U.Cyl(0.65, 0.08, hook * CFrame.new(0, 0, -0.3) * U.AxisZ, GOLD, model, METAL_MAT)) -- arm
		local lc = hook * CFrame.new(0, -0.48, -0.6)
		tpart(U.Ball(0.66, lc, tc, model, { Transparency = 0.25 }))
		for _, y in { -0.31, 0.31 } do
			tpart(U.Cyl(0.1, 0.38, lc * CFrame.new(0, y, 0) * U.AxisY, GOLD, model, METAL_MAT)) -- caps
		end
		tpart(U.Cyl(0.32, 0.08, lc * CFrame.new(0, -0.52, 0) * U.AxisY, tc, model)) -- tassel
		muzzle = tpart(U.Ball(0.32, lc, Color3.fromRGB(255, 215, 130), model, NEON))
		tipWorld = lc
	elseif tool == "ExRuneStaff" then
		-- archmage staff: dark pole, gold crescent cradle, a glowing orb inside a ring of floating gold runes
		local up = T(0, 0.05, -0.1) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.35)
		tpart(U.Cyl(2.7, 0.16, up * CFrame.new(0, 0.55, 0) * U.AxisY, tc, model))
		for _, s in { -1, 1 } do
			tpart(U.Cyl(0.55, 0.1, up * CFrame.new(0.14 * s, 2.05, 0) * CFrame.Angles(0, 0, -0.55 * s) * U.AxisY, GOLD, model, METAL_MAT)) -- crescent
		end
		local oc = up * CFrame.new(0, 2.45, 0)
		muzzle = tpart(U.Ball(0.46, oc, beam, model, NEON))
		for i = 0, 4 do
			local a = i * 2 * math.pi / 5
			tpart(U.Block(Vector3.new(0.14, 0.14, 0.05), oc * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.05 * (i % 2), -0.5) * CFrame.Angles(0, 0, math.pi / 4), GOLD, model, METAL_MAT)) -- runes
		end
		tipWorld = oc
	elseif tool == "ExHarvestBlade" then
		-- knight's sword: vine-wrapped hilt, pumpkin pommel, gold leaf guard, steel blade with an orange fuller
		local green = Color3.fromRGB(70, 120, 50)
		tpart(U.Cyl(0.5, 0.17, T(0, 0, 0.12) * U.AxisZ, green, model))
		tpart(U.Ball(0.3, T(0, 0, 0.42), Color3.fromRGB(240, 130, 40), model)) -- pommel
		tpart(U.Block(Vector3.new(0.95, 0.14, 0.2), T(0, 0, -0.16), GOLD, model, METAL_MAT)) -- guard
		tpart(U.Block(Vector3.new(0.1, 0.34, 1.6), T(0, 0, -1.0), tc, model, { Material = Enum.Material.Metal, Reflectance = 0.25 })) -- blade
		tpart(U.Block(Vector3.new(0.12, 0.1, 1.3), T(0, 0, -0.95), Color3.fromRGB(240, 130, 40), model)) -- fuller
		muzzle = tpart(U.Block(Vector3.new(0.2, 0.2, 0.2), T(0, 0, -1.85) * U.VertexUp, beam, model, NEON))
		tipWorld = T(0, 0, -1.95)
	elseif tool == "ExSporeScepter" then
		-- gold scepter crowned with a spotted mushroom and a floating glowing spore
		local up = T(0, 0.05, -0.15) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.3)
		tpart(U.Cyl(1.9, 0.12, up * CFrame.new(0, 0.45, 0) * U.AxisY, GOLD, model, METAL_MAT))
		tpart(U.Cyl(0.35, 0.22, up * CFrame.new(0, 1.5, 0) * U.AxisY, CREAM, model)) -- stem
		tpart(U.Cyl(0.06, 0.8, up * CFrame.new(0, 1.68, 0) * U.AxisY, Color3.fromRGB(255, 225, 235), model)) -- gills
		tpart(U.Ball(0.74, up * CFrame.new(0, 1.8, 0), Color3.fromRGB(240, 90, 140), model)) -- cap
		for _, q in { { 0.2, 2.08, -0.2 }, { -0.25, 2.0, -0.15 } } do
			tpart(U.Ball(0.16, up * CFrame.new(q[1], q[2], q[3]), WHITE, model))
		end
		muzzle = tpart(U.Ball(0.24, up * CFrame.new(0, 2.45, 0), beam, model, NEON))
		tipWorld = up * CFrame.new(0, 2.45, 0)
	elseif tool == "ExTideBlaster" then
		-- big water blaster: chunky body, see-through water tank on top, pump grip, long barrel, nozzle
		tpart(U.Block(Vector3.new(0.42, 0.5, 1.15), T(0, 0.15, -0.35), tc, model))
		tpart(U.Block(Vector3.new(0.44, 0.12, 0.9), T(0, 0.15, -0.38), Color3.fromRGB(40, 180, 220), model)) -- stripe
		tpart(U.Ball(0.66, T(0, 0.62, -0.2), Color3.fromRGB(140, 220, 255), model, { Transparency = 0.35 })) -- tank
		tpart(U.Cyl(0.45, 0.22, T(0, -0.05, -0.85) * U.AxisZ, Color3.fromRGB(40, 60, 110), model)) -- pump
		tpart(U.Cyl(0.6, 0.2, T(0, 0.2, -1.2) * U.AxisZ, WHITE, model)) -- barrel
		muzzle = tpart(U.Cyl(0.12, 0.28, T(0, 0.2, -1.55) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0.2, -1.65)
	elseif tool == "ExPrismSword" then
		-- crystal sword: silver hilt, gem pommel, crystal-tipped guard, long see-through crystal blade
		local crystal = Color3.fromRGB(190, 240, 255)
		tpart(U.Cyl(0.45, 0.17, T(0, 0, 0.12) * U.AxisZ, Color3.fromRGB(60, 70, 100), model))
		tpart(U.Block(Vector3.new(0.24, 0.24, 0.24), T(0, 0, 0.42) * U.VertexUp, Color3.fromRGB(120, 220, 255), model, { Reflectance = 0.4 }))
		tpart(U.Block(Vector3.new(0.8, 0.14, 0.18), T(0, 0, -0.16), Color3.fromRGB(215, 225, 240), model, { Material = Enum.Material.Metal, Reflectance = 0.35 }))
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.2, 0.2, 0.2), T(0.45 * s, 0, -0.16) * U.VertexUp, crystal, model, { Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.3 }))
		end
		tpart(U.Block(Vector3.new(0.1, 0.36, 1.8), T(0, 0, -1.1), tc, model, { Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.35 })) -- blade
		muzzle = tpart(U.Block(Vector3.new(0.24, 0.24, 0.24), T(0, 0, -2.05) * U.VertexUp, beam, model, NEON))
		tipWorld = T(0, 0, -2.15)
	elseif tool == "ExDiamondCard" then
		-- a giant gold VIP card held up: dark stripe, chip, diamond inlay and a twinkle on the corner
		local cc = T(0, 0.45, -0.45) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, -0.5, 0.15)
		tpart(U.Block(Vector3.new(1.05, 0.68, 0.05), cc, tc, model, { Material = Enum.Material.Metal, Reflectance = 0.3 }))
		tpart(U.Block(Vector3.new(1.05, 0.13, 0.06), cc * CFrame.new(0, 0.17, 0), Color3.fromRGB(40, 30, 40), model)) -- stripe
		tpart(U.Block(Vector3.new(0.2, 0.16, 0.07), cc * CFrame.new(-0.3, -0.07, 0), Color3.fromRGB(215, 220, 230), model, METAL_MAT)) -- chip
		tpart(U.Block(Vector3.new(0.24, 0.24, 0.24), cc * CFrame.new(0.3, -0.12, -0.04) * U.VertexUp, Color3.fromRGB(225, 250, 255), model, { Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.5 }))
		muzzle = tpart(U.Block(Vector3.new(0.15, 0.15, 0.15), cc * CFrame.new(0.55, 0.36, 0) * U.VertexUp, beam, model, NEON))
		tipWorld = cc * CFrame.new(0.55, 0.36, 0)
	elseif tool == "ExGoldWatch" then
		-- conductor's big gold pocket watch held up on its chain: cream face, black hands, winding crown
		local wc = T(0, 0.45, -0.45) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, -0.4, 0)
		tpart(U.Cyl(0.16, 0.85, wc * U.AxisZ, tc, model, { Material = Enum.Material.Metal, Reflectance = 0.25 }))
		tpart(U.Cyl(0.18, 0.68, wc * U.AxisZ, CREAM, model)) -- face
		tpart(U.Block(Vector3.new(0.05, 0.28, 0.04), wc * CFrame.new(0, 0.12, -0.1), EYE, model))
		tpart(U.Block(Vector3.new(0.2, 0.05, 0.04), wc * CFrame.new(0.09, 0, -0.1), EYE, model))
		tpart(U.Cyl(0.16, 0.16, wc * CFrame.new(0, 0.5, 0) * U.AxisY, tc, model, METAL_MAT)) -- crown
		tpart(U.Cyl(0.6, 0.05, U.Between((wc * CFrame.new(0, 0.58, 0)).Position, T(0, -0.05, 0.05).Position), tc, model, METAL_MAT)) -- chain
		muzzle = tpart(U.Ball(0.12, wc * CFrame.new(0, 0, -0.11), beam, model, NEON))
		tipWorld = wc * CFrame.new(0, 0, -0.2)
	elseif tool == "ExAmberScepter" then
		-- fossil bone staff with knobbly ends, an amber gem (a tiny bug inside) and a glowing spark on top
		local up = T(0, 0.05, -0.1) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.3)
		tpart(U.Cyl(2.0, 0.17, up * CFrame.new(0, 0.55, 0) * U.AxisY, tc, model))
		for _, y in { -0.45, 1.55 } do
			for _, s in { -1, 1 } do
				tpart(U.Ball(0.28, up * CFrame.new(0.1 * s, y, 0), tc, model)) -- knobs
			end
		end
		local gc = up * CFrame.new(0, 1.95, 0)
		tpart(U.Block(Vector3.new(0.55, 0.55, 0.55), gc * U.VertexUp, Color3.fromRGB(255, 160, 40), model, { Transparency = 0.25, Reflectance = 0.3 }))
		tpart(U.Ball(0.14, gc, Color3.fromRGB(60, 40, 30), model)) -- bug
		muzzle = tpart(U.Ball(0.2, up * CFrame.new(0, 2.5, 0), beam, model, NEON))
		tipWorld = up * CFrame.new(0, 2.5, 0)
	elseif tool == "ExChampionCup" then
		-- giant champion's cup raised high: wooden plinth, gold stem, wide cup, side handles, star on top
		local cf = T(0, 0.2, -0.45) * CFrame.Angles(math.pi / 6, 0, 0)
		local mat = { Material = Enum.Material.Metal, Reflectance = 0.25 }
		tpart(U.Block(Vector3.new(0.6, 0.25, 0.6), cf, Color3.fromRGB(90, 50, 30), model))
		tpart(U.Cyl(0.45, 0.16, cf * CFrame.new(0, 0.35, 0) * U.AxisY, tc, model, mat)) -- stem
		tpart(U.Cyl(0.3, 0.55, cf * CFrame.new(0, 0.7, 0) * U.AxisY, tc, model, mat)) -- cup
		tpart(U.Cyl(0.4, 0.95, cf * CFrame.new(0, 1.02, 0) * U.AxisY, tc, model, mat))
		for _, s in { -1, 1 } do
			tpart(U.Cyl(0.4, 0.07, U.Between((cf * CFrame.new(0.45 * s, 1.15, 0)).Position, (cf * CFrame.new(0.72 * s, 0.95, 0)).Position), tc, model, mat))
			tpart(U.Cyl(0.35, 0.07, U.Between((cf * CFrame.new(0.72 * s, 0.95, 0)).Position, (cf * CFrame.new(0.3 * s, 0.72, 0)).Position), tc, model, mat))
		end
		muzzle = tpart(U.Block(Vector3.new(0.34, 0.34, 0.07), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 4), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 1.55, 0)
	elseif tool == "ExNeonMic" then
		-- stage microphone held up: dark handle, coloured band, glowing grille
		local mc = T(0, 0.1, -0.3) * CFrame.Angles(math.pi / 6 + 0.35, 0, 0)
		tpart(U.Cyl(0.75, 0.17, mc * CFrame.new(0, 0.25, 0) * U.AxisY, Color3.fromRGB(35, 35, 45), model))
		tpart(U.Cyl(0.1, 0.24, mc * CFrame.new(0, 0.6, 0) * U.AxisY, tc, model))
		muzzle = tpart(U.Ball(0.42, mc * CFrame.new(0, 0.82, 0), beam, model, NEON))
		tipWorld = mc * CFrame.new(0, 0.9, 0)
	elseif tool == "ExIcingScepter" then
		-- royal icing scepter: gold rod, a swirl of pink and white icing and a glowing cherry
		local up = T(0, 0.05, -0.15) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.3)
		tpart(U.Cyl(1.8, 0.13, up * CFrame.new(0, 0.45, 0) * U.AxisY, tc, model, METAL_MAT))
		tpart(U.Cyl(0.14, 0.5, up * CFrame.new(0, 1.38, 0) * U.AxisY, tc, model, METAL_MAT)) -- cup
		for i, d in { 0.62, 0.48, 0.32 } do
			tpart(U.Ball(d, up * CFrame.new(0, 1.5 + i * 0.2, 0), if i % 2 == 1 then Color3.fromRGB(255, 170, 200) else WHITE, model)) -- icing
		end
		muzzle = tpart(U.Ball(0.26, up * CFrame.new(0, 2.25, 0), beam, model, NEON)) -- cherry
		tipWorld = up * CFrame.new(0, 2.3, 0)
	elseif tool == "ExHoloController" then
		-- hologram gamepad: see-through body and grips, a d-pad and three buttons, glowing centre light
		local cc = T(0, 0.35, -0.5) * CFrame.Angles(math.pi / 6 - 0.9, 0, 0) * CFrame.Angles(0, 0, 0.2)
		local glow = { Transparency = 0.35 }
		tpart(U.Block(Vector3.new(1.0, 0.16, 0.5), cc, tc, model, glow))
		for _, s in { -1, 1 } do
			tpart(U.Ball(0.38, cc * CFrame.new(0.45 * s, -0.02, 0.15), tc, model, glow)) -- grips
		end
		local pink = Color3.fromRGB(255, 90, 230)
		tpart(U.Block(Vector3.new(0.26, 0.06, 0.08), cc * CFrame.new(-0.28, 0.1, -0.02), pink, model))
		tpart(U.Block(Vector3.new(0.08, 0.06, 0.26), cc * CFrame.new(-0.28, 0.1, -0.02), pink, model)) -- d-pad
		for i, q in { { 0.22, 0.04 }, { 0.32, -0.08 }, { 0.42, 0.04 } } do
			tpart(U.Ball(0.1, cc * CFrame.new(q[1], 0.1, q[2]), RAINBOW[i * 2], model)) -- buttons
		end
		muzzle = tpart(U.Ball(0.14, cc * CFrame.new(0, 0.1, -0.12), beam, model, NEON))
		tipWorld = cc * CFrame.new(0, 0.1, -0.3)
	elseif tool == "ExStormSpear" then
		-- storm spear: silver shaft, blue grip, a zig-zag gold lightning-bolt head with a glowing point
		local up = T(0, 0.05, -0.1) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.3)
		tpart(U.Cyl(2.6, 0.12, up * CFrame.new(0, 0.6, 0) * U.AxisY, tc, model, METAL_MAT))
		tpart(U.Cyl(0.5, 0.17, up * CFrame.new(0, 0.05, 0) * U.AxisY, Color3.fromRGB(40, 80, 200), model)) -- grip
		local p = { Vector3.new(0, 1.85, 0), Vector3.new(0.22, 2.25, 0), Vector3.new(-0.12, 2.35, 0), Vector3.new(0.1, 2.85, 0) }
		for i = 1, 3 do
			local a = (up * CFrame.new(p[i])).Position
			local b = (up * CFrame.new(p[i + 1])).Position
			tpart(U.Block(Vector3.new(0.16, 0.08, (b - a).Magnitude + 0.08), CFrame.lookAt((a + b) / 2, b), GOLD, model, METAL_MAT)) -- bolt
		end
		muzzle = tpart(U.Block(Vector3.new(0.2, 0.2, 0.2), up * CFrame.new(p[4]) * U.VertexUp, beam, model, NEON))
		tipWorld = up * CFrame.new(p[4])
	elseif tool == "ExPlanetOrb" then
		-- a little ringed planet held up on the palm, with a glowing moonlet
		local pc = T(0, 0.55, -0.45)
		tpart(U.Ball(0.85, pc, tc, model))
		tpart(U.Cyl(0.16, 0.87, pc * CFrame.Angles(0.35, 0, 0.3) * U.AxisY, U.Shade(tc, 0.8), model)) -- band
		tpart(U.Cyl(0.03, 1.6, pc * CFrame.Angles(0.35, 0, 0.3) * U.AxisY, Color3.fromRGB(255, 225, 170), model, { Transparency = 0.25 })) -- ring
		muzzle = tpart(U.Ball(0.18, pc * CFrame.new(0.55, 0.5, -0.2), beam, model, NEON))
		tipWorld = pc * CFrame.new(0.55, 0.5, -0.2)
	elseif tool == "ExGalaxyScepter" then
		-- emperor's scepter: gold rod and collar, a tilted spiral galaxy of two see-through discs, a star core
		local up = T(0, 0.05, -0.1) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, 0, -0.3)
		tpart(U.Cyl(2.2, 0.14, up * CFrame.new(0, 0.55, 0) * U.AxisY, tc, model, METAL_MAT))
		tpart(U.Cyl(0.14, 0.34, up * CFrame.new(0, 1.62, 0) * U.AxisY, tc, model, METAL_MAT)) -- collar
		local gc = up * CFrame.new(0, 2.1, 0) * CFrame.Angles(0.5, 0, 0.3)
		tpart(U.Cyl(0.04, 1.15, gc * U.AxisY, Color3.fromRGB(150, 90, 230), model, { Transparency = 0.35 }))
		tpart(U.Cyl(0.05, 0.7, gc * CFrame.Angles(0, 0.6, 0) * U.AxisY, Color3.fromRGB(255, 150, 220), model, { Transparency = 0.25 }))
		muzzle = tpart(U.Block(Vector3.new(0.28, 0.28, 0.28), up * CFrame.new(0, 2.1, 0) * U.VertexUp, beam, model, NEON))
		tipWorld = up * CFrame.new(0, 2.1, 0)
	elseif tool == "Candle" then
		-- chamberstick: brass saucer, fat cream candle with a wax drip and a little flame
		local cc = T(0, 0.05, -0.45) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Cyl(0.08, 0.68, cc * U.AxisY, tc, model, METAL_MAT)) -- saucer
		tpart(U.Cyl(0.55, 0.28, cc * CFrame.new(0, 0.3, 0) * U.AxisY, CREAM, model))
		tpart(U.Ball(0.13, cc * CFrame.new(0.1, 0.45, -0.07), CREAM, model)) -- wax drip
		muzzle = tpart(U.Block(Vector3.new(0.17, 0.17, 0.17), cc * CFrame.new(0, 0.7, 0) * U.VertexUp, beam, model, NEON)) -- flame
		tipWorld = cc * CFrame.new(0, 0.78, 0)
	elseif tool == "Stamp" then
		-- library date stamp held upright: wooden knob, neck, chunky body and a glowing ink pad
		local sc = T(0, 0, -0.12) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Ball(0.36, sc * CFrame.new(0, 0.1, 0), Color3.fromRGB(150, 100, 60), model)) -- knob
		tpart(U.Cyl(0.4, 0.16, sc * CFrame.new(0, -0.2, 0) * U.AxisY, Color3.fromRGB(120, 80, 50), model))
		tpart(U.Block(Vector3.new(0.72, 0.28, 0.46), sc * CFrame.new(0, -0.5, 0), tc, model))
		tpart(U.Block(Vector3.new(0.74, 0.06, 0.48), sc * CFrame.new(0, -0.38, 0), GOLD, model, METAL_MAT)) -- trim
		muzzle = tpart(U.Block(Vector3.new(0.64, 0.06, 0.4), sc * CFrame.new(0, -0.67, 0), beam, model, NEON)) -- ink pad
		tipWorld = sc * CFrame.new(0, -0.72, 0)
	elseif tool == "Magnifier" then
		-- big magnifying glass held up and out: wooden handle, brass rim, glassy lens
		local mf = grip * CFrame.Angles(0.9, 0, 0)
		tpart(U.Cyl(0.7, 0.17, mf * CFrame.new(0, 0, -0.25) * U.AxisZ, Color3.fromRGB(120, 75, 45), model)) -- handle
		tpart(U.Cyl(0.12, 0.2, mf * CFrame.new(0, 0, -0.62) * U.AxisZ, tc, model, METAL_MAT)) -- collar
		local lc = mf * CFrame.new(0, 0, -1.12) * CFrame.Angles(0, 0.35, 0)
		tpart(U.Cyl(0.1, 0.95, lc, tc, model, METAL_MAT)) -- rim
		tpart(U.Cyl(0.12, 0.78, lc, Color3.fromRGB(200, 235, 255), model, { Transparency = 0.35, Reflectance = 0.3, Shadow = false })) -- lens
		muzzle = tpart(U.Block(Vector3.new(0.14, 0.14, 0.14), lc * CFrame.new(0.08, 0.2, -0.18) * U.VertexUp, beam, model, NEON)) -- glint
		tipWorld = lc
	elseif tool == "BookStaff" then
		-- archmage staff: tall dark pole, gold collar and an open book floating above with a glowing rune
		local sf = grip * CFrame.Angles(0.05, 0, -0.5)
		tpart(U.Cyl(3.0, 0.18, sf * CFrame.new(0, 0.55, 0) * U.AxisY, U.Shade(tc, 0.5), model))
		tpart(U.Cyl(0.18, 0.44, sf * CFrame.new(0, 2.0, 0) * U.AxisY, GOLD, model, METAL_MAT))
		tpart(U.Ball(0.3, sf * CFrame.new(0, 2.15, 0), GOLD, model, METAL_MAT))
		local bk = sf * CFrame.new(0, 2.55, 0) * CFrame.Angles(0, 0, 0.5) * CFrame.Angles(-1.0, 0, 0)
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.55, 0.06, 0.75), bk * CFrame.new(0.27 * s, 0, 0) * CFrame.Angles(0, 0, 0.18 * s), tc, model))
		end
		tpart(U.Block(Vector3.new(0.98, 0.1, 0.68), bk * CFrame.new(0, 0.08, 0), CREAM, model)) -- pages
		muzzle = tpart(U.Block(Vector3.new(0.26, 0.26, 0.26), bk * CFrame.new(0, 0.5, 0) * U.VertexUp, beam, model, NEON))
		tipWorld = bk * CFrame.new(0, 0.5, 0)
	elseif tool == "Anemometer" then
		-- hand-held wind meter: a pole with three spinning cups (one red) on top
		local sf = grip * CFrame.Angles(0.05, 0, -0.35)
		tpart(U.Cyl(1.9, 0.12, sf * CFrame.new(0, 0.6, 0) * U.AxisY, METAL, model, METAL_MAT))
		local hc = sf * CFrame.new(0, 1.6, 0)
		tpart(U.Cyl(0.22, 0.24, hc * U.AxisY, tc, model))
		for i = 0, 2 do
			local a = i * 2 * math.pi / 3 + 0.4
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			tpart(U.Cyl(0.62, 0.06, hc * CFrame.new(d * 0.3) * CFrame.Angles(0, -a, 0), METAL, model, METAL_MAT))
			tpart(U.Ball(0.34, hc * CFrame.new(d * 0.64), if i == 0 then RED else tc, model)) -- cup
		end
		muzzle = tpart(U.Ball(0.16, hc * CFrame.new(0, 0.2, 0), beam, model, NEON))
		tipWorld = hc * CFrame.new(0, 0.25, 0)
	elseif tool == "Crook" then
		-- shepherd's crook: tall pole whose top curls over outward, a little bell on the hook's end
		local sf = grip * CFrame.Angles(0.05, 0, -0.42)
		tpart(U.Cyl(2.6, 0.15, sf * CFrame.new(0, 0.55, 0) * U.AxisY, tc, model))
		local cx, cy, r = 0.34, 1.85, 0.34
		local prev = sf * CFrame.new(0, cy, 0)
		for i = 1, 5 do
			local a = math.pi - i * math.pi / 4
			local p = sf * CFrame.new(cx + math.cos(a) * r, cy + math.sin(a) * r, 0)
			tpart(U.Cyl((p.Position - prev.Position).Magnitude + 0.06, 0.15, U.Between(prev.Position, p.Position), tc, model))
			prev = p
		end
		muzzle = tpart(U.Ball(0.2, prev * CFrame.new(0, -0.12, 0), beam, model, NEON)) -- bell
		tipWorld = prev * CFrame.new(0, -0.2, 0)
	elseif tool == "Pinwheel" then
		-- rainbow pinwheel on a stick, turned a little toward the viewer
		local sf = grip * CFrame.Angles(0.05, 0, -0.6)
		tpart(U.Cyl(1.8, 0.1, sf * CFrame.new(0, 0.6, 0) * U.AxisY, tc, model))
		local pc = sf * CFrame.new(0, 1.55, -0.08) * CFrame.Angles(0, -0.45, 0.6)
		for i = 0, 3 do
			tpart(U.Wedge(Vector3.new(0.05, 0.75, 0.75), pc * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0.375, 0.375, 0) * CFrame.Angles(0, math.pi / 2, 0), RAINBOW[i * 2 + 1], model))
		end
		muzzle = tpart(U.Ball(0.18, pc * CFrame.new(0, 0, -0.06), beam, model, NEON))
		tipWorld = pc * CFrame.new(0, 0, -0.1)
	elseif tool == "Pitchfork" then
		-- long wooden pitchfork: metal socket and cross-bar, three tines, a glow between the tips
		tpart(U.Cyl(2.4, 0.13, T(0, 0.05, -0.45) * U.AxisZ, tc, model)) -- handle
		tpart(U.Cyl(0.25, 0.19, T(0, 0.05, -1.62) * U.AxisZ, METAL, model, METAL_MAT)) -- socket
		tpart(U.Block(Vector3.new(0.72, 0.1, 0.1), T(0, 0.05, -1.75), METAL, model, METAL_MAT)) -- cross-bar
		for _, x in { -0.31, 0, 0.31 } do
			tpart(U.Cyl(0.72, 0.07, T(x, 0.05, -2.1) * U.AxisZ, METAL, model, METAL_MAT)) -- tines
		end
		muzzle = tpart(U.Ball(0.18, T(0, 0.05, -2.3), beam, model, NEON))
		tipWorld = T(0, 0.05, -2.48)
	elseif tool == "Whip" then
		-- leather handle with wrapped bands, the whip curling out in a loose S and thinning to a glowing tip
		tpart(U.Cyl(0.6, 0.17, T(0, 0.05, -0.1) * U.AxisZ, U.Shade(tc, 0.75), model))
		for _, z in { 0.1, -0.25 } do
			tpart(U.Cyl(0.06, 0.2, T(0, 0.05, z) * U.AxisZ, U.Shade(tc, 0.45), model)) -- bands
		end
		local prev = T(0, 0.05, -0.4).Position
		for i = 1, 7 do
			local p = T(0.32 * math.sin(i * 0.95), 0.05 - 0.07 * i, -0.4 - 0.25 * i).Position
			tpart(U.Cyl((p - prev).Magnitude + 0.04, 0.13 - i * 0.012, U.Between(prev, p), tc, model))
			prev = p
		end
		muzzle = tpart(U.Ball(0.12, CFrame.new(prev), beam, model, NEON))
		tipWorld = CFrame.new(prev) * grip.Rotation
	elseif tool == "BoxingGlove" then
		-- big padded boxing glove: thumb, white cuff and laces, a glow in front of the knuckles
		tpart(U.Ball(0.95, T(0, 0.05, -0.2), tc, model))
		tpart(U.Ball(0.42, T(-0.34, 0.1, -0.12), U.Shade(tc, 0.92), model)) -- thumb
		tpart(U.Cyl(0.36, 0.62, T(0, 0.05, 0.25) * U.AxisZ, WHITE, model)) -- cuff
		tpart(U.Block(Vector3.new(0.06, 0.04, 0.42), T(0, 0.52, -0.05), WHITE, model)) -- laces
		muzzle = tpart(U.Ball(0.2, T(0, 0.05, -0.72), beam, model, NEON))
		tipWorld = T(0, 0.05, -0.8)
	elseif tool == "Trophy" then
		-- gold cup trophy held up: square base, stem, flared cup and ring handles
		local cf = T(0, 0.15, -0.45) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Block(Vector3.new(0.5, 0.2, 0.5), cf, U.Shade(tc, 0.7), model, METAL_MAT))
		tpart(U.Cyl(0.35, 0.15, cf * CFrame.new(0, 0.27, 0) * U.AxisY, tc, model, METAL_MAT)) -- stem
		for i, d in { 0.4, 0.6, 0.78 } do
			tpart(U.Cyl(0.2, d, cf * CFrame.new(0, 0.5 + (i - 1) * 0.18, 0) * U.AxisY, tc, model, METAL_MAT)) -- cup
		end
		for _, s in { -1, 1 } do
			for _, p in U.Hoop(0.16, 0.06, 0.06, 6, cf * CFrame.new(0.44 * s, 0.75, 0), tc, model, METAL_MAT) do
				tpart(p) -- handles
			end
		end
		muzzle = tpart(U.Ball(0.24, cf * CFrame.new(0, 1.12, 0), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 1.2, 0)
	elseif tool == "SewingPin" then
		-- a sewing pin used as a sword: coloured ball head, long thin metal shaft, sharp tip
		tpart(U.Ball(0.36, T(0, 0.05, 0.12), U.Vivid(look.Shirt), model))
		tpart(U.Cyl(2.2, 0.1, T(0, 0.05, -1.0) * U.AxisZ, tc, model, METAL_MAT))
		tpart(U.Wedge(Vector3.new(0.1, 0.05, 0.28), T(0, 0.075, -2.24), tc, model, METAL_MAT)) -- point
		tpart(U.Wedge(Vector3.new(0.1, 0.05, 0.28), T(0, 0.025, -2.24) * CFrame.Angles(0, 0, math.pi), tc, model, METAL_MAT))
		muzzle = tpart(U.Ball(0.1, T(0, 0.05, -2.4), beam, model, NEON))
		tipWorld = T(0, 0.05, -2.45)
	elseif tool == "RollingPin" then
		-- wooden rolling pin held crosswise, a glow on the far handle end
		local rc = T(0.35, 0.15, -0.45)
		tpart(U.Cyl(1.5, 0.45, rc, tc, model))
		for _, s in { -1, 1 } do
			tpart(U.Cyl(0.42, 0.17, rc * CFrame.new(0.95 * s, 0, 0), U.Shade(tc, 0.75), model)) -- handles
		end
		muzzle = tpart(U.Ball(0.2, rc * CFrame.new(1.22, 0, 0), beam, model, NEON))
		tipWorld = rc * CFrame.new(1.3, 0, 0)
	elseif tool == "Whisk" then
		-- kitchen whisk: handle and three wire loops making a balloon, a glow inside
		tpart(U.Cyl(0.7, 0.17, T(0, 0.05, -0.05) * U.AxisZ, U.Shade(tc, 0.6), model))
		tpart(U.Cyl(0.12, 0.2, T(0, 0.05, -0.42) * U.AxisZ, tc, model, METAL_MAT))
		for k = 0, 2 do
			local rot = T(0, 0.05, 0) * CFrame.Angles(0, 0, k * math.pi / 3)
			local pts = { Vector3.new(0, 0, -0.45), Vector3.new(0.24, 0, -0.75), Vector3.new(0.3, 0, -1.1), Vector3.new(0, 0, -1.45), Vector3.new(-0.3, 0, -1.1), Vector3.new(-0.24, 0, -0.75), Vector3.new(0, 0, -0.45) }
			for i = 1, #pts - 1 do
				local p0, p1 = (rot * CFrame.new(pts[i])).Position, (rot * CFrame.new(pts[i + 1])).Position
				tpart(U.Cyl((p1 - p0).Magnitude + 0.03, 0.05, U.Between(p0, p1), tc, model, METAL_MAT))
			end
		end
		muzzle = tpart(U.Ball(0.2, T(0, 0.05, -1.0), beam, model, NEON))
		tipWorld = T(0, 0.05, -1.5)
	elseif tool == "Joystick" then
		-- arcade joystick held like a wand: base box with two round buttons, stick and a glowing ball top
		local cf = T(0, 0.05, -0.4) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Block(Vector3.new(0.62, 0.24, 0.46), cf, Color3.fromRGB(45, 45, 60), model))
		for i, x in { -0.18, 0.05 } do
			tpart(U.Cyl(0.08, 0.15, cf * CFrame.new(x, 0.13, -0.12) * U.AxisY, if i == 1 then RED else U.Vivid(tc), model)) -- buttons
		end
		tpart(U.Cyl(0.55, 0.1, cf * CFrame.new(0.15, 0.4, 0.05) * U.AxisY, METAL, model, METAL_MAT))
		tpart(U.Ball(0.34, cf * CFrame.new(0.15, 0.72, 0.05), tc, model))
		muzzle = tpart(U.Ball(0.14, cf * CFrame.new(0.15, 0.9, 0.05), beam, model, NEON))
		tipWorld = cf * CFrame.new(0.15, 0.95, 0.05)
	elseif tool == "Diploma" then
		-- rolled-up diploma tied with a red ribbon and a gold seal
		tpart(U.Cyl(1.1, 0.28, T(0, 0.05, -0.45) * U.AxisZ, CREAM, model))
		tpart(U.Cyl(0.04, 0.27, T(0, 0.05, -1.01) * U.AxisZ, U.Shade(CREAM, 0.8), model)) -- rolled end
		tpart(U.Cyl(0.14, 0.31, T(0, 0.05, -0.5) * U.AxisZ, RED, model)) -- ribbon
		tpart(U.Cyl(0.05, 0.22, T(0.12, 0.1, -0.5) * CFrame.Angles(0, 0, -0.3), GOLD, model, METAL_MAT)) -- seal
		muzzle = tpart(U.Ball(0.18, T(0, 0.05, -1.1), beam, model, NEON))
		tipWorld = T(0, 0.05, -1.15)
	elseif tool == "WateringCan" then
		-- garden watering can: round body, top handle, long spout with a sprinkler rose
		local cf = T(0, 0.05, -0.5) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Cyl(0.62, 0.62, cf * U.AxisY, tc, model))
		tpart(U.Cyl(0.06, 0.66, cf * CFrame.new(0, 0.18, 0) * U.AxisY, U.Shade(tc, 0.75), model)) -- band
		local s0, s1 = (cf * CFrame.new(0, -0.05, -0.28)).Position, (cf * CFrame.new(0, 0.45, -0.85)).Position
		tpart(U.Cyl((s1 - s0).Magnitude, 0.11, U.Between(s0, s1), tc, model)) -- spout
		muzzle = tpart(U.Cyl(0.08, 0.26, U.DiscFacing(s1, s1 - s0), beam, model, NEON)) -- rose
		for _, q in { { 0.12, 0.38 }, { -0.1, 0.42 } } do
			tpart(U.Block(Vector3.new(0.06, 0.08, 0.3), cf * CFrame.new(0, q[2], 0.1 + q[1]) * CFrame.Angles(q[1] * 3, 0, 0), U.Shade(tc, 0.75), model)) -- handle
		end
		tipWorld = CFrame.new(s1 + (s1 - s0).Unit * 0.08) * grip.Rotation
	elseif tool == "BubbleWand" then
		-- bubble wand: thin stick, ring at the end and a few bubbles drifting off it
		tpart(U.Cyl(1.0, 0.1, T(0, 0.05, -0.45) * U.AxisZ, tc, model))
		local rc = T(0, 0.05, -1.25) * CFrame.Angles(0, 0.9, 0)
		for _, p in U.Hoop(0.24, 0.06, 0.06, 6, rc, tc, model) do
			tpart(p)
		end
		muzzle = tpart(U.Cyl(0.02, 0.44, rc * U.AxisZ, beam, model, { Transparency = 0.5, Shadow = false }))
		for i, q in { { 0.25, 0.45, -1.5, 0.32 }, { -0.1, 0.8, -1.7, 0.24 }, { 0.3, 1.05, -1.3, 0.18 } } do
			tpart(U.Ball(q[4], T(q[1], q[2], q[3]), U.Mix(beam, WHITE, 0.4 + i * 0.1), model, { Transparency = 0.45, Reflectance = 0.3, Shadow = false }))
		end
		tipWorld = rc * CFrame.new(0, 0, -0.1)
	elseif tool == "Fork" then
		-- a big golden fork, held like a little trident
		tpart(U.Block(Vector3.new(0.14, 0.07, 1.2), T(0, 0.05, -0.4), tc, model, METAL_MAT)) -- handle
		tpart(U.Block(Vector3.new(0.24, 0.07, 0.25), T(0, 0.05, -1.1), tc, model, METAL_MAT)) -- neck
		tpart(U.Block(Vector3.new(0.5, 0.07, 0.2), T(0, 0.05, -1.3), tc, model, METAL_MAT)) -- head
		for i = 0, 3 do
			tpart(U.Block(Vector3.new(0.07, 0.07, 0.45), T(-0.21 + i * 0.14, 0.05, -1.62), tc, model, METAL_MAT)) -- tines
		end
		muzzle = tpart(U.Ball(0.16, T(0, 0.05, -1.75), beam, model, NEON))
		tipWorld = T(0, 0.05, -1.9)
	elseif tool == "Pretzel" then
		-- giant soft pretzel held up: knotted loop with salt crystals
		local pc = T(0, 0.7, -0.6) * CFrame.Angles(math.pi / 6, 0.6, 0)
		for _, p in U.Hoop(0.48, 0.18, 0.16, 8, pc, tc, model) do
			tpart(p)
		end
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.16, 0.85, 0.16), pc * CFrame.new(0.14 * s, -0.15, -0.02) * CFrame.Angles(0, 0, 0.55 * s), U.Shade(tc, 0.9), model)) -- knot
		end
		for _, q in { { -0.25, 0.25 }, { 0.3, 0.12 }, { 0.05, 0.42 } } do
			tpart(U.Block(Vector3.new(0.07, 0.07, 0.07), pc * CFrame.new(q[1], q[2], -0.09), WHITE, model)) -- salt
		end
		tpart(U.Cyl(0.6, 0.08, T(0, 0.25, -0.5) * CFrame.Angles(math.pi / 6, 0, 0) * U.AxisY, CREAM, model)) -- stick
		muzzle = tpart(U.Ball(0.14, pc * CFrame.new(0, 0.5, 0), beam, model, NEON))
		tipWorld = pc * CFrame.new(0, 0.55, 0)
	elseif tool == "CandyCane" then
		-- red-and-white striped candy cane, hook curling over at the top
		local sf = grip * CFrame.Angles(0.05, 0, -0.42)
		for i = 0, 3 do
			tpart(U.Cyl(0.55, 0.17, sf * CFrame.new(0, -0.2 + i * 0.52, 0) * U.AxisY, if i % 2 == 0 then tc else WHITE, model))
		end
		local cx, cy, r = 0.32, 1.85, 0.32
		local prev = sf * CFrame.new(0, cy, 0)
		for i = 1, 4 do
			local a = math.pi - i * math.pi / 4
			local p = sf * CFrame.new(cx + math.cos(a) * r, cy + math.sin(a) * r, 0)
			tpart(U.Cyl((p.Position - prev.Position).Magnitude + 0.06, 0.17, U.Between(prev.Position, p.Position), if i % 2 == 0 then tc else WHITE, model))
			prev = p
		end
		muzzle = tpart(U.Ball(0.18, prev * CFrame.new(0, -0.1, 0), beam, model, NEON))
		tipWorld = prev * CFrame.new(0, -0.15, 0)
	elseif tool == "Lasagna" then
		-- a dish of lasagna held flat: pasta and sauce layers, melted cheese and a puff of steam
		local cf = T(0, 0.2, -0.6) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Block(Vector3.new(1.0, 0.18, 0.7), cf, tc, model))
		for i, col in { Color3.fromRGB(250, 205, 120), Color3.fromRGB(200, 60, 40), Color3.fromRGB(250, 205, 120), Color3.fromRGB(255, 225, 120) } do
			tpart(U.Block(Vector3.new(0.86, 0.07, 0.58), cf * CFrame.new(0, 0.08 + i * 0.06, 0), col, model))
		end
		muzzle = tpart(U.Ball(0.22, cf * CFrame.new(0.1, 0.55, 0), beam, model, { Material = Enum.Material.Neon, Transparency = 0.3 })) -- steam
		tipWorld = cf * CFrame.new(0.1, 0.6, 0)
	elseif tool == "Brush" then
		-- a fossil-dusting brush: wooden handle, metal ferrule and soft bristles
		tpart(U.Cyl(0.95, 0.14, T(0, 0.05, -0.25) * U.AxisZ, tc, model))
		tpart(U.Cyl(0.18, 0.2, T(0, 0.05, -0.8) * U.AxisZ, METAL, model, METAL_MAT))
		tpart(U.Block(Vector3.new(0.38, 0.12, 0.42), T(0, 0.05, -1.08), Color3.fromRGB(110, 80, 55), model)) -- bristles
		muzzle = tpart(U.Ball(0.18, T(0, 0.05, -1.38), beam, model, { Material = Enum.Material.Neon, Transparency = 0.3 })) -- dust puff
		tipWorld = T(0, 0.05, -1.45)
	elseif tool == "TourFlag" then
		-- tour guide's flag held high: tall pole, bright flag with a bone on it, glowing top knob
		local sf = grip * CFrame.Angles(0.05, 0, -0.45)
		tpart(U.Cyl(2.7, 0.1, sf * CFrame.new(0, 0.7, 0) * U.AxisY, METAL, model, METAL_MAT))
		local fc = sf * CFrame.new(-0.45, 1.75, 0)
		tpart(U.Block(Vector3.new(0.85, 0.55, 0.04), fc, tc, model))
		tpart(U.Block(Vector3.new(0.4, 0.08, 0.05), fc, WHITE, model)) -- bone
		for _, x in { -0.2, 0.2 } do
			for _, y in { -0.05, 0.05 } do
				tpart(U.Ball(0.11, fc * CFrame.new(x, y, 0), WHITE, model))
			end
		end
		muzzle = tpart(U.Ball(0.2, sf * CFrame.new(0, 2.1, 0), beam, model, NEON))
		tipWorld = sf * CFrame.new(0, 2.15, 0)
	elseif tool == "AmberStaff" then
		-- tall staff topped by a big amber gem (a tiny mosquito trapped inside) in gold prongs
		local sf = grip * CFrame.Angles(0.05, 0, -0.5)
		tpart(U.Cyl(3.0, 0.18, sf * CFrame.new(0, 0.55, 0) * U.AxisY, Color3.fromRGB(120, 80, 50), model))
		tpart(U.Cyl(0.18, 0.42, sf * CFrame.new(0, 2.0, 0) * U.AxisY, GOLD, model, METAL_MAT))
		local gc = sf * CFrame.new(0, 2.45, 0)
		for i = 0, 2 do
			tpart(U.Wedge(Vector3.new(0.08, 0.4, 0.14), gc * CFrame.Angles(0, i * 2 * math.pi / 3, 0) * CFrame.new(0, -0.15, -0.3), GOLD, model, METAL_MAT)) -- prongs
		end
		tpart(U.Block(Vector3.new(0.55, 0.55, 0.55), gc * U.VertexUp, tc, model, { Transparency = 0.25, Reflectance = 0.2 }))
		tpart(U.Ball(0.12, gc, Color3.fromRGB(50, 35, 30), model)) -- mosquito
		muzzle = tpart(U.Ball(0.22, gc * CFrame.new(0, 0.05, 0), beam, model, { Material = Enum.Material.Neon, Transparency = 0.4 }))
		tipWorld = gc
	elseif tool == "Popcorn" then
		-- striped popcorn box heaped with puffs
		local cf = T(0, 0.2, -0.5) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Block(Vector3.new(0.55, 0.7, 0.55), cf, WHITE, model))
		for _, x in { -0.15, 0.15 } do
			tpart(U.Block(Vector3.new(0.13, 0.71, 0.57), cf * CFrame.new(x, 0, 0), tc, model)) -- stripes
		end
		for _, q in { { -0.12, 0.42, 0.1 }, { 0.15, 0.45, -0.08 }, { 0.0, 0.55, 0.12 }, { -0.15, 0.48, -0.15 }, { 0.12, 0.4, 0.18 } } do
			tpart(U.Ball(0.26, cf * CFrame.new(q[1], q[2], q[3]), Color3.fromRGB(255, 245, 200), model))
		end
		muzzle = tpart(U.Ball(0.22, cf * CFrame.new(0.02, 0.68, 0), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0.75, 0)
	elseif tool == "RedCard" then
		-- referee's red card held up high, a whistle on a cord round the neck
		local cf = T(0, 0.55, -0.35) * CFrame.Angles(math.pi / 6, -0.5, 0)
		tpart(U.Block(Vector3.new(0.45, 0.65, 0.04), cf, tc, model))
		muzzle = tpart(U.Ball(0.12, cf * CFrame.new(0, 0.38, 0), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0.42, 0)
	elseif tool == "BiscuitBox" then
		-- a box of homemade biscuits with one sitting on the lid
		local cf = T(0, 0.15, -0.55) * CFrame.Angles(math.pi / 6, 0, 0)
		tpart(U.Block(Vector3.new(0.75, 0.28, 0.55), cf, tc, model))
		tpart(U.Block(Vector3.new(0.8, 0.08, 0.6), cf * CFrame.new(0, 0.17, 0), U.Mix(tc, WHITE, 0.5), model)) -- lid
		tpart(U.Block(Vector3.new(0.06, 0.29, 0.57), cf, WHITE, model)) -- ribbon
		muzzle = tpart(U.Cyl(0.08, 0.38, cf * CFrame.new(0.1, 0.26, 0) * U.AxisY, Color3.fromRGB(215, 160, 90), model)) -- biscuit
		for _, q in { { 0.02, -0.06 }, { 0.17, 0.06 } } do
			tpart(U.Ball(0.07, cf * CFrame.new(q[1], 0.3, q[2]), Color3.fromRGB(90, 55, 35), model))
		end
		tipWorld = cf * CFrame.new(0.1, 0.35, 0)
	elseif tool == "Basketball" then
		-- orange ball balanced on the hand, dark seams
		local bc = T(0, 0.55, -0.35)
		muzzle = tpart(U.Ball(0.85, bc, tc, model))
		for _, r in { CFrame.identity, CFrame.Angles(0, math.pi / 2, 0), U.AxisY } do
			tpart(U.Cyl(0.04, 0.87, bc * r, Color3.fromRGB(60, 35, 25), model))
		end
		tipWorld = bc * CFrame.new(0, 0, -0.45)
	elseif tool == "HockeyStick" then
		-- hockey stick swinging low: taped shaft, angled blade and a puck
		local sf = grip * CFrame.Angles(-0.55, 0, 0)
		tpart(U.Block(Vector3.new(0.12, 0.18, 1.9), sf * CFrame.new(0, 0, -0.75), tc, model))
		tpart(U.Block(Vector3.new(0.13, 0.19, 0.25), sf * CFrame.new(0, 0, 0.05), WHITE, model)) -- grip tape
		local bl = sf * CFrame.new(0.2, 0, -1.7) * CFrame.Angles(0.55, 0, 0)
		tpart(U.Block(Vector3.new(0.55, 0.12, 0.26), bl, tc, model)) -- blade
		tpart(U.Block(Vector3.new(0.4, 0.125, 0.27), bl * CFrame.new(0.05, 0, 0), WHITE, model)) -- blade tape
		muzzle = tpart(U.Cyl(0.12, 0.34, bl * CFrame.new(0.15, -0.05, -0.35) * U.AxisY, Color3.fromRGB(30, 30, 35), model)) -- puck
		tipWorld = bl * CFrame.new(0.15, 0, -0.45)
	elseif tool == "FoamFinger" then
		-- giant foam "number one" hand waved high
		local cf = T(0, 0.45, -0.4) * CFrame.Angles(math.pi / 6, -0.6, 0)
		tpart(U.Block(Vector3.new(0.72, 0.62, 0.3), cf, tc, model)) -- fist
		tpart(U.Block(Vector3.new(0.24, 0.85, 0.24), cf * CFrame.new(0.2, 0.7, 0), tc, model)) -- finger
		tpart(U.Ball(0.24, cf * CFrame.new(0.2, 1.12, 0), tc, model))
		tpart(U.Block(Vector3.new(0.22, 0.3, 0.2), cf * CFrame.new(-0.4, 0.15, -0.05) * CFrame.Angles(0, 0, 0.5), tc, model)) -- thumb
		tpart(U.Cyl(0.25, 0.5, cf * CFrame.new(0, -0.42, 0) * U.AxisY, U.Shade(tc, 0.7), model)) -- cuff
		muzzle = tpart(U.Ball(0.14, cf * CFrame.new(0.2, 1.28, 0), beam, model, NEON))
		tipWorld = cf * CFrame.new(0.2, 1.32, 0)
	elseif tool == "Coin" then
		-- big gold arcade token with a star on its face
		local cf = T(0, 0.5, -0.45) * CFrame.Angles(math.pi / 6, -0.7, 0)
		tpart(U.Cyl(0.12, 0.92, cf * U.AxisZ, tc, model, METAL_MAT))
		tpart(U.Cyl(0.14, 0.66, cf * U.AxisZ, U.Shade(tc, 0.85), model, METAL_MAT))
		tpart(U.Block(Vector3.new(0.28, 0.28, 0.16), cf, U.Mix(tc, WHITE, 0.5), model))
		muzzle = tpart(U.Block(Vector3.new(0.28, 0.28, 0.17), cf * CFrame.Angles(0, 0, math.pi / 4), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0, -0.12)
	elseif tool == "Gamepad" then
		-- game controller: two grips, a d-pad, four coloured buttons and a glowing start light
		local cf = T(0, 0.35, -0.55) * CFrame.Angles(math.pi / 6, 0, 0) * CFrame.Angles(0, -0.6, 0) * CFrame.Angles(-1.2, 0, 0)
		tpart(U.Block(Vector3.new(1.15, 0.24, 0.5), cf, tc, model))
		for _, s in { -1, 1 } do
			tpart(U.Ball(0.46, cf * CFrame.new(0.52 * s, -0.04, 0.14), tc, model)) -- grips
		end
		local dark = Color3.fromRGB(40, 40, 55)
		tpart(U.Block(Vector3.new(0.24, 0.06, 0.08), cf * CFrame.new(-0.27, 0.11, 0), dark, model)) -- d-pad
		tpart(U.Block(Vector3.new(0.08, 0.06, 0.24), cf * CFrame.new(-0.27, 0.11, 0), dark, model))
		for i, q in { { 0.27, -0.08 }, { 0.37, 0 }, { 0.27, 0.08 }, { 0.17, 0 } } do
			tpart(U.Cyl(0.06, 0.08, cf * CFrame.new(q[1], 0.12, q[2]) * U.AxisY, RAINBOW[i * 2 - 1], model))
		end
		muzzle = tpart(U.Ball(0.1, cf * CFrame.new(0, 0.12, 0), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0.2, -0.25)
	elseif tool == "GoldRing" then
		-- a big shiny gold ring held up, a twinkle on top
		local rc = T(0, 0.55, -0.45) * CFrame.Angles(math.pi / 6, -0.6, 0)
		for _, p in U.Hoop(0.36, 0.12, 0.12, 8, rc, tc, model, { Material = Enum.Material.Metal, Reflectance = 0.3 }) do
			tpart(p)
		end
		muzzle = tpart(U.Block(Vector3.new(0.16, 0.16, 0.16), rc * CFrame.new(0, 0.5, 0) * U.VertexUp, beam, model, NEON))
		tipWorld = rc * CFrame.new(0, 0.55, 0)
	elseif tool == "PixelSword" then
		-- chunky 8-bit sword: pixel hilt, gold guard, stepped blade and a glowing tip pixel
		local u = 0.22
		local dark = Color3.fromRGB(70, 50, 90)
		for i = 0, 1 do
			tpart(U.Block(Vector3.new(u, u, u), T(0, 0.05, 0.15 - i * u), dark, model)) -- hilt
		end
		for x = -1, 1 do
			tpart(U.Block(Vector3.new(u, u, u), T(x * u, 0.05, -0.32), GOLD, model)) -- guard
		end
		for i = 1, 5 do
			tpart(U.Block(Vector3.new(u, u, u), T(0, 0.05, -0.32 - i * u), if i % 2 == 0 then tc else U.Mix(tc, WHITE, 0.4), model)) -- blade
		end
		muzzle = tpart(U.Block(Vector3.new(u, u, u), T(0, 0.05, -0.32 - 6 * u), beam, model, NEON))
		tipWorld = T(0, 0.05, -0.32 - 6.6 * u)
	-- CYBERARCADE (world2c) ---------------------------------------- tools
	elseif tool == "PixelPickaxe" then
		-- chunky voxel pickaxe held up: brown pixel handle and a bright two-pointed head
		local u = 0.25
		local cf = T(0, 0.0, -0.05) * CFrame.Angles(0.75, 0, -0.55)
		tpart(U.Block(Vector3.new(u, 6 * u, u), cf * CFrame.new(0, 2.5 * u, 0), Color3.fromRGB(130, 85, 50), model)) -- handle
		tpart(U.Block(Vector3.new(u + 0.02, u, u + 0.02), cf * CFrame.new(0, 1.5 * u, 0), Color3.fromRGB(95, 60, 35), model)) -- grip pixel
		tpart(U.Block(Vector3.new(u, u, 3 * u), cf * CFrame.new(0, 5.5 * u, 0), tc, model)) -- head
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(u, u, u), cf * CFrame.new(0, 4.6 * u, 1.9 * u * s), U.Shade(tc, 0.85), model))
		end
		tpart(U.Block(Vector3.new(u * 0.8, u * 0.8, u * 0.8), cf * CFrame.new(0, 3.8 * u, 2.6 * u), U.Shade(tc, 0.85), model))
		muzzle = tpart(U.Block(Vector3.new(u * 0.8, u * 0.8, u * 0.8), cf * CFrame.new(0, 3.8 * u, -2.6 * u), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 3.6 * u, -3.0 * u)
	elseif tool == "PowerPellet" then
		-- a big power pellet held up like a prize: creamy shell with a glowing heart
		local cf = T(0, 0.45, -0.35)
		tpart(U.Ball(0.78, cf, tc, model, { Transparency = 0.3 }))
		muzzle = tpart(U.Ball(0.42, cf, beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0, -0.4)
	elseif tool == "PipeWrench" then
		-- big red-handled pipe wrench held up: silver jaws with a hooked top and a gold adjusting nut
		local silver = Color3.fromRGB(200, 205, 215)
		local cf = T(0, 0.0, -0.05) * CFrame.Angles(0.65, 0, -0.45)
		tpart(U.Block(Vector3.new(0.22, 1.1, 0.2), cf * CFrame.new(0, 0.35, 0), tc, model)) -- handle
		tpart(U.Block(Vector3.new(0.24, 0.55, 0.26), cf * CFrame.new(0, 1.15, 0), silver, model, METAL_MAT)) -- shank
		tpart(U.Block(Vector3.new(0.24, 0.2, 0.72), cf * CFrame.new(0, 1.48, -0.22), silver, model, METAL_MAT)) -- hook jaw
		tpart(U.Block(Vector3.new(0.24, 0.16, 0.5), cf * CFrame.new(0, 1.04, -0.3), silver, model, METAL_MAT)) -- lower jaw
		tpart(U.Cyl(0.26, 0.3, cf * CFrame.new(0, 1.22, 0.02) * U.AxisY, GOLD, model, METAL_MAT)) -- nut
		muzzle = tpart(U.Block(Vector3.new(0.1, 0.1, 0.1), cf * CFrame.new(0, 1.26, -0.5), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 1.26, -0.6)
	elseif tool == "TokenSack" then
		-- a lumpy loot sack of arcade tokens, tied at the neck, with gold tokens peeking out of the top
		local cf = T(0, 0.3, -0.4)
		tpart(U.Ball(0.98, cf * CFrame.new(0, -0.1, 0), tc, model))
		tpart(U.Ball(0.62, cf * CFrame.new(0.2, -0.38, -0.18), U.Shade(tc, 0.9), model)) -- lump
		tpart(U.Cyl(0.18, 0.42, cf * CFrame.new(0, 0.42, 0) * U.AxisY, U.Shade(tc, 0.65), model)) -- tie
		tpart(U.Cyl(0.08, 0.38, cf * CFrame.new(-0.08, 0.62, 0.05) * CFrame.Angles(0, 0.4, 1.2), GOLD, model, METAL_MAT)) -- tokens
		muzzle = tpart(U.Cyl(0.08, 0.34, cf * CFrame.new(0.12, 0.66, -0.06) * CFrame.Angles(0, -0.3, 1.9), beam, model, NEON))
		tipWorld = cf * CFrame.new(0.12, 0.8, -0.06)
	elseif tool == "HeroSword" then
		-- hero's sword raised: silver blade with a stepped point, wide blue guard with forward tips, blue grip
		local cf = T(0, 0.05, 0) * CFrame.Angles(1.65, -0.35, 0)
		local hilt = Color3.fromRGB(70, 80, 190)
		tpart(U.Block(Vector3.new(0.15, 0.15, 0.42), cf * CFrame.new(0, 0, 0.08), hilt, model)) -- grip
		tpart(U.Block(Vector3.new(0.2, 0.2, 0.14), cf * CFrame.new(0, 0, 0.34), GOLD, model, METAL_MAT)) -- pommel
		tpart(U.Block(Vector3.new(0.72, 0.13, 0.16), cf * CFrame.new(0, 0, -0.18), hilt, model)) -- guard
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.14, 0.13, 0.26), cf * CFrame.new(0.36 * s, 0, -0.3), hilt, model)) -- guard tips
		end
		tpart(U.Block(Vector3.new(0.26, 0.06, 1.45), cf * CFrame.new(0, 0, -0.98), tc, model, { Reflectance = 0.25 })) -- blade
		tpart(U.Block(Vector3.new(0.14, 0.06, 0.14), cf * CFrame.new(0, 0, -1.77), tc, model, { Reflectance = 0.25 })) -- stepped point
		muzzle = tpart(U.Block(Vector3.new(0.07, 0.07, 0.1), cf * CFrame.new(0, 0, -1.89), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0, -1.95)
	elseif tool == "StarRod" then
		-- magic star rod: striped rod held up and forward with a yellow star on the end
		local cf = T(0, 0.05, 0) * CFrame.Angles(0.55, 0, 0)
		local star = Color3.fromRGB(255, 220, 60)
		tpart(U.Cyl(1.45, 0.13, cf * CFrame.new(0, 0, -0.6) * U.AxisZ, tc, model))
		tpart(U.Cyl(0.16, 0.19, cf * CFrame.new(0, 0, -0.9) * U.AxisZ, WHITE, model))
		local sc = cf * CFrame.new(0, 0, -1.5)
		tpart(U.Cyl(0.14, 0.42, sc * U.AxisZ, star, model))
		local lsc = rArm.CFrame:ToObjectSpace(sc)
		for i = 0, 4 do
			spike(rArm, lsc * CFrame.Angles(0, 0, i * 2 * math.pi / 5) * CFrame.new(0, 0.17, 0), 0.26, 0.3, 0.12, star)
		end
		muzzle = tpart(U.Ball(0.16, sc * CFrame.new(0, 0, -0.06), beam, model, NEON))
		tipWorld = sc * CFrame.new(0, 0, -0.15)
	elseif tool == "BossScepter" then
		-- final-boss scepter: dark rod, gold collar and a big pixel heart with a glowing middle pixel
		local cf = T(0, -0.1, -0.05) * CFrame.Angles(0.6, 0, -0.4)
		tpart(U.Cyl(1.5, 0.14, cf * CFrame.new(0, 0.55, 0) * U.AxisY, Color3.fromRGB(60, 40, 90), model))
		tpart(U.Block(Vector3.new(0.32, 0.16, 0.32), cf * CFrame.new(0, 1.3, 0), GOLD, model, METAL_MAT))
		local u = 0.26
		local hc = cf * CFrame.new(0, 1.38 + 1.5 * u, 0)
		for _, q in { { -1, 1 }, { 1, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 } } do
			tpart(U.Block(Vector3.new(u, u, u * 0.8), hc * CFrame.new(q[1] * u, q[2] * u, 0), tc, model))
		end
		muzzle = tpart(U.Block(Vector3.new(u, u, u * 0.8), hc, beam, model, NEON))
		tipWorld = hc * CFrame.new(0, 0, -0.2)
	-- end CYBERARCADE (world2c) tools
	elseif tool == "Screwdriver" then
		-- sonic-style gadget: silver handle with dark grip bands, slim neck and a glowing tip
		tpart(U.Cyl(0.65, 0.2, T(0, 0.05, -0.2) * U.AxisZ, tc, model, METAL_MAT))
		for _, z in { -0.05, -0.3 } do
			tpart(U.Cyl(0.08, 0.22, T(0, 0.05, z) * U.AxisZ, Color3.fromRGB(50, 45, 55), model)) -- grip bands
		end
		tpart(U.Cyl(0.45, 0.12, T(0, 0.05, -0.75) * U.AxisZ, U.Shade(tc, 0.8), model, METAL_MAT))
		tpart(U.Cyl(0.08, 0.22, T(0, 0.05, -0.98) * U.AxisZ, tc, model, METAL_MAT)) -- collar
		muzzle = tpart(U.Ball(0.18, T(0, 0.05, -1.08), beam, model, NEON))
		tipWorld = T(0, 0.05, -1.15)
	-- WATERPARK/STADIUM (world2c)
	elseif tool == "RescueCan" then
		-- lifeguard rescue float: a long torpedo buoy with rounded ends, side grips and a short strap to the hand
		local cf = T(0, 0.12, -0.6)
		tpart(U.Cyl(1.3, 0.5, cf * U.AxisZ, tc, model))
		for _, z in { -0.65, 0.65 } do
			tpart(U.Ball(0.5, cf * CFrame.new(0, 0, z), tc, model))
		end
		for _, s in { -1, 1 } do
			tpart(U.Block(Vector3.new(0.08, 0.12, 0.7), cf * CFrame.new(0.24 * s, 0.08, 0), U.Shade(tc, 0.75), model)) -- grips
		end
		tpart(U.Cyl(0.5, 0.05, U.Between((cf * CFrame.new(0, -0.1, 0.85)).Position, T(0, -0.05, 0.1).Position), WHITE, model)) -- strap
		muzzle = tpart(U.Ball(0.14, cf * CFrame.new(0, 0, -0.93), beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0, -0.98)
	elseif tool == "SquirtGun" then
		-- chunky water blaster: bright body, see-through water tank on top, pump and a long nozzle
		local acc = Color3.fromRGB(255, 140, 40)
		tpart(U.Block(Vector3.new(0.4, 0.42, 1.0), T(0, 0.15, -0.4), tc, model))
		tpart(U.Block(Vector3.new(0.26, 0.5, 0.3), T(0, -0.12, -0.02) * CFrame.Angles(0.3, 0, 0), U.Shade(tc, 0.7), model)) -- handle
		tpart(U.Cyl(0.75, 0.44, T(0, 0.55, -0.45) * U.AxisZ, Color3.fromRGB(150, 220, 255), model, { Transparency = 0.35, Shadow = false })) -- tank
		tpart(U.Cyl(0.12, 0.24, T(0, 0.55, -0.02) * U.AxisZ, acc, model)) -- tank cap
		tpart(U.Cyl(0.42, 0.3, T(0, -0.02, -0.82) * U.AxisZ, acc, model)) -- pump
		tpart(U.Cyl(0.45, 0.17, T(0, 0.2, -1.1) * U.AxisZ, acc, model)) -- nozzle
		muzzle = tpart(U.Cyl(0.06, 0.2, T(0, 0.2, -1.34) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0.2, -1.4)
	elseif tool == "Conch" then
		-- big spiral conch shell held out like a horn: banded spire, knobs and a glowing pink mouth
		local cf = T(0, 0.18, -0.35)
		for i, q in { { 0.12, 0.24, 0.2 }, { -0.08, 0.42, 0.22 }, { -0.34, 0.56, 0.3 }, { -0.64, 0.64, 0.32 } } do
			tpart(U.Cyl(q[3], q[2], cf * CFrame.new(0, 0, q[1]) * U.AxisZ, if i % 2 == 0 then tc else U.Shade(tc, 0.82), model))
		end
		for _, a in { 0.4, 2.4, 4.4 } do
			tpart(U.Ball(0.16, cf * CFrame.new(math.cos(a) * 0.27, math.sin(a) * 0.27, -0.12), U.Mix(tc, WHITE, 0.4), model)) -- knobs
		end
		tpart(U.Cyl(0.08, 0.76, cf * CFrame.new(0, 0, -0.84) * U.AxisZ, U.Mix(tc, WHITE, 0.4), model)) -- flared lip
		muzzle = tpart(U.Cyl(0.04, 0.46, cf * CFrame.new(0, 0, -0.89) * U.AxisZ, beam, model, NEON))
		tipWorld = cf * CFrame.new(0, 0, -0.95)
	elseif tool == "Spatula" then
		-- fry-cook spatula raised high: handle, metal neck and a wide slotted blade, a soap bubble glowing at the tip
		local sf = grip * CFrame.Angles(0.85, 0, 0)
		tpart(U.Cyl(0.8, 0.17, sf * CFrame.new(0, 0, -0.12) * U.AxisZ, Color3.fromRGB(150, 60, 50), model)) -- handle
		tpart(U.Block(Vector3.new(0.1, 0.06, 0.55), sf * CFrame.new(0, 0, -0.78), tc, model, METAL_MAT)) -- neck
		local bf = sf * CFrame.new(0, 0, -1.4) * CFrame.Angles(math.pi / 2, 0, 0)
		tpart(U.Block(Vector3.new(0.82, 0.05, 0.8), bf, tc, model, METAL_MAT)) -- blade
		for _, x in { -0.18, 0, 0.18 } do
			tpart(U.Block(Vector3.new(0.07, 0.055, 0.46), bf * CFrame.new(x, 0, 0.02), Color3.fromRGB(60, 60, 70), model)) -- slots
		end
		muzzle = tpart(U.Ball(0.2, sf * CFrame.new(0.2, 0.15, -1.9), beam, model, NEON))
		tipWorld = sf * CFrame.new(0.2, 0.15, -2.0)
	elseif tool == "Longboard" then
		-- surfboard held upright at his side: long board with rounded ends, a bright stripe, fin, a glint at the nose
		local bf = grip * CFrame.Angles(0.3, 0, 0) * CFrame.new(0.4, 0.55, -0.05)
		local stripe = Color3.fromRGB(255, 120, 90)
		tpart(U.Block(Vector3.new(0.82, 2.2, 0.12), bf, tc, model))
		for _, y in { -1.1, 1.1 } do
			tpart(U.Cyl(0.12, 0.82, bf * CFrame.new(0, y, 0) * U.AxisZ, tc, model)) -- rounded nose / tail
		end
		tpart(U.Block(Vector3.new(0.18, 2.9, 0.13), bf, stripe, model)) -- stripe
		tpart(U.Wedge(Vector3.new(0.06, 0.3, 0.3), bf * CFrame.new(0, -1.05, 0.2) * CFrame.Angles(0, math.pi, 0), U.Shade(tc, 0.6), model)) -- fin
		muzzle = tpart(U.Ball(0.16, bf * CFrame.new(0, 1.5, -0.05), beam, model, NEON))
		tipWorld = bf * CFrame.new(0, 1.6, 0)
	elseif tool == "Paddle" then
		-- carved canoe paddle held upright: shaft, knob grip, leaf blade with a carved stripe, glow at the tip
		local pf = grip * CFrame.Angles(0.15, 0, -0.35)
		tpart(U.Cyl(2.1, 0.13, pf * CFrame.new(0, 0.45, 0) * U.AxisY, tc, model))
		tpart(U.Ball(0.22, pf * CFrame.new(0, -0.6, 0), U.Shade(tc, 0.75), model)) -- knob
		tpart(U.Block(Vector3.new(0.52, 1.0, 0.08), pf * CFrame.new(0, 1.85, 0), tc, model)) -- blade
		for _, s in { -1, 1 } do
			tpart(U.Wedge(Vector3.new(0.08, 0.4, 0.26), pf * CFrame.new(0.13 * s, 2.55, 0) * CFrame.Angles(0, s * math.pi / 2, 0), tc, model)) -- leaf tip
		end
		tpart(U.Block(Vector3.new(0.54, 0.1, 0.09), pf * CFrame.new(0, 1.55, 0), Color3.fromRGB(180, 70, 50), model)) -- carving
		tpart(U.Block(Vector3.new(0.1, 0.7, 0.09), pf * CFrame.new(0, 1.95, 0), U.Shade(tc, 0.7), model))
		muzzle = tpart(U.Ball(0.16, pf * CFrame.new(0, 2.8, 0), beam, model, NEON))
		tipWorld = pf * CFrame.new(0, 2.85, 0)
	elseif tool == "GhostNet" then
		-- long-handled fishing net: pole, gold hoop, see-through net bag with a little caught ghost glowing in it
		local pf = grip * CFrame.Angles(0, -1.25, 0) * CFrame.Angles(1.1, 0, 0)
		tpart(U.Cyl(2.3, 0.12, pf * CFrame.new(0, 0, -0.85) * U.AxisZ, Color3.fromRGB(150, 110, 70), model)) -- pole
		local rc = pf * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.pi / 2, 0, 0)
		for _, p in U.Hoop(0.5, 0.09, 0.09, 8, rc, tc, model, METAL_MAT) do
			tpart(p)
		end
		tpart(U.Ball(0.95, pf * CFrame.new(0, -0.3, -2.5), Color3.fromRGB(200, 230, 240), model, { Transparency = 0.55, Shadow = false })) -- net bag
		muzzle = tpart(U.Ball(0.34, pf * CFrame.new(0, -0.35, -2.5), beam, model, NEON)) -- the caught ghost
		tipWorld = pf * CFrame.new(0, 0, -3.0)
	elseif tool == "CoralStaff" then
		-- staff of pink coral: branches cradling a big glowing pearl
		local up = CFrame.Angles(0.05, 0, -0.5)
		local light = U.Mix(tc, WHITE, 0.35)
		tpart(U.Cyl(3.0, 0.18, grip * up * CFrame.new(0, 0.55, 0) * U.AxisY, U.Shade(tc, 0.8), model))
		for _, q in { Vector3.new(-0.32, 0.55, 0), Vector3.new(0.32, 0.55, 0), Vector3.new(0, 0.6, 0.3) } do
			local p0 = (grip * up * CFrame.new(0, 1.85, 0)).Position
			local p1 = (grip * up * CFrame.new(q + Vector3.new(0, 1.85, 0))).Position
			tpart(U.Cyl((p1 - p0).Magnitude, 0.12, U.Between(p0, p1), light, model))
		end
		muzzle = tpart(U.Ball(0.4, grip * up * CFrame.new(0, 2.35, 0), beam, model, NEON)) -- pearl
		tipWorld = grip * up * CFrame.new(0, 2.35, 0)
	elseif tool == "BoxerGlove" then
		-- big padded boxing glove, fist forward: knuckle bulge, thumb, white cuff with a stripe, a spark on the knuckles
		local gf = T(0, 0.05, -0.25)
		tpart(U.Ball(0.92, gf, tc, model))
		tpart(U.Ball(0.66, gf * CFrame.new(0, 0.03, -0.3), tc, model)) -- knuckles
		tpart(U.Ball(0.38, gf * CFrame.new(-0.36, 0.1, -0.12), U.Shade(tc, 0.9), model)) -- thumb
		tpart(U.Cyl(0.42, 0.62, gf * CFrame.new(0, -0.02, 0.48) * U.AxisZ, WHITE, model)) -- cuff
		tpart(U.Cyl(0.08, 0.64, gf * CFrame.new(0, -0.02, 0.36) * U.AxisZ, tc, model))
		muzzle = tpart(U.Ball(0.14, gf * CFrame.new(0, 0.06, -0.62), beam, model, NEON))
		tipWorld = gf * CFrame.new(0, 0.06, -0.7)
	else -- Flashlight (default)
		tpart(U.Cyl(1.2, 0.36, T(0, 0, -0.3) * U.AxisZ, U.Shade(tc, 0.7), model))
		tpart(U.Cyl(0.38, 0.62, T(0, 0, -1.05) * U.AxisZ, tc, model))
		muzzle = tpart(U.Cyl(0.06, 0.5, T(0, 0, -1.25) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0, -1.3)
	end
	local tip = U.AttachAt(muzzle, "Tip", tipWorld)
	if tool == "RedCard" or tool == "BiscuitBox" then
		-- referees and coaches wear a whistle on a cord
		for _, s in { -1, 1 } do
			bar(torso, Vector3.new(0.3 * s, 0.53, -0.36), Vector3.new(0.04 * s, 0.05, -0.46), 0.05, 0.03, Color3.fromRGB(40, 40, 50))
		end
		cyl(torso, 0.22, 0.15, CFrame.new(0, -0.02, -0.5) * U.AxisZ, Color3.fromRGB(200, 205, 215), METAL_MAT)
		ball(torso, 0.16, CFrame.new(0.06, -0.05, -0.45), Color3.fromRGB(200, 205, 215), METAL_MAT)
	end

	------------------------------------------------------------------ look flags
	if lookX.Chrome == true then
		-- mirror people: polished metal body, head and hands
		for _, b in { torso, head, arms[-1], arms[1], legs[-1], legs[1], hands[-1], hands[1] } do
			b.Material = Enum.Material.Metal
			b.Reflectance = 0.3
		end
	end
	if lookX.Signature then
		-- one-of-a-kind finish (only Nova has one): star motes orbiting the body. The beam colour
		-- cycle and the reveal flash read the model's "Signature" attribute.
		model:SetAttribute("Signature", lookX.Signature)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Signature"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.5, GOLD),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 120, 255)),
		})
		pe.LightEmission = 0.6
		pe.Rate = 8
		pe.Lifetime = NumberRange.new(1.2, 1.8)
		pe.Speed = NumberRange.new(0.6, 1.0)
		pe.SpreadAngle = Vector2.new(180, 20)
		pe.RotSpeed = NumberRange.new(-120, 120)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Acceleration = Vector3.new(0, 0.4, 0)
		pe.Parent = torso
	end

	-- EXCLUSIVES (world2c): shared "Exclusive" flair of the World 2 Exclusive-crate hunters: a small
	-- cyan crystal floating above the right temple on a gold setting, a little magenta twin gem (no Neon), plus a slow
	-- cyan/magenta sparkle. The "ExclusiveGem" attribute lets a client spin it if it wants to.
	local exclusiveW2 = set({ "LanternMarket", "PhantomLibrary", "PumpkinFarm", "Glowshroom", "WaterPark", "MirrorMaze", "ShoppingMall", "GhostSubway",
		"DinoMuseum", "Stadium", "NeonCity", "GiantsKitchen", "CyberArcade", "StormIslands", "MoonBase", "VoidThrone" })
	if def.Rarity == "Exclusive" and exclusiveW2[def.Zone] then
		local gc = CFrame.new(1.45, 1.45, -0.1)
		local cyan = if rarity then rarity.Color else Color3.fromRGB(80, 255, 230)
		local pink = if rarity then rarity.Color2 else Color3.fromRGB(255, 90, 230)
		local gem = block(head, Vector3.new(0.34, 0.34, 0.34), gc * U.VertexUp, cyan, { Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.35 })
		gem.Name = "ExclusiveGem"
		cyl(head, 0.07, 0.36, gc * CFrame.new(0, -0.22, 0) * U.AxisY, GOLD, METAL_MAT) -- gold setting
		block(head, Vector3.new(0.16, 0.16, 0.16), gc * CFrame.new(0, 0.34, 0) * U.VertexUp, pink, { Reflectance = 0.35 }) -- little twin gem
		model:SetAttribute("ExclusiveGem", true)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "ExclusiveSparkle"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(cyan, pink)
		pe.LightEmission = 0.4
		pe.Rate = 4
		pe.Lifetime = NumberRange.new(0.8, 1.3)
		pe.Speed = NumberRange.new(0.2, 0.5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Parent = gem
	end

	------------------------------------------------------------------ finish
	local top = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			top = math.max(top, U.TopY(d))
		end
	end

	local rig: Rig = {
		Model = model,
		Root = root,
		Motors = motors,
		Tip = tip,
		Height = top,
		HunterId = hunterId,
	}
	HunterRig.Pose(rig, "Idle", 0, 1)
	return rig, decos
end

function HunterRig.Build(hunterId: string): Rig
	local rig = buildInternal(hunterId)
	return rig
end

------------------------------------------------------------------ procedural poses
local sin, cos, abs, max = math.sin, math.cos, math.abs, math.max
local CFn, CFa = CFrame.new, CFrame.Angles
local AIM = math.pi / 6 -- arm pitch that levels the tool (the grip is tilted -30 degrees)

function HunterRig.Pose(rig: Rig, state: string, t: number, blend: number?)
	local b = if blend == nil then 1 else math.clamp(blend, 0, 1)
	local m = rig.Motors
	local torso, head, la, ra, ll, rl = m.Torso, m.Head, m.LeftArm, m.RightArm, m.LeftLeg, m.RightLeg

	if state == "Run" then
		local w = t * 13
		local s = sin(w)
		local lean = -0.22 * b
		local twist = 0.15 * s * b
		torso.Transform = CFn(0, abs(cos(w)) * 0.22 * b, 0) * CFa(lean, twist, 0)
		-- legs cancel the torso lean/twist so they swing from an upright hip
		local legBase = CFa(0, -twist, 0)
		ll.Transform = legBase * CFa(-lean + 0.95 * s * b, 0, 0)
		rl.Transform = legBase * CFa(-lean - 0.95 * s * b, 0, 0)
		la.Transform = CFa(-0.9 * s * b, 0, -0.12 * b)
		ra.Transform = CFa((0.4 + 0.3 * s) * b, 0, 0.1 * b)
		head.Transform = CFa(-lean * 0.6 + 0.05 * cos(2 * w) * b, -twist * 0.7, 0)
	elseif state == "Attack" then
		local ph = (t * 4) % 1
		local p = (1 - ph) * (1 - ph) * (1 - ph) -- recoil pulse, 4 Hz
		local jx = 0.015 * sin(t * 57) * b
		local jy = 0.015 * sin(t * 43) * b
		local lean = (-0.12 + 0.1 * p) * b
		torso.Transform = CFn(jx, jy, 0.06 * p * b) * CFa(lean, 0, 0)
		ll.Transform = CFa(-lean + 0.28 * b, 0, -0.12 * b)
		rl.Transform = CFa(-lean - 0.22 * b, 0, 0.12 * b)
		ra.Transform = CFa((AIM + 0.18 * p) * b - lean, 0, 0.04 * b)
		la.Transform = CFa((1.15 + 0.1 * p) * b - lean, 0, 0.45 * b)
		head.Transform = CFa(0.06 * b - lean * 0.5 + jy, 0, 0)
	elseif state == "Celebrate" then
		local w = t * 3.6
		local j = abs(sin(w))
		torso.Transform = CFn(0, 0.65 * j * b, 0) * CFa(-0.08 * b, 0.5 * sin(t * 2.4) * b, 0)
		ll.Transform = CFa(0.35 * j * b, 0, -0.15 * j * b)
		rl.Transform = CFa(-0.25 * j * b, 0, 0.15 * j * b)
		la.Transform = CFa(0, 0, (-2.5 - 0.25 * sin(t * 8)) * b)
		ra.Transform = CFa(0.2 * b, 0, (1.7 + 0.8 * max(0, sin(t * 7.2))) * b)
		head.Transform = CFa((-0.18 + 0.05 * sin(w * 2)) * b, 0, 0.12 * sin(w) * b)
	else -- Idle
		local br = sin(t * 2.2)
		torso.Transform = CFn(0, 0.03 * br * b, 0) * CFa(0.025 * br * b, 0, 0)
		head.Transform = CFa(0.04 * sin(t * 1.3) * b, 0.15 * sin(t * 0.6) * b, 0.05 * sin(t * 0.9) * b)
		la.Transform = CFa(0.06 * sin(t * 2.2 + 0.6) * b, 0, -(0.12 + 0.04 * br) * b)
		ra.Transform = CFa((0.22 + 0.05 * br) * b, 0, (0.1 + 0.03 * br) * b)
		ll.Transform = CFa(0, 0, -0.04 * b)
		rl.Transform = CFa(0, 0, 0.04 * b)
	end
end

------------------------------------------------------------------ tier look
-- Shiny (1): gold-tinted glossy finish on everything solid + gold sparkles.
-- Mega (2): pearly finish, a cyan/magenta crown-halo over the head and a rising cyan/magenta
-- ring of motes at the feet. Size (x1.2 for Mega) is left to the caller's ScaleTo.
-- Works on both Build() rigs (parts get welded) and BuildStatic() copies (parts get anchored).
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local MEGA_A = Color3.fromRGB(120, 230, 255)
local MEGA_B = Color3.fromRGB(255, 110, 230)

local function emitter(parent: BasePart, color: ColorSequence, rate: number, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "TierFx"
	e.Texture = SPARKLE
	e.Color = color
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.7, 1.2)
	e.Speed = NumberRange.new(0.5, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Size = NumberSequence.new(size, 0)
	e.Parent = parent
	return e
end

function HunterRig.ApplyTier(model: Model, tier: number)
	if tier <= 0 then
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local root = model.PrimaryPart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 0.3 and p.Material ~= Enum.Material.Neon then
			if tier == 1 then
				p.Color = U.Mix(p.Color, GOLD, 0.22)
				p.Reflectance = math.max(p.Reflectance, 0.3)
			else
				p.Color = U.Mix(p.Color, WHITE, 0.08)
				p.Reflectance = math.max(p.Reflectance, 0.18)
			end
		end
	end
	if tier == 1 then
		if torso then
			emitter(torso, ColorSequence.new(GOLD), 4, 0.4)
		end
		return
	end
	-- static copies are fully anchored (head too); live rigs only anchor Root, so weld instead
	local static = head ~= nil and head.Anchored
	local function attach(base: BasePart, p: BasePart)
		p.Name = "TierFx"
		if static then
			p.Anchored = true
		else
			U.FixedWeld(base, p)
		end
	end
	if head then
		-- crown-halo floating just above whatever the head wears
		local top = U.TopY(head)
		for _, w in model:GetDescendants() do
			if w:IsA("Weld") and w.Part0 == head and w.Part1 then
				top = math.max(top, U.TopY(w.Part1 :: BasePart))
			end
		end
		local hcf = head.CFrame * CFrame.new(0, top - head.Position.Y + 0.35, 0.1)
		local glow = { Material = Enum.Material.Neon, Shadow = false }
		for i, p in U.Hoop(0.72, 0.12, 0.12, 10, hcf * CFrame.Angles(math.pi / 2, 0, 0), MEGA_A, model, glow) do
			if i % 2 == 0 then
				p.Color = MEGA_B
			end
			attach(head, p)
		end
		for i = 0, 4 do
			local gem = U.Block(Vector3.new(0.2, 0.2, 0.2), hcf * CFrame.Angles(0, i * 2 * math.pi / 5, 0) * CFrame.new(0, 0.18, -0.78) * U.VertexUp, MEGA_B, model, glow)
			attach(head, gem)
		end
	end
	if root then
		local ring = U.Block(Vector3.new(3.4, 0.1, 3.4), root.CFrame * CFrame.new(0, 0.1, 0), WHITE, model, { Transparency = 1, Shadow = false })
		attach(root, ring)
		local e = emitter(ring, ColorSequence.new(MEGA_A, MEGA_B), 10, 0.35)
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.SpreadAngle = Vector2.new(0, 0)
		e.EmissionDirection = Enum.NormalId.Top
	end
end

------------------------------------------------------------------ portrait copy
-- Anchored, posed model for ViewportFrames (no physics runs there, so joints are solved here).
function HunterRig.BuildStatic(hunterId: string): Model
	local rig, decos = buildInternal(hunterId)
	HunterRig.Pose(rig, "Idle", 0.45, 1)
	for _, name in JOINT_ORDER do
		local mo = rig.Motors[name]
		local p0, p1 = mo.Part0, mo.Part1
		if p0 and p1 then
			p1.CFrame = p0.CFrame * mo.C0 * mo.Transform * mo.C1:Inverse()
		end
	end
	for b, list in decos do
		for _, d in list do
			d.Part.CFrame = b.CFrame * d.Offset
		end
	end
	for _, d in rig.Model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return rig.Model
end

return HunterRig
