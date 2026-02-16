extends "res://scripts/weapons/weapon_base.gd"
class_name WeaponRangedBase

# 远程基类：
# - 统一远程弹道参数
# - 子弹从武器节点位置发射
# - 按 bullet_type 区分子弹颜色与外形
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var bullet_type := ""
var bullet_speed := 500.0
var pellet_count := 1
var spread_degrees := 0.0
var bullet_pierce := 0


func configure_from_def(def: Dictionary) -> void:
	super.configure_from_def(def)
	bullet_type = str(def.get("bullet_type", ""))
	var stats: Dictionary = def.get("stats", {})
	bullet_speed = float(stats.get("bullet_speed", bullet_speed))
	pellet_count = int(stats.get("pellet_count", pellet_count))
	spread_degrees = float(stats.get("spread_degrees", spread_degrees))
	bullet_pierce = int(stats.get("bullet_pierce", bullet_pierce))


func _start_attack(_owner_node: Node2D, target: Node2D) -> bool:
	if bullet_scene == null:
		return false
	var final_damage := damage
	var elemental := ""
	if is_instance_valid(_owner_ref) and _owner_ref.has_method("get_final_damage"):
		final_damage = _owner_ref.get_final_damage(damage, weapon_id, {"is_melee": false})
	if is_instance_valid(_owner_ref) and _owner_ref.has_method("get_elemental_enchantment"):
		elemental = _owner_ref.get_elemental_enchantment()
	var base_direction: Vector2 = (target.global_position - global_position).normalized()
	var bullets := maxi(1, pellet_count)
	var did_shoot := false
	for i in range(bullets):
		var bullet := bullet_scene.instantiate() as Node2D
		if bullet == null:
			continue
		var offset_deg := 0.0
		if bullets > 1:
			offset_deg = lerpf(-spread_degrees * 0.5, spread_degrees * 0.5, float(i) / float(bullets - 1))
		var direction: Vector2 = base_direction.rotated(deg_to_rad(offset_deg))
		bullet.global_position = global_position
		bullet.set("direction", direction)
		bullet.set("speed", bullet_speed)
		bullet.set("damage", final_damage)
		bullet.set("hit_player", false)
		bullet.set("remaining_pierce", bullet_pierce)
		bullet.set("elemental_type", elemental)
		if bullet_type != "":
			bullet.set("bullet_type", bullet_type)
			bullet.set("bullet_color", color_hint)
		get_tree().current_scene.add_child(bullet)
		did_shoot = true
	if did_shoot:
		if bullet_type != "":
			AudioManager.play_shoot_by_type(bullet_type)
		else:
			AudioManager.play_shoot()
	return did_shoot


func apply_upgrade(upgrade_id: String) -> void:
	super.apply_upgrade(upgrade_id)
	match upgrade_id:
		"bullet_speed":
			bullet_speed += 60.0
		"multi_shot":
			pellet_count = mini(pellet_count + 1, 6)
			spread_degrees = maxf(spread_degrees, 20.0)
		"pierce":
			bullet_pierce = mini(bullet_pierce + 1, 5)
