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
@export var terrain_margin := 36.0
@export var placement_attempts := 24
@export var water_padding := 8.0
@export var obstacle_padding := 10.0
@export var grass_max_overlap_ratio := 0.45
@export var deep_water_cluster_count := 2
@export var shallow_water_cluster_count := 2
@export var obstacle_cluster_count := 3
@export var grass_cluster_count := 4
@export var deep_water_cluster_radius := 120.0
@export var shallow_water_cluster_radius := 140.0
@export var obstacle_cluster_radius := 150.0
@export var grass_cluster_radius := 170.0
@export var deep_water_cluster_items := Vector2i(2, 4)
@export var shallow_water_cluster_items := Vector2i(2, 5)
@export var obstacle_cluster_items := Vector2i(2, 4)
@export var grass_cluster_items := Vector2i(3, 6)
@export var floor_tile_size := 40.0
@export var floor_color_a := Color(0.78, 0.78, 0.80, 1.0)
@export var floor_color_b := Color(0.72, 0.72, 0.74, 1.0)
@export var boundary_thickness := 28.0
@export var boundary_color := Color(0.33, 0.33, 0.35, 1.0)

var player
var survival_time := 0.0
var is_game_over := false
var intermission_left := 0.0
var _upgrade_pool := [
	{"id": "damage", "title_key": "upgrade.damage.title", "desc_key": "upgrade.damage.desc", "cost": 2},
	{"id": "fire_rate", "title_key": "upgrade.fire_rate.title", "desc_key": "upgrade.fire_rate.desc", "cost": 2},
	{"id": "max_health", "title_key": "upgrade.max_health.title", "desc_key": "upgrade.max_health.desc", "cost": 3},
	{"id": "speed", "title_key": "upgrade.speed.title", "desc_key": "upgrade.speed.desc", "cost": 2},
	{"id": "bullet_speed", "title_key": "upgrade.bullet_speed.title", "desc_key": "upgrade.bullet_speed.desc", "cost": 1},
	{"id": "multi_shot", "title_key": "upgrade.multi_shot.title", "desc_key": "upgrade.multi_shot.desc", "cost": 4},
	{"id": "pierce", "title_key": "upgrade.pierce.title", "desc_key": "upgrade.pierce.desc", "cost": 4}
]
var _pending_upgrade_options: Array[Dictionary] = []
var _upgrade_selected := false
var _pending_start_weapon_options: Array[Dictionary] = []
var _pending_shop_weapon_options: Array[Dictionary] = []
var _waves_initialized := false
var _ui_modal_active := false
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

	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.kill_count_changed.connect(_on_kill_count_changed)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	wave_manager.intermission_started.connect(_on_intermission_started)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.start_weapon_selected.connect(_on_start_weapon_selected)
	hud.weapon_shop_selected.connect(_on_weapon_shop_selected)
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
	_start_weapon_pick()


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

	if not _ui_modal_active and Input.is_action_just_pressed("pause"):
		_toggle_pause()
	if Input.is_action_just_pressed("toggle_enemy_hp"):
		_toggle_enemy_healthbar_visibility()


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
	_pending_shop_weapon_options.clear()
	_pending_upgrade_options = _roll_upgrade_options(3)
	_set_ui_modal_active(true)
	hud.show_upgrade_options(_pending_upgrade_options, GameManager.run_currency)


func _on_kill_count_changed(kills: int) -> void:
	hud.set_kills(kills)


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
	hud.show_game_over(wave_manager.current_wave, wave_manager.kill_count, survival_time)


func _toggle_pause() -> void:
	if is_game_over:
		return
	if _ui_modal_active:
		return
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused
	# PauseMenu 是 CanvasLayer，统一通过接口控制显隐。
	pause_menu.set_visible_menu(new_paused)


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
	result.append({"id": "skip", "title_key": "upgrade.skip.title", "desc_key": "upgrade.skip.desc", "cost": 0})
	return result


