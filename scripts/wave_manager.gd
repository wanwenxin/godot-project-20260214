extends Node2D

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal kill_count_changed(kills: int)

@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var spawn_radius_extra := 110.0
@export var intermission_time := 3.5

var current_wave := 0
var kill_count := 0
var living_enemy_count := 0
var is_spawning := false
var _rng := RandomNumberGenerator.new()
var _player_ref: Node2D
var _viewport_size := Vector2(1280, 720)

@onready var intermission_timer: Timer = $IntermissionTimer


func _ready() -> void:
	_rng.randomize()
	intermission_timer.timeout.connect(_start_next_wave)


func setup(player_ref: Node2D) -> void:
	_player_ref = player_ref
	_viewport_size = get_viewport_rect().size
	start_first_wave()


func start_first_wave() -> void:
	current_wave = 0
	_start_next_wave()


func _start_next_wave() -> void:
	if is_spawning:
		return
	is_spawning = true
	current_wave += 1
	emit_signal("wave_started", current_wave)

	var total_to_spawn: int = 5 + current_wave * 2
	var ranged_count: int = maxi(1, int(current_wave / 2))
	var melee_count: int = maxi(total_to_spawn - ranged_count, 1)

	for i in range(melee_count):
		_spawn_enemy(melee_scene, 0.9 + current_wave * 0.06, 1.0 + current_wave * 0.08)
	for i in range(ranged_count):
		_spawn_enemy(ranged_scene, 1.0 + current_wave * 0.08, 1.0 + current_wave * 0.10)

	is_spawning = false


func _spawn_enemy(scene: PackedScene, hp_scale: float, speed_scale: float) -> void:
	if scene == null or not is_instance_valid(_player_ref):
		return
	var enemy = scene.instantiate()
	enemy.global_position = _random_spawn_position()
	enemy.call("set_player", _player_ref)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	enemy.max_health = int(enemy.max_health * hp_scale)
	enemy.current_health = enemy.max_health
	enemy.speed = enemy.speed * speed_scale

	living_enemy_count += 1
	add_child(enemy)


func _random_spawn_position() -> Vector2:
	var center: Vector2 = _player_ref.global_position if is_instance_valid(_player_ref) else _viewport_size * 0.5
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = maxf(_viewport_size.x, _viewport_size.y) * 0.5 + spawn_radius_extra
	return center + Vector2(cos(angle), sin(angle)) * radius


func _on_enemy_died(_enemy: Node) -> void:
	living_enemy_count = maxi(living_enemy_count - 1, 0)
	kill_count += 1
	emit_signal("kill_count_changed", kill_count)
	if living_enemy_count <= 0:
		emit_signal("wave_cleared", current_wave)
		intermission_timer.start(intermission_time)
