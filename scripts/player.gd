extends CharacterBody2D

# 玩家主体：
# - 输入移动
# - 自动索敌
# - 受伤/无敌帧/死亡
signal died
signal health_changed(current: int, max_value: int)
signal damaged(amount: int)

@export var base_speed := 160.0
@export var max_health := 100
@export var invulnerable_duration := 0.35

var current_health := 100
var move_input := Vector2.ZERO
var _invulnerable_timer := 0.0
var _character_data := {}
var external_move_input := Vector2.ZERO
var input_enabled := true
var _nearest_enemy_refresh := 0.0
var _cached_nearest_enemy: Node2D
# 多地形叠加时记录每个 zone 的速度系数，取最慢值。
var _terrain_effects: Dictionary = {}
var _terrain_speed_multiplier := 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon = $Weapon


func _ready() -> void:
	add_to_group("players")
	# 玩家仅与敌人发生实体碰撞，子弹通过 Area2D 处理。
	collision_layer = 1
	collision_mask = 2 | 8
	_update_sprite(0)
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func set_character_data(data: Dictionary) -> void:
	# 把角色模板参数应用到当前实体。
	_character_data = data.duplicate(true)
	max_health = int(_character_data.get("max_health", 100))
	base_speed = float(_character_data.get("speed", 160.0))
	current_health = max_health
	_update_sprite(int(_character_data.get("color_scheme", 0)))
	if weapon:
		# 武器参数由角色驱动，实现不同 build 风格。
		weapon.set("fire_rate", float(_character_data.get("fire_rate", 0.3)))
		weapon.set("bullet_damage", int(_character_data.get("bullet_damage", 10)))
		weapon.set("bullet_speed", float(_character_data.get("bullet_speed", 500.0)))
		weapon.set("pellet_count", int(_character_data.get("pellet_count", 1)))
		weapon.set("spread_degrees", float(_character_data.get("spread_degrees", 0.0)))
		weapon.set("bullet_pierce", int(_character_data.get("bullet_pierce", 0)))
	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	# 使用 Input.get_vector 自动处理对角线归一化。
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 键盘无输入时，允许触控虚拟摇杆接管。
	if move_input.length() < 0.05:
		move_input = external_move_input
	if not input_enabled:
		move_input = Vector2.ZERO
	velocity = move_input * base_speed * _terrain_speed_multiplier
	move_and_slide()

	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta
		var blink := int(Time.get_ticks_msec() / 80.0) % 2 == 0
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.45 if blink else 1.0)
	else:
		sprite.modulate = Color.WHITE

	# 降低最近敌人检索频率，缓解敌人数量上升时的每帧开销。
	_nearest_enemy_refresh -= delta
	if _nearest_enemy_refresh <= 0.0:
		_nearest_enemy_refresh = 0.12
		_cached_nearest_enemy = _get_nearest_enemy()
	var nearest_enemy := _cached_nearest_enemy
	if nearest_enemy != null and weapon:
		# 自动朝最近敌人开火（Brotato 风格核心体验）。
		weapon.try_shoot(nearest_enemy.global_position)


func take_damage(amount: int) -> void:
	# 无敌计时器 > 0 时忽略后续伤害，避免多次碰撞瞬间秒杀。
	if _invulnerable_timer > 0.0:
		return
	current_health = max(current_health - amount, 0)
	_invulnerable_timer = invulnerable_duration
	emit_signal("health_changed", current_health, max_health)
	emit_signal("damaged", amount)
	if current_health <= 0:
		emit_signal("died")
		queue_free()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			if weapon:
				weapon.bullet_damage += 3
		"fire_rate":
			if weapon:
				weapon.fire_rate = maxf(0.08, weapon.fire_rate - 0.03)
		"max_health":
			max_health += 20
			current_health = mini(current_health + 20, max_health)
			emit_signal("health_changed", current_health, max_health)
		"speed":
			base_speed += 20.0
		"bullet_speed":
			if weapon:
				weapon.bullet_speed += 60.0
		"multi_shot":
			if weapon:
				weapon.pellet_count = mini(weapon.pellet_count + 1, 5)
				weapon.spread_degrees = maxf(weapon.spread_degrees, 20.0)
		"pierce":
			if weapon:
				weapon.bullet_pierce = mini(weapon.bullet_pierce + 1, 4)


func set_terrain_effect(zone_id: int, speed_multiplier: float) -> void:
	_terrain_effects[zone_id] = clampf(speed_multiplier, 0.2, 1.2)
	_recompute_terrain_speed()


func clear_terrain_effect(zone_id: int) -> void:
	_terrain_effects.erase(zone_id)
	_recompute_terrain_speed()


func _get_nearest_enemy() -> Node2D:
	# 简单线性扫描，敌人数量较少时足够稳定。
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = enemy
	return nearest


func _update_sprite(color_scheme: int) -> void:
	# 角色贴图运行时生成，不依赖外部素材。
	if sprite:
		sprite.texture = PixelGenerator.generate_player_sprite(color_scheme)


func _recompute_terrain_speed() -> void:
	# 规则：多地形重叠时以“最慢速度系数”为准。
	_terrain_speed_multiplier = 1.0
	for key in _terrain_effects.keys():
		_terrain_speed_multiplier = minf(_terrain_speed_multiplier, float(_terrain_effects[key]))
