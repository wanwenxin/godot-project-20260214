extends Node2D
# 持续型区域粒子：用于蚀魂域（燃烧区域），随 BurnZone 节点存在而持续发射，随 zone queue_free 一起释放。
# 挂接：由 burn_zone_node.gd 在 _ready 中实例化本场景并 add_child(self)。

func _ready() -> void:
	var particles := CPUParticles2D.new()
	particles.amount = 28
	particles.lifetime = 0.8
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.gravity = Vector2(0, -20)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	particles.color = Color(1.0, 0.35, 0.05, 0.9)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 45.0
	particles.emitting = true
	add_child(particles)
