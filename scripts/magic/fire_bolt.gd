extends MagicBase

# 火球术：直线弹道，命中敌人造成火焰伤害并附着火元素。
var _scene: PackedScene  # 弹道场景，运行时加载
var _burst_scene: PackedScene = preload("res://scenes/vfx/magic_cast_burst.tscn")


func _init() -> void:
	magic_id = "fire_bolt"
	mana_cost = 8
	power = 25
	element = "fire"


func configure_from_def(def: Dictionary, tier: int = 0) -> void:
	super.configure_from_def(def, tier)


func cast(caster: Node2D, target_dir: Vector2) -> bool:
	if target_dir.length_squared() < 0.01:
		return false
	var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
	var root: Node = caster.get_tree().current_scene
	var bullet := ObjectPool.acquire(bullet_scene, root) as Area2D
	if bullet == null:
		return false
	bullet.global_position = caster.global_position
	bullet.set("direction", target_dir.normalized())
	bullet.set("speed", 450.0)
	bullet.set("damage", power)
	bullet.set("hit_player", false)
	bullet.collision_mask = 2  # 玩家魔法子弹碰撞敌人层
	bullet.set("remaining_pierce", 0)
	bullet.set("elemental_type", element)
	bullet.set("elemental_amount", EnemyBase.ELEMENT_AMOUNT_LARGE)
	bullet.set("bullet_type", "laser")
	bullet.set("bullet_color", Color(1.0, 0.4, 0.1, 1.0))
	bullet.set("owner_ref", caster)
	_spawn_cast_burst(root, caster.global_position, target_dir.normalized(), Color(1.0, 0.45, 0.1, 1.0), false)
	return true


## [自定义] 在指定位置生成一次性施法粒子爆发（硬编码路径：scenes/vfx/magic_cast_burst.tscn）
func _spawn_cast_burst(parent: Node, pos: Vector2, dir: Vector2, burst_color: Color, radial_360: bool) -> void:
	var burst: Node2D = _burst_scene.instantiate()
	burst.set_meta("burst_color", burst_color)
	burst.set_meta("cast_direction", dir)
	burst.set_meta("radial_360", radial_360)
	burst.global_position = pos
	parent.add_child(burst)
