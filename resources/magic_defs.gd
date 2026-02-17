extends RefCounted
class_name MagicDefs

# 魔法定义：魔力消耗、威力、元素、图标、脚本
# cast_mode: "projectile" 弹道型 | "area" 区域型
# effect_type: "shockwave" 一次性伤害 | "burn" 持续伤害（仅 area）
# cooldown: 冷却时间（秒），施法速度会缩短
const MAGIC_POOL := [
	{
		"id": "fire_bolt",
		"name_key": "magic.fire_bolt.name",
		"desc_key": "magic.fire_bolt.desc",
		"mana_cost": 8,
		"power": 25,
		"element": "fire",
		"cast_mode": "projectile",
		"cooldown": 1.0,
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
		"cast_mode": "projectile",
		"cooldown": 1.2,
		"icon_path": "res://assets/magic/icon_ice.png",
		"script_path": "res://scripts/magic/ice_shard.gd",
		"base_cost": 7
	},
	{
		"id": "shockwave",
		"name_key": "magic.shockwave.name",
		"desc_key": "magic.shockwave.desc",
		"mana_cost": 15,
		"power": 40,
		"element": "physical",
		"cast_mode": "area",
		"effect_type": "shockwave",
		"area_radius": 100.0,
		"cooldown": 3.0,
		"icon_path": "res://assets/magic/icon_fire.png",
		"script_path": "res://scripts/magic/area_shockwave.gd",
		"base_cost": 10
	},
	{
		"id": "burn_zone",
		"name_key": "magic.burn_zone.name",
		"desc_key": "magic.burn_zone.desc",
		"mana_cost": 20,
		"power": 15,
		"element": "fire",
		"cast_mode": "area",
		"effect_type": "burn",
		"area_radius": 80.0,
		"cooldown": 5.0,
		"burn_duration": 4.0,
		"burn_damage_per_tick": 8,
		"burn_interval": 0.5,
		"icon_path": "res://assets/magic/icon_fire.png",
		"script_path": "res://scripts/magic/area_burn.gd",
		"base_cost": 12
	},
]

static func get_magic_by_id(magic_id: String) -> Dictionary:
	for m in MAGIC_POOL:
		if str(m.get("id", "")) == magic_id:
			return m.duplicate(true)
	return {}
