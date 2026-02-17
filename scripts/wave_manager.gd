extends Node2D

# 波次管理器：
# - 控制每波敌人数与构成
# - 控制回合间隔
# - 维护击杀数与在场敌人计数
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal kill_count_changed(kills: int)
# 交给 HUD 显示“下一波倒计时”。
signal intermission_started(duration: float)
# 当前波次剩余时间，供 HUD 正上方显示；倒计时归零时视为波次结束。
signal wave_countdown_changed(seconds_left: float)

@export var wave_duration := 20.0
@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var tank_scene: PackedScene = preload("res://scenes/enemies/enemy_tank.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/enemy_boss.tscn")
@export var aquatic_scene: PackedScene = preload("res://scenes/enemies/enemy_aquatic.tscn")
@export var dasher_scene: PackedScene = preload("res://scenes/enemies/enemy_dasher.tscn")
@export var coin_pickup_scene: PackedScene = preload("res://scenes/pickup.tscn")
@export var heal_pickup_scene: PackedScene = preload("res://scenes/pickup.tscn")
@export var telegraph_scene: PackedScene = preload("res://scenes/spawn_telegraph.tscn")
@export var spawn_min_player_distance := 340.0
@export var spawn_attempts := 24
@export var spawn_region_margin := 24.0
@export var telegraph_enabled := true
@export var telegraph_duration := 0.9
@export var telegraph_show_ring := true
@export var telegraph_show_countdown := true
@export var intermission_time := 3.5
@export var coin_drop_chance := 0.38
@export var heal_drop_chance := 0.17
@export var boss_bonus_coin_count := Vector2i(2, 3)
@export var spawn_batch_count := 3
@export var spawn_batch_interval := 6.0
@export var spawn_positions_count := 5  # 出生点数量，单出生点可产生多个敌人

var current_wave := 0  # 当前波次编号
var kill_count := 0  # 本局总击杀数
var living_enemy_count := 0  # 在场敌人数量，归零且无待生成时触发 wave_cleared
var pending_spawn_count := 0  # 待生成数量（含警示中的）
var is_spawning := false  # 防重入：是否正在执行 _start_next_wave
var _current_intermission := 0.0  # 间隔剩余秒数（由 Timer 驱动）
var _rng := RandomNumberGenerator.new()
var _player_ref: Node2D  # 玩家引用，用于出生点避让
var _viewport_size := Vector2(1280, 720)  # 视口尺寸，用于生成区域
var _wave_countdown_left := 0.0  # 波次倒计时剩余秒数
var _wave_cleared_emitted := false  # 防重复发射 wave_cleared
var _pending_spawn_batches: Array = []  # 分批生成队列，每批为 Array[Dictionary]
var _batch_index := 0

@onready var intermission_timer: Timer = $IntermissionTimer


func _ready() -> void:
	_rng.randomize()
	intermission_timer.timeout.connect(_start_next_wave)


func setup(player_ref: Node2D) -> void:
	# 游戏场景创建完玩家后调用。
	_player_ref = player_ref
	_viewport_size = get_viewport_rect().size
	start_first_wave()


func start_first_wave() -> void:
	current_wave = 0
	_start_next_wave()


func begin_intermission() -> void:
	# 由 Game 在“升级完成”后显式触发，避免和旧逻辑冲突。
	_current_intermission = intermission_time
	emit_signal("intermission_started", intermission_time)
	intermission_timer.start(intermission_time)


func get_intermission_left() -> float:
	if intermission_timer.is_stopped():
		return 0.0
	return intermission_timer.time_left


func _process(delta: float) -> void:
	if _wave_countdown_left <= 0.0 or _wave_cleared_emitted:
		return
	# 限制单帧扣减，避免首帧/切回标签页时 delta 过大导致倒计时瞬间归零、波次提前结束
	var capped_delta := minf(delta, 0.5)
	_wave_countdown_left = maxf(0.0, _wave_countdown_left - capped_delta)
	emit_signal("wave_countdown_changed", _wave_countdown_left)
	# 分批生成：当波次已过去 batch_index * interval 秒时，生成下一批。
	var elapsed := wave_duration - _wave_countdown_left
	while _batch_index < _pending_spawn_batches.size():
		var batch_time := float(_batch_index) * spawn_batch_interval
		if elapsed < batch_time:
			break
		_spawn_batch(_pending_spawn_batches[_batch_index])
		_batch_index += 1
	if _wave_countdown_left <= 0.0:
		_try_emit_wave_cleared()


