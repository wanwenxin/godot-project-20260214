extends RefCounted
class_name MagicDefs

# 魔法定义：魔力消耗、威力、元素、图标、脚本
const MAGIC_POOL := [
	{
		"id": "fire_bolt",
		"name_key": "magic.fire_bolt.name",
		"desc_key": "magic.fire_bolt.desc",
		"mana_cost": 8,
		"power": 25,
		"element": "fire",
		"icon_path": "res://assets/magic/icon_fire.png",
		"script_path": "res://scripts/magic/fire_bolt.gd",
		"base_cost": 6
	},
	{
		"id": "ice_shard",
		"name_key": "magic.ice_shard.name",
		"desc_key": "magic.ice_shard.desc",
		"mana_cost": 10,
		"power": 20,
		"element": "ice",
		"icon_path": "res://assets/magic/icon_ice.png",
		"script_path": "res://scripts/magic/ice_shard.gd",
		"base_cost": 7
	},
]

static func get_magic_by_id(magic_id: String) -> Dictionary:
	for m in MAGIC_POOL:
		if str(m.get("id", "")) == magic_id:
			return m.duplicate(true)
	return {}
