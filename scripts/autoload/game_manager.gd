extends Node

# 全局场景路径，统一由 GameManager 控制切场，避免在各处硬编码。
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
## 设计分辨率固定 1280×720，等比例缩放时由 stretch aspect="keep" 负责留黑边。
const DESIGN_VIEWPORT := Vector2i(1280, 720)
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const MAX_WEAPONS := 6
const DEFAULT_USABLE_WEAPON_COUNT := 6  # 默认可用武器槽位数
const DEFAULT_USABLE_MAGIC_COUNT := 3  # 默认可用魔法槽位数，与武器生效数量逻辑一致
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
		"traits_path": "res://scripts/characters/rapid_shooter_traits.gd",
		"usable_weapon_count": 6,  # 默认可用武器槽位
		"usable_magic_count": 3  # 默认可用魔法槽位，与武器生效数量逻辑一致
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
		"traits_path": "res://scripts/characters/heavy_gunner_traits.gd",
		"usable_weapon_count": 6,
		"usable_magic_count": 3
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
var run_total_damage := 0  # 本局对敌人造成的总伤害（结算展示用）
var run_experience := 0  # 本局经验值
var run_level := 1  # 本局等级
var enemy_healthbar_visible := true  # 敌人血条显隐
var move_inertia_factor := 0.0  # 玩家移动惯性，0~0.9
var run_weapons: Array = []  # 本局武器列表，每项为 {id, tier}；2 同品级合成 1 高一品级
var shop_refresh_count := 0  # 本局商店刷新次数，用于计算刷新费用，新游戏/继续时重置
var run_items: Array[String] = []  # 本局已购买道具 id 列表（固化配置，品级固定）
var run_upgrades: Array = []  # 本局玩家相关升级，每项为 {id, value}，供词条系统聚合
var run_weapon_upgrades: Array[String] = []  # 本局武器相关升级 id 列表，同步武器时应用

# ---- 游戏模式 ----
var is_endless_mode := false  # 是否为无尽模式
var endless_wave_bonus := 0  # 无尽模式波次加成（用于难度计算）


## [系统] 节点入树时调用，加载武器定义、读取存档、应用设置并连接窗口缩放。
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


## [自定义] 返回角色配置字典。character_id < 0 时返回当前选中角色；深拷贝防篡改。
func get_character_data(character_id: int = -1) -> Dictionary:
	# character_id < 0 时返回当前选中角色。
	var target_id := selected_character_id if character_id < 0 else character_id
	for character in characters:
		if int(character["id"]) == target_id:
			# 深拷贝，防止调用方修改原始配置。
			return character.duplicate(true)
	return characters[0].duplicate(true)


## [自定义] 设置当前选中的角色 id。
func set_selected_character(character_id: int) -> void:
	selected_character_id = character_id


## [自定义] 设置当前选中的关卡预设 id，并 clamp 到有效范围。
func set_selected_preset_id(preset_id: int) -> void:
	selected_preset_id = clampi(preset_id, 0, LEVEL_PRESET_PATHS.size() - 1)


## [自定义] 动态加载关卡预设列表。路径来自 LEVEL_PRESET_PATHS 常量；ResourceLoader.exists 校验后 load()，
## 失败路径跳过；返回 Resource 数组供角色选择页展示。
func get_level_presets() -> Array:
	var result: Array = []
	for path in LEVEL_PRESET_PATHS:
		if ResourceLoader.exists(path):
			result.append(load(path) as Resource)
	return result


## [自定义] 根据 preset_id 加载关卡预设并填充 current_level_sequence。路径来自 LEVEL_PRESET_PATHS[preset_id]，
## 运行时 load()；preset 无效或 level_configs 为空时 sequence 为空；仅追加 LevelConfig 类型。
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


## [自定义] 返回指定波次对应的关卡配置；wave 越界时返回 null。
func get_current_level_config(wave: int) -> LevelConfig:
	if wave < 1 or wave > current_level_sequence.size():
		return null
	return current_level_sequence[wave - 1] as LevelConfig


## [自定义] 返回通关波次（关卡数量）；无配置时默认 5。
func get_victory_wave() -> int:
	if is_endless_mode:
		return 99999  # 无尽模式无通关限制
	if current_level_sequence.is_empty():
		return 5
	return current_level_sequence.size()


## [自定义] 开始无尽模式游戏。
func start_endless_mode(character_id: int) -> void:
	set_selected_character(character_id)
	is_endless_mode = true
	endless_wave_bonus = 0
	# 无尽模式使用标准预设但循环
	load_level_sequence_from_preset(0)
	# 本局资源重置
	run_currency = 500
	reset_run_experience()
	reset_run_weapons()
	get_tree().change_scene_to_file(SCENE_GAME)


