extends RefCounted
class_name MagicAffixDefs

# 魔法词条库：对应魔法专属效果（威力、冷却等）。
# 品级与 spell_speed 通过道具词条 item_spell_speed 影响。
const MAGIC_AFFIX_POOL := [
	{"id": "magic_power_bonus", "visible": true, "effect_type": "power_bonus", "base_value": 5, "name_key": "affix.magic_power.name", "desc_key": "affix.magic_power.desc"},
	{"id": "magic_cooldown_reduce", "visible": true, "effect_type": "cooldown_reduce", "base_value": 0.1, "name_key": "affix.magic_cooldown.name", "desc_key": "affix.magic_cooldown.desc"},
	{"id": "magic_burn_extend", "visible": true, "effect_type": "burn_duration", "base_value": 1.0, "name_key": "affix.magic_burn_extend.name", "desc_key": "affix.magic_burn_extend.desc"},
]


## 根据 id 获取词条定义。
static func get_affix_def(affix_id: String) -> Dictionary:
	for a in MAGIC_AFFIX_POOL:
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	return {}
