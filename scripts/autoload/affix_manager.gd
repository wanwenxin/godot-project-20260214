extends Node

# 词条管理器：收集玩家装备/道具/升级中的词条，聚合效果并应用到玩家。
# 使效果与具体物体解耦，支持批量应用与组合效果扩展。
# 升级中影响玩家的部分与道具均通过词条驱动。

# 玩家相关升级 id（影响玩家属性），其余为武器相关
const _PLAYER_UPGRADE_IDS := [
	"max_health", "max_mana", "armor", "speed", "melee_damage", "melee_damage_bonus",
	"ranged_damage", "ranged_damage_bonus", "health_regen", "lifesteal_chance",
	"mana_regen", "attack_speed", "spell_speed", "damage"
]

# upgrade_id -> effect_type 映射（升级 id 与道具 effect_type 一致时无需映射）
const _UPGRADE_TO_EFFECT := {
	"damage": "melee_damage_bonus",
	"melee_damage": "melee_damage_bonus",
	"ranged_damage": "ranged_damage_bonus",
}

# 浮点类 effect_type
const _FLOAT_EFFECTS := ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed", "spell_speed", "speed"]


## [自定义] 从玩家收集所有词条（道具 + 升级），按类型分组。
func collect_affixes_from_player(_player: Node) -> Dictionary:
	var result := {"item": [], "weapon": [], "magic": []}
	# 道具词条：从 run_items 推导
	var item_ids: Array = GameManager.get_run_items()
	for item_id in item_ids:
		var def := _get_item_def_by_id(str(item_id))
		if def.is_empty():
			continue
		var affix_ids_val = def.get("affix_ids")
		var affix_ids: Array = affix_ids_val if affix_ids_val != null else []
		if affix_ids.is_empty():
			# 兼容旧格式：attr + base_value 视为单个词条
			var attr_val = def.get("attr")
			var attr: String = str(attr_val if attr_val != null else "")
			if attr != "":
				affix_ids = [_attr_to_affix_id(attr)]
		for aid in affix_ids:
			var affix_def := ItemAffixDefs.get_affix_def(str(aid))
			if affix_def.is_empty():
				continue
			var affix := ItemAffix.new()
			affix.configure_from_def(affix_def)
			var tier_val = def.get("tier")
			var tier: int = int(tier_val if tier_val != null else 0)
			var mult: float = TierConfig.get_item_tier_multiplier(tier)
			# 绑定时可覆盖数值：item 的 base_value 优先于词条默认值
			var bound_val = def.get("base_value")
			var base_value_val = affix.params.get("base_value")
			var bv: Variant = bound_val if bound_val != null else (base_value_val if base_value_val != null else 0)
			if bv is float:
				affix.params["base_value"] = bv * mult
			else:
				affix.params["base_value"] = int(float(bv) * mult)
			result["item"].append(affix)
	# 升级词条：从 run_upgrades 推导
	var upgrades: Array = GameManager.get_run_upgrades()
	for u in upgrades:
		var uid_val = u.get("id")
		var uid: String = str(uid_val if uid_val != null else "")
		var uval = u.get("value")
		if uid == "" or uval == null:
			continue
		var effect_type: String = (_UPGRADE_TO_EFFECT.get(uid) if _UPGRADE_TO_EFFECT.has(uid) else uid)
		var affix := ItemAffix.new()
		affix.id = "upgrade_%s" % uid
		affix.visible = true
		affix.params = {"effect_type": effect_type, "base_value": uval}
		result["item"].append(affix)
	return result


