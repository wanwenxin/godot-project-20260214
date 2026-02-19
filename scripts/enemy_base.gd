extends CharacterBody2D
class_name EnemyBase

# 敌人基类：
# - 生命与死亡事件
# - 与玩家碰撞接触伤害
# - 通用追踪移动方法
# - 元素附着、每秒衰减与双元素反应
signal died(enemy: Node)

# 元素量档位常量：少量 1、大量 10、巨量 20；武器=1，魔法=10。
const ELEMENT_AMOUNT_SMALL := 1
const ELEMENT_AMOUNT_LARGE := 10
const ELEMENT_AMOUNT_HUGE := 20

@export var max_health := 25
@export var speed := 90.0
@export var exp_value := 5  # 击败该敌人可获得的经验值，各敌人在场景中配置不同值
@export var contact_damage := 8
@export var contact_damage_interval := 0.6
# 水中专属敌人离水伤害（子类 is_water_only 返回 true 时生效）。
@export var out_of_water_damage_per_tick := 5
@export var out_of_water_damage_interval := 0.2
@export_file("*.png") var texture_sheet: String  # 8 方向精灵图，空则尝试 texture_single
@export_file("*.png") var texture_single: String  # 单帧回退，空则 PixelGenerator
@export var frame_size: Vector2i = Vector2i(18, 18)  # 每帧像素尺寸
@export var sheet_columns: int = 8  # 精灵图列数（8 方向）
@export var sheet_rows: int = 3  # 精灵图行数（站立、行走1、行走2）
# 敌人类型：0=melee, 1=ranged, 2=tank, 3=boss, 4=aquatic, 5=dasher，用于死亡动画与 PixelGenerator 回退
@export var enemy_type: int = 0
# 敌人 id（如 slime、elite_goblin）：若设置则从 EnemyDefs 加载数值并用 generate_enemy_sprite_by_id 生成纹理
@export var enemy_id: String = ""

var current_health := 25
var player_ref: Node2D
# 接触伤害节流开关，避免同帧多次触发。
var _can_contact_damage := true
# 与玩家保持一致的地形减速逻辑。
var _terrain_effects: Dictionary = {}
var _terrain_speed_multiplier := 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var contact_timer: Timer = $ContactDamageTimer
@onready var hurt_area: Area2D = $HurtArea

var _health_bar: ProgressBar
# 血条上方横向排布的元素附着小图标容器；不足 5 点时对应图标闪烁
var _element_icons_container: HBoxContainer = null
var _knockback_velocity := Vector2.ZERO
var _out_of_water_cd := 0.0  # 离水伤害 CD
var _last_direction_index := 0  # 8 方向索引
var _is_dying := false  # 死亡动画播放中，防重入
# 行为模式：0=CHASE_DIRECT, 1=CHASE_NAV, 2=KEEP_DISTANCE, 3=FLANK, 4=CHARGE, 5=BOSS_CUSTOM；由 EnemyDefs 注入
var _behavior_mode: int = 0
var _nav_agent: NavigationAgent2D  # 寻路代理，CHASE_NAV/FLANK 时使用
# 元素附着量，如 {"fire": 10, "ice": 5}；每秒衰减 1，双元素等量消耗时触发反应
var _element_amounts: Dictionary = {}
var _element_decay_accum: float = 0.0  # 累加满 1 秒后执行一次衰减与反应


func is_water_only() -> bool:
	# 子类（如 enemy_aquatic）override 返回 true。
	return false


