extends CharacterBody2D
class_name EnemyBase

# 敌人基类：
# - 生命与死亡事件
# - 与玩家碰撞接触伤害
# - 通用追踪移动方法
signal died(enemy: Node)

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
var _knockback_velocity := Vector2.ZERO
var _out_of_water_cd := 0.0  # 离水伤害 CD
var _last_direction_index := 0  # 8 方向索引
var _is_dying := false  # 死亡动画播放中，防重入


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
	_refresh_health_bar()
	set_healthbar_visible(GameManager.enemy_healthbar_visible)
	if hurt_area:
		hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	if contact_timer:
		# 接触伤害通过计时器节流。
		contact_timer.wait_time = contact_damage_interval
		contact_timer.timeout.connect(_on_contact_timer_timeout)


func _process(delta: float) -> void:
	_update_direction_sprite()
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


func set_enemy_texture(enemy_type: int) -> void:
	# 优先 texture_sheet，失败则 texture_single，再回退 PixelGenerator；enemy_type 仅用于 PixelGenerator。
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
	sprite.texture = PixelGenerator.generate_enemy_sprite(enemy_type)
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


## 受到伤害；_elemental 为元素类型（如 "fire"），预留抗性/DOT 扩展，基类暂未使用
func take_damage(amount: int, _elemental: String = "") -> void:
	current_health -= amount
	_refresh_health_bar()
	if current_health <= 0 and not _is_dying:
		_is_dying = true
		_begin_death_sequence()


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
	var dir := (player_ref.global_position - global_position).normalized()
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
	_terrain_effects[zone_id] = clampf(speed_multiplier, 0.2, 1.2)
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


func _refresh_health_bar() -> void:
	if not _health_bar:
		return
	_health_bar.max_value = float(max_health)
	_health_bar.value = clampf(float(current_health), 0.0, float(max_health))