func _start_next_wave() -> void:
	if is_spawning:
		return
	intermission_timer.stop()
	is_spawning = true
	_wave_cleared_emitted = false
	current_wave += 1
	pending_spawn_count = 0

	var cfg: LevelConfig = GameManager.get_current_level_config(current_wave)
	if cfg == null:
		cfg = _get_fallback_level_config()
	wave_duration = cfg.wave_duration if cfg != null else 20.0
	spawn_batch_count = int(cfg.spawn_batch_count) if cfg != null else 3
	spawn_batch_interval = cfg.spawn_batch_interval if cfg != null else 6.0
	spawn_positions_count = int(cfg.spawn_positions_count) if cfg != null else 5
	_wave_countdown_left = wave_duration
	emit_signal("wave_started", current_wave)
	_current_intermission = 0.0

	var game_node = get_parent()
	var scenes := {
		"melee": melee_scene,
		"ranged": ranged_scene,
		"tank": tank_scene,
		"aquatic": aquatic_scene,
		"dasher": dasher_scene,
		"boss": boss_scene
	}
	var orders: Array = []
	if cfg != null:
		orders = cfg.get_enemy_spawn_orders(current_wave, game_node, scenes, _rng)
		var diff: float = cfg.difficulty
		for o in orders:
			o["hp_scale"] = (o.get("hp_scale", 1.0) as float) * diff
			o["speed_scale"] = (o.get("speed_scale", 1.0) as float) * diff
	else:
		orders = _get_fallback_orders(game_node)

	# 按出生点分组：单出生点可产生多个敌人。
	var position_batches: Array = []  # 每项为 {position: Vector2, spawns: Array}
	var aquatic_orders: Array = []
	var land_orders: Array = []
	for o in orders:
		if o.get("pos_override") != null and o.get("pos_override") is Vector2:
			aquatic_orders.append(o)
		else:
			land_orders.append(o)
	# 陆生敌人：生成 spawn_positions_count 个出生点，按顺序分配。
	var pos_count := maxi(1, spawn_positions_count)
	for i in range(pos_count):
		position_batches.append({"position": _random_spawn_position(), "spawns": []})
	for i in range(land_orders.size()):
		var o: Dictionary = land_orders[i]
		var idx := i % pos_count
		position_batches[idx].spawns.append(o)
	# 水生敌人：每个有独立水域位置，各成一批。
	for o in aquatic_orders:
		position_batches.append({"position": o.pos_override, "spawns": [o]})
	# 将出生点批次按时间拆分到多批（spawn_batch_count）。
	_pending_spawn_batches.clear()
	_batch_index = 0
	var temporal_count := maxi(1, spawn_batch_count)
	var per_temporal := int(position_batches.size() / temporal_count)
	var remainder := position_batches.size() % temporal_count
	var idx := 0
	for t in range(temporal_count):
		var batch_size := per_temporal + (1 if t < remainder else 0)
		var temporal_batch: Array = []
		for j in range(batch_size):
			if idx < position_batches.size():
				temporal_batch.append(position_batches[idx])
				idx += 1
		_pending_spawn_batches.append(temporal_batch)
	# 更新待生成总数。
	pending_spawn_count = 0
	for pb in position_batches:
		pending_spawn_count += pb.spawns.size()
	# 第 1 批立即生成。
	if _pending_spawn_batches.size() > 0:
		_spawn_batch(_pending_spawn_batches[0])
		_batch_index = 1

	is_spawning = false


func _spawn_batch(temporal_batch: Array) -> void:
	# temporal_batch 为多个 {position, spawns} 的数组。
	for pb in temporal_batch:
		_queue_batch_spawn(pb.position, pb.spawns)