## [自定义] 聚合词条效果，返回 {effect_type: value}。
func get_aggregated_effects(affixes: Dictionary) -> Dictionary:
	var agg := {}
	for _type in ["item", "weapon", "magic"]:
		var list: Array = affixes[_type] if affixes.has(_type) else []
		for a in list:
			if not (a is AffixBase):
				continue
			var et: String = str(a.params["effect_type"] if a.params.has("effect_type") else "")
			if et == "":
				continue
			var bv = a.params.get("base_value", 0)
			if agg.has(et):
				var cur = agg[et]
				if et in _FLOAT_EFFECTS:
					agg[et] = float(cur) + float(bv)
				else:
					agg[et] = int(cur) + int(bv)
			else:
				agg[et] = bv
	# 特殊处理：lifesteal_chance 限制在 0~1
	if agg.has("lifesteal_chance"):
		agg["lifesteal_chance"] = clampf(float(agg["lifesteal_chance"]), 0.0, 1.0)
	return agg


## [自定义] 将聚合效果应用到玩家。需在 set_character_data 之后调用。
func apply_affix_effects(player: Node, aggregated: Dictionary) -> void:
	if not player.has_method("_apply_affix_aggregated"):
		return
	player._apply_affix_aggregated(aggregated)


## [自定义] 刷新玩家：收集词条、聚合、应用（含套装加成+武器套装效果）。
func refresh_player(player: Node) -> void:
	var affixes := collect_affixes_from_player(player)
	var agg := get_aggregated_effects(affixes)
	var set_bonus := get_set_bonus_effects()
	_merge_effects(agg, set_bonus)
	# 应用武器套装效果（新系统）
	_apply_weapon_set_bonuses(player)
	apply_affix_effects(player, agg)


## [自定义] 计算并应用武器套装效果。
func _apply_weapon_set_bonuses(player: Node) -> void:
	var run_weapons: Array = GameManager.get_run_weapons()
	var equipped_weapons: Array = []
	for w in run_weapons:
		equipped_weapons.append({"id": str(w.get("id", "")), "tier": int(w.get("tier", 0))})
	
	var bonuses := WeaponSetDefs.calculate_set_bonuses(equipped_weapons)
	
	# 累加所有激活的效果到玩家
	var total_crit_chance := 0.0
	var total_crit_damage := 0.0
	var total_armor := 0
	var total_damage := 0
	var total_fire_rate := 0.0
	var total_mana_reduction := 0.0
	var total_magic_damage := 0.0
	
	for set_id in bonuses.keys():
		var set_data: Dictionary = bonuses[set_id]
		var active_val = set_data.get("active_bonuses")
		var active: Dictionary = active_val if active_val != null else {}
		
		total_crit_chance += float(active.get("crit_chance") if active.has("crit_chance") else 0)
		total_crit_damage += float(active.get("crit_damage") if active.has("crit_damage") else 0)
		total_armor += int(active.get("armor") if active.has("armor") else 0)
		total_damage += int(active.get("damage") if active.has("damage") else 0)
		total_fire_rate += float(active.get("fire_rate") if active.has("fire_rate") else 0)
		total_mana_reduction += float(active.get("mana_cost_reduction") if active.has("mana_cost_reduction") else 0)
		total_magic_damage += float(active.get("magic_damage") if active.has("magic_damage") else 0)
		
		# 特殊效果通过玩家 meta 设置
		if active.has("bleed_on_hit") and (active.get("bleed_on_hit") if active.has("bleed_on_hit") else false):
			player.set_meta("set_bleed_on_hit", true)
		if active.has("bullet_pierce"):
			var current: int = player.get_meta("set_pierce_bonus") if player.has_meta("set_pierce_bonus") else 0
			var bullet_pierce_val = active.get("bullet_pierce") if active.has("bullet_pierce") else 0
			player.set_meta("set_pierce_bonus", maxi(current, int(bullet_pierce_val)))
		if active.has("stun_chance"):
			var stun_chance_val = active.get("stun_chance")
			player.set_meta("set_stun_chance", float(stun_chance_val if stun_chance_val != null else 0))
	
	# 应用数值加成
	if total_armor > 0:
		player.armor += total_armor
	if total_crit_chance > 0:
		player.set_meta("crit_chance_bonus", total_crit_chance)
	if total_crit_damage > 0:
		player.set_meta("crit_damage_bonus", total_crit_damage)
	if total_fire_rate > 0:
		# 安全地获取 attack_speed 属性，如果不存在则使用默认值 1.0
		var current_attack_speed = 1.0
		if player.has_method("get_attack_speed"):
			current_attack_speed = player.get_attack_speed()
		elif "attack_speed" in player:
			current_attack_speed = player.attack_speed
		player.attack_speed = current_attack_speed * (1.0 + total_fire_rate)
	if total_mana_reduction > 0:
		player.set_meta("mana_cost_reduction", total_mana_reduction)
	if total_magic_damage > 0:
		player.set_meta("magic_damage_bonus", total_magic_damage)
	if total_damage > 0:
		# 近战和远程伤害都增加
		player.melee_damage_bonus += total_damage
		player.ranged_damage_bonus += total_damage


