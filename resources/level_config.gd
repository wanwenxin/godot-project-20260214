class_name LevelConfig
extends Resource

## 关卡配置基类：地形、敌人、BOSS、倒计时、难度等参数。
## 子类或 .tres 实例可覆盖默认值。

@export_group("Terrain")
@export var map_size_scale: float = 1.0  # 地图大小系数：0.8=小，1.0=中，1.2=大
@export var default_terrain_type: String = "mountain"  # 默认地形类型：flat=平地，seaside=海边，mountain=山地
@export var grass_count_min := 2 # 草地数量最小值
@export var grass_count_max := 4 # 草地数量最大值
@export var shallow_water_count_min := 1 # 浅水数量最小值
@export var shallow_water_count_max := 3 # 浅水数量最大值
@export var deep_water_count_min := 1 # 深水数量最小值
@export var deep_water_count_max := 2 # 深水数量最大值
@export var obstacle_count_min := 2 # 障碍物数量最小值
@export var obstacle_count_max := 4 # 障碍物数量最大值
@export var zone_area_scale := 2.0 # 区域面积缩放比例
@export var terrain_margin := 36.0 # 地形间距
@export var placement_attempts := 24 # 放置尝试次数
@export var water_padding := 8.0 # 水域间距
@export var obstacle_padding := 10.0 # 障碍物间距
@export var grass_padding := 4.0 # 草地间距
@export var deep_water_cluster_count := 2 # 深水集群数量
@export var shallow_water_cluster_count := 2 # 浅水集群数量
@export var obstacle_cluster_count := 3 # 障碍物集群数量
@export var grass_cluster_count := 4 # 草地集群数量
@export var deep_water_cluster_radius := 120.0 # 深水集群半径
@export var shallow_water_cluster_radius := 140.0 # 浅水集群半径
@export var obstacle_cluster_radius := 150.0 # 障碍物集群半径
@export var grass_cluster_radius := 170.0 # 草地集群半径		
@export var deep_water_cluster_items := Vector2i(2, 4) # 深水集群物品数量
@export var shallow_water_cluster_items := Vector2i(2, 5) # 浅水集群物品数量
@export var obstacle_cluster_items := Vector2i(2, 4) # 障碍物集群物品数量
@export var grass_cluster_items := Vector2i(3, 6) # 草地集群物品数量

@export_group("Enemies")
@export var melee_count_min := 6 # 近战敌人数量最小值
@export var melee_count_max := 10 # 近战敌人数量最大值
@export var ranged_count_min := 2 # 远程敌人数量最小值
@export var ranged_count_max := 5 # 远程敌人数量最大值
@export var tank_count_min := 0 # 坦克敌人数量最小值
@export var tank_count_max := 1 # 坦克敌人数量最大值
@export var aquatic_count_min := 0 # 水生敌人数量最小值
@export var aquatic_count_max := 2 # 水生敌人数量最大值
@export var dasher_count_min := 0 # 冲刺敌人数量最小值
@export var dasher_count_max := 2 # 冲刺敌人数量最大值
@export var boss_count := 0 # boss数量
@export var use_extended_spawn := false # 为 true 时使用 normal/elite/boss 池
@export var elite_spawn_chance_base := 0.05 # 精英基础概率
@export var elite_spawn_chance_per_wave := 0.02 # 每波增加的精英概率

@export_group("Wave")
@export var wave_duration := 20.0 # 波次持续时间
@export var difficulty := 1.0 # 难度
@export var spawn_batch_count := 3 # 生成批次数量
@export var spawn_batch_interval := 6.0 # 生成批次间隔时间
@export var spawn_positions_count := 5 # 出生点数量，单出生点可产生多个敌人


func get_terrain_params() -> Dictionary:
	return {
		"map_size_scale": map_size_scale,
		"default_terrain_type": default_terrain_type,
		"grass_count_min": grass_count_min,
		"grass_count_max": grass_count_max,
		"shallow_water_count_min": shallow_water_count_min,
		"shallow_water_count_max": shallow_water_count_max,
		"deep_water_count_min": deep_water_count_min,
		"deep_water_count_max": deep_water_count_max,
		"obstacle_count_min": obstacle_count_min,
		"obstacle_count_max": obstacle_count_max,
		"zone_area_scale": zone_area_scale,
		"terrain_margin": terrain_margin,
		"placement_attempts": placement_attempts,
		"water_padding": water_padding,
		"obstacle_padding": obstacle_padding,
		"grass_padding": grass_padding,
		"deep_water_cluster_count": deep_water_cluster_count,
		"shallow_water_cluster_count": shallow_water_cluster_count,
		"obstacle_cluster_count": obstacle_cluster_count,
		"grass_cluster_count": grass_cluster_count,
		"deep_water_cluster_radius": deep_water_cluster_radius,
		"shallow_water_cluster_radius": shallow_water_cluster_radius,
		"obstacle_cluster_radius": obstacle_cluster_radius,
		"grass_cluster_radius": grass_cluster_radius,
		"deep_water_cluster_items": deep_water_cluster_items,
		"shallow_water_cluster_items": shallow_water_cluster_items,
		"obstacle_cluster_items": obstacle_cluster_items,
		"grass_cluster_items": grass_cluster_items
	}