# 排队生成一批敌人：同一出生点可产生多个敌人，telegraph 显示数量。
func _queue_batch_spawn(spawn_position: Vector2, spawns: Array) -> void:
	if spawns.is_empty() or not is_instance_valid(_player_ref):
		return
	if telegraph_enabled and telegraph_scene != null:
		var telegraph = telegraph_scene.instantiate()
		telegraph.global_position = spawn_position
		telegraph.set("duration", telegraph_duration)
		telegraph.set("show_ring", telegraph_show_ring)
		telegraph.set("show_countdown", telegraph_show_countdown)
		telegraph.set("spawn_count", spawns.size())
		telegraph.telegraph_finished.connect(_on_telegraph_batch_finished.bind(spawns, telegraph))
		get_tree().current_scene.add_child(telegraph)
	else:
		for o in spawns:
			_spawn_enemy_at(o.scene, spawn_position, o.hp_scale, o.speed_scale)
		pending_spawn_count = maxi(pending_spawn_count - spawns.size(), 0)


func _on_telegraph_batch_finished(spawns: Array, telegraph_node: Node) -> void:
	var spawn_position: Vector2 = telegraph_node.global_position if is_instance_valid(telegraph_node) else _random_spawn_position()
	if is_instance_valid(telegraph_node):
		telegraph_node.queue_free()
	for o in spawns:
		_spawn_enemy_at(o.scene, spawn_position, o.hp_scale, o.speed_scale)
	pending_spawn_count = maxi(pending_spawn_count - spawns.size(), 0)


func _spawn_enemy_at(scene: PackedScene, spawn_position: Vector2, hp_scale: float, speed_scale: float) -> void:
	if scene == null or not is_instance_valid(_player_ref):
		return
	var enemy := scene.instantiate()
	enemy.global_position = spawn_position
	enemy.set_player(_player_ref)
	if enemy.has_method("set_water_bounds"):
		var game_node = get_parent()
		if game_node != null and game_node.has_method("get_water_rect_containing"):
			enemy.set_water_bounds(game_node.get_water_rect_containing(spawn_position))
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	# 每波对敌人生命与速度进行缩放。
	enemy.max_health = int(enemy.max_health * hp_scale)
	enemy.current_health = enemy.max_health
	enemy.speed = enemy.speed * speed_scale

	living_enemy_count += 1
	add_child(enemy)


func _random_spawn_position() -> Vector2:
	# 在可玩区域内采样，且尽量远离玩家；若反复失败则用“最远候选点”兜底。
	var region: Rect2
	var game_node := get_parent()
	if game_node != null and game_node.has_method("get_playable_bounds"):
		region = game_node.get_playable_bounds()
		# 内缩 margin 避免贴边
		region = Rect2(
			region.position + Vector2(spawn_region_margin, spawn_region_margin),
			region.size - Vector2(spawn_region_margin * 2.0, spawn_region_margin * 2.0)
		)
	else:
		region = Rect2(
			Vector2(spawn_region_margin, spawn_region_margin),
			Vector2(
				maxf(16.0, _viewport_size.x - spawn_region_margin * 2.0),
				maxf(16.0, _viewport_size.y - spawn_region_margin * 2.0)
			)
		)
	var region_center := region.position + region.size * 0.5
	var player_pos := _player_ref.global_position if is_instance_valid(_player_ref) else region_center
	var best_pos := region_center
	var best_dist := -1.0
	for i in range(maxi(1, spawn_attempts)):
		var candidate := Vector2(
			_rng.randf_range(region.position.x, region.end.x),
			_rng.randf_range(region.position.y, region.end.y)
		)
		var dist := candidate.distance_to(player_pos)
		if dist > best_dist:
			best_dist = dist
			best_pos = candidate
		if dist >= spawn_min_player_distance:
			return candidate
	return best_pos


func _on_enemy_died(enemy: Node) -> void:
	living_enemy_count = maxi(living_enemy_count - 1, 0)
	kill_count += 1
	AudioManager.play_kill()
	emit_signal("kill_count_changed", kill_count)
	# 击败敌人获得经验值（enemy_base 及子类均有 exp_value）
	var xp: int = int(enemy.exp_value) if "exp_value" in enemy else 5
	GameManager.add_experience(xp)
	_try_spawn_drop(enemy)
	_try_spawn_boss_bonus_drop(enemy)


# 在场敌人与待生成均为 0 或倒计时归零时发射一次 wave_cleared。
func _try_emit_wave_cleared() -> void:
	if _wave_cleared_emitted:
		return
	_wave_cleared_emitted = true
	living_enemy_count = 0
	pending_spawn_count = 0
	emit_signal("wave_cleared", current_wave)


