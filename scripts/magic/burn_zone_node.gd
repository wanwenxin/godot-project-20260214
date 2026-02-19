extends Node2D

# 燃烧区域节点：持续存在一段时间，周期性对范围内敌人造成伤害。
# 由 area_burn.gd 的 cast_at_position 实例化并设置 meta。
var _elapsed := 0.0
var _tick_cd := 0.0

var _zone_fire_scene: PackedScene = preload("res://scenes/vfx/magic_zone_fire.tscn")  # 持续型区域粒子，与 zone 同生共死


## [系统] 挂接持续型火焰粒子（scenes/vfx/magic_zone_fire.tscn），随本节点 queue_free 一起释放
func _ready() -> void:
	var vfx: Node2D = _zone_fire_scene.instantiate()
	add_child(vfx)


func _process(delta: float) -> void:
	_elapsed += delta
	var duration: float = get_meta("burn_duration", 4.0)
	if _elapsed >= duration:
		queue_free()
		return
	_tick_cd -= delta
	var interval: float = get_meta("burn_interval", 0.5)
	if _tick_cd <= 0.0:
		_tick_cd = interval
		var radius: float = float(get_meta("area_radius", 80.0))
		var dmg: int = int(get_meta("burn_damage_per_tick", 8))
		var elem: String = str(get_meta("element", "fire"))
		var caster_ref = get_meta("caster")
		for node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or not node.has_method("take_damage"):
				continue
			if (node.global_position - global_position).length_squared() <= radius * radius:
				node.take_damage(dmg, elem, EnemyBase.ELEMENT_AMOUNT_LARGE)
				GameManager.add_record_damage_dealt(dmg)
				if is_instance_valid(caster_ref) and caster_ref.has_method("try_lifesteal"):
					caster_ref.try_lifesteal()