func _is_in_water() -> bool:
	return get_meta("water_zone_count", 0) > 0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 8
	current_health = max_health
	_create_health_bar()
	_create_element_icons_container()
	_refresh_health_bar()
	set_healthbar_visible(GameManager.enemy_healthbar_visible)
	if hurt_area:
		hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	if contact_timer:
		# 接触伤害通过计时器节流。
		contact_timer.wait_time = contact_damage_interval
		contact_timer.timeout.connect(_on_contact_timer_timeout)
	# 从 EnemyDefs 取 behavior_mode；若 enemy_id 非空则覆盖。
	if enemy_id != "":
		var def := EnemyDefs.get_enemy_def(enemy_id)
		if not def.is_empty():
			_behavior_mode = def.get("behavior_mode", 0)
	# 体积：普通敌人与玩家同倍率，BOSS 使用 BOSS_SCALE（见 GameConstants）
	if enemy_type == 3:
		scale = Vector2(GameConstants.BOSS_SCALE, GameConstants.BOSS_SCALE)
	else:
		scale = Vector2(GameConstants.ENEMY_SCALE, GameConstants.ENEMY_SCALE)
	# 寻路代理：CHASE_NAV/FLANK/KEEP_DISTANCE 时需绕障碍；非水中敌人才创建；开启 avoidance 尽量不重叠。
	if not is_water_only() and (_behavior_mode == EnemyDefs.BEHAVIOR_CHASE_NAV or _behavior_mode == EnemyDefs.BEHAVIOR_FLANK or _behavior_mode == EnemyDefs.BEHAVIOR_KEEP_DISTANCE):
		_nav_agent = NavigationAgent2D.new()
		_nav_agent.path_desired_distance = 8.0
		_nav_agent.target_desired_distance = 8.0
		_nav_agent.avoidance_enabled = true
		var col: Node = get_node_or_null("CollisionShape2D")
		if col != null and col is CollisionShape2D and (col as CollisionShape2D).shape is CircleShape2D:
			_nav_agent.radius = (col.shape as CircleShape2D).radius * scale.x
		else:
			_nav_agent.radius = 36.0
		_nav_agent.max_neighbors = 8
		_nav_agent.neighbor_distance = 80.0
		add_child(_nav_agent)


func _process(delta: float) -> void:
	_update_direction_sprite()
	# 元素衰减与双元素反应：每累计 1 秒执行一次。
	_tick_element_decay(delta)
	# 元素图标：不足 5 点时闪烁
	_update_element_icons_blink()
	# 水中专属敌人离水时持续扣血。
	if not is_water_only():
		return
	if _is_in_water():
		_out_of_water_cd = out_of_water_damage_interval
		return
	_out_of_water_cd -= delta
	if _out_of_water_cd <= 0.0:
		take_damage(out_of_water_damage_per_tick)
		_out_of_water_cd = out_of_water_damage_interval


func set_player(node: Node2D) -> void:
	player_ref = node


func set_enemy_texture(type_hint: int = -1) -> void:
	# 优先 texture_sheet，失败则 texture_single；enemy_id 非空时用 generate_enemy_sprite_by_id；否则回退 PixelGenerator(enemy_type)。
	if not sprite:
		return
	var tex: Texture2D = null
	if texture_sheet != "" and ResourceLoader.exists(texture_sheet):
		tex = load(texture_sheet) as Texture2D
	if tex != null:
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, frame_size.x, frame_size.y)
		return
	if texture_single != "" and ResourceLoader.exists(texture_single):
		tex = load(texture_single) as Texture2D
	if tex != null:
		sprite.texture = tex
		sprite.region_enabled = false
		return
	if enemy_id != "":
		sprite.texture = PixelGenerator.generate_enemy_sprite_by_id(enemy_id)
	else:
		sprite.texture = PixelGenerator.generate_enemy_sprite(type_hint if type_hint >= 0 else enemy_type)
	sprite.region_enabled = false


func _update_direction_sprite() -> void:
	# 8 方向 x 3 行（站立、行走帧1、行走帧2）：根据 velocity 与时间切换，实现肉眼可见的行走动画。
	if not sprite or not sprite.region_enabled:
		return
	var frame_w := frame_size.x
	var frame_h := frame_size.y
	if velocity.length_squared() > 16.0:
		var angle := velocity.angle()
		_last_direction_index = wrapi(roundi((angle + PI) / (PI / 4.0)), 0, 8)
	# 行走时在行 1、2 间交替（约 150ms 一帧）
	var row := 0
	if velocity.length_squared() > 16.0:
		row = 1 + (int(Time.get_ticks_msec() / 150.0) % 2)
	sprite.region_rect = Rect2(_last_direction_index * frame_w, row * frame_h, frame_w, frame_h)


