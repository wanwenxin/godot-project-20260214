extends Node2D

# 主游戏控制器：
# - 生成玩家
# - 挂接波次系统事件
# - 维护计时、暂停、死亡结算
@export var player_scene: PackedScene  # 玩家场景
@export var victory_wave := 5  # 通关波次，达到后显示通关界面
# 地形块数量范围：每关在 min~max 内随机，严格无重叠。
@export var grass_count_min := 2 # 草地数量最小值
@export var grass_count_max := 4 # 草地数量最大值
@export var shallow_water_count_min := 1 # 浅水数量最小值
@export var shallow_water_count_max := 3 # 浅水数量最大值
@export var deep_water_count_min := 1 # 深水数量最小值
@export var deep_water_count_max := 2 # 深水数量最大值
@export var obstacle_count_min := 2 # 障碍物数量最小值
@export var obstacle_count_max := 4 # 障碍物数量最大值
@export var zone_area_scale := 5.0  # 单块面积倍率，线性约 sqrt 倍
@export var terrain_margin := 36.0 # 地形间距
@export var placement_attempts := 24 # 放置尝试次数
@export var water_padding := 8.0 # 水体间距
@export var obstacle_padding := 10.0 # 障碍物间距
@export var grass_padding := 4.0 # 草丛与其它地形的最小间距
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
@export var floor_tile_size := 40.0 # 地板砖尺寸
@export var floor_color_a := Color(0.78, 0.78, 0.80, 1.0) # 地板颜色A
@export var floor_color_b := Color(0.72, 0.72, 0.74, 1.0) # 地板颜色B
@export var boundary_thickness := 28.0 # 边界厚度
@export var boundary_color := Color(0.33, 0.33, 0.35, 1.0) # 边界颜色
@export var terrain_colors: Resource  # 地形色块配置，优先从此读取；空则用上方 @export 默认色
@export var camera_zoom_scale: float = 0.8  # 摄像机缩放系数（<1时为靠近地面）
@export var camera_zoom_min: float = 0.7  # 缩放下限（更近）
@export var camera_zoom_max: float = 1.3  # 缩放上限（更远）
@export var camera_zoom_step: float = 0.05  # 每次按键变化量
@export var camera_dead_zone_ratio: float = 0.30  # 玩家偏离中心超过此比例时开始跟随

var player  # 玩家节点引用
var survival_time := 0.0  # 本局生存时长（秒）
var is_game_over := false  # 死亡或通关后为 true，停止运行时统计
var intermission_left := 0.0  # 波次间隔剩余秒数
const UPGRADE_REFRESH_COST := 2  # 刷新升级选项消耗的金币
var _pending_upgrade_options: Array[Dictionary] = []  # 当前波次四选一升级项
var _upgrade_selected := false  # 防重入：本轮是否已选择升级
var _water_spawn_rects: Array[Rect2] = []  # 水域矩形，供水中敌人生成
var _playable_region: Rect2 = Rect2()  # 可玩区域，供冲刺怪等边界检测
var _obstacle_rects: Array[Rect2] = []  # 障碍物矩形，供导航烘焙时排除
var _terrain_container: Node2D  # 地形容器，波次重载时整体清除
var _terrain_layer: TileMapLayer  # 唯一地形层：先铺满默认地形，再覆盖草/水/障碍
var _terrain_atlas_rows: int = 1  # atlas 行数，用于限制 floor_row（1=仅 flat，3=flat/seaside/mountain）
const TERRAIN_TILE_SIZE := 32  # 地形瓦片像素尺寸
const TERRAIN_TILE_FLOOR_A := 0  # 地板 A 瓦片 x 坐标
const TERRAIN_TILE_FLOOR_B := 1
# default_terrain_type 对应 atlas 行号：flat=0, seaside=1, mountain=2
const TERRAIN_FLOOR_ROW_FLAT := 0
const TERRAIN_FLOOR_ROW_SEASIDE := 1
const TERRAIN_FLOOR_ROW_MOUNTAIN := 2
const TERRAIN_TILE_GRASS := 2
const TERRAIN_TILE_SHALLOW_WATER := 3
const TERRAIN_TILE_DEEP_WATER := 4
const TERRAIN_TILE_OBSTACLE := 5
const TERRAIN_TILE_BOUNDARY := 6
var _pending_start_weapon_options: Array[Dictionary] = []  # 开局武器选择候选
var _pending_shop_weapon_options: Array[Dictionary] = []  # 波次后商店武器候选
var _waves_initialized := false  # 波次管理器是否已 setup
var _ui_modal_active := false  # 升级/商店等模态面板是否打开
var _pending_area_slot := -1  # 区域施法时暂存槽位，确认/取消后清除
var _backpack_overlay: Control = null  # 商店内背包覆盖层
var _backpack_overlay_panel: Control = null  # 覆盖层内的 BackpackPanel，售卖后刷新用
# 触控方向缓存（由 HUD 虚拟按键驱动）。
var _mobile_move := Vector2.ZERO

@onready var wave_manager = $WaveManager
@onready var game_camera: Camera2D = $GameCamera2D
@onready var hud = $HUD
@onready var pause_menu = $PauseMenu
@onready var game_over_screen = $GameOverScreen
@onready var victory_screen = $VictoryScreen
@onready var world_background: ColorRect = $WorldBackground
@onready var magic_targeting_overlay: Node2D = $MagicTargetingOverlay
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D


## [系统] 节点入树时调用，生成玩家与地形、挂接波次/HUD 信号、打开开局商店。
func _ready() -> void:
	AudioManager.play_game_bgm()
	# 先创建玩家，再初始化依赖玩家引用的系统。
	_spawn_player()
	_terrain_container = Node2D.new()
	_terrain_container.name = "TerrainContainer"
	add_child(_terrain_container)
	_spawn_terrain_map()

	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.kill_count_changed.connect(_on_kill_count_changed)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	wave_manager.wave_countdown_changed.connect(_on_wave_countdown_changed)
	wave_manager.pre_spawn_countdown_started.connect(_on_pre_spawn_countdown_started)
	wave_manager.pre_spawn_countdown_changed.connect(_on_pre_spawn_countdown_changed)
	wave_manager.intermission_started.connect(_on_intermission_started)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.upgrade_refresh_requested.connect(_on_upgrade_refresh_requested)
	hud.weapon_shop_selected.connect(_on_weapon_shop_selected)
	hud.weapon_shop_refresh_requested.connect(_on_shop_refresh_requested)
	hud.weapon_shop_closed.connect(_on_shop_closed)
	hud.backpack_requested.connect(_on_backpack_requested)
	hud.backpack_sell_requested.connect(_on_weapon_sell_requested)
	hud.backpack_merge_completed.connect(_on_shop_backpack_merge_completed)
	hud.mobile_move_changed.connect(_on_mobile_move_changed)
	hud.pause_pressed.connect(_toggle_pause)

	hud.set_wave(1)
	hud.set_kills(0)
	hud.set_survival_time(0.0)
	hud.set_pause_hint(true)
	hud.set_health(int(player.current_health), int(player.max_health))
	hud.set_mana(player.current_mana, float(player.max_mana))
	hud.set_armor(player.armor)
	hud.set_currency(GameManager.run_currency)

	# 进入游戏默认隐藏暂停菜单。新游戏取消默认武器，先进入开局商店，购买后点击下一波再开始波次。
	pause_menu.set_visible_menu(false)
	player.input_enabled = false
	_open_start_shop()
	# 背景随视口尺寸变化，避免全屏/缩放时画面只占一小块。z_index 确保背景在地形之后绘制。
	world_background.z_index = -200
	call_deferred("_resize_world_background")
	get_viewport().size_changed.connect(_resize_world_background)
	# 初始化时限制缩放系数在有效范围内
	camera_zoom_scale = clampf(camera_zoom_scale, camera_zoom_min, camera_zoom_max)
	# 区域施法 overlay 默认隐藏
	if magic_targeting_overlay != null:
		magic_targeting_overlay.visible = false
		magic_targeting_overlay.cast_confirmed.connect(_on_magic_targeting_confirmed)
		magic_targeting_overlay.cast_cancelled.connect(_on_magic_targeting_cancelled)