func _on_upgrade_selected(upgrade_id: String) -> void:
	# 防重入：同一轮只允许结算一次升级选择。
	if _upgrade_selected or _pending_upgrade_options.is_empty():
		return
	var target: Dictionary = {}
	for item in _pending_upgrade_options:
		if str(item.get("id", "")) == upgrade_id:
			target = item
			break
	if target.is_empty():
		return
	var cost := int(target.get("cost", 0))
	if not GameManager.spend_currency(cost):
		return
	_upgrade_selected = true
	player.apply_upgrade(upgrade_id)
	hud.hide_upgrade_options()
	_pending_shop_weapon_options = _roll_weapon_shop_options(3)
	if _pending_shop_weapon_options.is_empty():
		_finish_wave_settlement()
		return
	_set_ui_modal_active(true)
	hud.show_weapon_shop(_pending_shop_weapon_options, GameManager.run_currency, player.get_weapon_capacity_left())


func _on_intermission_started(duration: float) -> void:
	intermission_left = duration


func _on_mobile_move_changed(direction: Vector2) -> void:
	_mobile_move = direction
	if is_instance_valid(player):
		player.external_move_input = _mobile_move


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


func _on_weapon_shop_selected(weapon_id: String) -> void:
	if weapon_id == "skip":
		_set_ui_modal_active(false)
		hud.hide_weapon_panel()
		_finish_wave_settlement()
		return
	if _pending_shop_weapon_options.is_empty():
		return
	var picked: Dictionary = {}
	for option in _pending_shop_weapon_options:
		if str(option.get("id", "")) == weapon_id:
			picked = option
			break
	if picked.is_empty():
		return
	var cost := int(picked.get("cost", 0))
	if not GameManager.spend_currency(cost):
		return
	if not _equip_weapon_to_player(weapon_id, true):
		GameManager.add_currency(cost)
		return
	_set_ui_modal_active(false)
	hud.hide_weapon_panel()
	hud.set_currency(GameManager.run_currency)
	_finish_wave_settlement()


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


func _equip_weapon_to_player(weapon_id: String, need_capacity: bool) -> bool:
	if need_capacity and player.get_weapon_capacity_left() <= 0:
		return false
	if not GameManager.can_add_run_weapon(weapon_id):
		return false
	if not player.equip_weapon_by_id(weapon_id):
		return false
	return GameManager.add_run_weapon(weapon_id)


func _finish_wave_settlement() -> void:
	_set_ui_modal_active(false)
	player.input_enabled = true
	wave_manager.begin_intermission()


func _set_ui_modal_active(value: bool) -> void:
	_ui_modal_active = value
	if _ui_modal_active:
		get_tree().paused = true
		pause_menu.set_visible_menu(false)
	else:
		get_tree().paused = false


