--!strict
-- GHOST HUNTER SIMULATOR: every tuning number, every content entry and the world layout.
-- Nothing else in the game should hold balance values. Adding Zone 4 = add a Zones entry,
-- its Ghosts, its Hunters, its Crate and a Layout block (see docs/ADDING_CONTENT.md).

local Config = {}

Config.Version = "1.0.0"
Config.DataStoreName = "GhostHunterData_v1"
Config.DataSchemaVersion = 1

--==================================================================
-- RARITIES (ordered weakest → strongest; disabled ones are ready for later)
--==================================================================
export type RarityDef = {
	Id: string,
	Name: string,
	Order: number,
	Color: Color3,
	Color2: Color3, -- gradient partner for cards / reveal
	Enabled: boolean,
	-- crate reveal tuning
	RevealPause: number, -- seconds of build-up before the lid pops
	ShakeIntensity: number,
	Particles: number, -- burst count
	Darken: number, -- 0..1 screen darken during build-up
	CameraPunch: boolean,
	Announce: boolean, -- server-wide chat banner
	Sound: string, -- key into Sounds
}

Config.Rarities = {
	Common = {
		Id = "Common", Name = "COMMON", Order = 1, Enabled = true,
		Color = Color3.fromRGB(176, 190, 210), Color2 = Color3.fromRGB(120, 135, 160),
		RevealPause = 0.0, ShakeIntensity = 0.15, Particles = 25, Darken = 0, CameraPunch = false, Announce = false,
		Sound = "RevealCommon",
	},
	Uncommon = {
		Id = "Uncommon", Name = "UNCOMMON", Order = 2, Enabled = true,
		Color = Color3.fromRGB(90, 230, 120), Color2 = Color3.fromRGB(30, 170, 90),
		RevealPause = 0.25, ShakeIntensity = 0.25, Particles = 45, Darken = 0, CameraPunch = false, Announce = false,
		Sound = "RevealCommon",
	},
	Rare = {
		Id = "Rare", Name = "RARE", Order = 3, Enabled = true,
		Color = Color3.fromRGB(70, 170, 255), Color2 = Color3.fromRGB(120, 90, 255),
		RevealPause = 0.6, ShakeIntensity = 0.4, Particles = 80, Darken = 0.2, CameraPunch = true, Announce = false,
		Sound = "RevealRare",
	},
	Epic = {
		Id = "Epic", Name = "EPIC", Order = 4, Enabled = false,
		Color = Color3.fromRGB(190, 90, 255), Color2 = Color3.fromRGB(255, 80, 200),
		RevealPause = 0.9, ShakeIntensity = 0.5, Particles = 110, Darken = 0.3, CameraPunch = true, Announce = false,
		Sound = "RevealRare",
	},
	Legendary = {
		Id = "Legendary", Name = "LEGENDARY", Order = 5, Enabled = true,
		Color = Color3.fromRGB(255, 196, 40), Color2 = Color3.fromRGB(255, 110, 40),
		RevealPause = 1.6, ShakeIntensity = 0.7, Particles = 160, Darken = 0.45, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
	Mythic = {
		Id = "Mythic", Name = "MYTHIC", Order = 6, Enabled = false,
		Color = Color3.fromRGB(255, 70, 110), Color2 = Color3.fromRGB(255, 160, 60),
		RevealPause = 2.0, ShakeIntensity = 0.8, Particles = 200, Darken = 0.55, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
	Secret = {
		Id = "Secret", Name = "SECRET", Order = 7, Enabled = false,
		Color = Color3.fromRGB(30, 30, 40), Color2 = Color3.fromRGB(240, 240, 255),
		RevealPause = 2.4, ShakeIntensity = 0.9, Particles = 220, Darken = 0.7, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
	Exclusive = {
		Id = "Exclusive", Name = "EXCLUSIVE", Order = 8, Enabled = false,
		Color = Color3.fromRGB(80, 255, 230), Color2 = Color3.fromRGB(255, 90, 230),
		RevealPause = 2.0, ShakeIntensity = 0.8, Particles = 200, Darken = 0.5, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
} :: { [string]: RarityDef }

--==================================================================
-- ZONES (Order defines the progression path; Cost is Ectoplasm)
--==================================================================
export type ZoneDef = {
	Id: string,
	Name: string,
	Order: number,
	Cost: number,
	Crate: string,
	-- visuals the client blends to when the player is inside the zone
	Ambient: Color3,
	FogColor: Color3,
	Accent: Color3,
	-- Z range of the zone on the world path (used for "which zone am I in")
	MinZ: number,
	MaxZ: number,
}

Config.Zones = {
	{
		Id = "Neighborhood", Name = "HAUNTED NEIGHBORHOOD", Order = 1, Cost = 0, Crate = "Beginner",
		Ambient = Color3.fromRGB(150, 120, 200), FogColor = Color3.fromRGB(120, 80, 170), Accent = Color3.fromRGB(150, 255, 120),
		MinZ = -60, MaxZ = 260,
	},
	{
		Id = "Cemetery", Name = "CEMETERY", Order = 2, Cost = 1500, Crate = "Haunted",
		Ambient = Color3.fromRGB(120, 150, 190), FogColor = Color3.fromRGB(90, 70, 150), Accent = Color3.fromRGB(80, 255, 170),
		MinZ = 260, MaxZ = 540,
	},
	{
		Id = "School", Name = "HAUNTED SCHOOL", Order = 3, Cost = 40000, Crate = "Elite",
		Ambient = Color3.fromRGB(160, 130, 210), FogColor = Color3.fromRGB(70, 50, 120), Accent = Color3.fromRGB(190, 110, 255),
		MinZ = 540, MaxZ = 880,
	},
} :: { ZoneDef }

Config.ZoneById = {} :: { [string]: ZoneDef }
for _, z in Config.Zones do
	Config.ZoneById[z.Id] = z
end

--==================================================================
-- GHOSTS (Spirit = health; Reward = Ectoplasm range BEFORE bonuses)
--==================================================================
export type GhostDef = {
	Id: string,
	Name: string,
	Zone: string,
	Spirit: number,
	Reward: { number }, -- {min, max}
	Drops: number, -- how many physical orbs the reward is split into
	Respawn: number, -- seconds
	Scale: number,
	Hover: number, -- studs above ground
	Speed: number, -- wander studs/second
	Wander: number, -- seconds between new wander points
	Kind: string, -- "Normal" | "MiniBoss" | "Boss" | "Event"
	Color: Color3,
	Glow: Color3,
	Style: string, -- visual accessory set (GhostRig)
}

Config.Ghosts = {
	-- ZONE 1
	WanderingSpirit = {
		Id = "WanderingSpirit", Name = "WANDERING SPIRIT", Zone = "Neighborhood",
		Spirit = 30, Reward = { 4, 6 }, Drops = 3, Respawn = 4, Scale = 1, Hover = 5, Speed = 5, Wander = 3.5,
		Kind = "Normal", Color = Color3.fromRGB(235, 240, 255), Glow = Color3.fromRGB(150, 255, 200), Style = "Plain",
	},
	MischiefGhost = {
		Id = "MischiefGhost", Name = "MISCHIEF GHOST", Zone = "Neighborhood",
		Spirit = 140, Reward = { 15, 21 }, Drops = 4, Respawn = 6, Scale = 1.3, Hover = 5.5, Speed = 7, Wander = 2.5,
		Kind = "Normal", Color = Color3.fromRGB(200, 160, 255), Glow = Color3.fromRGB(255, 120, 220), Style = "Mischief",
	},
	NeighborhoodPoltergeist = {
		Id = "NeighborhoodPoltergeist", Name = "NEIGHBORHOOD POLTERGEIST", Zone = "Neighborhood",
		Spirit = 700, Reward = { 80, 100 }, Drops = 8, Respawn = 15, Scale = 2.2, Hover = 7, Speed = 4, Wander = 4,
		Kind = "MiniBoss", Color = Color3.fromRGB(130, 255, 180), Glow = Color3.fromRGB(80, 255, 140), Style = "Poltergeist",
	},
	-- ZONE 2
	GraveSpirit = {
		Id = "GraveSpirit", Name = "GRAVE SPIRIT", Zone = "Cemetery",
		Spirit = 900, Reward = { 60, 80 }, Drops = 4, Respawn = 5, Scale = 1.2, Hover = 5, Speed = 5, Wander = 3.5,
		Kind = "Normal", Color = Color3.fromRGB(190, 255, 230), Glow = Color3.fromRGB(60, 255, 170), Style = "Grave",
	},
	CryptGhost = {
		Id = "CryptGhost", Name = "CRYPT GHOST", Zone = "Cemetery",
		Spirit = 2600, Reward = { 160, 200 }, Drops = 5, Respawn = 8, Scale = 1.5, Hover = 6, Speed = 5, Wander = 3,
		Kind = "Normal", Color = Color3.fromRGB(240, 225, 190), Glow = Color3.fromRGB(255, 200, 90), Style = "Crypt",
	},
	GraveyardWarden = {
		Id = "GraveyardWarden", Name = "GRAVEYARD WARDEN", Zone = "Cemetery",
		Spirit = 9500, Reward = { 620, 720 }, Drops = 10, Respawn = 18, Scale = 2.5, Hover = 7.5, Speed = 3.5, Wander = 4.5,
		Kind = "MiniBoss", Color = Color3.fromRGB(120, 110, 200), Glow = Color3.fromRGB(110, 255, 160), Style = "Warden",
	},
	-- ZONE 3
	HallwayHaunt = {
		Id = "HallwayHaunt", Name = "HALLWAY HAUNT", Zone = "School",
		Spirit = 12000, Reward = { 720, 900 }, Drops = 5, Respawn = 6, Scale = 1.4, Hover = 5, Speed = 6, Wander = 3,
		Kind = "Normal", Color = Color3.fromRGB(255, 220, 150), Glow = Color3.fromRGB(255, 150, 80), Style = "Hallway",
	},
	PossessedStudent = {
		Id = "PossessedStudent", Name = "POSSESSED STUDENT SPIRIT", Zone = "School",
		Spirit = 32000, Reward = { 1800, 2200 }, Drops = 6, Respawn = 9, Scale = 1.7, Hover = 5.5, Speed = 6.5, Wander = 2.8,
		Kind = "Normal", Color = Color3.fromRGB(160, 230, 255), Glow = Color3.fromRGB(190, 110, 255), Style = "Student",
	},
	HeadmasterPhantom = {
		Id = "HeadmasterPhantom", Name = "HEADMASTER PHANTOM", Zone = "School",
		Spirit = 130000, Reward = { 7200, 8400 }, Drops = 14, Respawn = 25, Scale = 3, Hover = 8, Speed = 3, Wander = 5,
		Kind = "Boss", Color = Color3.fromRGB(170, 120, 255), Glow = Color3.fromRGB(255, 80, 200), Style = "Headmaster",
	},
	-- EVENT (scaled at spawn time by Config.Event)
	GiantPoltergeist = {
		Id = "GiantPoltergeist", Name = "GIANT POLTERGEIST", Zone = "Neighborhood",
		Spirit = 6000, Reward = { 0, 0 }, Drops = 0, Respawn = 0, Scale = 6, Hover = 14, Speed = 4, Wander = 5,
		Kind = "Event", Color = Color3.fromRGB(255, 120, 230), Glow = Color3.fromRGB(255, 230, 90), Style = "Giant",
	},
} :: { [string]: GhostDef }

--==================================================================
-- GHOST HUNTERS (Power = Capture Power per second)
--==================================================================
export type HunterLook = {
	Skin: Color3,
	Hair: Color3,
	HairStyle: string, -- Spiky | Bob | Puff | Short | Long | None
	Shirt: Color3,
	Pants: Color3,
	Shoes: Color3,
	Hat: string?, -- Cap | Beanie | Fedora | Hood | Helmet | Mortarboard | Visor | Goggles | Halo
	HatColor: Color3?,
	Back: string?, -- Backpack | Tank | Cape | Wings | Antenna
	BackColor: Color3?,
	Tool: string, -- Flashlight | Vacuum | Scanner | Blaster | Cannon | Lantern | Staff | Projector
	ToolColor: Color3,
	Beam: Color3, -- attack beam colour
	Aura: boolean?, -- extra sparkle for high rarities
}

export type HunterDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Zone: string,
	Power: number,
	Blurb: string,
	Look: HunterLook,
}

local C = Color3.fromRGB
Config.Hunters = {
	-- ZONE 1: Beginner crate
	RookieHunter = {
		Id = "RookieHunter", Name = "Rookie Hunter", Rarity = "Common", Zone = "Neighborhood", Power = 5,
		Blurb = "First day on the job. Brought a flashlight and a lot of courage.",
		Look = { Skin = C(255, 214, 170), Hair = C(120, 70, 40), HairStyle = "Spiky", Shirt = C(255, 150, 40), Pants = C(60, 80, 140), Shoes = C(40, 40, 50),
			Hat = "Cap", HatColor = C(255, 90, 60), Tool = "Flashlight", ToolColor = C(250, 230, 90), Beam = C(255, 245, 160) },
	},
	ParanormalIntern = {
		Id = "ParanormalIntern", Name = "Paranormal Intern", Rarity = "Uncommon", Zone = "Neighborhood", Power = 9,
		Blurb = "Carries everyone's gear. Secretly the bravest one here.",
		Look = { Skin = C(200, 140, 100), Hair = C(30, 30, 40), HairStyle = "Puff", Shirt = C(90, 200, 120), Pants = C(70, 60, 50), Shoes = C(230, 230, 230),
			Hat = "Goggles", HatColor = C(80, 200, 255), Back = "Backpack", BackColor = C(255, 200, 60), Tool = "Vacuum", ToolColor = C(120, 230, 255), Beam = C(120, 255, 220) },
	},
	GhostInvestigator = {
		Id = "GhostInvestigator", Name = "Ghost Investigator", Rarity = "Rare", Zone = "Neighborhood", Power = 16,
		Blurb = "Has a scanner for everything. Even ghosts' feelings.",
		Look = { Skin = C(255, 200, 160), Hair = C(200, 60, 60), HairStyle = "Bob", Shirt = C(70, 110, 200), Pants = C(40, 40, 60), Shoes = C(120, 60, 30),
			Hat = "Fedora", HatColor = C(110, 80, 60), Back = "Antenna", BackColor = C(90, 90, 110), Tool = "Scanner", ToolColor = C(80, 220, 255), Beam = C(80, 200, 255) },
	},
	SpectralSpecialist = {
		Id = "SpectralSpecialist", Name = "Spectral Specialist", Rarity = "Legendary", Zone = "Neighborhood", Power = 40,
		Blurb = "Glows in the dark. On purpose.",
		Look = { Skin = C(240, 190, 150), Hair = C(255, 255, 255), HairStyle = "Long", Shirt = C(40, 30, 70), Pants = C(30, 25, 50), Shoes = C(150, 255, 200),
			Hat = "Visor", HatColor = C(140, 255, 200), Back = "Tank", BackColor = C(120, 255, 170), Tool = "Projector", ToolColor = C(160, 255, 210), Beam = C(110, 255, 190), Aura = true },
	},
	-- ZONE 2: Haunted crate
	GraveScout = {
		Id = "GraveScout", Name = "Grave Scout", Rarity = "Common", Zone = "Cemetery", Power = 30,
		Blurb = "Knows every path in the cemetery. Counts gravestones to fall asleep.",
		Look = { Skin = C(255, 220, 185), Hair = C(240, 200, 80), HairStyle = "Short", Shirt = C(110, 140, 70), Pants = C(80, 70, 50), Shoes = C(60, 40, 30),
			Hat = "Beanie", HatColor = C(90, 160, 90), Back = "Backpack", BackColor = C(150, 100, 60), Tool = "Lantern", ToolColor = C(120, 255, 160), Beam = C(140, 255, 150) },
	},
	CryptInvestigator = {
		Id = "CryptInvestigator", Name = "Crypt Investigator", Rarity = "Uncommon", Zone = "Cemetery", Power = 50,
		Blurb = "Has read every inscription. Twice.",
		Look = { Skin = C(170, 110, 80), Hair = C(50, 30, 30), HairStyle = "Bob", Shirt = C(150, 90, 50), Pants = C(60, 50, 40), Shoes = C(40, 30, 30),
			Hat = "Helmet", HatColor = C(230, 200, 90), Tool = "Flashlight", ToolColor = C(255, 220, 120), Beam = C(255, 230, 140) },
	},
	SpiritWarden = {
		Id = "SpiritWarden", Name = "Spirit Warden", Rarity = "Rare", Zone = "Cemetery", Power = 85,
		Blurb = "Guards the line between worlds. Takes lunch breaks in both.",
		Look = { Skin = C(230, 180, 140), Hair = C(60, 60, 90), HairStyle = "Spiky", Shirt = C(60, 60, 140), Pants = C(30, 30, 60), Shoes = C(200, 200, 230),
			Hat = "Hood", HatColor = C(80, 70, 170), Back = "Cape", BackColor = C(110, 80, 220), Tool = "Staff", ToolColor = C(150, 140, 255), Beam = C(150, 130, 255) },
	},
	PhantomExorcist = {
		Id = "PhantomExorcist", Name = "Phantom Exorcist", Rarity = "Legendary", Zone = "Cemetery", Power = 200,
		Blurb = "Ghosts leave the room when they hear their footsteps.",
		Look = { Skin = C(255, 225, 200), Hair = C(30, 20, 40), HairStyle = "Long", Shirt = C(250, 250, 255), Pants = C(40, 30, 60), Shoes = C(255, 210, 80),
			Hat = "Halo", HatColor = C(255, 230, 120), Back = "Wings", BackColor = C(255, 245, 220), Tool = "Cannon", ToolColor = C(255, 215, 90), Beam = C(255, 220, 110), Aura = true },
	},
	-- ZONE 3: Elite crate
	SchoolInvestigator = {
		Id = "SchoolInvestigator", Name = "School Investigator", Rarity = "Common", Zone = "School", Power = 150,
		Blurb = "Hall monitor by day, ghost hunter by... also day.",
		Look = { Skin = C(255, 205, 165), Hair = C(90, 50, 30), HairStyle = "Short", Shirt = C(230, 70, 70), Pants = C(50, 60, 90), Shoes = C(255, 255, 255),
			Hat = "Cap", HatColor = C(40, 60, 160), Back = "Backpack", BackColor = C(60, 180, 255), Tool = "Blaster", ToolColor = C(255, 120, 60), Beam = C(255, 140, 80) },
	},
	ParanormalProfessor = {
		Id = "ParanormalProfessor", Name = "Paranormal Professor", Rarity = "Uncommon", Zone = "School", Power = 250,
		Blurb = "Wrote the textbook on ghosts. Ghosts gave it two stars.",
		Look = { Skin = C(225, 170, 130), Hair = C(220, 220, 230), HairStyle = "Puff", Shirt = C(120, 80, 50), Pants = C(70, 60, 50), Shoes = C(60, 40, 30),
			Hat = "Mortarboard", HatColor = C(40, 40, 50), Tool = "Scanner", ToolColor = C(255, 170, 255), Beam = C(255, 150, 255) },
	},
	EliteContainmentAgent = {
		Id = "EliteContainmentAgent", Name = "Elite Containment Agent", Rarity = "Rare", Zone = "School", Power = 420,
		Blurb = "Shades on. Ghosts contained. No questions.",
		Look = { Skin = C(150, 100, 70), Hair = C(20, 20, 25), HairStyle = "Short", Shirt = C(35, 35, 45), Pants = C(30, 30, 40), Shoes = C(20, 20, 20),
			Hat = "Goggles", HatColor = C(255, 60, 90), Back = "Tank", BackColor = C(255, 60, 120), Tool = "Vacuum", ToolColor = C(255, 80, 140), Beam = C(255, 90, 160) },
	},
	VoidHunter = {
		Id = "VoidHunter", Name = "Void Hunter", Rarity = "Legendary", Zone = "School", Power = 1000,
		Blurb = "Came back from the other side with a souvenir cannon.",
		Look = { Skin = C(200, 180, 255), Hair = C(140, 60, 255), HairStyle = "Spiky", Shirt = C(25, 10, 50), Pants = C(15, 5, 35), Shoes = C(190, 90, 255),
			Hat = "Hood", HatColor = C(40, 10, 80), Back = "Wings", BackColor = C(150, 60, 255), Tool = "Cannon", ToolColor = C(190, 100, 255), Beam = C(200, 110, 255), Aura = true },
	},
} :: { [string]: HunterDef }

Config.StarterHunter = "RookieHunter"

--==================================================================
-- CRATES (Weights don't need to sum to 100; odds are shown as %)
--==================================================================
export type CrateDef = {
	Id: string,
	Name: string,
	Zone: string,
	Price: number,
	Color: Color3,
	Trim: Color3,
	Pool: { { Hunter: string, Weight: number } },
}

Config.Crates = {
	Beginner = {
		Id = "Beginner", Name = "BEGINNER HUNTER CRATE", Zone = "Neighborhood", Price = 25,
		Color = C(255, 150, 50), Trim = C(140, 255, 120),
		Pool = {
			{ Hunter = "RookieHunter", Weight = 60 },
			{ Hunter = "ParanormalIntern", Weight = 28 },
			{ Hunter = "GhostInvestigator", Weight = 10 },
			{ Hunter = "SpectralSpecialist", Weight = 2 },
		},
	},
	Haunted = {
		Id = "Haunted", Name = "HAUNTED HUNTER CRATE", Zone = "Cemetery", Price = 600,
		Color = C(110, 80, 200), Trim = C(90, 255, 180),
		Pool = {
			{ Hunter = "GraveScout", Weight = 60 },
			{ Hunter = "CryptInvestigator", Weight = 28 },
			{ Hunter = "SpiritWarden", Weight = 10 },
			{ Hunter = "PhantomExorcist", Weight = 2 },
		},
	},
	Elite = {
		Id = "Elite", Name = "ELITE HUNTER CRATE", Zone = "School", Price = 9000,
		Color = C(40, 30, 70), Trim = C(220, 120, 255),
		Pool = {
			{ Hunter = "SchoolInvestigator", Weight = 60 },
			{ Hunter = "ParanormalProfessor", Weight = 28 },
			{ Hunter = "EliteContainmentAgent", Weight = 10 },
			{ Hunter = "VoidHunter", Weight = 2 },
		},
	},
} :: { [string]: CrateDef }

-- Luck boost multiplies weights of these rarities (and above) by Boosts.Luck.Multiplier.
Config.LuckAffectsFromOrder = 3 -- Rare and higher

--==================================================================
-- INVENTORY
--==================================================================
Config.Inventory = {
	BaseSlots = 4, -- equipped hunters
	MaxHunters = 150, -- crate refuses to open when full
	ReleaseRefund = 0.1, -- fraction of the source crate price returned when a hunter is released
}

--==================================================================
-- COMBAT (server-authoritative damage)
--==================================================================
Config.Combat = {
	TickSeconds = 0.25, -- damage is applied in ticks of Power * TickSeconds
	EngageDelay = 0.6, -- hunters need this long to run to a new target before damage starts
	MaxRange = 90, -- player must be within this many studs of the target
	ContributorShare = 0.1, -- min share of max Spirit to receive personal drops (killer always does)
	HunterRunSpeed = 26, -- client visual
}

--==================================================================
-- ECTOPLASM DROPS + PICKUP RADIUS
--==================================================================
Config.Drops = {
	Lifetime = 45, -- seconds before an uncollected orb despawns
	ScatterMin = 3,
	ScatterMax = 9,
	PickupTick = 0.15, -- server checks pickups this often
	FlyTime = 0.35, -- client visual flight duration
	MaxPerPlayer = 250, -- safety cap on live orbs per player
}

--==================================================================
-- UPGRADES (Levels[i] = value at level i; Costs[i] = price to go from level i to i+1)
--==================================================================
export type UpgradeDef = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	Levels: { number },
	Costs: { number },
	Format: string, -- "studs" | "percent" | "speed"
}

Config.Upgrades = {
	PickupRadius = {
		Id = "PickupRadius", Name = "PICKUP RADIUS", Icon = "🧲",
		Description = "Ectoplasm flies to you from further away.",
		Levels = { 14, 19, 25, 33, 45 }, Costs = { 120, 900, 6000, 30000 }, Format = "studs",
	},
	EctoBonus = {
		Id = "EctoBonus", Name = "ECTOPLASM BONUS", Icon = "💚",
		Description = "Earn more Ectoplasm from every ghost.",
		Levels = { 0, 0.1, 0.2, 0.35, 0.5 }, Costs = { 300, 2500, 15000, 80000 }, Format = "percent",
	},
	MoveSpeed = {
		Id = "MoveSpeed", Name = "MOVEMENT SPEED", Icon = "👟",
		Description = "Run between ghosts faster.",
		Levels = { 16, 18, 20, 22, 24 }, Costs = { 200, 1500, 9000, 45000 }, Format = "speed",
	},
} :: { [string]: UpgradeDef }
Config.UpgradeOrder = { "PickupRadius", "EctoBonus", "MoveSpeed" }

--==================================================================
-- BOOSTS (temporary; from daily rewards and shop)
--==================================================================
Config.Boosts = {
	Ecto = { Name = "2x ECTOPLASM", Icon = "💚", Multiplier = 2 },
	Luck = { Name = "LUCKY CRATES", Icon = "🍀", Multiplier = 2 },
	MaxStackSeconds = 6 * 3600,
}

--==================================================================
-- DAILY REWARD (server os.time only)
--==================================================================
export type RewardDef = { Kind: string, Amount: number?, Boost: string?, Seconds: number?, Crate: string?, Label: string }

Config.Daily = {
	Cooldown = 20 * 3600, -- can claim again after this
	StreakReset = 48 * 3600, -- streak resets if you wait longer than this
	Rewards = {
		{ Kind = "Ecto", Amount = 50, Label = "50 ECTOPLASM" },
		{ Kind = "Ecto", Amount = 150, Label = "150 ECTOPLASM" },
		{ Kind = "Boost", Boost = "Luck", Seconds = 600, Label = "10 MIN LUCK" },
		{ Kind = "Ecto", Amount = 500, Label = "500 ECTOPLASM" },
		{ Kind = "Boost", Boost = "Ecto", Seconds = 900, Label = "15 MIN 2x ECTO" },
		{ Kind = "Ecto", Amount = 1500, Label = "1,500 ECTOPLASM" },
		{ Kind = "Day7", Amount = 5000, Crate = "Beginner", Boost = "Luck", Seconds = 1800, Label = "5,000 ECTO + FREE CRATE + 30 MIN LUCK" },
	} :: { RewardDef },
	-- Ecto rewards scale with your best unlocked zone so late players still care
	-- (roughly the ratio of typical farming income per zone).
	ZoneMultiplier = { 1, 6, 30 },
}

--==================================================================
-- GIANT POLTERGEIST EVENT
--==================================================================
Config.Event = {
	Ghost = "GiantPoltergeist",
	FirstDelay = 240, -- seconds after server start
	Interval = 600, -- seconds between events (end → next warning)
	WarningSeconds = 15,
	Duration = 180, -- seconds to defeat it before it escapes
	-- Spirit = Base + SpiritPerPower * sum(min(crew power, PowerCap) of players in server),
	-- i.e. ~60 s of everyone's combined crew power; a lone starter crew (~30) needs ~110 s.
	SpiritBase = 1500,
	SpiritPerPower = 60,
	PowerCap = 2500,
	-- Rewards (per participant): RewardBase * zoneMultiplier * clamp(share * players, MinShare, MaxShare)
	RewardBase = 400,
	MinShare = 0.35,
	MaxShare = 2.5,
	RewardDrops = 18,
	MinContribution = 0.01, -- share of Spirit you must deal to count as a participant
}

--==================================================================
-- SHOP (Robux). Fill in the IDs after creating products on the Creator Hub.
--==================================================================
export type ProductDef = { Key: string, Name: string, Icon: string, Kind: string, Amount: number?, Boost: string?, Seconds: number?, ProductId: number?, PriceLabel: string }
export type PassDef = { Key: string, Name: string, Icon: string, PassId: number?, PriceLabel: string, Slots: number?, Multiplier: number? }

Config.Products = {
	{ Key = "Ecto1", Name = "SACK OF ECTOPLASM", Icon = "💚", Kind = "Ecto", Amount = 2000, ProductId = nil, PriceLabel = "R$ 49" },
	{ Key = "Ecto2", Name = "BARREL OF ECTOPLASM", Icon = "🛢️", Kind = "Ecto", Amount = 12000, ProductId = nil, PriceLabel = "R$ 199" },
	{ Key = "Luck30", Name = "30 MIN LUCK BOOST", Icon = "🍀", Kind = "Boost", Boost = "Luck", Seconds = 1800, ProductId = nil, PriceLabel = "R$ 49" },
	{ Key = "Ecto30", Name = "30 MIN 2x ECTOPLASM", Icon = "⚡", Kind = "Boost", Boost = "Ecto", Seconds = 1800, ProductId = nil, PriceLabel = "R$ 49" },
} :: { ProductDef }
-- Ecto product amounts scale with best zone (same table as Daily.ZoneMultiplier).
Config.GamePasses = {
	{ Key = "ExtraSlots", Name = "+2 HUNTER SLOTS", Icon = "🎒", PassId = nil, PriceLabel = "R$ 149", Slots = 2 },
	{ Key = "DoubleEcto", Name = "PERMANENT 2x ECTOPLASM", Icon = "💎", PassId = nil, PriceLabel = "R$ 299", Multiplier = 2 },
} :: { PassDef }

--==================================================================
-- RATE LIMITS (requests per window, per player, per action)
--==================================================================
Config.RateLimits = {
	Default = { Count = 10, Window = 1 },
	SelectTarget = { Count = 8, Window = 1 },
	OpenCrate = { Count = 3, Window = 1 },
	Inventory = { Count = 12, Window = 1 },
}

Config.Data = {
	AutosaveSeconds = 90,
	Retries = 5,
	SessionLockSeconds = 300, -- a lock older than this is considered stale
}

--==================================================================
-- WORLD LAYOUT (studs; +Z is "forward" along the progression path)
--==================================================================
export type GhostArea = { Ghost: string, Center: Vector3, Radius: number, Count: number }

Config.Layout = {
	Spawn = Vector3.new(0, 3, 0),
	HalfWidth = 140, -- playable area spans X -HalfWidth..HalfWidth
	Gates = {
		-- gate that unlocks Zone Id, centred on X=0 at this Z
		Cemetery = { Z = 260, Width = 34 },
		School = { Z = 540, Width = 34 },
	},
	CrateStations = {
		Beginner = Vector3.new(-28, 0, 28),
		Haunted = Vector3.new(-28, 0, 292),
		Elite = Vector3.new(-28, 0, 572),
	},
	UpgradeStation = Vector3.new(28, 0, 28),
	EventArena = { Center = Vector3.new(95, 0, 110), Radius = 32 },
	GhostAreas = {
		{ Ghost = "WanderingSpirit", Center = Vector3.new(0, 0, 70), Radius = 34, Count = 7 },
		{ Ghost = "WanderingSpirit", Center = Vector3.new(-80, 0, 80), Radius = 26, Count = 4 },
		{ Ghost = "MischiefGhost", Center = Vector3.new(-60, 0, 160), Radius = 30, Count = 5 },
		{ Ghost = "MischiefGhost", Center = Vector3.new(30, 0, 170), Radius = 30, Count = 4 },
		{ Ghost = "NeighborhoodPoltergeist", Center = Vector3.new(0, 0, 225), Radius = 18, Count = 2 },
		{ Ghost = "GraveSpirit", Center = Vector3.new(0, 0, 335), Radius = 34, Count = 6 },
		{ Ghost = "GraveSpirit", Center = Vector3.new(75, 0, 360), Radius = 26, Count = 4 },
		{ Ghost = "CryptGhost", Center = Vector3.new(-65, 0, 420), Radius = 30, Count = 5 },
		{ Ghost = "CryptGhost", Center = Vector3.new(55, 0, 440), Radius = 28, Count = 3 },
		{ Ghost = "GraveyardWarden", Center = Vector3.new(0, 0, 505), Radius = 18, Count = 2 },
		{ Ghost = "HallwayHaunt", Center = Vector3.new(0, 0, 640), Radius = 14, Count = 6 },
		{ Ghost = "HallwayHaunt", Center = Vector3.new(0, 0, 700), Radius = 14, Count = 3 },
		{ Ghost = "PossessedStudent", Center = Vector3.new(-62, 0, 690), Radius = 20, Count = 4 },
		{ Ghost = "PossessedStudent", Center = Vector3.new(62, 0, 690), Radius = 20, Count = 4 },
		{ Ghost = "HeadmasterPhantom", Center = Vector3.new(0, 0, 805), Radius = 20, Count = 1 },
	} :: { GhostArea },
}

--==================================================================
-- TUTORIAL steps (client shows these; server only stores progress)
--==================================================================
Config.Tutorial = {
	Steps = { "TapGhost", "Collect", "OpenCrate", "Equip", "Unlock" },
	Text = {
		TapGhost = "TAP A GHOST!",
		Collect = "COLLECT ECTOPLASM!",
		OpenCrate = "OPEN A HUNTER CRATE!",
		Equip = "EQUIP YOUR NEW HUNTER!",
		Unlock = "UNLOCK THE CEMETERY!",
	},
}

return Config
