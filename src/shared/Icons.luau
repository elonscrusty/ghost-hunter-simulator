--!strict
-- Image icons (uploaded Roblox image ids). Until an id is filled in, the UI shows the emoji
-- it always had. Prompts to make these with an image generator: docs/ICON_PROMPTS.md.
-- Fill in as "rbxassetid://123456789".
local Icons = {}

Icons.Images = {
	menu_hunters = nil :: string?,
	menu_worlds = nil :: string?,
	menu_index = nil :: string?,
	menu_upgrades = nil :: string?,
	menu_shop = nil :: string?,
	menu_daily = nil :: string?,
	menu_settings = nil :: string?,
	ecto = nil :: string?,
	power = nil :: string?,
	up_pickup = nil :: string?,
	up_ectobonus = nil :: string?,
	up_speed = nil :: string?,
	boost_ecto2x = nil :: string?,
	boost_luck = nil :: string?,
	shop_ecto_sack = nil :: string?,
	shop_ecto_barrel = nil :: string?,
	pass_slots = nil :: string?,
	pass_ecto2x = nil :: string?,
	pass_autoattack = nil :: string?,
	zone_neighborhood = nil :: string?,
	zone_cemetery = nil :: string?,
	zone_school = nil :: string?,
	zone_carnival = nil :: string?,
	zone_hospital = nil :: string?,
	zone_harbor = nil :: string?,
	zone_castle = nil :: string?,
	zone_spiritrealm = nil :: string?,
	lock = nil :: string?,
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
