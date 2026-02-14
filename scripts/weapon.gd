extends Node

# 武器组件：
# - 管理射击冷却
# - 生成子弹并注入参数
@export var bullet_scene: PackedScene
@export var fire_rate := 0.3
@export var bullet_damage := 10
@export var bullet_speed := 500.0
@export var owner_is_enemy := false

var _cooldown := 0.0


func _process(delta: float) -> void:
	# 冷却递减，最低不小于 0。
	_cooldown = max(_cooldown - delta, 0.0)


func try_shoot(target_position: Vector2) -> void:
	# 冷却中或未配置子弹场景则直接返回。
	if _cooldown > 0.0:
		return
	if bullet_scene == null:
		return

	var bullet := bullet_scene.instantiate() as Node2D
	if bullet == null:
		return
	var origin := get_parent() as Node2D
	if origin == null:
		return
	var direction: Vector2 = (target_position - origin.global_position).normalized()

	# 将运行时参数注入子弹实例，实现同一子弹场景复用。
	bullet.global_position = origin.global_position
	bullet.set("direction", direction)
	bullet.set("speed", bullet_speed)
	bullet.set("damage", bullet_damage)
	bullet.set("hit_player", owner_is_enemy)

	get_tree().current_scene.add_child(bullet)
	# 射击成功后重置冷却。
	_cooldown = fire_rate
