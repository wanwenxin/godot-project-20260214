extends Area2D

# 通用子弹：
# - hit_player=false: 玩家子弹，命中敌人
# - hit_player=true: 敌人子弹，命中玩家
@export var speed := 500.0
@export var damage := 10
@export var life_time := 2.0
@export var hit_player := false

var direction := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# 子弹在 layer_3，仅与目标层发生重叠检测。
	collision_layer = 4
	collision_mask = 1 if hit_player else 2
	sprite.texture = PixelGenerator.generate_bullet_sprite(hit_player)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# 简单直线弹道。
	global_position += direction * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# 命中后立即销毁，避免重复结算。
	if hit_player and body.is_in_group("players"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif (not hit_player) and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
