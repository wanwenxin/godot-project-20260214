extends CharacterBody2D

# 敌人基类：
# - 生命与死亡事件
# - 与玩家碰撞接触伤害
# - 通用追踪移动方法
signal died(enemy: Node)

@export var max_health := 25
@export var speed := 90.0
@export var contact_damage := 8
@export var contact_damage_interval := 0.6
# 水中专属敌人离水伤害（子类 is_water_only 返回 true 时生效）。
@export var out_of_water_damage_per_tick := 5
@export var out_of_water_damage_interval := 0.2

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
	# 子类通过 enemy_type 指定外观。
	if sprite:
		var key := "enemy.melee"
		if enemy_type == 1:
			key = "enemy.ranged"
		elif enemy_type == 2:
			key = "enemy.tank"
		elif enemy_type == 3:
			key = "enemy.boss"
		elif enemy_type == 4:
			key = "enemy.aquatic"
		elif enemy_type >= 5:
			key = "enemy.dasher"
		var fallback := func() -> Texture2D:
			return PixelGenerator.generate_enemy_sprite(enemy_type)
		sprite.texture = VisualAssetRegistry.get_texture(key, fallback)


func apply_knockback(dir: Vector2, force: float) -> void:
	# 受击击退：累加冲击速度，由移动逻辑每帧衰减。
	_knockback_velocity += dir.normalized() * force


## 受到伤害；elemental 为元素类型（如 "fire"），预留抗性/DOT 扩展。
func take_damage(amount: int, elemental: String = "") -> void:
	current_health -= amount
	_refresh_health_bar()
	if current_health <= 0:
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
