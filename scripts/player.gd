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
@export var max_mana := 50  # 魔力上限
@export var armor := 0  # 护甲，减伤点数
@export var invulnerable_duration := 0.5
@export var inertia_factor := 0.0  # 移动惯性系数：0=无惯性，越大越“滑”。

@export_file("*.png") var texture_sheet: String = "res://assets/characters/player_scheme_0_sheet.png"  # 精灵图（scheme 0）
@export_file("*.png") var texture_sheet_1: String = "res://assets/characters/player_scheme_1_sheet.png"  # 精灵图（scheme 1）
@export_file("*.png") var texture_single: String = "res://assets/characters/player_scheme_0.png"  # 单帧回退（scheme 0）
@export_file("*.png") var texture_single_1: String = "res://assets/characters/player_scheme_1.png"  # 单帧回退（scheme 1）
@export var frame_size: Vector2i = Vector2i(24, 24)  # 每帧像素尺寸
@export var sheet_columns: int = 8  # 精灵图列数（8 方向）
@export var sheet_rows: int = 3  # 精灵图行数（站立、行走1、行走2）

var current_health := 100
var current_mana := 50.0  # 当前魔力
var move_input := Vector2.ZERO
# 扩展属性：伤害加成、恢复、吸血
var melee_damage_bonus := 0  # 近战伤害加成
var ranged_damage_bonus := 0  # 远程伤害加成
var health_regen := 0.0  # 血量/秒恢复
var lifesteal_chance := 0.0  # 吸血概率 0~1，命中时按概率恢复 1 点血
var mana_regen := 1.0  # 魔力/秒恢复，初始 1
var _invulnerable_timer := 0.0
var _pending_damages: Array[int] = []  # 帧内缓冲，帧末取最大后统一结算
var _character_data := {}
var _character_traits: CharacterTraitsBase  # 角色特质，参与伤害等数值计算
var _last_direction_index := 0  # 8 方向索引，用于精灵图
var external_move_input := Vector2.ZERO
var input_enabled := true
var _nearest_enemy_refresh := 0.0
var _cached_nearest_enemy: Node2D
# 多地形叠加时记录每个 zone 的速度系数，取最慢值。
var _terrain_effects: Dictionary = {}
var _terrain_speed_multiplier := 1.0
var _equipped_weapons: Array[Node2D] = []  # 已装备武器节点，最多 MAX_WEAPONS 把
var _equipped_magics: Array = []  # 已装备魔法，最多 3 个，每项为 {def, instance}
const MAX_MAGICS := 3
var _weapon_visuals: Array[Sprite2D] = []  # 武器环上的色块图标，随装备刷新
const DEFAULT_TRAITS = preload("res://scripts/characters/character_traits_base.gd")
const WEAPON_FALLBACK_SCRIPTS := {
	"blade_short": "res://scripts/weapons/melee/weapon_blade_short.gd",
	"dagger": "res://scripts/weapons/melee/weapon_dagger.gd",
	"spear": "res://scripts/weapons/melee/weapon_spear.gd",
	"chainsaw": "res://scripts/weapons/melee/weapon_chainsaw.gd",
	"hammer_heavy": "res://scripts/weapons/melee/weapon_hammer_heavy.gd",
	"pistol_basic": "res://scripts/weapons/ranged/weapon_pistol_basic.gd",
	"shotgun_wide": "res://scripts/weapons/ranged/weapon_shotgun_wide.gd",
	"rifle_long": "res://scripts/weapons/ranged/weapon_rifle_long.gd",
	"wand_focus": "res://scripts/weapons/ranged/weapon_wand_focus.gd",
	"sniper": "res://scripts/weapons/ranged/weapon_sniper.gd",
	"orb_wand": "res://scripts/weapons/ranged/weapon_orb_wand.gd"
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_slots: Node2D = $WeaponSlots


func _ready() -> void:
	add_to_group("players")
	# 玩家仅与敌人发生实体碰撞，子弹通过 Area2D 处理。
	collision_layer = 1
	collision_mask = 2 | 8
	_update_sprite(0)
	current_health = max_health
	current_mana = float(max_mana)
	emit_signal("health_changed", current_health, max_health)


func set_character_data(data: Dictionary) -> void:
	# 把角色模板参数应用到当前实体；加载特质并参与移速/生命系数计算。
	_character_data = data.duplicate(true)
	var traits_path := str(_character_data.get("traits_path", ""))
	if traits_path != "" and ResourceLoader.exists(traits_path):
		var script_obj = load(traits_path)
		if script_obj and script_obj is GDScript:
			_character_traits = (script_obj as GDScript).new() as CharacterTraitsBase
	else:
		_character_traits = DEFAULT_TRAITS.new()
	var base_hp := int(_character_data.get("max_health", 100))
	var base_spd := float(_character_data.get("speed", 160.0))
	var base_mana := int(_character_data.get("max_mana", 50))
	max_health = int(float(base_hp) * _character_traits.get_max_health_multiplier())
	max_mana = base_mana
	base_speed = base_spd * _character_traits.get_speed_multiplier()
	current_health = max_health
	current_mana = float(max_mana)
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
	# 通过插值速度制造惯性，系数越大收敛越慢。
	var target_velocity := move_input * base_speed * _terrain_speed_multiplier
	var response := clampf(1.0 - inertia_factor, 0.05, 1.0)
	velocity = velocity.lerp(target_velocity, response)
	move_and_slide()
	_update_direction_sprite()

	# 魔法释放检测
	_try_cast_magic(delta)

	# 血量与魔力恢复
	if health_regen > 0.0 and current_health < max_health:
		var heal_amount: int = int(health_regen * delta)
		if heal_amount > 0:
			heal(heal_amount)
	current_mana = minf(current_mana + mana_regen * delta, float(max_mana))

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

	# 帧末结算缓冲伤害：多伤害源只取最大。
	if _pending_damages.size() > 0:
		var max_amount: int = _pending_damages.max()
		_pending_damages.clear()
		current_health = max(current_health - max_amount, 0)
		_invulnerable_timer = invulnerable_duration
		emit_signal("health_changed", current_health, max_health)
		emit_signal("damaged", max_amount)
		if current_health <= 0:
			emit_signal("died")
			queue_free()


func take_damage(amount: int) -> void:
	# 无敌计时器 > 0 时忽略后续伤害，避免多次碰撞瞬间秒杀。
	if _invulnerable_timer > 0.0:
		return
	# 护甲减伤：至少造成 1 点伤害
	var actual: int = maxi(1, amount - armor)
	# 缓冲到帧末，与同帧其他伤害源取最大后统一结算。
	_pending_damages.append(actual)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)


