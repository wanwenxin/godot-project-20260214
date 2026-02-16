extends EnemyBase

# 远程敌人：
# - 维持与玩家的期望距离
# - 周期性发射敌方子弹
@export var preferred_distance := 220.0
@export var bullet_scene: PackedScene
@export var fire_rate := 1.25

var _shoot_cd := 0.0


func _ready() -> void:
	super._ready()
	# 远程敌人外观：紫色菱形风格。
	set_enemy_texture(1)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		return

	var to_player := player_ref.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()

	# 与玩家距离控制：
	# - 太远则靠近
	# - 太近则后退
	# - 在舒适区间内停留射击
	if dist > preferred_distance + 25.0:
		velocity = dir * speed
	elif dist < preferred_distance - 25.0:
		velocity = -dir * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	_shoot_cd = max(_shoot_cd - delta, 0.0)
	if _shoot_cd <= 0.0 and bullet_scene != null:
		# 复用通用 bullet 场景，通过 hit_player 区分阵营。
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.set("direction", dir)
		bullet.set("speed", 190.0)
		bullet.set("damage", 8)
		bullet.set("hit_player", true)
		get_tree().current_scene.add_child(bullet)
		_shoot_cd = fire_rate
