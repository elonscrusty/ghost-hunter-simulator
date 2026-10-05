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
	HairStyle = set({ "Spiky", "Bob", "Puff", "Short", "Long", "None", "RoundEars", "PointyEars", "Buns", "Braids", "Floaty", "Beard", "Owl", "Octo" }),
	Hat = set({
		"Cap", "Beanie", "Fedora", "Hood", "Helmet", "Mortarboard", "Visor", "Goggles", "Halo", "TopHat", "Jester",
		"NurseCap", "HeadMirror", "SailorCap", "Bandana", "Tricorn", "KnightHelm", "Wizard", "Crown", "Crystal", "Pith",
		"Earmuffs", "Nemes", "Propeller", "DivingHelmet", "Gears", "Bow", "WitchHat", "PumpkinHelm", "FlowerHead",
		"HeroMask", "Tiara", "MoonHood",
		-- World 2
		"ChefHat", "LanternRing", "Specs", "BookHat", "Roof", "ShroomCap", "ShroomCrown", "PrismCrown", "ConductorCap",
		"Headphones", "TVHead", "StormCloud", "SpaceHelmet", "EarHood", "StarCrown",
		"Nightcap", "BookHead", "WeatherVane", "HardHat", "SkyTricorn", "BirdMask", "TempestCrown",
	}),
	Back = set({
		"Backpack", "Tank", "Cape", "Wings", "Antenna", "Balloons", "MedKit", "LifeRing", "Shield", "Orbs", "HeroCape",
		"BatWings", "HeartWings",
		-- World 2
		"LanternPole", "FireworkRack", "BookWings", "Rings", "MirrorShards", "Shell", "Smokestack", "Boombox", "Glider",
		"StormWings", "Jetpack", "CometTail", "StretchyDog", "VoidRing",
		"BookStack", "BookCart", "PopUpCastle", "Tentacles", "Pages", "RuneBooks", "CloudSheep", "HotAirBalloon",
		"RainbowScarf", "Battery", "ShipWheel", "Cyclone", "FeatherWings",
	}),
	Tool = set({
		"Flashlight", "Vacuum", "Scanner", "Blaster", "Cannon", "Lantern", "Staff", "Projector", "Megaphone", "Wand", "Orb",
		"Spyglass", "Sword", "Trident", "Wrench", "HeartWand", "MoonStaff", "PumpkinLance",
		-- World 2
		"FryingPan", "SteamBasket", "Spellbook", "Quill", "Umbrella", "Magnet", "Teapot", "HandMirror", "Kaleidoscope",
		"Guitar", "Hammer", "Thunderbolt", "RayGun", "StarBlade",
		"Candle", "Stamp", "Magnifier", "BookStaff", "Anemometer", "Crook", "Pinwheel",
	}),
	Signature = set({ "Supernova" }),
}

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
	if hat ~= "TVHead" and hat ~= "BookHead" then -- the TV and the book draw their own faces
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
		if hat ~= "FlowerHead" and style ~= "Beard" and style ~= "Owl" then
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
	else -- Flashlight (default)
		tpart(U.Cyl(1.2, 0.36, T(0, 0, -0.3) * U.AxisZ, U.Shade(tc, 0.7), model))
		tpart(U.Cyl(0.38, 0.62, T(0, 0, -1.05) * U.AxisZ, tc, model))
		muzzle = tpart(U.Cyl(0.06, 0.5, T(0, 0, -1.25) * U.AxisZ, beam, model, NEON))
		tipWorld = T(0, 0, -1.3)
	end
	local tip = U.AttachAt(muzzle, "Tip", tipWorld)

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