# 应用升级到玩家与所有装备武器；value 为 UpgradeDefs 计算的奖励值，null 时用默认增量。
func apply_upgrade(upgrade_id: String, value: Variant = null) -> void:
	var v = value
	match upgrade_id:
		"max_health":
			var amount: int = int(v) if v != null else 20
			max_health += amount
			current_health = mini(current_health + amount, max_health)
			emit_signal("health_changed", current_health, max_health)
		"max_mana":
			var mana_amt: int = int(v) if v != null else 10
			max_mana += mana_amt
			current_mana = minf(current_mana + float(mana_amt), float(max_mana))
		"armor":
			armor += int(v) if v != null else 2
		"speed":
			base_speed += float(v) if v != null else 20.0
		"melee_damage", "melee_damage_bonus", "damage":
			melee_damage_bonus += int(v) if v != null else 3
		"ranged_damage", "ranged_damage_bonus":
			ranged_damage_bonus += int(v) if v != null else 3
		"health_regen":
			health_regen += float(v) if v != null else 0.5
		"lifesteal_chance":
			lifesteal_chance = clampf(lifesteal_chance + float(v) if v != null else 0.03, 0.0, 1.0)
		"mana_regen":
			mana_regen += float(v) if v != null else 0.3
		"fire_rate", "bullet_speed", "multi_shot", "pierce":
			pass
	# 将升级传递给每把武器（伤害、射速、穿透等由武器实现）。
	for weapon in _equipped_weapons:
		if weapon.has_method("apply_upgrade"):
			weapon.apply_upgrade(upgrade_id)


func set_terrain_effect(zone_id: int, speed_multiplier: float) -> void:
	_terrain_effects[zone_id] = clampf(speed_multiplier, 0.2, 1.2)
	_recompute_terrain_speed()


func clear_terrain_effect(zone_id: int) -> void:
	_terrain_effects.erase(zone_id)
	_recompute_terrain_speed()


func set_move_inertia(value: float) -> void:
	# 统一入口，便于从设置菜单或其他系统动态调整惯性。
	inertia_factor = clampf(value, 0.0, 0.9)


