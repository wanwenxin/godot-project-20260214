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
		"id": "dagger",
		"type": "melee",
		"script_path": "res://scripts/weapons/melee/weapon_dagger.gd",
		"name_key": "weapon.dagger.name",
		"desc_key": "weapon.dagger.desc",
		"cost": 4,
		"color": Color(0.60, 0.65, 0.75, 1.0),
		"stats": {
			"damage": 10,
			"cooldown": 0.28,
			"range": 68.0,
			"touch_interval": 0.25,
			"swing_duration": 0.12,
			"swing_degrees": 30.0,
			"swing_reach": 18.0,
			"hitbox_radius": 12.0
		}
	},
	{
		"id": "spear",
		"type": "melee",
		"script_path": "res://scripts/weapons/melee/weapon_spear.gd",
		"name_key": "weapon.spear.name",
		"desc_key": "weapon.spear.desc",
		"cost": 7,
		"color": Color(0.55, 0.60, 0.70, 1.0),
		"stats": {
			"damage": 18,
			"cooldown": 0.55,
			"range": 95.0,
			"touch_interval": 0.42,
			"swing_duration": 0.22,
			"swing_degrees": 40.0,
			"swing_reach": 34.0,
			"hitbox_radius": 14.0
		}
	},
	{
		"id": "chainsaw",
		"type": "melee",
		"script_path": "res://scripts/weapons/melee/weapon_chainsaw.gd",
		"name_key": "weapon.chainsaw.name",
		"desc_key": "weapon.chainsaw.desc",
		"cost": 12,
		"color": Color(0.35, 0.38, 0.40, 1.0),
		"stats": {
			"damage": 6,
			"cooldown": 0.85,
			"range": 72.0,
			"touch_interval": 0.15,
			"swing_duration": 0.20,
			"swing_degrees": 360.0,
			"swing_reach": 24.0,
			"hitbox_radius": 16.0,
			"spin_duration": 0.6
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
	},
	{
		"id": "sniper",
		"type": "ranged",
		"script_path": "res://scripts/weapons/ranged/weapon_sniper.gd",
		"name_key": "weapon.sniper.name",
		"desc_key": "weapon.sniper.desc",
		"cost": 14,
		"color": Color(0.45, 0.50, 0.55, 1.0),
		"bullet_type": "rifle",
		"stats": {"damage": 28, "cooldown": 0.95, "range": 2200.0, "bullet_speed": 900.0, "pellet_count": 1, "spread_degrees": 0.0, "bullet_pierce": 2}
	},
	{
		"id": "orb_wand",
		"type": "ranged",
		"script_path": "res://scripts/weapons/ranged/weapon_orb_wand.gd",
		"name_key": "weapon.orb_wand.name",
		"desc_key": "weapon.orb_wand.desc",
		"cost": 8,
		"color": Color(0.95, 0.70, 0.35, 1.0),
		"bullet_type": "orb",
		"stats": {"damage": 11, "cooldown": 0.38, "range": 800.0, "bullet_speed": 420.0, "pellet_count": 1, "spread_degrees": 0.0, "bullet_pierce": 0}
	}
]