func _spawn_terrain_map() -> void:
	# 簇团式分层生成：深水 -> 浅水 -> 障碍 -> 草丛。
	# 约束：
	# - 深/浅水互斥（共享 water_occupied）
	# - 障碍避让水域和已生成障碍（solid_occupied）
	# - 草丛允许与其它区块轻度重叠（自然感优先）
	var viewport := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var region := Rect2(
		Vector2(terrain_margin, terrain_margin),
		Vector2(
			maxf(64.0, viewport.x - terrain_margin * 2.0),
			maxf(64.0, viewport.y - terrain_margin * 2.0)
		)
	)
	var water_occupied: Array[Rect2] = []
	var solid_occupied: Array[Rect2] = []
	var deep_water_color := VisualAssetRegistry.get_color("terrain.deep_water", Color(0.08, 0.20, 0.42, 0.56))
	var shallow_water_color := VisualAssetRegistry.get_color("terrain.shallow_water", Color(0.24, 0.55, 0.80, 0.48))
	_spawn_walkable_floor(region)

	var deep_centers := _make_cluster_centers(deep_water_cluster_count, region, rng)
	var shallow_centers := _make_cluster_centers(shallow_water_cluster_count, region, rng)
	var grass_centers := _make_cluster_centers(grass_cluster_count, region, rng)

	var placed_deep := _spawn_clustered_zones(
		deep_water_count,
		deep_centers,
		deep_water_cluster_items,
		Vector2(78.0, 70.0),
		Vector2(128.0, 122.0),
		deep_water_cluster_radius,
		region,
		deep_water_color,
		"deep_water",
		0.52,
		2,
		1.2,
		water_occupied,
		water_padding,
		true,
		rng
	)
	var placed_shallow := _spawn_clustered_zones(
		shallow_water_count,
		shallow_centers,
		shallow_water_cluster_items,
		Vector2(76.0, 66.0),
		Vector2(148.0, 130.0),
		shallow_water_cluster_radius,
		region,
		shallow_water_color,
		"shallow_water",
		0.72,
		0,
		1.0,
		water_occupied,
		water_padding,
		true,
		rng
	)
	# 兜底：簇团不足时，补少量全图散点，降低“未达目标数量”的概率。
	if placed_deep < deep_water_count:
		placed_deep += _spawn_scattered_zones(
			deep_water_count - placed_deep,
			Vector2(78.0, 70.0),
			Vector2(128.0, 122.0),
			region,
			deep_water_color,
			"deep_water",
			0.52,
			2,
			1.2,
			water_occupied,
			water_padding,
			rng
		)
	if placed_shallow < shallow_water_count:
		placed_shallow += _spawn_scattered_zones(
			shallow_water_count - placed_shallow,
			Vector2(76.0, 66.0),
			Vector2(148.0, 130.0),
			region,
			shallow_water_color,
			"shallow_water",
			0.72,
			0,
			1.0,
			water_occupied,
			water_padding,
			rng
		)
	var hard_occupied: Array[Rect2] = []
	hard_occupied.append_array(water_occupied)
	hard_occupied.append_array(solid_occupied)
	var placed_obstacles := _spawn_scattered_obstacles(
		obstacle_count,
		Vector2(42.0, 38.0),
		Vector2(96.0, 88.0),
		region,
		hard_occupied,
		solid_occupied,
		obstacle_padding,
		rng
	)
	var grass_occupied_hint: Array[Rect2] = []
	grass_occupied_hint.append_array(water_occupied)
	grass_occupied_hint.append_array(solid_occupied)
	var placed_grass := _spawn_clustered_grass(
		grass_count,
		grass_centers,
		grass_cluster_items,
		Vector2(70.0, 60.0),
		Vector2(130.0, 120.0),
		grass_cluster_radius,
		region,
		grass_occupied_hint,
		grass_max_overlap_ratio,
		rng
	)
	if placed_deep < deep_water_count or placed_shallow < shallow_water_count or placed_obstacles < obstacle_count or placed_grass < grass_count:
		push_warning("Terrain placement reached limits: deep=%d/%d shallow=%d/%d obstacle=%d/%d grass=%d/%d" % [
			placed_deep, deep_water_count, placed_shallow, shallow_water_count, placed_obstacles, obstacle_count, placed_grass, grass_count
		])
	_spawn_world_bounds(region)

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
	rng: RandomNumberGenerator
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
			56.0,
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


func _spawn_clustered_grass(
	total_count: int,
	centers: Array[Vector2],
	items_per_cluster: Vector2i,
	size_min: Vector2,
	size_max: Vector2,
	cluster_radius: float,
	region: Rect2,
	hard_occupied_hint: Array[Rect2],
	max_overlap_ratio: float,
	rng: RandomNumberGenerator
) -> int:
	var placed := 0
	var grass_color := VisualAssetRegistry.get_color("terrain.grass", Color(0.20, 0.45, 0.18, 0.45))
	var local_grass_occupied: Array[Rect2] = []
	for center in centers:
		if placed >= total_count:
			break
		var items := rng.randi_range(items_per_cluster.x, items_per_cluster.y)
		for i in range(items):
			if placed >= total_count:
				break
			var item := _try_place_rect(size_min, size_max, center, cluster_radius, region, local_grass_occupied, -8.0, placement_attempts, rng)
			if item.is_empty():
				continue
			var rect: Rect2 = item["rect"]
			if not _can_place_rect_soft(rect, hard_occupied_hint, max_overlap_ratio):
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
			local_grass_occupied.append(rect)
			placed += 1
	return placed