## [自定义] 停止无尽模式（返回正常模式）。
func stop_endless_mode() -> void:
	is_endless_mode = false
	endless_wave_bonus = 0


## [自定义] 获取无尽模式下的动态难度加成。
func get_endless_difficulty_bonus(wave: int) -> float:
	if not is_endless_mode:
		return 1.0
	# 每过一波增加 5% 难度
	return 1.0 + (wave * 0.05)


## [自定义] 获取无尽模式下的动态精英概率。
func get_endless_elite_chance(wave: int) -> float:
	if not is_endless_mode:
		return 0.0
	# 基础 5%，每波增加 2%，最高 50%
	return minf(0.05 + wave * 0.02, 0.5)


## [自定义] 开始新游戏：设置角色、加载预设、重置本局资源、切到战斗场景。
func start_new_game(character_id: int) -> void:
	# 新游戏前先落当前角色选择。
	set_selected_character(character_id)
	load_level_sequence_from_preset(selected_preset_id)
	# 本局资源重置，避免跨局带入。新游戏默认 500 金币。
	run_currency = 500
	reset_run_experience()
	reset_run_weapons()
	get_tree().change_scene_to_file(SCENE_GAME)


## [自定义] 继续游戏（沿用角色重新开一局）：加载预设、重置本局资源、切到战斗场景。
func continue_game() -> void:
	# continue_game 当前语义是“沿用角色重新开一局”。
	load_level_sequence_from_preset(selected_preset_id)
	run_currency = 500
	reset_run_experience()
	reset_run_weapons()
	get_tree().change_scene_to_file(SCENE_GAME)


## [自定义] 切换到角色选择场景。
func open_character_select() -> void:
	get_tree().change_scene_to_file(SCENE_CHARACTER_SELECT)


## [自定义] 切换到主菜单场景。
func open_main_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


## [自定义] 保存本局战绩到内存与本地存档。
func save_run_result(wave: int, kills: int, survival_time: float) -> void:
	# 同时更新内存中的最近战绩和本地存档统计。
	last_run_result = {
		"wave": wave,
		"kills": kills,
		"survival_time": survival_time
	}
	SaveManager.update_run_result(wave, survival_time, kills, selected_character_id)


## [自定义] 增加本局金币，不低于 0。
func add_currency(amount: int) -> void:
	run_currency = maxi(run_currency + amount, 0)


## [自定义] 记录本局对敌人造成的伤害，供结算界面展示总伤害。
func add_record_damage_dealt(amount: int) -> void:
	if amount > 0:
		run_total_damage += amount


## 经验值系统：击败敌人获得经验，升级时 run_level 增加。
## 经验曲线见 GameConstants.XP_BASE、GameConstants.XP_CURVE。


## [自定义] 增加经验值，循环检查升级（可能连升多级）。
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	run_experience += amount
	# 循环检查升级，可能一次获得大量经验连升多级
	while run_experience >= get_level_up_threshold():
		run_experience -= get_level_up_threshold()
		run_level += 1


## [自定义] 返回当前等级升级所需经验值。
func get_level_up_threshold() -> int:
	return int(float(GameConstants.XP_BASE) * pow(float(run_level), GameConstants.XP_CURVE))


## [自定义] 重置经验与等级为初始值。
func reset_run_experience() -> void:
	run_experience = 0
	run_level = 1


## [自定义] 消耗金币，不足时返回 false。
func spend_currency(amount: int) -> bool:
	if run_currency < amount:
		return false
	run_currency -= amount
	return true


## [自定义] 从 SaveManager 读取设置并应用到音量、窗口、按键、血条、惯性。
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
	move_inertia_factor = clampf(float(game_cfg.get("move_inertia", 0.0)), 0.0, GameConstants.INERTIA_FACTOR_MAX)


## [自定义] 应用窗口模式（全屏/百分比/自定义尺寸），deferred 执行避免与设置菜单冲突。
func _apply_window_mode(value: String) -> void:
	# 使用 call_deferred 确保在帧末执行，避免设置菜单打开时窗口操作被吞掉
	call_deferred("_do_apply_window_mode", value)


## [自定义] 实际执行窗口模式切换：全屏/百分比/自定义分辨率，并设置 content_scale_size。
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


## [自定义] 将根窗口的 content_scale_size 设为 DESIGN_VIEWPORT，实现等比例缩放。
func _apply_content_scale_to_window(_size: Vector2i) -> void:
	var root := Engine.get_main_loop().root as Window
	if root:
		root.content_scale_size = DESIGN_VIEWPORT