## 装备魔法，最多 MAX_MAGICS 个；返回是否成功。
func equip_magic(magic_id: String) -> bool:
	if _equipped_magics.size() >= MAX_MAGICS:
		return false
	for m in _equipped_magics:
		if str(m.get("id", "")) == magic_id:
			return false
	var def := MagicDefs.get_magic_by_id(magic_id)
	if def.is_empty():
		return false
	var script_path := str(def.get("script_path", ""))
	if script_path == "" or not ResourceLoader.exists(script_path):
		return false
	var script_obj = load(script_path)
	if script_obj == null or not (script_obj is GDScript):
		return false
	var instance = (script_obj as GDScript).new()
	if not (instance is MagicBase):
		return false
	(instance as MagicBase).configure_from_def(def)
	_equipped_magics.append({"id": magic_id, "def": def, "instance": instance})
	return true


func get_equipped_magic_ids() -> Array[String]:
	var ids: Array[String] = []
	for m in _equipped_magics:
		ids.append(str(m.get("id", "")))
	return ids


## 获取魔法释放方向：优先朝向最近敌人，否则用移动方向或速度方向。
func _get_magic_aim_direction() -> Vector2:
	var nearest := _get_nearest_enemy()
	if nearest != null:
		return (nearest.global_position - global_position).normalized()
	if move_input.length_squared() > 0.01:
		return move_input.normalized()
	if velocity.length_squared() > 16.0:
		return velocity.normalized()
	return Vector2.RIGHT


func _try_cast_magic(_delta: float) -> void:
	if not input_enabled or _equipped_magics.is_empty():
		return
	var slot := -1
	if Input.is_action_just_pressed("cast_magic_1"):
		slot = 0
	elif Input.is_action_just_pressed("cast_magic_2"):
		slot = 1
	elif Input.is_action_just_pressed("cast_magic_3"):
		slot = 2
	if slot < 0 or slot >= _equipped_magics.size():
		return
	var mag: Dictionary = _equipped_magics[slot]
	var def: Dictionary = mag.get("def", {})
	var cost := int(def.get("mana_cost", 0))
	if current_mana < float(cost):
		return
	var instance = mag.get("instance")
	if instance == null or not (instance is MagicBase):
		return
	var dir := _get_magic_aim_direction()
	if (instance as MagicBase).cast(self, dir):
		current_mana -= float(cost)


## 供武器调用：获取近战伤害加成。
func get_melee_damage_bonus() -> int:
	return melee_damage_bonus


## 供武器调用：获取远程伤害加成。
func get_ranged_damage_bonus() -> int:
	return ranged_damage_bonus


## 供武器/子弹调用：攻击命中时按 lifesteal_chance 概率恢复 1 点血。
func try_lifesteal() -> void:
	if lifesteal_chance <= 0.0:
		return
	if randf() < lifesteal_chance:
		heal(1)


## 供武器调用：获取经角色特质修正后的最终伤害。
func get_final_damage(base_damage: int, weapon_id: String, context: Dictionary = {}) -> int:
	if _character_traits == null:
		return base_damage
	return _character_traits.get_final_damage(base_damage, weapon_id, context)


## 供武器调用：获取角色元素附魔类型。
func get_elemental_enchantment() -> String:
	if _character_traits == null:
		return ""
	return _character_traits.get_elemental_enchantment()


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


func _update_direction_sprite() -> void:
	# 8 方向 x 3 行（站立、行走帧1、行走帧2）：根据 velocity 与时间切换，实现肉眼可见的行走动画。
	if not sprite or not sprite.region_enabled:
		return
	var frame_w := frame_size.x
	var frame_h := frame_size.y
	if velocity.length_squared() > 16.0:
		var angle := velocity.angle()
		_last_direction_index = wrapi(roundi((angle + PI) / (PI / 4.0)), 0, 8)
	# 行走时在行 1、2 间交替（约 150ms 一帧）
	var row := 0
	if velocity.length_squared() > 16.0:
		row = 1 + (int(Time.get_ticks_msec() / 150) % 2)
	sprite.region_rect = Rect2(_last_direction_index * frame_w, row * frame_h, frame_w, frame_h)


func _update_sprite(color_scheme: int) -> void:
	# 角色贴图：优先 texture_sheet，失败则 texture_single，再回退 PixelGenerator。
	if not sprite:
		return
	var sheet_path := texture_sheet if color_scheme == 0 else texture_sheet_1
	var single_path := texture_single if color_scheme == 0 else texture_single_1
	var tex: Texture2D = null
	if sheet_path != "" and ResourceLoader.exists(sheet_path):
		tex = load(sheet_path) as Texture2D
	if tex != null:
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, frame_size.x, frame_size.y)
		return
	if single_path != "" and ResourceLoader.exists(single_path):
		tex = load(single_path) as Texture2D
	if tex != null:
		sprite.texture = tex
		sprite.region_enabled = false
		return
	sprite.texture = PixelGenerator.generate_player_sprite(color_scheme)
	sprite.region_enabled = false