## [自定义] 使背景填满视口，解决全屏/窗口缩放时画面只占一小块的问题。
func _resize_world_background() -> void:
	# 使背景填满视口，解决全屏/窗口缩放时画面只占一小块的问题。
	# 使用 offset 设置尺寸（Control.size 为只读，由 offset 推导）
	var vs := get_viewport_rect().size
	world_background.offset_left = 0
	world_background.offset_top = 0
	world_background.offset_right = vs.x
	world_background.offset_bottom = vs.y


## [系统] 每帧调用，更新生存计时、HUD、摄像机、波次倒计时、暂停/缩放按键。
func _process(delta: float) -> void:
	# 死亡后停止所有运行时统计更新，仅保留结算 UI。
	if is_game_over:
		return

	_update_camera()

	# 生存计时每帧刷新到 HUD。
	survival_time += delta
	hud.set_survival_time(survival_time)
	hud.set_currency(GameManager.run_currency)
	hud.set_experience(GameManager.run_experience, GameManager.get_level_up_threshold())
	hud.set_level(GameManager.run_level)
	if is_instance_valid(player):
		hud.set_mana(player.current_mana, float(player.max_mana))
		hud.set_armor(player.armor)
		hud.set_magic_ui(player.get_magic_ui_data())

	if intermission_left > 0.0:
		intermission_left = maxf(intermission_left - delta, 0.0)
		# 间隔倒计时也移至中上，与波次合并显示
		hud.set_pre_spawn_countdown(wave_manager.current_wave + 1, intermission_left)
	else:
		hud.set_pre_spawn_countdown(0, 0.0)

	if not _ui_modal_active and Input.is_action_just_pressed("pause"):
		_toggle_pause()
	if Input.is_action_just_pressed("toggle_enemy_hp"):
		_toggle_enemy_healthbar_visibility()
	# 非模态时响应摄像机缩放按键
	if not _ui_modal_active:
		if Input.is_action_just_pressed("camera_zoom_in"):
			camera_zoom_scale = minf(camera_zoom_scale + camera_zoom_step, camera_zoom_max)
		if Input.is_action_just_pressed("camera_zoom_out"):
			camera_zoom_scale = maxf(camera_zoom_scale - camera_zoom_step, camera_zoom_min)


## [自定义] 实例化玩家场景、设置角色数据、连接信号并加入场景树。
func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.global_position = get_viewport_rect().size * 0.5
	var character_data := GameManager.get_character_data()
	# 将角色模板参数下发给玩家（生命、移速、射速、伤害等）。
	player.set_character_data(character_data)
	player.set_move_inertia(GameManager.move_inertia_factor)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.damaged.connect(_on_player_damaged)
	player.request_area_targeting.connect(_on_player_request_area_targeting)
	add_child(player)


# 供 wave_manager 使用：在水中敌人生成时获取随机水域内位置。若无水域则返回视口中心。
## [自定义] 在水域矩形内随机返回一个出生点，供水中敌人生成。
func get_random_water_spawn_position() -> Vector2:
	if _water_spawn_rects.is_empty():
		return get_viewport_rect().get_center()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rect: Rect2 = _water_spawn_rects[rng.randi() % _water_spawn_rects.size()]
	# 内缩避免贴边。
	var inset := 16.0
	var inner := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset * 2.0, inset * 2.0))
	if inner.size.x <= 0 or inner.size.y <= 0:
		return rect.get_center()
	return Vector2(
		rng.randf_range(inner.position.x, inner.end.x),
		rng.randf_range(inner.position.y, inner.end.y)
	)


## [自定义] 是否存在水域出生点（_water_spawn_rects 非空）。
func has_water_spawn_positions() -> bool:
	return not _water_spawn_rects.is_empty()


# 供水中敌人生成时获取出生位置所属水域矩形。
## [自定义] 返回包含 pos 的水域矩形，供水中敌人边界检测；无则返回空 Rect2。
func get_water_rect_containing(pos: Vector2) -> Rect2:
	for rect in _water_spawn_rects:
		if rect.has_point(pos):
			return rect
	# 若无包含点，返回最近的。
	var best := Rect2()
	var best_dist := INF
	for rect in _water_spawn_rects:
		var d := pos.distance_to(rect.get_center())
		if d < best_dist:
			best_dist = d
			best = rect
	return best


# 供冲刺怪等：获取可玩区域，与地形 region 一致。
## [自定义] 返回可玩区域矩形，供波次管理器生成敌人、冲刺怪边界检测。
func get_playable_bounds() -> Rect2:
	return _playable_region


## [系统] 玩家 health_changed 信号回调，同步 HUD 血量。
func _on_player_health_changed(current: int, max_value: int) -> void:
	hud.set_health(current, max_value)


## [系统] 玩家 damaged 信号回调，播放受击音效。
func _on_player_damaged(_amount: int) -> void:
	AudioManager.play_hit()


## [系统] 波次 wave_started 信号回调，重置玩家、清除地形并重生成；地形完成后启动预生成倒计时。
func _on_wave_started(wave: int) -> void:
	hud.set_wave(wave)
	hud.show_wave_banner(wave)
	if is_instance_valid(player):
		player.global_position = _playable_region.get_center()
	if wave > 1:
		_clear_terrain()
		call_deferred("_spawn_terrain_map")
	else:
		# wave 1 地形已在 _ready 中生成，直接启动预生成倒计时
		wave_manager.start_pre_spawn_countdown()
	AudioManager.play_wave_start()


## [自定义] 清空地形容器内所有子节点。
func _clear_terrain() -> void:
	for c in _terrain_container.get_children():
		c.queue_free()


## [自定义] 动态加载默认关卡预设作为回退。路径来自 GameManager.LEVEL_PRESET_PATHS[0]，
## 运行时 load()；失败时返回带默认值的 LevelConfig。
func _get_fallback_level_config() -> LevelConfig:
	var preset: LevelPreset = load(GameManager.LEVEL_PRESET_PATHS[0]) as LevelPreset
	if preset and preset.level_configs.size() > 0 and preset.level_configs[0] is LevelConfig:
		return preset.level_configs[0] as LevelConfig
	return null


## [自定义] 清除场景中所有敌人与子弹，波次重载时调用。
## 子弹使用对象池 recycle_group 批量回收，避免 queue_free 开销。
func _clear_remaining_enemies_and_bullets() -> void:
	# 波次结束时清除未击败的敌人与所有飞行子弹。
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	ObjectPool.recycle_group("bullets")


## [系统] 波次 wave_cleared 信号回调，判断通关或进入升级/商店流程。
func _on_wave_cleared(wave: int) -> void:
	# 波次清场：清除剩余敌人与所有子弹，再进行恢复与升级。
	_clear_remaining_enemies_and_bullets()
	if not is_instance_valid(player):
		return
	# 通关判定：达到预设关卡数则显示通关界面，跳过升级/商店流程。
	if wave >= GameManager.get_victory_wave():
		is_game_over = true
		_set_ui_modal_active(false)
		GameManager.save_run_result(wave_manager.current_wave, wave_manager.kill_count, survival_time)
		hud.hide_upgrade_options()
		hud.hide_weapon_panel()
		victory_screen.show_result(wave_manager.current_wave, wave_manager.kill_count, survival_time, player)
		return
	player.heal(int(maxf(8.0, player.max_health * 0.12)))
	player.input_enabled = false
	_upgrade_selected = false
	_pending_shop_weapon_options.clear()
	_pending_upgrade_options = _roll_upgrade_options(4)
	_set_ui_modal_active(true)
	hud.show_upgrade_options(_pending_upgrade_options, GameManager.run_currency, UPGRADE_REFRESH_COST)


## [系统] 波次 kill_count_changed 信号回调，同步 HUD 击杀数。
func _on_kill_count_changed(kills: int) -> void:
	hud.set_kills(kills)


## [系统] 玩家 request_area_targeting 信号回调，显示区域施法 overlay。
func _on_player_request_area_targeting(slot: int, magic_def: Dictionary, instance: MagicBase) -> void:
	if not is_instance_valid(player) or magic_targeting_overlay == null:
		return
	_pending_area_slot = slot
	magic_targeting_overlay.start_targeting(magic_def, instance, player)


## [系统] 区域施法 overlay cast_confirmed 信号回调，在指定位置施放魔法。
func _on_magic_targeting_confirmed(world_pos: Vector2) -> void:
	if is_instance_valid(player) and _pending_area_slot >= 0:
		player.execute_area_cast(_pending_area_slot, world_pos)
	_pending_area_slot = -1


