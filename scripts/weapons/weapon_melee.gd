extends "res://scripts/weapons/weapon_base.gd"
class_name WeaponMelee


func _do_attack(_owner: Node2D, target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("take_damage"):
		target.take_damage(damage)
		AudioManager.play_hit()
		return true
	return false


func apply_upgrade(upgrade_id: String) -> void:
	super.apply_upgrade(upgrade_id)
	if upgrade_id == "speed":
		attack_range += 6.0
