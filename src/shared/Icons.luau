--!strict
-- Image icons (uploaded Roblox image ids). Until an id is filled in, the UI shows the emoji
-- it always had. Prompts to make these with an image generator: icon-prompts/.
-- Fill in as "rbxassetid://123456789".
local Icons = {}

Icons.Images = {
	menu_hunters = "rbxassetid://78038914324289",
	menu_worlds = "rbxassetid://84155230350180",
	menu_index = "rbxassetid://84366853615865",
	menu_upgrades = "rbxassetid://70876962926112",
	menu_shop = "rbxassetid://98986991699611",
	menu_daily = "rbxassetid://103331064081699",
	menu_settings = "rbxassetid://99239809195829",
	ecto = "rbxassetid://115742626417014",
	ecto_pile = "rbxassetid://104426184562660",
	power = "rbxassetid://105049502428109",
	up_pickup = "rbxassetid://127315035174085",
	up_ectobonus = "rbxassetid://80994628868726",
	up_speed = "rbxassetid://114316330748926",
	boost_ecto2x = "rbxassetid://114165384019879",
	boost_luck = "rbxassetid://119197782340566",
	shop_ecto_sack = "rbxassetid://74644638237754",
	shop_ecto_barrel = "rbxassetid://79064911417612",
	pass_slots = "rbxassetid://128224514797307",
	pass_ecto2x = "rbxassetid://133106155988584",
	pass_autoattack = "rbxassetid://107521431713061",
	zone_neighborhood = "rbxassetid://84354776363532",
	zone_cemetery = "rbxassetid://76424630974120",
	zone_school = "rbxassetid://100060199672041",
	zone_carnival = "rbxassetid://137903904817765",
	zone_hospital = "rbxassetid://125645806682932",
	zone_harbor = "rbxassetid://73257751418518",
	zone_castle = "rbxassetid://89579637417355",
	zone_spiritrealm = "rbxassetid://84426649388991",
	lock = "rbxassetid://75882408514306",
	crate_beginner = "rbxassetid://127133657811926",
	crate_haunted = "rbxassetid://96530620594896",
	crate_elite = "rbxassetid://122309182591652",
	crate_carnival = "rbxassetid://117478834387129",
	crate_medical = "rbxassetid://88751354514047",
	crate_sailor = "rbxassetid://89395681412353",
	crate_royal = "rbxassetid://109906150288392",
	crate_spirit = "rbxassetid://119576764620364",
	pass_lucky = "rbxassetid://103371053439761",
	pass_triple = "rbxassetid://132615388115540",
	pass_magnet = "rbxassetid://81446885451577",
	pass_vip = "rbxassetid://109454873320281",
	pass_storage = "rbxassetid://71346557862972",
	pass_rainbow = "rbxassetid://78785426323971",
	pass_trail = "rbxassetid://125533246361742",
	prod_skip_area = "rbxassetid://127875955780964",
	prod_exclusive_crate = "rbxassetid://129820612053146",
	prod_server_luck = "rbxassetid://112653054458293",
	prod_summon_event = "rbxassetid://138523085431067",
	zone_swamp = "rbxassetid://74627746786803",
	zone_frost = "rbxassetid://104917464524216",
	zone_tomb = "rbxassetid://118834990826697",
	zone_toyfactory = "rbxassetid://135682620798565",
	zone_sunken = "rbxassetid://132688241050624",
	zone_clockwork = "rbxassetid://79409356844090",
	zone_inferno = "rbxassetid://134443302381366",
	zone_throne = "rbxassetid://115102923793233",
	crate_swamp = "rbxassetid://97390932291893",
	crate_frost = "rbxassetid://130609388149781",
	crate_tomb = "rbxassetid://75613624704097",
	crate_toy = "rbxassetid://130101785717560",
	crate_sunken = "rbxassetid://129584966936667",
	crate_clock = "rbxassetid://134418542919641",
	crate_inferno = "rbxassetid://139448320964013",
	crate_throne = "rbxassetid://120485989017113",
	crate_exclusive = "rbxassetid://100579734342964",
} :: { [string]: string? }

-- Which icon key each piece of content uses.
Icons.ForUpgrade = { PickupRadius = "up_pickup", EctoBonus = "up_ectobonus", MoveSpeed = "up_speed" } :: { [string]: string }
Icons.ForProduct = {
	Ecto1 = "shop_ecto_sack",
	Ecto2 = "shop_ecto_barrel",
	Luck30 = "boost_luck",
	Ecto30 = "boost_ecto2x",
	ExtraSlots = "pass_slots",
	DoubleEcto = "pass_ecto2x",
	AutoAttack = "pass_autoattack",
	LuckyHunter = "pass_lucky",
	TripleOpen = "pass_triple",
	SuperMagnet = "pass_magnet",
	VIP = "pass_vip",
	Storage = "pass_storage",
	RainbowBeams = "pass_rainbow",
	SparkleTrail = "pass_trail",
	SkipArea = "prod_skip_area",
	ExclusiveCrate = "prod_exclusive_crate",
	ServerLuck = "prod_server_luck",
	SummonEvent = "prod_summon_event",
	PermanentSkip = "pass_permskip",
	AutoOpen = "pass_autoopen",
	SingleSkip = "prod_singleskip",
} :: { [string]: string }

-- crate id -> icon key
Icons.ForCrate = {
	Beginner = "crate_beginner",
	Haunted = "crate_haunted",
	Elite = "crate_elite",
	Carnival = "crate_carnival",
	Medical = "crate_medical",
	Sailor = "crate_sailor",
	Royal = "crate_royal",
	SpiritRealm = "crate_spirit",
	Bog = "crate_swamp",
	Frost = "crate_frost",
	Tomb = "crate_tomb",
	Toy = "crate_toy",
	Sunken = "crate_sunken",
	Clockwork = "crate_clock",
	Inferno = "crate_inferno",
	Throne = "crate_throne",
	Exclusive = "crate_exclusive",
} :: { [string]: string }

function Icons.ForZone(zoneId: string): string
	return "zone_" .. string.lower(zoneId)
end

function Icons.Get(key: string?): string?
	if not key then
		return nil
	end
	return Icons.Images[key]
end

return Icons
