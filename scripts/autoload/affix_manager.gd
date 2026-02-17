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


## 从玩家收集所有词条（道具 + 升级），按类型分组。
func collect_affixes_from_player(_player: Node) -> Dictionary:
	var result := {"item": [], "weapon": [], "magic": []}
	# 道具词条：从 run_items 推导
	var item_ids: Array = GameManager.get_run_items()
	for item_id in item_ids:
		var def := _get_item_def_by_id(str(item_id))
		if def.is_empty():
			continue
		var affix_ids: Array = def.get("affix_ids", [])
		if affix_ids.is_empty():
			# 兼容旧格式：attr + base_value 视为单个词条
			var attr: String = str(def.get("attr", ""))
			if attr != "":
				affix_ids = [_attr_to_affix_id(attr)]
		for aid in affix_ids:
			var affix_def := ItemAffixDefs.get_affix_def(str(aid))
			if affix_def.is_empty():
				continue
			var affix := ItemAffix.new()
			affix.configure_from_def(affix_def)
			var tier: int = int(def.get("tier", 0))
			var mult: float = TierConfig.get_item_tier_multiplier(tier)
			# 绑定时可覆盖数值：item 的 base_value 优先于词条默认值
			var bound_val = def.get("base_value")
			var bv: Variant = bound_val if bound_val != null else affix.params.get("base_value", 0)
			if bv is float:
				affix.params["base_value"] = bv * mult
			else:
				affix.params["base_value"] = int(float(bv) * mult)
			result["item"].append(affix)
	# 升级词条：从 run_upgrades 推导
	var upgrades: Array = GameManager.get_run_upgrades()
	for u in upgrades:
		var uid: String = str(u.get("id", ""))
		var uval = u.get("value")
		if uid == "" or uval == null:
			continue
		var effect_type: String = _UPGRADE_TO_EFFECT.get(uid, uid)
		var affix := ItemAffix.new()
		affix.id = "upgrade_%s" % uid
		affix.visible = true
		affix.params = {"effect_type": effect_type, "base_value": uval}
		result["item"].append(affix)
	return result


## 聚合词条效果，返回 {effect_type: value}。
func get_aggregated_effects(affixes: Dictionary) -> Dictionary:
	var agg := {}
	for _type in ["item", "weapon", "magic"]:
		var list: Array = affixes.get(_type, [])
		for a in list:
			if not (a is AffixBase):
				continue
			var et: String = str(a.params.get("effect_type", ""))
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


## 将聚合效果应用到玩家。需在 set_character_data 之后调用。
func apply_affix_effects(player: Node, aggregated: Dictionary) -> void:
	if not player.has_method("_apply_affix_aggregated"):
		return
	player._apply_affix_aggregated(aggregated)


## 刷新玩家：收集词条、聚合、应用（含套装加成）。
func refresh_player(player: Node) -> void:
	var affixes := collect_affixes_from_player(player)
	var agg := get_aggregated_effects(affixes)
	var set_bonus := get_set_bonus_effects()
	_merge_effects(agg, set_bonus)
	apply_affix_effects(player, agg)


## 计算武器类型/主题套装加成。多把同名武器只计 1 次，2-6 件线性增长。
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
		var tid: String = str(def.get("type_affix_id", ""))
		if tid != "":
			type_counts[tid] = type_counts.get(tid, 0) + 1
		var thid: String = str(def.get("theme_affix_id", ""))
		if thid != "":
			theme_counts[thid] = theme_counts.get(thid, 0) + 1
	# 计算套装加成：bonus = (count - 1) * bonus_per_count，2 <= count <= 6
	for tid in type_counts.keys():
		var count: int = int(type_counts[tid])
		if count < 2 or count > 6:
			continue
		var def := WeaponTypeAffixDefs.get_affix_def(tid)
		if def.is_empty():
			continue
		var et: String = str(def.get("effect_type", ""))
		var bpc = def.get("bonus_per_count", 0)
		if et == "" or bpc == null:
			continue
		var bonus = (count - 1) * float(bpc)
		if et in _FLOAT_EFFECTS:
			result[et] = result.get(et, 0.0) + bonus
		else:
			result[et] = result.get(et, 0) + int(bonus)
	for thid in theme_counts.keys():
		var count: int = int(theme_counts[thid])
		if count < 2 or count > 6:
			continue
		var def := WeaponThemeAffixDefs.get_affix_def(thid)
		if def.is_empty():
			continue
		var et: String = str(def.get("effect_type", ""))
		var bpc = def.get("bonus_per_count", 0)
		if et == "" or bpc == null:
			continue
		var bonus = (count - 1) * float(bpc)
		if et in _FLOAT_EFFECTS:
			result[et] = result.get(et, 0.0) + bonus
		else:
			result[et] = result.get(et, 0) + int(bonus)
	# lifesteal_chance 限制在 0~1
	if result.has("lifesteal_chance"):
		result["lifesteal_chance"] = clampf(float(result["lifesteal_chance"]), 0.0, 1.0)
	return result


## 将 set_bonus 合并到 agg（按 effect_type 累加）。
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


## 获取可见词条列表，供 UI 展示。
func get_visible_affixes(_affixes: Dictionary) -> Array:
	var out: Array = []
	for _type in ["item", "weapon", "magic"]:
		var list: Array = _affixes.get(_type, [])
		for a in list:
			if a is AffixBase and a.visible:
				out.append(a)
	return out


## 检测词条组合，返回触发的组合效果 id 列表。预留扩展点。
func check_combos(_affixes: Dictionary) -> Array:
	# 后续在 affix_combo_defs.gd 中配置
	return []


## 获取套装效果展示信息，供 UI 显示。返回 [{name_key, count, effect_type, bonus}]。
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
		var tid: String = str(def.get("type_affix_id", ""))
		if tid != "":
			type_counts[tid] = type_counts.get(tid, 0) + 1
		var thid: String = str(def.get("theme_affix_id", ""))
		if thid != "":
			theme_counts[thid] = theme_counts.get(thid, 0) + 1
	for tid in type_counts.keys():
		var count: int = int(type_counts[tid])
		if count < 2 or count > 6:
			continue
		var def := WeaponTypeAffixDefs.get_affix_def(tid)
		if def.is_empty():
			continue
		var bonus := (count - 1) * float(def.get("bonus_per_count", 0))
		result.append({"name_key": str(def.get("name_key", "")), "count": count, "effect_type": str(def.get("effect_type", "")), "bonus": bonus})
	for thid in theme_counts.keys():
		var count: int = int(theme_counts[thid])
		if count < 2 or count > 6:
			continue
		var def := WeaponThemeAffixDefs.get_affix_def(thid)
		if def.is_empty():
			continue
		var bonus := (count - 1) * float(def.get("bonus_per_count", 0))
		result.append({"name_key": str(def.get("name_key", "")), "count": count, "effect_type": str(def.get("effect_type", "")), "bonus": bonus})
	return result


func _get_item_def_by_id(item_id: String) -> Dictionary:
	for item in ShopItemDefs.ITEM_POOL:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _attr_to_affix_id(attr: String) -> String:
	var m := {
		"max_health": "item_max_health", "max_mana": "item_max_mana", "armor": "item_armor",
		"speed": "item_speed", "melee_damage_bonus": "item_melee", "ranged_damage_bonus": "item_ranged",
		"health_regen": "item_regen", "lifesteal_chance": "item_lifesteal",
		"mana_regen": "item_mana_regen", "spell_speed": "item_spell_speed"
	}
	return m.get(attr, "item_%s" % attr)