## [自定义] 全屏切换后延迟一帧应用 content_scale，此时窗口尺寸已更新。
func _deferred_apply_content_scale_after_fullscreen() -> void:
	_apply_content_scale_to_window(DisplayServer.window_get_size())


## [自定义] 连接根窗口 size_changed 信号，窗口缩放时同步 content_scale。
func _connect_window_resize() -> void:
	var root := Engine.get_main_loop().root as Window
	if root and not root.size_changed.is_connected(_on_root_size_changed):
		root.size_changed.connect(_on_root_size_changed)


## [系统] 根窗口 size_changed 信号回调，窗口缩放时重新应用 content_scale。
func _on_root_size_changed() -> void:
	_apply_content_scale_to_window(DisplayServer.window_get_size())


## [自定义] 应用预设按键（wasd/arrows）。
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
	"cast_magic", "magic_prev", "magic_next"
]


## [自定义] 应用完整按键绑定；冲突时后绑定的覆盖先绑定的。
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


## [自定义] 清除指定动作的所有按键绑定。
func _clear_action_events(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)


## [自定义] 将指定动作绑定为单一按键；key_name 无效时跳过。
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


## [自定义] 获取当前按键绑定（从 InputMap 或设置），供设置页显示。
func get_key_bindings() -> Dictionary:
	var settings := SaveManager.get_settings()
	var game_cfg: Dictionary = settings.get("game", {})
	var bindings: Dictionary = game_cfg.get("key_bindings", {})
	if not bindings.is_empty():
		var result := bindings.duplicate()
		# 迁移旧版 cast_magic_2 (E) 到 cast_magic
		if result.has("cast_magic_2") and not result.has("cast_magic"):
			result["cast_magic"] = result["cast_magic_2"]
		# 新动作缺失时使用默认（Q/E 切换魔法）
		if not result.has("magic_prev") or str(result.get("magic_prev", "")).strip_edges().is_empty():
			result["magic_prev"] = "Q"
		if not result.has("magic_next") or str(result.get("magic_next", "")).strip_edges().is_empty():
			result["magic_next"] = "E"
		return result
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
	for act in ["camera_zoom_in", "camera_zoom_out", "cast_magic", "magic_prev", "magic_next"]:
		if InputMap.has_action(act):
			var evts := InputMap.action_get_events(act)
			if not evts.is_empty() and evts[0] is InputEventKey:
				bindings[act] = OS.get_keycode_string(evts[0].keycode)
			elif not bindings.has(act):
				bindings[act] = "+"
	return bindings


## [自定义] 返回武器定义池的深拷贝。
func get_weapon_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in weapon_defs:
		result.append(item.duplicate(true))
	return result


## [自定义] 按 id 查找武器定义，未找到返回空字典。
func get_weapon_def_by_id(weapon_id: String) -> Dictionary:
	for item in weapon_defs:
		if str(item.get("id", "")) == weapon_id:
			return item.duplicate(true)
	return {}


## [自定义] 清空本局武器、道具、升级、总伤害等，新游戏/继续时调用。
func reset_run_weapons() -> void:
	run_weapons.clear()
	run_total_damage = 0
	shop_refresh_count = 0
	run_items.clear()
	run_upgrades.clear()
	run_weapon_upgrades.clear()


## [自定义] 商店刷新费用：1 + refresh_count * (1 + wave * 0.15)。
func get_shop_refresh_cost(wave: int) -> int:
	var wave_coef: float = 1.0 + float(wave) * 0.15
	return maxi(1, int(1.0 + float(shop_refresh_count) * wave_coef))


## [自定义] 尝试消耗金币执行商店刷新，成功则 shop_refresh_count +1 并返回 true。
func try_spend_shop_refresh(wave: int) -> bool:
	var cost: int = get_shop_refresh_cost(wave)
	if run_currency < cost:
		return false
	run_currency -= cost
	shop_refresh_count += 1
	return true


## [自定义] 添加道具到本局，已存在则不重复。
func add_run_item(item_id: String) -> void:
	if not run_items.has(item_id):
		run_items.append(item_id)


## [自定义] 返回本局道具 id 列表的副本。
func get_run_items() -> Array[String]:
	return run_items.duplicate()


## [自定义] 添加玩家升级到本局，供词条系统聚合。
func add_run_upgrade(upgrade_id: String, value: Variant) -> void:
	run_upgrades.append({"id": upgrade_id, "value": value})


