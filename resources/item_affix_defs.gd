extends RefCounted
class_name ItemAffixDefs

# 道具词条库：对应道具属性增强效果。
# 每个词条有 id、visible、effect_type（映射到 player 属性）、base_value。
const ITEM_AFFIX_POOL := [
	{"id": "item_max_health", "visible": true, "effect_type": "max_health", "base_value": 20, "name_key": "item.max_health.name", "desc_key": "item.max_health.desc"},
	{"id": "item_max_mana", "visible": true, "effect_type": "max_mana", "base_value": 15, "name_key": "item.max_mana.name", "desc_key": "item.max_mana.desc"},
	{"id": "item_armor", "visible": true, "effect_type": "armor", "base_value": 3, "name_key": "item.armor.name", "desc_key": "item.armor.desc"},
	{"id": "item_speed", "visible": true, "effect_type": "speed", "base_value": 15, "name_key": "item.speed.name", "desc_key": "item.speed.desc"},
	{"id": "item_melee", "visible": true, "effect_type": "melee_damage_bonus", "base_value": 3, "name_key": "item.melee.name", "desc_key": "item.melee.desc"},
	{"id": "item_ranged", "visible": true, "effect_type": "ranged_damage_bonus", "base_value": 3, "name_key": "item.ranged.name", "desc_key": "item.ranged.desc"},
	{"id": "item_regen", "visible": true, "effect_type": "health_regen", "base_value": 0.8, "name_key": "item.regen.name", "desc_key": "item.regen.desc"},
	{"id": "item_lifesteal", "visible": true, "effect_type": "lifesteal_chance", "base_value": 0.05, "name_key": "item.lifesteal.name", "desc_key": "item.lifesteal.desc"},
	{"id": "item_mana_regen", "visible": true, "effect_type": "mana_regen", "base_value": 0.5, "name_key": "item.mana_regen.name", "desc_key": "item.mana_regen.desc"},
	{"id": "item_spell_speed", "visible": true, "effect_type": "spell_speed", "base_value": 0.15, "name_key": "item.spell_speed.name", "desc_key": "item.spell_speed.desc"},
]


## 根据 id 获取词条定义。
static func get_affix_def(affix_id: String) -> Dictionary:
	for a in ITEM_AFFIX_POOL:
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	return {}