## [系统] 区域施法 overlay cast_cancelled 信号回调，取消施法并恢复输入。
func _on_magic_targeting_cancelled() -> void:
	_pending_area_slot = -1


## [系统] 玩家 died 信号回调，显示死亡结算界面。
func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	_set_ui_modal_active(false)
	get_tree().paused = false
	player.input_enabled = false
	# 结算时保存本局成绩（当前波次、击杀、生存时长）。
	GameManager.save_run_result(wave_manager.current_wave, wave_manager.kill_count, survival_time)
	hud.hide_upgrade_options()
	hud.hide_weapon_panel()
	game_over_screen.show_result(wave_manager.current_wave, wave_manager.kill_count, survival_time, player)


## [自定义] 切换暂停状态，显示/隐藏暂停菜单。
func _toggle_pause() -> void:
	if is_game_over:
		return
	if _ui_modal_active:
		return
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused
	# PauseMenu 是 CanvasLayer，统一通过接口控制显隐。
	pause_menu.set_visible_menu(new_paused)


## [自定义] 切换敌人血条显隐，并保存到设置。
func _toggle_enemy_healthbar_visibility() -> void:
	GameManager.enemy_healthbar_visible = not GameManager.enemy_healthbar_visible
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("set_healthbar_visible"):
			enemy.set_healthbar_visible(GameManager.enemy_healthbar_visible)
	var settings := SaveManager.get_settings()
	var game_cfg: Dictionary = settings.get("game", {})
	game_cfg["show_enemy_health_bar"] = GameManager.enemy_healthbar_visible
	settings["game"] = game_cfg
	SaveManager.set_settings(settings)


## [自定义] 返回玩家节点引用，供暂停菜单展示角色信息。
func get_player_for_pause() -> Node:
	# 供暂停菜单获取玩家引用以展示数值与装备。
	return player if is_instance_valid(player) else null


## [自定义] 重新加载战斗场景，开始新局。
func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## [自定义] 切换到主菜单场景。
func go_main_menu() -> void:
	get_tree().paused = false
	GameManager.open_main_menu()


