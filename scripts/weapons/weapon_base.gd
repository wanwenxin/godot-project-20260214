extends Node
class_name WeaponBase

var weapon_id := ""
var weapon_type := ""
var cooldown := 0.35
var damage := 8
var attack_range := 120.0
var color_hint := Color(0.9, 0.9, 0.9, 1.0)

var _cooldown_left := 0.0


func configure_from_def(def: Dictionary) -> void:
	weapon_id = str(def.get("id", ""))
	weapon_type = str(def.get("type", ""))
	color_hint = def.get("color", color_hint)
	var stats: Dictionary = def.get("stats", {})
	damage = int(stats.get("damage", damage))
	cooldown = float(stats.get("cooldown", cooldown))
	attack_range = float(stats.get("range", attack_range))


func tick_and_try_attack(owner_node: Node2D, target: Node2D, delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left > 0.0:
		return
	if not is_instance_valid(owner_node) or not is_instance_valid(target):
		return
	if owner_node.global_position.distance_to(target.global_position) > attack_range:
		return
	if _do_attack(owner_node, target):
		_cooldown_left = cooldown


func _do_attack(_owner: Node2D, _target: Node2D) -> bool:
	return false


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			damage += 3
		"fire_rate":
			cooldown = maxf(0.08, cooldown - 0.03)
