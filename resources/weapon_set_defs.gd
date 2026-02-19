# 武器套装定义：同套装武器同时装备时激活套装效果
# 套装效果按装备数量（2/4/6件）分级
extends RefCounted
class_name WeaponSetDefs

const WEAPON_SETS := {
	"blade_set": {
		"name_key": "weapon_set.blade",
		"description_key": "weapon_set.blade.desc",
		"weapons": ["blade_short", "blade_long", "dagger"],
		"bonuses": {
			2: {
				"crit_chance": 0.1,
				"description_key": "weapon_set.blade.bonus_2"
			},
			4: {
				"crit_damage": 0.5,
				"bleed_on_hit": true,
				"description_key": "weapon_set.blade.bonus_4"
			},
			6: {
				"crit_chance": 0.2,
				"crit_damage": 1.0,
				"bleed_damage": 5,
				"description_key": "weapon_set.blade.bonus_6"
			}
		}
	},
	"firearm_set": {
		"name_key": "weapon_set.firearm",
		"description_key": "weapon_set.firearm.desc",
		"weapons": ["pistol_basic", "shotgun_wide", "rifle_long", "sniper"],
		"bonuses": {
			2: {
				"fire_rate": 0.15,
				"description_key": "weapon_set.firearm.bonus_2"
			},
			4: {
				"bullet_pierce": 1,
				"damage": 10,
				"description_key": "weapon_set.firearm.bonus_4"
			},
			6: {
				"fire_rate": 0.3,
				"bullet_pierce": 2,
				"damage": 20,
				"spread_reduction": 0.3,
				"description_key": "weapon_set.firearm.bonus_6"
			}
		}
	},
	"magic_set": {
		"name_key": "weapon_set.magic",
		"description_key": "weapon_set.magic.desc",
		"weapons": ["wand_focus", "orb_wand", "elemental_staff"],
		"bonuses": {
			2: {
				"mana_cost_reduction": 0.1,
				"description_key": "weapon_set.magic.bonus_2"
			},
			4: {
				"magic_damage": 0.2,
				"cooldown_reduction": 0.15,
				"description_key": "weapon_set.magic.bonus_4"
			},
			6: {
				"mana_cost_reduction": 0.2,
				"magic_damage": 0.4,
				"elemental_amount_bonus": 1,
				"description_key": "weapon_set.magic.bonus_6"
			}
		}
	},
	"heavy_set": {
		"name_key": "weapon_set.heavy",
		"description_key": "weapon_set.heavy.desc",
		"weapons": ["hammer_heavy", "chainsaw", "spear"],
		"bonuses": {
			2: {
				"armor": 2,
				"knockback_bonus": 0.2,
				"description_key": "weapon_set.heavy.bonus_2"
			},
			4: {
				"armor": 5,
				"damage_reduction": 0.1,
				"stun_chance": 0.15,
				"description_key": "weapon_set.heavy.bonus_4"
			},
			6: {
				"armor": 10,
				"max_health": 50,
				"damage_reduction": 0.2,
				"stun_duration": 0.5,
				"description_key": "weapon_set.heavy.bonus_6"
			}
		}
	}
}


## [自定义] 获取武器所属的套装ID列表（一个武器可能在多个套装中）。
static func get_weapon_sets(weapon_id: String) -> Array[String]:
	var result: Array[String] = []
	for set_id in WEAPON_SETS.keys():
		var set_data: Dictionary = WEAPON_SETS[set_id]
		var weapons: Array = set_data.get("weapons", [])
		if weapon_id in weapons:
			result.append(set_id)
	return result


