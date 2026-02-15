extends Node

# 全局场景路径，统一由 GameManager 控制切场，避免在各处硬编码。
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"

# 角色配置表。
# 说明：
# - id: 角色唯一标识
# - fire_rate: 数值越小射速越快（每发间隔秒数）
# - color_scheme: 像素生成器的配色索引
var characters := [
	{
		"id": 0,
		"name": "RapidShooter",
		"max_health": 100,
		"speed": 180.0,
		"fire_rate": 0.18,
		"bullet_damage": 8,
		"bullet_speed": 520.0,
		"pellet_count": 1,
		"spread_degrees": 0.0,
		"bullet_pierce": 0,
		"color_scheme": 0
	},
	{
		"id": 1,
		"name": "HeavyGunner",
		"max_health": 130,
		"speed": 130.0,
		"fire_rate": 0.42,
		"bullet_damage": 18,
		"bullet_speed": 430.0,
		"pellet_count": 2,
		"spread_degrees": 16.0,
		"bullet_pierce": 1,
		"color_scheme": 1
	}
]

var selected_character_id := 0
# 最近一局战斗结果，当前主要用于运行期查看，持久化统计由 SaveManager 负责。
var last_run_result := {
	"wave": 0,
	"kills": 0,
	"survival_time": 0.0
}
var run_currency := 0
var enemy_healthbar_visible := true


func _ready() -> void:
	# 启动时读取上次选择的角色，保证“继续游戏”体验一致。
	var save_data := SaveManager.load_game()
	selected_character_id = int(save_data.get("last_character_id", 0))
	last_run_result = save_data.get("last_run", last_run_result)
	apply_saved_settings()


func get_character_data(character_id: int = -1) -> Dictionary:
	# character_id < 0 时返回当前选中角色。
	var target_id := selected_character_id if character_id < 0 else character_id
	for character in characters:
		if int(character["id"]) == target_id:
			# 深拷贝，防止调用方修改原始配置。
			return character.duplicate(true)
	return characters[0].duplicate(true)


func set_selected_character(character_id: int) -> void:
	selected_character_id = character_id


func start_new_game(character_id: int) -> void:
	# 新游戏前先落当前角色选择。
	set_selected_character(character_id)
	# 本局资源重置，避免跨局带入。
	run_currency = 0
	get_tree().change_scene_to_file(SCENE_GAME)


func continue_game() -> void:
	# continue_game 当前语义是“沿用角色重新开一局”。
	run_currency = 0
	get_tree().change_scene_to_file(SCENE_GAME)


func open_character_select() -> void:
	get_tree().change_scene_to_file(SCENE_CHARACTER_SELECT)


func open_main_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func save_run_result(wave: int, kills: int, survival_time: float) -> void:
	# 同时更新内存中的最近战绩和本地存档统计。
	last_run_result = {
		"wave": wave,
		"kills": kills,
		"survival_time": survival_time
	}
	SaveManager.update_run_result(wave, survival_time, kills, selected_character_id)


func add_currency(amount: int) -> void:
	run_currency = maxi(run_currency + amount, 0)


func spend_currency(amount: int) -> bool:
	if run_currency < amount:
		return false
	run_currency -= amount
	return true


func apply_saved_settings() -> void:
	var settings := SaveManager.get_settings()
	var system_cfg: Dictionary = settings.get("system", {})
	var game_cfg: Dictionary = settings.get("game", {})
	AudioManager.set_master_volume(float(system_cfg.get("master_volume", 0.70)))
	_apply_resolution_string(str(system_cfg.get("resolution", "1280x720")))
	_apply_key_preset(str(game_cfg.get("key_preset", "wasd")))
	_set_action_single_key("pause", str(game_cfg.get("pause_key", "P")))
	_set_action_single_key("toggle_enemy_hp", str(game_cfg.get("toggle_enemy_hp_key", "H")))
	enemy_healthbar_visible = bool(game_cfg.get("show_enemy_health_bar", true))


func _apply_resolution_string(value: String) -> void:
	var parts := value.split("x")
	if parts.size() != 2:
		return
	var width := int(parts[0])
	var height := int(parts[1])
	if width <= 0 or height <= 0:
		return
	DisplayServer.window_set_size(Vector2i(width, height))


func _apply_key_preset(preset: String) -> void:
	if preset == "arrows":
		_set_action_single_key("move_left", "Left")
		_set_action_single_key("move_right", "Right")
		_set_action_single_key("move_up", "Up")
		_set_action_single_key("move_down", "Down")
	else:
		_set_action_single_key("move_left", "A")
		_set_action_single_key("move_right", "D")
		_set_action_single_key("move_up", "W")
		_set_action_single_key("move_down", "S")


func _set_action_single_key(action: StringName, key_name: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == 0:
		return
	var event_key := InputEventKey.new()
	event_key.keycode = keycode
	InputMap.action_add_event(action, event_key)
