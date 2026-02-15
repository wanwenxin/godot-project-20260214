extends Node2D

# 主游戏控制器：
# - 生成玩家
# - 挂接波次系统事件
# - 维护计时、暂停、死亡结算
@export var player_scene: PackedScene
@export var obstacle_count := 6
# 地形块数量配置：运行时随机铺设，便于调试地图密度。
@export var grass_count := 7
@export var shallow_water_count := 5
@export var deep_water_count := 4

var player
var survival_time := 0.0
var is_game_over := false
var intermission_left := 0.0
var _upgrade_pool := [
	{"id": "damage", "title": "Power", "desc": "Damage", "cost": 2},
	{"id": "fire_rate", "title": "Rapid", "desc": "FireRate", "cost": 2},
	{"id": "max_health", "title": "Vital", "desc": "MaxHP", "cost": 3},
	{"id": "speed", "title": "Swift", "desc": "Speed", "cost": 2},
	{"id": "bullet_speed", "title": "Velocity", "desc": "BulletSpeed", "cost": 1},
	{"id": "multi_shot", "title": "Spread", "desc": "MultiShot", "cost": 4},
	{"id": "pierce", "title": "Pierce", "desc": "Penetration", "cost": 4}
]
var _pending_upgrade_options: Array[Dictionary] = []
var _upgrade_selected := false
# 触控方向缓存（由 HUD 虚拟按键驱动）。
var _mobile_move := Vector2.ZERO

@onready var wave_manager = $WaveManager
@onready var hud = $HUD
@onready var pause_menu = $PauseMenu


func _ready() -> void:
	AudioManager.play_game_bgm()
	# 先创建玩家，再初始化依赖玩家引用的系统。
	_spawn_player()
	_spawn_terrain_map()

	wave_manager.setup(player)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.kill_count_changed.connect(_on_kill_count_changed)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	wave_manager.intermission_started.connect(_on_intermission_started)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.mobile_move_changed.connect(_on_mobile_move_changed)
	hud.pause_pressed.connect(_toggle_pause)

	hud.set_wave(1)
	hud.set_kills(0)
	hud.set_survival_time(0.0)
	hud.set_pause_hint(true)
	hud.set_health(int(player.current_health), int(player.max_health))
	hud.set_currency(GameManager.run_currency)

	# 进入游戏默认隐藏暂停菜单。
	pause_menu.set_visible_menu(false)


func _process(delta: float) -> void:
	# 死亡后停止所有运行时统计更新，仅保留结算 UI。
	if is_game_over:
		return

	# 生存计时每帧刷新到 HUD。
	survival_time += delta
	hud.set_survival_time(survival_time)
	hud.set_currency(GameManager.run_currency)

	if intermission_left > 0.0:
		intermission_left = maxf(intermission_left - delta, 0.0)
		hud.set_intermission_countdown(intermission_left)
	else:
		hud.set_intermission_countdown(0.0)

	if Input.is_action_just_pressed("pause"):
		_toggle_pause()


func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.global_position = get_viewport_rect().size * 0.5
	var character_data := GameManager.get_character_data()
	# 将角色模板参数下发给玩家（生命、移速、射速、伤害等）。
	player.set_character_data(character_data)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.damaged.connect(_on_player_damaged)
	add_child(player)


func _on_player_health_changed(current: int, max_value: int) -> void:
	hud.set_health(current, max_value)


func _on_player_damaged(_amount: int) -> void:
	AudioManager.play_hit()


func _on_wave_started(wave: int) -> void:
	hud.set_wave(wave)
	hud.show_wave_banner(wave)
	AudioManager.play_wave_start()


func _on_wave_cleared(_wave: int) -> void:
	# 波次清场后进行恢复与升级，再进入下一波倒计时。
	if not is_instance_valid(player):
		return
	player.heal(int(maxf(8.0, player.max_health * 0.12)))
	player.input_enabled = false
	_upgrade_selected = false
	_pending_upgrade_options = _roll_upgrade_options(3)
	hud.show_upgrade_options(_pending_upgrade_options, GameManager.run_currency)


func _on_kill_count_changed(kills: int) -> void:
	hud.set_kills(kills)


func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	get_tree().paused = false
	player.input_enabled = false
	# 结算时保存本局成绩（当前波次、击杀、生存时长）。
	GameManager.save_run_result(wave_manager.current_wave, wave_manager.kill_count, survival_time)
	hud.hide_upgrade_options()
	hud.show_game_over(wave_manager.current_wave, wave_manager.kill_count, survival_time)


