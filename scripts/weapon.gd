extends Node

@export var bullet_scene: PackedScene
@export var fire_rate := 0.3
@export var bullet_damage := 10
@export var bullet_speed := 500.0
@export var owner_is_enemy := false

var _cooldown := 0.0


func _process(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)


func try_shoot(target_position: Vector2) -> void:
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

	bullet.global_position = origin.global_position
	bullet.set("direction", direction)
	bullet.set("speed", bullet_speed)
	bullet.set("damage", bullet_damage)
	bullet.set("hit_player", owner_is_enemy)

	get_tree().current_scene.add_child(bullet)
	_cooldown = fire_rate
