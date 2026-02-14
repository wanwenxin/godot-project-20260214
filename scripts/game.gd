extends Node2D

@export var player_scene: PackedScene

var player: Node2D
var survival_time := 0.0
var is_game_over := false

@onready var wave_manager: Node2D = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu


func _ready() -> void:
	_spawn_player()

	wave_manager.setup(player)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.kill_count_changed.connect(_on_kill_count_changed)
	wave_manager.wave_cleared.connect(_on_wave_cleared)

	hud.call("set_wave", 1)
	hud.call("set_kills", 0)
	hud.call("set_survival_time", 0.0)
	hud.call("set_pause_hint", true)
	hud.call("set_health", int(player.get("current_health")), int(player.get("max_health")))

	pause_menu.call("set_visible_menu", false)


func _process(delta: float) -> void:
	if is_game_over:
		return

	survival_time += delta
	hud.call("set_survival_time", survival_time)

	if Input.is_action_just_pressed("pause"):
		_toggle_pause()


func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.global_position = get_viewport_rect().size * 0.5
	var character_data := GameManager.get_character_data()
	player.call("set_character_data", character_data)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	add_child(player)


func _on_player_health_changed(current: int, max_value: int) -> void:
	hud.call("set_health", current, max_value)


func _on_wave_started(wave: int) -> void:
	hud.call("set_wave", wave)


func _on_wave_cleared(_wave: int) -> void:
	# Reserved for future between-wave rewards.
	pass


func _on_kill_count_changed(kills: int) -> void:
	hud.call("set_kills", kills)


func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	get_tree().paused = false
	GameManager.save_run_result(wave_manager.current_wave, wave_manager.kill_count, survival_time)
	hud.call("show_game_over", wave_manager.current_wave, wave_manager.kill_count, survival_time)


func _toggle_pause() -> void:
	if is_game_over:
		return
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused
	pause_menu.call("set_visible_menu", new_paused)


func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_main_menu() -> void:
	get_tree().paused = false
	GameManager.open_main_menu()