## [自定义] 返回本局玩家升级列表的副本。
func get_run_upgrades() -> Array:
	return run_upgrades.duplicate()


## [自定义] 添加武器升级到本局，同步武器时应用。
func add_run_weapon_upgrade(upgrade_id: String) -> void:
	if not run_weapon_upgrades.has(upgrade_id):
		run_weapon_upgrades.append(upgrade_id)


## [自定义] 返回本局武器升级 id 列表的副本。
func get_run_weapon_upgrades() -> Array[String]:
	return run_weapon_upgrades.duplicate()


## [自定义] 返回本局武器列表，每项为 {id, tier, random_affix_ids}。
func get_run_weapons() -> Array:
	var result: Array = []
	for w in run_weapons:
		var ra: Array = w.get("random_affix_ids", [])
		result.append({"id": str(w.get("id", "")), "tier": int(w.get("tier", 0)), "random_affix_ids": ra.duplicate()})
	return result


## [自定义] 添加武器；无上限，仅检查定义存在。
func add_run_weapon(weapon_id: String, random_affix_ids: Array = []) -> bool:
	if get_weapon_def_by_id(weapon_id).is_empty():
		return false
	# 移除容量限制，武器无上限
	run_weapons.append({"id": weapon_id, "tier": 0, "random_affix_ids": random_affix_ids.duplicate()})
	return true


## [自定义] 移除指定索引的武器，用于售卖。返回是否成功。
func remove_run_weapon(index: int) -> bool:
	if index < 0 or index >= run_weapons.size():
		return false
	run_weapons.remove_at(index)
	return true


## [自定义] 手动合并：base_index 武器品级 +1，material_index 武器移除。保留 base 的 random_affix_ids。
func merge_run_weapons(base_index: int, material_index: int) -> bool:
	if base_index < 0 or base_index >= run_weapons.size():
		return false
	if material_index < 0 or material_index >= run_weapons.size():
		return false
	if base_index == material_index:
		return false
	var base_w: Dictionary = run_weapons[base_index]
	var mat_w: Dictionary = run_weapons[material_index]
	if str(base_w.get("id", "")) != str(mat_w.get("id", "")):
		return false
	if int(base_w.get("tier", 0)) != int(mat_w.get("tier", 0)):
		return false
	var kept_affixes: Array = base_w.get("random_affix_ids", []).duplicate()
	var wid: String = str(base_w.get("id", ""))
	var new_tier: int = int(base_w.get("tier", 0)) + 1
	var lo: int = mini(base_index, material_index)
	var hi: int = maxi(base_index, material_index)
	run_weapons.remove_at(hi)
	run_weapons.remove_at(lo)
	run_weapons.insert(lo, {"id": wid, "tier": new_tier, "random_affix_ids": kept_affixes})
	return true


## [自定义] 检查是否可添加该武器（定义存在即可，无容量上限）。
func can_add_run_weapon(weapon_id: String) -> bool:
	return not get_weapon_def_by_id(weapon_id).is_empty()


## [自定义] 交换武器位置（拖拽换位）。
func reorder_run_weapons(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= run_weapons.size():
		return false
	if to_index < 0 or to_index >= run_weapons.size():
		return false
	if from_index == to_index:
		return true
	var item = run_weapons[from_index]
	run_weapons.remove_at(from_index)
	run_weapons.insert(to_index, item)
	return true


## [自定义] 交换魔法位置（拖拽换位）。
func reorder_run_magics(from_index: int, to_index: int) -> bool:
	# 魔法存储在 run_items 中，type == "magic" 的项
	var magic_items: Array[int] = []
	for i in range(run_items.size()):
		var def := _get_item_def_by_id(run_items[i])
		if str(def.get("type", "")) == "magic":
			magic_items.append(i)
	if from_index < 0 or from_index >= magic_items.size():
		return false
	if to_index < 0 or to_index >= magic_items.size():
		return false
	if from_index == to_index:
		return true
	var actual_from = magic_items[from_index]
	var actual_to = magic_items[to_index]
	var item = run_items[actual_from]
	run_items.remove_at(actual_from)
	run_items.insert(actual_to, item)
	return true


## [自定义] 按 id 查找道具定义，未找到返回空字典。
func _get_item_def_by_id(item_id: String) -> Dictionary:
	var shop_item_defs = load("res://resources/shop_item_defs.gd") as GDScript
	var shop_item_class = shop_item_defs.new()
	for item in shop_item_class.ITEM_POOL:
		if str(item.get("id", "")) == item_id:
			return item.duplicate(true)
	return {}
