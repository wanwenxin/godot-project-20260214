extends MagicBase

# 燃烧区域：区域型魔法，在范围内生成持续伤害区域。
# 由 magic_targeting_overlay 选择位置后调用 cast_at_position。
# 持续 burn_duration 秒，每 burn_interval 秒对区域内敌人造成 burn_damage_per_tick 伤害。

func _init() -> void:
	magic_id = "burn_zone"
	mana_cost = 20
	power = 15
	element = "fire"


func configure_from_def(def: Dictionary, tier: int = 0) -> void:
	super.configure_from_def(def, tier)


func cast_at_position(caster: Node2D, world_pos: Vector2) -> bool:
	var tree := caster.get_tree()
	if tree == null:
		return false
	var scene := tree.current_scene
	if scene == null:
		return false
	var zone := Node2D.new()
	zone.name = "BurnZone"
	# 持续伤害参数由 effect_dot 词条提供，范围由 range 词条提供
	zone.set_script(preload("res://scripts/magic/burn_zone_node.gd"))
	zone.set_meta("burn_duration", burn_duration)
	zone.set_meta("burn_damage_per_tick", burn_damage_per_tick)
	zone.set_meta("burn_interval", burn_interval)
	zone.set_meta("area_radius", range_size)
	zone.set_meta("element", element)
	zone.set_meta("caster", caster)
	zone.global_position = world_pos
	scene.add_child(zone)
	AudioManager.play_magic_cast()
	return true
