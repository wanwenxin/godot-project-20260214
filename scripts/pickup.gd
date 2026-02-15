extends Area2D

# 掉落物：金币或治疗，玩家接触后生效并销毁；带初始向上飘动。
@export var pickup_type := "coin"  # "coin" 或 "heal"
@export var value := 1  # 金币数量或治疗量
@export var life_time := 10.0  # 超时未拾取则销毁（秒）

var _velocity := Vector2.ZERO  # 飘动速度，每帧衰减

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
		_apply_coin_visual_by_value()
	body_entered.connect(_on_body_entered)
	_velocity = Vector2(randf_range(-20.0, 20.0), randf_range(-30.0, -10.0))


func _process(delta: float) -> void:
	life_time -= delta
	if life_time <= 0.0:
		queue_free()
		return
	# 飘动：初速度向上，逐渐衰减至静止。
	# 飘动：初速度向上，逐渐衰减至静止。
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


func _apply_coin_visual_by_value() -> void:
	# 金币价值分层配色：低值铜币，中值银币，高值金币。
	if value <= 1:
		sprite.modulate = Color(0.80, 0.55, 0.25, 1.0)
	elif value <= 3:
		sprite.modulate = Color(0.75, 0.78, 0.82, 1.0)
	else:
		sprite.modulate = Color(1.0, 0.85, 0.22, 1.0)
