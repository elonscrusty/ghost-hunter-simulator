--!strict
-- GHOST HUNTER SIMULATOR: every tuning number, every content entry and the world layout.
-- Nothing else in the game should hold balance values. Adding Zone 4 = add a Zones entry,
-- its Ghosts, its Hunters, its Crate and a Layout block (see docs/ADDING_CONTENT.md).

local Config = {}

Config.Version = "1.2.0"
Config.DataStoreName = "GhostHunterData_v1"
Config.DataSchemaVersion = 2

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
		Id = "Mythic", Name = "MYTHIC", Order = 6, Enabled = true,
		Color = Color3.fromRGB(255, 70, 110), Color2 = Color3.fromRGB(255, 160, 60),
		RevealPause = 2.0, ShakeIntensity = 0.8, Particles = 200, Darken = 0.55, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
	Secret = {
		Id = "Secret", Name = "SECRET", Order = 7, Enabled = true,
		Color = Color3.fromRGB(30, 30, 40), Color2 = Color3.fromRGB(240, 240, 255),
		RevealPause = 2.4, ShakeIntensity = 0.9, Particles = 220, Darken = 0.7, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
	-- above Secret; light/particle levels stay near Secret's (the reveal was toned down)
	Ultra = {
		Id = "Ultra", Name = "ULTRA", Order = 8, Enabled = true,
		Color = Color3.fromRGB(150, 70, 255), Color2 = Color3.fromRGB(40, 225, 255),
		RevealPause = 2.6, ShakeIntensity = 0.95, Particles = 230, Darken = 0.7, CameraPunch = true, Announce = true,
		Sound = "RevealLegendary",
	},
	-- Robux-only; stays the top Order
	Exclusive = {
		Id = "Exclusive", Name = "EXCLUSIVE", Order = 9, Enabled = true,
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
		MinZ = -140, MaxZ = 260, -- includes the lobby (Z -130..-37), always open
	},
	{
		Id = "Cemetery", Name = "CEMETERY", Order = 2, Cost = 1500, Crate = "Haunted",
		Ambient = Color3.fromRGB(120, 150, 190), FogColor = Color3.fromRGB(90, 70, 150), Accent = Color3.fromRGB(80, 255, 170),
		MinZ = 260, MaxZ = 540,
	},
	{
		Id = "School", Name = "HAUNTED SCHOOL", Order = 3, Cost = 15000, Crate = "Elite",
		Ambient = Color3.fromRGB(160, 130, 210), FogColor = Color3.fromRGB(70, 50, 120), Accent = Color3.fromRGB(190, 110, 255),
		MinZ = 540, MaxZ = 880,
	},
	{
		Id = "Carnival", Name = "ABANDONED CARNIVAL", Order = 4, Cost = 150000, Crate = "Carnival",
		Ambient = Color3.fromRGB(175, 130, 190), FogColor = Color3.fromRGB(120, 60, 130), Accent = Color3.fromRGB(255, 205, 70),
		MinZ = 880, MaxZ = 1220,
	},
	{
		Id = "Hospital", Name = "HAUNTED HOSPITAL", Order = 5, Cost = 1500000, Crate = "Medical",
		Ambient = Color3.fromRGB(150, 175, 200), FogColor = Color3.fromRGB(80, 110, 140), Accent = Color3.fromRGB(140, 230, 255),
		MinZ = 1220, MaxZ = 1560,
	},
	{
		Id = "Harbor", Name = "GHOST SHIP HARBOR", Order = 6, Cost = 15000000, Crate = "Sailor",
		Ambient = Color3.fromRGB(110, 150, 190), FogColor = Color3.fromRGB(40, 80, 120), Accent = Color3.fromRGB(90, 255, 210),
		MinZ = 1560, MaxZ = 1920,
	},
	{
		Id = "Castle", Name = "CURSED CASTLE", Order = 7, Cost = 90000000, Crate = "Royal",
		Ambient = Color3.fromRGB(130, 120, 180), FogColor = Color3.fromRGB(50, 45, 100), Accent = Color3.fromRGB(255, 200, 80),
		MinZ = 1920, MaxZ = 2280,
	},
	{
		Id = "SpiritRealm", Name = "SPIRIT REALM", Order = 8, Cost = 500000000, Crate = "SpiritRealm",
		Ambient = Color3.fromRGB(140, 120, 220), FogColor = Color3.fromRGB(60, 30, 120), Accent = Color3.fromRGB(110, 240, 255),
		MinZ = 2280, MaxZ = 2680,
	},
	{
		Id = "Swamp", Name = "PHANTOM SWAMP", Order = 9, Cost = 3000000000, Crate = "Bog",
		Ambient = Color3.fromRGB(120, 160, 120), FogColor = Color3.fromRGB(40, 70, 50), Accent = Color3.fromRGB(150, 255, 120),
		MinZ = 2680, MaxZ = 3040,
	},
	{
		Id = "Frost", Name = "FROSTBITE PEAKS", Order = 10, Cost = 18000000000, Crate = "Frost",
		Ambient = Color3.fromRGB(170, 200, 235), FogColor = Color3.fromRGB(110, 150, 200), Accent = Color3.fromRGB(170, 240, 255),
		MinZ = 3040, MaxZ = 3400,
	},
	{
		Id = "Tomb", Name = "PHARAOH'S TOMB", Order = 11, Cost = 108000000000, Crate = "Tomb",
		Ambient = Color3.fromRGB(210, 180, 130), FogColor = Color3.fromRGB(120, 90, 50), Accent = Color3.fromRGB(255, 210, 90),
		MinZ = 3400, MaxZ = 3760,
	},
	{
		Id = "ToyFactory", Name = "HAUNTED TOY FACTORY", Order = 12, Cost = 648000000000, Crate = "Toy",
		Ambient = Color3.fromRGB(200, 150, 210), FogColor = Color3.fromRGB(110, 60, 120), Accent = Color3.fromRGB(255, 140, 200),
		MinZ = 3760, MaxZ = 4120,
	},
	{
		Id = "Sunken", Name = "SUNKEN CITY", Order = 13, Cost = 3890000000000, Crate = "Sunken",
		Ambient = Color3.fromRGB(100, 170, 200), FogColor = Color3.fromRGB(20, 70, 110), Accent = Color3.fromRGB(90, 255, 230),
		MinZ = 4120, MaxZ = 4480,
	},
	{
		Id = "Clockwork", Name = "CLOCKWORK TOWER", Order = 14, Cost = 23300000000000, Crate = "Clockwork",
		Ambient = Color3.fromRGB(190, 160, 130), FogColor = Color3.fromRGB(90, 70, 50), Accent = Color3.fromRGB(255, 190, 90),
		MinZ = 4480, MaxZ = 4840,
	},
	{
		Id = "Inferno", Name = "INFERNO CAVERNS", Order = 15, Cost = 140000000000000, Crate = "Inferno",
		Ambient = Color3.fromRGB(210, 130, 100), FogColor = Color3.fromRGB(110, 40, 30), Accent = Color3.fromRGB(255, 140, 60),
		MinZ = 4840, MaxZ = 5200,
	},
	{
		Id = "Throne", Name = "GHOST KING'S THRONE", Order = 16, Cost = 840000000000000, Crate = "Throne",
		Ambient = Color3.fromRGB(190, 170, 240), FogColor = Color3.fromRGB(70, 50, 130), Accent = Color3.fromRGB(255, 230, 140),
		MinZ = 5200, MaxZ = 5560,
	},	-- WORLD 2: THE OTHER SIDE (areas 17-32)
	{
		Id = "LanternMarket", Name = "LANTERN MARKET", Order = 17, Cost = 5.04e15, Crate = "Lantern",
		Ambient = Color3.fromRGB(210, 150, 130), FogColor = Color3.fromRGB(110, 40, 50), Accent = Color3.fromRGB(255, 190, 80),
		MinZ = 7000, MaxZ = 7360,
	},
	{
		Id = "PhantomLibrary", Name = "PHANTOM LIBRARY", Order = 18, Cost = 3.02e16, Crate = "Library",
		Ambient = Color3.fromRGB(170, 150, 200), FogColor = Color3.fromRGB(50, 40, 80), Accent = Color3.fromRGB(120, 255, 220),
		MinZ = 7360, MaxZ = 7720,
	},
	{
		Id = "PumpkinFarm", Name = "HAUNTED PUMPKIN FARM", Order = 19, Cost = 1.81e17, Crate = "Harvest",
		Ambient = Color3.fromRGB(215, 165, 115), FogColor = Color3.fromRGB(95, 55, 30), Accent = Color3.fromRGB(255, 150, 50),
		MinZ = 7720, MaxZ = 8080,
	},
	{
		Id = "Glowshroom", Name = "GLOWSHROOM FOREST", Order = 20, Cost = 1.09e18, Crate = "Shroom",
		Ambient = Color3.fromRGB(110, 170, 190), FogColor = Color3.fromRGB(20, 60, 70), Accent = Color3.fromRGB(120, 255, 230),
		MinZ = 8080, MaxZ = 8440,
	},
	{
		Id = "WaterPark", Name = "HAUNTED WATER PARK", Order = 21, Cost = 6.53e18, Crate = "Splash",
		Ambient = Color3.fromRGB(150, 210, 235), FogColor = Color3.fromRGB(30, 90, 130), Accent = Color3.fromRGB(90, 230, 255),
		MinZ = 8440, MaxZ = 8800,
	},
	{
		Id = "MirrorMaze", Name = "MIRROR MAZE", Order = 22, Cost = 3.92e19, Crate = "Mirror",
		Ambient = Color3.fromRGB(190, 210, 235), FogColor = Color3.fromRGB(110, 130, 170), Accent = Color3.fromRGB(200, 240, 255),
		MinZ = 8800, MaxZ = 9160,
	},
	{
		Id = "ShoppingMall", Name = "HAUNTED SHOPPING MALL", Order = 23, Cost = 2.35e20, Crate = "Mall",
		Ambient = Color3.fromRGB(220, 190, 225), FogColor = Color3.fromRGB(90, 60, 115), Accent = Color3.fromRGB(255, 140, 210),
		MinZ = 9160, MaxZ = 9520,
	},
	{
		Id = "GhostSubway", Name = "GHOST SUBWAY", Order = 24, Cost = 1.41e21, Crate = "Subway",
		Ambient = Color3.fromRGB(150, 160, 180), FogColor = Color3.fromRGB(40, 45, 60), Accent = Color3.fromRGB(255, 220, 80),
		MinZ = 9520, MaxZ = 9880,
	},
	{
		Id = "DinoMuseum", Name = "DINO FOSSIL MUSEUM", Order = 25, Cost = 8.47e21, Crate = "Fossil",
		Ambient = Color3.fromRGB(205, 190, 155), FogColor = Color3.fromRGB(85, 70, 50), Accent = Color3.fromRGB(150, 230, 120),
		MinZ = 9880, MaxZ = 10240,
	},
	{
		Id = "Stadium", Name = "HAUNTED STADIUM", Order = 26, Cost = 5.08e22, Crate = "Champion",
		Ambient = Color3.fromRGB(175, 200, 235), FogColor = Color3.fromRGB(40, 60, 105), Accent = Color3.fromRGB(120, 255, 140),
		MinZ = 10240, MaxZ = 10600,
	},
	{
		Id = "NeonCity", Name = "NEON GHOST CITY", Order = 27, Cost = 3.05e23, Crate = "Neon",
		Ambient = Color3.fromRGB(170, 120, 220), FogColor = Color3.fromRGB(40, 20, 70), Accent = Color3.fromRGB(255, 80, 220),
		MinZ = 10600, MaxZ = 10960,
	},
	{
		Id = "GiantsKitchen", Name = "GIANT'S KITCHEN", Order = 28, Cost = 1.83e24, Crate = "CookieJar",
		Ambient = Color3.fromRGB(240, 215, 185), FogColor = Color3.fromRGB(125, 85, 55), Accent = Color3.fromRGB(255, 170, 90),
		MinZ = 10960, MaxZ = 11320,
	},
	{
		Id = "CyberArcade", Name = "CYBER ARCADE DIMENSION", Order = 29, Cost = 1.1e25, Crate = "Arcade",
		Ambient = Color3.fromRGB(150, 125, 225), FogColor = Color3.fromRGB(20, 10, 55), Accent = Color3.fromRGB(80, 255, 220),
		MinZ = 11320, MaxZ = 11680,
	},
	{
		Id = "StormIslands", Name = "STORM SKY ISLANDS", Order = 30, Cost = 6.58e25, Crate = "Storm",
		Ambient = Color3.fromRGB(160, 180, 220), FogColor = Color3.fromRGB(70, 80, 120), Accent = Color3.fromRGB(255, 240, 120),
		MinZ = 11680, MaxZ = 12040,
	},
	{
		Id = "MoonBase", Name = "HAUNTED MOON BASE", Order = 31, Cost = 3.95e26, Crate = "Moon",
		Ambient = Color3.fromRGB(170, 175, 200), FogColor = Color3.fromRGB(20, 20, 40), Accent = Color3.fromRGB(255, 150, 80),
		MinZ = 12040, MaxZ = 12400,
	},
	{
		Id = "VoidThrone", Name = "THE VOID THRONE", Order = 32, Cost = 2.37e27, Crate = "Void",
		Ambient = Color3.fromRGB(120, 100, 170), FogColor = Color3.fromRGB(15, 5, 30), Accent = Color3.fromRGB(200, 150, 255),
		MinZ = 12400, MaxZ = 12880,
	},

} :: { ZoneDef }

Config.ZoneById = {} :: { [string]: ZoneDef }
for _, z in Config.Zones do
	Config.ZoneById[z.Id] = z
end

-- WORLDS: runs of zones on separate tracks. World 1 is zones 1-16 (Z -140..5560); World 2
-- (THE OTHER SIDE) is zones 17-32 (Z 7000..12880), reached through the portal at the end of the
-- Ghost King's Throne (Config.Layout.Portals). First = order of the world's first zone.
export type WorldDef = { Name: string, Title: string, First: number, Last: number, Accent: Color3 }
Config.Worlds = {
	{ Name = "WORLD 1", Title = "THE HAUNTED LANDS", First = 1, Last = 16, Accent = Color3.fromRGB(150, 255, 120) },
	{ Name = "WORLD 2", Title = "THE OTHER SIDE", First = 17, Last = 32, Accent = Color3.fromRGB(200, 150, 255) },
} :: { WorldDef }

--==================================================================
-- GHOSTS (Spirit = health; Reward = BASE Ectoplasm per kill. The same ghost type always pays the
-- same base; FinalReward = Reward * the player's multiplier (upgrades, boosts, passes, global event))
-- (all rewards x1.25 in v1.5 so progression is 20% faster; prices unchanged)
--==================================================================
export type GhostDef = {
	Id: string,
	Name: string,
	Zone: string,
	Spirit: number,
	Reward: number, -- BASE Ectoplasm per kill (fixed; multipliers apply on top)
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
		Spirit = 30, Reward = 8, Drops = 3, Respawn = 4, Scale = 1, Hover = 5, Speed = 5, Wander = 3.5,
		Kind = "Normal", Color = Color3.fromRGB(235, 240, 255), Glow = Color3.fromRGB(150, 255, 200), Style = "Plain",
	},
	MischiefGhost = {
		Id = "MischiefGhost", Name = "MISCHIEF GHOST", Zone = "Neighborhood",
		Spirit = 140, Reward = 28, Drops = 4, Respawn = 6, Scale = 1.3, Hover = 5.5, Speed = 7, Wander = 2.5,
		Kind = "Normal", Color = Color3.fromRGB(200, 160, 255), Glow = Color3.fromRGB(255, 120, 220), Style = "Mischief",
	},
	NeighborhoodPoltergeist = {
		Id = "NeighborhoodPoltergeist", Name = "NEIGHBORHOOD POLTERGEIST", Zone = "Neighborhood",
		Spirit = 700, Reward = 140, Drops = 8, Respawn = 15, Scale = 2.2, Hover = 7, Speed = 4, Wander = 4,
		Kind = "MiniBoss", Color = Color3.fromRGB(130, 255, 180), Glow = Color3.fromRGB(80, 255, 140), Style = "Poltergeist",
	},
	-- ZONE 2
	GraveSpirit = {
		Id = "GraveSpirit", Name = "GRAVE SPIRIT", Zone = "Cemetery",
		Spirit = 900, Reward = 110, Drops = 4, Respawn = 5, Scale = 1.2, Hover = 5, Speed = 5, Wander = 3.5,
		Kind = "Normal", Color = Color3.fromRGB(190, 255, 230), Glow = Color3.fromRGB(60, 255, 170), Style = "Grave",
	},
	CryptGhost = {
		Id = "CryptGhost", Name = "CRYPT GHOST", Zone = "Cemetery",
		Spirit = 2600, Reward = 281, Drops = 5, Respawn = 8, Scale = 1.5, Hover = 6, Speed = 5, Wander = 3,
		Kind = "Normal", Color = Color3.fromRGB(240, 225, 190), Glow = Color3.fromRGB(255, 200, 90), Style = "Crypt",
	},
	GraveyardWarden = {
		Id = "GraveyardWarden", Name = "GRAVEYARD WARDEN", Zone = "Cemetery",
		Spirit = 9500, Reward = 1050, Drops = 10, Respawn = 18, Scale = 2.5, Hover = 7.5, Speed = 3.5, Wander = 4.5,
		Kind = "MiniBoss", Color = Color3.fromRGB(120, 110, 200), Glow = Color3.fromRGB(110, 255, 160), Style = "Warden",
	},
	-- ZONE 3
	HallwayHaunt = {
		Id = "HallwayHaunt", Name = "HALLWAY HAUNT", Zone = "School",
		Spirit = 12000, Reward = 1260, Drops = 5, Respawn = 6, Scale = 1.4, Hover = 5, Speed = 6, Wander = 3,
		Kind = "Normal", Color = Color3.fromRGB(255, 220, 150), Glow = Color3.fromRGB(255, 150, 80), Style = "Hallway",
	},
	PossessedStudent = {
		Id = "PossessedStudent", Name = "POSSESSED STUDENT SPIRIT", Zone = "School",
		Spirit = 32000, Reward = 3120, Drops = 6, Respawn = 9, Scale = 1.7, Hover = 5.5, Speed = 6.5, Wander = 2.8,
		Kind = "Normal", Color = Color3.fromRGB(160, 230, 255), Glow = Color3.fromRGB(190, 110, 255), Style = "Student",
	},
	HeadmasterPhantom = {
		Id = "HeadmasterPhantom", Name = "HEADMASTER PHANTOM", Zone = "School",
		Spirit = 130000, Reward = 12200, Drops = 14, Respawn = 25, Scale = 3, Hover = 8, Speed = 3, Wander = 5,
		Kind = "Boss", Color = Color3.fromRGB(170, 120, 255), Glow = Color3.fromRGB(255, 80, 200), Style = "Headmaster",
	},
	-- ZONE 4
	CarnivalSpirit = {
		Id = "CarnivalSpirit", Name = "CARNIVAL SPIRIT", Zone = "Carnival",
		Spirit = 60000, Reward = 6720, Drops = 5, Respawn = 6, Scale = 1.4, Hover = 5, Speed = 6, Wander = 3,
		Kind = "Normal", Color = Color3.fromRGB(255, 235, 200), Glow = Color3.fromRGB(255, 190, 70), Style = "Carnival",
	},
	ClownPhantom = {
		Id = "ClownPhantom", Name = "CLOWN PHANTOM", Zone = "Carnival",
		Spirit = 160000, Reward = 17200, Drops = 6, Respawn = 9, Scale = 1.7, Hover = 5.5, Speed = 6.5, Wander = 2.6,
		Kind = "Normal", Color = Color3.fromRGB(255, 250, 250), Glow = Color3.fromRGB(255, 80, 120), Style = "Clown",
	},
	RingmasterPoltergeist = {
		Id = "RingmasterPoltergeist", Name = "RINGMASTER POLTERGEIST", Zone = "Carnival",
		Spirit = 650000, Reward = 64000, Drops = 14, Respawn = 25, Scale = 3.2, Hover = 8.5, Speed = 3, Wander = 5,
		Kind = "Boss", Color = Color3.fromRGB(230, 70, 80), Glow = Color3.fromRGB(255, 210, 80), Style = "Ringmaster",
	},
	-- ZONE 5
	PatientSpirit = {
		Id = "PatientSpirit", Name = "PATIENT SPIRIT", Zone = "Hospital",
		Spirit = 300000, Reward = 33600, Drops = 5, Respawn = 6, Scale = 1.4, Hover = 5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(215, 240, 255), Glow = Color3.fromRGB(120, 230, 200), Style = "Patient",
	},
	PhantomDoctor = {
		Id = "PhantomDoctor", Name = "PHANTOM DOCTOR", Zone = "Hospital",
		Spirit = 800000, Reward = 86000, Drops = 6, Respawn = 9, Scale = 1.75, Hover = 5.5, Speed = 6, Wander = 2.8,
		Kind = "Normal", Color = Color3.fromRGB(245, 250, 255), Glow = Color3.fromRGB(170, 120, 255), Style = "Doctor",
	},
	HospitalDirector = {
		Id = "HospitalDirector", Name = "HOSPITAL DIRECTOR", Zone = "Hospital",
		Spirit = 3200000, Reward = 320000, Drops = 15, Respawn = 25, Scale = 3.3, Hover = 8.5, Speed = 3, Wander = 5,
		Kind = "Boss", Color = Color3.fromRGB(150, 210, 190), Glow = Color3.fromRGB(110, 255, 190), Style = "Director",
	},
	-- ZONE 6
	SailorSpirit = {
		Id = "SailorSpirit", Name = "SAILOR SPIRIT", Zone = "Harbor",
		Spirit = 1500000, Reward = 168000, Drops = 5, Respawn = 6, Scale = 1.45, Hover = 5, Speed = 5.5, Wander = 3,
		Kind = "Normal", Color = Color3.fromRGB(200, 240, 245), Glow = Color3.fromRGB(80, 230, 230), Style = "Sailor",
	},
	PhantomPirate = {
		Id = "PhantomPirate", Name = "PHANTOM PIRATE", Zone = "Harbor",
		Spirit = 4000000, Reward = 430000, Drops = 6, Respawn = 9, Scale = 1.8, Hover = 5.5, Speed = 6.5, Wander = 2.6,
		Kind = "Normal", Color = Color3.fromRGB(170, 240, 210), Glow = Color3.fromRGB(110, 255, 160), Style = "Pirate",
	},
	GhostCaptain = {
		Id = "GhostCaptain", Name = "GHOST CAPTAIN", Zone = "Harbor",
		Spirit = 16000000, Reward = 1600000, Drops = 15, Respawn = 25, Scale = 3.5, Hover = 9, Speed = 3, Wander = 5,
		Kind = "Boss", Color = Color3.fromRGB(110, 200, 210), Glow = Color3.fromRGB(90, 255, 200), Style = "Captain",
	},
	-- ZONE 7
	KnightSpirit = {
		Id = "KnightSpirit", Name = "KNIGHT SPIRIT", Zone = "Castle",
		Spirit = 7500000, Reward = 828000, Drops = 5, Respawn = 6, Scale = 1.5, Hover = 5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(215, 225, 245), Glow = Color3.fromRGB(120, 190, 255), Style = "Knight",
	},
	RoyalPhantom = {
		Id = "RoyalPhantom", Name = "ROYAL PHANTOM", Zone = "Castle",
		Spirit = 20000000, Reward = 2150000, Drops = 6, Respawn = 9, Scale = 1.85, Hover = 5.5, Speed = 6, Wander = 2.8,
		Kind = "Normal", Color = Color3.fromRGB(230, 200, 255), Glow = Color3.fromRGB(200, 90, 255), Style = "Royal",
	},
	CursedKing = {
		Id = "CursedKing", Name = "CURSED KING", Zone = "Castle",
		Spirit = 80000000, Reward = 8050000, Drops = 16, Respawn = 25, Scale = 3.7, Hover = 9.5, Speed = 3, Wander = 5,
		Kind = "Boss", Color = Color3.fromRGB(120, 140, 200), Glow = Color3.fromRGB(110, 255, 160), Style = "King",
	},
	-- ZONE 8
	AncientSpirit = {
		Id = "AncientSpirit", Name = "ANCIENT SPIRIT", Zone = "SpiritRealm",
		Spirit = 37000000, Reward = 4140000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(190, 220, 255), Glow = Color3.fromRGB(110, 240, 255), Style = "Ancient",
	},
	VoidPhantom = {
		Id = "VoidPhantom", Name = "VOID PHANTOM", Zone = "SpiritRealm",
		Spirit = 100000000, Reward = 10700000, Drops = 6, Respawn = 9, Scale = 1.9, Hover = 6, Speed = 6.5, Wander = 2.6,
		Kind = "Normal", Color = Color3.fromRGB(90, 70, 160), Glow = Color3.fromRGB(190, 110, 255), Style = "Void",
	},
	SpiritOverlord = {
		Id = "SpiritOverlord", Name = "SPIRIT OVERLORD", Zone = "SpiritRealm",
		Spirit = 420000000, Reward = 40600000, Drops = 18, Respawn = 30, Scale = 5, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(170, 140, 255), Glow = Color3.fromRGB(90, 255, 230), Style = "Overlord",
	},
	BogWisp = {
		Id = "BogWisp", Name = "BOG WISP", Zone = "Swamp",
		Spirit = 185000000, Reward = 21500000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(180, 230, 170), Glow = Color3.fromRGB(150, 255, 120), Style = "Bog",
	},
	MarshPhantom = {
		Id = "MarshPhantom", Name = "MARSH PHANTOM", Zone = "Swamp",
		Spirit = 500000000, Reward = 55600000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(140, 190, 140), Glow = Color3.fromRGB(200, 255, 90), Style = "Marsh",
	},
	SwampLord = {
		Id = "SwampLord", Name = "SWAMP LORD", Zone = "Swamp",
		Spirit = 2100000000, Reward = 211000000, Drops = 18, Respawn = 30, Scale = 5.15, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(90, 140, 90), Glow = Color3.fromRGB(170, 255, 110), Style = "SwampLord",
	},
	FrostSpirit = {
		Id = "FrostSpirit", Name = "FROST SPIRIT", Zone = "Frost",
		Spirit = 925000000, Reward = 112000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(230, 245, 255), Glow = Color3.fromRGB(140, 220, 255), Style = "FrostWisp",
	},
	YetiPhantom = {
		Id = "YetiPhantom", Name = "YETI PHANTOM", Zone = "Frost",
		Spirit = 2500000000, Reward = 290000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(240, 245, 250), Glow = Color3.fromRGB(120, 200, 255), Style = "Yeti",
	},
	BlizzardQueen = {
		Id = "BlizzardQueen", Name = "BLIZZARD QUEEN", Zone = "Frost",
		Spirit = 10500000000, Reward = 1100000000, Drops = 18, Respawn = 30, Scale = 5.30, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(200, 230, 255), Glow = Color3.fromRGB(170, 240, 255), Style = "Blizzard",
	},
	MummySpirit = {
		Id = "MummySpirit", Name = "MUMMY SPIRIT", Zone = "Tomb",
		Spirit = 4620000000, Reward = 582000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(240, 230, 200), Glow = Color3.fromRGB(255, 210, 90), Style = "Mummy",
	},
	ScarabPhantom = {
		Id = "ScarabPhantom", Name = "SCARAB PHANTOM", Zone = "Tomb",
		Spirit = 12500000000, Reward = 1500000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(80, 170, 180), Glow = Color3.fromRGB(90, 255, 220), Style = "Scarab",
	},
	PharaohsGhost = {
		Id = "PharaohsGhost", Name = "PHARAOH'S GHOST", Zone = "Tomb",
		Spirit = 52500000000, Reward = 5710000000, Drops = 18, Respawn = 30, Scale = 5.45, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(255, 220, 130), Glow = Color3.fromRGB(255, 180, 60), Style = "Pharaoh",
	},
	ToySoldierSpirit = {
		Id = "ToySoldierSpirit", Name = "TOY SOLDIER SPIRIT", Zone = "ToyFactory",
		Spirit = 23100000000, Reward = 3020000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(255, 200, 200), Glow = Color3.fromRGB(255, 90, 120), Style = "ToySoldier",
	},
	JackInTheBoxPhantom = {
		Id = "JackInTheBoxPhantom", Name = "JACK-IN-THE-BOX PHANTOM", Zone = "ToyFactory",
		Spirit = 62500000000, Reward = 7820000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(255, 230, 150), Glow = Color3.fromRGB(255, 140, 220), Style = "JackBox",
	},
	PuppetMaster = {
		Id = "PuppetMaster", Name = "PUPPET MASTER", Zone = "ToyFactory",
		Spirit = 262000000000, Reward = 29800000000, Drops = 18, Respawn = 30, Scale = 5.60, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(220, 170, 240), Glow = Color3.fromRGB(255, 120, 200), Style = "Puppet",
	},
	BubbleSpirit = {
		Id = "BubbleSpirit", Name = "BUBBLE SPIRIT", Zone = "Sunken",
		Spirit = 116000000000, Reward = 15800000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(180, 240, 255), Glow = Color3.fromRGB(90, 255, 230), Style = "Bubble",
	},
	SirenPhantom = {
		Id = "SirenPhantom", Name = "SIREN PHANTOM", Zone = "Sunken",
		Spirit = 312000000000, Reward = 40800000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(160, 230, 220), Glow = Color3.fromRGB(140, 255, 200), Style = "Siren",
	},
	LeviathanGhost = {
		Id = "LeviathanGhost", Name = "LEVIATHAN GHOST", Zone = "Sunken",
		Spirit = 1310000000000, Reward = 154000000000, Drops = 18, Respawn = 30, Scale = 5.75, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(70, 150, 170), Glow = Color3.fromRGB(90, 255, 230), Style = "Leviathan",
	},
	CogSpirit = {
		Id = "CogSpirit", Name = "COG SPIRIT", Zone = "Clockwork",
		Spirit = 578000000000, Reward = 81800000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(230, 210, 170), Glow = Color3.fromRGB(255, 190, 90), Style = "Cog",
	},
	ClockworkPhantom = {
		Id = "ClockworkPhantom", Name = "CLOCKWORK PHANTOM", Zone = "Clockwork",
		Spirit = 1560000000000, Reward = 211000000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(200, 180, 150), Glow = Color3.fromRGB(255, 220, 120), Style = "Clockwork",
	},
	TimeKeeper = {
		Id = "TimeKeeper", Name = "TIME KEEPER", Zone = "Clockwork",
		Spirit = 6560000000000, Reward = 802000000000, Drops = 18, Respawn = 30, Scale = 5.90, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(180, 150, 110), Glow = Color3.fromRGB(255, 200, 80), Style = "TimeKeeper",
	},
	EmberSpirit = {
		Id = "EmberSpirit", Name = "EMBER SPIRIT", Zone = "Inferno",
		Spirit = 2890000000000, Reward = 426000000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(255, 200, 150), Glow = Color3.fromRGB(255, 150, 60), Style = "Ember",
	},
	MagmaPhantom = {
		Id = "MagmaPhantom", Name = "MAGMA PHANTOM", Zone = "Inferno",
		Spirit = 7810000000000, Reward = 1100000000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(255, 150, 110), Glow = Color3.fromRGB(255, 110, 50), Style = "Magma",
	},
	InfernoTitan = {
		Id = "InfernoTitan", Name = "INFERNO TITAN", Zone = "Inferno",
		Spirit = 32800000000000, Reward = 4180000000000, Drops = 18, Respawn = 30, Scale = 6.05, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(200, 90, 70), Glow = Color3.fromRGB(255, 170, 60), Style = "Titan",
	},
	RoyalGuardSpirit = {
		Id = "RoyalGuardSpirit", Name = "ROYAL GUARD SPIRIT", Zone = "Throne",
		Spirit = 14500000000000, Reward = 2210000000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(235, 235, 250), Glow = Color3.fromRGB(255, 220, 120), Style = "Guard",
	},
	ShadowPhantom = {
		Id = "ShadowPhantom", Name = "SHADOW PHANTOM", Zone = "Throne",
		Spirit = 39100000000000, Reward = 5720000000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(90, 80, 130), Glow = Color3.fromRGB(190, 120, 255), Style = "Shadow",
	},
	GhostKing = {
		Id = "GhostKing", Name = "THE GHOST KING", Zone = "Throne",
		Spirit = 164000000000000, Reward = 21800000000000, Drops = 18, Respawn = 30, Scale = 6.20, Hover = 14, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(220, 210, 255), Glow = Color3.fromRGB(255, 230, 140), Style = "GhostKing",
	},
	-- BOSS TOWER (Spirit and hit are scaled per room by Config.Tower at spawn time).
	-- 16 regular bosses (Config.Tower.Bosses) + 4 BIG milestone bosses (Config.Tower.BigBosses).
	TowerWarden = {
		Id = "TowerWarden", Name = "TOWER WARDEN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4, Hover = 9, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(120, 110, 200), Glow = Color3.fromRGB(120, 219, 154), Style = "Warden",
	},
	TowerJester = {
		Id = "TowerJester", Name = "TOWER JESTER", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.2, Hover = 9, Speed = 3.5, Wander = 3.5,
		Kind = "Tower", Color = Color3.fromRGB(240, 90, 110), Glow = Color3.fromRGB(120, 219, 154), Style = "Jester",
	},
	TowerPumpkinKnight = {
		Id = "TowerPumpkinKnight", Name = "PUMPKIN KNIGHT", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.2, Hover = 9, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(205, 185, 255), Glow = Color3.fromRGB(120, 219, 154), Style = "PumpkinKnight",
	},
	TowerSwampHag = {
		Id = "TowerSwampHag", Name = "SWAMP HAG", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.2, Hover = 9, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(150, 210, 120), Glow = Color3.fromRGB(175, 219, 106), Style = "SwampHag",
	},
	TowerBaron = {
		Id = "TowerBaron", Name = "TOWER BARON", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.4, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(120, 140, 200), Glow = Color3.fromRGB(120, 219, 154), Style = "King",
	},
	TowerClockSpecter = {
		Id = "TowerClockSpecter", Name = "CLOCKWORK SPECTER", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.4, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(165, 235, 215), Glow = Color3.fromRGB(120, 219, 154), Style = "ClockSpecter",
	},
	TowerBanshee = {
		Id = "TowerBanshee", Name = "BANSHEE QUEEN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.4, Hover = 10, Speed = 3.5, Wander = 3.5,
		Kind = "Tower", Color = Color3.fromRGB(230, 220, 255), Glow = Color3.fromRGB(133, 219, 188), Style = "Banshee",
	},
	TowerBoneCaptain = {
		Id = "TowerBoneCaptain", Name = "SKELETON CAPTAIN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.4, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(185, 235, 230), Glow = Color3.fromRGB(120, 219, 154), Style = "BoneCaptain",
	},
	TowerMummyPharaoh = {
		Id = "TowerMummyPharaoh", Name = "MUMMY PHARAOH", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.6, Hover = 10, Speed = 2.5, Wander = 4.5,
		Kind = "Tower", Color = Color3.fromRGB(245, 228, 195), Glow = Color3.fromRGB(120, 219, 154), Style = "MummyPharaoh",
	},
	TowerFrostWraith = {
		Id = "TowerFrostWraith", Name = "FROST WRAITH", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.6, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(175, 215, 255), Glow = Color3.fromRGB(140, 219, 206), Style = "FrostWraith",
	},
	TowerPuppetMaster = {
		Id = "TowerPuppetMaster", Name = "PUPPET MASTER", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.6, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(195, 145, 230), Glow = Color3.fromRGB(120, 219, 154), Style = "PuppetMaster",
	},
	TowerStormPhantom = {
		Id = "TowerStormPhantom", Name = "STORM PHANTOM", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.6, Hover = 10, Speed = 3.5, Wander = 3.5,
		Kind = "Tower", Color = Color3.fromRGB(160, 175, 255), Glow = Color3.fromRGB(219, 206, 113), Style = "StormPhantom",
	},
	TowerHauntedArmor = {
		Id = "TowerHauntedArmor", Name = "HAUNTED ARMOR", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.8, Hover = 10, Speed = 2.5, Wander = 4.5,
		Kind = "Tower", Color = Color3.fromRGB(150, 170, 225), Glow = Color3.fromRGB(120, 219, 154), Style = "HauntedArmor",
	},
	TowerCandleLich = {
		Id = "TowerCandleLich", Name = "CANDLE LICH", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.8, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(210, 200, 240), Glow = Color3.fromRGB(120, 219, 154), Style = "CandleLich",
	},
	TowerVampireCount = {
		Id = "TowerVampireCount", Name = "VAMPIRE COUNT", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.8, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(235, 225, 255), Glow = Color3.fromRGB(219, 99, 133), Style = "VampireCount",
	},
	TowerTitan = {
		Id = "TowerTitan", Name = "TOWER TITAN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 5, Hover = 10, Speed = 2.5, Wander = 5,
		Kind = "Tower", Color = Color3.fromRGB(170, 140, 255), Glow = Color3.fromRGB(106, 219, 202), Style = "CrystalTitan",
	},
	-- BIG milestone bosses (rooms 5, 10, 15, 20, then repeating). Bigger than every regular boss;
	-- Scale/Hover keep their tops under the room walls' battlements (~28 studs, no ceiling).
	TowerGraveColossus = {
		Id = "TowerGraveColossus", Name = "GRAVE COLOSSUS", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 5.4, Hover = 11, Speed = 2, Wander = 5,
		Kind = "Tower", Color = Color3.fromRGB(170, 172, 205), Glow = Color3.fromRGB(120, 219, 154), Style = "GraveColossus",
	},
	TowerVoidLeviathan = {
		Id = "TowerVoidLeviathan", Name = "VOID LEVIATHAN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 5.4, Hover = 13, Speed = 2.5, Wander = 5,
		Kind = "Tower", Color = Color3.fromRGB(85, 100, 200), Glow = Color3.fromRGB(106, 219, 188), Style = "VoidLeviathan",
	},
	TowerPhantomEmperor = {
		Id = "TowerPhantomEmperor", Name = "THE PHANTOM EMPEROR", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 5.2, Hover = 8.5, Speed = 2, Wander = 5,
		Kind = "Tower", Color = Color3.fromRGB(232, 222, 255), Glow = Color3.fromRGB(120, 219, 154), Style = "PhantomEmperor",
	},
	TowerEclipseOverlord = {
		Id = "TowerEclipseOverlord", Name = "ECLIPSE OVERLORD", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 5.2, Hover = 8.5, Speed = 2, Wander = 5,
		Kind = "Tower", Color = Color3.fromRGB(90, 70, 160), Glow = Color3.fromRGB(219, 185, 106), Style = "EclipseOverlord",
	},
	-- EVENT (scaled at spawn time by Config.Event)
	GiantPoltergeist = {
		Id = "GiantPoltergeist", Name = "GIANT POLTERGEIST", Zone = "Neighborhood",
		Spirit = 6000, Reward = 0, Drops = 0, Respawn = 0, Scale = 6, Hover = 14, Speed = 4, Wander = 5,
		Kind = "Event", Color = Color3.fromRGB(255, 120, 230), Glow = Color3.fromRGB(255, 230, 90), Style = "Giant",
	},	-- WORLD 2: THE OTHER SIDE (areas 17-32)
	-- ZONE 17
	LanternWisp = {
		Id = "LanternWisp", Name = "LANTERN WISP", Zone = "LanternMarket",
		Spirit = 72500000000000, Reward = 11500000000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(255, 235, 215), Glow = Color3.fromRGB(255, 170, 70), Style = "PaperLantern",
	},
	DumplingDrifter = {
		Id = "DumplingDrifter", Name = "DUMPLING DRIFTER", Zone = "LanternMarket",
		Spirit = 196000000000000, Reward = 29700000000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(250, 245, 230), Glow = Color3.fromRGB(255, 210, 140), Style = "Dumpling",
	},
	LanternDragon = {
		Id = "LanternDragon", Name = "LANTERN DRAGON SPIRIT", Zone = "LanternMarket",
		Spirit = 820000000000000, Reward = 113000000000000, Drops = 18, Respawn = 30, Scale = 6.35, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(230, 60, 60), Glow = Color3.fromRGB(255, 200, 80), Style = "DragonDance",
	},
	-- ZONE 18
	PageSprite = {
		Id = "PageSprite", Name = "PAGE SPRITE", Zone = "PhantomLibrary",
		Spirit = 363000000000000, Reward = 59800000000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(250, 245, 225), Glow = Color3.fromRGB(120, 255, 220), Style = "FlyingBook",
	},
	InkblotPhantom = {
		Id = "InkblotPhantom", Name = "INKBLOT PHANTOM", Zone = "PhantomLibrary",
		Spirit = 980000000000000, Reward = 154000000000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(70, 70, 120), Glow = Color3.fromRGB(140, 160, 255), Style = "Inkblot",
	},
	GrandGrimoire = {
		Id = "GrandGrimoire", Name = "THE GRAND GRIMOIRE", Zone = "PhantomLibrary",
		Spirit = 4.1e15, Reward = 588000000000000, Drops = 18, Respawn = 30, Scale = 6.50, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(120, 70, 50), Glow = Color3.fromRGB(120, 255, 220), Style = "Grimoire",
	},
	-- ZONE 19
	-- CornCob: small ghost wearing a corn cob as a tall hat (yellow cylinder dotted with kernel balls, green husk wedges peeling down), popcorn puffs drifting round it
	CornWisp = {
		Id = "CornWisp", Name = "CORN WISP", Zone = "PumpkinFarm",
		Spirit = 1.81e15, Reward = 311000000000000, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(255, 245, 205), Glow = Color3.fromRGB(255, 215, 80), Style = "CornCob",
	},
	-- HayBale: ghost wearing a hay bale like a barrel (straw block with two twine bands), straw tufts poking out, red bandana round its neck
	HayrideHaunt = {
		Id = "HayrideHaunt", Name = "HAYRIDE HAUNT", Zone = "PumpkinFarm",
		Spirit = 4.9e15, Reward = 803000000000000, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(245, 230, 180), Glow = Color3.fromRGB(255, 170, 60), Style = "HayBale",
	},
	-- Scarecrow: boss: wide floppy straw hat, burlap patches with big cross-stitches, straw tufts at the nubs, a wooden crossbeam behind its arms with three little crows (black balls, orange wedge beaks) perched on it
	ScarecrowKing = {
		Id = "ScarecrowKing", Name = "THE SCARECROW KING", Zone = "PumpkinFarm",
		Spirit = 2.05e16, Reward = 3.06e15, Drops = 18, Respawn = 30, Scale = 6.65, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(215, 185, 125), Glow = Color3.fromRGB(255, 140, 40), Style = "Scarecrow",
	},
	-- ZONE 20
	SporeWisp = {
		Id = "SporeWisp", Name = "SPORE WISP", Zone = "Glowshroom",
		Spirit = 9.06e15, Reward = 1.62e15, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(200, 255, 240), Glow = Color3.fromRGB(120, 255, 230), Style = "Spore",
	},
	MossyPhantom = {
		Id = "MossyPhantom", Name = "MOSSY PHANTOM", Zone = "Glowshroom",
		Spirit = 2.45e16, Reward = 4.18e15, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(150, 200, 140), Glow = Color3.fromRGB(190, 255, 130), Style = "Moss",
	},
	MyceliumMonarch = {
		Id = "MyceliumMonarch", Name = "THE MYCELIUM MONARCH", Zone = "Glowshroom",
		Spirit = 1.03e17, Reward = 1.59e16, Drops = 18, Respawn = 30, Scale = 6.80, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(90, 160, 160), Glow = Color3.fromRGB(120, 255, 230), Style = "Mycelium",
	},
	-- ZONE 21
	-- SwimRing: small ghost wearing a red-and-white striped swim ring round its middle, a snorkel mask over its eyes and a trail of water drops
	SplashSprite = {
		Id = "SplashSprite", Name = "SPLASH SPRITE", Zone = "WaterPark",
		Spirit = 4.53e16, Reward = 8.41e15, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(225, 245, 255), Glow = Color3.fromRGB(90, 230, 255), Style = "SwimRing",
	},
	-- Floatie: ghost lounging on a pink inflatable donut float, sunglasses pushed up on its head and a little drink umbrella stuck in the float
	LazyRiverPhantom = {
		Id = "LazyRiverPhantom", Name = "LAZY RIVER PHANTOM", Zone = "WaterPark",
		Spirit = 1.23e17, Reward = 2.17e16, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(205, 235, 250), Glow = Color3.fromRGB(255, 200, 120), Style = "Floatie",
	},
	-- WaveCrown: boss: rides a curling wave (arc of blue wedges topped with white foam balls) behind it, inflatable gold crown, lifeguard whistle on a cord, a loop of water-slide tube round its tail
	KingCannonball = {
		Id = "KingCannonball", Name = "KING CANNONBALL", Zone = "WaterPark",
		Spirit = 5.13e17, Reward = 8.26e16, Drops = 18, Respawn = 30, Scale = 6.95, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(80, 170, 230), Glow = Color3.fromRGB(255, 240, 140), Style = "WaveCrown",
	},
	-- ZONE 22
	GlintSpirit = {
		Id = "GlintSpirit", Name = "GLINT SPIRIT", Zone = "MirrorMaze",
		Spirit = 2.27e17, Reward = 4.37e16, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(235, 245, 255), Glow = Color3.fromRGB(200, 240, 255), Style = "Glint",
	},
	CopycatPhantom = {
		Id = "CopycatPhantom", Name = "COPYCAT PHANTOM", Zone = "MirrorMaze",
		Spirit = 6.13e17, Reward = 1.13e17, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(200, 220, 255), Glow = Color3.fromRGB(255, 180, 230), Style = "Copycat",
	},
	QueenOfReflections = {
		Id = "QueenOfReflections", Name = "QUEEN OF REFLECTIONS", Zone = "MirrorMaze",
		Spirit = 2.56e18, Reward = 4.3e17, Drops = 18, Respawn = 30, Scale = 7.10, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(220, 230, 255), Glow = Color3.fromRGB(255, 215, 120), Style = "MirrorQueen",
	},
	-- ZONE 23
	-- ShoppingBags: small ghost with a paper shopping bag hanging from each nub arm (blocks with thin handle loops), sunglasses on its head and a long receipt curling off its tail
	ShopperSpirit = {
		Id = "ShopperSpirit", Name = "SHOPPER SPIRIT", Zone = "ShoppingMall",
		Spirit = 1.13e18, Reward = 2.27e17, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(250, 235, 250), Glow = Color3.fromRGB(255, 140, 210), Style = "ShoppingBags",
	},
	-- Mannequin: ghost dressed like a shop-window mannequin: neat wig bob, a big price tag on a string, a scarf, and a thin display-stand pole under its tail
	MannequinPhantom = {
		Id = "MannequinPhantom", Name = "MANNEQUIN PHANTOM", Zone = "ShoppingMall",
		Spirit = 3.06e18, Reward = 5.87e17, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(235, 225, 215), Glow = Color3.fromRGB(130, 230, 255), Style = "Mannequin",
	},
	-- FoodCourt: boss: wears a food-court tray as a crown piled with a burger, fries and a giant soda cup with a bendy straw; ketchup and mustard bottles orbit it
	FoodCourtQueen = {
		Id = "FoodCourtQueen", Name = "QUEEN OF THE FOOD COURT", Zone = "ShoppingMall",
		Spirit = 1.28e19, Reward = 2.23e18, Drops = 18, Respawn = 30, Scale = 7.25, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(255, 190, 120), Glow = Color3.fromRGB(255, 230, 120), Style = "FoodCourt",
	},
	-- ZONE 24
	CommuterSpecter = {
		Id = "CommuterSpecter", Name = "COMMUTER SPECTER", Zone = "GhostSubway",
		Spirit = 5.66e18, Reward = 1.18e18, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(220, 225, 235), Glow = Color3.fromRGB(255, 220, 120), Style = "Commuter",
	},
	TicketPhantom = {
		Id = "TicketPhantom", Name = "TICKET PHANTOM", Zone = "GhostSubway",
		Spirit = 1.53e19, Reward = 3.05e18, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(200, 240, 220), Glow = Color3.fromRGB(255, 120, 120), Style = "Ticket",
	},
	PhantomExpress = {
		Id = "PhantomExpress", Name = "THE PHANTOM EXPRESS", Zone = "GhostSubway",
		Spirit = 6.41e19, Reward = 1.16e19, Drops = 18, Respawn = 30, Scale = 7.40, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(80, 90, 120), Glow = Color3.fromRGB(255, 230, 120), Style = "Locomotive",
	},
	-- ZONE 25
	-- Pterodactyl: small ghost with bony pterodactyl wings (thin bone-coloured wedges on rod struts), a long crest on the back of its head and a tiny beak
	FossilFlitter = {
		Id = "FossilFlitter", Name = "FOSSIL FLITTER", Zone = "DinoMuseum",
		Spirit = 2.83e19, Reward = 6.15e18, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(240, 230, 205), Glow = Color3.fromRGB(150, 230, 120), Style = "Pterodactyl",
	},
	-- RaptorSkull: ghost wearing a raptor skull as a helmet (long snout block with a row of tiny tooth wedges, round eye holes) and a curved claw on each nub
	RaptorSpecter = {
		Id = "RaptorSpecter", Name = "RAPTOR SPECTER", Zone = "DinoMuseum",
		Spirit = 7.66e19, Reward = 1.59e19, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(225, 215, 190), Glow = Color3.fromRGB(255, 200, 90), Style = "RaptorSkull",
	},
	-- BoneTyrant: boss: giant T-rex skeleton head worn over the ghost (big jaw blocks with tooth wedges), ribcage arcs round the body, tiny bony arms and a long tail of shrinking vertebra blocks
	BoneTyrant = {
		Id = "BoneTyrant", Name = "REX, THE BONE TYRANT", Zone = "DinoMuseum",
		Spirit = 3.2e20, Reward = 6.04e19, Drops = 18, Respawn = 30, Scale = 7.55, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(235, 225, 200), Glow = Color3.fromRGB(150, 230, 120), Style = "BoneTyrant",
	},
	-- ZONE 26
	-- Cheerleader: small ghost cheerleader: a fluffy pom-pom on each nub arm (clusters of small balls), a big hair bow and a little megaphone floating beside it
	CheerSpirit = {
		Id = "CheerSpirit", Name = "CHEER SPIRIT", Zone = "Stadium",
		Spirit = 1.42e20, Reward = 3.2e19, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(250, 245, 255), Glow = Color3.fromRGB(255, 120, 160), Style = "Cheerleader",
	},
	-- FoamFinger: ghost waving a giant foam '#1' hand (big block with one tall finger), a team cap on backwards and two face-paint stripes on each cheek
	FoamFingerPhantom = {
		Id = "FoamFingerPhantom", Name = "FOAM-FINGER PHANTOM", Zone = "Stadium",
		Spirit = 3.83e20, Reward = 8.26e19, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(230, 240, 255), Glow = Color3.fromRGB(120, 255, 140), Style = "FoamFinger",
	},
	-- Scoreboard: boss: its body is wrapped by a big stadium scoreboard (dark frame block with glowing digit bars), two horn speakers on top and a floodlight pole on each side
	PhantomScoreboard = {
		Id = "PhantomScoreboard", Name = "THE PHANTOM SCOREBOARD", Zone = "Stadium",
		Spirit = 1.6e21, Reward = 3.14e20, Drops = 18, Respawn = 30, Scale = 7.70, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(50, 60, 90), Glow = Color3.fromRGB(120, 255, 140), Style = "Scoreboard",
	},
	-- ZONE 27
	NeonSprite = {
		Id = "NeonSprite", Name = "NEON SPRITE", Zone = "NeonCity",
		Spirit = 7.08e20, Reward = 1.66e20, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(255, 200, 250), Glow = Color3.fromRGB(255, 80, 220), Style = "NeonSign",
	},
	GraffitiPhantom = {
		Id = "GraffitiPhantom", Name = "GRAFFITI PHANTOM", Zone = "NeonCity",
		Spirit = 1.91e21, Reward = 4.29e20, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(230, 240, 255), Glow = Color3.fromRGB(120, 255, 200), Style = "Graffiti",
	},
	BillboardBoss = {
		Id = "BillboardBoss", Name = "THE BILLBOARD BOSS", Zone = "NeonCity",
		Spirit = 8.01e21, Reward = 1.63e21, Drops = 18, Respawn = 30, Scale = 7.85, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(60, 60, 90), Glow = Color3.fromRGB(120, 240, 255), Style = "Billboard",
	},
	-- ZONE 28
	-- Crumb: tiny ghost hugging a cookie crumb as big as itself (lumpy brown block with chocolate-chip balls), rainbow sprinkle sticks floating round it
	CrumbSprite = {
		Id = "CrumbSprite", Name = "CRUMB SPRITE", Zone = "GiantsKitchen",
		Spirit = 3.54e21, Reward = 8.64e20, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(255, 240, 220), Glow = Color3.fromRGB(255, 170, 90), Style = "Crumb",
	},
	-- Teacup: ghost sitting in a flowery teacup (short wide cylinder with a ring handle) on a saucer disc, a tea-bag tag hanging over the rim, steam puffs rising
	TeacupPhantom = {
		Id = "TeacupPhantom", Name = "TEACUP PHANTOM", Zone = "GiantsKitchen",
		Spirit = 9.57e21, Reward = 2.23e21, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(245, 240, 255), Glow = Color3.fromRGB(255, 200, 230), Style = "Teacup",
	},
	-- CheeseWheel: boss: half inside a giant wedge of holey cheese (yellow wedge with darker hole discs), a mousetrap worn like a crown and a butter-knife sword
	BigCheese = {
		Id = "BigCheese", Name = "THE BIG CHEESE", Zone = "GiantsKitchen",
		Spirit = 4e22, Reward = 8.49e21, Drops = 18, Respawn = 30, Scale = 8.00, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(255, 215, 90), Glow = Color3.fromRGB(255, 170, 60), Style = "CheeseWheel",
	},
	-- ZONE 29
	-- Pixel: small ghost built from chunky pixels: cube steps round its outline, square 8-bit eyes, a stair-stepped tail and little square coins floating beside it
	PixelPhantom = {
		Id = "PixelPhantom", Name = "PIXEL PHANTOM", Zone = "CyberArcade",
		Spirit = 1.77e22, Reward = 4.5e21, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(230, 240, 255), Glow = Color3.fromRGB(80, 255, 220), Style = "Pixel",
	},
	-- Glitch: ghost with offset colour slices (thin pink and cyan copies shifted left and right), jagged error bars and a floating '?' block over its head
	GlitchGremlin = {
		Id = "GlitchGremlin", Name = "GLITCH GREMLIN", Zone = "CyberArcade",
		Spirit = 4.79e22, Reward = 1.16e22, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(200, 180, 255), Glow = Color3.fromRGB(255, 80, 200), Style = "Glitch",
	},
	-- GameOver: boss: wears an arcade cabinet like armour (tall box with a glowing screen round its face, joystick and big round buttons on the control deck, coin slot), pixel hearts orbiting
	GameOverGoliath = {
		Id = "GameOverGoliath", Name = "THE GAME OVER GOLIATH", Zone = "CyberArcade",
		Spirit = 2e23, Reward = 4.42e22, Drops = 18, Respawn = 30, Scale = 8.15, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(60, 40, 110), Glow = Color3.fromRGB(80, 255, 220), Style = "GameOver",
	},
	-- ZONE 30
	BreezeSpirit = {
		Id = "BreezeSpirit", Name = "BREEZE SPIRIT", Zone = "StormIslands",
		Spirit = 8.85e22, Reward = 2.34e22, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(230, 245, 255), Glow = Color3.fromRGB(170, 230, 255), Style = "Breeze",
	},
	ThundercloudPhantom = {
		Id = "ThundercloudPhantom", Name = "THUNDERCLOUD PHANTOM", Zone = "StormIslands",
		Spirit = 2.39e23, Reward = 6.04e22, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(150, 160, 190), Glow = Color3.fromRGB(255, 240, 120), Style = "Thundercloud",
	},
	TempestRoc = {
		Id = "TempestRoc", Name = "TEMPEST ROC", Zone = "StormIslands",
		Spirit = 1e24, Reward = 2.3e23, Drops = 18, Respawn = 30, Scale = 8.30, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(120, 140, 200), Glow = Color3.fromRGB(255, 240, 120), Style = "StormRoc",
	},
	-- ZONE 31
	MoondustSpirit = {
		Id = "MoondustSpirit", Name = "MOONDUST SPIRIT", Zone = "MoonBase",
		Spirit = 4.43e23, Reward = 1.22e23, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(230, 230, 220), Glow = Color3.fromRGB(200, 220, 255), Style = "Moondust",
	},
	AstroPhantom = {
		Id = "AstroPhantom", Name = "ASTRO PHANTOM", Zone = "MoonBase",
		Spirit = 1.2e24, Reward = 3.14e23, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(240, 245, 255), Glow = Color3.fromRGB(255, 150, 80), Style = "Astronaut",
	},
	SaucerOverseer = {
		Id = "SaucerOverseer", Name = "THE SAUCER OVERSEER", Zone = "MoonBase",
		Spirit = 5e24, Reward = 1.19e24, Drops = 18, Respawn = 30, Scale = 8.45, Hover = 12, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(150, 230, 170), Glow = Color3.fromRGB(140, 255, 160), Style = "Saucer",
	},
	-- ZONE 32
	VoidMote = {
		Id = "VoidMote", Name = "VOID MOTE", Zone = "VoidThrone",
		Spirit = 2.21e24, Reward = 6.32e23, Drops = 5, Respawn = 6, Scale = 1.55, Hover = 5.5, Speed = 5, Wander = 3.2,
		Kind = "Normal", Color = Color3.fromRGB(40, 30, 70), Glow = Color3.fromRGB(200, 150, 255), Style = "Mote",
	},
	RiftPhantom = {
		Id = "RiftPhantom", Name = "RIFT PHANTOM", Zone = "VoidThrone",
		Spirit = 5.98e24, Reward = 1.63e24, Drops = 6, Respawn = 9, Scale = 1.90, Hover = 6, Speed = 6, Wander = 2.7,
		Kind = "Normal", Color = Color3.fromRGB(70, 50, 120), Glow = Color3.fromRGB(255, 120, 255), Style = "Rift",
	},
	VoidHerald = {
		Id = "VoidHerald", Name = "VOID HERALD", Zone = "VoidThrone",
		Spirit = 2.5e25, Reward = 6.21e24, Drops = 18, Respawn = 30, Scale = 8.60, Hover = 14, Speed = 2.5, Wander = 6,
		Kind = "Boss", Color = Color3.fromRGB(50, 40, 90), Glow = Color3.fromRGB(255, 255, 255), Style = "Herald",
	},
	VoidEmperor = {
		Id = "VoidEmperor", Name = "THE VOID EMPEROR", Zone = "VoidThrone",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 6, Hover = 32, Speed = 2, Wander = 6, -- Spirit set at spawn (Config.WorldBoss)
		Kind = "WorldBoss", Color = Color3.fromRGB(20, 15, 35), Glow = Color3.fromRGB(255, 255, 255), Style = "VoidEmperor",
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
	-- Cap | Beanie | Fedora | Hood | Helmet | Mortarboard | Visor | Goggles | Halo
	-- | TopHat | Jester | NurseCap | HeadMirror | SailorCap | Bandana | Tricorn | KnightHelm | Wizard | Crown | Crystal
	Hat: string?,
	HatColor: Color3?,
	Back: string?, -- Backpack | Tank | Cape | Wings | Antenna | Balloons | MedKit | LifeRing | Shield | Orbs
	BackColor: Color3?,
	-- Flashlight | Vacuum | Scanner | Blaster | Cannon | Lantern | Staff | Projector
	-- | Megaphone | Wand | Orb | Spyglass | Sword
	Tool: string,
	ToolColor: Color3,
	Beam: Color3, -- attack beam colour
	Aura: boolean?, -- extra sparkle for high rarities
	Chrome: boolean?, -- shiny metal body (World 2)
	Signature: string?, -- one-of-a-kind effect set, e.g. "Supernova" (World 2 final Ultra)
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
	-- ZONE 4: Carnival crate
	CarnivalScout = {
		Id = "CarnivalScout", Name = "Carnival Scout", Rarity = "Common", Zone = "Carnival", Power = 750,
		Blurb = "Won every prize at the ring toss. Now tosses rings at ghosts.",
		Look = { Skin = C(255, 214, 170), Hair = C(255, 200, 60), HairStyle = "Short", Shirt = C(230, 60, 60), Pants = C(60, 90, 200), Shoes = C(250, 245, 230),
			Hat = "Cap", HatColor = C(255, 205, 60), Back = "Balloons", BackColor = C(80, 170, 255), Tool = "Megaphone", ToolColor = C(255, 210, 60), Beam = C(255, 230, 120) },
	},
	ParanormalPerformer = {
		Id = "ParanormalPerformer", Name = "Paranormal Performer", Rarity = "Uncommon", Zone = "Carnival", Power = 1250,
		Blurb = "Their best trick? Making ghosts disappear.",
		Look = { Skin = C(240, 195, 160), Hair = C(230, 90, 140), HairStyle = "Puff", Shirt = C(250, 240, 220), Pants = C(150, 80, 230), Shoes = C(230, 60, 60),
			Hat = "Jester", HatColor = C(150, 80, 230), Tool = "Wand", ToolColor = C(40, 40, 50), Beam = C(200, 140, 255) },
	},
	SpectralRingmaster = {
		Id = "SpectralRingmaster", Name = "Spectral Ringmaster", Rarity = "Rare", Zone = "Carnival", Power = 2100,
		Blurb = "Ladies, gentlemen and ghosts: the show is OVER.",
		Look = { Skin = C(200, 140, 100), Hair = C(40, 30, 30), HairStyle = "Short", Shirt = C(200, 40, 50), Pants = C(250, 240, 220), Shoes = C(30, 30, 40),
			Hat = "TopHat", HatColor = C(200, 40, 50), Back = "Cape", BackColor = C(60, 80, 190), Tool = "Wand", ToolColor = C(255, 210, 60), Beam = C(255, 110, 130) },
	},
	PhantomTamer = {
		Id = "PhantomTamer", Name = "Phantom Tamer", Rarity = "Legendary", Zone = "Carnival", Power = 5000,
		Blurb = "Taught a poltergeist to sit, stay and roll over.",
		Look = { Skin = C(255, 220, 190), Hair = C(250, 250, 255), HairStyle = "Long", Shirt = C(120, 60, 220), Pants = C(40, 30, 70), Shoes = C(255, 200, 60),
			Hat = "TopHat", HatColor = C(255, 200, 60), Back = "Cape", BackColor = C(230, 50, 70), Tool = "Orb", ToolColor = C(255, 205, 60), Beam = C(220, 120, 255), Aura = true },
	},
	-- ZONE 5: Paranormal Medical crate
	MedicalInvestigator = {
		Id = "MedicalInvestigator", Name = "Medical Investigator", Rarity = "Common", Zone = "Hospital", Power = 3800,
		Blurb = "Checks every ghost's pulse. Still waiting for one.",
		Look = { Skin = C(255, 210, 175), Hair = C(110, 70, 40), HairStyle = "Bob", Shirt = C(160, 210, 240), Pants = C(160, 210, 240), Shoes = C(250, 250, 255),
			Hat = "NurseCap", HatColor = C(250, 250, 255), Tool = "Scanner", ToolColor = C(140, 220, 200), Beam = C(130, 255, 200) },
	},
	SpiritMedic = {
		Id = "SpiritMedic", Name = "Spirit Medic", Rarity = "Uncommon", Zone = "Hospital", Power = 6300,
		Blurb = "Patches up hunters and scares off ghosts. Same flashlight.",
		Look = { Skin = C(190, 130, 95), Hair = C(30, 25, 30), HairStyle = "Short", Shirt = C(130, 190, 150), Pants = C(130, 190, 150), Shoes = C(250, 250, 255),
			Hat = "HeadMirror", HatColor = C(220, 225, 235), Back = "MedKit", BackColor = C(250, 250, 255), Tool = "Flashlight", ToolColor = C(200, 230, 255), Beam = C(160, 240, 255) },
	},
	ParanormalDoctor = {
		Id = "ParanormalDoctor", Name = "Paranormal Doctor", Rarity = "Rare", Zone = "Hospital", Power = 10500,
		Blurb = "Diagnosis: haunted. Treatment: one big beam.",
		Look = { Skin = C(240, 200, 165), Hair = C(200, 200, 210), HairStyle = "Short", Shirt = C(245, 248, 255), Pants = C(70, 90, 140), Shoes = C(60, 50, 50),
			Hat = "HeadMirror", HatColor = C(200, 210, 225), Back = "Tank", BackColor = C(150, 110, 230), Tool = "Projector", ToolColor = C(180, 140, 255), Beam = C(180, 130, 255) },
	},
	SpectralSurgeon = {
		Id = "SpectralSurgeon", Name = "Spectral Surgeon", Rarity = "Legendary", Zone = "Hospital", Power = 25000,
		Blurb = "Steady hands, glowing gloves, zero ghosts left.",
		Look = { Skin = C(255, 225, 200), Hair = C(60, 200, 190), HairStyle = "Spiky", Shirt = C(90, 200, 180), Pants = C(60, 150, 140), Shoes = C(250, 250, 255),
			Hat = "Visor", HatColor = C(120, 255, 200), Back = "Tank", BackColor = C(120, 255, 190), Tool = "Cannon", ToolColor = C(230, 240, 255), Beam = C(120, 255, 200), Aura = true },
	},
	-- ZONE 6: Spectral Sailor crate
	HarborHunter = {
		Id = "HarborHunter", Name = "Harbor Hunter", Rarity = "Common", Zone = "Harbor", Power = 19000,
		Blurb = "Smells like fish. Ghosts hate that.",
		Look = { Skin = C(240, 195, 155), Hair = C(150, 90, 50), HairStyle = "Short", Shirt = C(250, 205, 60), Pants = C(40, 60, 110), Shoes = C(60, 45, 35),
			Hat = "Beanie", HatColor = C(190, 60, 60), Back = "LifeRing", BackColor = C(240, 90, 70), Tool = "Lantern", ToolColor = C(90, 80, 70), Beam = C(140, 255, 170) },
	},
	ParanormalSailor = {
		Id = "ParanormalSailor", Name = "Paranormal Sailor", Rarity = "Uncommon", Zone = "Harbor", Power = 31000,
		Blurb = "Spots a ghost ship from ten miles away. With one eye closed.",
		Look = { Skin = C(255, 215, 180), Hair = C(240, 210, 120), HairStyle = "Spiky", Shirt = C(240, 245, 255), Pants = C(30, 50, 120), Shoes = C(30, 30, 40),
			Hat = "SailorCap", HatColor = C(250, 250, 255), Tool = "Spyglass", ToolColor = C(200, 160, 80), Beam = C(100, 230, 230) },
	},
	SpectralPirateHunter = {
		Id = "SpectralPirateHunter", Name = "Spectral Pirate Hunter", Rarity = "Rare", Zone = "Harbor", Power = 52000,
		Blurb = "Arrr-rests ghost pirates. Keeps the treasure maps.",
		Look = { Skin = C(170, 115, 80), Hair = C(25, 20, 25), HairStyle = "Long", Shirt = C(60, 140, 150), Pants = C(90, 60, 40), Shoes = C(40, 30, 25),
			Hat = "Bandana", HatColor = C(190, 50, 60), Back = "Backpack", BackColor = C(130, 90, 55), Tool = "Sword", ToolColor = C(200, 210, 220), Beam = C(120, 255, 190) },
	},
	GhostCaptainHunter = {
		Id = "GhostCaptainHunter", Name = "Ghost Captain Hunter", Rarity = "Legendary", Zone = "Harbor", Power = 125000,
		Blurb = "Commands a crew of ex-ghosts. They all salute.",
		Look = { Skin = C(250, 215, 185), Hair = C(240, 240, 245), HairStyle = "Bob", Shirt = C(30, 50, 110), Pants = C(240, 235, 220), Shoes = C(30, 25, 25),
			Hat = "Tricorn", HatColor = C(30, 40, 80), Back = "Cape", BackColor = C(160, 40, 50), Tool = "Cannon", ToolColor = C(150, 110, 60), Beam = C(100, 255, 200), Aura = true },
	},
	-- ZONE 7: Royal crate
	CastleInvestigator = {
		Id = "CastleInvestigator", Name = "Castle Investigator", Rarity = "Common", Zone = "Castle", Power = 95000,
		Blurb = "Has a map of every secret passage. Mostly.",
		Look = { Skin = C(255, 205, 165), Hair = C(140, 80, 40), HairStyle = "Short", Shirt = C(130, 130, 150), Pants = C(70, 60, 50), Shoes = C(60, 40, 30),
			Hat = "Hood", HatColor = C(60, 70, 120), Back = "Backpack", BackColor = C(140, 95, 55), Tool = "Lantern", ToolColor = C(110, 100, 90), Beam = C(255, 210, 120) },
	},
	SpiritKnight = {
		Id = "SpiritKnight", Name = "Spirit Knight", Rarity = "Uncommon", Zone = "Castle", Power = 155000,
		Blurb = "Sworn to protect the realm from spooky business.",
		Look = { Skin = C(230, 180, 140), Hair = C(90, 60, 40), HairStyle = "None", Shirt = C(60, 70, 150), Pants = C(150, 155, 170), Shoes = C(120, 125, 140),
			Hat = "KnightHelm", HatColor = C(170, 175, 190), Back = "Shield", BackColor = C(60, 70, 150), Tool = "Sword", ToolColor = C(200, 210, 230), Beam = C(140, 200, 255) },
	},
	RoyalExorcist = {
		Id = "RoyalExorcist", Name = "Royal Exorcist", Rarity = "Rare", Zone = "Castle", Power = 260000,
		Blurb = "The king's personal ghost remover. Very busy job.",
		Look = { Skin = C(200, 150, 115), Hair = C(220, 220, 230), HairStyle = "Long", Shirt = C(110, 50, 170), Pants = C(60, 30, 90), Shoes = C(255, 200, 70),
			Hat = "Wizard", HatColor = C(110, 50, 170), Back = "Cape", BackColor = C(180, 40, 60), Tool = "Staff", ToolColor = C(255, 200, 60), Beam = C(150, 255, 180) },
	},
	PhantomChampion = {
		Id = "PhantomChampion", Name = "Phantom Champion", Rarity = "Legendary", Zone = "Castle", Power = 625000,
		Blurb = "Undefeated in 1,000 duels against the undead.",
		Look = { Skin = C(255, 220, 190), Hair = C(255, 210, 90), HairStyle = "None", Shirt = C(150, 30, 60), Pants = C(60, 40, 90), Shoes = C(255, 200, 70),
			Hat = "KnightHelm", HatColor = C(255, 200, 70), Back = "Wings", BackColor = C(120, 255, 190), Tool = "Sword", ToolColor = C(255, 225, 120), Beam = C(120, 255, 190), Aura = true },
	},
	-- ZONE 8: Spirit Realm crate
	RealmExplorer = {
		Id = "RealmExplorer", Name = "Realm Explorer", Rarity = "Common", Zone = "SpiritRealm", Power = 470000,
		Blurb = "First human to map the floating islands. Got lost twice.",
		Look = { Skin = C(240, 200, 170), Hair = C(90, 200, 255), HairStyle = "Spiky", Shirt = C(60, 50, 110), Pants = C(40, 40, 70), Shoes = C(80, 230, 255),
			Hat = "Goggles", HatColor = C(80, 230, 255), Back = "Backpack", BackColor = C(80, 120, 220), Tool = "Scanner", ToolColor = C(90, 200, 255), Beam = C(90, 230, 255) },
	},
	SpiritWalker = {
		Id = "SpiritWalker", Name = "Spirit Walker", Rarity = "Uncommon", Zone = "SpiritRealm", Power = 780000,
		Blurb = "Walks between worlds. Never takes the stairs.",
		Look = { Skin = C(180, 130, 100), Hair = C(30, 20, 50), HairStyle = "Long", Shirt = C(90, 60, 170), Pants = C(50, 35, 100), Shoes = C(120, 255, 220),
			Hat = "Hood", HatColor = C(90, 60, 170), Back = "Orbs", BackColor = C(120, 255, 220), Tool = "Staff", ToolColor = C(80, 230, 255), Beam = C(110, 255, 230) },
	},
	VoidInvestigator = {
		Id = "VoidInvestigator", Name = "Void Investigator", Rarity = "Rare", Zone = "SpiritRealm", Power = 1300000,
		Blurb = "Stared into the void. The void blinked first.",
		Look = { Skin = C(225, 205, 255), Hair = C(250, 250, 255), HairStyle = "Spiky", Shirt = C(25, 20, 45), Pants = C(20, 15, 35), Shoes = C(190, 90, 255),
			Hat = "Visor", HatColor = C(190, 90, 255), Back = "Tank", BackColor = C(170, 80, 255), Tool = "Projector", ToolColor = C(60, 40, 90), Beam = C(190, 100, 255) },
	},
	CelestialGhostHunter = {
		Id = "CelestialGhostHunter", Name = "Celestial Ghost Hunter", Rarity = "Legendary", Zone = "SpiritRealm", Power = 3200000,
		Blurb = "The legend every hunter dreams of. Made of starlight and courage.",
		Look = { Skin = C(255, 230, 210), Hair = C(200, 230, 255), HairStyle = "Long", Shirt = C(240, 240, 255), Pants = C(70, 60, 160), Shoes = C(255, 220, 120),
			Hat = "Crystal", HatColor = C(130, 240, 255), Back = "Wings", BackColor = C(150, 220, 255), Tool = "Orb", ToolColor = C(255, 230, 140), Beam = C(140, 240, 255), Aura = true },
	},
	-- MYTHIC + SECRET (one of each per area: very rare crate pulls)
	MoonlightMedium = {
		Id = "MoonlightMedium", Name = "Moonlight Medium", Rarity = "Mythic", Zone = "Neighborhood", Power = 100,
		Blurb = "Talks to ghosts by moonlight. They talk back.",
		Look = { Skin = C(235, 215, 255), Hair = C(200, 170, 255), HairStyle = "Long", Shirt = C(70, 40, 140), Pants = C(40, 25, 90), Shoes = C(255, 120, 200),
			Hat = "Wizard", HatColor = C(90, 50, 180), Back = "Orbs", BackColor = C(255, 140, 220), Tool = "Orb", ToolColor = C(255, 230, 255), Beam = C(255, 140, 230), Aura = true },
	},
	NightWatcher = {
		Id = "NightWatcher", Name = "The Night Watcher", Rarity = "Secret", Zone = "Neighborhood", Power = 240,
		Blurb = "Nobody knows who they are. The ghosts do.",
		Look = { Skin = C(60, 55, 75), Hair = C(20, 20, 25), HairStyle = "None", Shirt = C(20, 20, 30), Pants = C(15, 15, 20), Shoes = C(240, 240, 255),
			Hat = "Hood", HatColor = C(15, 15, 25), Back = "Cape", BackColor = C(240, 240, 255), Tool = "Lantern", ToolColor = C(30, 30, 40), Beam = C(240, 240, 255), Aura = true },
	},
	GravelightOracle = {
		Id = "GravelightOracle", Name = "Gravelight Oracle", Rarity = "Mythic", Zone = "Cemetery", Power = 500,
		Blurb = "Reads the future in the glow of old candles.",
		Look = { Skin = C(255, 230, 210), Hair = C(140, 255, 190), HairStyle = "Long", Shirt = C(30, 90, 70), Pants = C(20, 50, 45), Shoes = C(255, 120, 90),
			Hat = "Crown", HatColor = C(120, 255, 180), Back = "Wings", BackColor = C(255, 140, 110), Tool = "Staff", ToolColor = C(255, 200, 120), Beam = C(255, 150, 120), Aura = true },
	},
	ReapersApprentice = {
		Id = "ReapersApprentice", Name = "Reaper's Apprentice", Rarity = "Secret", Zone = "Cemetery", Power = 1200,
		Blurb = "Borrowed the Reaper's lantern. Never gave it back.",
		Look = { Skin = C(230, 230, 240), Hair = C(30, 30, 35), HairStyle = "Spiky", Shirt = C(25, 25, 30), Pants = C(20, 20, 25), Shoes = C(120, 255, 170),
			Hat = "Hood", HatColor = C(25, 25, 30), Back = "Cape", BackColor = C(120, 255, 170), Tool = "Lantern", ToolColor = C(40, 40, 50), Beam = C(120, 255, 170), Aura = true },
	},
	SpiritValedictorian = {
		Id = "SpiritValedictorian", Name = "Spirit Valedictorian", Rarity = "Mythic", Zone = "School", Power = 2500,
		Blurb = "Top of the class in every subject, including Ghostology.",
		Look = { Skin = C(250, 215, 180), Hair = C(255, 140, 60), HairStyle = "Puff", Shirt = C(255, 200, 60), Pants = C(60, 40, 120), Shoes = C(255, 90, 160),
			Hat = "Mortarboard", HatColor = C(255, 200, 60), Back = "Wings", BackColor = C(255, 120, 200), Tool = "Projector", ToolColor = C(255, 220, 120), Beam = C(255, 120, 220), Aura = true },
	},
	TheSubstitute = {
		Id = "TheSubstitute", Name = "The Substitute", Rarity = "Secret", Zone = "School", Power = 6000,
		Blurb = "Shows up when nobody expects it. Ghosts get detention.",
		Look = { Skin = C(200, 190, 210), Hair = C(240, 240, 250), HairStyle = "Short", Shirt = C(35, 30, 45), Pants = C(25, 20, 35), Shoes = C(190, 110, 255),
			Hat = "Fedora", HatColor = C(25, 20, 35), Back = "Cape", BackColor = C(190, 110, 255), Tool = "Staff", ToolColor = C(60, 50, 80), Beam = C(200, 120, 255), Aura = true },
	},
	GrandIllusionist = {
		Id = "GrandIllusionist", Name = "Grand Illusionist", Rarity = "Mythic", Zone = "Carnival", Power = 12500,
		Blurb = "Saws ghosts in half. They're fine. Mostly.",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 60, 120), HairStyle = "Spiky", Shirt = C(255, 210, 60), Pants = C(200, 40, 70), Shoes = C(60, 90, 220),
			Hat = "TopHat", HatColor = C(255, 210, 60), Back = "Balloons", BackColor = C(255, 90, 160), Tool = "Wand", ToolColor = C(255, 255, 255), Beam = C(255, 90, 170), Aura = true },
	},
	TheLastClown = {
		Id = "TheLastClown", Name = "The Last Clown", Rarity = "Secret", Zone = "Carnival", Power = 30000,
		Blurb = "When the carnival closed, they stayed. Honk.",
		Look = { Skin = C(250, 250, 255), Hair = C(255, 60, 60), HairStyle = "Puff", Shirt = C(40, 30, 50), Pants = C(30, 25, 40), Shoes = C(255, 60, 60),
			Hat = "Jester", HatColor = C(40, 30, 50), Back = "Cape", BackColor = C(255, 60, 60), Tool = "Megaphone", ToolColor = C(255, 60, 60), Beam = C(255, 80, 80), Aura = true },
	},
	ChiefOfSpiritMedicine = {
		Id = "ChiefOfSpiritMedicine", Name = "Chief of Spirit Medicine", Rarity = "Mythic", Zone = "Hospital", Power = 62000,
		Blurb = "Prescribes one beam, twice a day.",
		Look = { Skin = C(240, 205, 170), Hair = C(230, 230, 240), HairStyle = "Bob", Shirt = C(250, 252, 255), Pants = C(110, 200, 255), Shoes = C(120, 255, 200),
			Hat = "HeadMirror", HatColor = C(255, 215, 90), Back = "Wings", BackColor = C(150, 230, 255), Tool = "Cannon", ToolColor = C(250, 252, 255), Beam = C(110, 220, 255), Aura = true },
	},
	NightShiftNurse = {
		Id = "NightShiftNurse", Name = "Night Shift Nurse", Rarity = "Secret", Zone = "Hospital", Power = 150000,
		Blurb = "Works the 3 AM shift. The ghosts are scared of HER.",
		Look = { Skin = C(225, 220, 235), Hair = C(30, 25, 40), HairStyle = "Long", Shirt = C(40, 35, 55), Pants = C(30, 25, 45), Shoes = C(120, 255, 200),
			Hat = "NurseCap", HatColor = C(40, 35, 55), Back = "MedKit", BackColor = C(120, 255, 200), Tool = "Flashlight", ToolColor = C(40, 35, 55), Beam = C(120, 255, 200), Aura = true },
	},
	KrakenTamer = {
		Id = "KrakenTamer", Name = "Kraken Tamer", Rarity = "Mythic", Zone = "Harbor", Power = 310000,
		Blurb = "Their pet is very big and very wet.",
		Look = { Skin = C(190, 140, 110), Hair = C(60, 200, 210), HairStyle = "Long", Shirt = C(20, 90, 110), Pants = C(30, 40, 80), Shoes = C(255, 200, 80),
			Hat = "Tricorn", HatColor = C(20, 90, 110), Back = "LifeRing", BackColor = C(255, 200, 80), Tool = "Sword", ToolColor = C(90, 255, 220), Beam = C(90, 255, 220), Aura = true },
	},
	FlyingDutchman = {
		Id = "FlyingDutchman", Name = "The Flying Dutchman", Rarity = "Secret", Zone = "Harbor", Power = 750000,
		Blurb = "Captain of the ship that never docks.",
		Look = { Skin = C(170, 230, 210), Hair = C(220, 255, 240), HairStyle = "Bob", Shirt = C(20, 50, 50), Pants = C(15, 35, 40), Shoes = C(100, 255, 200),
			Hat = "Tricorn", HatColor = C(15, 35, 40), Back = "Cape", BackColor = C(100, 255, 200), Tool = "Spyglass", ToolColor = C(100, 255, 200), Beam = C(100, 255, 200), Aura = true },
	},
	PhantomMonarch = {
		Id = "PhantomMonarch", Name = "Phantom Monarch", Rarity = "Mythic", Zone = "Castle", Power = 1550000,
		Blurb = "Rules the castle now. The old king is NOT happy.",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 220, 120), HairStyle = "Long", Shirt = C(130, 30, 170), Pants = C(60, 20, 90), Shoes = C(255, 210, 80),
			Hat = "Crown", HatColor = C(255, 210, 80), Back = "Cape", BackColor = C(200, 40, 70), Tool = "Staff", ToolColor = C(255, 210, 80), Beam = C(200, 110, 255), Aura = true },
	},
	HeadlessKnight = {
		Id = "HeadlessKnight", Name = "The Headless Knight", Rarity = "Secret", Zone = "Castle", Power = 3800000,
		Blurb = "Lost their head ages ago. Never lost a fight.",
		Look = { Skin = C(180, 185, 200), Hair = C(20, 20, 25), HairStyle = "None", Shirt = C(30, 30, 40), Pants = C(110, 115, 130), Shoes = C(30, 30, 40),
			Hat = "KnightHelm", HatColor = C(30, 30, 40), Back = "Shield", BackColor = C(120, 255, 170), Tool = "Sword", ToolColor = C(120, 255, 170), Beam = C(120, 255, 170), Aura = true },
	},
	AstralGuardian = {
		Id = "AstralGuardian", Name = "Astral Guardian", Rarity = "Mythic", Zone = "SpiritRealm", Power = 8000000,
		Blurb = "Guards the gate between every world at once.",
		Look = { Skin = C(230, 220, 255), Hair = C(255, 240, 180), HairStyle = "Long", Shirt = C(60, 40, 160), Pants = C(30, 20, 90), Shoes = C(110, 240, 255),
			Hat = "Crystal", HatColor = C(255, 220, 120), Back = "Wings", BackColor = C(110, 240, 255), Tool = "Staff", ToolColor = C(255, 220, 120), Beam = C(255, 200, 255), Aura = true },
	},
	GhostHunterZero = {
		Id = "GhostHunterZero", Name = "Ghost Hunter Zero", Rarity = "Secret", Zone = "SpiritRealm", Power = 20000000,
		Blurb = "The very first ghost hunter. Some say they ARE a ghost.",
		Look = { Skin = C(245, 245, 255), Hair = C(250, 250, 255), HairStyle = "Spiky", Shirt = C(15, 15, 20), Pants = C(10, 10, 15), Shoes = C(250, 250, 255),
			Hat = "Goggles", HatColor = C(250, 250, 255), Back = "Orbs", BackColor = C(250, 250, 255), Tool = "Cannon", ToolColor = C(250, 250, 255), Beam = C(250, 250, 255), Aura = true },
	},
	-- ZONES 9-16
	SwampScout = {
		Id = "SwampScout", Name = "Swamp Scout", Rarity = "Common", Zone = "Swamp", Power = 2350000,
		Blurb = "Squelches loudly. Ghosts hear them coming.",
		Look = { Skin = C(235, 190, 150), Hair = C(90, 60, 30), HairStyle = "Short", Shirt = C(110, 140, 70), Pants = C(80, 70, 50), Shoes = C(70, 50, 30),
			Hat = "Pith", HatColor = C(200, 180, 120), Back = "Backpack", BackColor = C(120, 90, 50), Tool = "Lantern", ToolColor = C(80, 70, 60), Beam = C(170, 255, 120) },
	},
	BogTracker = {
		Id = "BogTracker", Name = "Bog Tracker", Rarity = "Uncommon", Zone = "Swamp", Power = 3900000,
		Blurb = "Follows ghost slime trails for fun.",
		Look = { Skin = C(200, 140, 100), Hair = C(30, 30, 30), HairStyle = "Spiky", Shirt = C(80, 120, 60), Pants = C(50, 60, 40), Shoes = C(40, 40, 30),
			Hat = "Cap", HatColor = C(150, 200, 80), Back = "Tank", BackColor = C(150, 255, 120), Tool = "Vacuum", ToolColor = C(120, 160, 80), Beam = C(150, 255, 120) },
	},
	MarshMystic = {
		Id = "MarshMystic", Name = "Marsh Mystic", Rarity = "Rare", Zone = "Swamp", Power = 6500000,
		Blurb = "Talks to frogs. The frogs know where ghosts are.",
		Look = { Skin = C(220, 180, 150), Hair = C(60, 90, 50), HairStyle = "Long", Shirt = C(60, 100, 70), Pants = C(40, 60, 40), Shoes = C(100, 70, 40),
			Hat = "Hood", HatColor = C(50, 90, 60), Back = "Orbs", BackColor = C(200, 255, 100), Tool = "Staff", ToolColor = C(120, 90, 50), Beam = C(200, 255, 100) },
	},
	FireflySage = {
		Id = "FireflySage", Name = "Firefly Sage", Rarity = "Legendary", Zone = "Swamp", Power = 16000000,
		Blurb = "A thousand fireflies light the way.",
		Look = { Skin = C(255, 220, 190), Hair = C(255, 240, 150), HairStyle = "Long", Shirt = C(70, 110, 60), Pants = C(40, 70, 40), Shoes = C(255, 220, 90),
			Hat = "Wizard", HatColor = C(70, 110, 60), Back = "Wings", BackColor = C(255, 240, 120), Tool = "Orb", ToolColor = C(255, 220, 90), Beam = C(255, 240, 120), Aura = true },
	},
	FrogPrince = {
		Id = "FrogPrince", Name = "Frog Prince", Rarity = "Mythic", Zone = "Swamp", Power = 40000000,
		Blurb = "Kissed a ghost once. Wouldn't recommend.",
		Look = { Skin = C(140, 210, 120), Hair = C(80, 160, 60), HairStyle = "None", Shirt = C(60, 140, 60), Pants = C(40, 90, 40), Shoes = C(255, 210, 80),
			Hat = "Crown", HatColor = C(255, 210, 80), Back = "Cape", BackColor = C(200, 40, 60), Tool = "Wand", ToolColor = C(255, 210, 80), Beam = C(170, 255, 110), Aura = true },
	},
	GatorKing = {
		Id = "GatorKing", Name = "The Gator King", Rarity = "Secret", Zone = "Swamp", Power = 100000000,
		Blurb = "Rules the swamp with a big toothy grin.",
		Look = { Skin = C(90, 150, 80), Hair = C(40, 70, 40), HairStyle = "None", Shirt = C(50, 110, 60), Pants = C(40, 80, 50), Shoes = C(230, 230, 200),
			Hat = "Crown", HatColor = C(255, 210, 80), Back = "Shield", BackColor = C(80, 140, 70), Tool = "Trident", ToolColor = C(230, 230, 200), Beam = C(170, 255, 110), Aura = true },
	},
	SnowScout = {
		Id = "SnowScout", Name = "Snow Scout", Rarity = "Common", Zone = "Frost", Power = 11800000,
		Blurb = "Wears four jackets. Still cold.",
		Look = { Skin = C(255, 220, 200), Hair = C(150, 90, 50), HairStyle = "Bob", Shirt = C(80, 160, 230), Pants = C(60, 70, 110), Shoes = C(240, 240, 250),
			Hat = "Earmuffs", HatColor = C(255, 120, 150), Back = "Backpack", BackColor = C(80, 160, 230), Tool = "Flashlight", ToolColor = C(200, 230, 255), Beam = C(170, 240, 255) },
	},
	IceClimber = {
		Id = "IceClimber", Name = "Ice Climber", Rarity = "Uncommon", Zone = "Frost", Power = 19500000,
		Blurb = "Climbs glaciers to reach floating ghosts.",
		Look = { Skin = C(240, 200, 170), Hair = C(50, 40, 30), HairStyle = "Short", Shirt = C(230, 90, 80), Pants = C(60, 70, 110), Shoes = C(60, 50, 50),
			Hat = "Beanie", HatColor = C(80, 160, 230), Back = "Tank", BackColor = C(170, 240, 255), Tool = "Vacuum", ToolColor = C(200, 230, 255), Beam = C(170, 240, 255) },
	},
	FrostMage = {
		Id = "FrostMage", Name = "Frost Mage", Rarity = "Rare", Zone = "Frost", Power = 32500000,
		Blurb = "Freezes ghosts mid-boo.",
		Look = { Skin = C(230, 230, 255), Hair = C(240, 250, 255), HairStyle = "Long", Shirt = C(120, 180, 255), Pants = C(70, 100, 180), Shoes = C(230, 240, 255),
			Hat = "Wizard", HatColor = C(120, 180, 255), Back = "Cape", BackColor = C(200, 230, 255), Tool = "Staff", ToolColor = C(170, 220, 255), Beam = C(170, 240, 255) },
	},
	YetiWhisperer = {
		Id = "YetiWhisperer", Name = "Yeti Whisperer", Rarity = "Legendary", Zone = "Frost", Power = 80000000,
		Blurb = "Best friends with a very big snowman.",
		Look = { Skin = C(220, 190, 170), Hair = C(250, 250, 255), HairStyle = "Puff", Shirt = C(240, 245, 255), Pants = C(150, 170, 200), Shoes = C(120, 140, 170),
			Hat = "Hood", HatColor = C(240, 245, 255), Back = "Wings", BackColor = C(200, 240, 255), Tool = "Orb", ToolColor = C(200, 240, 255), Beam = C(140, 255, 240), Aura = true },
	},
	AuroraKnight = {
		Id = "AuroraKnight", Name = "Aurora Knight", Rarity = "Mythic", Zone = "Frost", Power = 200000000,
		Blurb = "Armor made of northern lights.",
		Look = { Skin = C(240, 220, 200), Hair = C(120, 255, 210), HairStyle = "None", Shirt = C(70, 200, 180), Pants = C(60, 90, 160), Shoes = C(200, 240, 255),
			Hat = "KnightHelm", HatColor = C(140, 230, 255), Back = "Shield", BackColor = C(120, 255, 210), Tool = "Sword", ToolColor = C(200, 255, 240), Beam = C(120, 255, 210), Aura = true },
	},
	TheAbominable = {
		Id = "TheAbominable", Name = "The Abominable", Rarity = "Secret", Zone = "Frost", Power = 500000000,
		Blurb = "Nobody has a clear photo of them.",
		Look = { Skin = C(250, 250, 255), Hair = C(250, 250, 255), HairStyle = "Puff", Shirt = C(240, 245, 255), Pants = C(220, 230, 245), Shoes = C(180, 200, 230),
			Hat = "Hood", HatColor = C(250, 250, 255), Back = "Cape", BackColor = C(170, 240, 255), Tool = "Cannon", ToolColor = C(200, 230, 255), Beam = C(170, 240, 255), Aura = true },
	},
	TombExplorer = {
		Id = "TombExplorer", Name = "Tomb Explorer", Rarity = "Common", Zone = "Tomb", Power = 58800000,
		Blurb = "Mapped every trap. Stepped on most of them.",
		Look = { Skin = C(220, 170, 120), Hair = C(120, 70, 30), HairStyle = "Short", Shirt = C(220, 190, 130), Pants = C(150, 110, 60), Shoes = C(110, 70, 40),
			Hat = "Pith", HatColor = C(220, 190, 130), Back = "Backpack", BackColor = C(150, 100, 60), Tool = "Flashlight", ToolColor = C(255, 220, 120), Beam = C(255, 230, 140) },
	},
	ScarabSeeker = {
		Id = "ScarabSeeker", Name = "Scarab Seeker", Rarity = "Uncommon", Zone = "Tomb", Power = 97500000,
		Blurb = "Collects beetles. Ghosts find that gross.",
		Look = { Skin = C(170, 110, 70), Hair = C(30, 25, 20), HairStyle = "Long", Shirt = C(70, 170, 180), Pants = C(190, 160, 110), Shoes = C(90, 60, 30),
			Hat = "Bandana", HatColor = C(70, 170, 180), Back = "Tank", BackColor = C(90, 255, 220), Tool = "Scanner", ToolColor = C(70, 170, 180), Beam = C(90, 255, 220) },
	},
	SandMage = {
		Id = "SandMage", Name = "Sand Mage", Rarity = "Rare", Zone = "Tomb", Power = 162000000,
		Blurb = "Builds sandcastles out of ghosts.",
		Look = { Skin = C(200, 140, 90), Hair = C(30, 30, 30), HairStyle = "None", Shirt = C(240, 230, 200), Pants = C(70, 170, 180), Shoes = C(255, 210, 80),
			Hat = "Nemes", HatColor = C(70, 170, 200), Back = "Cape", BackColor = C(70, 170, 200), Tool = "Staff", ToolColor = C(255, 210, 80), Beam = C(255, 220, 110) },
	},
	PharaohHunter = {
		Id = "PharaohHunter", Name = "Pharaoh Hunter", Rarity = "Legendary", Zone = "Tomb", Power = 400000000,
		Blurb = "Wears the crown of the last pharaoh they caught.",
		Look = { Skin = C(190, 130, 90), Hair = C(30, 30, 30), HairStyle = "None", Shirt = C(255, 210, 80), Pants = C(70, 170, 200), Shoes = C(255, 210, 80),
			Hat = "Nemes", HatColor = C(255, 210, 80), Back = "Wings", BackColor = C(255, 230, 140), Tool = "Cannon", ToolColor = C(255, 210, 80), Beam = C(255, 220, 110), Aura = true },
	},
	SunKeeper = {
		Id = "SunKeeper", Name = "Sun Keeper", Rarity = "Mythic", Zone = "Tomb", Power = 1000000000,
		Blurb = "Carries a piece of the desert sun.",
		Look = { Skin = C(210, 150, 100), Hair = C(255, 230, 140), HairStyle = "Long", Shirt = C(255, 240, 200), Pants = C(255, 200, 80), Shoes = C(255, 210, 80),
			Hat = "Crown", HatColor = C(255, 200, 60), Back = "Wings", BackColor = C(255, 180, 60), Tool = "Orb", ToolColor = C(255, 230, 140), Beam = C(255, 200, 90), Aura = true },
	},
	GoldenMummy = {
		Id = "GoldenMummy", Name = "The Golden Mummy", Rarity = "Secret", Zone = "Tomb", Power = 2500000000,
		Blurb = "Wrapped in gold. Unwrapped by nobody.",
		Look = { Skin = C(255, 215, 100), Hair = C(255, 215, 100), HairStyle = "None", Shirt = C(255, 215, 100), Pants = C(240, 220, 180), Shoes = C(255, 215, 100),
			Hat = "Nemes", HatColor = C(255, 215, 100), Back = "Cape", BackColor = C(240, 220, 180), Tool = "Staff", ToolColor = C(255, 215, 100), Beam = C(255, 230, 140), Aura = true },
	},
	ToyTinker = {
		Id = "ToyTinker", Name = "Toy Tinker", Rarity = "Common", Zone = "ToyFactory", Power = 294000000,
		Blurb = "Fixes toys. Unfixes ghosts.",
		Look = { Skin = C(255, 220, 190), Hair = C(240, 120, 60), HairStyle = "Puff", Shirt = C(80, 170, 255), Pants = C(255, 90, 120), Shoes = C(255, 220, 80),
			Hat = "Propeller", HatColor = C(255, 90, 120), Back = "Backpack", BackColor = C(255, 220, 80), Tool = "Wrench", ToolColor = C(200, 200, 210), Beam = C(255, 220, 120) },
	},
	WindUpKnight = {
		Id = "WindUpKnight", Name = "Wind-Up Knight", Rarity = "Uncommon", Zone = "ToyFactory", Power = 488000000,
		Blurb = "Fights for exactly 30 seconds per wind.",
		Look = { Skin = C(250, 215, 180), Hair = C(90, 60, 40), HairStyle = "None", Shirt = C(220, 50, 60), Pants = C(60, 80, 180), Shoes = C(30, 30, 40),
			Hat = "KnightHelm", HatColor = C(220, 50, 60), Back = "Shield", BackColor = C(60, 80, 180), Tool = "Sword", ToolColor = C(220, 220, 230), Beam = C(255, 140, 200) },
	},
	MarionetteMaster = {
		Id = "MarionetteMaster", Name = "Marionette Master", Rarity = "Rare", Zone = "ToyFactory", Power = 812000000,
		Blurb = "Pulls the strings. Ghosts dance.",
		Look = { Skin = C(240, 200, 170), Hair = C(40, 30, 40), HairStyle = "Long", Shirt = C(140, 60, 170), Pants = C(40, 30, 50), Shoes = C(255, 140, 200),
			Hat = "TopHat", HatColor = C(140, 60, 170), Back = "Cape", BackColor = C(255, 140, 200), Tool = "Wand", ToolColor = C(255, 255, 255), Beam = C(255, 140, 220) },
	},
	TeddyTitan = {
		Id = "TeddyTitan", Name = "Teddy Titan", Rarity = "Legendary", Zone = "ToyFactory", Power = 2000000000,
		Blurb = "A giant teddy with a giant heart.",
		Look = { Skin = C(200, 140, 100), Hair = C(120, 80, 50), HairStyle = "Puff", Shirt = C(190, 130, 80), Pants = C(140, 90, 60), Shoes = C(255, 220, 80),
			Hat = "Beanie", HatColor = C(190, 130, 80), Back = "Balloons", BackColor = C(255, 140, 200), Tool = "Cannon", ToolColor = C(255, 140, 200), Beam = C(255, 160, 220), Aura = true },
	},
	JackInTheBoxer = {
		Id = "JackInTheBoxer", Name = "Jack-in-the-Boxer", Rarity = "Mythic", Zone = "ToyFactory", Power = 5000000000,
		Blurb = "POP goes the ghost!",
		Look = { Skin = C(255, 220, 200), Hair = C(255, 90, 160), HairStyle = "Spiky", Shirt = C(255, 220, 80), Pants = C(80, 170, 255), Shoes = C(255, 90, 160),
			Hat = "Jester", HatColor = C(255, 90, 160), Back = "Balloons", BackColor = C(80, 170, 255), Tool = "Megaphone", ToolColor = C(255, 220, 80), Beam = C(255, 140, 220), Aura = true },
	},
	TheNutcracker = {
		Id = "TheNutcracker", Name = "The Nutcracker", Rarity = "Secret", Zone = "ToyFactory", Power = 12500000000,
		Blurb = "Cracks nuts. And cases.",
		Look = { Skin = C(240, 220, 200), Hair = C(255, 215, 90), HairStyle = "None", Shirt = C(220, 40, 50), Pants = C(30, 40, 90), Shoes = C(30, 30, 40),
			Hat = "KnightHelm", HatColor = C(220, 40, 50), Back = "Shield", BackColor = C(255, 215, 90), Tool = "Sword", ToolColor = C(255, 215, 90), Beam = C(255, 215, 120), Aura = true },
	},
	DeepDiver = {
		Id = "DeepDiver", Name = "Deep Diver", Rarity = "Common", Zone = "Sunken", Power = 1470000000,
		Blurb = "Holds their breath for 3 hours.",
		Look = { Skin = C(240, 200, 170), Hair = C(40, 40, 50), HairStyle = "None", Shirt = C(60, 140, 170), Pants = C(40, 90, 120), Shoes = C(40, 40, 50),
			Hat = "DivingHelmet", HatColor = C(220, 180, 90), Back = "Tank", BackColor = C(90, 255, 230), Tool = "Trident", ToolColor = C(220, 180, 90), Beam = C(90, 255, 230) },
	},
	CoralKeeper = {
		Id = "CoralKeeper", Name = "Coral Keeper", Rarity = "Uncommon", Zone = "Sunken", Power = 2440000000,
		Blurb = "Gardens the reef between ghost hunts.",
		Look = { Skin = C(200, 150, 110), Hair = C(250, 140, 120), HairStyle = "Puff", Shirt = C(255, 130, 140), Pants = C(60, 140, 170), Shoes = C(240, 240, 250),
			Hat = "Goggles", HatColor = C(90, 255, 230), Back = "Tank", BackColor = C(255, 130, 140), Tool = "Vacuum", ToolColor = C(255, 180, 170), Beam = C(140, 255, 220) },
	},
	TideCaller = {
		Id = "TideCaller", Name = "Tide Caller", Rarity = "Rare", Zone = "Sunken", Power = 4060000000,
		Blurb = "Calls the waves. The waves answer.",
		Look = { Skin = C(170, 220, 230), Hair = C(60, 200, 210), HairStyle = "Long", Shirt = C(40, 120, 150), Pants = C(30, 80, 110), Shoes = C(90, 255, 230),
			Hat = "Hood", HatColor = C(40, 120, 150), Back = "Cape", BackColor = C(90, 255, 230), Tool = "Staff", ToolColor = C(255, 220, 120), Beam = C(90, 255, 230) },
	},
	AtlanteanHunter = {
		Id = "AtlanteanHunter", Name = "Atlantean Hunter", Rarity = "Legendary", Zone = "Sunken", Power = 10000000000,
		Blurb = "From a city that sank on purpose.",
		Look = { Skin = C(180, 230, 240), Hair = C(255, 220, 120), HairStyle = "Long", Shirt = C(40, 140, 170), Pants = C(30, 90, 120), Shoes = C(255, 220, 120),
			Hat = "Crown", HatColor = C(255, 220, 120), Back = "Shield", BackColor = C(90, 255, 230), Tool = "Trident", ToolColor = C(255, 220, 120), Beam = C(90, 255, 230), Aura = true },
	},
	PearlSovereign = {
		Id = "PearlSovereign", Name = "Pearl Sovereign", Rarity = "Mythic", Zone = "Sunken", Power = 25000000000,
		Blurb = "Rules the deep with a glowing pearl.",
		Look = { Skin = C(240, 230, 255), Hair = C(240, 200, 255), HairStyle = "Long", Shirt = C(250, 245, 255), Pants = C(140, 200, 230), Shoes = C(255, 240, 255),
			Hat = "Crown", HatColor = C(255, 240, 255), Back = "Orbs", BackColor = C(255, 250, 255), Tool = "Orb", ToolColor = C(255, 250, 255), Beam = C(240, 200, 255), Aura = true },
	},
	AbyssWalker = {
		Id = "AbyssWalker", Name = "The Abyss Walker", Rarity = "Secret", Zone = "Sunken", Power = 62500000000,
		Blurb = "Came up from the very bottom.",
		Look = { Skin = C(30, 40, 60), Hair = C(20, 20, 30), HairStyle = "None", Shirt = C(15, 25, 45), Pants = C(10, 20, 35), Shoes = C(90, 255, 230),
			Hat = "DivingHelmet", HatColor = C(30, 40, 60), Back = "Cape", BackColor = C(90, 255, 230), Tool = "Trident", ToolColor = C(90, 255, 230), Beam = C(90, 255, 230), Aura = true },
	},
	GearScout = {
		Id = "GearScout", Name = "Gear Scout", Rarity = "Common", Zone = "Clockwork", Power = 7340000000,
		Blurb = "Hears every tick and tock.",
		Look = { Skin = C(255, 215, 180), Hair = C(150, 90, 40), HairStyle = "Spiky", Shirt = C(160, 110, 70), Pants = C(80, 60, 50), Shoes = C(60, 40, 30),
			Hat = "Goggles", HatColor = C(220, 180, 90), Back = "Backpack", BackColor = C(150, 100, 60), Tool = "Wrench", ToolColor = C(200, 180, 120), Beam = C(255, 200, 100) },
	},
	ClockTinker = {
		Id = "ClockTinker", Name = "Clock Tinker", Rarity = "Uncommon", Zone = "Clockwork", Power = 12200000000,
		Blurb = "Winds the clocks. Unwinds the ghosts.",
		Look = { Skin = C(230, 190, 150), Hair = C(60, 40, 30), HairStyle = "Short", Shirt = C(120, 80, 50), Pants = C(70, 60, 50), Shoes = C(50, 40, 30),
			Hat = "TopHat", HatColor = C(90, 70, 50), Back = "Tank", BackColor = C(255, 190, 90), Tool = "Scanner", ToolColor = C(230, 200, 120), Beam = C(255, 200, 100) },
	},
	ChronoMage = {
		Id = "ChronoMage", Name = "Chrono Mage", Rarity = "Rare", Zone = "Clockwork", Power = 20300000000,
		Blurb = "Hunts ghosts five minutes before they appear.",
		Look = { Skin = C(200, 150, 110), Hair = C(230, 230, 240), HairStyle = "Long", Shirt = C(90, 80, 140), Pants = C(60, 50, 90), Shoes = C(255, 200, 90),
			Hat = "Gears", HatColor = C(230, 200, 120), Back = "Cape", BackColor = C(90, 80, 140), Tool = "Staff", ToolColor = C(230, 200, 120), Beam = C(255, 210, 120) },
	},
	TimeBender = {
		Id = "TimeBender", Name = "Time Bender", Rarity = "Legendary", Zone = "Clockwork", Power = 50000000000,
		Blurb = "Was born tomorrow.",
		Look = { Skin = C(250, 230, 210), Hair = C(255, 230, 180), HairStyle = "Long", Shirt = C(240, 230, 210), Pants = C(120, 90, 60), Shoes = C(230, 200, 120),
			Hat = "Gears", HatColor = C(230, 200, 120), Back = "Wings", BackColor = C(230, 200, 120), Tool = "Orb", ToolColor = C(230, 200, 120), Beam = C(255, 220, 140), Aura = true },
	},
	SteamTitan = {
		Id = "SteamTitan", Name = "Steam Titan", Rarity = "Mythic", Zone = "Clockwork", Power = 125000000000,
		Blurb = "Powered by tea. Lots of tea.",
		Look = { Skin = C(200, 180, 160), Hair = C(80, 60, 40), HairStyle = "None", Shirt = C(150, 110, 70), Pants = C(90, 70, 50), Shoes = C(200, 180, 120),
			Hat = "KnightHelm", HatColor = C(200, 170, 110), Back = "Tank", BackColor = C(255, 190, 90), Tool = "Cannon", ToolColor = C(200, 170, 110), Beam = C(255, 200, 100), Aura = true },
	},
	TheTimeless = {
		Id = "TheTimeless", Name = "The Timeless One", Rarity = "Secret", Zone = "Clockwork", Power = 312000000000,
		Blurb = "Older than the clock tower itself.",
		Look = { Skin = C(230, 220, 255), Hair = C(255, 255, 255), HairStyle = "Long", Shirt = C(40, 35, 50), Pants = C(30, 25, 40), Shoes = C(255, 210, 120),
			Hat = "Gears", HatColor = C(255, 210, 120), Back = "Cape", BackColor = C(255, 210, 120), Tool = "Orb", ToolColor = C(255, 210, 120), Beam = C(255, 230, 160), Aura = true },
	},
	EmberScout = {
		Id = "EmberScout", Name = "Ember Scout", Rarity = "Common", Zone = "Inferno", Power = 36700000000,
		Blurb = "Toasts marshmallows on ghost fire.",
		Look = { Skin = C(240, 190, 150), Hair = C(255, 120, 40), HairStyle = "Spiky", Shirt = C(255, 140, 60), Pants = C(90, 50, 40), Shoes = C(60, 30, 30),
			Hat = "Goggles", HatColor = C(255, 200, 80), Back = "Backpack", BackColor = C(255, 140, 60), Tool = "Flashlight", ToolColor = C(255, 200, 80), Beam = C(255, 180, 80) },
	},
	LavaDiver = {
		Id = "LavaDiver", Name = "Lava Diver", Rarity = "Uncommon", Zone = "Inferno", Power = 60900000000,
		Blurb = "Swims in lava. Don't try it.",
		Look = { Skin = C(200, 150, 110), Hair = C(60, 30, 20), HairStyle = "None", Shirt = C(200, 80, 50), Pants = C(80, 40, 30), Shoes = C(60, 30, 30),
			Hat = "DivingHelmet", HatColor = C(255, 170, 80), Back = "Tank", BackColor = C(255, 120, 40), Tool = "Vacuum", ToolColor = C(255, 170, 80), Beam = C(255, 150, 60) },
	},
	FireDancer = {
		Id = "FireDancer", Name = "Fire Dancer", Rarity = "Rare", Zone = "Inferno", Power = 102000000000,
		Blurb = "Dances so hot the ghosts melt.",
		Look = { Skin = C(220, 160, 120), Hair = C(255, 90, 40), HairStyle = "Long", Shirt = C(255, 90, 60), Pants = C(255, 200, 80), Shoes = C(255, 90, 60),
			Hat = "Bandana", HatColor = C(255, 200, 80), Back = "Cape", BackColor = C(255, 90, 60), Tool = "Wand", ToolColor = C(255, 230, 140), Beam = C(255, 140, 60) },
	},
	PhoenixHunter = {
		Id = "PhoenixHunter", Name = "Phoenix Hunter", Rarity = "Legendary", Zone = "Inferno", Power = 250000000000,
		Blurb = "Rises again after every fall.",
		Look = { Skin = C(255, 220, 190), Hair = C(255, 150, 50), HairStyle = "Spiky", Shirt = C(255, 170, 60), Pants = C(160, 50, 40), Shoes = C(255, 200, 80),
			Hat = "Crown", HatColor = C(255, 200, 80), Back = "Wings", BackColor = C(255, 120, 40), Tool = "Cannon", ToolColor = C(255, 200, 80), Beam = C(255, 160, 60), Aura = true },
	},
	DragonCaller = {
		Id = "DragonCaller", Name = "Dragon Caller", Rarity = "Mythic", Zone = "Inferno", Power = 625000000000,
		Blurb = "Their pet is a dragon. Obviously.",
		Look = { Skin = C(240, 200, 170), Hair = C(200, 40, 40), HairStyle = "None", Shirt = C(160, 30, 40), Pants = C(60, 20, 30), Shoes = C(255, 160, 60),
			Hat = "KnightHelm", HatColor = C(255, 160, 60), Back = "Wings", BackColor = C(255, 90, 40), Tool = "Sword", ToolColor = C(255, 200, 90), Beam = C(255, 120, 50), Aura = true },
	},
	TheEternalFlame = {
		Id = "TheEternalFlame", Name = "The Eternal Flame", Rarity = "Secret", Zone = "Inferno", Power = 1560000000000,
		Blurb = "Has been burning since the first ghost.",
		Look = { Skin = C(255, 230, 200), Hair = C(255, 240, 180), HairStyle = "Long", Shirt = C(255, 140, 40), Pants = C(120, 30, 20), Shoes = C(255, 220, 120),
			Hat = "Hood", HatColor = C(255, 140, 40), Back = "Wings", BackColor = C(255, 200, 80), Tool = "Orb", ToolColor = C(255, 240, 180), Beam = C(255, 200, 90), Aura = true },
	},
	ThronePage = {
		Id = "ThronePage", Name = "Throne Page", Rarity = "Common", Zone = "Throne", Power = 184000000000,
		Blurb = "Carries the king's cape. And a ghost vacuum.",
		Look = { Skin = C(255, 215, 180), Hair = C(200, 150, 80), HairStyle = "Short", Shirt = C(110, 80, 190), Pants = C(250, 245, 255), Shoes = C(255, 215, 90),
			Hat = "Cap", HatColor = C(255, 215, 90), Back = "Backpack", BackColor = C(110, 80, 190), Tool = "Flashlight", ToolColor = C(255, 215, 90), Beam = C(255, 230, 140) },
	},
	ShadowGuard = {
		Id = "ShadowGuard", Name = "Shadow Guard", Rarity = "Uncommon", Zone = "Throne", Power = 305000000000,
		Blurb = "Hides in shadows. Ghosts hide from them.",
		Look = { Skin = C(170, 150, 200), Hair = C(40, 30, 60), HairStyle = "None", Shirt = C(40, 30, 60), Pants = C(30, 20, 50), Shoes = C(190, 120, 255),
			Hat = "Hood", HatColor = C(40, 30, 60), Back = "Cape", BackColor = C(190, 120, 255), Tool = "Sword", ToolColor = C(190, 120, 255), Beam = C(190, 120, 255) },
	},
	CrownMage = {
		Id = "CrownMage", Name = "Crown Mage", Rarity = "Rare", Zone = "Throne", Power = 508000000000,
		Blurb = "Every spell ends with a tiny crown.",
		Look = { Skin = C(230, 190, 160), Hair = C(240, 240, 255), HairStyle = "Long", Shirt = C(150, 90, 230), Pants = C(80, 50, 140), Shoes = C(255, 215, 90),
			Hat = "Crown", HatColor = C(255, 215, 90), Back = "Cape", BackColor = C(200, 40, 70), Tool = "Staff", ToolColor = C(255, 215, 90), Beam = C(220, 160, 255) },
	},
	KingsChampion = {
		Id = "KingsChampion", Name = "King's Champion", Rarity = "Legendary", Zone = "Throne", Power = 1250000000000,
		Blurb = "Defeated every ghost in the kingdom.",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 230, 140), HairStyle = "None", Shirt = C(250, 245, 255), Pants = C(110, 80, 190), Shoes = C(255, 215, 90),
			Hat = "KnightHelm", HatColor = C(255, 215, 90), Back = "Wings", BackColor = C(255, 230, 140), Tool = "Sword", ToolColor = C(255, 230, 140), Beam = C(255, 230, 140), Aura = true },
	},
	EternalMonarch = {
		Id = "EternalMonarch", Name = "Eternal Monarch", Rarity = "Mythic", Zone = "Throne", Power = 3120000000000,
		Blurb = "Wears every crown ever won.",
		Look = { Skin = C(240, 230, 255), Hair = C(255, 240, 200), HairStyle = "Long", Shirt = C(120, 60, 200), Pants = C(60, 30, 110), Shoes = C(255, 215, 90),
			Hat = "Crown", HatColor = C(255, 215, 90), Back = "Wings", BackColor = C(255, 240, 200), Tool = "Orb", ToolColor = C(255, 240, 200), Beam = C(255, 220, 160), Aura = true },
	},
	TheFinalHunter = {
		Id = "TheFinalHunter", Name = "The Final Hunter", Rarity = "Secret", Zone = "Throne", Power = 7810000000000,
		Blurb = "The last ghost hunter. Or the first.",
		Look = { Skin = C(250, 250, 255), Hair = C(255, 255, 255), HairStyle = "Spiky", Shirt = C(250, 250, 255), Pants = C(230, 230, 245), Shoes = C(255, 215, 90),
			Hat = "Crystal", HatColor = C(255, 230, 140), Back = "Wings", BackColor = C(255, 255, 255), Tool = "Cannon", ToolColor = C(255, 255, 255), Beam = C(255, 250, 220), Aura = true },
	},
	-- EXCLUSIVE (Robux Exclusive Crate: one per area, 1.5x that area's Legendary)
	ExclusiveNeighborhood = {
		Id = "ExclusiveNeighborhood", Name = "Golden Rookie", Rarity = "Exclusive", Zone = "Neighborhood", Power = 60,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 240, 170), HairStyle = "Spiky", Shirt = C(255, 215, 90), Pants = C(255, 240, 170), Shoes = C(255, 215, 90),
			Hat = "Cap", HatColor = C(255, 215, 90), Back = "Wings", BackColor = C(255, 240, 170), Tool = "Cannon", ToolColor = C(255, 215, 90), Beam = C(255, 240, 170), Aura = true },
	},
	ExclusiveCemetery = {
		Id = "ExclusiveCemetery", Name = "Diamond Warden", Rarity = "Exclusive", Zone = "Cemetery", Power = 300,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(240, 250, 255), HairStyle = "Spiky", Shirt = C(190, 240, 255), Pants = C(240, 250, 255), Shoes = C(190, 240, 255),
			Hat = "Hood", HatColor = C(190, 240, 255), Back = "Cape", BackColor = C(240, 250, 255), Tool = "Staff", ToolColor = C(190, 240, 255), Beam = C(240, 250, 255), Aura = true },
	},
	ExclusiveSchool = {
		Id = "ExclusiveSchool", Name = "Platinum Professor", Rarity = "Exclusive", Zone = "School", Power = 1500,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(170, 180, 210), HairStyle = "Spiky", Shirt = C(225, 228, 240), Pants = C(170, 180, 210), Shoes = C(225, 228, 240),
			Hat = "Mortarboard", HatColor = C(225, 228, 240), Back = "Wings", BackColor = C(170, 180, 210), Tool = "Projector", ToolColor = C(225, 228, 240), Beam = C(170, 180, 210), Aura = true },
	},
	ExclusiveCarnival = {
		Id = "ExclusiveCarnival", Name = "Prismatic Ringmaster", Rarity = "Exclusive", Zone = "Carnival", Power = 7500,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(120, 240, 255), HairStyle = "Spiky", Shirt = C(255, 120, 220), Pants = C(120, 240, 255), Shoes = C(255, 120, 220),
			Hat = "TopHat", HatColor = C(255, 120, 220), Back = "Cape", BackColor = C(120, 240, 255), Tool = "Wand", ToolColor = C(255, 120, 220), Beam = C(120, 240, 255), Aura = true },
	},
	ExclusiveHospital = {
		Id = "ExclusiveHospital", Name = "Crystal Surgeon", Rarity = "Exclusive", Zone = "Hospital", Power = 37500,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(150, 220, 255), HairStyle = "Spiky", Shirt = C(200, 250, 255), Pants = C(150, 220, 255), Shoes = C(200, 250, 255),
			Hat = "HeadMirror", HatColor = C(200, 250, 255), Back = "Wings", BackColor = C(150, 220, 255), Tool = "Cannon", ToolColor = C(200, 250, 255), Beam = C(150, 220, 255), Aura = true },
	},
	ExclusiveHarbor = {
		Id = "ExclusiveHarbor", Name = "Sapphire Captain", Rarity = "Exclusive", Zone = "Harbor", Power = 188000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(160, 200, 255), HairStyle = "Spiky", Shirt = C(60, 110, 255), Pants = C(160, 200, 255), Shoes = C(60, 110, 255),
			Hat = "Tricorn", HatColor = C(60, 110, 255), Back = "Cape", BackColor = C(160, 200, 255), Tool = "Cannon", ToolColor = C(60, 110, 255), Beam = C(160, 200, 255), Aura = true },
	},
	ExclusiveCastle = {
		Id = "ExclusiveCastle", Name = "Ruby Champion", Rarity = "Exclusive", Zone = "Castle", Power = 938000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 180, 200), HairStyle = "Spiky", Shirt = C(230, 40, 80), Pants = C(255, 180, 200), Shoes = C(230, 40, 80),
			Hat = "KnightHelm", HatColor = C(230, 40, 80), Back = "Wings", BackColor = C(255, 180, 200), Tool = "Sword", ToolColor = C(230, 40, 80), Beam = C(255, 180, 200), Aura = true },
	},
	ExclusiveSpiritRealm = {
		Id = "ExclusiveSpiritRealm", Name = "Rainbow Celestial", Rarity = "Exclusive", Zone = "SpiritRealm", Power = 4800000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(120, 240, 255), HairStyle = "Spiky", Shirt = C(255, 140, 220), Pants = C(120, 240, 255), Shoes = C(255, 140, 220),
			Hat = "Crystal", HatColor = C(255, 140, 220), Back = "Wings", BackColor = C(120, 240, 255), Tool = "Orb", ToolColor = C(255, 140, 220), Beam = C(120, 240, 255), Aura = true },
	},
	ExclusiveSwamp = {
		Id = "ExclusiveSwamp", Name = "Emerald Shaman", Rarity = "Exclusive", Zone = "Swamp", Power = 24000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(200, 255, 220), HairStyle = "Spiky", Shirt = C(60, 220, 130), Pants = C(200, 255, 220), Shoes = C(60, 220, 130),
			Hat = "Wizard", HatColor = C(60, 220, 130), Back = "Orbs", BackColor = C(200, 255, 220), Tool = "Staff", ToolColor = C(60, 220, 130), Beam = C(200, 255, 220), Aura = true },
	},
	ExclusiveFrost = {
		Id = "ExclusiveFrost", Name = "Diamond Yeti Rider", Rarity = "Exclusive", Zone = "Frost", Power = 120000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 255, 255), HairStyle = "Spiky", Shirt = C(200, 240, 255), Pants = C(255, 255, 255), Shoes = C(200, 240, 255),
			Hat = "Hood", HatColor = C(200, 240, 255), Back = "Cape", BackColor = C(255, 255, 255), Tool = "Cannon", ToolColor = C(200, 240, 255), Beam = C(255, 255, 255), Aura = true },
	},
	ExclusiveTomb = {
		Id = "ExclusiveTomb", Name = "Golden Pharaoh", Rarity = "Exclusive", Zone = "Tomb", Power = 600000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(70, 200, 220), HairStyle = "Spiky", Shirt = C(255, 210, 80), Pants = C(70, 200, 220), Shoes = C(255, 210, 80),
			Hat = "Crown", HatColor = C(255, 210, 80), Back = "Wings", BackColor = C(70, 200, 220), Tool = "Staff", ToolColor = C(255, 210, 80), Beam = C(70, 200, 220), Aura = true },
	},
	ExclusiveToyFactory = {
		Id = "ExclusiveToyFactory", Name = "Rainbow Teddy", Rarity = "Exclusive", Zone = "ToyFactory", Power = 3000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 240, 120), HairStyle = "Spiky", Shirt = C(255, 150, 210), Pants = C(255, 240, 120), Shoes = C(255, 150, 210),
			Hat = "Beanie", HatColor = C(255, 150, 210), Back = "Balloons", BackColor = C(255, 240, 120), Tool = "Orb", ToolColor = C(255, 150, 210), Beam = C(255, 240, 120), Aura = true },
	},
	ExclusiveSunken = {
		Id = "ExclusiveSunken", Name = "Pearl Admiral", Rarity = "Exclusive", Zone = "Sunken", Power = 15000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(200, 230, 255), HairStyle = "Spiky", Shirt = C(250, 245, 255), Pants = C(200, 230, 255), Shoes = C(250, 245, 255),
			Hat = "Crown", HatColor = C(250, 245, 255), Back = "Orbs", BackColor = C(200, 230, 255), Tool = "Orb", ToolColor = C(250, 245, 255), Beam = C(200, 230, 255), Aura = true },
	},
	ExclusiveClockwork = {
		Id = "ExclusiveClockwork", Name = "Chrome Chronomancer", Rarity = "Exclusive", Zone = "Clockwork", Power = 75000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(120, 240, 255), HairStyle = "Spiky", Shirt = C(200, 205, 220), Pants = C(120, 240, 255), Shoes = C(200, 205, 220),
			Hat = "TopHat", HatColor = C(200, 205, 220), Back = "Wings", BackColor = C(120, 240, 255), Tool = "Orb", ToolColor = C(200, 205, 220), Beam = C(120, 240, 255), Aura = true },
	},
	ExclusiveInferno = {
		Id = "ExclusiveInferno", Name = "Obsidian Phoenix", Rarity = "Exclusive", Zone = "Inferno", Power = 375000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 140, 60), HairStyle = "Spiky", Shirt = C(40, 30, 45), Pants = C(255, 140, 60), Shoes = C(40, 30, 45),
			Hat = "Hood", HatColor = C(40, 30, 45), Back = "Wings", BackColor = C(255, 140, 60), Tool = "Cannon", ToolColor = C(40, 30, 45), Beam = C(255, 140, 60), Aura = true },
	},
	ExclusiveThrone = {
		Id = "ExclusiveThrone", Name = "Prismatic King", Rarity = "Exclusive", Zone = "Throne", Power = 1880000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(200, 140, 255), HairStyle = "Spiky", Shirt = C(255, 215, 90), Pants = C(200, 140, 255), Shoes = C(255, 215, 90),
			Hat = "Crown", HatColor = C(255, 215, 90), Back = "Wings", BackColor = C(200, 140, 255), Tool = "Orb", ToolColor = C(255, 215, 90), Beam = C(200, 140, 255), Aura = true },
	},
	-- NEW HUNTERS (extras + one Ultra per crate)
	BowBelle = {
		Id = "BowBelle", Name = "Bow Belle", Rarity = "Common", Zone = "Neighborhood", Power = 5,
		Blurb = "Ties a bow on every ghost she catches. They secretly love it.",
		Look = { Skin = C(255, 220, 195), Hair = C(255, 170, 200), HairStyle = "Puff", Shirt = C(255, 190, 215), Pants = C(255, 230, 240), Shoes = C(255, 140, 190),
			Hat = "Bow", HatColor = C(255, 110, 170), Tool = "Flashlight", ToolColor = C(255, 200, 230), Beam = C(255, 180, 220) },
	},
	LilMoonWitch = {
		Id = "LilMoonWitch", Name = "Lil' Moon Witch", Rarity = "Uncommon", Zone = "Cemetery", Power = 50,
		Blurb = "Her first spell turned a ghost into a very confused moth.",
		Look = { Skin = C(240, 215, 200), Hair = C(190, 160, 240), HairStyle = "Long", Shirt = C(200, 170, 240), Pants = C(120, 90, 180), Shoes = C(90, 60, 140),
			Hat = "WitchHat", HatColor = C(130, 90, 200), Tool = "Wand", ToolColor = C(220, 200, 255), Beam = C(210, 180, 255) },
	},
	GloomyGus = {
		Id = "GloomyGus", Name = "Gloomy Gus", Rarity = "Uncommon", Zone = "School", Power = 250,
		Blurb = "A tiny monster who sighs a lot. Ghosts find it very relatable.",
		Look = { Skin = C(140, 160, 200), Hair = C(90, 100, 140), HairStyle = "None", Shirt = C(110, 120, 170), Pants = C(70, 80, 120), Shoes = C(60, 60, 90),
			Hat = "Beanie", HatColor = C(80, 90, 140), Tool = "Lantern", ToolColor = C(170, 200, 255), Beam = C(160, 190, 255) },
	},
	HeartlightHealer = {
		Id = "HeartlightHealer", Name = "Heartlight Healer", Rarity = "Rare", Zone = "Carnival", Power = 2100,
		Blurb = "Heals friends, hugs ghosts, wins every carnival kindness prize.",
		Look = { Skin = C(255, 215, 190), Hair = C(255, 120, 160), HairStyle = "Bob", Shirt = C(255, 170, 200), Pants = C(255, 230, 240), Shoes = C(255, 90, 140),
			Back = "HeartWings", BackColor = C(255, 140, 180), Tool = "HeartWand", ToolColor = C(255, 90, 150), Beam = C(255, 150, 200) },
	},
	StarlitHexPrincess = {
		Id = "StarlitHexPrincess", Name = "Starlit Hex Princess", Rarity = "Legendary", Zone = "Hospital", Power = 25000,
		Blurb = "Casts get-well-soon hexes. Ghosts get well, then get gone.",
		Look = { Skin = C(245, 220, 205), Hair = C(60, 40, 110), HairStyle = "Long", Shirt = C(70, 40, 130), Pants = C(40, 25, 80), Shoes = C(200, 170, 255),
			Hat = "Tiara", HatColor = C(255, 225, 120), Back = "Cape", BackColor = C(110, 70, 200), Tool = "Wand", ToolColor = C(255, 230, 150), Beam = C(220, 180, 255), Aura = true },
	},
	PumpkinKnight = {
		Id = "PumpkinKnight", Name = "Pumpkin Knight", Rarity = "Mythic", Zone = "Castle", Power = 1550000,
		Blurb = "Sworn to protect the castle patch. Smells faintly of pie.",
		Look = { Skin = C(230, 200, 170), Hair = C(60, 40, 30), HairStyle = "Short", Shirt = C(150, 155, 170), Pants = C(100, 105, 120), Shoes = C(70, 70, 80),
			Hat = "PumpkinHelm", HatColor = C(255, 140, 40), Back = "Shield", BackColor = C(170, 175, 190), Tool = "Sword", ToolColor = C(220, 225, 235), Beam = C(255, 170, 60), Aura = true },
	},
	CaptainBoo = {
		Id = "CaptainBoo", Name = "Captain Boo", Rarity = "Ultra", Zone = "Neighborhood", Power = 600,
		Blurb = "A friendly ghost who became a hero. Says BOO only to bad guys.",
		Look = { Skin = C(240, 245, 255), Hair = C(230, 235, 255), HairStyle = "None", Shirt = C(70, 120, 255), Pants = C(40, 60, 170), Shoes = C(255, 210, 60),
			Hat = "HeroMask", HatColor = C(255, 60, 80), Back = "HeroCape", BackColor = C(255, 60, 80), Tool = "Blaster", ToolColor = C(255, 210, 60), Beam = C(140, 200, 255), Aura = true },
	},
	PetalChomper = {
		Id = "PetalChomper", Name = "Petal Chomper", Rarity = "Ultra", Zone = "Cemetery", Power = 3000,
		Blurb = "Looks like a cute graveside flower. Has a LOT of teeth.",
		Look = { Skin = C(120, 200, 110), Hair = C(60, 140, 70), HairStyle = "None", Shirt = C(80, 170, 90), Pants = C(50, 120, 60), Shoes = C(40, 90, 50),
			Hat = "FlowerHead", HatColor = C(255, 120, 190), Tool = "Lantern", ToolColor = C(255, 170, 220), Beam = C(255, 130, 200), Aura = true },
	},
	CelestiaMoonwitch = {
		Id = "CelestiaMoonwitch", Name = "Celestia Moonwitch", Rarity = "Ultra", Zone = "School", Power = 15000,
		Blurb = "Top of every class, including the one about moon magic.",
		Look = { Skin = C(250, 225, 215), Hair = C(220, 200, 255), HairStyle = "Long", Shirt = C(200, 185, 255), Pants = C(170, 210, 255), Shoes = C(255, 200, 230),
			Hat = "MoonHood", HatColor = C(180, 160, 250), Back = "Wings", BackColor = C(230, 215, 255), Tool = "MoonStaff", ToolColor = C(255, 240, 180), Beam = C(200, 190, 255), Aura = true },
	},
	PumpkinKingJack = {
		Id = "PumpkinKingJack", Name = "Pumpkin King Jack", Rarity = "Ultra", Zone = "Carnival", Power = 75000,
		Blurb = "Rules the midway from a throne of hay bales. Long live the King!",
		Look = { Skin = C(230, 200, 170), Hair = C(40, 30, 30), HairStyle = "None", Shirt = C(90, 40, 130), Pants = C(40, 25, 60), Shoes = C(255, 200, 60),
			Hat = "PumpkinHelm", HatColor = C(255, 130, 30), Back = "Cape", BackColor = C(110, 40, 160), Tool = "PumpkinLance", ToolColor = C(255, 200, 60), Beam = C(255, 150, 40), Aura = true },
	},
	DoctorMiracle = {
		Id = "DoctorMiracle", Name = "Doctor Miracle", Rarity = "Ultra", Zone = "Hospital", Power = 375000,
		Blurb = "Masked surgeon by night. Patients feel better just seeing the cape.",
		Look = { Skin = C(210, 160, 120), Hair = C(40, 40, 50), HairStyle = "Short", Shirt = C(240, 250, 255), Pants = C(100, 190, 255), Shoes = C(255, 255, 255),
			Hat = "HeroMask", HatColor = C(80, 160, 255), Back = "HeroCape", BackColor = C(110, 200, 255), Tool = "Wand", ToolColor = C(160, 240, 255), Beam = C(130, 230, 255), Aura = true },
	},
	SirenSeraphina = {
		Id = "SirenSeraphina", Name = "Siren Seraphina", Rarity = "Ultra", Zone = "Harbor", Power = 1900000,
		Blurb = "Her song lures ghosts out of the fog and straight into the net.",
		Look = { Skin = C(235, 215, 205), Hair = C(80, 220, 210), HairStyle = "Long", Shirt = C(110, 200, 220), Pants = C(60, 140, 190), Shoes = C(250, 240, 220),
			Hat = "Tiara", HatColor = C(255, 230, 210), Back = "Orbs", BackColor = C(160, 240, 255), Tool = "Orb", ToolColor = C(200, 255, 250), Beam = C(120, 240, 230), Aura = true },
	},
	CountBatula = {
		Id = "CountBatula", Name = "Count Batula", Rarity = "Ultra", Zone = "Castle", Power = 9500000,
		Blurb = "A vampire bat with excellent manners and a terrible bedtime.",
		Look = { Skin = C(200, 200, 225), Hair = C(30, 20, 40), HairStyle = "Spiky", Shirt = C(40, 20, 50), Pants = C(25, 15, 35), Shoes = C(150, 20, 40),
			Hat = "TopHat", HatColor = C(30, 20, 40), Back = "BatWings", BackColor = C(120, 20, 50), Tool = "Wand", ToolColor = C(220, 30, 60), Beam = C(230, 50, 80), Aura = true },
	},
	StarfallValkyrie = {
		Id = "StarfallValkyrie", Name = "Starfall Valkyrie", Rarity = "Ultra", Zone = "SpiritRealm", Power = 50000000,
		Blurb = "Rides falling stars between worlds. Never misses a landing.",
		Look = { Skin = C(250, 225, 205), Hair = C(255, 240, 180), HairStyle = "Long", Shirt = C(220, 230, 255), Pants = C(120, 140, 230), Shoes = C(255, 230, 140),
			Hat = "Halo", HatColor = C(255, 240, 170), Back = "HeroCape", BackColor = C(140, 160, 255), Tool = "Sword", ToolColor = C(230, 240, 255), Beam = C(180, 200, 255), Aura = true },
	},
	Bogzilla = {
		Id = "Bogzilla", Name = "Bogzilla", Rarity = "Ultra", Zone = "Swamp", Power = 250000000,
		Blurb = "Rose from the swamp, stomped one ghost and decided he liked it.",
		Look = { Skin = C(90, 140, 70), Hair = C(60, 100, 50), HairStyle = "None", Shirt = C(110, 150, 60), Pants = C(70, 100, 40), Shoes = C(50, 70, 30),
			Hat = "Helmet", HatColor = C(80, 120, 50), Back = "Tank", BackColor = C(170, 255, 90), Tool = "Cannon", ToolColor = C(140, 220, 80), Beam = C(170, 255, 110), Aura = true },
	},
	CrystaliaSnowQueen = {
		Id = "CrystaliaSnowQueen", Name = "Crystalia Snow Queen", Rarity = "Ultra", Zone = "Frost", Power = 1250000000,
		Blurb = "Every snowflake is a tiny ghost trap. She made them all herself.",
		Look = { Skin = C(245, 240, 255), Hair = C(220, 240, 255), HairStyle = "Long", Shirt = C(200, 230, 255), Pants = C(160, 200, 250), Shoes = C(240, 250, 255),
			Hat = "Crystal", HatColor = C(170, 230, 255), Back = "Wings", BackColor = C(220, 245, 255), Tool = "MoonStaff", ToolColor = C(200, 240, 255), Beam = C(160, 230, 255), Aura = true },
	},
	JackalAvenger = {
		Id = "JackalAvenger", Name = "Jackal Avenger", Rarity = "Ultra", Zone = "Tomb", Power = 6250000000,
		Blurb = "Guardian of the tomb with a cape of gold and a nose for mummies.",
		Look = { Skin = C(60, 50, 60), Hair = C(20, 20, 25), HairStyle = "None", Shirt = C(30, 30, 40), Pants = C(255, 200, 80), Shoes = C(255, 200, 80),
			Hat = "Hood", HatColor = C(20, 20, 30), Back = "HeroCape", BackColor = C(255, 200, 80), Tool = "Staff", ToolColor = C(70, 200, 220), Beam = C(90, 220, 230), Aura = true },
	},
	PrincessPomPom = {
		Id = "PrincessPomPom", Name = "Princess Pom-Pom", Rarity = "Ultra", Zone = "ToyFactory", Power = 31000000000,
		Blurb = "Cutest toy on the shelf. Ghosts are hugged into submission.",
		Look = { Skin = C(255, 225, 205), Hair = C(255, 190, 225), HairStyle = "Puff", Shirt = C(255, 200, 230), Pants = C(255, 240, 170), Shoes = C(255, 150, 200),
			Hat = "Bow", HatColor = C(255, 120, 190), Back = "HeartWings", BackColor = C(255, 180, 220), Tool = "HeartWand", ToolColor = C(255, 240, 140), Beam = C(255, 170, 220), Aura = true },
	},
	GlubbleTheDeepOne = {
		Id = "GlubbleTheDeepOne", Name = "Glubble the Deep One", Rarity = "Ultra", Zone = "Sunken", Power = 156000000000,
		Blurb = "A tiny glowing sea monster with a lantern on its head. Very huggable. Maybe.",
		Look = { Skin = C(60, 170, 180), Hair = C(40, 120, 140), HairStyle = "None", Shirt = C(50, 140, 160), Pants = C(30, 90, 120), Shoes = C(20, 70, 90),
			Hat = "Crystal", HatColor = C(150, 255, 230), Back = "BatWings", BackColor = C(70, 190, 200), Tool = "Orb", ToolColor = C(160, 255, 240), Beam = C(120, 255, 230), Aura = true },
	},
	TickTockTitaness = {
		Id = "TickTockTitaness", Name = "Tick-Tock Titaness", Rarity = "Ultra", Zone = "Clockwork", Power = 780000000000,
		Blurb = "Stops time, catches the ghost, starts time. Nobody notices.",
		Look = { Skin = C(240, 205, 175), Hair = C(180, 90, 50), HairStyle = "Bob", Shirt = C(200, 140, 70), Pants = C(110, 70, 40), Shoes = C(230, 200, 120),
			Hat = "Visor", HatColor = C(120, 240, 255), Back = "HeroCape", BackColor = C(190, 110, 50), Tool = "Projector", ToolColor = C(230, 200, 120), Beam = C(120, 240, 255), Aura = true },
	},
	Scorchmaw = {
		Id = "Scorchmaw", Name = "Scorchmaw", Rarity = "Ultra", Zone = "Inferno", Power = 3900000000000,
		Blurb = "A lava monster with a fiery crown and a very hot temper.",
		Look = { Skin = C(200, 60, 40), Hair = C(255, 140, 40), HairStyle = "Spiky", Shirt = C(60, 25, 25), Pants = C(40, 15, 15), Shoes = C(255, 120, 40),
			Hat = "Crown", HatColor = C(255, 170, 50), Back = "Wings", BackColor = C(255, 90, 30), Tool = "Cannon", ToolColor = C(255, 150, 40), Beam = C(255, 110, 30), Aura = true },
	},
	SovereignSupreme = {
		Id = "SovereignSupreme", Name = "Sovereign Supreme", Rarity = "Ultra", Zone = "Throne", Power = 19500000000000,
		Blurb = "The hero every throne is waiting for. Ghosts bow before she asks.",
		Look = { Skin = C(245, 220, 200), Hair = C(255, 235, 170), HairStyle = "Long", Shirt = C(250, 245, 255), Pants = C(200, 170, 255), Shoes = C(255, 215, 90),
			Hat = "Tiara", HatColor = C(255, 215, 90), Back = "HeroCape", BackColor = C(255, 215, 90), Tool = "Sword", ToolColor = C(250, 245, 255), Beam = C(255, 230, 140), Aura = true },
	},	-- WORLD 2: THE OTHER SIDE (areas 17-32)
	-- ZONE 17: LANTERN CRATE
	StallSweeper = {
		Id = "StallSweeper", Name = "Stall Sweeper", Rarity = "Common", Zone = "LanternMarket", Power = 920000000000,
		Blurb = "Sweeps the market every night. The ghosts keep dropping crumbs.",
		Look = { Skin = C(240, 200, 160), Hair = C(40, 30, 30), HairStyle = "Short", Shirt = C(220, 60, 60), Pants = C(60, 40, 40), Shoes = C(30, 30, 35),
			Hat = "Cap", HatColor = C(255, 200, 80), Tool = "Vacuum", ToolColor = C(255, 120, 80), Beam = C(255, 190, 120) },
	},
	-- NOD: Rapunzel from Tangled (a magically long golden braid with flowers, floating lanterns); our own orange dress
	LanternLighter = {
		Id = "LanternLighter", Name = "Rapunzie Lanternlocks", Rarity = "Uncommon", Zone = "LanternMarket", Power = 1530000000000,
		Blurb = "Lets down her very long golden hair and lights a floating lantern for every ghost she catches.",
		Look = { Skin = C(225, 175, 135), Hair = C(250, 210, 110), HairStyle = "LongBraid", Shirt = C(255, 150, 60), Pants = C(80, 40, 40), Shoes = C(40, 30, 30),
			Back = "LanternPole", BackColor = C(230, 50, 50), Tool = "Lantern", ToolColor = C(255, 200, 90), Beam = C(255, 170, 70) },
	},
	ChefSqueaks = {
		Id = "ChefSqueaks", Name = "Chef Squeaks", Rarity = "Rare", Zone = "LanternMarket", Power = 2540000000000,
		Blurb = "A tiny chef with a big frying pan. Ghost soup is NOT on the menu.",
		Look = { Skin = C(175, 175, 190), Hair = C(175, 175, 190), HairStyle = "RoundEars", Shirt = C(250, 250, 250), Pants = C(70, 70, 90), Shoes = C(40, 40, 50),
			Hat = "ChefHat", HatColor = C(250, 250, 250), Tool = "FryingPan", ToolColor = C(60, 60, 70), Beam = C(255, 220, 140) },
	},
	DumplingDarla = {
		Id = "DumplingDarla", Name = "Dumpling Darla", Rarity = "Rare", Zone = "LanternMarket", Power = 2540000000000,
		Blurb = "Steams ghosts like dumplings, then sets them free extra fluffy.",
		Look = { Skin = C(245, 210, 180), Hair = C(30, 25, 30), HairStyle = "Buns", Shirt = C(120, 200, 180), Pants = C(250, 240, 220), Shoes = C(200, 70, 70),
			Tool = "SteamBasket", ToolColor = C(200, 160, 100), Beam = C(255, 245, 230) },
	},
	BigBao = {
		Id = "BigBao", Name = "Big Bao the Dumpling Warrior", Rarity = "Legendary", Zone = "LanternMarket", Power = 6250000000000,
		Blurb = "Black belt in kung-fu. Also in second helpings.",
		Look = { Skin = C(245, 245, 245), Hair = C(30, 30, 35), HairStyle = "RoundEars", Shirt = C(245, 245, 245), Pants = C(60, 170, 160), Shoes = C(30, 30, 35),
			Back = "Backpack", BackColor = C(200, 60, 60), Tool = "Staff", ToolColor = C(150, 200, 90), Beam = C(255, 220, 120), Aura = true },
	},
	FireworkFei = {
		Id = "FireworkFei", Name = "Firework Fei", Rarity = "Mythic", Zone = "LanternMarket", Power = 15600000000000,
		Blurb = "Every catch ends with a bang and a LOT of sparkles.",
		Look = { Skin = C(240, 205, 175), Hair = C(200, 40, 60), HairStyle = "Long", Shirt = C(255, 210, 80), Pants = C(200, 40, 60), Shoes = C(255, 210, 80),
			Back = "FireworkRack", BackColor = C(230, 50, 60), Tool = "Cannon", ToolColor = C(230, 50, 60), Beam = C(255, 120, 200), Aura = true },
	},
	MidnightNoodleMaster = {
		Id = "MidnightNoodleMaster", Name = "The Midnight Noodle Master", Rarity = "Secret", Zone = "LanternMarket", Power = 39100000000000,
		Blurb = "Nobody knows who he is. Everybody knows his noodles.",
		Look = { Skin = C(230, 190, 150), Hair = C(20, 20, 25), HairStyle = "None", Shirt = C(40, 30, 50), Pants = C(30, 25, 40), Shoes = C(180, 30, 40),
			Hat = "Hood", HatColor = C(40, 30, 50), Back = "Cape", BackColor = C(180, 30, 40), Tool = "FryingPan", ToolColor = C(255, 210, 90), Beam = C(255, 200, 120), Aura = true },
	},
	LumaLanternEmpress = {
		Id = "LumaLanternEmpress", Name = "Luma, Lantern Empress", Rarity = "Ultra", Zone = "LanternMarket", Power = 97500000000000,
		Blurb = "When she waves, a thousand lanterns rise and every ghost floats home happy.",
		Look = { Skin = C(245, 215, 190), Hair = C(255, 230, 170), HairStyle = "Long", Shirt = C(230, 50, 70), Pants = C(255, 200, 90), Shoes = C(255, 215, 90),
			Hat = "LanternRing", HatColor = C(230, 50, 60), Back = "HeroCape", BackColor = C(255, 200, 80), Tool = "Lantern", ToolColor = C(255, 215, 90), Beam = C(255, 180, 80), Aura = true },
	},
	-- ZONE 18: SPELLBOOK CRATE
	ShushScout = {
		Id = "ShushScout", Name = "Pajama Pip", Rarity = "Common", Zone = "PhantomLibrary", Power = 4600000000000,
		Blurb = "Fell asleep in the reading room. Woke up a ghost hunter.",
		Look = { Skin = C(245, 205, 175), Hair = C(150, 90, 50), HairStyle = "Bob", Shirt = C(130, 170, 240), Pants = C(130, 170, 240), Shoes = C(255, 150, 180),
			Hat = "Nightcap", HatColor = C(70, 100, 200), Tool = "Candle", ToolColor = C(220, 180, 90), Beam = C(255, 200, 110) },
	},
	-- NOD: The Very Hungry Caterpillar (green segments, red face, a nibbled apple); Benny's own pal Wiggles rides on his shoulders
	BookwormBenny = {
		Id = "BookwormBenny", Name = "Benny & the Hungry Bookworm", Rarity = "Uncommon", Zone = "PhantomLibrary", Power = 7650000000000,
		Blurb = "On Monday his worm pal Wiggles ate one book. On Tuesday, two. By Sunday he was hungry for ghosts.",
		Look = { Skin = C(160, 110, 80), Hair = C(30, 25, 25), HairStyle = "Short", Shirt = C(120, 200, 80), Pants = C(120, 85, 60), Shoes = C(220, 70, 60),
			Back = "Caterpillar", BackColor = C(120, 200, 70), Tool = "Spellbook", ToolColor = C(60, 110, 200), Beam = C(120, 255, 220) },
	},
	SpecsMcSpellbook = {
		Id = "SpecsMcSpellbook", Name = "Professor Hoot", Rarity = "Rare", Zone = "PhantomLibrary", Power = 12700000000000,
		Blurb = "A wise old owl. Can spot a ghost hiding in a footnote.",
		Look = { Skin = C(240, 220, 185), Hair = C(140, 95, 55), HairStyle = "Owl", Shirt = C(95, 120, 80), Pants = C(110, 85, 60), Shoes = C(245, 165, 45),
			Hat = "Specs", HatColor = C(255, 200, 70), Back = "Wings", BackColor = C(150, 105, 65), Tool = "Magnifier", ToolColor = C(255, 200, 70), Beam = C(255, 240, 170) },
	},
	PaigeTurner = {
		Id = "PaigeTurner", Name = "Paige Turner", Rarity = "Rare", Zone = "PhantomLibrary", Power = 12700000000000,
		Blurb = "Sorts ghosts like library books. The spooky ones go on the bottom shelf.",
		Look = { Skin = C(200, 140, 100), Hair = C(40, 30, 35), HairStyle = "Buns", Shirt = C(175, 55, 85), Pants = C(55, 55, 100), Shoes = C(40, 35, 45),
			Hat = "Bow", HatColor = C(255, 200, 70), Back = "BookCart", BackColor = C(165, 115, 70), Tool = "Stamp", ToolColor = C(200, 60, 70), Beam = C(255, 120, 160) },
	},
	QuillKnight = {
		Id = "QuillKnight", Name = "Sir Pop-Up", Rarity = "Legendary", Zone = "PhantomLibrary", Power = 31300000000000,
		Blurb = "Leapt out of a pop-up book, sword first. Folds flat at bedtime.",
		Look = { Skin = C(245, 210, 180), Hair = C(200, 90, 40), HairStyle = "Short", Shirt = C(215, 50, 65), Pants = C(245, 235, 215), Shoes = C(90, 70, 120),
			Hat = "KnightHelm", HatColor = C(245, 238, 220), Back = "PopUpCastle", BackColor = C(70, 90, 190), Tool = "Sword", ToolColor = C(245, 238, 220), Beam = C(255, 150, 160), Aura = true },
	},
	ArchivistAurelia = {
		Id = "ArchivistAurelia", Name = "Octavia Inkwell", Rarity = "Mythic", Zone = "PhantomLibrary", Power = 78000000000000,
		Blurb = "Eight arms, eight quills. Writes down a ghost's whole life story in one second.",
		Look = { Skin = C(190, 150, 235), Hair = C(140, 90, 205), HairStyle = "Octo", Shirt = C(40, 130, 140), Pants = C(30, 90, 100), Shoes = C(140, 90, 205),
			Back = "Tentacles", BackColor = C(150, 100, 215), Tool = "Quill", ToolColor = C(90, 230, 210), Beam = C(90, 240, 220), Aura = true },
	},
	TheOverdueOne = {
		Id = "TheOverdueOne", Name = "The Overdue One", Rarity = "Secret", Zone = "PhantomLibrary", Power = 196000000000000,
		Blurb = "A library book nobody ever returned... so it walked back on its own.",
		Look = { Skin = C(220, 230, 225), Hair = C(40, 60, 50), HairStyle = "None", Shirt = C(35, 70, 55), Pants = C(28, 45, 38), Shoes = C(200, 160, 60),
			Hat = "BookHead", HatColor = C(40, 105, 80), Back = "Pages", Tool = "Lantern", ToolColor = C(200, 160, 60), Beam = C(150, 255, 170), Aura = true },
	},
	InkwellStorySorcerer = {
		Id = "InkwellStorySorcerer", Name = "Grand Archmage Folio", Rarity = "Ultra", Zone = "PhantomLibrary", Power = 488000000000000,
		Blurb = "Says please, and every book in the library floats up to help.",
		Look = { Skin = C(235, 195, 165), Hair = C(200, 180, 255), HairStyle = "Beard", Shirt = C(75, 50, 170), Pants = C(60, 40, 140), Shoes = C(255, 205, 70),
			Hat = "Wizard", HatColor = C(55, 35, 130), Back = "RuneBooks", BackColor = C(230, 150, 50), Tool = "BookStaff", ToolColor = C(150, 60, 50), Beam = C(120, 255, 235), Aura = true },
	},
	-- ZONE 19: HARVEST CRATE
	FarmhandFinn = {
		Id = "FarmhandFinn", Name = "Farmhand Finn", Rarity = "Common", Zone = "PumpkinFarm", Power = 23000000000000,
		Blurb = "Up at dawn to feed the chickens. The ghost chickens too.",
		Look = { Skin = C(240, 200, 165), Hair = C(200, 120, 60), HairStyle = "Short", Shirt = C(200, 60, 50), Pants = C(70, 100, 160), Shoes = C(90, 60, 40),
			Hat = "Cap", HatColor = C(70, 130, 70), Back = "HayBale", BackColor = C(235, 200, 95), Tool = "Pitchfork", ToolColor = C(150, 105, 60), Beam = C(255, 200, 120) },
	},
	CornMazeCora = {
		Id = "CornMazeCora", Name = "Corn-Maze Cora", Rarity = "Uncommon", Zone = "PumpkinFarm", Power = 38300000000000,
		Blurb = "Knows every twist of the corn maze. Ghosts ask HER for directions.",
		Look = { Skin = C(200, 150, 110), Hair = C(60, 35, 25), HairStyle = "Braids", Shirt = C(250, 210, 80), Pants = C(90, 120, 70), Shoes = C(120, 80, 50),
			Hat = "StrawHat", HatColor = C(235, 200, 110), Back = "CornBasket", BackColor = C(170, 120, 70), Tool = "Lantern", ToolColor = C(255, 190, 80), Beam = C(255, 215, 120) },
	},
	-- NOD: the Scarecrow from The Wizard of Oz (straw hair, floppy patched hat, a diploma for his new brain); our own green shirt
	BrainyStrawford = {
		Id = "BrainyStrawford", Name = "Brainy Strawford", Rarity = "Rare", Zone = "PumpkinFarm", Power = 63500000000000,
		Blurb = "Finally got the brain he always wanted. Uses all of it for ghost puns.",
		Look = { Skin = C(235, 210, 160), Hair = C(245, 205, 95), HairStyle = "Spiky", Shirt = C(100, 150, 80), Pants = C(120, 95, 65), Shoes = C(80, 60, 40),
			Hat = "ScarecrowHat", HatColor = C(165, 130, 85), Tool = "Diploma", ToolColor = C(245, 235, 210), Beam = C(255, 170, 70) },
	},
	-- NOD: Wilbur from Charlotte's Web ('SOME PIG'); a pink pig in our own blue overalls with a friendly spider's web behind him, no words
	SomePigSammy = {
		Id = "SomePigSammy", Name = "Some-Pig Sammy", Rarity = "Rare", Zone = "PumpkinFarm", Power = 63500000000000,
		Blurb = "A spider wrote SOME HUNTER in a web over his pen. Everybody agrees.",
		Look = { Skin = C(255, 180, 190), Hair = C(255, 165, 180), HairStyle = "Piggy", Shirt = C(255, 180, 190), Pants = C(80, 130, 200), Shoes = C(200, 120, 130),
			Back = "SpiderWeb", BackColor = C(245, 245, 250), Tool = "Scanner", ToolColor = C(255, 220, 120), Beam = C(255, 190, 210) },
	},
	-- NOD: the nursery rhyme Old MacDonald Had a Farm (public domain)
	OldMacBoonald = {
		Id = "OldMacBoonald", Name = "Old MacBoonald", Rarity = "Legendary", Zone = "PumpkinFarm", Power = 156000000000000,
		Blurb = "Had a farm. E-I-E-I-BOO! With a ghost-ghost here and a ghost-ghost there.",
		Look = { Skin = C(235, 195, 165), Hair = C(235, 235, 235), HairStyle = "Beard", Shirt = C(210, 60, 60), Pants = C(70, 100, 160), Shoes = C(80, 55, 35),
			Hat = "StrawHat", HatColor = C(230, 195, 110), Back = "Chicken", BackColor = C(205, 125, 65), Tool = "Pitchfork", ToolColor = C(170, 170, 185), Beam = C(255, 220, 140), Aura = true },
	},
	GemmaGourdheart = {
		Id = "GemmaGourdheart", Name = "Gemma Gourdheart", Rarity = "Mythic", Zone = "PumpkinFarm", Power = 390000000000000,
		Blurb = "Grows pumpkins as big as houses. Ghosts move in. She moves them out.",
		Look = { Skin = C(240, 200, 170), Hair = C(200, 90, 40), HairStyle = "Long", Shirt = C(90, 140, 70), Pants = C(120, 80, 50), Shoes = C(200, 110, 40),
			Hat = "FlowerHead", HatColor = C(255, 205, 60), Back = "GiantPumpkin", BackColor = C(255, 140, 40), Tool = "WateringCan", ToolColor = C(90, 170, 110), Beam = C(255, 170, 70), Aura = true },
	},
	-- NOD: the Headless Horseman from The Legend of Sleepy Hollow (public domain); friendly, with a lantern
	HeadlessHayrider = {
		Id = "HeadlessHayrider", Name = "The Headless Hayrider", Rarity = "Secret", Zone = "PumpkinFarm", Power = 978000000000000,
		Blurb = "Rides through the patch every Halloween looking for his head. Catches ghosts on the way.",
		Look = { Skin = C(60, 50, 60), Hair = C(30, 30, 35), HairStyle = "None", Shirt = C(40, 35, 50), Pants = C(30, 28, 35), Shoes = C(20, 20, 25),
			Hat = "PumpkinHelm", HatColor = C(255, 140, 40), Back = "Cape", BackColor = C(30, 25, 35), Tool = "Lantern", ToolColor = C(255, 150, 40), Beam = C(255, 150, 50), Aura = true },
	},
	AutumnaHarvestQueen = {
		Id = "AutumnaHarvestQueen", Name = "Autumna, Harvest Queen", Rarity = "Ultra", Zone = "PumpkinFarm", Power = 2.44e15,
		Blurb = "Shakes one golden leaf and every pumpkin in the patch lights up. Ghosts can't resist a glow-up.",
		Look = { Skin = C(245, 215, 190), Hair = C(220, 110, 40), HairStyle = "Long", Shirt = C(230, 140, 40), Pants = C(150, 60, 40), Shoes = C(255, 210, 90),
			Hat = "Crown", HatColor = C(255, 200, 80), Back = "FeatherWings", BackColor = C(200, 70, 40), Tool = "PumpkinLance", ToolColor = C(255, 200, 80), Beam = C(255, 170, 60), Aura = true },
	},
	-- ZONE 20: GLOWSHROOM CRATE
	SporeSniffer = {
		Id = "SporeSniffer", Name = "Spore Sniffer", Rarity = "Common", Zone = "Glowshroom", Power = 115000000000000,
		Blurb = "Can smell a ghost through forty mushrooms.",
		Look = { Skin = C(250, 215, 185), Hair = C(170, 90, 50), HairStyle = "Short", Shirt = C(80, 150, 90), Pants = C(80, 70, 50), Shoes = C(70, 50, 30),
			Hat = "Cap", HatColor = C(60, 130, 80), Back = "Backpack", BackColor = C(150, 110, 60), Tool = "Scanner", ToolColor = C(120, 255, 230), Beam = C(120, 255, 230) },
	},
	-- NOD: Totoro from My Neighbor Totoro (big round grey forest spirit, pale belly, whiskers, leaf umbrella); our own shapes
	MossRangerMo = {
		Id = "MossRangerMo", Name = "Neighbour Tumtum", Rarity = "Uncommon", Zone = "Glowshroom", Power = 191000000000000,
		Blurb = "A big, fluffy forest spirit. Waits at the glowshroom bus stop with a leaf for an umbrella.",
		Look = { Skin = C(150, 150, 165), Hair = C(150, 150, 165), HairStyle = "Spirit", Shirt = C(150, 150, 165), Pants = C(225, 225, 215), Shoes = C(120, 120, 135),
			Back = "BigBelly", BackColor = C(150, 150, 165), Tool = "Umbrella", ToolColor = C(90, 170, 80), Beam = C(120, 255, 210) },
	},
	GrandpaBluecap = {
		Id = "GrandpaBluecap", Name = "Grandpa Bluecap", Rarity = "Rare", Zone = "Glowshroom", Power = 318000000000000,
		Blurb = "Three apples tall and a hundred years wise.",
		Look = { Skin = C(110, 160, 230), Hair = C(250, 250, 250), HairStyle = "Beard", Shirt = C(60, 170, 170), Pants = C(60, 170, 170), Shoes = C(240, 240, 240),
			Hat = "ShroomCap", HatColor = C(60, 190, 190), Tool = "Staff", ToolColor = C(150, 100, 60), Beam = C(120, 255, 230) },
	},
	TeaTimeTilly = {
		Id = "TeaTimeTilly", Name = "Tea-Time Tilly", Rarity = "Rare", Zone = "Glowshroom", Power = 318000000000000,
		Blurb = "Hosts a tea party every hour. Ghosts must RSVP.",
		Look = { Skin = C(250, 220, 200), Hair = C(255, 140, 60), HairStyle = "Puff", Shirt = C(120, 200, 120), Pants = C(240, 230, 200), Shoes = C(160, 80, 120),
			Hat = "TopHat", HatColor = C(60, 140, 120), Tool = "Teapot", ToolColor = C(250, 245, 240), Beam = C(255, 200, 240) },
	},
	GlowcapGuardian = {
		Id = "GlowcapGuardian", Name = "Glowcap Guardian", Rarity = "Legendary", Zone = "Glowshroom", Power = 781000000000000,
		Blurb = "Wears a mushroom so bright that ghosts need sunglasses.",
		Look = { Skin = C(230, 190, 160), Hair = C(60, 40, 30), HairStyle = "Short", Shirt = C(70, 120, 110), Pants = C(50, 80, 70), Shoes = C(40, 60, 50),
			Hat = "ShroomCap", HatColor = C(120, 255, 230), Back = "Shield", BackColor = C(170, 130, 90), Tool = "Sword", ToolColor = C(140, 230, 120), Beam = C(140, 255, 160), Aura = true },
	},
	QueenMorel = {
		Id = "QueenMorel", Name = "Queen Morel", Rarity = "Mythic", Zone = "Glowshroom", Power = 1.95e15,
		Blurb = "Rules the forest from a toadstool throne. A very small throne.",
		Look = { Skin = C(240, 205, 180), Hair = C(120, 70, 40), HairStyle = "Long", Shirt = C(170, 120, 200), Pants = C(110, 80, 150), Shoes = C(255, 215, 90),
			Hat = "Crown", HatColor = C(255, 215, 90), Back = "Wings", BackColor = C(160, 255, 220), Tool = "MoonStaff", ToolColor = C(200, 255, 230), Beam = C(180, 255, 220), Aura = true },
	},
	TheSporefather = {
		Id = "TheSporefather", Name = "The Sporefather", Rarity = "Secret", Zone = "Glowshroom", Power = 4.89e15,
		Blurb = "One puff and the whole forest glows.",
		Look = { Skin = C(200, 210, 190), Hair = C(90, 100, 80), HairStyle = "Beard", Shirt = C(60, 70, 60), Pants = C(40, 50, 40), Shoes = C(30, 35, 30),
			Hat = "Hood", HatColor = C(70, 90, 70), Back = "Orbs", BackColor = C(120, 255, 230), Tool = "Orb", ToolColor = C(120, 255, 230), Beam = C(120, 255, 230), Aura = true },
	},
	LuminaBloomheart = {
		Id = "LuminaBloomheart", Name = "Lumina Bloomheart", Rarity = "Ultra", Zone = "Glowshroom", Power = 1.22e16,
		Blurb = "Every step grows a glowing mushroom. Ghosts get lost admiring them.",
		Look = { Skin = C(245, 225, 210), Hair = C(150, 255, 230), HairStyle = "Long", Shirt = C(250, 240, 255), Pants = C(120, 220, 210), Shoes = C(255, 180, 230),
			Hat = "ShroomCrown", HatColor = C(120, 255, 230), Back = "Wings", BackColor = C(200, 255, 245), Tool = "MoonStaff", ToolColor = C(255, 180, 230), Beam = C(150, 255, 230), Aura = true },
	},
	-- ZONE 21: SPLASH CRATE
	-- NOD: Baywatch (lifeguards running along the beach in slow motion); our own red swimsuit, sun hat and rescue float, no logo
	LifeguardLuca = {
		Id = "LifeguardLuca", Name = "Boowatch Bailey", Rarity = "Common", Zone = "WaterPark", Power = 575000000000000,
		Blurb = "Runs along the pool edge in slow motion. Every ghost gets rescued... straight into her trap.",
		Look = { Skin = C(240, 195, 160), Hair = C(250, 215, 110), HairStyle = "Long", Shirt = C(225, 45, 55), Pants = C(225, 45, 55), Shoes = C(250, 250, 250),
			Hat = "GuardHat", HatColor = C(245, 230, 190), Tool = "RescueCan", ToolColor = C(255, 140, 40), Beam = C(120, 230, 255) },
	},
	SunscreenSam = {
		Id = "SunscreenSam", Name = "Floatie Finn", Rarity = "Uncommon", Zone = "WaterPark", Power = 956000000000000,
		Blurb = "Can't swim a stroke, so he never takes off his duck float. Ghosts think it's cute. Big mistake.",
		Look = { Skin = C(245, 215, 190), Hair = C(215, 120, 55), HairStyle = "Spiky", Shirt = C(60, 190, 230), Pants = C(255, 140, 60), Shoes = C(255, 220, 60),
			Hat = "Snorkel", HatColor = C(255, 215, 60), Back = "DuckFloat", BackColor = C(255, 220, 60), Tool = "SquirtGun", ToolColor = C(120, 215, 90), Beam = C(120, 230, 255) },
	},
	-- NOD: The Little Mermaid (the fairy tale and the film: a mermaid who sings); our own coral hair, gold shell top and violet tail, no film costume
	MermaidenMarina = {
		Id = "MermaidenMarina", Name = "Coralie Finsong", Rarity = "Rare", Zone = "WaterPark", Power = 1.59e15,
		Blurb = "Give up her voice for legs? Never! She sings so sweetly the ghosts swim right up to her.",
		Look = { Skin = C(240, 205, 180), Hair = C(245, 110, 95), HairStyle = "Floaty", Shirt = C(150, 230, 215), Pants = C(130, 90, 210), Shoes = C(130, 90, 210),
			Hat = "ShellTiara", HatColor = C(255, 190, 80), Back = "MerTail", BackColor = C(130, 90, 210), Tool = "Conch", ToolColor = C(255, 200, 180), Beam = C(255, 150, 190) },
	},
	-- NOD: SpongeBob SquarePants (a square sea sponge fry cook who goes jellyfishing); our own green scrub top, teal shirt and orange shorts, no tie
	ForgetfulFlo = {
		Id = "ForgetfulFlo", Name = "Scrubby Spongeworth", Rarity = "Rare", Zone = "WaterPark", Power = 1.59e15,
		Blurb = "I'm ready! I'm ready! Flips ghosts like burgers and goes jellyfishing on his day off.",
		Look = { Skin = C(250, 225, 80), Hair = C(250, 225, 80), HairStyle = "None", Shirt = C(70, 190, 200), Pants = C(255, 150, 60), Shoes = C(40, 40, 50),
			Hat = "SpongeHead", HatColor = C(90, 185, 90), Back = "Jellyfish", BackColor = C(255, 140, 200), Tool = "Spatula", ToolColor = C(205, 210, 220), Beam = C(160, 230, 255) },
	},
	-- NOD: the surfer-dude sea turtle from Finding Nemo ("totally, dude"); our own shades, board shorts and longboard
	SplashGordon = {
		Id = "SplashGordon", Name = "Shellby, the Surf Turtle", Rarity = "Legendary", Zone = "WaterPark", Power = 3.91e15,
		Blurb = "Has been riding the wave pool for 150 years. Totally catches ghosts, dude!",
		Look = { Skin = C(130, 195, 110), Hair = C(130, 195, 110), HairStyle = "None", Shirt = C(130, 195, 110), Pants = C(255, 140, 60), Shoes = C(130, 195, 110),
			Hat = "Shades", HatColor = C(25, 25, 30), Back = "SeaTurtle", BackColor = C(115, 145, 70), Tool = "Longboard", ToolColor = C(80, 210, 230), Beam = C(120, 240, 255), Aura = true },
	},
	-- NOD: Moana (an island voyager who sails past the reef); our own teal top, sail, paddle and lei, no film outfit
	SlideQueenShayla = {
		Id = "SlideQueenShayla", Name = "Leilani Wayfinder", Rarity = "Mythic", Zone = "WaterPark", Power = 9.75e15,
		Blurb = "Reads the stars and the waves. Wherever the ghosts drift, she already knows the way.",
		Look = { Skin = C(175, 120, 85), Hair = C(40, 25, 20), HairStyle = "Long", Shirt = C(60, 160, 160), Pants = C(240, 200, 120), Shoes = C(175, 120, 85),
			Hat = "Hibiscus", HatColor = C(255, 90, 120), Back = "CanoeSail", BackColor = C(235, 205, 145), Tool = "Paddle", ToolColor = C(190, 135, 80), Beam = C(110, 235, 200), Aura = true },
	},
	GnawsGentleShark = {
		Id = "GnawsGentleShark", Name = "Abyssal Annie", Rarity = "Secret", Zone = "WaterPark", Power = 2.44e16,
		Blurb = "Hunts in the deep end where the lights don't reach. Her little lure brings every ghost swimming close.",
		Look = { Skin = C(235, 205, 185), Hair = C(30, 40, 70), HairStyle = "None", Shirt = C(40, 60, 105), Pants = C(30, 45, 80), Shoes = C(250, 200, 60),
			Hat = "AnglerHood", HatColor = C(50, 75, 120), Tool = "GhostNet", ToolColor = C(240, 200, 90), Beam = C(170, 255, 200), Aura = true },
	},
	TsunamiTiaWaveRider = {
		Id = "TsunamiTiaWaveRider", Name = "Nerissa Tidecaller, Serpent Rider", Rarity = "Ultra", Zone = "WaterPark", Power = 6.09e16,
		Blurb = "The sea serpent of the wave pool only listens to her. One song from her coral staff and it sweeps every ghost into the trap.",
		Look = { Skin = C(205, 150, 115), Hair = C(60, 215, 205), HairStyle = "Long", Shirt = C(40, 120, 170), Pants = C(30, 80, 140), Shoes = C(255, 215, 110),
			Hat = "CoralCrown", HatColor = C(255, 120, 140), Back = "SeaSerpent", BackColor = C(40, 175, 165), Tool = "CoralStaff", ToolColor = C(255, 120, 140), Beam = C(150, 250, 255), Aura = true },
	},
	-- ZONE 22: MIRROR CRATE
	-- NOD: the magic mirror from Snow White ('mirror, mirror on the wall', fairy tale): he carries it and keeps it polished
	PolisherPip = {
		Id = "PolisherPip", Name = "Mirror-Mirror Mervin", Rarity = "Common", Zone = "MirrorMaze", Power = 2.88e15,
		Blurb = "Polishes the magic mirror every day. It keeps telling him he's the fairest hunter of them all.",
		Look = { Skin = C(250, 215, 185), Hair = C(240, 200, 100), HairStyle = "Short", Shirt = C(120, 180, 230), Pants = C(70, 80, 110), Shoes = C(240, 240, 250),
			Hat = "Cap", HatColor = C(200, 220, 240), Back = "MagicMirror", BackColor = C(235, 190, 80), Tool = "Brush", ToolColor = C(150, 110, 70), Beam = C(200, 240, 255) },
	},
	MazeMapper = {
		Id = "MazeMapper", Name = "Maze Mapper", Rarity = "Uncommon", Zone = "MirrorMaze", Power = 4.78e15,
		Blurb = "Has a map of the maze. It's also a mirror. Very confusing.",
		Look = { Skin = C(190, 140, 100), Hair = C(30, 25, 25), HairStyle = "Bob", Shirt = C(240, 200, 120), Pants = C(90, 80, 70), Shoes = C(70, 60, 50),
			Hat = "Visor", HatColor = C(170, 230, 255), Back = "Backpack", BackColor = C(120, 140, 180), Tool = "Scanner", ToolColor = C(200, 220, 255), Beam = C(180, 230, 255) },
	},
	LookingGlassLucy = {
		Id = "LookingGlassLucy", Name = "Looking-Glass Lucy", Rarity = "Rare", Zone = "MirrorMaze", Power = 7.94e15,
		Blurb = "Stepped through a mirror and never looked back. Well, once.",
		Look = { Skin = C(250, 225, 205), Hair = C(250, 200, 150), HairStyle = "Long", Shirt = C(200, 180, 255), Pants = C(250, 250, 255), Shoes = C(40, 40, 50),
			Hat = "Bow", HatColor = C(200, 180, 255), Tool = "HandMirror", ToolColor = C(255, 215, 90), Beam = C(220, 200, 255) },
	},
	CopycatCass = {
		Id = "CopycatCass", Name = "Copycat Cass", Rarity = "Rare", Zone = "MirrorMaze", Power = 7.94e15,
		Blurb = "Copies every move you make. Including this one.",
		Look = { Skin = C(220, 180, 150), Hair = C(170, 180, 210), HairStyle = "Bob", Shirt = C(200, 205, 220), Pants = C(120, 130, 160), Shoes = C(200, 205, 220),
			Hat = "Goggles", HatColor = C(200, 205, 220), Back = "MirrorShards", BackColor = C(220, 235, 255), Tool = "HandMirror", ToolColor = C(200, 205, 220), Beam = C(200, 240, 255) },
	},
	PrismKnight = {
		Id = "PrismKnight", Name = "Prism Knight", Rarity = "Legendary", Zone = "MirrorMaze", Power = 1.95e16,
		Blurb = "Bends light into a rainbow, then bonks ghosts with it.",
		Look = { Skin = C(240, 205, 180), Hair = C(255, 255, 255), HairStyle = "Short", Shirt = C(220, 230, 250), Pants = C(150, 160, 200), Shoes = C(200, 210, 240),
			Hat = "Crystal", HatColor = C(200, 240, 255), Back = "Shield", BackColor = C(220, 235, 255), Tool = "Sword", ToolColor = C(220, 240, 255), Beam = C(255, 160, 230), Aura = true, Chrome = true },
	},
	MirageMystic = {
		Id = "MirageMystic", Name = "Mirage Mystic", Rarity = "Mythic", Zone = "MirrorMaze", Power = 4.88e16,
		Blurb = "You're never sure which one is the real her. Neither are the ghosts.",
		Look = { Skin = C(235, 200, 175), Hair = C(190, 220, 255), HairStyle = "Long", Shirt = C(170, 180, 230), Pants = C(110, 120, 180), Shoes = C(220, 230, 255),
			Hat = "Hood", HatColor = C(200, 210, 240), Back = "MirrorShards", BackColor = C(220, 235, 255), Tool = "Orb", ToolColor = C(220, 240, 255), Beam = C(200, 230, 255), Aura = true },
	},
	TheReflection = {
		Id = "TheReflection", Name = "The Reflection", Rarity = "Secret", Zone = "MirrorMaze", Power = 1.22e17,
		Blurb = "It's you, but backwards. And way better at ghost hunting.",
		Look = { Skin = C(210, 215, 230), Hair = C(150, 160, 190), HairStyle = "Spiky", Shirt = C(190, 195, 215), Pants = C(150, 155, 180), Shoes = C(210, 215, 230),
			Back = "MirrorShards", BackColor = C(230, 240, 255), Tool = "HandMirror", ToolColor = C(230, 235, 250), Beam = C(230, 240, 255), Aura = true, Chrome = true },
	},
	KaleidaQueenOfFacets = {
		Id = "KaleidaQueenOfFacets", Name = "Kaleida, Queen of Facets", Rarity = "Ultra", Zone = "MirrorMaze", Power = 3.05e17,
		Blurb = "Splits into a hundred reflections, and every one carries a ghost trap.",
		Look = { Skin = C(250, 230, 220), Hair = C(255, 200, 240), HairStyle = "Long", Shirt = C(250, 250, 255), Pants = C(200, 220, 255), Shoes = C(255, 200, 240),
			Hat = "PrismCrown", HatColor = C(220, 240, 255), Back = "MirrorShards", BackColor = C(255, 220, 245), Tool = "Kaleidoscope", ToolColor = C(220, 235, 255), Beam = C(255, 170, 240), Aura = true, Chrome = true },
	},
	-- ZONE 23: SHOPPING CRATE
	CartPusherCody = {
		Id = "CartPusherCody", Name = "Cart-Pusher Cody", Rarity = "Common", Zone = "ShoppingMall", Power = 1.44e16,
		Blurb = "Rounds up runaway shopping carts. And runaway ghosts.",
		Look = { Skin = C(210, 160, 120), Hair = C(60, 40, 30), HairStyle = "Spiky", Shirt = C(255, 140, 60), Pants = C(60, 70, 100), Shoes = C(230, 230, 235),
			Hat = "Cap", HatColor = C(255, 140, 60), Back = "ShoppingCart", BackColor = C(170, 180, 195), Tool = "Vacuum", ToolColor = C(255, 140, 200), Beam = C(255, 170, 220) },
	},
	PretzelPam = {
		Id = "PretzelPam", Name = "Pretzel Pam", Rarity = "Uncommon", Zone = "ShoppingMall", Power = 2.39e16,
		Blurb = "Twists pretzels shaped like ghosts. The real ghosts are very flattered.",
		Look = { Skin = C(245, 215, 190), Hair = C(160, 90, 50), HairStyle = "Buns", Shirt = C(250, 250, 250), Pants = C(200, 60, 60), Shoes = C(60, 50, 50),
			Hat = "ChefHat", HatColor = C(250, 250, 250), Tool = "Pretzel", ToolColor = C(190, 120, 60), Beam = C(255, 210, 140) },
	},
	-- NOD: Paul Blart: Mall Cop (moustache, self-balancing scooter); a friendly mall guard, no badge or logo copied
	OfficerBartBlurt = {
		Id = "OfficerBartBlurt", Name = "Officer Bart Blurt", Rarity = "Rare", Zone = "ShoppingMall", Power = 3.97e16,
		Blurb = "Patrols the mall on his scooter. No ghost gets past the food court on his watch.",
		Look = { Skin = C(240, 200, 175), Hair = C(90, 60, 40), HairStyle = "Moustache", Shirt = C(220, 225, 235), Pants = C(50, 60, 90), Shoes = C(30, 30, 35),
			Hat = "Cap", HatColor = C(50, 60, 90), Back = "Scooter", BackColor = C(60, 60, 70), Tool = "Flashlight", ToolColor = C(220, 220, 230), Beam = C(255, 240, 170) },
	},
	-- NOD: Buddy from the film Elf ('smiling's my favourite', loves sugar); a grown-up elf in a pointy green hat with a candy cane
	JollyBuddyElfington = {
		Id = "JollyBuddyElfington", Name = "Jolly Buddy Elfington", Rarity = "Rare", Zone = "ShoppingMall", Power = 3.97e16,
		Blurb = "Smiling's his favourite. Ghost hunting is a close second.",
		Look = { Skin = C(245, 210, 185), Hair = C(190, 140, 80), HairStyle = "Short", Shirt = C(60, 160, 80), Pants = C(255, 215, 60), Shoes = C(40, 35, 30),
			Hat = "ElfHat", HatColor = C(60, 160, 80), Tool = "CandyCane", ToolColor = C(230, 60, 60), Beam = C(255, 120, 140) },
	},
	-- NOD: Garfield (lazy orange cat with sleepy eyes, hates Mondays, loves lasagna); our own cat, no comic-strip look
	MondaysMcFluff = {
		Id = "MondaysMcFluff", Name = "Mondays McFluff", Rarity = "Legendary", Zone = "ShoppingMall", Power = 9.77e16,
		Blurb = "Hates Mondays. Loves lasagna. Hunts ghosts in between naps.",
		Look = { Skin = C(255, 160, 60), Hair = C(255, 150, 50), HairStyle = "Tabby", Shirt = C(255, 160, 60), Pants = C(230, 130, 40), Shoes = C(255, 160, 60),
			Tool = "Lasagna", ToolColor = C(200, 80, 60), Beam = C(255, 190, 90), Aura = true },
	},
	-- NOD: Barbie and her Dreamhouse (all-pink everything); no logo, our own heart wings
	DreamHouseDebbie = {
		Id = "DreamHouseDebbie", Name = "Dream-House Debbie", Rarity = "Mythic", Zone = "ShoppingMall", Power = 2.44e17,
		Blurb = "Pink car, pink house, pink ghost trap. The ghosts LOVE the pink.",
		Look = { Skin = C(250, 220, 200), Hair = C(255, 230, 120), HairStyle = "Long", Shirt = C(255, 120, 190), Pants = C(255, 180, 220), Shoes = C(255, 90, 170),
			Hat = "Bow", HatColor = C(255, 90, 170), Back = "HeartWings", BackColor = C(255, 150, 210), Tool = "HeartWand", ToolColor = C(255, 120, 190), Beam = C(255, 150, 220), Aura = true },
	},
	TheMannequin = {
		Id = "TheMannequin", Name = "The Mannequin", Rarity = "Secret", Zone = "ShoppingMall", Power = 6.11e17,
		Blurb = "Stands perfectly still in the shop window. Then you blink, and the ghost is gone.",
		Look = { Skin = C(235, 225, 215), Hair = C(235, 225, 215), HairStyle = "None", Shirt = C(40, 40, 50), Pants = C(40, 40, 50), Shoes = C(235, 225, 215),
			Hat = "Mannequin", HatColor = C(40, 40, 50), Back = "Stand", BackColor = C(200, 200, 210), Tool = "Wand", ToolColor = C(235, 225, 215), Beam = C(255, 240, 250), Aura = true },
	},
	BargainaMegaSale = {
		Id = "BargainaMegaSale", Name = "Bargaina, Queen of the Mega Sale", Rarity = "Ultra", Zone = "ShoppingMall", Power = 1.52e18,
		Blurb = "Shouts EVERYTHING HALF PRICE and every ghost in the mall rushes straight into her trap.",
		Look = { Skin = C(200, 150, 115), Hair = C(120, 60, 160), HairStyle = "Long", Shirt = C(255, 215, 90), Pants = C(255, 120, 200), Shoes = C(130, 230, 255),
			Hat = "Crown", HatColor = C(255, 215, 90), Back = "ShoppingBags", BackColor = C(255, 120, 200), Tool = "Megaphone", ToolColor = C(255, 215, 90), Beam = C(255, 140, 210), Aura = true },
	},
	-- ZONE 24: SUBWAY CRATE
	PlatformPatrol = {
		Id = "PlatformPatrol", Name = "Platform Patrol", Rarity = "Common", Zone = "GhostSubway", Power = 7.19e16,
		Blurb = "Mind the gap! And the ghosts.",
		Look = { Skin = C(200, 150, 110), Hair = C(30, 25, 25), HairStyle = "Short", Shirt = C(40, 60, 120), Pants = C(30, 40, 80), Shoes = C(20, 20, 25),
			Hat = "Cap", HatColor = C(40, 60, 120), Tool = "Flashlight", ToolColor = C(255, 220, 80), Beam = C(255, 240, 150) },
	},
	-- NOD: Thomas the Tank Engine ('really useful engine'); a blue engine costume with red lining, no face-on-a-train
	TrackTinker = {
		Id = "TrackTinker", Name = "Tommy Tank-Engine", Rarity = "Uncommon", Zone = "GhostSubway", Power = 1.2e17,
		Blurb = "Cheeky, cheerful and really, really useful. Puffs along the rails fixing every track.",
		Look = { Skin = C(240, 200, 170), Hair = C(120, 60, 30), HairStyle = "Bob", Shirt = C(60, 120, 210), Pants = C(60, 70, 90), Shoes = C(70, 50, 30),
			Hat = "ConductorCap", HatColor = C(60, 70, 100), Back = "TankEngine", BackColor = C(50, 110, 210), Tool = "Wrench", ToolColor = C(180, 185, 200), Beam = C(255, 200, 100) },
	},
	ProtonPete = {
		Id = "ProtonPete", Name = "Proton Pete", Rarity = "Rare", Zone = "GhostSubway", Power = 1.98e17,
		Blurb = "Carries a buzzing ghost-zapper pack. Has never once read the instructions.",
		Look = { Skin = C(235, 195, 165), Hair = C(90, 60, 40), HairStyle = "Short", Shirt = C(140, 120, 170), Pants = C(140, 120, 170), Shoes = C(40, 35, 45),
			Back = "Tank", BackColor = C(170, 175, 190), Tool = "Blaster", ToolColor = C(255, 210, 60), Beam = C(255, 160, 80) },
	},
	ShellyShellshock = {
		Id = "ShellyShellshock", Name = "Shelly Shellshock", Rarity = "Rare", Zone = "GhostSubway", Power = 1.98e17,
		Blurb = "Lives under the subway, eats pizza for breakfast and flips ghosts for fun.",
		Look = { Skin = C(110, 190, 90), Hair = C(80, 150, 70), HairStyle = "None", Shirt = C(200, 180, 110), Pants = C(110, 190, 90), Shoes = C(110, 190, 90),
			Hat = "Bandana", HatColor = C(255, 120, 180), Back = "Shell", BackColor = C(110, 140, 60), Tool = "Staff", ToolColor = C(150, 100, 60), Beam = C(255, 140, 200) },
	},
	MidnightConductor = {
		Id = "MidnightConductor", Name = "Midnight Conductor", Rarity = "Legendary", Zone = "GhostSubway", Power = 4.88e17,
		Blurb = "Punches your ticket and the ghost's ticket. One way only.",
		Look = { Skin = C(230, 195, 170), Hair = C(220, 220, 230), HairStyle = "Short", Shirt = C(30, 40, 80), Pants = C(25, 30, 60), Shoes = C(20, 20, 25),
			Hat = "ConductorCap", HatColor = C(30, 40, 80), Back = "Cape", BackColor = C(255, 210, 80), Tool = "Lantern", ToolColor = C(220, 50, 50), Beam = C(255, 120, 100), Aura = true },
	},
	ThirdRailRhea = {
		Id = "ThirdRailRhea", Name = "Third-Rail Rhea", Rarity = "Mythic", Zone = "GhostSubway", Power = 1.22e18,
		Blurb = "Runs on pure electricity and three cups of cocoa.",
		Look = { Skin = C(180, 130, 100), Hair = C(255, 240, 90), HairStyle = "Spiky", Shirt = C(60, 60, 70), Pants = C(40, 40, 50), Shoes = C(255, 240, 90),
			Hat = "Goggles", HatColor = C(255, 240, 90), Back = "Tank", BackColor = C(255, 240, 90), Tool = "Projector", ToolColor = C(255, 240, 90), Beam = C(255, 250, 120), Aura = true },
	},
	TheLastTrainHome = {
		Id = "TheLastTrainHome", Name = "The Last Train Home", Rarity = "Secret", Zone = "GhostSubway", Power = 3.05e18,
		Blurb = "Arrives exactly at midnight and takes every ghost along.",
		Look = { Skin = C(200, 220, 240), Hair = C(40, 40, 60), HairStyle = "None", Shirt = C(20, 25, 40), Pants = C(15, 20, 30), Shoes = C(255, 230, 120),
			Hat = "ConductorCap", HatColor = C(15, 20, 30), Back = "Cape", BackColor = C(40, 50, 80), Tool = "Lantern", ToolColor = C(255, 230, 120), Beam = C(255, 240, 170), Aura = true },
	},
	RailsPhantomEngineer = {
		Id = "RailsPhantomEngineer", Name = "Rails, the Phantom Engineer", Rarity = "Ultra", Zone = "GhostSubway", Power = 7.62e18,
		Blurb = "Built a train out of ghost-light. It is ALWAYS on time.",
		Look = { Skin = C(240, 210, 185), Hair = C(200, 90, 50), HairStyle = "Bob", Shirt = C(60, 90, 150), Pants = C(40, 50, 90), Shoes = C(255, 215, 90),
			Hat = "ConductorCap", HatColor = C(255, 215, 90), Back = "Smokestack", BackColor = C(60, 60, 80), Tool = "Cannon", ToolColor = C(255, 215, 90), Beam = C(255, 230, 140), Aura = true },
	},
	-- ZONE 25: FOSSIL CRATE
	DustyBrushworth = {
		Id = "DustyBrushworth", Name = "Dusty Brushworth", Rarity = "Common", Zone = "DinoMuseum", Power = 3.59e17,
		Blurb = "Dusts dinosaur bones with a tiny brush. Ghosts get dusted too.",
		Look = { Skin = C(240, 205, 175), Hair = C(130, 90, 50), HairStyle = "Short", Shirt = C(90, 140, 190), Pants = C(110, 90, 60), Shoes = C(80, 60, 40),
			Hat = "Cap", HatColor = C(150, 120, 80), Back = "Bone", BackColor = C(235, 225, 200), Tool = "Brush", ToolColor = C(200, 170, 90), Beam = C(255, 230, 150) },
	},
	TourGuideTheo = {
		Id = "TourGuideTheo", Name = "Tour Guide Theo", Rarity = "Uncommon", Zone = "DinoMuseum", Power = 5.98e17,
		Blurb = "Has told the T-rex story nine thousand times. Still gets goosebumps.",
		Look = { Skin = C(170, 120, 90), Hair = C(30, 25, 25), HairStyle = "Puff", Shirt = C(60, 140, 90), Pants = C(230, 215, 180), Shoes = C(70, 50, 35),
			Hat = "Cap", HatColor = C(60, 140, 90), Tool = "TourFlag", ToolColor = C(255, 200, 80), Beam = C(160, 240, 140) },
	},
	-- NOD: Larry the night guard from Night at the Museum (a cheeky monkey on his shoulder); a plain guard uniform, no film logo
	NightShiftLarry = {
		Id = "NightShiftLarry", Name = "Night-Shift Larry", Rarity = "Rare", Zone = "DinoMuseum", Power = 9.92e17,
		Blurb = "Every night the exhibits come alive. He just says hi and carries on with his rounds.",
		Look = { Skin = C(240, 200, 175), Hair = C(70, 50, 35), HairStyle = "Short", Shirt = C(60, 70, 110), Pants = C(40, 45, 70), Shoes = C(30, 30, 35),
			Hat = "ConductorCap", HatColor = C(40, 45, 70), Back = "Monkey", BackColor = C(140, 95, 60), Tool = "Flashlight", ToolColor = C(230, 230, 240), Beam = C(255, 240, 170) },
	},
	-- NOD: the park rangers of Jurassic Park (khaki kit, a dino egg about to hatch); no park logo
	JurassicJeff = {
		Id = "JurassicJeff", Name = "Jurassic Jeff", Rarity = "Rare", Zone = "DinoMuseum", Power = 9.92e17,
		Blurb = "Runs the dino tours. Has never lost a raptor. Okay, once. Twice.",
		Look = { Skin = C(230, 190, 155), Hair = C(120, 80, 45), HairStyle = "Short", Shirt = C(200, 180, 130), Pants = C(120, 105, 75), Shoes = C(90, 65, 40),
			Hat = "Pith", HatColor = C(210, 190, 140), Back = "DinoEgg", BackColor = C(205, 225, 175), Tool = "Spyglass", ToolColor = C(80, 80, 90), Beam = C(160, 240, 140) },
	},
	-- NOD: Indiana Jones (fedora, whip, hates snakes); our own colours
	IndianaBones = {
		Id = "IndianaBones", Name = "Indiana Bones", Rarity = "Legendary", Zone = "DinoMuseum", Power = 2.44e18,
		Blurb = "Hates snakes. Loves fossils. Snaps ghosts into his trap with one crack of the whip.",
		Look = { Skin = C(235, 195, 160), Hair = C(110, 75, 45), HairStyle = "Short", Shirt = C(125, 85, 55), Pants = C(120, 95, 65), Shoes = C(80, 55, 35),
			Hat = "Fedora", HatColor = C(120, 85, 55), Back = "Backpack", BackColor = C(140, 100, 60), Tool = "Whip", ToolColor = C(110, 70, 40), Beam = C(255, 210, 120), Aura = true },
	},
	-- NOD: Barney the purple dinosaur (sings about friendship); a lilac dino hood with lime trim
	PurplePalBarnaby = {
		Id = "PurplePalBarnaby", Name = "Purple Pal Barnaby", Rarity = "Mythic", Zone = "DinoMuseum", Power = 6.09e18,
		Blurb = "Sings ghosts a lullaby about friendship. They nap right into the trap.",
		Look = { Skin = C(170, 120, 210), Hair = C(170, 120, 210), HairStyle = "None", Shirt = C(170, 120, 210), Pants = C(150, 220, 110), Shoes = C(150, 100, 190),
			Hat = "DinoHood", HatColor = C(170, 120, 210), Back = "DinoTail", BackColor = C(170, 120, 210), Tool = "Wand", ToolColor = C(150, 220, 110), Beam = C(200, 160, 255), Aura = true },
	},
	TheLivingExhibit = {
		Id = "TheLivingExhibit", Name = "The Living Exhibit", Rarity = "Secret", Zone = "DinoMuseum", Power = 1.53e19,
		Blurb = "Stood very still in a glass case for 65 million years. Now it's stretching its legs.",
		Look = { Skin = C(235, 225, 200), Hair = C(235, 225, 200), HairStyle = "None", Shirt = C(220, 210, 185), Pants = C(200, 190, 165), Shoes = C(180, 170, 145),
			Hat = "DinoSkull", HatColor = C(235, 225, 200), Back = "DinoTail", BackColor = C(235, 225, 200), Tool = "Staff", ToolColor = C(200, 170, 90), Beam = C(160, 240, 140), Aura = true },
	},
	AmberlynFossilQueen = {
		Id = "AmberlynFossilQueen", Name = "Amberlyn, the Fossil Queen", Rarity = "Ultra", Zone = "DinoMuseum", Power = 3.81e19,
		Blurb = "One tap of her amber staff and every fossil in the hall wakes up to help.",
		Look = { Skin = C(245, 215, 190), Hair = C(255, 170, 60), HairStyle = "Long", Shirt = C(255, 190, 80), Pants = C(150, 90, 40), Shoes = C(255, 210, 90),
			Hat = "Tiara", HatColor = C(255, 190, 80), Back = "BatWings", BackColor = C(255, 170, 60), Tool = "AmberStaff", ToolColor = C(255, 170, 40), Beam = C(255, 190, 80), Aura = true },
	},
	-- ZONE 26: CHAMPION CRATE
	PopcornPercy = {
		Id = "PopcornPercy", Name = "Popcorn Percy", Rarity = "Common", Zone = "Stadium", Power = 1.8e18,
		Blurb = "Sells popcorn in the stands. Throws the extra at ghosts.",
		Look = { Skin = C(250, 215, 185), Hair = C(230, 120, 60), HairStyle = "Spiky", Shirt = C(230, 60, 60), Pants = C(250, 250, 250), Shoes = C(60, 60, 70),
			Hat = "Cap", HatColor = C(230, 60, 60), Tool = "Popcorn", ToolColor = C(230, 60, 60), Beam = C(255, 240, 170) },
	},
	RefereeRita = {
		Id = "RefereeRita", Name = "Referee Rita", Rarity = "Uncommon", Zone = "Stadium", Power = 2.99e18,
		Blurb = "One whistle, one red card, and that ghost is OFF the pitch.",
		Look = { Skin = C(200, 145, 110), Hair = C(40, 30, 30), HairStyle = "Bob", Shirt = C(240, 240, 240), Pants = C(30, 30, 35), Shoes = C(30, 30, 35),
			Hat = "Cap", HatColor = C(30, 30, 35), Back = "Stripes", BackColor = C(30, 30, 35), Tool = "RedCard", ToolColor = C(230, 40, 50), Beam = C(255, 90, 90) },
	},
	-- NOD: Coach Ted Lasso (moustache, visor, believes in everyone, bakes biscuits); our own team colours
	CoachNedLassiter = {
		Id = "CoachNedLassiter", Name = "Coach Ned Lassiter", Rarity = "Rare", Zone = "Stadium", Power = 4.96e18,
		Blurb = "Believes in every hunter on the team. Bakes them biscuits, too.",
		Look = { Skin = C(240, 200, 175), Hair = C(120, 85, 50), HairStyle = "Moustache", Shirt = C(60, 90, 170), Pants = C(50, 55, 70), Shoes = C(30, 30, 35),
			Hat = "Visor", HatColor = C(60, 90, 170), Tool = "BiscuitBox", ToolColor = C(255, 170, 200), Beam = C(160, 200, 255) },
	},
	-- NOD: Rocky Balboa (the boxer: gloves, robe, sweatband, grey sweats, running up the steps); our own green robe, no logo
	RockyBalBooa = {
		Id = "RockyBalBooa", Name = "Rocky Bal-BOO-a", Rarity = "Rare", Zone = "Stadium", Power = 4.96e18,
		Blurb = "Runs up the stadium steps every morning and punches the air at the top. Ghosts can't keep up.",
		Look = { Skin = C(235, 195, 165), Hair = C(40, 30, 25), HairStyle = "Short", Shirt = C(30, 140, 95), Pants = C(135, 140, 150), Shoes = C(40, 40, 45),
			Hat = "Sweatband", HatColor = C(220, 50, 50), Back = "BoxerRobe", BackColor = C(150, 155, 165), Tool = "BoxerGlove", ToolColor = C(220, 45, 50), Beam = C(255, 120, 100) },
	},
	-- NOD: Air Bud ('no rule says a dog can't play basketball'); a golden pup with floppy ears and a basketball
	AirPup = {
		Id = "AirPup", Name = "Air Pup", Rarity = "Legendary", Zone = "Stadium", Power = 1.22e19,
		Blurb = "There's no rule that says a dog can't hunt ghosts!",
		Look = { Skin = C(230, 180, 90), Hair = C(220, 165, 75), HairStyle = "Pup", Shirt = C(255, 200, 60), Pants = C(60, 90, 170), Shoes = C(250, 250, 250),
			Tool = "Basketball", ToolColor = C(255, 140, 50), Beam = C(255, 170, 80), Aura = true },
	},
	-- NOD: The Mighty Ducks (duck hockey team, the flying-V); own green kit and a duck-bill helmet, no team crest
	CaptainMightyQuack = {
		Id = "CaptainMightyQuack", Name = "Captain Mighty Quack", Rarity = "Mythic", Zone = "Stadium", Power = 3.05e19,
		Blurb = "Leads a team of hockey ducks. Their flying-V knocks ghosts flat.",
		Look = { Skin = C(240, 200, 170), Hair = C(250, 200, 80), HairStyle = "Spiky", Shirt = C(40, 130, 90), Pants = C(250, 250, 250), Shoes = C(30, 30, 35),
			Hat = "DuckHelmet", HatColor = C(250, 250, 250), Tool = "HockeyStick", ToolColor = C(60, 60, 70), Beam = C(120, 255, 160), Aura = true },
	},
	TheTwelfthFan = {
		Id = "TheTwelfthFan", Name = "The Twelfth Fan", Rarity = "Secret", Zone = "Stadium", Power = 7.64e19,
		Blurb = "Never misses a game. Nobody has ever seen him arrive or leave.",
		Look = { Skin = C(220, 225, 235), Hair = C(60, 70, 90), HairStyle = "None", Shirt = C(60, 90, 170), Pants = C(40, 50, 80), Shoes = C(255, 220, 80),
			Hat = "FanHat", HatColor = C(60, 90, 170), Back = "FanDrum", BackColor = C(255, 210, 70), Tool = "FoamFinger", ToolColor = C(255, 210, 70), Beam = C(160, 200, 255), Aura = true },
	},
	VictoriaVortexMVP = {
		Id = "VictoriaVortexMVP", Name = "Victoria Vortex, MVP", Rarity = "Ultra", Zone = "Stadium", Power = 1.9e20,
		Blurb = "Scores the winning goal every single game. The goal is always a ghost trap.",
		Look = { Skin = C(170, 115, 85), Hair = C(255, 220, 90), HairStyle = "Puff", Shirt = C(255, 220, 80), Pants = C(40, 90, 180), Shoes = C(120, 255, 140),
			Hat = "Crown", HatColor = C(255, 220, 80), Back = "HeroCape", BackColor = C(250, 250, 255), Tool = "Trophy", ToolColor = C(255, 215, 90), Beam = C(255, 230, 120), Aura = true },
	},
	-- ZONE 27: NEON CRATE
	RooftopRunner = {
		Id = "RooftopRunner", Name = "Rooftop Runner", Rarity = "Common", Zone = "NeonCity", Power = 8.98e18,
		Blurb = "Jumps between buildings. Lands mostly on the roofs.",
		Look = { Skin = C(220, 180, 150), Hair = C(30, 25, 30), HairStyle = "Spiky", Shirt = C(255, 80, 220), Pants = C(40, 40, 60), Shoes = C(240, 240, 255),
			Hat = "Cap", HatColor = C(40, 40, 60), Back = "Backpack", BackColor = C(120, 240, 255), Tool = "Flashlight", ToolColor = C(120, 240, 255), Beam = C(120, 240, 255) },
	},
	DJGhostbeat = {
		Id = "DJGhostbeat", Name = "DJ Ghostbeat", Rarity = "Uncommon", Zone = "NeonCity", Power = 1.49e19,
		Blurb = "Drops a beat so heavy that ghosts can't stop dancing.",
		Look = { Skin = C(150, 100, 70), Hair = C(30, 25, 25), HairStyle = "Puff", Shirt = C(40, 40, 60), Pants = C(30, 30, 45), Shoes = C(255, 80, 220),
			Hat = "Headphones", HatColor = C(120, 240, 255), Back = "Boombox", BackColor = C(60, 60, 80), Tool = "Projector", ToolColor = C(255, 80, 220), Beam = C(255, 120, 230) },
	},
	WebSpook = {
		Id = "WebSpook", Name = "Web Spook", Rarity = "Rare", Zone = "NeonCity", Power = 2.48e19,
		Blurb = "Swings between neon signs and sticks every landing.",
		Look = { Skin = C(240, 210, 190), Hair = C(30, 30, 35), HairStyle = "Short", Shirt = C(40, 200, 190), Pants = C(30, 30, 40), Shoes = C(40, 200, 190),
			Hat = "HeroMask", HatColor = C(30, 30, 40), Tool = "Blaster", ToolColor = C(240, 240, 250), Beam = C(250, 250, 255) },
	},
	-- NOD: Neo from The Matrix (long black coat, slim dark glasses, slow-motion dodges); green glow instead of code rain
	NeonNinjaNix = {
		Id = "NeonNinjaNix", Name = "Neeo the Chosen One", Rarity = "Rare", Zone = "NeonCity", Power = 2.48e19,
		Blurb = "Leans back in slow motion and every blob of ghost goo whooshes right past. Whoa.",
		Look = { Skin = C(230, 190, 160), Hair = C(20, 20, 30), HairStyle = "Short", Shirt = C(25, 25, 30), Pants = C(25, 25, 30), Shoes = C(25, 25, 30),
			Hat = "Shades", HatColor = C(25, 25, 30), Back = "TrenchCoat", BackColor = C(25, 25, 30), Tool = "Sword", ToolColor = C(120, 255, 160), Beam = C(120, 255, 160) },
	},
	TheNightOwl = {
		Id = "TheNightOwl", Name = "The Night Owl", Rarity = "Legendary", Zone = "NeonCity", Power = 6.1e19,
		Blurb = "Watches the city from the tallest sign and hoots at ghosts. Menacingly.",
		Look = { Skin = C(225, 185, 155), Hair = C(90, 60, 150), HairStyle = "PointyEars", Shirt = C(60, 50, 90), Pants = C(40, 35, 60), Shoes = C(255, 200, 80),
			Hat = "HeroMask", HatColor = C(90, 60, 150), Back = "HeroCape", BackColor = C(90, 60, 150), Tool = "Blaster", ToolColor = C(255, 200, 80), Beam = C(255, 210, 100), Aura = true },
	},
	GlitchRider = {
		Id = "GlitchRider", Name = "Glitch Rider", Rarity = "Mythic", Zone = "NeonCity", Power = 1.52e20,
		Blurb = "Rides a light-bike made of pure neon and leaves glowing tyre marks.",
		Look = { Skin = C(200, 210, 230), Hair = C(120, 240, 255), HairStyle = "Short", Shirt = C(20, 20, 30), Pants = C(20, 20, 30), Shoes = C(120, 240, 255),
			Hat = "Helmet", HatColor = C(20, 20, 30), Back = "Tank", BackColor = C(120, 240, 255), Tool = "Projector", ToolColor = C(120, 240, 255), Beam = C(120, 240, 255), Aura = true },
	},
	TheStatic = {
		Id = "TheStatic", Name = "The Static", Rarity = "Secret", Zone = "NeonCity", Power = 3.82e20,
		Blurb = "Appears whenever the TV goes fuzzy and takes the ghost with it.",
		Look = { Skin = C(170, 170, 180), Hair = C(120, 120, 130), HairStyle = "None", Shirt = C(90, 90, 100), Pants = C(60, 60, 70), Shoes = C(40, 40, 50),
			Hat = "TVHead", HatColor = C(90, 80, 70), Tool = "Scanner", ToolColor = C(220, 220, 230), Beam = C(230, 230, 240), Aura = true },
	},
	NeonovaCitySuperstar = {
		Id = "NeonovaCitySuperstar", Name = "Neonova, City Superstar", Rarity = "Ultra", Zone = "NeonCity", Power = 9.52e20,
		Blurb = "Her concerts light up the whole skyline. Ghosts buy front-row tickets.",
		Look = { Skin = C(240, 205, 185), Hair = C(255, 80, 220), HairStyle = "Long", Shirt = C(255, 255, 255), Pants = C(120, 240, 255), Shoes = C(255, 80, 220),
			Hat = "Headphones", HatColor = C(120, 240, 255), Back = "Wings", BackColor = C(255, 140, 240), Tool = "Guitar", ToolColor = C(255, 80, 220), Beam = C(255, 120, 240), Aura = true },
	},
	-- ZONE 28: COOKIE JAR CRATE
	SugarCubeSid = {
		Id = "SugarCubeSid", Name = "Sugar-Cube Sid", Rarity = "Common", Zone = "GiantsKitchen", Power = 4.49e19,
		Blurb = "Carries a sugar cube twice his size. Ghosts are very impressed.",
		Look = { Skin = C(240, 205, 175), Hair = C(200, 90, 50), HairStyle = "Spiky", Shirt = C(90, 170, 230), Pants = C(70, 70, 100), Shoes = C(255, 255, 255),
			Hat = "Cap", HatColor = C(255, 110, 90), Back = "SugarCube", BackColor = C(250, 250, 250), Tool = "Flashlight", ToolColor = C(255, 220, 120), Beam = C(255, 240, 170) },
	},
	ThimbleThea = {
		Id = "ThimbleThea", Name = "Thimble Thea", Rarity = "Uncommon", Zone = "GiantsKitchen", Power = 7.47e19,
		Blurb = "Wears a thimble for a helmet. Very safe, very shiny.",
		Look = { Skin = C(210, 160, 120), Hair = C(60, 40, 30), HairStyle = "Bob", Shirt = C(230, 90, 110), Pants = C(90, 60, 120), Shoes = C(60, 50, 50),
			Hat = "Thimble", HatColor = C(200, 205, 220), Back = "ThreadSpool", BackColor = C(230, 90, 110), Tool = "SewingPin", ToolColor = C(200, 205, 220), Beam = C(255, 200, 230) },
	},
	-- NOD: Stuart Little (a tiny white mouse in a sweater who races a toy sailboat); our own green sweater
	StueyTeeny = {
		Id = "StueyTeeny", Name = "Stuey Teeny", Rarity = "Rare", Zone = "GiantsKitchen", Power = 1.24e20,
		Blurb = "The smallest mouse in the family and the biggest ghost hunter in the kitchen.",
		Look = { Skin = C(245, 240, 235), Hair = C(245, 240, 235), HairStyle = "RoundEars", Shirt = C(80, 170, 90), Pants = C(70, 90, 160), Shoes = C(60, 50, 50),
			Back = "Sailboat", BackColor = C(220, 60, 60), Tool = "Scanner", ToolColor = C(255, 210, 90), Beam = C(255, 230, 150) },
	},
	-- NOD: The Borrowers / Arrietty (tiny people who borrow from the big house); a sewing pin for a sword, a button for a shield
	BorrowerEtty = {
		Id = "BorrowerEtty", Name = "Borrower Etty", Rarity = "Rare", Zone = "GiantsKitchen", Power = 1.24e20,
		Blurb = "Borrows a button here, a pin there. She never borrows ghosts. She CATCHES them.",
		Look = { Skin = C(240, 205, 180), Hair = C(160, 70, 40), HairStyle = "Long", Shirt = C(200, 90, 70), Pants = C(110, 80, 60), Shoes = C(80, 60, 40),
			Hat = "Bow", HatColor = C(230, 200, 90), Back = "ButtonShield", BackColor = C(80, 140, 210), Tool = "SewingPin", ToolColor = C(210, 215, 230), Beam = C(255, 210, 150) },
	},
	-- NOD: The Gingerbread Man fairy tale (public domain)
	GingerbreadRon = {
		Id = "GingerbreadRon", Name = "Run-Run Gingerbread Ron", Rarity = "Legendary", Zone = "GiantsKitchen", Power = 3.05e20,
		Blurb = "Run, run, as fast as you can! You can't catch... oh. He caught you.",
		Look = { Skin = C(190, 120, 60), Hair = C(190, 120, 60), HairStyle = "None", Shirt = C(190, 120, 60), Pants = C(190, 120, 60), Shoes = C(250, 250, 250),
			Hat = "GingerIcing", HatColor = C(255, 255, 255), Tool = "RollingPin", ToolColor = C(210, 170, 120), Beam = C(255, 200, 140), Aura = true },
	},
	-- NOD: Thumbelina (Andersen fairy tale, public domain)
	Thumbelinda = {
		Id = "Thumbelinda", Name = "Thumbelinda", Rarity = "Mythic", Zone = "GiantsKitchen", Power = 7.62e20,
		Blurb = "Sailed across the sink in a walnut shell. Now she rules the fruit bowl.",
		Look = { Skin = C(250, 220, 200), Hair = C(255, 220, 140), HairStyle = "Long", Shirt = C(255, 170, 200), Pants = C(140, 210, 140), Shoes = C(255, 170, 200),
			Hat = "TulipHat", HatColor = C(255, 120, 170), Back = "Wings", BackColor = C(220, 240, 255), Tool = "Wand", ToolColor = C(255, 215, 90), Beam = C(255, 190, 220), Aura = true },
	},
	TheFridgeLight = {
		Id = "TheFridgeLight", Name = "The Fridge Light", Rarity = "Secret", Zone = "GiantsKitchen", Power = 1.91e21,
		Blurb = "Switches on when the door opens. Nobody knows what it does when the door is shut.",
		Look = { Skin = C(240, 250, 255), Hair = C(200, 230, 255), HairStyle = "None", Shirt = C(230, 240, 250), Pants = C(200, 215, 235), Shoes = C(180, 195, 215),
			Hat = "Bulb", HatColor = C(255, 255, 230), Back = "FridgeDoor", BackColor = C(235, 245, 255), Tool = "Lantern", ToolColor = C(255, 255, 230), Beam = C(230, 250, 255), Aura = true },
	},
	SprinklaQueenOfSweets = {
		Id = "SprinklaQueenOfSweets", Name = "Sprinkla, Queen of Sweets", Rarity = "Ultra", Zone = "GiantsKitchen", Power = 4.76e21,
		Blurb = "Bakes a cake so big that the ghosts move in. Then she pops the lid on.",
		Look = { Skin = C(245, 215, 195), Hair = C(255, 140, 190), HairStyle = "Long", Shirt = C(255, 230, 240), Pants = C(140, 220, 255), Shoes = C(255, 140, 190),
			Hat = "Crown", HatColor = C(255, 215, 90), Back = "Cake", BackColor = C(255, 170, 210), Tool = "Whisk", ToolColor = C(220, 225, 235), Beam = C(255, 170, 220), Aura = true },
	},
	-- ZONE 29: ARCADE CRATE
	CoinOpCal = {
		Id = "CoinOpCal", Name = "Coin-Op Cal", Rarity = "Common", Zone = "CyberArcade", Power = 2.25e20,
		Blurb = "Pockets full of tokens, heart full of high scores.",
		Look = { Skin = C(240, 205, 175), Hair = C(60, 40, 30), HairStyle = "Spiky", Shirt = C(60, 200, 180), Pants = C(50, 40, 90), Shoes = C(255, 80, 200),
			Hat = "Headphones", HatColor = C(80, 80, 100), Tool = "Coin", ToolColor = C(255, 200, 60), Beam = C(80, 255, 220) },
	},
	ButtonMasherBea = {
		Id = "ButtonMasherBea", Name = "Button-Masher Bea", Rarity = "Uncommon", Zone = "CyberArcade", Power = 3.74e20,
		Blurb = "Presses every button at once. Somehow it always works.",
		Look = { Skin = C(170, 115, 85), Hair = C(255, 80, 200), HairStyle = "Buns", Shirt = C(255, 220, 80), Pants = C(60, 60, 120), Shoes = C(80, 255, 220),
			Hat = "Visor", HatColor = C(80, 255, 220), Tool = "Gamepad", ToolColor = C(255, 80, 200), Beam = C(255, 120, 220) },
	},
	-- NOD: Mario (jumping moustached plumber); our own teal cap, orange shirt and purple overalls, no letter badge
	MustachioThePlumber = {
		Id = "MustachioThePlumber", Name = "Mustachio the Plumber", Rarity = "Rare", Zone = "CyberArcade", Power = 6.2e20,
		Blurb = "Jumps on ghosts' heads, fixes the pipes and shouts 'Wahoo!' all the way down.",
		Look = { Skin = C(245, 205, 175), Hair = C(70, 45, 30), HairStyle = "Moustache", Shirt = C(255, 140, 50), Pants = C(120, 70, 190), Shoes = C(120, 80, 50),
			Hat = "Cap", HatColor = C(40, 180, 170), Back = "Overalls", BackColor = C(120, 70, 190), Tool = "Wrench", ToolColor = C(190, 195, 210), Beam = C(255, 200, 90) },
	},
	-- NOD: Sonic the Hedgehog ('gotta go fast', swept-back quills, gold rings); a lime-green hedgehog with orange shoes
	SpeedySpikes = {
		Id = "SpeedySpikes", Name = "Speedy Spikes", Rarity = "Rare", Zone = "CyberArcade", Power = 6.2e20,
		Blurb = "Gotta go fast? He's already gone FASTER.",
		Look = { Skin = C(245, 210, 175), Hair = C(120, 220, 80), HairStyle = "Quills", Shirt = C(120, 220, 80), Pants = C(120, 220, 80), Shoes = C(255, 140, 50),
			Back = "Rings", BackColor = C(255, 210, 70), Tool = "GoldRing", ToolColor = C(255, 210, 70), Beam = C(255, 230, 120) },
	},
	-- NOD: Pac-Man (waka-waka, power pellets, ghosts turn blue); a chomping round-head hat
	WakaWakaWanda = {
		Id = "WakaWakaWanda", Name = "Waka-Waka Wanda", Rarity = "Legendary", Zone = "CyberArcade", Power = 1.53e21,
		Blurb = "Munches power pellets for breakfast. Ghosts turn blue the moment she walks in.",
		Look = { Skin = C(245, 215, 185), Hair = C(255, 220, 60), HairStyle = "None", Shirt = C(255, 220, 60), Pants = C(60, 70, 160), Shoes = C(255, 220, 60),
			Hat = "ChompHead", HatColor = C(255, 220, 60), Back = "PelletTrail", BackColor = C(80, 120, 255), Tool = "Orb", ToolColor = C(255, 240, 200), Beam = C(120, 160, 255), Aura = true },
	},
	-- NOD: Tetris (falling blocks, clearing four lines); our own block colours
	BlockDropBoris = {
		Id = "BlockDropBoris", Name = "Block-Drop Boris", Rarity = "Mythic", Zone = "CyberArcade", Power = 3.81e21,
		Blurb = "Stacks ghosts in perfect lines. Four lines at once? Easy.",
		Look = { Skin = C(235, 200, 170), Hair = C(150, 90, 50), HairStyle = "Short", Shirt = C(220, 60, 70), Pants = C(60, 90, 200), Shoes = C(255, 210, 60),
			Hat = "Beanie", HatColor = C(60, 180, 90), Back = "Blocks", BackColor = C(120, 220, 255), Tool = "Joystick", ToolColor = C(255, 210, 60), Beam = C(150, 230, 255), Aura = true },
	},
	PlayerTwo = {
		Id = "PlayerTwo", Name = "Player Two", Rarity = "Secret", Zone = "CyberArcade", Power = 9.55e21,
		Blurb = "Has been waiting to join the game since 1982. Finally pressed START.",
		Look = { Skin = C(210, 220, 240), Hair = C(60, 60, 90), HairStyle = "None", Shirt = C(40, 40, 70), Pants = C(30, 30, 55), Shoes = C(80, 255, 220),
			Hat = "TVHead", HatColor = C(50, 50, 70), Back = "Antenna", BackColor = C(80, 80, 100), Tool = "Blaster", ToolColor = C(80, 255, 220), Beam = C(80, 255, 220), Aura = true },
	},
	PixellaArcadeEmpress = {
		Id = "PixellaArcadeEmpress", Name = "Pixella, Arcade Empress", Rarity = "Ultra", Zone = "CyberArcade", Power = 2.38e22,
		Blurb = "Presses START and every ghost in the arcade turns 8-bit and lines up for her trap.",
		Look = { Skin = C(245, 215, 195), Hair = C(80, 255, 220), HairStyle = "Long", Shirt = C(120, 60, 200), Pants = C(255, 80, 200), Shoes = C(80, 255, 220),
			Hat = "PrismCrown", HatColor = C(255, 80, 200), Back = "PixelWings", BackColor = C(80, 255, 220), Tool = "PixelSword", ToolColor = C(220, 240, 255), Beam = C(80, 255, 220), Aura = true },
	},
	-- ZONE 30: STORM CRATE
	KiteFlyerKit = {
		Id = "KiteFlyerKit", Name = "Storm Chaser Kit", Rarity = "Common", Zone = "StormIslands", Power = 1.12e21,
		Blurb = "Chases storms in her rain boots. The vane on her cap points at the next ghost.",
		Look = { Skin = C(250, 215, 185), Hair = C(200, 110, 50), HairStyle = "Bob", Shirt = C(255, 205, 50), Pants = C(70, 110, 170), Shoes = C(60, 170, 90),
			Hat = "WeatherVane", HatColor = C(230, 70, 60), Tool = "Anemometer", ToolColor = C(240, 240, 245), Beam = C(255, 240, 150) },
	},
	-- NOD: the nursery rhyme Little Bo-Peep (big bonnet, shepherd's crook, lost her sheep; public domain)
	CloudHopper = {
		Id = "CloudHopper", Name = "Little Bo Leap", Rarity = "Uncommon", Zone = "StormIslands", Power = 1.87e21,
		Blurb = "Lost her cloud-sheep, found them, lost them again... and found a ghost instead!",
		Look = { Skin = C(150, 100, 70), Hair = C(35, 25, 25), HairStyle = "Braids", Shirt = C(110, 175, 100), Pants = C(120, 95, 70), Shoes = C(90, 60, 40),
			Hat = "Bonnet", HatColor = C(255, 150, 190), Back = "CloudSheep", BackColor = C(240, 245, 255), Tool = "Crook", ToolColor = C(160, 110, 65), Beam = C(190, 230, 255) },
	},
	GrandpaBalloony = {
		Id = "GrandpaBalloony", Name = "Captain Balloony", Rarity = "Rare", Zone = "StormIslands", Power = 3.1e21,
		Blurb = "Floated up here in his patchwork balloon and decided to stay forever.",
		Look = { Skin = C(240, 205, 180), Hair = C(205, 95, 45), HairStyle = "Beard", Shirt = C(140, 85, 50), Pants = C(190, 170, 120), Shoes = C(70, 50, 40),
			Hat = "Goggles", HatColor = C(120, 80, 50), Back = "HotAirBalloon", BackColor = C(225, 60, 70), Tool = "Spyglass", ToolColor = C(220, 180, 90), Beam = C(255, 220, 150) },
	},
	ZephyrZoe = {
		Id = "ZephyrZoe", Name = "Rainbow Zoe", Rarity = "Rare", Zone = "StormIslands", Power = 3.1e21,
		Blurb = "Races across rainbows faster than the rain. Leaves a stripe of every colour behind.",
		Look = { Skin = C(240, 200, 170), Hair = C(255, 90, 170), HairStyle = "Floaty", Shirt = C(60, 200, 235), Pants = C(130, 90, 220), Shoes = C(255, 220, 60),
			Back = "RainbowScarf", Tool = "Pinwheel", ToolColor = C(250, 250, 255), Beam = C(255, 200, 240) },
	},
	ThunderThad = {
		Id = "ThunderThad", Name = "Sparkplug Thad", Rarity = "Legendary", Zone = "StormIslands", Power = 7.63e21,
		Blurb = "Builds lightning rods out of spare parts. The storm charges his battery for free.",
		Look = { Skin = C(160, 110, 80), Hair = C(30, 25, 25), HairStyle = "Short", Shirt = C(60, 100, 160), Pants = C(240, 120, 40), Shoes = C(50, 45, 45),
			Hat = "HardHat", HatColor = C(255, 200, 40), Back = "Battery", BackColor = C(45, 50, 60), Tool = "Wrench", ToolColor = C(180, 185, 200), Beam = C(255, 240, 120), Aura = true },
	},
	TempestTamsin = {
		Id = "TempestTamsin", Name = "Captain Tamsin Gale", Rarity = "Mythic", Zone = "StormIslands", Power = 1.9e22,
		Blurb = "Captain of the sky-ship Thunder-Gull. Steers straight into storms with a grin.",
		Look = { Skin = C(225, 185, 160), Hair = C(40, 165, 175), HairStyle = "Long", Shirt = C(195, 40, 55), Pants = C(40, 50, 90), Shoes = C(40, 35, 40),
			Hat = "SkyTricorn", HatColor = C(95, 60, 50), Back = "ShipWheel", BackColor = C(160, 105, 60), Tool = "Sword", ToolColor = C(215, 220, 235), Beam = C(120, 230, 255), Aura = true },
	},
	TheLightningKid = {
		Id = "TheLightningKid", Name = "The Thunderbird Kid", Rarity = "Secret", Zone = "StormIslands", Power = 4.77e22,
		Blurb = "Wears the mask of the storm bird. When those wings flap, thunder rolls.",
		Look = { Skin = C(230, 190, 160), Hair = C(30, 40, 90), HairStyle = "None", Shirt = C(30, 40, 85), Pants = C(25, 25, 55), Shoes = C(255, 220, 60),
			Hat = "BirdMask", HatColor = C(45, 95, 215), Back = "FeatherWings", BackColor = C(45, 95, 215), Tool = "Thunderbolt", ToolColor = C(255, 230, 80), Beam = C(255, 240, 120), Aura = true },
	},
	AerisQueenOfTheTempest = {
		Id = "AerisQueenOfTheTempest", Name = "Aeris, Tempest Titan Queen", Rarity = "Ultra", Zone = "StormIslands", Power = 1.19e23,
		Blurb = "Rides the eye of the storm. One wave of her trident and the clouds bow.",
		Look = { Skin = C(235, 205, 190), Hair = C(100, 110, 230), HairStyle = "Long", Shirt = C(60, 70, 150), Pants = C(45, 55, 125), Shoes = C(255, 215, 80),
			Hat = "TempestCrown", HatColor = C(255, 205, 70), Back = "Cyclone", BackColor = C(140, 155, 200), Tool = "Trident", ToolColor = C(255, 210, 80), Beam = C(255, 245, 150), Aura = true },
	},
	-- ZONE 31: MOON BASE CRATE
	MoonCadet = {
		Id = "MoonCadet", Name = "Moon Cadet", Rarity = "Common", Zone = "MoonBase", Power = 5.62e21,
		Blurb = "Bounces three metres with every step. Loves it.",
		Look = { Skin = C(240, 205, 180), Hair = C(120, 70, 40), HairStyle = "Short", Shirt = C(240, 240, 245), Pants = C(200, 205, 215), Shoes = C(255, 130, 60),
			Hat = "SpaceHelmet", HatColor = C(240, 240, 245), Back = "Backpack", BackColor = C(200, 205, 215), Tool = "Flashlight", ToolColor = C(255, 130, 60), Beam = C(255, 220, 160) },
	},
	CraterMechanic = {
		Id = "CraterMechanic", Name = "Crater Mechanic", Rarity = "Uncommon", Zone = "MoonBase", Power = 9.34e21,
		Blurb = "Fixes moon rovers with sticky tape and moon rocks.",
		Look = { Skin = C(170, 120, 90), Hair = C(30, 25, 25), HairStyle = "Puff", Shirt = C(255, 130, 60), Pants = C(80, 85, 100), Shoes = C(60, 60, 70),
			Hat = "Helmet", HatColor = C(240, 240, 245), Back = "Tank", BackColor = C(200, 205, 215), Tool = "Wrench", ToolColor = C(190, 195, 210), Beam = C(255, 180, 120) },
	},
	-- NOD: Buzz Lightyear from Toy Story ('to infinity and beyond'); our own white suit, purple hood and pop-out wings
	CosmoZoomer = {
		Id = "CosmoZoomer", Name = "Fuzz Moonyear", Rarity = "Rare", Zone = "MoonBase", Power = 1.55e22,
		Blurb = "To the moon and a little bit further! Lands every jump. Mostly.",
		Look = { Skin = C(240, 205, 180), Hair = C(140, 90, 200), HairStyle = "Short", Shirt = C(250, 250, 255), Pants = C(235, 235, 245), Shoes = C(140, 90, 200),
			Hat = "SpaceHelmet", HatColor = C(250, 250, 255), Back = "SpaceWings", BackColor = C(140, 215, 70), Tool = "RayGun", ToolColor = C(250, 250, 255), Beam = C(255, 120, 80) },
	},
	DocFizzbang = {
		Id = "DocFizzbang", Name = "Doc Fizzbang", Rarity = "Rare", Zone = "MoonBase", Power = 1.55e22,
		Blurb = "Built a ghost-zapper out of a toaster. It also makes toast.",
		Look = { Skin = C(220, 215, 205), Hair = C(170, 200, 230), HairStyle = "Spiky", Shirt = C(250, 250, 250), Pants = C(120, 90, 60), Shoes = C(60, 50, 40),
			Hat = "Specs", HatColor = C(60, 60, 70), Tool = "RayGun", ToolColor = C(140, 255, 160), Beam = C(140, 255, 160) },
	},
	OrbitOlivia = {
		Id = "OrbitOlivia", Name = "Orbit Olivia", Rarity = "Legendary", Zone = "MoonBase", Power = 3.81e22,
		Blurb = "Has done a thousand laps of the moon and still gets dizzy.",
		Look = { Skin = C(160, 110, 80), Hair = C(30, 20, 20), HairStyle = "Buns", Shirt = C(110, 120, 220), Pants = C(60, 70, 140), Shoes = C(250, 250, 255),
			Hat = "SpaceHelmet", HatColor = C(250, 250, 255), Back = "Rings", BackColor = C(255, 200, 120), Tool = "Orb", ToolColor = C(255, 200, 120), Beam = C(255, 210, 140), Aura = true },
	},
	LunarLancer = {
		Id = "LunarLancer", Name = "Lunar Lancer", Rarity = "Mythic", Zone = "MoonBase", Power = 9.52e22,
		Blurb = "Jousts ghosts from a moon buggy. Wins every single time.",
		Look = { Skin = C(240, 205, 180), Hair = C(200, 200, 210), HairStyle = "Short", Shirt = C(200, 205, 220), Pants = C(120, 125, 140), Shoes = C(255, 130, 60),
			Hat = "KnightHelm", HatColor = C(220, 225, 240), Back = "Jetpack", BackColor = C(120, 125, 140), Tool = "Sword", ToolColor = C(220, 225, 240), Beam = C(255, 160, 100), Aura = true },
	},
	TheMoonFace = {
		Id = "TheMoonFace", Name = "The Moon Face", Rarity = "Secret", Zone = "MoonBase", Power = 2.39e23,
		Blurb = "Has watched every ghost hunt since forever. Finally joined in.",
		Look = { Skin = C(250, 240, 190), Hair = C(220, 215, 170), HairStyle = "None", Shirt = C(40, 40, 70), Pants = C(30, 30, 55), Shoes = C(250, 240, 190),
			Hat = "MoonHood", HatColor = C(40, 40, 70), Back = "Cape", BackColor = C(60, 60, 100), Tool = "MoonStaff", ToolColor = C(250, 240, 190), Beam = C(255, 250, 210), Aura = true },
	},
	NebulaNyxCometRider = {
		Id = "NebulaNyxCometRider", Name = "Nebula Nyx, Comet Rider", Rarity = "Ultra", Zone = "MoonBase", Power = 5.95e23,
		Blurb = "Rides a comet to work. Ghosts see the tail and give up.",
		Look = { Skin = C(245, 220, 210), Hair = C(255, 120, 220), HairStyle = "Buns", Shirt = C(60, 40, 120), Pants = C(120, 80, 200), Shoes = C(120, 240, 255),
			Hat = "SpaceHelmet", HatColor = C(220, 200, 255), Back = "CometTail", BackColor = C(120, 240, 255), Tool = "RayGun", ToolColor = C(120, 240, 255), Beam = C(255, 140, 230), Aura = true },
	},
	-- ZONE 32: VOID CRATE
	-- NOD: Doctor Who (time traveller, a blue box that's bigger on the inside, a buzzing gadget); no police box sign or logo
	RiftScout = {
		Id = "RiftScout", Name = "Doctor When", Rarity = "Common", Zone = "VoidThrone", Power = 2.81e22,
		Blurb = "Travels through time in a blue box that's much bigger on the inside. Always late, never too late.",
		Look = { Skin = C(240, 205, 180), Hair = C(90, 60, 40), HairStyle = "Spiky", Shirt = C(120, 70, 50), Pants = C(60, 50, 60), Shoes = C(70, 50, 40),
			Back = "TimeBox", BackColor = C(30, 60, 140), Tool = "Screwdriver", ToolColor = C(200, 205, 215), Beam = C(110, 210, 255) },
	},
	StarStitcher = {
		Id = "StarStitcher", Name = "Star Stitcher", Rarity = "Uncommon", Zone = "VoidThrone", Power = 4.67e22,
		Blurb = "Sews the holes in the sky shut, one star at a time.",
		Look = { Skin = C(200, 150, 110), Hair = C(250, 250, 255), HairStyle = "Buns", Shirt = C(40, 40, 80), Pants = C(30, 30, 60), Shoes = C(255, 240, 160),
			Hat = "Beanie", HatColor = C(60, 50, 110), Back = "Orbs", BackColor = C(255, 240, 160), Tool = "Wand", ToolColor = C(255, 240, 160), Beam = C(255, 245, 190) },
	},
	NullKnight = {
		Id = "NullKnight", Name = "Null Knight", Rarity = "Rare", Zone = "VoidThrone", Power = 7.75e22,
		Blurb = "Armour made of pure nothing. Surprisingly comfy.",
		Look = { Skin = C(60, 50, 80), Hair = C(20, 15, 30), HairStyle = "None", Shirt = C(30, 25, 45), Pants = C(25, 20, 40), Shoes = C(200, 150, 255),
			Hat = "KnightHelm", HatColor = C(30, 25, 45), Back = "Shield", BackColor = C(40, 30, 60), Tool = "Sword", ToolColor = C(200, 150, 255), Beam = C(210, 170, 255) },
	},
	PortalPolly = {
		Id = "PortalPolly", Name = "Portal Polly", Rarity = "Rare", Zone = "VoidThrone", Power = 7.75e22,
		Blurb = "Opens a portal, pops the ghost in, closes it. Done by lunch.",
		Look = { Skin = C(245, 215, 195), Hair = C(120, 240, 255), HairStyle = "Bob", Shirt = C(255, 140, 60), Pants = C(60, 60, 90), Shoes = C(255, 140, 60),
			Hat = "Goggles", HatColor = C(255, 140, 60), Back = "Rings", BackColor = C(120, 240, 255), Tool = "Orb", ToolColor = C(120, 240, 255), Beam = C(120, 240, 255) },
	},
	GlenAndJeff = {
		Id = "GlenAndJeff", Name = "Glen & Jeff", Rarity = "Legendary", Zone = "VoidThrone", Power = 1.91e23,
		Blurb = "A brave kid and his stretchy dog. Adventure is their middle name.",
		Look = { Skin = C(250, 220, 195), Hair = C(250, 250, 250), HairStyle = "None", Shirt = C(240, 110, 70), Pants = C(40, 60, 120), Shoes = C(30, 30, 40),
			Hat = "EarHood", HatColor = C(160, 235, 210), Back = "StretchyDog", BackColor = C(235, 160, 70), Tool = "Sword", ToolColor = C(255, 215, 90), Beam = C(255, 220, 120), Aura = true },
	},
	UmbraShadowTwin = {
		Id = "UmbraShadowTwin", Name = "Umbra, the Shadow Twin", Rarity = "Mythic", Zone = "VoidThrone", Power = 4.76e23,
		Blurb = "Steps out of your shadow to help, then steps right back in.",
		Look = { Skin = C(70, 50, 110), Hair = C(20, 15, 30), HairStyle = "Long", Shirt = C(40, 30, 60), Pants = C(25, 20, 40), Shoes = C(200, 150, 255),
			Hat = "Hood", HatColor = C(30, 20, 50), Back = "Cape", BackColor = C(60, 40, 100), Tool = "Orb", ToolColor = C(200, 150, 255), Beam = C(200, 150, 255), Aura = true },
	},
	TheLastLightKeeper = {
		Id = "TheLastLightKeeper", Name = "The Last Light Keeper", Rarity = "Secret", Zone = "VoidThrone", Power = 1.19e24,
		Blurb = "Keeps the final lantern burning so the Void never wins.",
		Look = { Skin = C(250, 245, 235), Hair = C(255, 255, 255), HairStyle = "Long", Shirt = C(250, 250, 255), Pants = C(220, 220, 240), Shoes = C(255, 230, 140),
			Hat = "Halo", HatColor = C(255, 240, 180), Back = "Wings", BackColor = C(255, 255, 255), Tool = "Lantern", ToolColor = C(255, 255, 255), Beam = C(255, 250, 220), Aura = true },
	},
	NovaEmperorsBane = {
		Id = "NovaEmperorsBane", Name = "Nova, the Emperor's Bane", Rarity = "Ultra", Zone = "VoidThrone", Power = 2.98e24,
		Blurb = "The only hunter the Void Emperor is scared of. She's four feet tall.",
		Look = { Skin = C(245, 220, 205), Hair = C(255, 255, 255), HairStyle = "Floaty", Shirt = C(20, 15, 35), Pants = C(250, 250, 255), Shoes = C(255, 230, 140),
			Hat = "StarCrown", HatColor = C(255, 230, 140), Back = "VoidRing", BackColor = C(20, 15, 35), Tool = "StarBlade", ToolColor = C(255, 255, 255), Beam = C(255, 240, 200), Aura = true, Signature = "Supernova" },
	},
	-- EXCLUSIVES
	ExclusiveLanternMarket = {
		Id = "ExclusiveLanternMarket", Name = "Jade Lanternbearer", Rarity = "Exclusive", Zone = "LanternMarket", Power = 9400000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 230, 160), HairStyle = "Spiky", Shirt = C(80, 220, 150), Pants = C(255, 230, 160), Shoes = C(80, 220, 150),
			Hat = "LanternRing", HatColor = C(80, 220, 150), Back = "LanternPole", BackColor = C(255, 230, 160), Tool = "Lantern", ToolColor = C(80, 220, 150), Beam = C(255, 230, 160), Aura = true },
	},
	ExclusivePhantomLibrary = {
		Id = "ExclusivePhantomLibrary", Name = "Silver Scribe", Rarity = "Exclusive", Zone = "PhantomLibrary", Power = 47000000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(150, 255, 230), HairStyle = "Spiky", Shirt = C(210, 215, 230), Pants = C(150, 255, 230), Shoes = C(210, 215, 230),
			Hat = "BookHat", HatColor = C(210, 215, 230), Back = "BookWings", BackColor = C(150, 255, 230), Tool = "Quill", ToolColor = C(210, 215, 230), Beam = C(150, 255, 230), Aura = true },
	},
	ExclusivePumpkinFarm = {
		Id = "ExclusivePumpkinFarm", Name = "Copper Cornkeeper", Rarity = "Exclusive", Zone = "PumpkinFarm", Power = 235000000000000,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 185, 120), HairStyle = "Spiky", Shirt = C(200, 110, 60), Pants = C(255, 185, 120), Shoes = C(200, 110, 60),
			Hat = "StrawHat", HatColor = C(200, 110, 60), Back = "CornBasket", BackColor = C(255, 185, 120), Tool = "Pitchfork", ToolColor = C(200, 110, 60), Beam = C(255, 185, 120), Aura = true },
	},
	ExclusiveGlowshroom = {
		Id = "ExclusiveGlowshroom", Name = "Opal Shroomkin", Rarity = "Exclusive", Zone = "Glowshroom", Power = 1.18e15,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 190, 240), HairStyle = "Spiky", Shirt = C(220, 255, 245), Pants = C(255, 190, 240), Shoes = C(220, 255, 245),
			Hat = "ShroomCap", HatColor = C(220, 255, 245), Back = "Wings", BackColor = C(255, 190, 240), Tool = "MoonStaff", ToolColor = C(220, 255, 245), Beam = C(255, 190, 240), Aura = true },
	},
	ExclusiveWaterPark = {
		Id = "ExclusiveWaterPark", Name = "Aquamarine Lifeguard", Rarity = "Exclusive", Zone = "WaterPark", Power = 5.88e15,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(150, 255, 240), HairStyle = "Spiky", Shirt = C(60, 190, 230), Pants = C(150, 255, 240), Shoes = C(60, 190, 230),
			Hat = "Visor", HatColor = C(60, 190, 230), Back = "Surfboard", BackColor = C(150, 255, 240), Tool = "Trident", ToolColor = C(60, 190, 230), Beam = C(150, 255, 240), Aura = true },
	},
	ExclusiveMirrorMaze = {
		Id = "ExclusiveMirrorMaze", Name = "Platinum Reflection", Rarity = "Exclusive", Zone = "MirrorMaze", Power = 2.94e16,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(200, 240, 255), HairStyle = "Spiky", Shirt = C(225, 228, 240), Pants = C(200, 240, 255), Shoes = C(225, 228, 240),
			Hat = "PrismCrown", HatColor = C(225, 228, 240), Back = "MirrorShards", BackColor = C(200, 240, 255), Tool = "HandMirror", ToolColor = C(225, 228, 240), Beam = C(200, 240, 255), Aura = true },
	},
	ExclusiveShoppingMall = {
		Id = "ExclusiveShoppingMall", Name = "Rose-Gold Shopper", Rarity = "Exclusive", Zone = "ShoppingMall", Power = 1.47e17,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 195, 185), HairStyle = "Spiky", Shirt = C(230, 140, 155), Pants = C(255, 195, 185), Shoes = C(230, 140, 155),
			Hat = "Bow", HatColor = C(230, 140, 155), Back = "Balloons", BackColor = C(255, 195, 185), Tool = "Megaphone", ToolColor = C(230, 140, 155), Beam = C(255, 195, 185), Aura = true },
	},
	ExclusiveGhostSubway = {
		Id = "ExclusiveGhostSubway", Name = "Chrome Conductor", Rarity = "Exclusive", Zone = "GhostSubway", Power = 7.34e17,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 220, 80), HairStyle = "Spiky", Shirt = C(200, 205, 220), Pants = C(255, 220, 80), Shoes = C(200, 205, 220),
			Hat = "ConductorCap", HatColor = C(200, 205, 220), Back = "Smokestack", BackColor = C(255, 220, 80), Tool = "Lantern", ToolColor = C(200, 205, 220), Beam = C(255, 220, 80), Aura = true },
	},
	ExclusiveDinoMuseum = {
		Id = "ExclusiveDinoMuseum", Name = "Amber Paleontologist", Rarity = "Exclusive", Zone = "DinoMuseum", Power = 3.67e18,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 205, 120), HairStyle = "Spiky", Shirt = C(150, 220, 130), Pants = C(255, 205, 120), Shoes = C(150, 220, 130),
			Hat = "Pith", HatColor = C(150, 220, 130), Back = "BatWings", BackColor = C(255, 205, 120), Tool = "Whip", ToolColor = C(150, 220, 130), Beam = C(255, 205, 120), Aura = true },
	},
	ExclusiveStadium = {
		Id = "ExclusiveStadium", Name = "Golden Champion", Rarity = "Exclusive", Zone = "Stadium", Power = 1.84e19,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 230, 140), HairStyle = "Spiky", Shirt = C(60, 110, 220), Pants = C(255, 230, 140), Shoes = C(60, 110, 220),
			Hat = "Helmet", HatColor = C(60, 110, 220), Back = "Wings", BackColor = C(255, 230, 140), Tool = "Trophy", ToolColor = C(60, 110, 220), Beam = C(255, 230, 140), Aura = true },
	},
	ExclusiveNeonCity = {
		Id = "ExclusiveNeonCity", Name = "Prismatic Popstar", Rarity = "Exclusive", Zone = "NeonCity", Power = 9.18e19,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(120, 240, 255), HairStyle = "Spiky", Shirt = C(255, 120, 220), Pants = C(120, 240, 255), Shoes = C(255, 120, 220),
			Hat = "Headphones", HatColor = C(255, 120, 220), Back = "Boombox", BackColor = C(120, 240, 255), Tool = "Guitar", ToolColor = C(255, 120, 220), Beam = C(120, 240, 255), Aura = true },
	},
	ExclusiveGiantsKitchen = {
		Id = "ExclusiveGiantsKitchen", Name = "Sugar-Glass Baker", Rarity = "Exclusive", Zone = "GiantsKitchen", Power = 4.59e20,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 240, 250), HairStyle = "Spiky", Shirt = C(255, 150, 200), Pants = C(255, 240, 250), Shoes = C(255, 150, 200),
			Hat = "ChefHat", HatColor = C(255, 150, 200), Back = "Balloons", BackColor = C(255, 240, 250), Tool = "Whisk", ToolColor = C(255, 150, 200), Beam = C(255, 240, 250), Aura = true },
	},
	ExclusiveCyberArcade = {
		Id = "ExclusiveCyberArcade", Name = "Holo High-Scorer", Rarity = "Exclusive", Zone = "CyberArcade", Power = 2.29e21,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(180, 255, 240), HairStyle = "Spiky", Shirt = C(200, 120, 255), Pants = C(180, 255, 240), Shoes = C(200, 120, 255),
			Hat = "Headphones", HatColor = C(200, 120, 255), Back = "Blocks", BackColor = C(180, 255, 240), Tool = "Joystick", ToolColor = C(200, 120, 255), Beam = C(180, 255, 240), Aura = true },
	},
	ExclusiveStormIslands = {
		Id = "ExclusiveStormIslands", Name = "Sapphire Stormcaller", Rarity = "Exclusive", Zone = "StormIslands", Power = 1.15e22,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 240, 120), HairStyle = "Spiky", Shirt = C(60, 110, 255), Pants = C(255, 240, 120), Shoes = C(60, 110, 255),
			Hat = "StormCloud", HatColor = C(60, 110, 255), Back = "StormWings", BackColor = C(255, 240, 120), Tool = "Thunderbolt", ToolColor = C(60, 110, 255), Beam = C(255, 240, 120), Aura = true },
	},
	ExclusiveMoonBase = {
		Id = "ExclusiveMoonBase", Name = "Moonstone Astronaut", Rarity = "Exclusive", Zone = "MoonBase", Power = 5.74e22,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 150, 80), HairStyle = "Spiky", Shirt = C(230, 235, 255), Pants = C(255, 150, 80), Shoes = C(230, 235, 255),
			Hat = "SpaceHelmet", HatColor = C(230, 235, 255), Back = "Jetpack", BackColor = C(255, 150, 80), Tool = "RayGun", ToolColor = C(230, 235, 255), Beam = C(255, 150, 80), Aura = true },
	},
	ExclusiveVoidThrone = {
		Id = "ExclusiveVoidThrone", Name = "Obsidian Starborn", Rarity = "Exclusive", Zone = "VoidThrone", Power = 2.87e23,
		Blurb = "Only from the Exclusive Crate. Shiny!",
		Look = { Skin = C(255, 225, 200), Hair = C(255, 255, 255), HairStyle = "Spiky", Shirt = C(40, 30, 50), Pants = C(255, 255, 255), Shoes = C(40, 30, 50),
			Hat = "StarCrown", HatColor = C(40, 30, 50), Back = "VoidRing", BackColor = C(255, 255, 255), Tool = "StarBlade", ToolColor = C(40, 30, 50), Beam = C(255, 255, 255), Aura = true },
	},

} :: { [string]: HunterDef }

-- Exclusive Crate (Robux): you get the exclusive hunter of your furthest unlocked area
Config.Exclusives = {
	Neighborhood = "ExclusiveNeighborhood",
	Cemetery = "ExclusiveCemetery",
	School = "ExclusiveSchool",
	Carnival = "ExclusiveCarnival",
	Hospital = "ExclusiveHospital",
	Harbor = "ExclusiveHarbor",
	Castle = "ExclusiveCastle",
	SpiritRealm = "ExclusiveSpiritRealm",
	Swamp = "ExclusiveSwamp",
	Frost = "ExclusiveFrost",
	Tomb = "ExclusiveTomb",
	ToyFactory = "ExclusiveToyFactory",
	Sunken = "ExclusiveSunken",
	Clockwork = "ExclusiveClockwork",
	Inferno = "ExclusiveInferno",
	Throne = "ExclusiveThrone",
	-- WORLD 2: THE OTHER SIDE (areas 17-32)
	LanternMarket = "ExclusiveLanternMarket",
	PhantomLibrary = "ExclusivePhantomLibrary",
	PumpkinFarm = "ExclusivePumpkinFarm",
	Glowshroom = "ExclusiveGlowshroom",
	WaterPark = "ExclusiveWaterPark",
	MirrorMaze = "ExclusiveMirrorMaze",
	ShoppingMall = "ExclusiveShoppingMall",
	GhostSubway = "ExclusiveGhostSubway",
	DinoMuseum = "ExclusiveDinoMuseum",
	Stadium = "ExclusiveStadium",
	NeonCity = "ExclusiveNeonCity",
	GiantsKitchen = "ExclusiveGiantsKitchen",
	CyberArcade = "ExclusiveCyberArcade",
	StormIslands = "ExclusiveStormIslands",
	MoonBase = "ExclusiveMoonBase",
	VoidThrone = "ExclusiveVoidThrone",

} :: { [string]: string }

Config.StarterHunter = "RookieHunter"

--==================================================================
-- CRATES (each zone crate's Weights are exact percents summing to 100:
-- Common 50 / Uncommon 35 / Rare 10 / Legendary 3.5 / Mythic 1 / Secret 0.4 / Ultra 0.1)
--==================================================================
export type CrateDef = {
	Id: string,
	Name: string,
	Zone: string,
	Price: number,
	Color: Color3,
	Trim: Color3,
	-- visual family member (CrateRig): Basic | Haunted | Elite | Carnival | Medical | Sailor | Royal | Spirit.
	-- Later crates add more containment hardware on the same chest.
	Style: string,
	Pool: { { Hunter: string, Weight: number } },
}

Config.Crates = {
	Beginner = {
		Id = "Beginner", Name = "BEGINNER HUNTER CRATE", Zone = "Neighborhood", Price = 25,
		Color = C(255, 150, 50), Trim = C(140, 255, 120), Style = "Basic",
		Pool = {
			{ Hunter = "RookieHunter", Weight = 23 }, -- Common 46% (split 2 ways)
			{ Hunter = "BowBelle", Weight = 23 }, -- Common 46% (split 2 ways)
			{ Hunter = "ParanormalIntern", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "GhostInvestigator", Weight = 14 }, -- Rare 14%
			{ Hunter = "SpectralSpecialist", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "MoonlightMedium", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "NightWatcher", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "CaptainBoo", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Haunted = {
		Id = "Haunted", Name = "HAUNTED HUNTER CRATE", Zone = "Cemetery", Price = 600,
		Color = C(110, 80, 200), Trim = C(90, 255, 180), Style = "Haunted",
		Pool = {
			{ Hunter = "GraveScout", Weight = 46 }, -- Common 46%
			{ Hunter = "CryptInvestigator", Weight = 16 }, -- Uncommon 32% (split 2 ways)
			{ Hunter = "LilMoonWitch", Weight = 16 }, -- Uncommon 32% (split 2 ways)
			{ Hunter = "SpiritWarden", Weight = 14 }, -- Rare 14%
			{ Hunter = "PhantomExorcist", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "GravelightOracle", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "ReapersApprentice", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "PetalChomper", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Elite = {
		Id = "Elite", Name = "ELITE HUNTER CRATE", Zone = "School", Price = 5000,
		Color = C(40, 30, 70), Trim = C(220, 120, 255), Style = "Elite",
		Pool = {
			{ Hunter = "SchoolInvestigator", Weight = 46 }, -- Common 46%
			{ Hunter = "ParanormalProfessor", Weight = 16 }, -- Uncommon 32% (split 2 ways)
			{ Hunter = "GloomyGus", Weight = 16 }, -- Uncommon 32% (split 2 ways)
			{ Hunter = "EliteContainmentAgent", Weight = 14 }, -- Rare 14%
			{ Hunter = "VoidHunter", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "SpiritValedictorian", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheSubstitute", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "CelestiaMoonwitch", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Carnival = {
		Id = "Carnival", Name = "CARNIVAL HUNTER CRATE", Zone = "Carnival", Price = 40000,
		Color = C(230, 60, 70), Trim = C(255, 210, 70), Style = "Carnival",
		Pool = {
			{ Hunter = "CarnivalScout", Weight = 46 }, -- Common 46%
			{ Hunter = "ParanormalPerformer", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "SpectralRingmaster", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "HeartlightHealer", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "PhantomTamer", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "GrandIllusionist", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheLastClown", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "PumpkinKingJack", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Medical = {
		Id = "Medical", Name = "PARANORMAL MEDICAL CRATE", Zone = "Hospital", Price = 400000,
		Color = C(235, 240, 250), Trim = C(110, 200, 255), Style = "Medical",
		Pool = {
			{ Hunter = "MedicalInvestigator", Weight = 46 }, -- Common 46%
			{ Hunter = "SpiritMedic", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "ParanormalDoctor", Weight = 14 }, -- Rare 14%
			{ Hunter = "SpectralSurgeon", Weight = 2.75 }, -- Legendary 5.5% (split 2 ways)
			{ Hunter = "StarlitHexPrincess", Weight = 2.75 }, -- Legendary 5.5% (split 2 ways)
			{ Hunter = "ChiefOfSpiritMedicine", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "NightShiftNurse", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "DoctorMiracle", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Sailor = {
		Id = "Sailor", Name = "SPECTRAL SAILOR CRATE", Zone = "Harbor", Price = 3500000,
		Color = C(140, 95, 55), Trim = C(80, 230, 220), Style = "Sailor",
		Pool = {
			{ Hunter = "HarborHunter", Weight = 46 }, -- Common 46%
			{ Hunter = "ParanormalSailor", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "SpectralPirateHunter", Weight = 14 }, -- Rare 14%
			{ Hunter = "GhostCaptainHunter", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "KrakenTamer", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "FlyingDutchman", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "SirenSeraphina", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Royal = {
		Id = "Royal", Name = "ROYAL HUNTER CRATE", Zone = "Castle", Price = 22000000,
		Color = C(70, 40, 120), Trim = C(255, 200, 70), Style = "Royal",
		Pool = {
			{ Hunter = "CastleInvestigator", Weight = 46 }, -- Common 46%
			{ Hunter = "SpiritKnight", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "RoyalExorcist", Weight = 14 }, -- Rare 14%
			{ Hunter = "PhantomChampion", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "PhantomMonarch", Weight = 0.9 }, -- Mythic 1.8% (split 2 ways)
			{ Hunter = "PumpkinKnight", Weight = 0.9 }, -- Mythic 1.8% (split 2 ways)
			{ Hunter = "HeadlessKnight", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "CountBatula", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	SpiritRealm = {
		Id = "SpiritRealm", Name = "SPIRIT REALM CRATE", Zone = "SpiritRealm", Price = 130000000,
		Color = C(40, 35, 80), Trim = C(110, 240, 255), Style = "Spirit",
		Pool = {
			{ Hunter = "RealmExplorer", Weight = 46 }, -- Common 46%
			{ Hunter = "SpiritWalker", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "VoidInvestigator", Weight = 14 }, -- Rare 14%
			{ Hunter = "CelestialGhostHunter", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "AstralGuardian", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "GhostHunterZero", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "StarfallValkyrie", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Bog = {
		Id = "Bog", Name = "BOG HUNTER CRATE", Zone = "Swamp", Price = 780000000,
		Color = C(90, 120, 60), Trim = C(170, 255, 120), Style = "Swamp",
		Pool = {
			{ Hunter = "SwampScout", Weight = 46 }, -- Common 46%
			{ Hunter = "BogTracker", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "MarshMystic", Weight = 14 }, -- Rare 14%
			{ Hunter = "FireflySage", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "FrogPrince", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "GatorKing", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "Bogzilla", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Frost = {
		Id = "Frost", Name = "FROSTBITE CRATE", Zone = "Frost", Price = 4680000000,
		Color = C(200, 230, 255), Trim = C(110, 200, 255), Style = "Frost",
		Pool = {
			{ Hunter = "SnowScout", Weight = 46 }, -- Common 46%
			{ Hunter = "IceClimber", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "FrostMage", Weight = 14 }, -- Rare 14%
			{ Hunter = "YetiWhisperer", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "AuroraKnight", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheAbominable", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "CrystaliaSnowQueen", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Tomb = {
		Id = "Tomb", Name = "PHARAOH CRATE", Zone = "Tomb", Price = 28100000000,
		Color = C(220, 180, 100), Trim = C(70, 200, 220), Style = "Tomb",
		Pool = {
			{ Hunter = "TombExplorer", Weight = 46 }, -- Common 46%
			{ Hunter = "ScarabSeeker", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "SandMage", Weight = 14 }, -- Rare 14%
			{ Hunter = "PharaohHunter", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "SunKeeper", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "GoldenMummy", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "JackalAvenger", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Toy = {
		Id = "Toy", Name = "TOY BOX CRATE", Zone = "ToyFactory", Price = 168000000000,
		Color = C(255, 120, 170), Trim = C(255, 220, 80), Style = "Toy",
		Pool = {
			{ Hunter = "ToyTinker", Weight = 46 }, -- Common 46%
			{ Hunter = "WindUpKnight", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "MarionetteMaster", Weight = 14 }, -- Rare 14%
			{ Hunter = "TeddyTitan", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "JackInTheBoxer", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheNutcracker", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "PrincessPomPom", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Sunken = {
		Id = "Sunken", Name = "SUNKEN TREASURE CRATE", Zone = "Sunken", Price = 1010000000000,
		Color = C(60, 140, 170), Trim = C(255, 220, 120), Style = "Sunken",
		Pool = {
			{ Hunter = "DeepDiver", Weight = 46 }, -- Common 46%
			{ Hunter = "CoralKeeper", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "TideCaller", Weight = 14 }, -- Rare 14%
			{ Hunter = "AtlanteanHunter", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "PearlSovereign", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "AbyssWalker", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "GlubbleTheDeepOne", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Clockwork = {
		Id = "Clockwork", Name = "CLOCKWORK CRATE", Zone = "Clockwork", Price = 6070000000000,
		Color = C(150, 110, 70), Trim = C(230, 200, 120), Style = "Clock",
		Pool = {
			{ Hunter = "GearScout", Weight = 46 }, -- Common 46%
			{ Hunter = "ClockTinker", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "ChronoMage", Weight = 14 }, -- Rare 14%
			{ Hunter = "TimeBender", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "SteamTitan", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheTimeless", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "TickTockTitaness", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Inferno = {
		Id = "Inferno", Name = "INFERNO CRATE", Zone = "Inferno", Price = 36400000000000,
		Color = C(80, 40, 40), Trim = C(255, 150, 60), Style = "Inferno",
		Pool = {
			{ Hunter = "EmberScout", Weight = 46 }, -- Common 46%
			{ Hunter = "LavaDiver", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "FireDancer", Weight = 14 }, -- Rare 14%
			{ Hunter = "PhoenixHunter", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "DragonCaller", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheEternalFlame", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "Scorchmaw", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Throne = {
		Id = "Throne", Name = "KING'S CRATE", Zone = "Throne", Price = 218000000000000,
		Color = C(250, 245, 255), Trim = C(255, 215, 90), Style = "Throne",
		Pool = {
			{ Hunter = "ThronePage", Weight = 46 }, -- Common 46%
			{ Hunter = "ShadowGuard", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "CrownMage", Weight = 14 }, -- Rare 14%
			{ Hunter = "KingsChampion", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "EternalMonarch", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheFinalHunter", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "SovereignSupreme", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Exclusive = {
		Id = "Exclusive", Name = "EXCLUSIVE CRATE", Zone = "Neighborhood", Price = 0,
		Color = C(60, 40, 110), Trim = C(120, 240, 255), Style = "Spirit",
		Pool = {}, -- granted by the Robux product (Config.Exclusives), never rolled
	},	-- WORLD 2: THE OTHER SIDE (areas 17-32)
	Lantern = {
		Id = "Lantern", Name = "LANTERN CRATE", Zone = "LanternMarket", Price = 1.31e15,
		Color = C(200, 40, 50), Trim = C(255, 200, 80), Style = "Lantern",
		Pool = {
			{ Hunter = "StallSweeper", Weight = 46 }, -- Common 46%
			{ Hunter = "LanternLighter", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "ChefSqueaks", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "DumplingDarla", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "BigBao", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "FireworkFei", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "MidnightNoodleMaster", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "LumaLanternEmpress", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Library = {
		Id = "Library", Name = "SPELLBOOK CRATE", Zone = "PhantomLibrary", Price = 7.86e15,
		Color = C(90, 50, 40), Trim = C(120, 255, 220), Style = "Library",
		Pool = {
			{ Hunter = "ShushScout", Weight = 46 }, -- Common 46%
			{ Hunter = "BookwormBenny", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "SpecsMcSpellbook", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "PaigeTurner", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "QuillKnight", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "ArchivistAurelia", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheOverdueOne", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "InkwellStorySorcerer", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Harvest = {
		Id = "Harvest", Name = "HARVEST CRATE", Zone = "PumpkinFarm", Price = 4.72e16,
		Color = C(205, 110, 40), Trim = C(255, 215, 90), Style = "Harvest",
		Pool = {
			{ Hunter = "FarmhandFinn", Weight = 46 }, -- Common 46%
			{ Hunter = "CornMazeCora", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "BrainyStrawford", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "SomePigSammy", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "OldMacBoonald", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "GemmaGourdheart", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "HeadlessHayrider", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "AutumnaHarvestQueen", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Shroom = {
		Id = "Shroom", Name = "GLOWSHROOM CRATE", Zone = "Glowshroom", Price = 2.83e17,
		Color = C(60, 110, 90), Trim = C(120, 255, 230), Style = "Shroom",
		Pool = {
			{ Hunter = "SporeSniffer", Weight = 46 }, -- Common 46%
			{ Hunter = "MossRangerMo", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "GrandpaBluecap", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "TeaTimeTilly", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "GlowcapGuardian", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "QueenMorel", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheSporefather", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "LuminaBloomheart", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Splash = {
		Id = "Splash", Name = "SPLASH CRATE", Zone = "WaterPark", Price = 1.7e18,
		Color = C(40, 170, 220), Trim = C(255, 230, 90), Style = "Splash",
		Pool = {
			{ Hunter = "LifeguardLuca", Weight = 46 }, -- Common 46%
			{ Hunter = "SunscreenSam", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "MermaidenMarina", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "ForgetfulFlo", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "SplashGordon", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "SlideQueenShayla", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "GnawsGentleShark", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "TsunamiTiaWaveRider", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Mirror = {
		Id = "Mirror", Name = "MIRROR CRATE", Zone = "MirrorMaze", Price = 1.02e19,
		Color = C(200, 215, 235), Trim = C(170, 230, 255), Style = "Mirror",
		Pool = {
			{ Hunter = "PolisherPip", Weight = 46 }, -- Common 46%
			{ Hunter = "MazeMapper", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "LookingGlassLucy", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "CopycatCass", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "PrismKnight", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "MirageMystic", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheReflection", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "KaleidaQueenOfFacets", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Mall = {
		Id = "Mall", Name = "SHOPPING CRATE", Zone = "ShoppingMall", Price = 6.11e19,
		Color = C(235, 110, 170), Trim = C(130, 230, 255), Style = "Shopping",
		Pool = {
			{ Hunter = "CartPusherCody", Weight = 46 }, -- Common 46%
			{ Hunter = "PretzelPam", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "OfficerBartBlurt", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "JollyBuddyElfington", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "MondaysMcFluff", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "DreamHouseDebbie", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheMannequin", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "BargainaMegaSale", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Subway = {
		Id = "Subway", Name = "SUBWAY CRATE", Zone = "GhostSubway", Price = 3.67e20,
		Color = C(70, 80, 100), Trim = C(255, 220, 80), Style = "Subway",
		Pool = {
			{ Hunter = "PlatformPatrol", Weight = 46 }, -- Common 46%
			{ Hunter = "TrackTinker", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "ProtonPete", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "ShellyShellshock", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "MidnightConductor", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "ThirdRailRhea", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheLastTrainHome", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "RailsPhantomEngineer", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Fossil = {
		Id = "Fossil", Name = "FOSSIL CRATE", Zone = "DinoMuseum", Price = 2.2e21,
		Color = C(185, 150, 100), Trim = C(140, 230, 130), Style = "Fossil",
		Pool = {
			{ Hunter = "DustyBrushworth", Weight = 46 }, -- Common 46%
			{ Hunter = "TourGuideTheo", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "NightShiftLarry", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "JurassicJeff", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "IndianaBones", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "PurplePalBarnaby", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheLivingExhibit", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "AmberlynFossilQueen", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Champion = {
		Id = "Champion", Name = "CHAMPION CRATE", Zone = "Stadium", Price = 1.32e22,
		Color = C(40, 90, 180), Trim = C(255, 220, 80), Style = "Trophy",
		Pool = {
			{ Hunter = "PopcornPercy", Weight = 46 }, -- Common 46%
			{ Hunter = "RefereeRita", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "CoachNedLassiter", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "RockyBalBooa", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "AirPup", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "CaptainMightyQuack", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheTwelfthFan", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "VictoriaVortexMVP", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Neon = {
		Id = "Neon", Name = "NEON CRATE", Zone = "NeonCity", Price = 7.92e22,
		Color = C(30, 25, 50), Trim = C(255, 80, 220), Style = "Neon",
		Pool = {
			{ Hunter = "RooftopRunner", Weight = 46 }, -- Common 46%
			{ Hunter = "DJGhostbeat", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "WebSpook", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "NeonNinjaNix", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "TheNightOwl", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "GlitchRider", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheStatic", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "NeonovaCitySuperstar", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	CookieJar = {
		Id = "CookieJar", Name = "COOKIE JAR CRATE", Zone = "GiantsKitchen", Price = 4.75e23,
		Color = C(225, 190, 140), Trim = C(255, 110, 90), Style = "CookieJar",
		Pool = {
			{ Hunter = "SugarCubeSid", Weight = 46 }, -- Common 46%
			{ Hunter = "ThimbleThea", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "StueyTeeny", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "BorrowerEtty", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "GingerbreadRon", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "Thumbelinda", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheFridgeLight", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "SprinklaQueenOfSweets", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Arcade = {
		Id = "Arcade", Name = "ARCADE CRATE", Zone = "CyberArcade", Price = 2.85e24,
		Color = C(50, 30, 90), Trim = C(80, 255, 220), Style = "Arcade",
		Pool = {
			{ Hunter = "CoinOpCal", Weight = 46 }, -- Common 46%
			{ Hunter = "ButtonMasherBea", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "MustachioThePlumber", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "SpeedySpikes", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "WakaWakaWanda", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "BlockDropBoris", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "PlayerTwo", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "PixellaArcadeEmpress", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Storm = {
		Id = "Storm", Name = "STORM CRATE", Zone = "StormIslands", Price = 1.71e25,
		Color = C(70, 90, 140), Trim = C(255, 240, 120), Style = "Storm",
		Pool = {
			{ Hunter = "KiteFlyerKit", Weight = 46 }, -- Common 46%
			{ Hunter = "CloudHopper", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "GrandpaBalloony", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "ZephyrZoe", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "ThunderThad", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "TempestTamsin", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheLightningKid", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "AerisQueenOfTheTempest", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Moon = {
		Id = "Moon", Name = "MOON BASE CRATE", Zone = "MoonBase", Price = 1.03e26,
		Color = C(200, 205, 215), Trim = C(255, 130, 60), Style = "Moon",
		Pool = {
			{ Hunter = "MoonCadet", Weight = 46 }, -- Common 46%
			{ Hunter = "CraterMechanic", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "CosmoZoomer", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "DocFizzbang", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "OrbitOlivia", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "LunarLancer", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheMoonFace", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "NebulaNyxCometRider", Weight = 0.15 }, -- Ultra 0.15%
		},
	},
	Void = {
		Id = "Void", Name = "VOID CRATE", Zone = "VoidThrone", Price = 6.16e26,
		Color = C(25, 15, 40), Trim = C(255, 255, 255), Style = "Void",
		Pool = {
			{ Hunter = "RiftScout", Weight = 46 }, -- Common 46%
			{ Hunter = "StarStitcher", Weight = 32 }, -- Uncommon 32%
			{ Hunter = "NullKnight", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "PortalPolly", Weight = 7 }, -- Rare 14% (split 2 ways)
			{ Hunter = "GlenAndJeff", Weight = 5.5 }, -- Legendary 5.5%
			{ Hunter = "UmbraShadowTwin", Weight = 1.8 }, -- Mythic 1.8%
			{ Hunter = "TheLastLightKeeper", Weight = 0.55 }, -- Secret 0.55%
			{ Hunter = "NovaEmperorsBane", Weight = 0.15 }, -- Ultra 0.15%
		},
	},

} :: { [string]: CrateDef }

-- Luck boost multiplies weights of these rarities (and above) by Boosts.Luck.Multiplier.
Config.LuckAffectsFromOrder = 3 -- Rare and higher

-- LUCKY OPENS (bought with Ectoplasm at a crate): the next `Opens` opens of THAT crate roll with
-- x`Multiplier` luck (stacks with boosts/passes). Costs crate price x `PriceMultiplier` on top of
-- the opens themselves, so Rare+ per Ecto must beat plain opens (tests/Economy.spec.luau).
Config.LuckyOpens = { Opens = 5, Multiplier = 2, PriceMultiplier = 2, MaxStack = 50 }

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
	HunterRunSpeed = 26, -- client visual
	HitboxDiameter = 5.4, -- invisible tap target per ghost (x ghost Scale); the body is ~3.5
}

--==================================================================
-- ECTOPLASM DROPS + PICKUP RADIUS
-- GHOST RETALIATION + HUNTER KNOCKOUTS (v1.6)
-- Ghosts are passive until a crew attacks them. Then, every Interval seconds, the ghost
-- telegraphs (Windup) and hits ONE hunter of a crew that is still attacking it. Hunters that
-- reach 0 HP are knocked out for RecoverySeconds (real time: keeps counting offline); they are
-- never deleted. Hunter max HP = (tiered) power * HPPerPower * (1 + pet HP bonus).
-- Hit = ghost max Spirit * HitPerSpirit[kind], but never more than HitCap[kind] of the target's
-- max HP (so a knockout always takes several hits and the telegraph gives time to react).
-- Hits use max HP WITHOUT the pet HP bonus, so HP pets always mean more hits to a knockout.
--==================================================================
Config.Retaliation = {
	Interval = 2.5,
	Windup = 0.9,
	HPPerPower = 8,
	HitPerSpirit = { Normal = 0.04, MiniBoss = 0.06, Boss = 0.08, Event = 0.05 } :: { [string]: number },
	HitCap = { Normal = 0.25, MiniBoss = 0.4, Boss = 0.5, Event = 0.35 } :: { [string]: number },
	RegenDelay = 4, -- seconds without being hit before a hunter starts healing
	RegenPerSecond = 0.15, -- fraction of max HP per second
	RecoverySeconds = 60, -- knockout timer (owner-approved v1.16, was 120)
}

--==================================================================
-- HUNTER TIERS + MERGING (v1.6): 5 identical hunters of one tier -> 1 of the next tier
--==================================================================
export type TierDef = { Name: string, Icon: string, Mult: number, Color: Color3 }
Config.Tiers = {
	[0] = { Name = "NORMAL", Icon = "", Mult = 1, Color = Color3.fromRGB(255, 255, 255) },
	[1] = { Name = "SHINY", Icon = "✨", Mult = 2.5, Color = Color3.fromRGB(255, 225, 90) },
	[2] = { Name = "MEGA", Icon = "💎", Mult = 6.25, Color = Color3.fromRGB(120, 230, 255) },
} :: { [number]: TierDef }
Config.Merge = {
	Count = 5,
	MaxTier = 2,
	-- Ectoplasm cost = the hunter's crate price * CostMult[result tier]
	CostMult = { [1] = 2, [2] = 10 } :: { [number]: number },
}

--==================================================================
-- TRADING (v1.6): hunters only, both players in the same server
--==================================================================
Config.Trade = {
	Enabled = true, -- false switches trading off (old trade records still settle on join)
	BoothRadius = 24, -- trade requests only between players this close to the TRADING booth
	MaxOffer = 8, -- hunters per side
	RequestSeconds = 30, -- a trade request expires after this
	ConfirmCooldown = 2, -- seconds after the last offer change before CONFIRM is accepted
	DataStoreName = "GhostHunterTrades_v1", -- durable trade records for crash recovery
	AppliedMemory = 100, -- trade ids remembered per profile (exactly-once)
}

--==================================================================
-- SPIRIT SHARDS + GHOST PETS (v1.6). Shards come ONLY from Boss Tower chests.
--==================================================================
export type PetDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Price: number?, -- Spirit Shards; nil = not sold (event pets)
	Bonus: { Kind: string, Value: number }, -- Kind: Power | Ecto | HP | Recovery
	Color: Color3,
	Glow: Color3,
	Icon: string, -- emoji shown in the pets list (the 3D look is in PetFollowers, one builder per Id)
}
Config.PetRules = {
	MaxEquipped = 3,
	MaxOwned = 60,
	-- total bonus per kind from all equipped pets is capped (upgrades and hunters stay the main power)
	-- owner-approved (v1.16): Secret/Ultra pets stack above two Legendaries (was 0.6/0.5/0.75/0.5)
	Caps = { Power = 0.95, Ecto = 0.85, HP = 1.0, Recovery = 0.65 } :: { [string]: number },
}
Config.Pets = {
	-- ids, rarities and bonuses of the first nine pets are save data: never change them (v2 only
	-- renamed them and gave them new looks)
	GlowWisp = { Id = "GlowWisp", Name = "Wisp Candle", Rarity = "Common", Price = nil, Bonus = { Kind = "Power", Value = 0.05 }, Color = Color3.fromRGB(236, 226, 255), Glow = Color3.fromRGB(120, 255, 150), Icon = "🕯️" },
	BooBat = { Id = "BooBat", Name = "Boo Brew", Rarity = "Common", Price = nil, Bonus = { Kind = "Ecto", Value = 0.05 }, Color = Color3.fromRGB(255, 160, 200), Glow = Color3.fromRGB(205, 160, 255), Icon = "☕" },
	EctoSlime = { Id = "EctoSlime", Name = "Ecto Slime", Rarity = "Common", Price = nil, Bonus = { Kind = "Ecto", Value = 0.05 }, Color = Color3.fromRGB(120, 235, 140), Glow = Color3.fromRGB(120, 255, 150), Icon = "💚" },
	BooBalloon = { Id = "BooBalloon", Name = "Boo Balloon", Rarity = "Common", Price = nil, Bonus = { Kind = "Power", Value = 0.05 }, Color = Color3.fromRGB(150, 210, 255), Glow = Color3.fromRGB(170, 220, 255), Icon = "🎈" },
	JellyGhost = { Id = "JellyGhost", Name = "Pumpkin Sprite", Rarity = "Uncommon", Price = nil, Bonus = { Kind = "HP", Value = 0.15 }, Color = Color3.fromRGB(255, 145, 45), Glow = Color3.fromRGB(255, 170, 60), Icon = "🎃" },
	PhantomKitty = { Id = "PhantomKitty", Name = "Witch Kitty", Rarity = "Uncommon", Price = nil, Bonus = { Kind = "Recovery", Value = 0.15 }, Color = Color3.fromRGB(78, 62, 112), Glow = Color3.fromRGB(150, 230, 170), Icon = "🐱" },
	CursedTeddy = { Id = "CursedTeddy", Name = "Cursed Teddy", Rarity = "Uncommon", Price = nil, Bonus = { Kind = "HP", Value = 0.15 }, Color = Color3.fromRGB(160, 120, 200), Glow = Color3.fromRGB(190, 150, 255), Icon = "🧸" },
	MiniMummy = { Id = "MiniMummy", Name = "Mini Mummy", Rarity = "Uncommon", Price = nil, Bonus = { Kind = "Recovery", Value = 0.15 }, Color = Color3.fromRGB(235, 225, 195), Glow = Color3.fromRGB(200, 255, 120), Icon = "🩹" },
	MoonOwl = { Id = "MoonOwl", Name = "Grimoire", Rarity = "Rare", Price = nil, Bonus = { Kind = "Power", Value = 0.12 }, Color = Color3.fromRGB(105, 70, 190), Glow = Color3.fromRGB(140, 140, 255), Icon = "📖" },
	SpiritFox = { Id = "SpiritFox", Name = "Cauldron Imp", Rarity = "Rare", Price = nil, Bonus = { Kind = "Ecto", Value = 0.12 }, Color = Color3.fromRGB(62, 52, 82), Glow = Color3.fromRGB(120, 255, 150), Icon = "🧪" },
	HauntedMirror = { Id = "HauntedMirror", Name = "Haunted Mirror", Rarity = "Rare", Price = nil, Bonus = { Kind = "Power", Value = 0.12 }, Color = Color3.fromRGB(255, 205, 60), Glow = Color3.fromRGB(200, 150, 255), Icon = "🔮" },
	TreasureMimic = { Id = "TreasureMimic", Name = "Treasure Mimic", Rarity = "Rare", Price = nil, Bonus = { Kind = "Ecto", Value = 0.12 }, Color = Color3.fromRGB(150, 90, 50), Glow = Color3.fromRGB(120, 255, 150), Icon = "💰" },
	SpookyDrake = { Id = "SpookyDrake", Name = "Boo-FO", Rarity = "Epic", Price = nil, Bonus = { Kind = "Power", Value = 0.22 }, Color = Color3.fromRGB(200, 196, 230), Glow = Color3.fromRGB(180, 130, 255), Icon = "🛸" },
	HauntedClock = { Id = "HauntedClock", Name = "Haunted Clock", Rarity = "Epic", Price = nil, Bonus = { Kind = "Ecto", Value = 0.22 }, Color = Color3.fromRGB(120, 70, 200), Glow = Color3.fromRGB(255, 120, 210), Icon = "⏰" },
	GhostTrain = { Id = "GhostTrain", Name = "Ghost Express", Rarity = "Epic", Price = nil, Bonus = { Kind = "Power", Value = 0.22 }, Color = Color3.fromRGB(130, 60, 190), Glow = Color3.fromRGB(120, 255, 150), Icon = "🚂" },
	GhostPhoenix = { Id = "GhostPhoenix", Name = "Tiny Reaper", Rarity = "Legendary", Price = nil, Bonus = { Kind = "Power", Value = 0.35 }, Color = Color3.fromRGB(92, 70, 150), Glow = Color3.fromRGB(255, 200, 90), Icon = "💀" },
	CrystalSkull = { Id = "CrystalSkull", Name = "Crystal Skull", Rarity = "Legendary", Price = nil, Bonus = { Kind = "Ecto", Value = 0.35 }, Color = Color3.fromRGB(150, 230, 255), Glow = Color3.fromRGB(130, 230, 255), Icon = "💎" },
	-- launch event reward (never in eggs): Legendary, same bonus size as the other Legendaries
	LanternSpirit = { Id = "LanternSpirit", Name = "Lantern Spirit", Rarity = "Legendary", Price = nil, Bonus = { Kind = "Power", Value = 0.35 }, Color = Color3.fromRGB(255, 230, 150), Glow = Color3.fromRGB(255, 200, 80), Icon = "🏮" },
	-- Cursed Egg top tier (Boss Tower checkpoint 50). Secret/Ultra bonuses sit exactly at the
	-- PetRules.Caps total, so one such pet alone maxes that bonus (shown numbers are what it gives).
	PhantomKing = { Id = "PhantomKing", Name = "Phantom King", Rarity = "Mythic", Price = nil, Bonus = { Kind = "Power", Value = 0.45 }, Color = Color3.fromRGB(205, 45, 90), Glow = Color3.fromRGB(255, 205, 60), Icon = "👑" },
	GhostCarousel = { Id = "GhostCarousel", Name = "Teacup Carousel", Rarity = "Mythic", Price = nil, Bonus = { Kind = "HP", Value = 0.45 }, Color = Color3.fromRGB(255, 120, 170), Glow = Color3.fromRGB(255, 200, 130), Icon = "🎠" },
	GhostMusicBox = { Id = "GhostMusicBox", Name = "Haunted Music Box", Rarity = "Secret", Price = nil, Bonus = { Kind = "Recovery", Value = 0.5 }, Color = Color3.fromRGB(150, 60, 110), Glow = Color3.fromRGB(255, 175, 220), Icon = "🎶" },
	GhostShipBottle = { Id = "GhostShipBottle", Name = "Ghost Ship in a Bottle", Rarity = "Secret", Price = nil, Bonus = { Kind = "Ecto", Value = 0.5 }, Color = Color3.fromRGB(125, 70, 185), Glow = Color3.fromRGB(120, 255, 150), Icon = "⛵" },
	GhostBalloonRide = { Id = "GhostBalloonRide", Name = "Starlight Balloon", Rarity = "Ultra", Price = nil, Bonus = { Kind = "Power", Value = 0.6 }, Color = Color3.fromRGB(190, 160, 255), Glow = Color3.fromRGB(150, 240, 205), Icon = "🌙" },
} :: { [string]: PetDef }
Config.PetOrder = {
	"GlowWisp", "BooBat", "EctoSlime", "BooBalloon", "JellyGhost", "PhantomKitty", "CursedTeddy", "MiniMummy", "MoonOwl",
	"SpiritFox", "HauntedMirror", "TreasureMimic", "SpookyDrake", "HauntedClock", "GhostTrain", "GhostPhoenix", "CrystalSkull", "LanternSpirit",
	"PhantomKing", "GhostCarousel", "GhostMusicBox", "GhostShipBottle", "GhostBalloonRide",
}

-- PET EGGS (v1.8): the only way to get pets with Spirit Shards (direct pet purchases are gone;
-- event pets such as LanternSpirit are never in eggs). Hatched at the PET HATCHERY near the
-- Boss Tower. Egg tier is not pet rarity: each egg lists its pets with exact percent chances
-- that must total 100 (tests/Eggs.spec.luau). Unlock = Tower checkpoint needed (0 = none).
export type EggOdds = { Pet: string, Chance: number }
export type EggDef = {
	Id: string,
	Name: string,
	Price: number, -- Spirit Shards
	Unlock: number, -- TowerCheckpoint required (0 = always open)
	Odds: { EggOdds }, -- percent, rolled in this order
	Color: Color3,
	Accent: Color3,
}
Config.Eggs = {
	HauntedEgg = {
		Id = "HauntedEgg", Name = "Haunted Egg", Price = 200, Unlock = 0,
		Odds = {
			{ Pet = "GlowWisp", Chance = 20 }, { Pet = "BooBat", Chance = 19 }, { Pet = "EctoSlime", Chance = 19 },
			{ Pet = "BooBalloon", Chance = 17 }, { Pet = "JellyGhost", Chance = 9 }, { Pet = "CursedTeddy", Chance = 8 },
			{ Pet = "PhantomKitty", Chance = 6 }, { Pet = "MoonOwl", Chance = 2 },
		},
		Color = Color3.fromRGB(120, 60, 190), Accent = Color3.fromRGB(120, 255, 140),
	},
	PhantomEgg = {
		Id = "PhantomEgg", Name = "Phantom Egg", Price = 1200, Unlock = 10,
		Odds = {
			{ Pet = "JellyGhost", Chance = 20 }, { Pet = "PhantomKitty", Chance = 20 }, { Pet = "MiniMummy", Chance = 20 },
			{ Pet = "MoonOwl", Chance = 13 }, { Pet = "HauntedMirror", Chance = 12 }, { Pet = "SpiritFox", Chance = 10 },
			{ Pet = "SpookyDrake", Chance = 3 }, { Pet = "HauntedClock", Chance = 2 },
		},
		Color = Color3.fromRGB(210, 230, 255), Accent = Color3.fromRGB(110, 180, 255),
	},
	MoonlightEgg = {
		Id = "MoonlightEgg", Name = "Moonlight Egg", Price = 5000, Unlock = 25,
		Odds = {
			{ Pet = "MoonOwl", Chance = 20 }, { Pet = "SpiritFox", Chance = 20 }, { Pet = "TreasureMimic", Chance = 20 },
			{ Pet = "SpookyDrake", Chance = 15 }, { Pet = "GhostTrain", Chance = 15 }, { Pet = "GhostPhoenix", Chance = 6 },
			{ Pet = "CrystalSkull", Chance = 4 },
		},
		Color = Color3.fromRGB(30, 40, 120), Accent = Color3.fromRGB(255, 235, 150),
	},
	-- top tier; fractional chances are exact in binary (multiples of 0.25) so the total is exactly 100
	CursedEgg = {
		Id = "CursedEgg", Name = "Cursed Egg", Price = 20000, Unlock = 50,
		Odds = {
			{ Pet = "GhostPhoenix", Chance = 35 }, { Pet = "CrystalSkull", Chance = 35 },
			{ Pet = "PhantomKing", Chance = 12.5 }, { Pet = "GhostCarousel", Chance = 12.5 },
			{ Pet = "GhostMusicBox", Chance = 2.25 }, { Pet = "GhostShipBottle", Chance = 2.25 },
			{ Pet = "GhostBalloonRide", Chance = 0.5 },
		},
		Color = Color3.fromRGB(28, 12, 34), Accent = Color3.fromRGB(190, 40, 90),
	},
} :: { [string]: EggDef }
Config.EggOrder = { "HauntedEgg", "PhantomEgg", "MoonlightEgg", "CursedEgg" }

--==================================================================
-- ENDLESS BOSS TOWER (v1.6). Party of up to 4 (pad at the entrance); every run starts at
-- Room 1; rewards are paid the moment a boss is beaten and are never taken back.
-- v1.7 scaling (starting values for testing): boss health is an ABSOLUTE curve, so stronger
-- teams climb further: HP = BaseHP * HPGrowth^(room-1) * FiveRoomBump^floor(room/5),
-- but never less than party power * MinKillSeconds (strong teams can't one-shot rooms).
-- Boss hit = target hunter max HP (without the pet HP bonus) * HitFraction(room), which grows
-- more gently than health.
--==================================================================
Config.Tower = {
	MaxParty = 4,
	PadRadius = 9, -- players on the entrance pad join the party
	Countdown = 6, -- seconds after START before the party enters
	RoomSeconds = 180, -- a boss not beaten in time ends the run (rewards kept)
	BetweenRoomsSeconds = 30, -- time to choose CONTINUE / LEAVE before the run ends
	BaseHP = 180, -- room 1: ~9 s for a beginner crew (~20 power)
	HPGrowth = 1.25, -- +25% health per room (owner: a real grind; was 1.15)
	FiveRoomBump = 1.35, -- extra x1.35 from each big-boss room (5, 10, ...) on; owner D3: the big boss is the jump
	MinKillSeconds = 0, -- owner: boss health never scales with the party's power (was 4 s of party damage minimum)
	CheckpointEvery = 5, -- clearing room 5, 10, ... saves a checkpoint (next run may start at 6, 11, ...)
	HitFractionBase = 0.1,
	HitFractionGrowth = 1.05,
	HitFractionCap = 0.95,
	Interval = 2.3,
	MaxScaledRoom = 400, -- scaling stops growing past this room (numbers stay finite)
	-- rewards per player for beating room r:
	ShardsBase = 4, -- shards = ShardsBase + r * ShardsPerRoom (x milestone)
	ShardsPerRoom = 1.5,
	-- ecto = min(EctoPerMinute * (fight s + RoomOverheadSeconds) / 60 * zone multiplier,
	--           SpiritPayShare * boss HP / members * best zone's ghost Ecto per Spirit) (x milestone):
	-- a run pays about what farming your best zone pays (tests/EconSim.luau "ratio" column;
	-- Economy.spec asserts <= 1.5x).
	EctoPerMinute = 230,
	SpiritPayShare = 1.9,
	RoomOverheadSeconds = 8, -- walking in, vote, boss intro
	MilestoneEvery = { [10] = 3, [5] = 2 } :: { [number]: number }, -- room % key == 0 -> multiplier (largest wins)
	-- regular bosses cycle over the non-milestone rooms (1-4, 6-9, 11-14, 16-19, 21-24, ...)
	Bosses = {
		"TowerWarden", "TowerJester", "TowerPumpkinKnight", "TowerSwampHag",
		"TowerBaron", "TowerClockSpecter", "TowerBanshee", "TowerBoneCaptain",
		"TowerMummyPharaoh", "TowerFrostWraith", "TowerPuppetMaster", "TowerStormPhantom",
		"TowerHauntedArmor", "TowerCandleLich", "TowerVampireCount", "TowerTitan",
	},
	BigBossEvery = 5, -- room % 5 == 0 -> BIG boss
	BigBosses = { "TowerGraveColossus", "TowerVoidLeviathan", "TowerPhantomEmperor", "TowerEclipseOverlord" },
	Slots = 12, -- simultaneous runs per server (each gets its own room space)
}

--==================================================================
-- RARE PET LAUNCH EVENT (v1.6). Started ONLY by the developer button (DEV panel).
-- A new event needs a NEW Id: an Id that was ever started can never be started again.
--==================================================================
Config.RarePetEvent = {
	Id = "launch_rare_pet_1",
	Seconds = 48 * 3600,
	RequiredSeconds = 30 * 60,
	Pet = "LanternSpirit",
	TickSeconds = 5,
	IdleSeconds = 120, -- no movement and no actions for this long = idle (not counted)
	DataStoreName = "GhostHunterGlobal_v1", -- same store as the other global events
	Key = "RarePetEvent",
	Topic = "GHRarePetEvent",
	RefreshSeconds = 60,
	AdminUserIds = { 20194281, 837974693 } :: { number }, -- ONLY these accounts may start it (live servers)
}

--==================================================================
-- FALL SAFETY (v1.6): characters below this height are put back on solid ground
--==================================================================
Config.FallSafety = { MinY = -40, CheckSeconds = 0.5, SafeEvery = 1 }

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
		Levels = { 14, 19, 25, 33, 45, 52, 60, 68 }, Costs = { 120, 900, 6000, 30000, 600000, 15000000, 400000000 }, Format = "studs",
	},
	EctoBonus = {
		Id = "EctoBonus", Name = "ECTOPLASM BONUS", Icon = "💚",
		Description = "Earn more Ectoplasm from every ghost.",
		Levels = { 0, 0.1, 0.2, 0.35, 0.5, 0.7, 0.9, 1.2 }, Costs = { 300, 2500, 15000, 80000, 1500000, 40000000, 900000000 }, Format = "percent",
	},
	MoveSpeed = {
		Id = "MoveSpeed", Name = "MOVEMENT SPEED", Icon = "👟",
		Description = "Run between ghosts faster.",
		Levels = { 16, 18, 20, 22, 24, 26, 28, 30 }, Costs = { 200, 1500, 9000, 45000, 900000, 25000000, 600000000 }, Format = "speed",
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

-- all luck sources multiplied together (boost x pass x Server Luck x Lucky Opens) never exceed this
Config.LuckCap = 6

Config.Daily = {
	Cooldown = 20 * 3600, -- can claim again after this
	StreakReset = 48 * 3600, -- streak resets if you wait longer than this
	Rewards = {
		{ Kind = "Ecto", Amount = 200, Label = "200 ECTOPLASM" },
		{ Kind = "Ecto", Amount = 500, Label = "500 ECTOPLASM" },
		{ Kind = "Boost", Boost = "Luck", Seconds = 600, Label = "10 MIN LUCK" },
		{ Kind = "Ecto", Amount = 1500, Label = "1,500 ECTOPLASM" },
		{ Kind = "Boost", Boost = "Ecto", Seconds = 900, Label = "15 MIN 2x ECTO" },
		{ Kind = "Ecto", Amount = 3000, Label = "3,000 ECTOPLASM" },
		{ Kind = "Day7", Amount = 5000, Crate = "Best", Boost = "Luck", Seconds = 1800, Label = "5,000 ECTO + FREE CRATE + 30 MIN LUCK" }, -- "Best" = your best area's crate
	} :: { RewardDef },
	-- Ecto rewards scale with your best unlocked zone so late players still care
	-- (roughly the ratio of typical farming income per zone).
	ZoneMultiplier = { 1, 6, 30, 200, 1200, 7000, 40000, 220000, 1190000, 6430000, 34700000, 187000000, 1010000000, 5450000000, 29400000000, 159000000000,
		859000000000, 4640000000000, 25000000000000, 135000000000000, 730000000000000, 3.94e15, 2.13e16, 1.15e17, 6.21e17, 3.35e18, 1.81e19, 9.78e19, 5.28e20, 2.85e21, 1.54e22, 8.32e22 }, -- 17-32: World 2
}

--==================================================================
-- GIANT POLTERGEIST EVENT
--==================================================================
Config.Event = {
	Ghost = "GiantPoltergeist",
	FirstDelay = 240, -- seconds after server start
	Interval = 600, -- seconds between events (end > next warning)
	WarningSeconds = 15,
	Duration = 180, -- seconds to defeat it before it escapes
	-- Spirit = Base + SpiritPerPower * sum(min(crew power, PowerCap) of players in server),
	-- i.e. ~60 s of everyone's combined crew power; a lone starter crew (~30) needs ~110 s.
	SpiritBase = 1500,
	SpiritPerPower = 60,
	-- high enough that late crews still face a ~60 s fight (the cap only guards against absurd values)
	PowerCap = 50000000,
	-- Rewards (per participant): RewardBase * zoneMultiplier * clamp(share * players, MinShare, MaxShare)
	RewardBase = 625, -- +25% (progression 20% faster)
	MinShare = 0.35,
	MaxShare = 2.5,
	RewardDrops = 18,
	MinContribution = 0.01, -- share of Spirit you must deal to count as a participant...
	MinSeconds = 8, -- ...or this many seconds of your own crew's power
	JoinRadius = 260, -- crews within this distance of the arena when it spawns set its Spirit
}

--==================================================================
-- SHOP (Robux). Fill in the IDs after creating products on the Creator Hub.
--==================================================================
export type ProductDef = { Key: string, Name: string, Icon: string, Kind: string, Amount: number?, Boost: string?, Seconds: number?, ProductId: number?, PriceLabel: string, Blurb: string? }
export type PassDef = { Key: string, Name: string, Icon: string, PassId: number?, PriceLabel: string, Slots: number?, Multiplier: number?, Storage: number?, Blurb: string?, Hidden: boolean? }

Config.Products = {
	{ Key = "Ecto1", Name = "SACK OF ECTOPLASM", Icon = "💚", Kind = "Ecto", Amount = 5000, ProductId = 3715910102, PriceLabel = "R$ 49" }, -- ~102 Ecto/R$ (x best-area multiplier),
	{ Key = "Ecto2", Name = "BARREL OF ECTOPLASM", Icon = "🛢️", Kind = "Ecto", Amount = 30000, ProductId = 3715909987, PriceLabel = "R$ 199" }, -- ~151 Ecto/R$: the bigger pack is the better deal,
	{ Key = "Luck30", Name = "30 MIN LUCK BOOST", Icon = "🍀", Kind = "Boost", Boost = "Luck", Seconds = 1800, ProductId = 3715910020, PriceLabel = "R$ 199" },
	{ Key = "Ecto30", Name = "30 MIN 2x ECTOPLASM", Icon = "⚡", Kind = "Boost", Boost = "Ecto", Seconds = 1800, ProductId = 3715910145, PriceLabel = "R$ 149" },
	{ Key = "SingleSkip", Name = "SINGLE CRATE SKIP", Icon = "⏩", Kind = "CrateSkip", ProductId = nil, PriceLabel = "R$ 9", Blurb = "Skip one crate animation" },
	{ Key = "SkipArea", Name = "UNLOCK NEXT AREA", Icon = "🔓", Kind = "SkipArea", Amount = 12000, ProductId = 3715915055, PriceLabel = "R$ 99", Blurb = "Opens your next locked area right now" },
	{ Key = "ExclusiveCrate", Name = "EXCLUSIVE CRATE", Icon = "💎", Kind = "ExclusiveCrate", ProductId = 3715915093, PriceLabel = "R$ 199", Blurb = "An EXCLUSIVE hunter for your best area" },
	{ Key = "ServerLuck", Name = "SERVER LUCK 15 MIN", Icon = "🍀", Kind = "ServerLuck", Seconds = 900, ProductId = 3715915133, PriceLabel = "R$ 149", Blurb = "2x crate luck for EVERYONE in the server" },
	{ Key = "SummonEvent", Name = "SUMMON GIANT POLTERGEIST", Icon = "👻", Kind = "SummonEvent", ProductId = 3715915181, PriceLabel = "R$ 299", Blurb = "Starts the boss event for the whole server" },
} :: { ProductDef }
-- Ecto product amounts scale with best zone (same table as Daily.ZoneMultiplier).
Config.GamePasses = {
	{ Key = "ExtraSlots", Name = "+2 HUNTER SLOTS", Icon = "🎒", PassId = 2007038280, PriceLabel = "R$ 149", Slots = 2 },
	{ Key = "DoubleEcto", Name = "PERMANENT 2x ECTOPLASM", Icon = "💎", PassId = 2005844290, PriceLabel = "R$ 299", Multiplier = 2 },
	-- LEGACY: Auto Attack is FREE for everyone now. The pass is no longer sold (Hidden); players who
	-- bought it get AUTO OPEN for free instead (Config.LegacyAutoAttackGrantsAutoOpen).
	{ Key = "AutoAttack", Name = "AUTO ATTACK", Icon = "🤖", PassId = 2007026293, PriceLabel = "R$ 199", Blurb = "Your crew picks the next ghost for you", Hidden = true },
	{ Key = "LuckyHunter", Name = "LUCKY HUNTER", Icon = "🍀", PassId = 2005532289, PriceLabel = "R$ 349", Multiplier = 1.5, Blurb = "Better crate luck forever (x1.5)" },
	{ Key = "TripleOpen", Name = "TRIPLE OPEN", Icon = "📦", PassId = 2004530357, PriceLabel = "R$ 199", Blurb = "Open 3 crates at once" },
	{ Key = "SuperMagnet", Name = "SUPER MAGNET", Icon = "🧲", PassId = 2006720281, PriceLabel = "R$ 149", Multiplier = 1.6, Blurb = "Grab Ectoplasm from much further away" },
	{ Key = "VIP", Name = "VIP", Icon = "👑", PassId = 2005856286, PriceLabel = "R$ 249", Multiplier = 1.1, Blurb = "VIP tag, gold name, +10% Ectoplasm" },
	{ Key = "Storage", Name = "+50 HUNTER STORAGE", Icon = "🗃️", PassId = 2005124303, PriceLabel = "R$ 99", Storage = 50, Blurb = "Keep 50 more hunters" },
	{ Key = "RainbowBeams", Name = "RAINBOW BEAMS", Icon = "🌈", PassId = 2004968300, PriceLabel = "R$ 149", Blurb = "Your crew fires rainbow beams (looks only)" },
	{ Key = "PermanentSkip", Name = "PERMANENT CRATE SKIP", Icon = "⏩", PassId = 2005971344, PriceLabel = "R$ 49", Blurb = "Skip every crate animation, forever" },
	{ Key = "AutoOpen", Name = "AUTO OPEN", Icon = "🔁", PassId = 2006061299, PriceLabel = "R$ 49", Blurb = "Crates open by themselves while you stand at them" },
	{ Key = "SparkleTrail", Name = "SPARKLE TRAIL", Icon = "✨", PassId = 2006036302, PriceLabel = "R$ 99", Blurb = "A sparkly trail follows you (looks only)" },
} :: { PassDef }

--==================================================================
-- AUTO ATTACK (free for everyone; only automates choosing targets).
-- Tap a ghost once to send your crew; after the poof the crew comes home.
-- With the toggle ON, the server picks the nearest ghost in the zone you stand in.
-- No extra damage, rewards, drops or pickup range.
--==================================================================
-- Players who bought the old Auto Attack pass (Auto Attack is free now) get Auto Open for free.
Config.LegacyAutoAttackGrantsAutoOpen = true

-- Crate skips: the reveal is only a cinematic; the hunter is already rolled and saved before it
-- plays, so skipping never changes, rerolls or duplicates a reward.
Config.CrateSkip = { Product = "SingleSkip", Pass = "PermanentSkip", MaxTokens = 50 }

-- AUTO OPEN (game pass): the server re-opens the chosen crate while you stand at its station.
Config.AutoOpen = {
	Pass = "AutoOpen",
	Interval = 5.6, -- seconds between opens (time for the full reveal)
	FastInterval = 1.6, -- with Permanent Crate Skip: quick reveal
}

-- GLOBAL EVENTS (developer-controlled from the DEV panel; never automatic). State lives in a
-- DataStore (new servers read it) and changes are broadcast with MessagingService.
Config.GlobalEvents = {
	DataStoreName = "GhostHunterGlobal_v1",
	Key = "Events",
	Topic = "GHGlobalEvents",
	RefreshSeconds = 60, -- servers also re-read the state this often (in case a message is missed)
	Ecto2xMultiplier = 2,
}

-- Robux extras
Config.ServerLuck = { Multiplier = 2, MaxStackSeconds = 3600 } -- server-wide crate luck (product)
Config.TripleOpen = { Count = 3, Pass = "TripleOpen" }

Config.AutoAttack = {
	Range = 45, -- studs from the player
	ScanSeconds = 0.5, -- how often idle crews look for a ghost
}

--==================================================================
-- RATE LIMITS (requests per window, per player, per action)
--==================================================================
Config.RateLimits = {
	Default = { Count = 10, Window = 1 },
	SelectTarget = { Count = 8, Window = 1 },
	OpenCrate = { Count = 3, Window = 1 },
	Inventory = { Count = 12, Window = 1 },
}

-- Extra developer accounts (UserIds) that get the DEV button in live servers. The game's
-- creator (or the owner of the creator group) and anyone in Studio always get it.
Config.DevUserIds = { 20194281, 837974693 } :: { number } -- kcdrewcarter + 837974693 (only these get dev tools live)

-- Player feedback (FEEDBACK button in Settings; read in the DEV panel)
Config.Feedback = {
	DataStoreName = "GhostHunterFeedback_v1",
	InboxSize = 300, -- newest kept
	MinLength = 8,
	MaxLength = 500,
	Cooldown = 60, -- seconds between messages per player
	PerServer = 5, -- messages per player per server
}

-- Spawn leaderboard (all-time Ectoplasm, OrderedDataStore)
Config.Leaderboard = {
	DataStoreName = "GhostHunterTopEcto_v1",
	-- second board: each player's best-ever crew power (written only when it rises)
	PowerDataStoreName = "GhostHunterTopPower_v1",
	Rows = 10,
	RefreshSeconds = 120,
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
	-- Lobby (spawn plaza, HQ, booths, hatchery, Boss Tower entrance, boards) sits behind the
	-- Neighborhood: X MinX..MaxX, Z BackZ..FrontZ, no ghosts. The left side is wider (the Boss
	-- Tower stands there). Hedges close it on three sides; a hedge wall centred on FrontZ (6 thick)
	-- closes the front, with a free open arch (EntranceWidth, centred on X = 0) into the Neighborhood.
	Lobby = { BackZ = -130, FrontZ = -37, MinX = -96, MaxX = 64, EntranceWidth = 34 },
	Spawn = Vector3.new(0, 3, -70),
	HalfWidth = 140, -- playable area spans X -HalfWidth..HalfWidth
	Gates = {
		-- gate that unlocks Zone Id, centred on X=0 at this Z
		Cemetery = { Z = 260, Width = 34 },
		School = { Z = 540, Width = 34 },
		Carnival = { Z = 880, Width = 34 },
		Hospital = { Z = 1220, Width = 34 },
		Harbor = { Z = 1560, Width = 34 },
		Castle = { Z = 1920, Width = 34 },
		SpiritRealm = { Z = 2280, Width = 34 },
		Swamp = { Z = 2680, Width = 34 },
		Frost = { Z = 3040, Width = 34 },
		Tomb = { Z = 3400, Width = 34 },
		ToyFactory = { Z = 3760, Width = 34 },
		Sunken = { Z = 4120, Width = 34 },
		Clockwork = { Z = 4480, Width = 34 },
		Inferno = { Z = 4840, Width = 34 },
		Throne = { Z = 5200, Width = 34 },
		-- World 2 (Lantern Market has no gate wall: its entry is the portal at the end of the Throne)
		PhantomLibrary = { Z = 7360, Width = 34 },
		PumpkinFarm = { Z = 7720, Width = 34 },
		Glowshroom = { Z = 8080, Width = 34 },
		WaterPark = { Z = 8440, Width = 34 },
		MirrorMaze = { Z = 8800, Width = 34 },
		ShoppingMall = { Z = 9160, Width = 34 },
		GhostSubway = { Z = 9520, Width = 34 },
		DinoMuseum = { Z = 9880, Width = 34 },
		Stadium = { Z = 10240, Width = 34 },
		NeonCity = { Z = 10600, Width = 34 },
		GiantsKitchen = { Z = 10960, Width = 34 },
		CyberArcade = { Z = 11320, Width = 34 },
		StormIslands = { Z = 11680, Width = 34 },
		MoonBase = { Z = 12040, Width = 34 },
		VoidThrone = { Z = 12400, Width = 34 },
	},
	CrateStations = {
		Beginner = Vector3.new(-28, 0, -6), -- just inside the lobby entrance
		Haunted = Vector3.new(-28, 0, 292),
		Elite = Vector3.new(-28, 0, 572),
		Carnival = Vector3.new(-28, 0, 912),
		Medical = Vector3.new(-28, 0, 1252),
		Sailor = Vector3.new(-28, 0, 1592),
		Royal = Vector3.new(-28, 0, 1952),
		SpiritRealm = Vector3.new(-28, 0, 2312),
		Bog = Vector3.new(-28, 0, 2712),
		Frost = Vector3.new(-28, 0, 3072),
		Tomb = Vector3.new(-28, 0, 3432),
		Toy = Vector3.new(-28, 0, 3792),
		Sunken = Vector3.new(-28, 0, 4152),
		Clockwork = Vector3.new(-28, 0, 4512),
		Inferno = Vector3.new(-28, 0, 4872),
		Throne = Vector3.new(-28, 0, 5232),
		-- World 2 (Lantern Market has no gate wall: its entry is the portal at the end of the Throne)
		Lantern = Vector3.new(-28, 0, 7032),
		Library = Vector3.new(-28, 0, 7392),
		Harvest = Vector3.new(-28, 0, 7752),
		Shroom = Vector3.new(-28, 0, 8112),
		Splash = Vector3.new(-28, 0, 8472),
		Mirror = Vector3.new(-28, 0, 8832),
		Mall = Vector3.new(-28, 0, 9192),
		Subway = Vector3.new(-28, 0, 9552),
		Fossil = Vector3.new(-28, 0, 9912),
		Champion = Vector3.new(-28, 0, 10272),
		Neon = Vector3.new(-28, 0, 10632),
		CookieJar = Vector3.new(-28, 0, 10992),
		Arcade = Vector3.new(-28, 0, 11352),
		Storm = Vector3.new(-28, 0, 11712),
		Moon = Vector3.new(-28, 0, 12072),
		Void = Vector3.new(-28, 0, 12432),
	},
	-- Fast Travel (WORLDS menu) arrival points: open ground beside each zone's path, clear of
	-- ghost areas, stations and props (the builders keep a circle around each one free).
	ZoneSpawns = {
		Neighborhood = Vector3.new(0, 3, -70), -- the lobby spawn
		Cemetery = Vector3.new(26, 3, 296),
		School = Vector3.new(26, 3, 572),
		Carnival = Vector3.new(26, 3, 912),
		Hospital = Vector3.new(26, 3, 1252),
		Harbor = Vector3.new(26, 3, 1592),
		Castle = Vector3.new(26, 3, 1952),
		SpiritRealm = Vector3.new(26, 3, 2312),
		Swamp = Vector3.new(26, 3, 2712),
		Frost = Vector3.new(26, 3, 3072),
		Tomb = Vector3.new(26, 3, 3432),
		ToyFactory = Vector3.new(26, 3, 3792),
		Sunken = Vector3.new(26, 3, 4152),
		Clockwork = Vector3.new(26, 3, 4512),
		Inferno = Vector3.new(26, 3, 4872),
		Throne = Vector3.new(26, 3, 5232),
		-- World 2 (Lantern Market has no gate wall: its entry is the portal at the end of the Throne)
		LanternMarket = Vector3.new(26, 3, 7032),
		PhantomLibrary = Vector3.new(26, 3, 7392),
		PumpkinFarm = Vector3.new(26, 3, 7752),
		Glowshroom = Vector3.new(26, 3, 8112),
		WaterPark = Vector3.new(26, 3, 8472),
		MirrorMaze = Vector3.new(26, 3, 8832),
		ShoppingMall = Vector3.new(26, 3, 9192),
		GhostSubway = Vector3.new(26, 3, 9552),
		DinoMuseum = Vector3.new(26, 3, 9912),
		Stadium = Vector3.new(26, 3, 10272),
		NeonCity = Vector3.new(26, 3, 10632),
		GiantsKitchen = Vector3.new(26, 3, 10992),
		CyberArcade = Vector3.new(26, 3, 11352),
		StormIslands = Vector3.new(26, 3, 11712),
		MoonBase = Vector3.new(26, 3, 12072),
		VoidThrone = Vector3.new(26, 3, 12432),
	},
	-- World portals (World/Portals.luau, ProgressService). ToWorld2 stands at the far end of the
	-- Ghost King's Throne and works like the gate of Zone (bought with the same UnlockZone flow
	-- near Position); once owned, touching it sends you to Config.Layout.ZoneSpawns[Zone].
	-- Buying Zone also needs Boss beaten at least once (kill credit on it, any share of the
	-- damage counts; saved in the profile's BossesBeaten): Unlock Next Area can't skip that.
	-- ToWorld1 stands at the start of Lantern Market and sends you back to Arrive (in front of
	-- the World 2 portal, facing back into the Throne hall). Position = centre of the ring's base.
	Portals = {
		ToWorld2 = { Zone = "LanternMarket", Boss = "GhostKing", Position = Vector3.new(84, 0, 5546) },
		ToWorld1 = { Position = Vector3.new(0, 0, 7010), Arrive = Vector3.new(84, 3, 5528) },
	},
	UpgradeStation = Vector3.new(28, 0, -6),
	-- lobby boards on the right of the spawn plaza, side by side, turned toward the plaza:
	-- TOP GHOST HUNTERS (all-time Ectoplasm) and TOP POWER (best crew power)
	Leaderboard = { Position = Vector3.new(45.6, 0, -76.9), Yaw = math.rad(72) },
	PowerBoard = { Position = Vector3.new(38.4, 0, -55.1), Yaw = math.rad(72) },
	Hatchery = Vector3.new(-27, 0, -93), -- Pet Hatchery centre (PetService BuyEgg near check)
	TradeBooth = Vector3.new(31, 0, -89), -- TRADING booth: both players must stand near it to trade
	-- Boss Tower entrance in the lobby, left of the Pet Hatchery, facing the spawn plaza: party
	-- pad centre (TowerService pad checks use the built TowerPad part; Tutorial points here).
	TowerEntrance = { Pad = Vector3.new(-52, 0, -64) }, -- just left of the Pet Hatchery as seen from spawn
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
		-- ZONE 4 Carnival (Z 880..1220)
		{ Ghost = "CarnivalSpirit", Center = Vector3.new(0, 0, 965), Radius = 30, Count = 6 },
		{ Ghost = "CarnivalSpirit", Center = Vector3.new(-82, 0, 1000), Radius = 24, Count = 4 },
		{ Ghost = "ClownPhantom", Center = Vector3.new(75, 0, 1055), Radius = 26, Count = 4 },
		{ Ghost = "ClownPhantom", Center = Vector3.new(-62, 0, 1115), Radius = 24, Count = 4 },
		{ Ghost = "RingmasterPoltergeist", Center = Vector3.new(0, 0, 1165), Radius = 22, Count = 1 },
		-- ZONE 5 Hospital (Z 1220..1560)
		{ Ghost = "PatientSpirit", Center = Vector3.new(0, 0, 1305), Radius = 30, Count = 6 },
		{ Ghost = "PatientSpirit", Center = Vector3.new(-82, 0, 1340), Radius = 24, Count = 4 },
		{ Ghost = "PhantomDoctor", Center = Vector3.new(75, 0, 1395), Radius = 26, Count = 4 },
		{ Ghost = "PhantomDoctor", Center = Vector3.new(-62, 0, 1455), Radius = 24, Count = 4 },
		{ Ghost = "HospitalDirector", Center = Vector3.new(0, 0, 1505), Radius = 22, Count = 1 },
		-- ZONE 6 Harbor (Z 1560..1920)
		{ Ghost = "SailorSpirit", Center = Vector3.new(0, 0, 1645), Radius = 30, Count = 6 },
		{ Ghost = "SailorSpirit", Center = Vector3.new(-82, 0, 1680), Radius = 24, Count = 4 },
		{ Ghost = "PhantomPirate", Center = Vector3.new(75, 0, 1740), Radius = 26, Count = 4 },
		{ Ghost = "PhantomPirate", Center = Vector3.new(-62, 0, 1800), Radius = 24, Count = 4 },
		{ Ghost = "GhostCaptain", Center = Vector3.new(0, 0, 1860), Radius = 24, Count = 1 },
		-- ZONE 7 Castle (Z 1920..2280)
		{ Ghost = "KnightSpirit", Center = Vector3.new(0, 0, 2005), Radius = 30, Count = 6 },
		{ Ghost = "KnightSpirit", Center = Vector3.new(-82, 0, 2040), Radius = 24, Count = 4 },
		{ Ghost = "RoyalPhantom", Center = Vector3.new(75, 0, 2100), Radius = 26, Count = 4 },
		{ Ghost = "RoyalPhantom", Center = Vector3.new(-62, 0, 2160), Radius = 24, Count = 4 },
		{ Ghost = "CursedKing", Center = Vector3.new(0, 0, 2220), Radius = 24, Count = 1 },
		-- ZONE 8 Spirit Realm (Z 2280..2680)
		{ Ghost = "AncientSpirit", Center = Vector3.new(0, 0, 2365), Radius = 30, Count = 6 },
		{ Ghost = "AncientSpirit", Center = Vector3.new(-82, 0, 2400), Radius = 24, Count = 4 },
		{ Ghost = "VoidPhantom", Center = Vector3.new(75, 0, 2470), Radius = 26, Count = 4 },
		{ Ghost = "VoidPhantom", Center = Vector3.new(-62, 0, 2530), Radius = 24, Count = 4 },
		{ Ghost = "SpiritOverlord", Center = Vector3.new(0, 0, 2605), Radius = 28, Count = 1 },
		-- ZONE 9 Phantom Swamp (Z 2680..3040)
		{ Ghost = "BogWisp", Center = Vector3.new(0, 0, 2765), Radius = 30, Count = 6 },
		{ Ghost = "BogWisp", Center = Vector3.new(-82, 0, 2800), Radius = 24, Count = 4 },
		{ Ghost = "MarshPhantom", Center = Vector3.new(75, 0, 2860), Radius = 26, Count = 4 },
		{ Ghost = "MarshPhantom", Center = Vector3.new(-62, 0, 2920), Radius = 24, Count = 4 },
		{ Ghost = "SwampLord", Center = Vector3.new(0, 0, 2985), Radius = 26, Count = 1 },
		-- ZONE 10 Frostbite Peaks (Z 3040..3400)
		{ Ghost = "FrostSpirit", Center = Vector3.new(0, 0, 3125), Radius = 30, Count = 6 },
		{ Ghost = "FrostSpirit", Center = Vector3.new(-82, 0, 3160), Radius = 24, Count = 4 },
		{ Ghost = "YetiPhantom", Center = Vector3.new(75, 0, 3220), Radius = 26, Count = 4 },
		{ Ghost = "YetiPhantom", Center = Vector3.new(-62, 0, 3280), Radius = 24, Count = 4 },
		{ Ghost = "BlizzardQueen", Center = Vector3.new(0, 0, 3345), Radius = 26, Count = 1 },
		-- ZONE 11 Pharaoh'S Tomb (Z 3400..3760)
		{ Ghost = "MummySpirit", Center = Vector3.new(0, 0, 3485), Radius = 30, Count = 6 },
		{ Ghost = "MummySpirit", Center = Vector3.new(-82, 0, 3520), Radius = 24, Count = 4 },
		{ Ghost = "ScarabPhantom", Center = Vector3.new(75, 0, 3580), Radius = 26, Count = 4 },
		{ Ghost = "ScarabPhantom", Center = Vector3.new(-62, 0, 3640), Radius = 24, Count = 4 },
		{ Ghost = "PharaohsGhost", Center = Vector3.new(0, 0, 3705), Radius = 26, Count = 1 },
		-- ZONE 12 Haunted Toy Factory (Z 3760..4120)
		{ Ghost = "ToySoldierSpirit", Center = Vector3.new(0, 0, 3845), Radius = 30, Count = 6 },
		{ Ghost = "ToySoldierSpirit", Center = Vector3.new(-82, 0, 3880), Radius = 24, Count = 4 },
		{ Ghost = "JackInTheBoxPhantom", Center = Vector3.new(75, 0, 3940), Radius = 26, Count = 4 },
		{ Ghost = "JackInTheBoxPhantom", Center = Vector3.new(-62, 0, 4000), Radius = 24, Count = 4 },
		{ Ghost = "PuppetMaster", Center = Vector3.new(0, 0, 4065), Radius = 26, Count = 1 },
		-- ZONE 13 Sunken City (Z 4120..4480)
		{ Ghost = "BubbleSpirit", Center = Vector3.new(0, 0, 4205), Radius = 30, Count = 6 },
		{ Ghost = "BubbleSpirit", Center = Vector3.new(-82, 0, 4240), Radius = 24, Count = 4 },
		{ Ghost = "SirenPhantom", Center = Vector3.new(75, 0, 4300), Radius = 26, Count = 4 },
		{ Ghost = "SirenPhantom", Center = Vector3.new(-62, 0, 4360), Radius = 24, Count = 4 },
		{ Ghost = "LeviathanGhost", Center = Vector3.new(0, 0, 4425), Radius = 26, Count = 1 },
		-- ZONE 14 Clockwork Tower (Z 4480..4840)
		{ Ghost = "CogSpirit", Center = Vector3.new(0, 0, 4565), Radius = 30, Count = 6 },
		{ Ghost = "CogSpirit", Center = Vector3.new(-82, 0, 4600), Radius = 24, Count = 4 },
		{ Ghost = "ClockworkPhantom", Center = Vector3.new(75, 0, 4660), Radius = 26, Count = 4 },
		{ Ghost = "ClockworkPhantom", Center = Vector3.new(-62, 0, 4720), Radius = 24, Count = 4 },
		{ Ghost = "TimeKeeper", Center = Vector3.new(0, 0, 4785), Radius = 26, Count = 1 },
		-- ZONE 15 Inferno Caverns (Z 4840..5200)
		{ Ghost = "EmberSpirit", Center = Vector3.new(0, 0, 4925), Radius = 30, Count = 6 },
		{ Ghost = "EmberSpirit", Center = Vector3.new(-82, 0, 4960), Radius = 24, Count = 4 },
		{ Ghost = "MagmaPhantom", Center = Vector3.new(75, 0, 5020), Radius = 26, Count = 4 },
		{ Ghost = "MagmaPhantom", Center = Vector3.new(-62, 0, 5080), Radius = 24, Count = 4 },
		{ Ghost = "InfernoTitan", Center = Vector3.new(0, 0, 5145), Radius = 26, Count = 1 },
		-- ZONE 16 Ghost King'S Throne (Z 5200..5560)
		{ Ghost = "RoyalGuardSpirit", Center = Vector3.new(0, 0, 5285), Radius = 30, Count = 6 },
		{ Ghost = "RoyalGuardSpirit", Center = Vector3.new(-82, 0, 5320), Radius = 24, Count = 4 },
		{ Ghost = "ShadowPhantom", Center = Vector3.new(75, 0, 5380), Radius = 26, Count = 4 },
		{ Ghost = "ShadowPhantom", Center = Vector3.new(-62, 0, 5440), Radius = 24, Count = 4 },
		{ Ghost = "GhostKing", Center = Vector3.new(0, 0, 5505), Radius = 28, Count = 1 },
		-- ZONE 17 (World 2) LanternMarket (Z 7000..7360)
		{ Ghost = "LanternWisp", Center = Vector3.new(0, 0, 7085), Radius = 30, Count = 6 },
		{ Ghost = "LanternWisp", Center = Vector3.new(-82, 0, 7120), Radius = 24, Count = 4 },
		{ Ghost = "DumplingDrifter", Center = Vector3.new(75, 0, 7180), Radius = 26, Count = 4 },
		{ Ghost = "DumplingDrifter", Center = Vector3.new(-62, 0, 7240), Radius = 24, Count = 4 },
		{ Ghost = "LanternDragon", Center = Vector3.new(0, 0, 7305), Radius = 26, Count = 1 },
		-- ZONE 18 (World 2) PhantomLibrary (Z 7360..7720)
		{ Ghost = "PageSprite", Center = Vector3.new(0, 0, 7445), Radius = 30, Count = 6 },
		{ Ghost = "PageSprite", Center = Vector3.new(-82, 0, 7480), Radius = 24, Count = 4 },
		{ Ghost = "InkblotPhantom", Center = Vector3.new(75, 0, 7540), Radius = 26, Count = 4 },
		{ Ghost = "InkblotPhantom", Center = Vector3.new(-62, 0, 7600), Radius = 24, Count = 4 },
		{ Ghost = "GrandGrimoire", Center = Vector3.new(0, 0, 7665), Radius = 26, Count = 1 },
		-- ZONE 19 (World 2) PumpkinFarm (Z 7720..8080)
		{ Ghost = "CornWisp", Center = Vector3.new(0, 0, 7805), Radius = 30, Count = 6 },
		{ Ghost = "CornWisp", Center = Vector3.new(-82, 0, 7840), Radius = 24, Count = 4 },
		{ Ghost = "HayrideHaunt", Center = Vector3.new(75, 0, 7900), Radius = 26, Count = 4 },
		{ Ghost = "HayrideHaunt", Center = Vector3.new(-62, 0, 7960), Radius = 24, Count = 4 },
		{ Ghost = "ScarecrowKing", Center = Vector3.new(0, 0, 8025), Radius = 26, Count = 1 },
		-- ZONE 20 (World 2) Glowshroom (Z 8080..8440)
		{ Ghost = "SporeWisp", Center = Vector3.new(0, 0, 8165), Radius = 30, Count = 6 },
		{ Ghost = "SporeWisp", Center = Vector3.new(-82, 0, 8200), Radius = 24, Count = 4 },
		{ Ghost = "MossyPhantom", Center = Vector3.new(75, 0, 8260), Radius = 26, Count = 4 },
		{ Ghost = "MossyPhantom", Center = Vector3.new(-62, 0, 8320), Radius = 24, Count = 4 },
		{ Ghost = "MyceliumMonarch", Center = Vector3.new(0, 0, 8385), Radius = 26, Count = 1 },
		-- ZONE 21 (World 2) WaterPark (Z 8440..8800)
		{ Ghost = "SplashSprite", Center = Vector3.new(0, 0, 8525), Radius = 30, Count = 6 },
		{ Ghost = "SplashSprite", Center = Vector3.new(-82, 0, 8560), Radius = 24, Count = 4 },
		{ Ghost = "LazyRiverPhantom", Center = Vector3.new(75, 0, 8620), Radius = 26, Count = 4 },
		{ Ghost = "LazyRiverPhantom", Center = Vector3.new(-62, 0, 8680), Radius = 24, Count = 4 },
		{ Ghost = "KingCannonball", Center = Vector3.new(0, 0, 8745), Radius = 26, Count = 1 },
		-- ZONE 22 (World 2) MirrorMaze (Z 8800..9160)
		{ Ghost = "GlintSpirit", Center = Vector3.new(0, 0, 8885), Radius = 30, Count = 6 },
		{ Ghost = "GlintSpirit", Center = Vector3.new(-82, 0, 8920), Radius = 24, Count = 4 },
		{ Ghost = "CopycatPhantom", Center = Vector3.new(75, 0, 8980), Radius = 26, Count = 4 },
		{ Ghost = "CopycatPhantom", Center = Vector3.new(-62, 0, 9040), Radius = 24, Count = 4 },
		{ Ghost = "QueenOfReflections", Center = Vector3.new(0, 0, 9105), Radius = 26, Count = 1 },
		-- ZONE 23 (World 2) ShoppingMall (Z 9160..9520)
		{ Ghost = "ShopperSpirit", Center = Vector3.new(0, 0, 9245), Radius = 30, Count = 6 },
		{ Ghost = "ShopperSpirit", Center = Vector3.new(-82, 0, 9280), Radius = 24, Count = 4 },
		{ Ghost = "MannequinPhantom", Center = Vector3.new(75, 0, 9340), Radius = 26, Count = 4 },
		{ Ghost = "MannequinPhantom", Center = Vector3.new(-62, 0, 9400), Radius = 24, Count = 4 },
		{ Ghost = "FoodCourtQueen", Center = Vector3.new(0, 0, 9465), Radius = 26, Count = 1 },
		-- ZONE 24 (World 2) GhostSubway (Z 9520..9880)
		{ Ghost = "CommuterSpecter", Center = Vector3.new(0, 0, 9605), Radius = 30, Count = 6 },
		{ Ghost = "CommuterSpecter", Center = Vector3.new(-82, 0, 9640), Radius = 24, Count = 4 },
		{ Ghost = "TicketPhantom", Center = Vector3.new(75, 0, 9700), Radius = 26, Count = 4 },
		{ Ghost = "TicketPhantom", Center = Vector3.new(-62, 0, 9760), Radius = 24, Count = 4 },
		{ Ghost = "PhantomExpress", Center = Vector3.new(0, 0, 9825), Radius = 26, Count = 1 },
		-- ZONE 25 (World 2) DinoMuseum (Z 9880..10240)
		{ Ghost = "FossilFlitter", Center = Vector3.new(0, 0, 9965), Radius = 30, Count = 6 },
		{ Ghost = "FossilFlitter", Center = Vector3.new(-82, 0, 10000), Radius = 24, Count = 4 },
		{ Ghost = "RaptorSpecter", Center = Vector3.new(75, 0, 10060), Radius = 26, Count = 4 },
		{ Ghost = "RaptorSpecter", Center = Vector3.new(-62, 0, 10120), Radius = 24, Count = 4 },
		{ Ghost = "BoneTyrant", Center = Vector3.new(0, 0, 10185), Radius = 26, Count = 1 },
		-- ZONE 26 (World 2) Stadium (Z 10240..10600)
		{ Ghost = "CheerSpirit", Center = Vector3.new(0, 0, 10325), Radius = 30, Count = 6 },
		{ Ghost = "CheerSpirit", Center = Vector3.new(-82, 0, 10360), Radius = 24, Count = 4 },
		{ Ghost = "FoamFingerPhantom", Center = Vector3.new(75, 0, 10420), Radius = 26, Count = 4 },
		{ Ghost = "FoamFingerPhantom", Center = Vector3.new(-62, 0, 10480), Radius = 24, Count = 4 },
		{ Ghost = "PhantomScoreboard", Center = Vector3.new(0, 0, 10545), Radius = 26, Count = 1 },
		-- ZONE 27 (World 2) NeonCity (Z 10600..10960)
		{ Ghost = "NeonSprite", Center = Vector3.new(0, 0, 10685), Radius = 30, Count = 6 },
		{ Ghost = "NeonSprite", Center = Vector3.new(-82, 0, 10720), Radius = 24, Count = 4 },
		{ Ghost = "GraffitiPhantom", Center = Vector3.new(75, 0, 10780), Radius = 26, Count = 4 },
		{ Ghost = "GraffitiPhantom", Center = Vector3.new(-62, 0, 10840), Radius = 24, Count = 4 },
		{ Ghost = "BillboardBoss", Center = Vector3.new(0, 0, 10905), Radius = 26, Count = 1 },
		-- ZONE 28 (World 2) GiantsKitchen (Z 10960..11320)
		{ Ghost = "CrumbSprite", Center = Vector3.new(0, 0, 11045), Radius = 30, Count = 6 },
		{ Ghost = "CrumbSprite", Center = Vector3.new(-82, 0, 11080), Radius = 24, Count = 4 },
		{ Ghost = "TeacupPhantom", Center = Vector3.new(75, 0, 11140), Radius = 26, Count = 4 },
		{ Ghost = "TeacupPhantom", Center = Vector3.new(-62, 0, 11200), Radius = 24, Count = 4 },
		{ Ghost = "BigCheese", Center = Vector3.new(0, 0, 11265), Radius = 26, Count = 1 },
		-- ZONE 29 (World 2) CyberArcade (Z 11320..11680)
		{ Ghost = "PixelPhantom", Center = Vector3.new(0, 0, 11405), Radius = 30, Count = 6 },
		{ Ghost = "PixelPhantom", Center = Vector3.new(-82, 0, 11440), Radius = 24, Count = 4 },
		{ Ghost = "GlitchGremlin", Center = Vector3.new(75, 0, 11500), Radius = 26, Count = 4 },
		{ Ghost = "GlitchGremlin", Center = Vector3.new(-62, 0, 11560), Radius = 24, Count = 4 },
		{ Ghost = "GameOverGoliath", Center = Vector3.new(0, 0, 11625), Radius = 26, Count = 1 },
		-- ZONE 30 (World 2) StormIslands (Z 11680..12040)
		{ Ghost = "BreezeSpirit", Center = Vector3.new(0, 0, 11765), Radius = 30, Count = 6 },
		{ Ghost = "BreezeSpirit", Center = Vector3.new(-82, 0, 11800), Radius = 24, Count = 4 },
		{ Ghost = "ThundercloudPhantom", Center = Vector3.new(75, 0, 11860), Radius = 26, Count = 4 },
		{ Ghost = "ThundercloudPhantom", Center = Vector3.new(-62, 0, 11920), Radius = 24, Count = 4 },
		{ Ghost = "TempestRoc", Center = Vector3.new(0, 0, 11985), Radius = 26, Count = 1 },
		-- ZONE 31 (World 2) MoonBase (Z 12040..12400)
		{ Ghost = "MoondustSpirit", Center = Vector3.new(0, 0, 12125), Radius = 30, Count = 6 },
		{ Ghost = "MoondustSpirit", Center = Vector3.new(-82, 0, 12160), Radius = 24, Count = 4 },
		{ Ghost = "AstroPhantom", Center = Vector3.new(75, 0, 12220), Radius = 26, Count = 4 },
		{ Ghost = "AstroPhantom", Center = Vector3.new(-62, 0, 12280), Radius = 24, Count = 4 },
		{ Ghost = "SaucerOverseer", Center = Vector3.new(0, 0, 12345), Radius = 26, Count = 1 },
		-- ZONE 32 (World 2) VoidThrone (Z 12400..12880)
		{ Ghost = "VoidMote", Center = Vector3.new(0, 0, 12485), Radius = 30, Count = 6 },
		{ Ghost = "VoidMote", Center = Vector3.new(-82, 0, 12520), Radius = 24, Count = 4 },
		{ Ghost = "RiftPhantom", Center = Vector3.new(75, 0, 12580), Radius = 26, Count = 4 },
		{ Ghost = "RiftPhantom", Center = Vector3.new(-62, 0, 12640), Radius = 24, Count = 4 },
		{ Ghost = "VoidHerald", Center = Vector3.new(0, 0, 12640), Radius = 26, Count = 1 }, -- Void Emperor arena at (0, 12760) r60 beyond it
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

--==================================================================
-- WHAT'S NEW popup: shown once per Version to returning players when they join (players who
-- haven't finished the tutorial skip it). Bump Version and rewrite Lines for each update.
Config.UpdateNotes = {
	Version = "2.0",
	Title = "WORLD 2 IS HERE!",
	Lines = {
		"🌀 WORLD 2: THE OTHER SIDE! Beat THE GHOST KING to open the portal",
		"🏮 16 new areas, from Lantern Market to The Void Throne",
		"🧑‍🚀 128 new hunters + 16 new Exclusives",
		"👻 48 new ghosts and 16 new crates",
		"👑 THE VOID EMPEROR: a huge team boss fight in The Void Throne",
		"🌍 WORLD 1 / WORLD 2 tabs in the Worlds menu",
		"📱 Bigger, easier menus on phones",
	},
}

--==================================================================
-- THE VOID EMPEROR: World 2's final boss (VoidEmperorService, Logic/VoidEmperor). A team fight
-- in the Void Throne arena. No Robux path: nothing sold changes the fight, and its rewards
-- (Ectoplasm with the player's own multiplier, a free Void Crate open) are earned only by
-- taking part. No Spirit Shards here (those only come from the Boss Tower).
--==================================================================
Config.VoidEmperor = {
	Ghost = "VoidEmperor",
	Pylon = "VoidPylon", -- the phase-1 pylons (ghost entry added below)
	Zone = "VoidThrone",
	Center = Vector3.new(0, 0, 12760), -- arena centre (ground top Y = 0)
	Radius = 60, -- players inside this ring take part / set the boss Spirit
	PylonRadius = 45, -- fallback pylon spots (map parts VoidPylonSpot1..4 win when present)
	LightRadius = 30, -- fallback light circle spots (map parts VoidLightSpot1..4)
	-- when the portal opens: every IntervalSeconds, after HeraldKills Void Herald kills on the
	-- server, or when GatherPlayers wait in the ring (at most once per GatherCooldown)
	FirstDelay = 300,
	IntervalSeconds = 1200,
	HeraldKills = 50,
	GatherPlayers = 4,
	GatherCooldown = 300,
	JoinSeconds = 60, -- join window: players in the ring when it ends start the fight
	TimeLimit = 480,
	-- Spirit = SpiritSeconds * max(sum(min(crew power, PowerCap)), MinCrews * PowerRef)
	SpiritSeconds = 150,
	MinCrews = 4,
	PowerRef = 1.56e24, -- about one full crew of 8 area-32 (Void Throne) Legendaries
	PowerCap = 3.12e24, -- one huge crew can't make the boss unbeatable for everyone else
	Walls = { 0.66, 0.33 }, -- phase walls (share of Spirit left)
	-- phase 1: THE CROWN
	PylonShare = 0.04, -- each pylon's Spirit (share of the boss Spirit)
	ShieldTaken = 0.1, -- damage taken while any pylon stands
	KneelSeconds = 15,
	KneelTaken = 2,
	PylonReturnSeconds = 90, -- pylons come back if the wall isn't reached this long after they fell
	-- phase 2: THE SPLIT
	Copies = 3,
	CopyOrbit = 36, -- studs from the centre
	CrownHopSeconds = 12,
	CrownTellSeconds = 2,
	MirrorSeconds = 10, -- tapping a copy without the crown: your hunters do nothing this long
	MirrorGrace = 2.5, -- a copy that lost the crown this recently doesn't mirror yet
	-- phase 3: THE LAST LIGHT
	Circles = 4,
	CircleRadius = 8,
	CircleMoveSeconds = 30,
	FinalShare = 0.05, -- last 5%: one big circle in the centre
	FinalRadius = 16,
	-- rewards per participant: RewardBase * ZoneMultiplier[Void Throne's Order] * clamp(share * participants,
	-- MinShare, MaxShare) * the player's Ectoplasm multiplier; a timeout pays FailShare of it
	RewardBase = 900,
	RewardZone = (Config.ZoneById.VoidThrone :: ZoneDef).Order, -- the final area (32)
	MinShare = 0.35,
	MaxShare = 2.5,
	FailShare = 0.25,
	Crate = "Void", -- one free open on a win
	MinContribution = 0.01, -- share of the Spirit dealt to count as a participant...
	MinSeconds = 8, -- ...or this many seconds of your own crew's power
	Record = "VoidEmperor", -- EventPlay key: S = wins, G = beaten at least once
}

-- Phase-1 pylon: a ghost entry so the normal tap / crew / retaliation paths work on it. Its
-- Spirit is set at spawn; it pays nothing itself (the fight pays at the end).
Config.Ghosts.VoidPylon = {
	Id = "VoidPylon", Name = "VOID PYLON", Zone = "VoidThrone",
	Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 2.6, Hover = 9, Speed = 1, Wander = 8,
	Kind = "WorldBoss", Color = Color3.fromRGB(20, 15, 35), Glow = Color3.fromRGB(255, 255, 255), Style = "Rift",
}

return Config
