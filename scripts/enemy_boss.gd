extends EnemyBase

@export var bullet_scene: PackedScene
@export var fire_rate := 0.95

var _shoot_cd := 0.0


func _ready() -> void:
	super._ready()
	# Boss：高血量并拥有三连发扇形攻击。
	add_to_group("boss")
	set_enemy_texture(3)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		return
	_move_towards_player(delta, 0.55)

	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	if _shoot_cd > 0.0 or bullet_scene == null:
		return
	var to_player := (player_ref.global_position - global_position).normalized()
	for i in range(3):
		var bullet := bullet_scene.instantiate()
		if bullet == null:
			continue
		var offset_deg := lerpf(-18.0, 18.0, float(i) / 2.0)
		bullet.global_position = global_position
		bullet.set("direction", to_player.rotated(deg_to_rad(offset_deg)))
		bullet.set("speed", 300.0)
		bullet.set("damage", 11)
		bullet.set("hit_player", true)
		get_tree().current_scene.add_child(bullet)
	_shoot_cd = fire_rate