# 敌人死亡时按概率掉落金币或治疗；使用 call_deferred 避免 physics flushing。
func _try_spawn_drop(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var r := _rng.randf()
	if r < coin_drop_chance and coin_pickup_scene != null:
		var coin_value := 2 + int(current_wave / 3.0)
		_spawn_coin_drop(enemy.global_position, coin_value)
	elif r < coin_drop_chance + heal_drop_chance and heal_pickup_scene != null:
		var heal := heal_pickup_scene.instantiate()
		heal.global_position = enemy.global_position
		heal.pickup_type = "heal"
		heal.value = 6 + int(current_wave / 3.0)
		get_tree().current_scene.call_deferred("add_child", heal)


func _try_spawn_boss_bonus_drop(enemy: Node) -> void:
	# Boss 死亡时额外掉落多枚高价值金币，强化关键战反馈。
	if not _is_boss_enemy(enemy):
		return
	var extra_count := _rng.randi_range(boss_bonus_coin_count.x, boss_bonus_coin_count.y)
	for i in range(extra_count):
		var bonus_value := 5 + int(current_wave / 4.0)
		var offset := Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-18.0, 18.0))
		_spawn_coin_drop(enemy.global_position + offset, bonus_value)


func _spawn_coin_drop(spawn_position: Vector2, coin_value: int) -> void:
	if coin_pickup_scene == null:
		return
	var coin := coin_pickup_scene.instantiate()
	coin.global_position = spawn_position
	coin.pickup_type = "coin"
	coin.value = maxi(1, coin_value)
	# 在物理回调链里延迟 add_child，避免 flushing_queries 报错。
	get_tree().current_scene.call_deferred("add_child", coin)


func _is_boss_enemy(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	return enemy.is_in_group("boss") or str(enemy.name).to_lower().contains("boss")


func _get_fallback_level_config() -> LevelConfig:
	var preset: LevelPreset = load(GameManager.LEVEL_PRESET_PATHS[0]) as LevelPreset
	if preset and preset.level_configs.size() > 0 and preset.level_configs[0] is LevelConfig:
		return preset.level_configs[0] as LevelConfig
	return null


func _get_fallback_orders(game_node: Node) -> Array:
	var total: int = 8 + current_wave * 3
	var ranged_c: int = maxi(1, int(current_wave * 0.45))
	var tank_c: int = maxi(0, int(current_wave / 4.0))
	var melee_c: int = maxi(total - ranged_c - tank_c, 1)
	var orders: Array = []
	for i in range(melee_c):
		orders.append({"scene": melee_scene, "hp_scale": 0.9 + current_wave * 0.06, "speed_scale": 1.0 + current_wave * 0.08, "pos_override": null})
	for i in range(ranged_c):
		orders.append({"scene": ranged_scene, "hp_scale": 1.0 + current_wave * 0.08, "speed_scale": 1.0 + current_wave * 0.10, "pos_override": null})
	for i in range(tank_c):
		orders.append({"scene": tank_scene, "hp_scale": 1.0 + current_wave * 0.12, "speed_scale": 0.9 + current_wave * 0.05, "pos_override": null})
	var aquatic_c := 0
	if game_node != null and game_node.has_method("has_water_spawn_positions") and game_node.has_water_spawn_positions():
		aquatic_c = mini(maxi(1, int(current_wave * 0.5)), 2)
	for i in range(aquatic_c):
		var water_pos: Vector2 = game_node.get_random_water_spawn_position() if game_node != null else Vector2.ZERO
		orders.append({"scene": aquatic_scene, "hp_scale": 0.9 + current_wave * 0.06, "speed_scale": 1.0 + current_wave * 0.06, "pos_override": water_pos})
	var dasher_c := _rng.randi_range(1, 2) if current_wave >= 2 else 0
	for i in range(dasher_c):
		orders.append({"scene": dasher_scene, "hp_scale": 0.9 + current_wave * 0.06, "speed_scale": 1.0 + current_wave * 0.06, "pos_override": null})
	if current_wave % 5 == 0:
		orders.append({"scene": boss_scene, "hp_scale": 1.0 + current_wave * 0.15, "speed_scale": 1.0, "pos_override": null})
	return orders
