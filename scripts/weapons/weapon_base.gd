extends Node2D
class_name WeaponBase

# 武器基础类：
# - 提供统一冷却、配置、升级与槽位姿态接口
# - 由近战/远程基类继承扩展具体攻击行为
var weapon_id := ""
var weapon_type := ""
var cooldown := 0.35
var damage := 8
var attack_range := 120.0
var color_hint := Color(0.9, 0.9, 0.9, 1.0)

var _cooldown_left := 0.0
var _slot_base_position := Vector2.ZERO
var _slot_base_rotation := 0.0
var _owner_ref: Node2D  # 持有者（Player），供子类调用 get_final_damage 等


# 从武器定义字典初始化 id、type、color、damage、cooldown、range。
func configure_from_def(def: Dictionary) -> void:
	weapon_id = str(def.get("id", ""))
	weapon_type = str(def.get("type", ""))
	color_hint = def.get("color", color_hint)
	var stats: Dictionary = def.get("stats", {})
	damage = int(stats.get("damage", damage))
	cooldown = float(stats.get("cooldown", cooldown))
	attack_range = float(stats.get("range", attack_range))


# 每帧调用：扣减冷却，冷却归零且距离足够时尝试 _start_attack，成功则重置冷却。
func tick_and_try_attack(owner_node: Node2D, target: Node2D, delta: float) -> void:
	_owner_ref = owner_node
	_tick_attack(owner_node, target, delta)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left > 0.0:
		return
	if not is_instance_valid(owner_node) or not is_instance_valid(target):
		return
	if owner_node.global_position.distance_to(target.global_position) > attack_range:
		return
	if _start_attack(owner_node, target):
		_cooldown_left = cooldown


func set_slot_pose(local_position: Vector2, local_rotation: float) -> void:
	# 玩家在武器环布局刷新时下发槽位姿态。
	_slot_base_position = local_position
	_slot_base_rotation = local_rotation
	position = local_position
	rotation = local_rotation


func _start_attack(_owner: Node2D, _target: Node2D) -> bool:
	return false


func _tick_attack(_owner: Node2D, _target: Node2D, _delta: float) -> void:
	pass


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			damage += 3
		"fire_rate":
			cooldown = maxf(0.08, cooldown - 0.03)
