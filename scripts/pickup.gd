extends Area2D

@export var pickup_type := "coin"
@export var value := 1
@export var life_time := 10.0

var _velocity := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# 沿用 bullet 层做重叠检测，不参与实体碰撞。
	collision_layer = 1 << 2
	collision_mask = 1
	if pickup_type == "heal":
		var fallback_heal := func() -> Texture2D:
			return PixelGenerator.generate_pickup_sprite(true)
		sprite.texture = VisualAssetRegistry.get_texture("pickup.heal", fallback_heal)
	else:
		var fallback_coin := func() -> Texture2D:
			return PixelGenerator.generate_pickup_sprite(false)
		sprite.texture = VisualAssetRegistry.get_texture("pickup.coin", fallback_coin)
	body_entered.connect(_on_body_entered)
	_velocity = Vector2(randf_range(-20.0, 20.0), randf_range(-30.0, -10.0))


func _process(delta: float) -> void:
	life_time -= delta
	if life_time <= 0.0:
		queue_free()
		return
	_velocity = _velocity.move_toward(Vector2.ZERO, 60.0 * delta)
	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	if pickup_type == "coin":
		GameManager.add_currency(value)
	elif pickup_type == "heal" and body.has_method("heal"):
		body.heal(value)
	AudioManager.play_pickup()
	queue_free()
