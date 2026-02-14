extends "res://scripts/enemy_base.gd"

@export var preferred_distance := 220.0
@export var bullet_scene: PackedScene
@export var fire_rate := 1.25

var _shoot_cd := 0.0


func _ready() -> void:
	super._ready()
	set_enemy_texture(1)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		return

	var to_player := player_ref.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()

	if dist > preferred_distance + 25.0:
		velocity = dir * speed
	elif dist < preferred_distance - 25.0:
		velocity = -dir * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	_shoot_cd = max(_shoot_cd - delta, 0.0)
	if _shoot_cd <= 0.0 and bullet_scene != null:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.set("direction", dir)
		bullet.set("speed", 320.0)
		bullet.set("damage", 8)
		bullet.set("hit_player", true)
		get_tree().current_scene.add_child(bullet)
		_shoot_cd = fire_rate
