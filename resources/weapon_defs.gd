# 武器统一配置：
# - 集中维护所有武器数值与脚本映射
# - 便于统一平衡与扩展新武器
extends RefCounted
class_name WeaponDefs

const WEAPON_DEFS := [
	{
		"id": "blade_short",
		"type": "melee",
		"script_path": "res://scripts/weapons/melee/weapon_blade_short.gd",
		"name_key": "weapon.blade_short.name",
		"desc_key": "weapon.blade_short.desc",
		"cost": 5,
		"color": Color(0.95, 0.30, 0.30, 1.0),
		"stats": {
			"damage": 14,
			"cooldown": 0.40,
			"range": 74.0,
			"touch_interval": 0.38,
			"swing_duration": 0.20,
			"swing_degrees": 110.0,
			"swing_reach": 22.0,
			"hitbox_radius": 14.0
		}
	},
	{
		"id": "hammer_heavy",
		"type": "melee",
		"script_path": "res://scripts/weapons/melee/weapon_hammer_heavy.gd",
		"name_key": "weapon.hammer_heavy.name",
		"desc_key": "weapon.hammer_heavy.desc",
		"cost": 8,
		"color": Color(0.90, 0.58, 0.24, 1.0),
		"stats": {
			"damage": 24,
			"cooldown": 0.72,
			"range": 86.0,
			"touch_interval": 0.50,
			"swing_duration": 0.24,
			"swing_degrees": 96.0,
			"swing_reach": 26.0,
			"hitbox_radius": 16.0
		}
	},
	{
		"id": "pistol_basic",
		"type": "ranged",
		"script_path": "res://scripts/weapons/ranged/weapon_pistol_basic.gd",
		"name_key": "weapon.pistol_basic.name",
		"desc_key": "weapon.pistol_basic.desc",
		"cost": 6,
		"color": Color(0.25, 0.80, 0.95, 1.0),
		"bullet_type": "pistol",
		"stats": {"damage": 8, "cooldown": 0.28, "range": 1200.0, "bullet_speed": 520.0, "pellet_count": 1, "spread_degrees": 0.0, "bullet_pierce": 0}
	},
	{
		"id": "shotgun_wide",
		"type": "ranged",
		"script_path": "res://scripts/weapons/ranged/weapon_shotgun_wide.gd",
		"name_key": "weapon.shotgun_wide.name",
		"desc_key": "weapon.shotgun_wide.desc",
		"cost": 9,
		"color": Color(0.50, 0.88, 0.30, 1.0),
		"bullet_type": "shotgun",
		"stats": {"damage": 6, "cooldown": 0.46, "range": 980.0, "bullet_speed": 460.0, "pellet_count": 3, "spread_degrees": 20.0, "bullet_pierce": 0}
	},
	{
		"id": "rifle_long",
		"type": "ranged",
		"script_path": "res://scripts/weapons/ranged/weapon_rifle_long.gd",
		"name_key": "weapon.rifle_long.name",
		"desc_key": "weapon.rifle_long.desc",
		"cost": 10,
		"color": Color(0.65, 0.66, 0.95, 1.0),
		"bullet_type": "rifle",
		"stats": {"damage": 12, "cooldown": 0.52, "range": 1400.0, "bullet_speed": 700.0, "pellet_count": 1, "spread_degrees": 0.0, "bullet_pierce": 1}
	},
	{
		"id": "wand_focus",
		"type": "ranged",
		"script_path": "res://scripts/weapons/ranged/weapon_wand_focus.gd",
		"name_key": "weapon.wand_focus.name",
		"desc_key": "weapon.wand_focus.desc",
		"cost": 7,
		"color": Color(0.88, 0.46, 0.95, 1.0),
		"bullet_type": "laser",
		"stats": {"damage": 9, "cooldown": 0.34, "range": 1180.0, "bullet_speed": 560.0, "pellet_count": 2, "spread_degrees": 10.0, "bullet_pierce": 0}
	}
]
