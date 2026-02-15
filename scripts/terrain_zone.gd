extends Area2D

# 地形区：
# - grass: 轻微减速
# - shallow_water: 中等减速
# - deep_water: 强减速 + 持续伤害
@export var terrain_type := "grass"
@export var speed_multiplier := 0.9
@export var damage_per_tick := 0
@export var damage_interval := 1.0

var _tracked_bodies: Dictionary = {}  # 当前在地形内的单位 instance_id -> body，用于 DOT 与离开时清除


func _ready() -> void:
	monitoring = true
	monitorable = true
	# 地形区只做检测，不作为实体碰撞层参与物理阻挡。
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if damage_per_tick <= 0:
		return
	# 对 _tracked_bodies 中的单位按 damage_interval 施加 DOT（当前仅深水）。
	var ids := _tracked_bodies.keys()
	for body_id in ids:
		var body: Node = _tracked_bodies.get(body_id, null)
		if not is_instance_valid(body):
			_tracked_bodies.erase(body_id)
			continue
		var cd: float = float(body.get_meta("terrain_damage_cd_%s" % str(get_instance_id()), 0.0))
		cd -= delta
		if cd <= 0.0:
			if body.has_method("take_damage"):
				body.take_damage(damage_per_tick)
			cd = damage_interval
		body.set_meta("terrain_damage_cd_%s" % str(get_instance_id()), cd)


func _on_body_entered(body: Node) -> void:
	if not (body.is_in_group("players") or body.is_in_group("enemies")):
		return
	_tracked_bodies[body.get_instance_id()] = body
	if body.has_method("set_terrain_effect"):
		# 速度变化交给单位本身合并多个地形影响。
		body.set_terrain_effect(get_instance_id(), speed_multiplier)
	body.set_meta("terrain_damage_cd_%s" % str(get_instance_id()), damage_interval)


func _on_body_exited(body: Node) -> void:
	_tracked_bodies.erase(body.get_instance_id())
	if body.has_method("clear_terrain_effect"):
		body.clear_terrain_effect(get_instance_id())
	body.remove_meta("terrain_damage_cd_%s" % str(get_instance_id()))