## [自定义] 计算武器类型/主题套装加成。多把同名武器只计 1 次，2-6 件线性增长。
func get_set_bonus_effects() -> Dictionary:
	var result := {}
	var run_weapons_list: Array = GameManager.get_run_weapons()
	# 去重 weapon_id（每个 id 只计 1 次）
	var unique_ids: Array[String] = []
	for w in run_weapons_list:
		var wid: String = str(w.get("id", ""))
		if wid != "" and not unique_ids.has(wid):
			unique_ids.append(wid)
	# 按 type_affix_id、theme_affix_id 分组计数
	var type_counts: Dictionary = {}
	var theme_counts: Dictionary = {}
	for wid in unique_ids:
		var def := GameManager.get_weapon_def_by_id(wid)
		if def.is_empty():
			continue
		var tid_val = def.get("type_affix_id")
		var tid: String = str(tid_val if tid_val != null else "")
		if tid != "":
			var count_val = type_counts.get(tid)
			type_counts[tid] = (count_val if count_val != null else 0) + 1
		var thid_val = def.get("theme_affix_id")
		var thid: String = str(thid_val if thid_val != null else "")
		if thid != "":
			var count_val2 = theme_counts.get(thid)
			theme_counts[thid] = (count_val2 if count_val2 != null else 0) + 1
	# 计算套装加成：bonus = (count - 1) * bonus_per_count，2 <= count <= 6
	for tid in type_counts.keys():
		var count: int = int(type_counts[tid])
		if count < 2 or count > 6:
			continue
		var def := WeaponTypeAffixDefs.get_affix_def(tid)
		if def.is_empty():
			continue
		var et_val = def.get("effect_type")
		var et: String = str(et_val if et_val != null else "")
		var bpc_val = def.get("bonus_per_count")
		var bpc = bpc_val if bpc_val != null else 0
		if et == "" or bpc == null:
			continue
		var bonus = (count - 1) * float(bpc)
		if et in _FLOAT_EFFECTS:
			result[et] = result[et] if result.has(et) else 0.0 + bonus
		else:
			result[et] = result[et] if result.has(et) else 0 + int(bonus)
	for thid in theme_counts.keys():
		var count: int = int(theme_counts[thid])
		if count < 2 or count > 6:
			continue
		var def := WeaponThemeAffixDefs.get_affix_def(thid)
		if def.is_empty():
			continue
		var et_val = def.get("effect_type")
		var et: String = str(et_val if et_val != null else "")
		var bpc_val = def.get("bonus_per_count")
		var bpc = bpc_val if bpc_val != null else 0
		if et == "" or bpc == null:
			continue
		var bonus = (count - 1) * float(bpc)
		if et in _FLOAT_EFFECTS:
			result[et] = (result[et] if result.has(et) else 0.0) + bonus
		else:
			result[et] = (result[et] if result.has(et) else 0) + int(bonus)
	# lifesteal_chance 限制在 0~1
	if result.has("lifesteal_chance"):
		result["lifesteal_chance"] = clampf(float(result["lifesteal_chance"]), 0.0, 1.0)
	return result


