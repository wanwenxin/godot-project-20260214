extends Area2D

@export var speed := 500.0
@export var damage := 10
@export var life_time := 2.0
@export var hit_player := false

var direction := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 if hit_player else 2
	sprite.texture = PixelGenerator.generate_bullet_sprite(hit_player)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	global_position += direction * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if hit_player and body.is_in_group("players"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif (not hit_player) and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
