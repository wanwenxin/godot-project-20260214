extends "res://scripts/weapons/weapon_base.gd"
class_name WeaponMeleeBase

# 近战基类：
# - 攻击时武器执行挥击位移
# - 仅在碰触敌人时结算伤害
# - 每个武器-敌人独立 touch interval
var touch_interval := 0.38
var swing_duration := 0.20
var swing_degrees := 110.0
var swing_reach := 22.0
var hitbox_radius := 14.0
@export_file("*.png") var swing_texture_path: String  # 挥击刀刃/锤头纹理，空则色块
@export var swing_frame_size: Vector2i = Vector2i(24, 8)  # 挥击图尺寸（色块回退时用）

var _enemy_last_hit: Dictionary = {}
var _is_swinging := false
var _swing_elapsed := 0.0
var _swing_center_angle := 0.0
var _swing_dir := 1.0

var _hit_area: Area2D
var _hit_shape: CollisionShape2D


func _ready() -> void:
	_build_hit_area()


func configure_from_def(def: Dictionary, weapon_tier: int = 0) -> void:
	super.configure_from_def(def, weapon_tier)
	swing_texture_path = str(def.get("swing_texture_path", swing_texture_path))
	var frame: Variant = def.get("swing_frame_size")
	if frame is Vector2i:
		swing_frame_size = frame
	elif frame is Array and frame.size() >= 2:
		swing_frame_size = Vector2i(int(frame[0]), int(frame[1]))
	var stats: Dictionary = def.get("stats", {})
	touch_interval = float(stats.get("touch_interval", touch_interval)) * TierConfig.get_cooldown_multiplier(tier)
	swing_duration = float(stats.get("swing_duration", swing_duration))
	swing_degrees = float(stats.get("swing_degrees", swing_degrees))
	swing_reach = float(stats.get("swing_reach", swing_reach))
	hitbox_radius = float(stats.get("hitbox_radius", hitbox_radius))
	_refresh_hit_shape()


func set_slot_pose(local_position: Vector2, local_rotation: float) -> void:
	_slot_base_position = local_position
	_slot_base_rotation = local_rotation
	if not _is_swinging:
		position = local_position
		rotation = local_rotation


func _start_attack(owner_node: Node2D, target: Node2D) -> bool:
	# 攻击开启后进入“挥击窗口”，真正伤害由碰触逻辑触发。
	_is_swinging = true
	_swing_elapsed = 0.0
	_swing_center_angle = (target.global_position - owner_node.global_position).angle()
	_swing_dir = -1.0 if int(Time.get_ticks_msec() / 100.0) % 2 == 0 else 1.0
	_apply_touch_hits()
	return true


func _tick_attack(_owner: Node2D, _target: Node2D, delta: float) -> void:
	if not _is_swinging:
		return
	_swing_elapsed += delta
	var progress := clampf(_swing_elapsed / maxf(0.02, swing_duration), 0.0, 1.0)
	var start_deg := -swing_degrees * 0.5 * _swing_dir
	var end_deg := swing_degrees * 0.5 * _swing_dir
	var sweep_angle := _swing_center_angle + deg_to_rad(lerpf(start_deg, end_deg, progress))

	position = _slot_base_position + Vector2.RIGHT.rotated(sweep_angle) * swing_reach
	rotation = sweep_angle
	_apply_touch_hits()

	if progress >= 1.0:
		_is_swinging = false
		position = _slot_base_position
		rotation = _slot_base_rotation


func _apply_touch_hits() -> void:
	if _hit_area == null:
		return
	var final_damage := damage
	var elemental := ""
	if is_instance_valid(_owner_ref) and _owner_ref.has_method("get_final_damage"):
		final_damage = _owner_ref.get_final_damage(damage, weapon_id, {"is_melee": true})
		if _owner_ref.has_method("get_elemental_enchantment"):
			elemental = _owner_ref.get_elemental_enchantment()
	if is_instance_valid(_owner_ref) and _owner_ref.has_method("get_melee_damage_bonus"):
		final_damage += _owner_ref.get_melee_damage_bonus()
	for body in _hit_area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if not body.is_in_group("enemies"):
			continue
		if not body.has_method("take_damage"):
			continue
		if not _can_hit_enemy(body):
			continue
		body.take_damage(final_damage, elemental)
		GameManager.add_record_damage_dealt(final_damage)
		if is_instance_valid(_owner_ref) and _owner_ref.has_method("try_lifesteal"):
			_owner_ref.try_lifesteal()
		_enemy_last_hit[body.get_instance_id()] = float(Time.get_ticks_msec()) / 1000.0
		AudioManager.play_hit()


func _can_hit_enemy(enemy: Node) -> bool:
	var enemy_id := enemy.get_instance_id()
	var now_sec := float(Time.get_ticks_msec()) / 1000.0
	if not _enemy_last_hit.has(enemy_id):
		return true
	return now_sec - float(_enemy_last_hit[enemy_id]) >= touch_interval


func _build_hit_area() -> void:
	if _hit_area != null:
		return
	# 可见刀刃/锤头：随武器挥击移动，形成动作反馈
	_build_swing_visual()
	_hit_area = Area2D.new()
	_hit_area.monitoring = true
	_hit_area.monitorable = false
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 2
	add_child(_hit_area)

	_hit_shape = CollisionShape2D.new()
	_hit_area.add_child(_hit_shape)
	_refresh_hit_shape()


func _build_swing_visual() -> void:
	# 近战武器挥击时可见的刀刃/锤头，位于武器前方；优先 swing_texture_path，失败则色块。
	var spr := Sprite2D.new()
	spr.name = "SwingVisual"
	var tex: Texture2D = null
	if swing_texture_path != "" and ResourceLoader.exists(swing_texture_path):
		tex = load(swing_texture_path) as Texture2D
	if tex == null:
		tex = VisualAssetRegistry.make_color_texture(color_hint, swing_frame_size)
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(swing_frame_size.x * 0.5, swing_frame_size.y * 0.5)
	add_child(spr)


func _refresh_hit_shape() -> void:
	if _hit_shape == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = maxf(6.0, hitbox_radius)
	_hit_shape.shape = shape


func apply_upgrade(upgrade_id: String) -> void:
	super.apply_upgrade(upgrade_id)
	if upgrade_id == "speed":
		attack_range += 8.0
