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

var direction := Vector2.RIGHT
var _hit_targets: Dictionary = {}  # 已命中目标 instance_id，用于同目标去重

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("bullets")
	# 子弹在 layer_3，仅与目标层发生重叠检测。
	collision_layer = 1 << 2
	collision_mask = 1 if hit_player else 2
	_apply_collision_radius()
	_apply_bullet_appearance()
	body_entered.connect(_on_body_entered)


## 按 collision_radius 设置碰撞形状，仅 _ready 时执行一次。
func _apply_collision_radius() -> void:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = collision_radius


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


func _process(delta: float) -> void:
	# 简单直线弹道。
	global_position += direction * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# 命中后立即销毁，避免重复结算。
	# 同一目标只结算一次，避免 Area 重叠导致重复伤害。
	if _hit_targets.has(body.get_instance_id()):
		return
	_hit_targets[body.get_instance_id()] = true

	if hit_player and body.is_in_group("players"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			AudioManager.play_hit()
		_handle_pierce_or_destroy()
	elif (not hit_player) and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage, elemental_type)
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
	queue_free()
