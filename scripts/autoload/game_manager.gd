extends Node

# 全局场景路径，统一由 GameManager 控制切场，避免在各处硬编码。
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
## 设计分辨率固定 1280×720，等比例缩放时由 stretch aspect="keep" 负责留黑边。
const DESIGN_VIEWPORT := Vector2i(1280, 720)
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const MAX_WEAPONS := 6
const WEAPON_DEFS_RESOURCE = preload("res://resources/weapon_defs.gd")
const LEVEL_PRESET_PATHS := [
	"res://resources/presets/preset_standard.tres",
	"res://resources/presets/preset_aquatic.tres",
	"res://resources/presets/preset_boss.tres"
]

# 角色配置表。
# 说明：
# - id: 角色唯一标识
# - fire_rate: 数值越小射速越快（每发间隔秒数）
# - color_scheme: 像素生成器的配色索引
# traits_path: 角色特质脚本路径，供 Player 加载并参与数值计算
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
		"color_scheme": 0,
		"traits_path": "res://scripts/characters/rapid_shooter_traits.gd"
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
		"color_scheme": 1,
		"traits_path": "res://scripts/characters/heavy_gunner_traits.gd"
	}
]

var weapon_defs: Array[Dictionary] = []  # 从 weapon_defs.gd 载入的武器定义池

var selected_character_id := 0
var selected_preset_id := 0
var current_level_sequence: Array = []  # 本局关卡配置数组，由预设加载

# 最近一局战斗结果，当前主要用于运行期查看，持久化统计由 SaveManager 负责。
var last_run_result := {
	"wave": 0,
	"kills": 0,
	"survival_time": 0.0
}
var run_currency := 0  # 本局金币
var run_experience := 0  # 本局经验值
var run_level := 1  # 本局等级
var enemy_healthbar_visible := true  # 敌人血条显隐
var move_inertia_factor := 0.0  # 玩家移动惯性，0~0.9
var run_weapons: Array = []  # 本局武器列表，每项为 {id, tier}；2 同品级合成 1 高一品级
var run_items: Array[String] = []  # 本局已购买道具 id 列表（固化配置，品级固定）


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


func set_selected_preset_id(preset_id: int) -> void:
	selected_preset_id = clampi(preset_id, 0, LEVEL_PRESET_PATHS.size() - 1)


func get_level_presets() -> Array:
	var result: Array = []
	for path in LEVEL_PRESET_PATHS:
		if ResourceLoader.exists(path):
			result.append(load(path) as Resource)
	return result


func load_level_sequence_from_preset(preset_id: int) -> void:
	set_selected_preset_id(preset_id)
	current_level_sequence.clear()
	if preset_id < 0 or preset_id >= LEVEL_PRESET_PATHS.size():
		preset_id = 0
	var preset: LevelPreset = load(LEVEL_PRESET_PATHS[preset_id]) as LevelPreset
	if preset and preset.level_configs.size() > 0:
		for cfg in preset.level_configs:
			if cfg is LevelConfig:
				current_level_sequence.append(cfg)


func get_current_level_config(wave: int) -> LevelConfig:
	if wave < 1 or wave > current_level_sequence.size():
		return null
	return current_level_sequence[wave - 1] as LevelConfig


func get_victory_wave() -> int:
	if current_level_sequence.is_empty():
		return 5
	return current_level_sequence.size()


func start_new_game(character_id: int) -> void:
	# 新游戏前先落当前角色选择。
	set_selected_character(character_id)
	load_level_sequence_from_preset(selected_preset_id)
	# 本局资源重置，避免跨局带入。新游戏默认 500 金币。
	run_currency = 500
	reset_run_experience()
	reset_run_weapons()
	get_tree().change_scene_to_file(SCENE_GAME)


func continue_game() -> void:
	# continue_game 当前语义是“沿用角色重新开一局”。
	load_level_sequence_from_preset(selected_preset_id)
	run_currency = 500
	reset_run_experience()
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


## 经验值系统：击败敌人获得经验，升级时 run_level 增加。
## 经验曲线：base_xp * (level ^ curve)，如 base=50, curve=1.2
const XP_BASE := 50
const XP_CURVE := 1.2


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	run_experience += amount
	# 循环检查升级，可能一次获得大量经验连升多级
	while run_experience >= get_level_up_threshold():
		run_experience -= get_level_up_threshold()
		run_level += 1


func get_level_up_threshold() -> int:
	return int(float(XP_BASE) * pow(float(run_level), XP_CURVE))


func reset_run_experience() -> void:
	run_experience = 0
	run_level = 1


func spend_currency(amount: int) -> bool:
	if run_currency < amount:
		return false
	run_currency -= amount
	return true


# 从 SaveManager 读取设置并应用到音量、窗口、按键、血条、惯性。
func apply_saved_settings() -> void:
	var settings := SaveManager.get_settings()
	var system_cfg: Dictionary = settings.get("system", {})
	var game_cfg: Dictionary = settings.get("game", {})
	AudioManager.set_master_volume(float(system_cfg.get("master_volume", 0.70)))
	_apply_window_mode(str(system_cfg.get("resolution", "100%")))
	var key_bindings: Dictionary = game_cfg.get("key_bindings", {})
	if key_bindings.is_empty():
		_apply_key_preset(str(game_cfg.get("key_preset", "wasd")))
		_set_action_single_key("pause", str(game_cfg.get("pause_key", "Escape")))
		_set_action_single_key("toggle_enemy_hp", str(game_cfg.get("toggle_enemy_hp_key", "H")))
		# camera_zoom 与 cast_magic 使用 project.godot 默认，或从 key_bindings 补充
	else:
		_apply_key_bindings(key_bindings)
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
			_apply_content_scale_to_window(DESIGN_VIEWPORT)
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
	# 设计分辨率固定 1280×720，等比例缩放
	_apply_content_scale_to_window(DESIGN_VIEWPORT)


