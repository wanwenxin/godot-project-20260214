extends Node2D
# 一次性施法粒子爆发：用于绯焰弹、霜华刺、崩裂波等，在施放点播放短时粒子后自动 queue_free。
# 挂接：由 fire_bolt、ice_shard、area_shockwave 在 cast/cast_at_position 处实例化并 add_child 到当前场景；
# 实例化前通过 set_meta("burst_color", Color)、set_meta("cast_direction", Vector2)、set_meta("radial_360", bool) 设置样式。

func _ready() -> void:
	var color: Color = get_meta("burst_color", Color(1.0, 0.9, 0.7, 1.0))
	var cast_dir: Vector2 = get_meta("cast_direction", Vector2.RIGHT)
	var radial: bool = get_meta("radial_360", false)

	var particles := CPUParticles2D.new()
	particles.amount = 60
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = cast_dir if cast_dir.length_squared() > 0.01 else Vector2.RIGHT
	particles.spread = 360.0 if radial else 45.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 220.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 2.0
	particles.color = color
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	particles.emitting = true
	add_child(particles)

	var t := get_tree().create_timer(0.6)
	t.timeout.connect(_on_burst_finished)


## [系统] 定时器回调：粒子播完后释放节点
func _on_burst_finished() -> void:
	queue_free()
