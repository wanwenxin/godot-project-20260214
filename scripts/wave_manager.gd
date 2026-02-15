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

@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var tank_scene: PackedScene = preload("res://scenes/enemies/enemy_tank.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/enemy_boss.tscn")
@export var coin_pickup_scene: PackedScene = preload("res://scenes/pickup.tscn")
@export var heal_pickup_scene: PackedScene = preload("res://scenes/pickup.tscn")
@export var telegraph_scene: PackedScene = preload("res://scenes/spawn_telegraph.tscn")
@export var spawn_min_player_distance := 300.0
@export var spawn_attempts := 24
@export var spawn_region_margin := 24.0
@export var telegraph_enabled := true
@export var telegraph_duration := 0.9
@export var telegraph_show_ring := true
@export var telegraph_show_countdown := true
@export var intermission_time := 3.5

var current_wave := 0
var kill_count := 0
var living_enemy_count := 0
var pending_spawn_count := 0
var is_spawning := false
var _current_intermission := 0.0
var _rng := RandomNumberGenerator.new()
var _player_ref: Node2D
var _viewport_size := Vector2(1280, 720)

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


func _start_next_wave() -> void:
	if is_spawning:
		return
	intermission_timer.stop()
	is_spawning = true
	current_wave += 1
	pending_spawn_count = 0
	emit_signal("wave_started", current_wave)
	_current_intermission = 0.0

	# 简单难度曲线：总量随波次上升，远程占比逐渐提高。
	var total_to_spawn: int = 5 + current_wave * 2
	var ranged_count: int = maxi(1, int(current_wave * 0.45))
	var tank_count: int = 0
	if current_wave >= 4:
		tank_count = maxi(1, int(current_wave / 4.0))
	var melee_count: int = maxi(total_to_spawn - ranged_count - tank_count, 1)

	for i in range(melee_count):
		_queue_enemy_spawn(melee_scene, 0.9 + current_wave * 0.06, 1.0 + current_wave * 0.08)
	for i in range(ranged_count):
		_queue_enemy_spawn(ranged_scene, 1.0 + current_wave * 0.08, 1.0 + current_wave * 0.10)
	for i in range(tank_count):
		_queue_enemy_spawn(tank_scene, 1.0 + current_wave * 0.12, 0.9 + current_wave * 0.05)

	# 每 5 波生成 Boss，普通敌人数量减半以避免同屏过载。
	if current_wave % 5 == 0:
		_queue_enemy_spawn(boss_scene, 1.0 + current_wave * 0.15, 1.0)

	is_spawning = false


func _queue_enemy_spawn(scene: PackedScene, hp_scale: float, speed_scale: float) -> void:
	if scene == null or not is_instance_valid(_player_ref):
		return
	var spawn_position := _random_spawn_position()
	pending_spawn_count += 1
	if telegraph_enabled and telegraph_scene != null:
		var telegraph = telegraph_scene.instantiate()
		telegraph.global_position = spawn_position
		telegraph.set("duration", telegraph_duration)
		telegraph.set("show_ring", telegraph_show_ring)
		telegraph.set("show_countdown", telegraph_show_countdown)
		telegraph.telegraph_finished.connect(_on_telegraph_finished.bind(scene, hp_scale, speed_scale, telegraph))
		get_tree().current_scene.add_child(telegraph)
	else:
		_spawn_enemy_at(scene, spawn_position, hp_scale, speed_scale)
		pending_spawn_count = maxi(pending_spawn_count - 1, 0)


func _on_telegraph_finished(scene: PackedScene, hp_scale: float, speed_scale: float, telegraph_node: Node) -> void:
	var spawn_position: Vector2 = telegraph_node.global_position if is_instance_valid(telegraph_node) else _random_spawn_position()
	if is_instance_valid(telegraph_node):
		telegraph_node.queue_free()
	_spawn_enemy_at(scene, spawn_position, hp_scale, speed_scale)
	pending_spawn_count = maxi(pending_spawn_count - 1, 0)


func _spawn_enemy_at(scene: PackedScene, spawn_position: Vector2, hp_scale: float, speed_scale: float) -> void:
	if scene == null or not is_instance_valid(_player_ref):
		return
	var enemy := scene.instantiate()
	enemy.global_position = spawn_position
	enemy.set_player(_player_ref)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	# 每波对敌人生命与速度进行缩放。
	enemy.max_health = int(enemy.max_health * hp_scale)
	enemy.current_health = enemy.max_health
	enemy.speed = enemy.speed * speed_scale

	living_enemy_count += 1
	add_child(enemy)


func _random_spawn_position() -> Vector2:
	# 在边界内采样，且尽量远离玩家；若反复失败则用“最远候选点”兜底。
	var region := Rect2(
		Vector2(spawn_region_margin, spawn_region_margin),
		Vector2(
			maxf(16.0, _viewport_size.x - spawn_region_margin * 2.0),
			maxf(16.0, _viewport_size.y - spawn_region_margin * 2.0)
		)
	)
	var player_pos := _player_ref.global_position if is_instance_valid(_player_ref) else _viewport_size * 0.5
	var best_pos := region.position + region.size * 0.5
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
	_try_spawn_drop(enemy)
	if living_enemy_count <= 0 and pending_spawn_count <= 0:
		emit_signal("wave_cleared", current_wave)


func _try_spawn_drop(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var r := _rng.randf()
	if r < 0.18 and coin_pickup_scene != null:
		var coin := coin_pickup_scene.instantiate()
		coin.global_position = enemy.global_position
		coin.pickup_type = "coin"
		coin.value = 1 + int(current_wave / 4.0)
		# 在物理回调链里延迟 add_child，避免 flushing_queries 报错。
		get_tree().current_scene.call_deferred("add_child", coin)
	elif r < 0.23 and heal_pickup_scene != null:
		var heal := heal_pickup_scene.instantiate()
		heal.global_position = enemy.global_position
		heal.pickup_type = "heal"
		heal.value = 6 + int(current_wave / 3.0)
		get_tree().current_scene.call_deferred("add_child", heal)
