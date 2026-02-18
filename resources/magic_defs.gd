extends RefCounted
class_name MagicDefs

# 魔法定义：仅保留威力、消耗、冷却；范围、效果、元素由词条决定。
# 每魔法含 range_affix_id、effect_affix_id、element_affix_id 各 1 个。
const MAGIC_POOL := [
	{
		"id": "fire_bolt",
		"name_key": "magic.fire_bolt.name",
		"desc_key": "magic.fire_bolt.desc",
		"mana_cost": 8,
		"power": 25,
		"cooldown": 1.0,
		"icon_path": "res://assets/magic/icon_fire.png",
		"script_path": "res://scripts/magic/fire_bolt.gd",
		"base_cost": 6,
		"range_affix_id": "magic_range_line",
		"effect_affix_id": "magic_effect_instant",
		"element_affix_id": "magic_element_fire"
	},
	{
		"id": "ice_shard",
		"name_key": "magic.ice_shard.name",
		"desc_key": "magic.ice_shard.desc",
		"mana_cost": 10,
		"power": 20,
		"cooldown": 1.2,
		"icon_path": "res://assets/magic/icon_ice.png",
		"script_path": "res://scripts/magic/ice_shard.gd",
		"base_cost": 7,
		"range_affix_id": "magic_range_line",
		"effect_affix_id": "magic_effect_instant",
		"element_affix_id": "magic_element_ice"
	},
	{
		"id": "shockwave",
		"name_key": "magic.shockwave.name",
		"desc_key": "magic.shockwave.desc",
		"mana_cost": 15,
		"power": 40,
		"cooldown": 3.0,
		"icon_path": "res://assets/magic/icon_fire.png",
		"script_path": "res://scripts/magic/area_shockwave.gd",
		"base_cost": 10,
		"range_affix_id": "magic_range_mouse_circle",
		"effect_affix_id": "magic_effect_instant",
		"element_affix_id": "magic_element_physical"
	},
	{
		"id": "burn_zone",
		"name_key": "magic.burn_zone.name",
		"desc_key": "magic.burn_zone.desc",
		"mana_cost": 20,
		"power": 15,
		"cooldown": 5.0,
		"icon_path": "res://assets/magic/icon_fire.png",
		"script_path": "res://scripts/magic/area_burn.gd",
		"base_cost": 12,
		"range_affix_id": "magic_range_mouse_circle",
		"effect_affix_id": "magic_effect_dot",
		"element_affix_id": "magic_element_fire"
	},
]


static func get_magic_by_id(magic_id: String) -> Dictionary:
	for m in MAGIC_POOL:
		if str(m.get("id", "")) == magic_id:
			return m.duplicate(true)
	return {}