## [自定义] 从 UpgradeDefs 随机抽取 count 项，含 reward_value 与 reward_text；升级免费，刷新消耗金币。
func _roll_upgrade_options(count: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool: Array = UpgradeDefs.UPGRADE_POOL.duplicate(true)
	pool.shuffle()
	var result: Array[Dictionary] = []
	var level: int = GameManager.run_level
	for i in range(mini(count, pool.size())):
		var item: Dictionary = pool[i].duplicate(true)
		var reward_val = UpgradeDefs.get_reward_value(item, level)
		item["reward_value"] = reward_val
		item["reward_text"] = _format_upgrade_reward(str(item.get("id", "")), reward_val)
		result.append(item)
	return result


## [自定义] 将升级奖励值格式化为 UI 展示字符串（如 +10 HP、+0.5/s）。
func _format_upgrade_reward(upgrade_id: String, value: Variant) -> String:
	if value == null:
		return ""
	if value is float:
		var v_float: float = value
		if upgrade_id == "lifesteal_chance":
			return "+%.0f%%" % (v_float * 100.0)
		return "+%.1f" % v_float
	var v: int = int(value)
	if upgrade_id == "max_health":
		return "+%d HP" % v
	if upgrade_id == "max_mana":
		return "+%d MP" % v
	if upgrade_id == "armor":
		return "+%d" % v
	if upgrade_id == "speed":
		return "+%.0f" % float(v)
	if upgrade_id in ["melee_damage", "ranged_damage", "damage"]:
		return "+%d" % v
	if upgrade_id == "health_regen":
		return "+%.1f/s" % float(v)
	if upgrade_id == "mana_regen":
		return "+%.1f/s" % float(v)
	return "+%d" % v


## [系统] HUD upgrade_refresh_requested 信号回调，消耗金币刷新升级选项。
func _on_upgrade_refresh_requested() -> void:
	if GameManager.run_currency < UPGRADE_REFRESH_COST:
		return
	if not GameManager.spend_currency(UPGRADE_REFRESH_COST):
		return
	_pending_upgrade_options = _roll_upgrade_options(4)
	hud.show_upgrade_options(_pending_upgrade_options, GameManager.run_currency, UPGRADE_REFRESH_COST)


## [系统] HUD upgrade_selected 信号回调，应用升级并打开商店。
func _on_upgrade_selected(upgrade_id: String) -> void:
	# 防重入：同一轮只允许结算一次升级选择。
	if _upgrade_selected or _pending_upgrade_options.is_empty():
		return
	if upgrade_id == "skip":
		_upgrade_selected = true
		hud.hide_upgrade_options()
		_open_shop_after_upgrade()
		return
	var target: Dictionary = {}
	for item in _pending_upgrade_options:
		if str(item.get("id", "")) == upgrade_id:
			target = item
			break
	if target.is_empty():
		return
	_upgrade_selected = true
	var reward_val = target.get("reward_value")
	# 武器相关升级：加入 run_weapon_upgrades 并传递给每把武器；玩家相关：加入 run_upgrades 由词条系统聚合。
	const WEAPON_UPGRADE_IDS := ["fire_rate", "bullet_speed", "multi_shot", "pierce"]
	if upgrade_id in WEAPON_UPGRADE_IDS:
		GameManager.add_run_weapon_upgrade(upgrade_id)
		player.apply_upgrade(upgrade_id, reward_val)
	else:
		GameManager.add_run_upgrade(upgrade_id, reward_val)
		AffixManager.refresh_player(player)
	hud.hide_upgrade_options()
	_open_shop_after_upgrade()


## [自定义] 打开开局商店（波次 0），玩家购买后点击下一波再开始波次 1。
func _open_start_shop() -> void:
	# 开局商店：波次 0，玩家购买后点击下一波再开始波次 1
	_pending_shop_weapon_options = _roll_shop_items(4)
	_set_ui_modal_active(true)
	var stats: Dictionary = player.get_full_stats_for_pause() if is_instance_valid(player) and player.has_method("get_full_stats_for_pause") else {}
	stats["wave"] = 0
	hud.show_weapon_shop(_pending_shop_weapon_options, GameManager.run_currency, player.get_weapon_capacity_left(), 0, stats)


## [自定义] 升级完成后打开波次商店。
func _open_shop_after_upgrade() -> void:
	_pending_shop_weapon_options = _roll_shop_items(4)
	_set_ui_modal_active(true)
	var stats: Dictionary = player.get_full_stats_for_pause() if is_instance_valid(player) and player.has_method("get_full_stats_for_pause") else {}
	stats["wave"] = wave_manager.current_wave
	hud.show_weapon_shop(_pending_shop_weapon_options, GameManager.run_currency, player.get_weapon_capacity_left(), wave_manager.current_wave, stats)


## [系统] HUD weapon_shop_refresh_requested 信号回调，消耗金币刷新商店选项。
func _on_shop_refresh_requested() -> void:
	var wave: int = wave_manager.current_wave
	if not GameManager.try_spend_shop_refresh(wave):
		return
	_pending_shop_weapon_options = _roll_shop_items(4)
	var stats: Dictionary = player.get_full_stats_for_pause() if is_instance_valid(player) and player.has_method("get_full_stats_for_pause") else {}
	stats["wave"] = wave
	hud.show_weapon_shop(_pending_shop_weapon_options, GameManager.run_currency, player.get_weapon_capacity_left(), wave, stats)
	hud.set_currency(GameManager.run_currency)


## [系统] HUD weapon_shop_closed 信号回调，关闭商店并开始波次或完成波次结算。
func _on_shop_closed() -> void:
	_set_ui_modal_active(false)
	hud.hide_weapon_panel()
	if not _waves_initialized:
		# 开局商店关闭：开始波次 1
		_waves_initialized = true
		player.input_enabled = true
		wave_manager.setup(player)
	else:
		_finish_wave_settlement()


## [系统] HUD backpack_requested 信号回调，显示商店内背包覆盖层。
func _on_backpack_requested() -> void:
	_show_backpack_from_shop()


## [自定义] 商店内打开背包覆盖层，shop_context=true 时显示售卖/合并按钮。
## 覆盖层复用：关闭时仅 hide，再次打开时 show + set_stats，避免重复 load/new BackpackPanel。
func _show_backpack_from_shop() -> void:
	# 复用已存在的覆盖层
	if _backpack_overlay != null and is_instance_valid(_backpack_overlay) and _backpack_overlay_panel != null:
		_backpack_overlay.visible = true
		hud.move_child(_backpack_overlay, hud.get_child_count() - 1)
		var stats: Dictionary = {}
		if is_instance_valid(player) and player.has_method("get_full_stats_for_pause"):
			stats = player.get_full_stats_for_pause()
		stats["wave"] = wave_manager.current_wave
		_backpack_overlay_panel.set_stats(stats, true)
		return
	var overlay := Panel.new()
	overlay.name = "BackpackOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_style := StyleBoxFlat.new()
	theme_style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	theme_style.set_border_width_all(0)
	overlay.add_theme_stylebox_override("panel", theme_style)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	overlay.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var close_btn := Button.new()
	close_btn.text = LocalizationManager.tr_key("common.close")
	close_btn.pressed.connect(_on_backpack_overlay_closed.bind(overlay))
	vbox.add_child(close_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var backpack_panel: VBoxContainer = (load("res://scripts/ui/backpack_panel.gd") as GDScript).new()
	backpack_panel.name = "BackpackPanel"
	backpack_panel.add_theme_constant_override("separation", 12)
	backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(backpack_panel)
	_backpack_overlay = overlay
	_backpack_overlay_panel = backpack_panel
	hud.add_child(overlay)
	hud.move_child(overlay, hud.get_child_count() - 1)
	var stats: Dictionary = {}
	if is_instance_valid(player) and player.has_method("get_full_stats_for_pause"):
		stats = player.get_full_stats_for_pause()
	stats["wave"] = wave_manager.current_wave
	backpack_panel.set_stats(stats, true)
	backpack_panel.sell_requested.connect(_on_weapon_sell_requested)
	backpack_panel.merge_completed.connect(_on_backpack_overlay_merge_completed)


## [系统] 背包覆盖层关闭按钮回调。复用模式：仅 hide，不 queue_free。
func _on_backpack_overlay_closed(overlay: Control) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false


## [系统] 商店背包 Tab 内嵌面板 merge_completed 信号回调，刷新商店背包显示。
func _on_shop_backpack_merge_completed() -> void:
	var stats: Dictionary = {}
	if is_instance_valid(player) and player.has_method("get_full_stats_for_pause"):
		stats = player.get_full_stats_for_pause()
	stats["wave"] = wave_manager.current_wave
	if hud.has_method("refresh_shop_backpack"):
		hud.refresh_shop_backpack(stats)


## [系统] 商店背包覆盖层 merge_completed 信号回调，刷新覆盖层内背包显示。
func _on_backpack_overlay_merge_completed() -> void:
	if _backpack_overlay_panel == null or not is_instance_valid(_backpack_overlay_panel):
		return
	var stats: Dictionary = {}
	if is_instance_valid(player) and player.has_method("get_full_stats_for_pause"):
		stats = player.get_full_stats_for_pause()
	_backpack_overlay_panel.set_stats(stats, true)


## [系统] 背包售卖请求回调，移除武器、增加金币、刷新玩家与 HUD。
func _on_weapon_sell_requested(weapon_index: int) -> void:
	var run_weapons := GameManager.get_run_weapons()
	if weapon_index < 0 or weapon_index >= run_weapons.size():
		return
	var w: Dictionary = run_weapons[weapon_index]
	var wid: String = str(w.get("id", ""))
	var def := GameManager.get_weapon_def_by_id(wid)
	if def.is_empty():
		return
	var base_cost: int = int(def.get("base_cost", 5))
	var wave: int = wave_manager.current_wave
	var wave_coef: float = 1.0 + float(wave) * 0.15
	var tier_coef: float = TierConfig.get_damage_multiplier(int(w.get("tier", 0)))
	var sell_price: int = maxi(1, int(float(base_cost) * tier_coef * wave_coef * 0.3))
	if not GameManager.remove_run_weapon(weapon_index):
		return
	GameManager.add_currency(sell_price)
	if is_instance_valid(player):
		player.sync_weapons_from_run(GameManager.get_run_weapons())
	hud.set_currency(GameManager.run_currency)
	# 刷新背包覆盖层与商店 Tab 内嵌背包
	var stats: Dictionary = {}
	if is_instance_valid(player) and player.has_method("get_full_stats_for_pause"):
		stats = player.get_full_stats_for_pause()
	stats["wave"] = wave_manager.current_wave
	if _backpack_overlay_panel != null and is_instance_valid(_backpack_overlay_panel) and _backpack_overlay_panel.has_method("set_stats"):
		_backpack_overlay_panel.set_stats(stats, true)
	if hud.has_method("refresh_shop_backpack"):
		hud.refresh_shop_backpack(stats)


## [系统] 波次 wave_countdown_changed 信号回调，传递波次号给 HUD 合并显示。
func _on_wave_countdown_changed(seconds_left: float) -> void:
	hud.set_wave_countdown(wave_manager.current_wave, seconds_left)


## [系统] 预生成倒计时开始，HUD 显示合并的波次+倒计时。
func _on_pre_spawn_countdown_started(_duration: float) -> void:
	hud.set_pre_spawn_countdown(wave_manager.current_wave, _duration)


## [系统] 预生成倒计时每帧更新。
func _on_pre_spawn_countdown_changed(seconds_left: float) -> void:
	hud.set_pre_spawn_countdown(wave_manager.current_wave, seconds_left)


## [系统] 波次 intermission_started 信号回调，记录间隔剩余时间。
func _on_intermission_started(duration: float) -> void:
	intermission_left = duration


## [系统] HUD mobile_move_changed 信号回调，更新触控移动方向缓存。
func _on_mobile_move_changed(direction: Vector2) -> void:
	_mobile_move = direction
	if is_instance_valid(player):
		player.external_move_input = _mobile_move


## [自定义] 打开开局武器选择面板（四选一）。
func _start_weapon_pick() -> void:
	player.input_enabled = false
	_pending_start_weapon_options = _roll_weapon_shop_options(3)
	if _pending_start_weapon_options.is_empty():
		# 理论上不会为空，兜底保证流程继续。
		_waves_initialized = true
		player.input_enabled = true
		wave_manager.setup(player)
		return
	_set_ui_modal_active(true)
	hud.show_start_weapon_pick(_pending_start_weapon_options)


## [系统] 开局武器选择回调，装备武器并开始波次 1。
func _on_start_weapon_selected(weapon_id: String) -> void:
	if _pending_start_weapon_options.is_empty():
		return
	var selected := weapon_id
	if selected == "" or selected == "skip":
		selected = str(_pending_start_weapon_options[0].get("id", ""))
	if not _equip_weapon_to_player(selected, false):
		return
	_set_ui_modal_active(false)
	hud.hide_weapon_panel()
	player.input_enabled = true
	if not _waves_initialized:
		_waves_initialized = true
		wave_manager.setup(player)


## [系统] 波次商店武器选择回调，购买并装备武器或道具。
func _on_weapon_shop_selected(weapon_id: String) -> void:
	if _pending_shop_weapon_options.is_empty():
		return
	var picked: Dictionary = {}
	var picked_idx := -1
	for i in range(_pending_shop_weapon_options.size()):
		if str(_pending_shop_weapon_options[i].get("id", "")) == weapon_id:
			picked = _pending_shop_weapon_options[i]
			picked_idx = i
			break
	if picked.is_empty():
		return
	var cost := int(picked.get("cost", 0))
	if not GameManager.spend_currency(cost):
		return
	var item_type := str(picked.get("type", "weapon"))
	if item_type == "attribute":
		# 购买道具：仅加入 run_items，效果由词条系统聚合；刷新后应用。
		GameManager.add_run_item(str(picked.get("id", "")))
		AffixManager.refresh_player(player)
	elif item_type == "magic":
		if not player.equip_magic(weapon_id):
			GameManager.add_currency(cost)
			return
	else:
		var random_affixes: Array = picked.get("random_affix_ids", [])
		if not _equip_weapon_to_player(weapon_id, true, random_affixes):
			GameManager.add_currency(cost)
			return
	# 购买后移除该商品
	_pending_shop_weapon_options.remove_at(picked_idx)
	hud.set_currency(GameManager.run_currency)
	# 全部购买完则自动刷新；否则刷新显示
	if _pending_shop_weapon_options.is_empty():
		_pending_shop_weapon_options = _roll_shop_items(4)
	var stats: Dictionary = player.get_full_stats_for_pause() if is_instance_valid(player) and player.has_method("get_full_stats_for_pause") else {}
	stats["wave"] = wave_manager.current_wave
	hud.show_weapon_shop(_pending_shop_weapon_options, GameManager.run_currency, player.get_weapon_capacity_left(), wave_manager.current_wave, stats)


## [自定义] 从武器定义中排除已装备的，随机抽取 count 项作为开局武器候选。
func _roll_weapon_shop_options(count: int) -> Array[Dictionary]:
	var defs := GameManager.get_weapon_defs()
	var owned: Array[String] = player.get_equipped_weapon_ids()
	var filtered: Array[Dictionary] = []
	for item in defs:
		var id := str(item.get("id", ""))
		if owned.has(id):
			continue
		filtered.append(item)
	filtered.shuffle()
	var result: Array[Dictionary] = []
	for i in range(mini(count, filtered.size())):
		result.append(filtered[i])
	return result


## [自定义] 根据武器类型（melee/ranged）随机抽取词条，数量在 count_min~count_max 之间。
func _roll_random_weapon_affixes(weapon_type: String, count_min: int, count_max: int) -> Array:
	var pool: Array = WeaponAffixDefs.WEAPON_AFFIX_POOL
	var filtered: Array[Dictionary] = []
	for a in pool:
		var wt: String = str(a.get("weapon_type", "both"))
		if wt == "both" or wt == weapon_type:
			filtered.append(a)
	if filtered.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n: int = rng.randi_range(count_min, count_max)
	n = mini(n, filtered.size())
	filtered.shuffle()
	var ids: Array = []
	for i in range(n):
		ids.append(str(filtered[i].get("id", "")))
	return ids


## [自定义] 商店商品：武器 + 道具混合，价格随波次上涨。武器随机附加 0~2 个词条（近战/远程/通用）。
func _roll_shop_items(count: int) -> Array[Dictionary]:
	var wave: int = wave_manager.current_wave
	var result: Array[Dictionary] = []
	var weapon_defs := GameManager.get_weapon_defs()
	var weapon_candidates: Array[Dictionary] = []
	for item in weapon_defs:
		var w: Dictionary = item.duplicate(true)
		w["type"] = "weapon"
		w["cost"] = ShopItemDefs.get_price_with_tier(int(item.get("base_cost", 5)), 0, wave)
		w["random_affix_ids"] = _roll_random_weapon_affixes(str(item.get("type", "melee")), 0, 2)
		weapon_candidates.append(w)
	var owned_magics: Array[String] = player.get_equipped_magic_ids()
	var magic_slots_full: bool = owned_magics.size() >= 3
	var item_candidates: Array[Dictionary] = []
	for item in ShopItemDefs.ITEM_POOL:
		if str(item.get("type", "")) == "magic":
			var mid := str(item.get("id", ""))
			if magic_slots_full and not owned_magics.has(mid):
				continue
		var it: Dictionary = item.duplicate(true)
		it["cost"] = ShopItemDefs.get_price_with_tier(int(it.get("base_cost", 5)), 0, wave)
		item_candidates.append(it)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# 混合池：约一半武器、一半道具
	var mixed: Array[Dictionary] = []
	for w in weapon_candidates:
		mixed.append(w)
	for it in item_candidates:
		mixed.append(it)
	mixed.shuffle()
	for i in range(mini(count, mixed.size())):
		result.append(mixed[i])
	return result


## [自定义] 将武器装备到玩家，need_capacity 为 true 时检查容量。
func _equip_weapon_to_player(weapon_id: String, need_capacity: bool, random_affix_ids: Array = []) -> bool:
	if need_capacity and player.get_weapon_capacity_left() <= 0:
		return false
	return player.equip_weapon_by_id(weapon_id, random_affix_ids)


## [自定义] 完成波次结算：关闭模态、恢复输入，立即开始下一波（重置玩家→刷新地图→倒计时→生成敌人）。
func _finish_wave_settlement() -> void:
	_set_ui_modal_active(false)
	player.input_enabled = true
	wave_manager.start_next_wave_now()


## [自定义] 设置模态状态，true 时暂停游戏并隐藏暂停菜单。
func _set_ui_modal_active(value: bool) -> void:
	_ui_modal_active = value
	if _ui_modal_active:
		get_tree().paused = true
		pause_menu.set_visible_menu(false)
	else:
		get_tree().paused = false


## [自定义] 从 terrain_colors 资源或 @export 默认值获取地形颜色；key 为 terrain_color_config 属性名。
func _get_terrain_color(key: String, fallback: Color) -> Color:
	if terrain_colors != null:
		var c = terrain_colors.get(key)
		if c is Color:
			return c
	return fallback


## [自定义] 更新摄像机：缩放、跟随；当地图大于可视区域时，保持玩家偏离中心不超过 camera_dead_zone_ratio。
func _update_camera() -> void:
	if game_camera == null or not is_instance_valid(player):
		return
	var viewport_size := get_viewport_rect().size
	var zoom_val := 1.0 / camera_zoom_scale
	game_camera.zoom = Vector2(zoom_val, zoom_val)
	var visible_size := viewport_size / zoom_val
	if _playable_region.size.x <= visible_size.x and _playable_region.size.y <= visible_size.y:
		# 地图可完全覆盖时仍跟随玩家，保持角色在画面中心
		game_camera.position = player.global_position
		return
	# 地图大于可视区域，跟随玩家，保持玩家在 30% 死区内
	var dead_half := visible_size * camera_dead_zone_ratio * 0.5
	var cam_pos: Vector2 = game_camera.position
	var player_pos: Vector2 = player.global_position
	var dx: float = player_pos.x - cam_pos.x
	var dy: float = player_pos.y - cam_pos.y
	if absf(dx) > dead_half.x:
		cam_pos.x = player_pos.x - signf(dx) * dead_half.x
	if absf(dy) > dead_half.y:
		cam_pos.y = player_pos.y - signf(dy) * dead_half.y
	# 限制摄像机在 region 内，避免显示区域外
	var half_vis := visible_size * 0.5
	cam_pos.x = clampf(cam_pos.x, _playable_region.position.x + half_vis.x, _playable_region.end.x - half_vis.x)
	cam_pos.y = clampf(cam_pos.y, _playable_region.position.y + half_vis.y, _playable_region.end.y - half_vis.y)
	game_camera.position = cam_pos


## [自定义] 生成可玩区域：地板、水域、草地、障碍物、边界；依赖 _setup_terrain_tilemap 与 _spawn_terrain_zone。
func _spawn_terrain_map() -> void:
	var cfg: LevelConfig = GameManager.get_current_level_config(maxi(1, wave_manager.current_wave))
	if cfg == null:
		cfg = _get_fallback_level_config()
	var params: Dictionary = cfg.get_terrain_params() if cfg != null else {}
	# 簇团式分层生成：深水 -> 浅水 -> 障碍 -> 草丛。所有地形严格无重叠。
	var viewport := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var zone_scale: float = params.get("zone_area_scale", zone_area_scale)
	var linear_scale := sqrt(zone_scale)
	# 每关各地形数量在配置范围内随机。
	var deep_water_count := rng.randi_range(params.get("deep_water_count_min", deep_water_count_min), params.get("deep_water_count_max", deep_water_count_max))
	var shallow_water_count := rng.randi_range(params.get("shallow_water_count_min", shallow_water_count_min), params.get("shallow_water_count_max", shallow_water_count_max))
	var obstacle_count := rng.randi_range(params.get("obstacle_count_min", obstacle_count_min), params.get("obstacle_count_max", obstacle_count_max))
	var grass_count := rng.randi_range(params.get("grass_count_min", grass_count_min), params.get("grass_count_max", grass_count_max))
	var margin: float = params.get("terrain_margin", terrain_margin)
	var size_scale: float = params.get("map_size_scale", 1.0)
	var base_size := Vector2(
		maxf(64.0, viewport.x - margin * 2.0),
		maxf(64.0, viewport.y - margin * 2.0)
	)
	var region := Rect2(Vector2(margin, margin), base_size * size_scale)
	var water_occupied: Array[Rect2] = []
	var solid_occupied: Array[Rect2] = []
	var deep_water_color := _get_terrain_color("deep_water", Color(0.08, 0.20, 0.42, 0.56))
	var shallow_water_color := _get_terrain_color("shallow_water", Color(0.24, 0.55, 0.80, 0.48))
	_setup_terrain_tilemap()
	var has_special_terrain := (deep_water_count + shallow_water_count + obstacle_count + grass_count) > 0
	var default_type: String = params.get("default_terrain_type", "flat")
	_spawn_walkable_floor(region, default_type, not has_special_terrain)

	placement_attempts = int(params.get("placement_attempts", placement_attempts))
	var water_pad: float = params.get("water_padding", water_padding)
	var obstacle_pad: float = params.get("obstacle_padding", obstacle_padding)
	var grass_pad: float = params.get("grass_padding", grass_padding)
	# 簇团中心：在 region 内随机取点，后续围绕中心生成块。
	var deep_centers := _make_cluster_centers(params.get("deep_water_cluster_count", deep_water_cluster_count), region, rng)
	var shallow_centers := _make_cluster_centers(params.get("shallow_water_cluster_count", shallow_water_cluster_count), region, rng)
	var grass_centers := _make_cluster_centers(params.get("grass_cluster_count", grass_cluster_count), region, rng)

	# 深水：簇团式生成，写入 water_occupied 供浅水避让。
	var placed_deep := _spawn_clustered_zones(
		deep_water_count,
		deep_centers,
		params.get("deep_water_cluster_items", deep_water_cluster_items),
		Vector2(78.0, 70.0) * linear_scale,
		Vector2(128.0, 122.0) * linear_scale,
		params.get("deep_water_cluster_radius", deep_water_cluster_radius) * linear_scale,
		region,
		deep_water_color,
		"deep_water",
		0.52,
		2,
		1.2,
		water_occupied,
		water_pad,
		true,
		rng
	)
	# 浅水：与深水互斥，共用 water_occupied。
	var placed_shallow := _spawn_clustered_zones(
		shallow_water_count,
		shallow_centers,
		params.get("shallow_water_cluster_items", shallow_water_cluster_items),
		Vector2(76.0, 66.0) * linear_scale,
		Vector2(148.0, 130.0) * linear_scale,
		params.get("shallow_water_cluster_radius", shallow_water_cluster_radius) * linear_scale,
		region,
		shallow_water_color,
		"shallow_water",
		0.72,
		0,
		1.0,
		water_occupied,
		water_pad,
		true,
		rng
	)
	# 兜底：簇团不足时，补少量全图散点，降低“未达目标数量”的概率。
	if placed_deep < deep_water_count:
		placed_deep += _spawn_scattered_zones(
			deep_water_count - placed_deep,
			Vector2(78.0, 70.0) * linear_scale,
			Vector2(128.0, 122.0) * linear_scale,
			region,
			deep_water_color,
			"deep_water",
			0.52,
			2,
			1.2,
		water_occupied,
		water_pad,
		rng,
		56.0 * linear_scale
		)
	if placed_shallow < shallow_water_count:
		placed_shallow += _spawn_scattered_zones(
			shallow_water_count - placed_shallow,
			Vector2(76.0, 66.0) * linear_scale,
			Vector2(148.0, 130.0) * linear_scale,
			region,
			shallow_water_color,
			"shallow_water",
			0.72,
			0,
			1.0,
		water_occupied,
		water_pad,
		rng,
		56.0 * linear_scale
		)
	# 障碍物：避让水域与已生成障碍，全图散布。
	_obstacle_rects.clear()
	var hard_occupied: Array[Rect2] = []
	hard_occupied.append_array(water_occupied)
	hard_occupied.append_array(solid_occupied)
	var placed_obstacles := _spawn_scattered_obstacles(
		obstacle_count,
		Vector2(42.0, 38.0) * linear_scale,
		Vector2(96.0, 88.0) * linear_scale,
		region,
		hard_occupied,
		solid_occupied,
		obstacle_pad,
		rng
	)
	# 草丛：严格无重叠，避让水域与障碍，簇团式生成。
	var all_occupied: Array[Rect2] = []
	all_occupied.append_array(water_occupied)
	all_occupied.append_array(solid_occupied)
	var placed_grass := _spawn_clustered_grass(
		grass_count,
		grass_centers,
		params.get("grass_cluster_items", grass_cluster_items),
		Vector2(70.0, 60.0) * linear_scale,
		Vector2(130.0, 120.0) * linear_scale,
		params.get("grass_cluster_radius", grass_cluster_radius) * linear_scale,
		region,
		all_occupied,
		grass_pad,
		rng
	)
	if placed_deep < deep_water_count or placed_shallow < shallow_water_count or placed_obstacles < obstacle_count or placed_grass < grass_count:
		push_warning("Terrain placement reached limits: deep=%d/%d shallow=%d/%d obstacle=%d/%d grass=%d/%d" % [
			placed_deep, deep_water_count, placed_shallow, shallow_water_count, placed_obstacles, obstacle_count, placed_grass, grass_count
		])
	_water_spawn_rects.clear()
	_water_spawn_rects.append_array(water_occupied)
	_playable_region = region
	_spawn_world_bounds(region)
	call_deferred("_bake_navigation")
	# 地图刷新完成，启动预生成倒计时；倒计时结束后 wave_manager 生成第 1 批敌人。
	wave_manager.start_pre_spawn_countdown()

## [自定义] 在 region 内随机生成 count 个集群中心点。
func _make_cluster_centers(count: int, region: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var safe_count := maxi(1, count)
	for i in range(safe_count):
		var p := Vector2(
			rng.randf_range(region.position.x, region.end.x),
			rng.randf_range(region.position.y, region.end.y)
		)
		centers.append(p)
	return centers


## [自定义] 在集群中心周围生成地形区域（水域/草地）。
func _spawn_clustered_zones(
	total_count: int,
	centers: Array[Vector2],
	items_per_cluster: Vector2i,
	size_min: Vector2,
	size_max: Vector2,
	cluster_radius: float,
	region: Rect2,
	color: Color,
	terrain_type: String,
	speed_multiplier: float,
	damage_per_tick: int,
	damage_interval: float,
	occupied: Array[Rect2],
	padding: float,
	write_to_occupied: bool,
	rng: RandomNumberGenerator
) -> int:
	var placed := 0
	for center in centers:
		if placed >= total_count:
			break
		var items := rng.randi_range(items_per_cluster.x, items_per_cluster.y)
		for i in range(items):
			if placed >= total_count:
				break
			var item := _try_place_rect(size_min, size_max, center, cluster_radius, region, occupied, padding, placement_attempts, rng)
			if item.is_empty():
				continue
			_spawn_terrain_zone(
				item["position"],
				item["size"],
				color,
				terrain_type,
				speed_multiplier,
				damage_per_tick,
				damage_interval
			)
			if write_to_occupied:
				occupied.append(item["rect"])
			placed += 1
	return placed


## [自定义] 在分散的格子内生成地形区域。
func _spawn_scattered_zones(
	total_count: int,
	size_min: Vector2,
	size_max: Vector2,
	region: Rect2,
	color: Color,
	terrain_type: String,
	speed_multiplier: float,
	damage_per_tick: int,
	damage_interval: float,
	occupied: Array[Rect2],
	padding: float,
	rng: RandomNumberGenerator,
	scatter_radius: float = 56.0
) -> int:
	var placed := 0
	for i in range(total_count):
		var center := Vector2(
			rng.randf_range(region.position.x, region.end.x),
			rng.randf_range(region.position.y, region.end.y)
		)
		var item := _try_place_rect(
			size_min,
			size_max,
			center,
			scatter_radius,
			region,
			occupied,
			padding,
			placement_attempts * 2,
			rng
		)
		if item.is_empty():
			continue
		_spawn_terrain_zone(
			item["position"],
			item["size"],
			color,
			terrain_type,
			speed_multiplier,
			damage_per_tick,
			damage_interval
		)
		occupied.append(item["rect"])
		placed += 1
	return placed


## [自定义] 在分散的格子内生成障碍物。
func _spawn_scattered_obstacles(
	total_count: int,
	size_min: Vector2,
	size_max: Vector2,
	region: Rect2,
	hard_occupied: Array[Rect2],
	solid_occupied: Array[Rect2],
	padding: float,
	rng: RandomNumberGenerator
) -> int:
	# 障碍物采用“全图散布”策略，避免过分簇团导致布局偏一角。
	var placed := 0
	var cells := _build_scatter_cells(total_count, region)
	cells.shuffle()
	for cell in cells:
		if placed >= total_count:
			break
		var item := _try_place_rect_in_cell(size_min, size_max, cell, hard_occupied, padding, placement_attempts, rng)
		if item.is_empty():
			continue
		_spawn_obstacle(item["position"], item["size"])
		var rect: Rect2 = item["rect"]
		hard_occupied.append(rect)
		solid_occupied.append(rect)
		placed += 1
	if placed < total_count:
		# 兜底：若 cell 放置不足，补随机尝试。
		for i in range(total_count - placed):
			var random_cell := cells[rng.randi_range(0, maxi(0, cells.size() - 1))]
			var fallback := _try_place_rect_in_cell(size_min, size_max, random_cell, hard_occupied, padding, placement_attempts, rng)
			if fallback.is_empty():
				continue
			_spawn_obstacle(fallback["position"], fallback["size"])
			var f_rect: Rect2 = fallback["rect"]
			hard_occupied.append(f_rect)
			solid_occupied.append(f_rect)
			placed += 1
	return placed


## [自定义] 在集群中心周围生成草地区域。
func _spawn_clustered_grass(
	total_count: int,
	centers: Array[Vector2],
	items_per_cluster: Vector2i,
	size_min: Vector2,
	size_max: Vector2,
	cluster_radius: float,
	region: Rect2,
	occupied: Array[Rect2],
	padding: float,
	rng: RandomNumberGenerator
) -> int:
	# 草丛严格无重叠，与水域、障碍、其他草丛均保持 padding 间距。
	var placed := 0
	var grass_color := _get_terrain_color("grass", Color(0.20, 0.45, 0.18, 0.45))
	for center in centers:
		if placed >= total_count:
			break
		var items := rng.randi_range(items_per_cluster.x, items_per_cluster.y)
		for i in range(items):
			if placed >= total_count:
				break
			var item := _try_place_rect(size_min, size_max, center, cluster_radius, region, occupied, padding, placement_attempts, rng)
			if item.is_empty():
				continue
			_spawn_terrain_zone(
				item["position"],
				item["size"],
				grass_color,
				"grass",
				0.88,
				0,
				1.0
			)
			occupied.append(item["rect"])
			placed += 1
	return placed


## [自定义] 生成单个障碍物（StaticBody2D），玩家与敌人都被阻挡；视觉由 TileMap 绘制。
func _spawn_obstacle(spawn_pos: Vector2, size: Vector2) -> void:
	# 障碍物是 StaticBody2D，玩家与敌人都被阻挡；视觉由 TileMap 绘制。
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = spawn_pos
	body.add_child(col)
	if _terrain_layer != null:
		_paint_terrain_rect(Rect2(spawn_pos - size * 0.5, size), TERRAIN_TILE_OBSTACLE)
	else:
		var rect := ColorRect.new()
		rect.color = _get_terrain_color("obstacle", Color(0.16, 0.16, 0.20, 1.0))
		rect.size = size
		rect.position = -size * 0.5
		body.add_child(rect)
	_terrain_container.add_child(body)
	_obstacle_rects.append(Rect2(spawn_pos - size * 0.5, size))


## [自定义] 烘焙导航网格：可玩区域为可行走区，障碍物为孔洞；供 NavigationAgent2D 寻路。
func _bake_navigation() -> void:
	if nav_region == null or _playable_region.size.x <= 0 or _playable_region.size.y <= 0:
		return
	var geom := NavigationMeshSourceGeometryData2D.new()
	var outer := PackedVector2Array([
		_playable_region.position,
		_playable_region.position + Vector2(_playable_region.size.x, 0),
		_playable_region.position + _playable_region.size,
		_playable_region.position + Vector2(0, _playable_region.size.y)
	])
	geom.add_traversable_outline(outer)
	for rect in _obstacle_rects:
		var hole := PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y)
		])
		geom.add_obstruction_outline(hole)
	var nav_poly := NavigationPolygon.new()
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, geom)
	nav_region.navigation_polygon = nav_poly