func _spawn_obstacle(spawn_pos: Vector2, size: Vector2) -> void:
	# 障碍物是 StaticBody2D，玩家与敌人都被阻挡。
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var rect := ColorRect.new()
	shape.size = size
	col.shape = shape
	body.collision_layer = 8
	body.collision_mask = 0
	rect.color = VisualAssetRegistry.get_color("terrain.obstacle", Color(0.16, 0.16, 0.20, 1.0))
	rect.size = size
	rect.position = -size * 0.5
	body.position = spawn_pos
	body.add_child(col)
	body.add_child(rect)
	add_child(body)


func _spawn_walkable_floor(region: Rect2) -> void:
	# 可移动地面：使用浅灰色块铺满可玩区域，形成统一“地砖”视觉基底。
	var floor_root := Node2D.new()
	floor_root.name = "FloorLayer"
	floor_root.z_index = -100
	add_child(floor_root)
	var tile := maxf(12.0, floor_tile_size)
	var color_a := VisualAssetRegistry.get_color("terrain.floor_a", floor_color_a)
	var color_b := VisualAssetRegistry.get_color("terrain.floor_b", floor_color_b)
	var x := region.position.x
	var row := 0
	while x < region.end.x:
		var y := region.position.y
		var col := 0
		while y < region.end.y:
			var block := ColorRect.new()
			var w := minf(tile - 1.0, region.end.x - x)
			var h := minf(tile - 1.0, region.end.y - y)
			block.size = Vector2(maxf(4.0, w), maxf(4.0, h))
			block.position = Vector2(x, y)
			block.color = color_a if ((row + col) % 2 == 0) else color_b
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			floor_root.add_child(block)
			y += tile
			col += 1
		x += tile
		row += 1


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


func _spawn_boundary_body(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	var vis := ColorRect.new()
	vis.color = VisualAssetRegistry.get_color("terrain.boundary", boundary_color)
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	body.position = rect.position + rect.size * 0.5
	body.z_index = 10
	body.add_child(col)
	body.add_child(vis)
	add_child(body)


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


func _rect_inside_region(rect: Rect2, region: Rect2) -> bool:
	return (
		rect.position.x >= region.position.x and
		rect.position.y >= region.position.y and
		rect.end.x <= region.end.x and
		rect.end.y <= region.end.y
	)


func _can_place_rect(rect: Rect2, occupied: Array[Rect2], padding: float) -> bool:
	for other in occupied:
		if _rect_overlaps(rect, other, padding):
			return false
	return true


func _can_place_rect_soft(rect: Rect2, occupied: Array[Rect2], max_overlap_ratio: float) -> bool:
	var area := maxf(1.0, rect.size.x * rect.size.y)
	for other in occupied:
		var overlap := _overlap_area(rect, other)
		if overlap / area > max_overlap_ratio:
			return false
	return true


func _rect_overlaps(a: Rect2, b: Rect2, padding: float) -> bool:
	var aa := Rect2(
		a.position - Vector2(padding, padding),
		a.size + Vector2(padding * 2.0, padding * 2.0)
	)
	return aa.intersects(b)


func _overlap_area(a: Rect2, b: Rect2) -> float:
	var left := maxf(a.position.x, b.position.x)
	var top := maxf(a.position.y, b.position.y)
	var right := minf(a.end.x, b.end.x)
	var bottom := minf(a.end.y, b.end.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)


func _spawn_terrain_zone(
	spawn_pos: Vector2,
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

	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = -size * 0.5
	zone.add_child(rect)

	add_child(zone)
