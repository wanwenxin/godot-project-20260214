extends Area2D

# 掉落物：金币或治疗，玩家接触后生效并销毁；带初始向上飘动。
# 金币支持吸收范围：靠近时飞向玩家并有缩放动画。
# 支持对象池：acquire 时由 wave_manager 配置，recycle 时 reset_for_pool 重置。
@export var pickup_type := "coin"  # "coin" 或 "heal"
@export var value := 1  # 金币数量或治疗量
@export var life_time := 10.0  # 超时未拾取则销毁（秒）
@export var absorb_range: float = 80.0  # 金币吸收触发距离，进入后飞向玩家
@export var absorb_speed: float = 8.0  # 吸收时飞向玩家的插值速度
@export_file("*.png") var texture_coin: String = "res://assets/pickups/coin.png"  # 金币纹理
@export_file("*.png") var texture_heal: String = "res://assets/pickups/heal.png"  # 治疗纹理

var _velocity := Vector2.ZERO  # 飘动速度，每帧衰减
var _absorbing := false  # 是否处于吸收中（飞向玩家）

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# 沿用 bullet 层做重叠检测，不参与实体碰撞。
	collision_layer = 1 << 2
	collision_mask = 1
	var tex: Texture2D = null
	if pickup_type == "heal":
		if texture_heal != "" and ResourceLoader.exists(texture_heal):
			tex = load(texture_heal) as Texture2D
		if tex == null:
			tex = PixelGenerator.generate_pickup_sprite(true)
	else:
		if texture_coin != "" and ResourceLoader.exists(texture_coin):
			tex = load(texture_coin) as Texture2D
		if tex == null:
			tex = PixelGenerator.generate_pickup_sprite(false)
		_apply_coin_visual_by_value()
	sprite.texture = tex
	body_entered.connect(_on_body_entered)
	_velocity = Vector2(randf_range(-20.0, 20.0), randf_range(-30.0, -10.0))


func _process(delta: float) -> void:
	life_time -= delta
	if life_time <= 0.0:
		_recycle_or_free()
		return
	# 金币：检测玩家距离，进入吸收范围后飞向玩家并缩小。
	if pickup_type == "coin":
		var player := _get_player()
		if player != null:
			var dist := global_position.distance_to(player.global_position)
			if not _absorbing and dist < absorb_range:
				_absorbing = true
			if _absorbing:
				global_position = global_position.lerp(player.global_position, absorb_speed * delta)
				sprite.scale = sprite.scale.lerp(Vector2(0.3, 0.3), 6.0 * delta)
				if dist < 12.0:
					_do_pickup(player)
					return
	# 飘动：未吸收时初速度向上，逐渐衰减至静止。
	if not _absorbing:
		_velocity = _velocity.move_toward(Vector2.ZERO, 60.0 * delta)
		global_position += _velocity * delta


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p is Node2D:
			return p as Node2D
	return null


## [自定义] 执行拾取逻辑。defer_recycle=true 时延后回收，避免在 body_entered 物理回调中 remove_child 报错。
func _do_pickup(player: Node, defer_recycle: bool = false) -> void:
	if pickup_type == "coin":
		GameManager.add_currency(value)
	elif pickup_type == "heal" and player.has_method("heal"):
		player.heal(value)
	AudioManager.play_pickup()
	if defer_recycle:
		call_deferred("_recycle_or_free")
	else:
		_recycle_or_free()


## [自定义] 对象池 acquire 后由 wave_manager 调用，配置类型与数值并更新纹理。
func configure_for_spawn(p_type: String, val: int) -> void:
	pickup_type = p_type
	value = maxi(1, val)
	var tex: Texture2D = null
	if pickup_type == "heal":
		if texture_heal != "" and ResourceLoader.exists(texture_heal):
			tex = load(texture_heal) as Texture2D
		if tex == null:
			tex = PixelGenerator.generate_pickup_sprite(true)
	else:
		if texture_coin != "" and ResourceLoader.exists(texture_coin):
			tex = load(texture_coin) as Texture2D
		if tex == null:
			tex = PixelGenerator.generate_pickup_sprite(false)
		_apply_coin_visual_by_value()
	if sprite:
		sprite.texture = tex


## [自定义] 对象池回收时重置状态，供下次 acquire 使用。
func reset_for_pool() -> void:
	life_time = 10.0  # 恢复默认超时
	_velocity = Vector2(randf_range(-20.0, 20.0), randf_range(-30.0, -10.0))
	_absorbing = false
	if sprite:
		sprite.scale = Vector2(1.0, 1.0)


## [自定义] 优先回收到对象池，非池化实例则 queue_free。
func _recycle_or_free() -> void:
	if get_meta("object_pool_scene_path", "") != "":
		ObjectPool.recycle(self)
	else:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	_do_pickup(body, true)  # 物理回调中需 defer 回收，避免 remove_child 报错


func _apply_coin_visual_by_value() -> void:
	# 金币价值分层配色：低值铜币，中值银币，高值金币。
	# 若 sprite 未就绪（deferred add_child 时 configure_for_spawn 先于入树调用），跳过；_ready 会再次调用。
	if not is_instance_valid(sprite):
		return
	if value <= 1:
		sprite.modulate = Color(0.80, 0.55, 0.25, 1.0)
	elif value <= 3:
		sprite.modulate = Color(0.75, 0.78, 0.82, 1.0)
	else:
		sprite.modulate = Color(1.0, 0.85, 0.22, 1.0)