## [自定义] 创建 TileSet 与单层 TileMapLayer。动态加载：tex_path 硬编码，ResourceLoader.exists 校验后 load()，
## 失败时直接 return（无 TileMapLayer）。纹理用于地形瓦片。
func _setup_terrain_tilemap() -> void:
	# 创建 TileSet 与单层 TileMapLayer，先铺满默认地形，再覆盖草/水/障碍。
	_terrain_layer = null
	var atlas := TileSetAtlasSource.new()
	var tex_path := "res://assets/terrain/terrain_atlas.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex == null:
		return
	# 至少需要 7 个 32x32 瓦片（224x32）；224x96 支持 flat/seaside/mountain 三行地板。
	const MIN_ATLAS_W := 224
	const MIN_ATLAS_H := 32
	if tex.get_width() < MIN_ATLAS_W or tex.get_height() < MIN_ATLAS_H:
		return
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TERRAIN_TILE_SIZE, TERRAIN_TILE_SIZE)
	var rows := ceili(tex.get_height() / float(TERRAIN_TILE_SIZE))
	_terrain_atlas_rows = maxi(1, mini(rows, 3))
	for y in range(rows):
		for x in range(7):
			atlas.create_tile(Vector2i(x, y))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TERRAIN_TILE_SIZE, TERRAIN_TILE_SIZE)
	tileset.add_source(atlas, 0)
	var terrain_root := Node2D.new()
	terrain_root.name = "TerrainTileMap"
	_terrain_layer = TileMapLayer.new()
	_terrain_layer.name = "TerrainLayer"
	_terrain_layer.tile_set = tileset
	_terrain_layer.z_index = -100
	terrain_root.add_child(_terrain_layer)
	_terrain_container.add_child(terrain_root)