## 返回本关敌人生成订单数组。scenes 含 melee/ranged/tank/aquatic/dasher/boss 的 PackedScene。
## use_extended_spawn 为 true 时从 normal/elite/boss 池按 tier 抽取；否则沿用原有 count 逻辑。
func get_enemy_spawn_orders(wave: int, game_node: Node, scenes: Dictionary, rng: RandomNumberGenerator) -> Array:
	var orders: Array = []
	if use_extended_spawn:
		orders = _get_extended_spawn_orders(wave, game_node, rng)
	else:
		orders = _get_legacy_spawn_orders(wave, game_node, scenes, rng)
	return orders


func _get_extended_spawn_orders(wave: int, game_node: Node, rng: RandomNumberGenerator) -> Array:
	var orders: Array = []
	var normal_ids: Array[String] = []
	var elite_ids: Array[String] = []
	var boss_ids: Array[String] = []
	for eid in EnemyDefs.get_ids_by_tier("normal"):
		normal_ids.append(eid)
	for eid in EnemyDefs.get_ids_by_tier("elite"):
		elite_ids.append(eid)
	for eid in EnemyDefs.get_ids_by_tier("boss"):
		boss_ids.append(eid)
	if normal_ids.is_empty():
		normal_ids.append_array(["melee", "ranged", "tank", "aquatic", "dasher"])
	if boss_ids.is_empty():
		boss_ids.append("boss")
	var total := clampi(6 + wave * 2, 4, 25)
	var elite_chance := elite_spawn_chance_base + wave * elite_spawn_chance_per_wave
	var boss_num := 1 if (wave % 5 == 0 and wave > 0) else boss_count
	var elite_count := 0
	for _i in range(total - boss_num):
		if rng.randf() < elite_chance and not elite_ids.is_empty():
			elite_count += 1
	var normal_count := total - boss_num - elite_count
	var hp_base := 0.9 + wave * 0.05
	var speed_base := 1.0 + wave * 0.06
	for _i in range(normal_count):
		var eid: String = normal_ids[rng.randi() % normal_ids.size()]
		var def: Dictionary = EnemyDefs.get_enemy_def(eid)
		var hp_s := def.get("hp_scale", 1.0) as float * hp_base
		var sp_s := def.get("speed_scale", 1.0) as float * speed_base
		orders.append({"enemy_id": eid, "hp_scale": hp_s, "speed_scale": sp_s, "pos_override": null})
	for _i in range(elite_count):
		var eid: String = elite_ids[rng.randi() % elite_ids.size()]
		var def: Dictionary = EnemyDefs.get_enemy_def(eid)
		var hp_s := (def.get("hp_scale", 1.4) as float) * hp_base
		var sp_s := (def.get("speed_scale", 1.2) as float) * speed_base
		orders.append({"enemy_id": eid, "hp_scale": hp_s, "speed_scale": sp_s, "pos_override": null})
	for _i in range(boss_num):
		var eid: String = boss_ids[rng.randi() % boss_ids.size()]
		orders.append({"enemy_id": eid, "hp_scale": 1.0 + wave * 0.12, "speed_scale": 0.95, "pos_override": null})
	return orders


func _get_legacy_spawn_orders(wave: int, game_node: Node, scenes: Dictionary, rng: RandomNumberGenerator) -> Array:
	var orders: Array = []
	var melee_c := clampi(rng.randi_range(melee_count_min, melee_count_max), 0, 20)
	var ranged_c := clampi(rng.randi_range(ranged_count_min, ranged_count_max), 0, 10)
	var tank_c := clampi(rng.randi_range(tank_count_min, tank_count_max), 0, 5)
	var aquatic_c := 0
	if game_node != null and game_node.has_method("has_water_spawn_positions") and game_node.has_water_spawn_positions():
		aquatic_c = clampi(rng.randi_range(aquatic_count_min, aquatic_count_max), 0, 4)
	var dasher_c := clampi(rng.randi_range(dasher_count_min, dasher_count_max), 0, 4)
	var hp_base := 0.9 + wave * 0.06
	var speed_base := 1.0 + wave * 0.08
	for _i in range(melee_c):
		orders.append({"scene": scenes.get("melee"), "hp_scale": hp_base, "speed_scale": speed_base, "pos_override": null})
	for _i in range(ranged_c):
		orders.append({"scene": scenes.get("ranged"), "hp_scale": 1.0 + wave * 0.08, "speed_scale": 1.0 + wave * 0.10, "pos_override": null})
	for _i in range(tank_c):
		orders.append({"scene": scenes.get("tank"), "hp_scale": 1.0 + wave * 0.12, "speed_scale": 0.9 + wave * 0.05, "pos_override": null})
	for _i in range(aquatic_c):
		var water_pos: Vector2 = game_node.get_random_water_spawn_position() if game_node != null else Vector2.ZERO
		orders.append({"scene": scenes.get("aquatic"), "hp_scale": hp_base, "speed_scale": 1.0 + wave * 0.06, "pos_override": water_pos})
	for _i in range(dasher_c):
		orders.append({"scene": scenes.get("dasher"), "hp_scale": hp_base, "speed_scale": 1.0 + wave * 0.06, "pos_override": null})
	for _i in range(boss_count):
		orders.append({"scene": scenes.get("boss"), "hp_scale": 1.0 + wave * 0.15, "speed_scale": 1.0, "pos_override": null})
	return orders