## [自定义] 将 set_bonus 合并到 agg（按 effect_type 累加）。
func _merge_effects(agg: Dictionary, set_bonus: Dictionary) -> void:
	for et in set_bonus.keys():
		var val = set_bonus[et]
		if agg.has(et):
			var cur = agg[et]
			if et in _FLOAT_EFFECTS:
				agg[et] = float(cur) + float(val)
			else:
				agg[et] = int(cur) + int(val)
		else:
			agg[et] = val


## [自定义] 获取可见词条列表，供 UI 展示。
func get_visible_affixes(_affixes: Dictionary) -> Array:
	var out: Array = []
	for _type in ["item", "weapon", "magic"]:
		var list: Array = _affixes[_type] if _affixes.has(_type) else []
		for a in list:
			if a is AffixBase and a.visible:
				out.append(a)
	return out


## [自定义] 检测词条组合，返回触发的组合效果 id 列表。预留扩展点。
func check_combos(_affixes: Dictionary) -> Array:
	# 后续在 affix_combo_defs.gd 中配置
	return []


## [自定义] 获取套装效果展示信息，供 UI 显示。返回 [{name_key, count, effect_type, bonus}]。
func get_set_bonus_display_info() -> Array:
	var result: Array = []
	var run_weapons_list: Array = GameManager.get_run_weapons()
	var unique_ids: Array[String] = []
	for w in run_weapons_list:
		var wid: String = str(w.get("id", ""))
		if wid != "" and not unique_ids.has(wid):
			unique_ids.append(wid)
	var type_counts: Dictionary = {}
	var theme_counts: Dictionary = {}
	for wid in unique_ids:
		var def := GameManager.get_weapon_def_by_id(wid)
		if def.is_empty():
			continue
		var tid_val = def.get("type_affix_id")
		var tid: String = str(tid_val if tid_val != null else "")
		if tid != "":
			var count_val = type_counts.get(tid)
			type_counts[tid] = (count_val if count_val != null else 0) + 1
		var thid_val = def.get("theme_affix_id")
		var thid: String = str(thid_val if thid_val != null else "")
		if thid != "":
			var count_val2 = theme_counts.get(thid)
			theme_counts[thid] = (count_val2 if count_val2 != null else 0) + 1
	for tid in type_counts.keys():
		var count: int = int(type_counts[tid])
		if count < 2 or count > 6:
			continue
		var def := WeaponTypeAffixDefs.get_affix_def(tid)
		if def.is_empty():
			continue
		var bonus_val = def.get("bonus_per_count")
		var bonus := (count - 1) * float(bonus_val if bonus_val != null else 0)
		result.append({"name_key": str(def.get("name_key", "")), "count": count, "effect_type": str(def.get("effect_type", "")), "bonus": bonus})
	for thid in theme_counts.keys():
		var count: int = int(theme_counts[thid])
		if count < 2 or count > 6:
			continue
		var def := WeaponThemeAffixDefs.get_affix_def(thid)
		if def.is_empty():
			continue
		var bonus_val2 = def.get("bonus_per_count")
		var bonus := (count - 1) * float(bonus_val2 if bonus_val2 != null else 0)
		result.append({"name_key": str(def.get("name_key", "")), "count": count, "effect_type": str(def.get("effect_type", "")), "bonus": bonus})
	return result


## [自定义] 按 id 查找道具定义，未找到返回空字典。
func _get_item_def_by_id(item_id: String) -> Dictionary:
	for item in ShopItemDefs.ITEM_POOL:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


## [自定义] 将旧格式 attr 映射为词条 id，兼容旧配置。
func _attr_to_affix_id(attr: String) -> String:
	var m := {
		"max_health": "item_max_health", "max_mana": "item_max_mana", "armor": "item_armor",
		"speed": "item_speed", "melee_damage_bonus": "item_melee", "ranged_damage_bonus": "item_ranged",
		"health_regen": "item_regen", "lifesteal_chance": "item_lifesteal",
		"mana_regen": "item_mana_regen", "spell_speed": "item_spell_speed"
	}
	var mapped_val = m.get(attr) if m.has(attr) else null
	return mapped_val if mapped_val != null else ("item_%s" % attr)