## [自定义] 将世界坐标 rect 覆盖的 TileMapLayer 格子涂为指定 tile（覆盖已有地板）。
func _paint_terrain_rect(rect: Rect2, tile_type: int) -> void:
	# 将世界坐标 rect 覆盖的 TileMapLayer 格子涂为指定 tile（覆盖已有地板）。
	if _terrain_layer == null:
		return
	var source_id := 0
	var atlas_coords := Vector2i(tile_type, 0)
	var cell_start := Vector2i(floori(rect.position.x / float(TERRAIN_TILE_SIZE)), floori(rect.position.y / float(TERRAIN_TILE_SIZE)))
	var cell_end := Vector2i(ceili(rect.end.x / float(TERRAIN_TILE_SIZE)), ceili(rect.end.y / float(TERRAIN_TILE_SIZE)))
	for cx in range(cell_start.x, cell_end.x):
		for cy in range(cell_start.y, cell_end.y):
			_terrain_layer.set_cell(Vector2i(cx, cy), source_id, atlas_coords)


## [自定义] 可移动地面：优先用 TileMapLayer 铺满，支持风格化像素图；无 TileMapLayer 时回退 Polygon2D。
func _spawn_walkable_floor(region: Rect2, default_terrain_type: String = "flat", use_default_terrain: bool = false) -> void:
	# 可移动地面：优先用 TileMapLayer 铺满，支持风格化像素图；无 TileMapLayer 时回退 Polygon2D。
	var floor_row := TERRAIN_FLOOR_ROW_FLAT
	var t := default_terrain_type.to_lower()
	if t == "seaside" and _terrain_atlas_rows > 1:
		floor_row = TERRAIN_FLOOR_ROW_SEASIDE
	elif t == "mountain" and _terrain_atlas_rows > 2:
		floor_row = TERRAIN_FLOOR_ROW_MOUNTAIN
	floor_row = mini(floor_row, _terrain_atlas_rows - 1)
	if _terrain_layer != null:
		var source_id := 0
		var cell_start := Vector2i(floori(region.position.x / float(TERRAIN_TILE_SIZE)), floori(region.position.y / float(TERRAIN_TILE_SIZE)))
		var cell_end := Vector2i(ceili(region.end.x / float(TERRAIN_TILE_SIZE)), ceili(region.end.y / float(TERRAIN_TILE_SIZE)))
		for cx in range(cell_start.x, cell_end.x):
			for cy in range(cell_start.y, cell_end.y):
				var tile_x := TERRAIN_TILE_FLOOR_A if ((cx + cy) % 2 == 0) else TERRAIN_TILE_FLOOR_B
				_terrain_layer.set_cell(Vector2i(cx, cy), source_id, Vector2i(tile_x, floor_row))
		return
	# 回退：无 TileMapLayer 时用 Polygon2D
	var color_a: Color
	var color_b: Color
	if use_default_terrain:
		var cfg := DefaultTerrainColors.get_floor_colors(default_terrain_type)
		color_a = cfg[0]
		color_b = cfg[1]
	else:
		color_a = _get_terrain_color("floor_a", floor_color_a)
		color_b = _get_terrain_color("floor_b", floor_color_b)
	var floor_root := Node2D.new()
	floor_root.name = "FloorLayer"
	floor_root.z_index = -100
	_terrain_container.add_child(floor_root)
	var tile := maxf(12.0, floor_tile_size)
	var x := region.position.x
	var row := 0
	while x < region.end.x:
		var y := region.position.y
		var col := 0
		while y < region.end.y:
			var w := minf(tile - 1.0, region.end.x - x)
			var h := minf(tile - 1.0, region.end.y - y)
			var poly := Polygon2D.new()
			poly.color = color_a if ((row + col) % 2 == 0) else color_b
			poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
			poly.position = Vector2(x, y)
			floor_root.add_child(poly)
			y += tile
			col += 1
		x += tile
		row += 1


