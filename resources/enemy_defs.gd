extends RefCounted
class_name EnemyDefs

# 敌人定义集中化：供图鉴、生成、寻路使用。
# tier: normal | elite | boss；base_id: 底层行为类型；behavior_mode: 0=CHASE_DIRECT, 1=CHASE_NAV, 2=KEEP_DISTANCE, 3=FLANK, 4=CHARGE, 5=BOSS_CUSTOM
# 精英：hp_scale/speed_scale/damage_scale 约 1.3～1.8；BOSS：独立 attack_pattern

const BEHAVIOR_CHASE_DIRECT := 0
const BEHAVIOR_CHASE_NAV := 1
const BEHAVIOR_KEEP_DISTANCE := 2
const BEHAVIOR_FLANK := 3
const BEHAVIOR_CHARGE := 4
const BEHAVIOR_BOSS_CUSTOM := 5

const ENEMY_DEFS := [
	# 原有 6 种（保留兼容）
	{"id": "melee", "tier": "normal", "base_id": "melee", "behavior_mode": 0, "scene_path": "res://scenes/enemies/enemy_melee.tscn",
		"name_key": "enemy.melee.name", "desc_key": "enemy.melee.desc", "icon_path": "res://assets/enemies/enemy_melee.png",
		"max_health": 24, "speed": 110.0, "contact_damage": 10, "exp_value": 5},
	{"id": "ranged", "tier": "normal", "base_id": "ranged", "behavior_mode": 2, "scene_path": "res://scenes/enemies/enemy_ranged.tscn",
		"name_key": "enemy.ranged.name", "desc_key": "enemy.ranged.desc", "icon_path": "res://assets/enemies/enemy_ranged.png",
		"max_health": 40, "speed": 75.0, "contact_damage": 7, "exp_value": 8},
	{"id": "tank", "tier": "normal", "base_id": "tank", "behavior_mode": 0, "scene_path": "res://scenes/enemies/enemy_tank.tscn",
		"name_key": "enemy.tank.name", "desc_key": "enemy.tank.desc", "icon_path": "res://assets/enemies/enemy_tank.png",
		"max_health": 80, "speed": 62.0, "contact_damage": 14, "exp_value": 12},
	{"id": "boss", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_boss.tscn",
		"name_key": "enemy.boss.name", "desc_key": "enemy.boss.desc", "icon_path": "res://assets/enemies/enemy_boss.png",
		"max_health": 320, "speed": 58.0, "contact_damage": 18, "exp_value": 50},
	{"id": "aquatic", "tier": "normal", "base_id": "aquatic", "behavior_mode": 0, "scene_path": "res://scenes/enemies/enemy_aquatic.tscn",
		"name_key": "enemy.aquatic.name", "desc_key": "enemy.aquatic.desc", "icon_path": "res://assets/enemies/enemy_aquatic.png",
		"max_health": 20, "speed": 95.0, "contact_damage": 8, "exp_value": 6},
	{"id": "dasher", "tier": "normal", "base_id": "dasher", "behavior_mode": 4, "scene_path": "res://scenes/enemies/enemy_dasher.tscn",
		"name_key": "enemy.dasher.name", "desc_key": "enemy.dasher.desc", "icon_path": "res://assets/enemies/enemy_dasher.png",
		"max_health": 18, "speed": 85.0, "contact_damage": 14, "exp_value": 10},
	# 10 种普通敌人
	{"id": "slime", "tier": "normal", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_slime.tscn",
		"name_key": "enemy.slime.name", "desc_key": "enemy.slime.desc", "icon_path": "res://assets/enemies/slime.png",
		"max_health": 18, "speed": 95.0, "contact_damage": 8, "exp_value": 4},
	{"id": "goblin", "tier": "normal", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_goblin.tscn",
		"name_key": "enemy.goblin.name", "desc_key": "enemy.goblin.desc", "icon_path": "res://assets/enemies/goblin.png",
		"max_health": 22, "speed": 105.0, "contact_damage": 9, "exp_value": 5},
	{"id": "skeleton", "tier": "normal", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_skeleton.tscn",
		"name_key": "enemy.skeleton.name", "desc_key": "enemy.skeleton.desc", "icon_path": "res://assets/enemies/skeleton.png",
		"max_health": 20, "speed": 100.0, "contact_damage": 10, "exp_value": 5},
	{"id": "bat", "tier": "normal", "base_id": "dasher", "behavior_mode": 4, "scene_path": "res://scenes/enemies/enemy_bat.tscn",
		"name_key": "enemy.bat.name", "desc_key": "enemy.bat.desc", "icon_path": "res://assets/enemies/bat.png",
		"max_health": 14, "speed": 120.0, "contact_damage": 6, "exp_value": 4},
	{"id": "spider", "tier": "normal", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_spider.tscn",
		"name_key": "enemy.spider.name", "desc_key": "enemy.spider.desc", "icon_path": "res://assets/enemies/spider.png",
		"max_health": 19, "speed": 98.0, "contact_damage": 9, "exp_value": 5},
	{"id": "wolf", "tier": "normal", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_wolf.tscn",
		"name_key": "enemy.wolf.name", "desc_key": "enemy.wolf.desc", "icon_path": "res://assets/enemies/wolf.png",
		"max_health": 26, "speed": 115.0, "contact_damage": 11, "exp_value": 6},
	{"id": "orc", "tier": "normal", "base_id": "tank", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_orc.tscn",
		"name_key": "enemy.orc.name", "desc_key": "enemy.orc.desc", "icon_path": "res://assets/enemies/orc.png",
		"max_health": 65, "speed": 68.0, "contact_damage": 13, "exp_value": 10},
	{"id": "ghost", "tier": "normal", "base_id": "ranged", "behavior_mode": 2, "scene_path": "res://scenes/enemies/enemy_ghost.tscn",
		"name_key": "enemy.ghost.name", "desc_key": "enemy.ghost.desc", "icon_path": "res://assets/enemies/ghost.png",
		"max_health": 32, "speed": 72.0, "contact_damage": 6, "exp_value": 7},
	{"id": "beetle", "tier": "normal", "base_id": "tank", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_beetle.tscn",
		"name_key": "enemy.beetle.name", "desc_key": "enemy.beetle.desc", "icon_path": "res://assets/enemies/beetle.png",
		"max_health": 55, "speed": 70.0, "contact_damage": 12, "exp_value": 9},
	{"id": "serpent", "tier": "normal", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_serpent.tscn",
		"name_key": "enemy.serpent.name", "desc_key": "enemy.serpent.desc", "icon_path": "res://assets/enemies/serpent.png",
		"max_health": 21, "speed": 102.0, "contact_damage": 10, "exp_value": 5},
	# 10 种精英敌人（hp/speed/damage 倍率约 1.4/1.2/1.3）
	{"id": "elite_slime", "tier": "elite", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_slime.tscn",
		"name_key": "enemy.elite_slime.name", "desc_key": "enemy.elite_slime.desc", "icon_path": "res://assets/enemies/elite_slime.png",
		"max_health": 28, "speed": 110.0, "contact_damage": 11, "exp_value": 7, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_goblin", "tier": "elite", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_goblin.tscn",
		"name_key": "enemy.elite_goblin.name", "desc_key": "enemy.elite_goblin.desc", "icon_path": "res://assets/enemies/elite_goblin.png",
		"max_health": 32, "speed": 120.0, "contact_damage": 12, "exp_value": 8, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_skeleton", "tier": "elite", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_skeleton.tscn",
		"name_key": "enemy.elite_skeleton.name", "desc_key": "enemy.elite_skeleton.desc", "icon_path": "res://assets/enemies/elite_skeleton.png",
		"max_health": 30, "speed": 115.0, "contact_damage": 13, "exp_value": 8, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_bat", "tier": "elite", "base_id": "dasher", "behavior_mode": 4, "scene_path": "res://scenes/enemies/enemy_elite_bat.tscn",
		"name_key": "enemy.elite_bat.name", "desc_key": "enemy.elite_bat.desc", "icon_path": "res://assets/enemies/elite_bat.png",
		"max_health": 22, "speed": 140.0, "contact_damage": 8, "exp_value": 7, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_spider", "tier": "elite", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_spider.tscn",
		"name_key": "enemy.elite_spider.name", "desc_key": "enemy.elite_spider.desc", "icon_path": "res://assets/enemies/elite_spider.png",
		"max_health": 28, "speed": 112.0, "contact_damage": 12, "exp_value": 8, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_wolf", "tier": "elite", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_wolf.tscn",
		"name_key": "enemy.elite_wolf.name", "desc_key": "enemy.elite_wolf.desc", "icon_path": "res://assets/enemies/elite_wolf.png",
		"max_health": 38, "speed": 130.0, "contact_damage": 15, "exp_value": 9, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_orc", "tier": "elite", "base_id": "tank", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_orc.tscn",
		"name_key": "enemy.elite_orc.name", "desc_key": "enemy.elite_orc.desc", "icon_path": "res://assets/enemies/elite_orc.png",
		"max_health": 95, "speed": 78.0, "contact_damage": 17, "exp_value": 14, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_ghost", "tier": "elite", "base_id": "ranged", "behavior_mode": 2, "scene_path": "res://scenes/enemies/enemy_elite_ghost.tscn",
		"name_key": "enemy.elite_ghost.name", "desc_key": "enemy.elite_ghost.desc", "icon_path": "res://assets/enemies/elite_ghost.png",
		"max_health": 48, "speed": 82.0, "contact_damage": 8, "exp_value": 11, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_beetle", "tier": "elite", "base_id": "tank", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_beetle.tscn",
		"name_key": "enemy.elite_beetle.name", "desc_key": "enemy.elite_beetle.desc", "icon_path": "res://assets/enemies/elite_beetle.png",
		"max_health": 80, "speed": 82.0, "contact_damage": 16, "exp_value": 13, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	{"id": "elite_serpent", "tier": "elite", "base_id": "melee", "behavior_mode": 1, "scene_path": "res://scenes/enemies/enemy_elite_serpent.tscn",
		"name_key": "enemy.elite_serpent.name", "desc_key": "enemy.elite_serpent.desc", "icon_path": "res://assets/enemies/elite_serpent.png",
		"max_health": 32, "speed": 118.0, "contact_damage": 13, "exp_value": 8, "hp_scale": 1.4, "speed_scale": 1.2, "damage_scale": 1.3},
	# 10 种 BOSS
	{"id": "slime_king", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_slime_king.tscn",
		"name_key": "enemy.slime_king.name", "desc_key": "enemy.slime_king.desc", "icon_path": "res://assets/enemies/slime_king.png",
		"max_health": 280, "speed": 55.0, "contact_damage": 16, "exp_value": 45},
	{"id": "goblin_chief", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_goblin_chief.tscn",
		"name_key": "enemy.goblin_chief.name", "desc_key": "enemy.goblin_chief.desc", "icon_path": "res://assets/enemies/goblin_chief.png",
		"max_health": 300, "speed": 60.0, "contact_damage": 18, "exp_value": 48},
	{"id": "skeleton_lord", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_skeleton_lord.tscn",
		"name_key": "enemy.skeleton_lord.name", "desc_key": "enemy.skeleton_lord.desc", "icon_path": "res://assets/enemies/skeleton_lord.png",
		"max_health": 290, "speed": 58.0, "contact_damage": 17, "exp_value": 47},
	{"id": "bat_swarm_queen", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_bat_swarm_queen.tscn",
		"name_key": "enemy.bat_swarm_queen.name", "desc_key": "enemy.bat_swarm_queen.desc", "icon_path": "res://assets/enemies/bat_swarm_queen.png",
		"max_health": 260, "speed": 72.0, "contact_damage": 14, "exp_value": 44},
	{"id": "spider_queen", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_spider_queen.tscn",
		"name_key": "enemy.spider_queen.name", "desc_key": "enemy.spider_queen.desc", "icon_path": "res://assets/enemies/spider_queen.png",
		"max_health": 310, "speed": 52.0, "contact_damage": 19, "exp_value": 50},
	{"id": "alpha_wolf", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_alpha_wolf.tscn",
		"name_key": "enemy.alpha_wolf.name", "desc_key": "enemy.alpha_wolf.desc", "icon_path": "res://assets/enemies/alpha_wolf.png",
		"max_health": 295, "speed": 65.0, "contact_damage": 18, "exp_value": 49},
	{"id": "orc_warlord", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_orc_warlord.tscn",
		"name_key": "enemy.orc_warlord.name", "desc_key": "enemy.orc_warlord.desc", "icon_path": "res://assets/enemies/orc_warlord.png",
		"max_health": 350, "speed": 50.0, "contact_damage": 20, "exp_value": 55},
	{"id": "phantom", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_phantom.tscn",
		"name_key": "enemy.phantom.name", "desc_key": "enemy.phantom.desc", "icon_path": "res://assets/enemies/phantom.png",
		"max_health": 270, "speed": 68.0, "contact_damage": 15, "exp_value": 46},
	{"id": "beetle_tyrant", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_beetle_tyrant.tscn",
		"name_key": "enemy.beetle_tyrant.name", "desc_key": "enemy.beetle_tyrant.desc", "icon_path": "res://assets/enemies/beetle_tyrant.png",
		"max_health": 340, "speed": 48.0, "contact_damage": 21, "exp_value": 52},
	{"id": "serpent_ancient", "tier": "boss", "base_id": "boss", "behavior_mode": 5, "scene_path": "res://scenes/enemies/enemy_serpent_ancient.tscn",
		"name_key": "enemy.serpent_ancient.name", "desc_key": "enemy.serpent_ancient.desc", "icon_path": "res://assets/enemies/serpent_ancient.png",
		"max_health": 285, "speed": 62.0, "contact_damage": 17, "exp_value": 47}
]


## 根据 id 获取敌人定义。
static func get_enemy_def(enemy_id: String) -> Dictionary:
	for e in ENEMY_DEFS:
		if str(e.get("id", "")) == enemy_id:
			return e.duplicate(true)
	return {}


## 按 tier 获取 id 列表。
static func get_ids_by_tier(tier: String) -> Array[String]:
	var result: Array[String] = []
	for e in ENEMY_DEFS:
		if str(e.get("tier", "normal")) == tier:
			result.append(str(e.get("id", "")))
	return result
