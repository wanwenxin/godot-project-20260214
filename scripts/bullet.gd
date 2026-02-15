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

var direction := Vector2.RIGHT
var _hit_targets: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("bullets")
	# 子弹在 layer_3，仅与目标层发生重叠检测。
	collision_layer = 1 << 2
	collision_mask = 1 if hit_player else 2
	var texture_key := "bullet.enemy" if hit_player else "bullet.player"
	var fallback := func() -> Texture2D:
		return PixelGenerator.generate_bullet_sprite(hit_player)
	sprite.texture = VisualAssetRegistry.get_texture(texture_key, fallback)
	body_entered.connect(_on_body_entered)


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
			body.take_damage(damage)
		_handle_pierce_or_destroy()


func _handle_pierce_or_destroy() -> void:
	if remaining_pierce > 0:
		remaining_pierce -= 1
		return
	queue_free()