func apply_knockback(dir: Vector2, force: float) -> void:
	# 受击击退：累加冲击速度，由移动逻辑每帧衰减。
	_knockback_velocity += dir.normalized() * force


## 受到伤害；_elemental 为元素类型（如 "fire"），_element_amount 为本次附着的元素量（0 表示不附着）
func take_damage(amount: int, _elemental: String = "", _element_amount: int = 0) -> void:
	current_health -= amount
	_refresh_health_bar()
	if _elemental != "" and _element_amount > 0:
		_element_amounts[_elemental] = _element_amounts.get(_elemental, 0) + _element_amount
		_refresh_element_icons()
	if current_health <= 0 and not _is_dying:
		_is_dying = true
		_begin_death_sequence()


## [自定义] 每帧累加 delta，满 1 秒时对每种元素减 1、若存在两种元素则等量消耗并触发反应。
func _tick_element_decay(delta: float) -> void:
	if _is_dying:
		return
	_element_decay_accum += delta
	if _element_decay_accum < 1.0:
		return
	_element_decay_accum -= 1.0
	# 单元素衰减：每种元素量减 1，为 0 则移除
	var to_remove: Array[String] = []
	for k in _element_amounts.keys():
		_element_amounts[k] = maxi(0, _element_amounts[k] - 1)
		if _element_amounts[k] <= 0:
			to_remove.append(k)
	for k in to_remove:
		_element_amounts.erase(k)
	# 双元素等量消耗与反应：若至少两种元素量 > 0，取前两种等量消耗并触发反应
	if _element_amounts.size() < 2:
		return
	var keys_with_amount: Array[String] = []
	for k in _element_amounts.keys():
		if _element_amounts[k] > 0:
			keys_with_amount.append(k)
	keys_with_amount.sort()
	if keys_with_amount.size() < 2:
		return
	var elem_a: String = keys_with_amount[0]
	var elem_b: String = keys_with_amount[1]
	var consumed: int = mini(_element_amounts[elem_a], _element_amounts[elem_b])
	_element_amounts[elem_a] -= consumed
	_element_amounts[elem_b] -= consumed
	if _element_amounts[elem_a] <= 0:
		_element_amounts.erase(elem_a)
	if _element_amounts[elem_b] <= 0:
		_element_amounts.erase(elem_b)
	_trigger_element_reaction(elem_a, elem_b, consumed)
	_refresh_element_icons()


## [自定义] 双元素等量消耗后根据两种元素类型与消耗量触发反应效果；反应仅造成无元素伤害，避免二次附着。
func _trigger_element_reaction(elem_a: String, elem_b: String, consumed: int) -> void:
	if consumed <= 0 or _is_dying:
		return
	# 规范化为字典序，便于查表
	var lo: String = elem_a if elem_a < elem_b else elem_b
	var hi: String = elem_b if elem_a < elem_b else elem_a
	var reaction_damage: int = 0
	var knockback_force: float = 0.0
	if lo == "fire" and hi == "ice":
		# 融化：消耗量 * 2 的额外伤害
		reaction_damage = consumed * 2
	elif lo == "fire" and hi == "lightning":
		# 过载：伤害 + 击退
		reaction_damage = consumed * 2
		knockback_force = 30.0 + consumed * 2.0
	elif lo == "ice" and hi == "lightning":
		# 超导：消耗量 * 1 的伤害
		reaction_damage = consumed * 1
	elif (lo == "fire" and hi == "poison") or (lo == "ice" and hi == "poison") or (lo == "lightning" and hi == "poison"):
		# 毒与其他：少量额外伤害
		reaction_damage = consumed
	else:
		# 未定义组合（如 physical）：按消耗量造成 1:1 伤害
		reaction_damage = consumed
	if reaction_damage > 0:
		current_health -= reaction_damage
		_refresh_health_bar()
		GameManager.add_record_damage_dealt(reaction_damage)
		if current_health <= 0 and not _is_dying:
			_is_dying = true
			_begin_death_sequence()
	if knockback_force > 0.0 and is_instance_valid(player_ref):
		var away := (global_position - player_ref.global_position).normalized()
		apply_knockback(away, knockback_force)


