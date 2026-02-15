extends Node

# 武器组件：
# - 管理射击冷却
# - 生成子弹并注入参数
@export var bullet_scene: PackedScene
@export var fire_rate := 0.3
@export var bullet_damage := 10
@export var bullet_speed := 500.0
@export var owner_is_enemy := false
# 扩散/穿透参数：用于升级系统和角色差异化。
@export var pellet_count := 1
@export var spread_degrees := 0.0
@export var bullet_pierce := 0

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

	var origin := get_parent() as Node2D
	if origin == null:
		return
	var base_direction: Vector2 = (target_position - origin.global_position).normalized()
	var bullets := maxi(pellet_count, 1)
	for i in range(bullets):
		var bullet := bullet_scene.instantiate() as Node2D
		if bullet == null:
			continue
		var offset_deg := 0.0
		if bullets > 1:
			# 线性分布扇形角度，保证左右对称。
			offset_deg = lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, float(i) / float(bullets - 1))
		var direction := base_direction.rotated(deg_to_rad(offset_deg))

		# 将运行时参数注入子弹实例，实现同一子弹场景复用。
		bullet.global_position = origin.global_position
		bullet.set("direction", direction)
		bullet.set("speed", bullet_speed)
		bullet.set("damage", bullet_damage)
		bullet.set("hit_player", owner_is_enemy)
		bullet.set("remaining_pierce", bullet_pierce)

		get_tree().current_scene.add_child(bullet)
	if not owner_is_enemy:
		AudioManager.play_shoot()
	# 射击成功后重置冷却。
	_cooldown = fire_rate
