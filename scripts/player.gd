extends CharacterBody2D

# 玩家主体：
# - 输入移动
# - 自动索敌
# - 受伤/无敌帧/死亡
signal died
signal health_changed(current: int, max_value: int)
signal damaged(amount: int)

@export var base_speed := 160.0
@export var max_health := 100
@export var invulnerable_duration := 0.35

var current_health := 100
var move_input := Vector2.ZERO
var _invulnerable_timer := 0.0
var _character_data := {}
var external_move_input := Vector2.ZERO
var input_enabled := true
var _nearest_enemy_refresh := 0.0
var _cached_nearest_enemy: Node2D
# 多地形叠加时记录每个 zone 的速度系数，取最慢值。
var _terrain_effects: Dictionary = {}
var _terrain_speed_multiplier := 1.0
var _equipped_weapons: Array[Node] = []
var _weapon_visuals: Array[Sprite2D] = []
const WEAPON_MELEE_SCRIPT = preload("res://scripts/weapons/weapon_melee.gd")
const WEAPON_RANGED_SCRIPT = preload("res://scripts/weapons/weapon_ranged.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_slots: Node2D = $WeaponSlots


func _ready() -> void:
	add_to_group("players")
	# 玩家仅与敌人发生实体碰撞，子弹通过 Area2D 处理。
	collision_layer = 1
	collision_mask = 2 | 8
	_update_sprite(0)
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func set_character_data(data: Dictionary) -> void:
	# 把角色模板参数应用到当前实体。
	_character_data = data.duplicate(true)
	max_health = int(_character_data.get("max_health", 100))
	base_speed = float(_character_data.get("speed", 160.0))
	current_health = max_health
	_update_sprite(int(_character_data.get("color_scheme", 0)))
	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	# 使用 Input.get_vector 自动处理对角线归一化。
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 键盘无输入时，允许触控虚拟摇杆接管。
	if move_input.length() < 0.05:
		move_input = external_move_input
	if not input_enabled:
		move_input = Vector2.ZERO
	velocity = move_input * base_speed * _terrain_speed_multiplier
	move_and_slide()

	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta
		var blink := int(Time.get_ticks_msec() / 80.0) % 2 == 0
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.45 if blink else 1.0)
	else:
		sprite.modulate = Color.WHITE

	# 降低最近敌人检索频率，缓解敌人数量上升时的每帧开销。
	_nearest_enemy_refresh -= delta
	if _nearest_enemy_refresh <= 0.0:
		_nearest_enemy_refresh = 0.12
		_cached_nearest_enemy = _get_nearest_enemy()
	var nearest_enemy := _cached_nearest_enemy
	if nearest_enemy != null and not _equipped_weapons.is_empty():
		for item in _equipped_weapons:
			if item.has_method("tick_and_try_attack"):
				item.tick_and_try_attack(self, nearest_enemy, delta)


func take_damage(amount: int) -> void:
	# 无敌计时器 > 0 时忽略后续伤害，避免多次碰撞瞬间秒杀。
	if _invulnerable_timer > 0.0:
		return
	current_health = max(current_health - amount, 0)
	_invulnerable_timer = invulnerable_duration
	emit_signal("health_changed", current_health, max_health)
	emit_signal("damaged", amount)
	if current_health <= 0:
		emit_signal("died")
		queue_free()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			pass
		"fire_rate":
			pass
		"max_health":
			max_health += 20
			current_health = mini(current_health + 20, max_health)
			emit_signal("health_changed", current_health, max_health)
		"speed":
			base_speed += 20.0
		"bullet_speed":
			pass
		"multi_shot":
			pass
		"pierce":
			pass
	for weapon in _equipped_weapons:
		if weapon.has_method("apply_upgrade"):
			weapon.apply_upgrade(upgrade_id)


func set_terrain_effect(zone_id: int, speed_multiplier: float) -> void:
	_terrain_effects[zone_id] = clampf(speed_multiplier, 0.2, 1.2)
	_recompute_terrain_speed()


func clear_terrain_effect(zone_id: int) -> void:
	_terrain_effects.erase(zone_id)
	_recompute_terrain_speed()


func _get_nearest_enemy() -> Node2D:
	# 简单线性扫描，敌人数量较少时足够稳定。
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = enemy
	return nearest


func _update_sprite(color_scheme: int) -> void:
	# 角色贴图运行时生成，不依赖外部素材。
	if sprite:
		var texture_key := "player.scheme_0" if color_scheme == 0 else "player.scheme_1"
		var fallback := func() -> Texture2D:
			return PixelGenerator.generate_player_sprite(color_scheme)
		sprite.texture = VisualAssetRegistry.get_texture(texture_key, fallback)


func _recompute_terrain_speed() -> void:
	# 规则：多地形重叠时以“最慢速度系数”为准。
	_terrain_speed_multiplier = 1.0
	for key in _terrain_effects.keys():
		_terrain_speed_multiplier = minf(_terrain_speed_multiplier, float(_terrain_effects[key]))


func equip_weapon_by_id(weapon_id: String) -> bool:
	if _equipped_weapons.size() >= GameManager.MAX_WEAPONS:
		return false
	if get_equipped_weapon_ids().has(weapon_id):
		return false
	var def := GameManager.get_weapon_def_by_id(weapon_id)
	if def.is_empty():
		return false
	var weapon_type := str(def.get("type", ""))
	var instance: Node = null
	if weapon_type == "melee":
		instance = WEAPON_MELEE_SCRIPT.new()
	else:
		instance = WEAPON_RANGED_SCRIPT.new()
	if instance == null:
		return false
	instance.configure_from_def(def)
	weapon_slots.add_child(instance)
	_equipped_weapons.append(instance)
	_refresh_weapon_visuals()
	return true


func get_equipped_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _equipped_weapons:
		ids.append(str(item.weapon_id))
	return ids


func get_weapon_capacity_left() -> int:
	return maxi(0, GameManager.MAX_WEAPONS - _equipped_weapons.size())


func _refresh_weapon_visuals() -> void:
	for node in _weapon_visuals:
		if is_instance_valid(node):
			node.queue_free()
	_weapon_visuals.clear()
	var count := _equipped_weapons.size()
	if count <= 0:
		return
	var radius := 18.0
	for i in range(count):
		var ratio := float(i) / float(count)
		var angle := ratio * TAU - PI * 0.5
		var icon := Sprite2D.new()
		var weapon_id: String = str(_equipped_weapons[i].weapon_id)
		var color_hint_any = _equipped_weapons[i].color_hint
		var color_hint: Color = color_hint_any if color_hint_any is Color else Color(0.8, 0.8, 0.8, 1.0)
		var texture_key: String = "weapon.icon." + weapon_id
		var fallback := func() -> Texture2D:
			return VisualAssetRegistry.make_color_texture(texture_key, color_hint, Vector2i(10, 10))
		icon.texture = VisualAssetRegistry.get_texture(texture_key, fallback)
		icon.position = Vector2(cos(angle), sin(angle)) * radius
		weapon_slots.add_child(icon)
		_weapon_visuals.append(icon)