## [自定义] 四周边界：阻止单位离开可玩区域，并提供清晰边缘视觉。
func _spawn_world_bounds(region: Rect2) -> void:
	# 四周边界：阻止单位离开可玩区域，并提供清晰边缘视觉。
	var t := maxf(8.0, boundary_thickness)
	var top_rect := Rect2(region.position - Vector2(t, t), Vector2(region.size.x + t * 2.0, t))
	var bottom_rect := Rect2(Vector2(region.position.x - t, region.end.y), Vector2(region.size.x + t * 2.0, t))
	var left_rect := Rect2(Vector2(region.position.x - t, region.position.y), Vector2(t, region.size.y))
	var right_rect := Rect2(Vector2(region.end.x, region.position.y), Vector2(t, region.size.y))
	_spawn_boundary_body(top_rect)
	_spawn_boundary_body(bottom_rect)
	_spawn_boundary_body(left_rect)
	_spawn_boundary_body(right_rect)


## [自定义] 生成单条边界碰撞体，视觉上不可见。
func _spawn_boundary_body(rect: Rect2) -> void:
	# 边界仅保留碰撞，视觉上不可见。
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.position = rect.position + rect.size * 0.5
	body.z_index = 10
	body.add_child(col)
	_terrain_container.add_child(body)


## [自定义] 在集群中心附近尝试放置矩形，避免与 occupied 重叠；返回 {position, size, rect} 或空字典。
func _try_place_rect(
	size_min: Vector2,
	size_max: Vector2,
	cluster_center: Vector2,
	cluster_radius: float,
	region: Rect2,
	occupied: Array[Rect2],
	padding: float,
	max_attempts: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	for attempt in range(maxi(1, max_attempts)):
		var size := Vector2(
			rng.randf_range(size_min.x, size_max.x),
			rng.randf_range(size_min.y, size_max.y)
		)
		var pos := cluster_center + Vector2(
			rng.randf_range(-cluster_radius, cluster_radius),
			rng.randf_range(-cluster_radius, cluster_radius)
		)
		pos.x = clampf(pos.x, region.position.x, region.end.x)
		pos.y = clampf(pos.y, region.position.y, region.end.y)
		var rect := Rect2(pos - size * 0.5, size)
		if not _rect_inside_region(rect, region):
			continue
		if not _can_place_rect(rect, occupied, padding):
			continue
		return {
			"position": pos,
			"size": size,
			"rect": rect
		}
	return {}


## [自定义] 在指定 cell 内尝试放置矩形，避免与 occupied 重叠。
func _try_place_rect_in_cell(
	size_min: Vector2,
	size_max: Vector2,
	cell: Rect2,
	occupied: Array[Rect2],
	padding: float,
	max_attempts: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	for attempt in range(maxi(1, max_attempts)):
		var size := Vector2(
			rng.randf_range(size_min.x, minf(size_max.x, cell.size.x - 4.0)),
			rng.randf_range(size_min.y, minf(size_max.y, cell.size.y - 4.0))
		)
		var x_min := cell.position.x + size.x * 0.5
		var x_max := cell.end.x - size.x * 0.5
		var y_min := cell.position.y + size.y * 0.5
		var y_max := cell.end.y - size.y * 0.5
		if x_min >= x_max or y_min >= y_max:
			continue
		var pos := Vector2(
			rng.randf_range(x_min, x_max),
			rng.randf_range(y_min, y_max)
		)
		var rect := Rect2(pos - size * 0.5, size)
		if not _can_place_rect(rect, occupied, padding):
			continue
		return {
			"position": pos,
			"size": size,
			"rect": rect
		}
	return {}


## [自定义] 将 region 划分为 total_count 个近似均匀的格子，用于分散放置。
func _build_scatter_cells(total_count: int, region: Rect2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var safe_count := maxi(1, total_count)
	var aspect := maxf(0.2, region.size.x / maxf(1.0, region.size.y))
	var cols := maxi(1, int(round(sqrt(float(safe_count) * aspect))))
	var rows := maxi(1, int(ceil(float(safe_count) / float(cols))))
	var cell_w := region.size.x / float(cols)
	var cell_h := region.size.y / float(rows)
	for r in range(rows):
		for c in range(cols):
			var cell := Rect2(
				Vector2(region.position.x + c * cell_w, region.position.y + r * cell_h),
				Vector2(cell_w, cell_h)
			)
			cells.append(cell)
	return cells


## [自定义] 判断 rect 是否完全在 region 内。
func _rect_inside_region(rect: Rect2, region: Rect2) -> bool:
	return (
		rect.position.x >= region.position.x and
		rect.position.y >= region.position.y and
		rect.end.x <= region.end.x and
		rect.end.y <= region.end.y
	)


## [自定义] 判断 rect 与 occupied 中任意矩形是否重叠（含 padding）。
func _can_place_rect(rect: Rect2, occupied: Array[Rect2], padding: float) -> bool:
	for other in occupied:
		if _rect_overlaps(rect, other, padding):
			return false
	return true


## [自定义] 判断 a 扩展 padding 后是否与 b 相交。
func _rect_overlaps(a: Rect2, b: Rect2, padding: float) -> bool:
	var aa := Rect2(
		a.position - Vector2(padding, padding),
		a.size + Vector2(padding * 2.0, padding * 2.0)
	)
	return aa.intersects(b)


## [自定义] 生成地形区域（草地/浅水/深水）。动态加载：load("res://scripts/terrain_zone.gd") 运行时注入脚本到 Area2D，
## 路径硬编码；视觉由 TileMapLayer 或 ColorRect 绘制。
func _spawn_terrain_zone(
	spawn_pos: Vector2,
	size: Vector2,
	color: Color,
	terrain_type: String,
	speed_multiplier: float,
	damage_per_tick: int,
	damage_interval: float
) -> void:
	# 用同一个 terrain_zone.gd 统一草地/水面的行为；视觉由 TileMapLayer 绘制。
	var zone := Area2D.new()
	zone.set_script(load("res://scripts/terrain_zone.gd"))
	zone.position = spawn_pos
	zone.terrain_type = terrain_type
	zone.speed_multiplier = speed_multiplier
	zone.damage_per_tick = damage_per_tick
	zone.damage_interval = damage_interval

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)

	if _terrain_layer != null:
		var tile_type := TERRAIN_TILE_GRASS
		if terrain_type == "shallow_water":
			tile_type = TERRAIN_TILE_SHALLOW_WATER
		elif terrain_type == "deep_water":
			tile_type = TERRAIN_TILE_DEEP_WATER
		_paint_terrain_rect(Rect2(spawn_pos - size * 0.5, size), tile_type)
	else:
		var rect := ColorRect.new()
		rect.color = color
		rect.size = size
		rect.position = -size * 0.5
		zone.add_child(rect)

	_terrain_container.add_child(zone)
