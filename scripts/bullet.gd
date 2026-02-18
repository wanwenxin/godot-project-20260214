extends Area2D

# 通用子弹：
# - hit_player=false: 玩家子弹，命中敌人
# - hit_player=true: 敌人子弹，命中玩家
@export var speed := 500.0
@export var damage := 10
@export var life_time := 2.0
@export var hit_player := false
# 穿透次数：>0 时命中后不销毁，递减至 0 后销毁。
@export var remaining_pierce := 0
@export_file("*.png") var texture_path: String  # 子弹纹理，空则按 bullet_type 或 PixelGenerator
@export var collision_radius: float = 3.0  # 碰撞圆半径，_ready 时设置一次
# 玩家子弹按类型区分外观：pistol/shotgun/rifle/laser
var bullet_type := ""
var bullet_color := Color(1.0, 1.0, 0.4, 1.0)
# 元素附魔类型（如 "fire"），命中时传入 enemy.take_damage
var elemental_type := ""
# 玩家子弹的持有者，用于吸血等回调
var owner_ref: Node2D = null

var direction := Vector2.RIGHT
var _hit_targets: Dictionary = {}  # 已命中目标 instance_id，用于同目标去重

@onready var sprite: Sprite2D = $Sprite2D


## [自定义] 对象池回收时重置状态，避免残留 _hit_targets 等。
func reset_for_pool() -> void:
	_hit_targets.clear()
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


## [系统] 节点入树时调用，设置碰撞层、外观、连接 body_entered。
func _ready() -> void:
	add_to_group("bullets")
	# 子弹在 layer_3，仅与目标层发生重叠检测。
	collision_layer = 1 << 2
	collision_mask = 1 if hit_player else 2
	_apply_collision_radius()
	_apply_bullet_appearance()
	body_entered.connect(_on_body_entered)


## [自定义] 按 collision_radius 设置碰撞形状，仅 _ready 时执行一次。
func _apply_collision_radius() -> void:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = collision_radius


## [自定义] 设置子弹外观。动态加载：texture_path 来自 @export，ResourceLoader.exists 校验后 load()，失败则 PixelGenerator。
func _apply_bullet_appearance() -> void:
	# 优先 texture_path，空则按 bullet_type/hit_player 回退 PixelGenerator。
	var tex: Texture2D = null
	if texture_path != "" and ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	if tex != null:
		sprite.texture = tex
		sprite.modulate = bullet_color if bullet_type != "" else Color.WHITE
		if bullet_type == "rifle" or bullet_type == "laser":
			sprite.rotation = direction.angle()
		return
	if not hit_player and bullet_type != "":
		sprite.texture = PixelGenerator.generate_bullet_sprite_by_type(bullet_type, bullet_color)
		sprite.modulate = bullet_color
		if bullet_type == "rifle" or bullet_type == "laser":
			sprite.rotation = direction.angle()
	else:
		sprite.texture = PixelGenerator.generate_bullet_sprite(hit_player)


## [系统] 每帧调用，直线移动、超时或出界时销毁。
func _process(delta: float) -> void:
	# 简单直线弹道。
	global_position += direction * speed * delta
	if hit_player:
		# 敌人子弹：出界前不消失，仅当超出可玩区域时销毁。
		var bounds := _get_destroy_bounds()
		if not bounds.has_point(global_position):
			_recycle_or_free()
	else:
		# 玩家子弹：沿用 life_time 逻辑。
		life_time -= delta
		if life_time <= 0.0:
			_recycle_or_free()


## [自定义] 获取子弹销毁边界：优先用游戏可玩区域，否则用视口加边距。
func _get_destroy_bounds() -> Rect2:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_playable_bounds"):
		return scene.get_playable_bounds()
	var vp := get_viewport_rect()
	var margin := 64.0
	return Rect2(vp.position - Vector2(margin, margin), vp.size + Vector2(margin * 2.0, margin * 2.0))


## [系统] body_entered 信号回调，命中目标时结算伤害、穿透或销毁。
func _on_body_entered(body: Node) -> void:
	# 命中后立即销毁，避免重复结算。
	# 同一目标只结算一次，避免 Area 重叠导致重复伤害。
	if _hit_targets.has(body.get_instance_id()):
		return
	_hit_targets[body.get_instance_id()] = true

	if hit_player and body.is_in_group("players"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_handle_pierce_or_destroy()
	elif (not hit_player) and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage, elemental_type)
			GameManager.add_record_damage_dealt(damage)
		if is_instance_valid(owner_ref) and owner_ref.has_method("try_lifesteal"):
			owner_ref.try_lifesteal()
		if body.has_method("apply_knockback") and bullet_type != "":
			var force := 40.0
			match bullet_type:
				"shotgun": force = 80.0
				"rifle": force = 55.0
				"laser": force = 25.0
				"orb": force = 35.0
				_: force = 40.0
			body.apply_knockback(direction, force)
		_spawn_hit_flash(global_position, bullet_color if bullet_type != "" else Color(1.0, 1.0, 0.4))
		_handle_pierce_or_destroy()


func _spawn_hit_flash(pos: Vector2, color: Color) -> void:
	# 简单命中反馈：短暂闪烁，颜色与子弹一致。
	var flash := ColorRect.new()
	flash.size = Vector2(12, 12)
	flash.position = pos - flash.size * 0.5
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(flash)
	flash.z_index = 100
	var tween := flash.create_tween()
	tween.tween_property(flash, "color", Color(color.r, color.g, color.b, 0.0), 0.08)
	tween.tween_callback(flash.queue_free)


# 穿透弹：remaining_pierce>0 时递减并保留，否则销毁。
func _handle_pierce_or_destroy() -> void:
	if remaining_pierce > 0:
		remaining_pierce -= 1
		return
	_recycle_or_free()


## [自定义] 优先回收到对象池，非池化实例则 queue_free。
func _recycle_or_free() -> void:
	if get_meta("object_pool_scene_path", "") != "":
		ObjectPool.recycle(self)
	else:
		queue_free()
