extends CharacterBody2D

# 玩家主体：
# - 输入移动
# - 自动索敌
# - 受伤/无敌帧/死亡
signal died
signal health_changed(current: int, max_value: int)

@export var base_speed := 160.0
@export var max_health := 100
@export var invulnerable_duration := 0.35

var current_health := 100
var move_input := Vector2.ZERO
var _invulnerable_timer := 0.0
var _character_data := {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon: Node = $Weapon


func _ready() -> void:
	add_to_group("players")
	# 玩家仅与敌人发生实体碰撞，子弹通过 Area2D 处理。
	collision_layer = 1
	collision_mask = 2
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
	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	# 使用 Input.get_vector 自动处理对角线归一化。
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = move_input * base_speed
	move_and_slide()

	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta

	var nearest_enemy := _get_nearest_enemy()
	if nearest_enemy != null and weapon:
		# 自动朝最近敌人开火（Brotato 风格核心体验）。
		weapon.call("try_shoot", nearest_enemy.global_position)


func take_damage(amount: int) -> void:
	# 无敌计时器 > 0 时忽略后续伤害，避免多次碰撞瞬间秒杀。
	if _invulnerable_timer > 0.0:
		return
	current_health = max(current_health - amount, 0)
	_invulnerable_timer = invulnerable_duration
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0:
		emit_signal("died")
		queue_free()


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
