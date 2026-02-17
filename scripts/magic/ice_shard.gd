extends MagicBase

# 冰霜碎片：直线弹道，命中敌人造成冰霜伤害并附着冰元素。
func _init() -> void:
	magic_id = "ice_shard"
	mana_cost = 10
	power = 20
	element = "ice"


func configure_from_def(def: Dictionary) -> void:
	mana_cost = int(def.get("mana_cost", mana_cost))
	power = int(def.get("power", power))
	element = str(def.get("element", element))


func cast(caster: Node2D, target_dir: Vector2) -> bool:
	if target_dir.length_squared() < 0.01:
		return false
	var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate() as Area2D
	if bullet == null:
		return false
	bullet.global_position = caster.global_position
	bullet.set("direction", target_dir.normalized())
	bullet.set("speed", 380.0)
	bullet.set("damage", power)
	bullet.set("hit_player", false)
	bullet.set("remaining_pierce", 0)
	bullet.set("elemental_type", element)
	bullet.set("bullet_type", "laser")
	bullet.set("bullet_color", Color(0.4, 0.7, 1.0, 1.0))
	bullet.set("owner_ref", caster)
	caster.get_tree().current_scene.add_child(bullet)
	return true
