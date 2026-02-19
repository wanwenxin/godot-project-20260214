extends MagicBase

# 冲击波：区域型魔法，一次性对范围内敌人造成伤害。
# 由 magic_targeting_overlay 选择位置后调用 cast_at_position。


func _init() -> void:
	magic_id = "shockwave"
	mana_cost = 15
	power = 40
	element = "physical"


func configure_from_def(def: Dictionary, tier: int = 0) -> void:
	super.configure_from_def(def, tier)


func cast_at_position(caster: Node2D, world_pos: Vector2) -> bool:
	var radius: float = range_size  # 由范围词条 value_default 提供
	var tree := caster.get_tree()
	if tree == null:
		return false
	var enemies := tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or not node.has_method("take_damage"):
			continue
		var dist_sq: float = (node.global_position - world_pos).length_squared()
		if dist_sq <= radius * radius:
			node.take_damage(power, element, EnemyBase.ELEMENT_AMOUNT_LARGE)
			GameManager.add_record_damage_dealt(power)
			if is_instance_valid(caster) and caster.has_method("try_lifesteal"):
				caster.try_lifesteal()
	var burst_scene: PackedScene = preload("res://scenes/vfx/magic_cast_burst.tscn")
	var burst: Node2D = burst_scene.instantiate()
	burst.set_meta("burst_color", Color(0.85, 0.85, 0.9, 1.0))
	burst.set_meta("cast_direction", Vector2.RIGHT)
	burst.set_meta("radial_360", true)
	burst.global_position = world_pos
	tree.current_scene.add_child(burst)
	AudioManager.play_magic_cast()
	return true