func _recompute_terrain_speed() -> void:
	# 规则：多地形重叠时以“最慢速度系数”为准。
	_terrain_speed_multiplier = 1.0
	for key in _terrain_effects.keys():
		_terrain_speed_multiplier = minf(_terrain_speed_multiplier, float(_terrain_effects[key]))


# 装备指定武器；返回是否成功（槽位满或已装备则失败）。
func equip_weapon_by_id(weapon_id: String) -> bool:
	if _equipped_weapons.size() >= GameManager.MAX_WEAPONS:
		return false
	if get_equipped_weapon_ids().has(weapon_id):
		return false
	var def := GameManager.get_weapon_def_by_id(weapon_id)
	if def.is_empty():
		return false
	var instance := _create_weapon_instance(def)
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


func get_equipped_weapon_details() -> Array[Dictionary]:
	# 返回每把装备武器的详细数据，供暂停界面等 UI 展示。
	var result: Array[Dictionary] = []
	for item in _equipped_weapons:
		if not is_instance_valid(item):
			continue
		var d: Dictionary = {
			"id": str(item.weapon_id),
			"type": str(item.weapon_type),
			"damage": int(item.damage),
			"cooldown": float(item.cooldown),
			"range": float(item.attack_range)
		}
		if item is WeaponMeleeBase:
			var melee_item: WeaponMeleeBase = item
			d["touch_interval"] = float(melee_item.touch_interval)
			d["swing_duration"] = float(melee_item.swing_duration)
			d["swing_degrees"] = float(melee_item.swing_degrees)
			d["swing_reach"] = float(melee_item.swing_reach)
			d["hitbox_radius"] = float(melee_item.hitbox_radius)
		elif item is WeaponRangedBase:
			var ranged_item: WeaponRangedBase = item
			d["bullet_speed"] = float(ranged_item.bullet_speed)
			d["pellet_count"] = int(ranged_item.pellet_count)
			d["spread_degrees"] = float(ranged_item.spread_degrees)
			d["bullet_pierce"] = int(ranged_item.bullet_pierce)
			d["bullet_type"] = str(ranged_item.bullet_type)
		result.append(d)
	return result


func get_weapon_capacity_left() -> int:
	return maxi(0, GameManager.MAX_WEAPONS - _equipped_weapons.size())


# 刷新武器环布局：清除旧图标，按装备数量均匀分布槽位，更新每把武器的 set_slot_pose。
func _refresh_weapon_visuals() -> void:
	for node in _weapon_visuals:
		if is_instance_valid(node):
			node.queue_free()
	_weapon_visuals.clear()
	var count := _equipped_weapons.size()
	if count <= 0:
		return
	var radius := 26.0
	for i in range(count):
		var ratio := float(i) / float(count)
		var angle := ratio * TAU - PI * 0.5
		var slot_pos := Vector2(cos(angle), sin(angle)) * radius
		var weapon_node := _equipped_weapons[i]
		var icon := Sprite2D.new()
		var color_hint_any = weapon_node.color_hint
		var color_hint: Color = color_hint_any if color_hint_any is Color else Color(0.8, 0.8, 0.8, 1.0)
		var tex: Texture2D = null
		if weapon_node.icon_path != "" and ResourceLoader.exists(weapon_node.icon_path):
			tex = load(weapon_node.icon_path) as Texture2D
		if tex == null:
			tex = VisualAssetRegistry.make_color_texture(color_hint, Vector2i(10, 10))
		icon.texture = tex
		# 图标挂在武器节点下，近战挥击时图标随之移动
		weapon_node.add_child(icon)
		_weapon_visuals.append(icon)
		# 武器自身参与空间布局，远程子弹从武器位置发射
		if weapon_node.has_method("set_slot_pose"):
			weapon_node.set_slot_pose(slot_pos, angle)
		else:
			weapon_node.position = slot_pos
			weapon_node.rotation = angle


func _create_weapon_instance(def: Dictionary) -> Node2D:
	# 支持配置里声明具体武器脚本，未声明时走本地兜底映射。
	var script_path := str(def.get("script_path", ""))
	if script_path == "":
		var weapon_id := str(def.get("id", ""))
		script_path = str(WEAPON_FALLBACK_SCRIPTS.get(weapon_id, ""))
	if script_path == "":
		return null
	var script_obj = load(script_path)
	if script_obj == null or not (script_obj is GDScript):
		return null
	var instance = (script_obj as GDScript).new()
	if not (instance is Node2D):
		return null
	return instance as Node2D
