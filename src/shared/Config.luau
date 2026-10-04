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
	},
} :: { ZoneDef }

Config.ZoneById = {} :: { [string]: ZoneDef }
for _, z in Config.Zones do
	Config.ZoneById[z.Id] = z
end

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
	-- BOSS TOWER (Spirit and hit are scaled per room by Config.Tower at spawn time)
	TowerWarden = {
		Id = "TowerWarden", Name = "TOWER WARDEN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4, Hover = 9, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(120, 110, 200), Glow = Color3.fromRGB(110, 255, 160), Style = "Warden",
	},
	TowerJester = {
		Id = "TowerJester", Name = "TOWER JESTER", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.3, Hover = 9, Speed = 3.5, Wander = 3.5,
		Kind = "Tower", Color = Color3.fromRGB(230, 70, 80), Glow = Color3.fromRGB(255, 210, 80), Style = "Ringmaster",
	},
	TowerBaron = {
		Id = "TowerBaron", Name = "TOWER BARON", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 4.6, Hover = 10, Speed = 3, Wander = 4,
		Kind = "Tower", Color = Color3.fromRGB(120, 140, 200), Glow = Color3.fromRGB(110, 255, 160), Style = "King",
	},
	TowerTitan = {
		Id = "TowerTitan", Name = "TOWER TITAN", Zone = "Neighborhood",
		Spirit = 1000, Reward = 0, Drops = 0, Respawn = 0, Scale = 5, Hover = 10, Speed = 2.5, Wander = 5,
		Kind = "Tower", Color = Color3.fromRGB(170, 140, 255), Glow = Color3.fromRGB(90, 255, 230), Style = "Overlord",
	},
	-- EVENT (scaled at spawn time by Config.Event)
	GiantPoltergeist = {
		Id = "GiantPoltergeist", Name = "GIANT POLTERGEIST", Zone = "Neighborhood",
		Spirit = 6000, Reward = 0, Drops = 0, Respawn = 0, Scale = 6, Hover = 14, Speed = 4, Wander = 5,
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
			{ Hunter = "RookieHunter", Weight = 25 }, -- Common 50% (split 2 ways)
			{ Hunter = "BowBelle", Weight = 25 }, -- Common 50% (split 2 ways)
			{ Hunter = "ParanormalIntern", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "GhostInvestigator", Weight = 10 }, -- Rare 10%
			{ Hunter = "SpectralSpecialist", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "MoonlightMedium", Weight = 1 }, -- Mythic 1%
			{ Hunter = "NightWatcher", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "CaptainBoo", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Haunted = {
		Id = "Haunted", Name = "HAUNTED HUNTER CRATE", Zone = "Cemetery", Price = 600,
		Color = C(110, 80, 200), Trim = C(90, 255, 180), Style = "Haunted",
		Pool = {
			{ Hunter = "GraveScout", Weight = 50 }, -- Common 50%
			{ Hunter = "CryptInvestigator", Weight = 17.5 }, -- Uncommon 35% (split 2 ways)
			{ Hunter = "LilMoonWitch", Weight = 17.5 }, -- Uncommon 35% (split 2 ways)
			{ Hunter = "SpiritWarden", Weight = 10 }, -- Rare 10%
			{ Hunter = "PhantomExorcist", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "GravelightOracle", Weight = 1 }, -- Mythic 1%
			{ Hunter = "ReapersApprentice", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "PetalChomper", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Elite = {
		Id = "Elite", Name = "ELITE HUNTER CRATE", Zone = "School", Price = 5000,
		Color = C(40, 30, 70), Trim = C(220, 120, 255), Style = "Elite",
		Pool = {
			{ Hunter = "SchoolInvestigator", Weight = 50 }, -- Common 50%
			{ Hunter = "ParanormalProfessor", Weight = 17.5 }, -- Uncommon 35% (split 2 ways)
			{ Hunter = "GloomyGus", Weight = 17.5 }, -- Uncommon 35% (split 2 ways)
			{ Hunter = "EliteContainmentAgent", Weight = 10 }, -- Rare 10%
			{ Hunter = "VoidHunter", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "SpiritValedictorian", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheSubstitute", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "CelestiaMoonwitch", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Carnival = {
		Id = "Carnival", Name = "CARNIVAL HUNTER CRATE", Zone = "Carnival", Price = 40000,
		Color = C(230, 60, 70), Trim = C(255, 210, 70), Style = "Carnival",
		Pool = {
			{ Hunter = "CarnivalScout", Weight = 50 }, -- Common 50%
			{ Hunter = "ParanormalPerformer", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "SpectralRingmaster", Weight = 5 }, -- Rare 10% (split 2 ways)
			{ Hunter = "HeartlightHealer", Weight = 5 }, -- Rare 10% (split 2 ways)
			{ Hunter = "PhantomTamer", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "GrandIllusionist", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheLastClown", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "PumpkinKingJack", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Medical = {
		Id = "Medical", Name = "PARANORMAL MEDICAL CRATE", Zone = "Hospital", Price = 400000,
		Color = C(235, 240, 250), Trim = C(110, 200, 255), Style = "Medical",
		Pool = {
			{ Hunter = "MedicalInvestigator", Weight = 50 }, -- Common 50%
			{ Hunter = "SpiritMedic", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "ParanormalDoctor", Weight = 10 }, -- Rare 10%
			{ Hunter = "SpectralSurgeon", Weight = 1.75 }, -- Legendary 3.5% (split 2 ways)
			{ Hunter = "StarlitHexPrincess", Weight = 1.75 }, -- Legendary 3.5% (split 2 ways)
			{ Hunter = "ChiefOfSpiritMedicine", Weight = 1 }, -- Mythic 1%
			{ Hunter = "NightShiftNurse", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "DoctorMiracle", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Sailor = {
		Id = "Sailor", Name = "SPECTRAL SAILOR CRATE", Zone = "Harbor", Price = 3500000,
		Color = C(140, 95, 55), Trim = C(80, 230, 220), Style = "Sailor",
		Pool = {
			{ Hunter = "HarborHunter", Weight = 50 }, -- Common 50%
			{ Hunter = "ParanormalSailor", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "SpectralPirateHunter", Weight = 10 }, -- Rare 10%
			{ Hunter = "GhostCaptainHunter", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "KrakenTamer", Weight = 1 }, -- Mythic 1%
			{ Hunter = "FlyingDutchman", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "SirenSeraphina", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Royal = {
		Id = "Royal", Name = "ROYAL HUNTER CRATE", Zone = "Castle", Price = 22000000,
		Color = C(70, 40, 120), Trim = C(255, 200, 70), Style = "Royal",
		Pool = {
			{ Hunter = "CastleInvestigator", Weight = 50 }, -- Common 50%
			{ Hunter = "SpiritKnight", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "RoyalExorcist", Weight = 10 }, -- Rare 10%
			{ Hunter = "PhantomChampion", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "PhantomMonarch", Weight = 0.5 }, -- Mythic 1% (split 2 ways)
			{ Hunter = "PumpkinKnight", Weight = 0.5 }, -- Mythic 1% (split 2 ways)
			{ Hunter = "HeadlessKnight", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "CountBatula", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	SpiritRealm = {
		Id = "SpiritRealm", Name = "SPIRIT REALM CRATE", Zone = "SpiritRealm", Price = 130000000,
		Color = C(40, 35, 80), Trim = C(110, 240, 255), Style = "Spirit",
		Pool = {
			{ Hunter = "RealmExplorer", Weight = 50 }, -- Common 50%
			{ Hunter = "SpiritWalker", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "VoidInvestigator", Weight = 10 }, -- Rare 10%
			{ Hunter = "CelestialGhostHunter", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "AstralGuardian", Weight = 1 }, -- Mythic 1%
			{ Hunter = "GhostHunterZero", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "StarfallValkyrie", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Bog = {
		Id = "Bog", Name = "BOG HUNTER CRATE", Zone = "Swamp", Price = 780000000,
		Color = C(90, 120, 60), Trim = C(170, 255, 120), Style = "Swamp",
		Pool = {
			{ Hunter = "SwampScout", Weight = 50 }, -- Common 50%
			{ Hunter = "BogTracker", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "MarshMystic", Weight = 10 }, -- Rare 10%
			{ Hunter = "FireflySage", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "FrogPrince", Weight = 1 }, -- Mythic 1%
			{ Hunter = "GatorKing", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "Bogzilla", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Frost = {
		Id = "Frost", Name = "FROSTBITE CRATE", Zone = "Frost", Price = 4680000000,
		Color = C(200, 230, 255), Trim = C(110, 200, 255), Style = "Frost",
		Pool = {
			{ Hunter = "SnowScout", Weight = 50 }, -- Common 50%
			{ Hunter = "IceClimber", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "FrostMage", Weight = 10 }, -- Rare 10%
			{ Hunter = "YetiWhisperer", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "AuroraKnight", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheAbominable", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "CrystaliaSnowQueen", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Tomb = {
		Id = "Tomb", Name = "PHARAOH CRATE", Zone = "Tomb", Price = 28100000000,
		Color = C(220, 180, 100), Trim = C(70, 200, 220), Style = "Tomb",
		Pool = {
			{ Hunter = "TombExplorer", Weight = 50 }, -- Common 50%
			{ Hunter = "ScarabSeeker", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "SandMage", Weight = 10 }, -- Rare 10%
			{ Hunter = "PharaohHunter", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "SunKeeper", Weight = 1 }, -- Mythic 1%
			{ Hunter = "GoldenMummy", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "JackalAvenger", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Toy = {
		Id = "Toy", Name = "TOY BOX CRATE", Zone = "ToyFactory", Price = 168000000000,
		Color = C(255, 120, 170), Trim = C(255, 220, 80), Style = "Toy",
		Pool = {
			{ Hunter = "ToyTinker", Weight = 50 }, -- Common 50%
			{ Hunter = "WindUpKnight", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "MarionetteMaster", Weight = 10 }, -- Rare 10%
			{ Hunter = "TeddyTitan", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "JackInTheBoxer", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheNutcracker", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "PrincessPomPom", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Sunken = {
		Id = "Sunken", Name = "SUNKEN TREASURE CRATE", Zone = "Sunken", Price = 1010000000000,
		Color = C(60, 140, 170), Trim = C(255, 220, 120), Style = "Sunken",
		Pool = {
			{ Hunter = "DeepDiver", Weight = 50 }, -- Common 50%
			{ Hunter = "CoralKeeper", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "TideCaller", Weight = 10 }, -- Rare 10%
			{ Hunter = "AtlanteanHunter", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "PearlSovereign", Weight = 1 }, -- Mythic 1%
			{ Hunter = "AbyssWalker", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "GlubbleTheDeepOne", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Clockwork = {
		Id = "Clockwork", Name = "CLOCKWORK CRATE", Zone = "Clockwork", Price = 6070000000000,
		Color = C(150, 110, 70), Trim = C(230, 200, 120), Style = "Clock",
		Pool = {
			{ Hunter = "GearScout", Weight = 50 }, -- Common 50%
			{ Hunter = "ClockTinker", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "ChronoMage", Weight = 10 }, -- Rare 10%
			{ Hunter = "TimeBender", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "SteamTitan", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheTimeless", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "TickTockTitaness", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Inferno = {
		Id = "Inferno", Name = "INFERNO CRATE", Zone = "Inferno", Price = 36400000000000,
		Color = C(80, 40, 40), Trim = C(255, 150, 60), Style = "Inferno",
		Pool = {
			{ Hunter = "EmberScout", Weight = 50 }, -- Common 50%
			{ Hunter = "LavaDiver", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "FireDancer", Weight = 10 }, -- Rare 10%
			{ Hunter = "PhoenixHunter", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "DragonCaller", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheEternalFlame", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "Scorchmaw", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Throne = {
		Id = "Throne", Name = "KING'S CRATE", Zone = "Throne", Price = 218000000000000,
		Color = C(250, 245, 255), Trim = C(255, 215, 90), Style = "Throne",
		Pool = {
			{ Hunter = "ThronePage", Weight = 50 }, -- Common 50%
			{ Hunter = "ShadowGuard", Weight = 35 }, -- Uncommon 35%
			{ Hunter = "CrownMage", Weight = 10 }, -- Rare 10%
			{ Hunter = "KingsChampion", Weight = 3.5 }, -- Legendary 3.5%
			{ Hunter = "EternalMonarch", Weight = 1 }, -- Mythic 1%
			{ Hunter = "TheFinalHunter", Weight = 0.4 }, -- Secret 0.4%
			{ Hunter = "SovereignSupreme", Weight = 0.1 }, -- Ultra 0.1%
		},
	},
	Exclusive = {
		Id = "Exclusive", Name = "EXCLUSIVE CRATE", Zone = "Neighborhood", Price = 0,
		Color = C(60, 40, 110), Trim = C(120, 240, 255), Style = "Spirit",
		Pool = {}, -- granted by the Robux product (Config.Exclusives), never rolled
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
--==================================================================
Config.Retaliation = {
	Interval = 2.5,
	Windup = 0.9,
	HPPerPower = 8,
	HitPerSpirit = { Normal = 0.04, MiniBoss = 0.06, Boss = 0.08, Event = 0.05 } :: { [string]: number },
	HitCap = { Normal = 0.25, MiniBoss = 0.4, Boss = 0.5, Event = 0.35 } :: { [string]: number },
	RegenDelay = 4, -- seconds without being hit before a hunter starts healing
	RegenPerSecond = 0.15, -- fraction of max HP per second
	RecoverySeconds = 120, -- knockout timer (configurable)
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
	Caps = { Power = 0.6, Ecto = 0.5, HP = 0.75, Recovery = 0.5 } :: { [string]: number },
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
-- teams climb further: HP = BaseHP * HPGrowth^(room-1) * FiveRoomBump^floor((room-1)/5),
-- but never less than party power * MinKillSeconds (strong teams can't one-shot rooms).
-- Boss hit = target hunter max HP * HitFraction(room), which grows more gently than health.
--==================================================================
Config.Tower = {
	MaxParty = 4,
	PadRadius = 9, -- players on the entrance pad join the party
	Countdown = 6, -- seconds after START before the party enters
	RoomSeconds = 180, -- a boss not beaten in time ends the run (rewards kept)
	BetweenRoomsSeconds = 30, -- time to choose CONTINUE / LEAVE before the run ends
	BaseHP = 180, -- room 1: ~9 s for a beginner crew (~20 power)
	HPGrowth = 1.15, -- +15% health per room
	FiveRoomBump = 1.25, -- extra x1.25 after every 5 rooms
	MinKillSeconds = 4,
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
	Bosses = { "TowerWarden", "TowerJester", "TowerBaron", "TowerTitan" }, -- cycles by room
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
	AdminUserIds = { 20194281 } :: { number }, -- ONLY these accounts may start it (live servers)
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
	ZoneMultiplier = { 1, 6, 30, 200, 1200, 7000, 40000, 220000, 1190000, 6430000, 34700000, 187000000, 1010000000, 5450000000, 29400000000, 159000000000 },
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
	{ Key = "Ecto1", Name = "SACK OF ECTOPLASM", Icon = "💚", Kind = "Ecto", Amount = 6000, ProductId = 3715910102, PriceLabel = "R$ 149" },
	{ Key = "Ecto2", Name = "BARREL OF ECTOPLASM", Icon = "🛢️", Kind = "Ecto", Amount = 12000, ProductId = 3715909987, PriceLabel = "R$ 199" },
	{ Key = "Luck30", Name = "30 MIN LUCK BOOST", Icon = "🍀", Kind = "Boost", Boost = "Luck", Seconds = 1800, ProductId = 3715910020, PriceLabel = "R$ 199" },
	{ Key = "Ecto30", Name = "30 MIN 2x ECTOPLASM", Icon = "⚡", Kind = "Boost", Boost = "Ecto", Seconds = 1800, ProductId = 3715910145, PriceLabel = "R$ 149" },
	{ Key = "SingleSkip", Name = "SINGLE CRATE SKIP", Icon = "⏩", Kind = "CrateSkip", ProductId = nil, PriceLabel = "R$ 10", Blurb = "Skip one crate animation" },
	{ Key = "SkipArea", Name = "UNLOCK NEXT AREA", Icon = "🔓", Kind = "SkipArea", Amount = 12000, ProductId = 3715915055, PriceLabel = "R$ 199", Blurb = "Opens your next locked area right now" },
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
	{ Key = "PermanentSkip", Name = "PERMANENT CRATE SKIP", Icon = "⏩", PassId = nil, PriceLabel = "R$ 129", Blurb = "Skip every crate animation, forever" },
	{ Key = "AutoOpen", Name = "AUTO OPEN", Icon = "🔁", PassId = nil, PriceLabel = "R$ 99", Blurb = "Crates open by themselves while you stand at them" },
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
Config.DevUserIds = { 20194281 } :: { number } -- kcdrewcarter (only these get dev tools live)

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
	TowerEntrance = { Pad = Vector3.new(-66, 0, -82) },
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
