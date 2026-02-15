extends Node

# 全局场景路径，统一由 GameManager 控制切场，避免在各处硬编码。
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const MAX_WEAPONS := 6
const WEAPON_DEFS_RESOURCE = preload("res://resources/weapon_defs.gd")

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

var weapon_defs: Array[Dictionary] = []

var selected_character_id := 0
# 最近一局战斗结果，当前主要用于运行期查看，持久化统计由 SaveManager 负责。
var last_run_result := {
	"wave": 0,
	"kills": 0,
	"survival_time": 0.0
}
var run_currency := 0
var enemy_healthbar_visible := true
var move_inertia_factor := 0.0
var run_weapons: Array[String] = []


func _ready() -> void:
	# 启动时读取上次选择的角色，保证“继续游戏”体验一致。
	for item in WEAPON_DEFS_RESOURCE.WEAPON_DEFS:
		weapon_defs.append(item.duplicate(true))
	var save_data := SaveManager.load_game()
	selected_character_id = int(save_data.get("last_character_id", 0))
	last_run_result = save_data.get("last_run", last_run_result)
	apply_saved_settings()
	# 窗口手动缩放时同步更新 content_scale_size
	call_deferred("_connect_window_resize")


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
	reset_run_weapons()
	get_tree().change_scene_to_file(SCENE_GAME)


func continue_game() -> void:
	# continue_game 当前语义是“沿用角色重新开一局”。
	run_currency = 0
	reset_run_weapons()
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
	_apply_window_mode(str(system_cfg.get("resolution", "100%")))
	_apply_key_preset(str(game_cfg.get("key_preset", "wasd")))
	_set_action_single_key("pause", str(game_cfg.get("pause_key", "P")))
	_set_action_single_key("toggle_enemy_hp", str(game_cfg.get("toggle_enemy_hp_key", "H")))
	enemy_healthbar_visible = bool(game_cfg.get("show_enemy_health_bar", true))
	move_inertia_factor = clampf(float(game_cfg.get("move_inertia", 0.0)), 0.0, 0.9)


func _apply_window_mode(value: String) -> void:
	# 使用 call_deferred 确保在帧末执行，避免设置菜单打开时窗口操作被吞掉
	call_deferred("_do_apply_window_mode", value)


func _do_apply_window_mode(value: String) -> void:
	# 支持百分比窗口与全屏；同时将 content_scale_size 设为窗口尺寸，使画面填满
	var scale_factor := 1.0
	if value == "Fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		# 全屏后延迟一帧获取窗口尺寸并应用 content_scale
		call_deferred("_deferred_apply_content_scale_after_fullscreen")
		return
	elif value == "50%":
		scale_factor = 0.5
	elif value == "75%":
		scale_factor = 0.75
	elif value == "100%" or value == "":
		scale_factor = 1.0
	else:
		var parts := value.split("x")
		if parts.size() == 2 and int(parts[0]) > 0 and int(parts[1]) > 0:
			var custom_size := Vector2i(int(parts[0]), int(parts[1]))
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(custom_size)
			_apply_content_scale_to_window(custom_size)
			return
		scale_factor = 1.0
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var target_size := Vector2i(
		int(screen_size.x * scale_factor),
		int(screen_size.y * scale_factor)
	)
	target_size.x = maxi(target_size.x, 320)
	target_size.y = maxi(target_size.y, 180)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# 先设位置再设尺寸，避免部分平台下位置被覆盖
	var cx := int((screen_size.x - target_size.x) / 2.0)
	var cy := int((screen_size.y - target_size.y) / 2.0)
	DisplayServer.window_set_position(Vector2i(cx, cy))
	DisplayServer.window_set_size(target_size)
	# 将根视口 content_scale_size 设为窗口尺寸，覆盖 project.godot 的固定 1280x720，使画面填满
	_apply_content_scale_to_window(target_size)


func _apply_content_scale_to_window(size: Vector2i) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var root := Engine.get_main_loop().root as Window
	if root:
		root.content_scale_size = size


func _deferred_apply_content_scale_after_fullscreen() -> void:
	_apply_content_scale_to_window(DisplayServer.window_get_size())


func _connect_window_resize() -> void:
	var root := Engine.get_main_loop().root as Window
	if root and not root.size_changed.is_connected(_on_root_size_changed):
		root.size_changed.connect(_on_root_size_changed)


func _on_root_size_changed() -> void:
	_apply_content_scale_to_window(DisplayServer.window_get_size())


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


func get_weapon_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in weapon_defs:
		result.append(item.duplicate(true))
	return result


func get_weapon_def_by_id(weapon_id: String) -> Dictionary:
	for item in weapon_defs:
		if str(item.get("id", "")) == weapon_id:
			return item.duplicate(true)
	return {}


func reset_run_weapons() -> void:
	run_weapons.clear()


func get_run_weapons() -> Array[String]:
	return run_weapons.duplicate()


func add_run_weapon(weapon_id: String) -> bool:
	if not can_add_run_weapon(weapon_id):
		return false
	run_weapons.append(weapon_id)
	return true


func can_add_run_weapon(weapon_id: String) -> bool:
	if run_weapons.size() >= MAX_WEAPONS:
		return false
	if run_weapons.has(weapon_id):
		return false
	if get_weapon_def_by_id(weapon_id).is_empty():
		return false
	return true