## 死亡流程：禁用碰撞与移动，播放差异化死亡动画，结束后发出 died 并销毁。
func _begin_death_sequence() -> void:
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	if hurt_area:
		hurt_area.collision_layer = 0
		hurt_area.collision_mask = 0
	if _health_bar:
		_health_bar.visible = false
	_play_death_animation()


## 按 enemy_type 播放不同死亡动画，动画结束后 emit died 并 queue_free。
func _play_death_animation() -> void:
	if not sprite:
		_finish_death()
		return
	var dur := 0.25
	var tween := create_tween()
	tween.set_parallel(true)
	match enemy_type:
		0:  # melee：红色闪灭 + 快速缩小
			sprite.modulate = Color(1.2, 0.3, 0.3)
			tween.tween_property(sprite, "modulate", Color(0.8, 0.2, 0.2, 0.0), dur)
			tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), dur)
		1:  # ranged：紫色淡出 + 轻微旋转
			tween.tween_property(sprite, "modulate", Color(0.7, 0.2, 0.9, 0.0), dur)
			tween.tween_property(sprite, "rotation", TAU * 0.25, dur)
		2:  # tank：绿色碎裂感（放大后缩小 + 淡出）
			tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), dur * 0.4)
			var ch := tween.chain()
			ch.set_parallel(true)
			ch.tween_property(sprite, "scale", Vector2(0.2, 0.2), dur * 0.6)
			ch.tween_property(sprite, "modulate", Color(0.2, 0.65, 0.25, 0.0), dur * 0.6)
		3:  # boss：红色爆炸感（先放大再缩小 + 闪白）
			sprite.modulate = Color(1.5, 1.5, 1.5)
			tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), dur * 0.35)
			var ch_boss := tween.chain()
			ch_boss.set_parallel(true)
			ch_boss.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2, 0.0), dur * 0.65)
			ch_boss.tween_property(sprite, "scale", Vector2(0.2, 0.2), dur * 0.65)
		4:  # aquatic：青色水花散开（缩放 + 淡出）
			tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), dur)
			tween.parallel().tween_property(sprite, "modulate", Color(0.2, 0.8, 0.9, 0.0), dur)
		5:  # dasher：橙色拖尾淡出（水平拉伸 + 淡出）
			tween.tween_property(sprite, "scale", Vector2(1.8, 0.4), dur)
			tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.5, 0.2, 0.0), dur)
		_:  # 默认：淡出 + 缩小
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), dur)
			tween.parallel().tween_property(sprite, "scale", Vector2(0.2, 0.2), dur)
	tween.set_parallel(false)
	tween.tween_callback(_finish_death)


func _finish_death() -> void:
	emit_signal("died", self)
	queue_free()


func _move_towards_player(_delta: float, move_scale: float = 1.0) -> void:
	if not is_instance_valid(player_ref):
		return
	if _behavior_mode == EnemyDefs.BEHAVIOR_CHASE_NAV and _nav_agent != null:
		_move_towards_player_nav(_delta, move_scale)
		return
	if _behavior_mode == EnemyDefs.BEHAVIOR_FLANK and _nav_agent != null:
		_move_towards_flank_nav(_delta, move_scale)
		return
	var dir := (player_ref.global_position - global_position).normalized()
	velocity = dir * speed * move_scale * _terrain_speed_multiplier + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 0.5)
	move_and_slide()


## [自定义] 使用 NavigationAgent2D 寻路追击玩家；CHASE_NAV 时调用。
func _move_towards_player_nav(_delta: float, move_scale: float = 1.0) -> void:
	if not is_instance_valid(player_ref) or _nav_agent == null:
		return
	# 每帧更新目标；需在 physics 阶段后设置，避免首次 get_next_path_position 无效。
	_nav_agent.target_position = player_ref.global_position
	var next_pos := _nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	if dir.length_squared() < 0.001:
		dir = (player_ref.global_position - global_position).normalized()
	velocity = dir * speed * move_scale * _terrain_speed_multiplier + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 0.5)
	move_and_slide()