func _toggle_pause() -> void:
	if is_game_over:
		return
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused
	# PauseMenu 是 CanvasLayer，统一通过接口控制显隐。
	pause_menu.set_visible_menu(new_paused)


func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_main_menu() -> void:
	get_tree().paused = false
	GameManager.open_main_menu()


func _roll_upgrade_options(count: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shuffled: Array = _upgrade_pool.duplicate(true)
	shuffled.shuffle()
	var result: Array[Dictionary] = []
	for i in range(mini(count - 1, shuffled.size())):
		result.append(shuffled[i])
	result.append({"id": "skip", "title": "Skip", "desc": "No Upgrade", "cost": 0})
	return result


func _on_upgrade_selected(upgrade_id: String) -> void:
	# 防重入：同一轮只允许结算一次升级选择。
	if _upgrade_selected or _pending_upgrade_options.is_empty():
		return
	var target: Dictionary = {}
	for item in _pending_upgrade_options:
		if String(item.get("id", "")) == upgrade_id:
			target = item
			break
	if target.is_empty():
		return
	var cost := int(target.get("cost", 0))
	if not GameManager.spend_currency(cost):
		return
	_upgrade_selected = true
	player.apply_upgrade(upgrade_id)
	player.input_enabled = true
	hud.hide_upgrade_options()
	# 选完升级后才开始下一波倒计时。
	wave_manager.begin_intermission()


func _on_intermission_started(duration: float) -> void:
	intermission_left = duration


func _on_mobile_move_changed(direction: Vector2) -> void:
	_mobile_move = direction
	if is_instance_valid(player):
		player.external_move_input = _mobile_move


func _spawn_terrain_map() -> void:
	# 地图分为 4 类交互区域：草地、浅水、深水、障碍物。
	var viewport := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(grass_count):
		_spawn_terrain_zone(
			Vector2(rng.randf_range(120.0, viewport.x - 120.0), rng.randf_range(100.0, viewport.y - 100.0)),
			Vector2(rng.randf_range(70.0, 130.0), rng.randf_range(60.0, 120.0)),
			Color(0.20, 0.45, 0.18, 0.45),
			"grass",
			0.88,
			0,
			1.0
		)

	for i in range(shallow_water_count):
		_spawn_terrain_zone(
			Vector2(rng.randf_range(120.0, viewport.x - 120.0), rng.randf_range(100.0, viewport.y - 100.0)),
			Vector2(rng.randf_range(76.0, 148.0), rng.randf_range(66.0, 130.0)),
			Color(0.24, 0.55, 0.80, 0.48),
			"shallow_water",
			0.72,
			0,
			1.0
		)

	for i in range(deep_water_count):
		_spawn_terrain_zone(
			Vector2(rng.randf_range(130.0, viewport.x - 130.0), rng.randf_range(110.0, viewport.y - 110.0)),
			Vector2(rng.randf_range(78.0, 128.0), rng.randf_range(70.0, 122.0)),
			Color(0.08, 0.20, 0.42, 0.56),
			"deep_water",
			0.52,
			2,
			1.2
		)

	for i in range(obstacle_count):
		# 障碍物是 StaticBody2D，玩家与敌人都被阻挡。
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var rect := ColorRect.new()
		var size := Vector2(rng.randf_range(42.0, 96.0), rng.randf_range(38.0, 88.0))
		shape.size = size
		col.shape = shape
		body.collision_layer = 8
		body.collision_mask = 0
		rect.color = Color(0.16, 0.16, 0.20, 1.0)
		rect.size = size
		rect.position = -size * 0.5
		body.position = Vector2(
			rng.randf_range(180.0, viewport.x - 180.0),
			rng.randf_range(120.0, viewport.y - 120.0)
		)
		body.add_child(col)
		body.add_child(rect)
		add_child(body)


func _spawn_terrain_zone(
	position: Vector2,
	size: Vector2,
	color: Color,
	terrain_type: String,
	speed_multiplier: float,
	damage_per_tick: int,
	damage_interval: float
) -> void:
	# 用同一个 terrain_zone.gd 统一草地/水面的行为，避免复制脚本。
	var zone := Area2D.new()
	zone.set_script(load("res://scripts/terrain_zone.gd"))
	zone.position = position
	zone.terrain_type = terrain_type
	zone.speed_multiplier = speed_multiplier
	zone.damage_per_tick = damage_per_tick
	zone.damage_interval = damage_interval

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)

	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = -size * 0.5
	zone.add_child(rect)

	add_child(zone)