## [自定义] 计算当前装备的套装效果。
## equipped_weapons: [{id, tier}, ...]
## 返回: {set_id: {count, active_bonus, bonuses}}
static func calculate_set_bonuses(equipped_weapons: Array) -> Dictionary:
	var result := {}
	
	# 统计每个套装的装备数量
	var set_counts := {}
	for w in equipped_weapons:
		var weapon_id: String = str(w.get("id", ""))
		if weapon_id == "":
			continue
		var sets := get_weapon_sets(weapon_id)
		for set_id in sets:
			if not set_counts.has(set_id):
				set_counts[set_id] = {"count": 0, "weapons": []}
			# 同武器ID只计算一次（避免同名武器重复计数）
			if not weapon_id in set_counts[set_id]["weapons"]:
				set_counts[set_id]["count"] += 1
				set_counts[set_id]["weapons"].append(weapon_id)
	
	# 计算激活的套装效果
	for set_id in set_counts.keys():
		var count: int = set_counts[set_id]["count"]
		var set_data: Dictionary = WEAPON_SETS.get(set_id, {})
		var all_bonuses: Dictionary = set_data.get("bonuses", {})
		
		# 找出最高激活等级
		var active_thresholds: Array[int] = []
		for threshold_str in all_bonuses.keys():
			var threshold: int = int(threshold_str)
			if count >= threshold:
				active_thresholds.append(threshold)
		active_thresholds.sort()
		
		var active_bonuses := {}
		var highest_threshold := 0
		if not active_thresholds.is_empty():
			highest_threshold = active_thresholds[-1]
			active_bonuses = all_bonuses.get(highest_threshold, {})
		
		result[set_id] = {
			"count": count,
			"highest_threshold": highest_threshold,
			"active_bonuses": active_bonuses,
			"all_bonuses": all_bonuses,
			"name_key": set_data.get("name_key", ""),
			"description_key": set_data.get("description_key", "")
		}
	
	return result


## [自定义] 获取套装完整展示信息，供详情面板与人物属性面板使用。
## 返回: [{set_id, name_key, count, thresholds: [{n, desc_key, desc, active}], active_threshold}]
static func get_weapon_set_full_display_info(equipped_weapons: Array) -> Array:
	var bonuses := calculate_set_bonuses(equipped_weapons)
	var result: Array = []
	for set_id in bonuses.keys():
		var info: Dictionary = bonuses[set_id]
		var count: int = int(info.get("count", 0))
		var name_key: String = str(info.get("name_key", ""))
		var all_bonuses: Dictionary = info.get("all_bonuses", {})
		var highest_threshold: int = int(info.get("highest_threshold", 0))
		var thresholds: Array = []
		for n in [2, 4, 6]:
			if all_bonuses.has(n):
				var tier_data: Dictionary = all_bonuses[n]
				var desc_key: String = str(tier_data.get("description_key", ""))
				var desc: String = LocalizationManager.tr_key(desc_key) if desc_key != "" else ""
				var active: bool = (n == highest_threshold)
				thresholds.append({"n": n, "desc_key": desc_key, "desc": desc, "active": active})
		result.append({
			"set_id": set_id,
			"name_key": name_key,
			"count": count,
			"thresholds": thresholds,
			"active_threshold": highest_threshold
		})
	return result


## [自定义] 获取套装效果的文本描述。
static func get_set_bonus_description(set_id: String, equipped_weapons: Array) -> String:
	var bonuses := calculate_set_bonuses(equipped_weapons)
	var set_info: Dictionary = bonuses.get(set_id, {})
	if set_info.is_empty():
		return ""
	
	var name: String = LocalizationManager.tr_key(str(set_info.get("name_key", "")))
	var count: int = int(set_info.get("count", 0))
	var highest: int = int(set_info.get("highest_threshold", 0))
	
	var desc := "[%s] (%d件)" % [name, count]
	if highest > 0:
		desc += " - %d件套效果激活" % highest
	
	return desc


## [自定义] 将套装效果应用到玩家属性。
static func apply_set_bonuses_to_player(player: Node, equipped_weapons: Array) -> void:
	var bonuses := calculate_set_bonuses(equipped_weapons)
	
	# 累加所有激活的效果
	var total_crit_chance := 0.0
	var total_crit_damage := 0.0
	var total_armor := 0
	var total_damage := 0
	var total_fire_rate := 0.0
	var total_mana_reduction := 0.0
	
	for set_id in bonuses.keys():
		var set_data: Dictionary = bonuses[set_id]
		var active: Dictionary = set_data.get("active_bonuses", {})
		
		total_crit_chance += float(active.get("crit_chance", 0))
		total_crit_damage += float(active.get("crit_damage", 0))
		total_armor += int(active.get("armor", 0))
		total_damage += int(active.get("damage", 0))
		total_fire_rate += float(active.get("fire_rate", 0))
		total_mana_reduction += float(active.get("mana_cost_reduction", 0))
		
		# 处理特殊效果（如 bleed_on_hit）可以通过玩家属性标记
		if active.has("bleed_on_hit") and active.get("bleed_on_hit", false):
			# 在玩家上设置标记，供武器系统查询
			player.set_meta("set_bleed_on_hit", true)
		if active.has("bullet_pierce"):
			var current: int = player.get_meta("set_pierce_bonus", 0)
			player.set_meta("set_pierce_bonus", maxi(current, int(active.get("bullet_pierce", 0))))
	
	# 应用数值加成到玩家
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