## [自定义] 侧翼包抄：寻路至玩家侧翼方向；FLANK 时调用。
func _move_towards_flank_nav(_delta: float, move_scale: float = 1.0) -> void:
	if not is_instance_valid(player_ref) or _nav_agent == null:
		return
	var to_player := player_ref.global_position - global_position
	var dist := to_player.length()
	if dist < 20.0:
		# 已近，直接追击
		_move_towards_player_nav(_delta, move_scale)
		return
	var dir := to_player.normalized()
	# 侧翼：垂直于玩家朝向的方向，取离自己更近的一侧
	var side := Vector2(-dir.y, dir.x)
	var flank_target := player_ref.global_position + side * 80.0
	_nav_agent.target_position = flank_target
	var next_pos := _nav_agent.get_next_path_position()
	var move_dir := (next_pos - global_position).normalized()
	if move_dir.length_squared() < 0.001:
		move_dir = dir
	velocity = move_dir * speed * move_scale * _terrain_speed_multiplier + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 0.5)
	move_and_slide()


## [自定义] 使用 NavigationAgent2D 寻路远离玩家；KEEP_DISTANCE 时「太近则后退」调用。
func _move_away_nav(_delta: float, move_scale: float = 1.0) -> void:
	if not is_instance_valid(player_ref) or _nav_agent == null:
		return
	var away_target := global_position + (global_position - player_ref.global_position).normalized() * 150.0
	_nav_agent.target_position = away_target
	var next_pos := _nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	if dir.length_squared() < 0.001:
		dir = (global_position - player_ref.global_position).normalized()
	velocity = dir * speed * move_scale * _terrain_speed_multiplier + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 0.5)
	move_and_slide()


func _move_towards_player_clamped(_delta: float, move_scale: float, clamp_rect: Rect2) -> void:
	if not is_instance_valid(player_ref):
		return
	var dir := (player_ref.global_position - global_position).normalized()
	velocity = dir * speed * move_scale * _terrain_speed_multiplier + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 0.5)
	var next_pos := global_position + velocity * _delta
	next_pos.x = clampf(next_pos.x, clamp_rect.position.x, clamp_rect.end.x)
	next_pos.y = clampf(next_pos.y, clamp_rect.position.y, clamp_rect.end.y)
	velocity = (next_pos - global_position) / _delta if _delta > 0.0001 else Vector2.ZERO
	move_and_slide()


func _on_hurt_area_body_entered(body: Node) -> void:
	if not _can_contact_damage:
		return
	if body.is_in_group("players") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		_can_contact_damage = false
		# 进入短 CD，防止玩家与敌人重叠时持续掉血过快。
		contact_timer.start()


func _on_contact_timer_timeout() -> void:
	# 持续接触伤害：若玩家仍在 HurtArea 内，再次造成伤害并重启计时器。
	if hurt_area != null:
		for body in hurt_area.get_overlapping_bodies():
			if body.is_in_group("players") and body.has_method("take_damage"):
				body.take_damage(contact_damage)
				contact_timer.start()
				return
	_can_contact_damage = true


func set_terrain_effect(zone_id: int, speed_multiplier: float) -> void:
	_terrain_effects[zone_id] = clampf(speed_multiplier, GameConstants.TERRAIN_SPEED_CLAMP_MIN, GameConstants.TERRAIN_SPEED_CLAMP_MAX)
	_recompute_terrain_speed()


func clear_terrain_effect(zone_id: int) -> void:
	_terrain_effects.erase(zone_id)
	_recompute_terrain_speed()


func _recompute_terrain_speed() -> void:
	# 多地形重叠时采用最小速度倍率。
	_terrain_speed_multiplier = 1.0
	for key in _terrain_effects.keys():
		_terrain_speed_multiplier = minf(_terrain_speed_multiplier, float(_terrain_effects[key]))


