extends RefCounted
class_name EnemyDefs

# 敌人定义集中化：供图鉴等 UI 展示。
# 基础数值从各 enemy 场景提取，与 enemy_melee/ranged/tank/boss/aquatic/dasher 一致。

const ENEMY_DEFS := [
	{
		"id": "melee",
		"name_key": "enemy.melee.name",
		"desc_key": "enemy.melee.desc",
		"icon_path": "res://assets/enemies/enemy_melee.png",
		"max_health": 24,
		"speed": 110.0,
		"contact_damage": 10,
		"exp_value": 5
	},
	{
		"id": "ranged",
		"name_key": "enemy.ranged.name",
		"desc_key": "enemy.ranged.desc",
		"icon_path": "res://assets/enemies/enemy_ranged.png",
		"max_health": 40,
		"speed": 75.0,
		"contact_damage": 7,
		"exp_value": 8
	},
	{
		"id": "tank",
		"name_key": "enemy.tank.name",
		"desc_key": "enemy.tank.desc",
		"icon_path": "res://assets/enemies/enemy_tank.png",
		"max_health": 80,
		"speed": 62.0,
		"contact_damage": 14,
		"exp_value": 12
	},
	{
		"id": "boss",
		"name_key": "enemy.boss.name",
		"desc_key": "enemy.boss.desc",
		"icon_path": "res://assets/enemies/enemy_boss.png",
		"max_health": 320,
		"speed": 58.0,
		"contact_damage": 18,
		"exp_value": 50
	},
	{
		"id": "aquatic",
		"name_key": "enemy.aquatic.name",
		"desc_key": "enemy.aquatic.desc",
		"icon_path": "res://assets/enemies/enemy_aquatic.png",
		"max_health": 20,
		"speed": 95.0,
		"contact_damage": 8,
		"exp_value": 6
	},
	{
		"id": "dasher",
		"name_key": "enemy.dasher.name",
		"desc_key": "enemy.dasher.desc",
		"icon_path": "res://assets/enemies/enemy_dasher.png",
		"max_health": 18,
		"speed": 85.0,
		"contact_damage": 14,
		"exp_value": 10
	}
]


## 根据 id 获取敌人定义。
static func get_enemy_def(enemy_id: String) -> Dictionary:
	for e in ENEMY_DEFS:
		if str(e.get("id", "")) == enemy_id:
			return e.duplicate(true)
	return {}
