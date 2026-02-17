# 链锯近战武器：持续旋转攻击，在 spin_duration 内连续判定伤害。
extends "res://scripts/weapons/weapon_melee_base.gd"
class_name WeaponChainsaw

var spin_duration := 0.6  # 持续旋转时长
var _spin_elapsed := 0.0


func configure_from_def(def: Dictionary, weapon_tier: int = 0) -> void:
	super.configure_from_def(def, weapon_tier)
	var stats: Dictionary = def.get("stats", {})
	spin_duration = float(stats.get("spin_duration", spin_duration))


func _start_attack(owner_node: Node2D, target: Node2D) -> bool:
	_is_swinging = true
	_swing_elapsed = 0.0
	_swing_center_angle = (target.global_position - owner_node.global_position).angle()
	_apply_touch_hits()
	return true


func _tick_attack(_owner: Node2D, _target: Node2D, delta: float) -> void:
	if not _is_swinging:
		return
	_swing_elapsed += delta
	# 持续旋转：以目标方向为起点，顺时针旋转 360 度
	var spin_progress := _swing_elapsed / maxf(0.02, spin_duration)
	var sweep_angle := _swing_center_angle + spin_progress * TAU
	position = _slot_base_position + Vector2.RIGHT.rotated(sweep_angle) * swing_reach
	rotation = sweep_angle
	_apply_touch_hits()
	if spin_progress >= 1.0:
		_is_swinging = false
		position = _slot_base_position
		rotation = _slot_base_rotation