func _apply_content_scale_to_window(_size: Vector2i) -> void:
	var root := Engine.get_main_loop().root as Window
	if root:
		root.content_scale_size = DESIGN_VIEWPORT


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


## 可配置的 11 个动作，用于按键绑定。
const BINDABLE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"pause", "toggle_enemy_hp", "camera_zoom_in", "camera_zoom_out",
	"cast_magic_1", "cast_magic_2", "cast_magic_3"
]


## 应用完整按键绑定；冲突时后绑定的覆盖先绑定的。
func _apply_key_bindings(bindings: Dictionary) -> void:
	# 先清除所有动作的键位，避免同一键被多动作共享
	var key_to_action: Dictionary = {}
	for action in BINDABLE_ACTIONS:
		var key_name: String = str(bindings.get(action, "")).strip_edges()
		if key_name.is_empty():
			continue
		if key_to_action.has(key_name):
			var old_action: StringName = key_to_action[key_name]
			_clear_action_events(old_action)
		key_to_action[key_name] = StringName(action)
	for action in BINDABLE_ACTIONS:
		var key_name: String = str(bindings.get(action, "")).strip_edges()
		if key_name.is_empty():
			_clear_action_events(StringName(action))
		else:
			_set_action_single_key(StringName(action), key_name)


func _clear_action_events(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)


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


## 获取当前按键绑定（从 InputMap 或设置），供设置页显示。
func get_key_bindings() -> Dictionary:
	var settings := SaveManager.get_settings()
	var game_cfg: Dictionary = settings.get("game", {})
	var bindings: Dictionary = game_cfg.get("key_bindings", {})
	if not bindings.is_empty():
		return bindings.duplicate()
	# 从 preset + pause_key + toggle_hp_key 构建
	var preset: String = str(game_cfg.get("key_preset", "wasd"))
	if preset == "arrows":
		bindings["move_left"] = "Left"
		bindings["move_right"] = "Right"
		bindings["move_up"] = "Up"
		bindings["move_down"] = "Down"
	else:
		bindings["move_left"] = "A"
		bindings["move_right"] = "D"
		bindings["move_up"] = "W"
		bindings["move_down"] = "S"
	bindings["pause"] = str(game_cfg.get("pause_key", "Escape"))
	bindings["toggle_enemy_hp"] = str(game_cfg.get("toggle_enemy_hp_key", "H"))
	# 从 InputMap 读取 camera_zoom 与 cast_magic 的当前值
	for act in ["camera_zoom_in", "camera_zoom_out", "cast_magic_1", "cast_magic_2", "cast_magic_3"]:
		if InputMap.has_action(act):
			var evts := InputMap.action_get_events(act)
			if not evts.is_empty() and evts[0] is InputEventKey:
				bindings[act] = OS.get_keycode_string(evts[0].keycode)
			elif not bindings.has(act):
				bindings[act] = "+"
	return bindings


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
	run_items.clear()


func add_run_item(item_id: String) -> void:
	if not run_items.has(item_id):
		run_items.append(item_id)


func get_run_items() -> Array[String]:
	return run_items.duplicate()


## 返回本局武器列表，每项为 {id, tier}。
func get_run_weapons() -> Array:
	var result: Array = []
	for w in run_weapons:
		result.append({"id": str(w.get("id", "")), "tier": int(w.get("tier", 0))})
	return result


## 添加武器；若已有同 id 同 tier 的，则 2 合 1 升品级。返回是否成功。
func add_run_weapon(weapon_id: String) -> bool:
	if get_weapon_def_by_id(weapon_id).is_empty():
		return false
	# 查找同 id 同 tier 0 的（新获得武器为 tier 0）
	var tier_to_merge := 0
	var first_idx := -1
	for i in range(run_weapons.size()):
		var w: Dictionary = run_weapons[i]
		if str(w.get("id", "")) == weapon_id and int(w.get("tier", 0)) == tier_to_merge:
			first_idx = i
			break
	if first_idx >= 0:
		# 有同品级，合并：移除 2 个，添加 1 个高一品级，递归检查
		run_weapons.remove_at(first_idx)
		var new_tier := tier_to_merge + 1
		_try_merge_weapon(weapon_id, new_tier)
		return true
	# 无同品级可合并，需检查容量
	if run_weapons.size() >= MAX_WEAPONS:
		return false
	run_weapons.append({"id": weapon_id, "tier": 0})
	return true


## 递归：若存在 2 个同 id 同 tier，则合并为 tier+1。
func _try_merge_weapon(weapon_id: String, tier: int) -> void:
	var indices: Array[int] = []
	for i in range(run_weapons.size()):
		var w: Dictionary = run_weapons[i]
		if str(w.get("id", "")) == weapon_id and int(w.get("tier", 0)) == tier:
			indices.append(i)
	if indices.size() < 2:
		# 不足 2 个，添加当前这一个
		run_weapons.append({"id": weapon_id, "tier": tier})
		return
	# 移除前 2 个
	run_weapons.remove_at(indices[1])
	run_weapons.remove_at(indices[0])
	_try_merge_weapon(weapon_id, tier + 1)


func can_add_run_weapon(weapon_id: String) -> bool:
	if get_weapon_def_by_id(weapon_id).is_empty():
		return false
	# 若有同 id 同 tier 0 的，合并不占新槽位
	var count_tier0 := 0
	for w in run_weapons:
		if str(w.get("id", "")) == weapon_id and int(w.get("tier", 0)) == 0:
			count_tier0 += 1
	if count_tier0 >= 1:
		return true
	return run_weapons.size() < MAX_WEAPONS
