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
	var def := MagicDefs.get_magic_by_id(magic_id)
	if def.is_empty():
		return false
	var radius: float = float(def.get("area_radius", 100.0))
	var tree := caster.get_tree()
	if tree == null:
		return false
	var enemies := tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or not node.has_method("take_damage"):
			continue
		var dist_sq: float = (node.global_position - world_pos).length_squared()
		if dist_sq <= radius * radius:
			node.take_damage(power, element)
			if is_instance_valid(caster) and caster.has_method("try_lifesteal"):
				caster.try_lifesteal()
	AudioManager.play_magic_cast()
	return true