func set_healthbar_visible(value: bool) -> void:
	if _health_bar:
		_health_bar.visible = value
	if _element_icons_container:
		_element_icons_container.visible = value


func _create_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = float(max_health)
	_health_bar.value = float(current_health)
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(36.0, 6.0)
	_health_bar.position = Vector2(-18.0, -30.0)
	_health_bar.z_index = 20
	add_child(_health_bar)


## [自定义] 在血条上方创建横向排布的元素图标容器；无附着时隐藏，有附着时显示小图标，不足 5 点由 _update_element_icons_blink 闪烁。
func _create_element_icons_container() -> void:
	_element_icons_container = HBoxContainer.new()
	_element_icons_container.position = Vector2(-18.0, -38.0)
	_element_icons_container.custom_minimum_size = Vector2(36.0, 5.0)
	_element_icons_container.scale = Vector2(GameConstants.ELEMENT_ICONS_SCALE, GameConstants.ELEMENT_ICONS_SCALE)
	_element_icons_container.z_index = 20
	_element_icons_container.add_theme_constant_override("separation", 1)
	_element_icons_container.visible = false
	add_child(_element_icons_container)


## [自定义] 根据元素类型返回小图标纹理；有图用资源，无图用纯色占位。
func _get_element_icon_texture(element_key: String) -> Texture2D:
	var path: String = ""
	match element_key:
		"fire":
			path = "res://assets/magic/icon_fire.png"
		"ice":
			path = "res://assets/magic/icon_ice.png"
		"lightning":
			return VisualAssetRegistry.make_color_texture(Color(1.0, 0.95, 0.2, 1.0), Vector2i(4, 4))
		"poison":
			return VisualAssetRegistry.make_color_texture(Color(0.5, 0.2, 0.7, 1.0), Vector2i(4, 4))
		"physical":
			return VisualAssetRegistry.make_color_texture(Color(0.6, 0.6, 0.65, 1.0), Vector2i(4, 4))
		_:
			return VisualAssetRegistry.make_color_texture(Color(0.7, 0.7, 0.7, 1.0), Vector2i(4, 4))
	if path != "" and ResourceLoader.exists(path):
		var tex := VisualAssetRegistry.get_texture_cached(path)
		if tex != null:
			return tex
	return VisualAssetRegistry.make_color_texture(Color(0.8, 0.3, 0.2, 1.0), Vector2i(4, 4))


## [自定义] 根据 _element_amounts 同步图标列表：有元素则显示横向小图标，无则隐藏容器。
func _refresh_element_icons() -> void:
	if _element_icons_container == null:
		return
	while _element_icons_container.get_child_count() > 0:
		var c: Node = _element_icons_container.get_child(0)
		_element_icons_container.remove_child(c)
		c.queue_free()
	if _element_amounts.is_empty():
		_element_icons_container.visible = false
		return
	_element_icons_container.visible = _health_bar != null and _health_bar.visible
	var keys: Array[String] = []
	for k in _element_amounts.keys():
		if _element_amounts[k] > 0:
			keys.append(k)
	keys.sort()
	for k in keys:
		var amount: int = _element_amounts[k]
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(4.0, 4.0)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = _get_element_icon_texture(k)
		rect.set_meta("element", k)
		rect.set_meta("amount", amount)
		_element_icons_container.add_child(rect)


## [自定义] 每帧更新元素图标闪烁：附着量不足 5 的图标按时间闪烁（半透明/不透明交替）。
func _update_element_icons_blink() -> void:
	if _element_icons_container == null or not _element_icons_container.visible:
		return
	var period_ms := 250
	var half := int(Time.get_ticks_msec() / period_ms) % 2
	var dim: bool = half == 1
	for c in _element_icons_container.get_children():
		if not c is TextureRect:
			continue
		var amount: int = c.get_meta("amount", 0)
		if amount < 5:
			c.modulate.a = 0.45 if dim else 1.0
		else:
			c.modulate.a = 1.0


func _refresh_health_bar() -> void:
	if not _health_bar:
		return
	_health_bar.max_value = float(max_health)
	_health_bar.value = clampf(float(current_health), 0.0, float(max_health))
